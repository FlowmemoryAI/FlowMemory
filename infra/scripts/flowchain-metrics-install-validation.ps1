param(
    [string] $TaskName = "FlowChainOpsMetrics",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/metrics-install-validation-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/METRICS_INSTALL_VALIDATION.md",
    [string] $PlanReportPath = "docs/agent-runs/live-product-infra-rpc/metrics-install-windows-report.json",
    [string] $PlanMarkdownPath = "docs/agent-runs/live-product-infra-rpc/WINDOWS_METRICS_INSTALL.md",
    [string] $SystemdValidationReportPath = "docs/agent-runs/live-product-infra-rpc/metrics-install-systemd-validation-report.json",
    [string] $SystemdValidationMarkdownPath = "docs/agent-runs/live-product-infra-rpc/SYSTEMD_METRICS_INSTALL_VALIDATION.md"
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
$statusReportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/metrics-install-status-report.json")
$statusMarkdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/WINDOWS_METRICS_INSTALL_STATUS.md")
$uninstallAbsentReportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/metrics-install-uninstall-absent-report.json")
$uninstallAbsentMarkdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/WINDOWS_METRICS_INSTALL_UNINSTALL_ABSENT.md")
$installScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-metrics-install-windows.ps1")
$systemdInstallScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-metrics-install-systemd.ps1")
$systemdValidationScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-metrics-install-systemd-validation.ps1")
$metricsScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-ops-metrics-export.ps1")
$validationTmpDir = Join-Path $repoRoot "devnet/local/tmp/metrics-install-validation"
New-Item -ItemType Directory -Force -Path $validationTmpDir | Out-Null

function Invoke-MetricsInstallValidationChild {
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

function Get-MetricsInstallValidationProp {
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

function Get-MetricsInstallSecretMarkerFindings {
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
$planResult = Invoke-MetricsInstallValidationChild -ArgumentList @(
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
$planChecks = Get-MetricsInstallValidationProp -Object $planReport -Name "checks"
$planCommands = Get-MetricsInstallValidationProp -Object $planReport -Name "commands"
$planScheduledTask = Get-MetricsInstallValidationProp -Object $planReport -Name "scheduledTask"
$scheduledTaskArguments = [string](Get-MetricsInstallValidationProp -Object $planScheduledTask -Name "arguments" -Default "")
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

$statusResult = Invoke-MetricsInstallValidationChild -ArgumentList @(
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

$uninstallAbsentResult = Invoke-MetricsInstallValidationChild -ArgumentList @(
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
$statusTaskBefore = Get-MetricsInstallValidationProp -Object $statusReport -Name "taskBefore"
$statusTaskAfter = Get-MetricsInstallValidationProp -Object $statusReport -Name "taskAfter"
$uninstallAbsentTaskBefore = Get-MetricsInstallValidationProp -Object $uninstallAbsentReport -Name "taskBefore"
$uninstallAbsentTaskAfter = Get-MetricsInstallValidationProp -Object $uninstallAbsentReport -Name "taskAfter"

$systemdValidationResult = Invoke-MetricsInstallValidationChild -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $systemdValidationScriptPath,
    "-ReportPath",
    $systemdValidationReportFullPath,
    "-MarkdownPath",
    $systemdValidationMarkdownFullPath
)
$systemdValidationReport = Read-FlowChainJsonIfExists -Path $systemdValidationReportFullPath
$systemdChecks = Get-MetricsInstallValidationProp -Object $systemdValidationReport -Name "checks"

$requiredScripts = @(
    "flowchain:ops:metrics:export",
    "flowchain:ops:metrics:install:windows",
    "flowchain:ops:metrics:install:systemd",
    "flowchain:ops:metrics:install:systemd:validate",
    "flowchain:ops:metrics:install:validate",
    "flowchain:ops:snapshot",
    "flowchain:ops:alerts",
    "flowchain:service:monitor",
    "flowchain:service:status"
)
$missingPackageScripts = @($requiredScripts | Where-Object { -not (Test-PackageScript -PackageJson $packageJson -Name $_) })
$planStatus = [string](Get-MetricsInstallValidationProp -Object $planReport -Name "status" -Default "missing")
$planAction = [string](Get-MetricsInstallValidationProp -Object $planReport -Name "action" -Default "")
$planMutationPerformed = [bool](Get-MetricsInstallValidationProp -Object $planReport -Name "taskMutationPerformed" -Default $true)
$planPassed = [int]$planResult.exitCode -eq 0 -and $planStatus -eq "passed" -and $planAction -eq "Plan"

$checks = [ordered]@{
    installScriptExists = Test-Path -LiteralPath $installScriptPath
    systemdInstallScriptExists = Test-Path -LiteralPath $systemdInstallScriptPath
    systemdValidationScriptExists = Test-Path -LiteralPath $systemdValidationScriptPath
    metricsScriptExists = Test-Path -LiteralPath $metricsScriptPath
    packageScriptsPresent = $missingPackageScripts.Count -eq 0
    planCommandPassed = $planPassed
    planDidNotMutate = $planPassed -and ($planMutationPerformed -eq $false)
    statusCommandPassed = [int]$statusResult.exitCode -eq 0 -and [string](Get-MetricsInstallValidationProp -Object $statusReport -Name "status" -Default "missing") -eq "passed" -and [string](Get-MetricsInstallValidationProp -Object $statusReport -Name "action" -Default "") -eq "Status"
    statusDidNotMutate = (Get-MetricsInstallValidationProp -Object $statusReport -Name "taskMutationPerformed" -Default $true) -eq $false
    statusTaskStatePreserved = (Get-MetricsInstallValidationProp -Object $statusTaskBefore -Name "exists" -Default $false) -eq (Get-MetricsInstallValidationProp -Object $statusTaskAfter -Name "exists" -Default $true)
    uninstallAbsentCommandPassed = [int]$uninstallAbsentResult.exitCode -eq 0 -and [string](Get-MetricsInstallValidationProp -Object $uninstallAbsentReport -Name "status" -Default "missing") -eq "passed" -and [string](Get-MetricsInstallValidationProp -Object $uninstallAbsentReport -Name "action" -Default "") -eq "Uninstall"
    uninstallAbsentDidNotMutate = (Get-MetricsInstallValidationProp -Object $uninstallAbsentReport -Name "taskMutationPerformed" -Default $true) -eq $false
    uninstallAbsentTaskAbsentBefore = (Get-MetricsInstallValidationProp -Object $uninstallAbsentTaskBefore -Name "exists" -Default $true) -eq $false
    uninstallAbsentTaskAbsentAfter = (Get-MetricsInstallValidationProp -Object $uninstallAbsentTaskAfter -Name "exists" -Default $true) -eq $false
    schedulerCmdletsAvailable = (Get-MetricsInstallValidationProp -Object $planChecks -Name "schedulerCmdletsAvailable" -Default $false) -eq $true
    scheduledTaskActionSupportsWorkingDirectory = (Get-MetricsInstallValidationProp -Object $planChecks -Name "scheduledTaskActionSupportsWorkingDirectory" -Default $false) -eq $true
    scheduledTaskTriggerSupportsRepetition = (Get-MetricsInstallValidationProp -Object $planChecks -Name "scheduledTaskTriggerSupportsRepetition" -Default $false) -eq $true
    actionUsesMetricsScript = (Get-MetricsInstallValidationProp -Object $planChecks -Name "actionUsesMetricsScript" -Default $false) -eq $true
    actionUsesRepoWorkingDirectory = (Get-MetricsInstallValidationProp -Object $planChecks -Name "actionUsesRepoWorkingDirectory" -Default $false) -eq $true
    hasAllowBlocked = (Get-MetricsInstallValidationProp -Object $planChecks -Name "hasAllowBlocked" -Default $false) -eq $true
    hasReportPath = (Get-MetricsInstallValidationProp -Object $planChecks -Name "hasReportPath" -Default $false) -eq $true
    hasMarkdownPath = (Get-MetricsInstallValidationProp -Object $planChecks -Name "hasMarkdownPath" -Default $false) -eq $true
    hasMetricsJsonPath = (Get-MetricsInstallValidationProp -Object $planChecks -Name "hasMetricsJsonPath" -Default $false) -eq $true
    hasPrometheusTextPath = (Get-MetricsInstallValidationProp -Object $planChecks -Name "hasPrometheusTextPath" -Default $false) -eq $true
    noExternalDelivery = (Get-MetricsInstallValidationProp -Object $planChecks -Name "noExternalDelivery" -Default $false) -eq $true
    commandsPresent = -not [string]::IsNullOrWhiteSpace([string](Get-MetricsInstallValidationProp -Object $planCommands -Name "plan" -Default "")) `
        -and -not [string]::IsNullOrWhiteSpace([string](Get-MetricsInstallValidationProp -Object $planCommands -Name "install" -Default "")) `
        -and -not [string]::IsNullOrWhiteSpace([string](Get-MetricsInstallValidationProp -Object $planCommands -Name "status" -Default "")) `
        -and -not [string]::IsNullOrWhiteSpace([string](Get-MetricsInstallValidationProp -Object $planCommands -Name "uninstall" -Default "")) `
        -and -not [string]::IsNullOrWhiteSpace([string](Get-MetricsInstallValidationProp -Object $planCommands -Name "validate" -Default ""))
    scheduledCommandKeepsBlockedMetricsVisible = $scheduledTaskArguments -match "(^|\s)-AllowBlocked(\s|$)"
    scheduledCommandDoesNotDisableRefresh = $scheduledTaskArguments -notmatch "(^|\s)-NoRefresh(\s|$)"
    systemdValidationCommandPassed = [int]$systemdValidationResult.exitCode -eq 0
    systemdValidationPassed = [string](Get-MetricsInstallValidationProp -Object $systemdValidationReport -Name "status" -Default "missing") -eq "passed"
    systemdPlanDidNotMutate = (Get-MetricsInstallValidationProp -Object $systemdChecks -Name "planDidNotMutate" -Default $false) -eq $true
    systemdServiceUnitPlanned = (Get-MetricsInstallValidationProp -Object $systemdChecks -Name "serviceUnitPlanned" -Default $false) -eq $true
    systemdTimerUnitPlanned = (Get-MetricsInstallValidationProp -Object $systemdChecks -Name "timerUnitPlanned" -Default $false) -eq $true
    systemdTimerIntervalConfigured = (Get-MetricsInstallValidationProp -Object $systemdChecks -Name "timerUnitIntervalConfigured" -Default $false) -eq $true
    systemdOwnerEnvFileInjectable = (Get-MetricsInstallValidationProp -Object $systemdChecks -Name "serviceUnitOwnerEnvFileInjectable" -Default $false) -eq $true
    systemdNoExternalDelivery = (Get-MetricsInstallValidationProp -Object $systemdChecks -Name "noExternalDelivery" -Default $false) -eq $true
    systemdChildReportNoSecrets = (Get-MetricsInstallValidationProp -Object $systemdValidationReport -Name "noSecrets" -Default $false) -eq $true
    envValuesPrintedFalse = (Get-MetricsInstallValidationProp -Object $planReport -Name "envValuesPrinted" -Default $true) -eq $false
    childReportsNoSecrets = (Get-MetricsInstallValidationProp -Object $planReport -Name "noSecrets" -Default $false) -eq $true `
        -and (Get-MetricsInstallValidationProp -Object $statusReport -Name "noSecrets" -Default $false) -eq $true `
        -and (Get-MetricsInstallValidationProp -Object $uninstallAbsentReport -Name "noSecrets" -Default $false) -eq $true `
        -and (Get-MetricsInstallValidationProp -Object $systemdValidationReport -Name "noSecrets" -Default $false) -eq $true
    childReportsSecretMarkerFindingsEmpty = $true
    secretMarkerFindingsEmpty = $true
    noSecrets = $true
    broadcastsFalse = (Get-MetricsInstallValidationProp -Object $planReport -Name "broadcasts" -Default $true) -eq $false
}

$report = [ordered]@{
    schema = "flowchain.metrics_install_validation_report.v0"
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
            name = "metrics-install-plan"
            exitCode = [int]$planResult.exitCode
            timedOut = [bool]$planResult.timedOut
            stdoutPath = [string]$planResult.stdoutPath
            stderrPath = [string]$planResult.stderrPath
        },
        [ordered]@{
            name = "metrics-install-status"
            exitCode = [int]$statusResult.exitCode
            timedOut = [bool]$statusResult.timedOut
            stdoutPath = [string]$statusResult.stdoutPath
            stderrPath = [string]$statusResult.stderrPath
        },
        [ordered]@{
            name = "metrics-install-uninstall-absent"
            exitCode = [int]$uninstallAbsentResult.exitCode
            timedOut = [bool]$uninstallAbsentResult.timedOut
            stdoutPath = [string]$uninstallAbsentResult.stdoutPath
            stderrPath = [string]$uninstallAbsentResult.stderrPath
        },
        [ordered]@{
            name = "metrics-install-systemd-validation"
            exitCode = [int]$systemdValidationResult.exitCode
            timedOut = [bool]$systemdValidationResult.timedOut
            stdoutPath = [string]$systemdValidationResult.stdoutPath
            stderrPath = [string]$systemdValidationResult.stderrPath
        }
    )
    commands = [ordered]@{
        plan = "npm run flowchain:ops:metrics:install:windows -- -Action Plan"
        systemdPlan = "npm run flowchain:ops:metrics:install:systemd -- -Action Plan"
        systemdValidate = "npm run flowchain:ops:metrics:install:systemd:validate"
        install = "npm run flowchain:ops:metrics:install:windows -- -Action Install"
        status = "npm run flowchain:ops:metrics:install:windows -- -Action Status"
        uninstall = "npm run flowchain:ops:metrics:install:windows -- -Action Uninstall"
        validate = "npm run flowchain:ops:metrics:install:validate"
    }
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$childReportSecretMarkerFindings = @(
    if ($null -ne $planReport) {
        Get-MetricsInstallSecretMarkerFindings -Text ($planReport | ConvertTo-Json -Depth 18) -Label "metrics install plan report"
    }
    if ($null -ne $statusReport) {
        Get-MetricsInstallSecretMarkerFindings -Text ($statusReport | ConvertTo-Json -Depth 18) -Label "metrics install status report"
    }
    if ($null -ne $uninstallAbsentReport) {
        Get-MetricsInstallSecretMarkerFindings -Text ($uninstallAbsentReport | ConvertTo-Json -Depth 18) -Label "metrics install uninstall absent report"
    }
    if ($null -ne $systemdValidationReport) {
        Get-MetricsInstallSecretMarkerFindings -Text ($systemdValidationReport | ConvertTo-Json -Depth 18) -Label "systemd metrics install validation report"
    }
)
$preliminaryReportText = $report | ConvertTo-Json -Depth 18
$validationReportSecretMarkerFindings = @(Get-MetricsInstallSecretMarkerFindings -Text $preliminaryReportText -Label "metrics install validation report")
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
Assert-FlowChainNoSecretText -Text $reportText -Label "metrics install validation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Metrics Install Validation")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This validation proves the scheduled metrics export path is planned, status-checkable, absent-uninstall safe, no-secret, non-mutating in read-only/no-op modes, and refreshes local JSON plus Prometheus textfile metrics without external delivery. It covers both Windows Scheduled Task and Linux systemd timer paths.")
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
Assert-FlowChainNoSecretText -Text $markdownText -Label "metrics install validation markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain metrics install validation status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    Write-Host "Failed checks: $($failedChecks -join ', ')"
    exit 1
}
exit 0
