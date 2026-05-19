param(
    [ValidateSet("Plan", "Install", "Status", "Uninstall")]
    [string] $Action = "Plan",
    [string] $TaskName = "FlowChainStateBackup",
    [string] $RestoreDrillTaskName = "FlowChainStateRestoreDrill",
    [string] $TaskPath = "\",
    [string] $At = "03:00",
    [string] $RestoreDrillAt = "03:15",
    [string] $StatePath = "devnet/local/state.json",
    [string] $BackupReportPath = "docs/agent-runs/live-product-infra-rpc/scheduled-state-backup-report.json",
    [string] $RestoreDrillReportPath = "docs/agent-runs/live-product-infra-rpc/scheduled-state-restore-verify-report.json",
    [string] $RestoreDrillRestoreRoot = "devnet/local/restore-rehearsal/scheduled",
    [int] $RetentionCount = 14,
    [string] $OwnerEnvFile = "",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/backup-install-windows-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/WINDOWS_BACKUP_INSTALL.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$backupScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-state-backup.ps1")
$restoreDrillScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-state-restore-verify.ps1")
[void](Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath))
[void](Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $BackupReportPath))
[void](Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $RestoreDrillReportPath))
[void](Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $RestoreDrillRestoreRoot))

foreach ($nameToValidate in @($TaskName, $RestoreDrillTaskName)) {
    if ($nameToValidate -notmatch '^[A-Za-z0-9_. -]{1,120}$') {
        throw "TaskName values must contain only letters, numbers, spaces, dots, underscores, or hyphens."
    }
}
if ($TaskName -eq $RestoreDrillTaskName) {
    throw "TaskName and RestoreDrillTaskName must be distinct."
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
if ($At -notmatch '^(?:[01][0-9]|2[0-3]):[0-5][0-9]$') {
    throw "At must use HH:mm 24-hour time."
}
if ($RestoreDrillAt -notmatch '^(?:[01][0-9]|2[0-3]):[0-5][0-9]$') {
    throw "RestoreDrillAt must use HH:mm 24-hour time."
}
if ($RetentionCount -lt 1) {
    throw "RetentionCount must be at least 1."
}

function Get-BackupInstallCommandStatus {
    param([Parameter(Mandatory = $true)][string[]] $Names)

    return @($Names | ForEach-Object {
        $command = Get-Command $_ -ErrorAction SilentlyContinue
        [ordered]@{
            name = $_
            available = $null -ne $command
        }
    })
}

function Get-BackupTaskSnapshot {
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

function Get-BackupPackageCommand {
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

function New-BackupInstallTaskArguments {
    param(
        [Parameter(Mandatory = $true)][string] $ScriptPath,
        [Parameter(Mandatory = $true)][string[]] $ScriptArguments,
        [string] $OwnerEnvFile = ""
    )

    if ([string]::IsNullOrWhiteSpace($OwnerEnvFile)) {
        return (Join-FlowChainProcessArguments -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            $ScriptPath
        )) + " " + (Join-FlowChainProcessArguments -ArgumentList $ScriptArguments)
    }

    $escapedOwnerEnvFile = $OwnerEnvFile.Replace("'", "''")
    $escapedScriptPath = $ScriptPath.Replace("'", "''")
    $inner = "`$env:FLOWCHAIN_OWNER_ENV_FILE='$escapedOwnerEnvFile'; & '$escapedScriptPath' $(Join-FlowChainProcessArguments -ArgumentList $ScriptArguments)"
    return Join-FlowChainProcessArguments -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        $inner
    )
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
$schedulerCmdlets = @(Get-BackupInstallCommandStatus -Names $requiredSchedulerCmdlets)
$schedulerCmdletsAvailable = @($schedulerCmdlets | Where-Object { $_.available -ne $true }).Count -eq 0
$actionCommand = Get-Command "New-ScheduledTaskAction" -ErrorAction SilentlyContinue
$scheduledTaskActionSupportsWorkingDirectory = $null -ne $actionCommand -and $actionCommand.Parameters.Keys -contains "WorkingDirectory"
$powershellCommand = Get-Command "powershell.exe" -ErrorAction SilentlyContinue
$powershellExecutable = if ($null -ne $powershellCommand) { [string]$powershellCommand.Source } else { "powershell.exe" }

$backupScriptArguments = @(
    "-StatePath",
    $StatePath,
    "-ReportPath",
    $BackupReportPath,
    "-RetentionCount",
    "$RetentionCount"
)

$restoreDrillScriptArguments = @(
    "-ReportPath",
    $RestoreDrillReportPath,
    "-RestoreRoot",
    $RestoreDrillRestoreRoot,
    "-StatePath",
    $StatePath
)

$scheduledTaskArguments = New-BackupInstallTaskArguments -ScriptPath $backupScriptPath -ScriptArguments $backupScriptArguments -OwnerEnvFile $OwnerEnvFile
$restoreDrillTaskArguments = New-BackupInstallTaskArguments -ScriptPath $restoreDrillScriptPath -ScriptArguments $restoreDrillScriptArguments -OwnerEnvFile $OwnerEnvFile

$commands = [ordered]@{
    plan = Get-BackupPackageCommand -ScriptName "flowchain:backup:install:windows" -Extra "-Action Plan"
    validate = Get-BackupPackageCommand -ScriptName "flowchain:backup:install:validate"
    install = Get-BackupPackageCommand -ScriptName "flowchain:backup:install:windows" -Extra "-Action Install"
    status = Get-BackupPackageCommand -ScriptName "flowchain:backup:install:windows" -Extra "-Action Status"
    uninstall = Get-BackupPackageCommand -ScriptName "flowchain:backup:install:windows" -Extra "-Action Uninstall"
    backupCheck = Get-BackupPackageCommand -ScriptName "flowchain:backup:check" -Extra "-AllowBlocked"
}

$taskBefore = Get-BackupTaskSnapshot -Name $TaskName -Path $TaskPath -SchedulerAvailable $schedulerCmdletsAvailable
$restoreDrillTaskBefore = Get-BackupTaskSnapshot -Name $RestoreDrillTaskName -Path $TaskPath -SchedulerAvailable $schedulerCmdletsAvailable
$actionError = ""
$taskRegistered = $false
$restoreDrillTaskRegistered = $false
$taskRemoved = $false
$restoreDrillTaskRemoved = $false
$taskMutationPerformed = $Action -in @("Install", "Uninstall")

try {
    switch ($Action) {
        "Install" {
            if (-not $schedulerCmdletsAvailable) {
                throw "ScheduledTasks cmdlets are required for install."
            }
            if (-not $scheduledTaskActionSupportsWorkingDirectory) {
                throw "New-ScheduledTaskAction must support WorkingDirectory so the backup script can resolve the repository root."
            }
            $time = [datetime]::ParseExact($At, "HH:mm", [System.Globalization.CultureInfo]::InvariantCulture)
            $triggerAt = [datetime]::Today.AddHours($time.Hour).AddMinutes($time.Minute)
            $restoreTime = [datetime]::ParseExact($RestoreDrillAt, "HH:mm", [System.Globalization.CultureInfo]::InvariantCulture)
            $restoreTriggerAt = [datetime]::Today.AddHours($restoreTime.Hour).AddMinutes($restoreTime.Minute)
            $taskAction = New-ScheduledTaskAction -Execute $powershellExecutable -Argument $scheduledTaskArguments -WorkingDirectory $repoRoot
            $restoreDrillTaskAction = New-ScheduledTaskAction -Execute $powershellExecutable -Argument $restoreDrillTaskArguments -WorkingDirectory $repoRoot
            $trigger = New-ScheduledTaskTrigger -Daily -At $triggerAt
            $restoreDrillTrigger = New-ScheduledTaskTrigger -Daily -At $restoreTriggerAt
            $settings = New-ScheduledTaskSettingsSet `
                -StartWhenAvailable `
                -AllowStartIfOnBatteries `
                -DontStopIfGoingOnBatteries `
                -MultipleInstances IgnoreNew `
                -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
            Register-ScheduledTask `
                -TaskName $TaskName `
                -TaskPath $TaskPath `
                -Action $taskAction `
                -Trigger $trigger `
                -Settings $settings `
                -Description "FlowChain live L1 state backup. Creates manifest-backed snapshots for restore rehearsal." `
                -Force | Out-Null
            $taskRegistered = $true
            Register-ScheduledTask `
                -TaskName $RestoreDrillTaskName `
                -TaskPath $TaskPath `
                -Action $restoreDrillTaskAction `
                -Trigger $restoreDrillTrigger `
                -Settings $settings `
                -Description "FlowChain live L1 restore drill. Verifies the latest manifest-backed state backup without mutating live state." `
                -Force | Out-Null
            $restoreDrillTaskRegistered = $true
        }
        "Uninstall" {
            if (-not $schedulerCmdletsAvailable) {
                throw "ScheduledTasks cmdlets are required for uninstall."
            }
            if ($taskBefore.exists -eq $true) {
                Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Confirm:$false
                $taskRemoved = $true
            }
            if ($restoreDrillTaskBefore.exists -eq $true) {
                Unregister-ScheduledTask -TaskName $RestoreDrillTaskName -TaskPath $TaskPath -Confirm:$false
                $restoreDrillTaskRemoved = $true
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

$taskAfter = Get-BackupTaskSnapshot -Name $TaskName -Path $TaskPath -SchedulerAvailable $schedulerCmdletsAvailable
$restoreDrillTaskAfter = Get-BackupTaskSnapshot -Name $RestoreDrillTaskName -Path $TaskPath -SchedulerAvailable $schedulerCmdletsAvailable
$checks = [ordered]@{
    backupScriptExists = Test-Path -LiteralPath $backupScriptPath
    restoreDrillScriptExists = Test-Path -LiteralPath $restoreDrillScriptPath
    schedulerCmdletsAvailable = $schedulerCmdletsAvailable
    scheduledTaskActionSupportsWorkingDirectory = $scheduledTaskActionSupportsWorkingDirectory
    taskNamesDistinct = $TaskName -ne $RestoreDrillTaskName
    retentionCountValid = $RetentionCount -ge 1
    actionUsesBackupScript = $scheduledTaskArguments.Contains("flowchain-state-backup.ps1")
    actionUsesRetentionCount = $scheduledTaskArguments.Contains("-RetentionCount")
    actionUsesRepoWorkingDirectory = $true
    hasStatePath = $scheduledTaskArguments.Contains("-StatePath")
    hasReportPath = $scheduledTaskArguments.Contains("-ReportPath")
    restoreDrillUsesRestoreScript = $restoreDrillTaskArguments.Contains("flowchain-state-restore-verify.ps1")
    restoreDrillUsesRepoWorkingDirectory = $true
    restoreDrillHasRestoreRoot = $restoreDrillTaskArguments.Contains("-RestoreRoot")
    restoreDrillHasStatePath = $restoreDrillTaskArguments.Contains("-StatePath")
    restoreDrillHasReportPath = $restoreDrillTaskArguments.Contains("-ReportPath")
    reliesOnOwnerBackupEnv = $scheduledTaskArguments.Contains("FLOWCHAIN_RPC_STATE_BACKUP_PATH") -eq $false
    restoreDrillReliesOnOwnerBackupEnv = $restoreDrillTaskArguments.Contains("FLOWCHAIN_RPC_STATE_BACKUP_PATH") -eq $false
    ownerEnvFileCanBeInjected = $true
    installStatusUninstallCommandsPresent = -not [string]::IsNullOrWhiteSpace($commands.install) -and -not [string]::IsNullOrWhiteSpace($commands.status) -and -not [string]::IsNullOrWhiteSpace($commands.uninstall)
    planDoesNotMutate = if ($Action -eq "Plan") { -not $taskMutationPerformed } else { $null }
    envValuesPrintedFalse = $true
    noSecrets = $true
}

$baseReady = ($checks.backupScriptExists -eq $true) `
    -and ($checks.restoreDrillScriptExists -eq $true) `
    -and ($checks.schedulerCmdletsAvailable -eq $true) `
    -and ($checks.scheduledTaskActionSupportsWorkingDirectory -eq $true) `
    -and ($checks.taskNamesDistinct -eq $true) `
    -and ($checks.retentionCountValid -eq $true) `
    -and ($checks.actionUsesBackupScript -eq $true) `
    -and ($checks.actionUsesRetentionCount -eq $true) `
    -and ($checks.hasStatePath -eq $true) `
    -and ($checks.hasReportPath -eq $true) `
    -and ($checks.restoreDrillUsesRestoreScript -eq $true) `
    -and ($checks.restoreDrillHasRestoreRoot -eq $true) `
    -and ($checks.restoreDrillHasStatePath -eq $true) `
    -and ($checks.restoreDrillHasReportPath -eq $true) `
    -and ($checks.installStatusUninstallCommandsPresent -eq $true)

if (-not [string]::IsNullOrWhiteSpace($actionError)) {
    $status = "failed"
}
elseif (($Action -eq "Plan" -or $Action -eq "Status") -and $baseReady) {
    $status = "passed"
}
elseif ($Action -eq "Install" -and $baseReady -and $taskAfter.exists -eq $true -and $restoreDrillTaskAfter.exists -eq $true -and $taskRegistered -eq $true -and $restoreDrillTaskRegistered -eq $true) {
    $status = "passed"
}
elseif ($Action -eq "Uninstall" -and $baseReady -and $taskAfter.exists -eq $false -and $restoreDrillTaskAfter.exists -eq $false) {
    $status = "passed"
}
elseif (-not $schedulerCmdletsAvailable -or -not $scheduledTaskActionSupportsWorkingDirectory) {
    $status = "blocked"
}
else {
    $status = "failed"
}

$report = [ordered]@{
    schema = "flowchain.backup_install_windows_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    action = $Action
    plannedOnly = $Action -eq "Plan"
    taskMutationPerformed = $taskMutationPerformed
    taskRegistered = $taskRegistered
    restoreDrillTaskRegistered = $restoreDrillTaskRegistered
    taskRemoved = $taskRemoved
    restoreDrillTaskRemoved = $restoreDrillTaskRemoved
    taskName = $TaskName
    restoreDrillTaskName = $RestoreDrillTaskName
    taskPath = $TaskPath
    dailyAt = $At
    restoreDrillDailyAt = $RestoreDrillAt
    taskBefore = $taskBefore
    restoreDrillTaskBefore = $restoreDrillTaskBefore
    taskAfter = $taskAfter
    restoreDrillTaskAfter = $restoreDrillTaskAfter
    schedulerCmdlets = $schedulerCmdlets
    scheduledTask = [ordered]@{
        trigger = "Daily"
        dailyAt = $At
        execute = $powershellExecutable
        arguments = $scheduledTaskArguments
        workingDirectory = $repoRoot
        backupScript = $backupScriptPath
        ownerEnvFileConfigured = -not [string]::IsNullOrWhiteSpace($OwnerEnvFile)
    }
    restoreDrillScheduledTask = [ordered]@{
        trigger = "Daily"
        dailyAt = $RestoreDrillAt
        execute = $powershellExecutable
        arguments = $restoreDrillTaskArguments
        workingDirectory = $repoRoot
        restoreScript = $restoreDrillScriptPath
        ownerEnvFileConfigured = -not [string]::IsNullOrWhiteSpace($OwnerEnvFile)
    }
    backup = [ordered]@{
        statePath = $StatePath
        reportPath = $BackupReportPath
        retentionCount = $RetentionCount
        requiredEnvNames = @("FLOWCHAIN_RPC_STATE_BACKUP_PATH")
    }
    restoreDrill = [ordered]@{
        restoreRoot = $RestoreDrillRestoreRoot
        reportPath = $RestoreDrillReportPath
        requiredEnvNames = @("FLOWCHAIN_RPC_STATE_BACKUP_PATH")
    }
    commands = $commands
    checks = $checks
    actionErrorRedacted = $actionError
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$reportText = $report | ConvertTo-Json -Depth 20
Assert-FlowChainNoSecretText -Text $reportText -Label "Windows backup install report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Windows Backup Install")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Action: $Action")
$markdownLines.Add("Backup task: $TaskPath$TaskName")
$markdownLines.Add("Restore drill task: $TaskPath$RestoreDrillTaskName")
$markdownLines.Add("")
$markdownLines.Add("This runbook registers Windows Scheduled Tasks that run the manifest-backed state backup command every day, rotate old snapshots by retention count, and run a recurring restore drill against the latest snapshot. The tasks require `FLOWCHAIN_RPC_STATE_BACKUP_PATH` from the owner process environment or from `FLOWCHAIN_OWNER_ENV_FILE`.")
$markdownLines.Add("")
$markdownLines.Add("## Commands")
$markdownLines.Add("")
$markdownLines.Add("- Plan: $($commands.plan)")
$markdownLines.Add("- Validate: $($commands.validate)")
$markdownLines.Add("- Install: $($commands.install)")
$markdownLines.Add("- Status: $($commands.status)")
$markdownLines.Add("- Uninstall: $($commands.uninstall)")
$markdownLines.Add("- Backup check: $($commands.backupCheck)")
$markdownLines.Add("")
$markdownLines.Add("## Scheduled Task Action")
$markdownLines.Add("")
$markdownLines.Add("- Execute: ``$powershellExecutable``")
$markdownLines.Add("- Working directory: ``$repoRoot``")
$markdownLines.Add("- Backup script: ``$backupScriptPath``")
$markdownLines.Add("- Daily time: $At")
$markdownLines.Add("- Retention count: $RetentionCount")
$markdownLines.Add("- Restore drill script: ``$restoreDrillScriptPath``")
$markdownLines.Add("- Restore drill daily time: $RestoreDrillAt")
$markdownLines.Add("- Owner env file injected: $(-not [string]::IsNullOrWhiteSpace($OwnerEnvFile))")
$markdownLines.Add("")
$markdownLines.Add("## Status")
$markdownLines.Add("")
$markdownLines.Add("- Task existed before: $($taskBefore.exists)")
$markdownLines.Add("- Task exists after: $($taskAfter.exists)")
$markdownLines.Add("- Restore drill task existed before: $($restoreDrillTaskBefore.exists)")
$markdownLines.Add("- Restore drill task exists after: $($restoreDrillTaskAfter.exists)")
$markdownLines.Add("- Scheduler cmdlets available: $schedulerCmdletsAvailable")
$markdownLines.Add("- WorkingDirectory supported: $scheduledTaskActionSupportsWorkingDirectory")
if (-not [string]::IsNullOrWhiteSpace($actionError)) {
    $markdownLines.Add("- Action error: $actionError")
}

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "Windows backup install markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain Windows backup install status: $status"
Write-Host "Action: $Action"
Write-Host "Backup task: $TaskPath$TaskName"
Write-Host "Restore drill task: $TaskPath$RestoreDrillTaskName"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    exit 1
}
exit 0
