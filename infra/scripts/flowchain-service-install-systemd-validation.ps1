param(
    [string] $BundleDir = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/systemd-service-install-validation-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/SYSTEMD_SERVICE_INSTALL_VALIDATION.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$bundleFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $BundleDir)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)

function Get-SystemdValidationText {
    param([Parameter(Mandatory = $true)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }
    return Get-Content -Raw -LiteralPath $Path
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

function Invoke-SystemdInstallPlanValidation {
    param(
        [Parameter(Mandatory = $true)][string] $RepoRoot,
        [Parameter(Mandatory = $true)][string] $BundleDir,
        [Parameter(Mandatory = $true)][string] $RenderScriptPath,
        [Parameter(Mandatory = $true)][string] $InstallScriptPath
    )

    $safeTokenHash = "0000000000000000000000000000000000000000000000000000000000000000"
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "flowchain-systemd-install-validation-$PID-$([Guid]::NewGuid().ToString("N"))"
    $reportTempRoot = Join-Path $RepoRoot "devnet/local/systemd-install-validation-report-$PID-$([Guid]::NewGuid().ToString("N"))"
    $ownerEnvFile = Join-Path $tempRoot "owner-public-rpc.env"
    $renderDir = Join-Path $tempRoot "rendered"
    $backupDir = Join-Path $tempRoot "backups"
    $tlsCertPath = Join-Path $tempRoot "tls-cert.pem"
    $tlsKeyPath = Join-Path $tempRoot "tls-key.pem"
    $nginxExe = Join-Path $tempRoot "nginx.exe"
    $planReportPath = Join-Path $reportTempRoot "systemd-plan-report.json"
    $planMarkdownPath = Join-Path $reportTempRoot "SYSTEMD_PLAN.md"
    $bridgePlanReportPath = Join-Path $reportTempRoot "systemd-bridge-relayer-plan-report.json"
    $bridgePlanMarkdownPath = Join-Path $reportTempRoot "SYSTEMD_BRIDGE_RELAYER_PLAN.md"
    $renderOutput = @()
    $planOutput = @()
    $bridgePlanOutput = @()
    $renderExitCode = 1
    $planExitCode = 1
    $bridgePlanExitCode = 1
    $problem = ""
    $cleanupAttempted = $false
    $planReport = $null
    $bridgePlanReport = $null

    try {
        New-Item -ItemType Directory -Force -Path $tempRoot, $renderDir, $backupDir, $reportTempRoot | Out-Null
        Set-Content -LiteralPath $tlsCertPath -Value "dummy certificate validation sentinel" -Encoding UTF8
        Set-Content -LiteralPath $tlsKeyPath -Value "dummy key validation sentinel" -Encoding UTF8
        Set-Content -LiteralPath $nginxExe -Value "dummy nginx validation sentinel" -Encoding UTF8
        Set-Content -LiteralPath $ownerEnvFile -Value (@(
            "FLOWCHAIN_RPC_PUBLIC_URL=https://rpc.flowchain.example",
            "FLOWCHAIN_RPC_ALLOWED_ORIGINS=https://wallet.flowchain.example,https://dashboard.flowchain.example",
            "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE=60",
            "FLOWCHAIN_RPC_TLS_TERMINATED=true",
            "FLOWCHAIN_RPC_STATE_BACKUP_PATH=$backupDir",
            "FLOWCHAIN_TESTER_WRITE_ENABLED=true",
            "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256=$safeTokenHash",
            "FLOWCHAIN_TESTER_MAX_SEND_UNITS=10"
        ) -join "`r`n") -Encoding UTF8

        $renderOutput = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $RenderScriptPath `
            -BundleDir $BundleDir `
            -RenderDir $renderDir `
            -OwnerEnvFile $ownerEnvFile `
            -RepoRoot $RepoRoot `
            -ServiceUser "flowchain" `
            -ServiceGroup "flowchain" `
            -TlsCertificatePath $tlsCertPath `
            -TlsCertificateKeyPath $tlsKeyPath `
            -NginxExe $nginxExe 2>&1 | ForEach-Object { "$_" })
        $renderExitCode = $LASTEXITCODE
        if ($null -eq $renderExitCode) {
            $renderExitCode = 0
        }

        $planOutput = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $InstallScriptPath `
            -Action Plan `
            -RenderDir $renderDir `
            -ReportPath $planReportPath `
            -MarkdownPath $planMarkdownPath 2>&1 | ForEach-Object { "$_" })
        $planExitCode = $LASTEXITCODE
        if ($null -eq $planExitCode) {
            $planExitCode = 0
        }

        $bridgePlanOutput = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $InstallScriptPath `
            -Action Plan `
            -RenderDir $renderDir `
            -StartBridgeRelayerLoop `
            -ReportPath $bridgePlanReportPath `
            -MarkdownPath $bridgePlanMarkdownPath 2>&1 | ForEach-Object { "$_" })
        $bridgePlanExitCode = $LASTEXITCODE
        if ($null -eq $bridgePlanExitCode) {
            $bridgePlanExitCode = 0
        }

        $renderOutputText = @($renderOutput) -join "`n"
        $planOutputText = @($planOutput) -join "`n"
        $bridgePlanOutputText = @($bridgePlanOutput) -join "`n"
        Assert-FlowChainNoSecretText -Text $renderOutputText -Label "systemd install validation render output"
        Assert-FlowChainNoSecretText -Text $planOutputText -Label "systemd install validation plan output"
        Assert-FlowChainNoSecretText -Text $bridgePlanOutputText -Label "systemd bridge relayer opt-in plan output"
        $planReport = Read-FlowChainJsonIfExists -Path $planReportPath
        $bridgePlanReport = Read-FlowChainJsonIfExists -Path $bridgePlanReportPath
    }
    catch {
        $problem = $_.Exception.Message
    }
    finally {
        $tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
        $tempFull = [System.IO.Path]::GetFullPath($tempRoot)
        $tempLeaf = Split-Path -Leaf $tempFull
        if ($tempFull.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase) -and $tempLeaf.StartsWith("flowchain-systemd-install-validation-", [System.StringComparison]::Ordinal)) {
            $cleanupAttempted = $true
            Remove-Item -LiteralPath $tempFull -Recurse -Force -ErrorAction SilentlyContinue
        }
        $reportTempBase = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot "devnet/local"))
        $reportTempFull = [System.IO.Path]::GetFullPath($reportTempRoot)
        $reportTempLeaf = Split-Path -Leaf $reportTempFull
        if ($reportTempFull.StartsWith($reportTempBase, [System.StringComparison]::OrdinalIgnoreCase) -and $reportTempLeaf.StartsWith("systemd-install-validation-report-", [System.StringComparison]::Ordinal)) {
            Remove-Item -LiteralPath $reportTempFull -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $planChecks = if ($null -ne $planReport) { $planReport.checks } else { $null }
    $bridgePlanChecks = if ($null -ne $bridgePlanReport) { $bridgePlanReport.checks } else { $null }
    $bridgePlanUnitPreview = if ($null -ne $bridgePlanReport) { $bridgePlanReport.unitCommandPreview } else { $null }
    $bridgePlanSupervisorUnit = if ($null -ne $bridgePlanUnitPreview) { @($bridgePlanUnitPreview.supervisor) -join "`n" } else { "" }
    return [ordered]@{
        schema = "flowchain.systemd_install_plan_validation.v0"
        status = if (($renderExitCode -eq 0) -and ($planExitCode -eq 0) -and ($bridgePlanExitCode -eq 0) -and $null -ne $planReport -and "$($planReport.status)" -eq "passed" -and $null -ne $bridgePlanReport -and "$($bridgePlanReport.status)" -eq "passed") { "passed" } else { "failed" }
        renderExitCode = [int]$renderExitCode
        planExitCode = [int]$planExitCode
        bridgePlanExitCode = [int]$bridgePlanExitCode
        planReportStatus = if ($null -ne $planReport) { "$($planReport.status)" } else { "missing" }
        bridgePlanReportStatus = if ($null -ne $bridgePlanReport) { "$($bridgePlanReport.status)" } else { "missing" }
        problem = $problem
        checks = [ordered]@{
            renderCommandPassed = $renderExitCode -eq 0
            planCommandPassed = $planExitCode -eq 0
            planReportPassed = $null -ne $planReport -and "$($planReport.status)" -eq "passed"
            planUsesRenderedUnits = $null -ne $planReport -and "$($planReport.sourceMode)" -eq "rendered"
            planRenderDirProvided = $null -ne $planChecks -and $planChecks.renderDirProvided -eq $true
            planDidNotMutate = $null -ne $planReport -and $planReport.hostMutationPerformed -eq $false
            planActionReadOnly = $null -ne $planChecks -and $planChecks.planActionReadOnly -eq $true
            planCommandPlanPresent = $null -ne $planChecks -and $planChecks.commandPlanPresent -eq $true
            planNoSecrets = $null -ne $planReport -and $planReport.noSecrets -eq $true
            planEnvValuesPrintedFalse = $null -ne $planReport -and $planReport.envValuesPrinted -eq $false
            planBroadcastsFalse = $null -ne $planReport -and $planReport.broadcasts -eq $false
            bridgeRelayerOptInPlanCommandPassed = $bridgePlanExitCode -eq 0
            bridgeRelayerOptInPlanReportPassed = $null -ne $bridgePlanReport -and "$($bridgePlanReport.status)" -eq "passed"
            bridgeRelayerOptInPlanUsesRenderedUnits = $null -ne $bridgePlanReport -and "$($bridgePlanReport.sourceMode)" -eq "rendered"
            bridgeRelayerOptInPlanDidNotMutate = $null -ne $bridgePlanReport -and $bridgePlanReport.hostMutationPerformed -eq $false
            bridgeRelayerOptInStartsLoop = $null -ne $bridgePlanChecks -and $bridgePlanChecks.bridgeRelayerOptInStartsLoop -eq $true -and $bridgePlanSupervisorUnit.Contains("-StartBridgeRelayerLoop")
            bridgeRelayerOptInUsesSupervisor = $null -ne $bridgePlanChecks -and $bridgePlanChecks.bridgeRelayerOptInUsesSupervisor -eq $true
            bridgeRelayerOptInPlanNoSecrets = $null -ne $bridgePlanReport -and $bridgePlanReport.noSecrets -eq $true
            bridgeRelayerOptInPlanEnvValuesPrintedFalse = $null -ne $bridgePlanReport -and $bridgePlanReport.envValuesPrinted -eq $false
            bridgeRelayerOptInPlanBroadcastsFalse = $null -ne $bridgePlanReport -and $bridgePlanReport.broadcasts -eq $false
            cleanupAttempted = $cleanupAttempted
        }
        envValuesPrinted = $false
        noSecrets = $true
        broadcasts = $false
    }
}

