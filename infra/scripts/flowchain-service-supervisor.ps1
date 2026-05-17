param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node",
    [string] $ServicesDir = "devnet/local/services",
    [string] $ControlPlaneHost = "127.0.0.1",
    [int] $ControlPlanePort = 8787,
    [int] $BlockMs = 1000,
    [int] $IntervalSeconds = 30,
    [int] $MaxRestartAttempts = 3,
    [int] $MaxStateAgeSeconds = 90,
    [switch] $Once,
    [switch] $DryRun,
    [switch] $NonLiveProfile,
    [switch] $StartBridgeRelayerLoop,
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/service-supervisor-report.json",
    [string] $StatusReportPath = "docs/agent-runs/live-product-infra-rpc/service-supervisor-status-report.json",
    [string] $RestartReportPath = "docs/agent-runs/live-product-infra-rpc/service-supervisor-restart-report.json",
    [string] $StopReportPath = "docs/agent-runs/live-product-infra-rpc/service-supervisor-stop-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$statusReportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatusReportPath)
$restartReportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $RestartReportPath)
$stopReportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StopReportPath)
$supervisorTmpDir = Join-Path $repoRoot "devnet/local/tmp/service-supervisor"
New-Item -ItemType Directory -Force -Path $supervisorTmpDir | Out-Null

if ($IntervalSeconds -lt 1) {
    throw "IntervalSeconds must be at least 1."
}
if ($MaxRestartAttempts -lt 0) {
    throw "MaxRestartAttempts must be at least 0."
}
if ($MaxStateAgeSeconds -lt 1) {
    throw "MaxStateAgeSeconds must be at least 1."
}

