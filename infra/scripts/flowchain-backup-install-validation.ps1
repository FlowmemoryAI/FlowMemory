param(
    [string] $TaskName = "FlowChainStateBackup",
    [string] $RestoreDrillTaskName = "FlowChainStateRestoreDrill",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/backup-install-validation-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/BACKUP_INSTALL_VALIDATION.md",
    [string] $PlanReportPath = "docs/agent-runs/live-product-infra-rpc/backup-install-windows-report.json",
    [string] $PlanMarkdownPath = "docs/agent-runs/live-product-infra-rpc/WINDOWS_BACKUP_INSTALL.md",
    [string] $SystemdValidationReportPath = "docs/agent-runs/live-product-infra-rpc/backup-install-systemd-validation-report.json",
    [string] $SystemdValidationMarkdownPath = "docs/agent-runs/live-product-infra-rpc/SYSTEMD_BACKUP_INSTALL_VALIDATION.md",
    [string] $SystemdPlanReportPath = "docs/agent-runs/live-product-infra-rpc/backup-install-systemd-report.json",
    [string] $SystemdPlanMarkdownPath = "docs/agent-runs/live-product-infra-rpc/SYSTEMD_BACKUP_INSTALL.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$planReportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $PlanReportPath)
$planMarkdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $PlanMarkdownPath)
$systemdValidationReportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $SystemdValidationReportPath)
$systemdValidationMarkdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $SystemdValidationMarkdownPath)
$systemdPlanReportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $SystemdPlanReportPath)
$systemdPlanMarkdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $SystemdPlanMarkdownPath)
$installScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-backup-install-windows.ps1")
$systemdInstallScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-backup-install-systemd.ps1")
$systemdValidationScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-backup-install-systemd-validation.ps1")
$backupScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-state-backup.ps1")
$restoreDrillScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-state-restore-verify.ps1")
$validationTmpDir = Join-Path $repoRoot "devnet/local/tmp/backup-install-validation"
New-Item -ItemType Directory -Force -Path $validationTmpDir | Out-Null

function Invoke-BackupInstallValidationChild {
    param(
        [Parameter(Mandatory = $true)][string[]] $ArgumentList,
        [int] $TimeoutSeconds = 120
    )

    $runId = "$(Get-Date -Format 'yyyyMMddHHmmssfff')-$PID-$([System.Guid]::NewGuid().ToString('N').Substring(0, 8))"
    $stdoutPath = Join-Path $validationTmpDir "$runId.stdout.log"
    $stderrPath = Join-Path $validationTmpDir "$runId.stderr.log"
    $output = @()
    $exitCode = 1
    $timedOut = $false
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
        $output += @(Get-Content -LiteralPath $stdoutPath -Tail 30)
    }
    if (Test-Path -LiteralPath $stderrPath) {
        $output += @(Get-Content -LiteralPath $stderrPath -Tail 30)
    }
    return [ordered]@{
        exitCode = [int]$exitCode
        timedOut = $timedOut
        stdoutPath = $stdoutPath
        stderrPath = $stderrPath
        outputRedacted = @($output | ForEach-Object { "$_" })
    }
}

function Get-BackupInstallValidationProp {
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

function Test-PackageScript {
    param(
        [Parameter(Mandatory = $true)][AllowNull()][object] $PackageJson,
        [Parameter(Mandatory = $true)][string] $Name
    )
    if ($null -eq $PackageJson -or -not ($PackageJson.PSObject.Properties.Name -contains "scripts")) {
        return $false
    }
    return $PackageJson.scripts.PSObject.Properties.Name -contains $Name
}

$packageJson = Get-Content -Raw -LiteralPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "package.json") | ConvertFrom-Json
$planResult = Invoke-BackupInstallValidationChild -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $installScriptPath,
    "-Action",
    "Plan",
    "-TaskName",
    $TaskName,
    "-RestoreDrillTaskName",
    $RestoreDrillTaskName,
    "-ReportPath",
    $planReportFullPath,
    "-MarkdownPath",
    $planMarkdownFullPath
)

