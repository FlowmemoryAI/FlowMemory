param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $OutDir = "devnet/local/export/latest",
    [string] $ExportPath = "devnet/local/export/latest/flowchain-state-export.json",
    [string] $BundlePath = "devnet/local/export/flowchain-local-state.zip",
    [switch] $NoZip
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot | Out-Null
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$outFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $OutDir)
$exportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ExportPath)
$bundleFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $BundlePath)

if (-not (Test-Path -LiteralPath $stateFullPath)) {
    Invoke-FlowChainCommand -Label "Create deterministic devnet state for export" -FilePath "cargo" -ArgumentList @(
        "run",
        "--manifest-path",
        "crates/flowmemory-devnet/Cargo.toml",
        "--",
        "--state",
        $stateFullPath,
        "demo",
        "--out-dir",
        $outFullPath
    )
}

Invoke-FlowChainCommand -Label "Export devnet handoff fixtures" -FilePath "cargo" -ArgumentList @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $stateFullPath,
    "export-fixtures",
    "--out-dir",
    $outFullPath
)

Invoke-FlowChainCommand -Label "Export durable FlowChain state" -FilePath "cargo" -ArgumentList @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $stateFullPath,
    "export-state",
    "--out",
    $exportFullPath
)

$storageStatusRaw = & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $stateFullPath storage-status
if ($LASTEXITCODE -ne 0) {
    throw "Failed to inspect durable storage status."
}
$storageStatus = $storageStatusRaw | ConvertFrom-Json
$exportJson = Get-Content -Raw -LiteralPath $exportFullPath | ConvertFrom-Json

$manifestPath = Join-Path $outFullPath "export-manifest.json"
$manifest = [ordered]@{
    schema = "flowchain.private_testnet.export_manifest.v0"
    storageExportSchema = $exportJson.schema
    sourceStatePath = $stateFullPath
    outDir = $outFullPath
    exportPath = $exportFullPath
    dataDirectory = $storageStatus.dataDirectory
    latestHeight = $storageStatus.latestHeight
    latestHash = $storageStatus.latestHash
    finalizedHeight = $storageStatus.finalizedHeight
    finalizedHash = $storageStatus.finalizedHash
    stateRoot = $storageStatus.stateRoot
    indexHealth = [ordered]@{
        tx = $storageStatus.txIndexEntries
        receipts = $storageStatus.receiptIndexEntries
        events = $storageStatus.eventIndexEntries
        accounts = $storageStatus.accountIndexEntries
        tokens = $storageStatus.tokenIndexEntries
        pools = $storageStatus.poolIndexEntries
        bridgeObservations = $storageStatus.bridgeObservationEntries
        bridgeCredits = $storageStatus.bridgeCreditEntries
        withdrawalIntents = $storageStatus.withdrawalIntentEntries
        releaseEvidence = $storageStatus.releaseEvidenceEntries
        replayKeys = $storageStatus.replayKeyEntries
    }
    operatorSigningSecretsIncluded = $false
    files = @(
        "flowchain-state-export.json",
        "dashboard-state.json",
        "indexer-handoff.json",
        "verifier-handoff.json",
        "control-plane-handoff.json",
        "genesis-config.json",
        "operator-key-references.json",
        "state.json",
        "export-manifest.json"
    )
}
Write-FlowChainJson -Path $manifestPath -Value $manifest
Assert-FlowChainNoSecretFiles -Path $outFullPath
Assert-FlowChainNoSecretFiles -Path $exportFullPath

if (-not $NoZip) {
    $bundleParent = Split-Path -Parent $bundleFullPath
    New-Item -ItemType Directory -Force -Path $bundleParent | Out-Null
    if (Test-Path -LiteralPath $bundleFullPath) {
        Remove-Item -LiteralPath $bundleFullPath -Force
    }
    Compress-Archive -Path (Join-Path $outFullPath "*") -DestinationPath $bundleFullPath -Force
    Write-Host "Bundle: $bundleFullPath"
}

Write-Host ""
Write-Host "FlowChain local state export complete."
Write-Host "Export directory: $outFullPath"
Write-Host "Data directory: $($storageStatus.dataDirectory)"
Write-Host "Current height: $($storageStatus.latestHeight)"
Write-Host "Latest hash: $($storageStatus.latestHash)"
Write-Host "Finalized height: $($storageStatus.finalizedHeight)"
Write-Host "State root: $($storageStatus.stateRoot)"
Write-Host "Export path: $exportFullPath"
Write-Host "Index health: tx=$($storageStatus.txIndexEntries) receipts=$($storageStatus.receiptIndexEntries) events=$($storageStatus.eventIndexEntries) bridgeCredits=$($storageStatus.bridgeCreditEntries)"
