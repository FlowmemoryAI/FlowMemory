param(
    [string] $SmokeDir = "devnet/local/multi-node-smoke"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$smokeFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $SmokeDir)

& "$PSScriptRoot\flowchain-network-e2e.ps1" -OutDir $SmokeDir -ReportName "multi-node-smoke-report.json"
if ($LASTEXITCODE -ne 0) {
    throw "FlowChain multi-node smoke failed with exit code $LASTEXITCODE."
}

$reportPath = Join-Path $smokeFullDir "multi-node-smoke-report.json"
if (-not (Test-Path -LiteralPath $reportPath)) {
    throw "Expected multi-node smoke report was not written: $reportPath"
}

Write-Host ""
Write-Host "FlowChain multi-node smoke passed."
Write-Host "Report: $reportPath"
