param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-canary-schedule-validation-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/PUBLIC_RPC_CANARY_SCHEDULE_VALIDATION.md",
    [string] $ScheduledReportPath = "docs/agent-runs/live-product-infra-rpc/scheduled-public-rpc-synthetic-canary-report.json",
    [string] $ScheduledMarkdownPath = "docs/agent-runs/live-product-infra-rpc/SCHEDULED_PUBLIC_RPC_SYNTHETIC_CANARY.md",
    [string] $OwnerEnvFile = "devnet/local/owner-inputs/flowchain-owner.local.env",
    [int] $IntervalMinutes = 5
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$scheduledReportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ScheduledReportPath)
$scheduledMarkdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ScheduledMarkdownPath)
$canaryScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-public-rpc-synthetic-canary.ps1")
$packageJsonPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "package.json"
$repoRootFull = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)

if ($IntervalMinutes -lt 1 -or $IntervalMinutes -gt 1440) {
    throw "IntervalMinutes must be between 1 and 1440."
}
if ($OwnerEnvFile -match "[`r`n]") {
    throw "OwnerEnvFile must be a single path."
}

function Test-PublicRpcCanaryPackageScript {
    param([Parameter(Mandatory = $true)][string] $Name)

    $packageJson = Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json
    return $packageJson.scripts.PSObject.Properties.Name -contains $Name
}

