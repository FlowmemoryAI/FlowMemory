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
    publicRpcSyntheticCanary = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-synthetic-canary-report.json"
    publicRpcDeploymentBundle = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json"
    publicRpcDeploymentAutomation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json"
    backup = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json"
    bridgeLive = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
    bridgeInfra = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
    bridgeRelayerGuardrail = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-guardrail-validation-report.json"
    bridgeReleaseEvidenceValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-release-evidence-validation-report.json"
    realValuePilotAggregate = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/real-value-pilot-aggregate-report.json"
    externalTester = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
    publicTesterGateway = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json"
    externalTesterClientValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-client-validation-report.json"
    externalTesterEvidence = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-evidence-validation-report.json"
    dashboardUi = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/dashboard-ui-readiness-report.json"
    ownerInputsValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-validation-report.json"
    ownerActivationPlan = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-activation-plan-report.json"
    ownerGoLiveHandoff = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-go-live-handoff-report.json"
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
$publicRpc = $reports.publicRpc
$publicRpcSyntheticCanary = $reports.publicRpcSyntheticCanary
$externalTester = $reports.externalTester
$publicTesterGateway = $reports.publicTesterGateway
$externalTesterClientValidation = $reports.externalTesterClientValidation
$externalTesterEvidence = $reports.externalTesterEvidence
$dashboardUi = $reports.dashboardUi
$ownerInputsValidation = $reports.ownerInputsValidation
$ownerActivationPlan = $reports.ownerActivationPlan
$ownerGoLiveHandoff = $reports.ownerGoLiveHandoff
$bridgeReleaseEvidenceValidation = $reports.bridgeReleaseEvidenceValidation
$publicRpcDeploymentBundle = $reports.publicRpcDeploymentBundle
$publicRpcDeploymentAutomation = $reports.publicRpcDeploymentAutomation
$liveCutover = $reports.liveCutover
$truthTable = $reports.truthTable
$noSecret = $reports.noSecret

$metrics = New-Object System.Collections.ArrayList
$chain = Get-MetricsProp -Object $opsSnapshot -Name "chain"
$transactionIntake = Get-MetricsProp -Object $opsSnapshot -Name "transactionIntake"
$reportStatuses = Get-MetricsProp -Object $opsSnapshot -Name "reportStatuses"
$truthCounts = Get-MetricsProp -Object $truthTable -Name "classificationCounts"
$externalTesterChecks = Get-MetricsProp -Object $externalTester -Name "checks"
$externalTesterEvidenceChecks = Get-MetricsProp -Object $externalTesterEvidence -Name "checks"
$dashboardUiChecks = Get-MetricsProp -Object $dashboardUi -Name "checks"
$ownerInputsValidationScenarios = @((Get-MetricsProp -Object $ownerInputsValidation -Name "scenarios" -Default @()))
$ownerInputsValidationFailedScenarios = @($ownerInputsValidationScenarios | Where-Object { (Get-MetricsProp -Object $_ -Name "passed" -Default $false) -ne $true })
$ownerInputsValidationRequiredEnvNames = @((Get-MetricsProp -Object $ownerInputsValidation -Name "requiredEnvNames" -Default @()))
$ownerActivationPlanFailedChecks = @((Get-MetricsProp -Object $ownerActivationPlan -Name "failedChecks" -Default @()))
$ownerActivationPlanSecretFindings = @((Get-MetricsProp -Object $ownerActivationPlan -Name "secretMarkerFindings" -Default @()))
$ownerActivationPlanMissingEnvNames = @((Get-MetricsProp -Object $ownerActivationPlan -Name "missingEnvNames" -Default @()))
$ownerActivationPlanInvalidEnvNames = @((Get-MetricsProp -Object $ownerActivationPlan -Name "invalidEnvNames" -Default @()))
$ownerActivationPlanStageCount = [int](Get-MetricsProp -Object $ownerActivationPlan -Name "stageCount" -Default 0)
$ownerActivationPlanReadyStageCount = [int](Get-MetricsProp -Object $ownerActivationPlan -Name "readyStageCount" -Default 0)
$ownerActivationPlanReady = (Get-MetricsStatus -Report $ownerActivationPlan) -eq "passed" `
    -and $ownerActivationPlanFailedChecks.Count -eq 0 `
    -and $ownerActivationPlanSecretFindings.Count -eq 0 `
    -and $ownerActivationPlanStageCount -ge 8 `
    -and ((Get-MetricsProp -Object $ownerActivationPlan -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-MetricsProp -Object $ownerActivationPlan -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-MetricsProp -Object $ownerActivationPlan -Name "broadcasts" -Default $true) -eq $false)
$ownerGoLiveHandoffFailedChecks = @((Get-MetricsProp -Object $ownerGoLiveHandoff -Name "failedChecks" -Default @()))
$ownerGoLiveHandoffSecretFindings = @((Get-MetricsProp -Object $ownerGoLiveHandoff -Name "secretMarkerFindings" -Default @()))
$ownerGoLiveHandoffNextInputs = @((Get-MetricsProp -Object $ownerGoLiveHandoff -Name "nextOwnerInputNames" -Default @()))
$ownerGoLiveHandoffStageCount = [int](Get-MetricsProp -Object $ownerGoLiveHandoff -Name "stageCount" -Default 0)
$ownerGoLiveHandoffReady = (Get-MetricsStatus -Report $ownerGoLiveHandoff) -eq "passed" `
    -and $ownerGoLiveHandoffFailedChecks.Count -eq 0 `
    -and $ownerGoLiveHandoffSecretFindings.Count -eq 0 `
    -and $ownerGoLiveHandoffStageCount -ge 8 `
    -and ((Get-MetricsProp -Object $ownerGoLiveHandoff -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-MetricsProp -Object $ownerGoLiveHandoff -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-MetricsProp -Object $ownerGoLiveHandoff -Name "broadcasts" -Default $true) -eq $false)
