param(
    [string] $OutDir = "devnet/local/production-l1-e2e/dex",
    [string] $StatePath = "devnet/local/production-l1-e2e/dex/state.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot -Purpose "dex-e2e" | Out-Null
$outFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $OutDir)
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$exportDir = Join-Path $outFullDir "export"
$reportPath = Join-Path $outFullDir "dex-e2e-report.json"

if (Test-Path -LiteralPath $outFullDir) {
    Remove-Item -LiteralPath $outFullDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $outFullDir | Out-Null

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $productOutput = (& cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $stateFullPath product-smoke --out-dir $exportDir 2>&1) | ForEach-Object { "$_" }
    $productExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
if ($productExitCode -ne 0) {
    throw "Runtime product-smoke failed: $($productOutput -join [Environment]::NewLine)"
}
$text = $productOutput -join [Environment]::NewLine
$jsonStart = $text.IndexOf("{")
$jsonEnd = $text.LastIndexOf("}")
if ($jsonStart -lt 0 -or $jsonEnd -lt $jsonStart) {
    throw "Runtime product-smoke did not emit JSON output."
}
$productSmoke = $text.Substring($jsonStart, $jsonEnd - $jsonStart + 1) | ConvertFrom-Json

$required = @(
    "tokenLaunched",
    "poolCreated",
    "liquidityAdded",
    "swapExecuted",
    "liquidityRemoved",
    "productReceiptsQueryable",
    "noValueBoundary"
)
foreach ($name in $required) {
    if (-not [bool] $productSmoke.checks.$name) {
        throw "DEX/product check failed: $name"
    }
}

$report = [ordered]@{
    schema = "flowchain.dex_e2e_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "passed"
    statePath = $stateFullPath
    exportDir = $exportDir
    tokenStatus = "passed"
    dexStatus = "passed"
    checks = $productSmoke.checks
    stateRoot = $productSmoke.stateRoot
    noValueBoundary = "local product testnet records only; no tokenomics or real value"
}
Write-FlowChainJson -Path $reportPath -Value $report -Depth 16
Assert-FlowChainNoSecretFiles -Path $outFullDir

Write-Host "FlowChain token/DEX E2E passed."
Write-Host "State root: $($productSmoke.stateRoot)"
Write-Host "Report: $reportPath"
