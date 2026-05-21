param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/alert-install-systemd-validation-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/SYSTEMD_ALERT_INSTALL_VALIDATION.md",
    [string] $PlanReportPath = "docs/agent-runs/live-product-infra-rpc/alert-install-systemd-report.json",
    [string] $PlanMarkdownPath = "docs/agent-runs/live-product-infra-rpc/SYSTEMD_ALERT_INSTALL.md"
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
$installScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-alert-install-systemd.ps1")
$alertsScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-ops-alerts.ps1")
$validationTmpDir = Join-Path $repoRoot "devnet/local/tmp/alert-systemd-install-validation"
New-Item -ItemType Directory -Force -Path $validationTmpDir | Out-Null

function Invoke-AlertSystemdValidationChild {
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

function Get-AlertSystemdValidationProp {
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

function Test-AlertSystemdPackageScript {
    param([Parameter(Mandatory = $true)][string] $Name)

    $packageJsonPath = Join-Path $repoRoot "package.json"
    $packageJson = Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json
    return $packageJson.scripts.PSObject.Properties.Name -contains $Name
}

function Get-AlertSystemdSecretMarkerFindings {
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

$planResult = Invoke-AlertSystemdValidationChild -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $installScriptPath,
    "-Action",
    "Plan",
    "-OwnerEnvFile",
    $ownerEnvFile,
    "-ReportPath",
    $planReportFullPath,
    "-MarkdownPath",
    $planMarkdownFullPath
)
$planReport = Read-FlowChainJsonIfExists -Path $planReportFullPath
$planChecks = Get-AlertSystemdValidationProp -Object $planReport -Name "checks"
$planUnitPreview = Get-AlertSystemdValidationProp -Object $planReport -Name "unitPreview"
$planServiceUnit = [string](Get-AlertSystemdValidationProp -Object $planUnitPreview -Name "service" -Default "")
$planTimerUnit = [string](Get-AlertSystemdValidationProp -Object $planUnitPreview -Name "timer" -Default "")

$checks = [ordered]@{
    installScriptExists = Test-Path -LiteralPath $installScriptPath
    alertsScriptExists = Test-Path -LiteralPath $alertsScriptPath
    installPackageScriptPresent = Test-AlertSystemdPackageScript -Name "flowchain:ops:alerts:install:systemd"
    validationPackageScriptPresent = Test-AlertSystemdPackageScript -Name "flowchain:ops:alerts:install:systemd:validate"
    parentValidationPackageScriptPresent = Test-AlertSystemdPackageScript -Name "flowchain:ops:alerts:install:validate"
    planCommandPassed = [int]$planResult.exitCode -eq 0
    planReportWritten = Test-Path -LiteralPath $planReportFullPath
    planReportPassed = $null -ne $planReport -and [string](Get-AlertSystemdValidationProp -Object $planReport -Name "status" -Default "missing") -eq "passed"
    planActionReadOnly = (Get-AlertSystemdValidationProp -Object $planChecks -Name "planActionReadOnly" -Default $false) -eq $true
    planDidNotMutate = $null -ne $planReport -and (Get-AlertSystemdValidationProp -Object $planReport -Name "hostMutationPerformed" -Default $true) -eq $false
    serviceUnitPlanned = -not [string]::IsNullOrWhiteSpace($planServiceUnit) -and $planServiceUnit.Contains("Type=oneshot") -and $planServiceUnit.Contains("flowchain-ops-alerts.ps1")
    serviceUnitHasAllowBlocked = (Get-AlertSystemdValidationProp -Object $planChecks -Name "serviceUnitHasAllowBlocked" -Default $false) -eq $true
    serviceUnitHasReportPaths = (Get-AlertSystemdValidationProp -Object $planChecks -Name "serviceUnitHasReportPath" -Default $false) -eq $true `
        -and (Get-AlertSystemdValidationProp -Object $planChecks -Name "serviceUnitHasMarkdownPath" -Default $false) -eq $true `
        -and (Get-AlertSystemdValidationProp -Object $planChecks -Name "serviceUnitHasOpsSnapshotPath" -Default $false) -eq $true
    serviceUnitOwnerEnvFileInjectable = (Get-AlertSystemdValidationProp -Object $planChecks -Name "serviceUnitOwnerEnvFileInjectable" -Default $false) -eq $true
    serviceUnitHardeningPresent = (Get-AlertSystemdValidationProp -Object $planChecks -Name "serviceUnitHardeningPresent" -Default $false) -eq $true
    timerUnitPlanned = -not [string]::IsNullOrWhiteSpace($planTimerUnit) -and $planTimerUnit.Contains("Persistent=true") -and $planTimerUnit.Contains("WantedBy=timers.target")
    timerUnitIntervalConfigured = (Get-AlertSystemdValidationProp -Object $planChecks -Name "timerUnitIntervalConfigured" -Default $false) -eq $true
    noExternalDelivery = (Get-AlertSystemdValidationProp -Object $planChecks -Name "serviceUnitHasNoExternalDelivery" -Default $false) -eq $true
    commandPlanPresent = (Get-AlertSystemdValidationProp -Object $planChecks -Name "commandPlanPresent" -Default $false) -eq $true
    planReportEnvValuesPrintedFalse = $null -ne $planReport -and (Get-AlertSystemdValidationProp -Object $planReport -Name "envValuesPrinted" -Default $true) -eq $false
    planReportNoSecrets = $null -ne $planReport -and (Get-AlertSystemdValidationProp -Object $planReport -Name "noSecrets" -Default $false) -eq $true
    planReportBroadcastsFalse = $null -ne $planReport -and (Get-AlertSystemdValidationProp -Object $planReport -Name "broadcasts" -Default $true) -eq $false
    envValuesPrintedFalse = $true
    secretMarkerFindingsEmpty = $true
    noSecrets = $true
    broadcastsFalse = $true
}

$report = [ordered]@{
    schema = "flowchain.alert_install_systemd_validation_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "pending"
    paths = [ordered]@{
        installScript = $installScriptPath
        alertsScript = $alertsScriptPath
        planReport = $planReportFullPath
        planMarkdown = $planMarkdownFullPath
    }
    checks = $checks
    failedChecks = @()
    secretMarkerFindings = @()
    childProcessResults = @(
        [ordered]@{
            name = "alert-install-systemd-plan"
            exitCode = [int]$planResult.exitCode
            timedOut = [bool]$planResult.timedOut
            stdoutPath = [string]$planResult.stdoutPath
            stderrPath = [string]$planResult.stderrPath
        }
    )
    commands = [ordered]@{
        plan = "npm run flowchain:ops:alerts:install:systemd -- -Action Plan"
        install = "npm run flowchain:ops:alerts:install:systemd -- -Action Install"
        status = "npm run flowchain:ops:alerts:install:systemd -- -Action Status"
        uninstall = "npm run flowchain:ops:alerts:install:systemd -- -Action Uninstall"
        validate = "npm run flowchain:ops:alerts:install:systemd:validate"
    }
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$childReportSecretMarkerFindings = @(
    if ($null -ne $planReport) {
        Get-AlertSystemdSecretMarkerFindings -Text ($planReport | ConvertTo-Json -Depth 18) -Label "systemd alert install plan report"
    }
)
$preliminaryReportText = $report | ConvertTo-Json -Depth 18
$validationReportSecretMarkerFindings = @(Get-AlertSystemdSecretMarkerFindings -Text $preliminaryReportText -Label "systemd alert install validation report")
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
Assert-FlowChainNoSecretText -Text $reportText -Label "systemd alert install validation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Systemd Alert Install Validation")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This validation proves the Linux systemd timer path for recurring ops alert refresh is present, no-secret, non-mutating in Plan mode, and writes only local alert evidence.")
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
Assert-FlowChainNoSecretText -Text $markdownText -Label "systemd alert install validation markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain systemd alert install validation status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    Write-Host "Failed checks: $($failedChecks -join ', ')"
    exit 1
}
exit 0
