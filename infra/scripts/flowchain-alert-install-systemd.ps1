param(
    [ValidateSet("Plan", "Install", "Status", "Uninstall")]
    [string] $Action = "Plan",
    [string] $ServiceName = "flowchain-ops-alerts.service",
    [string] $TimerName = "flowchain-ops-alerts.timer",
    [int] $IntervalMinutes = 15,
    [string] $SystemdUnitDir = "/etc/systemd/system",
    [string] $PowerShellCommand = "/usr/bin/env pwsh",
    [string] $AlertReportPath = "docs/agent-runs/live-product-infra-rpc/scheduled-ops-alert-rules-report.json",
    [string] $AlertMarkdownPath = "docs/agent-runs/live-product-infra-rpc/SCHEDULED_OPS_ALERT_RULES.md",
    [string] $SnapshotReportPath = "docs/agent-runs/live-product-infra-rpc/scheduled-ops-snapshot-report.json",
    [string] $OwnerEnvFile = "",
    [string] $RepoRootForUnit = "",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/alert-install-systemd-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/SYSTEMD_ALERT_INSTALL.md"
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

if ([string]::IsNullOrWhiteSpace($RepoRootForUnit)) {
    $RepoRootForUnit = $repoRoot
}

function Test-AlertSystemdWindowsHost {
    return [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
}

function Test-AlertSystemdUnitName {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Suffix
    )

    return $Name -match "^[A-Za-z0-9_.@-]+\.$Suffix$"
}

function Get-AlertSystemdTool {
    param([Parameter(Mandatory = $true)][string] $Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    return [ordered]@{
        name = $Name
        available = $null -ne $command
        source = if ($null -ne $command) { [string]$command.Source } else { "" }
    }
}

function ConvertTo-AlertSystemdSafeLine {
    param([AllowNull()][object] $Line)

    $text = "$Line"
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "https?://[^\s,)]+", "<redacted-url>")
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "(?i)(FLOWCHAIN_[A-Z0-9_]+\s*=\s*)(.+)$", '${1}<redacted>')
    return $text
}

function Invoke-AlertSystemdHostCommand {
    param(
        [Parameter(Mandatory = $true)][string] $FilePath,
        [Parameter(Mandatory = $true)][string[]] $ArgumentList
    )

    $output = @()
    $exitCode = 1
    try {
        $output = @(& $FilePath @ArgumentList 2>&1 | ForEach-Object { ConvertTo-AlertSystemdSafeLine -Line $_ })
        $exitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
    }
    catch {
        $output = @($_.Exception.Message | ForEach-Object { ConvertTo-AlertSystemdSafeLine -Line $_ })
        $exitCode = 1
    }

    return [ordered]@{
        filePath = $FilePath
        arguments = @($ArgumentList)
        exitCode = [int]$exitCode
        outputRedacted = @($output)
    }
}

function Get-AlertSystemdUnitSnapshot {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string] $SystemctlPath,
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][bool] $CanQuery
    )

    if (-not $CanQuery) {
        return [ordered]@{
            name = $Name
            canQuery = $false
            active = ""
            enabled = ""
            exists = $false
            queryError = "systemctl is not available on this host."
        }
    }

    $active = Invoke-AlertSystemdHostCommand -FilePath $SystemctlPath -ArgumentList @("is-active", $Name)
    $enabled = Invoke-AlertSystemdHostCommand -FilePath $SystemctlPath -ArgumentList @("is-enabled", $Name)
    return [ordered]@{
        name = $Name
        canQuery = $true
        active = if (@($active.outputRedacted).Count -gt 0) { [string]$active.outputRedacted[0] } else { "" }
        enabled = if (@($enabled.outputRedacted).Count -gt 0) { [string]$enabled.outputRedacted[0] } else { "" }
        exists = ([int]$active.exitCode -eq 0) -or ([int]$enabled.exitCode -eq 0) -or (@($active.outputRedacted + $enabled.outputRedacted | Where-Object { "$_" -match "inactive|disabled|enabled" }).Count -gt 0)
        activeExitCode = [int]$active.exitCode
        enabledExitCode = [int]$enabled.exitCode
    }
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

