param(
    [ValidateSet("Plan", "Install", "Status", "Uninstall")]
    [string] $Action = "Plan",
    [string] $BackupServiceName = "flowchain-state-backup.service",
    [string] $BackupTimerName = "flowchain-state-backup.timer",
    [string] $RestoreDrillServiceName = "flowchain-state-restore-drill.service",
    [string] $RestoreDrillTimerName = "flowchain-state-restore-drill.timer",
    [string] $At = "03:00",
    [string] $RestoreDrillAt = "03:15",
    [string] $SystemdUnitDir = "/etc/systemd/system",
    [string] $PowerShellCommand = "/usr/bin/env pwsh",
    [string] $StatePath = "devnet/local/state.json",
    [string] $BackupReportPath = "docs/agent-runs/live-product-infra-rpc/scheduled-state-backup-report.json",
    [string] $RestoreDrillReportPath = "docs/agent-runs/live-product-infra-rpc/scheduled-state-restore-verify-report.json",
    [string] $RestoreDrillRestoreRoot = "devnet/local/restore-rehearsal/scheduled",
    [int] $RetentionCount = 14,
    [string] $OwnerEnvFile = "",
    [string] $BackupRootWritePath = "",
    [string] $RepoRootForUnit = "",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/backup-install-systemd-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/SYSTEMD_BACKUP_INSTALL.md"
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

if ([string]::IsNullOrWhiteSpace($RepoRootForUnit)) {
    $RepoRootForUnit = $repoRoot
}

function Test-BackupSystemdWindowsHost {
    return [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
}

function Test-BackupSystemdUnitName {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Suffix
    )

    return $Name -match "^[A-Za-z0-9_.@-]+\.$Suffix$"
}

function Get-BackupSystemdTool {
    param([Parameter(Mandatory = $true)][string] $Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    return [ordered]@{
        name = $Name
        available = $null -ne $command
        source = if ($null -ne $command) { [string]$command.Source } else { "" }
    }
}

function ConvertTo-BackupSystemdSafeLine {
    param([AllowNull()][object] $Line)

    $text = "$Line"
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "https?://[^\s,)]+", "<redacted-url>")
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "(?i)(FLOWCHAIN_[A-Z0-9_]+\s*=\s*)(.+)$", '${1}<redacted>')
    return $text
}

function Invoke-BackupSystemdHostCommand {
    param(
        [Parameter(Mandatory = $true)][string] $FilePath,
        [Parameter(Mandatory = $true)][string[]] $ArgumentList
    )

    $output = @()
    $exitCode = 1
    try {
        $output = @(& $FilePath @ArgumentList 2>&1 | ForEach-Object { ConvertTo-BackupSystemdSafeLine -Line $_ })
        $exitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
    }
    catch {
        $output = @($_.Exception.Message | ForEach-Object { ConvertTo-BackupSystemdSafeLine -Line $_ })
        $exitCode = 1
    }

    return [ordered]@{
        filePath = $FilePath
        arguments = @($ArgumentList)
        exitCode = [int]$exitCode
        outputRedacted = @($output)
    }
}

