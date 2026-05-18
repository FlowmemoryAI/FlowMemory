param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node",
    [string] $ServicesDir = "devnet/local/services",
    [string] $ControlPlaneHost = "127.0.0.1",
    [int] $ControlPlanePort = 8787,
    [string] $RelayerReportPath = "devnet/local/bridge-live-readiness/bridge-relayer-loop-report.json",
    [int] $RelayerReportMaxAgeSeconds = 180,
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
$relayerReportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $RelayerReportPath)
$controlPlaneScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "services/control-plane/src/server.ts")

$nodePidPath = Join-Path $nodeFullDir "flowchain-node.pid"
$controlPlanePidPath = Join-Path $servicesFullDir "control-plane.pid"
$relayerPidPath = Join-Path $servicesFullDir "bridge-relayer-loop.pid"
$nodePidPathLabel = Join-Path $NodeDir "flowchain-node.pid"
$controlPlanePidPathLabel = Join-Path $ServicesDir "control-plane.pid"
$relayerPidPathLabel = Join-Path $ServicesDir "bridge-relayer-loop.pid"
$serviceStartReportPath = Join-Path $servicesFullDir "flowchain-service-start-report.json"

$nodeStatus = Test-FlowChainPid -PidPath $nodePidPath -CommandLineIncludes @("flowmemory-devnet")
$nodePidSource = "pid-file"
if (-not ($nodeStatus.running -and $nodeStatus.commandLineMatched)) {
    $discoveredNodes = @(Find-FlowChainNodeProcess -StatePath $stateFullPath -NodeDir $nodeFullDir)
    if ($discoveredNodes.Count -gt 0) {
        $nodeStatus["configured"] = $true
        $nodeStatus["running"] = $true
        $nodeStatus["pid"] = [int]$discoveredNodes[0].pid
        $nodeStatus["commandLineMatched"] = $true
        $nodePidSource = "discovered-process"
        Set-Content -LiteralPath $nodePidPath -Value "$($nodeStatus.pid)" -Encoding ascii
    }
}
$controlPlaneStatus = Test-FlowChainPid -PidPath $controlPlanePidPath -CommandLineIncludes @($controlPlaneScriptPath)
$relayerStatus = Test-FlowChainPid -PidPath $relayerPidPath -CommandLineIncludes @("flowchain-bridge-relayer-once.ps1")
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
$relayerLoopReport = Read-FlowChainJsonIfExists -Path $relayerReportFullPath

function Get-ServiceStatusProp {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name,
        [object] $Default = $null
    )

    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $Default
}

function Get-ServiceStatusFileAgeSeconds {
    param([Parameter(Mandatory = $true)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    return [math]::Round(((Get-Date).ToUniversalTime() - (Get-Item -LiteralPath $Path).LastWriteTimeUtc).TotalSeconds, 3)
}

function Get-ServiceStatusSecretMarkerFindings {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string] $Label
    )

    $patterns = @(
        "privateKey",
        "private_key",
        "seedPhrase",
        "seed phrase",
        "mnemonic",
        "rpcUrl",
        "rpc-url",
        "apiKey",
        "webhook",
        "BEGIN RSA PRIVATE KEY",
        "BEGIN OPENSSH PRIVATE KEY"
    )

    $findings = New-Object System.Collections.ArrayList
    foreach ($pattern in $patterns) {
        if ($Text.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            [void] $findings.Add([ordered]@{
                label = $Label
                marker = $pattern
            })
        }
    }
    return @($findings)
}

if ($RelayerReportMaxAgeSeconds -lt 5) {
    throw "RelayerReportMaxAgeSeconds must be at least 5."
}

