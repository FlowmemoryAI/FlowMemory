param(
    [string] $ReportPath = "devnet/local/emergency/flowchain-emergency-recovery-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)

$steps = @(
    "npm run flowchain:emergency:export-evidence",
    "npm run flowchain:doctor",
    "npm run flowchain:init",
    "npm run flowchain:node:start",
    "npm run flowchain:node:status",
    "npm run control-plane:serve",
    "npm run workbench:dev",
    "npm run flowchain:bridge:live:check"
)

$report = [ordered]@{
    schema = "flowchain.emergency_recovery_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "printed"
    steps = $steps
    emergencyStopCommands = @(
        "npm run flowchain:emergency:stop-local",
        "npm run flowchain:bridge:emergency-stop",
        "npm run flowchain:emergency:pause-bridge",
        "npm run flowchain:emergency:export-evidence"
    )
}
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 10

Write-Host "FlowChain recovery steps:"
foreach ($step in $steps) {
    Write-Host "- $step"
}
Write-Host "Report: $reportFullPath"