$planReport = Read-FlowChainJsonIfExists -Path $planReportFullPath
$planChecks = Get-BackupInstallValidationProp -Object $planReport -Name "checks"
$planCommands = Get-BackupInstallValidationProp -Object $planReport -Name "commands"
$planScheduledTask = Get-BackupInstallValidationProp -Object $planReport -Name "scheduledTask"
$planRestoreDrillScheduledTask = Get-BackupInstallValidationProp -Object $planReport -Name "restoreDrillScheduledTask"
$scheduledTaskArguments = [string](Get-BackupInstallValidationProp -Object $planScheduledTask -Name "arguments" -Default "")
$restoreDrillTaskArguments = [string](Get-BackupInstallValidationProp -Object $planRestoreDrillScheduledTask -Name "arguments" -Default "")

$systemdValidationResult = Invoke-BackupInstallValidationChild -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $systemdValidationScriptPath,
    "-ReportPath",
    $systemdValidationReportFullPath,
    "-MarkdownPath",
    $systemdValidationMarkdownFullPath,
    "-PlanReportPath",
    $systemdPlanReportFullPath,
    "-PlanMarkdownPath",
    $systemdPlanMarkdownFullPath
)
$systemdValidationReport = Read-FlowChainJsonIfExists -Path $systemdValidationReportFullPath
$systemdValidationChecks = Get-BackupInstallValidationProp -Object $systemdValidationReport -Name "checks"
$systemdValidationFailedChecks = @((Get-BackupInstallValidationProp -Object $systemdValidationReport -Name "failedChecks" -Default @()))
$systemdSecretMarkerFindings = @((Get-BackupInstallValidationProp -Object $systemdValidationReport -Name "secretMarkerFindings" -Default @()))

$requiredScripts = @(
    "flowchain:backup:install:windows",
    "flowchain:backup:install:systemd",
    "flowchain:backup:install:systemd:validate",
    "flowchain:backup:install:validate",
    "flowchain:backup:create",
    "flowchain:backup:check",
    "flowchain:backup:restore:verify",
    "flowchain:backup:restore:validate"
)
$missingPackageScripts = @($requiredScripts | Where-Object { -not (Test-PackageScript -PackageJson $packageJson -Name $_) })
$planStatus = [string](Get-BackupInstallValidationProp -Object $planReport -Name "status" -Default "missing")
$planAction = [string](Get-BackupInstallValidationProp -Object $planReport -Name "action" -Default "")
$planMutationPerformed = [bool](Get-BackupInstallValidationProp -Object $planReport -Name "taskMutationPerformed" -Default $true)
$planPassed = [int]$planResult.exitCode -eq 0 -and $planStatus -eq "passed" -and $planAction -eq "Plan"

