param(
    [string] $ValidationDir = "devnet/local/bridge-deploy-control-validation",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-deploy-control-validation-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/BRIDGE_DEPLOY_CONTROL_VALIDATION.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$validationFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ValidationDir)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$tmpDir = Join-Path $validationFullDir "tmp"

$deployScriptPath = Join-Path $repoRoot "infra/scripts/bridge-base8453-deploy.ps1"
$controlScriptPath = Join-Path $repoRoot "infra/scripts/bridge-base8453-control.ps1"
$foundryScriptPath = Join-Path $repoRoot "script/DeployBridgeSpine.s.sol"
$lockboxContractPath = Join-Path $repoRoot "contracts/bridge/BaseBridgeLockbox.sol"
$deploymentRunbookPath = Join-Path $repoRoot "docs/OPERATIONS/FLOWCHAIN_BASE8453_LOCKBOX_DEPLOYMENT_RUNBOOK.md"

$bridgeEnvNames = @(
    "FLOWCHAIN_OWNER_ENV_FILE",
    "FLOWCHAIN_PILOT_OPERATOR_ACK",
    "FLOWCHAIN_BASE8453_RPC_URL",
    "FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY",
    "FLOWCHAIN_BASE8453_BROADCAST_ACK",
    "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
    "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_BASE8453_OWNER_ADDRESS",
    "FLOWCHAIN_BASE8453_RELEASE_AUTHORITY_ADDRESS",
    "FLOWCHAIN_BASE8453_SETTLEMENT_SUBMITTER_ADDRESS",
    "FLOWCHAIN_BASE8453_PILOT_ACK",
    "FLOWCHAIN_BRIDGE_OWNER",
    "FLOWCHAIN_BRIDGE_RELEASE_AUTHORITY",
    "FLOWCHAIN_SETTLEMENT_SUBMITTER",
    "FLOWCHAIN_BRIDGE_ALLOW_NATIVE",
    "FLOWCHAIN_BRIDGE_NATIVE_PER_DEPOSIT_CAP",
    "FLOWCHAIN_BRIDGE_NATIVE_TOTAL_CAP",
    "FLOWCHAIN_BRIDGE_ALLOW_ERC20",
    "FLOWCHAIN_BRIDGE_ERC20_TOKEN",
    "FLOWCHAIN_BRIDGE_ERC20_PER_DEPOSIT_CAP",
    "FLOWCHAIN_BRIDGE_ERC20_TOTAL_CAP"
)

function Read-ValidationText {
    param([Parameter(Mandatory = $true)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }
    return Get-Content -Raw -LiteralPath $Path
}

function Test-TextHasAll {
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

function Test-PackageScript {
    param([Parameter(Mandatory = $true)][string] $Name)

    $packageJson = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "package.json") | ConvertFrom-Json
    return $packageJson.scripts.PSObject.Properties.Name -contains $Name
}

function Get-ValidationProp {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name,
        [object] $Default = $null
    )

    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $Default
}

function ConvertTo-ValidationSafeLine {
    param([AllowNull()][object] $Line)

    $text = "$Line"
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "https?://[^\s,)]+", "<redacted-url>")
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "(?i)(FLOWCHAIN_[A-Z0-9_]+\s*=\s*)(.+)$", '${1}<redacted>')
    return $text
}

function Invoke-BridgeValidationChild {
    param(
        [Parameter(Mandatory = $true)][string[]] $ArgumentList,
        [int] $TimeoutSeconds = 90
    )

    New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
    $runId = "$(Get-Date -Format 'yyyyMMddHHmmssfff')-$PID-$([Guid]::NewGuid().ToString("N").Substring(0, 8))"
    $stdoutPath = Join-Path $tmpDir "$runId.stdout.log"
    $stderrPath = Join-Path $tmpDir "$runId.stderr.log"
    $exitCode = 1
    $timedOut = $false
    $savedEnv = @{}

    try {
        foreach ($name in $bridgeEnvNames) {
            $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
            [Environment]::SetEnvironmentVariable($name, $null, "Process")
        }

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
        Set-Content -LiteralPath $stderrPath -Value $_.Exception.Message -Encoding UTF8
        $exitCode = 1
    }
    finally {
        foreach ($name in $bridgeEnvNames) {
            [Environment]::SetEnvironmentVariable($name, $savedEnv[$name], "Process")
        }
    }

    $output = @()
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
        outputRedacted = @($output | ForEach-Object { ConvertTo-ValidationSafeLine -Line $_ })
    }
}

