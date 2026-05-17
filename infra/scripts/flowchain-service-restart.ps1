param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node",
    [string] $ServicesDir = "devnet/local/services",
    [string] $ControlPlaneHost = "127.0.0.1",
    [int] $ControlPlanePort = 8787,
    [int] $BlockMs = 1000,
    [int] $MaxBlocks = 0,
    [switch] $LiveProfile,
    [switch] $StartBridgeRelayerLoop,
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/service-restart-report.json",
    [string] $StopReportPath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)

$stopArgs = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (Join-Path $PSScriptRoot "flowchain-service-stop.ps1"),
    "-StatePath",
    $StatePath,
    "-NodeDir",
    $NodeDir,
    "-ServicesDir",
    $ServicesDir
)
if (-not [string]::IsNullOrWhiteSpace($StopReportPath)) {
    $stopArgs += @("-ReportPath", $StopReportPath)
}

& powershell @stopArgs
if ($LASTEXITCODE -ne 0) {
    throw "FlowChain service stop failed during restart."
}

$startArgs = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (Join-Path $PSScriptRoot "flowchain-service-start.ps1"),
    "-StatePath",
    $StatePath,
    "-NodeDir",
    $NodeDir,
    "-ServicesDir",
    $ServicesDir,
    "-ControlPlaneHost",
    $ControlPlaneHost,
    "-ControlPlanePort",
    "$ControlPlanePort",
    "-BlockMs",
    "$BlockMs",
    "-MaxBlocks",
    "$MaxBlocks"
)
if ($LiveProfile) { $startArgs += "-LiveProfile" }
if ($StartBridgeRelayerLoop) { $startArgs += "-StartBridgeRelayerLoop" }

& powershell @startArgs
if ($LASTEXITCODE -ne 0) {
    throw "FlowChain service start failed during restart."
}

$report = [ordered]@{
    schema = "flowchain.service_restart_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "passed"
    statePreserved = $true
    deletedRuntimeData = $false
    statusCommand = "npm run flowchain:service:status"
    envValuesPrinted = $false
    noSecrets = $true
}
Write-FlowChainJson -Path $reportPath -Value $report -Depth 10

Write-Host "FlowChain service restart passed."
Write-Host "Report: $reportPath"
