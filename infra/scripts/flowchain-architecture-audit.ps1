param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/flowchain-architecture-audit-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/ARCHITECTURE_AUDIT.md",
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)

$knownExternalOwnerInputs = @(
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

$reportPaths = [ordered]@{
    serviceStatus = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-status-report.json"
    operatorDoctor = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/operator-doctor-report.json"
    serviceMonitor = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-monitor-report.json"
    serviceSupervisorValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-report.json"
    serviceInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-install-validation-report.json"
    systemdServiceInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/systemd-service-install-validation-report.json"
    operatorPackage = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/operator-package-report.json"
    operatorPackageVerify = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/operator-package-verify-report.json"
    opsSnapshot = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-snapshot-report.json"
    opsAlertRules = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-alert-rules-report.json"
    alertInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/alert-install-validation-report.json"
    opsMetricsExport = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-metrics-export-report.json"
    metricsInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/metrics-install-validation-report.json"
    opsEscalationDryRun = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-escalation-dry-run-report.json"
    incidentDrill = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/incident-drill-report.json"
    liveWallet = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/live-service-wallet-e2e-report.json"
    testerNetwork = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json"
    publicRpcReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json"
    publicRpcSyntheticCanary = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-synthetic-canary-report.json"
    publicRpcValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json"
    publicRpcAbuseTest = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-abuse-test-report.json"
    backupReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json"
    backupRestoreValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-report.json"
    backupOwnerPathDryRun = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-owner-path-dry-run-report.json"
    backupInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-install-validation-report.json"
    bridgeLiveReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
    bridgeInfraReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
    bridgeRelayerOnce = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-once-report.json"
    bridgeRelayerGuardrailValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-guardrail-validation-report.json"
    bridgeRelayerLoopValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-loop-validation-report.json"
    bridgeRuntimeCreditValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-runtime-credit-validation-report.json"
    bridgePilotLocal = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "services/bridge-relayer/out/real-value-pilot-e2e/bridge-real-value-pilot-e2e-report.json"
    baseTxDiagnostic = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/live-l1-bridge-e2e/base-tx-diagnostic.json"
    ownerOnboarding = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-onboarding-report.json"
    ownerSignupChecklist = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-signup-checklist-report.json"
    ownerGoLiveHandoff = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-go-live-handoff-report.json"
    ownerInputs = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json"
    ownerEnvReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-env-readiness-report.json"
    ownerEnvReadinessValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-env-readiness-validation-report.json"
    publicRpcEdgeTemplate = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-edge-template-report.json"
    publicRpcDeploymentBundle = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json"
    publicRpcDeploymentAutomation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json"
    ownerInputsValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-validation-report.json"
    liveInfra = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-live-infra-check-report.json"
    liveProduct = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-live-product-e2e-report.json"
    externalTester = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
    externalTesterPacket = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json"
    externalTesterEvidenceValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-evidence-validation-report.json"
    testerWriteTokenSetup = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/tester-write-token-setup-report.json"
    publicTesterGateway = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json"
    dashboardUiReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/dashboard-ui-readiness-report.json"
    devPack = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-dev-pack/dev-pack-e2e-report.json"
    publicDeploymentContract = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json"
    noSecret = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json"
}

function Get-ArchitectureJson {
    param([Parameter(Mandatory = $true)][string] $Path)
    return Read-FlowChainJsonIfExists -Path $Path
}

function Get-ArchitectureProp {
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

function Get-ArchitectureStatus {
    param([AllowNull()][object] $Report)
    return [string](Get-ArchitectureProp -Object $Report -Name "status" -Default "missing")
}

function Test-RepoFile {
    param([Parameter(Mandatory = $true)][string] $Path)
    return Test-Path -LiteralPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $Path)
}

function Test-PackageScript {
    param(
        [Parameter(Mandatory = $true)][AllowNull()][object] $PackageJson,
        [Parameter(Mandatory = $true)][string] $Name
    )

    if ($null -eq $PackageJson -or -not ($PackageJson.PSObject.Properties.Name -contains "scripts")) {
        return $false
    }
    return $PackageJson.scripts.PSObject.Properties.Name -contains $Name
}

function Add-UniqueArchitectureName {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [object] $Value
    )
    $name = "$Value"
    if (-not [string]::IsNullOrWhiteSpace($name) -and -not $Target.Contains($name)) {
        [void] $Target.Add($name)
    }
}

function Add-ArchitectureItem {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Items,
        [Parameter(Mandatory = $true)][string] $Id,
        [Parameter(Mandatory = $true)][string] $Layer,
        [Parameter(Mandatory = $true)][string] $Requirement,
        [Parameter(Mandatory = $true)][string] $Status,
        [Parameter(Mandatory = $true)][string] $Evidence,
        [string[]] $Files = @(),
        [string[]] $Commands = @(),
        [string[]] $Blockers = @()
    )

    [void] $Items.Add([ordered]@{
        id = $Id
        layer = $Layer
        requirement = $Requirement
        status = $Status
        evidence = $Evidence
        files = $Files
        commands = $Commands
        blockers = $Blockers
    })
}

function Test-AllRepoFilesExist {
    param([string[]] $Paths)
    foreach ($path in $Paths) {
        if (-not (Test-RepoFile -Path $path)) {
            return $false
        }
    }
    return $true
}

$packageJsonPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "package.json"
$packageJson = Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json

$reports = [ordered]@{}
foreach ($entry in $reportPaths.GetEnumerator()) {
    $reports[$entry.Key] = Get-ArchitectureJson -Path $entry.Value
}

$readinessMissingEnvSourceNames = @(
    "liveProduct",
    "liveInfra",
    "externalTester",
    "ownerInputs",
    "ownerEnvReadiness",
    "externalTesterPacket",
    "publicRpcReadiness",
    "backupReadiness",
    "bridgeLiveReadiness",
    "bridgeInfraReadiness"
)
$missingOwnerInputs = New-Object System.Collections.ArrayList
$optionalOwnerInputs = @("FLOWCHAIN_BASE8453_CURSOR_STATE", "FLOWCHAIN_BASE8453_TO_BLOCK")
foreach ($sourceName in $readinessMissingEnvSourceNames) {
    $report = $reports[$sourceName]
    foreach ($name in @((Get-ArchitectureProp -Object $report -Name "missingEnvNames" -Default @()))) {
        if ($name -notin $optionalOwnerInputs) {
            Add-UniqueArchitectureName -Target $missingOwnerInputs -Value $name
        }
    }
}
foreach ($name in @((Get-ArchitectureProp -Object $reports.ownerInputs -Name "invalidEnvNames" -Default @()))) {
    Add-UniqueArchitectureName -Target $missingOwnerInputs -Value $name
}
$diagnosticMissingEnvNames = New-Object System.Collections.ArrayList
foreach ($name in @((Get-ArchitectureProp -Object $reports.baseTxDiagnostic -Name "missingEnvNames" -Default @()))) {
    Add-UniqueArchitectureName -Target $diagnosticMissingEnvNames -Value $name
}

$unknownOwnerInputs = @($missingOwnerInputs | Where-Object { $_ -notin $knownExternalOwnerInputs })
$items = New-Object System.Collections.ArrayList

$service = $reports.serviceStatus
$serviceChain = Get-ArchitectureProp -Object $service -Name "chain"
$serviceProfile = Get-ArchitectureProp -Object $service -Name "serviceProfile"
$serviceNode = Get-ArchitectureProp -Object $service -Name "node"
$serviceControlPlane = Get-ArchitectureProp -Object $service -Name "controlPlane"
$serviceStatus = Get-ArchitectureStatus -Report $service
$latestHeight = [string](Get-ArchitectureProp -Object $serviceChain -Name "latestHeight" -Default "")
$finalizedHeight = [string](Get-ArchitectureProp -Object $serviceChain -Name "finalizedHeight" -Default "")
$liveProfile = Get-ArchitectureProp -Object $serviceProfile -Name "liveProfile" -Default $false
$maxBlocks = [int](Get-ArchitectureProp -Object $serviceProfile -Name "maxBlocks" -Default -1)
$nodeRunning = [string](Get-ArchitectureProp -Object $serviceNode -Name "status") -eq "running"
$controlPlaneRunning = [string](Get-ArchitectureProp -Object $serviceControlPlane -Name "status") -eq "running"
$runtimeFiles = @(
    "crates/flowmemory-devnet/src/cli.rs",
    "crates/flowmemory-devnet/src/storage.rs",
    "infra/scripts/flowchain-service-start.ps1",
    "infra/scripts/flowchain-service-status.ps1",
    "infra/scripts/flowchain-service-stop.ps1",
    "infra/scripts/flowchain-service-restart.ps1"
)
$runtimeReady = (Test-AllRepoFilesExist -Paths $runtimeFiles) `
    -and ($serviceStatus -eq "passed") `
    -and ($liveProfile -eq $true) `
    -and ($maxBlocks -eq 0) `
    -and ($nodeRunning -eq $true) `
    -and ($controlPlaneRunning -eq $true) `
    -and ($latestHeight -match '^\d+$') `
    -and ($finalizedHeight -match '^\d+$')
Add-ArchitectureItem -Items $items -Id "runtime-node-boundary" -Layer "L1 runtime" `
    -Requirement "The block-producing node and service lifecycle are separated from RPC, run in live profile, and expose fresh state evidence." `
    -Status $(if ($runtimeReady) { "passed" } else { "failed" }) `
    -Evidence "serviceStatus=$serviceStatus, liveProfile=$liveProfile, maxBlocks=$maxBlocks, nodeRunning=$nodeRunning, controlPlaneRunning=$controlPlaneRunning, latestHeight=$latestHeight, finalizedHeight=$finalizedHeight" `
    -Files $runtimeFiles `
    -Commands @("npm run flowchain:service:status", "npm run flowchain:service:restart -- -LiveProfile")

$operatorDoctor = $reports.operatorDoctor
$operatorDoctorStatus = Get-ArchitectureStatus -Report $operatorDoctor
$operatorDoctorFailedChecks = @((Get-ArchitectureProp -Object $operatorDoctor -Name "failedChecks" -Default @()))
$operatorDoctorBlockedChecks = @((Get-ArchitectureProp -Object $operatorDoctor -Name "blockedChecks" -Default @()))
$operatorDoctorCheckCount = @((Get-ArchitectureProp -Object $operatorDoctor -Name "checks" -Default @())).Count
$operatorDoctorBlockedOnlyOwnerInputs = (Get-ArchitectureProp -Object $operatorDoctor -Name "blockedOnlyOnOwnerInputs" -Default $false) -eq $true
$operatorDoctorReady = (Test-PackageScript -PackageJson $packageJson -Name "flowchain:doctor") `
    -and ($operatorDoctorStatus -in @("passed", "blocked", "degraded")) `
    -and ($operatorDoctorFailedChecks.Count -eq 0) `
    -and ($operatorDoctorCheckCount -ge 40) `
    -and (($operatorDoctorStatus -ne "blocked") -or $operatorDoctorBlockedOnlyOwnerInputs)