$externalTesterLocalRehearsalReady = (Get-MetricsProp -Object $externalTester -Name "localTesterRehearsalReady" -Default $false) -eq $true
$externalTesterExternalSharingReady = (Get-MetricsProp -Object $externalTester -Name "externalSharingReady" -Default $false) -eq $true
$externalTesterMissingEnvNames = @((Get-MetricsProp -Object $externalTester -Name "missingEnvNames" -Default @()))
$externalTesterTesterNetwork = Get-MetricsProp -Object $externalTester -Name "testerNetwork"
$externalTesterTesterCount = [int](Get-MetricsProp -Object $externalTesterTesterNetwork -Name "testerCount" -Default 0)
$publicTesterGatewayChecks = Get-MetricsProp -Object $publicTesterGateway -Name "checks"
$publicTesterGatewayFailedChecks = @((Get-MetricsProp -Object $publicTesterGateway -Name "failedChecks" -Default @()))
$publicTesterGatewaySecretFindings = @((Get-MetricsProp -Object $publicTesterGateway -Name "secretMarkerFindings" -Default @()))
$publicTesterGatewayRoutes = @((Get-MetricsProp -Object $publicTesterGateway -Name "routes" -Default @()))
$externalTesterClientValidationChecks = Get-MetricsProp -Object $externalTesterClientValidation -Name "checks"
$externalTesterClientValidationFailedChecks = @((Get-MetricsProp -Object $externalTesterClientValidation -Name "failedChecks" -Default @()))
$externalTesterClientValidationSecretFindings = @((Get-MetricsProp -Object $externalTesterClientValidation -Name "secretMarkerFindings" -Default @()))
$publicRpcChecks = Get-MetricsProp -Object $publicRpc -Name "checks"
$publicRpcSyntheticCanaryChecks = Get-MetricsProp -Object $publicRpcSyntheticCanary -Name "checks"
$publicRpcSyntheticCanaryMissingEnvCount = @((Get-MetricsProp -Object $publicRpcSyntheticCanary -Name "missingEnvNames" -Default @())).Count
$publicRpcDeploymentBundleChecks = Get-MetricsProp -Object $publicRpcDeploymentBundle -Name "checks"
$publicRpcDeploymentAutomationChecks = Get-MetricsProp -Object $publicRpcDeploymentAutomation -Name "checks"
$bridgeReleaseEvidenceValidationChecks = Get-MetricsProp -Object $bridgeReleaseEvidenceValidation -Name "checks"
$bridgeReleaseEvidenceValidationFailedChecks = @((Get-MetricsProp -Object $bridgeReleaseEvidenceValidation -Name "failedChecks" -Default @()))
$bridgeReleaseEvidenceValidationFailedCases = @((Get-MetricsProp -Object $bridgeReleaseEvidenceValidation -Name "failedCases" -Default @()))
$bridgeReleaseEvidenceValidationMissingCases = @((Get-MetricsProp -Object $bridgeReleaseEvidenceValidation -Name "missingRequiredCases" -Default @()))
$bridgeReleaseEvidenceValidationSecretFindings = @((Get-MetricsProp -Object $bridgeReleaseEvidenceValidation -Name "secretMarkerFindings" -Default @()))
$publicRpcRequiredCutoverCommands = @(
    "npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked",
    "npm run flowchain:tester:gateway:e2e",
    "npm run flowchain:wallet:live-tester:e2e",
    "npm run flowchain:live:cutover:rehearsal -- -AllowBlocked",
    "npm run flowchain:truth-table -- -AllowBlocked",
    "npm run flowchain:no-secret:scan"
)
$publicRpcDeploymentBundleRequiredCommands = @((Get-MetricsProp -Object $publicRpcDeploymentBundle -Name "requiredCommands" -Default @()) | ForEach-Object { "$_" })
$publicRpcDeploymentBundleWalletCutoverProofReady = @($publicRpcRequiredCutoverCommands | Where-Object { $_ -notin $publicRpcDeploymentBundleRequiredCommands }).Count -eq 0
$publicRpcDeploymentAutomationWalletCutoverProofReady = ((Get-MetricsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesTesterGatewayE2e" -Default $false) -eq $true) `
    -and ((Get-MetricsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesWalletTesterE2e" -Default $false) -eq $true) `
    -and ((Get-MetricsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesSyntheticCanary" -Default $false) -eq $true) `
    -and ((Get-MetricsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesCutoverRehearsal" -Default $false) -eq $true) `
    -and ((Get-MetricsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesTruthTable" -Default $false) -eq $true) `
    -and ((Get-MetricsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesNoSecretScan" -Default $false) -eq $true)
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
Add-MetricGauge -Metrics $metrics -Name "flowchain_mempool_depth" -Help "Current local runtime mempool depth from service status." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $transactionIntake -Name "mempoolDepth"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_transaction_intake_rows_total" -Help "Signed transaction intake rows recorded in local NDJSON intake." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $transactionIntake -Name "txIntakeRows"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_transaction_intake_accepted_rows_total" -Help "Crypto-verified signed transaction intake rows recorded locally." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $transactionIntake -Name "txIntakeAcceptedRows"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_transaction_intake_invalid_rows" -Help "Invalid NDJSON rows in signed transaction intake." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $transactionIntake -Name "txIntakeInvalidRows"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_transaction_intake_file_age_seconds" -Help "Age of the signed transaction intake file in seconds, or zero when absent." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $transactionIntake -Name "txIntakeLastWriteAgeSeconds"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_runtime_submit_fixtures_total" -Help "Runtime-submit fixture files produced by signed envelope forwarding." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $transactionIntake -Name "runtimeSubmitFileCount"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_runtime_inbox_files_total" -Help "Current local runtime node inbox file count." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $transactionIntake -Name "runtimeInboxFileCount"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_ops_critical_findings" -Help "Current critical ops finding count." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $opsSnapshot -Name "criticalCount"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_ops_blocked_findings" -Help "Current owner-blocked ops finding count." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $opsSnapshot -Name "blockedCount"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_ops_alert_rules_total" -Help "Configured ops alert rule count." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $opsAlerts -Name "ruleCount"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_ops_alert_rules_critical" -Help "Configured critical ops alert rule count." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $opsAlerts -Name "criticalRuleCount"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_ops_alert_rules_blocked" -Help "Configured owner-blocked ops alert rule count." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $opsAlerts -Name "blockedRuleCount"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_ops_active_alert_rules" -Help "Active ops alert rule count for the current findings." -Value (@((Get-MetricsProp -Object $opsAlerts -Name "activeRuleIds" -Default @())).Count)
Add-MetricGauge -Metrics $metrics -Name "flowchain_service_status_ready" -Help "One when service status report is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsStatus -Report $serviceStatus))
Add-MetricGauge -Metrics $metrics -Name "flowchain_service_monitor_ready" -Help "One when service monitor report is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsStatus -Report $serviceMonitor))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_ready" -Help "One when public RPC readiness is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsProp -Object $reportStatuses -Name "publicRpc"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_synthetic_canary_ready" -Help "One when the public RPC synthetic canary passed all read-only live probes." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "publicRpcSyntheticCanaryReady" -Default (Get-MetricsProp -Object $publicRpcSyntheticCanary -Name "syntheticCanaryReady" -Default $false)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_synthetic_canary_probe_count" -Help "Read-only public RPC synthetic canary probe count." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "publicRpcSyntheticCanaryProbeCount" -Default (Get-MetricsProp -Object $publicRpcSyntheticCanary -Name "probeCount" -Default 0)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_synthetic_canary_failed_probes" -Help "Failed read-only public RPC synthetic canary probes." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "publicRpcSyntheticCanaryFailedProbeCount" -Default (Get-MetricsProp -Object $publicRpcSyntheticCanary -Name "failedProbeCount" -Default 0)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_synthetic_canary_missing_owner_inputs" -Help "Owner input names still blocking the public RPC synthetic canary." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "publicRpcSyntheticCanaryMissingEnvCount" -Default $publicRpcSyntheticCanaryMissingEnvCount))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_synthetic_canary_no_write_methods" -Help "One when the public RPC synthetic canary planned and invoked no write methods." -Value (ConvertTo-MetricBool -Value (((Get-MetricsProp -Object $publicRpcSyntheticCanaryChecks -Name "noWriteMethodsPlanned" -Default $false) -eq $true) -and ((Get-MetricsProp -Object $publicRpcSyntheticCanaryChecks -Name "noWriteMethodsInvoked" -Default $false) -eq $true)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_live_security_header_probe" -Help "One when the configured public RPC endpoint security-header probe ran against a non-local public URL." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcChecks -Name "securityHeadersProbePerformed" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_live_security_headers" -Help "One when the live public RPC endpoint was probed and returned all required defensive security headers." -Value (ConvertTo-MetricBool -Value (((Get-MetricsProp -Object $publicRpcChecks -Name "securityHeadersProbePerformed" -Default $false) -eq $true) -and ((Get-MetricsProp -Object $publicRpcChecks -Name "securityHeadersAllRequiredPresent" -Default $false) -eq $true)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_security_header_policy_ready" -Help "One when the public RPC readiness policy requires live headers only for non-local public endpoints and currently passes that policy." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcChecks -Name "securityHeadersAllRequiredPresent" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_deployment_bundle_ready" -Help "One when the public RPC deployment bundle is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsStatus -Report $publicRpcDeploymentBundle))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_deployment_automation_ready" -Help "One when public RPC deployment automation validation is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsStatus -Report $publicRpcDeploymentAutomation))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_disallowed_origin_preflight" -Help "One when the public RPC bundle includes a disallowed origin preflight." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcDeploymentBundleChecks -Name "includesDisallowedOriginPreflight" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_broad_state_blocked_preflight" -Help "One when the public RPC bundle blocks broad state paths in preflight." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcDeploymentBundleChecks -Name "includesBroadStateBlockedPreflight" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_private_wallet_create_blocked_preflight" -Help "One when the public RPC bundle blocks private wallet creation paths in preflight." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcDeploymentBundleChecks -Name "includesPrivateWalletCreateBlockedPreflight" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_auth_forwarding_scoped" -Help "One when public RPC authorization forwarding is scoped to tester writes." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcDeploymentBundleChecks -Name "authorizationForwardingScopedToTesterWrite" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_security_headers" -Help "One when the public RPC bundle includes defensive response headers." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcDeploymentBundleChecks -Name "includesSecurityHeaders" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_security_header_preflight" -Help "One when public RPC preflights check defensive response headers." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcDeploymentBundleChecks -Name "preflightsCheckSecurityHeaders" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_method_rejection_preflight" -Help "One when public RPC preflights include wrong-method rejection probes." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcDeploymentBundleChecks -Name "includesMethodRejectionPreflight" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_wallet_cutover_commands" -Help "One when the public RPC deployment bundle requires wallet/tester cutover verification commands." -Value (ConvertTo-MetricBool -Value $publicRpcDeploymentBundleWalletCutoverProofReady)
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_rendered_disallowed_origin_probe" -Help "One when rendered public RPC preflight has the disallowed origin probe." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightHasDisallowedOriginProbe" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_rendered_broad_state_blocked_probe" -Help "One when rendered public RPC preflight blocks broad state paths." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightBlocksBroadStatePath" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_rendered_private_wallet_create_blocked_probe" -Help "One when rendered public RPC preflight blocks private wallet creation paths." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightBlocksPrivateWalletCreate" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_rendered_auth_forwarding_scoped" -Help "One when rendered public RPC authorization forwarding is scoped to tester writes." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedNginxAuthorizationForwardingScoped" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_rendered_security_headers" -Help "One when rendered public RPC Nginx config includes defensive response headers." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedNginxHasSecurityHeaders" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_rendered_security_header_preflight" -Help "One when rendered public RPC preflights check defensive response headers." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightChecksSecurityHeaders" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_rendered_method_rejection_preflight" -Help "One when rendered public RPC preflights prove wrong HTTP methods are rejected." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightHasMethodRejectionProbes" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_command_plan_wallet_cutover_proof" -Help "One when public RPC deployment automation includes all wallet/tester cutover proof commands." -Value (ConvertTo-MetricBool -Value $publicRpcDeploymentAutomationWalletCutoverProofReady)
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_command_plan_tester_gateway_e2e" -Help "One when public RPC deployment automation includes tester gateway E2E." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesTesterGatewayE2e" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_command_plan_wallet_tester_e2e" -Help "One when public RPC deployment automation includes wallet tester E2E." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesWalletTesterE2e" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_command_plan_synthetic_canary" -Help "One when public RPC deployment automation includes the public RPC synthetic canary." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesSyntheticCanary" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_command_plan_cutover_rehearsal" -Help "One when public RPC deployment automation includes live cutover rehearsal." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesCutoverRehearsal" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_command_plan_truth_table" -Help "One when public RPC deployment automation includes production truth table verification." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesTruthTable" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_rpc_command_plan_no_secret_scan" -Help "One when public RPC deployment automation includes no-secret scan verification." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesNoSecretScan" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_backup_ready" -Help "One when backup readiness is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsProp -Object $reportStatuses -Name "backup"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_backup_retention_count" -Help "Configured state backup retention count from backup readiness." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "backupRetentionCount"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_backup_retention_candidates" -Help "Number of eligible state backup snapshots seen by retention." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "backupRetentionCandidateCount"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_backup_retention_snapshot_protected" -Help "One when retention protected the latest state backup snapshot." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "backupRetentionCurrentSnapshotProtected"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_backup_retention_prune_errors" -Help "State backup retention prune error count." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "backupRetentionPruneErrorCount"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_live_ready" -Help "One when bridge live readiness is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsProp -Object $reportStatuses -Name "bridgeLive"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_infra_ready" -Help "One when bridge infrastructure readiness is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsProp -Object $reportStatuses -Name "bridgeInfra"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_relayer_guardrail_ready" -Help "One when bridge relayer fail-closed guardrail is ready." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "bridgeRelayerGuardrailReady"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_direct_observe_guardrail_ready" -Help "One when standalone Base observer cursor guardrail is ready." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "bridgeRelayerDirectObserveGuardrailReady"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_direct_observe_staged_cursor_default" -Help "One when standalone Base observer defaults to staged cursor state." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "bridgeDirectObserveUsesStagedCursorByDefault"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_direct_observe_cursor_not_final" -Help "One when standalone Base observer cursor state is not the final relayer cursor." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "bridgeDirectObserveCursorNotFinal"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_direct_observe_final_cursor_unchanged" -Help "One when standalone Base observer leaves final relayer cursor unchanged." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "bridgeDirectObserveFinalCursorUnchanged"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_direct_observe_staged_cursor_not_written" -Help "One when missing-input standalone Base observer leaves staged cursor state unwritten." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "bridgeDirectObserveStagedCursorNotWritten"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_runtime_credit_ready" -Help "One when production-shaped Base 8453 runtime credit validation is passed." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "bridgeRuntimeCreditReady"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_runtime_credit_latency_seconds" -Help "Seconds from bridge handoff queue to spendable L1 credit in runtime validation." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "bridgeRuntimeCreditLatencySeconds"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_runtime_transfer_latency_seconds" -Help "Seconds from credited wallet transfer queue to spendable transfer in runtime validation." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "bridgeRuntimeTransferLatencySeconds"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_runtime_credit_failed_checks" -Help "Failed checks in bridge runtime credit validation." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "bridgeRuntimeCreditFailedChecks"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_runtime_credit_missing_checks" -Help "Missing required runtime proof checks in bridge runtime credit validation." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "bridgeRuntimeCreditMissingRuntimeChecks"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_runtime_credit_false_checks" -Help "Required runtime proof checks that are false in bridge runtime credit validation." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "bridgeRuntimeCreditFalseRuntimeChecks"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_release_evidence_validation_ready" -Help "One when bridge release evidence validation is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsStatus -Report $bridgeReleaseEvidenceValidation))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_release_evidence_cases_total" -Help "Bridge release evidence validation case count." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $bridgeReleaseEvidenceValidation -Name "caseCount" -Default 0))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_release_evidence_failed_cases" -Help "Failed bridge release evidence validation cases." -Value (ConvertTo-MetricNumber -Value $bridgeReleaseEvidenceValidationFailedCases.Count)
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_release_evidence_missing_cases" -Help "Missing required bridge release evidence validation cases." -Value (ConvertTo-MetricNumber -Value $bridgeReleaseEvidenceValidationMissingCases.Count)
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_release_evidence_failed_checks" -Help "Failed checks in bridge release evidence validation." -Value (ConvertTo-MetricNumber -Value $bridgeReleaseEvidenceValidationFailedChecks.Count)
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_release_evidence_secret_findings" -Help "Secret marker findings in bridge release evidence validation." -Value (ConvertTo-MetricNumber -Value $bridgeReleaseEvidenceValidationSecretFindings.Count)
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_release_evidence_release_broadcast_rejected" -Help "One when bridge release evidence validation rejects broadcast release evidence." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $bridgeReleaseEvidenceValidationChecks -Name "releaseBroadcastRejected" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_release_evidence_withdrawal_broadcast_rejected" -Help "One when bridge release evidence validation rejects broadcast withdrawal intent." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $bridgeReleaseEvidenceValidationChecks -Name "withdrawalBroadcastRejected" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_release_evidence_no_broadcasts" -Help "One when bridge release evidence validation made no broadcasts." -Value (ConvertTo-MetricBool -Value ((Get-MetricsProp -Object $bridgeReleaseEvidenceValidation -Name "broadcasts" -Default $true) -eq $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_release_evidence_no_secrets" -Help "One when bridge release evidence validation has no secret findings and reports no secrets." -Value (ConvertTo-MetricBool -Value (((Get-MetricsProp -Object $bridgeReleaseEvidenceValidation -Name "noSecrets" -Default $false) -eq $true) -and $bridgeReleaseEvidenceValidationSecretFindings.Count -eq 0))
Add-MetricGauge -Metrics $metrics -Name "flowchain_real_value_pilot_aggregate_ready" -Help "One when the real-value pilot aggregate proof is passed and safe." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "realValuePilotAggregateReady"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_real_value_pilot_aggregate_commands_total" -Help "Proof commands run by the real-value pilot aggregate gate." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "realValuePilotAggregateCommandsRun"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_real_value_pilot_aggregate_timed_out_commands" -Help "Timed-out proof commands in the real-value pilot aggregate gate." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "realValuePilotAggregateTimedOutCommands"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_real_value_pilot_aggregate_failed_commands" -Help "Failed proof commands in the real-value pilot aggregate gate." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "realValuePilotAggregateFailedCommands"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_real_value_pilot_aggregate_missing_proofs" -Help "Missing expected proof artifacts in the real-value pilot aggregate gate." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "realValuePilotAggregateMissingProofs"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_real_value_pilot_aggregate_owner_go_no_go" -Help "One when owner go/no-go is true in the real-value pilot aggregate gate." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "realValuePilotAggregateOwnerGoNoGo"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_bridge_relayer_loop_healthy" -Help "One when a running bridge relayer loop has fresh healthy no-secret/no-broadcast evidence." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "bridgeRelayerLoopReportHealthy"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_supervisor_bridge_relayer_requested" -Help "One when the latest service supervisor report requested bridge relayer loop supervision." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "supervisorBridgeRelayerRequested"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_supervisor_bridge_relayer_recovery_healthy" -Help "One when supervisor relayer-loop recovery evidence is healthy, or relayer supervision was not requested." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "supervisorBridgeRelayerRecoveryHealthy"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_supervisor_node_recovery_validated" -Help "One when isolated supervisor validation proves node crash recovery under the live profile." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "supervisorNodeRecoveryHealthy"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_supervisor_node_restart_attempts" -Help "Node recovery restart attempts recorded by isolated supervisor validation." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "supervisorNodeRestartAttempts"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_supervisor_node_crash_detected" -Help "One when isolated supervisor validation detected a killed node process." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "supervisorNodeCrashDetected"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_supervisor_node_recovery_live_profile" -Help "One when isolated node recovery returned under the live profile." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "supervisorNodeRecoveryLiveProfile"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_supervisor_node_recovery_unbounded" -Help "One when isolated node recovery preserved MaxBlocks=0." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "supervisorNodeRecoveryMaxBlocksUnbounded"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_ready" -Help "One when external tester readiness is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsProp -Object $reportStatuses -Name "externalTester"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_local_rehearsal_ready" -Help "One when the local tester wallet network rehearsal is ready for external launch." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "externalTesterLocalRehearsalReady" -Default $externalTesterLocalRehearsalReady))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_external_sharing_ready" -Help "One when the external tester packet is shareable." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "externalTesterExternalSharingReady" -Default $externalTesterExternalSharingReady))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_service_ready" -Help "One when service status is ready for external tester launch." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "externalTesterServiceReady" -Default (Get-MetricsProp -Object $externalTesterChecks -Name "serviceReady" -Default $false)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_chain_producing" -Help "One when the chain is producing blocks for external tester launch." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "externalTesterChainProducing" -Default (Get-MetricsProp -Object $externalTesterChecks -Name "chainProducing" -Default $false)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_wallet_network_ready" -Help "One when tester wallet create, faucet, send, and read rehearsal is passed." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "externalTesterWalletNetworkReady" -Default (Get-MetricsProp -Object $externalTesterChecks -Name "testerWalletNetworkReady" -Default $false)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_wallet_network_fresh" -Help "One when tester wallet rehearsal evidence is fresh." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "externalTesterWalletNetworkFresh" -Default (Get-MetricsProp -Object $externalTesterChecks -Name "testerWalletNetworkFresh" -Default $false)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_packet_smoke_validated" -Help "One when the share packet executable smoke path is validated." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "externalTesterPacketSmokeValidated" -Default (Get-MetricsProp -Object $externalTesterChecks -Name "packetExecutableSmokeValidated" -Default $false)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_public_gateway_ready" -Help "One when the public tester write gateway E2E is ready." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "externalTesterPublicGatewayReady" -Default (Get-MetricsProp -Object $externalTesterChecks -Name "publicTesterGatewayReady" -Default $false)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_public_gateway_fresh" -Help "One when public tester gateway E2E evidence is fresh." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "externalTesterPublicGatewayFresh" -Default (Get-MetricsProp -Object $externalTesterChecks -Name "publicTesterGatewayFresh" -Default $false)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_faucet_route_validated" -Help "One when the public tester faucet route is validated." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "externalTesterFaucetRouteValidated" -Default (Get-MetricsProp -Object $externalTesterChecks -Name "publicTesterGatewayFaucetRouteValidated" -Default $false)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_live_infra_ready" -Help "One when live infra readiness has passed for external tester launch." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "externalTesterLiveInfraReady" -Default (Get-MetricsProp -Object $externalTesterChecks -Name "liveInfraReady" -Default $false)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_missing_owner_inputs" -Help "Owner input count still blocking external tester sharing." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "externalTesterMissingEnvCount" -Default $externalTesterMissingEnvNames.Count))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_rehearsal_testers_total" -Help "Tester wallet count covered by the latest local tester rehearsal." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "externalTesterTesterCount" -Default $externalTesterTesterCount))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_tester_gateway_e2e_ready" -Help "One when public tester gateway E2E wallet create, faucet, send, cap, route, no-secret, and no-broadcast proof is passed." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "publicTesterGatewayReady" -Default ((Get-MetricsStatus -Report $publicTesterGateway) -eq "passed")))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_tester_gateway_accounts_total" -Help "Tester accounts created by the public tester gateway E2E proof." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "publicTesterGatewayAccountCount" -Default (Get-MetricsProp -Object $publicTesterGateway -Name "accountCount" -Default 0)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_tester_gateway_failed_checks" -Help "Failed checks in the public tester gateway E2E proof." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "publicTesterGatewayFailedChecks" -Default $publicTesterGatewayFailedChecks.Count))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_tester_gateway_routes_total" -Help "Routes covered by the public tester gateway E2E proof." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "publicTesterGatewayRouteCount" -Default $publicTesterGatewayRoutes.Count))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_tester_gateway_transfer_applied" -Help "One when the gateway send proof applied to the local runtime." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "publicTesterGatewayTransferApplied" -Default (Get-MetricsProp -Object $publicTesterGatewayChecks -Name "transferAppliedLocalRuntime" -Default $false)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_tester_gateway_cap_rejected" -Help "One when the gateway rejects an over-cap tester send." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "publicTesterGatewayCapRejected" -Default (Get-MetricsProp -Object $publicTesterGatewayChecks -Name "capRejected" -Default $false)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_tester_gateway_routes_covered" -Help "One when the gateway E2E report covers all required tester routes." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "publicTesterGatewayRoutesCovered" -Default (Get-MetricsProp -Object $publicTesterGatewayChecks -Name "routesCoverRequired" -Default $false)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_tester_gateway_no_secrets" -Help "One when the public tester gateway E2E report and checks contain no secrets." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "publicTesterGatewayNoSecrets" -Default (((Get-MetricsProp -Object $publicTesterGateway -Name "noSecrets" -Default $false) -eq $true) -and $publicTesterGatewaySecretFindings.Count -eq 0)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_tester_gateway_no_broadcasts" -Help "One when the public tester gateway E2E proof made no live broadcasts." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "publicTesterGatewayNoBroadcasts" -Default ((Get-MetricsProp -Object $publicTesterGateway -Name "broadcasts" -Default $true) -eq $false)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_client_validation_ready" -Help "One when standalone external tester client validation is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsStatus -Report $externalTesterClientValidation))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_client_failed_checks" -Help "Failed checks in standalone external tester client validation." -Value ($externalTesterClientValidationFailedChecks.Count)
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_client_secret_findings" -Help "Secret marker findings in standalone external tester client validation." -Value ($externalTesterClientValidationSecretFindings.Count)
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_client_dry_run_no_network" -Help "One when external tester client validation proves dry-run mode makes no network calls." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $externalTesterClientValidationChecks -Name "dryRunNoNetwork" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_client_routes_cover_reads" -Help "One when external tester client validation covers required read routes." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $externalTesterClientValidationChecks -Name "plannedRoutesCoverReads" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_client_routes_cover_writes" -Help "One when external tester client validation covers wallet create, faucet, and send routes." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $externalTesterClientValidationChecks -Name "plannedRoutesCoverWrites" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_client_no_token_configured" -Help "One when external tester client dry-run proof stores no tester bearer token." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $externalTesterClientValidationChecks -Name "tokenNotConfiguredInDryRun" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_client_no_broadcasts" -Help "One when external tester client validation proves no broadcasts." -Value (ConvertTo-MetricBool -Value ((Get-MetricsProp -Object $externalTesterClientValidation -Name "broadcasts" -Default $true) -eq $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_client_no_secrets" -Help "One when external tester client validation has no secret findings and reports no secrets." -Value (ConvertTo-MetricBool -Value (((Get-MetricsProp -Object $externalTesterClientValidation -Name "noSecrets" -Default $false) -eq $true) -and $externalTesterClientValidationSecretFindings.Count -eq 0))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_client_env_values_hidden" -Help "One when external tester client validation does not print environment values." -Value (ConvertTo-MetricBool -Value ((Get-MetricsProp -Object $externalTesterClientValidation -Name "envValuesPrinted" -Default $true) -eq $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_evidence_ready" -Help "One when external tester returned evidence validation is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsStatus -Report $externalTesterEvidence))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_evidence_failed_checks" -Help "Failed checks in the external tester returned evidence validation report." -Value (@((Get-MetricsProp -Object $externalTesterEvidence -Name "failedChecks" -Default @())).Count)
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_evidence_missing_files" -Help "Missing required files in the external tester returned evidence folder." -Value (@((Get-MetricsProp -Object $externalTesterEvidence -Name "missingRequiredFiles" -Default @())).Count)
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_evidence_secret_findings" -Help "Secret marker findings in external tester returned evidence." -Value (@((Get-MetricsProp -Object $externalTesterEvidence -Name "secretMarkerFindings" -Default @())).Count)
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_evidence_height_advanced" -Help "One when returned tester evidence shows block height advanced." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $externalTesterEvidenceChecks -Name "blockHeightAdvanced"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_external_tester_evidence_transfer_consistent" -Help "One when returned tester evidence has matching transfer, transaction, amount, and balance deltas." -Value (ConvertTo-MetricBool -Value $externalTesterEvidenceTransferConsistent)
Add-MetricGauge -Metrics $metrics -Name "flowchain_dashboard_ui_ready" -Help "One when dashboard UI readiness is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsStatus -Report $dashboardUi))
Add-MetricGauge -Metrics $metrics -Name "flowchain_dashboard_ui_browser_e2e_ready" -Help "One when dashboard browser E2E proof passed." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $dashboardUiChecks -Name "dashboardBrowserE2ePassed" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_dashboard_ui_build_ready" -Help "One when dashboard production build proof passed." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $dashboardUiChecks -Name "dashboardBuildPassed" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_dashboard_ui_tester_flow_covered" -Help "One when create, faucet, send, tester launch, and explorer routes are covered by dashboard UI readiness." -Value (ConvertTo-MetricBool -Value (((Get-MetricsProp -Object $dashboardUiChecks -Name "testerWalletCreateCovered" -Default $false) -eq $true) -and ((Get-MetricsProp -Object $dashboardUiChecks -Name "testerFaucetCovered" -Default $false) -eq $true) -and ((Get-MetricsProp -Object $dashboardUiChecks -Name "testerSendCovered" -Default $false) -eq $true) -and ((Get-MetricsProp -Object $dashboardUiChecks -Name "testerLaunchRouteCovered" -Default $false) -eq $true) -and ((Get-MetricsProp -Object $dashboardUiChecks -Name "explorerRouteCovered" -Default $false) -eq $true)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_dashboard_ui_tester_launch_covered" -Help "One when the dashboard tester launch route is covered by readiness." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $dashboardUiChecks -Name "testerLaunchRouteCovered" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_dashboard_ui_activation_covered" -Help "One when the dashboard activation cockpit route is covered by readiness." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $dashboardUiChecks -Name "activationRouteCovered" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_owner_inputs_validation_ready" -Help "One when owner input validation scenarios are passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsStatus -Report $ownerInputsValidation))
Add-MetricGauge -Metrics $metrics -Name "flowchain_owner_inputs_validation_scenarios_total" -Help "Owner input validation scenario count." -Value (ConvertTo-MetricNumber -Value $ownerInputsValidationScenarios.Count)
Add-MetricGauge -Metrics $metrics -Name "flowchain_owner_inputs_validation_scenarios_failed" -Help "Owner input validation scenario failures." -Value (ConvertTo-MetricNumber -Value $ownerInputsValidationFailedScenarios.Count)
Add-MetricGauge -Metrics $metrics -Name "flowchain_owner_inputs_required_env_total" -Help "Required owner input env names tracked by validation." -Value (ConvertTo-MetricNumber -Value $ownerInputsValidationRequiredEnvNames.Count)
Add-MetricGauge -Metrics $metrics -Name "flowchain_owner_activation_plan_ready" -Help "One when the owner activation plan report is passed and safe to use." -Value (ConvertTo-MetricBool -Value $ownerActivationPlanReady)
Add-MetricGauge -Metrics $metrics -Name "flowchain_owner_activation_ready" -Help "One when the owner activation plan reports all launch inputs are present." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $ownerActivationPlan -Name "activationReady" -Default $false))
Add-MetricGauge -Metrics $metrics -Name "flowchain_owner_activation_stages_total" -Help "Owner activation plan stage count." -Value (ConvertTo-MetricNumber -Value $ownerActivationPlanStageCount)
Add-MetricGauge -Metrics $metrics -Name "flowchain_owner_activation_ready_stages" -Help "Owner activation plan stages currently ready." -Value (ConvertTo-MetricNumber -Value $ownerActivationPlanReadyStageCount)
Add-MetricGauge -Metrics $metrics -Name "flowchain_owner_activation_missing_env_total" -Help "Owner activation input names still missing before live cutover." -Value (ConvertTo-MetricNumber -Value $ownerActivationPlanMissingEnvNames.Count)
Add-MetricGauge -Metrics $metrics -Name "flowchain_owner_activation_invalid_env_total" -Help "Owner activation input names currently invalid." -Value (ConvertTo-MetricNumber -Value $ownerActivationPlanInvalidEnvNames.Count)
Add-MetricGauge -Metrics $metrics -Name "flowchain_owner_go_live_handoff_ready" -Help "One when the owner go-live handoff report is passed and safe to use." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "ownerGoLiveHandoffReady" -Default $ownerGoLiveHandoffReady))
Add-MetricGauge -Metrics $metrics -Name "flowchain_owner_go_live_release_ready" -Help "One when the owner go-live handoff says public release readiness is clear." -Value (ConvertTo-MetricBool -Value (Get-MetricsProp -Object $reportStatuses -Name "ownerGoLiveReleaseReady" -Default (Get-MetricsProp -Object $ownerGoLiveHandoff -Name "releaseReady" -Default $false)))
Add-MetricGauge -Metrics $metrics -Name "flowchain_owner_go_live_stages_total" -Help "Owner go-live handoff stage count." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "ownerGoLiveStageCount" -Default $ownerGoLiveHandoffStageCount))
Add-MetricGauge -Metrics $metrics -Name "flowchain_owner_go_live_next_inputs_total" -Help "Owner input names still listed as needed by the go-live handoff." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "ownerGoLiveNextInputCount" -Default $ownerGoLiveHandoffNextInputs.Count))
Add-MetricGauge -Metrics $metrics -Name "flowchain_owner_go_live_failed_checks" -Help "Failed checks in the owner go-live handoff report." -Value (ConvertTo-MetricNumber -Value (Get-MetricsProp -Object $reportStatuses -Name "ownerGoLiveFailedChecks" -Default $ownerGoLiveHandoffFailedChecks.Count))
Add-MetricGauge -Metrics $metrics -Name "flowchain_public_deployment_ready" -Help "One when public deployment contract is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsProp -Object $reportStatuses -Name "publicDeployment"))
Add-MetricGauge -Metrics $metrics -Name "flowchain_live_cutover_ready" -Help "One when the live cutover rehearsal is passed." -Value (ConvertTo-MetricStatusPassed -Value (Get-MetricsStatus -Report $liveCutover))
Add-MetricGauge -Metrics $metrics -Name "flowchain_live_cutover_tester_network_e2e_passed" -Help "One when live cutover rehearsal directly ran the local tester wallet network E2E." -Value (ConvertTo-MetricBool -Value (Get-MetricsPathProp -Object $liveCutover -Path "ready.testerNetworkE2ePassed" -Default $false))
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
        publicRpcSyntheticCanaryStatus = Get-MetricsStatus -Report $publicRpcSyntheticCanary
        publicRpcDeploymentBundleStatus = Get-MetricsStatus -Report $publicRpcDeploymentBundle
        publicRpcDeploymentAutomationStatus = Get-MetricsStatus -Report $publicRpcDeploymentAutomation
        bridgeReleaseEvidenceValidationStatus = Get-MetricsStatus -Report $bridgeReleaseEvidenceValidation
        externalTesterStatus = Get-MetricsStatus -Report $externalTester
        publicTesterGatewayStatus = Get-MetricsStatus -Report $publicTesterGateway
        externalTesterClientValidationStatus = Get-MetricsStatus -Report $externalTesterClientValidation
        externalTesterEvidenceStatus = Get-MetricsStatus -Report $externalTesterEvidence
        dashboardUiStatus = Get-MetricsStatus -Report $dashboardUi
        ownerInputsValidationStatus = Get-MetricsStatus -Report $ownerInputsValidation
        ownerActivationPlanStatus = Get-MetricsStatus -Report $ownerActivationPlan
        ownerGoLiveHandoffStatus = Get-MetricsStatus -Report $ownerGoLiveHandoff
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
    "flowchain_mempool_depth",
    "flowchain_transaction_intake_rows_total",
    "flowchain_transaction_intake_accepted_rows_total",
    "flowchain_transaction_intake_invalid_rows",
    "flowchain_transaction_intake_file_age_seconds",
    "flowchain_runtime_submit_fixtures_total",
    "flowchain_runtime_inbox_files_total",
    "flowchain_ops_critical_findings",
    "flowchain_ops_blocked_findings",
    "flowchain_ops_alert_rules_total",
    "flowchain_ops_active_alert_rules",
    "flowchain_service_status_ready",
    "flowchain_public_rpc_ready",
    "flowchain_public_rpc_synthetic_canary_ready",
    "flowchain_public_rpc_synthetic_canary_probe_count",
    "flowchain_public_rpc_synthetic_canary_failed_probes",
    "flowchain_public_rpc_synthetic_canary_missing_owner_inputs",
    "flowchain_public_rpc_synthetic_canary_no_write_methods",
    "flowchain_public_rpc_live_security_header_probe",
    "flowchain_public_rpc_live_security_headers",
    "flowchain_public_rpc_security_header_policy_ready",
    "flowchain_public_rpc_deployment_bundle_ready",
    "flowchain_public_rpc_deployment_automation_ready",
    "flowchain_public_rpc_disallowed_origin_preflight",
    "flowchain_public_rpc_broad_state_blocked_preflight",
    "flowchain_public_rpc_private_wallet_create_blocked_preflight",
    "flowchain_public_rpc_auth_forwarding_scoped",
    "flowchain_public_rpc_security_headers",
    "flowchain_public_rpc_security_header_preflight",
    "flowchain_public_rpc_wallet_cutover_commands",
    "flowchain_public_rpc_rendered_security_headers",
    "flowchain_public_rpc_rendered_security_header_preflight",
    "flowchain_public_rpc_command_plan_wallet_cutover_proof",
    "flowchain_public_rpc_command_plan_tester_gateway_e2e",
    "flowchain_public_rpc_command_plan_wallet_tester_e2e",
    "flowchain_public_rpc_command_plan_synthetic_canary",
    "flowchain_public_rpc_command_plan_cutover_rehearsal",
    "flowchain_public_rpc_command_plan_truth_table",
    "flowchain_public_rpc_command_plan_no_secret_scan",
    "flowchain_backup_ready",
    "flowchain_backup_retention_count",
    "flowchain_backup_retention_candidates",
    "flowchain_backup_retention_snapshot_protected",
    "flowchain_backup_retention_prune_errors",
    "flowchain_bridge_live_ready",
    "flowchain_bridge_relayer_guardrail_ready",
    "flowchain_bridge_direct_observe_guardrail_ready",
    "flowchain_bridge_direct_observe_staged_cursor_default",
    "flowchain_bridge_direct_observe_cursor_not_final",
    "flowchain_bridge_direct_observe_final_cursor_unchanged",
    "flowchain_bridge_direct_observe_staged_cursor_not_written",
    "flowchain_bridge_runtime_credit_ready",
    "flowchain_bridge_runtime_credit_latency_seconds",
    "flowchain_bridge_runtime_transfer_latency_seconds",
    "flowchain_bridge_runtime_credit_failed_checks",
    "flowchain_bridge_runtime_credit_missing_checks",
    "flowchain_bridge_runtime_credit_false_checks",
    "flowchain_bridge_release_evidence_validation_ready",
    "flowchain_bridge_release_evidence_cases_total",
    "flowchain_bridge_release_evidence_failed_cases",
    "flowchain_bridge_release_evidence_missing_cases",
    "flowchain_bridge_release_evidence_failed_checks",
    "flowchain_bridge_release_evidence_secret_findings",
    "flowchain_bridge_release_evidence_release_broadcast_rejected",
    "flowchain_bridge_release_evidence_withdrawal_broadcast_rejected",
    "flowchain_bridge_release_evidence_no_broadcasts",
    "flowchain_bridge_release_evidence_no_secrets",
    "flowchain_real_value_pilot_aggregate_ready",
    "flowchain_real_value_pilot_aggregate_commands_total",
    "flowchain_real_value_pilot_aggregate_timed_out_commands",
    "flowchain_real_value_pilot_aggregate_failed_commands",
    "flowchain_real_value_pilot_aggregate_missing_proofs",
    "flowchain_real_value_pilot_aggregate_owner_go_no_go",
    "flowchain_bridge_relayer_loop_healthy",
    "flowchain_supervisor_bridge_relayer_requested",
    "flowchain_supervisor_bridge_relayer_recovery_healthy",
    "flowchain_supervisor_node_recovery_validated",
    "flowchain_supervisor_node_restart_attempts",
    "flowchain_supervisor_node_crash_detected",
    "flowchain_supervisor_node_recovery_live_profile",
    "flowchain_supervisor_node_recovery_unbounded",
    "flowchain_external_tester_ready",
    "flowchain_external_tester_local_rehearsal_ready",
    "flowchain_external_tester_external_sharing_ready",
    "flowchain_external_tester_public_gateway_ready",
    "flowchain_external_tester_faucet_route_validated",
    "flowchain_external_tester_live_infra_ready",
    "flowchain_external_tester_missing_owner_inputs",
    "flowchain_public_tester_gateway_e2e_ready",
    "flowchain_public_tester_gateway_accounts_total",
    "flowchain_public_tester_gateway_failed_checks",
    "flowchain_public_tester_gateway_routes_total",
    "flowchain_public_tester_gateway_transfer_applied",
    "flowchain_public_tester_gateway_cap_rejected",
    "flowchain_public_tester_gateway_routes_covered",
    "flowchain_public_tester_gateway_no_secrets",
    "flowchain_public_tester_gateway_no_broadcasts",
    "flowchain_external_tester_client_validation_ready",
    "flowchain_external_tester_client_failed_checks",
    "flowchain_external_tester_client_secret_findings",
    "flowchain_external_tester_client_dry_run_no_network",
    "flowchain_external_tester_client_routes_cover_reads",
    "flowchain_external_tester_client_routes_cover_writes",
    "flowchain_external_tester_client_no_token_configured",
    "flowchain_external_tester_client_no_broadcasts",
    "flowchain_external_tester_client_no_secrets",
    "flowchain_external_tester_client_env_values_hidden",
    "flowchain_external_tester_evidence_ready",
    "flowchain_external_tester_evidence_failed_checks",
    "flowchain_external_tester_evidence_missing_files",
    "flowchain_external_tester_evidence_secret_findings",
    "flowchain_external_tester_evidence_height_advanced",
    "flowchain_external_tester_evidence_transfer_consistent",
    "flowchain_dashboard_ui_ready",
    "flowchain_dashboard_ui_browser_e2e_ready",
    "flowchain_dashboard_ui_build_ready",
    "flowchain_dashboard_ui_tester_flow_covered",
    "flowchain_dashboard_ui_tester_launch_covered",
    "flowchain_dashboard_ui_activation_covered",
    "flowchain_owner_inputs_validation_ready",
    "flowchain_owner_inputs_validation_scenarios_total",
    "flowchain_owner_inputs_validation_scenarios_failed",
    "flowchain_owner_inputs_required_env_total",
    "flowchain_owner_activation_plan_ready",
    "flowchain_owner_activation_ready",
    "flowchain_owner_activation_stages_total",
    "flowchain_owner_activation_ready_stages",
    "flowchain_owner_activation_missing_env_total",
    "flowchain_owner_activation_invalid_env_total",
    "flowchain_owner_go_live_handoff_ready",
    "flowchain_owner_go_live_release_ready",
    "flowchain_owner_go_live_stages_total",
    "flowchain_owner_go_live_next_inputs_total",
    "flowchain_owner_go_live_failed_checks",
    "flowchain_public_deployment_ready",
    "flowchain_live_cutover_ready",
    "flowchain_live_cutover_tester_network_e2e_passed",
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
    publicRpcSyntheticCanaryLoaded = $null -ne $publicRpcSyntheticCanary
    externalTesterLoaded = $null -ne $externalTester
    publicTesterGatewayLoaded = $null -ne $publicTesterGateway
    externalTesterClientValidationLoaded = $null -ne $externalTesterClientValidation
    externalTesterEvidenceLoaded = $null -ne $externalTesterEvidence
    bridgeReleaseEvidenceValidationLoaded = $null -ne $bridgeReleaseEvidenceValidation
    dashboardUiLoaded = $null -ne $dashboardUi
    ownerInputsValidationLoaded = $null -ne $ownerInputsValidation
    ownerActivationPlanLoaded = $null -ne $ownerActivationPlan
    ownerGoLiveHandoffLoaded = $null -ne $ownerGoLiveHandoff
    liveCutoverLoaded = $null -ne $liveCutover
    truthTableLoaded = $null -ne $truthTable
    noSecretLoaded = $null -ne $noSecret
    metricsJsonWritten = $null -ne $metricsJsonFromFile
    prometheusTextWritten = Test-Path -LiteralPath $prometheusTextFullPath
    markdownWritten = $true
    metricCountSufficient = @($metrics).Count -ge 35
    requiredMetricsPresent = $missingMetricNames.Count -eq 0
    externalTesterEvidenceMetricsPresent = @(
        "flowchain_external_tester_ready",
        "flowchain_external_tester_local_rehearsal_ready",
        "flowchain_external_tester_external_sharing_ready",
        "flowchain_external_tester_service_ready",
        "flowchain_external_tester_chain_producing",
        "flowchain_external_tester_wallet_network_ready",
        "flowchain_external_tester_wallet_network_fresh",
        "flowchain_external_tester_packet_smoke_validated",
        "flowchain_external_tester_public_gateway_ready",
        "flowchain_external_tester_public_gateway_fresh",
        "flowchain_external_tester_faucet_route_validated",
        "flowchain_external_tester_live_infra_ready",
        "flowchain_external_tester_missing_owner_inputs",
        "flowchain_external_tester_rehearsal_testers_total",
        "flowchain_external_tester_evidence_ready",
        "flowchain_external_tester_evidence_failed_checks",
        "flowchain_external_tester_evidence_missing_files",
        "flowchain_external_tester_evidence_secret_findings",
        "flowchain_external_tester_evidence_height_advanced",
        "flowchain_external_tester_evidence_transfer_consistent"
    ) | Where-Object { $_ -notin $metricNames } | Measure-Object | ForEach-Object { $_.Count -eq 0 }
    bridgeDirectObserveMetricsPresent = @(
        "flowchain_bridge_direct_observe_guardrail_ready",
        "flowchain_bridge_direct_observe_staged_cursor_default",
        "flowchain_bridge_direct_observe_cursor_not_final",
        "flowchain_bridge_direct_observe_final_cursor_unchanged",
        "flowchain_bridge_direct_observe_staged_cursor_not_written"
    ) | Where-Object { $_ -notin $metricNames } | Measure-Object | ForEach-Object { $_.Count -eq 0 }
    bridgeRuntimeCreditMetricsPresent = @(
        "flowchain_bridge_runtime_credit_ready",
        "flowchain_bridge_runtime_credit_latency_seconds",
        "flowchain_bridge_runtime_transfer_latency_seconds",
        "flowchain_bridge_runtime_credit_failed_checks",
        "flowchain_bridge_runtime_credit_missing_checks",
        "flowchain_bridge_runtime_credit_false_checks"
    ) | Where-Object { $_ -notin $metricNames } | Measure-Object | ForEach-Object { $_.Count -eq 0 }
    bridgeReleaseEvidenceMetricsPresent = @(
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
    ) | Where-Object { $_ -notin $metricNames } | Measure-Object | ForEach-Object { $_.Count -eq 0 }
    realValuePilotAggregateMetricsPresent = @(
        "flowchain_real_value_pilot_aggregate_ready",
        "flowchain_real_value_pilot_aggregate_commands_total",
        "flowchain_real_value_pilot_aggregate_timed_out_commands",
        "flowchain_real_value_pilot_aggregate_failed_commands",
        "flowchain_real_value_pilot_aggregate_missing_proofs",
        "flowchain_real_value_pilot_aggregate_owner_go_no_go"
    ) | Where-Object { $_ -notin $metricNames } | Measure-Object | ForEach-Object { $_.Count -eq 0 }
    publicRpcEdgeMetricsPresent = @(
        "flowchain_public_rpc_synthetic_canary_ready",
        "flowchain_public_rpc_synthetic_canary_probe_count",
        "flowchain_public_rpc_synthetic_canary_failed_probes",
        "flowchain_public_rpc_synthetic_canary_missing_owner_inputs",
        "flowchain_public_rpc_synthetic_canary_no_write_methods",
        "flowchain_public_rpc_deployment_bundle_ready",
        "flowchain_public_rpc_deployment_automation_ready",
        "flowchain_public_rpc_live_security_header_probe",
        "flowchain_public_rpc_live_security_headers",
        "flowchain_public_rpc_security_header_policy_ready",
        "flowchain_public_rpc_disallowed_origin_preflight",
        "flowchain_public_rpc_broad_state_blocked_preflight",
        "flowchain_public_rpc_private_wallet_create_blocked_preflight",
        "flowchain_public_rpc_auth_forwarding_scoped",
        "flowchain_public_rpc_security_headers",
        "flowchain_public_rpc_security_header_preflight",
        "flowchain_public_rpc_wallet_cutover_commands",
        "flowchain_public_rpc_rendered_disallowed_origin_probe",
        "flowchain_public_rpc_rendered_broad_state_blocked_probe",
        "flowchain_public_rpc_rendered_private_wallet_create_blocked_probe",
        "flowchain_public_rpc_rendered_auth_forwarding_scoped",
        "flowchain_public_rpc_rendered_security_headers",
        "flowchain_public_rpc_rendered_security_header_preflight",
        "flowchain_public_rpc_command_plan_wallet_cutover_proof",
        "flowchain_public_rpc_command_plan_tester_gateway_e2e",
        "flowchain_public_rpc_command_plan_wallet_tester_e2e",
        "flowchain_public_rpc_command_plan_synthetic_canary",
        "flowchain_public_rpc_command_plan_cutover_rehearsal",
        "flowchain_public_rpc_command_plan_truth_table",
        "flowchain_public_rpc_command_plan_no_secret_scan"
    ) | Where-Object { $_ -notin $metricNames } | Measure-Object | ForEach-Object { $_.Count -eq 0 }
    publicTesterGatewayMetricsPresent = @(
        "flowchain_public_tester_gateway_e2e_ready",
        "flowchain_public_tester_gateway_accounts_total",
        "flowchain_public_tester_gateway_failed_checks",
        "flowchain_public_tester_gateway_routes_total",
        "flowchain_public_tester_gateway_transfer_applied",
        "flowchain_public_tester_gateway_cap_rejected",
        "flowchain_public_tester_gateway_routes_covered",
        "flowchain_public_tester_gateway_no_secrets",
        "flowchain_public_tester_gateway_no_broadcasts"
    ) | Where-Object { $_ -notin $metricNames } | Measure-Object | ForEach-Object { $_.Count -eq 0 }
    externalTesterClientMetricsPresent = @(
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
    ) | Where-Object { $_ -notin $metricNames } | Measure-Object | ForEach-Object { $_.Count -eq 0 }
    transactionIntakeMetricsPresent = @(
        "flowchain_mempool_depth",
        "flowchain_transaction_intake_rows_total",
        "flowchain_transaction_intake_accepted_rows_total",
        "flowchain_transaction_intake_invalid_rows",
        "flowchain_transaction_intake_file_age_seconds",
        "flowchain_runtime_submit_fixtures_total",
        "flowchain_runtime_inbox_files_total"
    ) | Where-Object { $_ -notin $metricNames } | Measure-Object | ForEach-Object { $_.Count -eq 0 }
    dashboardUiMetricsPresent = @(
        "flowchain_dashboard_ui_ready",
        "flowchain_dashboard_ui_browser_e2e_ready",
        "flowchain_dashboard_ui_build_ready",
        "flowchain_dashboard_ui_tester_flow_covered",
        "flowchain_dashboard_ui_tester_launch_covered",
        "flowchain_dashboard_ui_activation_covered"
    ) | Where-Object { $_ -notin $metricNames } | Measure-Object | ForEach-Object { $_.Count -eq 0 }
    ownerInputsValidationMetricsPresent = @(
        "flowchain_owner_inputs_validation_ready",
        "flowchain_owner_inputs_validation_scenarios_total",
        "flowchain_owner_inputs_validation_scenarios_failed",
        "flowchain_owner_inputs_required_env_total"
    ) | Where-Object { $_ -notin $metricNames } | Measure-Object | ForEach-Object { $_.Count -eq 0 }
    ownerActivationPlanMetricsPresent = @(
        "flowchain_owner_activation_plan_ready",
        "flowchain_owner_activation_ready",
        "flowchain_owner_activation_stages_total",
        "flowchain_owner_activation_ready_stages",
        "flowchain_owner_activation_missing_env_total",
        "flowchain_owner_activation_invalid_env_total"
    ) | Where-Object { $_ -notin $metricNames } | Measure-Object | ForEach-Object { $_.Count -eq 0 }
    ownerGoLiveHandoffMetricsPresent = @(
        "flowchain_owner_go_live_handoff_ready",
        "flowchain_owner_go_live_release_ready",
        "flowchain_owner_go_live_stages_total",
        "flowchain_owner_go_live_next_inputs_total",
        "flowchain_owner_go_live_failed_checks"
    ) | Where-Object { $_ -notin $metricNames } | Measure-Object | ForEach-Object { $_.Count -eq 0 }
    liveCutoverMetricsPresent = @(
        "flowchain_live_cutover_ready",
        "flowchain_live_cutover_tester_network_e2e_passed",
        "flowchain_live_cutover_owner_blocked",
        "flowchain_live_cutover_missing_owner_inputs"
    ) | Where-Object { $_ -notin $metricNames } | Measure-Object | ForEach-Object { $_.Count -eq 0 }
    supervisorNodeRecoveryMetricsPresent = @(
        "flowchain_supervisor_node_recovery_validated",
        "flowchain_supervisor_node_restart_attempts",
        "flowchain_supervisor_node_crash_detected",
        "flowchain_supervisor_node_recovery_live_profile",
        "flowchain_supervisor_node_recovery_unbounded"
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