$relayerLoopReportAgeSeconds = Get-ServiceStatusFileAgeSeconds -Path $relayerReportFullPath
$relayerLoopReportStatus = if ($null -ne $relayerLoopReport) { [string](Get-ServiceStatusProp -Object $relayerLoopReport -Name "status" -Default "missing") } else { "missing" }
$relayerLoopReportFresh = $null -ne $relayerLoopReportAgeSeconds -and [double]$relayerLoopReportAgeSeconds -le $RelayerReportMaxAgeSeconds
$relayerLoopReportAcceptableStatus = $relayerLoopReportStatus -in @("passed", "blocked")
$relayerLoopIssues = @(Get-ServiceStatusProp -Object $relayerLoopReport -Name "issues" -Default @())
$relayerLoopCodeIssues = @($relayerLoopIssues | Where-Object { [string](Get-ServiceStatusProp -Object $_ -Name "kind" -Default "") -eq "code" })
$relayerLoopBlockedOnlyOnOwnerInputs = if ($relayerLoopReportStatus -eq "blocked") { $relayerLoopCodeIssues.Count -eq 0 } else { $relayerLoopReportAcceptableStatus }
$relayerLoopReportNoSecrets = $null -ne $relayerLoopReport -and (Get-ServiceStatusProp -Object $relayerLoopReport -Name "noSecrets" -Default $false) -eq $true -and (Get-ServiceStatusProp -Object $relayerLoopReport -Name "envValuesPrinted" -Default $true) -eq $false
$relayerLoopReportNoBroadcasts = $null -ne $relayerLoopReport -and (Get-ServiceStatusProp -Object $relayerLoopReport -Name "broadcasts" -Default $true) -eq $false
$relayerLoopReportHealthy = $relayerLoopReportFresh -and $relayerLoopReportAcceptableStatus -and $relayerLoopBlockedOnlyOnOwnerInputs -and $relayerLoopReportNoSecrets -and $relayerLoopReportNoBroadcasts

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
if ($relayerStatus.running) {
    if ($null -eq $relayerLoopReport) {
        Add-FlowChainReadinessProblem -Problems $problems -Name $RelayerReportPath -Reason "bridge relayer loop is running but no loop report has been written yet" -Category "artifact"
    }
    elseif (-not $relayerLoopReportFresh) {
        Add-FlowChainReadinessProblem -Problems $problems -Name $RelayerReportPath -Reason "bridge relayer loop report is stale; ageSeconds=$relayerLoopReportAgeSeconds maxAgeSeconds=$RelayerReportMaxAgeSeconds" -Kind "failed" -Category "artifact"
    }
    elseif (-not $relayerLoopReportAcceptableStatus) {
        Add-FlowChainReadinessProblem -Problems $problems -Name $RelayerReportPath -Reason "bridge relayer loop report status is $relayerLoopReportStatus" -Kind "failed" -Category "artifact"
    }
    elseif (-not $relayerLoopBlockedOnlyOnOwnerInputs) {
        Add-FlowChainReadinessProblem -Problems $problems -Name $RelayerReportPath -Reason "bridge relayer loop blocked state includes code-owned issues" -Kind "failed" -Category "artifact"
    }
    elseif (-not $relayerLoopReportNoSecrets) {
        Add-FlowChainReadinessProblem -Problems $problems -Name $RelayerReportPath -Reason "bridge relayer loop report did not prove no-secret output" -Kind "failed" -Category "security"
    }
    elseif (-not $relayerLoopReportNoBroadcasts) {
        Add-FlowChainReadinessProblem -Problems $problems -Name $RelayerReportPath -Reason "bridge relayer loop report did not prove no-broadcast operation" -Kind "failed" -Category "bridge"
    }
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
$checks = [ordered]@{
    nodeRunning = $nodeStatus.running -eq $true
    nodeCommandLineMatched = $nodeStatus.commandLineMatched -eq $true
    controlPlaneRunning = $controlPlaneReady -eq $true
    controlPlaneCommandLineMatched = $controlPlaneReady -eq $true
    controlPlanePortPrivate = $ControlPlaneHost -eq "127.0.0.1"
    stateFileReadable = $stateFacts.readable -eq $true
    latestHeightNumeric = "$($stateFacts.latestHeight)" -match '^\d+$'
    finalizedHeightNumeric = "$($stateFacts.finalizedHeight)" -match '^\d+$'
    latestHeightPositive = "$($stateFacts.latestHeight)" -match '^\d+$' -and [int64]$stateFacts.latestHeight -gt 0
    stateFileFresh = [double]$stateFacts.stateFileLastWriteAgeSeconds -le 90
    serviceProfileLive = $liveProfile -eq $true
    serviceProfileUnbounded = $maxBlocks -eq 0
    boundedLiveModeRejectedFalse = -not ($liveProfile -and $maxBlocks -gt 0)
    relayerLoopStoppedOrHealthy = (-not $relayerStatus.running) -or $relayerLoopReportHealthy
    problemsEmpty = $problems.Count -eq 0
    failedProblemsEmpty = $failed.Count -eq 0
    envValuesPrintedFalse = $true
    secretMarkerFindingsEmpty = $true
    noSecrets = $true
    broadcastsFalse = $true
}

$report = [ordered]@{
    schema = "flowchain.service_status_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "pending"
    bind = [ordered]@{
        host = $ControlPlaneHost
        port = $ControlPlanePort
        localDefaultPrivate = ($ControlPlaneHost -eq "127.0.0.1")
    }
    node = [ordered]@{
        status = if ($nodeStatus.running) { "running" } else { "stopped" }
        pid = $nodeStatus.pid
        pidPath = $nodePidPathLabel
        pidSource = $nodePidSource
        commandLineMatched = $nodeStatus.commandLineMatched
    }
    controlPlane = [ordered]@{
        status = if ($controlPlaneReady) { "running" } elseif ($null -ne $controlPlanePortProcess -and $controlPlanePortProcess.cleanupPending) { "port-cleanup-pending" } elseif ($null -ne $controlPlanePortProcess) { "port-occupied" } elseif ($controlPlaneStatus.running) { "pid-mismatch" } else { "stopped" }
        pid = $controlPlaneStatus.pid
        pidPath = $controlPlanePidPathLabel
        commandLineMatched = $controlPlaneReady
    }
    controlPlanePortProcess = $controlPlanePortProcess
    bridgeRelayerLoop = [ordered]@{
        status = if ($relayerStatus.running) { "running" } else { "stopped" }
        pid = $relayerStatus.pid
        pidPath = $relayerPidPathLabel
        commandLineMatched = $relayerStatus.commandLineMatched
        report = [ordered]@{
            path = $RelayerReportPath
            status = $relayerLoopReportStatus
            ageSeconds = $relayerLoopReportAgeSeconds
            maxAgeSeconds = $RelayerReportMaxAgeSeconds
            fresh = $relayerLoopReportFresh
            acceptableStatus = $relayerLoopReportAcceptableStatus
            blockedOnlyOnOwnerInputs = $relayerLoopBlockedOnlyOnOwnerInputs
            codeIssueCount = $relayerLoopCodeIssues.Count
            noSecrets = $relayerLoopReportNoSecrets
            noBroadcasts = $relayerLoopReportNoBroadcasts
            healthy = $relayerLoopReportHealthy
        }
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
    checks = $checks
    failedChecks = @()
    secretMarkerFindings = @()
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$preliminaryReportText = $report | ConvertTo-Json -Depth 16
$secretMarkerFindings = @(Get-ServiceStatusSecretMarkerFindings -Text $preliminaryReportText -Label "service status report")
$checks["secretMarkerFindingsEmpty"] = $secretMarkerFindings.Count -eq 0
$checks["noSecrets"] = $secretMarkerFindings.Count -eq 0
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -gt 0) { "failed" } elseif ($problems.Count -gt 0) { "blocked" } else { "passed" }
$report["status"] = $status
$report["checks"] = $checks
$report["failedChecks"] = @($failedChecks)
$report["secretMarkerFindings"] = @($secretMarkerFindings)
$report["noSecrets"] = $secretMarkerFindings.Count -eq 0

Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

Write-Host "FlowChain service status: $status"
Write-Host "Node: $($report.node.status) PID=$($report.node.pid)"
Write-Host "Control plane: $($report.controlPlane.status) PID=$($report.controlPlane.pid) bind=$ControlPlaneHost`:$ControlPlanePort"
Write-Host "Bridge relayer loop: $($report.bridgeRelayerLoop.status) report=$($report.bridgeRelayerLoop.report.status) healthy=$($report.bridgeRelayerLoop.report.healthy)"
Write-Host "Public readiness: $($report.publicReadinessStatus)"
Write-Host "Latest height: $($report.chain.latestHeight)"
Write-Host "Finalized height: $($report.chain.finalizedHeight)"
Write-Host "Backup path: $($report.backupPathStatus)"
Write-Host "Bridge readiness: live=$($report.bridgeReadinessStatus.bridgeLiveCheck), infra=$($report.bridgeReadinessStatus.bridgeInfraCheck)"
Write-Host "Report: $reportFullPath"

if ($status -ne "passed" -and -not $AllowBlocked) {
    throw "FlowChain service status $status. See report for process and artifact names."
}
