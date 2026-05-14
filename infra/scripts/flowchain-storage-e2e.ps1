param(
    [string] $StatePath = "devnet/local/storage-e2e/state.json",
    [string] $OutDir = "devnet/local/storage-e2e"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot | Out-Null
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$outFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $OutDir)

Invoke-FlowChainCommand -Label "Run FlowChain durable storage E2E" -FilePath "cargo" -ArgumentList @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $stateFullPath,
    "storage-e2e",
    "--out-dir",
    $outFullDir
)

$summaryPath = Join-Path $outFullDir "flowchain-storage-e2e-export.json"
Assert-FlowChainNoSecretFiles -Path $outFullDir

Write-Host ""
Write-Host "FlowChain durable storage E2E passed."
Write-Host "Output directory: $outFullDir"
Write-Host "Export path: $summaryPath"
