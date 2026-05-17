param(
    [string] $StatePath = "devnet/local/bridge-relayer-loop-validation/state.json",
    [string] $NodeDir = "devnet/local/bridge-relayer-loop-validation/node",
    [string] $ServicesDir = "devnet/local/bridge-relayer-loop-validation/services",
    [string] $ControlPlaneHost = "127.0.0.1",
    [int] $ControlPlanePort = 8798,
    [int] $BlockMs = 1000,
    [int] $BridgePollSeconds = 5,
    [int] $SettleSeconds = 5,
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-relayer-loop-validation-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/BRIDGE_RELAYER_LOOP_VALIDATION.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$servicesFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ServicesDir)
$startReportPath = Join-Path $servicesFullDir "flowchain-service-start-report.json"
$statusAfterStartPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-loop-status-after-start.json"
$stopReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-loop-stop-report.json"
$statusAfterStopPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-loop-status-after-stop.json"
$cleanupStopReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-loop-cleanup-stop-report.json"
$relayerPidPath = Join-Path $servicesFullDir "bridge-relayer-loop.pid"
$validationTmpDir = Join-Path $repoRoot "devnet/local/tmp/bridge-relayer-loop-validation"
New-Item -ItemType Directory -Force -Path $validationTmpDir | Out-Null

if ($BridgePollSeconds -lt 5) {
    throw "BridgePollSeconds must be at least 5."
}
if ($SettleSeconds -lt 1) {
    throw "SettleSeconds must be at least 1."
}

function Invoke-RelayerLoopValidationChild {
    param(
        [Parameter(Mandatory = $true)][string[]] $ArgumentList,
        [int] $TimeoutSeconds = 240
    )

    $runId = "$(Get-Date -Format 'yyyyMMddHHmmssfff')-$PID-$([System.Guid]::NewGuid().ToString('N').Substring(0, 8))"
    $stdoutPath = Join-Path $validationTmpDir "$runId.stdout.log"
    $stderrPath = Join-Path $validationTmpDir "$runId.stderr.log"
    $exitCode = 1
    $timedOut = $false
    $output = @()

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
            $exitCode = [int]$process.ExitCode
        }
    }
    catch {
        $output += $_.Exception.Message
        $exitCode = 1
    }

    if (Test-Path -LiteralPath $stdoutPath) {
        $output += @(Get-Content -LiteralPath $stdoutPath -Tail 40)
    }
    if (Test-Path -LiteralPath $stderrPath) {
        $output += @(Get-Content -LiteralPath $stderrPath -Tail 40)
    }

    return [ordered]@{
        exitCode = [int]$exitCode
        timedOut = $timedOut
        stdoutPath = $stdoutPath
        stderrPath = $stderrPath
        outputRedacted = @($output | ForEach-Object { "$_" })
    }
}

function Get-RelayerLoopProp {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name,
        [object] $Default = $null
    )

    if ($null -ne $Object -and $Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
    }
    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $Default
}

function ConvertTo-RelayerLoopInt {
    param(
        [AllowNull()][object] $Value,
        [int] $Default = 0
    )

    if ($null -eq $Value) {
        return $Default
    }

    $parsed = 0
    if ([int]::TryParse("$Value", [ref]$parsed)) {
        return $parsed
    }

    return $Default
}

