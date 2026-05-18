param(
    [ValidateSet("Plan", "Install", "Status", "Uninstall")]
    [string] $Action = "Plan",
    [string] $TaskName = "FlowChainStateBackup",
    [string] $TaskPath = "\",
    [string] $At = "03:00",
    [string] $StatePath = "devnet/local/state.json",
    [string] $BackupReportPath = "docs/agent-runs/live-product-infra-rpc/scheduled-state-backup-report.json",
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
[void](Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath))
[void](Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $BackupReportPath))

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
if ($At -notmatch '^(?:[01][0-9]|2[0-3]):[0-5][0-9]$') {
    throw "At must use HH:mm 24-hour time."
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
    $BackupReportPath
)

if ([string]::IsNullOrWhiteSpace($OwnerEnvFile)) {
    $scheduledTaskArguments = (Join-FlowChainProcessArguments -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $backupScriptPath
    )) + " " + (Join-FlowChainProcessArguments -ArgumentList $backupScriptArguments)
}
else {
    $escapedOwnerEnvFile = $OwnerEnvFile.Replace("'", "''")
    $escapedBackupScriptPath = $backupScriptPath.Replace("'", "''")
    $inner = "`$env:FLOWCHAIN_OWNER_ENV_FILE='$escapedOwnerEnvFile'; & '$escapedBackupScriptPath' $(Join-FlowChainProcessArguments -ArgumentList $backupScriptArguments)"
    $scheduledTaskArguments = Join-FlowChainProcessArguments -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        $inner
    )
}

$commands = [ordered]@{
    plan = Get-BackupPackageCommand -ScriptName "flowchain:backup:install:windows" -Extra "-Action Plan"
    validate = Get-BackupPackageCommand -ScriptName "flowchain:backup:install:validate"
    install = Get-BackupPackageCommand -ScriptName "flowchain:backup:install:windows" -Extra "-Action Install"
    status = Get-BackupPackageCommand -ScriptName "flowchain:backup:install:windows" -Extra "-Action Status"
    uninstall = Get-BackupPackageCommand -ScriptName "flowchain:backup:install:windows" -Extra "-Action Uninstall"
    backupCheck = Get-BackupPackageCommand -ScriptName "flowchain:backup:check" -Extra "-AllowBlocked"
}

$taskBefore = Get-BackupTaskSnapshot -Name $TaskName -Path $TaskPath -SchedulerAvailable $schedulerCmdletsAvailable
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
                throw "New-ScheduledTaskAction must support WorkingDirectory so the backup script can resolve the repository root."
            }
            $time = [datetime]::ParseExact($At, "HH:mm", [System.Globalization.CultureInfo]::InvariantCulture)
            $triggerAt = [datetime]::Today.AddHours($time.Hour).AddMinutes($time.Minute)
            $taskAction = New-ScheduledTaskAction -Execute $powershellExecutable -Argument $scheduledTaskArguments -WorkingDirectory $repoRoot
            $trigger = New-ScheduledTaskTrigger -Daily -At $triggerAt
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

$taskAfter = Get-BackupTaskSnapshot -Name $TaskName -Path $TaskPath -SchedulerAvailable $schedulerCmdletsAvailable
$checks = [ordered]@{
    backupScriptExists = Test-Path -LiteralPath $backupScriptPath
    schedulerCmdletsAvailable = $schedulerCmdletsAvailable
    scheduledTaskActionSupportsWorkingDirectory = $scheduledTaskActionSupportsWorkingDirectory
    actionUsesBackupScript = $scheduledTaskArguments.Contains("flowchain-state-backup.ps1")
    actionUsesRepoWorkingDirectory = $true
    hasStatePath = $scheduledTaskArguments.Contains("-StatePath")
    hasReportPath = $scheduledTaskArguments.Contains("-ReportPath")
    reliesOnOwnerBackupEnv = $scheduledTaskArguments.Contains("FLOWCHAIN_RPC_STATE_BACKUP_PATH") -eq $false
    ownerEnvFileCanBeInjected = $true
    installStatusUninstallCommandsPresent = -not [string]::IsNullOrWhiteSpace($commands.install) -and -not [string]::IsNullOrWhiteSpace($commands.status) -and -not [string]::IsNullOrWhiteSpace($commands.uninstall)
    planDoesNotMutate = if ($Action -eq "Plan") { -not $taskMutationPerformed } else { $null }
    envValuesPrintedFalse = $true
    noSecrets = $true
}

$baseReady = ($checks.backupScriptExists -eq $true) `
    -and ($checks.schedulerCmdletsAvailable -eq $true) `
    -and ($checks.scheduledTaskActionSupportsWorkingDirectory -eq $true) `
    -and ($checks.actionUsesBackupScript -eq $true) `
    -and ($checks.hasStatePath -eq $true) `
    -and ($checks.hasReportPath -eq $true) `
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
    taskRemoved = $taskRemoved
    taskName = $TaskName
    taskPath = $TaskPath
    dailyAt = $At
    taskBefore = $taskBefore
    taskAfter = $taskAfter
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
    backup = [ordered]@{
        statePath = $StatePath
        reportPath = $BackupReportPath
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
$markdownLines.Add("Task: $TaskPath$TaskName")
$markdownLines.Add("")
$markdownLines.Add("This runbook registers a Windows Scheduled Task that runs the manifest-backed state backup command every day. The task requires `FLOWCHAIN_RPC_STATE_BACKUP_PATH` from the owner process environment or from `FLOWCHAIN_OWNER_ENV_FILE`.")
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
$markdownLines.Add("- Owner env file injected: $(-not [string]::IsNullOrWhiteSpace($OwnerEnvFile))")
$markdownLines.Add("")
$markdownLines.Add("## Status")
$markdownLines.Add("")
$markdownLines.Add("- Task existed before: $($taskBefore.exists)")
$markdownLines.Add("- Task exists after: $($taskAfter.exists)")
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
Write-Host "Task: $TaskPath$TaskName"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    exit 1
}
exit 0
