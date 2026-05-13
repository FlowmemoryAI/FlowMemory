param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $OutDir = "devnet/local/handoff/generated",
    [switch] $SkipLaunchCore
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot | Out-Null
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$outFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $OutDir)

if (-not $SkipLaunchCore) {
    Invoke-FlowChainCommand -Label "Generate launch-core fixtures" -FilePath "npm" -ArgumentList @("run", "launch:v0")
}

Invoke-FlowChainCommand -Label "Run deterministic FlowChain local demo" -FilePath "cargo" -ArgumentList @(
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

Assert-FlowChainNoSecretFiles -Path $outFullPath

Write-Host ""
Write-Host "FlowChain local demo complete."
Write-Host "State: $stateFullPath"
Write-Host "Handoff export: $outFullPath"
Write-Host "Next command: npm run flowchain:export"