function Invoke-SupervisorChild {
    param(
        [Parameter(Mandatory = $true)][string[]] $ArgumentList,
        [int] $TimeoutSeconds = 180
    )

    $runId = "$(Get-Date -Format 'yyyyMMddHHmmssfff')-$PID-$([System.Guid]::NewGuid().ToString('N').Substring(0, 8))"
    $stdoutPath = Join-Path $supervisorTmpDir "$runId.stdout.log"
    $stderrPath = Join-Path $supervisorTmpDir "$runId.stderr.log"
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

function Get-SupervisorProp {
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

function Invoke-SupervisorStatus {
    $statusArgs = @(
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
        $statusReportFullPath,
        "-AllowBlocked"
    )
    $statusResult = Invoke-SupervisorChild -ArgumentList $statusArgs
    $statusReport = Read-FlowChainJsonIfExists -Path $statusReportFullPath
    $chain = Get-SupervisorProp -Object $statusReport -Name "chain"
    $node = Get-SupervisorProp -Object $statusReport -Name "node"
    $controlPlane = Get-SupervisorProp -Object $statusReport -Name "controlPlane"
    $serviceProfile = Get-SupervisorProp -Object $statusReport -Name "serviceProfile"

    return [ordered]@{
        exitCode = [int]$statusResult.exitCode
        outputRedacted = @($statusResult.outputRedacted)
        reportStatus = [string](Get-SupervisorProp -Object $statusReport -Name "status" -Default "missing")
        nodeStatus = [string](Get-SupervisorProp -Object $node -Name "status" -Default "missing")
        controlPlaneStatus = [string](Get-SupervisorProp -Object $controlPlane -Name "status" -Default "missing")
        latestHeight = [string](Get-SupervisorProp -Object $chain -Name "latestHeight" -Default "")
        finalizedHeight = [string](Get-SupervisorProp -Object $chain -Name "finalizedHeight" -Default "")
        stateFileLastWriteAgeSeconds = [int](Get-SupervisorProp -Object $chain -Name "stateFileLastWriteAgeSeconds" -Default 999999)
        liveProfile = [bool](Get-SupervisorProp -Object $serviceProfile -Name "liveProfile" -Default $false)
        maxBlocks = [int](Get-SupervisorProp -Object $serviceProfile -Name "maxBlocks" -Default -1)
    }
}

function Get-RestartReasons {
    param([Parameter(Mandatory = $true)][object] $Facts)

    $reasons = New-Object System.Collections.ArrayList
    if ([int]$Facts.exitCode -ne 0 -or [string]$Facts.reportStatus -ne "passed") {
        [void]$reasons.Add("service-status-not-passed")
    }
    if ([string]$Facts.nodeStatus -ne "running") {
        [void]$reasons.Add("node-not-running")
    }
    if ([string]$Facts.controlPlaneStatus -ne "running") {
        [void]$reasons.Add("control-plane-not-running")
    }
    if ([string]$Facts.latestHeight -notmatch '^\d+$') {
        [void]$reasons.Add("height-unreadable")
    }
    if ([int]$Facts.stateFileLastWriteAgeSeconds -gt $MaxStateAgeSeconds) {
        [void]$reasons.Add("state-file-stale")
    }
    if (-not $NonLiveProfile.IsPresent -and ([bool]$Facts.liveProfile -ne $true -or [int]$Facts.maxBlocks -ne 0)) {
        [void]$reasons.Add("not-live-profile")
    }
    return @($reasons)
}

function Write-SupervisorReport {
    param(
        [Parameter(Mandatory = $true)][string] $Status,
        [Parameter(Mandatory = $true)][object[]] $Iterations,
        [Parameter(Mandatory = $true)][int] $RestartAttempts
    )

    $report = [ordered]@{
        schema = "flowchain.service_supervisor_report.v0"
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        status = $Status
        once = [bool]$Once
        dryRun = [bool]$DryRun
        liveProfile = -not $NonLiveProfile.IsPresent
        intervalSeconds = $IntervalSeconds
        maxRestartAttempts = $MaxRestartAttempts
        restartAttempts = $RestartAttempts
        maxStateAgeSeconds = $MaxStateAgeSeconds
        statePath = $StatePath
        nodeDir = $NodeDir
        servicesDir = $ServicesDir
        controlPlane = [ordered]@{
            host = $ControlPlaneHost
            port = $ControlPlanePort
        }
        reportPaths = [ordered]@{
            supervisor = $reportFullPath
            status = $statusReportFullPath
            restart = $restartReportFullPath
            stop = $stopReportFullPath
        }
        iterations = @($Iterations)
        envValuesPrinted = $false
        noSecrets = $true
        broadcasts = $false
    }
    $reportText = $report | ConvertTo-Json -Depth 20
    Assert-FlowChainNoSecretText -Text $reportText -Label "service supervisor report"
    Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20
}

$restartAttempts = 0
$iterations = New-Object System.Collections.ArrayList
$finalStatus = "watching"

while ($true) {
    $sampledAt = (Get-Date).ToUniversalTime().ToString("o")
    $before = Invoke-SupervisorStatus
    $reasons = @(Get-RestartReasons -Facts $before)
    $restartResult = $null
    $after = $before
    $restartPerformed = $false

    if ($reasons.Count -gt 0) {
        if ($DryRun.IsPresent) {
            $finalStatus = "blocked"
        }
        elseif ($restartAttempts -ge $MaxRestartAttempts) {
            $finalStatus = "failed"
        }
        else {
            $restartAttempts += 1
            $restartArgs = @(
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
                "$BlockMs",
                "-MaxBlocks",
                "0",
                "-ReportPath",
                $restartReportFullPath,
                "-StopReportPath",
                $stopReportFullPath
            )
            if (-not $NonLiveProfile.IsPresent) {
                $restartArgs += "-LiveProfile"
            }
            if ($StartBridgeRelayerLoop.IsPresent) {
                $restartArgs += "-StartBridgeRelayerLoop"
            }
            $restartResult = Invoke-SupervisorChild -ArgumentList $restartArgs
            $restartPerformed = ([int]$restartResult.exitCode -eq 0)
            $after = Invoke-SupervisorStatus
            $afterReasons = @(Get-RestartReasons -Facts $after)
            $finalStatus = if ($restartPerformed -and $afterReasons.Count -eq 0) { "passed" } else { "failed" }
        }
    }
    else {
        $finalStatus = if ($Once.IsPresent) { "passed" } else { "watching" }
    }

    $restartSummary = if ($null -ne $restartResult) {
        [ordered]@{
            exitCode = [int]$restartResult.exitCode
            stdoutPath = [string]$restartResult.stdoutPath
            stderrPath = [string]$restartResult.stderrPath
        }
    }
    else {
        $null
    }
    [void]$iterations.Add([ordered]@{
        sampledAt = $sampledAt
        restartReasons = @($reasons)
        restartNeeded = ($reasons.Count -gt 0)
        restartPerformed = $restartPerformed
        before = [ordered]@{
            exitCode = [int]$before.exitCode
            reportStatus = [string]$before.reportStatus
            nodeStatus = [string]$before.nodeStatus
            controlPlaneStatus = [string]$before.controlPlaneStatus
            latestHeight = [string]$before.latestHeight
            finalizedHeight = [string]$before.finalizedHeight
            stateFileLastWriteAgeSeconds = [int]$before.stateFileLastWriteAgeSeconds
            liveProfile = [bool]$before.liveProfile
            maxBlocks = [int]$before.maxBlocks
        }
        restart = $restartSummary
        after = [ordered]@{
            exitCode = [int]$after.exitCode
            reportStatus = [string]$after.reportStatus
            nodeStatus = [string]$after.nodeStatus
            controlPlaneStatus = [string]$after.controlPlaneStatus
            latestHeight = [string]$after.latestHeight
            finalizedHeight = [string]$after.finalizedHeight
            stateFileLastWriteAgeSeconds = [int]$after.stateFileLastWriteAgeSeconds
            liveProfile = [bool]$after.liveProfile
            maxBlocks = [int]$after.maxBlocks
        }
    })
    Write-SupervisorReport -Status $finalStatus -Iterations @($iterations) -RestartAttempts $restartAttempts

    if ($Once.IsPresent -or $finalStatus -eq "failed") {
        break
    }
    Start-Sleep -Seconds $IntervalSeconds
}

Write-Host "FlowChain service supervisor status: $finalStatus"
Write-Host "Restart attempts: $restartAttempts"
Write-Host "Report: $reportFullPath"
if ($finalStatus -eq "failed") {
    exit 1
}
exit 0