$checks = [ordered]@{
    installScriptExists = Test-Path -LiteralPath $installScriptPath
    systemdInstallScriptExists = Test-Path -LiteralPath $systemdInstallScriptPath
    systemdValidationScriptExists = Test-Path -LiteralPath $systemdValidationScriptPath
    backupScriptExists = Test-Path -LiteralPath $backupScriptPath
    restoreDrillScriptExists = Test-Path -LiteralPath $restoreDrillScriptPath
    packageScriptsPresent = $missingPackageScripts.Count -eq 0
    planCommandPassed = $planPassed
    planDidNotMutate = $planPassed -and ($planMutationPerformed -eq $false)
    schedulerCmdletsAvailable = (Get-BackupInstallValidationProp -Object $planChecks -Name "schedulerCmdletsAvailable" -Default $false) -eq $true
    scheduledTaskActionSupportsWorkingDirectory = (Get-BackupInstallValidationProp -Object $planChecks -Name "scheduledTaskActionSupportsWorkingDirectory" -Default $false) -eq $true
    taskNamesDistinct = (Get-BackupInstallValidationProp -Object $planChecks -Name "taskNamesDistinct" -Default $false) -eq $true
    retentionCountValid = (Get-BackupInstallValidationProp -Object $planChecks -Name "retentionCountValid" -Default $false) -eq $true
    actionUsesBackupScript = (Get-BackupInstallValidationProp -Object $planChecks -Name "actionUsesBackupScript" -Default $false) -eq $true
    actionUsesRetentionCount = (Get-BackupInstallValidationProp -Object $planChecks -Name "actionUsesRetentionCount" -Default $false) -eq $true
    actionUsesRepoWorkingDirectory = (Get-BackupInstallValidationProp -Object $planChecks -Name "actionUsesRepoWorkingDirectory" -Default $false) -eq $true
    hasStatePath = (Get-BackupInstallValidationProp -Object $planChecks -Name "hasStatePath" -Default $false) -eq $true
    hasReportPath = (Get-BackupInstallValidationProp -Object $planChecks -Name "hasReportPath" -Default $false) -eq $true
    restoreDrillUsesRestoreScript = (Get-BackupInstallValidationProp -Object $planChecks -Name "restoreDrillUsesRestoreScript" -Default $false) -eq $true
    restoreDrillUsesRepoWorkingDirectory = (Get-BackupInstallValidationProp -Object $planChecks -Name "restoreDrillUsesRepoWorkingDirectory" -Default $false) -eq $true
    restoreDrillHasRestoreRoot = (Get-BackupInstallValidationProp -Object $planChecks -Name "restoreDrillHasRestoreRoot" -Default $false) -eq $true
    restoreDrillHasStatePath = (Get-BackupInstallValidationProp -Object $planChecks -Name "restoreDrillHasStatePath" -Default $false) -eq $true
    restoreDrillHasReportPath = (Get-BackupInstallValidationProp -Object $planChecks -Name "restoreDrillHasReportPath" -Default $false) -eq $true
    ownerBackupEnvRequired = (Get-BackupInstallValidationProp -Object $planChecks -Name "reliesOnOwnerBackupEnv" -Default $false) -eq $true
    restoreDrillOwnerBackupEnvRequired = (Get-BackupInstallValidationProp -Object $planChecks -Name "restoreDrillReliesOnOwnerBackupEnv" -Default $false) -eq $true
    commandsPresent = -not [string]::IsNullOrWhiteSpace([string](Get-BackupInstallValidationProp -Object $planCommands -Name "plan" -Default "")) `
        -and -not [string]::IsNullOrWhiteSpace([string](Get-BackupInstallValidationProp -Object $planCommands -Name "install" -Default "")) `
        -and -not [string]::IsNullOrWhiteSpace([string](Get-BackupInstallValidationProp -Object $planCommands -Name "status" -Default "")) `
        -and -not [string]::IsNullOrWhiteSpace([string](Get-BackupInstallValidationProp -Object $planCommands -Name "uninstall" -Default "")) `
        -and -not [string]::IsNullOrWhiteSpace([string](Get-BackupInstallValidationProp -Object $planCommands -Name "validate" -Default ""))
    commandOmitsAllowBlocked = $scheduledTaskArguments -notmatch "(^|\s)-AllowBlocked(\s|$)" -and $restoreDrillTaskArguments -notmatch "(^|\s)-AllowBlocked(\s|$)"
    envValuesPrintedFalse = (Get-BackupInstallValidationProp -Object $planReport -Name "envValuesPrinted" -Default $true) -eq $false
    noSecrets = (Get-BackupInstallValidationProp -Object $planReport -Name "noSecrets" -Default $false) -eq $true
    broadcastsFalse = (Get-BackupInstallValidationProp -Object $planReport -Name "broadcasts" -Default $true) -eq $false
    systemdValidationCommandPassed = [int]$systemdValidationResult.exitCode -eq 0
    systemdValidationPassed = $null -ne $systemdValidationReport -and [string](Get-BackupInstallValidationProp -Object $systemdValidationReport -Name "status" -Default "missing") -eq "passed"
    systemdFailedChecksEmpty = $systemdValidationFailedChecks.Count -eq 0
    systemdPlanDidNotMutate = (Get-BackupInstallValidationProp -Object $systemdValidationChecks -Name "planDidNotMutate" -Default $false) -eq $true
    systemdBackupServiceUnitPlanned = (Get-BackupInstallValidationProp -Object $systemdValidationChecks -Name "backupServiceUnitPlanned" -Default $false) -eq $true
    systemdBackupTimerUnitPlanned = (Get-BackupInstallValidationProp -Object $systemdValidationChecks -Name "backupTimerUnitPlanned" -Default $false) -eq $true
    systemdRestoreServiceUnitPlanned = (Get-BackupInstallValidationProp -Object $systemdValidationChecks -Name "restoreDrillServiceUnitPlanned" -Default $false) -eq $true
    systemdRestoreTimerUnitPlanned = (Get-BackupInstallValidationProp -Object $systemdValidationChecks -Name "restoreDrillTimerUnitPlanned" -Default $false) -eq $true
    systemdCommandOmitsAllowBlocked = (Get-BackupInstallValidationProp -Object $systemdValidationChecks -Name "backupServiceOmitsAllowBlocked" -Default $false) -eq $true `
        -and (Get-BackupInstallValidationProp -Object $systemdValidationChecks -Name "restoreDrillServiceOmitsAllowBlocked" -Default $false) -eq $true
    systemdOwnerBackupEnvRequired = (Get-BackupInstallValidationProp -Object $systemdValidationChecks -Name "ownerBackupEnvRequiredByRuntime" -Default $false) -eq $true `
        -and (Get-BackupInstallValidationProp -Object $systemdValidationChecks -Name "restoreDrillOwnerBackupEnvRequiredByRuntime" -Default $false) -eq $true
    systemdOwnerEnvInjectable = (Get-BackupInstallValidationProp -Object $systemdValidationChecks -Name "servicesOwnerEnvFileInjectable" -Default $false) -eq $true
    systemdServicesHardeningPresent = (Get-BackupInstallValidationProp -Object $systemdValidationChecks -Name "servicesHardeningPresent" -Default $false) -eq $true
    systemdBackupRootWritePathConfigurable = (Get-BackupInstallValidationProp -Object $systemdValidationChecks -Name "backupRootWritePathConfigurable" -Default $false) -eq $true
    systemdChildReportNoSecrets = $null -ne $systemdValidationReport `
        -and (Get-BackupInstallValidationProp -Object $systemdValidationReport -Name "envValuesPrinted" -Default $true) -eq $false `
        -and (Get-BackupInstallValidationProp -Object $systemdValidationReport -Name "noSecrets" -Default $false) -eq $true `
        -and (Get-BackupInstallValidationProp -Object $systemdValidationReport -Name "broadcasts" -Default $true) -eq $false `
        -and $systemdSecretMarkerFindings.Count -eq 0
}