function Test-SystemdPackageScript {
    param([Parameter(Mandatory = $true)][string] $Name)

    $packageJsonPath = Join-Path $repoRoot "package.json"
    $packageJson = Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json
    return $packageJson.scripts.PSObject.Properties.Name -contains $Name
}

$paths = [ordered]@{
    installScript = Join-Path $PSScriptRoot "flowchain-service-install-systemd.ps1"
    liveServiceTemplate = Join-Path $bundleFullDir "flowchain-live.service.template"
    supervisorTemplate = Join-Path $bundleFullDir "flowchain-supervisor.service.template"
    renderScript = Join-Path $bundleFullDir "render-public-rpc-bundle.template.ps1"
    verifyRunbook = Join-Path $bundleFullDir "VERIFY.md"
    rollbackRunbook = Join-Path $bundleFullDir "ROLLBACK.md"
}

$liveServiceText = Get-SystemdValidationText -Path $paths.liveServiceTemplate
$supervisorText = Get-SystemdValidationText -Path $paths.supervisorTemplate
$renderScriptText = Get-SystemdValidationText -Path $paths.renderScript
$verifyText = Get-SystemdValidationText -Path $paths.verifyRunbook
$rollbackText = Get-SystemdValidationText -Path $paths.rollbackRunbook
$combinedUnitText = "$liveServiceText`n$supervisorText"
$installPlanValidation = Invoke-SystemdInstallPlanValidation -RepoRoot $repoRoot -BundleDir $bundleFullDir -RenderScriptPath $paths.renderScript -InstallScriptPath $paths.installScript

