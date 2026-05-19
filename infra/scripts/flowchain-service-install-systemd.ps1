param(
    [ValidateSet("Plan", "Install", "Status", "Uninstall")]
    [string] $Action = "Plan",
    [string] $BundleDir = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle",
    [string] $RenderDir = "",
    [string] $SystemdUnitDir = "/etc/systemd/system",
    [string] $LiveServiceName = "flowchain-live.service",
    [string] $SupervisorServiceName = "flowchain-supervisor.service",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/systemd-service-install-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/SYSTEMD_SERVICE_INSTALL.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$bundleFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $BundleDir)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)

function Test-SystemdWindowsHost {
    return [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
}

function Test-SystemdUnitName {
    param([Parameter(Mandatory = $true)][string] $Name)

    return $Name -match '^[A-Za-z0-9_.@-]+\.service$'
}

function Get-SystemdTool {
    param([Parameter(Mandatory = $true)][string] $Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    return [ordered]@{
        name = $Name
        available = $null -ne $command
        source = if ($null -ne $command) { [string]$command.Source } else { "" }
    }
}

function ConvertTo-SystemdSafeLine {
    param([AllowNull()][object] $Line)

    $text = "$Line"
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "https?://[^\s,)]+", "<redacted-url>")
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "(?i)(FLOWCHAIN_[A-Z0-9_]+\s*=\s*)(.+)$", '${1}<redacted>')
    return $text
}

function Invoke-SystemdHostCommand {
    param(
        [Parameter(Mandatory = $true)][string] $FilePath,
        [Parameter(Mandatory = $true)][string[]] $ArgumentList
    )

    $output = @()
    $exitCode = 1
    try {
        $output = @(& $FilePath @ArgumentList 2>&1 | ForEach-Object { ConvertTo-SystemdSafeLine -Line $_ })
        $exitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
    }
    catch {
        $output = @($_.Exception.Message | ForEach-Object { ConvertTo-SystemdSafeLine -Line $_ })
        $exitCode = 1
    }

    return [ordered]@{
        filePath = $FilePath
        arguments = @($ArgumentList)
        exitCode = [int]$exitCode
        outputRedacted = @($output)
    }
}

