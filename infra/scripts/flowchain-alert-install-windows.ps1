param(
    [ValidateSet("Plan", "Install", "Status", "Uninstall")]
    [string] $Action = "Plan",
    [string] $TaskName = "FlowChainOpsAlerts",
    [string] $TaskPath = "\",
    [int] $IntervalMinutes = 15,
    [string] $AlertReportPath = "docs/agent-runs/live-product-infra-rpc/scheduled-ops-alert-rules-report.json",
    [string] $AlertMarkdownPath = "docs/agent-runs/live-product-infra-rpc/SCHEDULED_OPS_ALERT_RULES.md",
    [string] $SnapshotReportPath = "docs/agent-runs/live-product-infra-rpc/scheduled-ops-snapshot-report.json",
    [string] $OwnerEnvFile = "",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/alert-install-windows-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/WINDOWS_ALERT_INSTALL.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$alertsScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-ops-alerts.ps1")
[void](Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $AlertReportPath))
[void](Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $AlertMarkdownPath))
[void](Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $SnapshotReportPath))

if ($TaskName -notmatch '^[A-Za-z0-9_. -]{1,120}$') {
    throw "TaskName must contain only letters, numbers, spaces, dots, underscores, or hyphens."
}
if ([string]::IsNullOrWhiteSpace($TaskPath)) {
    $TaskPath = "\"
}
if (-not $TaskPath.StartsWith("\")) {
    $TaskPath = "\$TaskPath"
}
if (-not $TaskPath.EndsWith("\")) {
    $TaskPath = "$TaskPath\"
}
if ($IntervalMinutes -lt 1 -or $IntervalMinutes -gt 1440) {
    throw "IntervalMinutes must be between 1 and 1440."
}

function Get-AlertInstallCommandStatus {
    param([Parameter(Mandatory = $true)][string[]] $Names)

    return @($Names | ForEach-Object {
        $command = Get-Command $_ -ErrorAction SilentlyContinue
        [ordered]@{
            name = $_
            available = $null -ne $command
        }
    })
}

function Get-AlertTaskSnapshot {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][bool] $SchedulerAvailable
    )

    if (-not $SchedulerAvailable) {
        return [ordered]@{
            exists = $false
            schedulerAvailable = $false
            taskName = $Name
            taskPath = $Path
            state = ""
            lastRunTime = ""
            nextRunTime = ""
            lastTaskResult = ""
            queryError = "ScheduledTasks cmdlets are not available."
        }
    }

    $queryError = ""
    $task = $null
    try {
        $task = Get-ScheduledTask -TaskName $Name -TaskPath $Path -ErrorAction SilentlyContinue
    }
    catch {
        $queryError = $_.Exception.Message
    }
    if ($null -eq $task) {
        return [ordered]@{
            exists = $false
            schedulerAvailable = $true
            taskName = $Name
            taskPath = $Path
            state = ""
            lastRunTime = ""
            nextRunTime = ""
            lastTaskResult = ""
            queryError = $queryError
        }
    }

    $info = $null
    try {
        $info = Get-ScheduledTaskInfo -TaskName $Name -TaskPath $Path -ErrorAction SilentlyContinue
    }
    catch {
        if ([string]::IsNullOrWhiteSpace($queryError)) {
            $queryError = $_.Exception.Message
        }
    }

    return [ordered]@{
        exists = $true
        schedulerAvailable = $true
        taskName = [string]$task.TaskName
        taskPath = [string]$task.TaskPath
        state = [string]$task.State
        lastRunTime = if ($null -ne $info) { [string]$info.LastRunTime } else { "" }
        nextRunTime = if ($null -ne $info) { [string]$info.NextRunTime } else { "" }
        lastTaskResult = if ($null -ne $info) { [string]$info.LastTaskResult } else { "" }
        queryError = $queryError
    }
}

function Get-AlertPackageCommand {
    param(
        [Parameter(Mandatory = $true)][string] $ScriptName,
        [string] $Extra = ""
    )

    $command = "npm run $ScriptName"
    if (-not [string]::IsNullOrWhiteSpace($Extra)) {
        $command = "$command -- $Extra"
    }
    return $command
}

