param(
    [Parameter(Mandatory = $true)]
    [string] $BundlePath,

    [string] $StatePath = "devnet/local/state.json",
    [string] $ImportDir = "devnet/local/imported",
    [switch] $Force
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot | Out-Null
$bundleFullPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path $BundlePath
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$importFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ImportDir)

if (-not (Test-Path -LiteralPath $bundleFullPath)) {
    throw "Import bundle does not exist: $bundleFullPath"
}

if ((Test-Path -LiteralPath $stateFullPath) -and -not $Force) {
    throw "State file already exists. Rerun with -Force to replace it from the import bundle."
}

if (Test-Path -LiteralPath $importFullPath) {
    Remove-Item -LiteralPath $importFullPath -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $importFullPath | Out-Null

Expand-Archive -LiteralPath $bundleFullPath -DestinationPath $importFullPath -Force
$importedState = Join-Path $importFullPath "state.json"
if (-not (Test-Path -LiteralPath $importedState)) {
    throw "Import bundle did not contain state.json."
}

Assert-FlowChainNoSecretFiles -Path $importFullPath
$stateParent = Split-Path -Parent $stateFullPath
New-Item -ItemType Directory -Force -Path $stateParent | Out-Null
Copy-Item -LiteralPath $importedState -Destination $stateFullPath -Force

Invoke-FlowChainCommand -Label "Inspect imported devnet state" -FilePath "cargo" -ArgumentList @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $stateFullPath,
    "inspect-state",
    "--summary"
)

Write-Host ""
Write-Host "FlowChain local state import complete."
Write-Host "State: $stateFullPath"
Write-Host "Next command: npm run flowchain:start"