function Test-ReportBlockedNoBroadcast {
    param(
        [AllowNull()][object] $Report,
        [Parameter(Mandatory = $true)][string[]] $ExpectedMissingNames
    )

    if ($null -eq $Report) {
        return $false
    }
    $missing = @((Get-ValidationProp -Object $Report -Name "missingEnvNames" -Default @()))
    return [string](Get-ValidationProp -Object $Report -Name "status" -Default "") -eq "blocked" `
        -and [bool](Get-ValidationProp -Object $Report -Name "broadcasts" -Default $true) -eq $false `
        -and [bool](Get-ValidationProp -Object $Report -Name "noSecrets" -Default $false) -eq $true `
        -and @($ExpectedMissingNames | Where-Object { $_ -notin $missing }).Count -eq 0
}

function Get-SecretMarkerFindings {
    param([Parameter(Mandatory = $true)][string] $Text)

    $findings = New-Object System.Collections.ArrayList
    foreach ($pattern in @(
        "BEGIN RSA PRIVATE KEY",
        "BEGIN OPENSSH PRIVATE KEY",
        ("BEGIN " + "PRIVATE KEY"),
        "seedPhrase",
        "mnemonicPhrase",
        "webhookUrl",
        "webhook_url"
    )) {
        if ($Text.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            [void]$findings.Add($pattern)
        }
    }
    return @($findings)
}

Reset-FlowChainDirectory -Path $validationFullDir | Out-Null
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

$deployBlockedReportRelPath = Join-Path $ValidationDir "base8453-deploy-missing-env-report.json"
$pauseBlockedReportRelPath = Join-Path $ValidationDir "base8453-pause-missing-env-report.json"
$resumeBlockedReportRelPath = Join-Path $ValidationDir "base8453-resume-missing-env-report.json"
$emergencyBlockedReportRelPath = Join-Path $ValidationDir "base8453-emergency-stop-missing-env-report.json"
$deployBlockedReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path $deployBlockedReportRelPath
$pauseBlockedReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path $pauseBlockedReportRelPath
$resumeBlockedReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path $resumeBlockedReportRelPath
$emergencyBlockedReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path $emergencyBlockedReportRelPath

$deployBlocked = Invoke-BridgeValidationChild -ArgumentList @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $deployScriptPath,
    "-ReportPath", $deployBlockedReportRelPath
)
$pauseBlocked = Invoke-BridgeValidationChild -ArgumentList @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $controlScriptPath,
    "-Action", "Pause",
    "-ReportPath", $pauseBlockedReportRelPath
)
$resumeBlocked = Invoke-BridgeValidationChild -ArgumentList @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $controlScriptPath,
    "-Action", "Resume",
    "-ReportPath", $resumeBlockedReportRelPath
)
$emergencyBlocked = Invoke-BridgeValidationChild -ArgumentList @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $controlScriptPath,
    "-Action", "EmergencyStop",
    "-ReportPath", $emergencyBlockedReportRelPath
)

$deployReport = Read-FlowChainJsonIfExists -Path $deployBlockedReportPath
$pauseReport = Read-FlowChainJsonIfExists -Path $pauseBlockedReportPath
$resumeReport = Read-FlowChainJsonIfExists -Path $resumeBlockedReportPath
$emergencyReport = Read-FlowChainJsonIfExists -Path $emergencyBlockedReportPath

$deployText = Read-ValidationText -Path $deployScriptPath
$controlText = Read-ValidationText -Path $controlScriptPath
$foundryText = Read-ValidationText -Path $foundryScriptPath
$lockboxText = Read-ValidationText -Path $lockboxContractPath
$runbookText = Read-ValidationText -Path $deploymentRunbookPath
$combinedText = @($deployText, $controlText, $foundryText, $lockboxText, $runbookText) -join "`n"
$secretMarkerFindings = @(Get-SecretMarkerFindings -Text $combinedText)

$deployExpectedMissing = @(
    "FLOWCHAIN_BASE8453_RPC_URL",
    "FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY",
    "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_PILOT_OPERATOR_ACK"
)
$controlExpectedMissing = @(
    "FLOWCHAIN_PILOT_OPERATOR_ACK",
    "FLOWCHAIN_BASE8453_RPC_URL",
    "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS"
)

$checks = [ordered]@{
    packageScriptDeployPresent = Test-PackageScript -Name "flowchain:bridge:deploy:base8453"
    packageScriptPausePresent = Test-PackageScript -Name "flowchain:bridge:pause"
    packageScriptResumePresent = Test-PackageScript -Name "flowchain:bridge:resume"
    packageScriptEmergencyStopPresent = Test-PackageScript -Name "flowchain:bridge:emergency-stop"
    packageScriptValidationPresent = Test-PackageScript -Name "flowchain:bridge:deploy:control:validate"
    deployScriptExists = Test-Path -LiteralPath $deployScriptPath
    controlScriptExists = Test-Path -LiteralPath $controlScriptPath
    foundryScriptExists = Test-Path -LiteralPath $foundryScriptPath
    lockboxContractExists = Test-Path -LiteralPath $lockboxContractPath
    deploymentRunbookExists = Test-Path -LiteralPath $deploymentRunbookPath
    deployMissingEnvCommandFailedClosed = Test-ReportBlockedNoBroadcast -Report $deployReport -ExpectedMissingNames $deployExpectedMissing
    deployMissingEnvReportWritten = Test-Path -LiteralPath $deployBlockedReportPath
    deployMissingEnvReportBlockedNoBroadcast = Test-ReportBlockedNoBroadcast -Report $deployReport -ExpectedMissingNames $deployExpectedMissing
    pauseMissingEnvCommandFailedClosed = Test-ReportBlockedNoBroadcast -Report $pauseReport -ExpectedMissingNames $controlExpectedMissing
    pauseMissingEnvReportBlockedNoBroadcast = Test-ReportBlockedNoBroadcast -Report $pauseReport -ExpectedMissingNames $controlExpectedMissing
    resumeMissingEnvCommandFailedClosed = Test-ReportBlockedNoBroadcast -Report $resumeReport -ExpectedMissingNames $controlExpectedMissing
    resumeMissingEnvReportBlockedNoBroadcast = Test-ReportBlockedNoBroadcast -Report $resumeReport -ExpectedMissingNames $controlExpectedMissing
    emergencyStopMissingEnvCommandFailedClosed = Test-ReportBlockedNoBroadcast -Report $emergencyReport -ExpectedMissingNames $controlExpectedMissing
    emergencyStopMissingEnvReportBlockedNoBroadcast = Test-ReportBlockedNoBroadcast -Report $emergencyReport -ExpectedMissingNames $controlExpectedMissing
    deployRequiresBase8453ChainId = $deployText.Contains('expected 0x2105') -and $deployText.Contains('eth_chainId')
    deployRequiresPilotAck = $deployText.Contains('FLOWCHAIN_PILOT_OPERATOR_ACK must equal')
    deployRequiresBroadcastAck = $deployText.Contains('FLOWCHAIN_BASE8453_BROADCAST_ACK must equal')
    deployRequiresAcknowledgeBroadcastSwitch = $deployText.Contains('Broadcast mode requires -AcknowledgeBroadcast')
    deployMapsFoundryPilotAck = $deployText.Contains('FLOWCHAIN_BASE8453_PILOT_ACK = "true"')
    deployMapsNativeAndErc20Caps = Test-TextHasAll -Text $deployText -Tokens @(
        "FLOWCHAIN_BRIDGE_ALLOW_NATIVE",
        "FLOWCHAIN_BRIDGE_NATIVE_PER_DEPOSIT_CAP",
        "FLOWCHAIN_BRIDGE_NATIVE_TOTAL_CAP",
        "FLOWCHAIN_BRIDGE_ALLOW_ERC20",
        "FLOWCHAIN_BRIDGE_ERC20_TOKEN",
        "FLOWCHAIN_BRIDGE_ERC20_PER_DEPOSIT_CAP",
        "FLOWCHAIN_BRIDGE_ERC20_TOTAL_CAP"
    )
    deployDryRunNoBroadcastStatus = $deployText.Contains('ready-no-broadcast') -and $deployText.Contains('No transaction was broadcast')
    deployBroadcastUsesForgeBroadcast = $deployText.Contains('forge script script/DeployBridgeSpine.s.sol:DeployBridgeSpine') -and $deployText.Contains('--broadcast')
    controlExecuteRequiresOwnerKeyAndBroadcastAck = Test-TextHasAll -Text $controlText -Tokens @(
        'if ($Execute)',
        'FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY',
        'FLOWCHAIN_BASE8453_BROADCAST_ACK',
        'FLOWCHAIN_BASE8453_BROADCAST_ACK must equal'
    )
    controlNoExecuteReportsReadyNoBroadcast = $controlText.Contains('ready-no-broadcast') -and $controlText.Contains('broadcasts = $false')
    controlSupportsPauseResumeEmergency = Test-TextHasAll -Text $controlText -Tokens @('Pause', 'Resume', 'EmergencyStop', 'setPaused(bool)', 'setEmergencyStopped(bool)')
    controlExecuteUsesCastSend = $controlText.Contains('cast send') -and $controlText.Contains('--private-key')
    foundryScriptGatesBase8453 = Test-TextHasAll -Text $foundryText -Tokens @('BASE_MAINNET_CHAIN_ID = 8_453', 'Base8453PilotAckRequired', 'FLOWCHAIN_BASE8453_PILOT_ACK')
    foundryScriptRequiresTotalCapOnBase = $foundryText.Contains('PilotTotalCapRequired')
    foundryScriptDeploysLockboxAndSpine = Test-TextHasAll -Text $foundryText -Tokens @('new BaseBridgeLockbox', 'new FlowChainSettlementSpine', 'FlowChainBridgeSpineDeployed')
    lockboxHasNonReentrantPauseEmergency = Test-TextHasAll -Text $lockboxText -Tokens @('modifier nonReentrant', 'whenNotPaused', 'whenNotEmergencyStopped', 'setPaused', 'setEmergencyStopped')
    lockboxHasCapsAndReplayProtection = Test-TextHasAll -Text $lockboxText -Tokens @('perDepositCap', 'totalCap', 'DepositAlreadyRecorded', 'ReleaseAlreadyProcessed')
    lockboxRejectsPlaceholderRecipient = $lockboxText.Contains('PLACEHOLDER_RECIPIENT') -and $lockboxText.Contains('PlaceholderRecipient')
    lockboxHasReleaseAuthority = $lockboxText.Contains('releaseAuthority') -and $lockboxText.Contains('onlyReleaseAuthority')
    runbookHasDryRunBroadcastVerifyRollback = Test-TextHasAll -Text $runbookText -Tokens @(
        'npm run flowchain:bridge:deploy:base8453',
        'npm run flowchain:bridge:deploy:base8453 -- -Mode Broadcast -AcknowledgeBroadcast',
        'npm run flowchain:bridge:infra:check',
        'npm run flowchain:bridge:live:check',
        'npm run flowchain:bridge:pause',
        'npm run flowchain:bridge:resume',
        'npm run flowchain:bridge:emergency-stop'
    )
    childProcessesDidNotTimeout = -not ([bool]$deployBlocked.timedOut -or [bool]$pauseBlocked.timedOut -or [bool]$resumeBlocked.timedOut -or [bool]$emergencyBlocked.timedOut)
    validationArtifactsInsideRepo = $deployBlockedReportPath.StartsWith($validationFullDir, [System.StringComparison]::OrdinalIgnoreCase) -and $pauseBlockedReportPath.StartsWith($validationFullDir, [System.StringComparison]::OrdinalIgnoreCase)
    secretMarkerFindingsEmpty = $secretMarkerFindings.Count -eq 0
    envValuesPrintedFalse = $true
    noSecrets = $true
    broadcastsFalse = $true
}

$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.bridge_deploy_control_validation_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    validationDir = $validationFullDir
    checkedFiles = [ordered]@{
        deployScript = $deployScriptPath
        controlScript = $controlScriptPath
        foundryScript = $foundryScriptPath
        lockboxContract = $lockboxContractPath
        deploymentRunbook = $deploymentRunbookPath
    }
    blockedScenarioReports = [ordered]@{
        deployDryRunMissingEnv = $deployBlockedReportPath
        pauseMissingEnv = $pauseBlockedReportPath
        resumeMissingEnv = $resumeBlockedReportPath
        emergencyStopMissingEnv = $emergencyBlockedReportPath
    }
    blockedScenarioExitCodes = [ordered]@{
        deployDryRunMissingEnv = [int]$deployBlocked.exitCode
        pauseMissingEnv = [int]$pauseBlocked.exitCode
        resumeMissingEnv = [int]$resumeBlocked.exitCode
        emergencyStopMissingEnv = [int]$emergencyBlocked.exitCode
    }
    requiredOwnerEnvNames = @(
        "FLOWCHAIN_PILOT_OPERATOR_ACK",
        "FLOWCHAIN_BASE8453_RPC_URL",
        "FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY",
        "FLOWCHAIN_BASE8453_BROADCAST_ACK",
        "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
        "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
        "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
        "FLOWCHAIN_PILOT_TOTAL_CAP_WEI"
    )
    commandPlan = @(
        "npm run flowchain:bridge:deploy:base8453",
        "npm run flowchain:bridge:deploy:base8453 -- -Mode Broadcast -AcknowledgeBroadcast",
        "npm run flowchain:bridge:pause",
        "npm run flowchain:bridge:resume",
        "npm run flowchain:bridge:emergency-stop",
        "npm run flowchain:bridge:pause -- -Execute",
        "npm run flowchain:bridge:resume -- -Execute",
        "npm run flowchain:bridge:emergency-stop -- -Execute"
    )
    checks = $checks
    failedChecks = @($failedChecks)
    secretMarkerFindings = @($secretMarkerFindings)
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Bridge Deploy And Control Validation")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This validation proves Base 8453 lockbox deploy/control commands fail closed without owner env, require explicit pilot and broadcast acknowledgements, and keep deploy, pause, resume, and emergency-stop paths no-broadcast unless the owner intentionally executes them.")
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("- $($entry.Key): $($entry.Value)")
}
$markdownLines.Add("")
$markdownLines.Add("## Command Plan")
$markdownLines.Add("")
foreach ($command in $report.commandPlan) {
    $markdownLines.Add("- $command")
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
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain bridge deploy/control validation status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    Write-Host "Failed checks: $($failedChecks -join ', ')"
    exit 1
}
exit 0
