param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node",
    [string] $OutDir = "devnet/local/live-l1-bridge-intake",
    [string] $ToAccount = "local-account:bridge:live-transfer-receiver",
    [UInt64] $AmountUnits = 1,
    [int] $TimeoutSeconds = 60
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string] $Path)
    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Get-FirstPropertyValue {
    param([object] $Value)
    $properties = @($Value.PSObject.Properties)
    if ($properties.Count -lt 1) {
        return $null
    }
    return $properties[0].Value
}

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot -Purpose "wallet-transfer-e2e" | Out-Null
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$nodeFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $NodeDir)
$outFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $OutDir)
New-Item -ItemType Directory -Force -Path $outFullDir | Out-Null

$statusPath = Join-Path $nodeFullDir "status.json"
if (-not (Test-Path -LiteralPath $statusPath)) {
    throw "Node status is missing. Start the node before running transfer e2e."
}
$status = Read-JsonFile -Path $statusPath
if ($status.status -ne "running") {
    throw "Node is not running; status is '$($status.status)'."
}
if (-not (Test-Path -LiteralPath $stateFullPath)) {
    throw "State file is missing: $stateFullPath"
}

$state = Read-JsonFile -Path $stateFullPath
$credit = Get-FirstPropertyValue -Value $state.bridgeCredits
if ($null -eq $credit) {
    throw "No bridge credit exists in runtime state."
}
$fromAccount = [string] $credit.recipientAccountId
$fromBalance = $state.localTestUnitBalances.PSObject.Properties[$fromAccount].Value
if ($null -eq $fromBalance -or [UInt64] $fromBalance.units -lt $AmountUnits) {
    throw "Credited account $fromAccount does not have enough spendable units."
}
$beforeReceiver = $state.localTestUnitBalances.PSObject.Properties[$ToAccount].Value
$beforeReceiverUnits = if ($null -eq $beforeReceiver) { [UInt64] 0 } else { [UInt64] $beforeReceiver.units }

$transferId = "transfer:bridge:live:" + ([Guid]::NewGuid().ToString("N"))
$txs = New-Object System.Collections.Generic.List[object]
if ($null -eq $beforeReceiver) {
    $txs.Add([ordered]@{
        type = "CreateLocalTestUnitBalance"
        accountId = $ToAccount
        owner = "operator:bridge:live-transfer"
    }) | Out-Null
}
$txs.Add([ordered]@{
    type = "TransferLocalTestUnits"
    transferId = $transferId
    fromAccountId = $fromAccount
    toAccountId = $ToAccount
    amountUnits = $AmountUnits
    memo = "live-bridge-credit-spend-proof"
}) | Out-Null

$txPath = Join-Path $outFullDir "wallet-transfer-tx.json"
Write-FlowChainJson -Path $txPath -Value ([ordered]@{
    schema = "flowmemory.local_devnet.wallet_transfer_e2e.v0"
    txs = @($txs)
})

$submitOutput = (& cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $stateFullPath --node-dir $nodeFullDir submit-tx --tx-file $txPath --authorized-by operator:bridge:live-transfer 2>&1) -join [Environment]::NewLine
if ($LASTEXITCODE -ne 0) {
    throw "Transfer submit failed.`n$submitOutput"
}
$jsonStart = $submitOutput.IndexOf("{")
$jsonEnd = $submitOutput.LastIndexOf("}")
$submit = $submitOutput.Substring($jsonStart, $jsonEnd - $jsonStart + 1) | ConvertFrom-Json
if (@($submit.queued).Count -lt 1) {
    throw "Transfer submit did not queue transactions."
}

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$afterState = $null
while ((Get-Date) -lt $deadline) {
    try {
        $candidate = Read-JsonFile -Path $stateFullPath
        $transferRecord = $candidate.balanceTransfers.PSObject.Properties[$transferId].Value
        $receiver = $candidate.localTestUnitBalances.PSObject.Properties[$ToAccount].Value
        if ($null -ne $transferRecord -and $null -ne $receiver -and [UInt64] $receiver.units -ge ($beforeReceiverUnits + $AmountUnits)) {
            $afterState = $candidate
            break
        }
    }
    catch {
    }
    Start-Sleep -Milliseconds 500
}

if ($null -eq $afterState) {
    throw "Timed out waiting for credited-account transfer to be included."
}

$receiverAfter = $afterState.localTestUnitBalances.PSObject.Properties[$ToAccount].Value
$senderAfter = $afterState.localTestUnitBalances.PSObject.Properties[$fromAccount].Value
$report = [ordered]@{
    schema = "flowchain.live_l1.wallet_transfer_e2e_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    statePath = $stateFullPath
    nodeDir = $nodeFullDir
    creditId = $credit.creditId
    fromAccount = $fromAccount
    toAccount = $ToAccount
    amountUnits = $AmountUnits
    transferId = $transferId
    senderBalanceAfter = $senderAfter.units
    receiverBalanceBefore = $beforeReceiverUnits
    receiverBalanceAfter = $receiverAfter.units
    queued = $submit
    passed = $true
}

Write-FlowChainJson -Path (Join-Path $outFullDir "wallet-transfer-report.json") -Value $report -Depth 20
$report | ConvertTo-Json -Depth 20