$requiredSchedulerCmdlets = @(
    "Get-ScheduledTask",
    "Get-ScheduledTaskInfo",
    "New-ScheduledTaskAction",
    "New-ScheduledTaskTrigger",
    "New-ScheduledTaskSettingsSet",
    "Register-ScheduledTask",
    "Unregister-ScheduledTask"
)
$schedulerCmdlets = @(Get-AlertInstallCommandStatus -Names $requiredSchedulerCmdlets)
$schedulerCmdletsAvailable = @($schedulerCmdlets | Where-Object { $_.available -ne $true }).Count -eq 0
$actionCommand = Get-Command "New-ScheduledTaskAction" -ErrorAction SilentlyContinue
$triggerCommand = Get-Command "New-ScheduledTaskTrigger" -ErrorAction SilentlyContinue
$scheduledTaskActionSupportsWorkingDirectory = $null -ne $actionCommand -and $actionCommand.Parameters.Keys -contains "WorkingDirectory"
$scheduledTaskTriggerSupportsRepetition = $null -ne $triggerCommand -and $triggerCommand.Parameters.Keys -contains "RepetitionInterval" -and $triggerCommand.Parameters.Keys -contains "RepetitionDuration"
$powershellCommand = Get-Command "powershell.exe" -ErrorAction SilentlyContinue
$powershellExecutable = if ($null -ne $powershellCommand) { [string]$powershellCommand.Source } else { "powershell.exe" }

$alertScriptArguments = @(
    "-AllowBlocked",
    "-ReportPath",
    $AlertReportPath,
    "-MarkdownPath",
    $AlertMarkdownPath,
    "-OpsSnapshotPath",
    $SnapshotReportPath
)

if ([string]::IsNullOrWhiteSpace($OwnerEnvFile)) {
    $scheduledTaskArguments = (Join-FlowChainProcessArguments -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $alertsScriptPath
    )) + " " + (Join-FlowChainProcessArguments -ArgumentList $alertScriptArguments)
}
else {
    $escapedOwnerEnvFile = $OwnerEnvFile.Replace("'", "''")
    $escapedAlertsScriptPath = $alertsScriptPath.Replace("'", "''")
    $inner = "`$env:FLOWCHAIN_OWNER_ENV_FILE='$escapedOwnerEnvFile'; & '$escapedAlertsScriptPath' $(Join-FlowChainProcessArguments -ArgumentList $alertScriptArguments)"
    $scheduledTaskArguments = Join-FlowChainProcessArguments -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        $inner
    )
}

$commands = [ordered]@{
    plan = Get-AlertPackageCommand -ScriptName "flowchain:ops:alerts:install:windows" -Extra "-Action Plan"
    validate = Get-AlertPackageCommand -ScriptName "flowchain:ops:alerts:install:validate"
    install = Get-AlertPackageCommand -ScriptName "flowchain:ops:alerts:install:windows" -Extra "-Action Install"
    status = Get-AlertPackageCommand -ScriptName "flowchain:ops:alerts:install:windows" -Extra "-Action Status"
    uninstall = Get-AlertPackageCommand -ScriptName "flowchain:ops:alerts:install:windows" -Extra "-Action Uninstall"
    alerts = Get-AlertPackageCommand -ScriptName "flowchain:ops:alerts" -Extra "-AllowBlocked"
}

$taskBefore = Get-AlertTaskSnapshot -Name $TaskName -Path $TaskPath -SchedulerAvailable $schedulerCmdletsAvailable
$actionError = ""
$taskRegistered = $false
$taskRemoved = $false
$taskMutationPerformed = $Action -in @("Install", "Uninstall")