Add-ArchitectureItem -Items $items -Id "operator-doctor-boundary" -Layer "Operations" `
    -Requirement "Operator doctor covers host tools, package scripts, state path, disk, service evidence, ports, owner-input groups, and owner env-file status without printing owner values." `
    -Status $(if ($operatorDoctorReady) { "passed" } else { "failed" }) `
    -Evidence "doctorStatus=$operatorDoctorStatus, checks=$operatorDoctorCheckCount, failedChecks=$($operatorDoctorFailedChecks.Count), blockedChecks=$($operatorDoctorBlockedChecks.Count), blockedOnlyOwner=$operatorDoctorBlockedOnlyOwnerInputs" `
    -Files @("infra/scripts/flowchain-doctor.ps1") `
    -Commands @("npm run flowchain:doctor -- -ReportPath docs/agent-runs/live-product-infra-rpc/operator-doctor-report.json")

$monitor = $reports.serviceMonitor
$monitorStatus = Get-ArchitectureStatus -Report $monitor
$monitorAdvanced = Get-ArchitectureProp -Object $monitor -Name "heightAdvanced" -Default $false
$monitorSamples = [int](Get-ArchitectureProp -Object $monitor -Name "sampleCount" -Default 0)
$supervisorValidation = $reports.serviceSupervisorValidation
$supervisorValidationStatus = Get-ArchitectureStatus -Report $supervisorValidation
$supervisorRestartAttempts = [int](Get-ArchitectureProp -Object $supervisorValidation -Name "restartAttempts" -Default 0)
$supervisorChecks = Get-ArchitectureProp -Object $supervisorValidation -Name "checks"
$supervisorNodeRecovery = Get-ArchitectureProp -Object $supervisorValidation -Name "nodeRecovery"
$supervisorNodeRestartAttempts = [int](Get-ArchitectureProp -Object $supervisorNodeRecovery -Name "restartAttempts" -Default 0)
$supervisorRelayerRecovery = Get-ArchitectureProp -Object $supervisorValidation -Name "relayerLoopRecovery"
$supervisorRelayerRestartAttempts = [int](Get-ArchitectureProp -Object $supervisorRelayerRecovery -Name "restartAttempts" -Default 0)
$serviceInstallValidation = $reports.serviceInstallValidation
$serviceInstallValidationStatus = Get-ArchitectureStatus -Report $serviceInstallValidation
$serviceInstallChecks = Get-ArchitectureProp -Object $serviceInstallValidation -Name "checks"
$serviceInstallFailedChecks = @((Get-ArchitectureProp -Object $serviceInstallValidation -Name "failedChecks" -Default @()))
$systemdServiceInstallValidation = $reports.systemdServiceInstallValidation
$systemdServiceInstallValidationStatus = Get-ArchitectureStatus -Report $systemdServiceInstallValidation
$systemdServiceInstallChecks = Get-ArchitectureProp -Object $systemdServiceInstallValidation -Name "checks"
$systemdServiceInstallFailedChecks = @((Get-ArchitectureProp -Object $systemdServiceInstallValidation -Name "failedChecks" -Default @()))
$opsSnapshot = $reports.opsSnapshot
$opsSnapshotStatus = Get-ArchitectureStatus -Report $opsSnapshot
$opsCriticalCount = [int](Get-ArchitectureProp -Object $opsSnapshot -Name "criticalCount" -Default 999)
$opsAlertRules = $reports.opsAlertRules
$opsAlertRulesStatus = Get-ArchitectureStatus -Report $opsAlertRules
$opsAlertRuleCount = [int](Get-ArchitectureProp -Object $opsAlertRules -Name "ruleCount" -Default 0)
$opsAlertCriticalRules = [int](Get-ArchitectureProp -Object $opsAlertRules -Name "criticalRuleCount" -Default 0)
$opsAlertBlockedRules = [int](Get-ArchitectureProp -Object $opsAlertRules -Name "blockedRuleCount" -Default 0)
$opsAlertCoveredFindingCodes = @((Get-ArchitectureProp -Object $opsAlertRules -Name "coveredFindingCodes" -Default @()))
$opsAlertUnmappedCodes = @((Get-ArchitectureProp -Object $opsAlertRules -Name "unmappedCurrentFindingCodes" -Default @()))
$opsAlertChecks = Get-ArchitectureProp -Object $opsAlertRules -Name "checks"
$alertInstallValidation = $reports.alertInstallValidation
$alertInstallValidationStatus = Get-ArchitectureStatus -Report $alertInstallValidation
$alertInstallChecks = Get-ArchitectureProp -Object $alertInstallValidation -Name "checks"
$alertInstallFailedChecks = @((Get-ArchitectureProp -Object $alertInstallValidation -Name "failedChecks" -Default @()))
$opsMetricsExport = $reports.opsMetricsExport
$opsMetricsExportStatus = Get-ArchitectureStatus -Report $opsMetricsExport
$opsMetricsExportChecks = Get-ArchitectureProp -Object $opsMetricsExport -Name "checks"
$opsMetricsExportMetricCount = [int](Get-ArchitectureProp -Object $opsMetricsExport -Name "metricCount" -Default 0)
$opsMetricsExportRequiredMetricNames = @((Get-ArchitectureProp -Object $opsMetricsExport -Name "requiredMetricNames" -Default @()))
$publicRpcSecurityHeaderMetricNames = @(
    "flowchain_public_rpc_live_security_header_probe",
    "flowchain_public_rpc_live_security_headers",
    "flowchain_public_rpc_security_header_policy_ready",
    "flowchain_public_rpc_security_headers",
    "flowchain_public_rpc_security_header_preflight",
    "flowchain_public_rpc_rendered_security_headers",
    "flowchain_public_rpc_rendered_security_header_preflight"
)
$missingPublicRpcSecurityHeaderMetricNames = @($publicRpcSecurityHeaderMetricNames | Where-Object { $_ -notin $opsMetricsExportRequiredMetricNames })
$opsMetricsHasPublicRpcSecurityHeaderMetrics = $missingPublicRpcSecurityHeaderMetricNames.Count -eq 0
$publicRpcRollbackDrillMetricNames = @(
    "flowchain_public_rpc_rollback_drill_ready",
    "flowchain_public_rpc_rollback_drill_performed",
    "flowchain_public_rpc_rollback_restored_previous",
    "flowchain_public_rpc_rollback_restored_original",
    "flowchain_public_rpc_rollback_artifacts_scoped",
    "flowchain_public_rpc_rollback_no_secrets",
    "flowchain_public_rpc_rollback_no_broadcasts"
)
$missingPublicRpcRollbackDrillMetricNames = @($publicRpcRollbackDrillMetricNames | Where-Object { $_ -notin $opsMetricsExportRequiredMetricNames })
$opsMetricsHasPublicRpcRollbackDrillMetrics = $missingPublicRpcRollbackDrillMetricNames.Count -eq 0
$publicRpcOwnerHostApplyPlanMetricNames = @(
    "flowchain_public_rpc_owner_host_apply_plan_ready",
    "flowchain_public_rpc_owner_host_artifacts_hashed",
    "flowchain_public_rpc_owner_host_install_targets_mapped",
    "flowchain_public_rpc_owner_host_systemd_install_command",
    "flowchain_public_rpc_owner_host_nginx_reload_command",
    "flowchain_public_rpc_owner_host_post_deploy_evidence"
)
$missingPublicRpcOwnerHostApplyPlanMetricNames = @($publicRpcOwnerHostApplyPlanMetricNames | Where-Object { $_ -notin $opsMetricsExportRequiredMetricNames })
$opsMetricsHasPublicRpcOwnerHostApplyPlanMetrics = $missingPublicRpcOwnerHostApplyPlanMetricNames.Count -eq 0
$backupRestoreValidationMetricNames = @(
    "flowchain_backup_restore_validation_ready",
    "flowchain_backup_restore_validation_failed_checks",
    "flowchain_backup_restore_validation_missing_checks",
    "flowchain_backup_restore_validation_secret_findings",
    "flowchain_backup_restore_hash_round_trip",
    "flowchain_backup_restore_live_state_protected",
    "flowchain_backup_restore_retention_protected"
)
$missingBackupRestoreValidationMetricNames = @($backupRestoreValidationMetricNames | Where-Object { $_ -notin $opsMetricsExportRequiredMetricNames })
$opsMetricsHasBackupRestoreValidationMetrics = $missingBackupRestoreValidationMetricNames.Count -eq 0
$backupOwnerPathDryRunMetricNames = @(
    "flowchain_backup_owner_path_dry_run_ready",
    "flowchain_backup_owner_path_dry_run_failed_checks",
    "flowchain_backup_owner_path_dry_run_missing_checks",
    "flowchain_backup_owner_path_dry_run_secret_findings",
    "flowchain_backup_owner_path_dry_run_snapshot_proof",
    "flowchain_backup_owner_path_dry_run_restore_proof",
    "flowchain_backup_owner_path_dry_run_live_state_protected",
    "flowchain_backup_owner_path_dry_run_no_mutation",
    "flowchain_backup_owner_path_dry_run_no_secrets"
)
$missingBackupOwnerPathDryRunMetricNames = @($backupOwnerPathDryRunMetricNames | Where-Object { $_ -notin $opsMetricsExportRequiredMetricNames })
$opsMetricsHasBackupOwnerPathDryRunMetrics = $missingBackupOwnerPathDryRunMetricNames.Count -eq 0
$bridgeDeployControlMetricNames = @(
    "flowchain_bridge_deploy_control_validation_ready",
    "flowchain_bridge_deploy_control_failed_checks",
    "flowchain_bridge_deploy_control_missing_checks",
    "flowchain_bridge_deploy_control_missing_env_fail_closed",
    "flowchain_bridge_deploy_control_requires_broadcast_ack",
    "flowchain_bridge_deploy_control_pause_resume_emergency",
    "flowchain_bridge_deploy_control_runbook_rollback",
    "flowchain_bridge_deploy_control_no_secrets",
    "flowchain_bridge_deploy_control_no_broadcasts"
)
$missingBridgeDeployControlMetricNames = @($bridgeDeployControlMetricNames | Where-Object { $_ -notin $opsMetricsExportRequiredMetricNames })
$opsMetricsHasBridgeDeployControlMetrics = $missingBridgeDeployControlMetricNames.Count -eq 0
$supervisorNodeRecoveryMetricNames = @(
    "flowchain_supervisor_node_recovery_validated",
    "flowchain_supervisor_node_restart_attempts",
    "flowchain_supervisor_node_crash_detected",
    "flowchain_supervisor_node_recovery_live_profile",
    "flowchain_supervisor_node_recovery_unbounded"
)
$missingSupervisorNodeRecoveryMetricNames = @($supervisorNodeRecoveryMetricNames | Where-Object { $_ -notin $opsMetricsExportRequiredMetricNames })
$opsMetricsHasSupervisorNodeRecoveryMetrics = $missingSupervisorNodeRecoveryMetricNames.Count -eq 0
$serviceInstallValidationMetricNames = @(
    "flowchain_service_install_validation_ready",
    "flowchain_service_install_failed_checks",
    "flowchain_service_install_missing_scripts",
    "flowchain_service_install_plan_did_not_mutate",
    "flowchain_service_install_live_profile_default",
    "flowchain_service_install_bridge_relayer_opt_in",
    "flowchain_service_install_status_read_only",
    "flowchain_service_install_no_secrets",
    "flowchain_service_install_no_broadcasts",
    "flowchain_systemd_service_install_validation_ready",
    "flowchain_systemd_service_install_failed_checks",
    "flowchain_systemd_service_install_rendered_units",
    "flowchain_systemd_service_install_autorecovery_loop",
    "flowchain_systemd_service_install_restart_always",
    "flowchain_systemd_service_install_hardening",
    "flowchain_systemd_service_install_no_secrets",
    "flowchain_systemd_service_install_no_broadcasts"
)
$missingServiceInstallValidationMetricNames = @($serviceInstallValidationMetricNames | Where-Object { $_ -notin $opsMetricsExportRequiredMetricNames })
$opsMetricsHasServiceInstallValidationMetrics = $missingServiceInstallValidationMetricNames.Count -eq 0
$bridgeRelayerLoopValidationMetricNames = @(
    "flowchain_bridge_relayer_loop_validation_ready",
    "flowchain_bridge_relayer_loop_failed_checks",
    "flowchain_bridge_relayer_loop_secret_findings",
    "flowchain_bridge_relayer_loop_poll_seconds",
    "flowchain_bridge_relayer_loop_settle_seconds",
    "flowchain_bridge_relayer_loop_report_fresh",
    "flowchain_bridge_relayer_loop_blocked_only_owner_inputs",
    "flowchain_bridge_relayer_loop_pid_cleanup_verified",
    "flowchain_bridge_relayer_loop_no_secrets",
    "flowchain_bridge_relayer_loop_no_broadcasts"
)
$missingBridgeRelayerLoopValidationMetricNames = @($bridgeRelayerLoopValidationMetricNames | Where-Object { $_ -notin $opsMetricsExportRequiredMetricNames })
$opsMetricsHasBridgeRelayerLoopValidationMetrics = $missingBridgeRelayerLoopValidationMetricNames.Count -eq 0
$bridgeReconciliationMetricNames = @(
    "flowchain_bridge_reconciliation_ready",
    "flowchain_bridge_reconciliation_rows_total",
    "flowchain_bridge_reconciliation_failed_checks",
    "flowchain_bridge_reconciliation_observed_credits",
    "flowchain_bridge_reconciliation_new_credits",
    "flowchain_bridge_reconciliation_queued_transactions",
    "flowchain_bridge_reconciliation_applied_credits",
    "flowchain_bridge_reconciliation_pending_credits",
    "flowchain_bridge_reconciliation_cursor_staged",
    "flowchain_bridge_reconciliation_cursor_committed",
    "flowchain_bridge_reconciliation_cursor_not_committed_when_blocked",
    "flowchain_bridge_reconciliation_runtime_credit_applied",
    "flowchain_bridge_reconciliation_replay_rejected",
    "flowchain_bridge_reconciliation_release_evidence_validated",
    "flowchain_bridge_reconciliation_no_secrets",
    "flowchain_bridge_reconciliation_no_broadcasts"
)
$missingBridgeReconciliationMetricNames = @($bridgeReconciliationMetricNames | Where-Object { $_ -notin $opsMetricsExportRequiredMetricNames })
$opsMetricsHasBridgeReconciliationMetrics = $missingBridgeReconciliationMetricNames.Count -eq 0
$externalTesterClientMetricNames = @(
    "flowchain_external_tester_client_validation_ready",
    "flowchain_external_tester_client_failed_checks",
    "flowchain_external_tester_client_secret_findings",
    "flowchain_external_tester_client_dry_run_no_network",
    "flowchain_external_tester_client_routes_cover_reads",
    "flowchain_external_tester_client_routes_cover_writes",
    "flowchain_external_tester_client_no_token_configured",
    "flowchain_external_tester_client_no_broadcasts",
    "flowchain_external_tester_client_no_secrets",
    "flowchain_external_tester_client_env_values_hidden"
)
$missingExternalTesterClientMetricNames = @($externalTesterClientMetricNames | Where-Object { $_ -notin $opsMetricsExportRequiredMetricNames })
$opsMetricsHasExternalTesterClientMetrics = $missingExternalTesterClientMetricNames.Count -eq 0
$secondComputerMetricNames = @(
    "flowchain_second_computer_ready",
    "flowchain_second_computer_bundle_created",
    "flowchain_second_computer_bundle_sha256_present",
    "flowchain_second_computer_stage_no_secret_ready",
    "flowchain_second_computer_verify_checks_passed",
    "flowchain_second_computer_failed_checks",
    "flowchain_second_computer_missing_next_commands",
    "flowchain_second_computer_failed_verify_checks",
    "flowchain_second_computer_secret_findings",
    "flowchain_second_computer_no_secrets",
    "flowchain_second_computer_no_broadcasts"
)
$missingSecondComputerMetricNames = @($secondComputerMetricNames | Where-Object { $_ -notin $opsMetricsExportRequiredMetricNames })
$opsMetricsHasSecondComputerMetrics = $missingSecondComputerMetricNames.Count -eq 0
$bridgeReleaseEvidenceMetricNames = @(
    "flowchain_bridge_release_evidence_validation_ready",
    "flowchain_bridge_release_evidence_cases_total",
    "flowchain_bridge_release_evidence_failed_cases",
    "flowchain_bridge_release_evidence_missing_cases",
    "flowchain_bridge_release_evidence_failed_checks",
    "flowchain_bridge_release_evidence_secret_findings",
    "flowchain_bridge_release_evidence_release_broadcast_rejected",
    "flowchain_bridge_release_evidence_withdrawal_broadcast_rejected",
    "flowchain_bridge_release_evidence_no_broadcasts",
    "flowchain_bridge_release_evidence_no_secrets"
)
$missingBridgeReleaseEvidenceMetricNames = @($bridgeReleaseEvidenceMetricNames | Where-Object { $_ -notin $opsMetricsExportRequiredMetricNames })
$opsMetricsHasBridgeReleaseEvidenceMetrics = $missingBridgeReleaseEvidenceMetricNames.Count -eq 0
$devPackMetricNames = @(
    "flowchain_dev_pack_ready",
    "flowchain_dev_pack_failed_checks",
    "flowchain_dev_pack_methods_total",
    "flowchain_dev_pack_public_ready_methods",
    "flowchain_dev_pack_language_sdks_total",
    "flowchain_dev_pack_python_sdk_ready",
    "flowchain_dev_pack_browser_starter_packaged",
    "flowchain_dev_pack_browser_starter_build_ready",
    "flowchain_dev_pack_browser_starter_smoke_ready",
    "flowchain_dev_pack_public_readiness_fail_closed",
    "flowchain_dev_pack_no_secrets"
)
$missingDevPackMetricNames = @($devPackMetricNames | Where-Object { $_ -notin $opsMetricsExportRequiredMetricNames })
$opsMetricsHasDevPackMetrics = $missingDevPackMetricNames.Count -eq 0
$opsMetricsExportFailedChecks = @((Get-ArchitectureProp -Object $opsMetricsExport -Name "failedChecks" -Default @()))
$opsMetricsExportSecretFindings = @((Get-ArchitectureProp -Object $opsMetricsExport -Name "secretMarkerFindings" -Default @()))
$metricsInstallValidation = $reports.metricsInstallValidation
$metricsInstallValidationStatus = Get-ArchitectureStatus -Report $metricsInstallValidation
$metricsInstallChecks = Get-ArchitectureProp -Object $metricsInstallValidation -Name "checks"
$metricsInstallFailedChecks = @((Get-ArchitectureProp -Object $metricsInstallValidation -Name "failedChecks" -Default @()))
$metricsInstallSecretFindings = @((Get-ArchitectureProp -Object $metricsInstallValidation -Name "secretMarkerFindings" -Default @()))
$opsEscalationDryRun = $reports.opsEscalationDryRun
$opsEscalationDryRunStatus = Get-ArchitectureStatus -Report $opsEscalationDryRun
$opsEscalationChecks = Get-ArchitectureProp -Object $opsEscalationDryRun -Name "checks"
$opsEscalationFailedChecks = @((Get-ArchitectureProp -Object $opsEscalationDryRun -Name "failedChecks" -Default @()))
$incidentDrill = $reports.incidentDrill
$incidentDrillStatus = Get-ArchitectureStatus -Report $incidentDrill
$incidentDrillReady = Get-ArchitectureProp -Object $incidentDrill -Name "incidentDrillReady" -Default $false
$incidentCaseCounts = Get-ArchitectureProp -Object $incidentDrill -Name "caseCounts"
$incidentFailedCases = [int](Get-ArchitectureProp -Object $incidentCaseCounts -Name "failed" -Default 999)
$incidentTotalCases = [int](Get-ArchitectureProp -Object $incidentCaseCounts -Name "total" -Default 0)
$observabilityFiles = @(
    "infra/scripts/flowchain-service-monitor.ps1",
    "infra/scripts/flowchain-service-supervisor.ps1",
    "infra/scripts/flowchain-service-supervisor-validation.ps1",
    "infra/scripts/flowchain-ops-snapshot.ps1",
    "infra/scripts/flowchain-ops-alerts.ps1",
    "infra/scripts/flowchain-alert-install-windows.ps1",
    "infra/scripts/flowchain-alert-install-systemd.ps1",
    "infra/scripts/flowchain-alert-install-systemd-validation.ps1",
    "infra/scripts/flowchain-alert-install-validation.ps1",
    "infra/scripts/flowchain-ops-metrics-export.ps1",
    "infra/scripts/flowchain-metrics-install-windows.ps1",
    "infra/scripts/flowchain-metrics-install-systemd.ps1",
    "infra/scripts/flowchain-metrics-install-systemd-validation.ps1",
    "infra/scripts/flowchain-metrics-install-validation.ps1",
    "infra/scripts/flowchain-ops-escalation-dry-run.ps1",
    "infra/scripts/flowchain-incident-drill.ps1",
    "infra/scripts/flowchain-emergency-stop-local.ps1",
    "infra/scripts/flowchain-node-stop.ps1"
)
$observabilityReady = (Test-AllRepoFilesExist -Paths $observabilityFiles) `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:service:monitor") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:service:supervisor") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:service:supervisor:validate") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:ops:snapshot") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:ops:alerts") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:ops:alerts:install:windows") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:ops:alerts:install:systemd") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:ops:alerts:install:systemd:validate") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:ops:alerts:install:validate") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:ops:metrics:export") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:ops:metrics:install:windows") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:ops:metrics:install:systemd") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:ops:metrics:install:systemd:validate") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:ops:metrics:install:validate") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:ops:escalation:dry-run") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:ops:incident-drill") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:emergency:stop-local") `
    -and ($monitorStatus -eq "passed") `
    -and ($monitorAdvanced -eq $true) `
    -and ($monitorSamples -ge 2) `
    -and ($supervisorValidationStatus -eq "passed") `
    -and ($supervisorRestartAttempts -ge 1) `
    -and ($supervisorNodeRestartAttempts -ge 1) `
    -and ((Get-ArchitectureProp -Object $supervisorChecks -Name "beforeNodeCrashPidRecorded" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $supervisorChecks -Name "nodeCrashDetected" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $supervisorChecks -Name "nodeRestartAttemptsExactlyOne" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $supervisorChecks -Name "afterNodeRecoveryNodeRunning" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $supervisorChecks -Name "afterNodeRecoveryControlPlaneRunning" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $supervisorChecks -Name "afterNodeRecoveryLiveProfile" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $supervisorChecks -Name "afterNodeRecoveryMaxBlocksUnbounded" -Default $false) -eq $true) `
    -and ($supervisorRelayerRestartAttempts -ge 1) `
    -and ((Get-ArchitectureProp -Object $supervisorChecks -Name "relayerCrashDetected" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $supervisorChecks -Name "afterRelayerRecoveryLoopRunning" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $supervisorChecks -Name "afterRelayerRecoveryLoopCommandLineMatched" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $supervisorChecks -Name "afterRelayerRecoveryLoopReportHealthy" -Default $false) -eq $true) `
    -and ($opsSnapshotStatus -in @("passed", "blocked")) `
    -and ($opsCriticalCount -eq 0) `
    -and ($opsAlertRulesStatus -eq "passed") `
    -and ($opsAlertRuleCount -ge ($opsAlertCriticalRules + $opsAlertBlockedRules)) `
    -and ($opsAlertCriticalRules -ge 5) `
    -and ($opsAlertBlockedRules -ge 5) `
    -and ($opsAlertCoveredFindingCodes.Count -ge 10) `
    -and ($opsAlertUnmappedCodes.Count -eq 0) `
    -and ($alertInstallValidationStatus -eq "passed") `
    -and ($alertInstallFailedChecks.Count -eq 0) `
    -and ((Get-ArchitectureProp -Object $alertInstallChecks -Name "planDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $alertInstallChecks -Name "statusDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $alertInstallChecks -Name "statusTaskStatePreserved" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $alertInstallChecks -Name "uninstallAbsentCommandPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $alertInstallChecks -Name "uninstallAbsentDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $alertInstallChecks -Name "uninstallAbsentTaskAbsentAfter" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $alertInstallChecks -Name "scheduledTaskTriggerSupportsRepetition" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $alertInstallChecks -Name "systemdValidationPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $alertInstallChecks -Name "systemdPlanDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $alertInstallChecks -Name "systemdServiceUnitPlanned" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $alertInstallChecks -Name "systemdTimerUnitPlanned" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $alertInstallChecks -Name "systemdNoExternalDelivery" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $alertInstallChecks -Name "noExternalDelivery" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsAlertChecks -Name "bridgeRelayerLoopRuleCoversValidationTelemetry" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsAlertChecks -Name "serviceInstallValidationRuleCoversAutorecoveryTelemetry" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsAlertChecks -Name "devPackRuleCoversBrowserStarter" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsAlertChecks -Name "publicRpcEdgeHardeningRuleCoversRollbackDrill" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsAlertChecks -Name "publicRpcEdgeHardeningRuleCoversOwnerHostApplyPlan" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsAlertChecks -Name "backupRestoreValidationRuleCoversSafety" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsAlertChecks -Name "backupOwnerPathDryRunRuleCoversOwnerPath" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsAlertChecks -Name "bridgeDeployControlRuleCoversDeploymentControls" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsAlertChecks -Name "bridgeReconciliationRuleCoversCursorAndReplay" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsAlertChecks -Name "secondComputerRuleCoversBundleVerifyNoSecret" -Default $false) -eq $true) `
    -and ($opsMetricsExportStatus -eq "passed") `
    -and ($opsMetricsExportMetricCount -ge 10) `
    -and ($opsMetricsExportFailedChecks.Count -eq 0) `
    -and ($opsMetricsExportSecretFindings.Count -eq 0) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "metricsJsonWritten" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "prometheusTextWritten" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "requiredMetricsPresent" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "backupRestoreValidationLoaded" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "backupRestoreValidationMetricsPresent" -Default $false) -eq $true) `
    -and ($opsMetricsHasBackupRestoreValidationMetrics -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "backupOwnerPathDryRunLoaded" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "backupOwnerPathDryRunMetricsPresent" -Default $false) -eq $true) `
    -and ($opsMetricsHasBackupOwnerPathDryRunMetrics -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "publicRpcEdgeMetricsPresent" -Default $false) -eq $true) `
    -and ($opsMetricsHasPublicRpcSecurityHeaderMetrics -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "publicRpcRollbackDrillMetricsPresent" -Default $false) -eq $true) `
    -and ($opsMetricsHasPublicRpcRollbackDrillMetrics -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "publicRpcOwnerHostApplyPlanMetricsPresent" -Default $false) -eq $true) `
    -and ($opsMetricsHasPublicRpcOwnerHostApplyPlanMetrics -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "bridgeDeployControlMetricsPresent" -Default $false) -eq $true) `
    -and ($opsMetricsHasBridgeDeployControlMetrics -eq $true) `
    -and ($opsMetricsHasSupervisorNodeRecoveryMetrics -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "serviceInstallValidationMetricsPresent" -Default $false) -eq $true) `
    -and ($opsMetricsHasServiceInstallValidationMetrics -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "bridgeRelayerLoopValidationMetricsPresent" -Default $false) -eq $true) `
    -and ($opsMetricsHasBridgeRelayerLoopValidationMetrics -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "bridgeReconciliationLoaded" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "bridgeReconciliationMetricsPresent" -Default $false) -eq $true) `
    -and ($opsMetricsHasBridgeReconciliationMetrics -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "bridgeReleaseEvidenceMetricsPresent" -Default $false) -eq $true) `
    -and ($opsMetricsHasBridgeReleaseEvidenceMetrics -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "externalTesterClientMetricsPresent" -Default $false) -eq $true) `
    -and ($opsMetricsHasExternalTesterClientMetrics -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "secondComputerLoaded" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "secondComputerMetricsPresent" -Default $false) -eq $true) `
    -and ($opsMetricsHasSecondComputerMetrics -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "devPackLoaded" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "devPackMetricsPresent" -Default $false) -eq $true) `
    -and ($opsMetricsHasDevPackMetrics -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "prometheusHasHelpAndType" -Default $false) -eq $true) `
    -and ($metricsInstallValidationStatus -eq "passed") `
    -and ($metricsInstallFailedChecks.Count -eq 0) `
    -and ($metricsInstallSecretFindings.Count -eq 0) `
    -and ((Get-ArchitectureProp -Object $metricsInstallChecks -Name "planDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $metricsInstallChecks -Name "statusDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $metricsInstallChecks -Name "uninstallAbsentDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $metricsInstallChecks -Name "systemdValidationPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $metricsInstallChecks -Name "systemdTimerUnitPlanned" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $metricsInstallChecks -Name "hasMetricsJsonPath" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $metricsInstallChecks -Name "hasPrometheusTextPath" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $metricsInstallChecks -Name "noExternalDelivery" -Default $false) -eq $true) `
    -and ($opsEscalationDryRunStatus -eq "passed") `
    -and ($opsEscalationFailedChecks.Count -eq 0) `
    -and ((Get-ArchitectureProp -Object $opsEscalationChecks -Name "notificationPlanNoNetworkDelivery" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsEscalationChecks -Name "notificationPlanStoresNoSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsEscalationChecks -Name "everyCurrentFindingMapped" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $opsEscalationChecks -Name "everyCurrentFindingHasCommands" -Default $false) -eq $true) `
    -and ($incidentDrillStatus -eq "passed") `
    -and ($incidentDrillReady -eq $true) `
    -and ($incidentFailedCases -eq 0) `
    -and ($incidentTotalCases -ge 8)
Add-ArchitectureItem -Items $items -Id "ops-observability-boundary" -Layer "Operations" `
    -Requirement "Operations has explicit status, monitor, ops snapshot, scheduled alert refresh, scheduled metrics export, alert rules, backup restore and owner-path telemetry, service-install validation telemetry, bridge relayer-loop validation telemetry, bridge reconciliation telemetry, bridge release-evidence validation telemetry, external tester client validation telemetry, escalation dry run, incident drills, and emergency controls that classify incidents separately from owner-input blockers." `
    -Status $(if ($observabilityReady) { "passed" } else { "failed" }) `
    -Evidence "monitorStatus=$monitorStatus, samples=$monitorSamples, heightAdvanced=$monitorAdvanced, supervisorValidation=$supervisorValidationStatus, supervisorRestartAttempts=$supervisorRestartAttempts, supervisorNodeRestartAttempts=$supervisorNodeRestartAttempts, supervisorNodeRecovered=$(Get-ArchitectureProp -Object $supervisorChecks -Name "afterNodeRecoveryNodeRunning" -Default $false), supervisorRelayerRestartAttempts=$supervisorRelayerRestartAttempts, supervisorRelayerRecovered=$(Get-ArchitectureProp -Object $supervisorChecks -Name "afterRelayerRecoveryLoopRunning" -Default $false), opsSnapshot=$opsSnapshotStatus, criticalCount=$opsCriticalCount, alertRules=$opsAlertRulesStatus, alertRuleCount=$opsAlertRuleCount, alertCoveredFindings=$($opsAlertCoveredFindingCodes.Count), relayerLoopAlertCoverage=$(Get-ArchitectureProp -Object $opsAlertChecks -Name "bridgeRelayerLoopRuleCoversValidationTelemetry" -Default $false), bridgeReconciliationAlert=$(Get-ArchitectureProp -Object $opsAlertChecks -Name "bridgeReconciliationRuleCoversCursorAndReplay" -Default $false), secondComputerAlert=$(Get-ArchitectureProp -Object $opsAlertChecks -Name "secondComputerRuleCoversBundleVerifyNoSecret" -Default $false), serviceInstallAlertCoverage=$(Get-ArchitectureProp -Object $opsAlertChecks -Name "serviceInstallValidationRuleCoversAutorecoveryTelemetry" -Default $false), devPackAlert=$(Get-ArchitectureProp -Object $opsAlertChecks -Name "devPackRuleCoversBrowserStarter" -Default $false), publicRpcRollbackAlert=$(Get-ArchitectureProp -Object $opsAlertChecks -Name "publicRpcEdgeHardeningRuleCoversRollbackDrill" -Default $false), publicRpcApplyPlanAlert=$(Get-ArchitectureProp -Object $opsAlertChecks -Name "publicRpcEdgeHardeningRuleCoversOwnerHostApplyPlan" -Default $false), backupRestoreAlert=$(Get-ArchitectureProp -Object $opsAlertChecks -Name "backupRestoreValidationRuleCoversSafety" -Default $false), backupOwnerPathAlert=$(Get-ArchitectureProp -Object $opsAlertChecks -Name "backupOwnerPathDryRunRuleCoversOwnerPath" -Default $false), bridgeDeployControlAlert=$(Get-ArchitectureProp -Object $opsAlertChecks -Name "bridgeDeployControlRuleCoversDeploymentControls" -Default $false), alertInstall=$alertInstallValidationStatus, systemdAlert=$(Get-ArchitectureProp -Object $alertInstallChecks -Name "systemdValidationPassed" -Default $false), alertInstallFailedChecks=$($alertInstallFailedChecks.Count), metricsExport=$opsMetricsExportStatus, metricCount=$opsMetricsExportMetricCount, publicRpcEdgeMetrics=$(Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "publicRpcEdgeMetricsPresent" -Default $false), publicRpcSecurityHeaderMetrics=$opsMetricsHasPublicRpcSecurityHeaderMetrics, publicRpcRollbackMetrics=$opsMetricsHasPublicRpcRollbackDrillMetrics, publicRpcOwnerApplyMetrics=$opsMetricsHasPublicRpcOwnerHostApplyPlanMetrics, backupRestoreMetrics=$opsMetricsHasBackupRestoreValidationMetrics, backupOwnerPathMetrics=$opsMetricsHasBackupOwnerPathDryRunMetrics, bridgeDeployControlMetrics=$opsMetricsHasBridgeDeployControlMetrics, supervisorNodeRecoveryMetrics=$opsMetricsHasSupervisorNodeRecoveryMetrics, serviceInstallValidationMetrics=$opsMetricsHasServiceInstallValidationMetrics, bridgeRelayerLoopValidationMetrics=$opsMetricsHasBridgeRelayerLoopValidationMetrics, bridgeReconciliationMetrics=$opsMetricsHasBridgeReconciliationMetrics, bridgeReleaseEvidenceMetrics=$opsMetricsHasBridgeReleaseEvidenceMetrics, externalTesterClientMetrics=$opsMetricsHasExternalTesterClientMetrics, secondComputerMetrics=$opsMetricsHasSecondComputerMetrics, devPackMetrics=$opsMetricsHasDevPackMetrics, metricsInstall=$metricsInstallValidationStatus, systemdMetrics=$(Get-ArchitectureProp -Object $metricsInstallChecks -Name "systemdValidationPassed" -Default $false), metricsInstallFailedChecks=$($metricsInstallFailedChecks.Count), escalationDryRun=$opsEscalationDryRunStatus, escalationFailedChecks=$($opsEscalationFailedChecks.Count), criticalRules=$opsAlertCriticalRules, blockedRules=$opsAlertBlockedRules, unmappedAlerts=$($opsAlertUnmappedCodes.Count), incidentDrill=$incidentDrillStatus, incidentCases=$incidentTotalCases, incidentFailed=$incidentFailedCases" `
    -Files $observabilityFiles `
    -Commands @("npm run flowchain:service:monitor", "npm run flowchain:service:supervisor:validate", "npm run flowchain:ops:snapshot -- -AllowBlocked", "npm run flowchain:ops:alerts -- -AllowBlocked", "npm run flowchain:ops:alerts:install:validate", "npm run flowchain:ops:alerts:install:systemd:validate", "npm run flowchain:ops:metrics:export -- -AllowBlocked", "npm run flowchain:ops:metrics:install:validate", "npm run flowchain:ops:metrics:install:systemd:validate", "npm run flowchain:ops:escalation:dry-run -- -AllowBlocked", "npm run flowchain:ops:incident-drill", "npm run flowchain:emergency:stop-local")

$serviceInstallFiles = @(
    "infra/scripts/flowchain-service-install-windows.ps1",
    "infra/scripts/flowchain-service-install-validation.ps1",
    "docs/agent-runs/live-product-infra-rpc/WINDOWS_SERVICE_INSTALL.md",
    "docs/agent-runs/live-product-infra-rpc/SERVICE_INSTALL_VALIDATION.md"
)
$systemdServiceInstallFiles = @(
    "infra/scripts/flowchain-service-install-systemd.ps1",
    "infra/scripts/flowchain-service-install-systemd-validation.ps1",
    "docs/agent-runs/live-product-infra-rpc/SYSTEMD_SERVICE_INSTALL.md",
    "docs/agent-runs/live-product-infra-rpc/SYSTEMD_SERVICE_INSTALL_VALIDATION.md"
)
$serviceInstallReady = (Test-AllRepoFilesExist -Paths $serviceInstallFiles) `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:service:install:windows") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:service:install:validate") `
    -and ($serviceInstallValidationStatus -eq "passed") `
    -and ($serviceInstallFailedChecks.Count -eq 0) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "packageScriptsPresent" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "planCommandPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "planDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "schedulerCmdletsAvailable" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "scheduledTaskActionSupportsWorkingDirectory" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "actionUsesSupervisor" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "liveProfileDefault" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "noBridgeRelayerDefault" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "bridgeRelayerOptInPlanCommandPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "bridgeRelayerOptInPlanDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "bridgeRelayerOptInStartsLoop" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "bridgeRelayerOptInAddsSupervisorFlag" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "bridgeRelayerOptInUsesSupervisor" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "commandOmitsNonLiveProfile" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "statusCommandPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "statusActionReadOnly" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "statusDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "statusReportNoSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "statusReportEnvValuesPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "statusReportBroadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "uninstallAbsentPreflightTaskAbsent" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "uninstallAbsentCommandPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "uninstallAbsentTaskWasAbsentBefore" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "uninstallAbsentDidNotCreateTask" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "uninstallAbsentDidNotRemoveTask" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "uninstallAbsentReportNoSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "uninstallAbsentReportEnvValuesPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallChecks -Name "uninstallAbsentReportBroadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $serviceInstallValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $serviceInstallValidation -Name "noSecrets" -Default $false) -eq $true)
$systemdServiceInstallReady = (Test-AllRepoFilesExist -Paths $systemdServiceInstallFiles) `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:service:install:systemd") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:service:install:systemd:validate") `
    -and ($systemdServiceInstallValidationStatus -eq "passed") `
    -and ($systemdServiceInstallFailedChecks.Count -eq 0) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "installScriptExists" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "installPackageScriptPresent" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "installPlanValidationPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "installPlanCommandPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "installPlanDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "installPlanUsesRenderedUnits" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "bridgeRelayerOptInPlanCommandPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "bridgeRelayerOptInPlanReportPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "bridgeRelayerOptInPlanDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "bridgeRelayerOptInPlanUsesRenderedUnits" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "bridgeRelayerOptInStartsLoop" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "bridgeRelayerOptInUsesSupervisor" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "bridgeRelayerOptInPlanNoSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "bridgeRelayerOptInPlanEnvValuesPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "bridgeRelayerOptInPlanBroadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "liveServiceUsesLiveProfile" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "supervisorUsesAutorecoveryLoop" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "leastPrivilegeHardeningPresent" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallValidation -Name "hostMutationPerformed" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $systemdServiceInstallValidation -Name "noSecrets" -Default $false) -eq $true)
$operatorPackage = $reports.operatorPackage
$operatorPackageStatus = Get-ArchitectureStatus -Report $operatorPackage
$operatorPackageChecks = Get-ArchitectureProp -Object $operatorPackage -Name "checks"
$operatorPackageFailedChecks = @((Get-ArchitectureProp -Object $operatorPackage -Name "failedChecks" -Default @()))
$operatorPackageCommandCount = [int](Get-ArchitectureProp -Object $operatorPackage -Name "commandCount" -Default 0)
$operatorPackageRunbookCount = [int](Get-ArchitectureProp -Object $operatorPackage -Name "runbookCount" -Default 0)
$operatorPackageEvidenceReportCount = [int](Get-ArchitectureProp -Object $operatorPackage -Name "evidenceReportCount" -Default 0)
$operatorPackageReady = (Test-PackageScript -PackageJson $packageJson -Name "flowchain:operator:package") `
    -and ($operatorPackageStatus -eq "passed") `
    -and ($operatorPackageFailedChecks.Count -eq 0) `
    -and ($operatorPackageCommandCount -ge 20) `
    -and ($operatorPackageRunbookCount -ge 10) `
    -and ($operatorPackageEvidenceReportCount -ge 15) `
    -and ((Get-ArchitectureProp -Object $operatorPackageChecks -Name "packageScriptsPresent" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $operatorPackageChecks -Name "commandMatrixWritten" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $operatorPackageChecks -Name "runbookDocsCopied" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $operatorPackageChecks -Name "evidenceReportsCopied" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $operatorPackageChecks -Name "ownerInputNamesOnly" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $operatorPackageChecks -Name "flowChainRpcIsRepoOwned" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $operatorPackageChecks -Name "thirdPartyFlowChainRpcProviderNeededFalse" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $operatorPackageChecks -Name "noSecretScanPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $operatorPackage -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $operatorPackage -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $operatorPackage -Name "broadcasts" -Default $true) -eq $false)
$operatorPackageVerify = $reports.operatorPackageVerify
$operatorPackageVerifyStatus = Get-ArchitectureStatus -Report $operatorPackageVerify
$operatorPackageVerifyChecks = Get-ArchitectureProp -Object $operatorPackageVerify -Name "checks"
$operatorPackageVerifyFailedChecks = @((Get-ArchitectureProp -Object $operatorPackageVerify -Name "failedChecks" -Default @()))
$operatorPackageVerifyExpectedFileCount = [int](Get-ArchitectureProp -Object $operatorPackageVerify -Name "expectedFileCount" -Default 0)
$operatorPackageVerifyCommandCount = [int](Get-ArchitectureProp -Object $operatorPackageVerify -Name "commandCount" -Default 0)
$operatorPackageVerifyGoLiveEvidenceCount = [int](Get-ArchitectureProp -Object $operatorPackageVerify -Name "goLiveExpectedPackageEvidenceCount" -Default 0)
$operatorPackageVerifyMissingGoLiveEvidence = @((Get-ArchitectureProp -Object $operatorPackageVerify -Name "missingGoLivePackageEvidence" -Default @()))
$operatorPackageVerifyGoLiveEvidenceNotInManifest = @((Get-ArchitectureProp -Object $operatorPackageVerify -Name "goLivePackageEvidenceNotInManifest" -Default @()))
$operatorPackageVerifyReady = (Test-PackageScript -PackageJson $packageJson -Name "flowchain:operator:package:verify") `
    -and ($operatorPackageVerifyStatus -eq "passed") `
    -and ($operatorPackageVerifyFailedChecks.Count -eq 0) `
    -and ($operatorPackageVerifyExpectedFileCount -ge 20) `
    -and ($operatorPackageVerifyCommandCount -ge 20) `
    -and ($operatorPackageVerifyGoLiveEvidenceCount -ge 30) `
    -and ($operatorPackageVerifyMissingGoLiveEvidence.Count -eq 0) `
    -and ($operatorPackageVerifyGoLiveEvidenceNotInManifest.Count -eq 0) `
    -and ((Get-ArchitectureProp -Object $operatorPackageVerifyChecks -Name "packageReportPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $operatorPackageVerifyChecks -Name "expectedFilesPresent" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $operatorPackageVerifyChecks -Name "goLiveHandoffEvidencePresent" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $operatorPackageVerifyChecks -Name "goLiveExpectedEvidencePathsPresent" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $operatorPackageVerifyChecks -Name "goLiveExpectedEvidenceInManifest" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $operatorPackageVerifyChecks -Name "ownerInputNamesOnly" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $operatorPackageVerifyChecks -Name "noForbiddenLocalFiles" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $operatorPackageVerifyChecks -Name "noSecretScanPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $operatorPackageVerify -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $operatorPackageVerify -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $operatorPackageVerify -Name "broadcasts" -Default $true) -eq $false)
Add-ArchitectureItem -Items $items -Id "service-install-boundary" -Layer "Operations" `
    -Requirement "Owner-host service lifecycle includes a no-secret Windows Scheduled Task install, read-only status, and safe absent-task uninstall no-op path for reboot-persistent live supervisor autorecovery." `
    -Status $(if ($serviceInstallReady) { "passed" } else { "failed" }) `
    -Evidence "installValidation=$serviceInstallValidationStatus, failedChecks=$($serviceInstallFailedChecks.Count), planDidNotMutate=$(Get-ArchitectureProp -Object $serviceInstallChecks -Name "planDidNotMutate"), statusCommand=$(Get-ArchitectureProp -Object $serviceInstallChecks -Name "statusCommandPassed"), statusDidNotMutate=$(Get-ArchitectureProp -Object $serviceInstallChecks -Name "statusDidNotMutate"), uninstallNoop=$(Get-ArchitectureProp -Object $serviceInstallChecks -Name "uninstallAbsentDidNotCreateTask"), liveProfileDefault=$(Get-ArchitectureProp -Object $serviceInstallChecks -Name "liveProfileDefault"), relayerDefaultOff=$(Get-ArchitectureProp -Object $serviceInstallChecks -Name "noBridgeRelayerDefault"), relayerOptIn=$(Get-ArchitectureProp -Object $serviceInstallChecks -Name "bridgeRelayerOptInStartsLoop"), schedulerCmdlets=$(Get-ArchitectureProp -Object $serviceInstallChecks -Name "schedulerCmdletsAvailable")" `
    -Files $serviceInstallFiles `
    -Commands @("npm run flowchain:service:install:validate", "npm run flowchain:service:install:windows -- -Action Plan", "npm run flowchain:service:install:windows -- -Action Install", "npm run flowchain:service:install:windows -- -Action Status", "npm run flowchain:service:install:windows -- -Action Uninstall")

Add-ArchitectureItem -Items $items -Id "systemd-service-install-boundary" -Layer "Operations" `
    -Requirement "Owner-host Linux/VPS service lifecycle includes a real no-secret systemd plan/install/status/uninstall path plus bridge-relayer opt-in plan for reboot-persistent live supervisor autorecovery from rendered units." `
    -Status $(if ($systemdServiceInstallReady) { "passed" } else { "failed" }) `
    -Evidence "systemdInstallValidation=$systemdServiceInstallValidationStatus, failedChecks=$($systemdServiceInstallFailedChecks.Count), installScript=$(Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "installScriptExists"), plan=$(Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "installPlanValidationPassed"), planDidNotMutate=$(Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "installPlanDidNotMutate"), renderedUnits=$(Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "installPlanUsesRenderedUnits"), relayerDefaultOff=$(Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "bridgeRelayerDefaultOff"), relayerOptIn=$(Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "bridgeRelayerOptInStartsLoop"), supervisor=$(Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "supervisorUsesAutorecoveryLoop"), hardening=$(Get-ArchitectureProp -Object $systemdServiceInstallChecks -Name "leastPrivilegeHardeningPresent")" `
    -Files $systemdServiceInstallFiles `
    -Commands @("npm run flowchain:service:install:systemd:validate", "npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>", "npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -StartBridgeRelayerLoop", "npm run flowchain:service:install:systemd -- -Action Install -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>", "npm run flowchain:service:install:systemd -- -Action Status", "npm run flowchain:service:install:systemd -- -Action Uninstall")

Add-ArchitectureItem -Items $items -Id "node-operator-package-boundary" -Layer "Operations" `
    -Requirement "Node operator packaging collects no-secret runbooks, command matrix, owner-input names, and current evidence for install, autorecovery, public RPC, backup, ops, bridge, testers, and release gates." `
    -Status $(if ($operatorPackageReady) { "passed" } else { "failed" }) `
    -Evidence "operatorPackage=$operatorPackageStatus, commands=$operatorPackageCommandCount, runbooks=$operatorPackageRunbookCount, evidenceReports=$operatorPackageEvidenceReportCount, failedChecks=$($operatorPackageFailedChecks.Count), noSecretScan=$(Get-ArchitectureProp -Object $operatorPackageChecks -Name "noSecretScanPassed" -Default $false)" `
    -Files @("infra/scripts/flowchain-operator-package.ps1", "docs/developer/FLOWCHAIN_NODE_OPERATOR.md") `
    -Commands @("npm run flowchain:operator:package")

Add-ArchitectureItem -Items $items -Id "node-operator-package-verify-boundary" -Layer "Operations" `
    -Requirement "Node operator package verifier independently checks generated package files, command matrix, owner-input name-only boundary, owner go-live expected evidence reports, forbidden local files, and no-secret scan." `
    -Status $(if ($operatorPackageVerifyReady) { "passed" } else { "failed" }) `
    -Evidence "operatorPackageVerify=$operatorPackageVerifyStatus, expectedFiles=$operatorPackageVerifyExpectedFileCount, commands=$operatorPackageVerifyCommandCount, goLiveEvidence=$operatorPackageVerifyGoLiveEvidenceCount, missingGoLiveEvidence=$($operatorPackageVerifyMissingGoLiveEvidence.Count), goLiveEvidenceNotInManifest=$($operatorPackageVerifyGoLiveEvidenceNotInManifest.Count), failedChecks=$($operatorPackageVerifyFailedChecks.Count), noSecretScan=$(Get-ArchitectureProp -Object $operatorPackageVerifyChecks -Name "noSecretScanPassed" -Default $false)" `
    -Files @("infra/scripts/flowchain-operator-package-verify.ps1", "docs/agent-runs/live-product-infra-rpc/OPERATOR_PACKAGE_VERIFY.md") `
    -Commands @("npm run flowchain:operator:package:verify")

$publicRpcValidation = $reports.publicRpcValidation
$publicRpcAbuseTest = $reports.publicRpcAbuseTest
$publicRpc = $reports.publicRpcReadiness
$publicRpcSyntheticCanary = $reports.publicRpcSyntheticCanary
$rpcFiles = @(
    "services/control-plane/src/server.ts",
    "services/control-plane/src/methods.ts",
    "infra/scripts/flowchain-public-rpc-readiness.ps1",
    "infra/scripts/flowchain-public-rpc-synthetic-canary.ps1",
    "infra/scripts/flowchain-public-rpc-validation.ps1",
    "infra/scripts/flowchain-public-rpc-abuse-test.ps1"
)
$publicRpcValidationStatus = Get-ArchitectureStatus -Report $publicRpcValidation
$publicRpcValidationChecks = Get-ArchitectureProp -Object $publicRpcValidation -Name "checks"
$corsAllowed = Get-ArchitectureProp -Object $publicRpcValidationChecks -Name "allowedOriginAccepted" -Default $false
$corsRejected = Get-ArchitectureProp -Object $publicRpcValidationChecks -Name "disallowedOriginRejected" -Default $false
$endpointChecks = Get-ArchitectureProp -Object $publicRpcValidationChecks -Name "noFailedEndpointChecks" -Default $false
$rateLimitProbe = Get-ArchitectureProp -Object $publicRpcValidationChecks -Name "rateLimitProbePerformed" -Default $false
$rateLimitRejected = Get-ArchitectureProp -Object $publicRpcValidationChecks -Name "rateLimitRejected" -Default $false
$rateLimitRetryAfter = Get-ArchitectureProp -Object $publicRpcValidationChecks -Name "rateLimitRetryAfterHeaderPresent" -Default $false
$securityHeaderSkip = Get-ArchitectureProp -Object $publicRpcValidationChecks -Name "securityHeaderProbeSkippedForLocalEndpoint" -Default $false
$securityHeaderPolicy = Get-ArchitectureProp -Object $publicRpcValidationChecks -Name "securityHeaderPassRequiredOnlyForPublicMode" -Default $false
$responseHygiene = Get-ArchitectureProp -Object $publicRpcValidationChecks -Name "responseHygienePassed" -Default $false
$publicRpcAbuseStatus = Get-ArchitectureStatus -Report $publicRpcAbuseTest
$publicRpcAbuseReady = Get-ArchitectureProp -Object $publicRpcAbuseTest -Name "abuseTestReady" -Default $false
$publicRpcAbuseChecks = Get-ArchitectureProp -Object $publicRpcAbuseTest -Name "checks"
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
    "badParamsRejected",
    "emptyBatchRejected",
    "oversizedBatchRejected",
    "oversizedBodyRejected",
    "notificationNoContent",
    "rateLimitRejected",
    "responseHygienePassed"
)
$publicRpcAbuseMissingChecks = @($publicRpcAbuseRequiredChecks | Where-Object { (Get-ArchitectureProp -Object $publicRpcAbuseChecks -Name $_ -Default $false) -ne $true })
$publicRpcAbusePassed = $publicRpcAbuseStatus -eq "passed" `
    -and $publicRpcAbuseReady -eq $true `
    -and $publicRpcAbuseMissingChecks.Count -eq 0 `
    -and ((Get-ArchitectureProp -Object $publicRpcAbuseTest -Name "ownerValuesRequired" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $publicRpcAbuseTest -Name "noSecrets" -Default $false) -eq $true)
$publicRpcSyntheticCanaryStatus = Get-ArchitectureStatus -Report $publicRpcSyntheticCanary
$publicRpcSyntheticCanaryChecks = Get-ArchitectureProp -Object $publicRpcSyntheticCanary -Name "checks"
$publicRpcSyntheticCanaryReady = Get-ArchitectureProp -Object $publicRpcSyntheticCanary -Name "syntheticCanaryReady" -Default $false
$publicRpcSyntheticCanaryOwnerBlocked = Get-ArchitectureProp -Object $publicRpcSyntheticCanary -Name "blockedOnlyOnKnownExternalOwnerInputs" -Default $false
$publicRpcSyntheticCanaryNoWriteMethods = ((Get-ArchitectureProp -Object $publicRpcSyntheticCanaryChecks -Name "noWriteMethodsPlanned" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $publicRpcSyntheticCanaryChecks -Name "noWriteMethodsInvoked" -Default $false) -eq $true)
$publicRpcSyntheticCanaryReadPlanCovered = ((Get-ArchitectureProp -Object $publicRpcSyntheticCanaryChecks -Name "plannedReadPathsCovered" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $publicRpcSyntheticCanaryChecks -Name "plannedReadMethodsCovered" -Default $false) -eq $true)
$publicRpcSyntheticCanarySafe = $publicRpcSyntheticCanaryStatus -in @("passed", "blocked") `
    -and ($publicRpcSyntheticCanaryNoWriteMethods -eq $true) `
    -and ($publicRpcSyntheticCanaryReadPlanCovered -eq $true) `
    -and ((Get-ArchitectureProp -Object $publicRpcSyntheticCanaryChecks -Name "safeReadMethodAllowlistEnforced" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $publicRpcSyntheticCanaryChecks -Name "responseHygienePassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $publicRpcSyntheticCanary -Name "endpointValuePrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $publicRpcSyntheticCanary -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $publicRpcSyntheticCanary -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $publicRpcSyntheticCanary -Name "broadcasts" -Default $true) -eq $false)
$rpcBoundaryReady = (Test-AllRepoFilesExist -Paths $rpcFiles) `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:public-rpc:validate") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:public-rpc:synthetic-canary") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:public-rpc:abuse-test") `
    -and ($publicRpcValidationStatus -eq "passed") `
    -and ($corsAllowed -eq $true) `
    -and ($corsRejected -eq $true) `
    -and ($endpointChecks -eq $true) `
    -and ($rateLimitProbe -eq $true) `
    -and ($rateLimitRejected -eq $true) `
    -and ($rateLimitRetryAfter -eq $true) `
    -and ($securityHeaderSkip -eq $true) `
    -and ($securityHeaderPolicy -eq $true) `
    -and ($responseHygiene -eq $true) `
    -and ($publicRpcSyntheticCanarySafe -eq $true) `
    -and ($publicRpcAbusePassed -eq $true)
Add-ArchitectureItem -Items $items -Id "rpc-api-boundary" -Layer "RPC/API" `
    -Requirement "The control-plane API has explicit health/discovery/readiness/CORS/live security-header/rate-limit validation, read-only synthetic canary coverage, narrow public reads, and abuse rejection before it can be exposed publicly." `
    -Status $(if ($rpcBoundaryReady) { "passed" } else { "failed" }) `
    -Evidence "validationStatus=$publicRpcValidationStatus, corsAllowed=$corsAllowed, corsRejected=$corsRejected, endpointChecks=$endpointChecks, securityHeaderSkip=$securityHeaderSkip, securityHeaderPolicy=$securityHeaderPolicy, rateLimitProbe=$rateLimitProbe, rateLimitRejected=$rateLimitRejected, rateLimitRetryAfter=$rateLimitRetryAfter, responseHygiene=$responseHygiene, canaryStatus=$publicRpcSyntheticCanaryStatus, canarySafe=$publicRpcSyntheticCanarySafe, noWriteMethods=$publicRpcSyntheticCanaryNoWriteMethods, abuseStatus=$publicRpcAbuseStatus, abusePassed=$publicRpcAbusePassed, abuseMissingChecks=$($publicRpcAbuseMissingChecks.Count)" `
    -Files $rpcFiles `
    -Commands @("npm run flowchain:public-rpc:validate", "npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked", "npm run flowchain:public-rpc:abuse-test")

$publicRpcStatus = Get-ArchitectureStatus -Report $publicRpc
$publicRpcReady = Get-ArchitectureProp -Object $publicRpc -Name "publicRpcReady" -Default $false
$publicRpcChecks = Get-ArchitectureProp -Object $publicRpc -Name "checks"
$publicRpcLiveHeaderProbe = Get-ArchitectureProp -Object $publicRpcChecks -Name "securityHeadersProbePerformed" -Default $false
$publicRpcLiveHeaders = ((Get-ArchitectureProp -Object $publicRpcChecks -Name "securityHeadersProbePerformed" -Default $false) -eq $true) -and ((Get-ArchitectureProp -Object $publicRpcChecks -Name "securityHeadersAllRequiredPresent" -Default $false) -eq $true)
$publicRpcHeaderPolicyReady = Get-ArchitectureProp -Object $publicRpcChecks -Name "securityHeadersAllRequiredPresent" -Default $false
Add-ArchitectureItem -Items $items -Id "public-rpc-edge" -Layer "Public edge" `
    -Requirement "External RPC exposure is a distinct owner-operated edge with TLS, allowed origins, rate limits, live security-header proof, endpoint checks, response hygiene, and passing read-only synthetic canary." `
    -Status $(if ($publicRpcStatus -eq "passed" -and $publicRpcReady -eq $true -and $publicRpcSyntheticCanaryReady -eq $true) { "passed" } elseif ($publicRpcStatus -eq "blocked" -or ($publicRpcSyntheticCanaryStatus -eq "blocked" -and $publicRpcSyntheticCanaryOwnerBlocked -eq $true)) { "blocked" } else { "failed" }) `
    -Evidence "publicRpcStatus=$publicRpcStatus, publicRpcReady=$publicRpcReady, liveHeaderProbe=$publicRpcLiveHeaderProbe, liveHeaders=$publicRpcLiveHeaders, headerPolicyReady=$publicRpcHeaderPolicyReady, canaryStatus=$publicRpcSyntheticCanaryStatus, canaryReady=$publicRpcSyntheticCanaryReady, canarySafe=$publicRpcSyntheticCanarySafe" `
    -Files @("infra/scripts/flowchain-public-rpc-readiness.ps1", "infra/scripts/flowchain-public-rpc-synthetic-canary.ps1", "docs/OPERATIONS/FLOWCHAIN_OWNER_OPERATED_PUBLIC_RPC.md") `
    -Commands @("npm run flowchain:public-rpc:check", "npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked") `
    -Blockers @("FLOWCHAIN_RPC_PUBLIC_URL", "FLOWCHAIN_RPC_ALLOWED_ORIGINS", "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE", "FLOWCHAIN_RPC_TLS_TERMINATED")

$publicRpcEdgeTemplate = $reports.publicRpcEdgeTemplate
$publicRpcEdgeTemplateStatus = Get-ArchitectureStatus -Report $publicRpcEdgeTemplate
$edgeTemplateReady = Get-ArchitectureProp -Object $publicRpcEdgeTemplate -Name "edgeTemplateReady" -Default $false
$edgeTemplateRepoOwned = Get-ArchitectureProp -Object $publicRpcEdgeTemplate -Name "flowChainRpcIsRepoOwned" -Default $false
$edgeTemplateThirdPartyNeeded = Get-ArchitectureProp -Object $publicRpcEdgeTemplate -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$edgeTemplateRequiresTls = Get-ArchitectureProp -Object $publicRpcEdgeTemplate -Name "requiresTlsTermination" -Default $false
$edgeTemplateRequiresRateLimit = Get-ArchitectureProp -Object $publicRpcEdgeTemplate -Name "requiresRateLimit" -Default $false
$edgeTemplateForwardsOrigin = Get-ArchitectureProp -Object $publicRpcEdgeTemplate -Name "forwardsOriginForCors" -Default $false
$edgeTemplateStateExcluded = Get-ArchitectureProp -Object $publicRpcEdgeTemplate -Name "publicStateMirrorExcluded" -Default $false
$edgeTemplateDevnetStateExcluded = Get-ArchitectureProp -Object $publicRpcEdgeTemplate -Name "devnetStatePublicRpcExcluded" -Default $false
$edgeTemplateSecurityHeaders = @((Get-ArchitectureProp -Object $publicRpcEdgeTemplate -Name "securityHeaders" -Default @()))
$edgeTemplateDefensiveHeaderRequirementPassed = @((Get-ArchitectureProp -Object $publicRpcEdgeTemplate -Name "edgeRequirements" -Default @()) | Where-Object {
        [string](Get-ArchitectureProp -Object $_ -Name "id" -Default "") -eq "defensive-response-headers" `
            -and [string](Get-ArchitectureProp -Object $_ -Name "status" -Default "") -eq "passed"
    }).Count -gt 0
$edgeTemplateHasSecurityHeaders = $edgeTemplateSecurityHeaders.Count -ge 6
$publicRpcDeploymentBundle = $reports.publicRpcDeploymentBundle
$publicRpcDeploymentBundleStatus = Get-ArchitectureStatus -Report $publicRpcDeploymentBundle
$deploymentBundleChecks = Get-ArchitectureProp -Object $publicRpcDeploymentBundle -Name "checks"
$deploymentBundleRequiredCommands = @((Get-ArchitectureProp -Object $publicRpcDeploymentBundle -Name "requiredCommands" -Default @()) | ForEach-Object { "$_" })
$deploymentBundleCoversWalletCutover = @(
    "npm run flowchain:tester:gateway:e2e",
    "npm run flowchain:wallet:live-tester:e2e",
    "npm run flowchain:live:cutover:rehearsal -- -AllowBlocked",
    "npm run flowchain:truth-table -- -AllowBlocked",
    "npm run flowchain:no-secret:scan"
) | Where-Object { $_ -notin $deploymentBundleRequiredCommands } | Measure-Object | ForEach-Object { $_.Count -eq 0 }
$deploymentBundleReady = $publicRpcDeploymentBundleStatus -eq "passed" `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:public-rpc:deployment-bundle") `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "nginxTemplateWritten" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "nginxPreflightScriptWritten" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "windowsNginxPreflightScriptWritten" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "windowsNginxPreflightTokensPresent" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "includesWindowsNginxConfigTest" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "includesTesterWritePreflight" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "includesDisallowedOriginPreflight" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "includesBroadStateBlockedPreflight" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "includesPrivateWalletCreateBlockedPreflight" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "authorizationForwardingScopedToTesterWrite" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "includesSecurityHeaders" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "preflightsCheckSecurityHeaders" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "includesMethodRejectionPreflight" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "ownerRenderIncludesSecurityHeaders" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "ownerRenderPreflightsRejectWrongMethods" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "publicStateMirrorExcluded" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "devnetStatePublicRpcExcluded" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "ownerRenderValidationPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "ownerRenderFilesHaveNoPlaceholders" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "ownerRenderDoesNotPrintTokenHash" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "ownerEnvExampleWritten" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "verifyRunbookWritten" -Default $false) -eq $true) `
    -and ($deploymentBundleCoversWalletCutover -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "rollbackRunbookWritten" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $publicRpcDeploymentBundle -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $publicRpcDeploymentBundle -Name "noSecrets" -Default $false) -eq $true)
$publicRpcDeploymentAutomation = $reports.publicRpcDeploymentAutomation
$publicRpcDeploymentAutomationStatus = Get-ArchitectureStatus -Report $publicRpcDeploymentAutomation
$publicRpcDeploymentAutomationAction = [string](Get-ArchitectureProp -Object $publicRpcDeploymentAutomation -Name "action" -Default "")
$deploymentAutomationChecks = Get-ArchitectureProp -Object $publicRpcDeploymentAutomation -Name "checks"
$deploymentAutomationReady = $publicRpcDeploymentAutomationStatus -eq "passed" `
    -and (Test-RepoFile -Path "infra/scripts/flowchain-public-rpc-deployment-automation.ps1") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:public-rpc:deployment:automation") `
    -and ($publicRpcDeploymentAutomationAction -eq "Validate") `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderCommandPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedFilesHaveNoPlaceholders" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedFilesKeepPrivateOrigin" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedNginxHasTls" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedNginxHasCorsForwarding" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedNginxHasRateLimit" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "bundleHasSecurityHeaders" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "bundlePreflightsCheckSecurityHeaders" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedNginxHasSecurityHeaders" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedPreflightChecksSecurityHeaders" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedPreflightHasMethodRejectionProbes" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedSystemdUsesOwnerEnv" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedPreflightHasReadinessProbe" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedPreflightHasTesterUnauthProbe" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedPreflightHasDisallowedOriginProbe" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedPreflightBlocksBroadStatePath" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedPreflightBlocksPrivateWalletCreate" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedNginxAuthorizationForwardingScoped" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "rollbackDrillPerformed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "rollbackRenderedConfigRestoredFromPrevious" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "rollbackOriginalConfigRestoredAfterDrill" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "rollbackArtifactsStayedInsideRenderDir" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedReportSummaryPresent" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedReportSummaryPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedReportSummaryListsFiles" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedReportSummaryHasRequiredEnvNames" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedReportSummaryNoSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedReportSummaryBroadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedReportSummaryOwnerPathsOutsideRepo" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedReportSnapshotWritten" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedReportSnapshotNoSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "ownerHostApplyPlanPresent" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "ownerHostApplyPlanArtifactManifestCount" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "ownerHostApplyPlanArtifactsHaveSha256" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "ownerHostApplyPlanInstallTargetsMapped" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "ownerHostApplyPlanHasMutatingInstallPhase" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "ownerHostApplyPlanHasMutatingEdgePhase" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "ownerHostApplyPlanIncludesPostDeployEvidence" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesTesterGatewayE2e" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesWalletTesterE2e" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesSyntheticCanary" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesCutoverRehearsal" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesTruthTable" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesNoSecretScan" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "hostMutationPerformedFalse" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $publicRpcDeploymentAutomation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $publicRpcDeploymentAutomation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $publicRpcDeploymentAutomation -Name "broadcasts" -Default $true) -eq $false)
$publicRpcEdgeTemplateReady = (Test-RepoFile -Path "infra/scripts/flowchain-public-rpc-edge-template.ps1") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:public-rpc:edge-template") `
    -and ($publicRpcEdgeTemplateStatus -eq "passed") `
    -and ($edgeTemplateReady -eq $true) `
    -and ($edgeTemplateRepoOwned -eq $true) `
    -and ($edgeTemplateThirdPartyNeeded -eq $false) `
    -and ($edgeTemplateRequiresTls -eq $true) `
    -and ($edgeTemplateRequiresRateLimit -eq $true) `
    -and ($edgeTemplateForwardsOrigin -eq $true) `
    -and ($edgeTemplateStateExcluded -eq $true) `
    -and ($edgeTemplateDevnetStateExcluded -eq $true) `
    -and ($edgeTemplateHasSecurityHeaders -eq $true) `
    -and ($edgeTemplateDefensiveHeaderRequirementPassed -eq $true) `
    -and ((Get-ArchitectureProp -Object $publicRpcEdgeTemplate -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $publicRpcEdgeTemplate -Name "noSecrets" -Default $false) -eq $true)
Add-ArchitectureItem -Items $items -Id "public-rpc-edge-template-boundary" -Layer "Public edge" `
    -Requirement "Public RPC exposure has a no-values owner edge template and render-validated deployment bundle for HTTPS reverse proxying, rate limiting, defensive response headers, tester write preflight, wallet/tester cutover proof, disallowed-origin and blocked-private-path probes, verification, rollback, and no broad local state mirror." `
    -Status $(if ($publicRpcEdgeTemplateReady -and $deploymentBundleReady) { "passed" } else { "failed" }) `
    -Evidence "edgeTemplateStatus=$publicRpcEdgeTemplateStatus, bundleStatus=$publicRpcDeploymentBundleStatus, renderValidation=$((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "ownerRenderValidationPassed" -Default $false)), testerWritePreflight=$((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "includesTesterWritePreflight" -Default $false)), methodRejectionPreflight=$((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "includesMethodRejectionPreflight" -Default $false)), walletCutoverCommands=$deploymentBundleCoversWalletCutover, securityHeaders=$((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "includesSecurityHeaders" -Default $false)), securityHeaderPreflight=$((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "preflightsCheckSecurityHeaders" -Default $false)), ownerRenderSecurityHeaders=$((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "ownerRenderIncludesSecurityHeaders" -Default $false)), repoOwned=$edgeTemplateRepoOwned, requiresTls=$edgeTemplateRequiresTls, requiresRateLimit=$edgeTemplateRequiresRateLimit, forwardsOrigin=$edgeTemplateForwardsOrigin, publicStateMirrorExcluded=$edgeTemplateStateExcluded, devnetStatePublicRpcExcluded=$edgeTemplateDevnetStateExcluded" `
    -Files @("infra/scripts/flowchain-public-rpc-edge-template.ps1", "infra/scripts/flowchain-public-rpc-deployment-bundle.ps1", "docs/agent-runs/live-product-infra-rpc/PUBLIC_RPC_EDGE_TEMPLATE.md", "docs/agent-runs/live-product-infra-rpc/PUBLIC_RPC_DEPLOYMENT_BUNDLE.md", "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle/WINDOWS_NGINX_PREFLIGHT.md") `
    -Commands @("npm run flowchain:public-rpc:edge-template", "npm run flowchain:public-rpc:deployment-bundle")

Add-ArchitectureItem -Items $items -Id "public-rpc-deployment-automation-boundary" -Layer "Public edge" `
    -Requirement "Public RPC deployment automation renders concrete owner-host Nginx, systemd, shell preflight, Windows preflight, defensive response-header probes, tester write unauthenticated rejection probe, wallet/tester cutover proof commands, hashed artifact manifest, install/edge apply phases, post-deploy evidence, and rollback drill phases without host mutation or owner-value leakage." `
    -Status $(if ($deploymentAutomationReady) { "passed" } else { "failed" }) `
    -Evidence "automationStatus=$publicRpcDeploymentAutomationStatus, action=$publicRpcDeploymentAutomationAction, renderCommand=$(Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderCommandPassed" -Default $false), noPlaceholders=$(Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedFilesHaveNoPlaceholders" -Default $false), securityHeaders=$(Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedNginxHasSecurityHeaders" -Default $false), securityHeaderPreflight=$(Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedPreflightChecksSecurityHeaders" -Default $false), methodRejectionProbes=$(Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedPreflightHasMethodRejectionProbes" -Default $false), testerUnauthProbe=$(Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedPreflightHasTesterUnauthProbe" -Default $false), walletTesterE2e=$(Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesWalletTesterE2e" -Default $false), syntheticCanary=$(Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesSyntheticCanary" -Default $false), cutoverRehearsal=$(Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesCutoverRehearsal" -Default $false), rollbackDrill=$(Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "rollbackDrillPerformed" -Default $false), renderSummary=$(Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedReportSummaryPresent" -Default $false), renderSnapshot=$(Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "renderedReportSnapshotWritten" -Default $false), applyPlan=$(Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "ownerHostApplyPlanPresent" -Default $false), artifactHashes=$(Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "ownerHostApplyPlanArtifactsHaveSha256" -Default $false), installTargets=$(Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "ownerHostApplyPlanInstallTargetsMapped" -Default $false), hostMutationFalse=$(Get-ArchitectureProp -Object $deploymentAutomationChecks -Name "hostMutationPerformedFalse" -Default $false)" `
    -Files @("infra/scripts/flowchain-public-rpc-deployment-automation.ps1", "docs/agent-runs/live-product-infra-rpc/PUBLIC_RPC_DEPLOYMENT_AUTOMATION.md", "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json", "docs/agent-runs/live-product-infra-rpc/public-rpc-render-report-snapshot.json") `
    -Commands @("npm run flowchain:public-rpc:deployment:automation")

$wallet = $reports.liveWallet
$testerNetwork = $reports.testerNetwork
$walletFiles = @(
    "services/control-plane/src/wallet-runtime.ts",
    "infra/scripts/flowchain-live-service-wallet-e2e.ps1",
    "infra/scripts/flowchain-live-service-tester-network-e2e.ps1"
)
$walletStatus = Get-ArchitectureStatus -Report $wallet
$testerStatus = Get-ArchitectureStatus -Report $testerNetwork
$testerCreates = @((Get-ArchitectureProp -Object $testerNetwork -Name "testerWalletCreates" -Default @()))
$testerSecretLeak = @($testerCreates | Where-Object { (Get-ArchitectureProp -Object $_ -Name "secretMaterialReturned" -Default $true) -ne $false }).Count -gt 0
$walletReady = (Test-AllRepoFilesExist -Paths $walletFiles) `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:wallet:live-service:e2e") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:wallet:live-tester:e2e") `
    -and ($walletStatus -eq "passed") `
    -and ($testerStatus -eq "passed") `
    -and ($testerCreates.Count -ge 4) `
    -and ($testerSecretLeak -eq $false)
Add-ArchitectureItem -Items $items -Id "wallet-runtime-boundary" -Layer "Wallets" `
    -Requirement "Wallet creation and wallet-to-wallet transfer are routed through the RPC/control-plane boundary into runtime blocks without returning secret material." `
    -Status $(if ($walletReady) { "passed" } else { "failed" }) `
    -Evidence "walletStatus=$walletStatus, testerStatus=$testerStatus, testerWalletCreates=$($testerCreates.Count), testerSecretLeak=$testerSecretLeak" `
    -Files $walletFiles `
    -Commands @("npm run flowchain:wallet:live-service:e2e", "npm run flowchain:wallet:live-tester:e2e")

$bridgePilot = $reports.bridgePilotLocal
$bridgeExact = Get-ArchitectureProp -Object $bridgePilot -Name "exactValueConservation"
$bridgeNegative = Get-ArchitectureProp -Object $bridgePilot -Name "negativeCoverage"
$bridgeLocalFiles = @(
    "services/bridge-relayer/src/observe-base-lockbox.ts",
    "services/bridge-relayer/src/bridge-pilot-e2e.ts",
    "fixtures/bridge/base8453-pilot-mock-deposit.json"
)
$bridgePilotReady = (Test-AllRepoFilesExist -Paths $bridgeLocalFiles) `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:real-value-pilot:bridge") `
    -and ((Get-ArchitectureProp -Object $bridgePilot -Name "broadcast" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $bridgePilot -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeExact -Name "allAmountsEqual" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeNegative -Name "wrongChainRejected" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeNegative -Name "unapprovedContractRejected" -Default $false) -eq $true)
Add-ArchitectureItem -Items $items -Id "bridge-local-proof-boundary" -Layer "Bridge" `
    -Requirement "The bridge architecture has a deterministic local proof for exact value, replay protection, wrong-chain rejection, unapproved-lockbox rejection, and no broadcast." `
    -Status $(if ($bridgePilotReady) { "passed" } else { "failed" }) `
    -Evidence "broadcast=$(Get-ArchitectureProp -Object $bridgePilot -Name "broadcast"), allAmountsEqual=$(Get-ArchitectureProp -Object $bridgeExact -Name "allAmountsEqual"), wrongChainRejected=$(Get-ArchitectureProp -Object $bridgeNegative -Name "wrongChainRejected"), unapprovedContractRejected=$(Get-ArchitectureProp -Object $bridgeNegative -Name "unapprovedContractRejected")" `
    -Files $bridgeLocalFiles `
    -Commands @("npm run flowchain:real-value-pilot:bridge")

$bridgeLiveStatus = Get-ArchitectureStatus -Report $reports.bridgeLiveReadiness
$bridgeInfraStatus = Get-ArchitectureStatus -Report $reports.bridgeInfraReadiness
$bridgeRelayerStatus = Get-ArchitectureStatus -Report $reports.bridgeRelayerOnce
$baseTxDiagnostic = $reports.baseTxDiagnostic
$bridgeLiveFiles = @(
    "infra/scripts/flowchain-bridge-live-check.ps1",
    "infra/scripts/flowchain-live-env-bridge-readiness.ps1",
    "services/bridge-relayer/src/diagnose-base8453-tx.ts",
    "infra/scripts/bridge-base-mainnet-pilot-observe.ps1",
    "infra/scripts/flowchain-bridge-relayer-once.ps1",
    "infra/scripts/flowchain-bridge-relayer-guardrail-validation.ps1",
    "infra/scripts/flowchain-bridge-relayer-loop-validation.ps1",
    "infra/scripts/flowchain-bridge-runtime-credit-validation.ps1",
    "infra/scripts/flowchain-real-value-pilot-runtime.ps1",
    "docs/agent-runs/live-product-infra-rpc/BRIDGE_RELAYER_LOOP_VALIDATION.md",
    "infra/scripts/flowchain-service-start.ps1"
)
$baseTxSafe = ((Get-ArchitectureStatus -Report $baseTxDiagnostic) -in @("blocked", "valid", "invalid")) `
    -and ((Get-ArchitectureProp -Object $baseTxDiagnostic -Name "broadcasts" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $baseTxDiagnostic -Name "printsEnvValues" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $baseTxDiagnostic -Name "noSecrets" -Default $false) -eq $true)
Add-ArchitectureItem -Items $items -Id "bridge-live-edge" -Layer "Bridge" `
    -Requirement "Live Base 8453 bridge observation is isolated behind owner guardrails, read-only diagnostics, confirmation/cap settings, and no-broadcast checks." `
    -Status $(if ($bridgeLiveStatus -eq "passed" -and $bridgeInfraStatus -eq "passed" -and $baseTxSafe) { "passed" } elseif ($bridgeLiveStatus -eq "blocked" -or $bridgeInfraStatus -eq "blocked") { "blocked" } else { "failed" }) `
    -Evidence "bridgeLive=$bridgeLiveStatus, bridgeInfra=$bridgeInfraStatus, baseTxDiagnostic=$(Get-ArchitectureStatus -Report $baseTxDiagnostic), baseTxSafe=$baseTxSafe" `
    -Files $bridgeLiveFiles `
    -Commands @("npm run flowchain:bridge:live:check", "npm run flowchain:bridge:infra:check", "npm run flowchain:bridge:diagnose:tx") `
    -Blockers @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_BASE8453_ASSET_DECIMALS", "FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS")

$bridgeRelayer = $reports.bridgeRelayerOnce
$bridgeRelayerGuardrail = $reports.bridgeRelayerGuardrailValidation
$bridgeRelayerGuardrailStatus = Get-ArchitectureStatus -Report $bridgeRelayerGuardrail
$bridgeRelayerGuardrailChecks = Get-ArchitectureProp -Object $bridgeRelayerGuardrail -Name "checks"
$bridgeRelayerGuardrailReady = $bridgeRelayerGuardrailStatus -eq "passed" `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerGuardrailChecks -Name "finalCursorUnchanged" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerGuardrailChecks -Name "stagedCursorNotWritten" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerGuardrailChecks -Name "noCreditsQueued" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerGuardrailChecks -Name "relayerChildTimeoutRecorded" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerGuardrailChecks -Name "relayerNoChildTimeouts" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerGuardrailChecks -Name "broadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerGuardrailChecks -Name "envValuesPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerGuardrailChecks -Name "noSecrets" -Default $false) -eq $true)
$bridgeRelayerLoopValidation = $reports.bridgeRelayerLoopValidation
$bridgeRelayerLoopStatus = Get-ArchitectureStatus -Report $bridgeRelayerLoopValidation
$bridgeRelayerLoopChecks = Get-ArchitectureProp -Object $bridgeRelayerLoopValidation -Name "checks"
$bridgeRelayerLoopFailedChecks = @((Get-ArchitectureProp -Object $bridgeRelayerLoopValidation -Name "failedChecks" -Default @()))
$bridgeRelayerLoopReady = ($bridgeRelayerLoopStatus -eq "passed") `
    -and ($bridgeRelayerLoopFailedChecks.Count -eq 0) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerLoopChecks -Name "relayerLoopRequested" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerLoopChecks -Name "statusReportsRelayerRunning" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerLoopChecks -Name "statusRelayerCommandLineMatched" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerLoopChecks -Name "statusRelayerReportFresh" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerLoopChecks -Name "statusRelayerReportAcceptable" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerLoopChecks -Name "statusRelayerReportBlockedOnlyOnOwnerInputs" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerLoopChecks -Name "statusRelayerReportNoSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerLoopChecks -Name "statusRelayerReportNoBroadcasts" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerLoopChecks -Name "statusRelayerReportHealthy" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerLoopChecks -Name "stopHandledRelayerLoop" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerLoopChecks -Name "statusAfterStopNotRunning" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerLoopChecks -Name "relayerPidNoLongerMatchesAfterStop" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerLoopChecks -Name "relayerPidFileRemovedAfterStop" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerLoopChecks -Name "stopReportRelayerPidFileRemoved" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerLoopChecks -Name "noValidationRelayerProcessAfterStop" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerLoopValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerLoopValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerLoopValidation -Name "broadcasts" -Default $true) -eq $false)
$bridgeRuntimeCreditValidation = $reports.bridgeRuntimeCreditValidation
$bridgeRuntimeCreditStatus = Get-ArchitectureStatus -Report $bridgeRuntimeCreditValidation
$bridgeRuntimeCreditChecks = Get-ArchitectureProp -Object $bridgeRuntimeCreditValidation -Name "checks"
$bridgeRuntimeCreditTiming = Get-ArchitectureProp -Object $bridgeRuntimeCreditValidation -Name "timing"
$bridgeRuntimeCreditFailedChecks = @((Get-ArchitectureProp -Object $bridgeRuntimeCreditValidation -Name "failedChecks" -Default @()))
$bridgeRuntimeCreditMissingRuntimeChecks = @((Get-ArchitectureProp -Object $bridgeRuntimeCreditValidation -Name "missingRuntimeChecks" -Default @()))
$bridgeRuntimeCreditFalseRuntimeChecks = @((Get-ArchitectureProp -Object $bridgeRuntimeCreditValidation -Name "falseRuntimeChecks" -Default @()))
$bridgeRuntimeCreditProofFailedChecks = @((Get-ArchitectureProp -Object $bridgeRuntimeCreditValidation -Name "proofFailedChecks" -Default @()))
$bridgeRuntimeCreditReady = ($bridgeRuntimeCreditStatus -eq "passed") `
    -and ($bridgeRuntimeCreditFailedChecks.Count -eq 0) `
    -and ($bridgeRuntimeCreditMissingRuntimeChecks.Count -eq 0) `
    -and ($bridgeRuntimeCreditFalseRuntimeChecks.Count -eq 0) `
    -and ($bridgeRuntimeCreditProofFailedChecks.Count -eq 0) `
    -and ((Get-ArchitectureProp -Object $bridgeRuntimeCreditChecks -Name "sourceChainBase8453" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRuntimeCreditChecks -Name "creditAppliedOnce" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRuntimeCreditChecks -Name "creditedBalanceTransferable" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRuntimeCreditChecks -Name "replayRejected" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRuntimeCreditChecks -Name "restartPreservesCreditHistory" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRuntimeCreditChecks -Name "exportImportPreservesReplayProtection" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRuntimeCreditChecks -Name "latencyGatePassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRuntimeCreditChecks -Name "transferLatencyUnderTarget" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRuntimeCreditChecks -Name "handoffNoReleaseBroadcast" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRuntimeCreditChecks -Name "handoffNoWithdrawalBroadcast" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRuntimeCreditValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $bridgeRuntimeCreditValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRuntimeCreditValidation -Name "broadcasts" -Default $true) -eq $false) `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:bridge:runtime-credit:validate")
$bridgeRelayerChecks = Get-ArchitectureProp -Object $bridgeRelayer -Name "checks"
$bridgeRelayerFailedChecks = @((Get-ArchitectureProp -Object $bridgeRelayer -Name "failedChecks" -Default @()))
$bridgeRelayerCheckContractReady = ($bridgeRelayerFailedChecks.Count -eq 0) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "statusKnown" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "requiredEnvNamesPresent" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "childTimeoutRecorded" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "childProcessesDidNotTimeout" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "broadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "envValuesPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "readinessInfraChecked" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "readinessLiveCheckedWhenInfraPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "blockedBeforeLiveReadinessWhenInfraBlocked" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "blockedBeforeObservationWhenReadinessBlocked" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "noQueuedTransactionsWhenBlocked" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "noAppliedCreditsWhenBlocked" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "cursorModeStaged" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "finalCursorNotCommittedWhenBlocked" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "finalCursorPathInsideRepo" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "stagedCursorPathInsideRepo" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "issuesClassified" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "externalBlockerClassifiedWhenBlocked" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "latencyGateRecorded" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "latencyGatePassedWhenApplied" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "queueAndApplyMatchWhenPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayerChecks -Name "cursorSafeWhenPassed" -Default $false) -eq $true)
$bridgeRelayerCounts = Get-ArchitectureProp -Object $bridgeRelayer -Name "counts"
$bridgeRelayerCursorCommit = Get-ArchitectureProp -Object $bridgeRelayer -Name "cursorCommit"
$bridgeRelayerSteps = @((Get-ArchitectureProp -Object $bridgeRelayer -Name "steps" -Default @()))
$bridgeRelayerTimedOutSteps = @($bridgeRelayerSteps | Where-Object { (Get-ArchitectureProp -Object $_ -Name "timedOut" -Default $false) -eq $true })
$bridgeRelayerChildTimeoutSeconds = [int](Get-ArchitectureProp -Object $bridgeRelayer -Name "childTimeoutSeconds" -Default 0)
$bridgeRelayerChildTimeoutReady = ($bridgeRelayerChildTimeoutSeconds -ge 1) -and ($bridgeRelayerTimedOutSteps.Count -eq 0)
$bridgeRelayerNewCount = [int](Get-ArchitectureProp -Object $bridgeRelayerCounts -Name "newCredits" -Default 0)
$bridgeRelayerQueuedCount = [int](Get-ArchitectureProp -Object $bridgeRelayerCounts -Name "queuedTransactions" -Default 0)
$bridgeRelayerAppliedCount = [int](Get-ArchitectureProp -Object $bridgeRelayerCounts -Name "appliedCredits" -Default 0)
$bridgeRelayerQueueDisabled = Get-ArchitectureProp -Object $bridgeRelayer -Name "queueDisabled" -Default $true
$bridgeRelayerCursorCommitRequired = Get-ArchitectureProp -Object $bridgeRelayerCursorCommit -Name "finalCommitRequired" -Default $true
$bridgeRelayerCursorCommitted = Get-ArchitectureProp -Object $bridgeRelayerCursorCommit -Name "finalCommitted" -Default $false
$bridgeRelayerCursorReason = Get-ArchitectureProp -Object $bridgeRelayerCursorCommit -Name "reason" -Default "missing"
$bridgeRelayerQueueReady = ($bridgeRelayerNewCount -eq 0) -or (($bridgeRelayerQueueDisabled -eq $false) -and ($bridgeRelayerQueuedCount -ge $bridgeRelayerNewCount) -and ($bridgeRelayerAppliedCount -eq $bridgeRelayerNewCount))
$bridgeRelayerCursorReady = ($bridgeRelayerStatus -ne "passed") -or ($bridgeRelayerCursorCommitted -eq $true) -or ($bridgeRelayerCursorCommitRequired -eq $false)
$bridgeRelayerReady = (Test-AllRepoFilesExist -Paths $bridgeLiveFiles) `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:bridge:relayer:once") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:bridge:relayer:guardrail:validate") `
    -and ($bridgeRelayerStatus -eq "passed") `
    -and $bridgeRelayerCheckContractReady `
    -and ((Get-ArchitectureProp -Object $bridgeRelayer -Name "broadcasts" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayer -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $bridgeRelayer -Name "noSecrets" -Default $false) -eq $true) `
    -and $bridgeRelayerChildTimeoutReady `
    -and $bridgeRelayerQueueReady `
    -and $bridgeRelayerCursorReady `
    -and $bridgeRelayerGuardrailReady `
    -and $bridgeRelayerLoopReady `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:bridge:relayer:loop:validate")
