param(
    [ValidateSet("Plan", "Install", "Status", "Uninstall")]
    [string] $Action = "Plan",
    [string] $TaskName = "FlowChainLiveSupervisor",
    [string] $TaskPath = "\",
    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node",
    [string] $ServicesDir = "devnet/local/services",
    [string] $ControlPlaneHost = "127.0.0.1",
    [int] $ControlPlanePort = 8787,
    [int] $BlockMs = 1000,
    [int] $IntervalSeconds = 30,
    [int] $MaxRestartAttempts = 3,
    [int] $MaxStateAgeSeconds = 90,
    [ValidateSet("Logon", "Startup", "Both")]
    [string] $TriggerMode = "Both",
    [switch] $StartBridgeRelayerLoop,
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/service-install-windows-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/WINDOWS_SERVICE_INSTALL.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$supervisorScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-service-supervisor.ps1")
[void](Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath))
[void](Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $NodeDir))
[void](Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ServicesDir))

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
if ($IntervalSeconds -lt 1) {
    throw "IntervalSeconds must be at least 1."
}
if ($MaxRestartAttempts -lt 0) {
    throw "MaxRestartAttempts must be at least 0."
}
if ($MaxStateAgeSeconds -lt 1) {
    throw "MaxStateAgeSeconds must be at least 1."
}
if ($ControlPlanePort -lt 1 -or $ControlPlanePort -gt 65535) {
    throw "ControlPlanePort must be between 1 and 65535."
}

function Get-ServiceInstallTriggerNames {
    param([Parameter(Mandatory = $true)][string] $Mode)

    $names = New-Object System.Collections.ArrayList
    if ($Mode -eq "Logon" -or $Mode -eq "Both") {
        [void]$names.Add("AtLogOn")
    }
    if ($Mode -eq "Startup" -or $Mode -eq "Both") {
        [void]$names.Add("AtStartup")
    }
    return @($names)
}

function Get-InstallCommandStatus {
    param([Parameter(Mandatory = $true)][string[]] $Names)

    return @($Names | ForEach-Object {
        $command = Get-Command $_ -ErrorAction SilentlyContinue
        [ordered]@{
            name = $_
            available = $null -ne $command
        }
    })
}

function Get-TaskSnapshot {
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

function Get-PackageCommand {
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
$schedulerCmdlets = @(Get-InstallCommandStatus -Names $requiredSchedulerCmdlets)
$schedulerCmdletsAvailable = @($schedulerCmdlets | Where-Object { $_.available -ne $true }).Count -eq 0
$actionCommand = Get-Command "New-ScheduledTaskAction" -ErrorAction SilentlyContinue
$scheduledTaskActionSupportsWorkingDirectory = $null -ne $actionCommand -and $actionCommand.Parameters.Keys -contains "WorkingDirectory"
$powershellCommand = Get-Command "powershell.exe" -ErrorAction SilentlyContinue
$powershellExecutable = if ($null -ne $powershellCommand) { [string]$powershellCommand.Source } else { "powershell.exe" }
$triggerNames = @(Get-ServiceInstallTriggerNames -Mode $TriggerMode)

$supervisorArguments = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $supervisorScriptPath,
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
    "-IntervalSeconds",
    "$IntervalSeconds",
    "-MaxRestartAttempts",
    "$MaxRestartAttempts",
    "-MaxStateAgeSeconds",
    "$MaxStateAgeSeconds"
)
if ($StartBridgeRelayerLoop.IsPresent) {
    $supervisorArguments += "-StartBridgeRelayerLoop"
}
$scheduledTaskArguments = Join-FlowChainProcessArguments -ArgumentList $supervisorArguments

$commands = [ordered]@{
    plan = Get-PackageCommand -ScriptName "flowchain:service:install:windows" -Extra "-Action Plan"
    validate = Get-PackageCommand -ScriptName "flowchain:service:install:validate"
    install = Get-PackageCommand -ScriptName "flowchain:service:install:windows" -Extra "-Action Install"
    status = Get-PackageCommand -ScriptName "flowchain:service:install:windows" -Extra "-Action Status"
    uninstall = Get-PackageCommand -ScriptName "flowchain:service:install:windows" -Extra "-Action Uninstall"
}

$taskBefore = Get-TaskSnapshot -Name $TaskName -Path $TaskPath -SchedulerAvailable $schedulerCmdletsAvailable
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
                throw "New-ScheduledTaskAction must support WorkingDirectory so the supervisor can resolve the repository root."
            }
            $taskAction = New-ScheduledTaskAction -Execute $powershellExecutable -Argument $scheduledTaskArguments -WorkingDirectory $repoRoot
            $triggers = @()
            if ($triggerNames -contains "AtLogOn") {
                $triggers += New-ScheduledTaskTrigger -AtLogOn
            }
            if ($triggerNames -contains "AtStartup") {
                $triggers += New-ScheduledTaskTrigger -AtStartup
            }
            $settings = New-ScheduledTaskSettingsSet `
                -StartWhenAvailable `
                -AllowStartIfOnBatteries `
                -DontStopIfGoingOnBatteries `
                -MultipleInstances IgnoreNew `
                -RestartCount 3 `
                -RestartInterval (New-TimeSpan -Minutes 1) `
                -ExecutionTimeLimit ([TimeSpan]::Zero)
            Register-ScheduledTask `
                -TaskName $TaskName `
                -TaskPath $TaskPath `
                -Action $taskAction `
                -Trigger $triggers `
                -Settings $settings `
                -Description "FlowChain live L1 supervisor. Keeps the private node and control-plane RPC recovered after startup or owner logon." `
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

