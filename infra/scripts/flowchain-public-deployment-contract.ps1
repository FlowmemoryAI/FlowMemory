param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/PUBLIC_DEPLOYMENT_CONTRACT.md",
    [int] $ChildTimeoutSeconds = 1800,
    [switch] $AllowBlocked,
    [switch] $NoRefresh
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)

if ($ChildTimeoutSeconds -lt 1) {
    throw "ChildTimeoutSeconds must be at least 1."
}

$knownOwnerInputs = @(
    "FLOWCHAIN_RPC_PUBLIC_URL",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
    "FLOWCHAIN_RPC_TLS_TERMINATED",
    "FLOWCHAIN_RPC_STATE_BACKUP_PATH",
    "FLOWCHAIN_TESTER_WRITE_ENABLED",
    "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256",
    "FLOWCHAIN_TESTER_MAX_SEND_UNITS",
    "FLOWCHAIN_PILOT_OPERATOR_ACK",
    "FLOWCHAIN_BASE8453_RPC_URL",
    "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
    "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
    "FLOWCHAIN_BASE8453_ASSET_DECIMALS",
    "FLOWCHAIN_BASE8453_FROM_BLOCK",
    "FLOWCHAIN_BASE8453_CURSOR_STATE",
    "FLOWCHAIN_BASE8453_TO_BLOCK",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_PILOT_CONFIRMATIONS"
)

$paths = [ordered]@{
    serviceStatus = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-status-report.json"
    serviceMonitor = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-monitor-report.json"
    serviceSupervisorValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-report.json"
    serviceInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-install-validation-report.json"
    systemdServiceInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/systemd-service-install-validation-report.json"
    opsSnapshot = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-snapshot-report.json"
    opsAlertRules = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-alert-rules-report.json"
    opsMetricsExport = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-metrics-export-report.json"
    alertInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/alert-install-validation-report.json"
    metricsInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/metrics-install-validation-report.json"
    opsEscalationDryRun = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-escalation-dry-run-report.json"
    ownerOnboarding = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-onboarding-report.json"
    ownerSignupChecklist = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-signup-checklist-report.json"
    ownerEnvTemplate = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-env-template-report.json"
    ownerInputs = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json"
    publicRpcEdgeTemplate = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-edge-template-report.json"
    publicRpcDeploymentBundle = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json"
    publicRpcDeploymentAutomation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json"
    publicRpc = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json"
    publicRpcSyntheticCanary = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-synthetic-canary-report.json"
    publicRpcCanaryScheduleValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-canary-schedule-validation-report.json"
    publicRpcValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json"
    publicRpcAbuseTest = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-abuse-test-report.json"
    testerWriteTokenSetup = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/tester-write-token-setup-report.json"
    publicTesterGateway = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json"
    backup = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json"
    backupRestoreValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-report.json"
    backupOwnerPathDryRun = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-owner-path-dry-run-report.json"
    backupInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-install-validation-report.json"
    bridgeLive = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
    bridgeInfra = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
    bridgeRelayerOnce = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-once-report.json"
    bridgeRelayerGuardrailValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-guardrail-validation-report.json"
    bridgeRelayerLoopValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-loop-validation-report.json"
    bridgeRuntimeCreditValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-runtime-credit-validation-report.json"
    bridgeReleaseEvidenceValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-release-evidence-validation-report.json"
    bridgeReconciliationScheduleValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-reconciliation-schedule-validation-report.json"
    externalTester = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
    externalTesterPacket = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json"
    architectureAudit = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-architecture-audit-report.json"
    noSecret = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json"
}

function Get-DeploymentJson {
    param([Parameter(Mandatory = $true)][string] $Path)
    return Read-FlowChainJsonIfExists -Path $Path
}

function Get-DeploymentProp {
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

function Get-DeploymentStatus {
    param([AllowNull()][object] $Report)
    return [string](Get-DeploymentProp -Object $Report -Name "status" -Default "missing")
}

function Test-DeploymentPackageScript {
    param(
        [Parameter(Mandatory = $true)][object] $PackageJson,
        [Parameter(Mandatory = $true)][string] $Name
    )

    return $PackageJson.PSObject.Properties.Name -contains "scripts" -and $PackageJson.scripts.PSObject.Properties.Name -contains $Name
}

function Add-UniqueDeploymentName {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [object] $Value
    )
    $name = "$Value"
    if (-not [string]::IsNullOrWhiteSpace($name) -and -not $Target.Contains($name)) {
        [void] $Target.Add($name)
    }
}

function Test-DeploymentRoutePresent {
    param(
        [AllowNull()][object] $Routes,
        [Parameter(Mandatory = $true)][string] $Route
    )

    foreach ($candidate in @($Routes)) {
        if ("$candidate" -eq $Route) {
            return $true
        }
    }
    return $false
}

function Add-DeploymentItem {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Items,
        [Parameter(Mandatory = $true)][string] $Id,
        [Parameter(Mandatory = $true)][string] $Requirement,
        [Parameter(Mandatory = $true)][string] $Status,
        [Parameter(Mandatory = $true)][string] $Evidence,
        [string[]] $Commands = @(),
        [string[]] $Blockers = @()
    )

    [void] $Items.Add([ordered]@{
        id = $Id
        requirement = $Requirement
        status = $Status
        evidence = $Evidence
        commands = $Commands
        blockers = $Blockers
    })
}

function ConvertTo-DeploymentSafeOutputLine {
    param([AllowNull()][object] $Line)

    $text = "$Line"
    foreach ($name in $knownOwnerInputs) {
        $escapedName = [System.Text.RegularExpressions.Regex]::Escape($name)
        $text = [System.Text.RegularExpressions.Regex]::Replace(
            $text,
            "(?i)($escapedName\s*[:=]\s*)([^\s,;]+)",
            {
                param([System.Text.RegularExpressions.Match] $Match)
                return "$($Match.Groups[1].Value)<redacted>"
            }
        )
    }
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "https?://[^\s,)]+", "<redacted-url>")
    return $text
}

function Stop-DeploymentProcessTree {
    param([Parameter(Mandatory = $true)][int] $ProcessId)

    $children = @()
    try {
        $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$ProcessId" -ErrorAction SilentlyContinue)
    }
    catch {
        $children = @()
    }

    foreach ($child in $children) {
        Stop-DeploymentProcessTree -ProcessId ([int] $child.ProcessId)
    }

    try {
        Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
    }
    catch {
    }
}

