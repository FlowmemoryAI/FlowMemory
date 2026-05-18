param(
    [switch] $StopKnownPorts,
    [string] $ReportPath = "devnet/local/emergency/flowchain-emergency-stop-local-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$actions = New-Object System.Collections.ArrayList

try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-node-stop.ps1")
    [void] $actions.Add([ordered]@{ action = "node-stop"; status = "requested"; command = "npm run flowchain:node:stop" })
}
catch {
    [void] $actions.Add([ordered]@{ action = "node-stop"; status = "failed"; command = "npm run flowchain:node:stop"; reason = $_.Exception.Message })
}

foreach ($port in @(8787, 5173)) {
    $connections = @(Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue)
    $pids = @($connections | Select-Object -ExpandProperty OwningProcess -Unique)
    foreach ($processId in $pids) {
        if ($StopKnownPorts) {
            Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
            [void] $actions.Add([ordered]@{ action = "stop-port-process"; status = "stopped"; port = $port; pid = $processId })
        }
        else {
            [void] $actions.Add([ordered]@{ action = "stop-port-process"; status = "manual"; port = $port; pid = $processId; command = "Stop-Process -Id $processId -Force" })
        }
    }
}

$report = [ordered]@{
    schema = "flowchain.emergency_stop_local_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "completed"
    actions = @($actions)
    bridgeRelayerStop = "Bridge relayer is normally one-shot in this repo. Stop any relayer PowerShell window or process using the PID shown by the relayer command."
    evidenceCommand = "npm run flowchain:emergency:export-evidence"
    recoveryCommand = "npm run flowchain:emergency:print-recovery"
}
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 12

Write-Host "FlowChain local emergency stop completed."
Write-Host "Report: $reportFullPath"
Write-Host "Evidence command: npm run flowchain:emergency:export-evidence"
Write-Host "Recovery command: npm run flowchain:emergency:print-recovery"
