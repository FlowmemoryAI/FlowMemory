param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/flowchain-completion-audit-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/COMPLETION_AUDIT.md",
    [int] $MonitorDurationSeconds = 20,
    [int] $MonitorPollSeconds = 5,
    [int] $MonitorMaxStateAgeSeconds = 90,
    [int] $ChildTimeoutSeconds = 10800,
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
$optionalMissingEnvNames = @(
    "FLOWCHAIN_BASE8453_CURSOR_STATE",
    "FLOWCHAIN_BASE8453_TO_BLOCK"
)

$paths = [ordered]@{
    serviceStatus = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-status-report.json"
    operatorDoctor = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/operator-doctor-report.json"
    serviceMonitor = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-monitor-report.json"
    serviceSupervisorValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-report.json"
    installCheck = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/install-check-report.json"
    upgradeRehearsal = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/upgrade-rehearsal-report.json"
    serviceInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-install-validation-report.json"
    systemdServiceInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/systemd-service-install-validation-report.json"
    liveProduct = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-live-product-e2e-report.json"
    liveInfra = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-live-infra-check-report.json"
    externalTester = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
    ownerInputs = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json"
    ownerOnboarding = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-onboarding-report.json"
    ownerSignupChecklist = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-signup-checklist-report.json"
    ownerActivationPlan = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-activation-plan-report.json"
    ownerGoLiveHandoff = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-go-live-handoff-report.json"
    ownerEnvTemplate = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-env-template-report.json"
    ownerEnvReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-env-readiness-report.json"
    ownerEnvReadinessValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-env-readiness-validation-report.json"
    ownerInputsValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-validation-report.json"
    publicRpcEdgeTemplate = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-edge-template-report.json"
    publicRpcValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json"
    publicRpcAbuseTest = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-abuse-test-report.json"
    testerWriteTokenSetup = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/tester-write-token-setup-report.json"
    publicTesterGateway = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json"
    dashboardUiReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/dashboard-ui-readiness-report.json"
    secondComputerReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/second-computer-readiness-report.json"
    publicRpcDeploymentBundle = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json"
    publicRpcDeploymentAutomation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json"
    operatorPackage = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/operator-package-report.json"
    operatorPackageVerify = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/operator-package-verify-report.json"
    externalTesterPacket = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json"
    externalTesterPacketValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-packet-validation-report.json"
    externalTesterClientValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-client-validation-report.json"
    externalTesterEvidenceValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-evidence-validation-report.json"
    opsSnapshot = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-snapshot-report.json"
    opsAlertRules = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-alert-rules-report.json"
    alertInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/alert-install-validation-report.json"
    opsMetricsExport = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-metrics-export-report.json"
    metricsInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/metrics-install-validation-report.json"
    opsEscalationDryRun = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-escalation-dry-run-report.json"
    incidentDrill = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/incident-drill-report.json"
    publicDeploymentContract = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json"
    architectureAudit = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-architecture-audit-report.json"
    backupRestoreValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-report.json"
    backupOwnerPathDryRun = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-owner-path-dry-run-report.json"
    backupInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-install-validation-report.json"
    liveWallet = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/live-service-wallet-e2e-report.json"
    testerNetwork = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json"
    publicRpc = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json"
    publicRpcSyntheticCanary = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-synthetic-canary-report.json"
    backup = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json"
    bridgeLive = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
    bridgeInfra = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
    bridgeDeployControlValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-deploy-control-validation-report.json"
    bridgeRelayerOnce = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-once-report.json"
    bridgeRelayerGuardrailValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-guardrail-validation-report.json"
    bridgeRelayerLoopValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-loop-validation-report.json"
    bridgeRuntimeCreditValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-runtime-credit-validation-report.json"
    realValuePilotAggregate = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/real-value-pilot-aggregate-report.json"
    bridgeReconciliation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-reconciliation-report.json"
    bridgeReleaseEvidenceValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-release-evidence-validation-report.json"
    bridgePilotLocal = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "services/bridge-relayer/out/real-value-pilot-e2e/bridge-real-value-pilot-e2e-report.json"
    baseTxDiagnostic = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/live-l1-bridge-e2e/base-tx-diagnostic.json"
    productionL1 = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json"
    devPack = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-dev-pack/dev-pack-e2e-report.json"
    noSecret = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json"
}

function Get-AuditJson {
    param([Parameter(Mandatory = $true)][string] $Path)
    return Read-FlowChainJsonIfExists -Path $Path
}

function Get-AuditProp {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name,
        [object] $Default = $null
    )

    if ($null -ne $Object -and $Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
    }
    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $Default
}

function Add-Unique {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [object] $Value
    )
    $text = "$Value"
    if (-not [string]::IsNullOrWhiteSpace($text) -and -not $Target.Contains($text)) {
        [void] $Target.Add($text)
    }
}

function Add-AuditItem {
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

function Get-ReportStatus {
    param([AllowNull()][object] $Report)
    return "$((Get-AuditProp -Object $Report -Name "status" -Default "missing"))"
}

function Test-StepPassed {
    param(
        [AllowNull()][object] $LiveProduct,
        [Parameter(Mandatory = $true)][string] $Name
    )
    foreach ($step in @((Get-AuditProp -Object $LiveProduct -Name "steps" -Default @()))) {
        if ("$((Get-AuditProp -Object $step -Name "name"))" -eq $Name) {
            return (Get-AuditProp -Object $step -Name "exitCode" -Default 1) -eq 0 -and "$((Get-AuditProp -Object $step -Name "status"))" -eq "passed"
        }
    }
    return $false
}

function Get-MissingAuditChecks {
    param(
        [AllowNull()][object] $Checks,
        [Parameter(Mandatory = $true)][string[]] $Names
    )

    return @($Names | Where-Object {
        (Get-AuditProp -Object $Checks -Name $_ -Default $false) -ne $true
    })
}

$script:AuditChildProcessResults = New-Object System.Collections.ArrayList

function Stop-AuditProcessTree {
    param([Parameter(Mandatory = $true)][int] $ProcessId)

    $children = @()
    try {
        $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$ProcessId" -ErrorAction SilentlyContinue)
    }
    catch {
        $children = @()
    }

    foreach ($child in $children) {
        Stop-AuditProcessTree -ProcessId ([int] $child.ProcessId)
    }

    try {
        Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
    }
    catch {
    }
}

function Read-AuditOutputFile {
    param([Parameter(Mandatory = $true)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }
    return @(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue | ForEach-Object { "$_" })
}

function Invoke-AuditChildProcess {
    param([Parameter(Mandatory = $true)][string[]] $ArgumentList)

    $startedAt = (Get-Date).ToUniversalTime()
    $stamp = $startedAt.ToString("yyyyMMddTHHmmssfffZ")
    $tempBase = Join-Path ([System.IO.Path]::GetTempPath()) "flowchain-completion-audit-$PID-$stamp-$([Guid]::NewGuid().ToString("N"))"
    $stdoutPath = "$tempBase.out.log"
    $stderrPath = "$tempBase.err.log"
    $timedOut = $false
    $exitCode = 1
    $processId = $null
    $output = @()

    try {
        $process = Start-Process -FilePath "powershell" -ArgumentList $ArgumentList -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -NoNewWindow -PassThru
        $processId = $process.Id
        $timeoutMs = [Math]::Max(1, $ChildTimeoutSeconds) * 1000
        if (-not $process.WaitForExit($timeoutMs)) {
            $timedOut = $true
            Stop-AuditProcessTree -ProcessId $process.Id
            $exitCode = 124
        }
        else {
            $exitCode = [int] $process.ExitCode
        }
    }
    catch {
        $output = @($_.Exception.Message)
        $exitCode = 1
    }

    $stdout = Read-AuditOutputFile -Path $stdoutPath
    $stderr = Read-AuditOutputFile -Path $stderrPath
    $output = @($output + $stdout + $stderr)
    if ($timedOut) {
        $output = @("Timed out after $ChildTimeoutSeconds seconds; child process tree was stopped.") + $output
    }
    $finishedAt = (Get-Date).ToUniversalTime()

    Remove-Item -LiteralPath $stdoutPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue

    $result = [ordered]@{
        argumentList = @($ArgumentList)
        processId = $processId
        startedAt = $startedAt.ToString("o")
        finishedAt = $finishedAt.ToString("o")
        durationSeconds = [int][Math]::Max(0, [Math]::Floor(($finishedAt - $startedAt).TotalSeconds))
        timedOut = $timedOut
        timeoutSeconds = $ChildTimeoutSeconds
        exitCode = $exitCode
        output = @($output)
    }
    [void] $script:AuditChildProcessResults.Add([ordered]@{
        argumentList = @($ArgumentList)
        processId = $processId
        startedAt = $result.startedAt
        finishedAt = $result.finishedAt
        durationSeconds = $result.durationSeconds
        timedOut = $timedOut
        timeoutSeconds = $ChildTimeoutSeconds
        exitCode = $exitCode
        outputLineCount = @($output).Count
    })

    return $result
}

function Use-AuditExistingReport {
    param(
        [Parameter(Mandatory = $true)][string[]] $ArgumentList,
        [Parameter(Mandatory = $true)][string] $Path,
        [switch] $AllowBlockedStatus
    )

    $startedAt = (Get-Date).ToUniversalTime()
    $report = Read-FlowChainJsonIfExists -Path $Path
    $status = Get-ReportStatus -Report $report
    $generatedAt = [string](Get-AuditProp -Object $report -Name "generatedAt" -Default "")
    $reportExists = $null -ne $report
    $exitCode = if ($status -eq "passed" -or ($AllowBlockedStatus.IsPresent -and $status -eq "blocked") -or ($reportExists -and $status -eq "missing")) { 0 } else { 1 }
    $message = "NoRefresh used existing report: path=$Path, status=$status, generatedAt=$generatedAt"
    $finishedAt = (Get-Date).ToUniversalTime()

    $result = [ordered]@{
        argumentList = @($ArgumentList)
        processId = $null
        startedAt = $startedAt.ToString("o")
        finishedAt = $finishedAt.ToString("o")
        durationSeconds = [int][Math]::Max(0, [Math]::Floor(($finishedAt - $startedAt).TotalSeconds))
        timedOut = $false
        timeoutSeconds = $ChildTimeoutSeconds
        exitCode = $exitCode
        output = @($message)
    }
    [void] $script:AuditChildProcessResults.Add([ordered]@{
        argumentList = @($ArgumentList)
        processId = $null
        startedAt = $result.startedAt
        finishedAt = $result.finishedAt
        durationSeconds = $result.durationSeconds
        timedOut = $false
        timeoutSeconds = $ChildTimeoutSeconds
        exitCode = $exitCode
        outputLineCount = 1
        noRefresh = $true
        existingReportPath = $Path
        existingReportStatus = $status
        existingReportGeneratedAt = $generatedAt
        existingReportHadStatusField = $status -ne "missing"
    })

    return $result
}

function Invoke-AuditChild {
    param(
        [Parameter(Mandatory = $true)][string[]] $ArgumentList,
        [Parameter(Mandatory = $true)][string] $Path,
        [switch] $AllowBlockedStatus
    )

    if ($NoRefresh.IsPresent) {
        return Use-AuditExistingReport -ArgumentList $ArgumentList -Path $Path -AllowBlockedStatus:$AllowBlockedStatus
    }

    return Invoke-AuditChildProcess -ArgumentList $ArgumentList
}

$liveProductResult = Invoke-AuditChild -Path $paths.liveProduct -AllowBlockedStatus -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-live-product-e2e.ps1"), "-AllowBlocked")
$liveProductOutput = @($liveProductResult.output)
$liveProductExitCode = $liveProductResult.exitCode
$serviceStatusResult = Invoke-AuditChild -Path $paths.serviceStatus -AllowBlockedStatus -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-status.ps1"), "-AllowBlocked")
$serviceStatusOutput = @($serviceStatusResult.output)
$serviceStatusExitCode = $serviceStatusResult.exitCode
$operatorDoctorResult = Invoke-AuditChild -Path $paths.operatorDoctor -AllowBlockedStatus -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-doctor.ps1"), "-ReportPath", "docs/agent-runs/live-product-infra-rpc/operator-doctor-report.json")
$operatorDoctorOutput = @($operatorDoctorResult.output)
$operatorDoctorExitCode = $operatorDoctorResult.exitCode
$serviceMonitorResult = Invoke-AuditChild -Path $paths.serviceMonitor -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-monitor.ps1"), "-DurationSeconds", "$MonitorDurationSeconds", "-PollSeconds", "$MonitorPollSeconds", "-MaxStateAgeSeconds", "$MonitorMaxStateAgeSeconds")
$serviceMonitorOutput = @($serviceMonitorResult.output)
$serviceMonitorExitCode = $serviceMonitorResult.exitCode
$serviceSupervisorValidationResult = Invoke-AuditChild -Path $paths.serviceSupervisorValidation -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-supervisor-validation.ps1"))
$serviceSupervisorValidationOutput = @($serviceSupervisorValidationResult.output)
$serviceSupervisorValidationExitCode = $serviceSupervisorValidationResult.exitCode
$serviceInstallValidationResult = Invoke-AuditChild -Path $paths.serviceInstallValidation -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-install-validation.ps1"))
$serviceInstallValidationOutput = @($serviceInstallValidationResult.output)
$serviceInstallValidationExitCode = $serviceInstallValidationResult.exitCode
$systemdServiceInstallValidationResult = Invoke-AuditChild -Path $paths.systemdServiceInstallValidation -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-install-systemd-validation.ps1"))
$systemdServiceInstallValidationOutput = @($systemdServiceInstallValidationResult.output)
$systemdServiceInstallValidationExitCode = $systemdServiceInstallValidationResult.exitCode
$upgradeRehearsalResult = Invoke-AuditChild -Path $paths.upgradeRehearsal -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-upgrade-rehearsal.ps1"))
$upgradeRehearsalOutput = @($upgradeRehearsalResult.output)
$upgradeRehearsalExitCode = $upgradeRehearsalResult.exitCode
$installCheckResult = Invoke-AuditChild -Path $paths.installCheck -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-install-check.ps1"))
$installCheckOutput = @($installCheckResult.output)
$installCheckExitCode = $installCheckResult.exitCode
$liveWalletResult = Invoke-AuditChild -Path $paths.liveWallet -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-live-service-wallet-e2e.ps1"))
$liveWalletOutput = @($liveWalletResult.output)
$liveWalletExitCode = $liveWalletResult.exitCode
$testerNetworkResult = Invoke-AuditChild -Path $paths.testerNetwork -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-live-service-tester-network-e2e.ps1"))
$testerNetworkOutput = @($testerNetworkResult.output)
$testerNetworkExitCode = $testerNetworkResult.exitCode
$devPackResult = Invoke-AuditChild -Path $paths.devPack -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "npm.cmd run flowchain:dev-pack:e2e")
$devPackOutput = @($devPackResult.output)
$devPackExitCode = $devPackResult.exitCode
$bridgePilotLocalResult = Invoke-AuditChild -Path $paths.bridgePilotLocal -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "npm.cmd run flowchain:real-value-pilot:bridge")
$bridgePilotLocalOutput = @($bridgePilotLocalResult.output)
$bridgePilotLocalExitCode = $bridgePilotLocalResult.exitCode
$baseTxDiagnosticResult = Invoke-AuditChild -Path $paths.baseTxDiagnostic -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "npm.cmd run flowchain:bridge:diagnose:tx")
$baseTxDiagnosticOutput = @($baseTxDiagnosticResult.output)
$baseTxDiagnosticExitCode = $baseTxDiagnosticResult.exitCode
$ownerInputsValidationResult = Invoke-AuditChild -Path $paths.ownerInputsValidation -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-inputs-validation.ps1"))
$ownerInputsValidationOutput = @($ownerInputsValidationResult.output)
$ownerInputsValidationExitCode = $ownerInputsValidationResult.exitCode
$publicRpcValidationResult = Invoke-AuditChild -Path $paths.publicRpcValidation -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-validation.ps1"))
$publicRpcValidationOutput = @($publicRpcValidationResult.output)
$publicRpcValidationExitCode = $publicRpcValidationResult.exitCode
$publicRpcAbuseTestResult = Invoke-AuditChild -Path $paths.publicRpcAbuseTest -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-abuse-test.ps1"))
$publicRpcAbuseTestOutput = @($publicRpcAbuseTestResult.output)
$publicRpcAbuseTestExitCode = $publicRpcAbuseTestResult.exitCode
$publicRpcSyntheticCanaryResult = Invoke-AuditChild -Path $paths.publicRpcSyntheticCanary -AllowBlockedStatus -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-synthetic-canary.ps1"), "-AllowBlocked")
$publicRpcSyntheticCanaryOutput = @($publicRpcSyntheticCanaryResult.output)
$publicRpcSyntheticCanaryExitCode = $publicRpcSyntheticCanaryResult.exitCode
$publicTesterGatewayResult = Invoke-AuditChild -Path $paths.publicTesterGateway -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-tester-gateway-e2e.ps1"))
$publicTesterGatewayOutput = @($publicTesterGatewayResult.output)
$publicTesterGatewayExitCode = $publicTesterGatewayResult.exitCode
$dashboardUiReadinessResult = Invoke-AuditChild -Path $paths.dashboardUiReadiness -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-dashboard-ui-readiness.ps1"))
$dashboardUiReadinessOutput = @($dashboardUiReadinessResult.output)
$dashboardUiReadinessExitCode = $dashboardUiReadinessResult.exitCode
$secondComputerReadinessResult = Invoke-AuditChild -Path $paths.secondComputerReadiness -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-second-computer-readiness.ps1"))
$secondComputerReadinessOutput = @($secondComputerReadinessResult.output)
$secondComputerReadinessExitCode = $secondComputerReadinessResult.exitCode
$backupRestoreValidationResult = Invoke-AuditChild -Path $paths.backupRestoreValidation -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-backup-restore-validation.ps1"))
$backupRestoreValidationOutput = @($backupRestoreValidationResult.output)
$backupRestoreValidationExitCode = $backupRestoreValidationResult.exitCode
$backupOwnerPathDryRunResult = Invoke-AuditChild -Path $paths.backupOwnerPathDryRun -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-backup-owner-path-dry-run.ps1"))
$backupOwnerPathDryRunOutput = @($backupOwnerPathDryRunResult.output)
$backupOwnerPathDryRunExitCode = $backupOwnerPathDryRunResult.exitCode
$backupInstallValidationResult = Invoke-AuditChild -Path $paths.backupInstallValidation -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-backup-install-validation.ps1"))
$backupInstallValidationOutput = @($backupInstallValidationResult.output)
$backupInstallValidationExitCode = $backupInstallValidationResult.exitCode
$bridgeDeployControlValidationResult = Invoke-AuditChild -Path $paths.bridgeDeployControlValidation -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-deploy-control-validation.ps1"))
$bridgeDeployControlValidationOutput = @($bridgeDeployControlValidationResult.output)
$bridgeDeployControlValidationExitCode = $bridgeDeployControlValidationResult.exitCode
$bridgeRelayerOnceResult = Invoke-AuditChild -Path $paths.bridgeRelayerOnce -AllowBlockedStatus -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-relayer-once.ps1"), "-AllowBlocked", "-ReportPath", $paths.bridgeRelayerOnce)
$bridgeRelayerOnceOutput = @($bridgeRelayerOnceResult.output)
$bridgeRelayerOnceExitCode = $bridgeRelayerOnceResult.exitCode
$bridgeRelayerGuardrailValidationResult = Invoke-AuditChild -Path $paths.bridgeRelayerGuardrailValidation -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-relayer-guardrail-validation.ps1"))
$bridgeRelayerGuardrailValidationOutput = @($bridgeRelayerGuardrailValidationResult.output)
$bridgeRelayerGuardrailValidationExitCode = $bridgeRelayerGuardrailValidationResult.exitCode
$bridgeRelayerLoopValidationResult = Invoke-AuditChild -Path $paths.bridgeRelayerLoopValidation -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-relayer-loop-validation.ps1"))
$bridgeRelayerLoopValidationOutput = @($bridgeRelayerLoopValidationResult.output)
$bridgeRelayerLoopValidationExitCode = $bridgeRelayerLoopValidationResult.exitCode
$bridgeRuntimeCreditValidationResult = Invoke-AuditChild -Path $paths.bridgeRuntimeCreditValidation -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-runtime-credit-validation.ps1"))
$bridgeRuntimeCreditValidationOutput = @($bridgeRuntimeCreditValidationResult.output)
$bridgeRuntimeCreditValidationExitCode = $bridgeRuntimeCreditValidationResult.exitCode
$realValuePilotAggregateResult = Invoke-AuditChild -Path $paths.realValuePilotAggregate -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-real-value-pilot-e2e.ps1"), "-SkipBaseline", "-ChildTimeoutSeconds", "1800", "-ReportDir", "devnet/local/real-value-pilot-aggregate", "-ReportPath", $paths.realValuePilotAggregate)
$realValuePilotAggregateOutput = @($realValuePilotAggregateResult.output)
$realValuePilotAggregateExitCode = $realValuePilotAggregateResult.exitCode
$bridgeReconciliationResult = Invoke-AuditChild -Path $paths.bridgeReconciliation -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-reconciliation.ps1"))
$bridgeReconciliationOutput = @($bridgeReconciliationResult.output)
$bridgeReconciliationExitCode = $bridgeReconciliationResult.exitCode
$bridgeReleaseEvidenceValidationResult = Invoke-AuditChild -Path $paths.bridgeReleaseEvidenceValidation -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-release-evidence-validation.ps1"))
$bridgeReleaseEvidenceValidationOutput = @($bridgeReleaseEvidenceValidationResult.output)
$bridgeReleaseEvidenceValidationExitCode = $bridgeReleaseEvidenceValidationResult.exitCode
$testerWriteTokenSetupResult = Invoke-AuditChild -Path $paths.testerWriteTokenSetup -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-tester-write-token-setup.ps1"), "-ReportPath", $paths.testerWriteTokenSetup)
$testerWriteTokenSetupOutput = @($testerWriteTokenSetupResult.output)
$testerWriteTokenSetupExitCode = $testerWriteTokenSetupResult.exitCode
$ownerInputsResult = Invoke-AuditChild -Path $paths.ownerInputs -AllowBlockedStatus -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-inputs.ps1"), "-AllowBlocked")
$ownerInputsOutput = @($ownerInputsResult.output)
$ownerInputsExitCode = $ownerInputsResult.exitCode
$ownerOnboardingResult = Invoke-AuditChild -Path $paths.ownerOnboarding -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-onboarding.ps1"))
$ownerOnboardingOutput = @($ownerOnboardingResult.output)
$ownerOnboardingExitCode = $ownerOnboardingResult.exitCode
$ownerSignupChecklistResult = Invoke-AuditChild -Path $paths.ownerSignupChecklist -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-signup-checklist.ps1"))
$ownerSignupChecklistOutput = @($ownerSignupChecklistResult.output)
$ownerSignupChecklistExitCode = $ownerSignupChecklistResult.exitCode
$ownerEnvTemplateResult = Invoke-AuditChild -Path $paths.ownerEnvTemplate -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-env-template.ps1"))
$ownerEnvTemplateOutput = @($ownerEnvTemplateResult.output)
$ownerEnvTemplateExitCode = $ownerEnvTemplateResult.exitCode
$ownerEnvReadinessValidationResult = Invoke-AuditChild -Path $paths.ownerEnvReadinessValidation -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-env-readiness-validation.ps1"))
$ownerEnvReadinessValidationOutput = @($ownerEnvReadinessValidationResult.output)
$ownerEnvReadinessValidationExitCode = $ownerEnvReadinessValidationResult.exitCode
$ownerEnvReadinessResult = Invoke-AuditChild -Path $paths.ownerEnvReadiness -AllowBlockedStatus -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-env-readiness.ps1"), "-AllowBlocked")
$ownerEnvReadinessOutput = @($ownerEnvReadinessResult.output)
$ownerEnvReadinessExitCode = $ownerEnvReadinessResult.exitCode
$publicRpcEdgeTemplateResult = Invoke-AuditChild -Path $paths.publicRpcEdgeTemplate -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-edge-template.ps1"))
$publicRpcEdgeTemplateOutput = @($publicRpcEdgeTemplateResult.output)
$publicRpcEdgeTemplateExitCode = $publicRpcEdgeTemplateResult.exitCode
$publicRpcDeploymentBundleResult = Invoke-AuditChild -Path $paths.publicRpcDeploymentBundle -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-deployment-bundle.ps1"))
$publicRpcDeploymentBundleOutput = @($publicRpcDeploymentBundleResult.output)
$publicRpcDeploymentBundleExitCode = $publicRpcDeploymentBundleResult.exitCode
$publicRpcDeploymentAutomationResult = Invoke-AuditChild -Path $paths.publicRpcDeploymentAutomation -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-deployment-automation.ps1"))
$publicRpcDeploymentAutomationOutput = @($publicRpcDeploymentAutomationResult.output)
$publicRpcDeploymentAutomationExitCode = $publicRpcDeploymentAutomationResult.exitCode
$operatorPackageResult = Invoke-AuditChild -Path $paths.operatorPackage -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-operator-package.ps1"))
$operatorPackageOutput = @($operatorPackageResult.output)
$operatorPackageExitCode = $operatorPackageResult.exitCode
$operatorPackageVerifyResult = Invoke-AuditChild -Path $paths.operatorPackageVerify -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-operator-package-verify.ps1"))
$operatorPackageVerifyOutput = @($operatorPackageVerifyResult.output)
$operatorPackageVerifyExitCode = $operatorPackageVerifyResult.exitCode
$liveInfraResult = Invoke-AuditChild -Path $paths.liveInfra -AllowBlockedStatus -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-live-infra-check.ps1"), "-AllowBlocked")
$liveInfraOutput = @($liveInfraResult.output)
$liveInfraExitCode = $liveInfraResult.exitCode
$externalTesterPacketResult = Invoke-AuditChild -Path $paths.externalTesterPacket -AllowBlockedStatus -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-external-tester-packet.ps1"), "-AllowBlocked")
$externalTesterPacketOutput = @($externalTesterPacketResult.output)
$externalTesterPacketExitCode = $externalTesterPacketResult.exitCode
$externalTesterPacketValidationResult = Invoke-AuditChild -Path $paths.externalTesterPacketValidation -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-external-tester-packet-validation.ps1"))
$externalTesterPacketValidationOutput = @($externalTesterPacketValidationResult.output)
$externalTesterPacketValidationExitCode = $externalTesterPacketValidationResult.exitCode
$externalTesterClientValidationResult = Invoke-AuditChild -Path $paths.externalTesterClientValidation -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-external-tester-client-validation.ps1"))
$externalTesterClientValidationOutput = @($externalTesterClientValidationResult.output)
$externalTesterClientValidationExitCode = $externalTesterClientValidationResult.exitCode
$externalTesterEvidenceValidationResult = Invoke-AuditChild -Path $paths.externalTesterEvidenceValidation -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-external-tester-evidence-validation.ps1"))
$externalTesterEvidenceValidationOutput = @($externalTesterEvidenceValidationResult.output)
$externalTesterEvidenceValidationExitCode = $externalTesterEvidenceValidationResult.exitCode
$incidentDrillResult = Invoke-AuditChild -Path $paths.incidentDrill -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-incident-drill.ps1"))
$incidentDrillOutput = @($incidentDrillResult.output)
$incidentDrillExitCode = $incidentDrillResult.exitCode
$opsSnapshotResult = Invoke-AuditChild -Path $paths.opsSnapshot -AllowBlockedStatus -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-ops-snapshot.ps1"), "-AllowBlocked", "-NoRefresh")
$opsSnapshotOutput = @($opsSnapshotResult.output)
$opsSnapshotExitCode = $opsSnapshotResult.exitCode
$opsAlertRulesResult = Invoke-AuditChild -Path $paths.opsAlertRules -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-ops-alerts.ps1"), "-AllowBlocked", "-NoRefresh")
$opsAlertRulesOutput = @($opsAlertRulesResult.output)
$opsAlertRulesExitCode = $opsAlertRulesResult.exitCode
$alertInstallValidationResult = Invoke-AuditChild -Path $paths.alertInstallValidation -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-alert-install-validation.ps1"))
$alertInstallValidationOutput = @($alertInstallValidationResult.output)
$alertInstallValidationExitCode = $alertInstallValidationResult.exitCode
$opsMetricsExportResult = Invoke-AuditChild -Path $paths.opsMetricsExport -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-ops-metrics-export.ps1"), "-AllowBlocked", "-NoRefresh")
$opsMetricsExportOutput = @($opsMetricsExportResult.output)
$opsMetricsExportExitCode = $opsMetricsExportResult.exitCode
$metricsInstallValidationResult = Invoke-AuditChild -Path $paths.metricsInstallValidation -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-metrics-install-validation.ps1"))
$metricsInstallValidationOutput = @($metricsInstallValidationResult.output)
$metricsInstallValidationExitCode = $metricsInstallValidationResult.exitCode
$opsEscalationDryRunResult = Invoke-AuditChild -Path $paths.opsEscalationDryRun -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-ops-escalation-dry-run.ps1"), "-NoRefresh")
$opsEscalationDryRunOutput = @($opsEscalationDryRunResult.output)
$opsEscalationDryRunExitCode = $opsEscalationDryRunResult.exitCode
$publicDeploymentContractResult = Invoke-AuditChild -Path $paths.publicDeploymentContract -AllowBlockedStatus -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-deployment-contract.ps1"), "-AllowBlocked", "-NoRefresh")
$publicDeploymentContractOutput = @($publicDeploymentContractResult.output)
$publicDeploymentContractExitCode = $publicDeploymentContractResult.exitCode
$ownerActivationPlanResult = Invoke-AuditChild -Path $paths.ownerActivationPlan -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-activation-plan.ps1"))
$ownerActivationPlanOutput = @($ownerActivationPlanResult.output)
$ownerActivationPlanExitCode = $ownerActivationPlanResult.exitCode
$architectureAuditResult = Invoke-AuditChild -Path $paths.architectureAudit -AllowBlockedStatus -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-architecture-audit.ps1"), "-AllowBlocked")
$architectureAuditOutput = @($architectureAuditResult.output)
$architectureAuditExitCode = $architectureAuditResult.exitCode

$reports = [ordered]@{}
foreach ($entry in $paths.GetEnumerator()) {
    $reports[$entry.Key] = Get-AuditJson -Path $entry.Value
}

