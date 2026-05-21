param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/backup-install-systemd-validation-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/SYSTEMD_BACKUP_INSTALL_VALIDATION.md",
    [string] $PlanReportPath = "docs/agent-runs/live-product-infra-rpc/backup-install-systemd-report.json",
    [string] $PlanMarkdownPath = "docs/agent-runs/live-product-infra-rpc/SYSTEMD_BACKUP_INSTALL.md"
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
$installScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-backup-install-systemd.ps1")
$backupScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-state-backup.ps1")
$restoreDrillScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-state-restore-verify.ps1")
$validationTmpDir = Join-Path $repoRoot "devnet/local/tmp/backup-systemd-install-validation"
New-Item -ItemType Directory -Force -Path $validationTmpDir | Out-Null

function Invoke-BackupSystemdValidationChild {
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

function Get-BackupSystemdValidationProp {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name,
        [object] $Default = $null
    )
    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    if ($null -ne $Object -and $Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
    }
    return $Default
}

function Test-BackupSystemdPackageScript {
    param([Parameter(Mandatory = $true)][string] $Name)

    $packageJsonPath = Join-Path $repoRoot "package.json"
    $packageJson = Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json
    return $packageJson.scripts.PSObject.Properties.Name -contains $Name
}

function Get-BackupSystemdSecretMarkerFindings {
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

$ownerEnvFile = Join-Path $validationTmpDir "owner-env-path-only.env"
Set-Content -LiteralPath $ownerEnvFile -Value "# validation path only; no values are imported by the plan" -Encoding UTF8
$backupRootWritePath = "/var/backups/flowchain-validation"

$planResult = Invoke-BackupSystemdValidationChild -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $installScriptPath,
    "-Action",
    "Plan",
    "-OwnerEnvFile",
    $ownerEnvFile,
    "-BackupRootWritePath",
    $backupRootWritePath,
    "-ReportPath",
    $planReportFullPath,
    "-MarkdownPath",
    $planMarkdownFullPath
)
$planReport = Read-FlowChainJsonIfExists -Path $planReportFullPath
$planChecks = Get-BackupSystemdValidationProp -Object $planReport -Name "checks"
$planUnitPreview = Get-BackupSystemdValidationProp -Object $planReport -Name "unitPreview"
$backupServiceUnit = [string](Get-BackupSystemdValidationProp -Object $planUnitPreview -Name "backupService" -Default "")
$backupTimerUnit = [string](Get-BackupSystemdValidationProp -Object $planUnitPreview -Name "backupTimer" -Default "")
$restoreDrillServiceUnit = [string](Get-BackupSystemdValidationProp -Object $planUnitPreview -Name "restoreDrillService" -Default "")
$restoreDrillTimerUnit = [string](Get-BackupSystemdValidationProp -Object $planUnitPreview -Name "restoreDrillTimer" -Default "")

$checks = [ordered]@{
    installScriptExists = Test-Path -LiteralPath $installScriptPath
    backupScriptExists = Test-Path -LiteralPath $backupScriptPath
    restoreDrillScriptExists = Test-Path -LiteralPath $restoreDrillScriptPath
    installPackageScriptPresent = Test-BackupSystemdPackageScript -Name "flowchain:backup:install:systemd"
    validationPackageScriptPresent = Test-BackupSystemdPackageScript -Name "flowchain:backup:install:systemd:validate"
    parentValidationPackageScriptPresent = Test-BackupSystemdPackageScript -Name "flowchain:backup:install:validate"
    planCommandPassed = [int]$planResult.exitCode -eq 0
    planReportWritten = Test-Path -LiteralPath $planReportFullPath
    planReportPassed = $null -ne $planReport -and [string](Get-BackupSystemdValidationProp -Object $planReport -Name "status" -Default "missing") -eq "passed"
    planActionReadOnly = (Get-BackupSystemdValidationProp -Object $planChecks -Name "planActionReadOnly" -Default $false) -eq $true
    planDidNotMutate = $null -ne $planReport -and (Get-BackupSystemdValidationProp -Object $planReport -Name "hostMutationPerformed" -Default $true) -eq $false
    backupServiceUnitPlanned = -not [string]::IsNullOrWhiteSpace($backupServiceUnit) -and $backupServiceUnit.Contains("flowchain-state-backup.ps1")
    backupServiceOmitsAllowBlocked = (Get-BackupSystemdValidationProp -Object $planChecks -Name "backupServiceOmitsAllowBlocked" -Default $false) -eq $true
    backupServiceHasRetentionCount = (Get-BackupSystemdValidationProp -Object $planChecks -Name "backupServiceHasRetentionCount" -Default $false) -eq $true
    backupTimerUnitPlanned = -not [string]::IsNullOrWhiteSpace($backupTimerUnit) -and $backupTimerUnit.Contains("Persistent=true")
    backupTimerCalendarConfigured = (Get-BackupSystemdValidationProp -Object $planChecks -Name "backupTimerCalendarConfigured" -Default $false) -eq $true
    restoreDrillServiceUnitPlanned = -not [string]::IsNullOrWhiteSpace($restoreDrillServiceUnit) -and $restoreDrillServiceUnit.Contains("flowchain-state-restore-verify.ps1")
    restoreDrillServiceOmitsAllowBlocked = (Get-BackupSystemdValidationProp -Object $planChecks -Name "restoreDrillServiceOmitsAllowBlocked" -Default $false) -eq $true
    restoreDrillTimerUnitPlanned = -not [string]::IsNullOrWhiteSpace($restoreDrillTimerUnit) -and $restoreDrillTimerUnit.Contains("Persistent=true")
    restoreDrillTimerCalendarConfigured = (Get-BackupSystemdValidationProp -Object $planChecks -Name "restoreDrillTimerCalendarConfigured" -Default $false) -eq $true
    servicesOwnerEnvFileInjectable = (Get-BackupSystemdValidationProp -Object $planChecks -Name "servicesOwnerEnvFileInjectable" -Default $false) -eq $true
    servicesHardeningPresent = (Get-BackupSystemdValidationProp -Object $planChecks -Name "servicesHardeningPresent" -Default $false) -eq $true
    backupRootWritePathConfigurable = (Get-BackupSystemdValidationProp -Object $planChecks -Name "backupRootWritePathConfigurable" -Default $false) -eq $true -and $backupServiceUnit.Contains($backupRootWritePath)
    ownerBackupEnvRequiredByRuntime = (Get-BackupSystemdValidationProp -Object $planChecks -Name "ownerBackupEnvRequiredByRuntime" -Default $false) -eq $true
    restoreDrillOwnerBackupEnvRequiredByRuntime = (Get-BackupSystemdValidationProp -Object $planChecks -Name "restoreDrillOwnerBackupEnvRequiredByRuntime" -Default $false) -eq $true
    commandPlanPresent = (Get-BackupSystemdValidationProp -Object $planChecks -Name "commandPlanPresent" -Default $false) -eq $true
    planReportEnvValuesPrintedFalse = $null -ne $planReport -and (Get-BackupSystemdValidationProp -Object $planReport -Name "envValuesPrinted" -Default $true) -eq $false
    planReportNoSecrets = $null -ne $planReport -and (Get-BackupSystemdValidationProp -Object $planReport -Name "noSecrets" -Default $false) -eq $true
    planReportBroadcastsFalse = $null -ne $planReport -and (Get-BackupSystemdValidationProp -Object $planReport -Name "broadcasts" -Default $true) -eq $false
    envValuesPrintedFalse = $true
    secretMarkerFindingsEmpty = $true
    noSecrets = $true
    broadcastsFalse = $true
}