function Get-PublicRpcCanarySecretMarkerFindings {
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

function ConvertTo-SystemdArg {
    param([Parameter(Mandatory = $true)][string] $Value)

    if ($Value -match '^[A-Za-z0-9_@%+=:,./\\-]+$') {
        return $Value
    }
    return '"' + ($Value.Replace("\", "\\").Replace('"', '\"')) + '"'
}

function Join-SystemdArgs {
    param([Parameter(Mandatory = $true)][string[]] $Arguments)

    return ($Arguments | ForEach-Object { ConvertTo-SystemdArg -Value $_ }) -join " "
}

function Test-PathInsideRepo {
    param([Parameter(Mandatory = $true)][string] $Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    return $fullPath.StartsWith($repoRootFull, [System.StringComparison]::OrdinalIgnoreCase)
}

$ownerEnvConfigured = -not [string]::IsNullOrWhiteSpace($OwnerEnvFile)
$canaryArguments = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $canaryScriptPath,
    "-AllowBlocked",
    "-ReportPath",
    $ScheduledReportPath,
    "-MarkdownPath",
    $ScheduledMarkdownPath
)

$escapedOwnerEnvFile = $OwnerEnvFile.Replace("'", "''")
$escapedCanaryScriptPath = $canaryScriptPath.Replace("'", "''")
$innerCommand = "`$env:FLOWCHAIN_OWNER_ENV_FILE='$escapedOwnerEnvFile'; & '$escapedCanaryScriptPath' -AllowBlocked -ReportPath '$ScheduledReportPath' -MarkdownPath '$ScheduledMarkdownPath'"
$windowsTaskPlan = [ordered]@{
    taskName = "FlowChainPublicRpcSyntheticCanary"
    taskPath = "\"
    intervalMinutes = $IntervalMinutes
    execute = "powershell.exe"
    arguments = Join-FlowChainProcessArguments -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        $innerCommand
    )
    workingDirectory = $repoRoot
    ownerEnvFileConfigured = $ownerEnvConfigured
    mutatesDuringValidation = $false
}

$unitRepoRoot = $repoRoot.TrimEnd("/", "\")
$unitCanaryScriptPath = ($canaryScriptPath -replace [System.Text.RegularExpressions.Regex]::Escape($repoRoot), $unitRepoRoot)
$systemdExecArguments = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $unitCanaryScriptPath,
    "-AllowBlocked",
    "-ReportPath",
    $ScheduledReportPath,
    "-MarkdownPath",
    $ScheduledMarkdownPath
)
$ownerEnvLines = @()
if ($ownerEnvConfigured) {
    $ownerEnvLines += "EnvironmentFile=-$OwnerEnvFile"
    $ownerEnvLines += "Environment=FLOWCHAIN_OWNER_ENV_FILE=$OwnerEnvFile"
}
$systemdService = @(
    "[Unit]",
    "Description=FlowChain public RPC synthetic canary",
    "Wants=network-online.target flowchain-live.service flowchain-supervisor.service",
    "After=network-online.target flowchain-live.service flowchain-supervisor.service",
    "",
    "[Service]",
    "Type=oneshot",
    "WorkingDirectory=$unitRepoRoot"
)
$systemdService += $ownerEnvLines
$systemdService += @(
    "ExecStart=/usr/bin/env pwsh $(Join-SystemdArgs -Arguments $systemdExecArguments)",
    "NoNewPrivileges=true",
    "PrivateTmp=true",
    "ProtectSystem=full",
    "ProtectHome=read-only",
    "ReadWritePaths=$unitRepoRoot/devnet $unitRepoRoot/docs/agent-runs",
    "",
    "[Install]",
    "WantedBy=multi-user.target"
)
$systemdServiceText = $systemdService -join "`n"
$systemdTimerText = @(
    "[Unit]",
    "Description=Run FlowChain public RPC synthetic canary every $IntervalMinutes minutes",
    "",
    "[Timer]",
    "OnBootSec=2min",
    "OnUnitActiveSec=${IntervalMinutes}min",
    "AccuracySec=30s",
    "Persistent=true",
    "Unit=flowchain-public-rpc-canary.service",
    "",
    "[Install]",
    "WantedBy=timers.target"
) -join "`n"

$commands = [ordered]@{
    validate = "npm run flowchain:public-rpc:canary:schedule:validate"
    canary = "npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked"
    windowsPlan = "Register Windows Scheduled Task FlowChainPublicRpcSyntheticCanary using the rendered action in this report"
    systemdPlan = "Install flowchain-public-rpc-canary.service and flowchain-public-rpc-canary.timer from the rendered units in this report"
    status = "Check the Windows task or systemd timer, then inspect $ScheduledReportPath"
}

$canaryScriptText = if (Test-Path -LiteralPath $canaryScriptPath) { Get-Content -Raw -LiteralPath $canaryScriptPath } else { "" }
$checks = [ordered]@{
    packageScriptPresent = Test-PublicRpcCanaryPackageScript -Name "flowchain:public-rpc:canary:schedule:validate"
    syntheticCanaryPackageScriptPresent = Test-PublicRpcCanaryPackageScript -Name "flowchain:public-rpc:synthetic-canary"
    canaryScriptExists = Test-Path -LiteralPath $canaryScriptPath
    canaryScriptReadOnlyPlan = $canaryScriptText.Contains("plannedReadPaths") -and $canaryScriptText.Contains("plannedReadMethods") -and $canaryScriptText.Contains("writeMethodDenylist")
    intervalMinutesValid = $IntervalMinutes -ge 1 -and $IntervalMinutes -le 1440
    scheduledReportPathInsideRepo = Test-PathInsideRepo -Path $scheduledReportFullPath
    scheduledMarkdownPathInsideRepo = Test-PathInsideRepo -Path $scheduledMarkdownFullPath
    windowsPlanRendered = -not [string]::IsNullOrWhiteSpace([string]$windowsTaskPlan.arguments)
    windowsPlanUsesCanaryScript = ([string]$windowsTaskPlan.arguments).Contains("flowchain-public-rpc-synthetic-canary.ps1")
    windowsPlanUsesOwnerEnvFile = ([string]$windowsTaskPlan.arguments).Contains("FLOWCHAIN_OWNER_ENV_FILE")
    windowsPlanHasAllowBlocked = ([string]$windowsTaskPlan.arguments).Contains("-AllowBlocked")
    windowsPlanHasReportPath = ([string]$windowsTaskPlan.arguments).Contains("-ReportPath")
    windowsPlanHasMarkdownPath = ([string]$windowsTaskPlan.arguments).Contains("-MarkdownPath")
    windowsPlanUsesRepoWorkingDirectory = [string]$windowsTaskPlan.workingDirectory -eq $repoRoot
    windowsPlanDoesNotMutateHost = $windowsTaskPlan.mutatesDuringValidation -eq $false
    systemdServiceRendered = $systemdServiceText.Contains("flowchain-public-rpc-synthetic-canary.ps1")
    systemdServiceUsesOneshot = $systemdServiceText.Contains("Type=oneshot")
    systemdServiceUsesOwnerEnvFile = $systemdServiceText.Contains("EnvironmentFile=-") -and $systemdServiceText.Contains("FLOWCHAIN_OWNER_ENV_FILE")
    systemdServiceHasAllowBlocked = $systemdServiceText.Contains("-AllowBlocked")
    systemdServiceHasReportPath = $systemdServiceText.Contains("-ReportPath")
    systemdServiceHasMarkdownPath = $systemdServiceText.Contains("-MarkdownPath")
    systemdServiceHardeningPresent = $systemdServiceText.Contains("NoNewPrivileges=true") -and $systemdServiceText.Contains("PrivateTmp=true") -and $systemdServiceText.Contains("ProtectSystem=full")
    systemdServiceWritePathsScoped = $systemdServiceText.Contains("/devnet") -and $systemdServiceText.Contains("/docs/agent-runs")
    systemdTimerRendered = $systemdTimerText.Contains("flowchain-public-rpc-canary.service")
    systemdTimerPersistent = $systemdTimerText.Contains("Persistent=true")
    systemdTimerIntervalConfigured = $systemdTimerText.Contains("OnUnitActiveSec=${IntervalMinutes}min")
    noExternalDelivery = $true
    hostMutationPerformedFalse = $true
    envValuesPrintedFalse = $true
    secretMarkerFindingsEmpty = $true
    noSecrets = $true
    broadcastsFalse = $true
}

$report = [ordered]@{
    schema = "flowchain.public_rpc_canary_schedule_validation_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "pending"
    intervalMinutes = $IntervalMinutes
    scheduledReportPath = $ScheduledReportPath
    scheduledMarkdownPath = $ScheduledMarkdownPath
    ownerEnvFileConfigured = $ownerEnvConfigured
    windowsTaskPlan = $windowsTaskPlan
    systemdPlan = [ordered]@{
        serviceName = "flowchain-public-rpc-canary.service"
        timerName = "flowchain-public-rpc-canary.timer"
        intervalMinutes = $IntervalMinutes
        unitPreview = [ordered]@{
            service = $systemdServiceText
            timer = $systemdTimerText
        }
    }
    commands = $commands
    checks = $checks
    failedChecks = @()
    secretMarkerFindings = @()
    hostMutationPerformed = $false
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$preliminaryText = $report | ConvertTo-Json -Depth 20
$secretMarkerFindings = @(Get-PublicRpcCanarySecretMarkerFindings -Text $preliminaryText -Label "public RPC canary schedule validation report")
$checks["secretMarkerFindingsEmpty"] = $secretMarkerFindings.Count -eq 0
$checks["noSecrets"] = $secretMarkerFindings.Count -eq 0
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
$report["status"] = $status
$report["checks"] = $checks
$report["failedChecks"] = @($failedChecks)
$report["secretMarkerFindings"] = @($secretMarkerFindings)
$report["noSecrets"] = $secretMarkerFindings.Count -eq 0

$reportText = $report | ConvertTo-Json -Depth 20
Assert-FlowChainNoSecretText -Text $reportText -Label "public RPC canary schedule validation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Public RPC Canary Schedule Validation")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This validation renders no-secret Windows Scheduled Task and Linux systemd timer plans for recurring read-only public RPC synthetic canary checks. It does not register tasks, mutate host services, send external notifications, or store owner endpoint values.")
$markdownLines.Add("")
$markdownLines.Add("## Commands")
$markdownLines.Add("")
foreach ($entry in $commands.GetEnumerator()) {
    $markdownLines.Add("- $($entry.Key): $($entry.Value)")
}
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
foreach ($entry in $checks.GetEnumerator()) {
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
Assert-FlowChainNoSecretText -Text $markdownText -Label "public RPC canary schedule validation markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain public RPC canary schedule validation status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    Write-Host "Failed checks: $($failedChecks -join ', ')"
    exit 1
}
exit 0