function Get-SystemdServiceSnapshot {
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

    $active = Invoke-SystemdHostCommand -FilePath $SystemctlPath -ArgumentList @("is-active", $Name)
    $enabled = Invoke-SystemdHostCommand -FilePath $SystemctlPath -ArgumentList @("is-enabled", $Name)
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

function Get-SystemdSecretMarkerFindings {
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

function Test-SystemdTextHasAll {
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

if (-not (Test-SystemdUnitName -Name $LiveServiceName)) {
    throw "LiveServiceName must be a systemd .service unit name."
}
if (-not (Test-SystemdUnitName -Name $SupervisorServiceName)) {
    throw "SupervisorServiceName must be a systemd .service unit name."
}
if ([string]::IsNullOrWhiteSpace($SystemdUnitDir)) {
    throw "SystemdUnitDir is required."
}

$renderDirProvided = -not [string]::IsNullOrWhiteSpace($RenderDir)
$renderFullDir = if ($renderDirProvided) { [System.IO.Path]::GetFullPath($RenderDir) } else { "" }
$liveSourcePath = if ($renderDirProvided) { Join-Path $renderFullDir $LiveServiceName } else { Join-Path $bundleFullDir "flowchain-live.service.template" }
$supervisorSourcePath = if ($renderDirProvided) { Join-Path $renderFullDir $SupervisorServiceName } else { Join-Path $bundleFullDir "flowchain-supervisor.service.template" }
$liveTargetPath = "$($SystemdUnitDir.TrimEnd('/'))/$LiveServiceName"
$supervisorTargetPath = "$($SystemdUnitDir.TrimEnd('/'))/$SupervisorServiceName"
$liveSourceExists = Test-Path -LiteralPath $liveSourcePath
$supervisorSourceExists = Test-Path -LiteralPath $supervisorSourcePath
$liveUnitText = if ($liveSourceExists) { Get-Content -Raw -LiteralPath $liveSourcePath } else { "" }
$supervisorUnitText = if ($supervisorSourceExists) { Get-Content -Raw -LiteralPath $supervisorSourcePath } else { "" }
$combinedUnitText = "$liveUnitText`n$supervisorUnitText"
$isWindowsHost = Test-SystemdWindowsHost
$systemctl = Get-SystemdTool -Name "systemctl"
$systemdAnalyze = Get-SystemdTool -Name "systemd-analyze"
$journalctl = Get-SystemdTool -Name "journalctl"
$canQuerySystemd = (-not $isWindowsHost) -and ($systemctl.available -eq $true)
$hostMutationPerformed = $false
$mutationCommands = New-Object System.Collections.ArrayList
$actionError = ""

$commands = [ordered]@{
    render = "npm run flowchain:public-rpc:deployment:automation -- -Action Render -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -OwnerEnvFile <FLOWCHAIN_OWNER_ENV_FILE> -TlsCertificatePath <PATH_TO_TLS_CERTIFICATE> -TlsCertificateKeyPath <PATH_TO_TLS_CERTIFICATE_KEY> -NginxExe <FLOWCHAIN_NGINX_EXE>"
    verifyLive = "systemd-analyze verify <FLOWCHAIN_DEPLOY_RENDER_DIR>/$LiveServiceName"
    verifySupervisor = "systemd-analyze verify <FLOWCHAIN_DEPLOY_RENDER_DIR>/$SupervisorServiceName"
    plan = "npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>"
    install = "npm run flowchain:service:install:systemd -- -Action Install -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>"
    status = "npm run flowchain:service:install:systemd -- -Action Status"
    uninstall = "npm run flowchain:service:install:systemd -- -Action Uninstall"
    serviceStatus = "npm run flowchain:service:status"
    serviceMonitor = "npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30"
}

$before = [ordered]@{
    live = Get-SystemdServiceSnapshot -SystemctlPath $systemctl.source -Name $LiveServiceName -CanQuery $canQuerySystemd
    supervisor = Get-SystemdServiceSnapshot -SystemctlPath $systemctl.source -Name $SupervisorServiceName -CanQuery $canQuerySystemd
}

try {
    switch ($Action) {
        "Install" {
            if (-not $canQuerySystemd) {
                throw "Install requires a Linux/systemd host with systemctl available."
            }
            if (-not $renderDirProvided -or -not $liveSourceExists -or -not $supervisorSourceExists) {
                throw "Install requires rendered $LiveServiceName and $SupervisorServiceName files in RenderDir."
            }

            Copy-Item -LiteralPath $liveSourcePath -Destination $liveTargetPath -Force
            Copy-Item -LiteralPath $supervisorSourcePath -Destination $supervisorTargetPath -Force
            $hostMutationPerformed = $true
            [void]$mutationCommands.Add("copy-rendered-units")
            foreach ($arguments in @(
                    @("daemon-reload"),
                    @("enable", "--now", $LiveServiceName),
                    @("enable", "--now", $SupervisorServiceName)
                )) {
                $result = Invoke-SystemdHostCommand -FilePath $systemctl.source -ArgumentList $arguments
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
            foreach ($arguments in @(
                    @("disable", "--now", $SupervisorServiceName),
                    @("disable", "--now", $LiveServiceName)
                )) {
                $result = Invoke-SystemdHostCommand -FilePath $systemctl.source -ArgumentList $arguments
                [void]$mutationCommands.Add($result)
            }
            Remove-Item -LiteralPath $supervisorTargetPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $liveTargetPath -Force -ErrorAction SilentlyContinue
            $hostMutationPerformed = $true
            [void]$mutationCommands.Add("remove-installed-units")
            $reload = Invoke-SystemdHostCommand -FilePath $systemctl.source -ArgumentList @("daemon-reload")
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
    live = Get-SystemdServiceSnapshot -SystemctlPath $systemctl.source -Name $LiveServiceName -CanQuery $canQuerySystemd
    supervisor = Get-SystemdServiceSnapshot -SystemctlPath $systemctl.source -Name $SupervisorServiceName -CanQuery $canQuerySystemd
}

$checks = [ordered]@{
    bundleDirExists = Test-Path -LiteralPath $bundleFullDir
    unitNamesValid = (Test-SystemdUnitName -Name $LiveServiceName) -and (Test-SystemdUnitName -Name $SupervisorServiceName)
    renderDirProvided = if ($renderDirProvided) { $true } else { $null }
    sourceModeRenderedWhenProvided = if ($renderDirProvided) { $true } else { $null }
    liveSourceExists = $liveSourceExists
    supervisorSourceExists = $supervisorSourceExists
    liveServiceUsesLiveProfile = $liveUnitText.Contains("npm run flowchain:service:start -- -LiveProfile")
    liveServiceRunsStatusAfterStart = $liveUnitText.Contains("npm run flowchain:service:status")
    liveServiceStopPreservesState = $liveUnitText.Contains("npm run flowchain:service:stop")
    liveServiceRestartOnFailure = $liveUnitText.Contains("Restart=on-failure")
    supervisorUsesAutorecoveryLoop = $supervisorUnitText.Contains("npm run flowchain:service:supervisor")
    supervisorRestartAlways = $supervisorUnitText.Contains("Restart=always")
    bridgeRelayerDefaultOff = -not $supervisorUnitText.Contains("StartBridgeRelayerLoop")
    ownerEnvFileUsed = Test-SystemdTextHasAll -Text $combinedUnitText -Tokens @("EnvironmentFile=", "FLOWCHAIN_OWNER_ENV_FILE=")
    repoWorkingDirectoryUsed = $combinedUnitText.Contains("WorkingDirectory=")
    leastPrivilegeHardeningPresent = Test-SystemdTextHasAll -Text $combinedUnitText -Tokens @("NoNewPrivileges=true", "PrivateTmp=true", "ProtectSystem=full")
    writePathsScoped = Test-SystemdTextHasAll -Text $combinedUnitText -Tokens @("/devnet", "/docs/agent-runs", "/services/bridge-relayer/out")
    installTargetPresent = Test-SystemdTextHasAll -Text $combinedUnitText -Tokens @("[Install]", "WantedBy=multi-user.target")
    planActionReadOnly = $Action -eq "Plan" -and $hostMutationPerformed -eq $false
    statusActionReadOnly = if ($Action -eq "Status") { $hostMutationPerformed -eq $false } else { $true }
    installRequiresRenderedUnits = if ($Action -eq "Install") { $renderDirProvided -and $liveSourceExists -and $supervisorSourceExists } else { $true }
    installRequiresSystemdHost = if ($Action -eq "Install") { $canQuerySystemd } else { $true }
    uninstallRequiresSystemdHost = if ($Action -eq "Uninstall") { $canQuerySystemd } else { $true }
    systemctlAvailable = if ($Action -eq "Plan") { $null } else { $systemctl.available }
    systemdAnalyzeAvailable = if ($Action -eq "Plan") { $null } else { $systemdAnalyze.available }
    journalctlAvailable = if ($Action -eq "Plan") { $null } else { $journalctl.available }
    commandPlanPresent = @($commands.Keys).Count -ge 8
    envValuesPrintedFalse = $true
    noSecrets = $true
    broadcastsFalse = $true
}

$requiredForPlan = @(
    "bundleDirExists",
    "unitNamesValid",
    "liveSourceExists",
    "supervisorSourceExists",
    "liveServiceUsesLiveProfile",
    "liveServiceRunsStatusAfterStart",
    "liveServiceStopPreservesState",
    "liveServiceRestartOnFailure",
    "supervisorUsesAutorecoveryLoop",
    "supervisorRestartAlways",
    "bridgeRelayerDefaultOff",
    "ownerEnvFileUsed",
    "repoWorkingDirectoryUsed",
    "leastPrivilegeHardeningPresent",
    "writePathsScoped",
    "installTargetPresent",
    "planActionReadOnly",
    "commandPlanPresent",
    "envValuesPrintedFalse",
    "noSecrets",
    "broadcastsFalse"
)

$failedChecks = New-Object System.Collections.ArrayList
foreach ($entry in $checks.GetEnumerator()) {
    if ($entry.Value -eq $false) {
        [void]$failedChecks.Add($entry.Key)
    }
}

$actionReady = $false
if ([string]::IsNullOrWhiteSpace($actionError)) {
    if ($Action -eq "Plan") {
        $actionReady = @($requiredForPlan | Where-Object { $checks[$_] -ne $true }).Count -eq 0
    }
    elseif ($Action -eq "Status") {
        $actionReady = $checks.statusActionReadOnly -eq $true
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
    schema = "flowchain.service_install_systemd_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    action = $Action
    sourceMode = if ($renderDirProvided) { "rendered" } else { "template-plan" }
    renderDir = $renderFullDir
    systemdUnitDir = $SystemdUnitDir
    liveServiceName = $LiveServiceName
    supervisorServiceName = $SupervisorServiceName
    sourcePaths = [ordered]@{
        live = $liveSourcePath
        supervisor = $supervisorSourcePath
    }
    targetPaths = [ordered]@{
        live = $liveTargetPath
        supervisor = $supervisorTargetPath
    }
    host = [ordered]@{
        isWindows = $isWindowsHost
        canQuerySystemd = $canQuerySystemd
        systemctl = $systemctl
        systemdAnalyze = $systemdAnalyze
        journalctl = $journalctl
    }
    before = $before
    after = $after
    commands = $commands
    mutationCommands = @($mutationCommands)
    checks = $checks
    failedChecks = @($failedChecks)
    actionErrorRedacted = $actionError
    hostMutationPerformed = $hostMutationPerformed
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$preliminaryText = $report | ConvertTo-Json -Depth 20
$secretMarkerFindings = @(Get-SystemdSecretMarkerFindings -Text $preliminaryText -Label "systemd service install report")
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
Assert-FlowChainNoSecretText -Text $reportText -Label "systemd service install report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Systemd Service Install")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Action: $Action")
$markdownLines.Add("")
$markdownLines.Add("This script installs, checks, or removes the rendered FlowChain live-service and supervisor systemd units on a Linux owner host. Plan mode is read-only and is the validation path used by this repository.")
$markdownLines.Add("")
$markdownLines.Add("## Commands")
$markdownLines.Add("")
foreach ($entry in $commands.GetEnumerator()) {
    $markdownLines.Add("- $($entry.Key): " + [char]96 + $entry.Value + [char]96)
}
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("- $($entry.Key): $($entry.Value)")
}
if (-not [string]::IsNullOrWhiteSpace($actionError)) {
    $markdownLines.Add("")
    $markdownLines.Add("Action error: $actionError")
}

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "systemd service install markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain systemd service install status: $status"
Write-Host "Action: $Action"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"

if ($status -ne "passed") {
    exit 1
}
exit 0