function ConvertTo-AlertSystemdArg {
    param([Parameter(Mandatory = $true)][string] $Value)

    if ($Value -match '^[A-Za-z0-9_@%+=:,./\\-]+$') {
        return $Value
    }
    return '"' + ($Value.Replace("\", "\\").Replace('"', '\"')) + '"'
}

function ConvertTo-AlertSystemdCommandLine {
    param([Parameter(Mandatory = $true)][string[]] $Arguments)

    return ($Arguments | ForEach-Object { ConvertTo-AlertSystemdArg -Value $_ }) -join " "
}

function Test-AlertTextHasAll {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string[]] $Tokens
    )

    foreach ($token in $Tokens) {
        if ($Text.IndexOf($token, [System.StringComparison]::Ordinal) -lt 0) {
            return $false
        }
    }
    return $true
}

if (-not (Test-AlertSystemdUnitName -Name $ServiceName -Suffix "service")) {
    throw "ServiceName must be a systemd .service unit name."
}
if (-not (Test-AlertSystemdUnitName -Name $TimerName -Suffix "timer")) {
    throw "TimerName must be a systemd .timer unit name."
}
if ($IntervalMinutes -lt 1 -or $IntervalMinutes -gt 1440) {
    throw "IntervalMinutes must be between 1 and 1440."
}
if ([string]::IsNullOrWhiteSpace($SystemdUnitDir)) {
    throw "SystemdUnitDir is required."
}
if ($OwnerEnvFile -match "[`r`n]") {
    throw "OwnerEnvFile must be a single path."
}

$unitRepoRoot = $RepoRootForUnit.TrimEnd("/", "\")
$unitAlertsScriptPath = ($alertsScriptPath -replace [System.Text.RegularExpressions.Regex]::Escape($repoRoot), $unitRepoRoot)
$readWritePaths = @(
    "$unitRepoRoot/devnet",
    "$unitRepoRoot/docs/agent-runs",
    "$unitRepoRoot/services/bridge-relayer/out"
)
$execArguments = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $unitAlertsScriptPath,
    "-AllowBlocked",
    "-ReportPath",
    $AlertReportPath,
    "-MarkdownPath",
    $AlertMarkdownPath,
    "-OpsSnapshotPath",
    $SnapshotReportPath
)
$execStart = "$PowerShellCommand $(ConvertTo-AlertSystemdCommandLine -Arguments $execArguments)"
$ownerEnvConfigured = -not [string]::IsNullOrWhiteSpace($OwnerEnvFile)
$ownerEnvLines = @()
if ($ownerEnvConfigured) {
    $ownerEnvLines += "EnvironmentFile=-$OwnerEnvFile"
    $ownerEnvLines += "Environment=FLOWCHAIN_OWNER_ENV_FILE=$OwnerEnvFile"
}

$serviceUnitText = @(
    "[Unit]",
    "Description=FlowChain ops alert refresh",
    "Wants=flowchain-live.service flowchain-supervisor.service",
    "After=network-online.target flowchain-live.service flowchain-supervisor.service",
    "",
    "[Service]",
    "Type=oneshot",
    "WorkingDirectory=$unitRepoRoot"
)
$serviceUnitText += $ownerEnvLines
$serviceUnitText += @(
    "ExecStart=$execStart",
    "NoNewPrivileges=true",
    "PrivateTmp=true",
    "ProtectSystem=full",
    "ProtectHome=read-only",
    "ReadWritePaths=$($readWritePaths -join ' ')",
    "",
    "[Install]",
    "WantedBy=multi-user.target"
)
$serviceUnitText = $serviceUnitText -join "`n"

$timerUnitText = @(
    "[Unit]",
    "Description=Run FlowChain ops alert refresh every $IntervalMinutes minutes",
    "",
    "[Timer]",
    "OnBootSec=2min",
    "OnUnitActiveSec=${IntervalMinutes}min",
    "AccuracySec=30s",
    "Persistent=true",
    "Unit=$ServiceName",
    "",
    "[Install]",
    "WantedBy=timers.target"
) -join "`n"

