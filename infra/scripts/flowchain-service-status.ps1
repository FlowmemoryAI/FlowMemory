param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node",
    [string] $ServicesDir = "devnet/local/services",
    [string] $ControlPlaneHost = "127.0.0.1",
    [int] $ControlPlanePort = 8787,
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/service-status-report.json",
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$nodeFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $NodeDir)
$servicesFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ServicesDir)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$controlPlaneScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "services/control-plane/src/server.ts")

$nodePidPath = Join-Path $nodeFullDir "flowchain-node.pid"
$controlPlanePidPath = Join-Path $servicesFullDir "control-plane.pid"
$relayerPidPath = Join-Path $servicesFullDir "bridge-relayer-loop.pid"
$serviceStartReportPath = Join-Path $servicesFullDir "flowchain-service-start-report.json"

$nodeStatus = Test-FlowChainPid -PidPath $nodePidPath -CommandLineIncludes @("flowmemory-devnet")
$controlPlaneStatus = Test-FlowChainPid -PidPath $controlPlanePidPath -CommandLineIncludes @($controlPlaneScriptPath)
$relayerStatus = Test-FlowChainPid -PidPath $relayerPidPath -CommandLineIncludes @("bridge-base-mainnet-pilot-observe.ps1")
$controlPlaneReady = $controlPlaneStatus.running -and $controlPlaneStatus.commandLineMatched
$controlPlanePortProcess = $null
if (-not $controlPlaneReady) {
    $connections = @(Get-NetTCPConnection -LocalPort $ControlPlanePort -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($connections.Count -gt 0) {
        $portPid = [int]$connections[0].OwningProcess
        $commandLine = ""
        if ($portPid -gt 0) {
            try {
                $commandLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$portPid").CommandLine
            }
            catch {
                $commandLine = ""
            }
        }
        if ("$commandLine" -like "*$controlPlaneScriptPath*") {
            $controlPlaneStatus["running"] = $true
            $controlPlaneStatus["pid"] = $portPid
            $controlPlaneStatus["commandLineMatched"] = $true
            $controlPlaneReady = $true
        }
        else {
            $controlPlanePortProcess = [ordered]@{
                pid = $portPid
                cleanupPending = ($portPid -le 0)
                currentRepoControlPlane = $false
            }
        }
    }
}
$stateFacts = Get-FlowChainStateFacts -StatePath $stateFullPath
$serviceStartReport = Read-FlowChainJsonIfExists -Path $serviceStartReportPath

$publicReadinessReport = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json")
$backupReadinessReport = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json")
$bridgeLiveReport = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/bridge-live-readiness/bridge-live-readiness-report.json")
$bridgeInfraReport = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json")

$problems = New-Object System.Collections.ArrayList
if (-not $nodeStatus.running) {
    Add-FlowChainReadinessProblem -Problems $problems -Name "devnet/local/node/flowchain-node.pid" -Reason "FlowChain node process is not running" -Category "process"
}
if (-not $controlPlaneReady) {
    Add-FlowChainReadinessProblem -Problems $problems -Name "devnet/local/services/control-plane.pid" -Reason "control-plane process is not running from this repository" -Category "process"
}
if ($null -ne $controlPlanePortProcess -and -not $controlPlaneReady) {
    if ($controlPlanePortProcess.cleanupPending) {
        Add-FlowChainReadinessProblem -Problems $problems -Name "127.0.0.1:$ControlPlanePort" -Reason "control-plane port is still being released by Windows" -Category "process"
    }
    else {
        Add-FlowChainReadinessProblem -Problems $problems -Name "127.0.0.1:$ControlPlanePort" -Reason "control-plane port is occupied by a process that was not launched from this repository" -Kind "failed" -Category "process"
    }
}
if (-not $stateFacts.readable) {
    Add-FlowChainReadinessProblem -Problems $problems -Name "devnet/local/state.json" -Reason "state file is missing or unreadable" -Category "artifact"
}

$liveProfile = $false
$maxBlocks = 0
if ($null -ne $serviceStartReport) {
    if ($serviceStartReport.PSObject.Properties.Name -contains "liveProfile") {
        $liveProfile = [bool]$serviceStartReport.liveProfile
    }
    if ($serviceStartReport.PSObject.Properties.Name -contains "maxBlocks") {
        $maxBlocks = [int]$serviceStartReport.maxBlocks
    }
}
if ($liveProfile -and $maxBlocks -gt 0) {
    Add-FlowChainReadinessProblem -Problems $problems -Name "flowchain-service-start.ps1" -Reason "live service profile must not use bounded MaxBlocks mode" -Kind "failed" -Category "process"
}

$failed = @($problems | Where-Object { $_.kind -eq "failed" })
$status = if ($failed.Count -gt 0) { "failed" } elseif ($problems.Count -gt 0) { "blocked" } else { "passed" }

$report = [ordered]@{
    schema = "flowchain.service_status_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    bind = [ordered]@{
        host = $ControlPlaneHost
        port = $ControlPlanePort
        localDefaultPrivate = ($ControlPlaneHost -eq "127.0.0.1")
    }
    node = [ordered]@{
        status = if ($nodeStatus.running) { "running" } else { "stopped" }
        pid = $nodeStatus.pid
        pidPath = "devnet/local/node/flowchain-node.pid"
        commandLineMatched = $nodeStatus.commandLineMatched
    }
    controlPlane = [ordered]@{
        status = if ($controlPlaneReady) { "running" } elseif ($null -ne $controlPlanePortProcess -and $controlPlanePortProcess.cleanupPending) { "port-cleanup-pending" } elseif ($null -ne $controlPlanePortProcess) { "port-occupied" } elseif ($controlPlaneStatus.running) { "pid-mismatch" } else { "stopped" }
        pid = $controlPlaneStatus.pid
        pidPath = "devnet/local/services/control-plane.pid"
        commandLineMatched = $controlPlaneReady
    }
    controlPlanePortProcess = $controlPlanePortProcess
    bridgeRelayerLoop = [ordered]@{
        status = if ($relayerStatus.running) { "running" } else { "stopped" }
        pid = $relayerStatus.pid
        pidPath = "devnet/local/services/bridge-relayer-loop.pid"
        commandLineMatched = $relayerStatus.commandLineMatched
    }
    serviceProfile = [ordered]@{
        liveProfile = $liveProfile
        maxBlocks = $maxBlocks
        boundedLiveModeRejected = $liveProfile -and $maxBlocks -gt 0
    }
    publicReadinessStatus = if ($publicReadinessReport) { $publicReadinessReport.status } else { "not-run" }
    backupPathStatus = if ([string]::IsNullOrWhiteSpace((Get-FlowChainEnvValue -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH"))) { "not-configured" } elseif ($backupReadinessReport) { $backupReadinessReport.status } else { "configured-not-checked" }
    bridgeReadinessStatus = [ordered]@{
        bridgeLiveCheck = if ($bridgeLiveReport) { $bridgeLiveReport.status } else { "not-run" }
        bridgeInfraCheck = if ($bridgeInfraReport) { $bridgeInfraReport.status } else { "not-run" }
    }
    chain = [ordered]@{
        stateFileReadable = $stateFacts.readable
        latestHeight = $stateFacts.latestHeight
        latestHash = $stateFacts.latestHash
        latestRoot = $stateFacts.latestRoot
        stateFileLastWriteAgeSeconds = $stateFacts.stateFileLastWriteAgeSeconds
        finalizedHeight = $stateFacts.finalizedHeight
        finalizedHash = $stateFacts.finalizedHash
        mempoolDepth = $stateFacts.mempoolDepth
        peerCount = $stateFacts.peerCount
    }
    stopCommand = "npm run flowchain:service:stop"
    restartCommand = "npm run flowchain:service:restart"
    problems = @($problems)
    envValuesPrinted = $false
    noSecrets = $true
}

Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

Write-Host "FlowChain service status: $status"
Write-Host "Node: $($report.node.status) PID=$($report.node.pid)"
Write-Host "Control plane: $($report.controlPlane.status) PID=$($report.controlPlane.pid) bind=$ControlPlaneHost`:$ControlPlanePort"
Write-Host "Public readiness: $($report.publicReadinessStatus)"
Write-Host "Latest height: $($report.chain.latestHeight)"
Write-Host "Finalized height: $($report.chain.finalizedHeight)"
Write-Host "Backup path: $($report.backupPathStatus)"
Write-Host "Bridge readiness: live=$($report.bridgeReadinessStatus.bridgeLiveCheck), infra=$($report.bridgeReadinessStatus.bridgeInfraCheck)"
Write-Host "Report: $reportFullPath"

if ($status -ne "passed" -and -not $AllowBlocked) {
    throw "FlowChain service status $status. See report for process and artifact names."
}
