param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $OutDir = "devnet/local/export/latest",
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
$bundleFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $BundlePath)

if (-not (Test-Path -LiteralPath $stateFullPath)) {
    throw "State file does not exist. Run npm run flowchain:init or npm run flowchain:demo first."
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

$dashboardPath = Join-Path $outFullPath "dashboard-state.json"
$exportedStatePath = Join-Path $outFullPath "state.json"
$dashboardState = Get-Content -Raw -LiteralPath $dashboardPath | ConvertFrom-Json
$manifestPath = Join-Path $outFullPath "export-manifest.json"
$manifest = [ordered]@{
    schema = "flowchain.private_testnet.export_manifest.v0"
    exportedAt = (Get-Date).ToUniversalTime().ToString("o")
    sourceStatePath = $stateFullPath
    outDir = $outFullPath
    statePath = $exportedStatePath
    stateRoot = $dashboardState.stateRoot
    mapRoots = $dashboardState.mapRoots
    includesPrivateOperatorKey = $false
    files = @(
        "dashboard-state.json",
        "indexer-handoff.json",
        "verifier-handoff.json",
        "control-plane-handoff.json",
        "genesis-config.json",
        "operator-key-references.json",
        "state.json"
    )
}
Write-FlowChainJson -Path $manifestPath -Value $manifest -Depth 24
Assert-FlowChainNoSecretFiles -Path $outFullPath

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