$missingEnv = New-Object System.Collections.ArrayList
foreach ($sourceName in @("liveProduct", "liveInfra", "externalTester", "ownerInputs", "ownerEnvReadiness", "ownerActivationPlan", "externalTesterPacket", "publicRpc", "bridgeLive", "bridgeInfra")) {
    foreach ($name in @((Get-AuditProp -Object $reports[$sourceName] -Name "missingEnvNames" -Default @()))) {
        if ($name -notin $optionalMissingEnvNames) {
            Add-Unique -Target $missingEnv -Value $name
        }
    }
}
foreach ($name in @((Get-AuditProp -Object $reports.ownerInputs -Name "invalidEnvNames" -Default @()))) {
    Add-Unique -Target $missingEnv -Value $name
}
$ownerInputValidNames = @((Get-AuditProp -Object $reports.ownerInputs -Name "inputs" -Default @()) | Where-Object {
        (Get-AuditProp -Object $_ -Name "present" -Default $false) -eq $true `
            -and (Get-AuditProp -Object $_ -Name "valid" -Default $false) -eq $true
    } | ForEach-Object {
        [string](Get-AuditProp -Object $_ -Name "name" -Default "")
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$filteredMissingEnv = New-Object System.Collections.ArrayList
foreach ($name in @($missingEnv)) {
    if ($name -notin $ownerInputValidNames) {
        Add-Unique -Target $filteredMissingEnv -Value $name
    }
}
$missingEnv = $filteredMissingEnv

$service = $reports.serviceStatus
$serviceMonitor = $reports.serviceMonitor
$nodeStatus = [string](Get-AuditProp -Object (Get-AuditProp -Object $service -Name "node") -Name "status")
$controlPlaneStatus = [string](Get-AuditProp -Object (Get-AuditProp -Object $service -Name "controlPlane") -Name "status")
$serviceChecks = Get-AuditProp -Object $service -Name "checks"
$serviceProblems = @((Get-AuditProp -Object $service -Name "problems" -Default @()))
$serviceFailedChecks = @((Get-AuditProp -Object $service -Name "failedChecks" -Default @()))
$serviceSecretFindings = @((Get-AuditProp -Object $service -Name "secretMarkerFindings" -Default @()))
$serviceRequiredChecks = @(
    "nodeRunning",
    "nodeCommandLineMatched",
    "controlPlaneRunning",
    "controlPlaneCommandLineMatched",
    "controlPlanePortPrivate",
    "stateFileReadable",
    "latestHeightNumeric",
    "finalizedHeightNumeric",
    "latestHeightPositive",
    "stateFileFresh",
    "serviceProfileLive",
    "serviceProfileUnbounded",
    "boundedLiveModeRejectedFalse",
    "relayerLoopStoppedOrHealthy",
    "problemsEmpty",
    "failedProblemsEmpty",
    "envValuesPrintedFalse",
    "secretMarkerFindingsEmpty",
    "noSecrets",
    "broadcastsFalse"
)
$serviceMissingChecks = @(Get-MissingAuditChecks -Checks $serviceChecks -Names $serviceRequiredChecks)
$serviceFailedCheckCount = $serviceFailedChecks.Count
$serviceSecretFindingCount = $serviceSecretFindings.Count
$serviceMissingCheckCount = $serviceMissingChecks.Count
$serviceReady = $serviceStatusExitCode -eq 0 `
    -and (Get-ReportStatus -Report $service) -eq "passed" `
    -and $serviceFailedCheckCount -eq 0 `
    -and $serviceSecretFindingCount -eq 0 `
    -and $serviceMissingCheckCount -eq 0 `
    -and $serviceProblems.Count -eq 0 `
    -and $nodeStatus -eq "running" `
    -and $controlPlaneStatus -eq "running" `
    -and ((Get-AuditProp -Object $service -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $service -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $service -Name "broadcasts" -Default $true) -eq $false)
$chain = Get-AuditProp -Object $service -Name "chain"
$latestHeight = [string](Get-AuditProp -Object $chain -Name "latestHeight" -Default "0")
$stateAge = [int] (Get-AuditProp -Object $chain -Name "stateFileLastWriteAgeSeconds" -Default 999999)
$chainProducing = $latestHeight -match '^\d+$' -and [int64] $latestHeight -gt 0 -and $stateAge -le 60
$operatorDoctor = $reports.operatorDoctor
$operatorDoctorStatus = Get-ReportStatus -Report $operatorDoctor
$operatorDoctorFailedChecks = @((Get-AuditProp -Object $operatorDoctor -Name "failedChecks" -Default @()))
$operatorDoctorBlockedChecks = @((Get-AuditProp -Object $operatorDoctor -Name "blockedChecks" -Default @()))
$operatorDoctorCheckCount = @((Get-AuditProp -Object $operatorDoctor -Name "checks" -Default @())).Count
$operatorDoctorBlockedOnlyOwnerInputs = (Get-AuditProp -Object $operatorDoctor -Name "blockedOnlyOnOwnerInputs" -Default $false) -eq $true
$operatorDoctorReady = $operatorDoctorExitCode -eq 0 `
    -and ($operatorDoctorStatus -in @("passed", "blocked", "degraded")) `
    -and ($operatorDoctorFailedChecks.Count -eq 0) `
    -and (($operatorDoctorStatus -ne "blocked") -or $operatorDoctorBlockedOnlyOwnerInputs)
$monitorStatus = Get-ReportStatus -Report $serviceMonitor
$monitorHeightAdvanced = Get-AuditProp -Object $serviceMonitor -Name "heightAdvanced" -Default $false
$monitorFirstHeight = [string](Get-AuditProp -Object $serviceMonitor -Name "firstHeight" -Default "")
$monitorLatestHeight = [string](Get-AuditProp -Object $serviceMonitor -Name "latestHeight" -Default "")
$monitorSampleCount = [int](Get-AuditProp -Object $serviceMonitor -Name "sampleCount" -Default 0)
$monitorChecks = Get-AuditProp -Object $serviceMonitor -Name "checks"
$monitorFailedChecks = @((Get-AuditProp -Object $serviceMonitor -Name "failedChecks" -Default @()))
$monitorSecretFindings = @((Get-AuditProp -Object $serviceMonitor -Name "secretMarkerFindings" -Default @()))
$monitorIssues = @((Get-AuditProp -Object $serviceMonitor -Name "issues" -Default @()))
$monitorIssueCodes = @((Get-AuditProp -Object $serviceMonitor -Name "issueCodes" -Default @()))
$monitorRequiredChecks = @(
    "sampleCountSufficient",
    "serviceStatusSamplesPassed",
    "nodeRunningEverySample",
    "controlPlaneRunningEverySample",
    "heightsReadable",
    "heightNeverRegressed",
    "stateFreshEverySample",
    "heightAdvanced",
    "issuesEmpty",
    "envValuesPrintedFalse",
    "secretMarkerFindingsEmpty",
    "noSecrets",
    "broadcastsFalse"
)
$monitorMissingChecks = @(Get-MissingAuditChecks -Checks $monitorChecks -Names $monitorRequiredChecks)
$monitorFailedCheckCount = $monitorFailedChecks.Count
$monitorSecretFindingCount = $monitorSecretFindings.Count
$monitorMissingCheckCount = $monitorMissingChecks.Count
$monitorPassed = $serviceMonitorExitCode -eq 0 `
    -and $monitorStatus -eq "passed" `
    -and $monitorFailedCheckCount -eq 0 `
    -and $monitorSecretFindingCount -eq 0 `
    -and $monitorMissingCheckCount -eq 0 `
    -and $monitorIssues.Count -eq 0 `
    -and $monitorIssueCodes.Count -eq 0 `
    -and $monitorHeightAdvanced -eq $true `
    -and $monitorSampleCount -ge 2 `
    -and $monitorFirstHeight -match '^\d+$' `
    -and $monitorLatestHeight -match '^\d+$' `
    -and ((Get-AuditProp -Object $serviceMonitor -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $serviceMonitor -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $serviceMonitor -Name "broadcasts" -Default $true) -eq $false)
$serviceSupervisorValidation = $reports.serviceSupervisorValidation
$serviceSupervisorValidationStatus = Get-ReportStatus -Report $serviceSupervisorValidation
$serviceSupervisorBefore = Get-AuditProp -Object $serviceSupervisorValidation -Name "before"
$serviceSupervisorAfterCrash = Get-AuditProp -Object $serviceSupervisorValidation -Name "afterCrash"
$serviceSupervisorAfterRecovery = Get-AuditProp -Object $serviceSupervisorValidation -Name "afterRecovery"
$serviceSupervisorNodeRecovery = Get-AuditProp -Object $serviceSupervisorValidation -Name "nodeRecovery"
$serviceSupervisorNodeAfterCrash = Get-AuditProp -Object $serviceSupervisorNodeRecovery -Name "afterCrash"
$serviceSupervisorNodeAfterRecovery = Get-AuditProp -Object $serviceSupervisorNodeRecovery -Name "afterRecovery"
$serviceSupervisorRelayerRecovery = Get-AuditProp -Object $serviceSupervisorValidation -Name "relayerLoopRecovery"
$serviceSupervisorRelayerAfterCrash = Get-AuditProp -Object $serviceSupervisorRelayerRecovery -Name "afterCrash"
$serviceSupervisorRelayerAfterRecovery = Get-AuditProp -Object $serviceSupervisorRelayerRecovery -Name "afterRecovery"
$serviceSupervisorRestartAttempts = [int](Get-AuditProp -Object $serviceSupervisorValidation -Name "restartAttempts" -Default 0)
$serviceSupervisorNodeRestartAttempts = [int](Get-AuditProp -Object $serviceSupervisorNodeRecovery -Name "restartAttempts" -Default 0)
$serviceSupervisorRelayerRestartAttempts = [int](Get-AuditProp -Object $serviceSupervisorRelayerRecovery -Name "restartAttempts" -Default 0)
$serviceSupervisorChecks = Get-AuditProp -Object $serviceSupervisorValidation -Name "checks"
$serviceSupervisorFailedChecks = @((Get-AuditProp -Object $serviceSupervisorValidation -Name "failedChecks" -Default @()))
$serviceSupervisorSecretFindings = @((Get-AuditProp -Object $serviceSupervisorValidation -Name "secretMarkerFindings" -Default @()))
$serviceSupervisorRequiredChecks = @(
    "preCleanStopCommandPassed",
    "startIsolatedLiveServiceCommandPassed",
    "beforeStatusCommandPassed",
    "beforeStatusPassed",
    "beforeControlPlanePidRecorded",
    "crashStatusCommandPassed",
    "crashStatusDetected",
    "supervisorOnceRecoveryCommandPassed",
    "restartAttemptsExactlyOne",
    "afterStatusCommandPassed",
    "afterRecoveryStatusPassed",
    "afterRecoveryNodeRunning",
    "afterRecoveryControlPlaneRunning",
    "afterRecoveryHeightNumeric",
    "afterRecoveryLiveProfile",
    "afterRecoveryMaxBlocksUnbounded",
    "beforeNodeCrashPidRecorded",
    "nodeCrashStatusCommandPassed",
    "nodeCrashDetected",
    "supervisorNodeRecoveryCommandPassed",
    "nodeRestartAttemptsExactlyOne",
    "afterNodeRecoveryStatusCommandPassed",
    "afterNodeRecoveryStatusPassed",
    "afterNodeRecoveryNodeRunning",
    "afterNodeRecoveryControlPlaneRunning",
    "afterNodeRecoveryHeightNumeric",
    "afterNodeRecoveryLiveProfile",
    "afterNodeRecoveryMaxBlocksUnbounded",
    "restartWithRelayerLoopCommandPassed",
    "beforeRelayerCrashStatusCommandPassed",
    "beforeRelayerCrashStatusPassed",
    "beforeRelayerCrashPidRecorded",
    "beforeRelayerCrashRunning",
    "beforeRelayerCrashCommandLineMatched",
    "beforeRelayerCrashReportHealthy",
    "relayerCrashStatusCommandPassed",
    "relayerCrashDetected",
    "supervisorRelayerRecoveryCommandPassed",
    "relayerRestartAttemptsExactlyOne",
    "afterRelayerRecoveryStatusCommandPassed",
    "afterRelayerRecoveryStatusPassed",
    "afterRelayerRecoveryNodeRunning",
    "afterRelayerRecoveryControlPlaneRunning",
    "afterRelayerRecoveryLiveProfile",
    "afterRelayerRecoveryMaxBlocksUnbounded",
    "afterRelayerRecoveryLoopRunning",
    "afterRelayerRecoveryLoopPidRecorded",
    "afterRelayerRecoveryLoopCommandLineMatched",
    "afterRelayerRecoveryLoopReportHealthy",
    "childLogPathsInsideRepo",
    "secretMarkerFindingsEmpty",
    "envValuesPrintedFalse",
    "noSecrets",
    "broadcastsFalse"
)
$serviceSupervisorMissingChecks = @(Get-MissingAuditChecks -Checks $serviceSupervisorChecks -Names $serviceSupervisorRequiredChecks)
$serviceSupervisorValidationPassed = $serviceSupervisorValidationExitCode -eq 0 `
    -and $serviceSupervisorValidationStatus -eq "passed" `
    -and $serviceSupervisorFailedChecks.Count -eq 0 `
    -and $serviceSupervisorSecretFindings.Count -eq 0 `
    -and $serviceSupervisorMissingChecks.Count -eq 0 `
    -and (Get-AuditProp -Object $serviceSupervisorBefore -Name "status" -Default "") -eq "passed" `
    -and (@("blocked", "failed") -contains (Get-AuditProp -Object $serviceSupervisorAfterCrash -Name "status" -Default "")) `
    -and (Get-AuditProp -Object $serviceSupervisorAfterCrash -Name "controlPlaneStatus" -Default "stopped") -ne "running" `
    -and (Get-AuditProp -Object $serviceSupervisorAfterRecovery -Name "status" -Default "") -eq "passed" `
    -and ((Get-AuditProp -Object $serviceSupervisorAfterRecovery -Name "nodeRunning" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $serviceSupervisorAfterRecovery -Name "controlPlaneRunning" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $serviceSupervisorAfterRecovery -Name "liveProfile" -Default $false) -eq $true) `
    -and ([int](Get-AuditProp -Object $serviceSupervisorAfterRecovery -Name "maxBlocks" -Default -1) -eq 0) `
    -and ($serviceSupervisorRestartAttempts -ge 1) `
    -and ((Get-AuditProp -Object $serviceSupervisorRelayerAfterCrash -Name "detected" -Default $false) -eq $true) `
    -and (Get-AuditProp -Object $serviceSupervisorRelayerAfterRecovery -Name "status" -Default "") -eq "passed" `
    -and (Get-AuditProp -Object $serviceSupervisorRelayerAfterRecovery -Name "loopStatus" -Default "") -eq "running" `
    -and ((Get-AuditProp -Object $serviceSupervisorRelayerAfterRecovery -Name "loopCommandLineMatched" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $serviceSupervisorRelayerAfterRecovery -Name "reportHealthy" -Default $false) -eq $true) `
    -and ($serviceSupervisorRelayerRestartAttempts -ge 1) `
    -and ((Get-AuditProp -Object $serviceSupervisorValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $serviceSupervisorValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $serviceSupervisorValidation -Name "broadcasts" -Default $true) -eq $false)
$serviceInstallValidation = $reports.serviceInstallValidation
$serviceInstallValidationStatus = Get-ReportStatus -Report $serviceInstallValidation
$serviceInstallChecks = Get-AuditProp -Object $serviceInstallValidation -Name "checks"
$serviceInstallFailedChecks = @((Get-AuditProp -Object $serviceInstallValidation -Name "failedChecks" -Default @()))
$serviceInstallSecretFindings = @((Get-AuditProp -Object $serviceInstallValidation -Name "secretMarkerFindings" -Default @()))
$serviceInstallMissingPackageScripts = @((Get-AuditProp -Object $serviceInstallValidation -Name "missingPackageScripts" -Default @()))
$serviceInstallRequiredChecks = @(
    "installScriptExists",
    "supervisorScriptExists",
    "packageScriptsPresent",
    "planCommandPassed",
    "planDidNotMutate",
    "schedulerCmdletsAvailable",
    "scheduledTaskActionSupportsWorkingDirectory",
    "actionUsesSupervisor",
    "actionUsesRepoWorkingDirectory",
    "liveProfileDefault",
    "noBridgeRelayerDefault",
    "triggerModeBothByDefault",
    "triggerIncludesStartup",
    "triggerIncludesLogon",
    "rebootPersistentTrigger",
    "bridgeRelayerOptInPlanCommandPassed",
    "bridgeRelayerOptInPlanDidNotMutate",
    "bridgeRelayerOptInStartsLoop",
    "bridgeRelayerOptInAddsSupervisorFlag",
    "bridgeRelayerOptInUsesSupervisor",
    "bridgeRelayerOptInKeepsBothTriggers",
    "hasIntervalSeconds",
    "hasMaxRestartAttempts",
    "hasMaxStateAgeSeconds",
    "commandOmitsNonLiveProfile",
    "statusCommandPassed",
    "statusActionReadOnly",
    "statusDidNotMutate",
    "statusTaskExistsStable",
    "statusReportNoSecrets",
    "statusReportEnvValuesPrintedFalse",
    "statusReportBroadcastsFalse",
    "uninstallAbsentPreflightTaskAbsent",
    "uninstallAbsentCommandPassed",
    "uninstallAbsentTaskCommandPassed",
    "uninstallAbsentTaskWasAbsentBefore",
    "uninstallAbsentDidNotCreateTask",
    "uninstallAbsentTaskAbsentAfter",
    "uninstallAbsentDidNotRemoveTask",
    "uninstallAbsentTaskRemovedFalse",
    "uninstallAbsentReportNoSecrets",
    "uninstallAbsentReportEnvValuesPrintedFalse",
    "uninstallAbsentReportBroadcastsFalse",
    "commandsPresent",
    "envValuesPrintedFalse",
    "childReportsNoSecrets",
    "childReportsSecretMarkerFindingsEmpty",
    "secretMarkerFindingsEmpty",
    "noSecrets",
    "broadcastsFalse"
)
$serviceInstallMissingChecks = @(Get-MissingAuditChecks -Checks $serviceInstallChecks -Names $serviceInstallRequiredChecks)
$serviceInstallFailedCheckCount = $serviceInstallFailedChecks.Count
$serviceInstallSecretFindingCount = $serviceInstallSecretFindings.Count
$serviceInstallMissingCheckCount = $serviceInstallMissingChecks.Count
$serviceInstallValidationPassed = $serviceInstallValidationExitCode -eq 0 `
    -and $serviceInstallValidationStatus -eq "passed" `
    -and $serviceInstallFailedCheckCount -eq 0 `
    -and $serviceInstallSecretFindingCount -eq 0 `
    -and $serviceInstallMissingPackageScripts.Count -eq 0 `
    -and $serviceInstallMissingCheckCount -eq 0 `
    -and ((Get-AuditProp -Object $serviceInstallValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $serviceInstallValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $serviceInstallValidation -Name "broadcasts" -Default $true) -eq $false)
$systemdServiceInstallValidation = $reports.systemdServiceInstallValidation
$systemdServiceInstallValidationStatus = Get-ReportStatus -Report $systemdServiceInstallValidation
$systemdServiceInstallChecks = Get-AuditProp -Object $systemdServiceInstallValidation -Name "checks"
$systemdServiceInstallFailedChecks = @((Get-AuditProp -Object $systemdServiceInstallValidation -Name "failedChecks" -Default @()))
$systemdServiceInstallSecretFindings = @((Get-AuditProp -Object $systemdServiceInstallValidation -Name "secretMarkerFindings" -Default @()))
$systemdServiceInstallRequiredChecks = @(
    "installScriptExists",
    "installPackageScriptPresent",
    "validationPackageScriptPresent",
    "publicRpcBundleExists",
    "liveServiceTemplateExists",
    "supervisorTemplateExists",
    "renderScriptExists",
    "liveServiceUsesLiveProfile",
    "liveServiceStopPreservesState",
    "liveServiceRestartOnFailure",
    "supervisorUsesAutorecoveryLoop",
    "supervisorRestartAlways",
    "bridgeRelayerDefaultOff",
    "bridgeRelayerOptInPlanCommandPassed",
    "bridgeRelayerOptInPlanReportPassed",
    "bridgeRelayerOptInPlanDidNotMutate",
    "bridgeRelayerOptInPlanUsesRenderedUnits",
    "bridgeRelayerOptInStartsLoop",
    "bridgeRelayerOptInUsesSupervisor",
    "bridgeRelayerOptInPlanNoSecrets",
    "bridgeRelayerOptInPlanEnvValuesPrintedFalse",
    "bridgeRelayerOptInPlanBroadcastsFalse",
    "ownerEnvFileUsed",
    "leastPrivilegeHardeningPresent",
    "writePathsScoped",
    "installPlanValidationPassed",
    "installPlanCommandPassed",
    "installPlanDidNotMutate",
    "installPlanUsesRenderedUnits",
    "installPlanReportNoSecrets",
    "installPlanReportEnvValuesPrintedFalse",
    "installPlanReportBroadcastsFalse",
    "hostMutationPerformedFalse",
    "envValuesPrintedFalse",
    "secretMarkerFindingsEmpty",
    "noSecrets",
    "broadcastsFalse"
)
$systemdServiceInstallMissingChecks = @(Get-MissingAuditChecks -Checks $systemdServiceInstallChecks -Names $systemdServiceInstallRequiredChecks)
$systemdServiceInstallFailedCheckCount = $systemdServiceInstallFailedChecks.Count
$systemdServiceInstallSecretFindingCount = $systemdServiceInstallSecretFindings.Count
$systemdServiceInstallMissingCheckCount = $systemdServiceInstallMissingChecks.Count
$systemdServiceInstallValidationPassed = $systemdServiceInstallValidationExitCode -eq 0 `
    -and $systemdServiceInstallValidationStatus -eq "passed" `
    -and $systemdServiceInstallFailedCheckCount -eq 0 `
    -and $systemdServiceInstallSecretFindingCount -eq 0 `
    -and $systemdServiceInstallMissingCheckCount -eq 0 `
    -and ((Get-AuditProp -Object $systemdServiceInstallValidation -Name "hostMutationPerformed" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $systemdServiceInstallValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $systemdServiceInstallValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $systemdServiceInstallValidation -Name "broadcasts" -Default $true) -eq $false)
$upgradeRehearsal = $reports.upgradeRehearsal
$upgradeRehearsalStatus = Get-ReportStatus -Report $upgradeRehearsal
$upgradeRehearsalChecks = Get-AuditProp -Object $upgradeRehearsal -Name "checks"
$upgradeRehearsalFailedChecks = @((Get-AuditProp -Object $upgradeRehearsal -Name "failedChecks" -Default @()))
$upgradeRehearsalSecretFindings = @((Get-AuditProp -Object $upgradeRehearsal -Name "secretMarkerFindings" -Default @()))
$upgradeRehearsalRequiredChecks = @(
    "stateSourceExists",
    "sourceStateReadable",
    "previousReleaseStateCopied",
    "backupStateCopied",
    "nextReleaseStateCopied",
    "rollbackStateCopied",
    "sourceStateHashPresent",
    "previousStateHashMatchesSource",
    "nextStateHashMatchesSource",
    "rollbackStateHashMatchesSource",
    "chainIdPreserved",
    "genesisHashPreserved",
    "nextBlockNumberPreserved",
    "packageManifestCaptured",
    "migrationManifestWritten",
    "rollbackManifestWritten",
    "rollbackCommandsPresent",
    "verifyCommandsPresent",
    "workDirInsideRepo",
    "hostMutationPerformedFalse",
    "envValuesPrintedFalse",
    "secretMarkerFindingsEmpty",
    "noSecrets",
    "broadcastsFalse"
)
$upgradeRehearsalMissingChecks = @(Get-MissingAuditChecks -Checks $upgradeRehearsalChecks -Names $upgradeRehearsalRequiredChecks)
$upgradeRehearsalFailedCheckCount = $upgradeRehearsalFailedChecks.Count
$upgradeRehearsalSecretFindingCount = $upgradeRehearsalSecretFindings.Count
$upgradeRehearsalMissingCheckCount = $upgradeRehearsalMissingChecks.Count
$upgradeRehearsalPassed = $upgradeRehearsalExitCode -eq 0 `
    -and $upgradeRehearsalStatus -eq "passed" `
    -and $upgradeRehearsalFailedCheckCount -eq 0 `
    -and $upgradeRehearsalSecretFindingCount -eq 0 `
    -and $upgradeRehearsalMissingCheckCount -eq 0 `
    -and ((Get-AuditProp -Object $upgradeRehearsal -Name "hostMutationPerformed" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $upgradeRehearsal -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $upgradeRehearsal -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $upgradeRehearsal -Name "broadcasts" -Default $true) -eq $false)
$installCheck = $reports.installCheck
$installCheckStatus = Get-ReportStatus -Report $installCheck
$installCheckChecks = Get-AuditProp -Object $installCheck -Name "checks"
$installCheckFailedChecks = @((Get-AuditProp -Object $installCheck -Name "failedChecks" -Default @()))
$installCheckSecretFindings = @((Get-AuditProp -Object $installCheck -Name "secretMarkerFindings" -Default @()))
$installCheckMissingScripts = @((Get-AuditProp -Object $installCheck -Name "missingScripts" -Default @()))
$installCheckMissingDocs = @((Get-AuditProp -Object $installCheck -Name "missingDocs" -Default @()))
$installCheckRequiredChecks = @(
    "repoRootResolved",
    "packageJsonReadable",
    "requiredPackageScriptsPresent",
    "requiredRunbooksPresent",
    "requiredToolsPresent",
    "diskFreeMeetsMinimum",
    "serviceInstallValidationReportPassed",
    "systemdInstallValidationReportPassed",
    "childValidationsPassed",
    "childValidationsDidNotTimeout",
    "ownerInputNamesOnly",
    "ownerInputAbsenceIsNonRepoBlocker",
    "hostMutationPerformedFalse",
    "envValuesPrintedFalse",
    "secretMarkerFindingsEmpty",
    "noSecrets",
    "broadcastsFalse"
)
$installCheckMissingChecks = @(Get-MissingAuditChecks -Checks $installCheckChecks -Names $installCheckRequiredChecks)
$installCheckFailedCheckCount = $installCheckFailedChecks.Count
$installCheckSecretFindingCount = $installCheckSecretFindings.Count
$installCheckMissingCheckCount = $installCheckMissingChecks.Count
$installCheckPassed = $installCheckExitCode -eq 0 `
    -and $installCheckStatus -eq "passed" `
    -and $installCheckFailedCheckCount -eq 0 `
    -and $installCheckSecretFindingCount -eq 0 `
    -and $installCheckMissingScripts.Count -eq 0 `
    -and $installCheckMissingDocs.Count -eq 0 `
    -and $installCheckMissingCheckCount -eq 0 `
    -and ((Get-AuditProp -Object $installCheck -Name "hostMutationPerformed" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $installCheck -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $installCheck -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $installCheck -Name "broadcasts" -Default $true) -eq $false)
$liveProduct = $reports.liveProduct
$externalTester = $reports.externalTester
$testerNetwork = $reports.testerNetwork
$liveWallet = $reports.liveWallet
$devPack = $reports.devPack
$liveInfra = $reports.liveInfra
$ownerInputs = $reports.ownerInputs
$ownerOnboarding = $reports.ownerOnboarding
$ownerSignupChecklist = $reports.ownerSignupChecklist
$ownerEnvTemplate = $reports.ownerEnvTemplate
$ownerGoLiveHandoff = $reports.ownerGoLiveHandoff
$ownerEnvReadiness = $reports.ownerEnvReadiness
$ownerEnvReadinessValidation = $reports.ownerEnvReadinessValidation
$ownerInputsValidation = $reports.ownerInputsValidation
$publicRpcValidation = $reports.publicRpcValidation
$publicRpcAbuseTest = $reports.publicRpcAbuseTest
$publicRpcSyntheticCanary = $reports.publicRpcSyntheticCanary
$publicTesterGateway = $reports.publicTesterGateway
$externalTesterPacket = $reports.externalTesterPacket
$testerWalletCreatesCount = @((Get-AuditProp -Object $testerNetwork -Name "testerWalletCreates" -Default @())).Count
$testerTransferCount = @((Get-AuditProp -Object $testerNetwork -Name "transferResults" -Default @())).Count
$testerCount = [int](Get-AuditProp -Object $testerNetwork -Name "testerCount" -Default 0)
$testerNetworkBefore = [string](Get-AuditProp -Object $testerNetwork -Name "chainBeforeBlock")
$testerNetworkAfter = [string](Get-AuditProp -Object $testerNetwork -Name "chainAfterBlock")
$testerNetworkChecks = Get-AuditProp -Object $testerNetwork -Name "checks"
$testerNetworkFailedChecks = @((Get-AuditProp -Object $testerNetwork -Name "failedChecks" -Default @()))
$testerNetworkSecretFindings = @((Get-AuditProp -Object $testerNetwork -Name "secretMarkerFindings" -Default @()))
$testerNetworkRequiredChecks = @(
    "serviceStatusSucceeded",
    "healthSchemaOk",
    "rpcDiscoverSchemaOk",
    "rpcReadinessSchemaOk",
    "testerCountAtLeastFour",
    "walletCreatesPublicOnly",
    "walletAccountsUnique",
    "fundingTxIdsPresent",
    "transferCountMatches",
    "allTransfersQueued",
    "allTransferIdsPresent",
    "allTransferTxIdsPresent",
    "balancesMatchExpected",
    "historyCountsAtLeastTwo",
    "chainStatusReadableBefore",
    "chainStatusReadableAfter",
    "blockHeightAdvanced",
    "packetExecutableSmokeValidated",
    "packetSmokeChecksAllPassed",
    "localOnly",
    "productionReadyFalse",
    "noLiveBroadcast",
    "broadcastsFalse",
    "envValuesPrintedFalse",
    "noSecrets",
    "secretMarkerFindingsEmpty"
)
$testerNetworkMissingChecks = Get-MissingAuditChecks -Checks $testerNetworkChecks -Names $testerNetworkRequiredChecks
$testerNetworkFailedCheckCount = @($testerNetworkFailedChecks | Where-Object { $null -ne $_ }).Count
$testerNetworkSecretFindingCount = @($testerNetworkSecretFindings | Where-Object { $null -ne $_ }).Count
$testerNetworkMissingCheckCount = @($testerNetworkMissingChecks | Where-Object { $null -ne $_ }).Count
$testerNetworkPassed = $testerNetworkExitCode -eq 0 `
    -and (Get-ReportStatus -Report $testerNetwork) -eq "passed" `
    -and $testerCount -ge 4 `
    -and $testerTransferCount -ge 4 `
    -and $testerNetworkFailedCheckCount -eq 0 `
    -and $testerNetworkSecretFindingCount -eq 0 `
    -and $testerNetworkMissingCheckCount -eq 0 `
    -and ((Get-AuditProp -Object $testerNetwork -Name "localOnly" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $testerNetwork -Name "productionReady" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $testerNetwork -Name "noLiveBroadcast" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $testerNetwork -Name "broadcasts" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $testerNetwork -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $testerNetwork -Name "noSecrets" -Default $false) -eq $true)
$liveWalletBalances = Get-AuditProp -Object $liveWallet -Name "balances"
$liveWalletSenderAfter = [string](Get-AuditProp -Object $liveWalletBalances -Name "senderAfter")
$liveWalletRecipientAfter = [string](Get-AuditProp -Object $liveWalletBalances -Name "recipientAfter")
$liveWalletBefore = [string](Get-AuditProp -Object $liveWallet -Name "chainBeforeBlock")
$liveWalletAfter = [string](Get-AuditProp -Object $liveWallet -Name "chainAfterBlock")
$liveWalletChecks = Get-AuditProp -Object $liveWallet -Name "checks"
$liveWalletFailedChecks = @((Get-AuditProp -Object $liveWallet -Name "failedChecks" -Default @()))
$liveWalletSecretFindings = @((Get-AuditProp -Object $liveWallet -Name "secretMarkerFindings" -Default @()))
$liveWalletRequiredChecks = @(
    "serviceStatusSucceeded",
    "healthSchemaOk",
    "faucetQueuedTransactions",
    "senderFundedBalanceReached",
    "sendAccepted",
    "sendQueuedLocalRuntime",
    "sendTxIdsPresent",
    "transferIdPresent",
    "senderDebitApplied",
    "recipientCreditApplied",
    "transferHistoryRecorded",
    "chainStatusReadableBefore",
    "chainStatusReadableAfter",
    "blockHeightAdvanced",
    "localOnly",
    "productionReadyFalse",
    "noLiveBroadcast",
    "broadcastsFalse",
    "envValuesPrintedFalse",
    "noSecrets",
    "secretMarkerFindingsEmpty"
)
$liveWalletMissingChecks = Get-MissingAuditChecks -Checks $liveWalletChecks -Names $liveWalletRequiredChecks
$liveWalletFailedCheckCount = @($liveWalletFailedChecks | Where-Object { $null -ne $_ }).Count
$liveWalletSecretFindingCount = @($liveWalletSecretFindings | Where-Object { $null -ne $_ }).Count
$liveWalletMissingCheckCount = @($liveWalletMissingChecks | Where-Object { $null -ne $_ }).Count
$liveWalletPassed = $liveWalletExitCode -eq 0 `
    -and (Get-ReportStatus -Report $liveWallet) -eq "passed" `
    -and $liveWalletSenderAfter -eq "75" `
    -and $liveWalletRecipientAfter -eq "25" `
    -and $liveWalletFailedCheckCount -eq 0 `
    -and $liveWalletSecretFindingCount -eq 0 `
    -and $liveWalletMissingCheckCount -eq 0 `
    -and ((Get-AuditProp -Object $liveWallet -Name "localOnly" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $liveWallet -Name "productionReady" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $liveWallet -Name "noLiveBroadcast" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $liveWallet -Name "broadcasts" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $liveWallet -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $liveWallet -Name "noSecrets" -Default $false) -eq $true)
$devPackChecks = Get-AuditProp -Object $devPack -Name "checks"
$devPackRequiredChecks = @(
    "discoveryLoaded",
    "readinessLoaded",
    "healthReadable",
    "nodeStatusReadable",
    "blockListReadable",
    "blockGetReadable",
    "transactionListReadable",
    "transactionGetReadable",
    "mempoolReadable",
    "accountListReadable",
    "balanceReadable",
    "walletMetadataReadable",
    "walletTransfersReadable",
    "walletBalancesReadable",
    "faucetEventsReadable",
    "finalityReadable",
    "bridgeLifecycleReadable",
    "walletSendRuntimeBacked",
    "waitTransactionSdkIncluded",
    "cliJsonStatus",
    "cliJsonBlocks",
    "cliJsonWaitTransaction",
    "nodeExamplePassed",
    "signedEnvelopeExamplePassed",
    "cliSignedEnvelopePrepared",
    "cliSignedTransactionSubmit",
    "browserExamplePresent",
    "browserExampleSmokePassed",
    "openApiSpecGenerated",
    "postmanCollectionGenerated",
    "curlExamplesGenerated",
    "developerGuidesPresent",
    "pythonSdkE2ePassed",
    "pythonSdkDiscoveryLoaded",
    "pythonSdkReadinessLoaded",
    "pythonDevkitJsonStatus",
    "pythonDevkitJsonBlocks",
    "pythonDevkitWaitTransaction",
    "pythonSdkDocsPresent",
    "pythonSdkSafeDiagnostics",
    "heightAdvanced",
    "publicReadinessFailClosed",
    "publicWriteMethodsBlockedFromPublicList",
    "broadLocalStateBlockedFromPublicList",
    "inventoryGenerated",
    "inventorySafe"
)
$devPackMissingChecks = @(Get-MissingAuditChecks -Checks $devPackChecks -Names $devPackRequiredChecks)
$devPackFailedChecks = @((Get-AuditProp -Object $devPack -Name "failedChecks" -Default @()))
$devPackLanguageSdks = @((Get-AuditProp -Object $devPack -Name "languageSdks" -Default @()))
$devPackImplementedLanguageNames = @($devPackLanguageSdks | Where-Object {
    (Get-AuditProp -Object $_ -Name "status" -Default "") -eq "implemented"
} | ForEach-Object {
    [string](Get-AuditProp -Object $_ -Name "language" -Default "")
})
$devPackReportPaths = Get-AuditProp -Object $devPack -Name "reportPaths"
$devPackRequiredReportPathNames = @("json", "markdown", "handoff", "inventory", "rpcReference", "openApi", "postman", "curlExamples", "pythonSdk")
$devPackMissingReportPathNames = @($devPackRequiredReportPathNames | Where-Object {
    [string]::IsNullOrWhiteSpace([string](Get-AuditProp -Object $devPackReportPaths -Name $_ -Default ""))
})
$devPackMethodCount = [int](Get-AuditProp -Object $devPack -Name "methodCount" -Default 0)
$devPackPublicReadyMethodCount = [int](Get-AuditProp -Object $devPack -Name "publicReadyMethodCount" -Default -1)
$devPackPassed = $devPackExitCode -eq 0 `
    -and (Get-ReportStatus -Report $devPack) -eq "passed" `
    -and $devPackMissingChecks.Count -eq 0 `
    -and $devPackFailedChecks.Count -eq 0 `
    -and $devPackMethodCount -ge 20 `
    -and $devPackPublicReadyMethodCount -eq 0 `
    -and ("python" -in $devPackImplementedLanguageNames) `
    -and $devPackMissingReportPathNames.Count -eq 0 `
    -and (Get-AuditProp -Object $devPack -Name "noLiveBroadcast" -Default $false) -eq $true `
    -and (Get-AuditProp -Object $devPack -Name "broadcasts" -Default $true) -eq $false `
    -and (Get-AuditProp -Object $devPack -Name "envValuesPrinted" -Default $true) -eq $false `
    -and (Get-AuditProp -Object $devPack -Name "noSecrets" -Default $false) -eq $true
$devPackFirstHeight = [string](Get-AuditProp -Object $devPack -Name "firstHeight" -Default "")
$devPackSecondHeight = [string](Get-AuditProp -Object $devPack -Name "secondHeight" -Default "")
$localTesterRehearsalReady = Get-AuditProp -Object $externalTester -Name "localTesterRehearsalReady"
$externalTesterHeight = [string](Get-AuditProp -Object $externalTester -Name "latestHeight")
$ownerInputsStatus = Get-ReportStatus -Report $ownerInputs
$ownerInputsReady = Get-AuditProp -Object $ownerInputs -Name "ownerInputReady" -Default $false
$ownerOnboardingStatus = Get-ReportStatus -Report $ownerOnboarding
$ownerOnboardingFlowChainRpcIsOurs = Get-AuditProp -Object $ownerOnboarding -Name "flowChainRpcIsOurs" -Default $false
$ownerOnboardingThirdPartyFlowChainRpcProviderNeeded = Get-AuditProp -Object $ownerOnboarding -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$ownerOnboardingPublicEdgeRequired = Get-AuditProp -Object $ownerOnboarding -Name "publicRpcRequiresOwnerPublicEdge" -Default $false
$ownerOnboardingBaseExternal = Get-AuditProp -Object $ownerOnboarding -Name "base8453RpcIsExternalChainDependency" -Default $false
$ownerOnboardingLocalEnvFileSupported = Get-AuditProp -Object $ownerOnboarding -Name "localEnvFileSupported" -Default $false
$ownerOnboardingChecks = Get-AuditProp -Object $ownerOnboarding -Name "checks"
$ownerOnboardingFailedChecks = @((Get-AuditProp -Object $ownerOnboarding -Name "failedChecks" -Default @()))
$ownerOnboardingSecretFindings = @((Get-AuditProp -Object $ownerOnboarding -Name "secretMarkerFindings" -Default @()))
$ownerOnboardingRequiredChecks = @(
    "flowChainRpcIsOurs",
    "thirdPartyFlowChainRpcProviderNeededFalse",
    "publicRpcRequiresOwnerPublicEdge",
    "base8453RpcIsExternalChainDependency",
    "localEnvFileSupported",
    "onboardingGroupsPresent",
    "localShellTemplatePresent",
    "nextCommandsPresent",
    "valuesPrintedFalse",
    "envValuesPrintedFalse",
    "noSecrets",
    "broadcastsFalse",
    "secretMarkerFindingsEmpty"
)
$ownerOnboardingMissingChecks = Get-MissingAuditChecks -Checks $ownerOnboardingChecks -Names $ownerOnboardingRequiredChecks
$ownerOnboardingFailedCheckCount = @($ownerOnboardingFailedChecks | Where-Object { $null -ne $_ }).Count
$ownerOnboardingSecretFindingCount = @($ownerOnboardingSecretFindings | Where-Object { $null -ne $_ }).Count
$ownerOnboardingMissingCheckCount = @($ownerOnboardingMissingChecks | Where-Object { $null -ne $_ }).Count
$ownerOnboardingPassed = $ownerOnboardingExitCode -eq 0 `
    -and $ownerOnboardingStatus -eq "passed" `
    -and $ownerOnboardingFlowChainRpcIsOurs -eq $true `
    -and $ownerOnboardingFailedCheckCount -eq 0 `
    -and $ownerOnboardingSecretFindingCount -eq 0 `
    -and $ownerOnboardingMissingCheckCount -eq 0 `
    -and $ownerOnboardingThirdPartyFlowChainRpcProviderNeeded -eq $false `
    -and $ownerOnboardingPublicEdgeRequired -eq $true `
    -and $ownerOnboardingBaseExternal -eq $true `
    -and $ownerOnboardingLocalEnvFileSupported -eq $true `
    -and ((Get-AuditProp -Object $ownerOnboarding -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $ownerOnboarding -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $ownerOnboarding -Name "broadcasts" -Default $true) -eq $false)
$ownerSignupChecklistStatus = Get-ReportStatus -Report $ownerSignupChecklist
$ownerSignupExternalCount = [int](Get-AuditProp -Object $ownerSignupChecklist -Name "externalSignupCount" -Default 0)
$ownerSignupItemCount = [int](Get-AuditProp -Object $ownerSignupChecklist -Name "itemCount" -Default 0)
$ownerSignupMissingCoverageCount = @((Get-AuditProp -Object $ownerSignupChecklist -Name "missingChecklistCoverage" -Default @())).Count
$ownerSignupRepoOwned = Get-AuditProp -Object $ownerSignupChecklist -Name "flowChainRpcIsRepoOwned" -Default $false
$ownerSignupThirdPartyFlowChainRpcNeeded = Get-AuditProp -Object $ownerSignupChecklist -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$ownerSignupLocalEnvFileSupported = Get-AuditProp -Object $ownerSignupChecklist -Name "localEnvFileSupported" -Default $false
$ownerSignupChecks = Get-AuditProp -Object $ownerSignupChecklist -Name "checks"
$ownerSignupFailedChecks = @((Get-AuditProp -Object $ownerSignupChecklist -Name "failedChecks" -Default @()))
$ownerSignupSecretFindings = @((Get-AuditProp -Object $ownerSignupChecklist -Name "secretMarkerFindings" -Default @()))
$ownerSignupRequiredChecks = @(
    "missingChecklistCoverageEmpty",
    "flowChainRpcIsRepoOwned",
    "thirdPartyFlowChainRpcProviderNeededFalse",
    "localEnvFileSupported",
    "itemCountMinimumMet",
    "externalSignupCountMinimumMet",
    "requiredOwnerEnvNamesPresent",
    "valuesPrintedFalse",
    "envValuesPrintedFalse",
    "noSecrets",
    "broadcastsFalse",
    "secretMarkerFindingsEmpty"
)
$ownerSignupMissingChecks = Get-MissingAuditChecks -Checks $ownerSignupChecks -Names $ownerSignupRequiredChecks
$ownerSignupFailedCheckCount = @($ownerSignupFailedChecks | Where-Object { $null -ne $_ }).Count
$ownerSignupSecretFindingCount = @($ownerSignupSecretFindings | Where-Object { $null -ne $_ }).Count
$ownerSignupMissingCheckCount = @($ownerSignupMissingChecks | Where-Object { $null -ne $_ }).Count
$ownerSignupChecklistPassed = $ownerSignupChecklistExitCode -eq 0 `
    -and $ownerSignupChecklistStatus -eq "passed" `
    -and $ownerSignupFailedCheckCount -eq 0 `
    -and $ownerSignupSecretFindingCount -eq 0 `
    -and $ownerSignupMissingCheckCount -eq 0 `
    -and $ownerSignupItemCount -ge 8 `
    -and $ownerSignupExternalCount -ge 3 `
    -and $ownerSignupMissingCoverageCount -eq 0 `
    -and $ownerSignupRepoOwned -eq $true `
    -and $ownerSignupThirdPartyFlowChainRpcNeeded -eq $false `
    -and $ownerSignupLocalEnvFileSupported -eq $true `
    -and ((Get-AuditProp -Object $ownerSignupChecklist -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $ownerSignupChecklist -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $ownerSignupChecklist -Name "broadcasts" -Default $true) -eq $false)
$ownerActivationPlan = $reports.ownerActivationPlan
$ownerActivationPlanStatus = Get-ReportStatus -Report $ownerActivationPlan
$ownerActivationPlanChecks = Get-AuditProp -Object $ownerActivationPlan -Name "checks"
$ownerActivationPlanRequiredChecks = @(
    "stageCountMinimumMet",
    "requiredEnvCoverageComplete",
    "knownMissingEnvNamesOnly",
    "invalidEnvNamesEmpty",
    "knownInvalidEnvNamesOnly",
    "validationCommandsPresent",
    "ownerMustNotSendPresent",
    "externalResourceMappingPresent",
    "serviceStagePresent",
    "publicRpcStagePresent",
    "backupStagePresent",
    "testerStagePresent",
    "bridgeStagePresent",
    "finalAuditStagePresent",
    "envValuesPrintedFalse",
    "noSecrets",
    "broadcastsFalse",
    "secretMarkerFindingsEmpty"
)
$ownerActivationPlanMissingChecks = Get-MissingAuditChecks -Checks $ownerActivationPlanChecks -Names $ownerActivationPlanRequiredChecks
$ownerActivationPlanFailedChecks = @((Get-AuditProp -Object $ownerActivationPlan -Name "failedChecks" -Default @()))
$ownerActivationPlanSecretFindings = @((Get-AuditProp -Object $ownerActivationPlan -Name "secretMarkerFindings" -Default @()))
$ownerActivationPlanMissingCoverage = @((Get-AuditProp -Object $ownerActivationPlan -Name "missingCoverage" -Default @()))
$ownerActivationPlanUnknownMissing = @((Get-AuditProp -Object $ownerActivationPlan -Name "unknownMissingEnvNames" -Default @()))
$ownerActivationPlanUnknownInvalid = @((Get-AuditProp -Object $ownerActivationPlan -Name "unknownInvalidEnvNames" -Default @()))
$ownerActivationPlanInvalid = @((Get-AuditProp -Object $ownerActivationPlan -Name "invalidEnvNames" -Default @()))
$ownerActivationPlanStageCount = [int](Get-AuditProp -Object $ownerActivationPlan -Name "stageCount" -Default 0)
$ownerActivationPlanReadyStageCount = [int](Get-AuditProp -Object $ownerActivationPlan -Name "readyStageCount" -Default 0)
$ownerActivationPlanActivationReady = (Get-AuditProp -Object $ownerActivationPlan -Name "activationReady" -Default $false) -eq $true
$ownerActivationPlanFailedCheckCount = @($ownerActivationPlanFailedChecks | Where-Object { $null -ne $_ }).Count
$ownerActivationPlanSecretFindingCount = @($ownerActivationPlanSecretFindings | Where-Object { $null -ne $_ }).Count
$ownerActivationPlanMissingCheckCount = @($ownerActivationPlanMissingChecks | Where-Object { $null -ne $_ }).Count
$ownerActivationPlanPassed = $ownerActivationPlanExitCode -eq 0 `
    -and $ownerActivationPlanStatus -eq "passed" `
    -and $ownerActivationPlanMissingCheckCount -eq 0 `
    -and $ownerActivationPlanFailedCheckCount -eq 0 `
    -and $ownerActivationPlanSecretFindingCount -eq 0 `
    -and $ownerActivationPlanMissingCoverage.Count -eq 0 `
    -and $ownerActivationPlanUnknownMissing.Count -eq 0 `
    -and $ownerActivationPlanUnknownInvalid.Count -eq 0 `
    -and $ownerActivationPlanInvalid.Count -eq 0 `
    -and $ownerActivationPlanStageCount -ge 8 `
    -and ((Get-AuditProp -Object $ownerActivationPlan -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $ownerActivationPlan -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $ownerActivationPlan -Name "broadcasts" -Default $true) -eq $false)
$ownerGoLiveHandoffStatus = Get-ReportStatus -Report $ownerGoLiveHandoff
$ownerGoLiveHandoffChecks = Get-AuditProp -Object $ownerGoLiveHandoff -Name "checks"
$ownerGoLiveHandoffRequiredChecks = @(
    "packageScriptPresent",
    "activationPlanLoaded",
    "activationPlanPassed",
    "signupChecklistLoaded",
    "signupChecklistPassed",
    "ownerInputsLoaded",
    "truthTableLoaded",
    "stageDeckPresent",
    "stageCountMinimumMet",
    "everyStageHasValidationCommand",
    "everyStageHasOwnerMustNotSend",
    "nonReadyStagesExplainBlockers",
    "requiredEnvCoverageComplete",
    "requiredAndOptionalOwnerInputsSeparated",
    "neededNowExcludesOptionalOwnerInputs",
    "knownOwnerInputBlockersOnly",
    "nextOwnerInputsPresentWhenBlocked",
    "nextCommandsPresent",
    "launchSequencePresent",
    "launchSequenceEveryStepHasCommands",
    "launchSequenceEveryStepHasExpectedStatuses",
    "launchSequenceEveryStepHasExpectedReportPath",
    "launchSequenceExpectedReportPathsScoped",
    "launchSequenceEveryStepStopsOnFailure",
    "launchSequenceCoversOwnerEnvReadiness",
    "launchSequenceCoversPublicRpcRender",
    "launchSequenceCoversOwnerHostApplyPlan",
    "launchSequenceCoversOwnerHostApplyExecution",
    "launchSequenceCoversSystemdInstallPlan",
    "launchSequenceCoversServiceMonitor",
    "launchSequenceCoversPublicRpcCanary",
    "launchSequenceCoversBackupRestore",
    "launchSequenceCoversBridgeRelayer",
    "launchSequenceCoversTesterPacket",
    "launchSequenceCoversCutoverAudit",
    "launchSequenceCoversTruthAndNoSecret",
    "launchSequenceCommandsAvoidInlineEnvAssignment",
    "launchSequenceCommandsAvoidUrls",
    "launchSequencePackageScriptsPresent",
    "rollbackCommandsPresent",
    "rollbackCoversLocalStop",
    "rollbackCoversBridgeEmergencyStop",
    "rollbackCoversOpsSnapshot",
    "rollbackCoversOwnerHostApplyRollback",
    "rollbackPackageScriptsPresent",
    "releaseClaimBlockedUntilTruthPassed",
    "packetShareBlockedUntilReady",
    "envValuesPrintedFalse",
    "noSecrets",
    "broadcastsFalse",
    "secretMarkerFindingsEmpty"
)
$ownerGoLiveHandoffMissingChecks = Get-MissingAuditChecks -Checks $ownerGoLiveHandoffChecks -Names $ownerGoLiveHandoffRequiredChecks
$ownerGoLiveHandoffFailedChecks = @((Get-AuditProp -Object $ownerGoLiveHandoff -Name "failedChecks" -Default @()))
$ownerGoLiveHandoffSecretFindings = @((Get-AuditProp -Object $ownerGoLiveHandoff -Name "secretMarkerFindings" -Default @()))
$ownerGoLiveHandoffUnknownMissing = @((Get-AuditProp -Object $ownerGoLiveHandoff -Name "unknownMissingEnvNames" -Default @()))
$ownerGoLiveHandoffUnknownInvalid = @((Get-AuditProp -Object $ownerGoLiveHandoff -Name "unknownInvalidEnvNames" -Default @()))
$ownerGoLiveHandoffInvalid = @((Get-AuditProp -Object $ownerGoLiveHandoff -Name "invalidEnvNames" -Default @()))
$ownerGoLiveHandoffMissingRequired = @((Get-AuditProp -Object $ownerGoLiveHandoff -Name "missingRequiredEnvNames" -Default @()))
$ownerGoLiveHandoffMissingOptional = @((Get-AuditProp -Object $ownerGoLiveHandoff -Name "missingOptionalEnvNames" -Default @()))
$ownerGoLiveHandoffNextOptionalInputs = @((Get-AuditProp -Object $ownerGoLiveHandoff -Name "nextOwnerOptionalInputNames" -Default @()))
$ownerGoLiveHandoffStageCount = [int](Get-AuditProp -Object $ownerGoLiveHandoff -Name "stageCount" -Default 0)
$ownerGoLiveHandoffLaunchSequenceCount = [int](Get-AuditProp -Object $ownerGoLiveHandoff -Name "launchSequenceCount" -Default 0)
$ownerGoLiveHandoffLaunchSequenceCommandCount = [int](Get-AuditProp -Object $ownerGoLiveHandoff -Name "launchSequenceCommandCount" -Default 0)
$ownerGoLiveHandoffExpectedReportPathCount = [int](Get-AuditProp -Object $ownerGoLiveHandoff -Name "launchSequenceExpectedReportPathCount" -Default 0)
$ownerGoLiveHandoffInvalidExpectedReportPaths = @((Get-AuditProp -Object $ownerGoLiveHandoff -Name "invalidLaunchSequenceExpectedReportPaths" -Default @()))
$ownerGoLiveHandoffMissingLaunchPackageScripts = @((Get-AuditProp -Object $ownerGoLiveHandoff -Name "missingLaunchSequencePackageScriptNames" -Default @()))
$ownerGoLiveHandoffRollbackCommandCount = [int](Get-AuditProp -Object $ownerGoLiveHandoff -Name "rollbackCommandCount" -Default 0)
$ownerGoLiveHandoffMissingRollbackPackageScripts = @((Get-AuditProp -Object $ownerGoLiveHandoff -Name "missingRollbackPackageScriptNames" -Default @()))
$ownerGoLiveHandoffReleaseReady = (Get-AuditProp -Object $ownerGoLiveHandoff -Name "releaseReady" -Default $false) -eq $true
$ownerGoLiveHandoffFailedCheckCount = @($ownerGoLiveHandoffFailedChecks | Where-Object { $null -ne $_ }).Count
$ownerGoLiveHandoffSecretFindingCount = @($ownerGoLiveHandoffSecretFindings | Where-Object { $null -ne $_ }).Count
$ownerGoLiveHandoffMissingCheckCount = @($ownerGoLiveHandoffMissingChecks | Where-Object { $null -ne $_ }).Count
$ownerGoLiveHandoffPassed = $ownerGoLiveHandoffStatus -eq "passed" `
    -and $ownerGoLiveHandoffMissingCheckCount -eq 0 `
    -and $ownerGoLiveHandoffFailedCheckCount -eq 0 `
    -and $ownerGoLiveHandoffSecretFindingCount -eq 0 `
    -and $ownerGoLiveHandoffUnknownMissing.Count -eq 0 `
    -and $ownerGoLiveHandoffUnknownInvalid.Count -eq 0 `
    -and $ownerGoLiveHandoffInvalid.Count -eq 0 `
    -and $ownerGoLiveHandoffStageCount -ge 8 `
    -and $ownerGoLiveHandoffLaunchSequenceCount -ge 8 `
    -and $ownerGoLiveHandoffExpectedReportPathCount -ge 8 `
    -and $ownerGoLiveHandoffInvalidExpectedReportPaths.Count -eq 0 `
    -and $ownerGoLiveHandoffRollbackCommandCount -ge 4 `
    -and $ownerGoLiveHandoffMissingLaunchPackageScripts.Count -eq 0 `
    -and $ownerGoLiveHandoffMissingRollbackPackageScripts.Count -eq 0 `
    -and ((Get-AuditProp -Object $ownerGoLiveHandoff -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $ownerGoLiveHandoff -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $ownerGoLiveHandoff -Name "broadcasts" -Default $true) -eq $false)
$ownerEnvTemplateStatus = Get-ReportStatus -Report $ownerEnvTemplate
$ownerEnvTemplateGitIgnored = Get-AuditProp -Object $ownerEnvTemplate -Name "pathIsGitIgnored" -Default $false
$ownerEnvTemplateIncludesRequired = Get-AuditProp -Object $ownerEnvTemplate -Name "templateIncludesAllRequiredEnvNames" -Default $false
$ownerEnvTemplateRequiredCount = [int](Get-AuditProp -Object $ownerEnvTemplate -Name "requiredEnvNameCount" -Default 0)
$ownerEnvTemplateOptionalCount = @((Get-AuditProp -Object $ownerEnvTemplate -Name "optionalEnvNames" -Default @())).Count
$ownerEnvTemplateChecks = Get-AuditProp -Object $ownerEnvTemplate -Name "checks"
$ownerEnvTemplateFailedChecks = @((Get-AuditProp -Object $ownerEnvTemplate -Name "failedChecks" -Default @()))
$ownerEnvTemplateSecretFindings = @((Get-AuditProp -Object $ownerEnvTemplate -Name "secretMarkerFindings" -Default @()))
$ownerEnvTemplateRequiredChecks = @(
    "pathIsGitIgnored",
    "createdOrPreservedLocalFile",
    "templateIncludesAllRequiredEnvNames",
    "requiredEnvNameCountExpected",
    "optionalEnvNameCountExpected",
    "valuesPrintedFalse",
    "envValuesPrintedFalse",
    "noSecrets",
    "broadcastsFalse",
    "secretMarkerFindingsEmpty"
)
$ownerEnvTemplateMissingChecks = Get-MissingAuditChecks -Checks $ownerEnvTemplateChecks -Names $ownerEnvTemplateRequiredChecks
$ownerEnvTemplateFailedCheckCount = @($ownerEnvTemplateFailedChecks | Where-Object { $null -ne $_ }).Count
$ownerEnvTemplateSecretFindingCount = @($ownerEnvTemplateSecretFindings | Where-Object { $null -ne $_ }).Count
$ownerEnvTemplateMissingCheckCount = @($ownerEnvTemplateMissingChecks | Where-Object { $null -ne $_ }).Count
$ownerEnvTemplatePassed = $ownerEnvTemplateExitCode -eq 0 `
    -and $ownerEnvTemplateStatus -eq "passed" `
    -and $ownerEnvTemplateFailedCheckCount -eq 0 `
    -and $ownerEnvTemplateSecretFindingCount -eq 0 `
    -and $ownerEnvTemplateMissingCheckCount -eq 0 `
    -and $ownerEnvTemplateGitIgnored -eq $true `
    -and $ownerEnvTemplateIncludesRequired -eq $true `
    -and $ownerEnvTemplateRequiredCount -eq 17 `
    -and $ownerEnvTemplateOptionalCount -eq 2 `
    -and ((Get-AuditProp -Object $ownerEnvTemplate -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $ownerEnvTemplate -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $ownerEnvTemplate -Name "broadcasts" -Default $true) -eq $false)
$ownerEnvReadinessValidationStatus = Get-ReportStatus -Report $ownerEnvReadinessValidation
$ownerEnvReadinessValidationChecks = Get-AuditProp -Object $ownerEnvReadinessValidation -Name "checks"
$ownerEnvReadinessValidationMissingFails = Get-AuditProp -Object $ownerEnvReadinessValidationChecks -Name "missingOwnerEnvFileFailsBeforeChildGates" -Default $false
$ownerEnvReadinessValidationUnignoredFails = Get-AuditProp -Object $ownerEnvReadinessValidationChecks -Name "unignoredOwnerEnvFileFailsBeforeChildGates" -Default $false
$ownerEnvReadinessValidationFailedChecks = @((Get-AuditProp -Object $ownerEnvReadinessValidation -Name "failedChecks" -Default @()))
$ownerEnvReadinessValidationSecretFindings = @((Get-AuditProp -Object $ownerEnvReadinessValidation -Name "secretMarkerFindings" -Default @()))
$ownerEnvReadinessValidationRequiredChecks = @(
    "missingOwnerEnvFileFailsBeforeChildGates",
    "unignoredOwnerEnvFileFailsBeforeChildGates",
    "scenarioCountExpected",
    "allScenariosPassed",
    "failedScenariosAbsent",
    "envValuesPrintedFalse",
    "noSecrets",
    "broadcastsFalse",
    "secretMarkerFindingsEmpty"
)
$ownerEnvReadinessValidationMissingChecks = Get-MissingAuditChecks -Checks $ownerEnvReadinessValidationChecks -Names $ownerEnvReadinessValidationRequiredChecks
$ownerEnvReadinessValidationFailedCheckCount = @($ownerEnvReadinessValidationFailedChecks | Where-Object { $null -ne $_ }).Count
$ownerEnvReadinessValidationSecretFindingCount = @($ownerEnvReadinessValidationSecretFindings | Where-Object { $null -ne $_ }).Count
$ownerEnvReadinessValidationMissingCheckCount = @($ownerEnvReadinessValidationMissingChecks | Where-Object { $null -ne $_ }).Count
$ownerEnvReadinessValidationPassed = $ownerEnvReadinessValidationExitCode -eq 0 `
    -and $ownerEnvReadinessValidationStatus -eq "passed" `
    -and $ownerEnvReadinessValidationFailedCheckCount -eq 0 `
    -and $ownerEnvReadinessValidationSecretFindingCount -eq 0 `
    -and $ownerEnvReadinessValidationMissingCheckCount -eq 0 `
    -and $ownerEnvReadinessValidationMissingFails -eq $true `
    -and $ownerEnvReadinessValidationUnignoredFails -eq $true `
    -and ((Get-AuditProp -Object $ownerEnvReadinessValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $ownerEnvReadinessValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $ownerEnvReadinessValidation -Name "broadcasts" -Default $true) -eq $false)
$ownerEnvReadinessStatus = Get-ReportStatus -Report $ownerEnvReadiness
$ownerEnvReadinessState = Get-AuditProp -Object $ownerEnvReadiness -Name "readiness"
$ownerEnvReadinessBlockedOnlyKnown = Get-AuditProp -Object $ownerEnvReadinessState -Name "blockedOnlyOnKnownExternalOwnerInputs" -Default $false
$ownerEnvReadinessOwnerInputsReady = Get-AuditProp -Object $ownerEnvReadinessState -Name "ownerInputsReady" -Default $false
$ownerEnvReadinessLiveInfraReady = Get-AuditProp -Object $ownerEnvReadinessState -Name "liveInfraReady" -Default $false
$ownerEnvReadinessDeploymentReady = Get-AuditProp -Object $ownerEnvReadinessState -Name "publicDeploymentContractReady" -Default $false
$ownerEnvReadinessPath = Get-AuditProp -Object $ownerEnvReadiness -Name "ownerEnvFile"
$ownerEnvReadinessGitIgnored = Get-AuditProp -Object $ownerEnvReadinessPath -Name "gitIgnored" -Default $false
$ownerEnvReadinessKnownSafe = $ownerEnvReadinessExitCode -eq 0 `
    -and $ownerEnvReadinessGitIgnored -eq $true `
    -and ((Get-AuditProp -Object $ownerEnvReadiness -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $ownerEnvReadiness -Name "noSecrets" -Default $false) -eq $true) `
    -and ($ownerEnvReadinessStatus -eq "passed" -or ($ownerEnvReadinessStatus -eq "blocked" -and $ownerEnvReadinessBlockedOnlyKnown -eq $true))
$publicRpcEdgeTemplate = $reports.publicRpcEdgeTemplate
$publicRpcEdgeTemplateStatus = Get-ReportStatus -Report $publicRpcEdgeTemplate
$publicRpcEdgeTemplateReadyFlag = Get-AuditProp -Object $publicRpcEdgeTemplate -Name "edgeTemplateReady" -Default $false
$publicRpcEdgeTemplateRepoOwned = Get-AuditProp -Object $publicRpcEdgeTemplate -Name "flowChainRpcIsRepoOwned" -Default $false
$publicRpcEdgeTemplateThirdPartyNeeded = Get-AuditProp -Object $publicRpcEdgeTemplate -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$publicRpcEdgeTemplateRequiresTls = Get-AuditProp -Object $publicRpcEdgeTemplate -Name "requiresTlsTermination" -Default $false
$publicRpcEdgeTemplateRequiresRateLimit = Get-AuditProp -Object $publicRpcEdgeTemplate -Name "requiresRateLimit" -Default $false
$publicRpcEdgeTemplateForwardsOrigin = Get-AuditProp -Object $publicRpcEdgeTemplate -Name "forwardsOriginForCors" -Default $false
$publicRpcEdgeTemplatePassed = $publicRpcEdgeTemplateExitCode -eq 0 `
    -and $publicRpcEdgeTemplateStatus -eq "passed" `
    -and $publicRpcEdgeTemplateReadyFlag -eq $true `
    -and $publicRpcEdgeTemplateRepoOwned -eq $true `
    -and $publicRpcEdgeTemplateThirdPartyNeeded -eq $false `
    -and $publicRpcEdgeTemplateRequiresTls -eq $true `
    -and $publicRpcEdgeTemplateRequiresRateLimit -eq $true `
    -and $publicRpcEdgeTemplateForwardsOrigin -eq $true `
    -and ((Get-AuditProp -Object $publicRpcEdgeTemplate -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $publicRpcEdgeTemplate -Name "noSecrets" -Default $false) -eq $true)
$publicRpcDeploymentBundle = $reports.publicRpcDeploymentBundle
$publicRpcDeploymentBundleStatus = Get-ReportStatus -Report $publicRpcDeploymentBundle
$publicRpcDeploymentBundleChecks = Get-AuditProp -Object $publicRpcDeploymentBundle -Name "checks"
$publicRpcDeploymentBundleRepoOwned = Get-AuditProp -Object $publicRpcDeploymentBundle -Name "flowChainRpcIsRepoOwned" -Default $false
$publicRpcDeploymentBundleFailedChecks = @((Get-AuditProp -Object $publicRpcDeploymentBundle -Name "failedChecks" -Default @()))
$publicRpcDeploymentBundleSecretFindings = @((Get-AuditProp -Object $publicRpcDeploymentBundle -Name "secretMarkerFindings" -Default @()))
$publicRpcDeploymentBundleRequiredChecks = @(
    "edgeTemplatePassed",
    "readmeWritten",
    "nginxTemplateWritten",
    "systemdServiceTemplateWritten",
    "systemdSupervisorTemplateWritten",
    "renderScriptWritten",
    "nginxPreflightScriptWritten",
    "nginxPreflightChecklistWritten",
    "windowsNginxPreflightScriptWritten",
    "windowsNginxPreflightChecklistWritten",
    "ownerEnvExampleWritten",
    "verifyRunbookWritten",
    "rollbackRunbookWritten",
    "bundleChecksJsonWritten",
    "requiredPlaceholdersPresent",
    "nginxRequiredTokensPresent",
    "systemdLiveServiceTemplatePresent",
    "systemdSupervisorTemplatePresent",
    "renderScriptTokensPresent",
    "nginxPreflightTokensPresent",
    "windowsNginxPreflightTokensPresent",
    "ownerRenderValidationPassed",
    "ownerRenderCommandPassed",
    "ownerRenderFilesHaveNoPlaceholders",
    "ownerRenderWritesShellPreflight",
    "ownerRenderWritesWindowsPreflight",
    "ownerRenderDoesNotPrintTokenHash",
    "ownerRenderFilesDoNotContainTokenHash",
    "ownerRenderIncludesSecurityHeaders",
    "ownerRenderPreflightsRejectWrongMethods",
    "ownerRenderRejectsPublicUrlPath",
    "ownerRenderPublicUrlPathRejectOutputNoSecrets",
    "includesPrivateOrigin",
    "includesRateLimitPlaceholder",
    "includesTlsPlaceholders",
    "includesSecurityHeaders",
    "preflightsCheckSecurityHeaders",
    "includesMethodRejectionPreflight",
    "includesCorsOriginForwarding",
    "publicStateMirrorExcluded",
    "devnetStatePublicRpcExcluded",
    "includesNginxConfigTest",
    "includesWindowsNginxConfigTest",
    "includesTesterWritePreflight",
    "includesDisallowedOriginPreflight",
    "includesBroadStateBlockedPreflight",
    "includesPrivateWalletCreateBlockedPreflight",
    "authorizationForwardingScopedToTesterWrite",
    "includesVerificationCommands",
    "includesRollbackCommands",
    "envExampleHasAllRequiredNames",
    "ownerEnvExampleValuesBlank",
    "noLiveBroadcastCommands",
    "noLiveBroadcastArtifacts",
    "valuesNotPrinted",
    "envValuesNotPrinted",
    "noSecrets",
    "secretMarkerFindingsEmpty",
    "liveBroadcastsDisabled"
)
$publicRpcDeploymentBundleMissingChecks = Get-MissingAuditChecks -Checks $publicRpcDeploymentBundleChecks -Names $publicRpcDeploymentBundleRequiredChecks
$publicRpcDeploymentBundleFailedCheckCount = @($publicRpcDeploymentBundleFailedChecks | Where-Object { $null -ne $_ }).Count
$publicRpcDeploymentBundleSecretFindingCount = @($publicRpcDeploymentBundleSecretFindings | Where-Object { $null -ne $_ }).Count
$publicRpcDeploymentBundleMissingCheckCount = @($publicRpcDeploymentBundleMissingChecks | Where-Object { $null -ne $_ }).Count
$publicRpcDeploymentBundleNginxTemplate = Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "nginxTemplateWritten" -Default $false
$publicRpcDeploymentBundleVerifyRunbook = Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "verifyRunbookWritten" -Default $false
$publicRpcDeploymentBundleRollbackRunbook = Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "rollbackRunbookWritten" -Default $false
$publicRpcDeploymentBundleRenderValidation = Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "ownerRenderValidationPassed" -Default $false
$publicRpcDeploymentBundleTesterWritePreflight = Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "includesTesterWritePreflight" -Default $false
$publicRpcDeploymentBundlePassed = $publicRpcDeploymentBundleExitCode -eq 0 `
    -and $publicRpcDeploymentBundleStatus -eq "passed" `
    -and $publicRpcDeploymentBundleFailedCheckCount -eq 0 `
    -and $publicRpcDeploymentBundleSecretFindingCount -eq 0 `
    -and $publicRpcDeploymentBundleMissingCheckCount -eq 0 `
    -and ($publicRpcDeploymentBundleRepoOwned -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundle -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true) -eq $false) `
    -and ($publicRpcDeploymentBundleNginxTemplate -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "nginxPreflightScriptWritten" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "windowsNginxPreflightScriptWritten" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "ownerEnvExampleWritten" -Default $false) -eq $true) `
    -and ($publicRpcDeploymentBundleVerifyRunbook -eq $true) `
    -and ($publicRpcDeploymentBundleRollbackRunbook -eq $true) `
    -and ($publicRpcDeploymentBundleRenderValidation -eq $true) `
    -and ($publicRpcDeploymentBundleTesterWritePreflight -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "ownerRenderFilesHaveNoPlaceholders" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "ownerRenderDoesNotPrintTokenHash" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "includesSecurityHeaders" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "ownerRenderIncludesSecurityHeaders" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "ownerRenderPreflightsRejectWrongMethods" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "preflightsCheckSecurityHeaders" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "includesMethodRejectionPreflight" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "envExampleHasAllRequiredNames" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "secretMarkerFindingsEmpty" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundle -Name "valuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundle -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundle -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundle -Name "broadcasts" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundle -Name "liveBroadcasts" -Default $true) -eq $false)
$publicRpcDeploymentAutomation = $reports.publicRpcDeploymentAutomation
$publicRpcDeploymentAutomationStatus = Get-ReportStatus -Report $publicRpcDeploymentAutomation
$publicRpcDeploymentAutomationAction = [string](Get-AuditProp -Object $publicRpcDeploymentAutomation -Name "action" -Default "")
$publicRpcDeploymentAutomationChecks = Get-AuditProp -Object $publicRpcDeploymentAutomation -Name "checks"
$publicRpcDeploymentAutomationFailedChecks = @((Get-AuditProp -Object $publicRpcDeploymentAutomation -Name "failedChecks" -Default @()))
$publicRpcDeploymentAutomationSecretFindings = @((Get-AuditProp -Object $publicRpcDeploymentAutomation -Name "secretMarkerFindings" -Default @()))
$publicRpcDeploymentAutomationRequiredChecks = @(
    "bundleReportPassed",
    "renderScriptExists",
    "packageScriptPresent",
    "bundleHasOwnerRenderValidation",
    "bundleHasShellPreflight",
    "bundleHasWindowsPreflight",
    "bundleHasRollbackRunbook",
    "bundlePreflightsCheckMethodRejection",
    "ownerPathsOutsideRepo",
    "hostMutationPerformedFalse",
    "valuesPrintedFalse",
    "envValuesPrintedFalse",
    "noSecrets",
    "secretMarkerFindingsEmpty",
    "broadcastsFalse",
    "liveBroadcastsFalse",
    "renderCommandPassed",
    "renderedFilesHaveNoPlaceholders",
    "renderedFilesKeepPrivateOrigin",
    "renderedNginxHasTls",
    "renderedNginxHasCorsForwarding",
    "renderedNginxHasRateLimit",
    "renderedNginxHasSecurityHeaders",
    "renderedSystemdUsesOwnerEnv",
    "renderedPreflightHasReadinessProbe",
    "renderedPreflightHasTesterUnauthProbe",
    "renderedPreflightHasDisallowedOriginProbe",
    "renderedPreflightChecksSecurityHeaders",
    "renderedPreflightHasMethodRejectionProbes",
    "renderedPreflightBlocksBroadStatePath",
    "renderedPreflightBlocksPrivateWalletCreate",
    "renderedNginxAuthorizationForwardingScoped",
    "renderedFilesDoNotContainTokenHash",
    "renderedReportDoesNotContainTokenHash",
    "renderedReportKeepsOwnerPathsOutsideRepo",
    "renderedReportNoSecrets",
    "renderedReportBroadcastsFalse",
    "renderedReportSummaryPresent",
    "renderedReportSummaryPassed",
    "renderedReportSummaryListsFiles",
    "renderedReportSummaryHasRequiredEnvNames",
    "renderedReportSummaryNoSecrets",
    "renderedReportSummaryBroadcastsFalse",
    "renderedReportSummaryOwnerPathsOutsideRepo",
    "renderedReportSnapshotWritten",
    "renderedReportSnapshotNoSecrets",
    "renderedOwnerHostApplyScriptWritten",
    "renderedOwnerHostApplyScriptHasPlanApplyRollback",
    "renderedOwnerHostApplyScriptVerifiesHashes",
    "renderedOwnerHostApplyScriptRunsPostDeployProof",
    "ownerHostApplyPlanPresent",
    "ownerHostApplyPlanSchema",
    "ownerHostApplyPlanRepoOwned",
    "ownerHostApplyPlanPrivateOrigin",
    "ownerHostApplyPlanArtifactManifestCount",
    "ownerHostApplyPlanAllArtifactsListed",
    "ownerHostApplyPlanArtifactsExist",
    "ownerHostApplyPlanArtifactsHaveSha256",
    "ownerHostApplyPlanInstallTargetsMapped",
    "ownerHostApplyPlanPhaseCount",
    "ownerHostApplyPlanAllPhasesPresent",
    "ownerHostApplyPlanHasMutatingInstallPhase",
    "ownerHostApplyPlanHasMutatingEdgePhase",
    "ownerHostApplyPlanHasReadOnlyProofPhase",
    "ownerHostApplyPlanIncludesSystemdInstallCommand",
    "ownerHostApplyPlanIncludesSystemdStatusCommand",
    "ownerHostApplyPlanIncludesSystemdUninstallRollback",
    "ownerHostApplyPlanIncludesNginxReload",
    "ownerHostApplyPlanIncludesOwnerApplyScript",
    "ownerHostApplyPlanIncludesPostDeployEvidence",
    "ownerHostApplyPlanValuesPrintedFalse",
    "ownerHostApplyPlanEnvValuesPrintedFalse",
    "ownerHostApplyPlanNoSecrets",
    "ownerHostApplyPlanBroadcastsFalse",
    "commandPlanIncludesTesterGatewayE2e",
    "commandPlanIncludesWalletTesterE2e",
    "commandPlanIncludesSyntheticCanary",
    "commandPlanIncludesCutoverRehearsal",
    "commandPlanIncludesTruthTable",
    "commandPlanIncludesNoSecretScan",
    "rollbackDrillPerformed",
    "rollbackRenderedConfigExists",
    "rollbackPreviousConfigWritten",
    "rollbackRenderedConfigRestoredFromPrevious",
    "rollbackOriginalConfigRestoredAfterDrill",
    "rollbackArtifactsStayedInsideRenderDir",
    "rollbackDrillNoSecrets",
    "rollbackDrillBroadcastsFalse",
    "cleanupAttempted"
)
$publicRpcDeploymentAutomationMissingChecks = Get-MissingAuditChecks -Checks $publicRpcDeploymentAutomationChecks -Names $publicRpcDeploymentAutomationRequiredChecks
$publicRpcDeploymentAutomationFailedCheckCount = @($publicRpcDeploymentAutomationFailedChecks | Where-Object { $null -ne $_ }).Count
$publicRpcDeploymentAutomationSecretFindingCount = @($publicRpcDeploymentAutomationSecretFindings | Where-Object { $null -ne $_ }).Count
$publicRpcDeploymentAutomationMissingCheckCount = @($publicRpcDeploymentAutomationMissingChecks | Where-Object { $null -ne $_ }).Count
$publicRpcDeploymentAutomationPassed = $publicRpcDeploymentAutomationExitCode -eq 0 `
    -and $publicRpcDeploymentAutomationStatus -eq "passed" `
    -and ($publicRpcDeploymentAutomationAction -eq "Validate") `
    -and $publicRpcDeploymentAutomationFailedCheckCount -eq 0 `
    -and $publicRpcDeploymentAutomationSecretFindingCount -eq 0 `
    -and $publicRpcDeploymentAutomationMissingCheckCount -eq 0 `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderCommandPassed" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "bundlePreflightsCheckMethodRejection" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedFilesHaveNoPlaceholders" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedFilesKeepPrivateOrigin" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedNginxHasTls" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedNginxHasCorsForwarding" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedNginxHasRateLimit" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedNginxHasSecurityHeaders" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedSystemdUsesOwnerEnv" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightHasReadinessProbe" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightHasTesterUnauthProbe" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightChecksSecurityHeaders" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightHasMethodRejectionProbes" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedReportSummaryPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedReportSummaryPassed" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedReportSummaryListsFiles" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedReportSummaryHasRequiredEnvNames" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedReportSummaryNoSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedReportSummaryBroadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedReportSummaryOwnerPathsOutsideRepo" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedReportSnapshotWritten" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedReportSnapshotNoSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedOwnerHostApplyScriptWritten" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedOwnerHostApplyScriptHasPlanApplyRollback" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedOwnerHostApplyScriptVerifiesHashes" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedOwnerHostApplyScriptRunsPostDeployProof" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "ownerHostApplyPlanPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "ownerHostApplyPlanArtifactsHaveSha256" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "ownerHostApplyPlanInstallTargetsMapped" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "ownerHostApplyPlanHasMutatingInstallPhase" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "ownerHostApplyPlanHasMutatingEdgePhase" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "ownerHostApplyPlanHasReadOnlyProofPhase" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "ownerHostApplyPlanIncludesSystemdInstallCommand" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "ownerHostApplyPlanIncludesSystemdUninstallRollback" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "ownerHostApplyPlanIncludesNginxReload" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "ownerHostApplyPlanIncludesOwnerApplyScript" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "ownerHostApplyPlanIncludesPostDeployEvidence" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "rollbackDrillPerformed" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "rollbackRenderedConfigRestoredFromPrevious" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "rollbackOriginalConfigRestoredAfterDrill" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "rollbackArtifactsStayedInsideRenderDir" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "rollbackDrillNoSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "rollbackDrillBroadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "hostMutationPerformedFalse" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "secretMarkerFindingsEmpty" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomation -Name "valuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomation -Name "broadcasts" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentAutomation -Name "liveBroadcasts" -Default $true) -eq $false)
$operatorPackage = $reports.operatorPackage
$operatorPackageStatus = Get-ReportStatus -Report $operatorPackage
$operatorPackageChecks = Get-AuditProp -Object $operatorPackage -Name "checks"
$operatorPackageFailedChecks = @((Get-AuditProp -Object $operatorPackage -Name "failedChecks" -Default @()))
$operatorPackageSecretFindings = @((Get-AuditProp -Object $operatorPackage -Name "secretMarkerFindings" -Default @()))
$operatorPackageCommandCount = [int](Get-AuditProp -Object $operatorPackage -Name "commandCount" -Default 0)
$operatorPackageRunbookCount = [int](Get-AuditProp -Object $operatorPackage -Name "runbookCount" -Default 0)
$operatorPackageEvidenceReportCount = [int](Get-AuditProp -Object $operatorPackage -Name "evidenceReportCount" -Default 0)
$operatorPackageSecretFindingCount = @($operatorPackageSecretFindings | Where-Object { $null -ne $_ }).Count
$operatorPackagePassed = $operatorPackageExitCode -eq 0 `
    -and $operatorPackageStatus -eq "passed" `
    -and $operatorPackageFailedChecks.Count -eq 0 `
    -and $operatorPackageSecretFindingCount -eq 0 `
    -and $operatorPackageCommandCount -ge 20 `
    -and $operatorPackageRunbookCount -ge 10 `
    -and $operatorPackageEvidenceReportCount -ge 15 `
    -and ((Get-AuditProp -Object $operatorPackageChecks -Name "packageScriptsPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $operatorPackageChecks -Name "commandMatrixWritten" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $operatorPackageChecks -Name "runbookDocsCopied" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $operatorPackageChecks -Name "evidenceReportsCopied" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $operatorPackageChecks -Name "ownerInputNamesOnly" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $operatorPackageChecks -Name "flowChainRpcIsRepoOwned" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $operatorPackageChecks -Name "thirdPartyFlowChainRpcProviderNeededFalse" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $operatorPackageChecks -Name "noSecretScanPassed" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $operatorPackageChecks -Name "secretMarkerFindingsEmpty" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $operatorPackage -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $operatorPackage -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $operatorPackage -Name "broadcasts" -Default $true) -eq $false)
$operatorPackageVerify = $reports.operatorPackageVerify
$operatorPackageVerifyStatus = Get-ReportStatus -Report $operatorPackageVerify
$operatorPackageVerifyChecks = Get-AuditProp -Object $operatorPackageVerify -Name "checks"
$operatorPackageVerifyFailedChecks = @((Get-AuditProp -Object $operatorPackageVerify -Name "failedChecks" -Default @()))
$operatorPackageVerifySecretFindings = @((Get-AuditProp -Object $operatorPackageVerify -Name "secretMarkerFindings" -Default @()))
$operatorPackageVerifyExpectedFileCount = [int](Get-AuditProp -Object $operatorPackageVerify -Name "expectedFileCount" -Default 0)
$operatorPackageVerifyCommandCount = [int](Get-AuditProp -Object $operatorPackageVerify -Name "commandCount" -Default 0)
$operatorPackageVerifyGoLiveEvidenceCount = [int](Get-AuditProp -Object $operatorPackageVerify -Name "goLiveExpectedPackageEvidenceCount" -Default 0)
$operatorPackageVerifyMissingGoLiveEvidence = @((Get-AuditProp -Object $operatorPackageVerify -Name "missingGoLivePackageEvidence" -Default @()))
$operatorPackageVerifyGoLiveEvidenceNotInManifest = @((Get-AuditProp -Object $operatorPackageVerify -Name "goLivePackageEvidenceNotInManifest" -Default @()))
$operatorPackageVerifySecretFindingCount = @($operatorPackageVerifySecretFindings | Where-Object { $null -ne $_ }).Count
$operatorPackageVerifyPassed = $operatorPackageVerifyExitCode -eq 0 `
    -and $operatorPackageVerifyStatus -eq "passed" `
    -and $operatorPackageVerifyFailedChecks.Count -eq 0 `
    -and $operatorPackageVerifySecretFindingCount -eq 0 `
    -and $operatorPackageVerifyExpectedFileCount -ge 20 `
    -and $operatorPackageVerifyCommandCount -ge 20 `
    -and $operatorPackageVerifyGoLiveEvidenceCount -ge 30 `
    -and $operatorPackageVerifyMissingGoLiveEvidence.Count -eq 0 `
    -and $operatorPackageVerifyGoLiveEvidenceNotInManifest.Count -eq 0 `
    -and ((Get-AuditProp -Object $operatorPackageVerifyChecks -Name "packageReportPassed" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $operatorPackageVerifyChecks -Name "expectedFilesPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $operatorPackageVerifyChecks -Name "goLiveHandoffEvidencePresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $operatorPackageVerifyChecks -Name "goLiveExpectedEvidencePathsPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $operatorPackageVerifyChecks -Name "goLiveExpectedEvidenceInManifest" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $operatorPackageVerifyChecks -Name "ownerInputNamesOnly" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $operatorPackageVerifyChecks -Name "noForbiddenLocalFiles" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $operatorPackageVerifyChecks -Name "noSecretScanPassed" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $operatorPackageVerifyChecks -Name "secretMarkerFindingsEmpty" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $operatorPackageVerify -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $operatorPackageVerify -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $operatorPackageVerify -Name "broadcasts" -Default $true) -eq $false)
$ownerInputsValidationStatus = Get-ReportStatus -Report $ownerInputsValidation
$ownerInputsValidationChecks = Get-AuditProp -Object $ownerInputsValidation -Name "checks"
$ownerInputsValidationMissingBlocks = Get-AuditProp -Object $ownerInputsValidationChecks -Name "missingScenarioBlocks" -Default $false
$ownerInputsValidationInvalidFails = Get-AuditProp -Object $ownerInputsValidationChecks -Name "invalidScenarioFails" -Default $false
$ownerInputsValidationValidPasses = Get-AuditProp -Object $ownerInputsValidationChecks -Name "validStructureScenarioPasses" -Default $false
$ownerInputsValidationEnvFilePasses = Get-AuditProp -Object $ownerInputsValidationChecks -Name "validOwnerEnvFileScenarioPasses" -Default $false
$ownerInputsValidationMissingEnvFileFails = Get-AuditProp -Object $ownerInputsValidationChecks -Name "missingOwnerEnvFileScenarioFails" -Default $false
$ownerInputsValidationMalformedEnvFileFails = Get-AuditProp -Object $ownerInputsValidationChecks -Name "malformedOwnerEnvFileScenarioFails" -Default $false
$ownerInputsValidationPassed = $ownerInputsValidationExitCode -eq 0 `
    -and $ownerInputsValidationStatus -eq "passed" `
    -and $ownerInputsValidationMissingBlocks -eq $true `
    -and $ownerInputsValidationInvalidFails -eq $true `
    -and $ownerInputsValidationValidPasses -eq $true `
    -and $ownerInputsValidationEnvFilePasses -eq $true `
    -and $ownerInputsValidationMissingEnvFileFails -eq $true `
    -and $ownerInputsValidationMalformedEnvFileFails -eq $true
$publicRpcValidationStatus = Get-ReportStatus -Report $publicRpcValidation
$publicRpcValidationChecks = Get-AuditProp -Object $publicRpcValidation -Name "checks"
$publicRpcValidationFailedChecks = @((Get-AuditProp -Object $publicRpcValidation -Name "failedChecks" -Default @()))
$publicRpcValidationSecretFindings = @((Get-AuditProp -Object $publicRpcValidation -Name "secretMarkerFindings" -Default @()))
$publicRpcValidationAllowed = Get-AuditProp -Object $publicRpcValidationChecks -Name "allowedOriginAccepted" -Default $false
$publicRpcValidationDisallowedProbe = Get-AuditProp -Object $publicRpcValidationChecks -Name "disallowedOriginProbePerformed" -Default $false
$publicRpcValidationDisallowedRejected = Get-AuditProp -Object $publicRpcValidationChecks -Name "disallowedOriginRejected" -Default $false
$publicRpcValidationSecurityHeaderSkip = Get-AuditProp -Object $publicRpcValidationChecks -Name "securityHeaderProbeSkippedForLocalEndpoint" -Default $false
$publicRpcValidationSecurityHeaderPolicy = Get-AuditProp -Object $publicRpcValidationChecks -Name "securityHeaderPassRequiredOnlyForPublicMode" -Default $false
$publicRpcValidationEndpointChecks = Get-AuditProp -Object $publicRpcValidationChecks -Name "noFailedEndpointChecks" -Default $false
$publicRpcValidationRateLimitProbe = Get-AuditProp -Object $publicRpcValidationChecks -Name "rateLimitProbePerformed" -Default $false
$publicRpcValidationRateLimitRejected = Get-AuditProp -Object $publicRpcValidationChecks -Name "rateLimitRejected" -Default $false
$publicRpcValidationRateLimitRetryAfter = Get-AuditProp -Object $publicRpcValidationChecks -Name "rateLimitRetryAfterHeaderPresent" -Default $false
$publicRpcValidationHygiene = Get-AuditProp -Object $publicRpcValidationChecks -Name "responseHygienePassed" -Default $false
$publicRpcValidationSecretFindingsEmpty = Get-AuditProp -Object $publicRpcValidationChecks -Name "secretMarkerFindingsEmpty" -Default $false
$publicRpcValidationFailedCheckCount = $publicRpcValidationFailedChecks.Count
$publicRpcValidationSecretFindingCount = $publicRpcValidationSecretFindings.Count
$publicRpcValidationPassed = $publicRpcValidationExitCode -eq 0 `
    -and $publicRpcValidationStatus -eq "passed" `
    -and $publicRpcValidationFailedCheckCount -eq 0 `
    -and $publicRpcValidationSecretFindingCount -eq 0 `
    -and $publicRpcValidationAllowed -eq $true `
    -and $publicRpcValidationDisallowedProbe -eq $true `
    -and $publicRpcValidationDisallowedRejected -eq $true `
    -and $publicRpcValidationSecurityHeaderSkip -eq $true `
    -and $publicRpcValidationSecurityHeaderPolicy -eq $true `
    -and $publicRpcValidationEndpointChecks -eq $true `
    -and $publicRpcValidationRateLimitProbe -eq $true `
    -and $publicRpcValidationRateLimitRejected -eq $true `
    -and $publicRpcValidationRateLimitRetryAfter -eq $true `
    -and $publicRpcValidationHygiene -eq $true `
    -and $publicRpcValidationSecretFindingsEmpty -eq $true `
    -and ((Get-AuditProp -Object $publicRpcValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $publicRpcValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcValidation -Name "broadcasts" -Default $true) -eq $false)
$publicRpcAbuseTestStatus = Get-ReportStatus -Report $publicRpcAbuseTest
$publicRpcAbuseTestReady = Get-AuditProp -Object $publicRpcAbuseTest -Name "abuseTestReady" -Default $false
$publicRpcAbuseTestChecks = Get-AuditProp -Object $publicRpcAbuseTest -Name "checks"
$publicRpcAbuseFailedChecks = @((Get-AuditProp -Object $publicRpcAbuseTest -Name "failedChecks" -Default @()))
$publicRpcAbuseSecretFindings = @((Get-AuditProp -Object $publicRpcAbuseTest -Name "secretMarkerFindings" -Default @()))
$publicRpcAbuseFailedCheckCount = $publicRpcAbuseFailedChecks.Count
$publicRpcAbuseSecretFindingCount = $publicRpcAbuseSecretFindings.Count
$publicRpcAbuseRequiredChecks = @(
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
    "testerWriteGatewayFailsClosed",
    "badParamsRejected",
    "emptyBatchRejected",
    "oversizedBatchRejected",
    "oversizedBodyRejected",
    "notificationNoContent",
    "rateLimitRejected",
    "responseHygienePassed",
    "failedCasesAbsent",
    "fatalErrorAbsent",
    "secretMarkerFindingsEmpty",
    "envValuesPrintedFalse",
    "noSecrets",
    "noLiveBroadcast",
    "broadcastsFalse"
)
$publicRpcAbuseMissingChecks = @($publicRpcAbuseRequiredChecks | Where-Object { (Get-AuditProp -Object $publicRpcAbuseTestChecks -Name $_ -Default $false) -ne $true })
$publicRpcAbuseTestPassed = $publicRpcAbuseTestExitCode -eq 0 `
    -and $publicRpcAbuseTestStatus -eq "passed" `
    -and $publicRpcAbuseTestReady -eq $true `
    -and $publicRpcAbuseFailedCheckCount -eq 0 `
    -and $publicRpcAbuseSecretFindingCount -eq 0 `
    -and $publicRpcAbuseMissingChecks.Count -eq 0 `
    -and ((Get-AuditProp -Object $publicRpcAbuseTest -Name "ownerValuesRequired" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $publicRpcAbuseTest -Name "noLiveBroadcast" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcAbuseTest -Name "broadcasts" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $publicRpcAbuseTest -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $publicRpcAbuseTest -Name "noSecrets" -Default $false) -eq $true)
$publicRpcSyntheticCanaryStatus = Get-ReportStatus -Report $publicRpcSyntheticCanary
$publicRpcSyntheticCanaryChecks = Get-AuditProp -Object $publicRpcSyntheticCanary -Name "checks"
$publicRpcSyntheticCanaryFailedChecks = @((Get-AuditProp -Object $publicRpcSyntheticCanary -Name "failedChecks" -Default @()))
$publicRpcSyntheticCanarySecretFindings = @((Get-AuditProp -Object $publicRpcSyntheticCanary -Name "secretMarkerFindings" -Default @()))
$publicRpcSyntheticCanaryMissingEnvNames = @((Get-AuditProp -Object $publicRpcSyntheticCanary -Name "missingEnvNames" -Default @()))
$publicRpcSyntheticCanaryReady = (Get-AuditProp -Object $publicRpcSyntheticCanary -Name "syntheticCanaryReady" -Default $false) -eq $true
$publicRpcSyntheticCanaryOwnerBlocked = (Get-AuditProp -Object $publicRpcSyntheticCanary -Name "blockedOnlyOnKnownExternalOwnerInputs" -Default $false) -eq $true
$publicRpcSyntheticCanaryNoWriteMethods = ((Get-AuditProp -Object $publicRpcSyntheticCanaryChecks -Name "noWriteMethodsPlanned" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcSyntheticCanaryChecks -Name "noWriteMethodsInvoked" -Default $false) -eq $true)
$publicRpcSyntheticCanaryReadPlanCovered = ((Get-AuditProp -Object $publicRpcSyntheticCanaryChecks -Name "plannedReadPathsCovered" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcSyntheticCanaryChecks -Name "plannedReadMethodsCovered" -Default $false) -eq $true)
$publicRpcSyntheticCanarySafe = $publicRpcSyntheticCanaryExitCode -eq 0 `
    -and $publicRpcSyntheticCanaryStatus -in @("passed", "blocked") `
    -and $publicRpcSyntheticCanaryFailedChecks.Count -eq 0 `
    -and $publicRpcSyntheticCanarySecretFindings.Count -eq 0 `
    -and $publicRpcSyntheticCanaryNoWriteMethods `
    -and $publicRpcSyntheticCanaryReadPlanCovered `
    -and ((Get-AuditProp -Object $publicRpcSyntheticCanaryChecks -Name "safeReadMethodAllowlistEnforced" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcSyntheticCanaryChecks -Name "responseHygienePassed" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcSyntheticCanary -Name "endpointValuePrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $publicRpcSyntheticCanary -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $publicRpcSyntheticCanary -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcSyntheticCanary -Name "broadcasts" -Default $true) -eq $false)
$publicRpcSyntheticCanaryPassed = $publicRpcSyntheticCanarySafe -and $publicRpcSyntheticCanaryStatus -eq "passed" -and $publicRpcSyntheticCanaryReady
$publicRpcSyntheticCanaryBlockedSafe = $publicRpcSyntheticCanarySafe -and $publicRpcSyntheticCanaryStatus -eq "blocked" -and $publicRpcSyntheticCanaryOwnerBlocked
$testerWriteTokenSetup = $reports.testerWriteTokenSetup
$testerWriteTokenSetupStatus = Get-ReportStatus -Report $testerWriteTokenSetup
$testerWriteTokenSetupChecks = Get-AuditProp -Object $testerWriteTokenSetup -Name "checks"
$testerWriteTokenSetupRequiredChecks = @(
    "tokenPathGitIgnored",
    "ownerEnvPathGitIgnored",
    "tokenFileExists",
    "ownerEnvFileExists",
    "tokenLengthSufficient",
    "tokenHashLengthValid",
    "ownerEnvTesterEnabledWritten",
    "ownerEnvTesterHashWritten",
    "ownerEnvTesterCapWritten",
    "rawTokenPrintedFalse",
    "tokenHashPrintedFalse",
    "envValuesPrintedFalse",
    "noSecrets",
    "broadcastsFalse",
    "secretMarkerFindingsEmpty"
)
$testerWriteTokenSetupFailedChecks = @((Get-AuditProp -Object $testerWriteTokenSetup -Name "failedChecks" -Default @()))
$testerWriteTokenSetupSecretFindings = @((Get-AuditProp -Object $testerWriteTokenSetup -Name "secretMarkerFindings" -Default @()))
$testerWriteTokenSetupMissingChecks = @($testerWriteTokenSetupRequiredChecks | Where-Object {
    (Get-AuditProp -Object $testerWriteTokenSetupChecks -Name $_ -Default $false) -ne $true
})
$testerWriteTokenSetupPassed = $testerWriteTokenSetupExitCode -eq 0 `
    -and $testerWriteTokenSetupStatus -eq "passed" `
    -and $testerWriteTokenSetupFailedChecks.Count -eq 0 `
    -and $testerWriteTokenSetupSecretFindings.Count -eq 0 `
    -and $testerWriteTokenSetupMissingChecks.Count -eq 0 `
    -and ((Get-AuditProp -Object $testerWriteTokenSetup -Name "maxSendUnitsConfigured" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $testerWriteTokenSetup -Name "rawTokenPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $testerWriteTokenSetup -Name "tokenHashPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $testerWriteTokenSetup -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $testerWriteTokenSetup -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $testerWriteTokenSetup -Name "broadcasts" -Default $true) -eq $false)
$publicTesterGatewayStatus = Get-ReportStatus -Report $publicTesterGateway
$publicTesterGatewayPassed = $publicTesterGatewayExitCode -eq 0 `
    -and $publicTesterGatewayStatus -eq "passed" `
    -and ((Get-AuditProp -Object $publicTesterGateway -Name "testerGatewayConfigured" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicTesterGateway -Name "testerWriteTokenHashConfigured" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicTesterGateway -Name "transferAccepted" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicTesterGateway -Name "capRejected" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicTesterGateway -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $publicTesterGateway -Name "noSecrets" -Default $false) -eq $true)
$dashboardUiReadiness = $reports.dashboardUiReadiness
$dashboardUiReadinessStatus = Get-ReportStatus -Report $dashboardUiReadiness
$dashboardUiReadinessChecks = Get-AuditProp -Object $dashboardUiReadiness -Name "checks"
$dashboardUiRequiredChecks = @(
    "dashboardPackageScriptPresent",
    "rootPackageScriptPresent",
    "playwrightConfigExists",
    "browserSpecExists",
    "desktopProjectConfigured",
    "mobileProjectConfigured",
    "walletTesterRouteCovered",
    "testerWalletCreateCovered",
    "testerFaucetCovered",
    "testerSendCovered",
    "explorerRouteCovered",
    "testerLaunchRouteCovered",
    "activationRouteCovered",
    "bridgeRouteCovered",
    "bridgePilotRuntimeProofCovered",
    "bridgeRuntimeCreditProofCovered",
    "realValuePilotAggregateProofCovered",
    "publicRpcHeaderProofCovered",
    "noSecretLeakageAsserted",
    "noHorizontalOverflowAsserted",
    "dashboardUnitTestsPassed",
    "dashboardBrowserE2ePassed",
    "dashboardBuildPassed",
    "controlPlaneTesterGatewayTestsPassed",
    "commandsCompletedWithoutTimeout",
    "secretMarkerFindingsEmpty",
    "envValuesPrintedFalse",
    "noSecrets",
    "broadcastsFalse"
)
$dashboardUiMissingChecks = @($dashboardUiRequiredChecks | Where-Object {
    (Get-AuditProp -Object $dashboardUiReadinessChecks -Name $_ -Default $false) -ne $true
})
$dashboardUiFailedChecks = @((Get-AuditProp -Object $dashboardUiReadiness -Name "failedChecks" -Default @()))
$dashboardUiSecretFindings = @((Get-AuditProp -Object $dashboardUiReadiness -Name "secretMarkerFindings" -Default @()))
$dashboardUiSecretFindingCount = @($dashboardUiSecretFindings | Where-Object { $null -ne $_ }).Count
$dashboardUiBrowserProjects = @((Get-AuditProp -Object $dashboardUiReadiness -Name "browserProjects" -Default @()))
$dashboardUiCoveredRoutes = @((Get-AuditProp -Object $dashboardUiReadiness -Name "coveredRoutes" -Default @()))
$dashboardUiCoveredProofs = @((Get-AuditProp -Object $dashboardUiReadiness -Name "coveredProofs" -Default @()))
$dashboardUiRequiredBrowserProjects = @("chromium-desktop", "chromium-mobile")
$dashboardUiMissingBrowserProjects = @($dashboardUiRequiredBrowserProjects | Where-Object { $_ -notin $dashboardUiBrowserProjects })
$dashboardUiRequiredRoutes = @("/wallet?panel=tester", "/tester/wallets/create", "/tester/faucet", "/tester/wallets/send", "/explorer", "/tester", "/activation", "/bridge")
$dashboardUiMissingRoutes = @($dashboardUiRequiredRoutes | Where-Object { $_ -notin $dashboardUiCoveredRoutes })
$dashboardUiRequiredProofs = @("base8453-bridge-runtime-credit-proof", "real-value-pilot-aggregate-proof")
$dashboardUiMissingProofs = @($dashboardUiRequiredProofs | Where-Object { $_ -notin $dashboardUiCoveredProofs })
$dashboardUiReadinessPassed = $dashboardUiReadinessExitCode -eq 0 `
    -and $dashboardUiReadinessStatus -eq "passed" `
    -and $dashboardUiMissingChecks.Count -eq 0 `
    -and $dashboardUiFailedChecks.Count -eq 0 `
    -and $dashboardUiSecretFindingCount -eq 0 `
    -and $dashboardUiBrowserProjects.Count -ge 2 `
    -and $dashboardUiMissingBrowserProjects.Count -eq 0 `
    -and $dashboardUiCoveredRoutes.Count -ge 8 `
    -and $dashboardUiMissingRoutes.Count -eq 0 `
    -and $dashboardUiCoveredProofs.Count -ge 2 `
    -and $dashboardUiMissingProofs.Count -eq 0 `
    -and ((Get-AuditProp -Object $dashboardUiReadiness -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $dashboardUiReadiness -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $dashboardUiReadiness -Name "broadcasts" -Default $true) -eq $false)
$secondComputerReadiness = $reports.secondComputerReadiness
$secondComputerReadinessStatus = Get-ReportStatus -Report $secondComputerReadiness
$secondComputerReadinessChecks = Get-AuditProp -Object $secondComputerReadiness -Name "checks"
$secondComputerRequiredChecks = @(
    "bundlePackageScriptPresent",
    "verifyPackageScriptPresent",
    "readinessPackageScriptPresent",
    "setupDocExists",
    "setupDocMentionsBundle",
    "setupDocMentionsVerify",
    "bundleCommandPassed",
    "verifyCommandPassed",
    "bundleReportPassed",
    "verifyReportPassed",
    "stageNoSecretScanPassed",
    "bundleZipCreated",
    "bundleSha256Present",
    "manifestWritten",
    "manifestNextCommandsPresent",
    "excludesGitMetadata",
    "excludesNodeModules",
    "excludesLocalRuntime",
    "excludesEnvFiles",
    "excludesSecretMarkerFiles",
    "verifyChecksPassed",
    "secretMarkerFindingsEmpty",
    "envValuesPrintedFalse",
    "noSecrets",
    "broadcastsFalse"
)
$secondComputerMissingChecks = @($secondComputerRequiredChecks | Where-Object {
    (Get-AuditProp -Object $secondComputerReadinessChecks -Name $_ -Default $false) -ne $true
})
$secondComputerFailedChecks = @((Get-AuditProp -Object $secondComputerReadiness -Name "failedChecks" -Default @()))
$secondComputerMissingNextCommands = @((Get-AuditProp -Object $secondComputerReadiness -Name "missingNextCommands" -Default @()))
$secondComputerFailedVerifyChecks = @((Get-AuditProp -Object $secondComputerReadiness -Name "failedVerifyChecks" -Default @()))
$secondComputerSecretFindings = @((Get-AuditProp -Object $secondComputerReadiness -Name "secretMarkerFindings" -Default @()))
$secondComputerSecretFindingCount = @($secondComputerSecretFindings | Where-Object { $null -ne $_ }).Count
$secondComputerReadinessPassed = $secondComputerReadinessExitCode -eq 0 `
    -and $secondComputerReadinessStatus -eq "passed" `
    -and $secondComputerMissingChecks.Count -eq 0 `
    -and $secondComputerFailedChecks.Count -eq 0 `
    -and $secondComputerMissingNextCommands.Count -eq 0 `
    -and $secondComputerFailedVerifyChecks.Count -eq 0 `
    -and $secondComputerSecretFindingCount -eq 0 `
    -and ((Get-AuditProp -Object $secondComputerReadiness -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $secondComputerReadiness -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $secondComputerReadiness -Name "broadcasts" -Default $true) -eq $false)
$backupRestoreValidation = $reports.backupRestoreValidation
$backupRestoreValidationStatus = Get-ReportStatus -Report $backupRestoreValidation
$backupRestoreValidationChecks = Get-AuditProp -Object $backupRestoreValidation -Name "checks"
$backupRestoreValidationFailedChecks = @((Get-AuditProp -Object $backupRestoreValidation -Name "failedChecks" -Default @()))
$backupRestoreValidationSecretFindings = @((Get-AuditProp -Object $backupRestoreValidation -Name "secretMarkerFindings" -Default @()))
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
    "valuesPrintedFalse",
    "envValuesPrintedFalse",
    "noSecrets",
    "secretMarkerFindingsEmpty",
    "broadcastsFalse"
)
$backupRestoreValidationMissingChecks = @($backupRestoreValidationRequiredChecks | Where-Object {
    (Get-AuditProp -Object $backupRestoreValidationChecks -Name $_ -Default $false) -ne $true
})
$backupRestoreValidationFailedCheckCount = @($backupRestoreValidationFailedChecks | Where-Object { $null -ne $_ }).Count
$backupRestoreValidationSecretFindingCount = @($backupRestoreValidationSecretFindings | Where-Object { $null -ne $_ }).Count
$backupRestoreValidationMissingCheckCount = @($backupRestoreValidationMissingChecks | Where-Object { $null -ne $_ }).Count
$backupRestoreValidationPassed = $backupRestoreValidationExitCode -eq 0 `
    -and $backupRestoreValidationStatus -eq "passed" `
    -and $backupRestoreValidationFailedCheckCount -eq 0 `
    -and $backupRestoreValidationSecretFindingCount -eq 0 `
    -and $backupRestoreValidationMissingCheckCount -eq 0 `
    -and ((Get-AuditProp -Object $backupRestoreValidation -Name "valuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $backupRestoreValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $backupRestoreValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $backupRestoreValidation -Name "broadcasts" -Default $true) -eq $false)
$backupOwnerPathDryRun = $reports.backupOwnerPathDryRun
$backupOwnerPathDryRunStatus = Get-ReportStatus -Report $backupOwnerPathDryRun
$backupOwnerPathDryRunChecks = Get-AuditProp -Object $backupOwnerPathDryRun -Name "checks"
$backupOwnerPathDryRunFailedChecks = @((Get-AuditProp -Object $backupOwnerPathDryRun -Name "failedChecks" -Default @()))
$backupOwnerPathDryRunSecretFindings = @((Get-AuditProp -Object $backupOwnerPathDryRun -Name "secretMarkerFindings" -Default @()))
$backupOwnerPathDryRunMissingChecks = Get-MissingAuditChecks -Checks $backupOwnerPathDryRunChecks -Names @(
    "childReadinessCommandPassed",
    "readinessStatusPassed",
    "snapshotProofPassed",
    "restoreProofPassed",
    "writeVerified",
    "latestPointerVerified",
    "latestPointerWrittenAtomically",
    "restoreLiveStateProtected",
    "restoreDidNotMutateLiveState",
    "ownerBackupEnvRestored",
    "envValuesPrintedFalse",
    "noSecrets",
    "secretMarkerFindingsEmpty",
    "broadcastsFalse"
)
$backupOwnerPathDryRunFailedCheckCount = @($backupOwnerPathDryRunFailedChecks | Where-Object { $null -ne $_ }).Count
$backupOwnerPathDryRunSecretFindingCount = @($backupOwnerPathDryRunSecretFindings | Where-Object { $null -ne $_ }).Count
$backupOwnerPathDryRunMissingCheckCount = @($backupOwnerPathDryRunMissingChecks | Where-Object { $null -ne $_ }).Count
$backupOwnerPathDryRunPassed = $backupOwnerPathDryRunExitCode -eq 0 `
    -and $backupOwnerPathDryRunStatus -eq "passed" `
    -and $backupOwnerPathDryRunFailedCheckCount -eq 0 `
    -and $backupOwnerPathDryRunSecretFindingCount -eq 0 `
    -and $backupOwnerPathDryRunMissingCheckCount -eq 0 `
    -and ((Get-AuditProp -Object $backupOwnerPathDryRunChecks -Name "readinessStatusPassed" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $backupOwnerPathDryRunChecks -Name "snapshotProofPassed" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $backupOwnerPathDryRunChecks -Name "restoreProofPassed" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $backupOwnerPathDryRunChecks -Name "restoreLiveStateProtected" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $backupOwnerPathDryRunChecks -Name "restoreDidNotMutateLiveState" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $backupOwnerPathDryRunChecks -Name "ownerBackupEnvRestored" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $backupOwnerPathDryRunChecks -Name "secretMarkerFindingsEmpty" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $backupOwnerPathDryRun -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $backupOwnerPathDryRun -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $backupOwnerPathDryRun -Name "broadcasts" -Default $true) -eq $false)
$backupInstallValidation = $reports.backupInstallValidation
$backupInstallValidationStatus = Get-ReportStatus -Report $backupInstallValidation
$backupInstallValidationChecks = Get-AuditProp -Object $backupInstallValidation -Name "checks"
$backupInstallValidationFailedChecks = @((Get-AuditProp -Object $backupInstallValidation -Name "failedChecks" -Default @()))
$backupInstallValidationMissingPackageScripts = @((Get-AuditProp -Object $backupInstallValidation -Name "missingPackageScripts" -Default @()))
$backupInstallValidationRequiredChecks = @(
    "installScriptExists",
    "systemdInstallScriptExists",
    "systemdValidationScriptExists",
    "backupScriptExists",
    "restoreDrillScriptExists",
    "packageScriptsPresent",
    "planCommandPassed",
    "planDidNotMutate",
    "schedulerCmdletsAvailable",
    "scheduledTaskActionSupportsWorkingDirectory",
    "taskNamesDistinct",
    "retentionCountValid",
    "actionUsesBackupScript",
    "actionUsesRetentionCount",
    "restoreDrillUsesRestoreScript",
    "restoreDrillHasRestoreRoot",
    "restoreDrillHasStatePath",
    "restoreDrillHasReportPath",
    "ownerBackupEnvRequired",
    "restoreDrillOwnerBackupEnvRequired",
    "commandOmitsAllowBlocked",
    "commandsPresent",
    "systemdValidationCommandPassed",
    "systemdValidationPassed",
    "systemdFailedChecksEmpty",
    "systemdPlanDidNotMutate",
    "systemdBackupServiceUnitPlanned",
    "systemdBackupTimerUnitPlanned",
    "systemdRestoreServiceUnitPlanned",
    "systemdRestoreTimerUnitPlanned",
    "systemdCommandOmitsAllowBlocked",
    "systemdOwnerBackupEnvRequired",
    "systemdOwnerEnvInjectable",
    "systemdServicesHardeningPresent",
    "systemdBackupRootWritePathConfigurable",
    "systemdChildReportNoSecrets",
    "envValuesPrintedFalse",
    "noSecrets",
    "broadcastsFalse"
)
$backupInstallValidationMissingChecks = @(Get-MissingAuditChecks -Checks $backupInstallValidationChecks -Names $backupInstallValidationRequiredChecks)
$backupInstallValidationFailedCheckCount = @($backupInstallValidationFailedChecks | Where-Object { $null -ne $_ }).Count
$backupInstallValidationMissingPackageScriptCount = @($backupInstallValidationMissingPackageScripts | Where-Object { $null -ne $_ }).Count
$backupInstallValidationMissingCheckCount = @($backupInstallValidationMissingChecks | Where-Object { $null -ne $_ }).Count
$backupInstallValidationPassed = $backupInstallValidationExitCode -eq 0 `
    -and $backupInstallValidationStatus -eq "passed" `
    -and $backupInstallValidationFailedCheckCount -eq 0 `
    -and $backupInstallValidationMissingPackageScriptCount -eq 0 `
    -and $backupInstallValidationMissingCheckCount -eq 0 `
    -and ((Get-AuditProp -Object $backupInstallValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $backupInstallValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $backupInstallValidation -Name "broadcasts" -Default $true) -eq $false)
$bridgeDeployControlValidation = $reports.bridgeDeployControlValidation
$bridgeDeployControlValidationStatus = Get-ReportStatus -Report $bridgeDeployControlValidation
$bridgeDeployControlChecks = Get-AuditProp -Object $bridgeDeployControlValidation -Name "checks"
$bridgeDeployControlFailedChecks = @((Get-AuditProp -Object $bridgeDeployControlValidation -Name "failedChecks" -Default @()))
$bridgeDeployControlSecretMarkerFindings = @((Get-AuditProp -Object $bridgeDeployControlValidation -Name "secretMarkerFindings" -Default @()))
$bridgeDeployControlRequiredChecks = @(
    "packageScriptDeployPresent",
    "packageScriptPausePresent",
    "packageScriptResumePresent",
    "packageScriptEmergencyStopPresent",
    "packageScriptValidationPresent",
    "deployScriptExists",
    "controlScriptExists",
    "foundryScriptExists",
    "lockboxContractExists",
    "deploymentRunbookExists",
    "deployMissingEnvCommandFailedClosed",
    "deployMissingEnvReportWritten",
    "deployMissingEnvReportBlockedNoBroadcast",
    "pauseMissingEnvCommandFailedClosed",
    "pauseMissingEnvReportBlockedNoBroadcast",
    "resumeMissingEnvCommandFailedClosed",
    "resumeMissingEnvReportBlockedNoBroadcast",
    "emergencyStopMissingEnvCommandFailedClosed",
    "emergencyStopMissingEnvReportBlockedNoBroadcast",
    "deployRequiresBase8453ChainId",
    "deployRequiresPilotAck",
    "deployRequiresBroadcastAck",
    "deployRequiresAcknowledgeBroadcastSwitch",
    "deployMapsFoundryPilotAck",
    "deployMapsNativeAndErc20Caps",
    "deployDryRunNoBroadcastStatus",
    "deployBroadcastUsesForgeBroadcast",
    "controlExecuteRequiresOwnerKeyAndBroadcastAck",
    "controlNoExecuteReportsReadyNoBroadcast",
    "controlSupportsPauseResumeEmergency",
    "controlExecuteUsesCastSend",
    "foundryScriptGatesBase8453",
    "foundryScriptRequiresTotalCapOnBase",
    "foundryScriptDeploysLockboxAndSpine",
    "lockboxHasNonReentrantPauseEmergency",
    "lockboxHasCapsAndReplayProtection",
    "lockboxRejectsPlaceholderRecipient",
    "lockboxHasReleaseAuthority",
    "runbookHasDryRunBroadcastVerifyRollback",
    "childProcessesDidNotTimeout",
    "validationArtifactsInsideRepo",
    "secretMarkerFindingsEmpty",
    "envValuesPrintedFalse",
    "noSecrets",
    "broadcastsFalse"
)
$bridgeDeployControlMissingChecks = @(Get-MissingAuditChecks -Checks $bridgeDeployControlChecks -Names $bridgeDeployControlRequiredChecks)
$bridgeDeployControlValidationPassed = $bridgeDeployControlValidationExitCode -eq 0 `
    -and $bridgeDeployControlValidationStatus -eq "passed" `
    -and $bridgeDeployControlFailedChecks.Count -eq 0 `
    -and $bridgeDeployControlSecretMarkerFindings.Count -eq 0 `
    -and $bridgeDeployControlMissingChecks.Count -eq 0 `
    -and ((Get-AuditProp -Object $bridgeDeployControlValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $bridgeDeployControlValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $bridgeDeployControlValidation -Name "broadcasts" -Default $true) -eq $false)
$bridgeRelayerOnce = $reports.bridgeRelayerOnce
$bridgeRelayerOnceStatus = Get-ReportStatus -Report $bridgeRelayerOnce
$bridgeRelayerOnceChecks = Get-AuditProp -Object $bridgeRelayerOnce -Name "checks"
$bridgeRelayerOnceFailedChecks = @((Get-AuditProp -Object $bridgeRelayerOnce -Name "failedChecks" -Default @()))
$bridgeRelayerOnceSecretFindings = @((Get-AuditProp -Object $bridgeRelayerOnce -Name "secretMarkerFindings" -Default @()))
$bridgeRelayerOnceRequiredChecks = @(
    "statusKnown",
    "requiredEnvNamesPresent",
    "childTimeoutRecorded",
    "childProcessesDidNotTimeout",
    "broadcastsFalse",
    "envValuesPrintedFalse",
    "noSecrets",
    "readinessInfraChecked",
    "readinessLiveCheckedWhenInfraPassed",
    "blockedBeforeLiveReadinessWhenInfraBlocked",
    "blockedBeforeObservationWhenReadinessBlocked",
    "noQueuedTransactionsWhenBlocked",
    "noAppliedCreditsWhenBlocked",
    "cursorModeStaged",
    "finalCursorNotCommittedWhenBlocked",
    "finalCursorPathInsideRepo",
    "stagedCursorPathInsideRepo",
    "issuesClassified",
    "externalBlockerClassifiedWhenBlocked",
    "latencyGateRecorded",
    "latencyGatePassedWhenApplied",
    "queueAndApplyMatchWhenPassed",
    "cursorSafeWhenPassed"
)
$bridgeRelayerOnceMissingChecks = @(Get-MissingAuditChecks -Checks $bridgeRelayerOnceChecks -Names $bridgeRelayerOnceRequiredChecks)
$bridgeRelayerOnceFalseRequiredChecks = @($bridgeRelayerOnceRequiredChecks | Where-Object { (Get-AuditProp -Object $bridgeRelayerOnceChecks -Name $_ -Default $false) -ne $true })
$bridgeRelayerOnceFailedCheckCount = @($bridgeRelayerOnceFailedChecks | Where-Object { $null -ne $_ }).Count
$bridgeRelayerOnceSecretFindingCount = @($bridgeRelayerOnceSecretFindings | Where-Object { $null -ne $_ }).Count
$bridgeRelayerOnceMissingCheckCount = @($bridgeRelayerOnceMissingChecks | Where-Object { $null -ne $_ }).Count
$bridgeRelayerOnceFalseRequiredCheckCount = @($bridgeRelayerOnceFalseRequiredChecks | Where-Object { $null -ne $_ }).Count
$bridgeRelayerOnceCheckContractPassed = $bridgeRelayerOnceExitCode -eq 0 `
    -and $bridgeRelayerOnceStatus -in @("passed", "blocked") `
    -and $bridgeRelayerOnceFailedCheckCount -eq 0 `
    -and $bridgeRelayerOnceSecretFindingCount -eq 0 `
    -and $bridgeRelayerOnceMissingCheckCount -eq 0 `
    -and $bridgeRelayerOnceFalseRequiredCheckCount -eq 0 `
    -and ((Get-AuditProp -Object $bridgeRelayerOnce -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $bridgeRelayerOnce -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $bridgeRelayerOnce -Name "broadcasts" -Default $true) -eq $false)
$bridgeRelayerGuardrailValidation = $reports.bridgeRelayerGuardrailValidation
$bridgeRelayerGuardrailValidationStatus = Get-ReportStatus -Report $bridgeRelayerGuardrailValidation
$bridgeRelayerGuardrailChecks = Get-AuditProp -Object $bridgeRelayerGuardrailValidation -Name "checks"
$bridgeRelayerGuardrailFailedChecks = @((Get-AuditProp -Object $bridgeRelayerGuardrailValidation -Name "failedChecks" -Default @()))
$bridgeRelayerGuardrailSecretFindings = @((Get-AuditProp -Object $bridgeRelayerGuardrailValidation -Name "secretMarkerFindings" -Default @()))
$bridgeRelayerGuardrailRequiredChecks = @(
    "relayerCommandExitedZeroWithAllowBlocked",
    "relayerReportWritten",
    "relayerStatusBlocked",
    "relayerChildTimeoutRecorded",
    "relayerNoChildTimeouts",
    "blockedBeforeLiveReadiness",
    "externalOwnerIssueRecorded",
    "finalCursorUnchanged",
    "stagedCursorNotWritten",
    "finalCursorNotCommitted",
    "noCreditsObserved",
    "noCreditsQueued",
    "noCreditsApplied",
    "ownerEnvNotImported",
    "directObserveFailedClosed",
    "directObserveReportWritten",
    "directObserveStatusBlocked",
    "directObserveUsesStagedCursorByDefault",
    "directObserveCursorNotFinal",
    "directObserveFinalCursorUnchanged",
    "directObserveStagedCursorNotWritten",
    "directObserveBroadcastsFalse",
    "directObserveEnvValuesPrintedFalse",
    "directObserveNoSecrets",
    "broadcastsFalse",
    "envValuesPrintedFalse",
    "noSecrets",
    "secretMarkerFindingsEmpty"
)
$bridgeRelayerGuardrailMissingChecks = @(Get-MissingAuditChecks -Checks $bridgeRelayerGuardrailChecks -Names $bridgeRelayerGuardrailRequiredChecks)
$bridgeRelayerGuardrailFalseRequiredChecks = @($bridgeRelayerGuardrailRequiredChecks | Where-Object { (Get-AuditProp -Object $bridgeRelayerGuardrailChecks -Name $_ -Default $false) -ne $true })
$bridgeRelayerGuardrailFailedCheckCount = @($bridgeRelayerGuardrailFailedChecks | Where-Object { $null -ne $_ }).Count
$bridgeRelayerGuardrailSecretFindingCount = @($bridgeRelayerGuardrailSecretFindings | Where-Object { $null -ne $_ }).Count
$bridgeRelayerGuardrailMissingCheckCount = @($bridgeRelayerGuardrailMissingChecks | Where-Object { $null -ne $_ }).Count
$bridgeRelayerGuardrailFalseRequiredCheckCount = @($bridgeRelayerGuardrailFalseRequiredChecks | Where-Object { $null -ne $_ }).Count
$bridgeRelayerGuardrailValidationPassed = $bridgeRelayerGuardrailValidationExitCode -eq 0 `
    -and $bridgeRelayerGuardrailValidationStatus -eq "passed" `
    -and $bridgeRelayerGuardrailFailedCheckCount -eq 0 `
    -and $bridgeRelayerGuardrailSecretFindingCount -eq 0 `
    -and $bridgeRelayerGuardrailMissingCheckCount -eq 0 `
    -and $bridgeRelayerGuardrailFalseRequiredCheckCount -eq 0 `
    -and ((Get-AuditProp -Object $bridgeRelayerGuardrailChecks -Name "secretMarkerFindingsEmpty" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $bridgeRelayerGuardrailValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $bridgeRelayerGuardrailValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $bridgeRelayerGuardrailValidation -Name "broadcasts" -Default $true) -eq $false)
$bridgeRelayerLoopValidation = $reports.bridgeRelayerLoopValidation
$bridgeRelayerLoopValidationStatus = Get-ReportStatus -Report $bridgeRelayerLoopValidation
$bridgeRelayerLoopChecks = Get-AuditProp -Object $bridgeRelayerLoopValidation -Name "checks"
$bridgeRelayerLoopFailedChecks = @((Get-AuditProp -Object $bridgeRelayerLoopValidation -Name "failedChecks" -Default @()))
$bridgeRelayerLoopSecretFindings = @((Get-AuditProp -Object $bridgeRelayerLoopValidation -Name "secretMarkerFindings" -Default @()))
$bridgeRelayerLoopRequiredChecks = @(
    "startCommandPassed",
    "startReportWritten",
    "liveProfile",
    "relayerLoopRequested",
    "relayerLoopStartedOrRunning",
    "relayerPidRecorded",
    "relayerPollSecondsRecorded",
    "relayerQueuesRuntimeHandoffs",
    "statusCommandPassed",
    "statusReportsRelayerRunning",
    "statusRelayerCommandLineMatched",
    "statusRelayerReportFresh",
    "statusRelayerReportAcceptable",
    "statusRelayerReportBlockedOnlyOnOwnerInputs",
    "statusRelayerReportNoSecrets",
    "statusRelayerReportNoBroadcasts",
    "statusRelayerReportHealthy",
    "stopCommandPassed",
    "stopPreservedState",
    "stopHandledRelayerLoop",
    "statusAfterStopCommandPassed",
    "statusAfterStopNotRunning",
    "relayerPidNoLongerMatchesAfterStop",
    "relayerPidFileRemovedAfterStop",
    "stopReportRelayerPidFileRemoved",
    "noValidationRelayerProcessAfterStop",
    "envValuesPrintedFalse",
    "noSecrets",
    "secretMarkerFindingsEmpty",
    "broadcastsFalse"
)
$bridgeRelayerLoopMissingChecks = @(Get-MissingAuditChecks -Checks $bridgeRelayerLoopChecks -Names $bridgeRelayerLoopRequiredChecks)
$bridgeRelayerLoopFailedCheckCount = @($bridgeRelayerLoopFailedChecks | Where-Object { $null -ne $_ }).Count
$bridgeRelayerLoopSecretFindingCount = @($bridgeRelayerLoopSecretFindings | Where-Object { $null -ne $_ }).Count
$bridgeRelayerLoopMissingCheckCount = @($bridgeRelayerLoopMissingChecks | Where-Object { $null -ne $_ }).Count
$bridgeRelayerLoopValidationPassed = $bridgeRelayerLoopValidationExitCode -eq 0 `
    -and $bridgeRelayerLoopValidationStatus -eq "passed" `
    -and $bridgeRelayerLoopFailedCheckCount -eq 0 `
    -and $bridgeRelayerLoopSecretFindingCount -eq 0 `
    -and $bridgeRelayerLoopMissingCheckCount -eq 0 `
    -and ((Get-AuditProp -Object $bridgeRelayerLoopChecks -Name "secretMarkerFindingsEmpty" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $bridgeRelayerLoopValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $bridgeRelayerLoopValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $bridgeRelayerLoopValidation -Name "broadcasts" -Default $true) -eq $false)
$bridgeRuntimeCreditValidation = $reports.bridgeRuntimeCreditValidation
$bridgeRuntimeCreditValidationStatus = Get-ReportStatus -Report $bridgeRuntimeCreditValidation
$bridgeRuntimeCreditChecks = Get-AuditProp -Object $bridgeRuntimeCreditValidation -Name "checks"
$bridgeRuntimeCreditFailedChecks = @((Get-AuditProp -Object $bridgeRuntimeCreditValidation -Name "failedChecks" -Default @()))
$bridgeRuntimeCreditMissingRuntimeChecks = @((Get-AuditProp -Object $bridgeRuntimeCreditValidation -Name "missingRuntimeChecks" -Default @()))
$bridgeRuntimeCreditFalseRuntimeChecks = @((Get-AuditProp -Object $bridgeRuntimeCreditValidation -Name "falseRuntimeChecks" -Default @()))
$bridgeRuntimeCreditProofFailedChecks = @((Get-AuditProp -Object $bridgeRuntimeCreditValidation -Name "proofFailedChecks" -Default @()))
$bridgeRuntimeCreditSecretFindings = @((Get-AuditProp -Object $bridgeRuntimeCreditValidation -Name "secretMarkerFindings" -Default @()))
$bridgeRuntimeCreditRequiredChecks = @(
    "childCommandPassed",
    "childDidNotTimeout",
    "proofReportWritten",
    "proofClassificationReady",
    "proofFailedChecksEmpty",
    "requiredRuntimeChecksCovered",
    "requiredRuntimeChecksPassed",
    "sourceChainBase8453",
    "creditAppliedOnce",
    "creditedBalanceTransferable",
    "replayRejected",
    "restartPreservesCreditHistory",
    "exportImportPreservesReplayProtection",
    "latencyRecorded",
    "latencyGatePassed",
    "transferLatencyUnderTarget",
    "proofBroadcastsFalse",
    "proofEnvValuesPrintedFalse",
    "proofNoSecrets",
    "handoffReportReadable",
    "handoffNoReleaseBroadcast",
    "handoffNoWithdrawalBroadcast",
    "secretMarkerFindingsEmpty",
    "broadcastsFalse",
    "envValuesPrintedFalse",
    "noSecrets"
)
$bridgeRuntimeCreditMissingChecks = @(Get-MissingAuditChecks -Checks $bridgeRuntimeCreditChecks -Names $bridgeRuntimeCreditRequiredChecks)
$bridgeRuntimeCreditFalseRequiredChecks = @($bridgeRuntimeCreditRequiredChecks | Where-Object { (Get-AuditProp -Object $bridgeRuntimeCreditChecks -Name $_ -Default $false) -ne $true })
$bridgeRuntimeCreditValidationPassed = $bridgeRuntimeCreditValidationExitCode -eq 0 `
    -and $bridgeRuntimeCreditValidationStatus -eq "passed" `
    -and $bridgeRuntimeCreditFailedChecks.Count -eq 0 `
    -and $bridgeRuntimeCreditMissingRuntimeChecks.Count -eq 0 `
    -and $bridgeRuntimeCreditFalseRuntimeChecks.Count -eq 0 `
    -and $bridgeRuntimeCreditProofFailedChecks.Count -eq 0 `
    -and $bridgeRuntimeCreditSecretFindings.Count -eq 0 `
    -and $bridgeRuntimeCreditMissingChecks.Count -eq 0 `
    -and $bridgeRuntimeCreditFalseRequiredChecks.Count -eq 0 `
    -and ((Get-AuditProp -Object $bridgeRuntimeCreditValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $bridgeRuntimeCreditValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $bridgeRuntimeCreditValidation -Name "broadcasts" -Default $true) -eq $false)
$realValuePilotAggregate = $reports.realValuePilotAggregate
$realValuePilotAggregateStatus = Get-ReportStatus -Report $realValuePilotAggregate
$realValuePilotAggregateChecks = Get-AuditProp -Object $realValuePilotAggregate -Name "checks"
$realValuePilotAggregateTimedOutCommands = @((Get-AuditProp -Object $realValuePilotAggregate -Name "timedOutCommands" -Default @()))
$realValuePilotAggregateFailedCommands = @((Get-AuditProp -Object $realValuePilotAggregate -Name "failedCommands" -Default @()))
$realValuePilotAggregateMissingProofs = @((Get-AuditProp -Object $realValuePilotAggregate -Name "missingProofs" -Default @()))
$realValuePilotAggregateMissingExpectedCommands = @((Get-AuditProp -Object $realValuePilotAggregate -Name "missingExpectedCommands" -Default @()))
$realValuePilotAggregateCommandsRun = @((Get-AuditProp -Object $realValuePilotAggregate -Name "commandsRun" -Default @()) | ForEach-Object { "$_" })
$realValuePilotAggregateRequiredCommands = @(
    "npm run flowchain:real-value-pilot:contracts",
    "npm run flowchain:real-value-pilot:bridge",
    "npm run flowchain:real-value-pilot:runtime",
    "npm run flowchain:real-value-pilot:wallet",
    "npm run flowchain:real-value-pilot:control-dashboard",
    "npm run flowchain:real-value-pilot:ops"
)
$realValuePilotAggregateMissingCommandsRun = @($realValuePilotAggregateRequiredCommands | Where-Object { $_ -notin $realValuePilotAggregateCommandsRun })
$realValuePilotAggregateRequiredChecks = @(
    "pilotSpecPresent",
    "baselineScriptsPresent",
    "requiredProofScriptsPresent",
    "requiredProofCommandsRun",
    "childTimeoutSecondsPositive",
    "commandsDidNotTimeout",
    "commandsDidNotFail",
    "missingProofsEmpty",
    "ownerGoNoGoTrue",
    "outputTailsRedacted",
    "envValuesPrintedFalse",
    "noSecrets",
    "broadcastsFalse"
)
$realValuePilotAggregateMissingChecks = @(Get-MissingAuditChecks -Checks $realValuePilotAggregateChecks -Names $realValuePilotAggregateRequiredChecks)
$realValuePilotAggregateFalseRequiredChecks = @($realValuePilotAggregateRequiredChecks | Where-Object { (Get-AuditProp -Object $realValuePilotAggregateChecks -Name $_ -Default $false) -ne $true })
$realValuePilotAggregateOwnerGoNoGo = Get-AuditProp -Object (Get-AuditProp -Object $realValuePilotAggregate -Name "ownerGoNoGo") -Name "go" -Default $false
$realValuePilotAggregatePassed = $realValuePilotAggregateExitCode -eq 0 `
    -and $realValuePilotAggregateStatus -eq "passed" `
    -and $realValuePilotAggregateTimedOutCommands.Count -eq 0 `
    -and $realValuePilotAggregateFailedCommands.Count -eq 0 `
    -and $realValuePilotAggregateMissingProofs.Count -eq 0 `
    -and $realValuePilotAggregateMissingExpectedCommands.Count -eq 0 `
    -and $realValuePilotAggregateMissingCommandsRun.Count -eq 0 `
    -and $realValuePilotAggregateMissingChecks.Count -eq 0 `
    -and $realValuePilotAggregateFalseRequiredChecks.Count -eq 0 `
    -and $realValuePilotAggregateOwnerGoNoGo -eq $true `
    -and ((Get-AuditProp -Object $realValuePilotAggregate -Name "skipBaseline" -Default $false) -eq $true) `
    -and ([int](Get-AuditProp -Object $realValuePilotAggregate -Name "childTimeoutSeconds" -Default 0) -ge 1) `
    -and ((Get-AuditProp -Object $realValuePilotAggregate -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $realValuePilotAggregate -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $realValuePilotAggregate -Name "broadcasts" -Default $true) -eq $false)
$bridgeReconciliation = $reports.bridgeReconciliation
$bridgeReconciliationStatus = Get-ReportStatus -Report $bridgeReconciliation
$bridgeReconciliationChecks = Get-AuditProp -Object $bridgeReconciliation -Name "checks"
$bridgeReconciliationFailedChecks = @((Get-AuditProp -Object $bridgeReconciliation -Name "failedChecks" -Default @()))
$bridgeReconciliationSecretFindings = @((Get-AuditProp -Object $bridgeReconciliation -Name "secretMarkerFindings" -Default @()))
$bridgeReconciliationRows = @((Get-AuditProp -Object $bridgeReconciliation -Name "reconciliation" -Default @()))
$bridgeReconciliationRequiredChecks = @(
    "relayerOnceReportLoaded",
    "relayerOnceStatusBlockedOrPassed",
    "relayerOnceNoFailedChecks",
    "relayerOnceNoSecrets",
    "relayerOnceNoBroadcasts",
    "relayerCountsNonNegative",
    "pendingCreditsNonNegative",
    "cursorModeStaged",
    "cursorFinalNotCommittedWhenBlocked",
    "relayerBlockedClassifiedOwnerInput",
    "guardrailReportPassed",
    "guardrailNoFailedChecks",
    "guardrailCursorSafe",
    "loopValidationPassedOrOwnerBlocked",
    "runtimeCreditPassed",
    "runtimeCreditNoFailedChecks",
    "runtimeCreditAppliedOnce",
    "runtimeReplayRejected",
    "localPilotPassed",
    "localPilotNoFailedChecks",
    "localPilotExactValueConserved",
    "localPilotDuplicateReplayRejected",
    "releaseEvidenceValidationPassed",
    "releaseEvidenceNoFailedChecks",
    "reconciliationRowsPresent",
    "liveReadinessBlockedOrPassed",
    "bridgeInfraBlockedOrPassed",
    "envValuesPrintedFalse",
    "secretMarkerFindingsEmpty",
    "noSecrets",
    "broadcastsFalse"
)
$bridgeReconciliationMissingChecks = @(Get-MissingAuditChecks -Checks $bridgeReconciliationChecks -Names $bridgeReconciliationRequiredChecks)
$bridgeReconciliationFailedCheckCount = $bridgeReconciliationFailedChecks.Count
$bridgeReconciliationSecretFindingCount = $bridgeReconciliationSecretFindings.Count
$bridgeReconciliationMissingCheckCount = $bridgeReconciliationMissingChecks.Count
$bridgeReconciliationPassed = $bridgeReconciliationExitCode -eq 0 `
    -and $bridgeReconciliationStatus -eq "passed" `
    -and $bridgeReconciliationFailedCheckCount -eq 0 `
    -and $bridgeReconciliationSecretFindingCount -eq 0 `
    -and $bridgeReconciliationMissingCheckCount -eq 0 `
    -and $bridgeReconciliationRows.Count -ge 8 `
    -and ((Get-AuditProp -Object $bridgeReconciliation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $bridgeReconciliation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $bridgeReconciliation -Name "broadcasts" -Default $true) -eq $false)
$bridgeReleaseEvidenceValidation = $reports.bridgeReleaseEvidenceValidation
$bridgeReleaseEvidenceValidationStatus = Get-ReportStatus -Report $bridgeReleaseEvidenceValidation
$bridgeReleaseEvidenceValidationChecks = Get-AuditProp -Object $bridgeReleaseEvidenceValidation -Name "checks"
$bridgeReleaseEvidenceValidationFailedChecks = @((Get-AuditProp -Object $bridgeReleaseEvidenceValidation -Name "failedChecks" -Default @()))
$bridgeReleaseEvidenceValidationFailedCases = @((Get-AuditProp -Object $bridgeReleaseEvidenceValidation -Name "failedCases" -Default @()))
$bridgeReleaseEvidenceValidationMissingCases = @((Get-AuditProp -Object $bridgeReleaseEvidenceValidation -Name "missingRequiredCases" -Default @()))
$bridgeReleaseEvidenceValidationSecretFindings = @((Get-AuditProp -Object $bridgeReleaseEvidenceValidation -Name "secretMarkerFindings" -Default @()))
$bridgeReleaseEvidenceValidationRequiredChecks = @(
    "releaseEvidenceScriptExists",
    "matchingEvidencePasses",
    "missingInputsBlock",
    "amountMismatchFails",
    "tokenMismatchFails",
    "recipientMismatchFails",
    "chainMismatchFails",
    "assetMismatchFails",
    "releaseBroadcastRejected",
    "withdrawalBroadcastRejected",
    "allRequiredCasesCovered",
    "failedCasesAbsent",
    "noSecretScanPassed",
    "broadcastsFalse",
    "envValuesPrintedFalse",
    "noSecrets",
    "secretMarkerFindingsEmpty"
)
$bridgeReleaseEvidenceValidationMissingChecks = @(Get-MissingAuditChecks -Checks $bridgeReleaseEvidenceValidationChecks -Names $bridgeReleaseEvidenceValidationRequiredChecks)
$bridgeReleaseEvidenceValidationFalseRequiredChecks = @($bridgeReleaseEvidenceValidationRequiredChecks | Where-Object { (Get-AuditProp -Object $bridgeReleaseEvidenceValidationChecks -Name $_ -Default $false) -ne $true })
$bridgeReleaseEvidenceValidationPassed = $bridgeReleaseEvidenceValidationExitCode -eq 0 `
    -and $bridgeReleaseEvidenceValidationStatus -eq "passed" `
    -and $bridgeReleaseEvidenceValidationFailedChecks.Count -eq 0 `
    -and $bridgeReleaseEvidenceValidationFailedCases.Count -eq 0 `
    -and $bridgeReleaseEvidenceValidationMissingCases.Count -eq 0 `
    -and $bridgeReleaseEvidenceValidationSecretFindings.Count -eq 0 `
    -and $bridgeReleaseEvidenceValidationMissingChecks.Count -eq 0 `
    -and $bridgeReleaseEvidenceValidationFalseRequiredChecks.Count -eq 0 `
    -and ((Get-AuditProp -Object $bridgeReleaseEvidenceValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $bridgeReleaseEvidenceValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $bridgeReleaseEvidenceValidation -Name "broadcasts" -Default $true) -eq $false)
$externalTesterPacketStatus = Get-ReportStatus -Report $externalTesterPacket
$externalTesterPacketShareable = Get-AuditProp -Object $externalTesterPacket -Name "packetShareable" -Default $false
$externalTesterPacketPath = [string](Get-AuditProp -Object $externalTesterPacket -Name "packetPath" -Default $paths.externalTesterPacket)
$externalTesterPacketExecutableSmokeValidated = Get-AuditProp -Object $externalTesterPacket -Name "packetExecutableSmokeValidated" -Default $false
$externalTesterPacketSmokeChecks = Get-AuditProp -Object $externalTesterPacket -Name "packetSmokeChecks"
$externalTesterPacketSmokeRoutes = @((Get-AuditProp -Object $externalTesterPacket -Name "packetSmokeRoutes" -Default @()))
$externalTesterConnectPackShareable = Get-AuditProp -Object $externalTesterPacket -Name "connectPackShareable" -Default $false
$externalTesterConnectPackChecks = Get-AuditProp -Object $externalTesterPacket -Name "connectPackChecks"
$externalTesterConnectPackReady = ((Get-AuditProp -Object $externalTesterConnectPackChecks -Name "connectPackWritten" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $externalTesterConnectPackChecks -Name "connectPackSchemaValid" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $externalTesterConnectPackChecks -Name "connectPackHasNetworkProfile" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $externalTesterConnectPackChecks -Name "connectPackHasRpcPlaceholder" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $externalTesterConnectPackChecks -Name "connectPackHasTesterTokenPlaceholder" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $externalTesterConnectPackChecks -Name "connectPackHasReadOnlyRoutes" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $externalTesterConnectPackChecks -Name "connectPackHasTesterWriteRoutes" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $externalTesterConnectPackChecks -Name "connectPackShareableMatchesPacket" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $externalTesterConnectPackChecks -Name "connectPackNoConcreteUrl" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $externalTesterConnectPackChecks -Name "connectPackNoSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $externalTesterConnectPackChecks -Name "connectPackBroadcastsFalse" -Default $false) -eq $true) `
    -and ($externalTesterConnectPackShareable -eq $externalTesterPacketShareable)
$externalTesterPacketValidation = $reports.externalTesterPacketValidation
$externalTesterPacketValidationStatus = Get-ReportStatus -Report $externalTesterPacketValidation
$externalTesterPacketValidationChecks = Get-AuditProp -Object $externalTesterPacketValidation -Name "checks"
$externalTesterPacketValidationFailedChecks = @((Get-AuditProp -Object $externalTesterPacketValidation -Name "failedChecks" -Default @()))
$externalTesterPacketValidationSecretFindings = @((Get-AuditProp -Object $externalTesterPacketValidation -Name "secretMarkerFindings" -Default @()))
$externalTesterPacketValidationRequiredChecks = @(
    "packageScriptPacketPresent",
    "packageScriptValidationPresent",
    "packetScriptExists",
    "readinessScriptExists",
    "testerNetworkReportExists",
    "publicTesterGatewayReportExists",
    "packetCommandAllowsBlocked",
    "packetReportWritten",
    "packetMarkdownWritten",
    "connectPackWritten",
    "packetStatusBlockedUntilOwnerInputs",
    "packetShareableFalseWithoutOwnerInputs",
    "connectPackShareableFalseWithoutOwnerInputs",
    "externalSharingReadyFalse",
    "localTesterRehearsalReady",
    "packetExecutableSmokeValidated",
    "testerNetworkReportPassed",
    "publicTesterGatewayReportPassed",
    "publicTesterGatewayRoutesCovered",
    "publicTesterGatewayCapRejected",
    "packetSmokeChecksAllTrue",
    "packetSmokeRoutesCoverReadOnly",
    "packetSmokeRoutesCoverTesterWrites",
    "connectPackChecksAllTrue",
    "connectPackSchemaValid",
    "connectPackStatusMatchesReport",
    "connectPackShareableMatchesReport",
    "connectPackHasChainId",
    "connectPackHasEndpointPlaceholders",
    "connectPackHasNoConcreteUrl",
    "connectPackReadOnlyRoutesCovered",
    "connectPackTesterWriteRoutesCovered",
    "packetMarkdownWarnsNotShareable",
    "packetMarkdownHasConnectionProfile",
    "packetMarkdownHasEndpointChecks",
    "packetMarkdownHasWalletFlow",
    "packetMarkdownListsOwnerCommands",
    "requiredOwnerEnvNamesListed",
    "envValuesPrintedFalse",
    "noSecrets",
    "broadcastsFalse",
    "secretMarkerFindingsEmpty",
    "packetReportInsideRepo",
    "connectPackInsideRepo",
    "packetMarkdownInsideRepo"
)
$externalTesterPacketValidationMissingChecks = @(Get-MissingAuditChecks -Checks $externalTesterPacketValidationChecks -Names $externalTesterPacketValidationRequiredChecks)
$externalTesterPacketValidationPassed = $externalTesterPacketValidationExitCode -eq 0 `
    -and $externalTesterPacketValidationStatus -eq "passed" `
    -and $externalTesterPacketValidationFailedChecks.Count -eq 0 `
    -and $externalTesterPacketValidationSecretFindings.Count -eq 0 `
    -and $externalTesterPacketValidationMissingChecks.Count -eq 0 `
    -and ((Get-AuditProp -Object $externalTesterPacketValidation -Name "packetShareable" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $externalTesterPacketValidation -Name "connectPackShareable" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $externalTesterPacketValidation -Name "externalSharingReady" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $externalTesterPacketValidation -Name "packetExecutableSmokeValidated" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $externalTesterPacketValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $externalTesterPacketValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $externalTesterPacketValidation -Name "broadcasts" -Default $true) -eq $false)
$externalTesterClientValidation = $reports.externalTesterClientValidation
$externalTesterClientValidationStatus = Get-ReportStatus -Report $externalTesterClientValidation
$externalTesterClientValidationChecks = Get-AuditProp -Object $externalTesterClientValidation -Name "checks"
$externalTesterClientValidationFailedChecks = @((Get-AuditProp -Object $externalTesterClientValidation -Name "failedChecks" -Default @()))
$externalTesterClientValidationSecretFindings = @((Get-AuditProp -Object $externalTesterClientValidation -Name "secretMarkerFindings" -Default @()))
$externalTesterClientValidationRequiredChecks = @(
    "clientScriptExists",
    "connectPackExists",
    "connectPackSchemaValid",
    "clientExitCodeZero",
    "dryRunReportWritten",
    "dryRunSchemaValid",
    "dryRunStatusPlanned",
    "dryRunNoNetwork",
    "blockedConnectPackAllowedOnlyByFlag",
    "plannedRoutesCoverReads",
    "plannedRoutesCoverWrites",
    "endpointRedacted",
    "tokenNotConfiguredInDryRun",
    "broadcastsFalse",
    "envValuesPrintedFalse",
    "noSecrets",
    "secretMarkerFindingsEmpty"
)
$externalTesterClientValidationMissingChecks = @(Get-MissingAuditChecks -Checks $externalTesterClientValidationChecks -Names $externalTesterClientValidationRequiredChecks)
$externalTesterClientValidationPassed = $externalTesterClientValidationExitCode -eq 0 `
    -and $externalTesterClientValidationStatus -eq "passed" `
    -and $externalTesterClientValidationFailedChecks.Count -eq 0 `
    -and $externalTesterClientValidationSecretFindings.Count -eq 0 `
    -and $externalTesterClientValidationMissingChecks.Count -eq 0 `
    -and ((Get-AuditProp -Object $externalTesterClientValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $externalTesterClientValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $externalTesterClientValidation -Name "broadcasts" -Default $true) -eq $false)
$externalTesterEvidenceValidation = $reports.externalTesterEvidenceValidation
$externalTesterEvidenceValidationStatus = Get-ReportStatus -Report $externalTesterEvidenceValidation
$externalTesterEvidenceValidationChecks = Get-AuditProp -Object $externalTesterEvidenceValidation -Name "checks"
$externalTesterEvidenceValidationFailedChecks = @((Get-AuditProp -Object $externalTesterEvidenceValidation -Name "failedChecks" -Default @()))
$externalTesterEvidenceValidationSecretFindings = @((Get-AuditProp -Object $externalTesterEvidenceValidation -Name "secretMarkerFindings" -Default @()))
$externalTesterEvidenceValidationCredentialUrlFindings = @((Get-AuditProp -Object $externalTesterEvidenceValidation -Name "credentialUrlFindings" -Default @()))
$externalTesterEvidenceValidationEnvAssignmentFindings = @((Get-AuditProp -Object $externalTesterEvidenceValidation -Name "envAssignmentFindings" -Default @()))
$externalTesterEvidenceValidationMissingRequiredFiles = @((Get-AuditProp -Object $externalTesterEvidenceValidation -Name "missingRequiredFiles" -Default @()))
$externalTesterEvidenceValidationInvalidJsonFiles = @((Get-AuditProp -Object $externalTesterEvidenceValidation -Name "invalidJsonFiles" -Default @()))
$externalTesterEvidenceValidationRequiredChecks = @(
    "packageScriptPresent",
    "guideExists",
    "guideListsSuggestedFiles",
    "guideHasOwnerReviewChecklist",
    "guideHasStopRules",
    "evidenceDirInsideRepo",
    "evidenceDirExists",
    "requiredFilesPresent",
    "requiredJsonValid",
    "notesPresent",
    "readinessPassed",
    "diagnosticsPassed",
    "diagnosticsNoSecrets",
    "heightsNumeric",
    "blockHeightAdvanced",
    "sendAccepted",
    "transferIdPresent",
    "transactionIdPresent",
    "transferFound",
    "transferMatchesAccounts",
    "transferAmountMatches",
    "transactionIdMatches",
    "transferBlockHeightInWindow",
    "includedHeightMatchesTransfer",
    "amountWithinLimit",
    "balancesPresent",
    "senderDebited",
    "recipientCredited",
    "secretMarkerFindingsEmpty",
    "credentialUrlFindingsEmpty",
    "envAssignmentFindingsEmpty",
    "envValuesPrintedFalse",
    "noSecrets",
    "broadcastsFalse"
)
$externalTesterEvidenceValidationMissingChecks = @(Get-MissingAuditChecks -Checks $externalTesterEvidenceValidationChecks -Names $externalTesterEvidenceValidationRequiredChecks)
$externalTesterEvidenceValidationPassed = $externalTesterEvidenceValidationExitCode -eq 0 `
    -and $externalTesterEvidenceValidationStatus -eq "passed" `
    -and $externalTesterEvidenceValidationFailedChecks.Count -eq 0 `
    -and $externalTesterEvidenceValidationSecretFindings.Count -eq 0 `
    -and $externalTesterEvidenceValidationCredentialUrlFindings.Count -eq 0 `
    -and $externalTesterEvidenceValidationEnvAssignmentFindings.Count -eq 0 `
    -and $externalTesterEvidenceValidationMissingRequiredFiles.Count -eq 0 `
    -and $externalTesterEvidenceValidationInvalidJsonFiles.Count -eq 0 `
    -and $externalTesterEvidenceValidationMissingChecks.Count -eq 0 `
    -and ((Get-AuditProp -Object $externalTesterEvidenceValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $externalTesterEvidenceValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $externalTesterEvidenceValidation -Name "broadcasts" -Default $true) -eq $false)
$externalTesterStatus = Get-ReportStatus -Report $externalTester
$externalSharingReady = Get-AuditProp -Object $externalTester -Name "externalSharingReady" -Default $false
$externalTesterChecks = Get-AuditProp -Object $externalTester -Name "checks"
$externalTesterNetworkFresh = Get-AuditProp -Object $externalTesterChecks -Name "testerWalletNetworkFresh" -Default $false
$externalTesterLaunchPassed = ($externalTesterStatus -eq "passed") `
    -and ($externalTesterPacketStatus -eq "passed") `
    -and ($externalSharingReady -eq $true) `
    -and ($externalTesterPacketShareable -eq $true) `
    -and ($externalTesterNetworkFresh -eq $true) `
    -and ($externalTesterPacketExecutableSmokeValidated -eq $true) `
    -and ($externalTesterConnectPackReady -eq $true) `
    -and ($externalTesterClientValidationPassed -eq $true) `
    -and ($externalTesterEvidenceValidationPassed -eq $true)
$externalTesterLaunchBlocked = ($externalTesterStatus -eq "blocked") `
    -and ($externalTesterPacketStatus -eq "blocked") `
    -and ($externalSharingReady -eq $false) `
    -and ($externalTesterPacketShareable -eq $false) `
    -and ($externalTesterNetworkFresh -eq $true) `
    -and ($externalTesterPacketExecutableSmokeValidated -eq $true) `
    -and ($externalTesterConnectPackReady -eq $true) `
    -and ($externalTesterClientValidationPassed -eq $true) `
    -and ($externalTesterEvidenceValidationPassed -eq $true)
$opsSnapshot = $reports.opsSnapshot
$opsSnapshotStatus = Get-ReportStatus -Report $opsSnapshot
$opsSnapshotCriticalCount = [int](Get-AuditProp -Object $opsSnapshot -Name "criticalCount" -Default 999999)
$opsSnapshotBlockedCount = [int](Get-AuditProp -Object $opsSnapshot -Name "blockedCount" -Default 0)
$opsSnapshotChain = Get-AuditProp -Object $opsSnapshot -Name "chain"
$opsSnapshotLatestHeight = [string](Get-AuditProp -Object $opsSnapshotChain -Name "latestHeight" -Default "")
$opsSnapshotFinalizedHeight = [string](Get-AuditProp -Object $opsSnapshotChain -Name "finalizedHeight" -Default "")
$opsSnapshotPassed = $opsSnapshotExitCode -eq 0 `
    -and $opsSnapshotStatus -in @("passed", "blocked") `
    -and $opsSnapshotCriticalCount -eq 0 `
    -and (-not [string]::IsNullOrWhiteSpace($opsSnapshotLatestHeight)) `
    -and (-not [string]::IsNullOrWhiteSpace($opsSnapshotFinalizedHeight))
$opsAlertRules = $reports.opsAlertRules
$opsAlertRulesStatus = Get-ReportStatus -Report $opsAlertRules
$opsAlertRuleCount = [int](Get-AuditProp -Object $opsAlertRules -Name "ruleCount" -Default 0)
$opsAlertCriticalRuleCount = [int](Get-AuditProp -Object $opsAlertRules -Name "criticalRuleCount" -Default 0)
$opsAlertBlockedRuleCount = [int](Get-AuditProp -Object $opsAlertRules -Name "blockedRuleCount" -Default 0)
$opsAlertUnmappedCodes = @((Get-AuditProp -Object $opsAlertRules -Name "unmappedCurrentFindingCodes" -Default @()))
$opsAlertRulesWithoutCommands = @((Get-AuditProp -Object $opsAlertRules -Name "rulesWithoutCommands" -Default @()))
$opsAlertActiveRulesWithoutCommands = @((Get-AuditProp -Object $opsAlertRules -Name "activeRuleIdsWithoutCommands" -Default @()))
$opsAlertCommandsWithInlineEnvAssignment = @((Get-AuditProp -Object $opsAlertRules -Name "commandsWithInlineEnvAssignment" -Default @()))
$opsAlertCommandsWithUrls = @((Get-AuditProp -Object $opsAlertRules -Name "commandsWithUrls" -Default @()))
$opsAlertFindingsWithoutCommands = @((Get-AuditProp -Object $opsAlertRules -Name "findingsWithoutCommands" -Default @()))
$opsAlertFailedChecks = @((Get-AuditProp -Object $opsAlertRules -Name "failedChecks" -Default @()))
$opsAlertSecretFindings = @((Get-AuditProp -Object $opsAlertRules -Name "secretMarkerFindings" -Default @()))
$opsAlertChecks = Get-AuditProp -Object $opsAlertRules -Name "checks"
$opsAlertRequiredChecks = @(
    "opsSnapshotLoaded",
    "opsRefreshSucceeded",
    "ruleCountSufficient",
    "criticalRuleCountSufficient",
    "blockedRuleCountSufficient",
    "currentFindingsLoaded",
    "everyCurrentFindingMapped",
    "everyRuleHasCommands",
    "everyActiveRuleHasCommands",
    "commandsAvoidInlineEnvAssignment",
    "commandsAvoidUrls",
    "publicRpcEdgeHardeningRuleCoversRollbackDrill",
    "publicRpcEdgeHardeningRuleCoversOwnerHostApplyPlan",
    "backupRestoreValidationRuleCoversSafety",
    "backupOwnerPathDryRunRuleCoversOwnerPath",
    "bridgeDeployControlRuleCoversDeploymentControls",
    "supervisorNodeRecoveryRuleCoversLiveProfile",
    "bridgeRelayerLoopRuleCoversValidationTelemetry",
    "bridgeReconciliationRuleCoversCursorAndReplay",
    "serviceInstallValidationRuleCoversAutorecoveryTelemetry",
    "devPackRuleCoversBrowserStarter",
    "secondComputerRuleCoversBundleVerifyNoSecret",
    "findingsWithoutCommandsEmpty",
    "notificationPlanStoresNoSecrets",
    "notificationPlanNoNetworkDelivery",
    "envValuesPrintedFalse",
    "secretMarkerFindingsEmpty",
    "noSecrets",
    "broadcastsFalse"
)
$opsAlertMissingChecks = @(Get-MissingAuditChecks -Checks $opsAlertChecks -Names $opsAlertRequiredChecks)
$opsAlertFailedCheckCount = $opsAlertFailedChecks.Count
$opsAlertSecretFindingCount = $opsAlertSecretFindings.Count
$opsAlertMissingCheckCount = $opsAlertMissingChecks.Count
$opsAlertRulesPassed = $opsAlertRulesExitCode -eq 0 `
    -and $opsAlertRulesStatus -eq "passed" `
    -and $opsAlertFailedCheckCount -eq 0 `
    -and $opsAlertMissingCheckCount -eq 0 `
    -and $opsAlertSecretFindingCount -eq 0 `
    -and $opsAlertRuleCount -ge 10 `
    -and $opsAlertCriticalRuleCount -ge 5 `
    -and $opsAlertBlockedRuleCount -ge 5 `
    -and $opsAlertUnmappedCodes.Count -eq 0 `
    -and $opsAlertRulesWithoutCommands.Count -eq 0 `
    -and $opsAlertActiveRulesWithoutCommands.Count -eq 0 `
    -and $opsAlertCommandsWithInlineEnvAssignment.Count -eq 0 `
    -and $opsAlertCommandsWithUrls.Count -eq 0 `
    -and $opsAlertFindingsWithoutCommands.Count -eq 0 `
    -and ((Get-AuditProp -Object $opsAlertRules -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $opsAlertRules -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsAlertRules -Name "broadcasts" -Default $true) -eq $false)
$alertInstallValidation = $reports.alertInstallValidation
$alertInstallValidationStatus = Get-ReportStatus -Report $alertInstallValidation
$alertInstallValidationChecks = Get-AuditProp -Object $alertInstallValidation -Name "checks"
$alertInstallValidationFailedChecks = @((Get-AuditProp -Object $alertInstallValidation -Name "failedChecks" -Default @()))
$alertInstallValidationSecretFindings = @((Get-AuditProp -Object $alertInstallValidation -Name "secretMarkerFindings" -Default @()))
$alertInstallValidationFailedCheckCount = $alertInstallValidationFailedChecks.Count
$alertInstallValidationSecretFindingCount = $alertInstallValidationSecretFindings.Count
$alertInstallValidationPassed = $alertInstallValidationExitCode -eq 0 `
    -and $alertInstallValidationStatus -eq "passed" `
    -and $alertInstallValidationFailedCheckCount -eq 0 `
    -and $alertInstallValidationSecretFindingCount -eq 0 `
    -and ((Get-AuditProp -Object $alertInstallValidationChecks -Name "packageScriptsPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $alertInstallValidationChecks -Name "planDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $alertInstallValidationChecks -Name "statusDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $alertInstallValidationChecks -Name "uninstallAbsentDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $alertInstallValidationChecks -Name "systemdValidationPassed" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $alertInstallValidationChecks -Name "systemdPlanDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $alertInstallValidationChecks -Name "systemdServiceUnitPlanned" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $alertInstallValidationChecks -Name "systemdTimerUnitPlanned" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $alertInstallValidationChecks -Name "systemdNoExternalDelivery" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $alertInstallValidationChecks -Name "noExternalDelivery" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $alertInstallValidationChecks -Name "childReportsNoSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $alertInstallValidationChecks -Name "childReportsSecretMarkerFindingsEmpty" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $alertInstallValidationChecks -Name "secretMarkerFindingsEmpty" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $alertInstallValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $alertInstallValidation -Name "noSecrets" -Default $false) -eq $true)
$opsMetricsExport = $reports.opsMetricsExport
$opsMetricsExportStatus = Get-ReportStatus -Report $opsMetricsExport
$opsMetricsExportChecks = Get-AuditProp -Object $opsMetricsExport -Name "checks"
$opsMetricsExportFailedChecks = @((Get-AuditProp -Object $opsMetricsExport -Name "failedChecks" -Default @()))
$opsMetricsExportSecretFindings = @((Get-AuditProp -Object $opsMetricsExport -Name "secretMarkerFindings" -Default @()))
$opsMetricsExportMetricCount = [int](Get-AuditProp -Object $opsMetricsExport -Name "metricCount" -Default 0)
$opsMetricsExportPassed = $opsMetricsExportExitCode -eq 0 `
    -and $opsMetricsExportStatus -in @("passed", "blocked") `
    -and $opsMetricsExportFailedChecks.Count -eq 0 `
    -and $opsMetricsExportSecretFindings.Count -eq 0 `
    -and $opsMetricsExportMetricCount -ge 1 `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "opsSnapshotLoaded" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "prometheusTextWritten" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "metricsJsonWritten" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "requiredMetricsPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "backupRestoreValidationLoaded" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "backupRestoreValidationMetricsPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "backupOwnerPathDryRunLoaded" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "backupOwnerPathDryRunMetricsPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "publicRpcEdgeMetricsPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "publicRpcRollbackDrillMetricsPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "publicRpcOwnerHostApplyPlanMetricsPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "bridgeDeployControlMetricsPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "serviceInstallValidationMetricsPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "bridgeRelayerLoopValidationMetricsPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "bridgeReconciliationLoaded" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "bridgeReconciliationMetricsPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "bridgeReleaseEvidenceMetricsPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "externalTesterClientMetricsPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "secondComputerLoaded" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "secondComputerMetricsPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "devPackLoaded" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "devPackMetricsPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "supervisorNodeRecoveryMetricsPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "prometheusHasHelpAndType" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "envValuesPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "secretMarkerFindingsEmpty" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExportChecks -Name "broadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExport -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $opsMetricsExport -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsMetricsExport -Name "broadcasts" -Default $true) -eq $false)
$metricsInstallValidation = $reports.metricsInstallValidation
$metricsInstallValidationStatus = Get-ReportStatus -Report $metricsInstallValidation
$metricsInstallValidationChecks = Get-AuditProp -Object $metricsInstallValidation -Name "checks"
$metricsInstallValidationFailedChecks = @((Get-AuditProp -Object $metricsInstallValidation -Name "failedChecks" -Default @()))
$metricsInstallValidationSecretFindings = @((Get-AuditProp -Object $metricsInstallValidation -Name "secretMarkerFindings" -Default @()))
$metricsInstallValidationMissingPackageScripts = @((Get-AuditProp -Object $metricsInstallValidation -Name "missingPackageScripts" -Default @()))
$metricsInstallValidationFailedCheckCount = $metricsInstallValidationFailedChecks.Count
$metricsInstallValidationSecretFindingCount = $metricsInstallValidationSecretFindings.Count
$metricsInstallValidationMissingPackageScriptCount = $metricsInstallValidationMissingPackageScripts.Count
$metricsInstallValidationPassed = $metricsInstallValidationExitCode -eq 0 `
    -and $metricsInstallValidationStatus -eq "passed" `
    -and $metricsInstallValidationFailedCheckCount -eq 0 `
    -and $metricsInstallValidationSecretFindingCount -eq 0 `
    -and $metricsInstallValidationMissingPackageScriptCount -eq 0 `
    -and ((Get-AuditProp -Object $metricsInstallValidationChecks -Name "packageScriptsPresent" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $metricsInstallValidationChecks -Name "planDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $metricsInstallValidationChecks -Name "statusDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $metricsInstallValidationChecks -Name "uninstallAbsentDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $metricsInstallValidationChecks -Name "actionUsesMetricsScript" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $metricsInstallValidationChecks -Name "hasAllowBlocked" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $metricsInstallValidationChecks -Name "hasMetricsJsonPath" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $metricsInstallValidationChecks -Name "hasPrometheusTextPath" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $metricsInstallValidationChecks -Name "scheduledCommandDoesNotDisableRefresh" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $metricsInstallValidationChecks -Name "systemdValidationPassed" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $metricsInstallValidationChecks -Name "systemdPlanDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $metricsInstallValidationChecks -Name "systemdServiceUnitPlanned" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $metricsInstallValidationChecks -Name "systemdTimerUnitPlanned" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $metricsInstallValidationChecks -Name "systemdTimerIntervalConfigured" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $metricsInstallValidationChecks -Name "systemdNoExternalDelivery" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $metricsInstallValidationChecks -Name "noExternalDelivery" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $metricsInstallValidationChecks -Name "childReportsNoSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $metricsInstallValidationChecks -Name "childReportsSecretMarkerFindingsEmpty" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $metricsInstallValidationChecks -Name "secretMarkerFindingsEmpty" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $metricsInstallValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $metricsInstallValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $metricsInstallValidation -Name "broadcasts" -Default $true) -eq $false)
$opsEscalationDryRun = $reports.opsEscalationDryRun
$opsEscalationDryRunStatus = Get-ReportStatus -Report $opsEscalationDryRun
$opsEscalationDryRunChecks = Get-AuditProp -Object $opsEscalationDryRun -Name "checks"
$opsEscalationDryRunFailedChecks = @((Get-AuditProp -Object $opsEscalationDryRun -Name "failedChecks" -Default @()))
$opsEscalationDryRunSecretFindings = @((Get-AuditProp -Object $opsEscalationDryRun -Name "secretMarkerFindings" -Default @()))
$opsEscalationDryRunFailedCheckCount = $opsEscalationDryRunFailedChecks.Count
$opsEscalationDryRunSecretFindingCount = $opsEscalationDryRunSecretFindings.Count
$opsEscalationDryRunEventCount = [int](Get-AuditProp -Object $opsEscalationDryRun -Name "dryRunEventCount" -Default 0)
$opsEscalationDryRunPassed = $opsEscalationDryRunExitCode -eq 0 `
    -and $opsEscalationDryRunStatus -eq "passed" `
    -and $opsEscalationDryRunFailedCheckCount -eq 0 `
    -and $opsEscalationDryRunSecretFindingCount -eq 0 `
    -and $opsEscalationDryRunEventCount -ge 1 `
    -and ((Get-AuditProp -Object $opsEscalationDryRunChecks -Name "notificationPlanNoNetworkDelivery" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsEscalationDryRunChecks -Name "notificationPlanStoresNoSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsEscalationDryRunChecks -Name "everyCurrentFindingMapped" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsEscalationDryRunChecks -Name "everyCurrentFindingHasCommands" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsEscalationDryRunChecks -Name "dryRunEventsDoNotSend" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsEscalationDryRunChecks -Name "dryRunEventsStoreNoCredentials" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsEscalationDryRunChecks -Name "sourceReportsSecretMarkerFindingsEmpty" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsEscalationDryRunChecks -Name "secretMarkerFindingsEmpty" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsEscalationDryRun -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $opsEscalationDryRun -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $opsEscalationDryRun -Name "broadcasts" -Default $true) -eq $false)
$incidentDrill = $reports.incidentDrill
$incidentDrillStatus = Get-ReportStatus -Report $incidentDrill
$incidentDrillReady = Get-AuditProp -Object $incidentDrill -Name "incidentDrillReady" -Default $false
$incidentCaseCounts = Get-AuditProp -Object $incidentDrill -Name "caseCounts"
$incidentFailedCases = [int](Get-AuditProp -Object $incidentCaseCounts -Name "failed" -Default 999999)
$incidentTotalCases = [int](Get-AuditProp -Object $incidentCaseCounts -Name "total" -Default 0)
$incidentDrillChecks = Get-AuditProp -Object $incidentDrill -Name "checks"
$incidentDrillFailedChecks = @((Get-AuditProp -Object $incidentDrill -Name "failedChecks" -Default @()))
$incidentDrillSecretFindings = @((Get-AuditProp -Object $incidentDrill -Name "secretMarkerFindings" -Default @()))
$incidentDrillRequiredChecks = @(
    "incidentDrillReady",
    "ownerValuesRequiredFalse",
    "mutatesLiveStateFalse",
    "syntheticIncidentInputs",
    "allRequiredScenariosCovered",
    "allCasesPassed",
    "failedCasesAbsent",
    "minimumCaseCountMet",
    "publicTesterGatewayIncidentCovered",
    "recoveryCommandPrinted",
    "postDrillLiveStatusPassed",
    "liveStateBeforeReadable",
    "liveStateAfterReadable",
    "liveBlockHeightAdvancedOrEqual",
    "noLiveBroadcast",
    "broadcastsFalse",
    "envValuesPrintedFalse",
    "noSecrets",
    "secretMarkerFindingsEmpty"
)
$incidentDrillMissingChecks = Get-MissingAuditChecks -Checks $incidentDrillChecks -Names $incidentDrillRequiredChecks
$incidentDrillFailedCheckCount = @($incidentDrillFailedChecks | Where-Object { $null -ne $_ }).Count
$incidentDrillSecretFindingCount = @($incidentDrillSecretFindings | Where-Object { $null -ne $_ }).Count
$incidentDrillMissingCheckCount = @($incidentDrillMissingChecks | Where-Object { $null -ne $_ }).Count
$incidentDrillPassed = $incidentDrillExitCode -eq 0 `
    -and $incidentDrillStatus -eq "passed" `
    -and $incidentDrillReady -eq $true `
    -and $incidentDrillFailedCheckCount -eq 0 `
    -and $incidentDrillSecretFindingCount -eq 0 `
    -and $incidentDrillMissingCheckCount -eq 0 `
    -and $incidentFailedCases -eq 0 `
    -and $incidentTotalCases -ge 20 `
    -and ((Get-AuditProp -Object $incidentDrill -Name "mutatesLiveState" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $incidentDrill -Name "noLiveBroadcast" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $incidentDrill -Name "broadcasts" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $incidentDrill -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $incidentDrill -Name "noSecrets" -Default $false) -eq $true)
$productionLocalAggregateStatus = [string](Get-AuditProp -Object $liveProduct -Name "productionLocalAggregateStatus")
$liveProductLiveInfraStatus = [string](Get-AuditProp -Object $liveProduct -Name "liveInfraStatus")
$liveProductNoLiveBroadcast = Get-AuditProp -Object $liveProduct -Name "noLiveBroadcast"
$liveProductEnvValuesPrinted = Get-AuditProp -Object $liveProduct -Name "envValuesPrinted"
$liveInfraStatus = Get-ReportStatus -Report $liveInfra
$liveInfraReadiness = Get-AuditProp -Object $liveInfra -Name "readiness"
$liveInfraOwnerInputsReady = Get-AuditProp -Object $liveInfraReadiness -Name "ownerInputsReady" -Default $false
$liveInfraPublicRpcReady = Get-AuditProp -Object $liveInfraReadiness -Name "publicRpcReady" -Default $false
$liveInfraServicesReady = Get-AuditProp -Object $liveInfraReadiness -Name "servicesReady" -Default $false
$liveInfraBackupReady = Get-AuditProp -Object $liveInfraReadiness -Name "backupReady" -Default $false
$liveInfraBridgeReady = Get-AuditProp -Object $liveInfraReadiness -Name "bridgeReady" -Default $false
$liveInfraNoSecretReady = Get-AuditProp -Object $liveInfraReadiness -Name "noSecretReady" -Default $false
$bridgePilotLocal = $reports.bridgePilotLocal
$bridgePilotExactValue = Get-AuditProp -Object $bridgePilotLocal -Name "exactValueConservation"
$bridgePilotNegative = Get-AuditProp -Object $bridgePilotLocal -Name "negativeCoverage"
$bridgePilotChecks = Get-AuditProp -Object $bridgePilotLocal -Name "checks"
$bridgePilotFailedChecks = @((Get-AuditProp -Object $bridgePilotLocal -Name "failedChecks" -Default @()) | Where-Object { $null -ne $_ })
$bridgePilotStatus = Get-ReportStatus -Report $bridgePilotLocal
$bridgePilotBroadcast = Get-AuditProp -Object $bridgePilotLocal -Name "broadcast"
$bridgePilotNoSecrets = Get-AuditProp -Object $bridgePilotLocal -Name "noSecrets"
$bridgePilotAllAmountsEqual = Get-AuditProp -Object $bridgePilotExactValue -Name "allAmountsEqual"
$bridgePilotWrongChainRejected = Get-AuditProp -Object $bridgePilotNegative -Name "wrongChainRejected"
$bridgePilotUnapprovedContractRejected = Get-AuditProp -Object $bridgePilotNegative -Name "unapprovedContractRejected"
$bridgePilotRequiredCheckNames = @(
    "sourceChainIsBase8453",
    "firstCreditApplied",
    "firstApplicationAppliedOnce",
    "replayCreditRejected",
    "replayApplicationIdempotent",
    "duplicateReplayRejected",
    "exactValueConserved",
    "wrongChainRejected",
    "unapprovedContractRejected",
    "withdrawalIntentCreated",
    "releaseEvidenceNoBroadcast",
    "noLiveBroadcast",
    "noSecrets"
)
$bridgePilotMissingChecks = @(Get-MissingAuditChecks -Checks $bridgePilotChecks -Names $bridgePilotRequiredCheckNames)
$bridgePilotLocalPassed = $bridgePilotLocalExitCode -eq 0 `
    -and $null -ne $bridgePilotLocal `
    -and $bridgePilotStatus -eq "passed" `
    -and $bridgePilotBroadcast -eq $false `
    -and $bridgePilotNoSecrets -eq $true `
    -and $bridgePilotAllAmountsEqual -eq $true `
    -and $bridgePilotWrongChainRejected -eq $true `
    -and $bridgePilotUnapprovedContractRejected -eq $true `
    -and $bridgePilotFailedChecks.Count -eq 0 `
    -and $bridgePilotMissingChecks.Count -eq 0
$baseTxDiagnostic = $reports.baseTxDiagnostic
$baseTxDiagnosticStatus = Get-ReportStatus -Report $baseTxDiagnostic
$baseTxDiagnosticSafeReason = [string](Get-AuditProp -Object $baseTxDiagnostic -Name "safeReasonCode")
$baseTxDiagnosticBroadcasts = Get-AuditProp -Object $baseTxDiagnostic -Name "broadcasts"
$baseTxDiagnosticPrintsEnvValues = Get-AuditProp -Object $baseTxDiagnostic -Name "printsEnvValues"
$baseTxDiagnosticNoSecrets = Get-AuditProp -Object $baseTxDiagnostic -Name "noSecrets"
$baseTxDiagnosticFailClosedPassed = $null -ne $baseTxDiagnostic `
    -and $baseTxDiagnosticStatus -eq "blocked" `
    -and $baseTxDiagnosticSafeReason -eq "missing-env" `
    -and $baseTxDiagnosticBroadcasts -eq $false `
    -and $baseTxDiagnosticPrintsEnvValues -eq $false `
    -and $baseTxDiagnosticNoSecrets -eq $true
$baseTxDiagnosticWithOwnerInputPassed = $null -ne $baseTxDiagnostic `
    -and $baseTxDiagnosticStatus -in @("valid", "invalid") `
    -and $baseTxDiagnosticBroadcasts -eq $false `
    -and $baseTxDiagnosticPrintsEnvValues -eq $false `
    -and $baseTxDiagnosticNoSecrets -eq $true
$baseTxDiagnosticPassed = $baseTxDiagnosticFailClosedPassed -or $baseTxDiagnosticWithOwnerInputPassed
$publicDeploymentContract = $reports.publicDeploymentContract
$publicDeploymentContractStatus = Get-ReportStatus -Report $publicDeploymentContract
$publicDeploymentContractCounts = Get-AuditProp -Object $publicDeploymentContract -Name "itemCounts"
$publicDeploymentContractFailed = [int](Get-AuditProp -Object $publicDeploymentContractCounts -Name "failed" -Default 1)
$publicDeploymentContractBlocked = [int](Get-AuditProp -Object $publicDeploymentContractCounts -Name "blocked" -Default 0)
$publicDeploymentContractBlockedOnlyKnown = Get-AuditProp -Object $publicDeploymentContract -Name "blockedOnlyOnKnownExternalOwnerInputs" -Default $false
$publicDeploymentContractDeploymentReady = Get-AuditProp -Object $publicDeploymentContract -Name "deploymentReady" -Default $false
$publicDeploymentContractPacketShareable = Get-AuditProp -Object $publicDeploymentContract -Name "packetShareable" -Default $false
$publicDeploymentContractPacketSmoke = Get-AuditProp -Object $publicDeploymentContract -Name "packetExecutableSmokeValidated" -Default $false
$publicDeploymentContractSafe = ($publicDeploymentContractExitCode -eq 0) `
    -and ($publicDeploymentContractStatus -in @("passed", "blocked")) `
    -and ($publicDeploymentContractFailed -eq 0) `
    -and ($publicDeploymentContractBlockedOnlyKnown -eq $true) `
    -and ($publicDeploymentContractPacketSmoke -eq $true) `
    -and ((Get-AuditProp -Object $publicDeploymentContract -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicDeploymentContract -Name "noLiveBroadcast" -Default $false) -eq $true)
$architectureAudit = $reports.architectureAudit
$architectureAuditStatus = Get-ReportStatus -Report $architectureAudit
$architectureAuditCounts = Get-AuditProp -Object $architectureAudit -Name "itemCounts"
$architectureAuditFailed = [int](Get-AuditProp -Object $architectureAuditCounts -Name "failed" -Default 1)
$architectureAuditBlocked = [int](Get-AuditProp -Object $architectureAuditCounts -Name "blocked" -Default 0)
$architectureAuditBlockedOnlyKnown = Get-AuditProp -Object $architectureAudit -Name "blockedOnlyOnKnownExternalOwnerInputs" -Default $false
$architectureAuditNoSecrets = Get-AuditProp -Object $architectureAudit -Name "noSecrets" -Default $false
$architectureAuditNoBroadcast = Get-AuditProp -Object $architectureAudit -Name "noLiveBroadcast" -Default $false
$architectureAuditReady = ($architectureAuditExitCode -eq 0) `
    -and ($architectureAuditStatus -in @("passed", "blocked")) `
    -and ($architectureAuditFailed -eq 0) `
    -and ($architectureAuditBlockedOnlyKnown -eq $true) `
    -and ($architectureAuditNoSecrets -eq $true) `
    -and ($architectureAuditNoBroadcast -eq $true)

$items = New-Object System.Collections.ArrayList

Add-AuditItem -Items $items -Id "service-live-profile" `
    -Requirement "Chain service is running in live profile and command lines match this worktree." `
    -Status $(if ($serviceReady) { "passed" } else { "failed" }) `
    -Evidence "service-status status=$(Get-ReportStatus -Report $service), node=$nodeStatus, controlPlane=$controlPlaneStatus, failedChecks=$serviceFailedCheckCount, missingChecks=$serviceMissingCheckCount, secretFindings=$serviceSecretFindingCount, problems=$($serviceProblems.Count), report=$($paths.serviceStatus)" `
    -Commands @("npm run flowchain:service:status")

Add-AuditItem -Items $items -Id "block-production" `
    -Requirement "Chain is producing/finalizing blocks and state is fresh." `
    -Status $(if ($chainProducing) { "passed" } else { "failed" }) `
    -Evidence "latestHeight=$latestHeight, stateFileLastWriteAgeSeconds=$stateAge, report=$($paths.serviceStatus)" `
    -Commands @("npm run flowchain:service:status")

Add-AuditItem -Items $items -Id "operator-doctor" `
    -Requirement "Operator doctor checks host tools, package scripts, state path, disk, service evidence, ports, owner-input groups, and owner env-file status without printing owner values." `
    -Status $(if ($operatorDoctorReady) { "passed" } else { "failed" }) `
    -Evidence "doctorStatus=$operatorDoctorStatus, checks=$operatorDoctorCheckCount, failedChecks=$($operatorDoctorFailedChecks.Count), blockedChecks=$($operatorDoctorBlockedChecks.Count), blockedOnlyOwner=$operatorDoctorBlockedOnlyOwnerInputs, report=$($paths.operatorDoctor)" `
    -Commands @("npm run flowchain:doctor -- -ReportPath docs/agent-runs/live-product-infra-rpc/operator-doctor-report.json")

Add-AuditItem -Items $items -Id "sustained-block-production" `
    -Requirement "Live service monitor observes running services and advancing block height over a sampling window." `
    -Status $(if ($monitorPassed) { "passed" } else { "failed" }) `
    -Evidence "monitorStatus=$monitorStatus, samples=$monitorSampleCount, heightAdvanced=$monitorHeightAdvanced, heights=$monitorFirstHeight->$monitorLatestHeight, failedChecks=$monitorFailedCheckCount, missingChecks=$monitorMissingCheckCount, secretFindings=$monitorSecretFindingCount, issues=$($monitorIssues.Count), report=$($paths.serviceMonitor)" `
    -Commands @("npm run flowchain:service:monitor -- -DurationSeconds $MonitorDurationSeconds -PollSeconds $MonitorPollSeconds -MaxStateAgeSeconds $MonitorMaxStateAgeSeconds")

Add-AuditItem -Items $items -Id "service-supervisor-autorecovery" `
    -Requirement "Live service supervisor can recover crashed local node, control-plane, and bridge-relayer-loop processes under the live profile without deleting chain state." `
    -Status $(if ($serviceSupervisorValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "supervisorValidation=$serviceSupervisorValidationStatus, restartAttempts=$serviceSupervisorRestartAttempts, nodeRestartAttempts=$serviceSupervisorNodeRestartAttempts, relayerRestartAttempts=$serviceSupervisorRelayerRestartAttempts, failedChecks=$($serviceSupervisorFailedChecks.Count), missingChecks=$($serviceSupervisorMissingChecks.Count), secretFindings=$($serviceSupervisorSecretFindings.Count), before=$(Get-AuditProp -Object $serviceSupervisorBefore -Name "status" -Default "missing"), afterCrash=$(Get-AuditProp -Object $serviceSupervisorAfterCrash -Name "status" -Default "missing"), afterRecovery=$(Get-AuditProp -Object $serviceSupervisorAfterRecovery -Name "status" -Default "missing"), nodeAfterCrash=$(Get-AuditProp -Object $serviceSupervisorNodeAfterCrash -Name "nodeStatus" -Default "missing"), nodeAfterRecovery=$(Get-AuditProp -Object $serviceSupervisorNodeAfterRecovery -Name "nodeRunning" -Default $false), relayerAfterCrash=$(Get-AuditProp -Object $serviceSupervisorRelayerAfterCrash -Name "loopStatus" -Default "missing"), relayerAfterRecovery=$(Get-AuditProp -Object $serviceSupervisorRelayerAfterRecovery -Name "loopStatus" -Default "missing"), report=$($paths.serviceSupervisorValidation)" `
    -Commands @("npm run flowchain:service:supervisor:validate")

Add-AuditItem -Items $items -Id "service-install-validation" `
    -Requirement "Owner-host Windows service install validation proves no-secret Scheduled Task plan/status/uninstall no-op behavior and a bridge-relayer opt-in plan for reboot-persistent live supervisor operation." `
    -Status $(if ($serviceInstallValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "serviceInstall=$serviceInstallValidationStatus, failedChecks=$serviceInstallFailedCheckCount, missingChecks=$serviceInstallMissingCheckCount, secretFindings=$serviceInstallSecretFindingCount, missingScripts=$($serviceInstallMissingPackageScripts.Count), planDidNotMutate=$(Get-AuditProp -Object $serviceInstallChecks -Name "planDidNotMutate" -Default $false), statusDidNotMutate=$(Get-AuditProp -Object $serviceInstallChecks -Name "statusDidNotMutate" -Default $false), relayerOptIn=$(Get-AuditProp -Object $serviceInstallChecks -Name "bridgeRelayerOptInStartsLoop" -Default $false), report=$($paths.serviceInstallValidation)" `
    -Commands @("npm run flowchain:service:install:validate", "npm run flowchain:service:install:windows -- -Action Plan")

Add-AuditItem -Items $items -Id "systemd-service-install-validation" `
    -Requirement "Owner-host Linux/VPS service install validation proves a real no-secret systemd plan/install/status/uninstall script plus bridge-relayer opt-in plan can plan from rendered live-service and supervisor units without mutating the host." `
    -Status $(if ($systemdServiceInstallValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "systemdInstall=$systemdServiceInstallValidationStatus, failedChecks=$systemdServiceInstallFailedCheckCount, missingChecks=$systemdServiceInstallMissingCheckCount, secretFindings=$systemdServiceInstallSecretFindingCount, installScript=$(Get-AuditProp -Object $systemdServiceInstallChecks -Name "installScriptExists" -Default $false), plan=$(Get-AuditProp -Object $systemdServiceInstallChecks -Name "installPlanValidationPassed" -Default $false), planDidNotMutate=$(Get-AuditProp -Object $systemdServiceInstallChecks -Name "installPlanDidNotMutate" -Default $false), renderedUnits=$(Get-AuditProp -Object $systemdServiceInstallChecks -Name "installPlanUsesRenderedUnits" -Default $false), relayerDefaultOff=$(Get-AuditProp -Object $systemdServiceInstallChecks -Name "bridgeRelayerDefaultOff" -Default $false), relayerOptIn=$(Get-AuditProp -Object $systemdServiceInstallChecks -Name "bridgeRelayerOptInStartsLoop" -Default $false), report=$($paths.systemdServiceInstallValidation)" `
    -Commands @("npm run flowchain:service:install:systemd:validate", "npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>", "npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -StartBridgeRelayerLoop")

Add-AuditItem -Items $items -Id "upgrade-rehearsal" `
    -Requirement "State-preserving upgrade and rollback rehearsal copies live L1 state, verifies matching hashes after next-release and rollback restore, and documents exact operator commands without host mutation." `
    -Status $(if ($upgradeRehearsalPassed) { "passed" } else { "failed" }) `
    -Evidence "upgradeRehearsal=$upgradeRehearsalStatus, failedChecks=$upgradeRehearsalFailedCheckCount, missingChecks=$upgradeRehearsalMissingCheckCount, secretFindings=$upgradeRehearsalSecretFindingCount, stateHashPresent=$(Get-AuditProp -Object $upgradeRehearsalChecks -Name "sourceStateHashPresent" -Default $false), nextStateMatches=$(Get-AuditProp -Object $upgradeRehearsalChecks -Name "nextStateHashMatchesSource" -Default $false), rollbackStateMatches=$(Get-AuditProp -Object $upgradeRehearsalChecks -Name "rollbackStateHashMatchesSource" -Default $false), report=$($paths.upgradeRehearsal)" `
    -Commands @("npm run flowchain:upgrade:rehearse")

Add-AuditItem -Items $items -Id "install-check" `
    -Requirement "Top-level owner-host install check verifies tools, package commands, install runbooks, Windows service install validation, Linux systemd validation, and no-secret boundaries as one operator preflight." `
    -Status $(if ($installCheckPassed) { "passed" } else { "failed" }) `
    -Evidence "installCheck=$installCheckStatus, failedChecks=$installCheckFailedCheckCount, missingChecks=$installCheckMissingCheckCount, secretFindings=$installCheckSecretFindingCount, missingScripts=$($installCheckMissingScripts.Count), missingDocs=$($installCheckMissingDocs.Count), childValidations=$(Get-AuditProp -Object $installCheckChecks -Name "childValidationsPassed" -Default $false), ownerInputBlockerAllowed=$(Get-AuditProp -Object $installCheckChecks -Name "ownerInputAbsenceIsNonRepoBlocker" -Default $false), report=$($paths.installCheck)" `
    -Commands @("npm run flowchain:install:check")

Add-AuditItem -Items $items -Id "wallet-create" `
    -Requirement "People can create wallets through the RPC service without receiving secret material." `
    -Status $(if ($testerNetworkPassed -and $testerWalletCreatesCount -ge 4) { "passed" } else { "failed" }) `
    -Evidence "testerWalletCreates=$testerWalletCreatesCount, failedChecks=$testerNetworkFailedCheckCount, secretFindings=$testerNetworkSecretFindingCount, missingChecks=$testerNetworkMissingCheckCount, secretMaterialReturned=false, report=$($paths.testerNetwork)" `
    -Commands @("npm run flowchain:wallet:live-tester:e2e")

Add-AuditItem -Items $items -Id "wallet-transfer" `
    -Requirement "Wallet-to-wallet transfers sent through the running service settle on produced blocks." `
    -Status $(if ($liveWalletPassed) { "passed" } else { "failed" }) `
    -Evidence "single-transfer blocks $liveWalletBefore->$liveWalletAfter, failedChecks=$liveWalletFailedCheckCount, secretFindings=$liveWalletSecretFindingCount, missingChecks=$liveWalletMissingCheckCount, report=$($paths.liveWallet)" `
    -Commands @("npm run flowchain:wallet:live-service:e2e")

Add-AuditItem -Items $items -Id "tester-network-transfer" `
    -Requirement "A small tester group can create wallets, receive funds, and send funds to each other through the running service." `
    -Status $(if ($testerNetworkPassed) { "passed" } else { "failed" }) `
    -Evidence "testerCount=$testerCount, transfers=$testerTransferCount, blocks=$testerNetworkBefore->$testerNetworkAfter, failedChecks=$testerNetworkFailedCheckCount, secretFindings=$testerNetworkSecretFindingCount, missingChecks=$testerNetworkMissingCheckCount, report=$($paths.testerNetwork)" `
    -Commands @("npm run flowchain:wallet:live-tester:e2e")

Add-AuditItem -Items $items -Id "rpc-connect-local" `
    -Requirement "Clients can connect to the private RPC service for health, discovery, readiness, chain, and wallet methods." `
    -Status $(if ((Get-ReportStatus -Report $externalTester) -eq "blocked" -and $localTesterRehearsalReady -eq $true) { "passed" } else { "failed" }) `
    -Evidence "localTesterRehearsalReady=$localTesterRehearsalReady, latestHeight=$externalTesterHeight, report=$($paths.externalTester)" `
    -Commands @("npm run flowchain:tester:readiness -- -AllowBlocked")

Add-AuditItem -Items $items -Id "developer-dev-pack" `
    -Requirement "Developer SDK/devkit proof connects to the real RPC, checks readiness/discovery, reads wallet data, submits runtime-backed local wallet sends, proves CLI examples, signed-envelope submission, packaged Vite/React browser starter build/smoke, OpenAPI/Postman/cURL docs, Python SDK/devkit, and keeps public readiness fail-closed." `
    -Status $(if ($devPackPassed) { "passed" } else { "failed" }) `
    -Evidence "devPackStatus=$(Get-ReportStatus -Report $devPack), heights=$devPackFirstHeight->$devPackSecondHeight, methodCount=$devPackMethodCount, publicReadyMethodCount=$devPackPublicReadyMethodCount, missingChecks=$($devPackMissingChecks.Count), failedChecks=$($devPackFailedChecks.Count), languageSdks=$($devPackLanguageSdks.Count), missingReportPaths=$($devPackMissingReportPathNames.Count), noLiveBroadcast=$(Get-AuditProp -Object $devPack -Name "noLiveBroadcast" -Default $false), report=$($paths.devPack)" `
    -Commands @("npm run flowchain:dev-pack:e2e")

Add-AuditItem -Items $items -Id "system-architecture-audit" `
    -Requirement "System architecture for runtime, RPC, wallets, bridge, backup, operations, verification, and fail-closed owner boundaries is explicit and evidence-backed." `
    -Status $(if ($architectureAuditReady) { "passed" } else { "failed" }) `
    -Evidence "architectureStatus=$architectureAuditStatus, blockedOnlyOnKnownExternalOwnerInputs=$architectureAuditBlockedOnlyKnown, blockedItems=$architectureAuditBlocked, failedItems=$architectureAuditFailed, report=$($paths.architectureAudit)" `
    -Commands @("npm run flowchain:architecture:audit -- -AllowBlocked")

Add-AuditItem -Items $items -Id "public-deployment-contract" `
    -Requirement "Owner-operated public deployment contract is machine-checkable, has rollback commands, and fails closed until public RPC, backup, bridge, and tester sharing gates pass." `
    -Status $(if ($publicDeploymentContractSafe) { "passed" } else { "failed" }) `
    -Evidence "deploymentStatus=$publicDeploymentContractStatus, deploymentReady=$publicDeploymentContractDeploymentReady, packetShareable=$publicDeploymentContractPacketShareable, packetSmoke=$publicDeploymentContractPacketSmoke, blockedOnlyKnown=$publicDeploymentContractBlockedOnlyKnown, blockedItems=$publicDeploymentContractBlocked, failedItems=$publicDeploymentContractFailed, report=$($paths.publicDeploymentContract)" `
    -Commands @("npm run flowchain:public-deployment:contract -- -AllowBlocked")

Add-AuditItem -Items $items -Id "owner-input-validator-self-test" `
    -Requirement "Owner input validator blocks missing env, fails invalid env, passes structurally valid dummy owner inputs from direct env and the local owner env-file loader, and writes failed reports for missing or malformed owner env files without printing values." `
    -Status $(if ($ownerInputsValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "validationStatus=$ownerInputsValidationStatus, missingBlocks=$ownerInputsValidationMissingBlocks, invalidFails=$ownerInputsValidationInvalidFails, validPasses=$ownerInputsValidationValidPasses, ownerEnvFilePasses=$ownerInputsValidationEnvFilePasses, missingOwnerEnvFileFails=$ownerInputsValidationMissingEnvFileFails, malformedOwnerEnvFileFails=$ownerInputsValidationMalformedEnvFileFails, report=$($paths.ownerInputsValidation)" `
    -Commands @("npm run flowchain:owner-inputs:validate")

Add-AuditItem -Items $items -Id "owner-input-contract" `
    -Requirement "Owner public RPC, tester write gateway, backup, and Base 8453 bridge inputs are validated without printing values." `
    -Status $(if ($ownerInputsStatus -eq "passed" -and $ownerInputsReady -eq $true) { "passed" } elseif ($ownerInputsStatus -eq "blocked") { "blocked" } else { "failed" }) `
    -Evidence "ownerInputsStatus=$ownerInputsStatus, ownerInputReady=$ownerInputsReady, report=$($paths.ownerInputs)" `
    -Commands @("npm run flowchain:owner-inputs") `
    -Blockers @($missingEnv)

Add-AuditItem -Items $items -Id "owner-onboarding-packet" `
    -Requirement "Owner onboarding distinguishes repo-owned FlowChain RPC from the external Base 8453 RPC dependency and gives no-values setup commands." `
    -Status $(if ($ownerOnboardingPassed) { "passed" } else { "failed" }) `
    -Evidence "onboardingStatus=$ownerOnboardingStatus, flowChainRpcIsOurs=$ownerOnboardingFlowChainRpcIsOurs, thirdPartyFlowChainRpcProviderNeeded=$ownerOnboardingThirdPartyFlowChainRpcProviderNeeded, publicRpcRequiresOwnerPublicEdge=$ownerOnboardingPublicEdgeRequired, base8453RpcIsExternalChainDependency=$ownerOnboardingBaseExternal, localEnvFileSupported=$ownerOnboardingLocalEnvFileSupported, failedChecks=$ownerOnboardingFailedCheckCount, secretFindings=$ownerOnboardingSecretFindingCount, missingChecks=$ownerOnboardingMissingCheckCount, report=$($paths.ownerOnboarding)" `
    -Commands @("npm run flowchain:owner:onboarding")

Add-AuditItem -Items $items -Id "owner-signup-checklist" `
    -Requirement "Owner signup checklist maps public RPC edge, tester write token/cap, always-on host, backup storage, Base 8453 RPC, bridge details, and local env-file setup to exact owner actions without requesting secrets." `
    -Status $(if ($ownerSignupChecklistPassed) { "passed" } else { "failed" }) `
    -Evidence "signupStatus=$ownerSignupChecklistStatus, itemCount=$ownerSignupItemCount, externalSignupCount=$ownerSignupExternalCount, missingCoverage=$ownerSignupMissingCoverageCount, repoOwned=$ownerSignupRepoOwned, localEnvFileSupported=$ownerSignupLocalEnvFileSupported, failedChecks=$ownerSignupFailedCheckCount, secretFindings=$ownerSignupSecretFindingCount, missingChecks=$ownerSignupMissingCheckCount, report=$($paths.ownerSignupChecklist)" `
    -Commands @("npm run flowchain:owner:signup-checklist")

Add-AuditItem -Items $items -Id "owner-activation-plan" `
    -Requirement "Owner activation plan turns remaining public launch inputs into ordered stages with exact validation commands, resource boundaries, and no-secret handoff instructions." `
    -Status $(if ($ownerActivationPlanPassed) { "passed" } else { "failed" }) `
    -Evidence "activationPlanStatus=$ownerActivationPlanStatus, activationReady=$ownerActivationPlanActivationReady, stages=$ownerActivationPlanStageCount, readyStages=$ownerActivationPlanReadyStageCount, failedChecks=$ownerActivationPlanFailedCheckCount, secretFindings=$ownerActivationPlanSecretFindingCount, missingChecks=$ownerActivationPlanMissingCheckCount, report=$($paths.ownerActivationPlan)" `
    -Commands @("npm run flowchain:owner:activation-plan")

Add-AuditItem -Items $items -Id "owner-go-live-handoff" `
    -Requirement "Owner go-live handoff converts the remaining owner inputs and activation stages into one ordered launch sequence with expected statuses, stop-on-failure gates, rollback commands, and no-secret boundaries." `
    -Status $(if ($ownerGoLiveHandoffPassed) { "passed" } else { "failed" }) `
    -Evidence "handoffStatus=$ownerGoLiveHandoffStatus, releaseReady=$ownerGoLiveHandoffReleaseReady, stages=$ownerGoLiveHandoffStageCount, launchSteps=$ownerGoLiveHandoffLaunchSequenceCount, launchCommands=$ownerGoLiveHandoffLaunchSequenceCommandCount, evidenceReports=$ownerGoLiveHandoffExpectedReportPathCount, invalidEvidenceReports=$($ownerGoLiveHandoffInvalidExpectedReportPaths.Count), missingRequiredInputs=$($ownerGoLiveHandoffMissingRequired.Count), missingOptionalInputs=$($ownerGoLiveHandoffMissingOptional.Count), neededNowOptionalInputs=$($ownerGoLiveHandoffNextOptionalInputs.Count), missingLaunchScripts=$($ownerGoLiveHandoffMissingLaunchPackageScripts.Count), rollbackCommands=$ownerGoLiveHandoffRollbackCommandCount, missingRollbackScripts=$($ownerGoLiveHandoffMissingRollbackPackageScripts.Count), failedChecks=$ownerGoLiveHandoffFailedCheckCount, secretFindings=$ownerGoLiveHandoffSecretFindingCount, missingChecks=$ownerGoLiveHandoffMissingCheckCount, report=$($paths.ownerGoLiveHandoff)" `
    -Commands @("npm run flowchain:owner:go-live-handoff")

Add-AuditItem -Items $items -Id "owner-env-template" `
    -Requirement "Owner env-file setup has a command-generated local scaffold whose target path is git-ignored before owner values are added." `
    -Status $(if ($ownerEnvTemplatePassed) { "passed" } else { "failed" }) `
    -Evidence "templateStatus=$ownerEnvTemplateStatus, pathIsGitIgnored=$ownerEnvTemplateGitIgnored, requiredEnvNameCount=$ownerEnvTemplateRequiredCount, optionalEnvNameCount=$ownerEnvTemplateOptionalCount, includesAllRequired=$ownerEnvTemplateIncludesRequired, failedChecks=$ownerEnvTemplateFailedCheckCount, secretFindings=$ownerEnvTemplateSecretFindingCount, missingChecks=$ownerEnvTemplateMissingCheckCount, report=$($paths.ownerEnvTemplate)" `
    -Commands @("npm run flowchain:owner-env:template")

Add-AuditItem -Items $items -Id "owner-env-readiness-validator-self-test" `
    -Requirement "Owner env readiness validator fails closed before child gates for missing owner env files and repo-local env files that are not git-ignored." `
    -Status $(if ($ownerEnvReadinessValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "validationStatus=$ownerEnvReadinessValidationStatus, missingFails=$ownerEnvReadinessValidationMissingFails, unignoredFails=$ownerEnvReadinessValidationUnignoredFails, failedChecks=$ownerEnvReadinessValidationFailedCheckCount, secretFindings=$ownerEnvReadinessValidationSecretFindingCount, missingChecks=$ownerEnvReadinessValidationMissingCheckCount, report=$($paths.ownerEnvReadinessValidation)" `
    -Commands @("npm run flowchain:owner-env:readiness:validate")

Add-AuditItem -Items $items -Id "owner-env-readiness" `
    -Requirement "The ignored owner env file can drive owner-input, live-infra, and public deployment gates through one redacted command." `
    -Status $(if ($ownerEnvReadinessStatus -eq "passed" -and $ownerEnvReadinessKnownSafe) { "passed" } elseif ($ownerEnvReadinessStatus -eq "blocked" -and $ownerEnvReadinessKnownSafe) { "blocked" } else { "failed" }) `
    -Evidence "readinessStatus=$ownerEnvReadinessStatus, pathGitIgnored=$ownerEnvReadinessGitIgnored, ownerInputsReady=$ownerEnvReadinessOwnerInputsReady, liveInfraReady=$ownerEnvReadinessLiveInfraReady, publicDeploymentContractReady=$ownerEnvReadinessDeploymentReady, blockedOnlyKnown=$ownerEnvReadinessBlockedOnlyKnown, report=$($paths.ownerEnvReadiness)" `
    -Commands @("npm run flowchain:owner-env:readiness -- -AllowBlocked") `
    -Blockers @($missingEnv)

Add-AuditItem -Items $items -Id "public-rpc-edge-template" `
    -Requirement "Public RPC exposure has a no-values owner edge template for HTTPS reverse proxying, rate limiting, and CORS-origin forwarding." `
    -Status $(if ($publicRpcEdgeTemplatePassed) { "passed" } else { "failed" }) `
    -Evidence "edgeTemplateStatus=$publicRpcEdgeTemplateStatus, repoOwned=$publicRpcEdgeTemplateRepoOwned, requiresTls=$publicRpcEdgeTemplateRequiresTls, requiresRateLimit=$publicRpcEdgeTemplateRequiresRateLimit, forwardsOrigin=$publicRpcEdgeTemplateForwardsOrigin, report=$($paths.publicRpcEdgeTemplate)" `
    -Commands @("npm run flowchain:public-rpc:edge-template")

Add-AuditItem -Items $items -Id "public-rpc-deployment-bundle" `
    -Requirement "Public RPC deployment bundle has no-secret Nginx, owner env, owner render validation, tester write preflight, wallet/tester cutover verification, disallowed-origin and blocked-private-path probes, verification, and rollback artifacts for exposing FlowChain's own RPC." `
    -Status $(if ($publicRpcDeploymentBundlePassed) { "passed" } else { "failed" }) `
    -Evidence "bundleStatus=$publicRpcDeploymentBundleStatus, repoOwned=$publicRpcDeploymentBundleRepoOwned, nginxTemplate=$publicRpcDeploymentBundleNginxTemplate, renderValidation=$publicRpcDeploymentBundleRenderValidation, testerWritePreflight=$publicRpcDeploymentBundleTesterWritePreflight, disallowedOriginPreflight=$(Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "includesDisallowedOriginPreflight" -Default $false), blockedStatePreflight=$(Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "includesBroadStateBlockedPreflight" -Default $false), privateWalletCreateBlocked=$(Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "includesPrivateWalletCreateBlockedPreflight" -Default $false), authForwardingScoped=$(Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "authorizationForwardingScopedToTesterWrite" -Default $false), failedChecks=$publicRpcDeploymentBundleFailedCheckCount, missingChecks=$publicRpcDeploymentBundleMissingCheckCount, secretFindings=$publicRpcDeploymentBundleSecretFindingCount, verifyRunbook=$publicRpcDeploymentBundleVerifyRunbook, rollbackRunbook=$publicRpcDeploymentBundleRollbackRunbook, report=$($paths.publicRpcDeploymentBundle)" `
    -Commands @("npm run flowchain:public-rpc:deployment-bundle")

Add-AuditItem -Items $items -Id "public-rpc-deployment-automation" `
    -Requirement "Public RPC deployment automation validates owner-host rendering of concrete Nginx, systemd, shell preflight, Windows preflight, tester write unauthenticated rejection probe, wallet/tester cutover proof commands, synthetic public RPC canary, disallowed-origin and blocked-private-path probes, post-deploy verification, and rollback phases without host mutation or owner-value leakage." `
    -Status $(if ($publicRpcDeploymentAutomationPassed) { "passed" } else { "failed" }) `
    -Evidence "automationStatus=$publicRpcDeploymentAutomationStatus, action=$publicRpcDeploymentAutomationAction, renderCommand=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderCommandPassed" -Default $false), noPlaceholders=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedFilesHaveNoPlaceholders" -Default $false), testerUnauthProbe=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightHasTesterUnauthProbe" -Default $false), walletTesterE2e=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesWalletTesterE2e" -Default $false), syntheticCanary=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesSyntheticCanary" -Default $false), cutoverRehearsal=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesCutoverRehearsal" -Default $false), disallowedOriginProbe=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightHasDisallowedOriginProbe" -Default $false), blockedStateProbe=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightBlocksBroadStatePath" -Default $false), privateWalletCreateBlocked=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightBlocksPrivateWalletCreate" -Default $false), authForwardingScoped=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedNginxAuthorizationForwardingScoped" -Default $false), renderSummary=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedReportSummaryPresent" -Default $false), renderSnapshot=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedReportSnapshotWritten" -Default $false), applyScript=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedOwnerHostApplyScriptWritten" -Default $false), applyScriptHashes=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedOwnerHostApplyScriptVerifiesHashes" -Default $false), applyScriptPostDeploy=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedOwnerHostApplyScriptRunsPostDeployProof" -Default $false), applyPlan=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "ownerHostApplyPlanPresent" -Default $false), ownerApplyScriptInPlan=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "ownerHostApplyPlanIncludesOwnerApplyScript" -Default $false), artifactHashes=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "ownerHostApplyPlanArtifactsHaveSha256" -Default $false), installPhase=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "ownerHostApplyPlanHasMutatingInstallPhase" -Default $false), edgePhase=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "ownerHostApplyPlanHasMutatingEdgePhase" -Default $false), hostMutationFalse=$(Get-AuditProp -Object $publicRpcDeploymentAutomationChecks -Name "hostMutationPerformedFalse" -Default $false), failedChecks=$publicRpcDeploymentAutomationFailedCheckCount, missingChecks=$publicRpcDeploymentAutomationMissingCheckCount, secretFindings=$publicRpcDeploymentAutomationSecretFindingCount, report=$($paths.publicRpcDeploymentAutomation)" `
    -Commands @("npm run flowchain:public-rpc:deployment:automation")

Add-AuditItem -Items $items -Id "node-operator-package" `
    -Requirement "Node operator package collects no-secret runbooks, command matrix, owner-input names, and current evidence for install, autorecovery, public RPC, backup, ops, bridge, testers, and release gates." `
    -Status $(if ($operatorPackagePassed) { "passed" } else { "failed" }) `
    -Evidence "operatorPackageStatus=$operatorPackageStatus, commands=$operatorPackageCommandCount, runbooks=$operatorPackageRunbookCount, evidenceReports=$operatorPackageEvidenceReportCount, failedChecks=$($operatorPackageFailedChecks.Count), secretFindings=$operatorPackageSecretFindingCount, report=$($paths.operatorPackage)" `
    -Commands @("npm run flowchain:operator:package")

Add-AuditItem -Items $items -Id "node-operator-package-verify" `
    -Requirement "Node operator package verifier independently checks the generated package manifest, expected files, command matrix, owner-input names, owner go-live expected evidence reports, forbidden local files, and no-secret scan." `
    -Status $(if ($operatorPackageVerifyPassed) { "passed" } else { "failed" }) `
    -Evidence "verifyStatus=$operatorPackageVerifyStatus, expectedFiles=$operatorPackageVerifyExpectedFileCount, commands=$operatorPackageVerifyCommandCount, goLiveEvidence=$operatorPackageVerifyGoLiveEvidenceCount, missingGoLiveEvidence=$($operatorPackageVerifyMissingGoLiveEvidence.Count), goLiveEvidenceNotInManifest=$($operatorPackageVerifyGoLiveEvidenceNotInManifest.Count), failedChecks=$($operatorPackageVerifyFailedChecks.Count), secretFindings=$operatorPackageVerifySecretFindingCount, report=$($paths.operatorPackageVerify)" `
    -Commands @("npm run flowchain:operator:package:verify")

Add-AuditItem -Items $items -Id "public-rpc-readiness-validator-self-test" `
    -Requirement "Public RPC readiness validator proves endpoint checks, CORS allowed-origin acceptance, disallowed-origin rejection, live public-edge security-header policy, bounded rate-limit rejection, retry-after evidence, and response hygiene against a temporary local control plane." `
    -Status $(if ($publicRpcValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "validationStatus=$publicRpcValidationStatus, allowedOriginAccepted=$publicRpcValidationAllowed, disallowedProbe=$publicRpcValidationDisallowedProbe, disallowedRejected=$publicRpcValidationDisallowedRejected, securityHeaderSkip=$publicRpcValidationSecurityHeaderSkip, securityHeaderPolicy=$publicRpcValidationSecurityHeaderPolicy, endpointChecks=$publicRpcValidationEndpointChecks, rateLimitProbe=$publicRpcValidationRateLimitProbe, rateLimitRejected=$publicRpcValidationRateLimitRejected, rateLimitRetryAfter=$publicRpcValidationRateLimitRetryAfter, responseHygiene=$publicRpcValidationHygiene, failedChecks=$publicRpcValidationFailedCheckCount, secretFindings=$publicRpcValidationSecretFindingCount, report=$($paths.publicRpcValidation)" `
    -Commands @("npm run flowchain:public-rpc:validate")

Add-AuditItem -Items $items -Id "public-rpc-abuse-test" `
    -Requirement "Public RPC abuse harness proves CORS rejection, media-type rejection, parse-error handling, method/params failure envelopes, batch/body caps, notification 204 handling, rate limiting, and no-secret response summaries." `
    -Status $(if ($publicRpcAbuseTestPassed) { "passed" } else { "failed" }) `
    -Evidence "abuseStatus=$publicRpcAbuseTestStatus, abuseReady=$publicRpcAbuseTestReady, failedChecks=$publicRpcAbuseFailedCheckCount, secretFindings=$publicRpcAbuseSecretFindingCount, missingChecks=$($publicRpcAbuseMissingChecks.Count), report=$($paths.publicRpcAbuseTest)" `
    -Commands @("npm run flowchain:public-rpc:abuse-test")

Add-AuditItem -Items $items -Id "public-rpc-synthetic-canary" `
    -Requirement "Public RPC synthetic canary proves the owner endpoint with read-only HTTP/JSON-RPC probes, denies write methods, and blocks safely without endpoint values until the endpoint exists." `
    -Status $(if ($publicRpcSyntheticCanaryPassed) { "passed" } elseif ($publicRpcSyntheticCanaryBlockedSafe) { "blocked" } else { "failed" }) `
    -Evidence "canaryStatus=$publicRpcSyntheticCanaryStatus, ready=$publicRpcSyntheticCanaryReady, ownerBlocked=$publicRpcSyntheticCanaryOwnerBlocked, probes=$(Get-AuditProp -Object $publicRpcSyntheticCanary -Name "probeCount" -Default 0), failedProbes=$(Get-AuditProp -Object $publicRpcSyntheticCanary -Name "failedProbeCount" -Default 0), noWriteMethods=$publicRpcSyntheticCanaryNoWriteMethods, readPlanCovered=$publicRpcSyntheticCanaryReadPlanCovered, report=$($paths.publicRpcSyntheticCanary)" `
    -Commands @("npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked") `
    -Blockers @($publicRpcSyntheticCanaryMissingEnvNames)

Add-AuditItem -Items $items -Id "tester-write-token-setup" `
    -Requirement "Tester write token setup creates or preserves the raw bearer token only in ignored local storage, writes only its SHA-256 digest and send cap into the ignored owner env file, and proves no token or digest is printed to committed evidence." `
    -Status $(if ($testerWriteTokenSetupPassed) { "passed" } else { "failed" }) `
    -Evidence "tokenSetupStatus=$testerWriteTokenSetupStatus, failedChecks=$($testerWriteTokenSetupFailedChecks.Count), missingChecks=$($testerWriteTokenSetupMissingChecks.Count), secretFindings=$($testerWriteTokenSetupSecretFindings.Count), tokenPath=$(Get-AuditProp -Object $testerWriteTokenSetup -Name "tokenPath"), ownerEnvFile=$(Get-AuditProp -Object $testerWriteTokenSetup -Name "ownerEnvFile"), report=$($paths.testerWriteTokenSetup)" `
    -Commands @("npm run flowchain:tester:token:setup")

Add-AuditItem -Items $items -Id "public-tester-gateway-e2e" `
    -Requirement "Public tester write gateway proves bearer auth configuration, public-only wallet creation, capped send settlement, and over-cap rejection on a temporary local control-plane." `
    -Status $(if ($publicTesterGatewayPassed) { "passed" } else { "failed" }) `
    -Evidence "gatewayStatus=$publicTesterGatewayStatus, configured=$(Get-AuditProp -Object $publicTesterGateway -Name "testerGatewayConfigured"), transferAccepted=$(Get-AuditProp -Object $publicTesterGateway -Name "transferAccepted"), capRejected=$(Get-AuditProp -Object $publicTesterGateway -Name "capRejected"), report=$($paths.publicTesterGateway)" `
    -Commands @("npm run flowchain:tester:gateway:e2e")

Add-AuditItem -Items $items -Id "dashboard-ui-readiness" `
    -Requirement "Dashboard browser readiness proves desktop and mobile users can create a tester wallet, request faucet funds, send tester units, inspect the result in Explorer, review tester launch readiness, review the L1 activation cockpit, review bridge/runtime proof surfaces, and avoid token/secret leakage or horizontal overflow." `
    -Status $(if ($dashboardUiReadinessPassed) { "passed" } else { "failed" }) `
    -Evidence "dashboardUiStatus=$dashboardUiReadinessStatus, browserProjects=$($dashboardUiBrowserProjects.Count), coveredRoutes=$($dashboardUiCoveredRoutes.Count), coveredProofs=$($dashboardUiCoveredProofs.Count), missingProjects=$($dashboardUiMissingBrowserProjects.Count), missingRoutes=$($dashboardUiMissingRoutes.Count), missingProofs=$($dashboardUiMissingProofs.Count), failedChecks=$($dashboardUiFailedChecks.Count), missingChecks=$($dashboardUiMissingChecks.Count), secretFindings=$dashboardUiSecretFindingCount, report=$($paths.dashboardUiReadiness)" `
    -Commands @("npm run flowchain:dashboard:ui:readiness", "npm run browser:e2e --prefix apps/dashboard")

Add-AuditItem -Items $items -Id "second-computer-readiness" `
    -Requirement "Second-computer readiness creates a no-secret offline source bundle, verifies local dependency prerequisites, documents the bundle/verify commands, and keeps the bundle under ignored local output." `
    -Status $(if ($secondComputerReadinessPassed) { "passed" } else { "failed" }) `
    -Evidence "secondComputerStatus=$secondComputerReadinessStatus, failedChecks=$($secondComputerFailedChecks.Count), missingChecks=$($secondComputerMissingChecks.Count), missingNextCommands=$($secondComputerMissingNextCommands.Count), failedVerifyChecks=$($secondComputerFailedVerifyChecks.Count), secretFindings=$secondComputerSecretFindingCount, report=$($paths.secondComputerReadiness)" `
    -Commands @("npm run flowchain:second-computer:readiness")

Add-AuditItem -Items $items -Id "backup-restore-validator-self-test" `
    -Requirement "Backup tooling creates manifest-backed live-state snapshots, verifies latest-snapshot restore rehearsal without targeting live state, and rejects corrupt, tampered, missing-artifact, stale-pointer, and wrong-chain cases." `
    -Status $(if ($backupRestoreValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "validationStatus=$backupRestoreValidationStatus, requiredChecks=$($backupRestoreValidationRequiredChecks.Count), failedChecks=$backupRestoreValidationFailedCheckCount, missingChecks=$backupRestoreValidationMissingCheckCount, secretFindings=$backupRestoreValidationSecretFindingCount, report=$($paths.backupRestoreValidation)" `
    -Commands @("npm run flowchain:backup:restore:validate")

Add-AuditItem -Items $items -Id "backup-owner-path-dry-run" `
    -Requirement "Backup owner-path dry run injects an ignored local backup path into the production backup readiness gate and proves snapshot plus restore evidence without using the owner's real directory." `
    -Status $(if ($backupOwnerPathDryRunPassed) { "passed" } else { "failed" }) `
    -Evidence "dryRunStatus=$backupOwnerPathDryRunStatus, failedChecks=$backupOwnerPathDryRunFailedCheckCount, missingChecks=$backupOwnerPathDryRunMissingCheckCount, secretFindings=$backupOwnerPathDryRunSecretFindingCount, readiness=$(Get-AuditProp -Object $backupOwnerPathDryRun -Name "childReadinessStatus"), snapshotProof=$(Get-AuditProp -Object $backupOwnerPathDryRunChecks -Name "snapshotProofPassed"), restoreProof=$(Get-AuditProp -Object $backupOwnerPathDryRunChecks -Name "restoreProofPassed"), report=$($paths.backupOwnerPathDryRun)" `
    -Commands @("npm run flowchain:backup:owner-path:dry-run")

Add-AuditItem -Items $items -Id "backup-install-validation" `
    -Requirement "Backup scheduler install validation proves Windows Scheduled Task and Linux systemd timer plans for recurring state backup and restore drills are no-secret, fail closed without owner backup path env, and do not mutate the host in plan mode." `
    -Status $(if ($backupInstallValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "installStatus=$backupInstallValidationStatus, failedChecks=$backupInstallValidationFailedCheckCount, missingChecks=$backupInstallValidationMissingCheckCount, missingPackageScripts=$backupInstallValidationMissingPackageScriptCount, systemdValidation=$(Get-AuditProp -Object $backupInstallValidationChecks -Name "systemdValidationPassed"), systemdTimer=$(Get-AuditProp -Object $backupInstallValidationChecks -Name "systemdBackupTimerUnitPlanned"), report=$($paths.backupInstallValidation)" `
    -Commands @("npm run flowchain:backup:install:validate", "npm run flowchain:backup:install:windows -- -Action Plan", "npm run flowchain:backup:install:systemd -- -Action Plan", "npm run flowchain:backup:install:systemd:validate")

Add-AuditItem -Items $items -Id "external-tester-packet" `
    -Requirement "External tester handoff packet and machine-readable connection pack are generated, executable packet-route smoke is validated, and sharing fails closed until public gates pass." `
    -Status $(if (($externalTesterPacketStatus -eq "passed" -and $externalTesterPacketShareable -eq $true -and $externalTesterPacketExecutableSmokeValidated -eq $true -and $externalTesterConnectPackReady -eq $true) -or ($externalTesterPacketStatus -eq "blocked" -and $externalTesterPacketShareable -eq $false -and $externalTesterPacketExecutableSmokeValidated -eq $true -and $externalTesterConnectPackReady -eq $true)) { "passed" } else { "failed" }) `
    -Evidence "packetStatus=$externalTesterPacketStatus, shareable=$externalTesterPacketShareable, packetSmoke=$externalTesterPacketExecutableSmokeValidated, smokeRoutes=$($externalTesterPacketSmokeRoutes.Count), connectPackReady=$externalTesterConnectPackReady, packet=$externalTesterPacketPath" `
    -Commands @("npm run flowchain:external-tester:packet")

Add-AuditItem -Items $items -Id "external-tester-packet-validation" `
    -Requirement "External tester packet validation proves the packet and connect pack are no-secret, locally executable, and not externally shareable before owner public inputs exist." `
    -Status $(if ($externalTesterPacketValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "validationStatus=$externalTesterPacketValidationStatus, failedChecks=$($externalTesterPacketValidationFailedChecks.Count), missingChecks=$($externalTesterPacketValidationMissingChecks.Count), secretFindings=$($externalTesterPacketValidationSecretFindings.Count), packetShareable=$(Get-AuditProp -Object $externalTesterPacketValidation -Name "packetShareable" -Default $true), report=$($paths.externalTesterPacketValidation)" `
    -Commands @("npm run flowchain:external-tester:packet:validate")

Add-AuditItem -Items $items -Id "external-tester-client-validation" `
    -Requirement "External tester client validation proves the generated connect pack can drive the standalone tester client in a no-network dry run covering read routes, wallet create, faucet, send, redaction, no-token storage, no secrets, and no broadcasts." `
    -Status $(if ($externalTesterClientValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "clientValidationStatus=$externalTesterClientValidationStatus, failedChecks=$($externalTesterClientValidationFailedChecks.Count), missingChecks=$($externalTesterClientValidationMissingChecks.Count), secretFindings=$($externalTesterClientValidationSecretFindings.Count), report=$($paths.externalTesterClientValidation)" `
    -Commands @("npm run flowchain:external-tester:client:validate")

Add-AuditItem -Items $items -Id "external-tester-evidence-validation" `
    -Requirement "External tester evidence validation proves returned friends-and-family evidence is complete, redacted, height-advancing, wallet-transfer consistent, amount-capped, and no-secret before owner review." `
    -Status $(if ($externalTesterEvidenceValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "validationStatus=$externalTesterEvidenceValidationStatus, failedChecks=$($externalTesterEvidenceValidationFailedChecks.Count), missingChecks=$($externalTesterEvidenceValidationMissingChecks.Count), missingRequiredFiles=$($externalTesterEvidenceValidationMissingRequiredFiles.Count), invalidJsonFiles=$($externalTesterEvidenceValidationInvalidJsonFiles.Count), secretFindings=$($externalTesterEvidenceValidationSecretFindings.Count), credentialUrls=$($externalTesterEvidenceValidationCredentialUrlFindings.Count), envAssignments=$($externalTesterEvidenceValidationEnvAssignmentFindings.Count), report=$($paths.externalTesterEvidenceValidation)" `
    -Commands @("npm run flowchain:tester:evidence:validate")

Add-AuditItem -Items $items -Id "friends-and-family-launch" `
    -Requirement "Friends-and-family tester launch requires fresh tester-wallet evidence, executable packet-route smoke, a machine-readable connection pack, standalone client validation, and validated returned evidence, and remains blocked until public RPC, backup, and Base bridge gates pass." `
    -Status $(if ($externalTesterLaunchPassed) { "passed" } elseif ($externalTesterLaunchBlocked) { "blocked" } else { "failed" }) `
    -Evidence "externalTester=$externalTesterStatus, testerNetworkFresh=$externalTesterNetworkFresh, packetStatus=$externalTesterPacketStatus, shareable=$externalTesterPacketShareable, packetSmoke=$externalTesterPacketExecutableSmokeValidated, smokeRoutes=$($externalTesterPacketSmokeRoutes.Count), connectPackReady=$externalTesterConnectPackReady, clientValidation=$externalTesterClientValidationPassed, evidenceValidation=$externalTesterEvidenceValidationPassed, externalSharingReady=$externalSharingReady" `
    -Commands @("npm run flowchain:tester:readiness -- -AllowBlocked", "npm run flowchain:external-tester:packet -- -AllowBlocked", "npm run flowchain:external-tester:client:validate", "npm run flowchain:tester:evidence:validate") `
    -Blockers @($missingEnv)

Add-AuditItem -Items $items -Id "ops-snapshot" `
    -Requirement "Ops snapshot separates critical incidents from expected owner-input blockers and records incident commands." `
    -Status $(if ($opsSnapshotPassed) { "passed" } else { "failed" }) `
    -Evidence "opsStatus=$opsSnapshotStatus, criticalCount=$opsSnapshotCriticalCount, blockedCount=$opsSnapshotBlockedCount, latestHeight=$opsSnapshotLatestHeight, finalizedHeight=$opsSnapshotFinalizedHeight, report=$($paths.opsSnapshot)" `
    -Commands @("npm run flowchain:ops:snapshot -- -AllowBlocked")

Add-AuditItem -Items $items -Id "ops-alert-rules" `
    -Requirement "Ops alert rules map every current ops finding, public RPC apply-plan regression, backup restore/owner-path regression, bridge reconciliation regression, service-install validation regression, and autorecovery telemetry regression to local operator commands with critical and blocked rule coverage, no unmapped current findings, and no external delivery credentials." `
    -Status $(if ($opsAlertRulesPassed) { "passed" } else { "failed" }) `
    -Evidence "alertRules=$opsAlertRulesStatus, rules=$opsAlertRuleCount, criticalRules=$opsAlertCriticalRuleCount, blockedRules=$opsAlertBlockedRuleCount, failedChecks=$opsAlertFailedCheckCount, missingChecks=$opsAlertMissingCheckCount, secretFindings=$opsAlertSecretFindingCount, publicRpcRollbackAlert=$(Get-AuditProp -Object $opsAlertChecks -Name "publicRpcEdgeHardeningRuleCoversRollbackDrill" -Default $false), publicRpcApplyPlanAlert=$(Get-AuditProp -Object $opsAlertChecks -Name "publicRpcEdgeHardeningRuleCoversOwnerHostApplyPlan" -Default $false), backupRestoreAlert=$(Get-AuditProp -Object $opsAlertChecks -Name "backupRestoreValidationRuleCoversSafety" -Default $false), backupOwnerPathAlert=$(Get-AuditProp -Object $opsAlertChecks -Name "backupOwnerPathDryRunRuleCoversOwnerPath" -Default $false), bridgeDeployControlAlert=$(Get-AuditProp -Object $opsAlertChecks -Name "bridgeDeployControlRuleCoversDeploymentControls" -Default $false), bridgeReconciliationAlert=$(Get-AuditProp -Object $opsAlertChecks -Name "bridgeReconciliationRuleCoversCursorAndReplay" -Default $false), serviceInstallAlert=$(Get-AuditProp -Object $opsAlertChecks -Name "serviceInstallValidationRuleCoversAutorecoveryTelemetry" -Default $false), devPackAlert=$(Get-AuditProp -Object $opsAlertChecks -Name "devPackRuleCoversBrowserStarter" -Default $false), secondComputerAlert=$(Get-AuditProp -Object $opsAlertChecks -Name "secondComputerRuleCoversBundleVerifyNoSecret" -Default $false), unmapped=$($opsAlertUnmappedCodes.Count), rulesWithoutCommands=$($opsAlertRulesWithoutCommands.Count), commandUrls=$($opsAlertCommandsWithUrls.Count), inlineEnvAssignments=$($opsAlertCommandsWithInlineEnvAssignment.Count), report=$($paths.opsAlertRules)" `
    -Commands @("npm run flowchain:ops:alerts -- -AllowBlocked")

Add-AuditItem -Items $items -Id "ops-alert-install-validation" `
    -Requirement "Ops alert scheduled refresh install validation proves Windows Scheduled Task and Linux systemd timer plan/status/uninstall boundaries and no external delivery for recurring local alert evidence." `
    -Status $(if ($alertInstallValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "alertInstall=$alertInstallValidationStatus, failedChecks=$alertInstallValidationFailedCheckCount, secretFindings=$alertInstallValidationSecretFindingCount, planDidNotMutate=$(Get-AuditProp -Object $alertInstallValidationChecks -Name "planDidNotMutate" -Default $false), statusDidNotMutate=$(Get-AuditProp -Object $alertInstallValidationChecks -Name "statusDidNotMutate" -Default $false), systemdValidation=$(Get-AuditProp -Object $alertInstallValidationChecks -Name "systemdValidationPassed" -Default $false), systemdTimer=$(Get-AuditProp -Object $alertInstallValidationChecks -Name "systemdTimerUnitPlanned" -Default $false), noExternalDelivery=$(Get-AuditProp -Object $alertInstallValidationChecks -Name "noExternalDelivery" -Default $false), report=$($paths.alertInstallValidation)" `
    -Commands @("npm run flowchain:ops:alerts:install:validate")

Add-AuditItem -Items $items -Id "ops-metrics-export" `
    -Requirement "Ops metrics export writes no-secret JSON and Prometheus textfile metrics from current L1 operations evidence, including backup restore/owner-path safety, public RPC edge deployment hardening, bridge relayer-loop validation, bridge reconciliation, bridge release-evidence validation, and external tester client validation coverage, without hiding owner-input blockers." `
    -Status $(if ($opsMetricsExportPassed) { "passed" } else { "failed" }) `
    -Evidence "metricsExport=$opsMetricsExportStatus, metricCount=$opsMetricsExportMetricCount, failedChecks=$($opsMetricsExportFailedChecks.Count), secretFindings=$($opsMetricsExportSecretFindings.Count), metricsJsonWritten=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "metricsJsonWritten" -Default $false), prometheusTextWritten=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "prometheusTextWritten" -Default $false), requiredMetricsPresent=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "requiredMetricsPresent" -Default $false), backupRestoreValidationLoaded=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "backupRestoreValidationLoaded" -Default $false), backupRestoreValidationMetricsPresent=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "backupRestoreValidationMetricsPresent" -Default $false), backupOwnerPathDryRunLoaded=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "backupOwnerPathDryRunLoaded" -Default $false), backupOwnerPathDryRunMetricsPresent=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "backupOwnerPathDryRunMetricsPresent" -Default $false), publicRpcEdgeMetricsPresent=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "publicRpcEdgeMetricsPresent" -Default $false), publicRpcRollbackDrillMetricsPresent=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "publicRpcRollbackDrillMetricsPresent" -Default $false), publicRpcOwnerApplyMetricsPresent=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "publicRpcOwnerHostApplyPlanMetricsPresent" -Default $false), bridgeDeployControlMetricsPresent=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "bridgeDeployControlMetricsPresent" -Default $false), serviceInstallValidationMetricsPresent=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "serviceInstallValidationMetricsPresent" -Default $false), bridgeRelayerLoopValidationMetricsPresent=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "bridgeRelayerLoopValidationMetricsPresent" -Default $false), bridgeReconciliationLoaded=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "bridgeReconciliationLoaded" -Default $false), bridgeReconciliationMetricsPresent=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "bridgeReconciliationMetricsPresent" -Default $false), bridgeReleaseEvidenceMetricsPresent=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "bridgeReleaseEvidenceMetricsPresent" -Default $false), externalTesterClientMetricsPresent=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "externalTesterClientMetricsPresent" -Default $false), secondComputerLoaded=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "secondComputerLoaded" -Default $false), secondComputerMetricsPresent=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "secondComputerMetricsPresent" -Default $false), devPackLoaded=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "devPackLoaded" -Default $false), devPackMetricsPresent=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "devPackMetricsPresent" -Default $false), supervisorNodeRecoveryMetricsPresent=$(Get-AuditProp -Object $opsMetricsExportChecks -Name "supervisorNodeRecoveryMetricsPresent" -Default $false), report=$($paths.opsMetricsExport)" `
    -Commands @("npm run flowchain:ops:metrics:export -- -AllowBlocked")

Add-AuditItem -Items $items -Id "ops-metrics-install-validation" `
    -Requirement "Ops metrics scheduled export install validation proves Windows Scheduled Task and Linux systemd timer plan/status/uninstall boundaries and no external delivery for recurring JSON and Prometheus textfile metrics." `
    -Status $(if ($metricsInstallValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "metricsInstall=$metricsInstallValidationStatus, failedChecks=$metricsInstallValidationFailedCheckCount, missingPackageScripts=$metricsInstallValidationMissingPackageScriptCount, secretFindings=$metricsInstallValidationSecretFindingCount, planDidNotMutate=$(Get-AuditProp -Object $metricsInstallValidationChecks -Name "planDidNotMutate" -Default $false), statusDidNotMutate=$(Get-AuditProp -Object $metricsInstallValidationChecks -Name "statusDidNotMutate" -Default $false), systemdValidation=$(Get-AuditProp -Object $metricsInstallValidationChecks -Name "systemdValidationPassed" -Default $false), systemdTimer=$(Get-AuditProp -Object $metricsInstallValidationChecks -Name "systemdTimerUnitPlanned" -Default $false), metricsJsonPath=$(Get-AuditProp -Object $metricsInstallValidationChecks -Name "hasMetricsJsonPath" -Default $false), prometheusTextPath=$(Get-AuditProp -Object $metricsInstallValidationChecks -Name "hasPrometheusTextPath" -Default $false), noExternalDelivery=$(Get-AuditProp -Object $metricsInstallValidationChecks -Name "noExternalDelivery" -Default $false), report=$($paths.metricsInstallValidation)" `
    -Commands @("npm run flowchain:ops:metrics:install:validate", "npm run flowchain:ops:metrics:install:windows -- -Action Plan", "npm run flowchain:ops:metrics:install:systemd -- -Action Plan")

Add-AuditItem -Items $items -Id "ops-escalation-dry-run" `
    -Requirement "Ops escalation dry run maps every current finding to local operator commands and proves the repo-owned alert path does not send network delivery or store external delivery credentials." `
    -Status $(if ($opsEscalationDryRunPassed) { "passed" } else { "failed" }) `
    -Evidence "dryRunStatus=$opsEscalationDryRunStatus, events=$opsEscalationDryRunEventCount, failedChecks=$opsEscalationDryRunFailedCheckCount, secretFindings=$opsEscalationDryRunSecretFindingCount, noNetworkDelivery=$(Get-AuditProp -Object $opsEscalationDryRunChecks -Name "notificationPlanNoNetworkDelivery"), storesNoSecrets=$(Get-AuditProp -Object $opsEscalationDryRunChecks -Name "notificationPlanStoresNoSecrets"), report=$($paths.opsEscalationDryRun)" `
    -Commands @("npm run flowchain:ops:escalation:dry-run -- -NoRefresh")

Add-AuditItem -Items $items -Id "incident-drill" `
    -Requirement "Incident drills prove node-down, control-plane-down, stale-state, stalled-height, public tester gateway, and no-secret failures classify as critical while owner-input blockers stay non-critical." `
    -Status $(if ($incidentDrillPassed) { "passed" } else { "failed" }) `
    -Evidence "incidentStatus=$incidentDrillStatus, ready=$incidentDrillReady, cases=$incidentTotalCases, failedCases=$incidentFailedCases, failedChecks=$incidentDrillFailedCheckCount, secretFindings=$incidentDrillSecretFindingCount, missingChecks=$incidentDrillMissingCheckCount, report=$($paths.incidentDrill)" `
    -Commands @("npm run flowchain:ops:incident-drill")

Add-AuditItem -Items $items -Id "public-rpc-external-sharing" `
    -Requirement "External/public RPC is configured behind owner TLS, CORS, rate limit, endpoint checks, response hygiene, and a passing read-only synthetic canary before sharing." `
    -Status $(if ((Get-ReportStatus -Report $reports.publicRpc) -eq "passed" -and $publicRpcSyntheticCanaryPassed) { "passed" } elseif ((Get-ReportStatus -Report $reports.publicRpc) -eq "blocked" -or $publicRpcSyntheticCanaryBlockedSafe) { "blocked" } else { "failed" }) `
    -Evidence "publicRpcStatus=$(Get-ReportStatus -Report $reports.publicRpc), canaryStatus=$publicRpcSyntheticCanaryStatus, canaryReady=$publicRpcSyntheticCanaryReady, noWriteMethods=$publicRpcSyntheticCanaryNoWriteMethods, reports=$($paths.publicRpc), $($paths.publicRpcSyntheticCanary)" `
    -Commands @("npm run flowchain:public-rpc:check", "npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked") `
    -Blockers @("FLOWCHAIN_RPC_PUBLIC_URL", "FLOWCHAIN_RPC_ALLOWED_ORIGINS", "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE", "FLOWCHAIN_RPC_TLS_TERMINATED")

$backupReadinessStatus = Get-ReportStatus -Report $reports.backup
$backupReadinessDetails = Get-AuditProp -Object $reports.backup -Name "backup"
$backupSnapshotProofStatus = Get-AuditProp -Object $backupReadinessDetails -Name "snapshotProofStatus" -Default "not-run"
$backupRestoreProofStatus = Get-AuditProp -Object $backupReadinessDetails -Name "restoreProofStatus" -Default "not-run"
$backupRestoreVerified = Get-AuditProp -Object $backupReadinessDetails -Name "restoreVerified" -Default $false
Add-AuditItem -Items $items -Id "state-backup" `
    -Requirement "State backup path is configured, can create a manifest-backed snapshot, verifies restore rehearsal, and has Windows plus Linux recurring scheduler install proof for live RPC operations." `
    -Status $(if ($backupReadinessStatus -eq "passed" -and $backupRestoreValidationPassed -and $backupOwnerPathDryRunPassed -and $backupInstallValidationPassed) { "passed" } elseif ($backupReadinessStatus -eq "blocked" -and $backupRestoreValidationPassed -and $backupOwnerPathDryRunPassed -and $backupInstallValidationPassed) { "blocked" } else { "failed" }) `
    -Evidence "backupStatus=$backupReadinessStatus, snapshotProof=$backupSnapshotProofStatus, restoreProof=$backupRestoreProofStatus, restoreVerified=$backupRestoreVerified, validationStatus=$backupRestoreValidationStatus, ownerPathDryRun=$backupOwnerPathDryRunStatus, installValidation=$backupInstallValidationStatus, systemdValidation=$(Get-AuditProp -Object $backupInstallValidationChecks -Name "systemdValidationPassed"), report=$($paths.backup)" `
    -Commands @("npm run flowchain:backup:create", "npm run flowchain:backup:restore:verify", "npm run flowchain:backup:owner-path:dry-run", "npm run flowchain:backup:install:validate", "npm run flowchain:backup:install:systemd:validate", "npm run flowchain:backup:check") `
    -Blockers @("FLOWCHAIN_RPC_STATE_BACKUP_PATH")

Add-AuditItem -Items $items -Id "bridge-funds" `
    -Requirement "Bridge readiness for owner-operated Base 8453 funds is verified fail-closed without live broadcasts." `
    -Status $(if ((Get-ReportStatus -Report $reports.bridgeLive) -eq "passed" -and (Get-ReportStatus -Report $reports.bridgeInfra) -eq "passed") { "passed" } else { "blocked" }) `
    -Evidence "bridgeLive=$(Get-ReportStatus -Report $reports.bridgeLive), bridgeInfra=$(Get-ReportStatus -Report $reports.bridgeInfra), reports=$($paths.bridgeLive), $($paths.bridgeInfra)" `
    -Commands @("npm run flowchain:bridge:live:check", "npm run flowchain:bridge:infra:check") `
    -Blockers @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_BASE8453_ASSET_DECIMALS", "FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS")

Add-AuditItem -Items $items -Id "bridge-local-pilot-proof" `
    -Requirement "Local/mock bridge pilot proof preserves exact value, rejects replay/wrong-chain/unapproved-lockbox cases, and performs no broadcast." `
    -Status $(if ($bridgePilotLocalPassed) { "passed" } else { "failed" }) `
    -Evidence "status=$bridgePilotStatus, broadcast=$bridgePilotBroadcast, allAmountsEqual=$bridgePilotAllAmountsEqual, wrongChainRejected=$bridgePilotWrongChainRejected, unapprovedContractRejected=$bridgePilotUnapprovedContractRejected, failedChecks=$($bridgePilotFailedChecks.Count), missingChecks=$($bridgePilotMissingChecks.Count), report=$($paths.bridgePilotLocal)" `
    -Commands @("npm run flowchain:real-value-pilot:bridge")

Add-AuditItem -Items $items -Id "base-tx-diagnostic-fail-closed" `
    -Requirement "Owner-supplied Base 8453 transaction diagnostic is read-only, no-secret, and fails closed when tx/env inputs are absent." `
    -Status $(if ($baseTxDiagnosticPassed) { "passed" } else { "failed" }) `
    -Evidence "diagnosticStatus=$baseTxDiagnosticStatus, safeReason=$baseTxDiagnosticSafeReason, broadcasts=$baseTxDiagnosticBroadcasts, printsEnvValues=$baseTxDiagnosticPrintsEnvValues, noSecrets=$baseTxDiagnosticNoSecrets, report=$($paths.baseTxDiagnostic)" `
    -Commands @("npm run flowchain:bridge:diagnose:tx")

Add-AuditItem -Items $items -Id "bridge-deploy-control-validation" `
    -Requirement "Base 8453 bridge deploy/control validation proves deploy, pause, resume, and emergency-stop fail closed without owner env and remain no-broadcast without explicit owner execution." `
    -Status $(if ($bridgeDeployControlValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "deployControlStatus=$bridgeDeployControlValidationStatus, failedChecks=$($bridgeDeployControlFailedChecks.Count), missingChecks=$($bridgeDeployControlMissingChecks.Count), secretMarkerFindings=$($bridgeDeployControlSecretMarkerFindings.Count), report=$($paths.bridgeDeployControlValidation)" `
    -Commands @("npm run flowchain:bridge:deploy:control:validate")

Add-AuditItem -Items $items -Id "bridge-relayer-once-runtime-contract" `
    -Requirement "Bridge relayer one-shot reports must publish explicit checks proving no broadcasts, no env value printing, no child timeouts, staged cursor safety, blocked-before-observation behavior, no queued/applied credits while blocked, classified external blockers, and safe cursor/queue evidence when passed." `
    -Status $(if ($bridgeRelayerOnceCheckContractPassed -and $bridgeRelayerOnceStatus -eq "passed") { "passed" } elseif ($bridgeRelayerOnceCheckContractPassed -and $bridgeRelayerOnceStatus -eq "blocked") { "blocked" } else { "failed" }) `
    -Evidence "relayerStatus=$bridgeRelayerOnceStatus, failedChecks=$bridgeRelayerOnceFailedCheckCount, missingChecks=$bridgeRelayerOnceMissingCheckCount, falseRequiredChecks=$bridgeRelayerOnceFalseRequiredCheckCount, secretFindings=$bridgeRelayerOnceSecretFindingCount, noQueuedWhenBlocked=$(Get-AuditProp -Object $bridgeRelayerOnceChecks -Name "noQueuedTransactionsWhenBlocked" -Default $false), finalCursorNotCommittedWhenBlocked=$(Get-AuditProp -Object $bridgeRelayerOnceChecks -Name "finalCursorNotCommittedWhenBlocked" -Default $false), report=$($paths.bridgeRelayerOnce)" `
    -Commands @("npm run flowchain:bridge:relayer:once -- -AllowBlocked") `
    -Blockers @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_BASE8453_ASSET_DECIMALS", "FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS")

Add-AuditItem -Items $items -Id "bridge-relayer-guardrail-validation" `
    -Requirement "Bridge relayer missing-owner-input guardrail validation fails closed without mutating final cursor state, staging cursor state, queueing credits, printing env values, broadcasting, or letting standalone Base observation use the final relayer cursor by default." `
    -Status $(if ($bridgeRelayerGuardrailValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "guardrailStatus=$bridgeRelayerGuardrailValidationStatus, failedChecks=$bridgeRelayerGuardrailFailedCheckCount, missingChecks=$bridgeRelayerGuardrailMissingCheckCount, falseRequiredChecks=$bridgeRelayerGuardrailFalseRequiredCheckCount, secretFindings=$bridgeRelayerGuardrailSecretFindingCount, finalCursorUnchanged=$(Get-AuditProp -Object $bridgeRelayerGuardrailChecks -Name "finalCursorUnchanged" -Default $false), directObserveStagedDefault=$(Get-AuditProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveUsesStagedCursorByDefault" -Default $false), directObserveCursorNotFinal=$(Get-AuditProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveCursorNotFinal" -Default $false), report=$($paths.bridgeRelayerGuardrailValidation)" `
    -Commands @("npm run flowchain:bridge:relayer:guardrail:validate")

Add-AuditItem -Items $items -Id "bridge-relayer-loop-validation" `
    -Requirement "Bridge relayer loop validation proves isolated live-service loop start, fresh blocked-only-on-owner-input loop health, clean stop, PID-file cleanup, and no leftover validation relayer process." `
    -Status $(if ($bridgeRelayerLoopValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "loopStatus=$bridgeRelayerLoopValidationStatus, failedChecks=$bridgeRelayerLoopFailedCheckCount, missingChecks=$bridgeRelayerLoopMissingCheckCount, secretFindings=$bridgeRelayerLoopSecretFindingCount, loopHealthy=$(Get-AuditProp -Object $bridgeRelayerLoopChecks -Name "statusRelayerReportHealthy" -Default $false), stopped=$(Get-AuditProp -Object $bridgeRelayerLoopChecks -Name "statusAfterStopNotRunning" -Default $false), report=$($paths.bridgeRelayerLoopValidation)" `
    -Commands @("npm run flowchain:bridge:relayer:loop:validate")

Add-AuditItem -Items $items -Id "bridge-runtime-credit-validation" `
    -Requirement "Bridge runtime credit validation proves a production-shaped Base 8453 handoff can be queued into an isolated L1, become spendable within the settlement target, reject replay, spend from the credited wallet, and survive restart/export/import without secrets or broadcasts." `
    -Status $(if ($bridgeRuntimeCreditValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "runtimeCreditStatus=$bridgeRuntimeCreditValidationStatus, failedChecks=$($bridgeRuntimeCreditFailedChecks.Count), missingChecks=$($bridgeRuntimeCreditMissingChecks.Count), falseRequiredChecks=$($bridgeRuntimeCreditFalseRequiredChecks.Count), missingRuntimeChecks=$($bridgeRuntimeCreditMissingRuntimeChecks.Count), falseRuntimeChecks=$($bridgeRuntimeCreditFalseRuntimeChecks.Count), latencyGate=$(Get-AuditProp -Object (Get-AuditProp -Object $bridgeRuntimeCreditValidation -Name 'timing') -Name 'latencyGate' -Default 'missing'), queueToSpendableSeconds=$(Get-AuditProp -Object (Get-AuditProp -Object $bridgeRuntimeCreditValidation -Name 'timing') -Name 'queueToSpendableSeconds' -Default ''), report=$($paths.bridgeRuntimeCreditValidation)" `
    -Commands @("npm run flowchain:bridge:runtime-credit:validate")

Add-AuditItem -Items $items -Id "real-value-pilot-aggregate" `
    -Requirement "Real-value pilot aggregate runs contracts, bridge, runtime, wallet, control-dashboard, and ops proofs under bounded child timeouts with redacted logs, no failed commands, no timed-out commands, and an owner go/no-go result." `
    -Status $(if ($realValuePilotAggregatePassed) { "passed" } else { "failed" }) `
    -Evidence "aggregateStatus=$realValuePilotAggregateStatus, childTimeoutSeconds=$(Get-AuditProp -Object $realValuePilotAggregate -Name 'childTimeoutSeconds' -Default ''), commandsRun=$($realValuePilotAggregateCommandsRun.Count), missingCommands=$($realValuePilotAggregateMissingCommandsRun.Count), missingExpectedCommands=$($realValuePilotAggregateMissingExpectedCommands.Count), timedOut=$($realValuePilotAggregateTimedOutCommands.Count), failedCommands=$($realValuePilotAggregateFailedCommands.Count), missingProofs=$($realValuePilotAggregateMissingProofs.Count), ownerGoNoGo=$realValuePilotAggregateOwnerGoNoGo, report=$($paths.realValuePilotAggregate)" `
    -Commands @("npm run flowchain:real-value-pilot:e2e -- -SkipBaseline -ChildTimeoutSeconds 1800")

Add-AuditItem -Items $items -Id "bridge-reconciliation" `
    -Requirement "Bridge reconciliation summarizes live relayer observed/new/queued/applied/pending credits, cursor commit safety, local runtime credit proof, replay rejection, and release evidence validation in one no-secret operator report." `
    -Status $(if ($bridgeReconciliationPassed) { "passed" } else { "failed" }) `
    -Evidence "reconciliationStatus=$bridgeReconciliationStatus, rows=$($bridgeReconciliationRows.Count), failedChecks=$bridgeReconciliationFailedCheckCount, missingChecks=$bridgeReconciliationMissingCheckCount, secretFindings=$bridgeReconciliationSecretFindingCount, relayerBlockedOwner=$(Get-AuditProp -Object $bridgeReconciliationChecks -Name "relayerBlockedClassifiedOwnerInput" -Default $false), runtimeApplied=$(Get-AuditProp -Object $bridgeReconciliationChecks -Name "runtimeCreditAppliedOnce" -Default $false), replayRejected=$(Get-AuditProp -Object $bridgeReconciliationChecks -Name "localPilotDuplicateReplayRejected" -Default $false), report=$($paths.bridgeReconciliation)" `
    -Commands @("npm run flowchain:bridge:reconciliation")

Add-AuditItem -Items $items -Id "bridge-release-evidence-validation" `
    -Requirement "Bridge withdrawal/release evidence validation proves matching release evidence passes, missing inputs block, amount/token/recipient/chain/asset mismatches fail, broadcast flags are rejected, and validation remains no-secret/no-broadcast." `
    -Status $(if ($bridgeReleaseEvidenceValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "releaseEvidenceValidation=$bridgeReleaseEvidenceValidationStatus, cases=$(Get-AuditProp -Object $bridgeReleaseEvidenceValidation -Name "caseCount" -Default 0), failedChecks=$($bridgeReleaseEvidenceValidationFailedChecks.Count), failedCases=$($bridgeReleaseEvidenceValidationFailedCases.Count), missingCases=$($bridgeReleaseEvidenceValidationMissingCases.Count), secretFindings=$($bridgeReleaseEvidenceValidationSecretFindings.Count), report=$($paths.bridgeReleaseEvidenceValidation)" `
    -Commands @("npm run flowchain:bridge:release:evidence:validate")

Add-AuditItem -Items $items -Id "live-infra-aggregate-refresh" `
    -Requirement "Completion audit refreshes the live-infra aggregate gate before deciding readiness." `
    -Status $(if ($liveInfraStatus -eq "passed") { "passed" } elseif ($liveInfraStatus -eq "blocked") { "blocked" } else { "failed" }) `
    -Evidence "liveInfraStatus=$liveInfraStatus, ownerInputsReady=$liveInfraOwnerInputsReady, publicRpcReady=$liveInfraPublicRpcReady, servicesReady=$liveInfraServicesReady, backupReady=$liveInfraBackupReady, bridgeReady=$liveInfraBridgeReady, noSecretReady=$liveInfraNoSecretReady, report=$($paths.liveInfra)" `
    -Commands @("npm run flowchain:live-infra:check -- -AllowBlocked") `
    -Blockers @($missingEnv)

Add-AuditItem -Items $items -Id "aggregate-gate" `
    -Requirement "Full product gate runs production local L1 aggregate, restores live service, proves wallet flows, and runs live infra readiness." `
    -Status $(if ($liveProductExitCode -eq 0 -and (Get-ReportStatus -Report $liveProduct) -eq "passed") { "passed" } elseif ($liveProductExitCode -eq 0 -and $productionLocalAggregateStatus -eq "passed-with-live-blockers" -and (Test-StepPassed -LiveProduct $liveProduct -Name "Live service wallet transfer E2E") -and (Test-StepPassed -LiveProduct $liveProduct -Name "Live service tester network E2E")) { "blocked" } else { "failed" }) `
    -Evidence "liveProductExitCode=$liveProductExitCode, liveProductStatus=$(Get-ReportStatus -Report $liveProduct), productionLocalAggregate=$productionLocalAggregateStatus, liveInfra=$liveProductLiveInfraStatus, report=$($paths.liveProduct)" `
    -Commands @("npm run flowchain:live-product:e2e -- -AllowBlocked") `
    -Blockers @($missingEnv)

$noSecretChecks = Get-AuditProp -Object $reports.noSecret -Name "checks"
$noSecretCoverageReady = ((Get-AuditProp -Object $noSecretChecks -Name "scansDashboardPublicData" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $noSecretChecks -Name "scansGeneratedLiveProductReports" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $noSecretChecks -Name "scansGeneratedDevPackReports" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $noSecretChecks -Name "scansGeneratedSdkDocs" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $noSecretChecks -Name "reportPathMatchesProductionGate" -Default $false) -eq $true)
$noSecretFailedChecks = @((Get-AuditProp -Object $reports.noSecret -Name "failedChecks" -Default @()))
$noSecretSecretFindings = @((Get-AuditProp -Object $reports.noSecret -Name "secretMarkerFindings" -Default @()))
$noSecretFindings = @((Get-AuditProp -Object $reports.noSecret -Name "findings" -Default @()))
$noSecretFailedCheckCount = @($noSecretFailedChecks | Where-Object { $null -ne $_ }).Count
$noSecretSecretFindingCount = @($noSecretSecretFindings | Where-Object { $null -ne $_ }).Count
$noSecretFindingCount = @($noSecretFindings | Where-Object { $null -ne $_ }).Count
$noSecretSafetyReady = $noSecretCoverageReady `
    -and $noSecretFailedCheckCount -eq 0 `
    -and $noSecretSecretFindingCount -eq 0 `
    -and $noSecretFindingCount -eq 0 `
    -and ((Get-AuditProp -Object $noSecretChecks -Name "scannedCountPositive" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $noSecretChecks -Name "findingsEmpty" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $noSecretChecks -Name "secretMarkerFindingsEmpty" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $noSecretChecks -Name "envValuesPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $noSecretChecks -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $noSecretChecks -Name "broadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $reports.noSecret -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $reports.noSecret -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $reports.noSecret -Name "broadcasts" -Default $true) -eq $false)
Add-AuditItem -Items $items -Id "no-secrets-no-broadcasts" `
    -Requirement "Reports and gates do not print secrets/env values and no live Base broadcast occurred." `
    -Status $(if ((Get-ReportStatus -Report $reports.noSecret) -eq "passed" -and $noSecretSafetyReady -and $liveProductNoLiveBroadcast -eq $true -and $liveProductEnvValuesPrinted -eq $false -and $baseTxDiagnosticBroadcasts -eq $false -and $baseTxDiagnosticPrintsEnvValues -eq $false -and $baseTxDiagnosticNoSecrets -eq $true -and (Get-AuditProp -Object $devPack -Name "noSecrets" -Default $false) -eq $true -and (Get-AuditProp -Object $devPack -Name "envValuesPrinted" -Default $true) -eq $false) { "passed" } else { "failed" }) `
    -Evidence "noSecretStatus=$(Get-ReportStatus -Report $reports.noSecret), scansGeneratedReports=$(Get-AuditProp -Object $noSecretChecks -Name "scansGeneratedLiveProductReports"), scansDevPack=$(Get-AuditProp -Object $noSecretChecks -Name "scansGeneratedDevPackReports"), scansSdkDocs=$(Get-AuditProp -Object $noSecretChecks -Name "scansGeneratedSdkDocs"), reportPathMatchesProductionGate=$(Get-AuditProp -Object $noSecretChecks -Name "reportPathMatchesProductionGate"), failedChecks=$noSecretFailedCheckCount, secretFindings=$noSecretSecretFindingCount, findings=$noSecretFindingCount, liveProductNoLiveBroadcast=$liveProductNoLiveBroadcast, baseTxDiagnosticBroadcasts=$baseTxDiagnosticBroadcasts, baseTxDiagnosticNoSecrets=$baseTxDiagnosticNoSecrets, devPackNoSecrets=$(Get-AuditProp -Object $devPack -Name "noSecrets" -Default $false), reports=$($paths.noSecret), $($paths.baseTxDiagnostic), $($paths.devPack)" `
    -Commands @("npm run flowchain:no-secret:scan")

$failedItems = @($items | Where-Object { $_.status -eq "failed" })
$blockedItems = @($items | Where-Object { $_.status -eq "blocked" })
$status = if ($failedItems.Count -gt 0) { "failed" } elseif ($blockedItems.Count -gt 0) { "blocked" } else { "passed" }
$completionReady = $status -eq "passed"

$report = [ordered]@{
    schema = "flowchain.completion_audit_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    completionReady = $completionReady
    refreshMode = $(if ($NoRefresh.IsPresent) { "no-refresh-existing-reports" } else { "full-child-refresh" })
    childRefreshPerformed = -not $NoRefresh.IsPresent
    objective = "FlowChain live infrastructure/public RPC/deployment readiness with wallets, RPC connectivity, bridge readiness, block production, fail-closed owner inputs, no secrets, and no live broadcasts."
    latestHeight = $latestHeight
    liveProductExitCode = $liveProductExitCode
    liveProductOutputRedacted = @($liveProductOutput | ForEach-Object { "$_" })
    serviceStatusExitCode = $serviceStatusExitCode
    serviceStatusOutputRedacted = @($serviceStatusOutput | ForEach-Object { "$_" })
    operatorDoctorExitCode = $operatorDoctorExitCode
    operatorDoctorOutputRedacted = @($operatorDoctorOutput | ForEach-Object { "$_" })
    serviceMonitorExitCode = $serviceMonitorExitCode
    serviceMonitorOutputRedacted = @($serviceMonitorOutput | ForEach-Object { "$_" })
    serviceSupervisorValidationExitCode = $serviceSupervisorValidationExitCode
    serviceSupervisorValidationOutputRedacted = @($serviceSupervisorValidationOutput | ForEach-Object { "$_" })
    serviceInstallValidationExitCode = $serviceInstallValidationExitCode
    serviceInstallValidationOutputRedacted = @($serviceInstallValidationOutput | ForEach-Object { "$_" })
    systemdServiceInstallValidationExitCode = $systemdServiceInstallValidationExitCode
    systemdServiceInstallValidationOutputRedacted = @($systemdServiceInstallValidationOutput | ForEach-Object { "$_" })
    upgradeRehearsalExitCode = $upgradeRehearsalExitCode
    upgradeRehearsalOutputRedacted = @($upgradeRehearsalOutput | ForEach-Object { "$_" })
    installCheckExitCode = $installCheckExitCode
    installCheckOutputRedacted = @($installCheckOutput | ForEach-Object { "$_" })
    liveWalletExitCode = $liveWalletExitCode
    liveWalletOutputRedacted = @($liveWalletOutput | ForEach-Object { "$_" })
    testerNetworkExitCode = $testerNetworkExitCode
    testerNetworkOutputRedacted = @($testerNetworkOutput | ForEach-Object { "$_" })
    devPackExitCode = $devPackExitCode
    devPackOutputRedacted = @($devPackOutput | ForEach-Object { "$_" })
    bridgePilotLocalExitCode = $bridgePilotLocalExitCode
    bridgePilotLocalOutputRedacted = @($bridgePilotLocalOutput | ForEach-Object { "$_" })
    baseTxDiagnosticExitCode = $baseTxDiagnosticExitCode
    baseTxDiagnosticOutputRedacted = @($baseTxDiagnosticOutput | ForEach-Object { "$_" })
    ownerInputsValidationExitCode = $ownerInputsValidationExitCode
    ownerInputsValidationOutputRedacted = @($ownerInputsValidationOutput | ForEach-Object { "$_" })
    publicRpcValidationExitCode = $publicRpcValidationExitCode
    publicRpcValidationOutputRedacted = @($publicRpcValidationOutput | ForEach-Object { "$_" })
    publicRpcAbuseTestExitCode = $publicRpcAbuseTestExitCode
    publicRpcAbuseTestOutputRedacted = @($publicRpcAbuseTestOutput | ForEach-Object { "$_" })
    publicRpcSyntheticCanaryExitCode = $publicRpcSyntheticCanaryExitCode
    publicRpcSyntheticCanaryOutputRedacted = @($publicRpcSyntheticCanaryOutput | ForEach-Object { "$_" })
    testerWriteTokenSetupExitCode = $testerWriteTokenSetupExitCode
    testerWriteTokenSetupOutputRedacted = @($testerWriteTokenSetupOutput | ForEach-Object { "$_" })
    publicTesterGatewayExitCode = $publicTesterGatewayExitCode
    publicTesterGatewayOutputRedacted = @($publicTesterGatewayOutput | ForEach-Object { "$_" })
    dashboardUiReadinessExitCode = $dashboardUiReadinessExitCode
    dashboardUiReadinessOutputRedacted = @($dashboardUiReadinessOutput | ForEach-Object { "$_" })
    secondComputerReadinessExitCode = $secondComputerReadinessExitCode
    secondComputerReadinessOutputRedacted = @($secondComputerReadinessOutput | ForEach-Object { "$_" })
    backupRestoreValidationExitCode = $backupRestoreValidationExitCode
    backupRestoreValidationOutputRedacted = @($backupRestoreValidationOutput | ForEach-Object { "$_" })
    backupOwnerPathDryRunExitCode = $backupOwnerPathDryRunExitCode
    backupOwnerPathDryRunOutputRedacted = @($backupOwnerPathDryRunOutput | ForEach-Object { "$_" })
    backupInstallValidationExitCode = $backupInstallValidationExitCode
    backupInstallValidationOutputRedacted = @($backupInstallValidationOutput | ForEach-Object { "$_" })
    bridgeDeployControlValidationExitCode = $bridgeDeployControlValidationExitCode
    bridgeDeployControlValidationOutputRedacted = @($bridgeDeployControlValidationOutput | ForEach-Object { "$_" })
    bridgeRelayerOnceExitCode = $bridgeRelayerOnceExitCode
    bridgeRelayerOnceOutputRedacted = @($bridgeRelayerOnceOutput | ForEach-Object { "$_" })
    bridgeRelayerGuardrailValidationExitCode = $bridgeRelayerGuardrailValidationExitCode
    bridgeRelayerGuardrailValidationOutputRedacted = @($bridgeRelayerGuardrailValidationOutput | ForEach-Object { "$_" })
    bridgeRelayerLoopValidationExitCode = $bridgeRelayerLoopValidationExitCode
    bridgeRelayerLoopValidationOutputRedacted = @($bridgeRelayerLoopValidationOutput | ForEach-Object { "$_" })
    bridgeRuntimeCreditValidationExitCode = $bridgeRuntimeCreditValidationExitCode
    bridgeRuntimeCreditValidationOutputRedacted = @($bridgeRuntimeCreditValidationOutput | ForEach-Object { "$_" })
    realValuePilotAggregateExitCode = $realValuePilotAggregateExitCode
    realValuePilotAggregateOutputRedacted = @($realValuePilotAggregateOutput | ForEach-Object { "$_" })
    bridgeReconciliationExitCode = $bridgeReconciliationExitCode
    bridgeReconciliationOutputRedacted = @($bridgeReconciliationOutput | ForEach-Object { "$_" })
    ownerInputsExitCode = $ownerInputsExitCode
    ownerInputsOutputRedacted = @($ownerInputsOutput | ForEach-Object { "$_" })
    ownerOnboardingExitCode = $ownerOnboardingExitCode
    ownerOnboardingOutputRedacted = @($ownerOnboardingOutput | ForEach-Object { "$_" })
    ownerSignupChecklistExitCode = $ownerSignupChecklistExitCode
    ownerSignupChecklistOutputRedacted = @($ownerSignupChecklistOutput | ForEach-Object { "$_" })
    ownerActivationPlanExitCode = $ownerActivationPlanExitCode
    ownerActivationPlanOutputRedacted = @($ownerActivationPlanOutput | ForEach-Object { "$_" })
    ownerEnvTemplateExitCode = $ownerEnvTemplateExitCode
    ownerEnvTemplateOutputRedacted = @($ownerEnvTemplateOutput | ForEach-Object { "$_" })
    ownerEnvReadinessValidationExitCode = $ownerEnvReadinessValidationExitCode
    ownerEnvReadinessValidationOutputRedacted = @($ownerEnvReadinessValidationOutput | ForEach-Object { "$_" })
    ownerEnvReadinessExitCode = $ownerEnvReadinessExitCode
    ownerEnvReadinessOutputRedacted = @($ownerEnvReadinessOutput | ForEach-Object { "$_" })
    publicRpcEdgeTemplateExitCode = $publicRpcEdgeTemplateExitCode
    publicRpcEdgeTemplateOutputRedacted = @($publicRpcEdgeTemplateOutput | ForEach-Object { "$_" })
    publicRpcDeploymentBundleExitCode = $publicRpcDeploymentBundleExitCode
    publicRpcDeploymentBundleOutputRedacted = @($publicRpcDeploymentBundleOutput | ForEach-Object { "$_" })
    publicRpcDeploymentAutomationExitCode = $publicRpcDeploymentAutomationExitCode
    publicRpcDeploymentAutomationOutputRedacted = @($publicRpcDeploymentAutomationOutput | ForEach-Object { "$_" })
    operatorPackageExitCode = $operatorPackageExitCode
    operatorPackageOutputRedacted = @($operatorPackageOutput | ForEach-Object { "$_" })
    operatorPackageVerifyExitCode = $operatorPackageVerifyExitCode
    operatorPackageVerifyOutputRedacted = @($operatorPackageVerifyOutput | ForEach-Object { "$_" })
    liveInfraExitCode = $liveInfraExitCode
    liveInfraOutputRedacted = @($liveInfraOutput | ForEach-Object { "$_" })
    externalTesterPacketExitCode = $externalTesterPacketExitCode
    externalTesterPacketOutputRedacted = @($externalTesterPacketOutput | ForEach-Object { "$_" })
    externalTesterPacketValidationExitCode = $externalTesterPacketValidationExitCode
    externalTesterPacketValidationOutputRedacted = @($externalTesterPacketValidationOutput | ForEach-Object { "$_" })
    externalTesterEvidenceValidationExitCode = $externalTesterEvidenceValidationExitCode
    externalTesterEvidenceValidationOutputRedacted = @($externalTesterEvidenceValidationOutput | ForEach-Object { "$_" })
    incidentDrillExitCode = $incidentDrillExitCode
    incidentDrillOutputRedacted = @($incidentDrillOutput | ForEach-Object { "$_" })
    opsSnapshotExitCode = $opsSnapshotExitCode
    opsSnapshotOutputRedacted = @($opsSnapshotOutput | ForEach-Object { "$_" })
    opsAlertRulesExitCode = $opsAlertRulesExitCode
    opsAlertRulesOutputRedacted = @($opsAlertRulesOutput | ForEach-Object { "$_" })
    alertInstallValidationExitCode = $alertInstallValidationExitCode
    alertInstallValidationOutputRedacted = @($alertInstallValidationOutput | ForEach-Object { "$_" })
    opsMetricsExportExitCode = $opsMetricsExportExitCode
    opsMetricsExportOutputRedacted = @($opsMetricsExportOutput | ForEach-Object { "$_" })
    metricsInstallValidationExitCode = $metricsInstallValidationExitCode
    metricsInstallValidationOutputRedacted = @($metricsInstallValidationOutput | ForEach-Object { "$_" })
    opsEscalationDryRunExitCode = $opsEscalationDryRunExitCode
    opsEscalationDryRunOutputRedacted = @($opsEscalationDryRunOutput | ForEach-Object { "$_" })
    publicDeploymentContractExitCode = $publicDeploymentContractExitCode
    publicDeploymentContractOutputRedacted = @($publicDeploymentContractOutput | ForEach-Object { "$_" })
    architectureAuditExitCode = $architectureAuditExitCode
    architectureAuditOutputRedacted = @($architectureAuditOutput | ForEach-Object { "$_" })
    packetExecutableSmokeValidated = $externalTesterPacketExecutableSmokeValidated
    externalTesterLaunchEvidence = [ordered]@{
        externalTesterStatus = $externalTesterStatus
        externalSharingReady = $externalSharingReady
        testerNetworkFresh = $externalTesterNetworkFresh
        packetStatus = $externalTesterPacketStatus
        packetShareable = $externalTesterPacketShareable
        packetExecutableSmokeValidated = $externalTesterPacketExecutableSmokeValidated
        packetSmokeChecks = $externalTesterPacketSmokeChecks
        packetSmokeRoutes = @($externalTesterPacketSmokeRoutes)
        connectPackShareable = $externalTesterConnectPackShareable
        connectPackReady = $externalTesterConnectPackReady
        connectPackChecks = $externalTesterConnectPackChecks
        packetValidationStatus = $externalTesterPacketValidationStatus
        packetValidationPassed = $externalTesterPacketValidationPassed
        evidenceValidationStatus = $externalTesterEvidenceValidationStatus
        evidenceValidationPassed = $externalTesterEvidenceValidationPassed
        packetPath = $externalTesterPacketPath
        readinessStatus = (Get-ReportStatus -Report $externalTester)
        ownerActivationPlanStatus = $ownerActivationPlanStatus
        ownerActivationPlanPassed = $ownerActivationPlanPassed
        ownerActivationPlanActivationReady = $ownerActivationPlanActivationReady
        testerWriteTokenSetupStatus = $testerWriteTokenSetupStatus
        testerWriteTokenSetupPassed = $testerWriteTokenSetupPassed
        publicTesterGatewayStatus = $publicTesterGatewayStatus
        publicTesterGatewayPassed = $publicTesterGatewayPassed
        publicRpcSyntheticCanaryStatus = $publicRpcSyntheticCanaryStatus
        publicRpcSyntheticCanaryReady = $publicRpcSyntheticCanaryReady
        publicRpcSyntheticCanaryOwnerBlocked = $publicRpcSyntheticCanaryOwnerBlocked
        publicRpcSyntheticCanarySafe = $publicRpcSyntheticCanarySafe
        dashboardUiReadinessStatus = $dashboardUiReadinessStatus
        dashboardUiReadinessPassed = $dashboardUiReadinessPassed
        dashboardUiBrowserProjects = @($dashboardUiBrowserProjects)
        dashboardUiCoveredRoutes = @($dashboardUiCoveredRoutes)
        secondComputerReadinessStatus = $secondComputerReadinessStatus
        secondComputerReadinessPassed = $secondComputerReadinessPassed
        serviceSupervisorValidationStatus = $serviceSupervisorValidationStatus
        serviceSupervisorValidationPassed = $serviceSupervisorValidationPassed
        serviceInstallValidationStatus = $serviceInstallValidationStatus
        serviceInstallValidationPassed = $serviceInstallValidationPassed
        systemdServiceInstallValidationStatus = $systemdServiceInstallValidationStatus
        systemdServiceInstallValidationPassed = $systemdServiceInstallValidationPassed
        upgradeRehearsalStatus = $upgradeRehearsalStatus
        upgradeRehearsalPassed = $upgradeRehearsalPassed
        installCheckStatus = $installCheckStatus
        installCheckPassed = $installCheckPassed
        bridgeDeployControlValidationStatus = $bridgeDeployControlValidationStatus
        bridgeDeployControlValidationPassed = $bridgeDeployControlValidationPassed
        bridgeRelayerOnceStatus = $bridgeRelayerOnceStatus
        bridgeRelayerOnceCheckContractPassed = $bridgeRelayerOnceCheckContractPassed
        bridgeRelayerGuardrailValidationStatus = $bridgeRelayerGuardrailValidationStatus
        bridgeRelayerGuardrailValidationPassed = $bridgeRelayerGuardrailValidationPassed
        bridgeRelayerLoopValidationStatus = $bridgeRelayerLoopValidationStatus
        bridgeRelayerLoopValidationPassed = $bridgeRelayerLoopValidationPassed
        bridgeRuntimeCreditValidationStatus = $bridgeRuntimeCreditValidationStatus
        bridgeRuntimeCreditValidationPassed = $bridgeRuntimeCreditValidationPassed
        realValuePilotAggregateStatus = $realValuePilotAggregateStatus
        realValuePilotAggregatePassed = $realValuePilotAggregatePassed
        bridgeReconciliationStatus = $bridgeReconciliationStatus
        bridgeReconciliationPassed = $bridgeReconciliationPassed
        publicDeploymentContractPacketSmoke = $publicDeploymentContractPacketSmoke
    }
    childProcessTimeoutSeconds = $ChildTimeoutSeconds
    childProcessResults = @($script:AuditChildProcessResults)
    itemCounts = [ordered]@{
        passed = @($items | Where-Object { $_.status -eq "passed" }).Count
        blocked = $blockedItems.Count
        failed = $failedItems.Count
        total = $items.Count
    }
    items = @($items)
    missingEnvNames = @($missingEnv)
    exactExternalOwnerInputsRemaining = @($missingEnv)
    reportPaths = $paths
    nextCommandsAfterOwnerInputs = @(
        "npm run flowchain:owner-inputs:validate",
        "npm run flowchain:owner:onboarding",
        "npm run flowchain:owner:signup-checklist",
        "npm run flowchain:owner:activation-plan",
        "npm run flowchain:owner:go-live-handoff",
        "npm run flowchain:owner-env:template",
        "npm run flowchain:owner-env:readiness:validate",
        "npm run flowchain:owner-env:readiness -- -AllowBlocked",
        "npm run flowchain:owner-inputs",
        "npm run flowchain:doctor -- -ReportPath docs/agent-runs/live-product-infra-rpc/operator-doctor-report.json",
        "npm run flowchain:public-rpc:edge-template",
        "npm run flowchain:public-rpc:deployment-bundle",
        "npm run flowchain:public-rpc:deployment:automation",
        "npm run flowchain:operator:package",
        "npm run flowchain:operator:package:verify",
        "npm run flowchain:public-rpc:validate",
        "npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked",
        "npm run flowchain:public-rpc:abuse-test",
        "npm run flowchain:tester:gateway:e2e",
        "npm run flowchain:dashboard:ui:readiness",
        "npm run flowchain:second-computer:readiness",
        "npm run flowchain:backup:restore:validate",
        "npm run flowchain:backup:owner-path:dry-run",
        "npm run flowchain:backup:create",
        "npm run flowchain:backup:restore:verify",
        "npm run flowchain:backup:check",
        "npm run flowchain:service:monitor",
        "npm run flowchain:service:supervisor:validate",
        "npm run flowchain:service:install:validate",
        "npm run flowchain:dev-pack:e2e",
        "npm run flowchain:bridge:relayer:guardrail:validate",
        "npm run flowchain:bridge:relayer:loop:validate",
        "npm run flowchain:bridge:runtime-credit:validate",
        "npm run flowchain:real-value-pilot:e2e -- -SkipBaseline -ChildTimeoutSeconds 1800",
        "npm run flowchain:bridge:release:evidence:validate",
        "npm run flowchain:ops:snapshot",
        "npm run flowchain:ops:alerts",
        "npm run flowchain:ops:alerts:install:systemd:validate",
        "npm run flowchain:ops:alerts:install:validate",
        "npm run flowchain:ops:metrics:export",
        "npm run flowchain:ops:metrics:install:systemd:validate",
        "npm run flowchain:ops:metrics:install:validate",
        "npm run flowchain:ops:escalation:dry-run",
        "npm run flowchain:ops:incident-drill",
        "npm run flowchain:live-infra:check",
        "npm run flowchain:bridge:diagnose:tx",
        "npm run flowchain:tester:readiness",
        "npm run flowchain:external-tester:packet",
        "npm run flowchain:external-tester:client:validate",
        "npm run flowchain:tester:evidence:validate",
        "npm run flowchain:public-deployment:contract",
        "npm run flowchain:architecture:audit",
        "npm run flowchain:live-product:e2e"
    )
    noLiveBroadcast = $true
    envValuesPrinted = $false
    noSecrets = $true
}

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Completion Audit")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Completion ready: $completionReady")
$markdownLines.Add("Refresh mode: $($report.refreshMode)")
$markdownLines.Add("Latest observed height: $latestHeight")
$markdownLines.Add("")
$markdownLines.Add("## Prompt-To-Artifact Checklist")
$markdownLines.Add("")
$markdownLines.Add("| Requirement | Status | Evidence | Commands |")
$markdownLines.Add("| --- | --- | --- | --- |")
foreach ($item in $items) {
    $markdownLines.Add("| $($item.requirement.Replace('|','/')) | $($item.status) | $($item.evidence.Replace('|','/')) | $((@($item.commands)) -join '; ') |")
}
$markdownLines.Add("")
$markdownLines.Add("## Remaining External Owner Inputs")
$markdownLines.Add("")
if ($missingEnv.Count -eq 0) {
    $markdownLines.Add("- None")
}
else {
    foreach ($name in @($missingEnv)) {
        $markdownLines.Add("- $name")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Completion Decision")
$markdownLines.Add("")
if ($completionReady) {
    $markdownLines.Add("All audited requirements are passed.")
}
else {
    $markdownLines.Add("Do not mark the goal complete. The local L1 and private tester rehearsal are working, but public RPC, tester write gateway, backup, and Base 8453 bridge readiness remain blocked on exact owner inputs.")
}

$reportText = $report | ConvertTo-Json -Depth 20
Assert-FlowChainNoSecretText -Text $reportText -Label "completion audit report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "completion audit markdown"
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain completion audit status: $status"
Write-Host "Completion ready: $completionReady"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($missingEnv.Count -gt 0) {
    Write-Host "Missing env names: $((@($missingEnv)) -join ', ')"
}
if ($status -eq "passed" -or ($status -eq "blocked" -and $AllowBlocked)) {
    exit 0
}
exit 1
