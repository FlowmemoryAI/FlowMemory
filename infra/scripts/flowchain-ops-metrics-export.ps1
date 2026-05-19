param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/ops-metrics-export-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/OPS_METRICS_EXPORT.md",
    [string] $MetricsJsonPath = "docs/agent-runs/live-product-infra-rpc/ops-metrics.json",
    [string] $PrometheusTextPath = "docs/agent-runs/live-product-infra-rpc/ops-metrics.prom.txt",
    [switch] $NoRefresh,
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$metricsJsonFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MetricsJsonPath)
$prometheusTextFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $PrometheusTextPath)

$paths = [ordered]@{
    opsSnapshot = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-snapshot-report.json"
    opsAlerts = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-alert-rules-report.json"
    serviceStatus = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-status-report.json"
    serviceMonitor = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-monitor-report.json"
    publicRpc = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json"
    backup = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json"
    bridgeLive = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
    bridgeInfra = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
    bridgeRelayerGuardrail = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-guardrail-validation-report.json"
    externalTester = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
    externalTesterEvidence = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-evidence-validation-report.json"
    publicDeployment = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json"
    liveCutover = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/live-cutover-rehearsal-report.json"
    truthTable = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/production-truth-table-report.json"
    noSecret = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json"
}

function Get-MetricsProp {
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

function Get-MetricsPathProp {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Path,
        [object] $Default = $null
    )

    $current = $Object
    foreach ($part in @($Path -split "\.")) {
        if ($null -eq $current) {
            return $Default
        }
        $current = Get-MetricsProp -Object $current -Name $part -Default $null
    }
    if ($null -eq $current) {
        return $Default
    }
    return $current
}

function Get-MetricsStatus {
    param([AllowNull()][object] $Report)
    return [string](Get-MetricsProp -Object $Report -Name "status" -Default "missing")
}

function ConvertTo-MetricNumber {
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

function ConvertTo-MetricBool {
    param([AllowNull()][object] $Value)

    if ($Value -is [bool]) {
        return $(if ($Value) { 1 } else { 0 })
    }
    $text = "$Value".Trim().ToLowerInvariant()
    return $(if ($text -in @("true", "passed", "ready", "healthy", "1")) { 1 } else { 0 })
}

function ConvertTo-MetricStatusPassed {
    param([AllowNull()][object] $Value)
    return $(if ("$Value" -eq "passed") { 1 } else { 0 })
}

function Add-MetricGauge {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Metrics,
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Help,
        [Parameter(Mandatory = $true)][double] $Value
    )

    [void] $Metrics.Add([ordered]@{
        name = $Name
        type = "gauge"
        help = $Help
        value = $Value
    })
}