function Get-BackupSystemdUnitSnapshot {
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

    $active = Invoke-BackupSystemdHostCommand -FilePath $SystemctlPath -ArgumentList @("is-active", $Name)
    $enabled = Invoke-BackupSystemdHostCommand -FilePath $SystemctlPath -ArgumentList @("is-enabled", $Name)
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

function ConvertTo-BackupSystemdArg {
    param([Parameter(Mandatory = $true)][string] $Value)

    if ($Value -match '^[A-Za-z0-9_@%+=:,./\\-]+$') {
        return $Value
    }
    return '"' + ($Value.Replace("\", "\\").Replace('"', '\"')) + '"'
}

function ConvertTo-BackupSystemdCommandLine {
    param([Parameter(Mandatory = $true)][string[]] $Arguments)

    return ($Arguments | ForEach-Object { ConvertTo-BackupSystemdArg -Value $_ }) -join " "
}

function Test-BackupTextHasAll {
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

function ConvertTo-OnCalendarTime {
    param([Parameter(Mandatory = $true)][string] $TimeText)

    if ($TimeText -notmatch '^(?:[01][0-9]|2[0-3]):[0-5][0-9]$') {
        throw "Time values must use HH:mm 24-hour time."
    }
    return "*-*-* $TimeText`:00"
}

foreach ($entry in @(
        @{ Name = $BackupServiceName; Suffix = "service" },
        @{ Name = $BackupTimerName; Suffix = "timer" },
        @{ Name = $RestoreDrillServiceName; Suffix = "service" },
        @{ Name = $RestoreDrillTimerName; Suffix = "timer" }
    )) {
    if (-not (Test-BackupSystemdUnitName -Name $entry.Name -Suffix $entry.Suffix)) {
        throw "$($entry.Name) must be a systemd .$($entry.Suffix) unit name."
    }
}
if ($RetentionCount -lt 1) {
    throw "RetentionCount must be at least 1."
}
if ([string]::IsNullOrWhiteSpace($SystemdUnitDir)) {
    throw "SystemdUnitDir is required."
}
if ($OwnerEnvFile -match "[`r`n]") {
    throw "OwnerEnvFile must be a single path."
}
if ($BackupRootWritePath -match "[`r`n]") {
    throw "BackupRootWritePath must be a single path."
}

$backupCalendar = ConvertTo-OnCalendarTime -TimeText $At
$restoreDrillCalendar = ConvertTo-OnCalendarTime -TimeText $RestoreDrillAt
$unitRepoRoot = $RepoRootForUnit.TrimEnd("/", "\")
$unitBackupScriptPath = ($backupScriptPath -replace [System.Text.RegularExpressions.Regex]::Escape($repoRoot), $unitRepoRoot)
$unitRestoreDrillScriptPath = ($restoreDrillScriptPath -replace [System.Text.RegularExpressions.Regex]::Escape($repoRoot), $unitRepoRoot)
$readWritePaths = @(
    "$unitRepoRoot/devnet",
    "$unitRepoRoot/docs/agent-runs"
)
if (-not [string]::IsNullOrWhiteSpace($BackupRootWritePath)) {
    $readWritePaths += $BackupRootWritePath
}
$ownerEnvConfigured = -not [string]::IsNullOrWhiteSpace($OwnerEnvFile)
$ownerEnvLines = @()
if ($ownerEnvConfigured) {
    $ownerEnvLines += "EnvironmentFile=-$OwnerEnvFile"
    $ownerEnvLines += "Environment=FLOWCHAIN_OWNER_ENV_FILE=$OwnerEnvFile"
}

$backupExecArguments = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $unitBackupScriptPath,
    "-StatePath",
    $StatePath,
    "-ReportPath",
    $BackupReportPath,
    "-RetentionCount",
    "$RetentionCount"
)
$restoreDrillExecArguments = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $unitRestoreDrillScriptPath,
    "-ReportPath",
    $RestoreDrillReportPath,
    "-RestoreRoot",
    $RestoreDrillRestoreRoot,
    "-StatePath",
    $StatePath
)
$backupExecStart = "$PowerShellCommand $(ConvertTo-BackupSystemdCommandLine -Arguments $backupExecArguments)"
$restoreDrillExecStart = "$PowerShellCommand $(ConvertTo-BackupSystemdCommandLine -Arguments $restoreDrillExecArguments)"

function New-BackupServiceUnitText {
    param(
        [Parameter(Mandatory = $true)][string] $Description,
        [Parameter(Mandatory = $true)][string] $ExecStart
    )

    $lines = @(
        "[Unit]",
        "Description=$Description",
        "After=network-online.target flowchain-live.service",
        "Wants=flowchain-live.service",
        "",
        "[Service]",
        "Type=oneshot",
        "WorkingDirectory=$unitRepoRoot"
    )
    $lines += $ownerEnvLines
    $lines += @(
        "ExecStart=$ExecStart",
        "NoNewPrivileges=true",
        "PrivateTmp=true",
        "ProtectSystem=full",
        "ProtectHome=read-only",
        "ReadWritePaths=$($readWritePaths -join ' ')",
        "",
        "[Install]",
        "WantedBy=multi-user.target"
    )
    return $lines -join "`n"
}

function New-BackupTimerUnitText {
    param(
        [Parameter(Mandatory = $true)][string] $Description,
        [Parameter(Mandatory = $true)][string] $OnCalendar,
        [Parameter(Mandatory = $true)][string] $ServiceName
    )

    return @(
        "[Unit]",
        "Description=$Description",
        "",
        "[Timer]",
        "OnCalendar=$OnCalendar",
        "AccuracySec=1min",
        "Persistent=true",
        "Unit=$ServiceName",
        "",
        "[Install]",
        "WantedBy=timers.target"
    ) -join "`n"
}

$backupServiceUnitText = New-BackupServiceUnitText -Description "FlowChain state backup" -ExecStart $backupExecStart
$restoreDrillServiceUnitText = New-BackupServiceUnitText -Description "FlowChain state restore drill" -ExecStart $restoreDrillExecStart
$backupTimerUnitText = New-BackupTimerUnitText -Description "Run FlowChain state backup daily" -OnCalendar $backupCalendar -ServiceName $BackupServiceName
$restoreDrillTimerUnitText = New-BackupTimerUnitText -Description "Run FlowChain state restore drill daily" -OnCalendar $restoreDrillCalendar -ServiceName $RestoreDrillServiceName

$targetPaths = [ordered]@{
    backupService = "$($SystemdUnitDir.TrimEnd('/'))/$BackupServiceName"
    backupTimer = "$($SystemdUnitDir.TrimEnd('/'))/$BackupTimerName"
    restoreDrillService = "$($SystemdUnitDir.TrimEnd('/'))/$RestoreDrillServiceName"
    restoreDrillTimer = "$($SystemdUnitDir.TrimEnd('/'))/$RestoreDrillTimerName"
}
$isWindowsHost = Test-BackupSystemdWindowsHost
$systemctl = Get-BackupSystemdTool -Name "systemctl"
$journalctl = Get-BackupSystemdTool -Name "journalctl"
$canQuerySystemd = (-not $isWindowsHost) -and ($systemctl.available -eq $true)
$hostMutationPerformed = $false
$mutationCommands = New-Object System.Collections.ArrayList
$actionError = ""

$commands = [ordered]@{
    plan = "npm run flowchain:backup:install:systemd -- -Action Plan"
    validate = "npm run flowchain:backup:install:systemd:validate"
    install = "npm run flowchain:backup:install:systemd -- -Action Install"
    status = "npm run flowchain:backup:install:systemd -- -Action Status"
    uninstall = "npm run flowchain:backup:install:systemd -- -Action Uninstall"
    backupCheck = "npm run flowchain:backup:check -- -AllowBlocked"
    journal = "journalctl -u $BackupServiceName -u $BackupTimerName -u $RestoreDrillServiceName -u $RestoreDrillTimerName --since -24h --no-pager"
}

$before = [ordered]@{
    backupService = Get-BackupSystemdUnitSnapshot -SystemctlPath $systemctl.source -Name $BackupServiceName -CanQuery $canQuerySystemd
    backupTimer = Get-BackupSystemdUnitSnapshot -SystemctlPath $systemctl.source -Name $BackupTimerName -CanQuery $canQuerySystemd
    restoreDrillService = Get-BackupSystemdUnitSnapshot -SystemctlPath $systemctl.source -Name $RestoreDrillServiceName -CanQuery $canQuerySystemd
    restoreDrillTimer = Get-BackupSystemdUnitSnapshot -SystemctlPath $systemctl.source -Name $RestoreDrillTimerName -CanQuery $canQuerySystemd
}

try {
    switch ($Action) {
        "Install" {
            if (-not $canQuerySystemd) {
                throw "Install requires a Linux/systemd host with systemctl available."
            }
            Set-Content -LiteralPath $targetPaths.backupService -Value $backupServiceUnitText -Encoding UTF8
            Set-Content -LiteralPath $targetPaths.backupTimer -Value $backupTimerUnitText -Encoding UTF8
            Set-Content -LiteralPath $targetPaths.restoreDrillService -Value $restoreDrillServiceUnitText -Encoding UTF8
            Set-Content -LiteralPath $targetPaths.restoreDrillTimer -Value $restoreDrillTimerUnitText -Encoding UTF8
            $hostMutationPerformed = $true
            [void]$mutationCommands.Add("write-systemd-backup-units")
            foreach ($arguments in @(
                    @("daemon-reload"),
                    @("enable", "--now", $BackupTimerName),
                    @("enable", "--now", $RestoreDrillTimerName)
                )) {
                $result = Invoke-BackupSystemdHostCommand -FilePath $systemctl.source -ArgumentList $arguments
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
            foreach ($timerName in @($RestoreDrillTimerName, $BackupTimerName)) {
                $disable = Invoke-BackupSystemdHostCommand -FilePath $systemctl.source -ArgumentList @("disable", "--now", $timerName)
                [void]$mutationCommands.Add($disable)
            }
            foreach ($path in @($targetPaths.restoreDrillTimer, $targetPaths.restoreDrillService, $targetPaths.backupTimer, $targetPaths.backupService)) {
                Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            }
            $hostMutationPerformed = $true
            [void]$mutationCommands.Add("remove-systemd-backup-units")
            $reload = Invoke-BackupSystemdHostCommand -FilePath $systemctl.source -ArgumentList @("daemon-reload")
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
    backupService = Get-BackupSystemdUnitSnapshot -SystemctlPath $systemctl.source -Name $BackupServiceName -CanQuery $canQuerySystemd
    backupTimer = Get-BackupSystemdUnitSnapshot -SystemctlPath $systemctl.source -Name $BackupTimerName -CanQuery $canQuerySystemd
    restoreDrillService = Get-BackupSystemdUnitSnapshot -SystemctlPath $systemctl.source -Name $RestoreDrillServiceName -CanQuery $canQuerySystemd
    restoreDrillTimer = Get-BackupSystemdUnitSnapshot -SystemctlPath $systemctl.source -Name $RestoreDrillTimerName -CanQuery $canQuerySystemd
}

$combinedUnitText = "$backupServiceUnitText`n$backupTimerUnitText`n$restoreDrillServiceUnitText`n$restoreDrillTimerUnitText"
$checks = [ordered]@{
    unitNamesValid = (Test-BackupSystemdUnitName -Name $BackupServiceName -Suffix "service") -and (Test-BackupSystemdUnitName -Name $BackupTimerName -Suffix "timer") -and (Test-BackupSystemdUnitName -Name $RestoreDrillServiceName -Suffix "service") -and (Test-BackupSystemdUnitName -Name $RestoreDrillTimerName -Suffix "timer")
    backupScriptExists = Test-Path -LiteralPath $backupScriptPath
    restoreDrillScriptExists = Test-Path -LiteralPath $restoreDrillScriptPath
    retentionCountValid = $RetentionCount -ge 1
    backupServiceUsesOneshot = $backupServiceUnitText.Contains("Type=oneshot")
    backupServiceUsesBackupScript = $backupServiceUnitText.Contains("flowchain-state-backup.ps1")
    backupServiceHasStatePath = $backupServiceUnitText.Contains("-StatePath")
    backupServiceHasReportPath = $backupServiceUnitText.Contains("-ReportPath")
    backupServiceHasRetentionCount = $backupServiceUnitText.Contains("-RetentionCount")
    backupServiceOmitsAllowBlocked = $backupServiceUnitText -notmatch "(^|\s)-AllowBlocked(\s|$)"
    restoreDrillServiceUsesOneshot = $restoreDrillServiceUnitText.Contains("Type=oneshot")
    restoreDrillServiceUsesRestoreScript = $restoreDrillServiceUnitText.Contains("flowchain-state-restore-verify.ps1")
    restoreDrillServiceHasRestoreRoot = $restoreDrillServiceUnitText.Contains("-RestoreRoot")
    restoreDrillServiceHasStatePath = $restoreDrillServiceUnitText.Contains("-StatePath")
    restoreDrillServiceHasReportPath = $restoreDrillServiceUnitText.Contains("-ReportPath")
    restoreDrillServiceOmitsAllowBlocked = $restoreDrillServiceUnitText -notmatch "(^|\s)-AllowBlocked(\s|$)"
    servicesUseRepoWorkingDirectory = $combinedUnitText.Contains("WorkingDirectory=")
    servicesOwnerEnvFileInjectable = if ($ownerEnvConfigured) { Test-BackupTextHasAll -Text $combinedUnitText -Tokens @("EnvironmentFile=-", "FLOWCHAIN_OWNER_ENV_FILE=") } else { $true }
    servicesHardeningPresent = Test-BackupTextHasAll -Text $combinedUnitText -Tokens @("NoNewPrivileges=true", "PrivateTmp=true", "ProtectSystem=full")
    servicesWritePathsScoped = Test-BackupTextHasAll -Text $combinedUnitText -Tokens @("/devnet", "/docs/agent-runs")
    backupRootWritePathConfigurable = if ([string]::IsNullOrWhiteSpace($BackupRootWritePath)) { $true } else { $combinedUnitText.Contains($BackupRootWritePath) }
    backupTimerTargetsService = $backupTimerUnitText.Contains("Unit=$BackupServiceName")
    restoreDrillTimerTargetsService = $restoreDrillTimerUnitText.Contains("Unit=$RestoreDrillServiceName")
    backupTimerCalendarConfigured = $backupTimerUnitText.Contains("OnCalendar=$backupCalendar")
    restoreDrillTimerCalendarConfigured = $restoreDrillTimerUnitText.Contains("OnCalendar=$restoreDrillCalendar")
    backupTimerPersistent = $backupTimerUnitText.Contains("Persistent=true")
    restoreDrillTimerPersistent = $restoreDrillTimerUnitText.Contains("Persistent=true")
    timerInstallTargetsPresent = Test-BackupTextHasAll -Text "$backupTimerUnitText`n$restoreDrillTimerUnitText" -Tokens @("WantedBy=timers.target")
    ownerBackupEnvRequiredByRuntime = $backupServiceUnitText.Contains("FLOWCHAIN_RPC_STATE_BACKUP_PATH") -eq $false
    restoreDrillOwnerBackupEnvRequiredByRuntime = $restoreDrillServiceUnitText.Contains("FLOWCHAIN_RPC_STATE_BACKUP_PATH") -eq $false
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
    "backupScriptExists",
    "restoreDrillScriptExists",
    "retentionCountValid",
    "backupServiceUsesOneshot",
    "backupServiceUsesBackupScript",
    "backupServiceHasStatePath",
    "backupServiceHasReportPath",
    "backupServiceHasRetentionCount",
    "backupServiceOmitsAllowBlocked",
    "restoreDrillServiceUsesOneshot",
    "restoreDrillServiceUsesRestoreScript",
    "restoreDrillServiceHasRestoreRoot",
    "restoreDrillServiceHasStatePath",
    "restoreDrillServiceHasReportPath",
    "restoreDrillServiceOmitsAllowBlocked",
    "servicesUseRepoWorkingDirectory",
    "servicesOwnerEnvFileInjectable",
    "servicesHardeningPresent",
    "servicesWritePathsScoped",
    "backupRootWritePathConfigurable",
    "backupTimerTargetsService",
    "restoreDrillTimerTargetsService",
    "backupTimerCalendarConfigured",
    "restoreDrillTimerCalendarConfigured",
    "backupTimerPersistent",
    "restoreDrillTimerPersistent",
    "timerInstallTargetsPresent",
    "ownerBackupEnvRequiredByRuntime",
    "restoreDrillOwnerBackupEnvRequiredByRuntime",
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
    schema = "flowchain.backup_install_systemd_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    action = $Action
    backupServiceName = $BackupServiceName
    backupTimerName = $BackupTimerName
    restoreDrillServiceName = $RestoreDrillServiceName
    restoreDrillTimerName = $RestoreDrillTimerName
    dailyAt = $At
    restoreDrillDailyAt = $RestoreDrillAt
    backupCalendar = $backupCalendar
    restoreDrillCalendar = $restoreDrillCalendar
    systemdUnitDir = $SystemdUnitDir
    targetPaths = $targetPaths
    scheduledBackup = [ordered]@{
        backupScript = $backupScriptPath
        restoreDrillScript = $restoreDrillScriptPath
        statePath = $StatePath
        backupReportPath = $BackupReportPath
        restoreDrillReportPath = $RestoreDrillReportPath
        restoreDrillRestoreRoot = $RestoreDrillRestoreRoot
        retentionCount = $RetentionCount
        ownerEnvFileConfigured = $ownerEnvConfigured
        backupRootWritePathConfigured = -not [string]::IsNullOrWhiteSpace($BackupRootWritePath)
        requiredEnvNames = @("FLOWCHAIN_RPC_STATE_BACKUP_PATH")
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
        backupService = $backupServiceUnitText
        backupTimer = $backupTimerUnitText
        restoreDrillService = $restoreDrillServiceUnitText
        restoreDrillTimer = $restoreDrillTimerUnitText
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
$secretMarkerFindings = @(Get-BackupSystemdSecretMarkerFindings -Text $preliminaryText -Label "systemd backup install report")
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
Assert-FlowChainNoSecretText -Text $reportText -Label "systemd backup install report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Systemd Backup Install")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Action: $Action")
$markdownLines.Add("")
$markdownLines.Add("This script installs, checks, or removes Linux systemd timers for manifest-backed state backups and restore-drill verification. Plan mode is read-only and the scheduled units fail closed until the owner backup path env is configured.")
$markdownLines.Add("")
$markdownLines.Add("## Commands")
$markdownLines.Add("")
foreach ($entry in $commands.GetEnumerator()) {
    $markdownLines.Add("- $($entry.Key): " + [char]96 + $entry.Value + [char]96)
}
$markdownLines.Add("")
$markdownLines.Add("## Units")
$markdownLines.Add("")
$markdownLines.Add("- Backup service: ``$BackupServiceName``")
$markdownLines.Add("- Backup timer: ``$BackupTimerName`` at ``$backupCalendar``")
$markdownLines.Add("- Restore drill service: ``$RestoreDrillServiceName``")
$markdownLines.Add("- Restore drill timer: ``$RestoreDrillTimerName`` at ``$restoreDrillCalendar``")
$markdownLines.Add("- Retention count: $RetentionCount")
$markdownLines.Add("- Owner env file injected: $ownerEnvConfigured")
$markdownLines.Add("- Backup root write path configured: $(-not [string]::IsNullOrWhiteSpace($BackupRootWritePath))")
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
Assert-FlowChainNoSecretText -Text $markdownText -Label "systemd backup install markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain systemd backup install status: $status"
Write-Host "Action: $Action"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"

if ($status -ne "passed") {
    exit 1
}
exit 0
