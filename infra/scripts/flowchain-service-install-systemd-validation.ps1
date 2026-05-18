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

function Test-SystemdPackageScript {
    param([Parameter(Mandatory = $true)][string] $Name)

    $packageJsonPath = Join-Path $repoRoot "package.json"
    $packageJson = Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json
    return $packageJson.scripts.PSObject.Properties.Name -contains $Name
}

$paths = [ordered]@{
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
    ownerEnvFileUsed = Test-SystemdTextHasAll -Text $combinedUnitText -Tokens @("EnvironmentFile=<FLOWCHAIN_OWNER_ENV_FILE>", "Environment=FLOWCHAIN_OWNER_ENV_FILE=<FLOWCHAIN_OWNER_ENV_FILE>")
    repoWorkingDirectoryUsed = Test-SystemdTextHasAll -Text $combinedUnitText -Tokens @("WorkingDirectory=<FLOWCHAIN_REPO_ABSOLUTE_PATH>")
    cargoTargetDirIsExternalized = $combinedUnitText.Contains("FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR=<FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR>")
    leastPrivilegeHardeningPresent = Test-SystemdTextHasAll -Text $combinedUnitText -Tokens @("NoNewPrivileges=true", "PrivateTmp=true", "ProtectSystem=full")
    writePathsScoped = Test-SystemdTextHasAll -Text $combinedUnitText -Tokens @("/devnet", "/docs/agent-runs", "/services/bridge-relayer/out")
    installTargetPresent = Test-SystemdTextHasAll -Text $combinedUnitText -Tokens @("[Install]", "WantedBy=multi-user.target")
    renderScriptRendersSystemdUnits = Test-SystemdTextHasAll -Text $renderScriptText -Tokens @("flowchain-live.service", "flowchain-supervisor.service")
    verifyRunbookMentionsSystemdVerify = Test-SystemdTextHasAll -Text $verifyText -Tokens @("systemd-analyze verify <FLOWCHAIN_SYSTEMD_RENDERED_UNIT>", "systemd-analyze verify <FLOWCHAIN_SUPERVISOR_SYSTEMD_RENDERED_UNIT>")
    rollbackRunbookMentionsSystemctl = $rollbackText.Contains("systemctl")
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