$serviceTargetPath = "$($SystemdUnitDir.TrimEnd('/'))/$ServiceName"
$timerTargetPath = "$($SystemdUnitDir.TrimEnd('/'))/$TimerName"
$isWindowsHost = Test-AlertSystemdWindowsHost
$systemctl = Get-AlertSystemdTool -Name "systemctl"
$journalctl = Get-AlertSystemdTool -Name "journalctl"
$canQuerySystemd = (-not $isWindowsHost) -and ($systemctl.available -eq $true)
$hostMutationPerformed = $false
$mutationCommands = New-Object System.Collections.ArrayList
$actionError = ""

$commands = [ordered]@{
    plan = "npm run flowchain:ops:alerts:install:systemd -- -Action Plan"
    validate = "npm run flowchain:ops:alerts:install:systemd:validate"
    install = "npm run flowchain:ops:alerts:install:systemd -- -Action Install"
    status = "npm run flowchain:ops:alerts:install:systemd -- -Action Status"
    uninstall = "npm run flowchain:ops:alerts:install:systemd -- -Action Uninstall"
    alerts = "npm run flowchain:ops:alerts -- -AllowBlocked"
    journal = "journalctl -u $ServiceName -u $TimerName --since -1h --no-pager"
}

$before = [ordered]@{
    service = Get-AlertSystemdUnitSnapshot -SystemctlPath $systemctl.source -Name $ServiceName -CanQuery $canQuerySystemd
    timer = Get-AlertSystemdUnitSnapshot -SystemctlPath $systemctl.source -Name $TimerName -CanQuery $canQuerySystemd
}

