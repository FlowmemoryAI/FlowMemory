param(
    [string] $Path = "devnet/local/live-l1-bridge-intake"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$fullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $Path)

Assert-FlowChainNoSecretFiles -Path $fullPath

$report = [ordered]@{
    schema = "flowchain.no_secret_scan.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    path = $fullPath
    passed = $true
}

if ((Get-Item -LiteralPath $fullPath).PSIsContainer) {
    Write-FlowChainJson -Path (Join-Path $fullPath "no-secret-scan-report.json") -Value $report -Depth 8
}

$report | ConvertTo-Json -Depth 8