$bridgeRelayerBlockedSafely = ($bridgeRelayerStatus -eq "blocked") -and $bridgeRelayerCheckContractReady -and $bridgeRelayerGuardrailReady -and $bridgeRelayerLoopReady -and $bridgeRelayerChildTimeoutReady
Add-ArchitectureItem -Items $items -Id "bridge-relayer-runtime-queue" -Layer "Bridge" `
    -Requirement "The live bridge relayer path checks owner guardrails, bounds child process execution, validates the isolated relayer loop start/stop path plus fresh no-secret/no-broadcast loop health, observes Base 8453 deposits with a staged cursor, builds runtime handoff, filters already-seen replay keys, queues new credits into the running L1, waits for main-state credit evidence, commits the Base cursor only after safe proof without broadcasts, and proves missing-owner-input runs leave cursor state untouched." `
    -Status $(if ($bridgeRelayerReady) { "passed" } elseif ($bridgeRelayerBlockedSafely) { "blocked" } else { "failed" }) `
    -Evidence "relayer=$bridgeRelayerStatus, onceChecksReady=$bridgeRelayerCheckContractReady, onceFailedChecks=$($bridgeRelayerFailedChecks.Count), childTimeoutSeconds=$bridgeRelayerChildTimeoutSeconds, timedOutSteps=$($bridgeRelayerTimedOutSteps.Count), guardrail=$bridgeRelayerGuardrailStatus, guardrailChildTimeoutRecorded=$(Get-ArchitectureProp -Object $bridgeRelayerGuardrailChecks -Name 'relayerChildTimeoutRecorded' -Default $false), guardrailNoChildTimeouts=$(Get-ArchitectureProp -Object $bridgeRelayerGuardrailChecks -Name 'relayerNoChildTimeouts' -Default $false), loopValidation=$bridgeRelayerLoopStatus, loopFailedChecks=$($bridgeRelayerLoopFailedChecks.Count), loopReportHealthy=$(Get-ArchitectureProp -Object $bridgeRelayerLoopChecks -Name 'statusRelayerReportHealthy' -Default $false), observed=$(Get-ArchitectureProp -Object $bridgeRelayerCounts -Name 'observedCredits' -Default 0), new=$bridgeRelayerNewCount, queued=$bridgeRelayerQueuedCount, applied=$bridgeRelayerAppliedCount, cursorCommitRequired=$bridgeRelayerCursorCommitRequired, cursorCommitted=$bridgeRelayerCursorCommitted, cursorReason=$bridgeRelayerCursorReason" `
    -Files $bridgeLiveFiles `
    -Commands @("npm run flowchain:bridge:relayer:once", "npm run flowchain:bridge:relayer:guardrail:validate", "npm run flowchain:bridge:relayer:loop:validate", "npm run flowchain:service:restart -- -LiveProfile -StartBridgeRelayerLoop") `
    -Blockers @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_BASE8453_ASSET_DECIMALS", "FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS")

