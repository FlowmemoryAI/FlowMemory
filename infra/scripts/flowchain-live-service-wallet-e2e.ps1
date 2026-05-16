param(
    [string] $RpcUrl = "http://127.0.0.1:8787",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/live-service-wallet-e2e-report.json",
    [int] $PollSeconds = 45
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot -Purpose "live-service-wallet-e2e" | Out-Null
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

function New-LocalSignedEnvelope {
    param(
        [Parameter(Mandatory = $true)][object] $Tx,
        [Parameter(Mandatory = $true)][string] $Signer,
        [Parameter(Mandatory = $true)][string] $RunId
    )

    return [ordered]@{
        schema = "flowchain.live_service_wallet_e2e.signed_envelope.v0"
        tx = $Tx
        signature = [ordered]@{
            scheme = "local-live-service-e2e-placeholder"
            signer = $Signer
            digest = "live-service-wallet-e2e-$RunId"
        }
    }
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
    throw "Live service wallet E2E requires running local service. Status output: $serviceStatus"
}

$runId = ((Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmssfff") + "-$PID")
$sender = "local-account:live-service-wallet:${runId}:sender"
$recipient = "local-account:live-service-wallet:${runId}:recipient"
$signer = "operator:live-service-wallet-e2e"

$health = Invoke-LocalJson -Path "/health"
$chainBefore = Invoke-LocalJson -Path "/chain/status"

$fundSender = Invoke-CargoJson -ArgumentList @(
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
    $sender,
    "--amount",
    "100",
    "--reason",
    "live-service-wallet-e2e",
    "--authorized-by",
    $signer
)

$senderFunded = Wait-LocalBalanceAtLeast -AccountId $sender -Amount 100

$send = Invoke-LocalJson -Path "/wallets/send" -Method "POST" -Body ([ordered]@{
    fromAccountId = $sender
    toAccountId = $recipient
    amountUnits = "25"
    memo = "live-service-wallet-e2e"
    applyBlock = $false
    createRecipient = $true
})
if ($send.accepted -ne $true -or $send.status -ne "queued_local_runtime") {
    throw "Wallet send did not queue against live runtime. Status: $($send.status)"
}

$senderAfter = Wait-LocalBalanceEquals -AccountId $sender -Amount 75
$recipientAfter = Wait-LocalBalanceEquals -AccountId $recipient -Amount 25

$chainAfter = Invoke-LocalJson -Path "/chain/status"
$transferHistory = Invoke-LocalRpc -Method "wallet_transfer_history" -Params @{ walletAddress = $sender; limit = 25 }

$report = [ordered]@{
    schema = "flowchain.live_service_wallet_e2e_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "passed"
    rpcEndpoint = "local-private-127.0.0.1"
    runId = $runId
    serviceHealthSchema = $health.schema
    chainBeforeBlock = Get-ChainBlockValue -Status $chainBefore
    chainAfterBlock = Get-ChainBlockValue -Status $chainAfter
    senderAccountId = $sender
    recipientAccountId = $recipient
    fundSenderTxIds = $fundSender.queued
    sendTxIds = $send.txIds
    sendStatus = $send.status
    transferId = $send.transferId
    balances = [ordered]@{
        senderFunded = $senderFunded.amount
        senderAfter = $senderAfter.amount
        recipientAfter = $recipientAfter.amount
    }
    transferHistoryCount = $transferHistory.count
    localOnly = $true
    productionReady = $false
    noLiveBroadcast = $true
    envValuesPrinted = $false
    noSecrets = $true
}

$reportText = $report | ConvertTo-Json -Depth 16
Assert-FlowChainNoSecretText -Text $reportText -Label "live service wallet E2E report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

Write-Host "FlowChain live service wallet E2E passed."
Write-Host "Sender after: $($senderAfter.amount)"
Write-Host "Recipient after: $($recipientAfter.amount)"
Write-Host "Report: $reportFullPath"