function Read-DeploymentOutputFile {
    param([Parameter(Mandatory = $true)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }
    return @(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue | ForEach-Object { "$_" })
}

function Invoke-DeploymentChildProcess {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string[]] $ArgumentList
    )

    $startedAt = (Get-Date).ToUniversalTime()
    $stamp = $startedAt.ToString("yyyyMMddTHHmmssfffZ")
    $tempBase = Join-Path ([System.IO.Path]::GetTempPath()) "flowchain-public-deployment-$PID-$stamp-$([Guid]::NewGuid().ToString("N"))"
    $stdoutPath = "$tempBase.out.log"
    $stderrPath = "$tempBase.err.log"
    $timedOut = $false
    $exitCode = 1
    $processId = $null
    $output = @()

    try {
        $process = Start-Process -FilePath "powershell" `
            -ArgumentList (Join-FlowChainProcessArguments -ArgumentList $ArgumentList) `
            -WorkingDirectory $repoRoot `
            -PassThru `
            -WindowStyle Hidden `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath
        $processId = $process.Id
        if (-not $process.WaitForExit($ChildTimeoutSeconds * 1000)) {
            $timedOut = $true
            Stop-DeploymentProcessTree -ProcessId $process.Id
            $exitCode = 124
        }
        else {
            $process.Refresh()
            $exitCode = [int] $process.ExitCode
        }
    }
    catch {
        $output = @($_.Exception.Message)
        $exitCode = 1
    }

    $stdout = Read-DeploymentOutputFile -Path $stdoutPath
    $stderr = Read-DeploymentOutputFile -Path $stderrPath
    $output = @($output + $stdout + $stderr) | ForEach-Object { ConvertTo-DeploymentSafeOutputLine -Line $_ }
    if ($timedOut) {
        $output = @("Timed out after $ChildTimeoutSeconds seconds; child process tree was stopped.") + $output
    }
    $finishedAt = (Get-Date).ToUniversalTime()

    Remove-Item -LiteralPath $stdoutPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue

    return [ordered]@{
        name = $Name
        startedAt = $startedAt.ToString("o")
        finishedAt = $finishedAt.ToString("o")
        durationSeconds = [int][Math]::Max(0, [Math]::Floor(($finishedAt - $startedAt).TotalSeconds))
        timedOut = $timedOut
        timeoutSeconds = $ChildTimeoutSeconds
        processId = $processId
        exitCode = [int] $exitCode
        outputRedacted = @($output)
    }
}

$script:DeploymentRefreshAborted = $false
$script:DeploymentRefreshAbortReason = ""
$script:DeploymentRefreshAbortStep = ""

function Add-DeploymentRefreshStep {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Steps,
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string[]] $ArgumentList
    )

    if ($script:DeploymentRefreshAborted) {
        $now = (Get-Date).ToUniversalTime().ToString("o")
        [void] $Steps.Add([ordered]@{
            name = $Name
            startedAt = $now
            finishedAt = $now
            durationSeconds = 0
            timedOut = $false
            timeoutSeconds = $ChildTimeoutSeconds
            processId = $null
            exitCode = 125
            skipped = $true
            skipReason = $script:DeploymentRefreshAbortReason
            skippedAfterStep = $script:DeploymentRefreshAbortStep
            outputRedacted = @("Skipped because dependency refresh already failed at $($script:DeploymentRefreshAbortStep): $($script:DeploymentRefreshAbortReason)")
        })
        return
    }

    Write-Host "Refreshing deployment dependency: $Name"
    $result = Invoke-DeploymentChildProcess -Name $Name -ArgumentList $ArgumentList
    $result["skipped"] = $false
    [void] $Steps.Add($result)
    Write-Host "Deployment dependency result: $Name exit=$($result.exitCode) timedOut=$($result.timedOut) durationSeconds=$($result.durationSeconds)"

    if ($result.timedOut -eq $true -or [int] $result.exitCode -ne 0) {
        $script:DeploymentRefreshAborted = $true
        $script:DeploymentRefreshAbortStep = $Name
        $script:DeploymentRefreshAbortReason = if ($result.timedOut -eq $true) {
            "timed out after $ChildTimeoutSeconds seconds"
        }
        else {
            "exited with code $($result.exitCode)"
        }
        Write-Host "Deployment dependency refresh aborted after ${Name}: $script:DeploymentRefreshAbortReason"
    }
}

$dependencyRefreshSteps = New-Object System.Collections.ArrayList
$dependencyRefreshCommands = @(
    "npm run flowchain:service:status -- -AllowBlocked",
    "npm run flowchain:service:monitor -- -DurationSeconds 20 -PollSeconds 5 -MaxStateAgeSeconds 90",
    "npm run flowchain:service:supervisor:validate",
    "npm run flowchain:service:install:validate",
    "npm run flowchain:service:install:systemd:validate",
    "npm run flowchain:ops:snapshot -- -AllowBlocked",
    "npm run flowchain:ops:alerts -- -AllowBlocked",
    "npm run flowchain:ops:metrics:export -- -AllowBlocked",
    "npm run flowchain:ops:alerts:install:validate",
    "npm run flowchain:ops:metrics:install:validate",
    "npm run flowchain:ops:escalation:dry-run -- -AllowBlocked",
    "npm run flowchain:owner:onboarding",
    "npm run flowchain:owner:signup-checklist",
    "npm run flowchain:owner-env:template",
    "npm run flowchain:owner-inputs -- -AllowBlocked",
    "npm run flowchain:public-rpc:edge-template",
    "npm run flowchain:public-rpc:deployment-bundle",
    "npm run flowchain:public-rpc:deployment:automation",
    "npm run flowchain:public-rpc:validate",
    "npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked",
    "npm run flowchain:public-rpc:canary:schedule:validate",
    "npm run flowchain:public-rpc:abuse-test",
    "npm run flowchain:tester:token:setup",
    "npm run flowchain:tester:gateway:e2e",
    "npm run flowchain:public-rpc:check -- -AllowBlocked",
    "npm run flowchain:backup:restore:validate",
    "npm run flowchain:backup:owner-path:dry-run",
    "npm run flowchain:backup:install:validate",
    "npm run flowchain:backup:check -- -AllowBlocked",
    "npm run flowchain:bridge:live:check -- -AllowBlocked",
    "npm run flowchain:bridge:infra:check -- -AllowBlocked",
    "npm run flowchain:bridge:relayer:once -- -AllowBlocked",
    "npm run flowchain:bridge:relayer:loop:validate",
    "npm run flowchain:bridge:release:evidence:validate",
    "npm run flowchain:external-tester:packet -- -AllowBlocked",
    "npm run flowchain:no-secret:scan"
)

if (-not $NoRefresh.IsPresent) {
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "service-status" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-status.ps1"), "-AllowBlocked", "-ReportPath", $paths.serviceStatus)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "service-monitor" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-monitor.ps1"), "-DurationSeconds", "20", "-PollSeconds", "5", "-MaxStateAgeSeconds", "90", "-ReportPath", $paths.serviceMonitor)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "service-supervisor-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-supervisor-validation.ps1"), "-ReportPath", $paths.serviceSupervisorValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "service-install-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-install-validation.ps1"), "-ReportPath", $paths.serviceInstallValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "systemd-service-install-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-install-systemd-validation.ps1"), "-ReportPath", $paths.systemdServiceInstallValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "ops-snapshot" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-ops-snapshot.ps1"), "-AllowBlocked", "-NoRefresh", "-ReportPath", $paths.opsSnapshot)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "ops-alert-rules" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-ops-alerts.ps1"), "-AllowBlocked", "-NoRefresh", "-ReportPath", $paths.opsAlertRules)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "ops-metrics-export" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-ops-metrics-export.ps1"), "-AllowBlocked", "-NoRefresh", "-ReportPath", $paths.opsMetricsExport)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "alert-install-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-alert-install-validation.ps1"), "-ReportPath", $paths.alertInstallValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "metrics-install-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-metrics-install-validation.ps1"), "-ReportPath", $paths.metricsInstallValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "ops-escalation-dry-run" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-ops-escalation-dry-run.ps1"), "-AllowBlocked", "-NoRefresh", "-ReportPath", $paths.opsEscalationDryRun, "-OpsSnapshotPath", $paths.opsSnapshot, "-OpsAlertRulesPath", $paths.opsAlertRules)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "owner-onboarding" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-onboarding.ps1"), "-ReportPath", $paths.ownerOnboarding)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "owner-signup-checklist" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-signup-checklist.ps1"), "-ReportPath", $paths.ownerSignupChecklist)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "owner-env-template" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-env-template.ps1"), "-ReportPath", $paths.ownerEnvTemplate)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "owner-inputs" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-inputs.ps1"), "-AllowBlocked", "-ReportPath", $paths.ownerInputs)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-rpc-edge-template" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-edge-template.ps1"), "-ReportPath", $paths.publicRpcEdgeTemplate)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-rpc-deployment-bundle" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-deployment-bundle.ps1"), "-ReportPath", $paths.publicRpcDeploymentBundle)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-rpc-deployment-automation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-deployment-automation.ps1"), "-ReportPath", $paths.publicRpcDeploymentAutomation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-rpc-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-validation.ps1"), "-ReportPath", $paths.publicRpcValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-rpc-abuse-test" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-abuse-test.ps1"), "-ReportPath", $paths.publicRpcAbuseTest)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "tester-write-token-setup" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-tester-write-token-setup.ps1"), "-ReportPath", $paths.testerWriteTokenSetup)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-tester-gateway-e2e" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-tester-gateway-e2e.ps1"), "-ReportPath", $paths.publicTesterGateway)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-rpc-readiness" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-readiness.ps1"), "-AllowBlocked", "-ReportPath", $paths.publicRpc)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-rpc-synthetic-canary" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-synthetic-canary.ps1"), "-AllowBlocked", "-ReportPath", $paths.publicRpcSyntheticCanary)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-rpc-canary-schedule-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-canary-schedule-validation.ps1"), "-ReportPath", $paths.publicRpcCanaryScheduleValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "backup-restore-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-backup-restore-validation.ps1"), "-ReportPath", $paths.backupRestoreValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "backup-owner-path-dry-run" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-backup-owner-path-dry-run.ps1"), "-ReportPath", $paths.backupOwnerPathDryRun)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "backup-install-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-backup-install-validation.ps1"), "-ReportPath", $paths.backupInstallValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-rpc-backup" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-backup-readiness.ps1"), "-AllowBlocked", "-ReportPath", $paths.backup)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "bridge-live" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-live-check.ps1"), "-AllowBlocked", "-ReportPath", $paths.bridgeLive)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "bridge-infra" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-live-env-bridge-readiness.ps1"), "-AllowBlocked", "-ReportPath", $paths.bridgeInfra)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "bridge-relayer-once" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-relayer-once.ps1"), "-AllowBlocked", "-ReportPath", $paths.bridgeRelayerOnce)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "bridge-relayer-guardrail-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-relayer-guardrail-validation.ps1"), "-ReportPath", $paths.bridgeRelayerGuardrailValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "bridge-relayer-loop-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-relayer-loop-validation.ps1"), "-ReportPath", $paths.bridgeRelayerLoopValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "bridge-runtime-credit-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-runtime-credit-validation.ps1"), "-ReportPath", $paths.bridgeRuntimeCreditValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "bridge-release-evidence-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-release-evidence-validation.ps1"), "-ReportPath", $paths.bridgeReleaseEvidenceValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "bridge-reconciliation-schedule-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-reconciliation-schedule-validation.ps1"), "-ReportPath", $paths.bridgeReconciliationScheduleValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "external-tester-packet" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-external-tester-packet.ps1"), "-AllowBlocked", "-ReportPath", $paths.externalTesterPacket)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "no-secret-scan" -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Join-Path $PSScriptRoot "flowchain-no-secret-scan.ps1"),
        "-ReportPath",
        $paths.noSecret
    )
}

$dependencyRefreshFailedSteps = @($dependencyRefreshSteps | Where-Object { $_.skipped -ne $true -and [int] $_.exitCode -ne 0 })
$dependencyRefreshTimedOutSteps = @($dependencyRefreshSteps | Where-Object { $_.skipped -ne $true -and $_.timedOut -eq $true })
$dependencyRefreshSkippedSteps = @($dependencyRefreshSteps | Where-Object { $_.skipped -eq $true })
$dependencyRefreshCompletedSteps = @($dependencyRefreshSteps | Where-Object { $_.skipped -ne $true })
$dependencyRefreshTotalDurationSeconds = 0
foreach ($step in @($dependencyRefreshCompletedSteps)) {
    $dependencyRefreshTotalDurationSeconds += [int] $step.durationSeconds
}
$dependencyRefresh = [ordered]@{
    performed = -not $NoRefresh.IsPresent
    delegatedToCaller = $NoRefresh.IsPresent
    childTimeoutSeconds = $ChildTimeoutSeconds
    failurePolicy = "stop-after-first-refresh-failure-or-timeout"
    aborted = $script:DeploymentRefreshAborted
    abortStepName = $script:DeploymentRefreshAbortStep
    abortReason = $script:DeploymentRefreshAbortReason
    stepCount = $dependencyRefreshSteps.Count
    completedStepCount = $dependencyRefreshCompletedSteps.Count
    skippedStepCount = $dependencyRefreshSkippedSteps.Count
    totalDurationSeconds = $dependencyRefreshTotalDurationSeconds
    failedStepNames = @($dependencyRefreshFailedSteps | ForEach-Object { $_.name })
    timedOutStepNames = @($dependencyRefreshTimedOutSteps | ForEach-Object { $_.name })
    skippedStepNames = @($dependencyRefreshSkippedSteps | ForEach-Object { $_.name })
    steps = @($dependencyRefreshSteps)
}

$packageJson = Get-Content -Raw -LiteralPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "package.json") | ConvertFrom-Json
$reports = [ordered]@{}
foreach ($entry in $paths.GetEnumerator()) {
    $reports[$entry.Key] = Get-DeploymentJson -Path $entry.Value
}

$optionalOwnerInputs = @("FLOWCHAIN_BASE8453_CURSOR_STATE", "FLOWCHAIN_BASE8453_TO_BLOCK")
$missingEnvNames = New-Object System.Collections.ArrayList
foreach ($report in $reports.Values) {
    foreach ($name in @((Get-DeploymentProp -Object $report -Name "missingEnvNames" -Default @()))) {
        if ($name -in $knownOwnerInputs -and $name -notin $optionalOwnerInputs) {
            Add-UniqueDeploymentName -Target $missingEnvNames -Value $name
        }
    }
}
foreach ($name in @((Get-DeploymentProp -Object $reports.ownerInputs -Name "invalidEnvNames" -Default @()))) {
    Add-UniqueDeploymentName -Target $missingEnvNames -Value $name
}
$ownerInputValidNames = @((Get-DeploymentProp -Object $reports.ownerInputs -Name "inputs" -Default @()) | Where-Object {
        (Get-DeploymentProp -Object $_ -Name "present" -Default $false) -eq $true `
            -and (Get-DeploymentProp -Object $_ -Name "valid" -Default $false) -eq $true
    } | ForEach-Object {
        [string](Get-DeploymentProp -Object $_ -Name "name" -Default "")
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$filteredMissingEnvNames = New-Object System.Collections.ArrayList
foreach ($name in @($missingEnvNames)) {
    if ($name -notin $ownerInputValidNames) {
        Add-UniqueDeploymentName -Target $filteredMissingEnvNames -Value $name
    }
}
$missingEnvNames = $filteredMissingEnvNames
$unknownMissingEnvNames = @($missingEnvNames | Where-Object { $_ -notin $knownOwnerInputs })

$items = New-Object System.Collections.ArrayList
Add-DeploymentItem -Items $items -Id "dependency-report-refresh" `
    -Requirement "The deployment contract evaluates reports freshly generated by this command or an explicit caller such as the completion audit." `
    -Status $(if ($dependencyRefreshFailedSteps.Count -eq 0 -and $dependencyRefreshSkippedSteps.Count -eq 0) { "passed" } else { "failed" }) `
    -Evidence "refreshPerformed=$($dependencyRefresh.performed), delegatedToCaller=$($dependencyRefresh.delegatedToCaller), aborted=$($dependencyRefresh.aborted), failedSteps=$($dependencyRefreshFailedSteps.Count), timedOutSteps=$($dependencyRefreshTimedOutSteps.Count), skippedSteps=$($dependencyRefreshSkippedSteps.Count), childTimeoutSeconds=$ChildTimeoutSeconds" `
    -Commands $dependencyRefreshCommands

$ownerOnboarding = $reports.ownerOnboarding
$ownerOnboardingStatus = Get-DeploymentStatus -Report $ownerOnboarding
$flowChainRpcIsOurs = Get-DeploymentProp -Object $ownerOnboarding -Name "flowChainRpcIsOurs" -Default $false
$thirdPartyFlowChainRpcProviderNeeded = Get-DeploymentProp -Object $ownerOnboarding -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$publicRpcRequiresOwnerPublicEdge = Get-DeploymentProp -Object $ownerOnboarding -Name "publicRpcRequiresOwnerPublicEdge" -Default $false
$base8453RpcIsExternalChainDependency = Get-DeploymentProp -Object $ownerOnboarding -Name "base8453RpcIsExternalChainDependency" -Default $false
$ownerOnboardingLocalEnvFileSupported = Get-DeploymentProp -Object $ownerOnboarding -Name "localEnvFileSupported" -Default $false
$ownerOnboardingReady = ($ownerOnboardingStatus -eq "passed") `
    -and ($flowChainRpcIsOurs -eq $true) `
    -and ($thirdPartyFlowChainRpcProviderNeeded -eq $false) `
    -and ($publicRpcRequiresOwnerPublicEdge -eq $true) `
    -and ($base8453RpcIsExternalChainDependency -eq $true) `
    -and ($ownerOnboardingLocalEnvFileSupported -eq $true) `
    -and ((Get-DeploymentProp -Object $ownerOnboarding -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $ownerOnboarding -Name "noSecrets" -Default $false) -eq $true)
Add-DeploymentItem -Items $items -Id "owner-onboarding-packet" `
    -Requirement "Owner onboarding clearly distinguishes repo-owned FlowChain RPC from the external Base 8453 RPC dependency without values and documents local owner env-file loading." `
    -Status $(if ($ownerOnboardingReady) { "passed" } else { "failed" }) `
    -Evidence "onboardingStatus=$ownerOnboardingStatus, flowChainRpcIsOurs=$flowChainRpcIsOurs, publicRpcRequiresOwnerPublicEdge=$publicRpcRequiresOwnerPublicEdge, base8453RpcIsExternalChainDependency=$base8453RpcIsExternalChainDependency, localEnvFileSupported=$ownerOnboardingLocalEnvFileSupported" `
    -Commands @("npm run flowchain:owner:onboarding")

$ownerSignupChecklist = $reports.ownerSignupChecklist
$ownerSignupChecklistStatus = Get-DeploymentStatus -Report $ownerSignupChecklist
$ownerSignupExternalCount = [int](Get-DeploymentProp -Object $ownerSignupChecklist -Name "externalSignupCount" -Default 0)
$ownerSignupItemCount = [int](Get-DeploymentProp -Object $ownerSignupChecklist -Name "itemCount" -Default 0)
$ownerSignupMissingCoverageCount = @((Get-DeploymentProp -Object $ownerSignupChecklist -Name "missingChecklistCoverage" -Default @())).Count
$ownerSignupRepoOwned = Get-DeploymentProp -Object $ownerSignupChecklist -Name "flowChainRpcIsRepoOwned" -Default $false
$ownerSignupThirdPartyFlowChainRpcNeeded = Get-DeploymentProp -Object $ownerSignupChecklist -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$ownerSignupLocalEnvFileSupported = Get-DeploymentProp -Object $ownerSignupChecklist -Name "localEnvFileSupported" -Default $false
$ownerSignupChecklistReady = ($ownerSignupChecklistStatus -eq "passed") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:owner:signup-checklist") `
    -and ($ownerSignupItemCount -ge 8) `
    -and ($ownerSignupExternalCount -ge 3) `
    -and ($ownerSignupMissingCoverageCount -eq 0) `
    -and ($ownerSignupRepoOwned -eq $true) `
    -and ($ownerSignupThirdPartyFlowChainRpcNeeded -eq $false) `
    -and ($ownerSignupLocalEnvFileSupported -eq $true) `
    -and ((Get-DeploymentProp -Object $ownerSignupChecklist -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $ownerSignupChecklist -Name "noSecrets" -Default $false) -eq $true)
Add-DeploymentItem -Items $items -Id "owner-signup-checklist" `
    -Requirement "Owner signup checklist maps every public RPC, tester write gateway, backup, and Base 8453 bridge value to the exact thing the owner must get without requesting secrets in chat." `
    -Status $(if ($ownerSignupChecklistReady) { "passed" } else { "failed" }) `
    -Evidence "signupStatus=$ownerSignupChecklistStatus, itemCount=$ownerSignupItemCount, externalSignupCount=$ownerSignupExternalCount, missingCoverage=$ownerSignupMissingCoverageCount, repoOwned=$ownerSignupRepoOwned, localEnvFileSupported=$ownerSignupLocalEnvFileSupported" `
    -Commands @("npm run flowchain:owner:signup-checklist")

$ownerEnvTemplate = $reports.ownerEnvTemplate
$ownerEnvTemplateStatus = Get-DeploymentStatus -Report $ownerEnvTemplate
$ownerEnvTemplateGitIgnored = Get-DeploymentProp -Object $ownerEnvTemplate -Name "pathIsGitIgnored" -Default $false
$ownerEnvTemplateIncludesRequired = Get-DeploymentProp -Object $ownerEnvTemplate -Name "templateIncludesAllRequiredEnvNames" -Default $false
$ownerEnvTemplateRequiredCount = [int](Get-DeploymentProp -Object $ownerEnvTemplate -Name "requiredEnvNameCount" -Default 0)
$ownerEnvTemplateOptionalCount = @((Get-DeploymentProp -Object $ownerEnvTemplate -Name "optionalEnvNames" -Default @())).Count
$ownerEnvTemplateFieldGuideCount = [int](Get-DeploymentProp -Object $ownerEnvTemplate -Name "fieldGuideCount" -Default 0)
$ownerEnvTemplateChecks = Get-DeploymentProp -Object $ownerEnvTemplate -Name "checks"
$ownerEnvTemplateReady = ($ownerEnvTemplateStatus -eq "passed") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:owner-env:template") `
    -and ($ownerEnvTemplateGitIgnored -eq $true) `
    -and ($ownerEnvTemplateIncludesRequired -eq $true) `
    -and (($ownerEnvTemplateRequiredCount + $ownerEnvTemplateOptionalCount) -eq $knownOwnerInputs.Count) `
    -and ($ownerEnvTemplateFieldGuideCount -eq $knownOwnerInputs.Count) `
    -and ((Get-DeploymentProp -Object $ownerEnvTemplateChecks -Name "fieldGuideCoversAllRequiredEnvNames" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $ownerEnvTemplateChecks -Name "fieldGuideCoversAllOptionalEnvNames" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $ownerEnvTemplateChecks -Name "fieldGuideHasValidationForEveryName" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $ownerEnvTemplateChecks -Name "fieldGuideHasDoNotSendForEveryName" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $ownerEnvTemplate -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $ownerEnvTemplate -Name "noSecrets" -Default $false) -eq $true)
Add-DeploymentItem -Items $items -Id "owner-env-template" `
    -Requirement "Owner env-file setup has a command-generated local scaffold and no-secret field guide whose target path is git-ignored before owner values are added." `
    -Status $(if ($ownerEnvTemplateReady) { "passed" } else { "failed" }) `
    -Evidence "templateStatus=$ownerEnvTemplateStatus, pathIsGitIgnored=$ownerEnvTemplateGitIgnored, requiredEnvNameCount=$ownerEnvTemplateRequiredCount, optionalEnvNameCount=$ownerEnvTemplateOptionalCount, fieldGuideCount=$ownerEnvTemplateFieldGuideCount, includesAllRequired=$ownerEnvTemplateIncludesRequired" `
    -Commands @("npm run flowchain:owner-env:template")

$publicRpcEdgeTemplate = $reports.publicRpcEdgeTemplate
$publicRpcEdgeTemplateStatus = Get-DeploymentStatus -Report $publicRpcEdgeTemplate
$edgeTemplateReady = Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "edgeTemplateReady" -Default $false
$edgeTemplateRepoOwned = Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "flowChainRpcIsRepoOwned" -Default $false
$edgeTemplateThirdPartyNeeded = Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$edgeTemplateRequiresTls = Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "requiresTlsTermination" -Default $false
$edgeTemplateRequiresRateLimit = Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "requiresRateLimit" -Default $false
$edgeTemplateForwardsOrigin = Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "forwardsOriginForCors" -Default $false
$edgeTemplateStateExcluded = Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "publicStateMirrorExcluded" -Default $false
$edgeTemplateDevnetStateExcluded = Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "devnetStatePublicRpcExcluded" -Default $false
$publicRpcDeploymentBundle = $reports.publicRpcDeploymentBundle
$publicRpcDeploymentBundleStatus = Get-DeploymentStatus -Report $publicRpcDeploymentBundle
$deploymentBundleChecks = Get-DeploymentProp -Object $publicRpcDeploymentBundle -Name "checks"
$deploymentBundleRequiredCommands = @((Get-DeploymentProp -Object $publicRpcDeploymentBundle -Name "requiredCommands" -Default @()) | ForEach-Object { "$_" })
$deploymentBundleCoversWalletCutover = @(
    "npm run flowchain:tester:gateway:e2e",
    "npm run flowchain:wallet:live-tester:e2e",
    "npm run flowchain:live:cutover:rehearsal -- -AllowBlocked",
    "npm run flowchain:truth-table -- -AllowBlocked",
    "npm run flowchain:no-secret:scan"
) | Where-Object { $_ -notin $deploymentBundleRequiredCommands } | Measure-Object | ForEach-Object { $_.Count -eq 0 }
$deploymentBundleReady = $publicRpcDeploymentBundleStatus -eq "passed" `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "nginxTemplateWritten" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "nginxPreflightScriptWritten" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "windowsNginxPreflightScriptWritten" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "windowsNginxPreflightTokensPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "includesWindowsNginxConfigTest" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "includesTesterWritePreflight" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "includesMethodRejectionPreflight" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "includesDisallowedOriginPreflight" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "includesTimeoutGuardrails" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "preflightsCheckTimeoutGuardrails" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "includesBroadStateBlockedPreflight" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "includesPrivateWalletCreateBlockedPreflight" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "authorizationForwardingScopedToTesterWrite" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "publicStateMirrorExcluded" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "devnetStatePublicRpcExcluded" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "ownerRenderValidationPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "ownerRenderFilesHaveNoPlaceholders" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "ownerRenderDoesNotPrintTokenHash" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "ownerRenderPreflightsRejectWrongMethods" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "ownerEnvExampleWritten" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "verifyRunbookWritten" -Default $false) -eq $true) `
    -and ($deploymentBundleCoversWalletCutover -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "rollbackRunbookWritten" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcDeploymentBundle -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $publicRpcDeploymentBundle -Name "noSecrets" -Default $false) -eq $true)
