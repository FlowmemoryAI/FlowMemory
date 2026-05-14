param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node",
    [string] $OutDir = "devnet/local/live-l1-bridge-intake",
    [int] $BlockMs = 1000
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
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot -Purpose "restart-verify" | Out-Null
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$nodeFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $NodeDir)
$outFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $OutDir)
New-Item -ItemType Directory -Force -Path $outFullDir | Out-Null

if (-not (Test-Path -LiteralPath $stateFullPath)) {
    throw "State file is missing: $stateFullPath"
}

$beforeState = Read-JsonFile -Path $stateFullPath
$beforeCredit = Get-FirstPropertyValue -Value $beforeState.bridgeCredits
if ($null -eq $beforeCredit) {
    throw "No bridge credit exists before restart verification."
}
$beforeBalance = $beforeState.localTestUnitBalances.PSObject.Properties[$beforeCredit.recipientAccountId].Value
if ($null -eq $beforeBalance) {
    throw "Credited account balance is missing before restart verification."
}

& cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $stateFullPath --node-dir $nodeFullDir node-stop | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "node-stop failed."
}
Start-Sleep -Seconds 2

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-node-start.ps1") -StatePath $stateFullPath -NodeDir $nodeFullDir -BlockMs $BlockMs -OutDir $outFullDir | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "node restart start failed."
}

$status = Read-JsonFile -Path (Join-Path $nodeFullDir "status.json")
if ($status.status -ne "running") {
    throw "Node did not report running after restart."
}

$snapshotPath = Join-Path $outFullDir "restart-state-snapshot.json"
$importedStatePath = Join-Path $outFullDir "restart-imported-state.json"
& cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $stateFullPath export-state --out $snapshotPath | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "export-state failed during restart verification."
}
& cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $importedStatePath import-state --from $snapshotPath | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "import-state failed during restart verification."
}

$afterState = Read-JsonFile -Path $stateFullPath
$importedState = Read-JsonFile -Path $importedStatePath
$afterCredit = $afterState.bridgeCredits.PSObject.Properties[$beforeCredit.creditId].Value
$afterReceipt = $afterState.bridgeCreditReceipts.PSObject.Properties[$beforeCredit.creditId].Value
$afterReplayCount = Get-ObjectPropertyCount -Value $afterState.bridgeReplayKeys
$afterBalance = $afterState.localTestUnitBalances.PSObject.Properties[$beforeCredit.recipientAccountId].Value

if ($null -eq $afterCredit -or $null -eq $afterReceipt -or $afterReplayCount -lt 1 -or $null -eq $afterBalance) {
    throw "Bridge credit, receipt, replay index, or balance was not preserved after restart."
}
if ($importedState.bridgeCredits.PSObject.Properties[$beforeCredit.creditId].Value.creditId -ne $beforeCredit.creditId) {
    throw "Imported state did not preserve bridge credit."
}
if ($importedState.bridgeCreditReceipts.PSObject.Properties[$beforeCredit.creditId].Value.receiptId -ne $beforeCredit.creditId) {
    throw "Imported state did not preserve bridge credit receipt."
}
if ($importedState.localTestUnitBalances.PSObject.Properties[$beforeCredit.recipientAccountId].Value.units -ne $afterBalance.units) {
    throw "Imported state did not preserve credited balance."
}

$report = [ordered]@{
    schema = "flowchain.live_l1.restart_verify_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    statePath = $stateFullPath
    nodeDir = $nodeFullDir
    status = $status
    creditId = $beforeCredit.creditId
    creditedAccount = $beforeCredit.recipientAccountId
    bridgeCredits = Get-ObjectPropertyCount -Value $afterState.bridgeCredits
    bridgeCreditReceipts = Get-ObjectPropertyCount -Value $afterState.bridgeCreditReceipts
    bridgeReplayKeys = $afterReplayCount
    creditedBalance = $afterBalance.units
    exportImportPreserved = $true
    snapshotPath = $snapshotPath
    importedStatePath = $importedStatePath
    passed = $true
}

Write-FlowChainJson -Path (Join-Path $outFullDir "restart-verify-report.json") -Value $report -Depth 20
$report | ConvertTo-Json -Depth 20