$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.backup_install_validation_report.v1"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    taskName = $TaskName
    restoreDrillTaskName = $RestoreDrillTaskName
    checks = $checks
    failedChecks = @($failedChecks)
    missingPackageScripts = @($missingPackageScripts)
    planReportPath = $planReportFullPath
    planMarkdownPath = $planMarkdownFullPath
    systemdValidationReportPath = $systemdValidationReportFullPath
    systemdValidationMarkdownPath = $systemdValidationMarkdownFullPath
    systemdPlanReportPath = $systemdPlanReportFullPath
    systemdPlanMarkdownPath = $systemdPlanMarkdownFullPath
    childProcessResults = @(
        [ordered]@{
            name = "backup-install-plan"
            exitCode = [int]$planResult.exitCode
            timedOut = [bool]$planResult.timedOut
            stdoutPath = [string]$planResult.stdoutPath
            stderrPath = [string]$planResult.stderrPath
        },
        [ordered]@{
            name = "backup-install-systemd-validation"
            exitCode = [int]$systemdValidationResult.exitCode
            timedOut = [bool]$systemdValidationResult.timedOut
            stdoutPath = [string]$systemdValidationResult.stdoutPath
            stderrPath = [string]$systemdValidationResult.stderrPath
        }
    )
    commands = [ordered]@{
        plan = "npm run flowchain:backup:install:windows -- -Action Plan"
        systemdPlan = "npm run flowchain:backup:install:systemd -- -Action Plan"
        install = "npm run flowchain:backup:install:windows -- -Action Install"
        systemdInstall = "npm run flowchain:backup:install:systemd -- -Action Install"
        status = "npm run flowchain:backup:install:windows -- -Action Status"
        systemdStatus = "npm run flowchain:backup:install:systemd -- -Action Status"
        uninstall = "npm run flowchain:backup:install:windows -- -Action Uninstall"
        systemdUninstall = "npm run flowchain:backup:install:systemd -- -Action Uninstall"
        systemdValidate = "npm run flowchain:backup:install:systemd:validate"
        validate = "npm run flowchain:backup:install:validate"
    }
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$reportText = $report | ConvertTo-Json -Depth 18
Assert-FlowChainNoSecretText -Text $reportText -Label "backup install validation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Backup Install Validation")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This validation proves the Windows Scheduled Task and Linux systemd timer install paths are planned, no-secret, non-mutating in plan mode, rotate snapshots by retention count, schedule recurring restore drills, and fail closed unless the owner backup path env is configured for actual backup and restore runs.")
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
Assert-FlowChainNoSecretText -Text $markdownText -Label "backup install validation markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain backup install validation status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    Write-Host "Failed checks: $($failedChecks -join ', ')"
    exit 1
}
exit 0