$publicRpcDeploymentAutomation = $reports.publicRpcDeploymentAutomation
$publicRpcDeploymentAutomationStatus = Get-DeploymentStatus -Report $publicRpcDeploymentAutomation
$publicRpcDeploymentAutomationAction = [string](Get-DeploymentProp -Object $publicRpcDeploymentAutomation -Name "action" -Default "")
$deploymentAutomationChecks = Get-DeploymentProp -Object $publicRpcDeploymentAutomation -Name "checks"
$deploymentAutomationReady = $publicRpcDeploymentAutomationStatus -eq "passed" `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:public-rpc:deployment:automation") `
    -and ($publicRpcDeploymentAutomationAction -eq "Validate") `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "bundleReportPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderCommandPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedFilesHaveNoPlaceholders" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedFilesKeepPrivateOrigin" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedNginxHasTls" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedNginxHasCorsForwarding" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedNginxHasRateLimit" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedNginxHasTimeoutGuardrails" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedSystemdUsesOwnerEnv" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedPreflightHasReadinessProbe" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedPreflightHasTesterUnauthProbe" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedPreflightHasDisallowedOriginProbe" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedPreflightChecksTimeoutGuardrails" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedPreflightBlocksBroadStatePath" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedPreflightBlocksPrivateWalletCreate" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedPreflightHasMethodRejectionProbes" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedNginxAuthorizationForwardingScoped" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "rollbackDrillPerformed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "rollbackRenderedConfigRestoredFromPrevious" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "rollbackOriginalConfigRestoredAfterDrill" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "rollbackArtifactsStayedInsideRenderDir" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedReportSummaryPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedReportSummaryPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedReportSummaryListsFiles" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedReportSummaryHasRequiredEnvNames" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedReportSummaryNoSecrets" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedReportSummaryBroadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedReportSummaryOwnerPathsOutsideRepo" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedReportSnapshotWritten" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedReportSnapshotNoSecrets" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedOwnerHostApplyScriptWritten" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedOwnerHostApplyScriptHasPlanApplyRollback" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedOwnerHostApplyScriptVerifiesHashes" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedOwnerHostApplyScriptRunsPostDeployProof" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedOwnerHostApplyPowerShellWritten" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedOwnerHostApplyPowerShellHasPlanApplyRollback" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedOwnerHostApplyPowerShellParses" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedOwnerHostApplyPowerShellVerifiesHashes" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedOwnerHostApplyPowerShellRunsPostDeployProof" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "ownerHostApplyPlanPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "ownerHostApplyPlanArtifactsHaveSha256" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "ownerHostApplyPlanIncludesOwnerApplyScript" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "ownerHostApplyPlanIncludesWindowsOwnerApplyScript" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "ownerHostApplyPlanIncludesPostDeployEvidence" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesTesterGatewayE2e" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesWalletTesterE2e" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesCutoverRehearsal" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesTruthTable" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesNoSecretScan" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentAutomationChecks -Name "hostMutationPerformedFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcDeploymentAutomation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $publicRpcDeploymentAutomation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcDeploymentAutomation -Name "broadcasts" -Default $true) -eq $false)
$publicRpcEdgeTemplateReady = ($publicRpcEdgeTemplateStatus -eq "passed") `
    -and ($edgeTemplateReady -eq $true) `
    -and ($edgeTemplateRepoOwned -eq $true) `
    -and ($edgeTemplateThirdPartyNeeded -eq $false) `
    -and ($edgeTemplateRequiresTls -eq $true) `
    -and ($edgeTemplateRequiresRateLimit -eq $true) `
    -and ($edgeTemplateForwardsOrigin -eq $true) `
    -and ($edgeTemplateStateExcluded -eq $true) `
    -and ($edgeTemplateDevnetStateExcluded -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "noSecrets" -Default $false) -eq $true)
Add-DeploymentItem -Items $items -Id "public-rpc-edge-template" `
    -Requirement "Public RPC exposure has a no-values owner edge template and render-validated deployment bundle for HTTPS reverse proxying, rate limiting, tester write preflight, wallet/tester cutover proof, disallowed-origin and blocked-private-path probes, verification, rollback, and no broad local state mirror." `
    -Status $(if ($publicRpcEdgeTemplateReady -and $deploymentBundleReady) { "passed" } else { "failed" }) `
    -Evidence "edgeTemplateStatus=$publicRpcEdgeTemplateStatus, bundleStatus=$publicRpcDeploymentBundleStatus, renderValidation=$((Get-DeploymentProp -Object $deploymentBundleChecks -Name "ownerRenderValidationPassed" -Default $false)), testerWritePreflight=$((Get-DeploymentProp -Object $deploymentBundleChecks -Name "includesTesterWritePreflight" -Default $false)), methodRejectionPreflight=$((Get-DeploymentProp -Object $deploymentBundleChecks -Name "includesMethodRejectionPreflight" -Default $false)), timeoutGuardrails=$((Get-DeploymentProp -Object $deploymentBundleChecks -Name "includesTimeoutGuardrails" -Default $false)), walletCutoverCommands=$deploymentBundleCoversWalletCutover, disallowedOriginPreflight=$((Get-DeploymentProp -Object $deploymentBundleChecks -Name "includesDisallowedOriginPreflight" -Default $false)), blockedStatePreflight=$((Get-DeploymentProp -Object $deploymentBundleChecks -Name "includesBroadStateBlockedPreflight" -Default $false)), privateWalletCreateBlocked=$((Get-DeploymentProp -Object $deploymentBundleChecks -Name "includesPrivateWalletCreateBlockedPreflight" -Default $false)), authForwardingScoped=$((Get-DeploymentProp -Object $deploymentBundleChecks -Name "authorizationForwardingScopedToTesterWrite" -Default $false)), repoOwned=$edgeTemplateRepoOwned, requiresTls=$edgeTemplateRequiresTls, requiresRateLimit=$edgeTemplateRequiresRateLimit, forwardsOrigin=$edgeTemplateForwardsOrigin, publicStateMirrorExcluded=$edgeTemplateStateExcluded, devnetStatePublicRpcExcluded=$edgeTemplateDevnetStateExcluded" `
    -Commands @("npm run flowchain:public-rpc:edge-template", "npm run flowchain:public-rpc:deployment-bundle")

Add-DeploymentItem -Items $items -Id "public-rpc-deployment-automation" `
    -Requirement "Public RPC deployment automation renders concrete owner-host Nginx, systemd, shell preflight, Windows preflight, tester write unauthenticated rejection probe, wallet/tester cutover proof commands, disallowed-origin and blocked-private-path probes, Linux and Windows owner-host plan/apply/rollback scripts, artifact hash verification, post-deploy proof commands, and rollback drill phases without host mutation or owner-value leakage." `
    -Status $(if ($deploymentAutomationReady) { "passed" } else { "failed" }) `
    -Evidence "automationStatus=$publicRpcDeploymentAutomationStatus, action=$publicRpcDeploymentAutomationAction, renderCommand=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderCommandPassed" -Default $false), noPlaceholders=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedFilesHaveNoPlaceholders" -Default $false), timeoutGuardrails=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedNginxHasTimeoutGuardrails" -Default $false), testerUnauthProbe=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedPreflightHasTesterUnauthProbe" -Default $false), methodRejectionProbes=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedPreflightHasMethodRejectionProbes" -Default $false), walletTesterE2e=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesWalletTesterE2e" -Default $false), cutoverRehearsal=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesCutoverRehearsal" -Default $false), disallowedOriginProbe=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedPreflightHasDisallowedOriginProbe" -Default $false), blockedStateProbe=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedPreflightBlocksBroadStatePath" -Default $false), privateWalletCreateBlocked=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedPreflightBlocksPrivateWalletCreate" -Default $false), authForwardingScoped=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedNginxAuthorizationForwardingScoped" -Default $false), rollbackDrill=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "rollbackDrillPerformed" -Default $false), renderSummary=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedReportSummaryPresent" -Default $false), renderSnapshot=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedReportSnapshotWritten" -Default $false), applyScript=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedOwnerHostApplyScriptWritten" -Default $false), applyScriptHashes=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedOwnerHostApplyScriptVerifiesHashes" -Default $false), applyScriptPostDeploy=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedOwnerHostApplyScriptRunsPostDeployProof" -Default $false), windowsApplyScript=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedOwnerHostApplyPowerShellWritten" -Default $false), windowsApplyScriptParses=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedOwnerHostApplyPowerShellParses" -Default $false), windowsApplyScriptHashes=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedOwnerHostApplyPowerShellVerifiesHashes" -Default $false), windowsApplyScriptPostDeploy=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "renderedOwnerHostApplyPowerShellRunsPostDeployProof" -Default $false), applyPlan=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "ownerHostApplyPlanPresent" -Default $false), ownerApplyScriptInPlan=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "ownerHostApplyPlanIncludesOwnerApplyScript" -Default $false), windowsOwnerApplyScriptInPlan=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "ownerHostApplyPlanIncludesWindowsOwnerApplyScript" -Default $false), artifactHashes=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "ownerHostApplyPlanArtifactsHaveSha256" -Default $false), hostMutationFalse=$(Get-DeploymentProp -Object $deploymentAutomationChecks -Name "hostMutationPerformedFalse" -Default $false)" `
    -Commands @("npm run flowchain:public-rpc:deployment:automation")

$service = $reports.serviceStatus
$serviceStatus = Get-DeploymentStatus -Report $service
$bind = Get-DeploymentProp -Object $service -Name "bind"
$chain = Get-DeploymentProp -Object $service -Name "chain"
$node = Get-DeploymentProp -Object $service -Name "node"
$controlPlane = Get-DeploymentProp -Object $service -Name "controlPlane"
$serviceProfile = Get-DeploymentProp -Object $service -Name "serviceProfile"
$latestHeight = [string](Get-DeploymentProp -Object $chain -Name "latestHeight" -Default "")
$finalizedHeight = [string](Get-DeploymentProp -Object $chain -Name "finalizedHeight" -Default "")
$privateBind = (Get-DeploymentProp -Object $bind -Name "localDefaultPrivate" -Default $false) -eq $true
$serviceReady = ($serviceStatus -eq "passed") `
    -and ($privateBind -eq $true) `
    -and ([string](Get-DeploymentProp -Object $node -Name "status") -eq "running") `
    -and ([string](Get-DeploymentProp -Object $controlPlane -Name "status") -eq "running") `
    -and ((Get-DeploymentProp -Object $serviceProfile -Name "liveProfile" -Default $false) -eq $true) `
    -and ($latestHeight -match '^\d+$') `
    -and ($finalizedHeight -match '^\d+$')
Add-DeploymentItem -Items $items -Id "private-service-origin" `
    -Requirement "The public deployment origin service is running privately in live profile before any owner TLS edge is considered shareable." `
    -Status $(if ($serviceReady) { "passed" } else { "failed" }) `
    -Evidence "serviceStatus=$serviceStatus, privateBind=$privateBind, latestHeight=$latestHeight, finalizedHeight=$finalizedHeight" `
    -Commands @("npm run flowchain:service:status")

$monitor = $reports.serviceMonitor
$monitorStatus = Get-DeploymentStatus -Report $monitor
$monitorAdvanced = Get-DeploymentProp -Object $monitor -Name "heightAdvanced" -Default $false
$monitorSamples = [int](Get-DeploymentProp -Object $monitor -Name "sampleCount" -Default 0)
Add-DeploymentItem -Items $items -Id "pre-share-monitoring" `
    -Requirement "The deployment has recent service-monitor evidence that block height advances over multiple samples." `
    -Status $(if (($monitorStatus -eq "passed") -and ($monitorAdvanced -eq $true) -and ($monitorSamples -ge 2)) { "passed" } else { "failed" }) `
    -Evidence "monitorStatus=$monitorStatus, samples=$monitorSamples, heightAdvanced=$monitorAdvanced" `
    -Commands @("npm run flowchain:service:monitor")

$supervisorValidation = $reports.serviceSupervisorValidation
$supervisorValidationStatus = Get-DeploymentStatus -Report $supervisorValidation
$supervisorRestartAttempts = [int](Get-DeploymentProp -Object $supervisorValidation -Name "restartAttempts" -Default 0)
$supervisorNodeRecovery = Get-DeploymentProp -Object $supervisorValidation -Name "nodeRecovery"
$supervisorRelayerRecovery = Get-DeploymentProp -Object $supervisorValidation -Name "relayerLoopRecovery"
$supervisorChecks = Get-DeploymentProp -Object $supervisorValidation -Name "checks"
$supervisorNodeRestartAttempts = [int](Get-DeploymentProp -Object $supervisorNodeRecovery -Name "restartAttempts" -Default 0)
$supervisorRelayerRestartAttempts = [int](Get-DeploymentProp -Object $supervisorRelayerRecovery -Name "restartAttempts" -Default 0)
$supervisorRecoveryReady = ($supervisorValidationStatus -eq "passed") `
    -and ($supervisorRestartAttempts -ge 1) `
    -and ($supervisorNodeRestartAttempts -ge 1) `
    -and ($supervisorRelayerRestartAttempts -ge 1) `
    -and ((Get-DeploymentProp -Object $supervisorChecks -Name "nodeCrashDetected" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $supervisorChecks -Name "afterNodeRecoveryNodeRunning" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $supervisorChecks -Name "afterNodeRecoveryControlPlaneRunning" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $supervisorChecks -Name "afterNodeRecoveryLiveProfile" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $supervisorChecks -Name "afterNodeRecoveryMaxBlocksUnbounded" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $supervisorChecks -Name "relayerCrashDetected" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $supervisorChecks -Name "afterRelayerRecoveryLoopRunning" -Default $false) -eq $true)
Add-DeploymentItem -Items $items -Id "service-autorecovery" `
    -Requirement "The owner service has an autorecovery supervisor and an isolated recovery drill proving node, control-plane, and bridge-relayer-loop restart without touching live state." `
    -Status $(if ($supervisorRecoveryReady) { "passed" } else { "failed" }) `
    -Evidence "supervisorValidation=$supervisorValidationStatus, restartAttempts=$supervisorRestartAttempts, nodeRestartAttempts=$supervisorNodeRestartAttempts, relayerRestartAttempts=$supervisorRelayerRestartAttempts, nodeRecovered=$(Get-DeploymentProp -Object $supervisorChecks -Name "afterNodeRecoveryNodeRunning" -Default $false), relayerRecovered=$(Get-DeploymentProp -Object $supervisorChecks -Name "afterRelayerRecoveryLoopRunning" -Default $false)" `
    -Commands @("npm run flowchain:service:supervisor:validate", "npm run flowchain:service:supervisor -- -IntervalSeconds 30 -MaxRestartAttempts 3")

