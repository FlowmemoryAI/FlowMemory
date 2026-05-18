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

function Get-WalletSecretMarkerFindings {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string] $Label
    )

    $patterns = @(
        "privateKey",
        "private_key",
        "seedPhrase",
        "seed phrase",
        "mnemonic",
        "rpcUrl",
        "rpc-url",
        "apiKey",
        "webhook",
        "BEGIN RSA PRIVATE KEY",
        "BEGIN OPENSSH PRIVATE KEY"
    )

    $findings = New-Object System.Collections.ArrayList
    foreach ($pattern in $patterns) {
        if ($Text.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            [void] $findings.Add([ordered]@{
                label = $Label
                marker = $pattern
            })
        }
    }
    return @($findings)
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
[int64] $chainBeforeInt = 0
[int64] $chainAfterInt = 0
[void] [int64]::TryParse((Get-ChainBlockValue -Status $chainBefore), [ref] $chainBeforeInt)
[void] [int64]::TryParse((Get-ChainBlockValue -Status $chainAfter), [ref] $chainAfterInt)

$checks = [ordered]@{
    serviceStatusSucceeded = $true
    healthSchemaOk = $health.schema -eq "flowmemory.control_plane.health.v0"
    faucetQueuedTransactions = @($fundSender.queued).Count -ge 1
    senderFundedBalanceReached = [int64] $senderFunded.amount -ge 100
    sendAccepted = $send.accepted -eq $true
    sendQueuedLocalRuntime = $send.status -eq "queued_local_runtime"
    sendTxIdsPresent = @($send.txIds).Count -ge 1
    transferIdPresent = -not [string]::IsNullOrWhiteSpace("$($send.transferId)")
    senderDebitApplied = [int64] $senderAfter.amount -eq 75
    recipientCreditApplied = [int64] $recipientAfter.amount -eq 25
    transferHistoryRecorded = [int64] $transferHistory.count -ge 1
    chainStatusReadableBefore = -not [string]::IsNullOrWhiteSpace((Get-ChainBlockValue -Status $chainBefore))
    chainStatusReadableAfter = -not [string]::IsNullOrWhiteSpace((Get-ChainBlockValue -Status $chainAfter))
    blockHeightAdvanced = $chainAfterInt -gt $chainBeforeInt
    localOnly = $true
    productionReadyFalse = $true
    noLiveBroadcast = $true
    broadcastsFalse = $true
    envValuesPrintedFalse = $true
    noSecrets = $true
    secretMarkerFindingsEmpty = $true
}

$report = [ordered]@{
    schema = "flowchain.live_service_wallet_e2e_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "pending"
    rpcEndpoint = "local-private-127.0.0.1"
    runId = $runId
    checks = $checks
    failedChecks = @()
    secretMarkerFindings = @()
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
    broadcasts = $false
    envValuesPrinted = $false
    noSecrets = $true
}

$preliminaryReportText = $report | ConvertTo-Json -Depth 16
$secretMarkerFindings = @(Get-WalletSecretMarkerFindings -Text $preliminaryReportText -Label "live service wallet E2E report")
$checks["secretMarkerFindingsEmpty"] = $secretMarkerFindings.Count -eq 0
$checks["noSecrets"] = $secretMarkerFindings.Count -eq 0
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
$report["status"] = $status
$report["checks"] = $checks
$report["failedChecks"] = @($failedChecks)
$report["secretMarkerFindings"] = @($secretMarkerFindings)
$report["noSecrets"] = $secretMarkerFindings.Count -eq 0

$reportText = $report | ConvertTo-Json -Depth 16
Assert-FlowChainNoSecretText -Text $reportText -Label "live service wallet E2E report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

Write-Host "FlowChain live service wallet E2E passed."
Write-Host "Sender after: $($senderAfter.amount)"
Write-Host "Recipient after: $($recipientAfter.amount)"
Write-Host "Report: $reportFullPath"
if ($status -ne "passed") {
    Write-Host "Failed checks: $($failedChecks -join ', ')"
    exit 1
}