$taskAfter = Get-TaskSnapshot -Name $TaskName -Path $TaskPath -SchedulerAvailable $schedulerCmdletsAvailable
$checks = [ordered]@{
    supervisorScriptExists = Test-Path -LiteralPath $supervisorScriptPath
    schedulerCmdletsAvailable = $schedulerCmdletsAvailable
    scheduledTaskActionSupportsWorkingDirectory = $scheduledTaskActionSupportsWorkingDirectory
    actionUsesSupervisor = $scheduledTaskArguments.Contains("flowchain-service-supervisor.ps1")
    actionUsesRepoWorkingDirectory = $true
    liveProfileDefault = -not ($supervisorArguments -contains "-NonLiveProfile")
    noBridgeRelayerDefault = -not $StartBridgeRelayerLoop.IsPresent
    triggerModeValid = $triggerNames.Count -gt 0
    rebootPersistentTrigger = $triggerNames -contains "AtStartup"
    logonRecoveryTrigger = $triggerNames -contains "AtLogOn"
    hasIntervalSeconds = $supervisorArguments -contains "-IntervalSeconds"
    hasMaxRestartAttempts = $supervisorArguments -contains "-MaxRestartAttempts"
    hasMaxStateAgeSeconds = $supervisorArguments -contains "-MaxStateAgeSeconds"
    hasInstallCommand = -not [string]::IsNullOrWhiteSpace($commands.install)
    hasStatusCommand = -not [string]::IsNullOrWhiteSpace($commands.status)
    hasUninstallCommand = -not [string]::IsNullOrWhiteSpace($commands.uninstall)
    planDoesNotMutate = if ($Action -eq "Plan") { -not $taskMutationPerformed } else { $null }
    envValuesPrintedFalse = $true
    noSecrets = $true
}

$baseReady = ($checks.supervisorScriptExists -eq $true) `
    -and ($checks.schedulerCmdletsAvailable -eq $true) `
    -and ($checks.scheduledTaskActionSupportsWorkingDirectory -eq $true) `
    -and ($checks.actionUsesSupervisor -eq $true) `
    -and ($checks.liveProfileDefault -eq $true) `
    -and ($checks.triggerModeValid -eq $true) `
    -and ($checks.rebootPersistentTrigger -eq $true) `
    -and ($checks.hasIntervalSeconds -eq $true) `
    -and ($checks.hasMaxRestartAttempts -eq $true) `
    -and ($checks.hasMaxStateAgeSeconds -eq $true) `
    -and ($checks.hasInstallCommand -eq $true) `
    -and ($checks.hasStatusCommand -eq $true) `
    -and ($checks.hasUninstallCommand -eq $true)

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
    schema = "flowchain.service_install_windows_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    action = $Action
    plannedOnly = $Action -eq "Plan"
    taskMutationPerformed = $taskMutationPerformed
    taskRegistered = $taskRegistered
    taskRemoved = $taskRemoved
    taskName = $TaskName
    taskPath = $TaskPath
    taskBefore = $taskBefore
    taskAfter = $taskAfter
    schedulerCmdlets = $schedulerCmdlets
    scheduledTask = [ordered]@{
        triggerMode = $TriggerMode
        triggers = $triggerNames
        execute = $powershellExecutable
        arguments = $scheduledTaskArguments
        workingDirectory = $repoRoot
        supervisorScript = $supervisorScriptPath
        startsBridgeRelayerLoop = $StartBridgeRelayerLoop.IsPresent
        liveProfileDefault = $checks.liveProfileDefault
    }
    supervisor = [ordered]@{
        statePath = $StatePath
        nodeDir = $NodeDir
        servicesDir = $ServicesDir
        controlPlaneHost = $ControlPlaneHost
        controlPlanePort = $ControlPlanePort
        blockMs = $BlockMs
        intervalSeconds = $IntervalSeconds
        maxRestartAttempts = $MaxRestartAttempts
        maxStateAgeSeconds = $MaxStateAgeSeconds
    }
    commands = $commands
    checks = $checks
    actionErrorRedacted = $actionError
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$reportText = $report | ConvertTo-Json -Depth 20
Assert-FlowChainNoSecretText -Text $reportText -Label "Windows service install report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Windows Service Install")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Action: $Action")
$markdownLines.Add("Task: $TaskPath$TaskName")
$markdownLines.Add("")
$markdownLines.Add("This runbook registers the live service supervisor as a Windows Scheduled Task at owner startup and logon by default. It keeps the private node and control-plane RPC recovered after reboot or logon, while preserving the private local origin.")
$markdownLines.Add("")
$markdownLines.Add("## Commands")
$markdownLines.Add("")
$markdownLines.Add("- Plan: $($commands.plan)")
$markdownLines.Add("- Validate: $($commands.validate)")
$markdownLines.Add("- Install: $($commands.install)")
$markdownLines.Add("- Status: $($commands.status)")
$markdownLines.Add("- Uninstall: $($commands.uninstall)")
$markdownLines.Add("")
$markdownLines.Add("## Scheduled Task Action")
$markdownLines.Add("")
$markdownLines.Add("- Execute: ``$powershellExecutable``")
$markdownLines.Add("- Working directory: ``$repoRoot``")
$markdownLines.Add("- Supervisor: ``$supervisorScriptPath``")
$markdownLines.Add("- Trigger mode: $TriggerMode")
$markdownLines.Add("- Triggers: $($triggerNames -join ', ')")
$markdownLines.Add("- Bridge relayer loop enabled: $($StartBridgeRelayerLoop.IsPresent)")
$markdownLines.Add("- Live profile default: $($checks.liveProfileDefault)")
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
Assert-FlowChainNoSecretText -Text $markdownText -Label "Windows service install markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain Windows service install status: $status"
Write-Host "Action: $Action"
Write-Host "Task: $TaskPath$TaskName"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    exit 1
}
exit 0