Add-ArchitectureItem -Items $items -Id "bridge-runtime-credit-proof" -Layer "Bridge" `
    -Requirement "The bridge runtime has a local production-shaped proof that a Base 8453 handoff becomes spendable on L1 within the settlement target, can be transferred by the credited wallet, rejects replay, and survives restart/export/import without broadcasts." `
    -Status $(if ($bridgeRuntimeCreditReady) { "passed" } else { "failed" }) `
    -Evidence "runtimeCredit=$bridgeRuntimeCreditStatus, failedChecks=$($bridgeRuntimeCreditFailedChecks.Count), missingRuntimeChecks=$($bridgeRuntimeCreditMissingRuntimeChecks.Count), falseRuntimeChecks=$($bridgeRuntimeCreditFalseRuntimeChecks.Count), latencyGate=$(Get-ArchitectureProp -Object $bridgeRuntimeCreditTiming -Name 'latencyGate' -Default 'missing'), queueToSpendableSeconds=$(Get-ArchitectureProp -Object $bridgeRuntimeCreditTiming -Name 'queueToSpendableSeconds' -Default ''), transferSeconds=$(Get-ArchitectureProp -Object $bridgeRuntimeCreditTiming -Name 'transferSettlementSeconds' -Default '')" `
    -Files @("infra/scripts/flowchain-bridge-runtime-credit-validation.ps1", "infra/scripts/flowchain-real-value-pilot-runtime.ps1", "docs/agent-runs/live-product-infra-rpc/bridge-runtime-credit-validation-report.json", "docs/agent-runs/live-product-infra-rpc/BRIDGE_RUNTIME_CREDIT_VALIDATION.md") `
    -Commands @("npm run flowchain:bridge:runtime-credit:validate")

$backupStatus = Get-ArchitectureStatus -Report $reports.backupReadiness
$backupValidation = $reports.backupRestoreValidation
$backupValidationStatus = Get-ArchitectureStatus -Report $backupValidation
$backupValidationChecks = Get-ArchitectureProp -Object $backupValidation -Name "checks"
$backupValidationRequiredChecks = @(
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
$backupValidationMissingChecks = @($backupValidationRequiredChecks | Where-Object {
    (Get-ArchitectureProp -Object $backupValidationChecks -Name $_ -Default $false) -ne $true
})
$backupValidationPassed = $backupValidationStatus -eq "passed" `
    -and ($backupValidationMissingChecks.Count -eq 0) `
    -and ((Get-ArchitectureProp -Object $backupValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $backupValidation -Name "noSecrets" -Default $false) -eq $true)
$backupOwnerPathDryRun = $reports.backupOwnerPathDryRun
$backupOwnerPathDryRunStatus = Get-ArchitectureStatus -Report $backupOwnerPathDryRun
$backupOwnerPathDryRunChecks = Get-ArchitectureProp -Object $backupOwnerPathDryRun -Name "checks"
$backupOwnerPathDryRunFailedChecks = @((Get-ArchitectureProp -Object $backupOwnerPathDryRun -Name "failedChecks" -Default @()))
$backupOwnerPathDryRunReady = ($backupOwnerPathDryRunStatus -eq "passed") `
    -and ($backupOwnerPathDryRunFailedChecks.Count -eq 0) `
    -and ((Get-ArchitectureProp -Object $backupOwnerPathDryRunChecks -Name "readinessStatusPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupOwnerPathDryRunChecks -Name "snapshotProofPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupOwnerPathDryRunChecks -Name "restoreProofPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupOwnerPathDryRunChecks -Name "retentionCurrentSnapshotProtected" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupOwnerPathDryRunChecks -Name "retentionPruneErrorsEmpty" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupOwnerPathDryRunChecks -Name "backupRetentionProtectedSnapshot" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupOwnerPathDryRunChecks -Name "restoreLiveStateProtected" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupOwnerPathDryRunChecks -Name "restoreDidNotMutateLiveState" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupOwnerPathDryRunChecks -Name "ownerBackupEnvRestored" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupOwnerPathDryRun -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $backupOwnerPathDryRun -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupOwnerPathDryRun -Name "broadcasts" -Default $true) -eq $false) `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:backup:owner-path:dry-run")
