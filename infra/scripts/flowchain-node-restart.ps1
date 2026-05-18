param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node",
    [int] $BlockMs = 1000,
    [int] $MaxBlocks = 0,
    [switch] $Wait
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/node/flowchain-node-restart-report.json")
$startedAt = (Get-Date).ToUniversalTime().ToString("o")

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-node-stop.ps1") -StatePath $StatePath -NodeDir $NodeDir
if ($LASTEXITCODE -ne 0) {
    throw "Node stop failed during restart."
}

$startArgs = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (Join-Path $PSScriptRoot "flowchain-node-start.ps1"),
    "-StatePath",
    $StatePath,
    "-NodeDir",
    $NodeDir,
    "-BlockMs",
    "$BlockMs"
)
if ($MaxBlocks -gt 0) {
    $startArgs += @("-MaxBlocks", "$MaxBlocks")
}
if ($Wait) {
    $startArgs += "-Wait"
}

& powershell @startArgs
if ($LASTEXITCODE -ne 0) {
    throw "Node start failed during restart."
}

$report = [ordered]@{
    schema = "flowchain.private_testnet.node_restart_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    startedAt = $startedAt
    completedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "passed"
    statePath = $StatePath
    nodeDir = $NodeDir
    maxBlocks = $MaxBlocks
    waited = [bool] $Wait
    statusCommand = "npm run flowchain:node:status"
    logsCommand = "npm run flowchain:node:logs"
}
Write-FlowChainJson -Path $reportPath -Value $report

Write-Host "FlowChain node restart complete."
Write-Host "Report: $reportPath"