$serviceInstallValidation = $reports.serviceInstallValidation
$serviceInstallValidationStatus = Get-DeploymentStatus -Report $serviceInstallValidation
$serviceInstallChecks = Get-DeploymentProp -Object $serviceInstallValidation -Name "checks"
$serviceInstallReady = ($serviceInstallValidationStatus -eq "passed") `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "packageScriptsPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "planCommandPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "planDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "schedulerCmdletsAvailable" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "scheduledTaskActionSupportsWorkingDirectory" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "actionUsesSupervisor" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "liveProfileDefault" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "noBridgeRelayerDefault" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "bridgeRelayerOptInPlanCommandPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "bridgeRelayerOptInPlanDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "bridgeRelayerOptInStartsLoop" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "bridgeRelayerOptInAddsSupervisorFlag" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "bridgeRelayerOptInUsesSupervisor" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "commandOmitsNonLiveProfile" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "statusCommandPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "statusActionReadOnly" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "statusDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "statusReportNoSecrets" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "statusReportEnvValuesPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "statusReportBroadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "uninstallAbsentPreflightTaskAbsent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "uninstallAbsentCommandPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "uninstallAbsentTaskWasAbsentBefore" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "uninstallAbsentDidNotCreateTask" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "uninstallAbsentDidNotRemoveTask" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "uninstallAbsentReportNoSecrets" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "uninstallAbsentReportEnvValuesPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "uninstallAbsentReportBroadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "commandsPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $serviceInstallValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:service:install:windows") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:service:install:validate")
Add-DeploymentItem -Items $items -Id "service-install-automation" `
    -Requirement "The owner host has a no-secret Windows install, read-only status, and safe absent-task uninstall no-op path for registering the live supervisor as a reboot-persistent scheduled task." `
    -Status $(if ($serviceInstallReady) { "passed" } else { "failed" }) `
    -Evidence "serviceInstallValidation=$serviceInstallValidationStatus, planDidNotMutate=$(Get-DeploymentProp -Object $serviceInstallChecks -Name "planDidNotMutate"), statusCommand=$(Get-DeploymentProp -Object $serviceInstallChecks -Name "statusCommandPassed"), statusDidNotMutate=$(Get-DeploymentProp -Object $serviceInstallChecks -Name "statusDidNotMutate"), uninstallNoop=$(Get-DeploymentProp -Object $serviceInstallChecks -Name "uninstallAbsentDidNotCreateTask"), liveProfileDefault=$(Get-DeploymentProp -Object $serviceInstallChecks -Name "liveProfileDefault"), relayerDefaultOff=$(Get-DeploymentProp -Object $serviceInstallChecks -Name "noBridgeRelayerDefault"), relayerOptIn=$(Get-DeploymentProp -Object $serviceInstallChecks -Name "bridgeRelayerOptInStartsLoop"), commandsPresent=$(Get-DeploymentProp -Object $serviceInstallChecks -Name "commandsPresent")" `
    -Commands @("npm run flowchain:service:install:validate", "npm run flowchain:service:install:windows -- -Action Plan", "npm run flowchain:service:install:windows -- -Action Install", "npm run flowchain:service:install:windows -- -Action Status", "npm run flowchain:service:install:windows -- -Action Uninstall")

$systemdInstallValidation = $reports.systemdServiceInstallValidation
$systemdInstallValidationStatus = Get-DeploymentStatus -Report $systemdInstallValidation
$systemdInstallChecks = Get-DeploymentProp -Object $systemdInstallValidation -Name "checks"
$systemdInstallReady = ($systemdInstallValidationStatus -eq "passed") `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "installScriptExists" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "installPackageScriptPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "validationPackageScriptPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "installPlanValidationPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "installPlanCommandPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "installPlanDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "installPlanUsesRenderedUnits" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "bridgeRelayerOptInPlanCommandPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "bridgeRelayerOptInPlanReportPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "bridgeRelayerOptInPlanDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "bridgeRelayerOptInPlanUsesRenderedUnits" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "bridgeRelayerOptInStartsLoop" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "bridgeRelayerOptInUsesSupervisor" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "bridgeRelayerOptInPlanNoSecrets" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "bridgeRelayerOptInPlanEnvValuesPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "bridgeRelayerOptInPlanBroadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "liveServiceUsesLiveProfile" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "liveServiceStopPreservesState" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "liveServiceRestartOnFailure" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "supervisorUsesAutorecoveryLoop" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "supervisorRestartAlways" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "bridgeRelayerDefaultOff" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "ownerEnvFileUsed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "leastPrivilegeHardeningPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "writePathsScoped" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "hostMutationPerformedFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "installPlanReportNoSecrets" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "installPlanReportEnvValuesPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallChecks -Name "installPlanReportBroadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $systemdInstallValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $systemdInstallValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:service:install:systemd") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:service:install:systemd:validate")
Add-DeploymentItem -Items $items -Id "systemd-service-install-automation" `
    -Requirement "The owner Linux/VPS host has a real no-secret systemd plan/install/status/uninstall path plus bridge-relayer opt-in plan for rendered live-service and supervisor units, validated through read-only rendered-unit plan drills." `
    -Status $(if ($systemdInstallReady) { "passed" } else { "failed" }) `
    -Evidence "systemdInstallValidation=$systemdInstallValidationStatus, installScript=$(Get-DeploymentProp -Object $systemdInstallChecks -Name "installScriptExists"), plan=$(Get-DeploymentProp -Object $systemdInstallChecks -Name "installPlanValidationPassed"), planDidNotMutate=$(Get-DeploymentProp -Object $systemdInstallChecks -Name "installPlanDidNotMutate"), renderedUnits=$(Get-DeploymentProp -Object $systemdInstallChecks -Name "installPlanUsesRenderedUnits"), relayerDefaultOff=$(Get-DeploymentProp -Object $systemdInstallChecks -Name "bridgeRelayerDefaultOff"), relayerOptIn=$(Get-DeploymentProp -Object $systemdInstallChecks -Name "bridgeRelayerOptInStartsLoop"), liveProfile=$(Get-DeploymentProp -Object $systemdInstallChecks -Name "liveServiceUsesLiveProfile"), supervisor=$(Get-DeploymentProp -Object $systemdInstallChecks -Name "supervisorUsesAutorecoveryLoop"), hardening=$(Get-DeploymentProp -Object $systemdInstallChecks -Name "leastPrivilegeHardeningPresent")" `
    -Commands @("npm run flowchain:service:install:systemd:validate", "npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>", "npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -StartBridgeRelayerLoop", "npm run flowchain:service:install:systemd -- -Action Install -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>", "npm run flowchain:service:install:systemd -- -Action Status", "npm run flowchain:service:install:systemd -- -Action Uninstall")

$opsSnapshot = $reports.opsSnapshot
$opsSnapshotStatus = Get-DeploymentStatus -Report $opsSnapshot
$opsCriticalCount = [int](Get-DeploymentProp -Object $opsSnapshot -Name "criticalCount" -Default 999)
$opsBlockedCount = [int](Get-DeploymentProp -Object $opsSnapshot -Name "blockedCount" -Default 0)
Add-DeploymentItem -Items $items -Id "ops-snapshot" `
    -Requirement "Owner deployment has a no-secret ops snapshot that separates critical incidents from expected owner-input blockers and lists incident commands." `
    -Status $(if (($opsSnapshotStatus -in @("passed", "blocked")) -and $opsCriticalCount -eq 0) { "passed" } else { "failed" }) `
    -Evidence "opsSnapshot=$opsSnapshotStatus, criticalCount=$opsCriticalCount, blockedCount=$opsBlockedCount" `
    -Commands @("npm run flowchain:ops:snapshot -- -AllowBlocked")

$opsAlertRules = $reports.opsAlertRules
$opsAlertRulesStatus = Get-DeploymentStatus -Report $opsAlertRules
$opsAlertCriticalRules = [int](Get-DeploymentProp -Object $opsAlertRules -Name "criticalRuleCount" -Default 0)
$opsAlertBlockedRules = [int](Get-DeploymentProp -Object $opsAlertRules -Name "blockedRuleCount" -Default 0)
$opsAlertUnmappedCodes = @((Get-DeploymentProp -Object $opsAlertRules -Name "unmappedCurrentFindingCodes" -Default @()))
Add-DeploymentItem -Items $items -Id "ops-alert-rules" `
    -Requirement "Owner deployment has a no-secret alert rule manifest that maps every current ops finding to operator commands without committing delivery credentials." `
    -Status $(if (($opsAlertRulesStatus -eq "passed") -and ($opsAlertCriticalRules -ge 5) -and ($opsAlertBlockedRules -ge 5) -and ($opsAlertUnmappedCodes.Count -eq 0)) { "passed" } else { "failed" }) `
    -Evidence "alertRules=$opsAlertRulesStatus, criticalRules=$opsAlertCriticalRules, blockedRules=$opsAlertBlockedRules, unmappedCurrentFindingCodes=$($opsAlertUnmappedCodes.Count)" `
    -Commands @("npm run flowchain:ops:alerts -- -AllowBlocked")

$alertInstallValidation = $reports.alertInstallValidation
$alertInstallValidationStatus = Get-DeploymentStatus -Report $alertInstallValidation
$alertInstallChecks = Get-DeploymentProp -Object $alertInstallValidation -Name "checks"
$alertInstallReady = ($alertInstallValidationStatus -eq "passed") `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "packageScriptsPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "planCommandPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "planDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "statusCommandPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "statusDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "statusTaskStatePreserved" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "uninstallAbsentCommandPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "uninstallAbsentDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "uninstallAbsentTaskAbsentBefore" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "uninstallAbsentTaskAbsentAfter" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "schedulerCmdletsAvailable" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "scheduledTaskTriggerSupportsRepetition" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "actionUsesAlertsScript" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "hasAllowBlocked" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "scheduledCommandDoesNotDisableRefresh" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "systemdValidationPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "systemdPlanDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "systemdServiceUnitPlanned" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "systemdTimerUnitPlanned" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "systemdTimerIntervalConfigured" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "systemdNoExternalDelivery" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "noExternalDelivery" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $alertInstallValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:ops:alerts:install:windows") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:ops:alerts:install:systemd") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:ops:alerts:install:systemd:validate") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:ops:alerts:install:validate")
Add-DeploymentItem -Items $items -Id "ops-alert-schedule-automation" `
    -Requirement "The owner host has no-secret Windows Scheduled Task and Linux systemd timer install paths for recurring ops snapshot and alert-rule refresh without committed external delivery credentials." `
    -Status $(if ($alertInstallReady) { "passed" } else { "failed" }) `
    -Evidence "alertInstallValidation=$alertInstallValidationStatus, planDidNotMutate=$(Get-DeploymentProp -Object $alertInstallChecks -Name "planDidNotMutate"), statusDidNotMutate=$(Get-DeploymentProp -Object $alertInstallChecks -Name "statusDidNotMutate"), systemdValidation=$(Get-DeploymentProp -Object $alertInstallChecks -Name "systemdValidationPassed"), systemdTimer=$(Get-DeploymentProp -Object $alertInstallChecks -Name "systemdTimerUnitPlanned"), hasAllowBlocked=$(Get-DeploymentProp -Object $alertInstallChecks -Name "hasAllowBlocked"), noExternalDelivery=$(Get-DeploymentProp -Object $alertInstallChecks -Name "noExternalDelivery")" `
    -Commands @("npm run flowchain:ops:alerts:install:validate", "npm run flowchain:ops:alerts:install:windows -- -Action Plan", "npm run flowchain:ops:alerts:install:systemd -- -Action Plan", "npm run flowchain:ops:alerts:install:systemd:validate", "npm run flowchain:ops:alerts:install:windows -- -Action Install", "npm run flowchain:ops:alerts:install:windows -- -Action Status", "npm run flowchain:ops:alerts:install:windows -- -Action Uninstall", "npm run flowchain:ops:alerts:install:systemd -- -Action Status", "npm run flowchain:ops:alerts:install:systemd -- -Action Uninstall")

$metricsInstallValidation = $reports.metricsInstallValidation
$metricsInstallValidationStatus = Get-DeploymentStatus -Report $metricsInstallValidation
$metricsInstallChecks = Get-DeploymentProp -Object $metricsInstallValidation -Name "checks"
$metricsInstallFailedChecks = @((Get-DeploymentProp -Object $metricsInstallValidation -Name "failedChecks" -Default @()))
$metricsInstallReady = ($metricsInstallValidationStatus -eq "passed") `
    -and ($metricsInstallFailedChecks.Count -eq 0) `
    -and ((Get-DeploymentProp -Object $metricsInstallChecks -Name "packageScriptsPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $metricsInstallChecks -Name "planDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $metricsInstallChecks -Name "statusDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $metricsInstallChecks -Name "uninstallAbsentDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $metricsInstallChecks -Name "actionUsesMetricsScript" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $metricsInstallChecks -Name "hasAllowBlocked" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $metricsInstallChecks -Name "hasMetricsJsonPath" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $metricsInstallChecks -Name "hasPrometheusTextPath" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $metricsInstallChecks -Name "scheduledCommandDoesNotDisableRefresh" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $metricsInstallChecks -Name "systemdValidationPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $metricsInstallChecks -Name "systemdPlanDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $metricsInstallChecks -Name "systemdServiceUnitPlanned" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $metricsInstallChecks -Name "systemdTimerUnitPlanned" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $metricsInstallChecks -Name "systemdTimerIntervalConfigured" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $metricsInstallChecks -Name "systemdNoExternalDelivery" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $metricsInstallChecks -Name "noExternalDelivery" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $metricsInstallValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $metricsInstallValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:ops:metrics:install:windows") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:ops:metrics:install:systemd") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:ops:metrics:install:systemd:validate") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:ops:metrics:install:validate")
Add-DeploymentItem -Items $items -Id "ops-metrics-schedule-automation" `
    -Requirement "The owner host has no-secret Windows Scheduled Task and Linux systemd timer install paths for recurring ops metrics JSON and Prometheus textfile refresh without committed external delivery credentials." `
    -Status $(if ($metricsInstallReady) { "passed" } else { "failed" }) `
    -Evidence "metricsInstallValidation=$metricsInstallValidationStatus, planDidNotMutate=$(Get-DeploymentProp -Object $metricsInstallChecks -Name "planDidNotMutate"), statusDidNotMutate=$(Get-DeploymentProp -Object $metricsInstallChecks -Name "statusDidNotMutate"), systemdValidation=$(Get-DeploymentProp -Object $metricsInstallChecks -Name "systemdValidationPassed"), systemdTimer=$(Get-DeploymentProp -Object $metricsInstallChecks -Name "systemdTimerUnitPlanned"), hasMetricsJsonPath=$(Get-DeploymentProp -Object $metricsInstallChecks -Name "hasMetricsJsonPath"), hasPrometheusTextPath=$(Get-DeploymentProp -Object $metricsInstallChecks -Name "hasPrometheusTextPath"), noExternalDelivery=$(Get-DeploymentProp -Object $metricsInstallChecks -Name "noExternalDelivery")" `
    -Commands @("npm run flowchain:ops:metrics:install:validate", "npm run flowchain:ops:metrics:install:windows -- -Action Plan", "npm run flowchain:ops:metrics:install:systemd -- -Action Plan", "npm run flowchain:ops:metrics:install:systemd:validate", "npm run flowchain:ops:metrics:install:windows -- -Action Install", "npm run flowchain:ops:metrics:install:windows -- -Action Status", "npm run flowchain:ops:metrics:install:windows -- -Action Uninstall", "npm run flowchain:ops:metrics:install:systemd -- -Action Status", "npm run flowchain:ops:metrics:install:systemd -- -Action Uninstall")

$opsEscalationDryRun = $reports.opsEscalationDryRun
$opsEscalationDryRunStatus = Get-DeploymentStatus -Report $opsEscalationDryRun
$opsEscalationChecks = Get-DeploymentProp -Object $opsEscalationDryRun -Name "checks"
$opsEscalationFailedChecks = @((Get-DeploymentProp -Object $opsEscalationDryRun -Name "failedChecks" -Default @()))
$opsEscalationReady = ($opsEscalationDryRunStatus -eq "passed") `
    -and ($opsEscalationFailedChecks.Count -eq 0) `
    -and ((Get-DeploymentProp -Object $opsEscalationChecks -Name "notificationPlanNoNetworkDelivery" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $opsEscalationChecks -Name "notificationPlanStoresNoSecrets" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $opsEscalationChecks -Name "notificationPlanOutOfRepo" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $opsEscalationChecks -Name "everyCurrentFindingMapped" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $opsEscalationChecks -Name "everyCurrentFindingHasCommands" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $opsEscalationChecks -Name "dryRunEventsDoNotSend" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $opsEscalationChecks -Name "dryRunEventsStoreNoCredentials" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $opsEscalationDryRun -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $opsEscalationDryRun -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $opsEscalationDryRun -Name "broadcasts" -Default $true) -eq $false) `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:ops:escalation:dry-run")