$backupDetails = Get-ArchitectureProp -Object $reports.backupReadiness -Name "backup"
$backupSnapshotProof = Get-ArchitectureProp -Object $backupDetails -Name "snapshotProofStatus" -Default "not-run"
$backupRestoreProof = Get-ArchitectureProp -Object $backupDetails -Name "restoreProofStatus" -Default "not-run"
$backupInstallValidation = $reports.backupInstallValidation
$backupInstallValidationStatus = Get-ArchitectureStatus -Report $backupInstallValidation
$backupInstallChecks = Get-ArchitectureProp -Object $backupInstallValidation -Name "checks"
$backupInstallFailedChecks = @((Get-ArchitectureProp -Object $backupInstallValidation -Name "failedChecks" -Default @()))
$backupInstallReady = ($backupInstallValidationStatus -eq "passed") `
    -and ($backupInstallFailedChecks.Count -eq 0) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "packageScriptsPresent" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "planCommandPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "planDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "schedulerCmdletsAvailable" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "scheduledTaskActionSupportsWorkingDirectory" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "taskNamesDistinct" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "retentionCountValid" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "actionUsesBackupScript" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "actionUsesRetentionCount" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "restoreDrillUsesRestoreScript" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "restoreDrillHasRestoreRoot" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "restoreDrillHasStatePath" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "restoreDrillHasReportPath" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "ownerBackupEnvRequired" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "restoreDrillOwnerBackupEnvRequired" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "commandOmitsAllowBlocked" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "systemdValidationPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "systemdPlanDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "systemdBackupServiceUnitPlanned" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "systemdBackupTimerUnitPlanned" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "systemdRestoreServiceUnitPlanned" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "systemdRestoreTimerUnitPlanned" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "systemdCommandOmitsAllowBlocked" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "systemdOwnerBackupEnvRequired" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "systemdBackupRootWritePathConfigurable" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallChecks -Name "systemdChildReportNoSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupInstallValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $backupInstallValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:backup:install:systemd") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:backup:install:systemd:validate")
$backupFiles = @(
    "infra/scripts/flowchain-public-rpc-backup-readiness.ps1",
    "infra/scripts/flowchain-state-backup.ps1",
    "infra/scripts/flowchain-state-restore-verify.ps1",
    "infra/scripts/flowchain-backup-restore-validation.ps1",
    "infra/scripts/flowchain-backup-owner-path-dry-run.ps1",
    "infra/scripts/flowchain-backup-install-windows.ps1",
    "infra/scripts/flowchain-backup-install-systemd.ps1",
    "infra/scripts/flowchain-backup-install-systemd-validation.ps1",
    "infra/scripts/flowchain-backup-install-validation.ps1",
    "docs/agent-runs/live-product-infra-rpc/WINDOWS_BACKUP_INSTALL.md",
    "docs/agent-runs/live-product-infra-rpc/SYSTEMD_BACKUP_INSTALL.md",
    "docs/agent-runs/live-product-infra-rpc/SYSTEMD_BACKUP_INSTALL_VALIDATION.md",
    "docs/agent-runs/live-product-infra-rpc/BACKUP_INSTALL_VALIDATION.md"
)
Add-ArchitectureItem -Items $items -Id "state-backup-boundary" -Layer "Storage/recovery" `
    -Requirement "Live state backup and restore are separate configured storage boundaries with manifest hash proof, latest-pointer proof, owner-path dry-run proof, Windows and Linux scheduled backup plus restore-drill install proof, retention rotation, live-state protection, and adversarial tamper/missing-artifact/wrong-chain rejection before public operation." `
    -Status $(if ($backupStatus -eq "passed" -and $backupValidationPassed -and $backupOwnerPathDryRunReady -and $backupInstallReady) { "passed" } elseif ($backupStatus -eq "blocked" -and $backupValidationPassed -and $backupOwnerPathDryRunReady -and $backupInstallReady) { "blocked" } else { "failed" }) `
    -Evidence "backupStatus=$backupStatus, validationStatus=$backupValidationStatus, ownerPathDryRun=$backupOwnerPathDryRunStatus, ownerPathFailedChecks=$($backupOwnerPathDryRunFailedChecks.Count), installValidation=$backupInstallValidationStatus, installFailedChecks=$($backupInstallFailedChecks.Count), systemdValidation=$(Get-ArchitectureProp -Object $backupInstallChecks -Name "systemdValidationPassed"), systemdTimer=$(Get-ArchitectureProp -Object $backupInstallChecks -Name "systemdBackupTimerUnitPlanned"), snapshotProof=$backupSnapshotProof, restoreProof=$backupRestoreProof, requiredChecks=$($backupValidationRequiredChecks.Count), missingChecks=$($backupValidationMissingChecks.Count)" `
    -Files $backupFiles `
    -Commands @("npm run flowchain:backup:create", "npm run flowchain:backup:restore:verify", "npm run flowchain:backup:restore:validate", "npm run flowchain:backup:owner-path:dry-run", "npm run flowchain:backup:install:validate", "npm run flowchain:backup:install:windows -- -Action Plan", "npm run flowchain:backup:install:systemd -- -Action Plan", "npm run flowchain:backup:install:systemd:validate", "npm run flowchain:backup:check") `
    -Blockers @("FLOWCHAIN_RPC_STATE_BACKUP_PATH")

$deploymentContract = $reports.publicDeploymentContract
$deploymentContractStatus = Get-ArchitectureStatus -Report $deploymentContract
$deploymentContractCounts = Get-ArchitectureProp -Object $deploymentContract -Name "itemCounts"
$deploymentContractFailed = [int](Get-ArchitectureProp -Object $deploymentContractCounts -Name "failed" -Default 1)
$deploymentContractBlocked = [int](Get-ArchitectureProp -Object $deploymentContractCounts -Name "blocked" -Default 0)
$deploymentContractBlockedOnlyKnown = Get-ArchitectureProp -Object $deploymentContract -Name "blockedOnlyOnKnownExternalOwnerInputs" -Default $false
$deploymentContractReady = (Get-ArchitectureProp -Object $deploymentContract -Name "deploymentReady" -Default $false) -eq $true
$deploymentContractPacketShareable = Get-ArchitectureProp -Object $deploymentContract -Name "packetShareable" -Default $false
$deploymentContractPacketSmoke = Get-ArchitectureProp -Object $deploymentContract -Name "packetExecutableSmokeValidated" -Default $false
$deploymentContractSafe = ($deploymentContractStatus -in @("passed", "blocked")) `
    -and ($deploymentContractFailed -eq 0) `
    -and ($deploymentContractBlockedOnlyKnown -eq $true) `
    -and ($deploymentContractPacketSmoke -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentContract -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentContract -Name "noLiveBroadcast" -Default $false) -eq $true)