try {
    switch ($Action) {
        "Install" {
            if (-not $schedulerCmdletsAvailable) {
                throw "ScheduledTasks cmdlets are required for install."
            }
            if (-not $scheduledTaskActionSupportsWorkingDirectory) {
                throw "New-ScheduledTaskAction must support WorkingDirectory so alert refresh can resolve the repository root."
            }
            if (-not $scheduledTaskTriggerSupportsRepetition) {
                throw "New-ScheduledTaskTrigger must support repetition for interval alert checks."
            }
            $taskAction = New-ScheduledTaskAction -Execute $powershellExecutable -Argument $scheduledTaskArguments -WorkingDirectory $repoRoot
            $trigger = New-ScheduledTaskTrigger `
                -Once `
                -At (Get-Date).AddMinutes(1) `
                -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
                -RepetitionDuration (New-TimeSpan -Days 3650)
            $settings = New-ScheduledTaskSettingsSet `
                -StartWhenAvailable `
                -AllowStartIfOnBatteries `
                -DontStopIfGoingOnBatteries `
                -MultipleInstances IgnoreNew `
                -ExecutionTimeLimit (New-TimeSpan -Minutes 20)
            Register-ScheduledTask `
                -TaskName $TaskName `
                -TaskPath $TaskPath `
                -Action $taskAction `
                -Trigger $trigger `
                -Settings $settings `
                -Description "FlowChain live L1 ops alert refresh. Writes no-secret local alert reports on a fixed interval." `
                -Force | Out-Null
            $taskRegistered = $true
        }
        "Uninstall" {
            if (-not $schedulerCmdletsAvailable) {
                throw "ScheduledTasks cmdlets are required for uninstall."
            }
            if ($taskBefore.exists -eq $true) {
                Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Confirm:$false
                $taskRemoved = $true
            }
        }
        "Status" {
        }
        "Plan" {
        }
    }
}
catch {
    $actionError = $_.Exception.Message
}

$taskAfter = Get-AlertTaskSnapshot -Name $TaskName -Path $TaskPath -SchedulerAvailable $schedulerCmdletsAvailable
$checks = [ordered]@{
    alertsScriptExists = Test-Path -LiteralPath $alertsScriptPath
    schedulerCmdletsAvailable = $schedulerCmdletsAvailable
    scheduledTaskActionSupportsWorkingDirectory = $scheduledTaskActionSupportsWorkingDirectory
    scheduledTaskTriggerSupportsRepetition = $scheduledTaskTriggerSupportsRepetition
    actionUsesAlertsScript = $scheduledTaskArguments.Contains("flowchain-ops-alerts.ps1")
    actionUsesRepoWorkingDirectory = $true
    hasAllowBlocked = $scheduledTaskArguments.Contains("-AllowBlocked")
    hasReportPath = $scheduledTaskArguments.Contains("-ReportPath")
    hasMarkdownPath = $scheduledTaskArguments.Contains("-MarkdownPath")
    hasOpsSnapshotPath = $scheduledTaskArguments.Contains("-OpsSnapshotPath")
    intervalMinutesValid = $IntervalMinutes -ge 1 -and $IntervalMinutes -le 1440
    noExternalDelivery = $true
    installStatusUninstallCommandsPresent = -not [string]::IsNullOrWhiteSpace($commands.install) -and -not [string]::IsNullOrWhiteSpace($commands.status) -and -not [string]::IsNullOrWhiteSpace($commands.uninstall)
    planDoesNotMutate = if ($Action -eq "Plan") { -not $taskMutationPerformed } else { $null }
    envValuesPrintedFalse = $true
    noSecrets = $true
}

$baseReady = ($checks.alertsScriptExists -eq $true) `
    -and ($checks.schedulerCmdletsAvailable -eq $true) `
    -and ($checks.scheduledTaskActionSupportsWorkingDirectory -eq $true) `
    -and ($checks.scheduledTaskTriggerSupportsRepetition -eq $true) `
    -and ($checks.actionUsesAlertsScript -eq $true) `
    -and ($checks.hasAllowBlocked -eq $true) `
    -and ($checks.hasReportPath -eq $true) `
    -and ($checks.hasMarkdownPath -eq $true) `
    -and ($checks.hasOpsSnapshotPath -eq $true) `
    -and ($checks.intervalMinutesValid -eq $true) `
    -and ($checks.installStatusUninstallCommandsPresent -eq $true)

if (-not [string]::IsNullOrWhiteSpace($actionError)) {
    $status = "failed"
}
elseif (($Action -eq "Plan" -or $Action -eq "Status") -and $baseReady) {
    $status = "passed"
}
elseif ($Action -eq "Install" -and $baseReady -and $taskAfter.exists -eq $true -and $taskRegistered -eq $true) {
    $status = "passed"
}
elseif ($Action -eq "Uninstall" -and $baseReady -and $taskAfter.exists -eq $false) {
    $status = "passed"
}
elseif (-not $schedulerCmdletsAvailable -or -not $scheduledTaskActionSupportsWorkingDirectory -or -not $scheduledTaskTriggerSupportsRepetition) {
    $status = "blocked"
}
else {
    $status = "failed"
}

$report = [ordered]@{
    schema = "flowchain.alert_install_windows_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    action = $Action
    plannedOnly = $Action -eq "Plan"
    taskMutationPerformed = $taskMutationPerformed
    taskRegistered = $taskRegistered
    taskRemoved = $taskRemoved
    taskName = $TaskName
    taskPath = $TaskPath
    intervalMinutes = $IntervalMinutes
    taskBefore = $taskBefore
    taskAfter = $taskAfter
    schedulerCmdlets = $schedulerCmdlets
    scheduledTask = [ordered]@{
        trigger = "Interval"
        intervalMinutes = $IntervalMinutes
        execute = $powershellExecutable
        arguments = $scheduledTaskArguments
        workingDirectory = $repoRoot
        alertsScript = $alertsScriptPath
        ownerEnvFileConfigured = -not [string]::IsNullOrWhiteSpace($OwnerEnvFile)
        sendsExternalNotifications = $false
    }
    alerts = [ordered]@{
        reportPath = $AlertReportPath
        markdownPath = $AlertMarkdownPath
        opsSnapshotPath = $SnapshotReportPath
    }
    commands = $commands
    checks = $checks
    actionErrorRedacted = $actionError
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$reportText = $report | ConvertTo-Json -Depth 20
Assert-FlowChainNoSecretText -Text $reportText -Label "Windows alert install report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Windows Alert Install")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Action: $Action")
$markdownLines.Add("Task: $TaskPath$TaskName")
$markdownLines.Add("")
$markdownLines.Add("This runbook registers a Windows Scheduled Task that refreshes the no-secret ops snapshot and alert rules on a fixed interval. It writes local reports only and does not store external delivery credentials.")
$markdownLines.Add("")
$markdownLines.Add("## Commands")
$markdownLines.Add("")
$markdownLines.Add("- Plan: $($commands.plan)")
$markdownLines.Add("- Validate: $($commands.validate)")
$markdownLines.Add("- Install: $($commands.install)")
$markdownLines.Add("- Status: $($commands.status)")
$markdownLines.Add("- Uninstall: $($commands.uninstall)")
$markdownLines.Add("- Alerts: $($commands.alerts)")
$markdownLines.Add("")
$markdownLines.Add("## Scheduled Task Action")
$markdownLines.Add("")
$markdownLines.Add("- Execute: ``$powershellExecutable``")
$markdownLines.Add("- Working directory: ``$repoRoot``")
$markdownLines.Add("- Alerts script: ``$alertsScriptPath``")
$markdownLines.Add("- Interval minutes: $IntervalMinutes")
$markdownLines.Add("- Owner env file injected: $(-not [string]::IsNullOrWhiteSpace($OwnerEnvFile))")
$markdownLines.Add("")
$markdownLines.Add("## Status")
$markdownLines.Add("")
$markdownLines.Add("- Task existed before: $($taskBefore.exists)")
$markdownLines.Add("- Task exists after: $($taskAfter.exists)")
$markdownLines.Add("- Scheduler cmdlets available: $schedulerCmdletsAvailable")
$markdownLines.Add("- WorkingDirectory supported: $scheduledTaskActionSupportsWorkingDirectory")
$markdownLines.Add("- Repetition supported: $scheduledTaskTriggerSupportsRepetition")
if (-not [string]::IsNullOrWhiteSpace($actionError)) {
    $markdownLines.Add("- Action error: $actionError")
}

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "Windows alert install markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain Windows alert install status: $status"
Write-Host "Action: $Action"
Write-Host "Task: $TaskPath$TaskName"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    exit 1
}
exit 0