Add-DeploymentItem -Items $items -Id "ops-escalation-dry-run" `
    -Requirement "Owner deployment has a no-secret escalation dry run that maps every current ops finding to local operator actions while proving repo-owned alert evidence does not send network delivery or store external delivery credentials." `
    -Status $(if ($opsEscalationReady) { "passed" } else { "failed" }) `
    -Evidence "dryRun=$opsEscalationDryRunStatus, failedChecks=$($opsEscalationFailedChecks.Count), events=$(Get-DeploymentProp -Object $opsEscalationDryRun -Name "dryRunEventCount"), noNetworkDelivery=$(Get-DeploymentProp -Object $opsEscalationChecks -Name "notificationPlanNoNetworkDelivery"), storesNoSecrets=$(Get-DeploymentProp -Object $opsEscalationChecks -Name "notificationPlanStoresNoSecrets")" `
    -Commands @("npm run flowchain:ops:escalation:dry-run -- -AllowBlocked")

$ownerInputs = $reports.ownerInputs
$ownerStatus = Get-DeploymentStatus -Report $ownerInputs
$ownerReady = Get-DeploymentProp -Object $ownerInputs -Name "ownerInputReady" -Default $false
$ownerMissingInputs = @((Get-DeploymentProp -Object $ownerInputs -Name "missingEnvNames" -Default @()))
Add-DeploymentItem -Items $items -Id "owner-input-contract" `
    -Requirement "The owner deployment contract validates the required public RPC, tester write gateway, backup, and Base 8453 input names without values." `
    -Status $(if (($ownerStatus -eq "passed") -and ($ownerReady -eq $true)) { "passed" } elseif ($ownerStatus -eq "blocked") { "blocked" } else { "failed" }) `
    -Evidence "ownerInputsStatus=$ownerStatus, ownerInputReady=$ownerReady" `
    -Commands @("npm run flowchain:owner-inputs") `
    -Blockers @($ownerMissingInputs)

$publicRpc = $reports.publicRpc
$publicRpcStatus = Get-DeploymentStatus -Report $publicRpc
$publicRpcReady = Get-DeploymentProp -Object $publicRpc -Name "publicRpcReady" -Default $false
$publicRpcSyntheticCanary = $reports.publicRpcSyntheticCanary
$publicRpcSyntheticCanaryStatus = Get-DeploymentStatus -Report $publicRpcSyntheticCanary
$publicRpcSyntheticCanaryReady = Get-DeploymentProp -Object $publicRpcSyntheticCanary -Name "syntheticCanaryReady" -Default $false
$publicRpcSyntheticCanaryBlockedOnlyOnOwnerInputs = Get-DeploymentProp -Object $publicRpcSyntheticCanary -Name "blockedOnlyOnKnownExternalOwnerInputs" -Default $false
$publicRpcSyntheticCanaryMissingEnvNames = @((Get-DeploymentProp -Object $publicRpcSyntheticCanary -Name "missingEnvNames" -Default @()))
$publicRpcCanaryScheduleValidation = $reports.publicRpcCanaryScheduleValidation
$publicRpcCanaryScheduleValidationStatus = Get-DeploymentStatus -Report $publicRpcCanaryScheduleValidation
$publicRpcCanaryScheduleChecks = Get-DeploymentProp -Object $publicRpcCanaryScheduleValidation -Name "checks"
$publicRpcCanaryScheduleFailedChecks = @((Get-DeploymentProp -Object $publicRpcCanaryScheduleValidation -Name "failedChecks" -Default @()))
$publicRpcCanaryScheduleReady = ($publicRpcCanaryScheduleValidationStatus -eq "passed") `
    -and ($publicRpcCanaryScheduleFailedChecks.Count -eq 0) `
    -and ((Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "packageScriptPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "syntheticCanaryPackageScriptPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "canaryScriptReadOnlyPlan" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "windowsPlanUsesCanaryScript" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "windowsPlanUsesOwnerEnvFile" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "windowsPlanHasAllowBlocked" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "windowsPlanDoesNotMutateHost" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "systemdServiceRendered" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "systemdServiceUsesOwnerEnvFile" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "systemdServiceHasAllowBlocked" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "systemdServiceHardeningPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "systemdTimerRendered" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "systemdTimerPersistent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "systemdTimerIntervalConfigured" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "noExternalDelivery" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "hostMutationPerformedFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcCanaryScheduleValidation -Name "hostMutationPerformed" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $publicRpcCanaryScheduleValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $publicRpcCanaryScheduleValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:public-rpc:canary:schedule:validate")
$publicValidation = $reports.publicRpcValidation
$publicValidationStatus = Get-DeploymentStatus -Report $publicValidation
$publicValidationChecks = Get-DeploymentProp -Object $publicValidation -Name "checks"
$publicValidationPassed = ($publicValidationStatus -eq "passed") `
    -and ((Get-DeploymentProp -Object $publicValidationChecks -Name "allowedOriginAccepted" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicValidationChecks -Name "disallowedOriginRejected" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicValidationChecks -Name "securityHeaderProbeSkippedForLocalEndpoint" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicValidationChecks -Name "securityHeaderPassRequiredOnlyForPublicMode" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicValidationChecks -Name "rateLimitProbePerformed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicValidationChecks -Name "rateLimitRejected" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicValidationChecks -Name "rateLimitRetryAfterHeaderPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicValidationChecks -Name "responseHygienePassed" -Default $false) -eq $true)
$publicAbuse = $reports.publicRpcAbuseTest
$publicAbuseStatus = Get-DeploymentStatus -Report $publicAbuse
$publicAbuseReady = Get-DeploymentProp -Object $publicAbuse -Name "abuseTestReady" -Default $false
$publicAbuseChecks = Get-DeploymentProp -Object $publicAbuse -Name "checks"
$publicAbuseRequiredChecks = @(
    "serverStarted",
    "allowedOriginAccepted",
    "disallowedOriginRejected",
    "optionsPreflightPassed",
    "unsupportedMediaTypeRejected",
    "malformedJsonRejected",
    "unknownMethodRejected",
    "transactionSubmitRejected",
    "bridgeObservationSubmitRejected",
    "rawJsonGetRejected",
    "devnetStateRejected",
    "bridgeObservationPostAliasRejected",
    "badParamsRejected",
    "emptyBatchRejected",
    "oversizedBatchRejected",
    "oversizedBodyRejected",
    "notificationNoContent",
    "rateLimitRejected",
    "responseHygienePassed"
)
$publicAbuseMissingChecks = @($publicAbuseRequiredChecks | Where-Object { (Get-DeploymentProp -Object $publicAbuseChecks -Name $_ -Default $false) -ne $true })
$publicAbusePassed = ($publicAbuseStatus -eq "passed") `
    -and ($publicAbuseReady -eq $true) `
    -and ($publicAbuseMissingChecks.Count -eq 0) `
    -and ((Get-DeploymentProp -Object $publicAbuse -Name "ownerValuesRequired" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $publicAbuse -Name "noLiveBroadcast" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicAbuse -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $publicAbuse -Name "noSecrets" -Default $false) -eq $true)
Add-DeploymentItem -Items $items -Id "public-rpc-abuse-test" `
    -Requirement "The local public RPC abuse harness proves CORS rejection, media-type rejection, malformed JSON handling, broad local-state rejection, batch/body caps, notification handling, rate limiting, and no-secret response summaries." `
    -Status $(if ($publicAbusePassed) { "passed" } else { "failed" }) `
    -Evidence "abuseStatus=$publicAbuseStatus, abuseReady=$publicAbuseReady, missingChecks=$($publicAbuseMissingChecks.Count)" `
    -Commands @("npm run flowchain:public-rpc:abuse-test")
Add-DeploymentItem -Items $items -Id "public-rpc-synthetic-canary" `
    -Requirement "The public RPC synthetic canary must run read-only live endpoint probes, avoid write methods, and stay owner-blocked until the public endpoint exists." `
    -Status $(if (($publicRpcSyntheticCanaryStatus -eq "passed") -and ($publicRpcSyntheticCanaryReady -eq $true)) { "passed" } elseif (($publicRpcSyntheticCanaryStatus -eq "blocked") -and ($publicRpcSyntheticCanaryBlockedOnlyOnOwnerInputs -eq $true)) { "blocked" } else { "failed" }) `
    -Evidence "canaryStatus=$publicRpcSyntheticCanaryStatus, ready=$publicRpcSyntheticCanaryReady, ownerBlocked=$publicRpcSyntheticCanaryBlockedOnlyOnOwnerInputs" `
    -Commands @("npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked") `
    -Blockers @($publicRpcSyntheticCanaryMissingEnvNames)
Add-DeploymentItem -Items $items -Id "public-rpc-canary-schedule-automation" `
    -Requirement "The owner host has no-secret Windows Scheduled Task and Linux systemd timer plans for recurring read-only public RPC synthetic canary checks without host mutation or external delivery credentials." `
    -Status $(if ($publicRpcCanaryScheduleReady) { "passed" } else { "failed" }) `
    -Evidence "canaryScheduleValidation=$publicRpcCanaryScheduleValidationStatus, windowsPlan=$(Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "windowsPlanUsesCanaryScript"), systemdTimer=$(Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "systemdTimerRendered"), ownerEnv=$(Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "systemdServiceUsesOwnerEnvFile"), noMutation=$(Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "hostMutationPerformedFalse"), noExternalDelivery=$(Get-DeploymentProp -Object $publicRpcCanaryScheduleChecks -Name "noExternalDelivery")" `
    -Commands @("npm run flowchain:public-rpc:canary:schedule:validate", "npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked")
Add-DeploymentItem -Items $items -Id "public-rpc-edge" `
    -Requirement "The owner TLS edge must pass endpoint, CORS, live security-header, rate-limit, readiness, and response-hygiene checks before sharing." `
    -Status $(if (($publicRpcStatus -eq "passed") -and ($publicRpcReady -eq $true) -and ($publicRpcSyntheticCanaryReady -eq $true) -and ($publicRpcCanaryScheduleReady -eq $true) -and ($publicValidationPassed -eq $true) -and ($publicAbusePassed -eq $true)) { "passed" } elseif (($publicRpcStatus -eq "blocked") -and ($publicRpcSyntheticCanaryStatus -in @("blocked", "passed")) -and ($publicRpcCanaryScheduleReady -eq $true) -and ($publicValidationPassed -eq $true) -and ($publicAbusePassed -eq $true)) { "blocked" } else { "failed" }) `
    -Evidence "publicRpcStatus=$publicRpcStatus, publicRpcReady=$publicRpcReady, canaryStatus=$publicRpcSyntheticCanaryStatus, canaryReady=$publicRpcSyntheticCanaryReady, canaryScheduleReady=$publicRpcCanaryScheduleReady, validationStatus=$publicValidationStatus, validationPassed=$publicValidationPassed, abuseStatus=$publicAbuseStatus, abusePassed=$publicAbusePassed" `
    -Commands @("npm run flowchain:public-rpc:validate", "npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked", "npm run flowchain:public-rpc:canary:schedule:validate", "npm run flowchain:public-rpc:abuse-test", "npm run flowchain:public-rpc:check") `
    -Blockers @("FLOWCHAIN_RPC_PUBLIC_URL", "FLOWCHAIN_RPC_ALLOWED_ORIGINS", "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE", "FLOWCHAIN_RPC_TLS_TERMINATED")

$backup = $reports.backup
$backupStatus = Get-DeploymentStatus -Report $backup
$backupDetails = Get-DeploymentProp -Object $backup -Name "backup"
$backupSnapshotProof = Get-DeploymentProp -Object $backupDetails -Name "snapshotProofStatus" -Default "not-run"
$backupRestoreProof = Get-DeploymentProp -Object $backupDetails -Name "restoreProofStatus" -Default "not-run"
$backupRestoreValidation = $reports.backupRestoreValidation
$backupRestoreValidationStatus = Get-DeploymentStatus -Report $backupRestoreValidation
$backupRestoreValidationChecks = Get-DeploymentProp -Object $backupRestoreValidation -Name "checks"
$backupRestoreValidationRequiredChecks = @(
    "backupCommandPassed",
    "restoreCommandPassed",
    "backupRestoreHashRoundTrip",
    "secondBackupCommandPassed",
    "latestManifestMatchesSecondSnapshot",
    "latestRestoreCommandPassed",
    "latestRestoreUsedLatestSnapshot",
    "restoreTargetsLiveStateProtected",
    "liveStateNonMutationProven",
    "corruptedSnapshotDetected",
    "manifestTamperDetected",
    "missingStateArtifactDetected",
    "missingSnapshotManifestDetected",
    "latestPointerTamperDetected",
    "wrongChainStateMismatchDetected",
    "retentionBackupCommandPassed",
    "retentionPrunedOldestSnapshot",
    "retentionRetainedNewestSnapshots",
    "retentionLatestManifestMatchesNewest",
    "retentionReportShowsPrunedSnapshot",
    "retentionReportProtectsCurrentSnapshot",
    "retentionRestoreCommandPassed",
    "retentionRestoreUsedNewestSnapshot"
)
$backupRestoreValidationMissingChecks = @($backupRestoreValidationRequiredChecks | Where-Object {
    (Get-DeploymentProp -Object $backupRestoreValidationChecks -Name $_ -Default $false) -ne $true
})
$backupRestoreValidationPassed = $backupRestoreValidationStatus -eq "passed" `
    -and ($backupRestoreValidationMissingChecks.Count -eq 0) `
    -and ((Get-DeploymentProp -Object $backupRestoreValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $backupRestoreValidation -Name "noSecrets" -Default $false) -eq $true)
Add-DeploymentItem -Items $items -Id "state-backup-restore-validation" `
    -Requirement "Backup tooling must create manifest-backed state snapshots, rotate retained snapshots safely, restore the latest retained snapshot, reject tampered/missing/stale/wrong-chain backup evidence, and avoid owner secrets." `
    -Status $(if ($backupRestoreValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "validationStatus=$backupRestoreValidationStatus, requiredChecks=$($backupRestoreValidationRequiredChecks.Count), missingChecks=$($backupRestoreValidationMissingChecks.Count)" `
    -Commands @("npm run flowchain:backup:restore:validate")

