param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node",
    [string] $ServicesDir = "devnet/local/services",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/service-stop-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$servicesFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ServicesDir)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$controlPlanePidPath = Join-Path $servicesFullDir "control-plane.pid"
$relayerPidPath = Join-Path $servicesFullDir "bridge-relayer-loop.pid"

function Stop-FlowChainPidFile {
    param([Parameter(Mandatory = $true)][string] $PidPath)
    $status = Test-FlowChainPid -PidPath $PidPath
    if ($status.running -and $null -ne $status.pid) {
        Stop-Process -Id $status.pid -Force -ErrorAction SilentlyContinue
        return "stopped"
    }
    return "not-running"
}

$relayerStop = Stop-FlowChainPidFile -PidPath $relayerPidPath
$controlStop = Stop-FlowChainPidFile -PidPath $controlPlanePidPath
$nodeStop = "not-run"
try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-node-stop.ps1") -StatePath $StatePath -NodeDir $NodeDir
    $nodeStop = if ($LASTEXITCODE -eq 0) { "stop-requested" } else { "failed" }
}
catch {
    $nodeStop = "failed"
}

$report = [ordered]@{
    schema = "flowchain.service_stop_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = if ($nodeStop -eq "failed") { "degraded" } else { "stopped" }
    node = $nodeStop
    controlPlane = $controlStop
    bridgeRelayerLoop = $relayerStop
    statePreserved = $true
    deletedRuntimeData = $false
    restartCommand = "npm run flowchain:service:restart"
    envValuesPrinted = $false
    noSecrets = $true
}
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 10

Write-Host "FlowChain service stop status: $($report.status)"
Write-Host "State preserved: true"
Write-Host "Report: $reportFullPath"
if ($report.status -eq "degraded") {
    throw "FlowChain service stop degraded. State was preserved."
}
