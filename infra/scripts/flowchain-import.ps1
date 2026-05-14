param(
    [string] $BundlePath = "devnet/local/export/latest/flowchain-state-export.json",

    [string] $StatePath = "devnet/local/imported/state.json",
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

if (Test-Path -LiteralPath $importFullPath) {
    if (-not $Force -and ($StatePath -ne "devnet/local/imported/state.json")) {
        throw "Import directory already exists. Rerun with -Force or choose a clean -ImportDir."
    }
    Remove-Item -LiteralPath $importFullPath -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $importFullPath | Out-Null

$exportJsonPath = $bundleFullPath
if ([System.IO.Path]::GetExtension($bundleFullPath).Equals(".zip", [System.StringComparison]::OrdinalIgnoreCase)) {
    Expand-Archive -LiteralPath $bundleFullPath -DestinationPath $importFullPath -Force
    $candidate = Join-Path $importFullPath "flowchain-state-export.json"
    if (-not (Test-Path -LiteralPath $candidate)) {
        $candidate = Join-Path $importFullPath "latest/flowchain-state-export.json"
    }
    if (-not (Test-Path -LiteralPath $candidate)) {
        throw "Import bundle did not contain flowchain-state-export.json."
    }
    $exportJsonPath = $candidate
}

Assert-FlowChainNoSecretFiles -Path $importFullPath
Assert-FlowChainNoSecretFiles -Path $exportJsonPath

Invoke-FlowChainCommand -Label "Import durable FlowChain state" -FilePath "cargo" -ArgumentList @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $stateFullPath,
    "import-state",
    "--from",
    $exportJsonPath
)
Assert-FlowChainNoSecretFiles -Path $importFullPath

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

$storageStatusRaw = & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $stateFullPath storage-status
if ($LASTEXITCODE -ne 0) {
    throw "Failed to inspect imported storage status."
}
$storageStatus = $storageStatusRaw | ConvertFrom-Json

Write-Host ""
Write-Host "FlowChain local state import complete."
Write-Host "State: $stateFullPath"
Write-Host "Restore path: $stateFullPath"
Write-Host "Data directory: $($storageStatus.dataDirectory)"
Write-Host "Current height: $($storageStatus.latestHeight)"
Write-Host "Latest hash: $($storageStatus.latestHash)"
Write-Host "Finalized height: $($storageStatus.finalizedHeight)"
Write-Host "State root: $($storageStatus.stateRoot)"
Write-Host "Index health: tx=$($storageStatus.txIndexEntries) receipts=$($storageStatus.receiptIndexEntries) events=$($storageStatus.eventIndexEntries) bridgeCredits=$($storageStatus.bridgeCreditEntries)"
Write-Host "Next command: npm run flowchain:start"