$backupOwnerPathDryRun = $reports.backupOwnerPathDryRun
$backupOwnerPathDryRunStatus = Get-DeploymentStatus -Report $backupOwnerPathDryRun
$backupOwnerPathDryRunChecks = Get-DeploymentProp -Object $backupOwnerPathDryRun -Name "checks"
$backupOwnerPathDryRunFailedChecks = @((Get-DeploymentProp -Object $backupOwnerPathDryRun -Name "failedChecks" -Default @()))
$backupOwnerPathDryRunReady = ($backupOwnerPathDryRunStatus -eq "passed") `
    -and ($backupOwnerPathDryRunFailedChecks.Count -eq 0) `
    -and ((Get-DeploymentProp -Object $backupOwnerPathDryRunChecks -Name "childReadinessCommandPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupOwnerPathDryRunChecks -Name "readinessStatusPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupOwnerPathDryRunChecks -Name "snapshotProofPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupOwnerPathDryRunChecks -Name "restoreProofPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupOwnerPathDryRunChecks -Name "retentionCurrentSnapshotProtected" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupOwnerPathDryRunChecks -Name "retentionPruneErrorsEmpty" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupOwnerPathDryRunChecks -Name "backupRetentionProtectedSnapshot" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupOwnerPathDryRunChecks -Name "restoreLiveStateProtected" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupOwnerPathDryRunChecks -Name "restoreDidNotMutateLiveState" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupOwnerPathDryRunChecks -Name "ownerBackupEnvRestored" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupOwnerPathDryRun -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $backupOwnerPathDryRun -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupOwnerPathDryRun -Name "broadcasts" -Default $true) -eq $false) `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:backup:owner-path:dry-run")
Add-DeploymentItem -Items $items -Id "state-backup-owner-path-dry-run" `
    -Requirement "Backup readiness has an owner-path dry run that injects an ignored local backup path into the production backup gate and proves snapshot, retention, and restore evidence without using the owner's real directory." `
    -Status $(if ($backupOwnerPathDryRunReady) { "passed" } else { "failed" }) `
    -Evidence "dryRun=$backupOwnerPathDryRunStatus, failedChecks=$($backupOwnerPathDryRunFailedChecks.Count), readiness=$(Get-DeploymentProp -Object $backupOwnerPathDryRun -Name "childReadinessStatus"), snapshotProof=$(Get-DeploymentProp -Object $backupOwnerPathDryRunChecks -Name "snapshotProofPassed"), retention=$(Get-DeploymentProp -Object $backupOwnerPathDryRunChecks -Name "retentionCurrentSnapshotProtected"), restoreProof=$(Get-DeploymentProp -Object $backupOwnerPathDryRunChecks -Name "restoreProofPassed")" `
    -Commands @("npm run flowchain:backup:owner-path:dry-run")

$backupInstallValidation = $reports.backupInstallValidation
$backupInstallValidationStatus = Get-DeploymentStatus -Report $backupInstallValidation
$backupInstallChecks = Get-DeploymentProp -Object $backupInstallValidation -Name "checks"
$backupInstallReady = ($backupInstallValidationStatus -eq "passed") `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "packageScriptsPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "planCommandPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "planDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "schedulerCmdletsAvailable" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "scheduledTaskActionSupportsWorkingDirectory" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "taskNamesDistinct" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "retentionCountValid" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "actionUsesBackupScript" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "actionUsesRetentionCount" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "restoreDrillUsesRestoreScript" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "restoreDrillHasRestoreRoot" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "restoreDrillHasStatePath" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "restoreDrillHasReportPath" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "ownerBackupEnvRequired" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "restoreDrillOwnerBackupEnvRequired" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "commandOmitsAllowBlocked" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "commandsPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "systemdValidationPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "systemdPlanDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "systemdBackupServiceUnitPlanned" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "systemdBackupTimerUnitPlanned" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "systemdRestoreServiceUnitPlanned" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "systemdRestoreTimerUnitPlanned" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "systemdCommandOmitsAllowBlocked" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "systemdOwnerBackupEnvRequired" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "systemdBackupRootWritePathConfigurable" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "systemdChildReportNoSecrets" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $backupInstallValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:backup:install:windows") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:backup:install:systemd") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:backup:install:systemd:validate") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:backup:install:validate")
Add-DeploymentItem -Items $items -Id "state-backup-schedule-automation" `
    -Requirement "The owner host has no-secret Windows Scheduled Task and Linux systemd install, status, and uninstall paths for recurring manifest-backed state backups, retention rotation, and restore drills that fail closed without the owner backup path." `
    -Status $(if ($backupInstallReady) { "passed" } else { "failed" }) `
    -Evidence "backupInstallValidation=$backupInstallValidationStatus, planDidNotMutate=$(Get-DeploymentProp -Object $backupInstallChecks -Name "planDidNotMutate"), retention=$(Get-DeploymentProp -Object $backupInstallChecks -Name "actionUsesRetentionCount"), restoreDrill=$(Get-DeploymentProp -Object $backupInstallChecks -Name "restoreDrillUsesRestoreScript"), ownerBackupEnvRequired=$(Get-DeploymentProp -Object $backupInstallChecks -Name "ownerBackupEnvRequired"), commandOmitsAllowBlocked=$(Get-DeploymentProp -Object $backupInstallChecks -Name "commandOmitsAllowBlocked"), systemdValidation=$(Get-DeploymentProp -Object $backupInstallChecks -Name "systemdValidationPassed"), systemdTimer=$(Get-DeploymentProp -Object $backupInstallChecks -Name "systemdBackupTimerUnitPlanned")" `
    -Commands @("npm run flowchain:backup:install:validate", "npm run flowchain:backup:install:windows -- -Action Plan", "npm run flowchain:backup:install:windows -- -Action Install", "npm run flowchain:backup:install:windows -- -Action Status", "npm run flowchain:backup:install:windows -- -Action Uninstall", "npm run flowchain:backup:install:systemd -- -Action Plan", "npm run flowchain:backup:install:systemd -- -Action Install", "npm run flowchain:backup:install:systemd -- -Action Status", "npm run flowchain:backup:install:systemd -- -Action Uninstall", "npm run flowchain:backup:install:systemd:validate")

Add-DeploymentItem -Items $items -Id "state-backup" `
    -Requirement "The public deployment must prove the configured state backup directory can create a manifest-backed snapshot and restore it in rehearsal." `
    -Status $(if ($backupStatus -eq "passed" -and $backupRestoreValidationPassed -and $backupOwnerPathDryRunReady) { "passed" } elseif ($backupStatus -eq "blocked" -and $backupRestoreValidationPassed -and $backupOwnerPathDryRunReady) { "blocked" } else { "failed" }) `
    -Evidence "backupStatus=$backupStatus, snapshotProof=$backupSnapshotProof, restoreProof=$backupRestoreProof, ownerPathDryRun=$backupOwnerPathDryRunStatus" `
    -Commands @("npm run flowchain:backup:create", "npm run flowchain:backup:restore:verify", "npm run flowchain:backup:owner-path:dry-run", "npm run flowchain:backup:check") `
    -Blockers @("FLOWCHAIN_RPC_STATE_BACKUP_PATH")

$bridgeLiveStatus = Get-DeploymentStatus -Report $reports.bridgeLive
$bridgeInfraStatus = Get-DeploymentStatus -Report $reports.bridgeInfra
Add-DeploymentItem -Items $items -Id "base8453-bridge-edge" `
    -Requirement "The public deployment must not invite bridge-funded testing until Base 8453 live and infra checks pass with owner guardrails." `
    -Status $(if (($bridgeLiveStatus -eq "passed") -and ($bridgeInfraStatus -eq "passed")) { "passed" } elseif (($bridgeLiveStatus -eq "blocked") -or ($bridgeInfraStatus -eq "blocked")) { "blocked" } else { "failed" }) `
    -Evidence "bridgeLive=$bridgeLiveStatus, bridgeInfra=$bridgeInfraStatus" `
    -Commands @("npm run flowchain:bridge:live:check", "npm run flowchain:bridge:infra:check") `
    -Blockers @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_BASE8453_ASSET_DECIMALS", "FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS")

$bridgeRelayer = $reports.bridgeRelayerOnce
$bridgeRelayerGuardrail = $reports.bridgeRelayerGuardrailValidation
$bridgeRelayerGuardrailStatus = Get-DeploymentStatus -Report $bridgeRelayerGuardrail
$bridgeRelayerGuardrailChecks = Get-DeploymentProp -Object $bridgeRelayerGuardrail -Name "checks"
$bridgeRelayerGuardrailReady = $bridgeRelayerGuardrailStatus -eq "passed" `
    -and ((Get-DeploymentProp -Object $bridgeRelayerGuardrailChecks -Name "finalCursorUnchanged" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerGuardrailChecks -Name "stagedCursorNotWritten" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerGuardrailChecks -Name "noCreditsQueued" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveFailedClosed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveReportWritten" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveStatusBlocked" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveUsesStagedCursorByDefault" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveCursorNotFinal" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveFinalCursorUnchanged" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveStagedCursorNotWritten" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveBroadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveEnvValuesPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveNoSecrets" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerGuardrailChecks -Name "broadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerGuardrailChecks -Name "envValuesPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerGuardrailChecks -Name "noSecrets" -Default $false) -eq $true)
$bridgeRelayerLoopValidation = $reports.bridgeRelayerLoopValidation
$bridgeRelayerLoopStatus = Get-DeploymentStatus -Report $bridgeRelayerLoopValidation
$bridgeRelayerLoopChecks = Get-DeploymentProp -Object $bridgeRelayerLoopValidation -Name "checks"
$bridgeRelayerLoopFailedChecks = @((Get-DeploymentProp -Object $bridgeRelayerLoopValidation -Name "failedChecks" -Default @()))
$bridgeRelayerLoopReady = ($bridgeRelayerLoopStatus -eq "passed") `
    -and ($bridgeRelayerLoopFailedChecks.Count -eq 0) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerLoopChecks -Name "startCommandPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerLoopChecks -Name "relayerLoopRequested" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerLoopChecks -Name "statusReportsRelayerRunning" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerLoopChecks -Name "statusRelayerCommandLineMatched" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerLoopChecks -Name "statusRelayerReportFresh" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerLoopChecks -Name "statusRelayerReportAcceptable" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerLoopChecks -Name "statusRelayerReportBlockedOnlyOnOwnerInputs" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerLoopChecks -Name "statusRelayerReportNoSecrets" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerLoopChecks -Name "statusRelayerReportNoBroadcasts" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerLoopChecks -Name "statusRelayerReportHealthy" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerLoopChecks -Name "stopHandledRelayerLoop" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerLoopChecks -Name "statusAfterStopNotRunning" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerLoopChecks -Name "relayerPidNoLongerMatchesAfterStop" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerLoopChecks -Name "relayerPidFileRemovedAfterStop" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerLoopChecks -Name "stopReportRelayerPidFileRemoved" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerLoopChecks -Name "noValidationRelayerProcessAfterStop" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerLoopValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerLoopValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerLoopValidation -Name "broadcasts" -Default $true) -eq $false)
$bridgeRelayerStatus = Get-DeploymentStatus -Report $bridgeRelayer
$bridgeRelayerChecks = Get-DeploymentProp -Object $bridgeRelayer -Name "checks"
$bridgeRelayerFailedChecks = @((Get-DeploymentProp -Object $bridgeRelayer -Name "failedChecks" -Default @()))
$bridgeRelayerCheckContractReady = ($bridgeRelayerFailedChecks.Count -eq 0) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "statusKnown" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "requiredEnvNamesPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "childTimeoutRecorded" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "childProcessesDidNotTimeout" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "broadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "envValuesPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "readinessInfraChecked" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "readinessLiveCheckedWhenInfraPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "blockedBeforeLiveReadinessWhenInfraBlocked" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "blockedBeforeObservationWhenReadinessBlocked" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "noQueuedTransactionsWhenBlocked" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "noAppliedCreditsWhenBlocked" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "cursorModeStaged" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "finalCursorNotCommittedWhenBlocked" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "finalCursorPathInsideRepo" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "stagedCursorPathInsideRepo" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "issuesClassified" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "externalBlockerClassifiedWhenBlocked" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "latencyGateRecorded" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "latencyGatePassedWhenApplied" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "queueAndApplyMatchWhenPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRelayerChecks -Name "cursorSafeWhenPassed" -Default $false) -eq $true)
$bridgeRelayerCounts = Get-DeploymentProp -Object $bridgeRelayer -Name "counts"
$bridgeRelayerTiming = Get-DeploymentProp -Object $bridgeRelayer -Name "timing"
$bridgeRelayerCursorCommit = Get-DeploymentProp -Object $bridgeRelayer -Name "cursorCommit"
$bridgeRelayerNewCount = [int](Get-DeploymentProp -Object $bridgeRelayerCounts -Name "newCredits" -Default 0)
$bridgeRelayerQueuedCount = [int](Get-DeploymentProp -Object $bridgeRelayerCounts -Name "queuedTransactions" -Default 0)
$bridgeRelayerAppliedCount = [int](Get-DeploymentProp -Object $bridgeRelayerCounts -Name "appliedCredits" -Default 0)
$bridgeRelayerLatencyGate = Get-DeploymentProp -Object $bridgeRelayerTiming -Name "latencyGate" -Default "missing"
$bridgeRelayerLatencyReady = $bridgeRelayerAppliedCount -eq 0 -or $bridgeRelayerLatencyGate -eq "passed"
$bridgeRelayerQueueDisabled = Get-DeploymentProp -Object $bridgeRelayer -Name "queueDisabled" -Default $true
$bridgeRelayerCursorCommitRequired = Get-DeploymentProp -Object $bridgeRelayerCursorCommit -Name "finalCommitRequired" -Default $true
$bridgeRelayerCursorCommitted = Get-DeploymentProp -Object $bridgeRelayerCursorCommit -Name "finalCommitted" -Default $false
$bridgeRelayerCursorReason = Get-DeploymentProp -Object $bridgeRelayerCursorCommit -Name "reason" -Default "missing"
$bridgeRelayerQueueReady = ($bridgeRelayerNewCount -eq 0) -or (($bridgeRelayerQueueDisabled -eq $false) -and ($bridgeRelayerQueuedCount -ge $bridgeRelayerNewCount) -and ($bridgeRelayerAppliedCount -eq $bridgeRelayerNewCount))
$bridgeRelayerCursorReady = ($bridgeRelayerStatus -ne "passed") -or ($bridgeRelayerCursorCommitted -eq $true) -or ($bridgeRelayerCursorCommitRequired -eq $false)
$bridgeRelayerReady = ($bridgeRelayerStatus -eq "passed") `
    -and $bridgeRelayerCheckContractReady `
    -and ((Get-DeploymentProp -Object $bridgeRelayer -Name "broadcasts" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $bridgeRelayer -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $bridgeRelayer -Name "noSecrets" -Default $false) -eq $true) `
    -and $bridgeRelayerLatencyReady `
    -and $bridgeRelayerQueueReady `
    -and $bridgeRelayerCursorReady `
    -and $bridgeRelayerGuardrailReady `
    -and $bridgeRelayerLoopReady `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:bridge:relayer:once") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:bridge:relayer:guardrail:validate") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:bridge:relayer:loop:validate")
$bridgeRelayerBlockedSafely = ($bridgeRelayerStatus -eq "blocked") -and $bridgeRelayerCheckContractReady -and $bridgeRelayerGuardrailReady -and $bridgeRelayerLoopReady
Add-DeploymentItem -Items $items -Id "base8453-bridge-relayer-queue" `
    -Requirement "The bridge relayer has a no-broadcast one-shot path plus an isolated loop validation that checks owner guardrails, proves fresh no-secret/no-broadcast loop health, observes Base 8453 deposits with a staged cursor, filters replays, queues new credits into the running L1, waits for main-state credit evidence, records handoff-to-spendable latency, only commits the Base cursor after safe proof, and proves missing-owner-input runs plus standalone observation leave final cursor state untouched." `
    -Status $(if ($bridgeRelayerReady) { "passed" } elseif ($bridgeRelayerBlockedSafely) { "blocked" } else { "failed" }) `
    -Evidence "relayer=$bridgeRelayerStatus, onceChecksReady=$bridgeRelayerCheckContractReady, onceFailedChecks=$($bridgeRelayerFailedChecks.Count), guardrail=$bridgeRelayerGuardrailStatus, directObserveStagedDefault=$(Get-DeploymentProp -Object $bridgeRelayerGuardrailChecks -Name 'directObserveUsesStagedCursorByDefault' -Default $false), directObserveCursorNotFinal=$(Get-DeploymentProp -Object $bridgeRelayerGuardrailChecks -Name 'directObserveCursorNotFinal' -Default $false), loopValidation=$bridgeRelayerLoopStatus, loopFailedChecks=$($bridgeRelayerLoopFailedChecks.Count), loopReportHealthy=$(Get-DeploymentProp -Object $bridgeRelayerLoopChecks -Name 'statusRelayerReportHealthy' -Default $false), observed=$(Get-DeploymentProp -Object $bridgeRelayerCounts -Name 'observedCredits' -Default 0), new=$bridgeRelayerNewCount, queued=$bridgeRelayerQueuedCount, applied=$bridgeRelayerAppliedCount, latencyGate=$bridgeRelayerLatencyGate, cursorCommitRequired=$bridgeRelayerCursorCommitRequired, cursorCommitted=$bridgeRelayerCursorCommitted, cursorReason=$bridgeRelayerCursorReason, handoffToSpendableSeconds=$(Get-DeploymentProp -Object $bridgeRelayerTiming -Name 'handoffToSpendableSeconds')" `
    -Commands @("npm run flowchain:bridge:relayer:once", "npm run flowchain:bridge:relayer:guardrail:validate", "npm run flowchain:bridge:relayer:loop:validate") `
    -Blockers @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_BASE8453_ASSET_DECIMALS", "FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS")

$bridgeReconciliationScheduleValidation = $reports.bridgeReconciliationScheduleValidation
$bridgeReconciliationScheduleStatus = Get-DeploymentStatus -Report $bridgeReconciliationScheduleValidation
$bridgeReconciliationScheduleChecks = Get-DeploymentProp -Object $bridgeReconciliationScheduleValidation -Name "checks"
$bridgeReconciliationScheduleFailedChecks = @((Get-DeploymentProp -Object $bridgeReconciliationScheduleValidation -Name "failedChecks" -Default @()))
$bridgeReconciliationScheduleReady = ($bridgeReconciliationScheduleStatus -eq "passed") `
    -and ($bridgeReconciliationScheduleFailedChecks.Count -eq 0) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "packageScriptPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "reconciliationPackageScriptPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "reconciliationScriptReadsRelayerEvidence" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "reconciliationScriptReadsRuntimeEvidence" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "windowsPlanUsesReconciliationScript" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "windowsPlanUsesOwnerEnvFile" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "windowsPlanHasReportPath" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "windowsPlanHasMarkdownPath" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "windowsPlanDoesNotMutateHost" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "systemdServiceRendered" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "systemdServiceUsesOwnerEnvFile" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "systemdServiceHasReportPath" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "systemdServiceHasMarkdownPath" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "systemdServiceHardeningPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "systemdTimerRendered" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "systemdTimerPersistent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "systemdTimerIntervalConfigured" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "noExternalDelivery" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "hostMutationPerformedFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleValidation -Name "hostMutationPerformed" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeReconciliationScheduleValidation -Name "broadcasts" -Default $true) -eq $false) `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:bridge:reconciliation:schedule:validate")