Add-ArchitectureItem -Items $items -Id "public-deployment-contract-boundary" -Layer "Deployment" `
    -Requirement "The owner-operated public deployment contract is machine-checkable, includes rollback commands, and blocks sharing until public RPC, backup, bridge, and tester gates pass." `
    -Status $(if ($deploymentContractStatus -eq "passed" -and $deploymentContractReady -eq $true -and $deploymentContractSafe) { "passed" } elseif ($deploymentContractStatus -eq "blocked" -and $deploymentContractSafe) { "blocked" } else { "failed" }) `
    -Evidence "deploymentStatus=$deploymentContractStatus, deploymentReady=$deploymentContractReady, packetShareable=$deploymentContractPacketShareable, packetSmoke=$deploymentContractPacketSmoke, blockedOnlyKnown=$deploymentContractBlockedOnlyKnown, blockedItems=$deploymentContractBlocked, failedItems=$deploymentContractFailed" `
    -Files @("infra/scripts/flowchain-public-deployment-contract.ps1", "docs/OPERATIONS/FLOWCHAIN_OWNER_OPERATED_PUBLIC_RPC.md") `
    -Commands @("npm run flowchain:public-deployment:contract -- -AllowBlocked") `
    -Blockers @($missingOwnerInputs)

$ownerGoLiveHandoff = $reports.ownerGoLiveHandoff
$ownerGoLiveHandoffStatus = Get-ArchitectureStatus -Report $ownerGoLiveHandoff
$ownerGoLiveHandoffChecks = Get-ArchitectureProp -Object $ownerGoLiveHandoff -Name "checks"
$ownerGoLiveHandoffFailedChecks = @((Get-ArchitectureProp -Object $ownerGoLiveHandoff -Name "failedChecks" -Default @()))
$ownerGoLiveHandoffSecretFindings = @((Get-ArchitectureProp -Object $ownerGoLiveHandoff -Name "secretMarkerFindings" -Default @()))
$ownerGoLiveHandoffStageCount = [int](Get-ArchitectureProp -Object $ownerGoLiveHandoff -Name "stageCount" -Default 0)
$ownerGoLiveHandoffLaunchSequenceCount = [int](Get-ArchitectureProp -Object $ownerGoLiveHandoff -Name "launchSequenceCount" -Default 0)
$ownerGoLiveHandoffLaunchSequenceCommandCount = [int](Get-ArchitectureProp -Object $ownerGoLiveHandoff -Name "launchSequenceCommandCount" -Default 0)
$ownerGoLiveHandoffExpectedReportPathCount = [int](Get-ArchitectureProp -Object $ownerGoLiveHandoff -Name "launchSequenceExpectedReportPathCount" -Default 0)
$ownerGoLiveHandoffInvalidExpectedReportPaths = @((Get-ArchitectureProp -Object $ownerGoLiveHandoff -Name "invalidLaunchSequenceExpectedReportPaths" -Default @()))
$ownerGoLiveHandoffMissingRequiredInputs = @((Get-ArchitectureProp -Object $ownerGoLiveHandoff -Name "missingRequiredEnvNames" -Default @()))
$ownerGoLiveHandoffMissingOptionalInputs = @((Get-ArchitectureProp -Object $ownerGoLiveHandoff -Name "missingOptionalEnvNames" -Default @()))
$ownerGoLiveHandoffNextOptionalInputs = @((Get-ArchitectureProp -Object $ownerGoLiveHandoff -Name "nextOwnerOptionalInputNames" -Default @()))
$ownerGoLiveHandoffMissingLaunchPackageScripts = @((Get-ArchitectureProp -Object $ownerGoLiveHandoff -Name "missingLaunchSequencePackageScriptNames" -Default @()))
$ownerGoLiveHandoffRollbackCommandCount = [int](Get-ArchitectureProp -Object $ownerGoLiveHandoff -Name "rollbackCommandCount" -Default 0)
$ownerGoLiveHandoffMissingRollbackPackageScripts = @((Get-ArchitectureProp -Object $ownerGoLiveHandoff -Name "missingRollbackPackageScriptNames" -Default @()))
$ownerGoLiveHandoffSafe = $ownerGoLiveHandoffStatus -eq "passed" `
    -and $ownerGoLiveHandoffFailedChecks.Count -eq 0 `
    -and $ownerGoLiveHandoffSecretFindings.Count -eq 0 `
    -and $ownerGoLiveHandoffStageCount -ge 8 `
    -and $ownerGoLiveHandoffLaunchSequenceCount -ge 8 `
    -and $ownerGoLiveHandoffLaunchSequenceCommandCount -ge 20 `
    -and $ownerGoLiveHandoffExpectedReportPathCount -ge 8 `
    -and $ownerGoLiveHandoffInvalidExpectedReportPaths.Count -eq 0 `
    -and $ownerGoLiveHandoffRollbackCommandCount -ge 4 `
    -and ((Get-ArchitectureProp -Object $ownerGoLiveHandoffChecks -Name "launchSequencePresent" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerGoLiveHandoffChecks -Name "launchSequenceEveryStepHasExpectedReportPath" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerGoLiveHandoffChecks -Name "launchSequenceExpectedReportPathsScoped" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerGoLiveHandoffChecks -Name "launchSequenceCoversPublicRpcRender" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerGoLiveHandoffChecks -Name "launchSequenceCoversSystemdInstallPlan" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerGoLiveHandoffChecks -Name "launchSequenceCoversBackupRestore" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerGoLiveHandoffChecks -Name "launchSequenceCoversBridgeRelayer" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerGoLiveHandoffChecks -Name "launchSequenceCoversTesterPacket" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerGoLiveHandoffChecks -Name "launchSequenceCoversCutoverAudit" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerGoLiveHandoffChecks -Name "launchSequencePackageScriptsPresent" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerGoLiveHandoffChecks -Name "requiredAndOptionalOwnerInputsSeparated" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerGoLiveHandoffChecks -Name "neededNowExcludesOptionalOwnerInputs" -Default $false) -eq $true) `
    -and $ownerGoLiveHandoffNextOptionalInputs.Count -eq 0 `
    -and ((Get-ArchitectureProp -Object $ownerGoLiveHandoffChecks -Name "rollbackCommandsPresent" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerGoLiveHandoffChecks -Name "rollbackCoversLocalStop" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerGoLiveHandoffChecks -Name "rollbackCoversBridgeEmergencyStop" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerGoLiveHandoffChecks -Name "rollbackPackageScriptsPresent" -Default $false) -eq $true) `
    -and $ownerGoLiveHandoffMissingLaunchPackageScripts.Count -eq 0 `
    -and $ownerGoLiveHandoffMissingRollbackPackageScripts.Count -eq 0 `
    -and ((Get-ArchitectureProp -Object $ownerGoLiveHandoff -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $ownerGoLiveHandoff -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerGoLiveHandoff -Name "broadcasts" -Default $true) -eq $false)
Add-ArchitectureItem -Items $items -Id "owner-go-live-launch-boundary" -Layer "Deployment/governance" `
    -Requirement "Owner go-live handoff sequences owner inputs, public RPC render, service install, live monitoring, public RPC canaries, backup restore proof, bridge relayer pilot, external testers, final audits, and rollback commands as one no-secret launch-control boundary." `
    -Status $(if ($ownerGoLiveHandoffSafe) { "passed" } else { "failed" }) `
    -Evidence "handoffStatus=$ownerGoLiveHandoffStatus, stages=$ownerGoLiveHandoffStageCount, launchSteps=$ownerGoLiveHandoffLaunchSequenceCount, launchCommands=$ownerGoLiveHandoffLaunchSequenceCommandCount, evidenceReports=$ownerGoLiveHandoffExpectedReportPathCount, invalidEvidenceReports=$($ownerGoLiveHandoffInvalidExpectedReportPaths.Count), missingRequiredInputs=$($ownerGoLiveHandoffMissingRequiredInputs.Count), missingOptionalInputs=$($ownerGoLiveHandoffMissingOptionalInputs.Count), neededNowOptionalInputs=$($ownerGoLiveHandoffNextOptionalInputs.Count), missingLaunchScripts=$($ownerGoLiveHandoffMissingLaunchPackageScripts.Count), rollbackCommands=$ownerGoLiveHandoffRollbackCommandCount, missingRollbackScripts=$($ownerGoLiveHandoffMissingRollbackPackageScripts.Count), failedChecks=$($ownerGoLiveHandoffFailedChecks.Count), secretFindings=$($ownerGoLiveHandoffSecretFindings.Count)" `
    -Files @("infra/scripts/flowchain-owner-go-live-handoff.ps1", "docs/agent-runs/live-product-infra-rpc/OWNER_GO_LIVE_HANDOFF.md") `
    -Commands @("npm run flowchain:owner:go-live-handoff") `
    -Blockers @($missingOwnerInputs)

$ownerInputs = $reports.ownerInputs
$ownerInputsValidation = $reports.ownerInputsValidation
$ownerInputFiles = @(
    "infra/scripts/flowchain-owner-inputs.ps1",
    "infra/scripts/flowchain-owner-inputs-validation.ps1"
)
$ownerInputsStatus = Get-ArchitectureStatus -Report $ownerInputs
$ownerValidationStatus = Get-ArchitectureStatus -Report $ownerInputsValidation
$ownerChecks = Get-ArchitectureProp -Object $ownerInputsValidation -Name "checks"
$ownerValidationEnvFilePasses = (Get-ArchitectureProp -Object $ownerChecks -Name "validOwnerEnvFileScenarioPasses" -Default $false) -eq $true
$ownerValidationMissingEnvFileFails = (Get-ArchitectureProp -Object $ownerChecks -Name "missingOwnerEnvFileScenarioFails" -Default $false) -eq $true
$ownerValidationMalformedEnvFileFails = (Get-ArchitectureProp -Object $ownerChecks -Name "malformedOwnerEnvFileScenarioFails" -Default $false) -eq $true
$ownerInputBoundaryReady = (Test-AllRepoFilesExist -Paths $ownerInputFiles) `
    -and ($ownerValidationStatus -eq "passed") `
    -and ((Get-ArchitectureProp -Object $ownerChecks -Name "missingScenarioBlocks" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerChecks -Name "invalidScenarioFails" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerChecks -Name "validStructureScenarioPasses" -Default $false) -eq $true) `
    -and ($ownerValidationEnvFilePasses -eq $true) `
    -and ($ownerValidationMissingEnvFileFails -eq $true) `
    -and ($ownerValidationMalformedEnvFileFails -eq $true) `
    -and ($unknownOwnerInputs.Count -eq 0)
Add-ArchitectureItem -Items $items -Id "owner-input-fail-closed-boundary" -Layer "Governance/safety" `
    -Requirement "Live-only inputs are externally owned, listed by name only, self-tested for missing/invalid/valid direct env plus local owner env-file loading, and fail closed on missing or malformed owner env files without printing values." `
    -Status $(if ($ownerInputBoundaryReady -and $ownerInputsStatus -in @("passed", "blocked")) { "passed" } else { "failed" }) `
    -Evidence "ownerInputsStatus=$ownerInputsStatus, validationStatus=$ownerValidationStatus, ownerEnvFilePasses=$ownerValidationEnvFilePasses, missingOwnerEnvFileFails=$ownerValidationMissingEnvFileFails, malformedOwnerEnvFileFails=$ownerValidationMalformedEnvFileFails, knownMissingInputs=$($missingOwnerInputs.Count), unknownInputs=$($unknownOwnerInputs.Count)" `
    -Files $ownerInputFiles `
    -Commands @("npm run flowchain:owner-inputs:validate", "npm run flowchain:owner-inputs") `
    -Blockers @($missingOwnerInputs)

$ownerEnvReadiness = $reports.ownerEnvReadiness
$ownerEnvReadinessValidation = $reports.ownerEnvReadinessValidation
$ownerEnvReadinessStatus = Get-ArchitectureStatus -Report $ownerEnvReadiness
$ownerEnvReadinessState = Get-ArchitectureProp -Object $ownerEnvReadiness -Name "readiness"
$ownerEnvReadinessPath = Get-ArchitectureProp -Object $ownerEnvReadiness -Name "ownerEnvFile"
$ownerEnvReadinessBlockedOnlyKnown = Get-ArchitectureProp -Object $ownerEnvReadinessState -Name "blockedOnlyOnKnownExternalOwnerInputs" -Default $false
$ownerEnvReadinessGitIgnored = Get-ArchitectureProp -Object $ownerEnvReadinessPath -Name "gitIgnored" -Default $false
$ownerEnvReadinessValidationStatus = Get-ArchitectureStatus -Report $ownerEnvReadinessValidation
$ownerEnvReadinessValidationChecks = Get-ArchitectureProp -Object $ownerEnvReadinessValidation -Name "checks"
$ownerEnvReadinessValidationMissingFails = Get-ArchitectureProp -Object $ownerEnvReadinessValidationChecks -Name "missingOwnerEnvFileFailsBeforeChildGates" -Default $false
$ownerEnvReadinessValidationUnignoredFails = Get-ArchitectureProp -Object $ownerEnvReadinessValidationChecks -Name "unignoredOwnerEnvFileFailsBeforeChildGates" -Default $false
$ownerEnvReadinessSafe = (Test-RepoFile -Path "infra/scripts/flowchain-owner-env-readiness.ps1") `
    -and (Test-RepoFile -Path "infra/scripts/flowchain-owner-env-readiness-validation.ps1") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:owner-env:readiness") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:owner-env:readiness:validate") `
    -and ($ownerEnvReadinessValidationStatus -eq "passed") `
    -and ($ownerEnvReadinessValidationMissingFails -eq $true) `
    -and ($ownerEnvReadinessValidationUnignoredFails -eq $true) `
    -and ($ownerEnvReadinessGitIgnored -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerEnvReadiness -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $ownerEnvReadiness -Name "noSecrets" -Default $false) -eq $true) `
    -and ($ownerEnvReadinessStatus -eq "passed" -or ($ownerEnvReadinessStatus -eq "blocked" -and $ownerEnvReadinessBlockedOnlyKnown -eq $true))
Add-ArchitectureItem -Items $items -Id "owner-env-readiness-boundary" -Layer "Governance/safety" `
    -Requirement "The ignored owner env file is a first-class setup boundary that can drive owner-input, live-infra, and public deployment gates through one redacted command." `
    -Status $(if ($ownerEnvReadinessStatus -eq "passed" -and $ownerEnvReadinessSafe) { "passed" } elseif ($ownerEnvReadinessStatus -eq "blocked" -and $ownerEnvReadinessSafe) { "blocked" } else { "failed" }) `
    -Evidence "readinessStatus=$ownerEnvReadinessStatus, validationStatus=$ownerEnvReadinessValidationStatus, missingFails=$ownerEnvReadinessValidationMissingFails, unignoredFails=$ownerEnvReadinessValidationUnignoredFails, gitIgnored=$ownerEnvReadinessGitIgnored, blockedOnlyKnown=$ownerEnvReadinessBlockedOnlyKnown" `
    -Files @("infra/scripts/flowchain-owner-env-readiness.ps1", "infra/scripts/flowchain-owner-env-readiness-validation.ps1", "docs/agent-runs/live-product-infra-rpc/OWNER_ENV_READINESS.md") `
    -Commands @("npm run flowchain:owner-env:readiness:validate", "npm run flowchain:owner-env:readiness -- -AllowBlocked") `
    -Blockers @($missingOwnerInputs)

$ownerOnboarding = $reports.ownerOnboarding
$ownerOnboardingStatus = Get-ArchitectureStatus -Report $ownerOnboarding
$flowChainRpcIsOurs = Get-ArchitectureProp -Object $ownerOnboarding -Name "flowChainRpcIsOurs" -Default $false
$thirdPartyFlowChainRpcProviderNeeded = Get-ArchitectureProp -Object $ownerOnboarding -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$publicRpcRequiresOwnerPublicEdge = Get-ArchitectureProp -Object $ownerOnboarding -Name "publicRpcRequiresOwnerPublicEdge" -Default $false
$base8453RpcIsExternalChainDependency = Get-ArchitectureProp -Object $ownerOnboarding -Name "base8453RpcIsExternalChainDependency" -Default $false
$ownerOnboardingLocalEnvFileSupported = Get-ArchitectureProp -Object $ownerOnboarding -Name "localEnvFileSupported" -Default $false
$ownerOnboardingReady = (Test-RepoFile -Path "infra/scripts/flowchain-owner-onboarding.ps1") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:owner:onboarding") `
    -and ($ownerOnboardingStatus -eq "passed") `
    -and ($flowChainRpcIsOurs -eq $true) `
    -and ($thirdPartyFlowChainRpcProviderNeeded -eq $false) `
    -and ($publicRpcRequiresOwnerPublicEdge -eq $true) `
    -and ($base8453RpcIsExternalChainDependency -eq $true) `
    -and ($ownerOnboardingLocalEnvFileSupported -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerOnboarding -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $ownerOnboarding -Name "noSecrets" -Default $false) -eq $true)
Add-ArchitectureItem -Items $items -Id "owner-onboarding-boundary" -Layer "Governance/safety" `
    -Requirement "Owner onboarding distinguishes repo-owned FlowChain RPC from the external Base 8453 RPC dependency and gives no-values setup commands." `
    -Status $(if ($ownerOnboardingReady) { "passed" } else { "failed" }) `
    -Evidence "onboardingStatus=$ownerOnboardingStatus, flowChainRpcIsOurs=$flowChainRpcIsOurs, thirdPartyFlowChainRpcProviderNeeded=$thirdPartyFlowChainRpcProviderNeeded, publicRpcRequiresOwnerPublicEdge=$publicRpcRequiresOwnerPublicEdge, base8453RpcIsExternalChainDependency=$base8453RpcIsExternalChainDependency, localEnvFileSupported=$ownerOnboardingLocalEnvFileSupported" `
    -Files @("infra/scripts/flowchain-owner-onboarding.ps1", "docs/agent-runs/live-product-infra-rpc/OWNER_ONBOARDING.md") `
    -Commands @("npm run flowchain:owner:onboarding")

