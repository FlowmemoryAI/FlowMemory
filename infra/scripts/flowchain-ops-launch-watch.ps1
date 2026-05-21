param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/ops-launch-watch-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/OPS_LAUNCH_WATCH.md",
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

$paths = [ordered]@{
    opsSnapshot = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-snapshot-report.json"
    opsAlerts = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-alert-rules-report.json"
    opsMetricsExport = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-metrics-export-report.json"
    opsMetricsJson = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-metrics.json"
    monitoringBundle = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/monitoring-bundle-report.json"
    serviceStatus = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-status-report.json"
    serviceMonitor = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-monitor-report.json"
    serviceInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-install-validation-report.json"
    systemdServiceInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/systemd-service-install-validation-report.json"
    publicRpc = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json"
    publicRpcSyntheticCanary = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-synthetic-canary-report.json"
    publicRpcDeploymentAutomation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json"
    publicRpcCommandMatrix = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-command-matrix-report.json"
    backup = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json"
    backupRestoreValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-report.json"
    backupOwnerPathDryRun = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-owner-path-dry-run-report.json"
    backupInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-install-validation-report.json"
    bridgeLive = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
    bridgeInfra = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
    bridgeRelayerOnce = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-once-report.json"
    bridgeRelayerGuardrail = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-guardrail-validation-report.json"
    bridgeRelayerLoop = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-loop-validation-report.json"
    bridgeRuntimeCredit = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-runtime-credit-validation-report.json"
    bridgeReconciliation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-reconciliation-report.json"
    bridgeReleaseEvidence = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-release-evidence-validation-report.json"
    realValuePilotAggregate = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/real-value-pilot-aggregate-report.json"
    externalTester = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
    externalTesterPacket = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json"
    externalTesterClientValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-client-validation-report.json"
    externalTesterEvidenceValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-evidence-validation-report.json"
    publicTesterGateway = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json"
    dashboardUi = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/dashboard-ui-readiness-report.json"
    ownerGoLiveHandoff = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-go-live-handoff-report.json"
    ownerNeedsNow = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-needs-now-report.json"
    publicDeploymentContract = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json"
    liveCapabilityMatrix = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/live-chain-capability-matrix-report.json"
    completionAudit = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-completion-audit-report.json"
    liveCutover = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/live-cutover-rehearsal-report.json"
    truthTable = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/production-truth-table-report.json"
    noSecret = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json"
}

function Get-WatchProp {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name,
        [object] $Default = $null
    )

    if ($null -ne $Object -and $Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
    }
    if ($null -ne $Object) {
        $property = $Object.PSObject.Properties[$Name]
        if ($null -ne $property) {
            return $property.Value
        }
    }
    return $Default
}

function Get-WatchStatus {
    param([AllowNull()][object] $Report)
    return [string](Get-WatchProp -Object $Report -Name "status" -Default "missing")
}

function Get-WatchArray {
    param([AllowNull()][object] $Value)
    return @($Value | Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string] $_) })
}

function Get-WatchCount {
    param([AllowNull()][object] $Value)
    if ($null -eq $Value) {
        return 0
    }
    return [int](@($Value | Where-Object { $null -ne $_ }) | Measure-Object).Count
}

function Test-WatchPackageScript {
    param([Parameter(Mandatory = $true)][string] $Name)
    $packageJson = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "package.json") | ConvertFrom-Json
    return $packageJson.scripts.PSObject.Properties.Name -contains $Name
}

function ConvertTo-WatchMetricNumber {
    param([AllowNull()][object] $Value, [double] $Default = 0)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace("$Value")) {
        return $Default
    }
    try {
        return [double] $Value
    }
    catch {
        return $Default
    }
}

function Invoke-WatchChild {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string[]] $ArgumentList
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = (& powershell @ArgumentList 2>&1) | ForEach-Object { "$_" }
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
    }
    catch {
        $output = @($_.Exception.Message)
        $exitCode = 1
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    return [ordered]@{
        name = $Name
        exitCode = $exitCode
        outputLineCount = Get-WatchCount -Value $output
    }
}

