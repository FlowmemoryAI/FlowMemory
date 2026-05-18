param(
    [string]$ReportPath = "devnet/local/bridge-live-readiness/bridge-command-matrix-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$package = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "package.json") | ConvertFrom-Json
$scripts = $package.scripts

$requiredScripts = @(
    "flowchain:bridge:live:check",
    "flowchain:bridge:deploy:base8453",
    "flowchain:bridge:observe:base8453",
    "flowchain:bridge:pause",
    "flowchain:bridge:resume",
    "flowchain:bridge:withdraw:intent",
    "flowchain:bridge:release:evidence",
    "flowchain:bridge:local-credit:smoke",
    "flowchain:bridge:command-matrix",
    "flowchain:bridge:no-secret-audit"
)

$rows = foreach ($name in $requiredScripts) {
    $exists = $scripts.PSObject.Properties.Name -contains $name
    [ordered]@{
        script = $name
        exists = $exists
        commandPresent = $exists
    }
}
$missing = @($rows | Where-Object { -not $_.exists } | ForEach-Object { $_.script })
$status = if ($missing.Count -eq 0) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.bridge_command_matrix_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    requiredScripts = $requiredScripts
    rows = @($rows)
    missingScripts = $missing
    broadcasts = $false
    printsEnvValues = $false
    noSecrets = $true
}

Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 12
Write-Host "Bridge command matrix status: $status"
Write-Host "Report: $reportFullPath"
if ($missing.Count -gt 0) {
    throw "Missing bridge root scripts: $($missing -join ', ')"
}
