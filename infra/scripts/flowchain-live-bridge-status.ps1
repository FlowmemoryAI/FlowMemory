param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node",
    [string] $OutDir = "devnet/local/live-l1-bridge-intake"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string] $Path)
    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Get-ObjectPropertyCount {
    param([object] $Value)
    if ($null -eq $Value -or $null -eq $Value.PSObject) {
        return 0
    }
    return @($Value.PSObject.Properties).Count
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
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$nodeFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $NodeDir)
$outFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $OutDir)
New-Item -ItemType Directory -Force -Path $outFullDir | Out-Null

$statusPath = Join-Path $nodeFullDir "status.json"
if (-not (Test-Path -LiteralPath $statusPath)) {
    throw "Node status is missing."
}
if (-not (Test-Path -LiteralPath $stateFullPath)) {
    throw "State file is missing."
}

$status = Read-JsonFile -Path $statusPath
$state = Read-JsonFile -Path $stateFullPath
$credit = Get-FirstPropertyValue -Value $state.bridgeCredits
if ($null -eq $credit) {
    throw "No bridge credits exist in state."
}
$receipt = $state.bridgeCreditReceipts.PSObject.Properties[$credit.creditId].Value
$balance = $state.localTestUnitBalances.PSObject.Properties[$credit.recipientAccountId].Value
$transferReportPath = Join-Path $outFullDir "wallet-transfer-report.json"
$restartReportPath = Join-Path $outFullDir "restart-verify-report.json"
$ingestReportPath = Join-Path $outFullDir "bridge-ingest-report.json"
$transferReport = if (Test-Path -LiteralPath $transferReportPath) { Read-JsonFile -Path $transferReportPath } else { $null }
$restartReport = if (Test-Path -LiteralPath $restartReportPath) { Read-JsonFile -Path $restartReportPath } else { $null }
$ingestReport = if (Test-Path -LiteralPath $ingestReportPath) { Read-JsonFile -Path $ingestReportPath } else { $null }

$checks = [ordered]@{
    nodeRunning = ($status.status -eq "running")
    bridgeCreditsPositive = ((Get-ObjectPropertyCount -Value $state.bridgeCredits) -gt 0)
    bridgeCreditReceiptsPositive = ((Get-ObjectPropertyCount -Value $state.bridgeCreditReceipts) -gt 0)
    bridgeReplayKeysPositive = ((Get-ObjectPropertyCount -Value $state.bridgeReplayKeys) -gt 0)
    creditedBalanceExists = ($null -ne $balance -and [UInt64] $balance.units -gt 0)
    creditedBalanceTransferred = ($null -ne $transferReport -and $transferReport.passed -eq $true)
    exportImportPreserved = ($null -ne $restartReport -and $restartReport.exportImportPreserved -eq $true)
    liveHandoffApplied = ($credit.productionReady -eq $true -and $credit.localOnly -eq $false)
}

foreach ($entry in $checks.GetEnumerator()) {
    if (-not $entry.Value) {
        throw "Live bridge status check failed: $($entry.Key)"
    }
}

$report = [ordered]@{
    schema = "flowchain.live_l1.bridge_status_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    statePath = $stateFullPath
    nodeDir = $nodeFullDir
    checks = $checks
    node = [ordered]@{
        status = $status.status
        nodeId = $status.nodeId
        pid = $status.pid
        latestHeight = $status.latestHeight
        stateRoot = $status.stateRoot
    }
    bridge = [ordered]@{
        bridgeCredits = Get-ObjectPropertyCount -Value $state.bridgeCredits
        bridgeCreditReceipts = Get-ObjectPropertyCount -Value $state.bridgeCreditReceipts
        bridgeReplayKeys = Get-ObjectPropertyCount -Value $state.bridgeReplayKeys
        creditId = $credit.creditId
        receiptId = $receipt.receiptId
        creditedAccount = $credit.recipientAccountId
        creditedBalance = $balance.units
        latency = if ($null -ne $ingestReport) { $ingestReport.latency } else { $receipt.latency }
    }
    transfer = $transferReport
    restart = $restartReport
    passed = $true
}

$reportPath = Join-Path $outFullDir "LIVE_NODE_BRIDGE_INTAKE_STATUS.json"
Write-FlowChainJson -Path $reportPath -Value $report -Depth 24
$report | ConvertTo-Json -Depth 24
