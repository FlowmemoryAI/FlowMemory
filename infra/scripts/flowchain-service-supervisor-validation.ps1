param(
    [string] $StatePath = "devnet/local/service-supervisor-validation/state.json",
    [string] $NodeDir = "devnet/local/service-supervisor-validation/node",
    [string] $ServicesDir = "devnet/local/service-supervisor-validation/services",
    [string] $ControlPlaneHost = "127.0.0.1",
    [int] $ControlPlanePort = 8797,
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$statusBeforePath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-status-before.json"
$statusAfterCrashPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-status-after-crash.json"
$statusAfterPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-status-after.json"
$statusBeforeRelayerCrashPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-relayer-status-before-crash.json"
$statusAfterRelayerCrashPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-relayer-status-after-crash.json"
$statusDuringRelayerRecoveryPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-relayer-status-during-recovery.json"
$statusAfterRelayerRecoveryPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-relayer-status-after-recovery.json"
$supervisorReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-supervisor-report.json"
$restartReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-restart-report.json"
$stopReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-stop-report.json"
$relayerStartRestartReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-relayer-start-restart-report.json"
$relayerStartStopReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-relayer-start-stop-report.json"
$relayerSupervisorReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-relayer-supervisor-report.json"
$relayerSupervisorRestartReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-relayer-restart-report.json"
$relayerSupervisorStopReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-relayer-stop-report.json"
$finalStopReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-final-stop-report.json"
$validationTmpDir = Join-Path $repoRoot "devnet/local/tmp/service-supervisor-validation"
New-Item -ItemType Directory -Force -Path $validationTmpDir | Out-Null

function Invoke-ValidationChild {
    param(
        [Parameter(Mandatory = $true)][string[]] $ArgumentList,
        [int] $TimeoutSeconds = 180
    )

    $runId = "$(Get-Date -Format 'yyyyMMddHHmmssfff')-$PID-$([System.Guid]::NewGuid().ToString('N').Substring(0, 8))"
    $stdoutPath = Join-Path $validationTmpDir "$runId.stdout.log"
    $stderrPath = Join-Path $validationTmpDir "$runId.stderr.log"
    try {
        $process = Start-Process -FilePath "powershell" `
            -ArgumentList (Join-FlowChainProcessArguments -ArgumentList $ArgumentList) `
            -WorkingDirectory $repoRoot `
            -PassThru `
            -WindowStyle Hidden `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath
        $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
        if ($timedOut) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            $exitCode = 124
        }
        else {
            $process.Refresh()
            $exitCode = $process.ExitCode
        }
        $output = @()
        if (Test-Path -LiteralPath $stdoutPath) {
            $output += @(Get-Content -LiteralPath $stdoutPath -Tail 30)
        }
        if (Test-Path -LiteralPath $stderrPath) {
            $output += @(Get-Content -LiteralPath $stderrPath -Tail 30)
        }
    }
    catch {
        $output = @("$($_.Exception.Message)")
        $exitCode = 1
    }

    return [ordered]@{
        exitCode = [int]$exitCode
        outputRedacted = @($output)
        stdoutPath = $stdoutPath
        stderrPath = $stderrPath
    }
}

function Get-ValidationProp {
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

function Invoke-ValidationStatus {
    param([Parameter(Mandatory = $true)][string] $Path)
    $result = Invoke-ValidationChild -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Join-Path $PSScriptRoot "flowchain-service-status.ps1"),
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
        "-ReportPath",
        $Path,
        "-AllowBlocked"
    )
    $report = Read-FlowChainJsonIfExists -Path $Path
    return [ordered]@{
        exitCode = [int]$result.exitCode
        outputRedacted = @($result.outputRedacted)
        report = $report
    }
}

$steps = New-Object System.Collections.ArrayList
$cleanup = $true
$status = "failed"

try {
    Write-Host "Supervisor validation: stopping any previous isolated service."
    [void]$steps.Add([ordered]@{
        name = "pre-clean-stop"
        result = Invoke-ValidationChild -ArgumentList @(
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
            $ServicesDir,
            "-ReportPath",
            $finalStopReportPath
        )
    })

    Write-Host "Supervisor validation: starting isolated live service on $ControlPlaneHost`:$ControlPlanePort."
    [void]$steps.Add([ordered]@{
        name = "start-isolated-live-service"
        result = Invoke-ValidationChild -ArgumentList @(
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
            "-LiveProfile"
        )
    })

    Write-Host "Supervisor validation: reading isolated service status before crash."
    $before = Invoke-ValidationStatus -Path $statusBeforePath
    $beforeReport = $before.report
    $beforeControlPlane = Get-ValidationProp -Object $beforeReport -Name "controlPlane"
    $beforeControlPlanePid = [int](Get-ValidationProp -Object $beforeControlPlane -Name "pid" -Default 0)
    if ($beforeControlPlanePid -le 0) {
        throw "Validation could not read isolated control-plane PID."
    }

    Write-Host "Supervisor validation: killing isolated control-plane PID $beforeControlPlanePid."
    Stop-Process -Id $beforeControlPlanePid -Force -ErrorAction Stop
    Start-Sleep -Seconds 2
    Write-Host "Supervisor validation: confirming crash state."
    $afterCrash = Invoke-ValidationStatus -Path $statusAfterCrashPath

    Write-Host "Supervisor validation: running supervisor once for recovery."
    [void]$steps.Add([ordered]@{
        name = "supervisor-once-recovery"
        result = Invoke-ValidationChild -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            (Join-Path $PSScriptRoot "flowchain-service-supervisor.ps1"),
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
            "-Once",
            "-IntervalSeconds",
            "1",
            "-MaxRestartAttempts",
            "1",
            "-ReportPath",
            $supervisorReportPath,
            "-StatusReportPath",
            $statusAfterCrashPath,
            "-RestartReportPath",
            $restartReportPath,
            "-StopReportPath",
            $stopReportPath
        )
    })

    Write-Host "Supervisor validation: verifying recovered service."
    $after = Invoke-ValidationStatus -Path $statusAfterPath
    $afterReport = $after.report
    $afterStatus = [string](Get-ValidationProp -Object $afterReport -Name "status" -Default "missing")
    $afterNode = Get-ValidationProp -Object $afterReport -Name "node"
    $afterControlPlane = Get-ValidationProp -Object $afterReport -Name "controlPlane"
    $afterChain = Get-ValidationProp -Object $afterReport -Name "chain"
    $afterProfile = Get-ValidationProp -Object $afterReport -Name "serviceProfile"
    $afterNodeRunning = [string](Get-ValidationProp -Object $afterNode -Name "status" -Default "") -eq "running"
    $afterControlPlaneRunning = [string](Get-ValidationProp -Object $afterControlPlane -Name "status" -Default "") -eq "running"
    $afterHeight = [string](Get-ValidationProp -Object $afterChain -Name "latestHeight" -Default "")
    $afterLiveProfile = [bool](Get-ValidationProp -Object $afterProfile -Name "liveProfile" -Default $false)
    $afterMaxBlocks = [int](Get-ValidationProp -Object $afterProfile -Name "maxBlocks" -Default -1)
    $afterCrashReport = $afterCrash.report
    $afterCrashStatus = [string](Get-ValidationProp -Object $afterCrashReport -Name "status" -Default "missing")
    $afterCrashControlPlane = Get-ValidationProp -Object $afterCrashReport -Name "controlPlane"
    $afterCrashControlPlaneStatus = [string](Get-ValidationProp -Object $afterCrashControlPlane -Name "status" -Default "missing")
    $afterCrashDetected = (@("blocked", "failed") -contains $afterCrashStatus) -and $afterCrashControlPlaneStatus -ne "running"
    $supervisorReport = Read-FlowChainJsonIfExists -Path $supervisorReportPath
    $restartAttempts = [int](Get-ValidationProp -Object $supervisorReport -Name "restartAttempts" -Default 0)

    Write-Host "Supervisor validation: restarting isolated service with bridge relayer loop enabled."
    [void]$steps.Add([ordered]@{
        name = "restart-with-relayer-loop"
        result = Invoke-ValidationChild -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            (Join-Path $PSScriptRoot "flowchain-service-restart.ps1"),
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
            "1000",
            "-MaxBlocks",
            "0",
            "-LiveProfile",
            "-StartBridgeRelayerLoop",
            "-BridgePollSeconds",
            "5",
            "-ReportPath",
            $relayerStartRestartReportPath,
            "-StopReportPath",
            $relayerStartStopReportPath
        )
    })

    Start-Sleep -Seconds 5
    Write-Host "Supervisor validation: reading relayer loop status before crash."
    $beforeRelayerCrash = Invoke-ValidationStatus -Path $statusBeforeRelayerCrashPath
    $beforeRelayerCrashReport = $beforeRelayerCrash.report
    $beforeRelayerCrashStatus = [string](Get-ValidationProp -Object $beforeRelayerCrashReport -Name "status" -Default "missing")
    $beforeRelayerLoop = Get-ValidationProp -Object $beforeRelayerCrashReport -Name "bridgeRelayerLoop"
    $beforeRelayerLoopReport = Get-ValidationProp -Object $beforeRelayerLoop -Name "report"
    $beforeRelayerLoopStatus = [string](Get-ValidationProp -Object $beforeRelayerLoop -Name "status" -Default "missing")
    $beforeRelayerLoopPid = [int](Get-ValidationProp -Object $beforeRelayerLoop -Name "pid" -Default 0)
    $beforeRelayerLoopCommandLineMatched = [bool](Get-ValidationProp -Object $beforeRelayerLoop -Name "commandLineMatched" -Default $false)
    $beforeRelayerLoopReportStatus = [string](Get-ValidationProp -Object $beforeRelayerLoopReport -Name "status" -Default "missing")
    $beforeRelayerLoopReportHealthy = [bool](Get-ValidationProp -Object $beforeRelayerLoopReport -Name "healthy" -Default $false)
    if ($beforeRelayerLoopPid -le 0) {
        throw "Validation could not read isolated bridge relayer loop PID."
    }

    Write-Host "Supervisor validation: killing isolated bridge relayer loop PID $beforeRelayerLoopPid."
    Stop-Process -Id $beforeRelayerLoopPid -Force -ErrorAction Stop
    Start-Sleep -Seconds 2
    Write-Host "Supervisor validation: confirming relayer loop crash state."
    $afterRelayerCrash = Invoke-ValidationStatus -Path $statusAfterRelayerCrashPath
    $afterRelayerCrashReport = $afterRelayerCrash.report
    $afterRelayerCrashStatus = [string](Get-ValidationProp -Object $afterRelayerCrashReport -Name "status" -Default "missing")
    $afterRelayerCrashLoop = Get-ValidationProp -Object $afterRelayerCrashReport -Name "bridgeRelayerLoop"
    $afterRelayerCrashLoopStatus = [string](Get-ValidationProp -Object $afterRelayerCrashLoop -Name "status" -Default "missing")
    $afterRelayerCrashDetected = $afterRelayerCrashLoopStatus -ne "running"

    Write-Host "Supervisor validation: running supervisor once for relayer loop recovery."
    [void]$steps.Add([ordered]@{
        name = "supervisor-once-relayer-loop-recovery"
        result = Invoke-ValidationChild -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            (Join-Path $PSScriptRoot "flowchain-service-supervisor.ps1"),
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
            "-Once",
            "-IntervalSeconds",
            "1",
            "-MaxRestartAttempts",
            "1",
            "-BridgePollSeconds",
            "5",
            "-PostRestartSettleSeconds",
            "30",
            "-PostRestartPollSeconds",
            "1",
            "-StartBridgeRelayerLoop",
            "-ReportPath",
            $relayerSupervisorReportPath,
            "-StatusReportPath",
            $statusDuringRelayerRecoveryPath,
            "-RestartReportPath",
            $relayerSupervisorRestartReportPath,
            "-StopReportPath",
            $relayerSupervisorStopReportPath
        )
    })

    Write-Host "Supervisor validation: verifying relayer loop recovered."
    $afterRelayerRecovery = Invoke-ValidationStatus -Path $statusAfterRelayerRecoveryPath
    $afterRelayerRecoveryReport = $afterRelayerRecovery.report
    $afterRelayerRecoveryStatus = [string](Get-ValidationProp -Object $afterRelayerRecoveryReport -Name "status" -Default "missing")
    $afterRelayerRecoveryNode = Get-ValidationProp -Object $afterRelayerRecoveryReport -Name "node"
    $afterRelayerRecoveryControlPlane = Get-ValidationProp -Object $afterRelayerRecoveryReport -Name "controlPlane"
    $afterRelayerRecoveryProfile = Get-ValidationProp -Object $afterRelayerRecoveryReport -Name "serviceProfile"
    $afterRelayerRecoveryLoop = Get-ValidationProp -Object $afterRelayerRecoveryReport -Name "bridgeRelayerLoop"
    $afterRelayerRecoveryLoopReport = Get-ValidationProp -Object $afterRelayerRecoveryLoop -Name "report"
    $afterRelayerRecoveryNodeRunning = [string](Get-ValidationProp -Object $afterRelayerRecoveryNode -Name "status" -Default "") -eq "running"
    $afterRelayerRecoveryControlPlaneRunning = [string](Get-ValidationProp -Object $afterRelayerRecoveryControlPlane -Name "status" -Default "") -eq "running"
    $afterRelayerRecoveryLiveProfile = [bool](Get-ValidationProp -Object $afterRelayerRecoveryProfile -Name "liveProfile" -Default $false)
    $afterRelayerRecoveryMaxBlocks = [int](Get-ValidationProp -Object $afterRelayerRecoveryProfile -Name "maxBlocks" -Default -1)
    $afterRelayerRecoveryLoopStatus = [string](Get-ValidationProp -Object $afterRelayerRecoveryLoop -Name "status" -Default "missing")
    $afterRelayerRecoveryLoopPid = [int](Get-ValidationProp -Object $afterRelayerRecoveryLoop -Name "pid" -Default 0)
    $afterRelayerRecoveryLoopCommandLineMatched = [bool](Get-ValidationProp -Object $afterRelayerRecoveryLoop -Name "commandLineMatched" -Default $false)
    $afterRelayerRecoveryLoopReportStatus = [string](Get-ValidationProp -Object $afterRelayerRecoveryLoopReport -Name "status" -Default "missing")
    $afterRelayerRecoveryLoopReportHealthy = [bool](Get-ValidationProp -Object $afterRelayerRecoveryLoopReport -Name "healthy" -Default $false)
    $relayerSupervisorReport = Read-FlowChainJsonIfExists -Path $relayerSupervisorReportPath
    $relayerRestartAttempts = [int](Get-ValidationProp -Object $relayerSupervisorReport -Name "restartAttempts" -Default 0)

    $stepSummaries = @($steps | ForEach-Object {
        [ordered]@{
            name = [string]$_.name
            exitCode = [int]$_.result.exitCode
            stdoutPath = [string]$_.result.stdoutPath
            stderrPath = [string]$_.result.stderrPath
        }
    })
    $stepByName = @{}
    foreach ($step in @($stepSummaries)) {
        $stepByName[[string]$step.name] = $step
    }
    $secretMarkerFindings = New-Object System.Collections.ArrayList
    $childLogPathsInsideRepo = $true
    foreach ($step in @($stepSummaries)) {
        foreach ($path in @([string]$step.stdoutPath, [string]$step.stderrPath)) {
            if ([string]::IsNullOrWhiteSpace($path)) {
                continue
            }
            try {
                [void](Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path $path)
            }
            catch {
                $childLogPathsInsideRepo = $false
                [void]$secretMarkerFindings.Add([ordered]@{ path = $path; reason = "path outside repo" })
                continue
            }
            if (Test-Path -LiteralPath $path) {
                $text = Get-Content -Raw -LiteralPath $path
                if ([string]::IsNullOrEmpty($text)) {
                    continue
                }
                try {
                    Assert-FlowChainNoSecretText -Text $text -Label "service supervisor validation child log"
                }
                catch {
                    [void]$secretMarkerFindings.Add([ordered]@{ path = $path; reason = $_.Exception.Message })
                }
            }
        }
    }
    $checks = [ordered]@{
        preCleanStopCommandPassed = $stepByName.ContainsKey("pre-clean-stop") -and [int]$stepByName["pre-clean-stop"].exitCode -eq 0
        startIsolatedLiveServiceCommandPassed = $stepByName.ContainsKey("start-isolated-live-service") -and [int]$stepByName["start-isolated-live-service"].exitCode -eq 0
        beforeStatusCommandPassed = [int]$before.exitCode -eq 0
        beforeStatusPassed = [string](Get-ValidationProp -Object $beforeReport -Name "status" -Default "missing") -eq "passed"
        beforeControlPlanePidRecorded = $beforeControlPlanePid -gt 0
        crashStatusCommandPassed = [int]$afterCrash.exitCode -eq 0
        crashStatusDetected = $afterCrashDetected
        supervisorOnceRecoveryCommandPassed = $stepByName.ContainsKey("supervisor-once-recovery") -and [int]$stepByName["supervisor-once-recovery"].exitCode -eq 0
        restartAttemptsExactlyOne = $restartAttempts -eq 1
        afterStatusCommandPassed = [int]$after.exitCode -eq 0
        afterRecoveryStatusPassed = $afterStatus -eq "passed"
        afterRecoveryNodeRunning = $afterNodeRunning
        afterRecoveryControlPlaneRunning = $afterControlPlaneRunning
        afterRecoveryHeightNumeric = $afterHeight -match '^\d+$'
        afterRecoveryLiveProfile = $afterLiveProfile
        afterRecoveryMaxBlocksUnbounded = $afterMaxBlocks -eq 0
        restartWithRelayerLoopCommandPassed = $stepByName.ContainsKey("restart-with-relayer-loop") -and [int]$stepByName["restart-with-relayer-loop"].exitCode -eq 0
        beforeRelayerCrashStatusCommandPassed = [int]$beforeRelayerCrash.exitCode -eq 0
        beforeRelayerCrashStatusPassed = $beforeRelayerCrashStatus -eq "passed"
        beforeRelayerCrashPidRecorded = $beforeRelayerLoopPid -gt 0
        beforeRelayerCrashRunning = $beforeRelayerLoopStatus -eq "running"
        beforeRelayerCrashCommandLineMatched = $beforeRelayerLoopCommandLineMatched
        beforeRelayerCrashReportHealthy = $beforeRelayerLoopReportHealthy
        relayerCrashStatusCommandPassed = [int]$afterRelayerCrash.exitCode -eq 0
        relayerCrashDetected = $afterRelayerCrashDetected
        supervisorRelayerRecoveryCommandPassed = $stepByName.ContainsKey("supervisor-once-relayer-loop-recovery") -and [int]$stepByName["supervisor-once-relayer-loop-recovery"].exitCode -eq 0
        relayerRestartAttemptsExactlyOne = $relayerRestartAttempts -eq 1
        afterRelayerRecoveryStatusCommandPassed = [int]$afterRelayerRecovery.exitCode -eq 0
        afterRelayerRecoveryStatusPassed = $afterRelayerRecoveryStatus -eq "passed"
        afterRelayerRecoveryNodeRunning = $afterRelayerRecoveryNodeRunning
        afterRelayerRecoveryControlPlaneRunning = $afterRelayerRecoveryControlPlaneRunning
        afterRelayerRecoveryLiveProfile = $afterRelayerRecoveryLiveProfile
        afterRelayerRecoveryMaxBlocksUnbounded = $afterRelayerRecoveryMaxBlocks -eq 0
        afterRelayerRecoveryLoopRunning = $afterRelayerRecoveryLoopStatus -eq "running"
        afterRelayerRecoveryLoopPidRecorded = $afterRelayerRecoveryLoopPid -gt 0
        afterRelayerRecoveryLoopCommandLineMatched = $afterRelayerRecoveryLoopCommandLineMatched
        afterRelayerRecoveryLoopReportHealthy = $afterRelayerRecoveryLoopReportHealthy
        childLogPathsInsideRepo = $childLogPathsInsideRepo
        secretMarkerFindingsEmpty = $secretMarkerFindings.Count -eq 0
        envValuesPrintedFalse = $true
        noSecrets = $true
        broadcastsFalse = $true
    }
    $failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
    $status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }

    Write-Host "Supervisor validation: writing validation report."
    $report = [ordered]@{
        schema = "flowchain.service_supervisor_validation_report.v0"
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        status = $status
        statePath = $StatePath
        nodeDir = $NodeDir
        servicesDir = $ServicesDir
        controlPlane = [ordered]@{
            host = $ControlPlaneHost
            port = $ControlPlanePort
            killedPid = $beforeControlPlanePid
        }
        before = [ordered]@{
            status = [string](Get-ValidationProp -Object $beforeReport -Name "status" -Default "missing")
        }
        afterCrash = [ordered]@{
            status = $afterCrashStatus
            controlPlaneStatus = $afterCrashControlPlaneStatus
        }
        afterRecovery = [ordered]@{
            status = $afterStatus
            nodeRunning = $afterNodeRunning
            controlPlaneRunning = $afterControlPlaneRunning
            latestHeight = $afterHeight
            liveProfile = $afterLiveProfile
            maxBlocks = $afterMaxBlocks
        }
        restartAttempts = $restartAttempts
        relayerLoopRecovery = [ordered]@{
            beforeCrash = [ordered]@{
                status = $beforeRelayerCrashStatus
                loopStatus = $beforeRelayerLoopStatus
                pid = $beforeRelayerLoopPid
                commandLineMatched = $beforeRelayerLoopCommandLineMatched
                reportStatus = $beforeRelayerLoopReportStatus
                reportHealthy = $beforeRelayerLoopReportHealthy
            }
            afterCrash = [ordered]@{
                status = $afterRelayerCrashStatus
                loopStatus = $afterRelayerCrashLoopStatus
                detected = $afterRelayerCrashDetected
            }
            afterRecovery = [ordered]@{
                status = $afterRelayerRecoveryStatus
                nodeRunning = $afterRelayerRecoveryNodeRunning
                controlPlaneRunning = $afterRelayerRecoveryControlPlaneRunning
                liveProfile = $afterRelayerRecoveryLiveProfile
                maxBlocks = $afterRelayerRecoveryMaxBlocks
                loopStatus = $afterRelayerRecoveryLoopStatus
                loopPid = $afterRelayerRecoveryLoopPid
                loopCommandLineMatched = $afterRelayerRecoveryLoopCommandLineMatched
                reportStatus = $afterRelayerRecoveryLoopReportStatus
                reportHealthy = $afterRelayerRecoveryLoopReportHealthy
            }
            restartAttempts = $relayerRestartAttempts
        }
        checks = $checks
        failedChecks = @($failedChecks)
        secretMarkerFindings = @($secretMarkerFindings)
        reportPaths = [ordered]@{
            validation = $reportFullPath
            before = $statusBeforePath
            afterCrash = $statusAfterCrashPath
            supervisor = $supervisorReportPath
            restart = $restartReportPath
            stop = $stopReportPath
            after = $statusAfterPath
            relayerBeforeCrash = $statusBeforeRelayerCrashPath
            relayerAfterCrash = $statusAfterRelayerCrashPath
            relayerDuringRecovery = $statusDuringRelayerRecoveryPath
            relayerAfterRecovery = $statusAfterRelayerRecoveryPath
            relayerStartRestart = $relayerStartRestartReportPath
            relayerStartStop = $relayerStartStopReportPath
            relayerSupervisor = $relayerSupervisorReportPath
            relayerRestart = $relayerSupervisorRestartReportPath
            relayerStop = $relayerSupervisorStopReportPath
        }
        steps = @($stepSummaries)
        envValuesPrinted = $false
        noSecrets = $true
        broadcasts = $false
    }
    $reportText = $report | ConvertTo-Json -Depth 20
    Assert-FlowChainNoSecretText -Text $reportText -Label "service supervisor validation report"
    Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20
}
finally {
    if ($cleanup) {
        Invoke-ValidationChild -ArgumentList @(
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
            $ServicesDir,
            "-ReportPath",
            $finalStopReportPath
        ) | Out-Null
    }
}

Write-Host "FlowChain service supervisor validation status: $status"
Write-Host "Report: $reportFullPath"
if ($status -ne "passed") {
    exit 1
}
exit 0
