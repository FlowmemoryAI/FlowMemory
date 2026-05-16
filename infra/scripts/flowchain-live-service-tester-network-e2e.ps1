param(
    [string] $RpcUrl = "http://127.0.0.1:8787",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json",
    [int] $PollSeconds = 75
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot -Purpose "live-service-tester-network-e2e" | Out-Null
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/state.json")
$nodeFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/node")

function Invoke-LocalJson {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [string] $Method = "GET",
        [object] $Body = $null
    )

    $uri = "$($RpcUrl.TrimEnd('/'))$Path"
    $args = @{
        Uri = $uri
        Method = $Method
        TimeoutSec = 30
    }
    if ($null -ne $Body) {
        $args.ContentType = "application/json"
        $args.Body = $Body | ConvertTo-Json -Depth 20
    }
    return Invoke-RestMethod @args
}

function Invoke-LocalRpc {
    param(
        [Parameter(Mandatory = $true)][string] $Method,
        [object] $Params = @{}
    )

    $response = Invoke-LocalJson -Path "/rpc" -Method "POST" -Body ([ordered]@{
        jsonrpc = "2.0"
        id = $Method
        method = $Method
        params = $Params
    })
    if ($response.PSObject.Properties.Name -contains "error" -and $null -ne $response.error) {
        throw "RPC $Method failed: $($response.error.message)"
    }
    return $response.result
}

function Invoke-CargoJson {
    param([Parameter(Mandatory = $true)][string[]] $ArgumentList)

    $output = & cargo @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "cargo $($ArgumentList -join ' ') failed with exit code $LASTEXITCODE"
    }
    return $output | ConvertFrom-Json
}

function Wait-LocalBalanceEquals {
    param(
        [Parameter(Mandatory = $true)][string] $AccountId,
        [Parameter(Mandatory = $true)][int64] $Amount
    )

    $deadline = (Get-Date).AddSeconds($PollSeconds)
    $lastError = $null
    while ((Get-Date) -lt $deadline) {
        try {
            $balance = Invoke-LocalRpc -Method "balance_get" -Params @{ accountId = $AccountId }
            $actual = [int64] $balance.amount
            if ($actual -eq $Amount) {
                return $balance
            }
            $lastError = "balance=$actual expected=$Amount"
        }
        catch {
            $lastError = $_.Exception.Message
        }
        Start-Sleep -Seconds 1
    }
    throw "Timed out waiting for $AccountId balance = $Amount. Last status: $lastError"
}

function Wait-LocalBalanceAtLeast {
    param(
        [Parameter(Mandatory = $true)][string] $AccountId,
        [Parameter(Mandatory = $true)][int64] $Amount
    )

    $deadline = (Get-Date).AddSeconds($PollSeconds)
    $lastError = $null
    while ((Get-Date) -lt $deadline) {
        try {
            $balance = Invoke-LocalRpc -Method "balance_get" -Params @{ accountId = $AccountId }
            $actual = [int64] $balance.amount
            if ($actual -ge $Amount) {
                return $balance
            }
            $lastError = "balance=$actual expectedAtLeast=$Amount"
        }
        catch {
            $lastError = $_.Exception.Message
        }
        Start-Sleep -Seconds 1
    }
    throw "Timed out waiting for $AccountId balance >= $Amount. Last status: $lastError"
}

function Get-ChainBlockValue {
    param([object] $Status)

    foreach ($name in @("currentBlock", "latestHeight", "latestBlockNumber", "finalizedBlock")) {
        if ($Status.PSObject.Properties.Name -contains $name) {
            return "$($Status.$name)"
        }
    }
    return ""
}

$serviceStatus = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-service-status.ps1") -AllowBlocked 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Live service tester network E2E requires running local service. Status output: $serviceStatus"
}