Add-DeploymentItem -Items $items -Id "base8453-bridge-reconciliation-schedule-automation" `
    -Requirement "The owner host has no-secret Windows Scheduled Task and Linux systemd timer plans for recurring bridge reconciliation checks without host mutation or external delivery credentials." `
    -Status $(if ($bridgeReconciliationScheduleReady) { "passed" } else { "failed" }) `
    -Evidence "reconciliationSchedule=$bridgeReconciliationScheduleStatus, windowsPlan=$(Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "windowsPlanUsesReconciliationScript"), systemdTimer=$(Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "systemdTimerRendered"), ownerEnv=$(Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "systemdServiceUsesOwnerEnvFile"), noMutation=$(Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "hostMutationPerformedFalse"), noExternalDelivery=$(Get-DeploymentProp -Object $bridgeReconciliationScheduleChecks -Name "noExternalDelivery")" `
    -Commands @("npm run flowchain:bridge:reconciliation:schedule:validate", "npm run flowchain:bridge:reconciliation")

$bridgeRuntimeCreditValidation = $reports.bridgeRuntimeCreditValidation
$bridgeRuntimeCreditStatus = Get-DeploymentStatus -Report $bridgeRuntimeCreditValidation
$bridgeRuntimeCreditChecks = Get-DeploymentProp -Object $bridgeRuntimeCreditValidation -Name "checks"
$bridgeRuntimeCreditTiming = Get-DeploymentProp -Object $bridgeRuntimeCreditValidation -Name "timing"
$bridgeRuntimeCreditFailedChecks = @((Get-DeploymentProp -Object $bridgeRuntimeCreditValidation -Name "failedChecks" -Default @()))
$bridgeRuntimeCreditMissingRuntimeChecks = @((Get-DeploymentProp -Object $bridgeRuntimeCreditValidation -Name "missingRuntimeChecks" -Default @()))
$bridgeRuntimeCreditFalseRuntimeChecks = @((Get-DeploymentProp -Object $bridgeRuntimeCreditValidation -Name "falseRuntimeChecks" -Default @()))
$bridgeRuntimeCreditProofFailedChecks = @((Get-DeploymentProp -Object $bridgeRuntimeCreditValidation -Name "proofFailedChecks" -Default @()))
$bridgeRuntimeCreditReady = ($bridgeRuntimeCreditStatus -eq "passed") `
    -and ($bridgeRuntimeCreditFailedChecks.Count -eq 0) `
    -and ($bridgeRuntimeCreditMissingRuntimeChecks.Count -eq 0) `
    -and ($bridgeRuntimeCreditFalseRuntimeChecks.Count -eq 0) `
    -and ($bridgeRuntimeCreditProofFailedChecks.Count -eq 0) `
    -and ((Get-DeploymentProp -Object $bridgeRuntimeCreditChecks -Name "requiredRuntimeChecksCovered" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRuntimeCreditChecks -Name "requiredRuntimeChecksPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRuntimeCreditChecks -Name "sourceChainBase8453" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRuntimeCreditChecks -Name "creditAppliedOnce" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRuntimeCreditChecks -Name "creditedBalanceTransferable" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRuntimeCreditChecks -Name "replayRejected" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRuntimeCreditChecks -Name "restartPreservesCreditHistory" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRuntimeCreditChecks -Name "exportImportPreservesReplayProtection" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRuntimeCreditChecks -Name "latencyGatePassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRuntimeCreditChecks -Name "transferLatencyUnderTarget" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRuntimeCreditChecks -Name "proofBroadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRuntimeCreditChecks -Name "handoffNoReleaseBroadcast" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRuntimeCreditChecks -Name "handoffNoWithdrawalBroadcast" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRuntimeCreditValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $bridgeRuntimeCreditValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $bridgeRuntimeCreditValidation -Name "broadcasts" -Default $true) -eq $false) `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:bridge:runtime-credit:validate")
Add-DeploymentItem -Items $items -Id "base8453-bridge-runtime-credit-proof" `
    -Requirement "The deployment has a local production-shaped proof that a Base 8453 bridge handoff becomes spendable on L1 within the settlement target, can be spent by the credited wallet, rejects replay, and survives restart/export/import without live broadcasts." `
    -Status $(if ($bridgeRuntimeCreditReady) { "passed" } else { "failed" }) `
    -Evidence "runtimeCredit=$bridgeRuntimeCreditStatus, failedChecks=$($bridgeRuntimeCreditFailedChecks.Count), missingRuntimeChecks=$($bridgeRuntimeCreditMissingRuntimeChecks.Count), falseRuntimeChecks=$($bridgeRuntimeCreditFalseRuntimeChecks.Count), latencyGate=$(Get-DeploymentProp -Object $bridgeRuntimeCreditTiming -Name 'latencyGate' -Default 'missing'), queueToSpendableSeconds=$(Get-DeploymentProp -Object $bridgeRuntimeCreditTiming -Name 'queueToSpendableSeconds' -Default ''), transferSeconds=$(Get-DeploymentProp -Object $bridgeRuntimeCreditTiming -Name 'transferSettlementSeconds' -Default '')" `
    -Commands @("npm run flowchain:bridge:runtime-credit:validate")

$bridgeReleaseEvidenceValidation = $reports.bridgeReleaseEvidenceValidation
$bridgeReleaseEvidenceStatus = Get-DeploymentStatus -Report $bridgeReleaseEvidenceValidation
$bridgeReleaseEvidenceChecks = Get-DeploymentProp -Object $bridgeReleaseEvidenceValidation -Name "checks"
$bridgeReleaseEvidenceFailedChecks = @((Get-DeploymentProp -Object $bridgeReleaseEvidenceValidation -Name "failedChecks" -Default @()))
$bridgeReleaseEvidenceFailedCases = @((Get-DeploymentProp -Object $bridgeReleaseEvidenceValidation -Name "failedCases" -Default @()))
$bridgeReleaseEvidenceMissingCases = @((Get-DeploymentProp -Object $bridgeReleaseEvidenceValidation -Name "missingRequiredCases" -Default @()))
$bridgeReleaseEvidenceSecretFindings = @((Get-DeploymentProp -Object $bridgeReleaseEvidenceValidation -Name "secretMarkerFindings" -Default @()))
$bridgeReleaseEvidenceCaseCount = [int](Get-DeploymentProp -Object $bridgeReleaseEvidenceValidation -Name "caseCount" -Default 0)
$bridgeReleaseEvidenceRequiredChecks = @(
    "releaseEvidenceScriptExists",
    "matchingEvidencePasses",
    "missingInputsBlock",
    "amountMismatchFails",
    "methodMismatchFails",
    "tokenMismatchFails",
    "recipientMismatchFails",
    "chainMismatchFails",
    "assetMismatchFails",
    "releaseBroadcastRejected",
    "withdrawalBroadcastRejected",
    "releaseProductionReadyFalseRejected",
    "releaseLocalOnlyTrueRejected",
    "allRequiredCasesCovered",
    "failedCasesAbsent",
    "noSecretScanPassed",
    "broadcastsFalse",
    "envValuesPrintedFalse",
    "noSecrets",
    "secretMarkerFindingsEmpty"
)
$bridgeReleaseEvidenceMissingChecks = @($bridgeReleaseEvidenceRequiredChecks | Where-Object {
        (Get-DeploymentProp -Object $bridgeReleaseEvidenceChecks -Name $_ -Default $false) -ne $true
    })
$bridgeReleaseEvidenceReady = ($bridgeReleaseEvidenceStatus -eq "passed") `
    -and ($bridgeReleaseEvidenceCaseCount -ge 12) `
    -and ($bridgeReleaseEvidenceFailedChecks.Count -eq 0) `
    -and ($bridgeReleaseEvidenceFailedCases.Count -eq 0) `
    -and ($bridgeReleaseEvidenceMissingCases.Count -eq 0) `
    -and ($bridgeReleaseEvidenceMissingChecks.Count -eq 0) `
    -and ($bridgeReleaseEvidenceSecretFindings.Count -eq 0) `
    -and ((Get-DeploymentProp -Object $bridgeReleaseEvidenceValidation -Name "broadcasts" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $bridgeReleaseEvidenceValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $bridgeReleaseEvidenceValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:bridge:release:evidence:validate")
Add-DeploymentItem -Items $items -Id "base8453-bridge-release-evidence-validation" `
    -Requirement "Bridge withdrawal/release evidence must prove the Base 8453 release method, amount, token, recipient, source chain, destination asset, production-ready flag, local-only boundary, and no-broadcast/no-secret constraints before bridge-funded tester launch." `
    -Status $(if ($bridgeReleaseEvidenceReady) { "passed" } else { "failed" }) `
    -Evidence "releaseEvidence=$bridgeReleaseEvidenceStatus, cases=$bridgeReleaseEvidenceCaseCount, failedChecks=$($bridgeReleaseEvidenceFailedChecks.Count), missingChecks=$($bridgeReleaseEvidenceMissingChecks.Count), failedCases=$($bridgeReleaseEvidenceFailedCases.Count), missingCases=$($bridgeReleaseEvidenceMissingCases.Count), secretFindings=$($bridgeReleaseEvidenceSecretFindings.Count), broadcasts=$(Get-DeploymentProp -Object $bridgeReleaseEvidenceValidation -Name 'broadcasts' -Default 'missing'), noSecrets=$(Get-DeploymentProp -Object $bridgeReleaseEvidenceValidation -Name 'noSecrets' -Default 'missing')" `
    -Commands @("npm run flowchain:bridge:release:evidence:validate")

$externalTester = $reports.externalTester
$externalPacket = $reports.externalTesterPacket
$externalTesterStatus = Get-DeploymentStatus -Report $externalTester
$externalPacketStatus = Get-DeploymentStatus -Report $externalPacket
$externalSharingReady = Get-DeploymentProp -Object $externalTester -Name "externalSharingReady" -Default $false
$externalTesterChecks = Get-DeploymentProp -Object $externalTester -Name "checks"
$externalTesterNetworkFresh = Get-DeploymentProp -Object $externalTesterChecks -Name "testerWalletNetworkFresh" -Default $false
$externalTesterPublicGatewayReady = Get-DeploymentProp -Object $externalTesterChecks -Name "publicTesterGatewayReady" -Default $false
$externalTesterFaucetRouteValidated = Get-DeploymentProp -Object $externalTesterChecks -Name "publicTesterGatewayFaucetRouteValidated" -Default $false
$packetExecutableSmokeValidated = Get-DeploymentProp -Object $externalPacket -Name "packetExecutableSmokeValidated" -Default $false
$packetSmokeChecks = Get-DeploymentProp -Object $externalPacket -Name "packetSmokeChecks"
$packetTesterFaucet = Get-DeploymentProp -Object $packetSmokeChecks -Name "testerFaucet" -Default $false
$packetTesterCapRejected = Get-DeploymentProp -Object $packetSmokeChecks -Name "testerCapRejected" -Default $false
$localTesterRehearsalReady = Get-DeploymentProp -Object $externalTester -Name "localTesterRehearsalReady" -Default $false
$packetShareable = Get-DeploymentProp -Object $externalPacket -Name "packetShareable" -Default $false
$connectPackShareable = Get-DeploymentProp -Object $externalPacket -Name "connectPackShareable" -Default $false
$connectPackChecks = Get-DeploymentProp -Object $externalPacket -Name "connectPackChecks"
$connectPackReady = ((Get-DeploymentProp -Object $connectPackChecks -Name "connectPackWritten" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $connectPackChecks -Name "connectPackSchemaValid" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $connectPackChecks -Name "connectPackHasNetworkProfile" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $connectPackChecks -Name "connectPackHasRpcPlaceholder" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $connectPackChecks -Name "connectPackHasTesterTokenPlaceholder" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $connectPackChecks -Name "connectPackHasReadOnlyRoutes" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $connectPackChecks -Name "connectPackHasTesterWriteRoutes" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $connectPackChecks -Name "connectPackShareableMatchesPacket" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $connectPackChecks -Name "connectPackNoConcreteUrl" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $connectPackChecks -Name "connectPackNoSecrets" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $connectPackChecks -Name "connectPackBroadcastsFalse" -Default $false) -eq $true) `
    -and ($connectPackShareable -eq $packetShareable)
Add-DeploymentItem -Items $items -Id "external-tester-sharing" `
    -Requirement "External tester packet and machine-readable connection pack must remain not-shareable until owner public RPC, backup, and bridge gates pass, and they must rely on fresh tester-wallet evidence plus authenticated tester faucet/send gateway smoke." `
    -Status $(if (($externalTesterStatus -eq "passed") -and ($externalPacketStatus -eq "passed") -and ($externalSharingReady -eq $true) -and ($packetShareable -eq $true) -and ($externalTesterNetworkFresh -eq $true) -and ($externalTesterPublicGatewayReady -eq $true) -and ($externalTesterFaucetRouteValidated -eq $true) -and ($packetExecutableSmokeValidated -eq $true) -and ($packetTesterFaucet -eq $true) -and ($packetTesterCapRejected -eq $true) -and ($connectPackReady -eq $true) -and ($bridgeReleaseEvidenceReady -eq $true)) { "passed" } elseif (($externalTesterStatus -eq "blocked") -and ($externalPacketStatus -eq "blocked") -and ($externalSharingReady -eq $false) -and ($packetShareable -eq $false) -and ($externalTesterNetworkFresh -eq $true) -and ($externalTesterPublicGatewayReady -eq $true) -and ($externalTesterFaucetRouteValidated -eq $true) -and ($packetExecutableSmokeValidated -eq $true) -and ($packetTesterFaucet -eq $true) -and ($packetTesterCapRejected -eq $true) -and ($connectPackReady -eq $true) -and ($bridgeReleaseEvidenceReady -eq $true)) { "blocked" } else { "failed" }) `
    -Evidence "externalTester=$externalTesterStatus, localTesterRehearsalReady=$localTesterRehearsalReady, testerNetworkFresh=$externalTesterNetworkFresh, publicTesterGatewayReady=$externalTesterPublicGatewayReady, faucetRoute=$externalTesterFaucetRouteValidated, packetSmoke=$packetExecutableSmokeValidated, testerFaucet=$packetTesterFaucet, capRejected=$packetTesterCapRejected, connectPackReady=$connectPackReady, bridgeReleaseEvidenceReady=$bridgeReleaseEvidenceReady, externalSharingReady=$externalSharingReady, packet=$externalPacketStatus, packetShareable=$packetShareable" `
    -Commands @("npm run flowchain:tester:readiness", "npm run flowchain:external-tester:packet") `
    -Blockers @($ownerMissingInputs)

$testerWriteTokenSetup = $reports.testerWriteTokenSetup
$testerWriteTokenSetupStatus = Get-DeploymentStatus -Report $testerWriteTokenSetup
$testerWriteTokenSetupChecks = Get-DeploymentProp -Object $testerWriteTokenSetup -Name "checks"
$testerWriteTokenSetupReady = ($testerWriteTokenSetupStatus -eq "passed") `
    -and ((Get-DeploymentProp -Object $testerWriteTokenSetupChecks -Name "tokenPathGitIgnored" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $testerWriteTokenSetupChecks -Name "ownerEnvPathGitIgnored" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $testerWriteTokenSetupChecks -Name "tokenFileExists" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $testerWriteTokenSetupChecks -Name "ownerEnvFileExists" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $testerWriteTokenSetupChecks -Name "ownerEnvTesterHashWritten" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $testerWriteTokenSetupChecks -Name "ownerEnvTesterCapWritten" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $testerWriteTokenSetupChecks -Name "rawTokenPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $testerWriteTokenSetupChecks -Name "tokenHashPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $testerWriteTokenSetup -Name "rawTokenPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $testerWriteTokenSetup -Name "tokenHashPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $testerWriteTokenSetup -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $testerWriteTokenSetup -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $testerWriteTokenSetup -Name "broadcasts" -Default $true) -eq $false) `
    -and (@((Get-DeploymentProp -Object $testerWriteTokenSetup -Name "failedChecks" -Default @())).Count -eq 0) `
    -and (@((Get-DeploymentProp -Object $testerWriteTokenSetup -Name "secretMarkerFindings" -Default @())).Count -eq 0)
