param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node"
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$nodeFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $NodeDir)
$pidPath = Join-Path $nodeFullDir "flowchain-node.pid"
$stopPath = Join-Path $nodeFullDir "stop"
$statusPath = Join-Path $nodeFullDir "status.json"
$reportPath = Join-Path $nodeFullDir "flowchain-node-stop-report.json"

New-Item -ItemType Directory -Force -Path $nodeFullDir | Out-Null
$pidStatus = Test-FlowChainPid -PidPath $pidPath -CommandLineIncludes @("flowmemory-devnet")
if ($pidStatus.running -and -not $pidStatus.commandLineMatched) {
    $report = [ordered]@{
        schema = "flowchain.private_testnet.node_stop_report.v0"
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        status = "pid-mismatch-not-stopped"
        pid = $pidStatus.pid
        statePath = $stateFullPath
        nodeDir = $nodeFullDir
        stopFile = $stopPath
        envValuesPrinted = $false
        noSecrets = $true
    }
    Write-FlowChainJson -Path $reportPath -Value $report -Depth 10
    throw "FlowChain node pid file points at a non-node process."
}

Set-Content -LiteralPath $stopPath -Value "stop" -Encoding ascii
$stopStatus = "stop-file-written"
$forceStopped = $false
if ($pidStatus.running -and $null -ne $pidStatus.pid) {
    try {
        $process = Get-Process -Id $pidStatus.pid -ErrorAction Stop
        if (-not $process.WaitForExit(10000)) {
            Stop-Process -Id $pidStatus.pid -Force -ErrorAction SilentlyContinue
            $forceStopped = $true
            $stopStatus = "force-stopped"
        }
        else {
            $stopStatus = "stopped"
        }
    }
    catch {
        $stopStatus = "not-running"
    }
}
else {
    $stopStatus = "not-running"
}

$status = [ordered]@{
    schema = "flowmemory.local_devnet.node_status.v0"
    status = if ($stopStatus -eq "not-running") { "stopped" } else { $stopStatus }
    note = "local stop requested"
    nodeId = "node:local:unknown"
    pid = $pidStatus.pid
    statePath = $stateFullPath
    nodeDir = $nodeFullDir
}
Write-FlowChainJson -Path $statusPath -Value $status -Depth 10

$report = [ordered]@{
    schema = "flowchain.private_testnet.node_stop_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $stopStatus
    pid = $pidStatus.pid
    statePath = $stateFullPath
    nodeDir = $nodeFullDir
    stopFile = $stopPath
    forceStopped = $forceStopped
    envValuesPrinted = $false
    noSecrets = $true
}
Write-FlowChainJson -Path $reportPath -Value $report -Depth 10

Write-Host "FlowChain node stop status: $stopStatus"
Write-Host "Report: $reportPath"