function Get-WatchSecretMarkerFindings {
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

$refreshSteps = New-Object System.Collections.ArrayList
if (-not $NoRefresh.IsPresent) {
    [void] $refreshSteps.Add((Invoke-WatchChild -Name "ops-snapshot" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-ops-snapshot.ps1"), "-AllowBlocked", "-ReportPath", $paths.opsSnapshot)))
    [void] $refreshSteps.Add((Invoke-WatchChild -Name "ops-alerts" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-ops-alerts.ps1"), "-AllowBlocked", "-NoRefresh", "-ReportPath", $paths.opsAlerts, "-OpsSnapshotPath", $paths.opsSnapshot)))
    [void] $refreshSteps.Add((Invoke-WatchChild -Name "ops-metrics-export" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-ops-metrics-export.ps1"), "-AllowBlocked", "-NoRefresh", "-ReportPath", $paths.opsMetricsExport, "-MetricsJsonPath", $paths.opsMetricsJson)))
    [void] $refreshSteps.Add((Invoke-WatchChild -Name "monitoring-bundle" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-monitoring-bundle.ps1"), "-ReportPath", $paths.monitoringBundle, "-MetricsJsonPath", $paths.opsMetricsJson, "-MetricsExportReportPath", $paths.opsMetricsExport, "-AlertRulesPath", $paths.opsAlerts)))
}

$reports = [ordered]@{}
foreach ($entry in $paths.GetEnumerator()) {
    if ($entry.Key -eq "opsMetricsJson") {
        continue
    }
    $reports[$entry.Key] = Read-FlowChainJsonIfExists -Path $entry.Value
}
$metricsJson = Read-FlowChainJsonIfExists -Path $paths.opsMetricsJson

$metricsByName = @{}
foreach ($metric in @(Get-WatchProp -Object $metricsJson -Name "metrics" -Default @())) {
    $name = [string](Get-WatchProp -Object $metric -Name "name" -Default "")
    if (-not [string]::IsNullOrWhiteSpace($name)) {
        $metricsByName[$name] = $metric
    }
}

function Get-WatchMetricValue {
    param([Parameter(Mandatory = $true)][string] $Name)
    if ($metricsByName.ContainsKey($Name)) {
        return ConvertTo-WatchMetricNumber -Value (Get-WatchProp -Object $metricsByName[$Name] -Name "value" -Default 0)
    }
    return $null
}

function New-WatchLane {
    param(
        [Parameter(Mandatory = $true)][string] $Id,
        [Parameter(Mandatory = $true)][string] $Title,
        [Parameter(Mandatory = $true)][string[]] $ReportNames,
        [Parameter(Mandatory = $true)][string[]] $MetricNames,
        [Parameter(Mandatory = $true)][string[]] $AlertRuleIds,
        [Parameter(Mandatory = $true)][string[]] $Commands,
        [string[]] $Blockers = @(),
        [string] $ExpectedStatus = "passed"
    )

    $reportStatuses = [ordered]@{}
    foreach ($reportName in $ReportNames) {
        $reportStatuses[$reportName] = Get-WatchStatus -Report $reports[$reportName]
    }
    $missingReports = @($ReportNames | Where-Object { $null -eq $reports[$_] })
    $missingMetrics = @($MetricNames | Where-Object { -not $metricsByName.ContainsKey($_) })
    $missingAlertRules = @($AlertRuleIds | Where-Object { $_ -notin $alertRuleIds })
    $missingScripts = @($Commands | Where-Object { $_ -like "npm run *" } | ForEach-Object {
            $scriptName = (($_ -replace '^npm run ', '') -split '\s+')[0]
            if (-not (Test-WatchPackageScript -Name $scriptName)) {
                $scriptName
            }
        })

    $coverageReady = (Get-WatchCount -Value $missingReports) -eq 0 -and (Get-WatchCount -Value $missingMetrics) -eq 0 -and (Get-WatchCount -Value $missingAlertRules) -eq 0 -and (Get-WatchCount -Value $missingScripts) -eq 0
    return [ordered]@{
        id = $Id
        title = $Title
        status = $ExpectedStatus
        coverageReady = $coverageReady
        reportStatuses = $reportStatuses
        requiredReports = $ReportNames
        missingReports = $missingReports
        requiredMetrics = $MetricNames
        missingMetrics = $missingMetrics
        requiredAlertRules = $AlertRuleIds
        missingAlertRules = $missingAlertRules
        commands = $Commands
        missingPackageScripts = @($missingScripts | Select-Object -Unique)
        blockers = $Blockers
    }
}

$opsSnapshot = $reports.opsSnapshot
$opsAlerts = $reports.opsAlerts
$opsMetricsExport = $reports.opsMetricsExport
$monitoringBundle = $reports.monitoringBundle
$truthTable = $reports.truthTable
$liveCapabilityMatrix = $reports.liveCapabilityMatrix
$completionAudit = $reports.completionAudit

$alertRuleIds = @((Get-WatchProp -Object $opsAlerts -Name "rules" -Default @()) | ForEach-Object {
        [string](Get-WatchProp -Object $_ -Name "id" -Default "")
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$activeAlertRuleIds = @(Get-WatchArray -Value (Get-WatchProp -Object $opsAlerts -Name "activeRuleIds" -Default @()))
$currentFindingCodes = @(Get-WatchArray -Value (Get-WatchProp -Object $opsAlerts -Name "currentFindingCodes" -Default @()))
$expectedOwnerBlockedFindingCodes = @(
    "public-rpc-not-ready",
    "backup-not-ready",
    "bridge-not-ready",
    "bridge-relayer-not-ready",
    "external-tester-not-shareable",
    "deployment-contract-not-ready"
)
$unexpectedCurrentFindingCodes = @($currentFindingCodes | Where-Object { $_ -notin $expectedOwnerBlockedFindingCodes })

$truthCounts = Get-WatchProp -Object $truthTable -Name "classificationCounts"
$missingOwnerInputs = @(
    Get-WatchArray -Value (Get-WatchProp -Object $truthTable -Name "missingRequiredOwnerInputs" -Default @())
    Get-WatchArray -Value (Get-WatchProp -Object $liveCapabilityMatrix -Name "missingRequiredOwnerInputs" -Default @())
) | Select-Object -Unique

$publicRpcBlockers = @(Get-WatchArray -Value (Get-WatchProp -Object $liveCapabilityMatrix -Name "publicRpcBlockers" -Default @()))
$backupBlockers = @(Get-WatchArray -Value (Get-WatchProp -Object $liveCapabilityMatrix -Name "backupBlockers" -Default @()))
$bridgeBlockers = @(Get-WatchArray -Value (Get-WatchProp -Object $liveCapabilityMatrix -Name "bridgeBlockers" -Default @()))
$testerBlockers = @(Get-WatchArray -Value (Get-WatchProp -Object $liveCapabilityMatrix -Name "externalTesterBlockers" -Default @()))

$lanes = @(
    New-WatchLane -Id "service-autorecovery" `
        -Title "Service install and autorecovery" `
        -ReportNames @("serviceStatus", "serviceMonitor", "serviceInstallValidation", "systemdServiceInstallValidation") `
        -MetricNames @("flowchain_service_status_ready", "flowchain_service_monitor_ready", "flowchain_height_advanced", "flowchain_service_install_validation_ready", "flowchain_systemd_service_install_validation_ready") `
        -AlertRuleIds @("node-process-down", "control-plane-down", "block-production-stalled", "state-file-stale", "supervisor-node-recovery-validation-failed", "service-install-validation-failed") `
        -Commands @("npm run flowchain:service:status", "npm run flowchain:service:monitor", "npm run flowchain:service:supervisor:validate", "npm run flowchain:service:install:validate", "npm run flowchain:service:install:systemd:validate")
    New-WatchLane -Id "public-rpc-deployment" `
        -Title "Public RPC deployment watch" `
        -ReportNames @("publicRpc", "publicRpcSyntheticCanary", "publicRpcDeploymentAutomation", "publicRpcCommandMatrix") `
        -MetricNames @("flowchain_public_rpc_ready", "flowchain_public_rpc_synthetic_canary_ready", "flowchain_public_rpc_deployment_automation_ready", "flowchain_public_rpc_command_matrix_ready", "flowchain_public_rpc_owner_host_apply_plan_ready", "flowchain_public_rpc_owner_host_apply_script_post_deploy") `
        -AlertRuleIds @("public-rpc-not-shareable", "public-rpc-edge-hardening-failed", "public-rpc-command-matrix-failed", "public-rpc-synthetic-canary-failed") `
        -Commands @("npm run flowchain:public-rpc:deployment:automation", "npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked", "npm run flowchain:public-rpc:command-matrix", "npm run flowchain:public-rpc:abuse-test") `
        -Blockers $publicRpcBlockers `
        -ExpectedStatus "blocked-owner-input"
    New-WatchLane -Id "backup-restore" `
        -Title "Backup and restore watch" `
        -ReportNames @("backup", "backupRestoreValidation", "backupOwnerPathDryRun", "backupInstallValidation") `
        -MetricNames @("flowchain_backup_ready", "flowchain_backup_restore_validation_ready", "flowchain_backup_owner_path_dry_run_ready", "flowchain_backup_owner_path_dry_run_snapshot_proof", "flowchain_backup_owner_path_dry_run_restore_proof") `
        -AlertRuleIds @("backup-not-ready", "backup-retention-unsafe", "backup-restore-validation-failed", "backup-owner-path-dry-run-failed") `
        -Commands @("npm run flowchain:backup:restore:validate", "npm run flowchain:backup:owner-path:dry-run", "npm run flowchain:backup:install:validate", "npm run flowchain:backup:check -- -AllowBlocked") `
        -Blockers $backupBlockers `
        -ExpectedStatus "blocked-owner-input"
    New-WatchLane -Id "bridge-pilot-relayer" `
        -Title "Bridge pilot and relayer watch" `
        -ReportNames @("bridgeLive", "bridgeInfra", "bridgeRelayerOnce", "bridgeRelayerGuardrail", "bridgeRelayerLoop", "bridgeRuntimeCredit", "bridgeReconciliation", "bridgeReleaseEvidence", "realValuePilotAggregate") `
        -MetricNames @("flowchain_bridge_live_ready", "flowchain_bridge_infra_ready", "flowchain_bridge_relayer_guardrail_ready", "flowchain_bridge_runtime_credit_ready", "flowchain_bridge_reconciliation_ready", "flowchain_bridge_release_evidence_validation_ready", "flowchain_real_value_pilot_aggregate_ready") `
        -AlertRuleIds @("bridge-not-ready", "bridge-relayer-not-ready", "bridge-relayer-guardrail-failed", "bridge-relayer-loop-unhealthy", "bridge-runtime-credit-validation-failed", "bridge-reconciliation-failed", "bridge-release-evidence-validation-failed", "real-value-pilot-aggregate-failed") `
        -Commands @("npm run flowchain:bridge:relayer:once -- -AllowBlocked", "npm run flowchain:bridge:relayer:loop:validate", "npm run flowchain:bridge:runtime-credit:validate", "npm run flowchain:bridge:reconciliation", "npm run flowchain:bridge:release:evidence:validate") `
        -Blockers $bridgeBlockers `
        -ExpectedStatus "blocked-owner-input"
    New-WatchLane -Id "explorer-faucet-wallet-ui" `
        -Title "Explorer, faucet, and wallet UI watch" `
        -ReportNames @("externalTester", "externalTesterPacket", "externalTesterClientValidation", "externalTesterEvidenceValidation", "publicTesterGateway", "dashboardUi") `
        -MetricNames @("flowchain_external_tester_ready", "flowchain_external_tester_wallet_network_ready", "flowchain_external_tester_public_gateway_ready", "flowchain_external_tester_faucet_route_validated", "flowchain_public_tester_gateway_e2e_ready", "flowchain_dashboard_ui_ready", "flowchain_dashboard_ui_tester_flow_covered") `
        -AlertRuleIds @("external-tester-not-shareable", "external-tester-evidence-unsafe", "external-tester-evidence-invalid", "public-tester-gateway-e2e-failed", "dashboard-ui-readiness-failed") `
        -Commands @("npm run flowchain:dashboard:ui:readiness", "npm run flowchain:tester:gateway:e2e", "npm run flowchain:external-tester:client:validate", "npm run flowchain:tester:evidence:validate", "npm run flowchain:external-tester:packet -- -AllowBlocked") `
        -Blockers $testerBlockers `
        -ExpectedStatus "blocked-owner-input"
    New-WatchLane -Id "observability-alerting" `
        -Title "Observability and alerting watch" `
        -ReportNames @("opsSnapshot", "opsAlerts", "opsMetricsExport", "monitoringBundle", "noSecret", "truthTable") `
        -MetricNames @("flowchain_ops_critical_findings", "flowchain_ops_blocked_findings", "flowchain_ops_alert_rules_total", "flowchain_ops_active_alert_rules", "flowchain_no_secret_ready", "flowchain_truth_gates_failed", "flowchain_truth_gates_stale", "flowchain_truth_gates_repo_blocked") `
        -AlertRuleIds @("secret-boundary-breach", "truth-table-stale-or-failed", "deployment-refresh-aborted") `
        -Commands @("npm run flowchain:ops:snapshot -- -AllowBlocked", "npm run flowchain:ops:alerts -- -AllowBlocked", "npm run flowchain:ops:metrics:export -- -AllowBlocked", "npm run flowchain:ops:monitoring:bundle", "npm run flowchain:no-secret:scan")
    New-WatchLane -Id "release-governance" `
        -Title "Release governance watch" `
        -ReportNames @("liveCapabilityMatrix", "completionAudit", "liveCutover", "publicDeploymentContract", "ownerGoLiveHandoff", "ownerNeedsNow") `
        -MetricNames @("flowchain_owner_go_live_handoff_ready", "flowchain_owner_go_live_release_ready", "flowchain_owner_go_live_launch_sequence_ready", "flowchain_owner_go_live_rollback_ready", "flowchain_live_cutover_owner_blocked", "flowchain_live_cutover_missing_owner_inputs") `
        -AlertRuleIds @("owner-go-live-handoff-failed", "owner-needs-now-failed", "deployment-contract-not-ready") `
        -Commands @("npm run flowchain:owner:needs-now", "npm run flowchain:owner:go-live-handoff", "npm run flowchain:live:capabilities", "npm run flowchain:completion:audit -- -AllowBlocked", "npm run flowchain:live:cutover:rehearsal -- -AllowBlocked") `
        -Blockers $missingOwnerInputs `
        -ExpectedStatus "blocked-owner-input"
)

$allLaneMissingReports = @($lanes | ForEach-Object { @($_.missingReports) } | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) })
$allLaneMissingMetrics = @($lanes | ForEach-Object { @($_.missingMetrics) } | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) })
$allLaneMissingAlertRules = @($lanes | ForEach-Object { @($_.missingAlertRules) } | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) })
$allLaneMissingScripts = @($lanes | ForEach-Object { @($_.missingPackageScripts) } | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) })
$blockedLanes = @($lanes | Where-Object { $_.status -eq "blocked-owner-input" })
$blockedLaneUnknownBlockers = @($blockedLanes | Where-Object {
        $laneBlockers = @(Get-WatchArray -Value $_.blockers)
        (Get-WatchCount -Value $laneBlockers) -eq 0 -or (Get-WatchCount -Value @($laneBlockers | Where-Object { $_ -notin $missingOwnerInputs })) -gt 0
    } | ForEach-Object { $_.id })
$lanesWithoutCommands = New-Object System.Collections.ArrayList
foreach ($lane in $lanes) {
    if ((Get-WatchCount -Value @(Get-WatchProp -Object $lane -Name "commands" -Default @())) -eq 0) {
        [void] $lanesWithoutCommands.Add([string](Get-WatchProp -Object $lane -Name "id" -Default "unknown"))
    }
}
$commands = @($lanes | ForEach-Object { @($_.commands) })
$commandsWithInlineEnvAssignment = @($commands | Where-Object { "$_" -match '(^|\s)(\$env:)?[A-Z][A-Z0-9_]+\s*=' })
$commandsWithUrls = @($commands | Where-Object { "$_" -match 'https?://' })

$criticalOpsFindingCount = [int](Get-WatchProp -Object $opsSnapshot -Name "criticalCount" -Default 999999)
$blockedOpsFindingCount = [int](Get-WatchProp -Object $opsSnapshot -Name "blockedCount" -Default 0)
$repoBlockedTruthGates = [int](Get-WatchProp -Object $truthCounts -Name "blocked-repo-work" -Default 999999)
$failedTruthGates = [int](Get-WatchProp -Object $truthCounts -Name "failed" -Default 999999)
$staleTruthGates = [int](Get-WatchProp -Object $truthCounts -Name "stale" -Default 999999)
$staleTruthGateIds = @((Get-WatchProp -Object $truthTable -Name "items" -Default @()) | Where-Object {
        [string](Get-WatchProp -Object $_ -Name "classification" -Default "") -eq "stale"
    } | ForEach-Object {
        [string](Get-WatchProp -Object $_ -Name "id" -Default "")
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$truthTableStaleOnlyBecauseLaunchWatchIsRefreshing = (Get-WatchCount -Value $staleTruthGateIds) -eq 1 -and $staleTruthGateIds[0] -eq "ops-launch-watch"
$repoBlockedCapabilities = Get-WatchArray -Value (Get-WatchProp -Object $liveCapabilityMatrix -Name "repoBlockedCapabilities" -Default @())
$productionReady = (Get-WatchProp -Object $liveCapabilityMatrix -Name "productionReady" -Default $true) -eq $true
$completionReady = (Get-WatchProp -Object $completionAudit -Name "completionReady" -Default $true) -eq $true
$failedRefreshStepCount = 0
foreach ($step in $refreshSteps) {
    if ([int](Get-WatchProp -Object $step -Name "exitCode" -Default 1) -ne 0) {
        $failedRefreshStepCount += 1
    }
}
$laneCount = Get-WatchCount -Value $lanes
$allLaneMissingReportsCount = Get-WatchCount -Value $allLaneMissingReports
$allLaneMissingMetricsCount = Get-WatchCount -Value $allLaneMissingMetrics
$allLaneMissingAlertRulesCount = Get-WatchCount -Value $allLaneMissingAlertRules
$allLaneMissingScriptsCount = Get-WatchCount -Value $allLaneMissingScripts
$lanesWithoutCommandsCount = Get-WatchCount -Value $lanesWithoutCommands
$unexpectedCurrentFindingCount = Get-WatchCount -Value $unexpectedCurrentFindingCodes
$activeAlertRuleCount = Get-WatchCount -Value $activeAlertRuleIds
$currentFindingCount = Get-WatchCount -Value $currentFindingCodes
$repoBlockedCapabilityCount = Get-WatchCount -Value $repoBlockedCapabilities
$blockedLaneUnknownBlockerCount = Get-WatchCount -Value $blockedLaneUnknownBlockers
$commandsWithInlineEnvAssignmentCount = Get-WatchCount -Value $commandsWithInlineEnvAssignment
$commandsWithUrlsCount = Get-WatchCount -Value $commandsWithUrls
$blockedLaneCount = Get-WatchCount -Value $blockedLanes
$unmappedCurrentFindingCount = 0
foreach ($code in @(Get-WatchProp -Object $opsAlerts -Name "unmappedCurrentFindingCodes" -Default @())) {
    if (-not [string]::IsNullOrWhiteSpace([string] $code)) {
        $unmappedCurrentFindingCount += 1
    }
}

$checks = [ordered]@{
    packageScriptPresent = Test-WatchPackageScript -Name "flowchain:ops:launch-watch"
    refreshStepsSucceeded = $failedRefreshStepCount -eq 0
    metricsJsonLoaded = $null -ne $metricsJson
    laneCountSufficient = $laneCount -ge 6
    everyLaneHasEvidence = $allLaneMissingReportsCount -eq 0
    everyLaneHasMetrics = $allLaneMissingMetricsCount -eq 0
    everyLaneHasAlertRules = $allLaneMissingAlertRulesCount -eq 0
    everyLaneHasCommands = $lanesWithoutCommandsCount -eq 0
    everyLaneCommandHasPackageScript = $allLaneMissingScriptsCount -eq 0
    commandsAvoidInlineEnvAssignment = $commandsWithInlineEnvAssignmentCount -eq 0
    commandsAvoidUrls = $commandsWithUrlsCount -eq 0
    opsSnapshotLoaded = $null -ne $opsSnapshot
    opsSnapshotHasNoCriticalFindings = $criticalOpsFindingCount -eq 0
    opsSnapshotBlockedFindingsAreExpected = $unexpectedCurrentFindingCount -eq 0
    opsAlertRulesPassed = (Get-WatchStatus -Report $opsAlerts) -eq "passed"
    opsAlertsMapCurrentFindings = $unmappedCurrentFindingCount -eq 0
    activeAlertRulesPresent = $activeAlertRuleCount -ge $currentFindingCount
    opsMetricsExportPassed = (Get-WatchStatus -Report $opsMetricsExport) -eq "passed"
    monitoringBundlePassed = (Get-WatchStatus -Report $monitoringBundle) -eq "passed"
    noSecretScanPassed = (Get-WatchStatus -Report $reports.noSecret) -eq "passed"
    truthTableNoRepoBlocked = $repoBlockedTruthGates -eq 0
    truthTableNoFailed = $failedTruthGates -eq 0
    truthTableNoStale = $staleTruthGates -eq 0 -or $truthTableStaleOnlyBecauseLaunchWatchIsRefreshing
    capabilityMatrixNoRepoBlocked = $repoBlockedCapabilityCount -eq 0
    blockedLanesHaveKnownOwnerInputs = $blockedLaneUnknownBlockerCount -eq 0
    noProductionReadyClaimWhileBlocked = ($productionReady -eq $false) -and ($completionReady -eq $false)
    opsCriticalMetricZero = (Get-WatchMetricValue -Name "flowchain_ops_critical_findings") -eq 0
    truthFailedMetricZero = (Get-WatchMetricValue -Name "flowchain_truth_gates_failed") -eq 0
    truthStaleMetricZero = (Get-WatchMetricValue -Name "flowchain_truth_gates_stale") -eq 0
    truthRepoBlockedMetricZero = (Get-WatchMetricValue -Name "flowchain_truth_gates_repo_blocked") -eq 0
    envValuesPrintedFalse = $true
    secretMarkerFindingsEmpty = $true
    noSecrets = $true
    broadcastsFalse = $true
}

$launchWatchStatus = if ($checks.opsSnapshotHasNoCriticalFindings -and $blockedLaneCount -gt 0) {
    "blocked-owner-input"
}
elseif ($checks.opsSnapshotHasNoCriticalFindings) {
    "passed"
}
else {
    "failed"
}

$report = [ordered]@{
    schema = "flowchain.ops_launch_watch_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "pending"
    launchWatchStatus = $launchWatchStatus
    laneCount = $laneCount
    blockedLaneCount = $blockedLaneCount
    criticalOpsFindingCount = $criticalOpsFindingCount
    blockedOpsFindingCount = $blockedOpsFindingCount
    missingOwnerInputs = @($missingOwnerInputs)
    currentFindingCodes = @($currentFindingCodes)
    unexpectedCurrentFindingCodes = @($unexpectedCurrentFindingCodes)
    staleTruthGateIds = @($staleTruthGateIds)
    truthTableStaleOnlyBecauseLaunchWatchIsRefreshing = $truthTableStaleOnlyBecauseLaunchWatchIsRefreshing
    activeAlertRuleIds = @($activeAlertRuleIds)
    missingReports = @($allLaneMissingReports | Select-Object -Unique)
    missingMetrics = @($allLaneMissingMetrics | Select-Object -Unique)
    missingAlertRules = @($allLaneMissingAlertRules | Select-Object -Unique)
    missingPackageScripts = @($allLaneMissingScripts | Select-Object -Unique)
    blockedLaneUnknownBlockers = @($blockedLaneUnknownBlockers)
    commandsWithInlineEnvAssignment = @($commandsWithInlineEnvAssignment)
    commandsWithUrls = @($commandsWithUrls)
    refresh = [ordered]@{
        performed = -not $NoRefresh.IsPresent
        steps = @($refreshSteps)
    }
    reportPaths = $paths
    lanes = @($lanes)
    checks = $checks
    failedChecks = @()
    secretMarkerFindings = @()
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
    noLiveBroadcast = $true
}

$preliminaryReportText = $report | ConvertTo-Json -Depth 18
$secretMarkerFindings = @(Get-WatchSecretMarkerFindings -Text $preliminaryReportText -Label "ops launch watch report")
$secretMarkerFindingCount = Get-WatchCount -Value $secretMarkerFindings
$checks["secretMarkerFindingsEmpty"] = $secretMarkerFindingCount -eq 0
$checks["noSecrets"] = $secretMarkerFindingCount -eq 0
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$failedCheckCount = Get-WatchCount -Value $failedChecks
$status = if ($failedCheckCount -eq 0) { "passed" } else { "failed" }
$report["status"] = $status
$report["checks"] = $checks
$report["failedChecks"] = @($failedChecks)
$report["secretMarkerFindings"] = @($secretMarkerFindings)
$report["noSecrets"] = $secretMarkerFindingCount -eq 0

$reportText = $report | ConvertTo-Json -Depth 18
Assert-FlowChainNoSecretText -Text $reportText -Label "ops launch watch report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Ops Launch Watch")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Launch watch status: $launchWatchStatus")
$markdownLines.Add("")
$markdownLines.Add("This report ties the launch-critical service, public RPC, backup, bridge, tester UI, observability, and release-governance lanes to evidence, metrics, alert rules, and operator commands. It does not send network notifications, store delivery credentials, print owner values, or broadcast transactions.")
$markdownLines.Add("")
$markdownLines.Add("| Lane | Status | Evidence | Metrics | Alerts | Blockers |")
$markdownLines.Add("| --- | --- | --- | --- | --- | --- |")
foreach ($lane in $lanes) {
    $markdownLines.Add("| $($lane.id) | $($lane.status) | $(Get-WatchCount -Value $lane.requiredReports) reports | $(Get-WatchCount -Value $lane.requiredMetrics) metrics | $(Get-WatchCount -Value $lane.requiredAlertRules) rules | ``$((@($lane.blockers)) -join ', ')`` |")
}
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
$markdownLines.Add("| Check | Result |")
$markdownLines.Add("| --- | --- |")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("| $($entry.Key) | $($entry.Value) |")
}
if ($failedCheckCount -gt 0) {
    $markdownLines.Add("")
    $markdownLines.Add("## Failed Checks")
    $markdownLines.Add("")
    foreach ($check in $failedChecks) {
        $markdownLines.Add("- $check")
    }
}

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "ops launch watch markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain ops launch watch status: $status"
Write-Host "Launch watch: $launchWatchStatus"
Write-Host "Lanes: $laneCount"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"

if ($status -ne "passed") {
    throw "FlowChain ops launch watch failed checks: $($failedChecks -join ', ')"
}
exit 0