$report = [ordered]@{
    schema = "flowchain.backup_install_systemd_validation_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "pending"
    paths = [ordered]@{
        installScript = $installScriptPath
        backupScript = $backupScriptPath
        restoreDrillScript = $restoreDrillScriptPath
        planReport = $planReportFullPath
        planMarkdown = $planMarkdownFullPath
    }
    checks = $checks
    failedChecks = @()
    secretMarkerFindings = @()
    childProcessResults = @(
        [ordered]@{
            name = "backup-install-systemd-plan"
            exitCode = [int]$planResult.exitCode
            timedOut = [bool]$planResult.timedOut
            stdoutPath = [string]$planResult.stdoutPath
            stderrPath = [string]$planResult.stderrPath
        }
    )
    commands = [ordered]@{
        plan = "npm run flowchain:backup:install:systemd -- -Action Plan"
        install = "npm run flowchain:backup:install:systemd -- -Action Install"
        status = "npm run flowchain:backup:install:systemd -- -Action Status"
        uninstall = "npm run flowchain:backup:install:systemd -- -Action Uninstall"
        validate = "npm run flowchain:backup:install:systemd:validate"
    }
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$childReportSecretMarkerFindings = @(
    if ($null -ne $planReport) {
        Get-BackupSystemdSecretMarkerFindings -Text ($planReport | ConvertTo-Json -Depth 18) -Label "systemd backup install plan report"
    }
)
$preliminaryReportText = $report | ConvertTo-Json -Depth 18
$validationReportSecretMarkerFindings = @(Get-BackupSystemdSecretMarkerFindings -Text $preliminaryReportText -Label "systemd backup install validation report")
$secretMarkerFindings = @(
    @($childReportSecretMarkerFindings)
    @($validationReportSecretMarkerFindings)
)
$checks["secretMarkerFindingsEmpty"] = $secretMarkerFindings.Count -eq 0
$checks["noSecrets"] = $checks["planReportNoSecrets"] -eq $true -and $secretMarkerFindings.Count -eq 0
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
$report["status"] = $status
$report["checks"] = $checks
$report["failedChecks"] = @($failedChecks)
$report["secretMarkerFindings"] = @($secretMarkerFindings)
$report["noSecrets"] = $secretMarkerFindings.Count -eq 0

$reportText = $report | ConvertTo-Json -Depth 18
Assert-FlowChainNoSecretText -Text $reportText -Label "systemd backup install validation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Systemd Backup Install Validation")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This validation proves the Linux systemd timer path for recurring state backup and restore-drill verification is present, no-secret, non-mutating in Plan mode, and fails closed until the owner backup path env is configured.")
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
Assert-FlowChainNoSecretText -Text $markdownText -Label "systemd backup install validation markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain systemd backup install validation status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    Write-Host "Failed checks: $($failedChecks -join ', ')"
    exit 1
}
exit 0