function Test-RelayerLoopValidationCommandLine {
    param([AllowNull()][string] $CommandLine)

    if ([string]::IsNullOrWhiteSpace($CommandLine)) {
        return $false
    }

    return $CommandLine.IndexOf("flowchain-bridge-relayer-once.ps1", [System.StringComparison]::OrdinalIgnoreCase) -ge 0 `
        -and $CommandLine.IndexOf($StatePath, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Get-RelayerLoopProcessProof {
    param([int] $ProcessId)

    $proof = [ordered]@{
        pid = $ProcessId
        processExists = $false
        matchesValidationRelayer = $false
    }

    if ($ProcessId -le 0) {
        return $proof
    }

    $process = $null
    try {
        $process = Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction SilentlyContinue
    }
    catch {
        $process = $null
    }

    if ($null -eq $process) {
        return $proof
    }

    $proof.processExists = $true
    $proof.matchesValidationRelayer = Test-RelayerLoopValidationCommandLine -CommandLine ([string]$process.CommandLine)
    return $proof
}

function Find-RelayerLoopValidationProcesses {
    $matches = New-Object System.Collections.ArrayList
    foreach ($process in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)) {
        if (-not (Test-RelayerLoopValidationCommandLine -CommandLine ([string]$process.CommandLine))) {
            continue
        }
        [void]$matches.Add([ordered]@{
            pid = [int]$process.ProcessId
            validationStatePathMatched = $true
        })
    }

    return @($matches)
}

function Invoke-RelayerLoopStatus {
    param([Parameter(Mandatory = $true)][string] $Path)

    return Invoke-RelayerLoopValidationChild -ArgumentList @(
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
}

function Invoke-RelayerLoopStop {
    param([Parameter(Mandatory = $true)][string] $Path)

    return Invoke-RelayerLoopValidationChild -ArgumentList @(
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
        $Path
    )
}

$steps = New-Object System.Collections.ArrayList
$status = "failed"
$stopAlreadyRequested = $false

try {
    [void]$steps.Add([ordered]@{
        name = "pre-clean-stop"
        result = Invoke-RelayerLoopStop -Path $cleanupStopReportPath
    })

    [void]$steps.Add([ordered]@{
        name = "start-live-service-with-relayer-loop"
        result = Invoke-RelayerLoopValidationChild -ArgumentList @(
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
            "0",
            "-LiveProfile",
            "-StartBridgeRelayerLoop",
            "-BridgePollSeconds",
            "$BridgePollSeconds"
        )
    })

    Start-Sleep -Seconds $SettleSeconds

    [void]$steps.Add([ordered]@{
        name = "status-after-relayer-loop-start"
        result = Invoke-RelayerLoopStatus -Path $statusAfterStartPath
    })

    [void]$steps.Add([ordered]@{
        name = "stop-relayer-loop-service"
        result = Invoke-RelayerLoopStop -Path $stopReportPath
    })
    $stopAlreadyRequested = $true

    Start-Sleep -Seconds 2

    [void]$steps.Add([ordered]@{
        name = "status-after-relayer-loop-stop"
        result = Invoke-RelayerLoopStatus -Path $statusAfterStopPath
    })

    $startStep = @($steps | Where-Object { $_.name -eq "start-live-service-with-relayer-loop" } | Select-Object -First 1)
    $statusStep = @($steps | Where-Object { $_.name -eq "status-after-relayer-loop-start" } | Select-Object -First 1)
    $stopStep = @($steps | Where-Object { $_.name -eq "stop-relayer-loop-service" } | Select-Object -First 1)
    $statusAfterStopStep = @($steps | Where-Object { $_.name -eq "status-after-relayer-loop-stop" } | Select-Object -First 1)

    $startReport = Read-FlowChainJsonIfExists -Path $startReportPath
    $statusAfterStart = Read-FlowChainJsonIfExists -Path $statusAfterStartPath
    $stopReport = Read-FlowChainJsonIfExists -Path $stopReportPath
    $statusAfterStop = Read-FlowChainJsonIfExists -Path $statusAfterStopPath
    $startRelayer = Get-RelayerLoopProp -Object $startReport -Name "bridgeRelayerLoop"
    $statusRelayer = Get-RelayerLoopProp -Object $statusAfterStart -Name "bridgeRelayerLoop"
    $stopRelayer = Get-RelayerLoopProp -Object $stopReport -Name "bridgeRelayerLoop" -Default ""
    $statusAfterStopRelayer = Get-RelayerLoopProp -Object $statusAfterStop -Name "bridgeRelayerLoop"
    $statusRelayerReport = Get-RelayerLoopProp -Object $statusRelayer -Name "report"
    $stopPidFiles = Get-RelayerLoopProp -Object $stopReport -Name "pidFiles"
    $relayerPidBeforeStop = ConvertTo-RelayerLoopInt -Value (Get-RelayerLoopProp -Object $startRelayer -Name "pid" -Default 0)
    if ($relayerPidBeforeStop -le 0) {
        $relayerPidBeforeStop = ConvertTo-RelayerLoopInt -Value (Get-RelayerLoopProp -Object $statusRelayer -Name "pid" -Default 0)
    }
    $relayerPidProofAfterStop = Get-RelayerLoopProcessProof -ProcessId $relayerPidBeforeStop
    $validationRelayerProcessesAfterStop = @(Find-RelayerLoopValidationProcesses)
    $relayerPidFileExistsAfterStop = Test-Path -LiteralPath $relayerPidPath

    $checks = [ordered]@{
        startCommandPassed = [int]$startStep[0].result.exitCode -eq 0
        startReportWritten = $null -ne $startReport
        liveProfile = (Get-RelayerLoopProp -Object $startReport -Name "liveProfile" -Default $false) -eq $true
        relayerLoopRequested = (Get-RelayerLoopProp -Object $startRelayer -Name "requested" -Default $false) -eq $true
        relayerLoopStartedOrRunning = ((Get-RelayerLoopProp -Object $startRelayer -Name "startedThisRun" -Default $false) -eq $true) -or ((Get-RelayerLoopProp -Object $startRelayer -Name "running" -Default $false) -eq $true)
        relayerPidRecorded = [int](Get-RelayerLoopProp -Object $startRelayer -Name "pid" -Default 0) -gt 0
        relayerPollSecondsRecorded = [int](Get-RelayerLoopProp -Object $startRelayer -Name "pollSeconds" -Default 0) -eq $BridgePollSeconds
        relayerQueuesRuntimeHandoffs = (Get-RelayerLoopProp -Object $startRelayer -Name "queuesRuntimeHandoffs" -Default $false) -eq $true
        statusCommandPassed = [int]$statusStep[0].result.exitCode -eq 0
        statusReportsRelayerRunning = [string](Get-RelayerLoopProp -Object $statusRelayer -Name "status" -Default "") -eq "running"
        statusRelayerCommandLineMatched = (Get-RelayerLoopProp -Object $statusRelayer -Name "commandLineMatched" -Default $false) -eq $true
        statusRelayerReportFresh = (Get-RelayerLoopProp -Object $statusRelayerReport -Name "fresh" -Default $false) -eq $true
        statusRelayerReportAcceptable = (Get-RelayerLoopProp -Object $statusRelayerReport -Name "acceptableStatus" -Default $false) -eq $true
        statusRelayerReportBlockedOnlyOnOwnerInputs = (Get-RelayerLoopProp -Object $statusRelayerReport -Name "blockedOnlyOnOwnerInputs" -Default $false) -eq $true
        statusRelayerReportNoSecrets = (Get-RelayerLoopProp -Object $statusRelayerReport -Name "noSecrets" -Default $false) -eq $true
        statusRelayerReportNoBroadcasts = (Get-RelayerLoopProp -Object $statusRelayerReport -Name "noBroadcasts" -Default $false) -eq $true
        statusRelayerReportHealthy = (Get-RelayerLoopProp -Object $statusRelayerReport -Name "healthy" -Default $false) -eq $true
        stopCommandPassed = [int]$stopStep[0].result.exitCode -eq 0
        stopPreservedState = (Get-RelayerLoopProp -Object $stopReport -Name "statePreserved" -Default $false) -eq $true
        stopHandledRelayerLoop = [string]$stopRelayer -in @("stopped", "not-running")
        statusAfterStopCommandPassed = [int]$statusAfterStopStep[0].result.exitCode -eq 0
        statusAfterStopNotRunning = [string](Get-RelayerLoopProp -Object $statusAfterStopRelayer -Name "status" -Default "stopped") -ne "running"
        relayerPidNoLongerMatchesAfterStop = $relayerPidBeforeStop -gt 0 -and ((Get-RelayerLoopProp -Object $relayerPidProofAfterStop -Name "matchesValidationRelayer" -Default $true) -eq $false)
        relayerPidFileRemovedAfterStop = -not $relayerPidFileExistsAfterStop
        stopReportRelayerPidFileRemoved = (Get-RelayerLoopProp -Object $stopPidFiles -Name "bridgeRelayerLoopExistsAfterStop" -Default $true) -eq $false
        noValidationRelayerProcessAfterStop = $validationRelayerProcessesAfterStop.Count -eq 0
        envValuesPrintedFalse = $true
        noSecrets = $true
        broadcastsFalse = $true
    }
    $failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
    $status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }

    $stepSummaries = @($steps | ForEach-Object {
        [ordered]@{
            name = [string]$_.name
            exitCode = [int]$_.result.exitCode
            timedOut = [bool]$_.result.timedOut
            stdoutPath = [string]$_.result.stdoutPath
            stderrPath = [string]$_.result.stderrPath
        }
    })

    $report = [ordered]@{
        schema = "flowchain.bridge_relayer_loop_validation_report.v0"
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        status = $status
        statePath = $StatePath
        nodeDir = $NodeDir
        servicesDir = $ServicesDir
        controlPlane = [ordered]@{
            host = $ControlPlaneHost
            port = $ControlPlanePort
        }
        bridgePollSeconds = $BridgePollSeconds
        settleSeconds = $SettleSeconds
        checks = $checks
        failedChecks = @($failedChecks)
        reportPaths = [ordered]@{
            validation = $reportFullPath
            start = $startReportPath
            statusAfterStart = $statusAfterStartPath
            stop = $stopReportPath
            statusAfterStop = $statusAfterStopPath
        }
        observed = [ordered]@{
            startRelayerLoop = $startRelayer
            statusRelayerLoop = $statusRelayer
            stopRelayerLoop = $stopRelayer
            statusAfterStopRelayerLoop = $statusAfterStopRelayer
            relayerPidBeforeStop = $relayerPidBeforeStop
            relayerPidProofAfterStop = $relayerPidProofAfterStop
            relayerPidFile = [ordered]@{
                path = (Join-Path $ServicesDir "bridge-relayer-loop.pid")
                existsAfterStop = $relayerPidFileExistsAfterStop
                stopReportExistsAfterStop = Get-RelayerLoopProp -Object $stopPidFiles -Name "bridgeRelayerLoopExistsAfterStop"
            }
            validationRelayerProcessCountAfterStop = $validationRelayerProcessesAfterStop.Count
            validationRelayerProcessesAfterStop = @($validationRelayerProcessesAfterStop)
        }
        commands = [ordered]@{
            validate = "npm run flowchain:bridge:relayer:loop:validate"
            start = "npm run flowchain:service:start -- -LiveProfile -StartBridgeRelayerLoop"
            status = "npm run flowchain:service:status -- -AllowBlocked"
            stop = "npm run flowchain:service:stop"
        }
        steps = @($stepSummaries)
        envValuesPrinted = $false
        noSecrets = $true
        broadcasts = $false
    }
    $reportText = $report | ConvertTo-Json -Depth 20
    Assert-FlowChainNoSecretText -Text $reportText -Label "bridge relayer loop validation report"
    Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20

    $markdownLines = New-Object System.Collections.Generic.List[string]
    $markdownLines.Add("# FlowChain Bridge Relayer Loop Validation")
    $markdownLines.Add("")
    $markdownLines.Add("Generated: $($report.generatedAt)")
    $markdownLines.Add("Status: $status")
    $markdownLines.Add("")
    $markdownLines.Add("This validation starts an isolated live service with the bridge relayer loop enabled, verifies the loop is reported as running, then stops the service and confirms the relayer loop is not left running, its PID file is removed, and no validation relayer process remains.")
    $markdownLines.Add("")
    $markdownLines.Add("## Checks")
    $markdownLines.Add("")
    foreach ($entry in $checks.GetEnumerator()) {
        $markdownLines.Add("- $($entry.Key): $($entry.Value)")
    }
    $markdownLines.Add("")
    $markdownLines.Add("## Commands")
    $markdownLines.Add("")
    foreach ($entry in $report.commands.GetEnumerator()) {
        $markdownLines.Add("- $($entry.Key): $($entry.Value)")
    }
    if ($failedChecks.Count -gt 0) {
        $markdownLines.Add("")
        $markdownLines.Add("## Failed Checks")
        $markdownLines.Add("")
        foreach ($name in $failedChecks) {
            $markdownLines.Add("- $name")
        }
    }
    $markdownText = $markdownLines -join "`r`n"
    Assert-FlowChainNoSecretText -Text $markdownText -Label "bridge relayer loop validation markdown"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
    Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8
}
finally {
    if (-not $stopAlreadyRequested) {
        Invoke-RelayerLoopStop -Path $cleanupStopReportPath | Out-Null
    }
}

Write-Host "FlowChain bridge relayer loop validation status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    exit 1
}
exit 0