$ownerSignupChecklist = $reports.ownerSignupChecklist
$ownerSignupChecklistStatus = Get-ArchitectureStatus -Report $ownerSignupChecklist
$ownerSignupExternalCount = [int](Get-ArchitectureProp -Object $ownerSignupChecklist -Name "externalSignupCount" -Default 0)
$ownerSignupItemCount = [int](Get-ArchitectureProp -Object $ownerSignupChecklist -Name "itemCount" -Default 0)
$ownerSignupMissingCoverageCount = @((Get-ArchitectureProp -Object $ownerSignupChecklist -Name "missingChecklistCoverage" -Default @())).Count
$ownerSignupRepoOwned = Get-ArchitectureProp -Object $ownerSignupChecklist -Name "flowChainRpcIsRepoOwned" -Default $false
$ownerSignupThirdPartyFlowChainRpcNeeded = Get-ArchitectureProp -Object $ownerSignupChecklist -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$ownerSignupLocalEnvFileSupported = Get-ArchitectureProp -Object $ownerSignupChecklist -Name "localEnvFileSupported" -Default $false
$ownerSignupChecklistReady = (Test-RepoFile -Path "infra/scripts/flowchain-owner-signup-checklist.ps1") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:owner:signup-checklist") `
    -and ($ownerSignupChecklistStatus -eq "passed") `
    -and ($ownerSignupItemCount -ge 8) `
    -and ($ownerSignupExternalCount -ge 3) `
    -and ($ownerSignupMissingCoverageCount -eq 0) `
    -and ($ownerSignupRepoOwned -eq $true) `
    -and ($ownerSignupThirdPartyFlowChainRpcNeeded -eq $false) `
    -and ($ownerSignupLocalEnvFileSupported -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerSignupChecklist -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $ownerSignupChecklist -Name "noSecrets" -Default $false) -eq $true)
Add-ArchitectureItem -Items $items -Id "owner-signup-checklist-boundary" -Layer "Governance/safety" `
    -Requirement "Owner signup checklist maps public RPC edge, tester write token/cap, always-on host, backup storage, Base 8453 RPC, bridge details, and local env-file setup to exact owner actions without requesting secrets." `
    -Status $(if ($ownerSignupChecklistReady) { "passed" } else { "failed" }) `
    -Evidence "signupStatus=$ownerSignupChecklistStatus, itemCount=$ownerSignupItemCount, externalSignupCount=$ownerSignupExternalCount, missingCoverage=$ownerSignupMissingCoverageCount, repoOwned=$ownerSignupRepoOwned, localEnvFileSupported=$ownerSignupLocalEnvFileSupported" `
    -Files @("infra/scripts/flowchain-owner-signup-checklist.ps1", "docs/agent-runs/live-product-infra-rpc/OWNER_SIGNUP_CHECKLIST.md") `
    -Commands @("npm run flowchain:owner:signup-checklist")

$noSecret = $reports.noSecret
$liveProduct = $reports.liveProduct
$devPack = $reports.devPack
$noSecretStatus = Get-ArchitectureStatus -Report $noSecret
$noSecretChecks = Get-ArchitectureProp -Object $noSecret -Name "checks"
$noSecretCoverageReady = ((Get-ArchitectureProp -Object $noSecretChecks -Name "scansDashboardPublicData" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $noSecretChecks -Name "scansGeneratedLiveProductReports" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $noSecretChecks -Name "reportPathMatchesProductionGate" -Default $false) -eq $true)
$safetyReady = ($noSecretStatus -eq "passed") `
    -and $noSecretCoverageReady `
    -and ((Get-ArchitectureProp -Object $liveProduct -Name "noLiveBroadcast" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $liveProduct -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $baseTxDiagnostic -Name "broadcasts" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $baseTxDiagnostic -Name "printsEnvValues" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $devPack -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $devPack -Name "envValuesPrinted" -Default $true) -eq $false)
Add-ArchitectureItem -Items $items -Id "secret-broadcast-boundary" -Layer "Security" `
    -Requirement "Architecture reports and live-readiness commands preserve the no-secret and no-live-broadcast safety boundary." `
    -Status $(if ($safetyReady) { "passed" } else { "failed" }) `
    -Evidence "noSecretStatus=$noSecretStatus, scansGeneratedReports=$(Get-ArchitectureProp -Object $noSecretChecks -Name "scansGeneratedLiveProductReports"), reportPathMatchesProductionGate=$(Get-ArchitectureProp -Object $noSecretChecks -Name "reportPathMatchesProductionGate"), liveProductNoLiveBroadcast=$(Get-ArchitectureProp -Object $liveProduct -Name "noLiveBroadcast"), liveProductEnvValuesPrinted=$(Get-ArchitectureProp -Object $liveProduct -Name "envValuesPrinted"), baseTxBroadcasts=$(Get-ArchitectureProp -Object $baseTxDiagnostic -Name "broadcasts"), devPackNoSecrets=$(Get-ArchitectureProp -Object $devPack -Name "noSecrets")" `
    -Files @("infra/scripts/flowchain-no-secret-scan.ps1") `
    -Commands @("npm run flowchain:no-secret:scan")

$liveInfra = $reports.liveInfra
$externalTester = $reports.externalTester
$externalTesterPacket = $reports.externalTesterPacket
$testerWriteTokenSetup = $reports.testerWriteTokenSetup
$publicTesterGateway = $reports.publicTesterGateway
$dashboardUiReadiness = $reports.dashboardUiReadiness
$devPackStatus = Get-ArchitectureStatus -Report $devPack
$devPackChecks = Get-ArchitectureProp -Object $devPack -Name "checks"
$devPackReady = (Test-RepoFile -Path "services/flowchain-sdk/src/client.ts") `
    -and (Test-RepoFile -Path "services/flowchain-sdk/src/cli.ts") `
    -and (Test-RepoFile -Path "docs/developer/FLOWCHAIN_QUICKSTART.md") `
    -and (Test-RepoFile -Path "docs/sdk/RPC_REFERENCE.generated.md") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:dev-pack:e2e") `
    -and ($devPackStatus -eq "passed") `
    -and ((Get-ArchitectureProp -Object $devPackChecks -Name "discoveryLoaded" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $devPackChecks -Name "walletTransfersReadable" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $devPackChecks -Name "walletBalancesReadable" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $devPackChecks -Name "walletSendRuntimeBacked" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $devPackChecks -Name "browserExampleViteReactPackaged" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $devPackChecks -Name "browserExampleBuildPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $devPackChecks -Name "publicReadinessFailClosed" -Default $false) -eq $true)
Add-ArchitectureItem -Items $items -Id "developer-dev-pack-boundary" -Layer "Developer ecosystem" `
    -Requirement "Developer SDK/devkit and docs connect to the real FlowChain RPC, generate a live RPC reference, read wallet data, submit a runtime-backed local wallet send, prove the packaged browser starter, and fail closed for public readiness." `
    -Status $(if ($devPackReady) { "passed" } else { "failed" }) `
    -Evidence "devPackStatus=$devPackStatus, methodCount=$(Get-ArchitectureProp -Object $devPack -Name "methodCount"), heights=$(Get-ArchitectureProp -Object $devPack -Name "firstHeight")->$(Get-ArchitectureProp -Object $devPack -Name "secondHeight"), report=$($reportPaths.devPack)" `
    -Files @("services/flowchain-sdk/src/client.ts", "services/flowchain-sdk/src/cli.ts", "examples/flowchain-browser-readiness/package.json", "examples/flowchain-browser-readiness/src/main.jsx", "docs/developer/FLOWCHAIN_QUICKSTART.md", "docs/sdk/RPC_REFERENCE.generated.md") `
    -Commands @("npm run flowchain:dev-pack:e2e")
$productGateFiles = @(
    "infra/scripts/flowchain-live-infra-check.ps1",
    "infra/scripts/flowchain-live-product-e2e.ps1",
    "infra/scripts/flowchain-completion-audit.ps1",
    "infra/scripts/flowchain-public-deployment-contract.ps1",
    "infra/scripts/flowchain-doctor.ps1",
    "infra/scripts/flowchain-operator-package.ps1",
    "infra/scripts/flowchain-operator-package-verify.ps1",
    "infra/scripts/flowchain-external-tester-readiness.ps1",
    "infra/scripts/flowchain-external-tester-packet.ps1",
    "infra/scripts/flowchain-external-tester-evidence-validation.ps1",
    "infra/scripts/flowchain-tester-write-token-setup.ps1",
    "infra/scripts/flowchain-public-tester-gateway-e2e.ps1",
    "infra/scripts/flowchain-dashboard-ui-readiness.ps1",
    "apps/dashboard/playwright.config.ts",
    "apps/dashboard/e2e/flowchain-ui-readiness.spec.ts"
)
$liveInfraGateStatus = Get-ArchitectureStatus -Report $liveInfra
$liveProductGateStatus = Get-ArchitectureStatus -Report $liveProduct
$externalTesterStatus = Get-ArchitectureStatus -Report $externalTester
$externalTesterPacketStatus = Get-ArchitectureStatus -Report $externalTesterPacket
$testerWriteTokenSetupStatus = Get-ArchitectureStatus -Report $testerWriteTokenSetup
$testerWriteTokenSetupChecks = Get-ArchitectureProp -Object $testerWriteTokenSetup -Name "checks"
$testerWriteTokenSetupReady = ($testerWriteTokenSetupStatus -eq "passed") `
    -and ((Get-ArchitectureProp -Object $testerWriteTokenSetupChecks -Name "tokenPathGitIgnored" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $testerWriteTokenSetupChecks -Name "ownerEnvPathGitIgnored" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $testerWriteTokenSetupChecks -Name "tokenFileExists" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $testerWriteTokenSetupChecks -Name "ownerEnvFileExists" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $testerWriteTokenSetupChecks -Name "ownerEnvTesterHashWritten" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $testerWriteTokenSetupChecks -Name "ownerEnvTesterCapWritten" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $testerWriteTokenSetupChecks -Name "rawTokenPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $testerWriteTokenSetupChecks -Name "tokenHashPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $testerWriteTokenSetup -Name "rawTokenPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $testerWriteTokenSetup -Name "tokenHashPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $testerWriteTokenSetup -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $testerWriteTokenSetup -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $testerWriteTokenSetup -Name "broadcasts" -Default $true) -eq $false) `
    -and (@((Get-ArchitectureProp -Object $testerWriteTokenSetup -Name "failedChecks" -Default @())).Count -eq 0) `
    -and (@((Get-ArchitectureProp -Object $testerWriteTokenSetup -Name "secretMarkerFindings" -Default @())).Count -eq 0)
$publicTesterGatewayStatus = Get-ArchitectureStatus -Report $publicTesterGateway
$publicTesterGatewayReady = ($publicTesterGatewayStatus -eq "passed") `
    -and ((Get-ArchitectureProp -Object $publicTesterGateway -Name "testerGatewayConfigured" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $publicTesterGateway -Name "transferAccepted" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $publicTesterGateway -Name "capRejected" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $publicTesterGateway -Name "noSecrets" -Default $false) -eq $true)
$dashboardUiStatus = Get-ArchitectureStatus -Report $dashboardUiReadiness
$dashboardUiChecks = Get-ArchitectureProp -Object $dashboardUiReadiness -Name "checks"
$dashboardUiFailedChecks = @((Get-ArchitectureProp -Object $dashboardUiReadiness -Name "failedChecks" -Default @()))
$dashboardUiBrowserProjects = @((Get-ArchitectureProp -Object $dashboardUiReadiness -Name "browserProjects" -Default @()))
$dashboardUiCoveredRoutes = @((Get-ArchitectureProp -Object $dashboardUiReadiness -Name "coveredRoutes" -Default @()))
$dashboardUiReady = ($dashboardUiStatus -eq "passed") `
    -and ($dashboardUiFailedChecks.Count -eq 0) `
    -and ($dashboardUiBrowserProjects.Count -ge 2) `
    -and ($dashboardUiCoveredRoutes.Count -ge 7) `
    -and ((Get-ArchitectureProp -Object $dashboardUiChecks -Name "desktopProjectConfigured" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $dashboardUiChecks -Name "mobileProjectConfigured" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $dashboardUiChecks -Name "walletTesterRouteCovered" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $dashboardUiChecks -Name "testerWalletCreateCovered" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $dashboardUiChecks -Name "testerFaucetCovered" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $dashboardUiChecks -Name "testerSendCovered" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $dashboardUiChecks -Name "explorerRouteCovered" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $dashboardUiChecks -Name "testerLaunchRouteCovered" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $dashboardUiChecks -Name "activationRouteCovered" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $dashboardUiChecks -Name "dashboardBrowserE2ePassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $dashboardUiChecks -Name "dashboardBuildPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $dashboardUiChecks -Name "controlPlaneTesterGatewayTestsPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $dashboardUiChecks -Name "noSecretLeakageAsserted" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $dashboardUiChecks -Name "noHorizontalOverflowAsserted" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $dashboardUiReadiness -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $dashboardUiReadiness -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $dashboardUiReadiness -Name "broadcasts" -Default $true) -eq $false)
$externalTesterChecks = Get-ArchitectureProp -Object $externalTester -Name "checks"
$externalTesterNetworkFresh = Get-ArchitectureProp -Object $externalTesterChecks -Name "testerWalletNetworkFresh" -Default $false
$externalSharingReady = Get-ArchitectureProp -Object $externalTester -Name "externalSharingReady" -Default $false
$externalTesterPacketShareable = Get-ArchitectureProp -Object $externalTesterPacket -Name "packetShareable" -Default $false
$externalTesterPacketExecutableSmokeValidated = Get-ArchitectureProp -Object $externalTesterPacket -Name "packetExecutableSmokeValidated" -Default $false
$externalTesterPacketSmokeRoutes = @((Get-ArchitectureProp -Object $externalTesterPacket -Name "packetSmokeRoutes" -Default @()))
$externalTesterEvidenceValidation = $reports.externalTesterEvidenceValidation
$externalTesterEvidenceValidationStatus = Get-ArchitectureStatus -Report $externalTesterEvidenceValidation
$externalTesterEvidenceValidationFailedChecks = @((Get-ArchitectureProp -Object $externalTesterEvidenceValidation -Name "failedChecks" -Default @()))
$externalTesterEvidenceValidationPassed = ($externalTesterEvidenceValidationStatus -eq "passed") `
    -and ($externalTesterEvidenceValidationFailedChecks.Count -eq 0) `
    -and ((Get-ArchitectureProp -Object $externalTesterEvidenceValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $externalTesterEvidenceValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $externalTesterEvidenceValidation -Name "broadcasts" -Default $true) -eq $false)
$externalTesterConnectPackShareable = Get-ArchitectureProp -Object $externalTesterPacket -Name "connectPackShareable" -Default $false
$externalTesterConnectPackChecks = Get-ArchitectureProp -Object $externalTesterPacket -Name "connectPackChecks"
$externalTesterConnectPackReady = ((Get-ArchitectureProp -Object $externalTesterConnectPackChecks -Name "connectPackWritten" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $externalTesterConnectPackChecks -Name "connectPackSchemaValid" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $externalTesterConnectPackChecks -Name "connectPackHasNetworkProfile" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $externalTesterConnectPackChecks -Name "connectPackHasRpcPlaceholder" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $externalTesterConnectPackChecks -Name "connectPackHasTesterTokenPlaceholder" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $externalTesterConnectPackChecks -Name "connectPackHasReadOnlyRoutes" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $externalTesterConnectPackChecks -Name "connectPackHasTesterWriteRoutes" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $externalTesterConnectPackChecks -Name "connectPackShareableMatchesPacket" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $externalTesterConnectPackChecks -Name "connectPackNoConcreteUrl" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $externalTesterConnectPackChecks -Name "connectPackNoSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $externalTesterConnectPackChecks -Name "connectPackBroadcastsFalse" -Default $false) -eq $true) `
    -and ($externalTesterConnectPackShareable -eq $externalTesterPacketShareable)
$externalTesterLaunchPassed = ($externalTesterStatus -eq "passed") `
    -and ($externalTesterPacketStatus -eq "passed") `
    -and ($externalSharingReady -eq $true) `
    -and ($externalTesterPacketShareable -eq $true) `
    -and ($externalTesterNetworkFresh -eq $true) `
    -and ($externalTesterPacketExecutableSmokeValidated -eq $true) `
    -and ($externalTesterConnectPackReady -eq $true) `
    -and ($externalTesterEvidenceValidationPassed -eq $true)
$externalTesterLaunchBlocked = ($externalTesterStatus -eq "blocked") `
    -and ($externalTesterPacketStatus -eq "blocked") `
    -and ($externalSharingReady -eq $false) `
    -and ($externalTesterPacketShareable -eq $false) `
    -and ($externalTesterNetworkFresh -eq $true) `
    -and ($externalTesterPacketExecutableSmokeValidated -eq $true) `
    -and ($externalTesterConnectPackReady -eq $true) `
    -and ($externalTesterEvidenceValidationPassed -eq $true)
Add-ArchitectureItem -Items $items -Id "external-tester-launch-boundary" -Layer "External tester launch" `
    -Requirement "Friends-and-family tester sharing requires fresh tester-wallet evidence, executable packet-route smoke, a machine-readable connection pack, and returned-evidence validation, and remains blocked until public RPC, backup, and Base bridge gates pass." `
    -Status $(if ($externalTesterLaunchPassed) { "passed" } elseif ($externalTesterLaunchBlocked) { "blocked" } else { "failed" }) `
    -Evidence "externalTester=$externalTesterStatus, testerNetworkFresh=$externalTesterNetworkFresh, packet=$externalTesterPacketStatus, packetShareable=$externalTesterPacketShareable, packetSmoke=$externalTesterPacketExecutableSmokeValidated, smokeRoutes=$($externalTesterPacketSmokeRoutes.Count), connectPackReady=$externalTesterConnectPackReady, evidenceValidation=$externalTesterEvidenceValidationPassed, externalSharingReady=$externalSharingReady" `
    -Files @("infra/scripts/flowchain-external-tester-readiness.ps1", "infra/scripts/flowchain-external-tester-packet.ps1", "infra/scripts/flowchain-external-tester-evidence-validation.ps1", "docs/agent-runs/live-product-infra-rpc/EXTERNAL_TESTER_PACKET.md", "docs/agent-runs/live-product-infra-rpc/external-tester-connect-pack.json", "docs/agent-runs/live-product-infra-rpc/EXTERNAL_TESTER_EVIDENCE_VALIDATION.md") `
    -Commands @("npm run flowchain:tester:readiness -- -AllowBlocked", "npm run flowchain:external-tester:packet -- -AllowBlocked", "npm run flowchain:tester:evidence:validate") `
    -Blockers @($missingOwnerInputs)
Add-ArchitectureItem -Items $items -Id "tester-write-token-setup-boundary" -Layer "External tester launch" `
    -Requirement "Friends-and-family tester write access has a no-secret setup proof where the raw bearer token stays in ignored local storage, only its digest and cap are written to the ignored owner env file, and committed evidence prints neither token nor digest." `
    -Status $(if ($testerWriteTokenSetupReady) { "passed" } else { "failed" }) `
    -Evidence "tokenSetupStatus=$testerWriteTokenSetupStatus, tokenPath=$(Get-ArchitectureProp -Object $testerWriteTokenSetup -Name "tokenPath"), ownerEnvFile=$(Get-ArchitectureProp -Object $testerWriteTokenSetup -Name "ownerEnvFile"), tokenCreated=$(Get-ArchitectureProp -Object $testerWriteTokenSetup -Name "tokenCreated"), tokenPreserved=$(Get-ArchitectureProp -Object $testerWriteTokenSetup -Name "tokenPreserved"), report=$($reportPaths.testerWriteTokenSetup)" `
    -Files @("infra/scripts/flowchain-tester-write-token-setup.ps1") `
    -Commands @("npm run flowchain:tester:token:setup")
Add-ArchitectureItem -Items $items -Id "public-tester-gateway-boundary" -Layer "External tester launch" `
    -Requirement "Public tester write gateway has a local production-shaped E2E proof for bearer auth, public-only wallet creation, capped wallet sends, balance settlement, and over-cap rejection." `
    -Status $(if ($publicTesterGatewayReady) { "passed" } else { "failed" }) `
    -Evidence "gatewayStatus=$publicTesterGatewayStatus, configured=$(Get-ArchitectureProp -Object $publicTesterGateway -Name "testerGatewayConfigured"), transferAccepted=$(Get-ArchitectureProp -Object $publicTesterGateway -Name "transferAccepted"), capRejected=$(Get-ArchitectureProp -Object $publicTesterGateway -Name "capRejected"), report=$($reportPaths.publicTesterGateway)" `
    -Files @("services/control-plane/src/server.ts", "infra/scripts/flowchain-public-tester-gateway-e2e.ps1") `
    -Commands @("npm run flowchain:tester:gateway:e2e")
Add-ArchitectureItem -Items $items -Id "dashboard-ui-browser-boundary" -Layer "Explorer and wallet UI" `
    -Requirement "Dashboard browser verification covers the tester wallet panel, authenticated tester create/faucet/send operations, Explorer inspection, tester launch readiness, L1 activation cockpit, desktop and mobile viewports, no token/secret leakage, and no horizontal overflow." `
    -Status $(if ($dashboardUiReady) { "passed" } else { "failed" }) `
    -Evidence "dashboardUiStatus=$dashboardUiStatus, browserProjects=$($dashboardUiBrowserProjects.Count), coveredRoutes=$($dashboardUiCoveredRoutes.Count), failedChecks=$($dashboardUiFailedChecks.Count), report=$($reportPaths.dashboardUiReadiness)" `
    -Files @("apps/dashboard/playwright.config.ts", "apps/dashboard/e2e/flowchain-ui-readiness.spec.ts", "apps/dashboard/src/views/WalletView.tsx", "apps/dashboard/src/views/ExplorerView.tsx", "apps/dashboard/src/views/ExternalTesterLaunchView.tsx", "apps/dashboard/src/views/OwnerActivationView.tsx", "infra/scripts/flowchain-dashboard-ui-readiness.ps1") `
    -Commands @("npm run flowchain:dashboard:ui:readiness", "npm run browser:e2e --prefix apps/dashboard")
$productGateReady = (Test-AllRepoFilesExist -Paths $productGateFiles) `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:live-infra:check") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:live-product:e2e") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:public-deployment:contract") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:completion:audit") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:doctor") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:operator:package") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:operator:package:verify") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:dev-pack:e2e") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:tester:token:setup") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:tester:gateway:e2e") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:tester:evidence:validate") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:dashboard:ui:readiness") `
    -and ($liveInfraGateStatus -in @("passed", "blocked")) `
    -and ($liveProductGateStatus -in @("passed", "blocked")) `
    -and ($externalTesterStatus -in @("passed", "blocked")) `
    -and ($externalTesterNetworkFresh -eq $true) `
    -and ($externalTesterPacketStatus -in @("passed", "blocked")) `
    -and ($externalTesterPacketExecutableSmokeValidated -eq $true) `
    -and ($externalTesterEvidenceValidationPassed -eq $true) `
    -and ($externalTesterConnectPackReady -eq $true) `
    -and ($testerWriteTokenSetupReady -eq $true) `
    -and ($publicTesterGatewayReady -eq $true) `
    -and ($dashboardUiReady -eq $true) `
    -and ($operatorDoctorReady -eq $true) `
    -and ($operatorPackageReady -eq $true) `
    -and ($operatorPackageVerifyReady -eq $true) `
    -and ($devPackReady -eq $true)
Add-ArchitectureItem -Items $items -Id "aggregate-verification-boundary" -Layer "Verification" `
    -Requirement "Product-level verification composes runtime, RPC, wallets, public tester gateway, bridge, backup, public deployment contract, executable external tester packet smoke, operator doctor, node-operator package, developer dev-pack, and completion evidence into one auditable path." `
    -Status $(if ($productGateReady) { "passed" } else { "failed" }) `
    -Evidence "liveInfra=$liveInfraGateStatus, liveProduct=$liveProductGateStatus, externalTester=$externalTesterStatus, testerNetworkFresh=$externalTesterNetworkFresh, externalTesterPacket=$externalTesterPacketStatus, packetSmoke=$externalTesterPacketExecutableSmokeValidated, connectPackReady=$externalTesterConnectPackReady, testerTokenSetup=$testerWriteTokenSetupStatus, publicTesterGateway=$publicTesterGatewayStatus, dashboardUi=$dashboardUiStatus, operatorDoctor=$operatorDoctorStatus, operatorPackage=$operatorPackageStatus, operatorPackageVerify=$operatorPackageVerifyStatus, devPack=$devPackStatus" `
    -Files $productGateFiles `
    -Commands @("npm run flowchain:live-infra:check", "npm run flowchain:live-product:e2e", "npm run flowchain:completion:audit", "npm run flowchain:external-tester:packet", "npm run flowchain:tester:token:setup", "npm run flowchain:tester:gateway:e2e", "npm run flowchain:dashboard:ui:readiness", "npm run flowchain:doctor -- -ReportPath docs/agent-runs/live-product-infra-rpc/operator-doctor-report.json", "npm run flowchain:operator:package", "npm run flowchain:operator:package:verify", "npm run flowchain:dev-pack:e2e")