Add-DeploymentItem -Items $items -Id "tester-write-token-setup" `
    -Requirement "Friends-and-family tester writes have a no-secret setup proof: the raw bearer token stays in ignored local storage, only its SHA-256 digest and send cap enter the ignored owner env file, and committed evidence prints neither token nor digest." `
    -Status $(if ($testerWriteTokenSetupReady) { "passed" } else { "failed" }) `
    -Evidence "tokenSetupStatus=$testerWriteTokenSetupStatus, tokenPath=$(Get-DeploymentProp -Object $testerWriteTokenSetup -Name "tokenPath"), ownerEnvFile=$(Get-DeploymentProp -Object $testerWriteTokenSetup -Name "ownerEnvFile"), tokenCreated=$(Get-DeploymentProp -Object $testerWriteTokenSetup -Name "tokenCreated"), tokenPreserved=$(Get-DeploymentProp -Object $testerWriteTokenSetup -Name "tokenPreserved")" `
    -Commands @("npm run flowchain:tester:token:setup")

$publicTesterGateway = $reports.publicTesterGateway
$publicTesterGatewayStatus = Get-DeploymentStatus -Report $publicTesterGateway
$publicTesterGatewayReady = ($publicTesterGatewayStatus -eq "passed") `
    -and ((Get-DeploymentProp -Object $publicTesterGateway -Name "testerGatewayConfigured" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicTesterGateway -Name "testerFaucetSchema" -Default "") -eq "flowmemory.control_plane.tester_faucet_result.v0") `
    -and ((Get-DeploymentProp -Object $publicTesterGateway -Name "transferAccepted" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicTesterGateway -Name "capRejected" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicTesterGateway -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $publicTesterGateway -Name "noSecrets" -Default $false) -eq $true) `
    -and (Test-DeploymentRoutePresent -Routes (Get-DeploymentProp -Object $publicTesterGateway -Name "routes" -Default @()) -Route "/tester/faucet")
Add-DeploymentItem -Items $items -Id "public-tester-write-gateway" `
    -Requirement "The public deployment has a local production-shaped proof for authenticated tester wallet creation, capped tester faucet funding, capped tester sends, balance settlement, and over-cap rejection." `
    -Status $(if ($publicTesterGatewayReady) { "passed" } else { "failed" }) `
    -Evidence "gatewayStatus=$publicTesterGatewayStatus, testerFaucetSchema=$(Get-DeploymentProp -Object $publicTesterGateway -Name "testerFaucetSchema"), transferAccepted=$(Get-DeploymentProp -Object $publicTesterGateway -Name "transferAccepted"), capRejected=$(Get-DeploymentProp -Object $publicTesterGateway -Name "capRejected")" `
    -Commands @("npm run flowchain:tester:gateway:e2e")

$requiredRollbackScripts = @(
    "flowchain:service:status",
    "flowchain:ops:snapshot",
    "flowchain:service:stop",
    "flowchain:service:restart",
    "flowchain:emergency:stop-local",
    "flowchain:completion:audit",
    "flowchain:public-deployment:contract"
)
$missingRollbackScripts = @($requiredRollbackScripts | Where-Object { -not (Test-DeploymentPackageScript -PackageJson $packageJson -Name $_) })
$rollbackReady = ($missingRollbackScripts.Count -eq 0) `
    -and (Test-Path -LiteralPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-service-stop.ps1")) `
    -and (Test-Path -LiteralPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-emergency-stop-local.ps1"))
Add-DeploymentItem -Items $items -Id "rollback-controls" `
    -Requirement "Owner deployment has explicit status, stop, restart, emergency stop, and re-audit commands before exposure." `
    -Status $(if ($rollbackReady) { "passed" } else { "failed" }) `
    -Evidence "missingRollbackScripts=$($missingRollbackScripts.Count)" `
    -Commands @($requiredRollbackScripts | ForEach-Object { "npm run $_" })

$noSecret = $reports.noSecret
$noSecretStatus = Get-DeploymentStatus -Report $noSecret
$noSecretChecks = Get-DeploymentProp -Object $noSecret -Name "checks"
$noSecretCoverageReady = ((Get-DeploymentProp -Object $noSecretChecks -Name "scansDashboardPublicData" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $noSecretChecks -Name "scansGeneratedLiveProductReports" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $noSecretChecks -Name "reportPathMatchesProductionGate" -Default $false) -eq $true)
Add-DeploymentItem -Items $items -Id "no-secret-no-broadcast" `
    -Requirement "Deployment contract and current readiness reports preserve no-secret, no-env-value, and no-live-broadcast boundaries." `
    -Status $(if ($noSecretStatus -eq "passed" -and $noSecretCoverageReady) { "passed" } else { "failed" }) `
    -Evidence "noSecretStatus=$noSecretStatus, scansGeneratedReports=$(Get-DeploymentProp -Object $noSecretChecks -Name "scansGeneratedLiveProductReports"), reportPathMatchesProductionGate=$(Get-DeploymentProp -Object $noSecretChecks -Name "reportPathMatchesProductionGate")" `
    -Commands @("npm run flowchain:no-secret:scan")

$failedItems = @($items | Where-Object { $_.status -eq "failed" })
$blockedItems = @($items | Where-Object { $_.status -eq "blocked" })
$blockedItemsWithoutBlockers = @($blockedItems | Where-Object { @($_.blockers).Count -eq 0 })
$blockedItemsWithUnknownBlockers = @($blockedItems | Where-Object {
    $itemBlockers = @($_.blockers)
    @($itemBlockers | Where-Object { $_ -notin $knownOwnerInputs }).Count -gt 0
})
$blockedOnlyOnKnownOwnerInputs = ($failedItems.Count -eq 0) `
    -and ($blockedItemsWithoutBlockers.Count -eq 0) `
    -and ($blockedItemsWithUnknownBlockers.Count -eq 0) `
    -and ($unknownMissingEnvNames.Count -eq 0)
$status = if ($failedItems.Count -gt 0) { "failed" } elseif ($blockedItems.Count -gt 0) { "blocked" } else { "passed" }

$operatorCommands = [ordered]@{
    preExposure = @(
        "npm run flowchain:service:status",
        "npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30",
        "npm run flowchain:service:install:validate",
        "npm run flowchain:service:install:windows -- -Action Plan",
        "npm run flowchain:service:install:systemd:validate",
        "npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>",
        "npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -StartBridgeRelayerLoop",
        "npm run flowchain:ops:snapshot -- -AllowBlocked",
        "npm run flowchain:ops:alerts -- -AllowBlocked",
        "npm run flowchain:ops:metrics:export -- -AllowBlocked",
        "npm run flowchain:ops:alerts:install:validate",
        "npm run flowchain:ops:metrics:install:validate",
        "npm run flowchain:ops:escalation:dry-run -- -AllowBlocked",
        "npm run flowchain:ops:alerts:install:windows -- -Action Plan",
        "npm run flowchain:ops:alerts:install:systemd -- -Action Plan",
        "npm run flowchain:ops:metrics:install:windows -- -Action Plan",
        "npm run flowchain:ops:metrics:install:systemd -- -Action Plan",
        "npm run flowchain:owner:onboarding",
        "npm run flowchain:owner-env:template",
        "npm run flowchain:owner-inputs",
        "npm run flowchain:public-rpc:edge-template",
        "npm run flowchain:public-rpc:deployment-bundle",
        "npm run flowchain:public-rpc:validate",
        "npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked",
        "npm run flowchain:public-rpc:abuse-test",
        "npm run flowchain:tester:gateway:e2e",
        "npm run flowchain:wallet:live-tester:e2e",
        "npm run flowchain:public-rpc:check",
        "npm run flowchain:backup:restore:validate",
        "npm run flowchain:backup:install:validate",
        "npm run flowchain:backup:install:windows -- -Action Plan",
        "npm run flowchain:backup:install:systemd -- -Action Plan",
        "npm run flowchain:backup:install:systemd:validate",
        "npm run flowchain:backup:owner-path:dry-run",
        "npm run flowchain:backup:create",
        "npm run flowchain:backup:restore:verify",
        "npm run flowchain:backup:check",
        "npm run flowchain:bridge:live:check",
                                                 "npm run flowchain:bridge:infra:check",
                                                 "npm run flowchain:bridge:relayer:once",
                                                 "npm run flowchain:bridge:runtime-credit:validate",
                                                 "npm run flowchain:bridge:release:evidence:validate",
                                                 "npm run flowchain:tester:readiness",
        "npm run flowchain:external-tester:packet",
        "npm run flowchain:live:cutover:rehearsal -- -AllowBlocked",
        "npm run flowchain:truth-table -- -AllowBlocked",
        "npm run flowchain:no-secret:scan",
        "npm run flowchain:completion:audit"
    )
    rollback = @(
        "npm run flowchain:service:status",
        "npm run flowchain:service:install:windows -- -Action Status",
        "npm run flowchain:service:install:windows -- -Action Uninstall",
        "npm run flowchain:service:install:systemd -- -Action Status",
        "npm run flowchain:service:install:systemd -- -Action Uninstall",
        "npm run flowchain:backup:install:windows -- -Action Status",
        "npm run flowchain:backup:install:windows -- -Action Uninstall",
        "npm run flowchain:backup:install:systemd -- -Action Status",
        "npm run flowchain:backup:install:systemd -- -Action Uninstall",
        "npm run flowchain:ops:alerts:install:windows -- -Action Status",
        "npm run flowchain:ops:alerts:install:windows -- -Action Uninstall",
        "npm run flowchain:ops:alerts:install:systemd -- -Action Status",
        "npm run flowchain:ops:alerts:install:systemd -- -Action Uninstall",
        "npm run flowchain:ops:metrics:install:windows -- -Action Status",
        "npm run flowchain:ops:metrics:install:windows -- -Action Uninstall",
        "npm run flowchain:ops:metrics:install:systemd -- -Action Status",
        "npm run flowchain:ops:metrics:install:systemd -- -Action Uninstall",
        "npm run flowchain:service:stop",
        "npm run flowchain:service:restart -- -LiveProfile",
        "npm run flowchain:emergency:stop-local"
    )
}

$report = [ordered]@{
    schema = "flowchain.public_deployment_contract_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    deploymentReady = $status -eq "passed"
    packetShareable = $packetShareable
    packetExecutableSmokeValidated = $packetExecutableSmokeValidated
    connectPackShareable = $connectPackShareable
    connectPackReady = $connectPackReady
    blockedOnlyOnKnownExternalOwnerInputs = $blockedOnlyOnKnownOwnerInputs
    itemCounts = [ordered]@{
        passed = @($items | Where-Object { $_.status -eq "passed" }).Count
        blocked = $blockedItems.Count
        failed = $failedItems.Count
        total = $items.Count
    }
    items = @($items)
    dependencyRefresh = $dependencyRefresh
    missingEnvNames = @($missingEnvNames)
    unknownMissingEnvNames = @($unknownMissingEnvNames)
    knownOwnerInputs = $knownOwnerInputs
    reportPaths = $paths
    operatorCommands = $operatorCommands
    noLiveBroadcast = $true
    envValuesPrinted = $false
    noSecrets = $true
}

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Public Deployment Contract")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Deployment ready: $($report.deploymentReady)")
$markdownLines.Add("Packet shareable: $packetShareable")
$markdownLines.Add("Connect pack ready: $connectPackReady")
$markdownLines.Add("Blocked only on known external owner inputs: $blockedOnlyOnKnownOwnerInputs")
$markdownLines.Add("")
$markdownLines.Add("This file records deployment gates, commands, and env names only. It must not contain owner-provided values.")
$markdownLines.Add("")
$markdownLines.Add("## Dependency Refresh")
$markdownLines.Add("")
$markdownLines.Add("- Performed: $($dependencyRefresh.performed)")
$markdownLines.Add("- Delegated to caller: $($dependencyRefresh.delegatedToCaller)")
$markdownLines.Add("- Failure policy: $($dependencyRefresh.failurePolicy)")
$markdownLines.Add("- Aborted: $($dependencyRefresh.aborted)")
$markdownLines.Add("- Child timeout seconds: $ChildTimeoutSeconds")
$markdownLines.Add("- Completed steps: $($dependencyRefresh.completedStepCount)")
$markdownLines.Add("- Failed steps: $($dependencyRefreshFailedSteps.Count)")
$markdownLines.Add("- Timed out steps: $($dependencyRefreshTimedOutSteps.Count)")
$markdownLines.Add("- Skipped steps: $($dependencyRefreshSkippedSteps.Count)")
$markdownLines.Add("- Total child duration seconds: $dependencyRefreshTotalDurationSeconds")
if ($dependencyRefresh.aborted) {
    $markdownLines.Add("- Abort step: $($dependencyRefresh.abortStepName)")
    $markdownLines.Add("- Abort reason: $($dependencyRefresh.abortReason)")
}
if ($dependencyRefreshFailedSteps.Count -gt 0) {
    foreach ($step in @($dependencyRefreshFailedSteps)) {
        $markdownLines.Add("- Failed: $($step.name) exit=$($step.exitCode)")
    }
}
if ($dependencyRefreshTimedOutSteps.Count -gt 0) {
    foreach ($step in @($dependencyRefreshTimedOutSteps)) {
        $markdownLines.Add("- Timed out: $($step.name)")
    }
}
if ($dependencyRefreshSkippedSteps.Count -gt 0) {
    foreach ($step in @($dependencyRefreshSkippedSteps)) {
        $markdownLines.Add("- Skipped: $($step.name)")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Gate Checklist")
$markdownLines.Add("")
$markdownLines.Add("| Requirement | Status | Evidence |")
$markdownLines.Add("| --- | --- | --- |")
foreach ($item in $items) {
    $markdownLines.Add("| $($item.requirement.Replace('|','/')) | $($item.status) | $($item.evidence.Replace('|','/')) |")
}
$markdownLines.Add("")
$markdownLines.Add("## Pre-Exposure Commands")
$markdownLines.Add("")
foreach ($command in @($operatorCommands.preExposure)) {
    $markdownLines.Add("- $command")
}
$markdownLines.Add("")
$markdownLines.Add("## Rollback Commands")
$markdownLines.Add("")
foreach ($command in @($operatorCommands.rollback)) {
    $markdownLines.Add("- $command")
}
$markdownLines.Add("")
$markdownLines.Add("## Remaining Owner Inputs")
$markdownLines.Add("")
if ($missingEnvNames.Count -eq 0) {
    $markdownLines.Add("- None")
}
else {
    foreach ($name in @($missingEnvNames)) {
        $markdownLines.Add("- $name")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Deployment Decision")
$markdownLines.Add("")
if ($status -eq "passed") {
    $markdownLines.Add("All public deployment contract gates are passed. External sharing still requires the owner to distribute endpoint values out of band.")
}
elseif ($status -eq "blocked") {
    $markdownLines.Add("Do not expose or share the public endpoint yet. The deployment contract is fail-closed on the listed owner inputs.")
}
else {
    $markdownLines.Add("Do not expose or share the public endpoint. At least one local deployment contract gate failed.")
}

$reportText = $report | ConvertTo-Json -Depth 18
Assert-FlowChainNoSecretText -Text $reportText -Label "public deployment contract report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "public deployment contract markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain public deployment contract status: $status"
Write-Host "Deployment ready: $($report.deploymentReady)"
Write-Host "Packet shareable: $packetShareable"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($missingEnvNames.Count -gt 0) {
    Write-Host "Missing env names: $((@($missingEnvNames)) -join ', ')"
}

if ($status -eq "passed" -or ($status -eq "blocked" -and $AllowBlocked)) {
    exit 0
}
exit 1