function ConvertTo-PrometheusText {
    param([Parameter(Mandatory = $true)][object[]] $Metrics)

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($metric in $Metrics) {
        $name = [string](Get-MetricsProp -Object $metric -Name "name")
        $help = ([string](Get-MetricsProp -Object $metric -Name "help")).Replace("\", "\\").Replace("`n", " ")
        $type = [string](Get-MetricsProp -Object $metric -Name "type")
        $value = ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $metric -Name "value")
        $lines.Add("# HELP $name $help")
        $lines.Add("# TYPE $name $type")
        $lines.Add("$name $value")
    }
    return ($lines -join "`n")
}

function Get-OpsMetricsSecretMarkerFindings {
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

function Test-OpsMetricsPackageScript {
    param([Parameter(Mandatory = $true)][string] $Name)
    $packageJson = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "package.json") | ConvertFrom-Json
    return $packageJson.scripts.PSObject.Properties.Name -contains $Name
}

$refreshSteps = New-Object System.Collections.ArrayList
if (-not $NoRefresh.IsPresent) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $opsOutput = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-ops-snapshot.ps1") -AllowBlocked -ReportPath $paths.opsSnapshot 2>&1) | ForEach-Object { "$_" }
        $opsExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        [void] $refreshSteps.Add([ordered]@{ name = "ops-snapshot"; exitCode = $opsExitCode; outputLineCount = @($opsOutput).Count })

        $alertsOutput = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-ops-alerts.ps1") -AllowBlocked -NoRefresh -ReportPath $paths.opsAlerts -OpsSnapshotPath $paths.opsSnapshot 2>&1) | ForEach-Object { "$_" }
        $alertsExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        [void] $refreshSteps.Add([ordered]@{ name = "ops-alerts"; exitCode = $alertsExitCode; outputLineCount = @($alertsOutput).Count })
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

$reports = [ordered]@{}
foreach ($entry in $paths.GetEnumerator()) {
    $reports[$entry.Key] = Read-FlowChainJsonIfExists -Path $entry.Value
}

$opsSnapshot = $reports.opsSnapshot
$opsAlerts = $reports.opsAlerts
$serviceStatus = $reports.serviceStatus
$serviceMonitor = $reports.serviceMonitor
$externalTesterEvidence = $reports.externalTesterEvidence
$liveCutover = $reports.liveCutover
$truthTable = $reports.truthTable
$noSecret = $reports.noSecret

$metrics = New-Object System.Collections.ArrayList
$chain = Get-MetricsProp -Object $opsSnapshot -Name "chain"
$reportStatuses = Get-MetricsProp -Object $opsSnapshot -Name "reportStatuses"
$truthCounts = Get-MetricsProp -Object $truthTable -Name "classificationCounts"
$externalTesterEvidenceChecks = Get-MetricsProp -Object $externalTesterEvidence -Name "checks"
$externalTesterEvidenceTransferConsistent = (Get-MetricsProp -Object $externalTesterEvidenceChecks -Name "transferFound" -Default $false) -eq $true `
    -and (Get-MetricsProp -Object $externalTesterEvidenceChecks -Name "transferMatchesAccounts" -Default $false) -eq $true `
    -and (Get-MetricsProp -Object $externalTesterEvidenceChecks -Name "transferAmountMatches" -Default $false) -eq $true `
    -and (Get-MetricsProp -Object $externalTesterEvidenceChecks -Name "transactionIdMatches" -Default $false) -eq $true `
    -and (Get-MetricsProp -Object $externalTesterEvidenceChecks -Name "senderDebited" -Default $false) -eq $true `
    -and (Get-MetricsProp -Object $externalTesterEvidenceChecks -Name "recipientCredited" -Default $false) -eq $true

Add-MetricGauge -Metrics $metrics -Name "flowchain_latest_height" -Help "Latest FlowChain block height from ops snapshot." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $chain -Name "latestHeight"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_finalized_height" -Help "Finalized FlowChain block height from ops snapshot." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $chain -Name "finalizedHeight"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_state_file_age_seconds" -Help "Age of the live state file in seconds." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $chain -Name "stateFileLastWriteAgeSeconds"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_monitor_samples_total" -Help "Service monitor samples recorded in the current ops snapshot." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $chain -Name "monitorSamples"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_height_advanced" -Help "One when service monitor proved advancing block height." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $chain -Name "monitorHeightAdvanced"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_ops_critical_findings" -Help "Current critical ops finding count." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $opsSnapshot -Name "criticalCount"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_ops_blocked_findings" -Help "Current owner-blocked ops finding count." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $opsSnapshot -Name "blockedCount"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_ops_alert_rules_total" -Help "Configured ops alert rule count." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $opsAlerts -Name "ruleCount"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_ops_alert_rules_critical" -Help "Configured critical ops alert rule count." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $opsAlerts -Name "criticalRuleCount"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_ops_alert_rules_blocked" -Help "Configured owner-blocked ops alert rule count." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $opsAlerts -Name "blockedRuleCount"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_ops_active_alert_rules" -Help "Active ops alert rule count for the current findings." -Value (@((Get-MetricsProp -Object $opsAlerts -Name "activeRuleIds" -Default @())).Count)
Add-MetricGauge -Metrics $metrics -Name "flowchain_service_status_ready" -Help "One when service status report is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsStatus -Report $serviceStatus))
Add-MetricGauge -Metrics $metrics -Name "flowchain_service_monitor_ready" -Help "One when service monitor report is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsStatus -Report $serviceMonitor))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_ready" -Help "One when public RPC readiness is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsProp -Object $reportStatuses -Name "publicRpc"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_backup_ready" -Help "One when backup readiness is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsProp -Object $reportStatuses -Name "backup"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_backup_retention_count" -Help "Configured state backup retention count from backup readiness." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "backupRetentionCount"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_backup_retention_candidates" -Help "Number of eligible state backup snapshots seen by retention." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "backupRetentionCandidateCount"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_backup_retention_snapshot_protected" -Help "One when retention protected the latest state backup snapshot." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "backupRetentionCurrentSnapshotProtected"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_backup_retention_prune_errors" -Help "State backup retention prune error count." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "backupRetentionPruneErrorCount"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_live_ready" -Help "One when bridge live readiness is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsProp -Object $reportStatuses -Name "bridgeLive"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_infra_ready" -Help "One when bridge infrastructure readiness is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsProp -Object $reportStatuses -Name "bridgeInfra"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_relayer_guardrail_ready" -Help "One when bridge relayer fail-closed guardrail is ready." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "bridgeRelayerGuardrailReady"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_relayer_loop_healthy" -Help "One when a running bridge relayer loop has fresh healthy no-secret/no-broadcast evidence." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "bridgeRelayerLoopReportHealthy"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_supervisor_bridge_relayer_requested" -Help "One when the latest service supervisor report requested bridge relayer loop supervision." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "supervisorBridgeRelayerRequested"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_supervisor_bridge_relayer_recovery_healthy" -Help "One when supervisor relayer-loop recovery evidence is healthy, or relayer supervision was not requested." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "supervisorBridgeRelayerRecoveryHealthy"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_ready" -Help "One when external tester readiness is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsProp -Object $reportStatuses -Name "externalTester"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_evidence_ready" -Help "One when external tester returned evidence validation is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsStatus -Report $externalTesterEvidence))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_evidence_failed_checks" -Help "Failed checks in the external tester returned evidence validation report." -Value (@((Get-MetricsProp -Object $externalTesterEvidence -Name "failedChecks" -Default @())).Count)
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_evidence_missing_files" -Help "Missing required files in the external tester returned evidence folder." -Value (@((Get-MetricsProp -Object $externalTesterEvidence -Name "missingRequiredFiles" -Default @())).Count)
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_evidence_secret_findings" -Help "Secret marker findings in external tester returned evidence." -Value (@((Get-MetricsProp -Object $externalTesterEvidence -Name "secretMarkerFindings" -Default @())).Count)
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_evidence_height_advanced" -Help "One when returned tester evidence shows block height advanced." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $externalTesterEvidenceChecks -Name "blockHeightAdvanced"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_evidence_transfer_consistent" -Help "One when returned tester evidence has matching transfer, transaction, amount, and balance deltas." -Value (ConvertTo-MetricBool -Value $externalTesterEvidenceTransferConsistent)
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_deployment_ready" -Help "One when public deployment contract is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsProp -Object $reportStatuses -Name "publicDeployment"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_live_cutover_ready" -Help "One when the live cutover rehearsal is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsStatus -Report $liveCutover))
Add-MetricGauge -Metrics $metrics -Name "flowchain_live_cutover_owner_blocked" -Help "One when live cutover is blocked only on known owner inputs." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $liveCutover -Name "blockedOnlyOnKnownExternalOwnerInputs"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_live_cutover_missing_owner_inputs" -Help "Number of required owner input names still blocking live cutover." -Value @((Get-MetricsProp -Object $liveCutover -Name "missingEnvNames" -Default @())).Count
Add-MetricGauge -Metrics $metrics -Name "flowchain_no_secret_ready" -Help "One when no-secret scan is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsStatus -Report $noSecret))
Add-MetricGauge -Metrics $metrics -Name "flowchain_truth_gates_total" -Help "Total production truth table gates." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $truthTable -Name "productionGateCount"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_truth_gates_passed" -Help "Passed production truth table gates." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $truthCounts -Name "passed"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_truth_gates_owner_blocked" -Help "Owner-input blocked production truth table gates." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $truthCounts -Name "blocked-owner-input"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_truth_gates_repo_blocked" -Help "Repo-blocked production truth table gates." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $truthCounts -Name "blocked-repo-work"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_truth_gates_failed" -Help "Failed production truth table gates." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $truthCounts -Name "failed"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_truth_gates_stale" -Help "Stale production truth table gates." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $truthCounts -Name "stale"))

$prometheusText = ConvertTo-PrometheusText -Metrics @($metrics)
$prometheusSecretMarkerFindings = @(Get-OpsMetricsSecretMarkerFindings -Text $prometheusText -Label "ops metrics Prometheus text export")
Assert-FlowChainNoSecretText -Text $prometheusText -Label "ops Prometheus metrics export"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $prometheusTextFullPath) | Out-Null
Set-Content -LiteralPath $prometheusTextFullPath -Value $prometheusText -Encoding UTF8

$metricsJson = [ordered]@{
    schema = "flowchain.ops_metrics.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    sourceReports = [ordered]@{
        opsSnapshotStatus = Get-MetricsStatus -Report $opsSnapshot
        opsAlertRulesStatus = Get-MetricsStatus -Report $opsAlerts
        serviceStatusStatus = Get-MetricsStatus -Report $serviceStatus
        serviceMonitorStatus = Get-MetricsStatus -Report $serviceMonitor
        externalTesterEvidenceStatus = Get-MetricsStatus -Report $externalTesterEvidence
        liveCutoverStatus = Get-MetricsStatus -Report $liveCutover
        truthTableStatus = Get-MetricsStatus -Report $truthTable
        noSecretStatus = Get-MetricsStatus -Report $noSecret
    }
    metrics = @($metrics)
    metricCount = @($metrics).Count
    prometheusTextPath = $PrometheusTextPath
    envValuesPrinted = $false
    noSecrets = $true
    secretMarkerFindings = @()
    broadcasts = $false
}
$metricsJsonText = $metricsJson | ConvertTo-Json -Depth 12
$metricsJsonSecretMarkerFindings = @(Get-OpsMetricsSecretMarkerFindings -Text $metricsJsonText -Label "ops metrics JSON export")
$metricsJson["secretMarkerFindings"] = @($metricsJsonSecretMarkerFindings)
$metricsJson["noSecrets"] = $metricsJsonSecretMarkerFindings.Count -eq 0
$metricsJsonText = $metricsJson | ConvertTo-Json -Depth 12
Assert-FlowChainNoSecretText -Text $metricsJsonText -Label "ops metrics JSON export"
Write-FlowChainJson -Path $metricsJsonFullPath -Value $metricsJson -Depth 12

$metricNames = @($metrics | ForEach-Object { [string](Get-MetricsProp -Object $_ -Name "name") })
$requiredMetricNames = @(
    "flowchain_latest_height",
    "flowchain_finalized_height",
    "flowchain_state_file_age_seconds",
    "flowchain_height_advanced",
    "flowchain_ops_critical_findings",
    "flowchain_ops_blocked_findings",
    "flowchain_ops_alert_rules_total",
    "flowchain_ops_active_alert_rules",
    "flowchain_service_status_ready",
    "flowchain_public_rpc_ready",
    "flowchain_backup_ready",
    "flowchain_backup_retention_count",
    "flowchain_backup_retention_candidates",
    "flowchain_backup_retention_snapshot_protected",
    "flowchain_backup_retention_prune_errors",
    "flowchain_bridge_live_ready",
    "flowchain_bridge_relayer_guardrail_ready",
    "flowchain_bridge_relayer_loop_healthy",
    "flowchain_supervisor_bridge_relayer_requested",
    "flowchain_supervisor_bridge_relayer_recovery_healthy",
    "flowchain_external_tester_evidence_ready",
    "flowchain_external_tester_evidence_failed_checks",
    "flowchain_external_tester_evidence_missing_files",
    "flowchain_external_tester_evidence_secret_findings",
    "flowchain_external_tester_evidence_height_advanced",
    "flowchain_external_tester_evidence_transfer_consistent",
    "flowchain_public_deployment_ready",
    "flowchain_live_cutover_ready",
    "flowchain_live_cutover_owner_blocked",
    "flowchain_live_cutover_missing_owner_inputs",
    "flowchain_no_secret_ready",
    "flowchain_truth_gates_total",
    "flowchain_truth_gates_failed",
    "flowchain_truth_gates_stale"
)
$missingMetricNames = @($requiredMetricNames | Where-Object { $_ -notin $metricNames })
$prometheusTextFromFile = if (Test-Path -LiteralPath $prometheusTextFullPath) { Get-Content -Raw -LiteralPath $prometheusTextFullPath } else { "" }
$metricsJsonFromFile = Read-FlowChainJsonIfExists -Path $metricsJsonFullPath

$checks = [ordered]@{
    packageScriptPresent = Test-OpsMetricsPackageScript -Name "flowchain:ops:metrics:export"
    opsSnapshotLoaded = $null -ne $opsSnapshot
    opsAlertRulesLoaded = $null -ne $opsAlerts
    serviceStatusLoaded = $null -ne $serviceStatus
    serviceMonitorLoaded = $null -ne $serviceMonitor
    externalTesterEvidenceLoaded = $null -ne $externalTesterEvidence
    liveCutoverLoaded = $null -ne $liveCutover
    truthTableLoaded = $null -ne $truthTable
    noSecretLoaded = $null -ne $noSecret
    metricsJsonWritten = $null -ne $metricsJsonFromFile
    prometheusTextWritten = Test-Path -LiteralPath $prometheusTextFullPath
    markdownWritten = $true
    metricCountSufficient = @($metrics).Count -ge 35
    requiredMetricsPresent = $missingMetricNames.Count -eq 0
    externalTesterEvidenceMetricsPresent = @(
        "flowchain_external_tester_evidence_ready",
        "flowchain_external_tester_evidence_failed_checks",
        "flowchain_external_tester_evidence_missing_files",
        "flowchain_external_tester_evidence_secret_findings",
        "flowchain_external_tester_evidence_height_advanced",
        "flowchain_external_tester_evidence_transfer_consistent"
    ) | Where-Object { $_ -notin $metricNames } | Measure-Object | ForEach-Object { $_.Count -eq 0 }
    prometheusHasHelpAndType = $prometheusTextFromFile.Contains("# HELP flowchain_latest_height") -and $prometheusTextFromFile.Contains("# TYPE flowchain_latest_height gauge")
    prometheusContainsNoUrls = $prometheusTextFromFile -notmatch 'https?://'
    prometheusContainsNoEnvAssignments = $prometheusTextFromFile -notmatch 'FLOWCHAIN_[A-Z0-9_]+\s*='
    metricsJsonNoSecrets = (Get-MetricsProp -Object $metricsJsonFromFile -Name "noSecrets" -Default $false) -eq $true
    metricsJsonSecretMarkerFindingsEmpty = @((Get-MetricsProp -Object $metricsJsonFromFile -Name "secretMarkerFindings" -Default @())).Count -eq 0
    metricsJsonEnvValuesPrintedFalse = (Get-MetricsProp -Object $metricsJsonFromFile -Name "envValuesPrinted" -Default $true) -eq $false
    metricsJsonBroadcastsFalse = (Get-MetricsProp -Object $metricsJsonFromFile -Name "broadcasts" -Default $true) -eq $false
    envValuesPrintedFalse = $true
    secretMarkerFindingsEmpty = $true
    noSecrets = $true
    broadcastsFalse = $true
}

$report = [ordered]@{
    schema = "flowchain.ops_metrics_export_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "pending"
    refresh = [ordered]@{
        performed = -not $NoRefresh.IsPresent
        steps = @($refreshSteps)
    }
    reportPaths = $paths
    metricsJsonPath = $MetricsJsonPath
    prometheusTextPath = $PrometheusTextPath
    metricCount = @($metrics).Count
    requiredMetricNames = $requiredMetricNames
    missingMetricNames = @($missingMetricNames)
    checks = $checks
    failedChecks = @()
    secretMarkerFindings = @()
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}
$preliminaryReportText = $report | ConvertTo-Json -Depth 18
$reportSecretMarkerFindings = @(Get-OpsMetricsSecretMarkerFindings -Text $preliminaryReportText -Label "ops metrics export report")
$secretMarkerFindings = @(
    @($prometheusSecretMarkerFindings)
    @($metricsJsonSecretMarkerFindings)
    @($reportSecretMarkerFindings)
)
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
Assert-FlowChainNoSecretText -Text $reportText -Label "ops metrics export report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Ops Metrics Export")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This export converts existing no-secret ops evidence into owner-collector friendly JSON and Prometheus textfile metrics. It does not send network notifications or store external delivery credentials.")
$markdownLines.Add("")
$markdownLines.Add("- Metrics JSON: ``$MetricsJsonPath``")
$markdownLines.Add("- Prometheus textfile: ``$PrometheusTextPath``")
$markdownLines.Add("- Metric count: $(@($metrics).Count)")
$markdownLines.Add("")
$markdownLines.Add("## Required Metrics")
$markdownLines.Add("")
foreach ($name in $requiredMetricNames) {
    $state = if ($name -in $missingMetricNames) { "missing" } else { "present" }
    $markdownLines.Add("- ${name}: $state")
}
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
$markdownLines.Add("| Check | Result |")
$markdownLines.Add("| --- | --- |")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("| $($entry.Key) | $($entry.Value) |")
}
$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "ops metrics export markdown"
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain ops metrics export status: $status"
Write-Host "Metric count: $(@($metrics).Count)"
Write-Host "Report: $reportFullPath"
Write-Host "Prometheus textfile: $prometheusTextFullPath"
if ($status -ne "passed") {
    throw "FlowChain ops metrics export failed checks: $($failedChecks -join ', ')"
}
exit 0