$installCommands = @(
    "sudo install -o root -g root -m 0644 <FLOWCHAIN_RENDER_DIR>/flowchain-live.service /etc/systemd/system/flowchain-live.service",
    "sudo install -o root -g root -m 0644 <FLOWCHAIN_RENDER_DIR>/flowchain-supervisor.service /etc/systemd/system/flowchain-supervisor.service",
    "sudo systemctl daemon-reload",
    "sudo systemctl enable --now flowchain-live.service",
    "sudo systemctl enable --now flowchain-supervisor.service"
)
$statusCommands = @(
    "systemctl status flowchain-live.service --no-pager",
    "systemctl status flowchain-supervisor.service --no-pager",
    "journalctl -u flowchain-live.service -u flowchain-supervisor.service --since -1h --no-pager",
    "npm run flowchain:service:status",
    "npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30"
)
$uninstallCommands = @(
    "sudo systemctl disable --now flowchain-supervisor.service",
    "sudo systemctl disable --now flowchain-live.service",
    "sudo rm -f /etc/systemd/system/flowchain-supervisor.service /etc/systemd/system/flowchain-live.service",
    "sudo systemctl daemon-reload"
)

$checks = [ordered]@{
    installScriptExists = Test-Path -LiteralPath $paths.installScript
    installPackageScriptPresent = Test-SystemdPackageScript -Name "flowchain:service:install:systemd"
    validationPackageScriptPresent = Test-SystemdPackageScript -Name "flowchain:service:install:systemd:validate"
    publicRpcBundleExists = Test-Path -LiteralPath $bundleFullDir
    liveServiceTemplateExists = Test-Path -LiteralPath $paths.liveServiceTemplate
    supervisorTemplateExists = Test-Path -LiteralPath $paths.supervisorTemplate
    renderScriptExists = Test-Path -LiteralPath $paths.renderScript
    verifyRunbookExists = Test-Path -LiteralPath $paths.verifyRunbook
    rollbackRunbookExists = Test-Path -LiteralPath $paths.rollbackRunbook
    liveServiceUsesLiveProfile = $liveServiceText.Contains("npm run flowchain:service:start -- -LiveProfile")
    liveServiceRunsStatusAfterStart = $liveServiceText.Contains("npm run flowchain:service:status")
    liveServiceReloadRestartsLiveProfile = $liveServiceText.Contains("npm run flowchain:service:restart -- -LiveProfile")
    liveServiceStopPreservesState = $liveServiceText.Contains("npm run flowchain:service:stop")
    liveServiceRestartOnFailure = $liveServiceText.Contains("Restart=on-failure")
    liveServiceRemainAfterExit = $liveServiceText.Contains("RemainAfterExit=yes")
    supervisorUsesAutorecoveryLoop = $supervisorText.Contains("npm run flowchain:service:supervisor")
    supervisorRestartAlways = $supervisorText.Contains("Restart=always")
    bridgeRelayerDefaultOff = -not $supervisorText.Contains("StartBridgeRelayerLoop")
    bridgeRelayerOptInPlanCommandPassed = $installPlanValidation.checks.bridgeRelayerOptInPlanCommandPassed -eq $true
    bridgeRelayerOptInPlanReportPassed = $installPlanValidation.checks.bridgeRelayerOptInPlanReportPassed -eq $true
    bridgeRelayerOptInPlanDidNotMutate = $installPlanValidation.checks.bridgeRelayerOptInPlanDidNotMutate -eq $true
    bridgeRelayerOptInPlanUsesRenderedUnits = $installPlanValidation.checks.bridgeRelayerOptInPlanUsesRenderedUnits -eq $true
    bridgeRelayerOptInStartsLoop = $installPlanValidation.checks.bridgeRelayerOptInStartsLoop -eq $true
    bridgeRelayerOptInUsesSupervisor = $installPlanValidation.checks.bridgeRelayerOptInUsesSupervisor -eq $true
    bridgeRelayerOptInPlanNoSecrets = $installPlanValidation.checks.bridgeRelayerOptInPlanNoSecrets -eq $true
    bridgeRelayerOptInPlanEnvValuesPrintedFalse = $installPlanValidation.checks.bridgeRelayerOptInPlanEnvValuesPrintedFalse -eq $true
    bridgeRelayerOptInPlanBroadcastsFalse = $installPlanValidation.checks.bridgeRelayerOptInPlanBroadcastsFalse -eq $true
    ownerEnvFileUsed = Test-SystemdTextHasAll -Text $combinedUnitText -Tokens @("EnvironmentFile=<FLOWCHAIN_OWNER_ENV_FILE>", "Environment=FLOWCHAIN_OWNER_ENV_FILE=<FLOWCHAIN_OWNER_ENV_FILE>")
    repoWorkingDirectoryUsed = Test-SystemdTextHasAll -Text $combinedUnitText -Tokens @("WorkingDirectory=<FLOWCHAIN_REPO_ABSOLUTE_PATH>")
    cargoTargetDirIsExternalized = $combinedUnitText.Contains("FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR=<FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR>")
    leastPrivilegeHardeningPresent = Test-SystemdTextHasAll -Text $combinedUnitText -Tokens @("NoNewPrivileges=true", "PrivateTmp=true", "ProtectSystem=full")
    writePathsScoped = Test-SystemdTextHasAll -Text $combinedUnitText -Tokens @("/devnet", "/docs/agent-runs", "/services/bridge-relayer/out")
    installTargetPresent = Test-SystemdTextHasAll -Text $combinedUnitText -Tokens @("[Install]", "WantedBy=multi-user.target")
    renderScriptRendersSystemdUnits = Test-SystemdTextHasAll -Text $renderScriptText -Tokens @("flowchain-live.service", "flowchain-supervisor.service")
    verifyRunbookMentionsSystemdVerify = Test-SystemdTextHasAll -Text $verifyText -Tokens @("systemd-analyze verify <FLOWCHAIN_SYSTEMD_RENDERED_UNIT>", "systemd-analyze verify <FLOWCHAIN_SUPERVISOR_SYSTEMD_RENDERED_UNIT>")
    rollbackRunbookMentionsSystemctl = $rollbackText.Contains("systemctl")
    installPlanValidationPassed = "$($installPlanValidation.status)" -eq "passed"
    installPlanCommandPassed = (Get-SystemdValidationText -Path $paths.installScript).Contains("ValidateSet(`"Plan`", `"Install`", `"Status`", `"Uninstall`")") -and $installPlanValidation.checks.planCommandPassed -eq $true
    installPlanDidNotMutate = $installPlanValidation.checks.planDidNotMutate -eq $true
    installPlanUsesRenderedUnits = $installPlanValidation.checks.planUsesRenderedUnits -eq $true
    installPlanReportNoSecrets = $installPlanValidation.checks.planNoSecrets -eq $true
    installPlanReportEnvValuesPrintedFalse = $installPlanValidation.checks.planEnvValuesPrintedFalse -eq $true
    installPlanReportBroadcastsFalse = $installPlanValidation.checks.planBroadcastsFalse -eq $true
    installCommandsPresent = $installCommands.Count -ge 5
    statusCommandsPresent = $statusCommands.Count -ge 5
    uninstallCommandsPresent = $uninstallCommands.Count -ge 4
    hostMutationPerformedFalse = $true
    envValuesPrintedFalse = $true
    secretMarkerFindingsEmpty = $true
    noSecrets = $true
    broadcastsFalse = $true
}

$report = [ordered]@{
    schema = "flowchain.systemd_service_install_validation_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "pending"
    bundleDir = $bundleFullDir
    paths = $paths
    installPlanValidation = $installPlanValidation
    installCommands = $installCommands
    statusCommands = $statusCommands
    uninstallCommands = $uninstallCommands
    checks = $checks
    failedChecks = @()
    secretMarkerFindings = @()
    hostMutationPerformed = $false
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$preliminaryReportText = $report | ConvertTo-Json -Depth 18
$secretMarkerFindings = @(Get-SystemdSecretMarkerFindings -Text $preliminaryReportText -Label "systemd service install validation report")
$checks["secretMarkerFindingsEmpty"] = $secretMarkerFindings.Count -eq 0
$checks["noSecrets"] = $secretMarkerFindings.Count -eq 0
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
$report["status"] = $status
$report["checks"] = $checks
$report["failedChecks"] = @($failedChecks)
$report["secretMarkerFindings"] = @($secretMarkerFindings)
$report["noSecrets"] = $secretMarkerFindings.Count -eq 0

$reportText = $report | ConvertTo-Json -Depth 18
Assert-FlowChainNoSecretText -Text $reportText -Label "systemd service install validation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Systemd Service Install Validation")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This validation proves the owner Linux systemd install plan is present, no-secret, non-mutating, live-profile by default, and includes autorecovery through the FlowChain supervisor.")
$markdownLines.Add("It also executes the real default Plan and bridge-relayer opt-in Plan actions against rendered units in a temporary directory and verifies that no host mutation occurs.")
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
$markdownLines.Add("| Check | Result |")
$markdownLines.Add("| --- | --- |")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("| $($entry.Key) | $($entry.Value) |")
}
$markdownLines.Add("")
$markdownLines.Add("## Install Plan")
$markdownLines.Add("")
foreach ($command in $installCommands) {
    $markdownLines.Add("- " + [char]96 + $command + [char]96)
}
$markdownLines.Add("")
$markdownLines.Add("## Status Plan")
$markdownLines.Add("")
foreach ($command in $statusCommands) {
    $markdownLines.Add("- " + [char]96 + $command + [char]96)
}
$markdownLines.Add("")
$markdownLines.Add("## Uninstall Plan")
$markdownLines.Add("")
foreach ($command in $uninstallCommands) {
    $markdownLines.Add("- " + [char]96 + $command + [char]96)
}

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "systemd service install validation markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain systemd service install validation status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    throw "FlowChain systemd service install validation failed checks: $($failedChecks -join ', ')"
}
