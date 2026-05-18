param(
    [string] $TaskName = "FlowChainOpsAlerts",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/alert-install-validation-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/ALERT_INSTALL_VALIDATION.md",
    [string] $PlanReportPath = "docs/agent-runs/live-product-infra-rpc/alert-install-windows-report.json",
    [string] $PlanMarkdownPath = "docs/agent-runs/live-product-infra-rpc/WINDOWS_ALERT_INSTALL.md"
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
$statusReportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/alert-install-status-report.json")
$statusMarkdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/WINDOWS_ALERT_INSTALL_STATUS.md")
$uninstallAbsentReportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/alert-install-uninstall-absent-report.json")
$uninstallAbsentMarkdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/WINDOWS_ALERT_INSTALL_UNINSTALL_ABSENT.md")
$installScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-alert-install-windows.ps1")
$alertsScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-ops-alerts.ps1")
$validationTmpDir = Join-Path $repoRoot "devnet/local/tmp/alert-install-validation"
New-Item -ItemType Directory -Force -Path $validationTmpDir | Out-Null

function Invoke-AlertInstallValidationChild {
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

function Get-AlertInstallValidationProp {
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

function Get-AlertInstallSecretMarkerFindings {
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
$planResult = Invoke-AlertInstallValidationChild -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $installScriptPath,
    "-Action",
    "Plan",
    "-TaskName",
    $TaskName,
    "-ReportPath",
    $planReportFullPath,
    "-MarkdownPath",
    $planMarkdownFullPath
)

$planReport = Read-FlowChainJsonIfExists -Path $planReportFullPath
$planChecks = Get-AlertInstallValidationProp -Object $planReport -Name "checks"
$planCommands = Get-AlertInstallValidationProp -Object $planReport -Name "commands"
$planScheduledTask = Get-AlertInstallValidationProp -Object $planReport -Name "scheduledTask"
$scheduledTaskArguments = [string](Get-AlertInstallValidationProp -Object $planScheduledTask -Name "arguments" -Default "")
$absentTaskName = "$TaskName-ValidationAbsent"
if ($absentTaskName -notmatch '^[A-Za-z0-9_. -]{1,120}$') {
    throw "Validation absent task name is invalid: $absentTaskName"
}

$existingAbsentTask = $null
if (Get-Command "Get-ScheduledTask" -ErrorAction SilentlyContinue) {
    $existingAbsentTask = Get-ScheduledTask -TaskName $absentTaskName -TaskPath "\" -ErrorAction SilentlyContinue
}
if ($null -ne $existingAbsentTask) {
    throw "Refusing to use existing validation task: $absentTaskName"
}

$statusResult = Invoke-AlertInstallValidationChild -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $installScriptPath,
    "-Action",
    "Status",
    "-TaskName",
    $TaskName,
    "-ReportPath",
    $statusReportFullPath,
    "-MarkdownPath",
    $statusMarkdownFullPath
)
$statusReport = Read-FlowChainJsonIfExists -Path $statusReportFullPath

$uninstallAbsentResult = Invoke-AlertInstallValidationChild -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $installScriptPath,
    "-Action",
    "Uninstall",
    "-TaskName",
    $absentTaskName,
    "-ReportPath",
    $uninstallAbsentReportFullPath,
    "-MarkdownPath",
    $uninstallAbsentMarkdownFullPath
)
$uninstallAbsentReport = Read-FlowChainJsonIfExists -Path $uninstallAbsentReportFullPath
$statusTaskBefore = Get-AlertInstallValidationProp -Object $statusReport -Name "taskBefore"
$statusTaskAfter = Get-AlertInstallValidationProp -Object $statusReport -Name "taskAfter"
$uninstallAbsentTaskBefore = Get-AlertInstallValidationProp -Object $uninstallAbsentReport -Name "taskBefore"
$uninstallAbsentTaskAfter = Get-AlertInstallValidationProp -Object $uninstallAbsentReport -Name "taskAfter"

$requiredScripts = @(
    "flowchain:ops:alerts",
    "flowchain:ops:alerts:install:windows",
    "flowchain:ops:alerts:install:validate",
    "flowchain:ops:snapshot",
    "flowchain:service:monitor",
    "flowchain:service:status"
)
$missingPackageScripts = @($requiredScripts | Where-Object { -not (Test-PackageScript -PackageJson $packageJson -Name $_) })
$planStatus = [string](Get-AlertInstallValidationProp -Object $planReport -Name "status" -Default "missing")
$planAction = [string](Get-AlertInstallValidationProp -Object $planReport -Name "action" -Default "")
$planMutationPerformed = [bool](Get-AlertInstallValidationProp -Object $planReport -Name "taskMutationPerformed" -Default $true)
$planPassed = [int]$planResult.exitCode -eq 0 -and $planStatus -eq "passed" -and $planAction -eq "Plan"

$checks = [ordered]@{
    installScriptExists = Test-Path -LiteralPath $installScriptPath
    alertsScriptExists = Test-Path -LiteralPath $alertsScriptPath
    packageScriptsPresent = $missingPackageScripts.Count -eq 0
    planCommandPassed = $planPassed
    planDidNotMutate = $planPassed -and ($planMutationPerformed -eq $false)
    statusCommandPassed = [int]$statusResult.exitCode -eq 0 -and [string](Get-AlertInstallValidationProp -Object $statusReport -Name "status" -Default "missing") -eq "passed" -and [string](Get-AlertInstallValidationProp -Object $statusReport -Name "action" -Default "") -eq "Status"
    statusDidNotMutate = (Get-AlertInstallValidationProp -Object $statusReport -Name "taskMutationPerformed" -Default $true) -eq $false
    statusTaskStatePreserved = (Get-AlertInstallValidationProp -Object $statusTaskBefore -Name "exists" -Default $false) -eq (Get-AlertInstallValidationProp -Object $statusTaskAfter -Name "exists" -Default $true)
    uninstallAbsentCommandPassed = [int]$uninstallAbsentResult.exitCode -eq 0 -and [string](Get-AlertInstallValidationProp -Object $uninstallAbsentReport -Name "status" -Default "missing") -eq "passed" -and [string](Get-AlertInstallValidationProp -Object $uninstallAbsentReport -Name "action" -Default "") -eq "Uninstall"
    uninstallAbsentDidNotMutate = (Get-AlertInstallValidationProp -Object $uninstallAbsentReport -Name "taskMutationPerformed" -Default $true) -eq $false
    uninstallAbsentTaskAbsentBefore = (Get-AlertInstallValidationProp -Object $uninstallAbsentTaskBefore -Name "exists" -Default $true) -eq $false
    uninstallAbsentTaskAbsentAfter = (Get-AlertInstallValidationProp -Object $uninstallAbsentTaskAfter -Name "exists" -Default $true) -eq $false
    schedulerCmdletsAvailable = (Get-AlertInstallValidationProp -Object $planChecks -Name "schedulerCmdletsAvailable" -Default $false) -eq $true
    scheduledTaskActionSupportsWorkingDirectory = (Get-AlertInstallValidationProp -Object $planChecks -Name "scheduledTaskActionSupportsWorkingDirectory" -Default $false) -eq $true
    scheduledTaskTriggerSupportsRepetition = (Get-AlertInstallValidationProp -Object $planChecks -Name "scheduledTaskTriggerSupportsRepetition" -Default $false) -eq $true
    actionUsesAlertsScript = (Get-AlertInstallValidationProp -Object $planChecks -Name "actionUsesAlertsScript" -Default $false) -eq $true
    actionUsesRepoWorkingDirectory = (Get-AlertInstallValidationProp -Object $planChecks -Name "actionUsesRepoWorkingDirectory" -Default $false) -eq $true
    hasAllowBlocked = (Get-AlertInstallValidationProp -Object $planChecks -Name "hasAllowBlocked" -Default $false) -eq $true
    hasReportPath = (Get-AlertInstallValidationProp -Object $planChecks -Name "hasReportPath" -Default $false) -eq $true
    hasMarkdownPath = (Get-AlertInstallValidationProp -Object $planChecks -Name "hasMarkdownPath" -Default $false) -eq $true
    hasOpsSnapshotPath = (Get-AlertInstallValidationProp -Object $planChecks -Name "hasOpsSnapshotPath" -Default $false) -eq $true
    noExternalDelivery = (Get-AlertInstallValidationProp -Object $planChecks -Name "noExternalDelivery" -Default $false) -eq $true
    commandsPresent = -not [string]::IsNullOrWhiteSpace([string](Get-AlertInstallValidationProp -Object $planCommands -Name "plan" -Default "")) `
        -and -not [string]::IsNullOrWhiteSpace([string](Get-AlertInstallValidationProp -Object $planCommands -Name "install" -Default "")) `
        -and -not [string]::IsNullOrWhiteSpace([string](Get-AlertInstallValidationProp -Object $planCommands -Name "status" -Default "")) `
        -and -not [string]::IsNullOrWhiteSpace([string](Get-AlertInstallValidationProp -Object $planCommands -Name "uninstall" -Default "")) `
        -and -not [string]::IsNullOrWhiteSpace([string](Get-AlertInstallValidationProp -Object $planCommands -Name "validate" -Default ""))
    scheduledCommandKeepsBlockedAlertsVisible = $scheduledTaskArguments -match "(^|\s)-AllowBlocked(\s|$)"
    scheduledCommandDoesNotDisableRefresh = $scheduledTaskArguments -notmatch "(^|\s)-NoRefresh(\s|$)"
    envValuesPrintedFalse = (Get-AlertInstallValidationProp -Object $planReport -Name "envValuesPrinted" -Default $true) -eq $false
    childReportsNoSecrets = (Get-AlertInstallValidationProp -Object $planReport -Name "noSecrets" -Default $false) -eq $true `
        -and (Get-AlertInstallValidationProp -Object $statusReport -Name "noSecrets" -Default $false) -eq $true `
        -and (Get-AlertInstallValidationProp -Object $uninstallAbsentReport -Name "noSecrets" -Default $false) -eq $true
    childReportsSecretMarkerFindingsEmpty = $true
    secretMarkerFindingsEmpty = $true
    noSecrets = $true
    broadcastsFalse = (Get-AlertInstallValidationProp -Object $planReport -Name "broadcasts" -Default $true) -eq $false
}

$report = [ordered]@{
    schema = "flowchain.alert_install_validation_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "pending"
    taskName = $TaskName
    checks = $checks
    failedChecks = @()
    secretMarkerFindings = @()
    missingPackageScripts = @($missingPackageScripts)
    planReportPath = $planReportFullPath
    planMarkdownPath = $planMarkdownFullPath
    statusReportPath = $statusReportFullPath
    uninstallAbsentReportPath = $uninstallAbsentReportFullPath
    absentValidationTaskName = $absentTaskName
    childProcessResults = @(
        [ordered]@{
            name = "alert-install-plan"
            exitCode = [int]$planResult.exitCode
            timedOut = [bool]$planResult.timedOut
            stdoutPath = [string]$planResult.stdoutPath
            stderrPath = [string]$planResult.stderrPath
        },
        [ordered]@{
            name = "alert-install-status"
            exitCode = [int]$statusResult.exitCode
            timedOut = [bool]$statusResult.timedOut
            stdoutPath = [string]$statusResult.stdoutPath
            stderrPath = [string]$statusResult.stderrPath
        },
        [ordered]@{
            name = "alert-install-uninstall-absent"
            exitCode = [int]$uninstallAbsentResult.exitCode
            timedOut = [bool]$uninstallAbsentResult.timedOut
            stdoutPath = [string]$uninstallAbsentResult.stdoutPath
            stderrPath = [string]$uninstallAbsentResult.stderrPath
        }
    )
    commands = [ordered]@{
        plan = "npm run flowchain:ops:alerts:install:windows -- -Action Plan"
        install = "npm run flowchain:ops:alerts:install:windows -- -Action Install"
        status = "npm run flowchain:ops:alerts:install:windows -- -Action Status"
        uninstall = "npm run flowchain:ops:alerts:install:windows -- -Action Uninstall"
        validate = "npm run flowchain:ops:alerts:install:validate"
    }
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$childReportSecretMarkerFindings = @(
    if ($null -ne $planReport) {
        Get-AlertInstallSecretMarkerFindings -Text ($planReport | ConvertTo-Json -Depth 18) -Label "alert install plan report"
    }
    if ($null -ne $statusReport) {
        Get-AlertInstallSecretMarkerFindings -Text ($statusReport | ConvertTo-Json -Depth 18) -Label "alert install status report"
    }
    if ($null -ne $uninstallAbsentReport) {
        Get-AlertInstallSecretMarkerFindings -Text ($uninstallAbsentReport | ConvertTo-Json -Depth 18) -Label "alert install uninstall absent report"
    }
)
$preliminaryReportText = $report | ConvertTo-Json -Depth 18
$validationReportSecretMarkerFindings = @(Get-AlertInstallSecretMarkerFindings -Text $preliminaryReportText -Label "alert install validation report")
$secretMarkerFindings = @(
    @($childReportSecretMarkerFindings)
    @($validationReportSecretMarkerFindings)
)
$checks["childReportsSecretMarkerFindingsEmpty"] = $childReportSecretMarkerFindings.Count -eq 0
$checks["secretMarkerFindingsEmpty"] = $secretMarkerFindings.Count -eq 0
$checks["noSecrets"] = $checks["childReportsNoSecrets"] -eq $true -and $secretMarkerFindings.Count -eq 0
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
$report["status"] = $status
$report["checks"] = $checks
$report["failedChecks"] = @($failedChecks)
$report["secretMarkerFindings"] = @($secretMarkerFindings)
$report["noSecrets"] = $secretMarkerFindings.Count -eq 0

$reportText = $report | ConvertTo-Json -Depth 18
Assert-FlowChainNoSecretText -Text $reportText -Label "alert install validation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Alert Install Validation")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This validation proves the scheduled alert refresh path is planned, status-checkable, absent-uninstall safe, no-secret, non-mutating in read-only/no-op modes, and refreshes local alert evidence without external delivery.")
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
Assert-FlowChainNoSecretText -Text $markdownText -Label "alert install validation markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain alert install validation status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    Write-Host "Failed checks: $($failedChecks -join ', ')"
    exit 1
}
exit 0