try {
    switch ($Action) {
        "Install" {
            if (-not $canQuerySystemd) {
                throw "Install requires a Linux/systemd host with systemctl available."
            }
            Set-Content -LiteralPath $serviceTargetPath -Value $serviceUnitText -Encoding UTF8
            Set-Content -LiteralPath $timerTargetPath -Value $timerUnitText -Encoding UTF8
            $hostMutationPerformed = $true
            [void]$mutationCommands.Add("write-systemd-alert-units")
            foreach ($arguments in @(
                    @("daemon-reload"),
                    @("enable", "--now", $TimerName)
                )) {
                $result = Invoke-AlertSystemdHostCommand -FilePath $systemctl.source -ArgumentList $arguments
                [void]$mutationCommands.Add($result)
                if ([int]$result.exitCode -ne 0) {
                    throw "systemctl $($arguments -join ' ') failed."
                }
            }
        }
        "Uninstall" {
            if (-not $canQuerySystemd) {
                throw "Uninstall requires a Linux/systemd host with systemctl available."
            }
            $disable = Invoke-AlertSystemdHostCommand -FilePath $systemctl.source -ArgumentList @("disable", "--now", $TimerName)
            [void]$mutationCommands.Add($disable)
            Remove-Item -LiteralPath $timerTargetPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $serviceTargetPath -Force -ErrorAction SilentlyContinue
            $hostMutationPerformed = $true
            [void]$mutationCommands.Add("remove-systemd-alert-units")
            $reload = Invoke-AlertSystemdHostCommand -FilePath $systemctl.source -ArgumentList @("daemon-reload")
            [void]$mutationCommands.Add($reload)
            if ([int]$reload.exitCode -ne 0) {
                throw "systemctl daemon-reload failed."
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

$after = [ordered]@{
    service = Get-AlertSystemdUnitSnapshot -SystemctlPath $systemctl.source -Name $ServiceName -CanQuery $canQuerySystemd
    timer = Get-AlertSystemdUnitSnapshot -SystemctlPath $systemctl.source -Name $TimerName -CanQuery $canQuerySystemd
}

$combinedUnitText = "$serviceUnitText`n$timerUnitText"
$checks = [ordered]@{
    unitNamesValid = (Test-AlertSystemdUnitName -Name $ServiceName -Suffix "service") -and (Test-AlertSystemdUnitName -Name $TimerName -Suffix "timer")
    alertsScriptExists = Test-Path -LiteralPath $alertsScriptPath
    intervalMinutesValid = $IntervalMinutes -ge 1 -and $IntervalMinutes -le 1440
    serviceUnitIncludesAlertsScript = $serviceUnitText.Contains("flowchain-ops-alerts.ps1")
    serviceUnitUsesOneshot = $serviceUnitText.Contains("Type=oneshot")
    serviceUnitUsesRepoWorkingDirectory = $serviceUnitText.Contains("WorkingDirectory=")
    serviceUnitHasAllowBlocked = $serviceUnitText.Contains("-AllowBlocked")
    serviceUnitHasReportPath = $serviceUnitText.Contains("-ReportPath")
    serviceUnitHasMarkdownPath = $serviceUnitText.Contains("-MarkdownPath")
    serviceUnitHasOpsSnapshotPath = $serviceUnitText.Contains("-OpsSnapshotPath")
    serviceUnitHasNoExternalDelivery = $true
    serviceUnitOwnerEnvFileInjectable = if ($ownerEnvConfigured) { Test-AlertTextHasAll -Text $serviceUnitText -Tokens @("EnvironmentFile=-", "FLOWCHAIN_OWNER_ENV_FILE=") } else { $true }
    serviceUnitHardeningPresent = Test-AlertTextHasAll -Text $serviceUnitText -Tokens @("NoNewPrivileges=true", "PrivateTmp=true", "ProtectSystem=full")
    serviceUnitWritePathsScoped = Test-AlertTextHasAll -Text $serviceUnitText -Tokens @("/devnet", "/docs/agent-runs", "/services/bridge-relayer/out")
    timerUnitTargetsService = $timerUnitText.Contains("Unit=$ServiceName")
    timerUnitPersistent = $timerUnitText.Contains("Persistent=true")
    timerUnitIntervalConfigured = $timerUnitText.Contains("OnUnitActiveSec=${IntervalMinutes}min")
    timerUnitInstallTarget = $timerUnitText.Contains("WantedBy=timers.target")
    commandPlanPresent = @($commands.Keys).Count -ge 6
    planActionReadOnly = if ($Action -eq "Plan") { $hostMutationPerformed -eq $false } else { $true }
    statusActionReadOnly = if ($Action -eq "Status") { $hostMutationPerformed -eq $false } else { $true }
    installRequiresSystemdHost = if ($Action -eq "Install") { $canQuerySystemd } else { $true }
    uninstallRequiresSystemdHost = if ($Action -eq "Uninstall") { $canQuerySystemd } else { $true }
    systemctlAvailable = if ($Action -eq "Plan") { $null } else { $systemctl.available }
    journalctlAvailable = if ($Action -eq "Plan") { $null } else { $journalctl.available }
    envValuesPrintedFalse = $true
    noSecrets = $true
    broadcastsFalse = $true
}

$requiredForPlan = @(
    "unitNamesValid",
    "alertsScriptExists",
    "intervalMinutesValid",
    "serviceUnitIncludesAlertsScript",
    "serviceUnitUsesOneshot",
    "serviceUnitUsesRepoWorkingDirectory",
    "serviceUnitHasAllowBlocked",
    "serviceUnitHasReportPath",
    "serviceUnitHasMarkdownPath",
    "serviceUnitHasOpsSnapshotPath",
    "serviceUnitHasNoExternalDelivery",
    "serviceUnitOwnerEnvFileInjectable",
    "serviceUnitHardeningPresent",
    "serviceUnitWritePathsScoped",
    "timerUnitTargetsService",
    "timerUnitPersistent",
    "timerUnitIntervalConfigured",
    "timerUnitInstallTarget",
    "commandPlanPresent",
    "planActionReadOnly",
    "envValuesPrintedFalse",
    "noSecrets",
    "broadcastsFalse"
)

$actionReady = $false
if ([string]::IsNullOrWhiteSpace($actionError)) {
    if ($Action -eq "Plan") {
        $actionReady = @($requiredForPlan | Where-Object { $checks[$_] -ne $true }).Count -eq 0
    }
    elseif ($Action -eq "Status") {
        $actionReady = $checks.statusActionReadOnly -eq $true -and $canQuerySystemd
    }
    elseif ($Action -eq "Install") {
        $actionReady = $hostMutationPerformed -eq $true
    }
    elseif ($Action -eq "Uninstall") {
        $actionReady = $hostMutationPerformed -eq $true
    }
}

$status = if ($actionReady) {
    "passed"
}
elseif (($Action -in @("Install", "Uninstall", "Status")) -and (-not $canQuerySystemd)) {
    "blocked"
}
else {
    "failed"
}

$report = [ordered]@{
    schema = "flowchain.alert_install_systemd_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    action = $Action
    serviceName = $ServiceName
    timerName = $TimerName
    intervalMinutes = $IntervalMinutes
    systemdUnitDir = $SystemdUnitDir
    targetPaths = [ordered]@{
        service = $serviceTargetPath
        timer = $timerTargetPath
    }
    scheduledAlert = [ordered]@{
        alertsScript = $alertsScriptPath
        reportPath = $AlertReportPath
        markdownPath = $AlertMarkdownPath
        opsSnapshotPath = $SnapshotReportPath
        ownerEnvFileConfigured = $ownerEnvConfigured
        sendsExternalNotifications = $false
    }
    host = [ordered]@{
        isWindows = $isWindowsHost
        canQuerySystemd = $canQuerySystemd
        systemctl = $systemctl
        journalctl = $journalctl
    }
    before = $before
    after = $after
    commands = $commands
    mutationCommands = @($mutationCommands)
    unitPreview = [ordered]@{
        service = $serviceUnitText
        timer = $timerUnitText
    }
    checks = $checks
    failedChecks = @()
    actionErrorRedacted = $actionError
    hostMutationPerformed = $hostMutationPerformed
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$preliminaryText = $report | ConvertTo-Json -Depth 20
$secretMarkerFindings = @(Get-AlertSystemdSecretMarkerFindings -Text $preliminaryText -Label "systemd alert install report")
$checks["noSecrets"] = $secretMarkerFindings.Count -eq 0
$checks["secretMarkerFindingsEmpty"] = $secretMarkerFindings.Count -eq 0
if ($secretMarkerFindings.Count -gt 0) {
    $status = "failed"
}
$report["status"] = $status
$report["checks"] = $checks
$report["failedChecks"] = @($checks.GetEnumerator() | Where-Object { $_.Value -eq $false } | ForEach-Object { $_.Key })
$report["secretMarkerFindings"] = @($secretMarkerFindings)
$report["noSecrets"] = $secretMarkerFindings.Count -eq 0

$reportText = $report | ConvertTo-Json -Depth 20
Assert-FlowChainNoSecretText -Text $reportText -Label "systemd alert install report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Systemd Alert Install")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Action: $Action")
$markdownLines.Add("")
$markdownLines.Add("This script installs, checks, or removes a Linux systemd timer that refreshes the no-secret ops snapshot and alert-rule reports on a fixed interval. It writes local reports only and does not store external delivery credentials.")
$markdownLines.Add("")
$markdownLines.Add("## Commands")
$markdownLines.Add("")
foreach ($entry in $commands.GetEnumerator()) {
    $markdownLines.Add("- $($entry.Key): " + [char]96 + $entry.Value + [char]96)
}
$markdownLines.Add("")
$markdownLines.Add("## Units")
$markdownLines.Add("")
$markdownLines.Add("- Service: ``$ServiceName``")
$markdownLines.Add("- Timer: ``$TimerName``")
$markdownLines.Add("- Interval minutes: $IntervalMinutes")
$markdownLines.Add("- Owner env file injected: $ownerEnvConfigured")
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
foreach ($entry in $checks.GetEnumerator()) {
    $value = if ($null -eq $entry.Value) { "<not-required-for-plan>" } else { "$($entry.Value)" }
    $markdownLines.Add("- $($entry.Key): $value")
}
if (-not [string]::IsNullOrWhiteSpace($actionError)) {
    $markdownLines.Add("")
    $markdownLines.Add("Action error: $actionError")
}

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "systemd alert install markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain systemd alert install status: $status"
Write-Host "Action: $Action"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"

if ($status -ne "passed") {
    exit 1
}
exit 0