$failedItems = @($items | Where-Object { $_.status -eq "failed" })
$blockedItems = @($items | Where-Object { $_.status -eq "blocked" })
$blockedItemsWithoutBlockers = @($blockedItems | Where-Object { @($_.blockers).Count -eq 0 })
$blockedItemsWithUnknownBlockers = @($blockedItems | Where-Object {
    $itemBlockers = @($_.blockers)
    @($itemBlockers | Where-Object { $_ -notin $knownExternalOwnerInputs }).Count -gt 0
})
$blockedOnlyOnKnownOwnerInputs = ($failedItems.Count -eq 0) `
    -and ($blockedItemsWithoutBlockers.Count -eq 0) `
    -and ($blockedItemsWithUnknownBlockers.Count -eq 0) `
    -and ($unknownOwnerInputs.Count -eq 0)
$status = if ($failedItems.Count -gt 0) { "failed" } elseif ($blockedItems.Count -gt 0) { "blocked" } else { "passed" }

$dataFlows = @(
    [ordered]@{
        name = "private-local-wallet-transfer"
        path = @("tester wallet create", "control-plane /wallets/create", "wallet public metadata", "control-plane /wallets/send", "live node inbox", "runtime block", "wallet balance/transfer reads")
        latestEvidence = $reportPaths.testerNetwork
    },
    [ordered]@{
        name = "owner-host-service-lifecycle"
        path = @("Windows Scheduled Task", "repo working directory", "live service supervisor", "service status check", "restart with live profile", "private node/control-plane/relayer recovery")
        latestEvidence = $reportPaths.serviceInstallValidation
    },
    [ordered]@{
        name = "node-operator-package"
        path = @("operator doctor", "operator package command", "copied runbooks", "command matrix", "owner-input names", "latest evidence reports", "independent verifier", "no-secret scan")
        latestEvidence = $reportPaths.operatorPackageVerify
    },
    [ordered]@{
        name = "tester-write-token-setup"
        path = @("ignored local bearer token file", "SHA-256 digest only in ignored owner env", "tester send cap env gate", "no-secret setup evidence", "public tester gateway auth")
        latestEvidence = $reportPaths.testerWriteTokenSetup
    },
    [ordered]@{
        name = "public-tester-gateway"
        path = @("tester token setup proof", "public edge /tester/wallets/create", "public-only wallet metadata", "public edge /tester/wallets/send", "cap enforcement", "runtime block", "balance proof")
        latestEvidence = $reportPaths.publicTesterGateway
        tokenSetupEvidence = $reportPaths.testerWriteTokenSetup
    },
    [ordered]@{
        name = "dashboard-wallet-explorer"
        path = @("browser /wallet tester panel", "tester token kept out of page/storage output", "tester wallet create", "tester faucet", "tester send", "browser /explorer inspection", "desktop/mobile viewport checks")
        latestEvidence = $reportPaths.dashboardUiReadiness
    },
    [ordered]@{
        name = "developer-dev-pack"
        path = @("developer CLI/SDK", "control-plane /rpc", "rpc_discover", "wallet balance/history reads", "control-plane /wallets/send", "runtime block", "generated RPC reference")
        latestEvidence = $reportPaths.devPack
    },
    [ordered]@{
        name = "public-rpc-exposure"
        path = @("owner TLS endpoint", "allowed-origin/rate-limit gate", "control-plane HTTP server", "read-only synthetic canary", "JSON-RPC/REST methods", "runtime state reads")
        latestEvidence = $reportPaths.publicRpcReadiness
        canaryEvidence = $reportPaths.publicRpcSyntheticCanary
        blockedBy = @("FLOWCHAIN_RPC_PUBLIC_URL", "FLOWCHAIN_RPC_ALLOWED_ORIGINS", "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE", "FLOWCHAIN_RPC_TLS_TERMINATED")
    },
    [ordered]@{
        name = "public-rpc-edge-template"
        path = @("placeholder edge config", "owner DNS/TLS", "rate-limited reverse proxy", "defensive response headers", "private FlowChain RPC origin", "readiness gates")
        latestEvidence = $reportPaths.publicRpcEdgeTemplate
    },
    [ordered]@{
        name = "owner-public-edge-onboarding"
        path = @("owner signup decisions", "public DNS/TLS/proxy", "repo-owned FlowChain RPC origin", "local-only env values", "public readiness gates")
        latestEvidence = $reportPaths.ownerOnboarding
    },
    [ordered]@{
        name = "owner-signup-checklist"
        path = @("owner signup/setup list", "public RPC hostname", "tester write token hash and cap", "always-on host", "backup storage", "Base 8453 RPC", "bridge pilot values", "local env-file loader")
        latestEvidence = $reportPaths.ownerSignupChecklist
    },
    [ordered]@{
        name = "owner-go-live-launch"
        path = @("ignored owner inputs", "public RPC render", "systemd service plan", "live monitor", "public canary", "backup restore proof", "bridge relayer pilot", "external tester packet", "completion/truth/no-secret gates", "rollback commands")
        latestEvidence = $reportPaths.ownerGoLiveHandoff
        blockedBy = @("FLOWCHAIN_RPC_PUBLIC_URL", "FLOWCHAIN_RPC_STATE_BACKUP_PATH", "FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL")
    },
    [ordered]@{
        name = "base8453-bridge-credit"
        path = @("Base 8453 lockbox event", "staged scan cursor", "read-only bridge observer", "deposit validation", "bridge credit handoff", "runtime block inclusion", "safe cursor commit", "wallet spend path")
        latestEvidence = $reportPaths.bridgeRelayerOnce
        blockedBy = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_BASE8453_ASSET_DECIMALS", "FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS")
    },
    [ordered]@{
        name = "state-recovery"
        path = @("runtime state file", "service status/readiness", "owner backup path", "write/read backup proof", "operator recovery command")
        latestEvidence = $reportPaths.backupReadiness
        blockedBy = @("FLOWCHAIN_RPC_STATE_BACKUP_PATH")
    }
)

$objectiveDeliverables = @(
    "A live-profile L1 node produces and finalizes blocks.",
    "RPC clients can connect through a private service now and through a public owner-operated edge only after TLS/CORS/rate-limit checks pass.",
    "Public RPC exposure has a no-values owner edge template for HTTPS reverse proxying, rate limiting, CORS-origin forwarding, and defensive response headers.",
    "Wallets can be created without returned secret material and can send wallet-to-wallet transfers that settle in produced blocks.",
    "The dashboard has a browser-level desktop/mobile proof for tester wallet create, faucet, send, and Explorer inspection without leaking tester tokens or causing horizontal overflow.",
    "Friends-and-family write access has an authenticated tester gateway with cap enforcement and a local E2E proof.",
    "Bridge funds are modeled through a Base 8453 observer/credit path that is local-proven, bounds relayer child processes, stages the Base scan cursor until L1 credit proof, can queue new relayer handoffs into the L1, and remains live-blocked until owner guardrails are configured.",
    "State backup, monitoring, node/control-plane/bridge-relayer autorecovery, reboot-persistent service install, operator doctor diagnostics, node-operator packaging, service lifecycle, emergency stop, and external tester packet are explicit operational boundaries.",
    "Owner onboarding explicitly separates the repo-owned FlowChain RPC public edge from the external Base 8453 bridge RPC dependency.",
    "Owner signup checklist maps the external services and local setup values needed for public operation without requesting secrets.",
    "The owner-operated public deployment contract has pre-exposure and rollback commands and cannot become shareable until all public gates pass.",
    "The owner go-live handoff gives the operator one ordered launch sequence with expected statuses, stop-on-failure gates, rollback commands, and final release audits.",
    "Every missing production edge fails closed on exact owner input names, with no secrets, env values, or live broadcasts."
)

$report = [ordered]@{
    schema = "flowchain.architecture_audit_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    blockedOnlyOnKnownExternalOwnerInputs = $blockedOnlyOnKnownOwnerInputs
    objectiveDeliverables = $objectiveDeliverables
    itemCounts = [ordered]@{
        passed = @($items | Where-Object { $_.status -eq "passed" }).Count
        blocked = $blockedItems.Count
        failed = $failedItems.Count
        total = $items.Count
    }
    items = @($items)
    dataFlows = $dataFlows
    missingEnvNames = @($missingOwnerInputs)
    diagnosticMissingEnvNames = @($diagnosticMissingEnvNames)
    unknownMissingEnvNames = @($unknownOwnerInputs)
    knownExternalOwnerInputs = $knownExternalOwnerInputs
    reportPaths = $reportPaths
    packetExecutableSmokeValidated = $externalTesterPacketExecutableSmokeValidated
    externalTesterLaunchEvidence = [ordered]@{
        externalTesterStatus = $externalTesterStatus
        externalTesterPacketStatus = $externalTesterPacketStatus
        externalSharingReady = $externalSharingReady
        packetShareable = $externalTesterPacketShareable
        packetExecutableSmokeValidated = $externalTesterPacketExecutableSmokeValidated
        packetSmokeRoutes = @($externalTesterPacketSmokeRoutes)
        connectPackShareable = $externalTesterConnectPackShareable
        connectPackReady = $externalTesterConnectPackReady
        connectPackChecks = $externalTesterConnectPackChecks
        testerNetworkFresh = $externalTesterNetworkFresh
        testerWriteTokenSetupStatus = $testerWriteTokenSetupStatus
        testerWriteTokenSetupReady = $testerWriteTokenSetupReady
        publicTesterGatewayStatus = $publicTesterGatewayStatus
        publicTesterGatewayReady = $publicTesterGatewayReady
        dashboardUiStatus = $dashboardUiStatus
        dashboardUiReady = $dashboardUiReady
        dashboardUiBrowserProjects = @($dashboardUiBrowserProjects)
        dashboardUiCoveredRoutes = @($dashboardUiCoveredRoutes)
        publicDeploymentContractPacketSmoke = $deploymentContractPacketSmoke
    }
    opsAlertCoverage = [ordered]@{
        status = $opsAlertRulesStatus
        ruleCount = $opsAlertRuleCount
        criticalRuleCount = $opsAlertCriticalRules
        blockedRuleCount = $opsAlertBlockedRules
        coveredFindingCount = $opsAlertCoveredFindingCodes.Count
        unmappedCurrentFindingCount = $opsAlertUnmappedCodes.Count
    }
    opsMetricsCoverage = [ordered]@{
        exportStatus = $opsMetricsExportStatus
        metricCount = $opsMetricsExportMetricCount
        exportFailedCheckCount = $opsMetricsExportFailedChecks.Count
        installStatus = $metricsInstallValidationStatus
        installFailedCheckCount = $metricsInstallFailedChecks.Count
        metricsJsonWritten = (Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "metricsJsonWritten" -Default $false)
        prometheusTextWritten = (Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "prometheusTextWritten" -Default $false)
        requiredMetricsPresent = (Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "requiredMetricsPresent" -Default $false)
        publicRpcEdgeMetricsPresent = (Get-ArchitectureProp -Object $opsMetricsExportChecks -Name "publicRpcEdgeMetricsPresent" -Default $false)
        publicRpcSecurityHeaderMetricsPresent = $opsMetricsHasPublicRpcSecurityHeaderMetrics
        missingPublicRpcSecurityHeaderMetricNames = @($missingPublicRpcSecurityHeaderMetricNames)
        publicRpcRollbackDrillMetricsPresent = $opsMetricsHasPublicRpcRollbackDrillMetrics
        missingPublicRpcRollbackDrillMetricNames = @($missingPublicRpcRollbackDrillMetricNames)
        publicRpcOwnerHostApplyPlanMetricsPresent = $opsMetricsHasPublicRpcOwnerHostApplyPlanMetrics
        missingPublicRpcOwnerHostApplyPlanMetricNames = @($missingPublicRpcOwnerHostApplyPlanMetricNames)
        bridgeDeployControlMetricsPresent = $opsMetricsHasBridgeDeployControlMetrics
        missingBridgeDeployControlMetricNames = @($missingBridgeDeployControlMetricNames)
        supervisorNodeRecoveryMetricsPresent = $opsMetricsHasSupervisorNodeRecoveryMetrics
        missingSupervisorNodeRecoveryMetricNames = @($missingSupervisorNodeRecoveryMetricNames)
        serviceInstallValidationMetricsPresent = $opsMetricsHasServiceInstallValidationMetrics
        missingServiceInstallValidationMetricNames = @($missingServiceInstallValidationMetricNames)
        bridgeRelayerLoopValidationMetricsPresent = $opsMetricsHasBridgeRelayerLoopValidationMetrics
        missingBridgeRelayerLoopValidationMetricNames = @($missingBridgeRelayerLoopValidationMetricNames)
        bridgeReconciliationMetricsPresent = $opsMetricsHasBridgeReconciliationMetrics
        missingBridgeReconciliationMetricNames = @($missingBridgeReconciliationMetricNames)
        bridgeReleaseEvidenceMetricsPresent = $opsMetricsHasBridgeReleaseEvidenceMetrics
        missingBridgeReleaseEvidenceMetricNames = @($missingBridgeReleaseEvidenceMetricNames)
        externalTesterClientMetricsPresent = $opsMetricsHasExternalTesterClientMetrics
        missingExternalTesterClientMetricNames = @($missingExternalTesterClientMetricNames)
        secondComputerMetricsPresent = $opsMetricsHasSecondComputerMetrics
        missingSecondComputerMetricNames = @($missingSecondComputerMetricNames)
        devPackMetricsPresent = $opsMetricsHasDevPackMetrics
        missingDevPackMetricNames = @($missingDevPackMetricNames)
        systemdTimerUnitPlanned = (Get-ArchitectureProp -Object $metricsInstallChecks -Name "systemdTimerUnitPlanned" -Default $false)
        noExternalDelivery = (Get-ArchitectureProp -Object $metricsInstallChecks -Name "noExternalDelivery" -Default $false)
    }
    serviceSupervisorAutorecovery = [ordered]@{
        status = $supervisorValidationStatus
        controlPlaneRestartAttempts = $supervisorRestartAttempts
        nodeRestartAttempts = $supervisorNodeRestartAttempts
        relayerRestartAttempts = $supervisorRelayerRestartAttempts
        nodeCrashDetected = (Get-ArchitectureProp -Object $supervisorChecks -Name "nodeCrashDetected" -Default $false)
        nodeRecovered = (Get-ArchitectureProp -Object $supervisorChecks -Name "afterNodeRecoveryNodeRunning" -Default $false)
        controlPlaneRecoveredAfterNodeCrash = (Get-ArchitectureProp -Object $supervisorChecks -Name "afterNodeRecoveryControlPlaneRunning" -Default $false)
        nodeRecoveryLiveProfile = (Get-ArchitectureProp -Object $supervisorChecks -Name "afterNodeRecoveryLiveProfile" -Default $false)
        nodeRecoveryMaxBlocksUnbounded = (Get-ArchitectureProp -Object $supervisorChecks -Name "afterNodeRecoveryMaxBlocksUnbounded" -Default $false)
        relayerRecovered = (Get-ArchitectureProp -Object $supervisorChecks -Name "afterRelayerRecoveryLoopRunning" -Default $false)
    }
    bridgeRelayerSafetyEvidence = [ordered]@{
        status = $bridgeRelayerStatus
        childTimeoutSeconds = $bridgeRelayerChildTimeoutSeconds
        stepCount = $bridgeRelayerSteps.Count
        timedOutStepCount = $bridgeRelayerTimedOutSteps.Count
        guardrailChildTimeoutRecorded = (Get-ArchitectureProp -Object $bridgeRelayerGuardrailChecks -Name "relayerChildTimeoutRecorded" -Default $false)
        guardrailNoChildTimeouts = (Get-ArchitectureProp -Object $bridgeRelayerGuardrailChecks -Name "relayerNoChildTimeouts" -Default $false)
        loopValidationStatus = $bridgeRelayerLoopStatus
        loopReportHealthy = (Get-ArchitectureProp -Object $bridgeRelayerLoopChecks -Name "statusRelayerReportHealthy" -Default $false)
    }
    architectureMarkdownPath = $markdownFullPath
    noLiveBroadcast = $true
    envValuesPrinted = $false
    noSecrets = $true
}

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Architecture Audit")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Blocked only on known external owner inputs: $blockedOnlyOnKnownOwnerInputs")
$markdownLines.Add("")
$markdownLines.Add("## Concrete Deliverables")
$markdownLines.Add("")
foreach ($deliverable in $objectiveDeliverables) {
    $markdownLines.Add("- $deliverable")
}
$markdownLines.Add("")
$markdownLines.Add("## Architecture Checklist")
$markdownLines.Add("")
$markdownLines.Add("| Layer | Requirement | Status | Evidence |")
$markdownLines.Add("| --- | --- | --- | --- |")
foreach ($item in $items) {
    $markdownLines.Add("| $($item.layer.Replace('|','/')) | $($item.requirement.Replace('|','/')) | $($item.status) | $($item.evidence.Replace('|','/')) |")
}
$markdownLines.Add("")
$markdownLines.Add("## Data Flows")
$markdownLines.Add("")
foreach ($flow in $dataFlows) {
    $markdownLines.Add("- $($flow.name): $((@($flow.path)) -join ' -> ')")
}
$markdownLines.Add("")
$markdownLines.Add("## Remaining External Owner Inputs")
$markdownLines.Add("")
if ($missingOwnerInputs.Count -eq 0) {
    $markdownLines.Add("- None")
}
else {
    foreach ($name in @($missingOwnerInputs)) {
        $markdownLines.Add("- $name")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Architecture Decision")
$markdownLines.Add("")
if ($status -eq "failed") {
    $markdownLines.Add("The architecture audit found failed local evidence. Do not treat the L1 architecture as ready.")
}
elseif ($status -eq "blocked") {
    $markdownLines.Add("The local architecture is explicit and evidence-backed, but public RPC, tester write gateway, backup, and/or Base 8453 live edges remain blocked until exact owner inputs are configured.")
}
else {
    $markdownLines.Add("All audited architecture boundaries are passed.")
}

$reportText = $report | ConvertTo-Json -Depth 20
Assert-FlowChainNoSecretText -Text $reportText -Label "architecture audit report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "architecture audit markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain architecture audit status: $status"
Write-Host "Blocked only on known external owner inputs: $blockedOnlyOnKnownOwnerInputs"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($missingOwnerInputs.Count -gt 0) {
    Write-Host "Missing env names: $((@($missingOwnerInputs)) -join ', ')"
}

if ($status -eq "passed" -or ($status -eq "blocked" -and $AllowBlocked)) {
    exit 0
}
exit 1