$runId = ((Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmssfff") + "-$PID")
$signer = "operator:live-service-tester-network-e2e"
$testerNames = @("tester-a", "tester-b", "tester-c", "tester-d")

$health = Invoke-LocalJson -Path "/health"
$discover = Invoke-LocalJson -Path "/rpc/discover"
$readiness = Invoke-LocalJson -Path "/rpc/readiness"
$chainBefore = Invoke-LocalJson -Path "/chain/status"

$walletCreates = @()
$accounts = @()
foreach ($testerName in $testerNames) {
    $walletCreate = Invoke-LocalJson -Path "/wallets/create" -Method "POST" -Body ([ordered]@{
        label = "live-service-$runId-$testerName"
        password = "local-tester-network-$runId-$testerName"
        chainId = "31337"
        replace = $true
        isolated = $true
    })
    $walletCreatePublicOnly = $walletCreate.PSObject.Properties.Name -contains "secretMaterialReturned" -and $walletCreate.secretMaterialReturned -eq $false
    if (-not $walletCreatePublicOnly) {
        throw "Wallet create endpoint did not preserve the public-only response boundary for $testerName."
    }
    if ($walletCreate.PSObject.Properties.Name -notcontains "account" -or $null -eq $walletCreate.account -or [string]::IsNullOrWhiteSpace("$($walletCreate.account.accountId)")) {
        throw "Wallet create endpoint did not return a public account id for $testerName."
    }
    $accounts += "$($walletCreate.account.accountId)"
    $walletCreates += [ordered]@{
        tester = $testerName
        schema = $walletCreate.schema
        created = $walletCreate.created
        alreadyExists = $walletCreate.alreadyExists
        isolated = $walletCreate.isolated
        accountId = "$($walletCreate.account.accountId)"
        keyScheme = "$($walletCreate.account.keyScheme)"
        secretMaterialReturned = $walletCreate.secretMaterialReturned
        credentialStored = if ($walletCreate.PSObject.Properties.Name -contains "credentialStored") { $walletCreate.credentialStored } else { $null }
    }
}

$expectedBalances = [ordered]@{
    $accounts[0] = 108
    $accounts[1] = 98
    $accounts[2] = 96
    $accounts[3] = 98
}
$transfers = @(
    [ordered]@{ from = $accounts[0]; to = $accounts[1]; amount = 11 },
    [ordered]@{ from = $accounts[1]; to = $accounts[2]; amount = 13 },
    [ordered]@{ from = $accounts[2]; to = $accounts[3]; amount = 17 },
    [ordered]@{ from = $accounts[3]; to = $accounts[0]; amount = 19 }
)

$fundingTxIds = @()
foreach ($account in $accounts) {
    $fund = Invoke-CargoJson -ArgumentList @(
        "run",
        "--manifest-path",
        "crates/flowmemory-devnet/Cargo.toml",
        "--",
        "--state",
        $stateFullPath,
        "--node-dir",
        $nodeFullDir,
        "faucet",
        "--account",
        $account,
        "--amount",
        "100",
        "--reason",
        "live-service-tester-network-e2e",
        "--authorized-by",
        $signer
    )
    foreach ($txId in @($fund.queued)) {
        $fundingTxIds += "$txId"
    }
}

foreach ($account in $accounts) {
    [void] (Wait-LocalBalanceAtLeast -AccountId $account -Amount 100)
}

$sendResults = @()
foreach ($transfer in $transfers) {
    $send = Invoke-LocalJson -Path "/wallets/send" -Method "POST" -Body ([ordered]@{
        fromAccountId = $transfer.from
        toAccountId = $transfer.to
        amountUnits = "$($transfer.amount)"
        memo = "live-service-tester-network-e2e"
        applyBlock = $false
        createRecipient = $false
    })
    if ($send.accepted -ne $true -or $send.status -ne "queued_local_runtime") {
        throw "Tester transfer did not queue against live runtime. From: $($transfer.from) To: $($transfer.to) Status: $($send.status)"
    }
    $sendResults += [ordered]@{
        from = $transfer.from
        to = $transfer.to
        amount = "$($transfer.amount)"
        transferId = $send.transferId
        txIds = $send.txIds
        status = $send.status
    }
}

$balancesAfter = [ordered]@{}
foreach ($account in $accounts) {
    $balance = Wait-LocalBalanceEquals -AccountId $account -Amount ([int64] $expectedBalances[$account])
    $balancesAfter[$account] = $balance.amount
}

$historyCounts = [ordered]@{}
foreach ($account in $accounts) {
    $history = Invoke-LocalRpc -Method "wallet_transfer_history" -Params @{ walletAddress = $account; limit = 25 }
    $historyCounts[$account] = $history.count
}

$packetWalletBalances = Invoke-LocalJson -Path "/wallets/balances"
$packetWalletTransfers = Invoke-LocalJson -Path "/wallets/transfers"
$chainAfter = Invoke-LocalJson -Path "/chain/status"
$chainAfterBlock = Get-ChainBlockValue -Status $chainAfter
$chainBeforeBlock = Get-ChainBlockValue -Status $chainBefore
if ($chainBeforeBlock -match '^\d+$' -and $chainAfterBlock -match '^\d+$' -and ([int64] $chainAfterBlock) -le ([int64] $chainBeforeBlock)) {
    throw "Chain did not advance during tester network E2E. Before: $chainBeforeBlock After: $chainAfterBlock"
}

$packetSmokeChecks = [ordered]@{
    health = $health.schema -eq "flowmemory.control_plane.health.v0"
    rpcDiscover = $discover.schema -eq "flowchain.rpc.discovery.v0"
    rpcReadiness = $readiness.schema -eq "flowchain.rpc.readiness.v0"
    chainStatus = $chainAfter.schema -eq "flowmemory.control_plane.chain_status.v0"
    walletCreate = @($walletCreates | Where-Object { $_.schema -eq "flowmemory.control_plane.local_wallet_create_result.v0" -and $_.secretMaterialReturned -eq $false }).Count -eq $walletCreates.Count
    walletBalances = $packetWalletBalances.schema -eq "flowmemory.control_plane.wallet_balance_list.v0"
    walletSend = $sendResults.Count -eq $transfers.Count
    walletTransfers = $packetWalletTransfers.schema -eq "flowmemory.control_plane.wallet_transfer_history.v0"
}
$packetSmokeRoutes = @("/health", "/rpc/discover", "/rpc/readiness", "/chain/status", "/wallets/create", "/wallets/balances", "/wallets/send", "/wallets/transfers")
$packetExecutableSmokeValidated = @($packetSmokeChecks.GetEnumerator() | Where-Object { $_.Value -ne $true }).Count -eq 0
if (-not $packetExecutableSmokeValidated) {
    $failedChecks = @($packetSmokeChecks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Name })
    throw "External tester packet smoke did not validate: $($failedChecks -join ', ')"
}

$report = [ordered]@{
    schema = "flowchain.live_service_tester_network_e2e_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "passed"
    rpcEndpoint = "local-private-127.0.0.1"
    runId = $runId
    serviceHealthSchema = $health.schema
    rpcDiscoverSchema = $discover.schema
    rpcReadinessSchema = $readiness.schema
    chainBeforeBlock = $chainBeforeBlock
    chainAfterBlock = $chainAfterBlock
    testerCount = $accounts.Count
    testerAccountIds = $accounts
    testerWalletCreates = $walletCreates
    fundingTxIds = $fundingTxIds
    transferResults = $sendResults
    expectedBalances = $expectedBalances
    balancesAfter = $balancesAfter
    transferHistoryCounts = $historyCounts
    packetExecutableSmokeValidated = $packetExecutableSmokeValidated
    packetSmokeChecks = $packetSmokeChecks
    packetSmokeRoutes = $packetSmokeRoutes
    localOnly = $true
    productionReady = $false
    noLiveBroadcast = $true
    envValuesPrinted = $false
    noSecrets = $true
}

$reportText = $report | ConvertTo-Json -Depth 20
Assert-FlowChainNoSecretText -Text $reportText -Label "live service tester network E2E report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20

Write-Host "FlowChain live service tester network E2E passed."
Write-Host "Tester accounts: $($accounts.Count)"
Write-Host "Chain blocks: $chainBeforeBlock -> $chainAfterBlock"
Write-Host "Report: $reportFullPath"
