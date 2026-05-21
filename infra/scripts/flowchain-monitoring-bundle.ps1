param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/monitoring-bundle-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/MONITORING_BUNDLE.md",
    [string] $BundleDir = "docs/agent-runs/live-product-infra-rpc/monitoring-bundle",
    [string] $MetricsJsonPath = "docs/agent-runs/live-product-infra-rpc/ops-metrics.json",
    [string] $MetricsExportReportPath = "docs/agent-runs/live-product-infra-rpc/ops-metrics-export-report.json",
    [string] $AlertRulesPath = "docs/agent-runs/live-product-infra-rpc/ops-alert-rules-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$bundleFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $BundleDir)
$metricsJsonFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MetricsJsonPath)
$metricsExportReportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MetricsExportReportPath)
$alertRulesFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $AlertRulesPath)

$allowedBundleParent = [System.IO.Path]::GetFullPath((Join-Path $repoRoot "docs/agent-runs/live-product-infra-rpc")).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
)
$allowedBundlePrefix = $allowedBundleParent + [System.IO.Path]::DirectorySeparatorChar
if (-not $bundleFullPath.StartsWith($allowedBundlePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Monitoring bundle output must stay under docs/agent-runs/live-product-infra-rpc."
}
if ($bundleFullPath -eq $allowedBundleParent) {
    throw "Refusing to write the monitoring bundle at the live-product-infra-rpc report root."
}

function Get-MonitoringProp {
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

function Get-MonitoringRelativePath {
    param(
        [Parameter(Mandatory = $true)][string] $BasePath,
        [Parameter(Mandatory = $true)][string] $ChildPath
    )

    $base = [System.IO.Path]::GetFullPath($BasePath).TrimEnd("\", "/")
    $child = [System.IO.Path]::GetFullPath($ChildPath)
    if (-not $child.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside repo."
    }
    return $child.Substring($base.Length).TrimStart("\", "/") -replace '\\', '/'
}

function Test-MonitoringPackageScript {
    param([Parameter(Mandatory = $true)][string] $Name)

    $packageJson = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "package.json") | ConvertFrom-Json
    return $packageJson.scripts.PSObject.Properties.Name -contains $Name
}

function Get-MonitoringSecretMarkerFindings {
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

function ConvertTo-YamlSingleQuoted {
    param([AllowNull()][object] $Value)

    return "'" + ([string]$Value).Replace("'", "''") + "'"
}

function Get-MetricNamesFromExpression {
    param([Parameter(Mandatory = $true)][string] $Expression)

    return @([regex]::Matches($Expression, 'flowchain_[a-z0-9_]+') | ForEach-Object { $_.Value } | Select-Object -Unique)
}

function New-GrafanaPanel {
    param(
        [Parameter(Mandatory = $true)][int] $Id,
        [Parameter(Mandatory = $true)][string] $Title,
        [Parameter(Mandatory = $true)][string] $Expression,
        [Parameter(Mandatory = $true)][int] $X,
        [Parameter(Mandatory = $true)][int] $Y,
        [int] $W = 6,
        [int] $H = 6,
        [string] $Unit = "short",
        [string] $Type = "stat"
    )

    return [ordered]@{
        id = $Id
        title = $Title
        type = $Type
        datasource = [ordered]@{
            type = "prometheus"
            uid = '${DS_PROMETHEUS}'
        }
        gridPos = [ordered]@{
            x = $X
            y = $Y
            w = $W
            h = $H
        }
        targets = @(
            [ordered]@{
                refId = "A"
                expr = $Expression
                legendFormat = $Title
            }
        )
        fieldConfig = [ordered]@{
            defaults = [ordered]@{
                unit = $Unit
                mappings = @()
                thresholds = [ordered]@{
                    mode = "absolute"
                    steps = @(
                        [ordered]@{ color = "red"; value = $null },
                        [ordered]@{ color = "green"; value = 1 }
                    )
                }
            }
            overrides = @()
        }
        options = [ordered]@{
            reduceOptions = [ordered]@{
                values = $false
                calcs = @("lastNotNull")
                fields = ""
            }
            orientation = "auto"
            textMode = "auto"
            colorMode = "value"
            graphMode = "area"
            justifyMode = "auto"
        }
    }
}

function New-PrometheusRule {
    param(
        [Parameter(Mandatory = $true)][string] $Alert,
        [Parameter(Mandatory = $true)][string] $Expression,
        [Parameter(Mandatory = $true)][string] $For,
        [Parameter(Mandatory = $true)][string] $Severity,
        [Parameter(Mandatory = $true)][string[]] $SourceRuleIds,
        [Parameter(Mandatory = $true)][string] $Summary,
        [Parameter(Mandatory = $true)][string[]] $Commands
    )

    return [ordered]@{
        alert = $Alert
        expr = $Expression
        for = $For
        severity = $Severity
        sourceRuleIds = @($SourceRuleIds)
        summary = $Summary
        commands = @($Commands)
    }
}

$metricsJson = Read-FlowChainJsonIfExists -Path $metricsJsonFullPath
$metricsExportReport = Read-FlowChainJsonIfExists -Path $metricsExportReportFullPath
$alertRulesReport = Read-FlowChainJsonIfExists -Path $alertRulesFullPath
if ($null -eq $metricsJson) {
    throw "Ops metrics JSON is missing: $metricsJsonFullPath"
}
if ($null -eq $metricsExportReport) {
    throw "Ops metrics export report is missing: $metricsExportReportFullPath"
}
if ($null -eq $alertRulesReport) {
    throw "Ops alert rules report is missing: $alertRulesFullPath"
}

$metrics = @((Get-MonitoringProp -Object $metricsJson -Name "metrics" -Default @()))
$metricNames = @($metrics | ForEach-Object { [string](Get-MonitoringProp -Object $_ -Name "name" -Default "") } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
$alertRules = @((Get-MonitoringProp -Object $alertRulesReport -Name "rules" -Default @()))
$alertRuleIds = @($alertRules | ForEach-Object { [string](Get-MonitoringProp -Object $_ -Name "id" -Default "") } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)

$dashboardPanels = @(
    New-GrafanaPanel -Id 1 -Title "Latest block height" -Expression "flowchain_latest_height" -X 0 -Y 0 -W 6 -H 5
    New-GrafanaPanel -Id 2 -Title "Finalized block height" -Expression "flowchain_finalized_height" -X 6 -Y 0 -W 6 -H 5
    New-GrafanaPanel -Id 3 -Title "Height advancing" -Expression "flowchain_height_advanced" -X 12 -Y 0 -W 6 -H 5
    New-GrafanaPanel -Id 4 -Title "State file age seconds" -Expression "flowchain_state_file_age_seconds" -X 18 -Y 0 -W 6 -H 5 -Unit "s"
    New-GrafanaPanel -Id 5 -Title "Service ready" -Expression "flowchain_service_status_ready" -X 0 -Y 5 -W 6 -H 5
    New-GrafanaPanel -Id 6 -Title "Supervisor node recovery" -Expression "flowchain_supervisor_node_recovery_validated" -X 6 -Y 5 -W 6 -H 5
    New-GrafanaPanel -Id 7 -Title "Public RPC ready" -Expression "flowchain_public_rpc_ready" -X 12 -Y 5 -W 6 -H 5
    New-GrafanaPanel -Id 8 -Title "Public RPC canary ready" -Expression "flowchain_public_rpc_synthetic_canary_ready" -X 18 -Y 5 -W 6 -H 5
    New-GrafanaPanel -Id 9 -Title "Public RPC hardening" -Expression "min(flowchain_public_rpc_security_headers, flowchain_public_rpc_timeout_guardrails, flowchain_public_rpc_auth_forwarding_scoped)" -X 0 -Y 10 -W 8 -H 5
    New-GrafanaPanel -Id 10 -Title "Backup restore proof" -Expression "flowchain_backup_restore_validation_ready" -X 8 -Y 10 -W 8 -H 5
    New-GrafanaPanel -Id 11 -Title "Backup owner path proof" -Expression "flowchain_backup_owner_path_dry_run_ready" -X 16 -Y 10 -W 8 -H 5
    New-GrafanaPanel -Id 12 -Title "Bridge relayer loop" -Expression "flowchain_bridge_relayer_loop_validation_ready" -X 0 -Y 15 -W 6 -H 5
    New-GrafanaPanel -Id 13 -Title "Bridge reconciliation" -Expression "flowchain_bridge_reconciliation_ready" -X 6 -Y 15 -W 6 -H 5
    New-GrafanaPanel -Id 14 -Title "Bridge guardrail ready" -Expression "flowchain_bridge_relayer_guardrail_ready" -X 12 -Y 15 -W 6 -H 5
    New-GrafanaPanel -Id 15 -Title "External tester local rehearsal" -Expression "flowchain_external_tester_local_rehearsal_ready" -X 18 -Y 15 -W 6 -H 5
    New-GrafanaPanel -Id 16 -Title "Dashboard UI ready" -Expression "flowchain_dashboard_ui_ready" -X 0 -Y 20 -W 6 -H 5
    New-GrafanaPanel -Id 17 -Title "Owner inputs still needed" -Expression "flowchain_owner_needs_now_next_inputs_total" -X 6 -Y 20 -W 6 -H 5
    New-GrafanaPanel -Id 18 -Title "Critical ops findings" -Expression "flowchain_ops_critical_findings" -X 12 -Y 20 -W 6 -H 5
    New-GrafanaPanel -Id 19 -Title "Truth table failures" -Expression "flowchain_truth_gates_failed + flowchain_truth_gates_repo_blocked + flowchain_truth_gates_stale" -X 18 -Y 20 -W 6 -H 5
    New-GrafanaPanel -Id 20 -Title "No-secret scan ready" -Expression "flowchain_no_secret_ready" -X 0 -Y 25 -W 6 -H 5
)

$dashboard = [ordered]@{
    uid = "flowchain-l1-ops"
    title = "FlowChain L1 Operations"
    tags = @("flowchain", "l1", "owner-operated", "no-secret")
    timezone = "browser"
    schemaVersion = 39
    version = 1
    refresh = "30s"
    templating = [ordered]@{
        list = @(
            [ordered]@{
                name = "DS_PROMETHEUS"
                type = "datasource"
                query = "prometheus"
                current = [ordered]@{
                    text = "Prometheus"
                    value = '${DS_PROMETHEUS}'
                }
            }
        )
    }
    panels = @($dashboardPanels)
}

$prometheusRules = @(
    New-PrometheusRule -Alert "FlowChainServiceDown" -Expression "flowchain_service_status_ready == 0" -For "2m" -Severity "critical" -SourceRuleIds @("node-process-down", "control-plane-down") -Summary "FlowChain service status is not ready." -Commands @("npm run flowchain:service:status", "npm run flowchain:service:restart -- -LiveProfile")
    New-PrometheusRule -Alert "FlowChainBlockProductionStalled" -Expression "(flowchain_height_advanced == 0) or (flowchain_latest_height <= 0)" -For "5m" -Severity "critical" -SourceRuleIds @("block-production-stalled") -Summary "FlowChain block height is not advancing." -Commands @("npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30", "npm run flowchain:service:restart -- -LiveProfile")
    New-PrometheusRule -Alert "FlowChainStateFileStale" -Expression "flowchain_state_file_age_seconds > 300" -For "5m" -Severity "critical" -SourceRuleIds @("state-file-stale") -Summary "FlowChain state evidence is stale." -Commands @("npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30", "npm run flowchain:service:restart -- -LiveProfile")
    New-PrometheusRule -Alert "FlowChainPublicRpcNotReady" -Expression "(flowchain_public_rpc_ready == 0) or (flowchain_public_rpc_synthetic_canary_ready == 0)" -For "5m" -Severity "blocked" -SourceRuleIds @("public-rpc-edge-hardening-failed") -Summary "Public RPC is not ready for sharing." -Commands @("npm run flowchain:public-rpc:check -- -AllowBlocked", "npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked")
    New-PrometheusRule -Alert "FlowChainPublicRpcHardeningMissing" -Expression "min(flowchain_public_rpc_security_headers, flowchain_public_rpc_timeout_guardrails, flowchain_public_rpc_auth_forwarding_scoped) == 0" -For "5m" -Severity "critical" -SourceRuleIds @("public-rpc-edge-hardening-failed") -Summary "Public RPC hardening evidence is incomplete." -Commands @("npm run flowchain:public-rpc:deployment-bundle", "npm run flowchain:public-rpc:deployment:automation")
    New-PrometheusRule -Alert "FlowChainBackupRestoreProofMissing" -Expression "(flowchain_backup_restore_validation_ready == 0) or (flowchain_backup_owner_path_dry_run_ready == 0)" -For "10m" -Severity "critical" -SourceRuleIds @("backup-restore-validation-failed", "backup-owner-path-dry-run-failed") -Summary "Backup restore or owner-path proof is not ready." -Commands @("npm run flowchain:backup:restore:validate", "npm run flowchain:backup:owner-path:dry-run")
    New-PrometheusRule -Alert "FlowChainBridgeRelayerUnsafe" -Expression "(flowchain_bridge_relayer_loop_validation_ready == 0) or (flowchain_bridge_relayer_guardrail_ready == 0)" -For "5m" -Severity "critical" -SourceRuleIds @("bridge-relayer-loop-unhealthy", "bridge-relayer-guardrail-failed") -Summary "Bridge relayer loop or guardrail evidence is unsafe." -Commands @("npm run flowchain:bridge:relayer:loop:validate", "npm run flowchain:bridge:relayer:guardrail:validate")
    New-PrometheusRule -Alert "FlowChainBridgeReconciliationFailed" -Expression "flowchain_bridge_reconciliation_ready == 0" -For "10m" -Severity "critical" -SourceRuleIds @("bridge-reconciliation-failed") -Summary "Bridge reconciliation evidence is missing or failing." -Commands @("npm run flowchain:bridge:reconciliation", "npm run flowchain:bridge:emergency-stop")
    New-PrometheusRule -Alert "FlowChainExternalTesterNotShareable" -Expression "(flowchain_external_tester_external_sharing_ready == 0) or (flowchain_external_tester_missing_owner_inputs > 0)" -For "10m" -Severity "blocked" -SourceRuleIds @("external-tester-not-shareable") -Summary "External tester sharing remains blocked." -Commands @("npm run flowchain:external-tester:packet -- -AllowBlocked", "npm run flowchain:external-tester:packet:validate")
    New-PrometheusRule -Alert "FlowChainNoSecretScanFailed" -Expression "flowchain_no_secret_ready == 0" -For "1m" -Severity "critical" -SourceRuleIds @("secret-boundary-breach") -Summary "No-secret scan is not passing." -Commands @("npm run flowchain:no-secret:scan", "npm run flowchain:emergency:export-evidence")
    New-PrometheusRule -Alert "FlowChainTruthTableFailed" -Expression "(flowchain_truth_gates_failed > 0) or (flowchain_truth_gates_repo_blocked > 0) or (flowchain_truth_gates_stale > 0)" -For "1m" -Severity "critical" -SourceRuleIds @("truth-table-stale-or-failed") -Summary "Production truth table has failed, repo-blocked, or stale gates." -Commands @("npm run flowchain:truth-table -- -AllowBlocked", "npm run flowchain:completion:audit -- -AllowBlocked -NoRefresh")
    New-PrometheusRule -Alert "FlowChainOwnerInputsStillBlockingLaunch" -Expression "flowchain_owner_needs_now_next_inputs_total > 0" -For "30m" -Severity "blocked" -SourceRuleIds @("owner-inputs-validation-failed", "owner-go-live-handoff-failed") -Summary "Launch remains blocked on owner-provided inputs." -Commands @("npm run flowchain:owner:needs-now", "npm run flowchain:owner:activation-plan")
)

$dashboardExpressions = @($dashboardPanels | ForEach-Object {
        @((Get-MonitoringProp -Object $_ -Name "targets" -Default @())) | ForEach-Object { [string](Get-MonitoringProp -Object $_ -Name "expr" -Default "") }
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$prometheusExpressions = @($prometheusRules | ForEach-Object { [string](Get-MonitoringProp -Object $_ -Name "expr" -Default "") })
$dashboardMetricNames = @($dashboardExpressions | ForEach-Object { Get-MetricNamesFromExpression -Expression $_ } | Select-Object -Unique)
$prometheusMetricNames = @($prometheusExpressions | ForEach-Object { Get-MetricNamesFromExpression -Expression $_ } | Select-Object -Unique)
$missingDashboardMetricNames = @($dashboardMetricNames | Where-Object { $_ -notin $metricNames })
$missingPrometheusMetricNames = @($prometheusMetricNames | Where-Object { $_ -notin $metricNames })
$prometheusSourceRuleIds = @($prometheusRules | ForEach-Object { @($_.sourceRuleIds) } | Select-Object -Unique)
$missingSourceRuleIds = @($prometheusSourceRuleIds | Where-Object { $_ -notin $alertRuleIds })
$commands = @($prometheusRules | ForEach-Object { @($_.commands) })
$commandsWithInlineEnvAssignment = @($commands | Where-Object { "$_" -match 'FLOWCHAIN_[A-Z0-9_]+\s*=' })
$commandsWithUrls = @($commands | Where-Object { "$_" -match 'https?://' })
$rulesWithoutCommands = @($prometheusRules | Where-Object { @($_.commands).Count -eq 0 } | ForEach-Object { $_.alert })

New-Item -ItemType Directory -Force -Path $bundleFullPath | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $reportFullPath) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null

$dashboardPath = Join-Path $bundleFullPath "flowchain-grafana-dashboard.json"
$prometheusRulesPath = Join-Path $bundleFullPath "flowchain-prometheus-alerts.yml"
$readmePath = Join-Path $bundleFullPath "README.md"
$manifestPath = Join-Path $bundleFullPath "flowchain-monitoring-bundle-manifest.json"

Write-FlowChainJson -Path $dashboardPath -Value $dashboard -Depth 20

$yamlLines = New-Object System.Collections.Generic.List[string]
$yamlLines.Add("groups:")
$yamlLines.Add("  - name: flowchain_l1_ops")
$yamlLines.Add("    rules:")
foreach ($rule in $prometheusRules) {
    $yamlLines.Add("      - alert: $($rule.alert)")
    $yamlLines.Add("        expr: $(ConvertTo-YamlSingleQuoted -Value $rule.expr)")
    $yamlLines.Add("        for: $($rule.for)")
    $yamlLines.Add("        labels:")
    $yamlLines.Add("          severity: $($rule.severity)")
    $yamlLines.Add("          source_rule_ids: $(ConvertTo-YamlSingleQuoted -Value (($rule.sourceRuleIds -join ',')))")
    $yamlLines.Add("        annotations:")
    $yamlLines.Add("          summary: $(ConvertTo-YamlSingleQuoted -Value $rule.summary)")
    $yamlLines.Add("          commands: $(ConvertTo-YamlSingleQuoted -Value (($rule.commands -join '; ')))")
}
$prometheusYaml = ($yamlLines -join "`n") + [Environment]::NewLine
Set-Content -LiteralPath $prometheusRulesPath -Value $prometheusYaml -Encoding UTF8

$readmeLines = New-Object System.Collections.Generic.List[string]
$readmeLines.Add("# FlowChain Monitoring Bundle")
$readmeLines.Add("")
$readmeLines.Add("This bundle turns existing no-secret FlowChain ops evidence into owner-operated monitoring files.")
$readmeLines.Add("")
$readmeLines.Add('- Grafana dashboard: `flowchain-grafana-dashboard.json`')
$readmeLines.Add('- Prometheus alert rules: `flowchain-prometheus-alerts.yml`')
$readmeLines.Add("- Source metrics: ``$MetricsJsonPath``")
$readmeLines.Add("- Source alert rules: ``$AlertRulesPath``")
$readmeLines.Add("")
$readmeLines.Add('Import the dashboard into the owner Grafana workspace with a Prometheus datasource named `DS_PROMETHEUS`. Load the alert rules into the owner Prometheus-compatible rules path. These files contain metric names, thresholds, and commands only.')
$readmeLines.Add("")
$readmeLines.Add("Do not put owner credentials, raw tester tokens, private keys, seed words, provider credentials, or rendered owner env files in this bundle.")
$readmeLines.Add("")
$readmeLines.Add("Regenerate with:")
$readmeLines.Add("")
$readmeLines.Add('```powershell')
$readmeLines.Add("npm run flowchain:ops:monitoring:bundle")
$readmeLines.Add('```')
Set-Content -LiteralPath $readmePath -Value ($readmeLines -join [Environment]::NewLine) -Encoding UTF8

$artifactSeed = @(
    [ordered]@{ name = "grafanaDashboard"; path = $dashboardPath },
    [ordered]@{ name = "prometheusAlertRules"; path = $prometheusRulesPath },
    [ordered]@{ name = "readme"; path = $readmePath }
)
$artifactEntries = New-Object System.Collections.ArrayList
foreach ($artifact in $artifactSeed) {
    $artifactPath = [string]$artifact.path
    [void] $artifactEntries.Add([ordered]@{
        name = $artifact.name
        path = Get-MonitoringRelativePath -BasePath $repoRoot -ChildPath $artifactPath
        sha256 = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
        byteLength = [int64](Get-Item -LiteralPath $artifactPath).Length
    })
}
$manifest = [ordered]@{
    schema = "flowchain.monitoring_bundle_manifest.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    bundleDir = Get-MonitoringRelativePath -BasePath $repoRoot -ChildPath $bundleFullPath
    sourceReports = [ordered]@{
        metricsJson = $MetricsJsonPath
        metricsExportReport = $MetricsExportReportPath
        alertRules = $AlertRulesPath
    }
    artifacts = @($artifactEntries)
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}
Write-FlowChainJson -Path $manifestPath -Value $manifest -Depth 12

$allArtifactPaths = @($dashboardPath, $prometheusRulesPath, $readmePath, $manifestPath)
$secretMarkerFindings = New-Object System.Collections.ArrayList
foreach ($artifactPath in $allArtifactPaths) {
    $text = Get-Content -Raw -LiteralPath $artifactPath
    $relativeArtifactPath = Get-MonitoringRelativePath -BasePath $repoRoot -ChildPath $artifactPath
    Assert-FlowChainNoSecretText -Text $text -Label $relativeArtifactPath
    foreach ($finding in @(Get-MonitoringSecretMarkerFindings -Text $text -Label $relativeArtifactPath)) {
        [void] $secretMarkerFindings.Add($finding)
    }
}

$dashboardRoundTrip = Read-FlowChainJsonIfExists -Path $dashboardPath
$dashboardRoundTripPanels = @((Get-MonitoringProp -Object $dashboardRoundTrip -Name "panels" -Default @()))
$prometheusYamlText = Get-Content -Raw -LiteralPath $prometheusRulesPath
$manifestRoundTrip = Read-FlowChainJsonIfExists -Path $manifestPath
$manifestArtifacts = @((Get-MonitoringProp -Object $manifestRoundTrip -Name "artifacts" -Default @()))
$artifactHashGaps = @($manifestArtifacts | Where-Object { [string]::IsNullOrWhiteSpace([string](Get-MonitoringProp -Object $_ -Name "sha256" -Default "")) } | ForEach-Object { [string](Get-MonitoringProp -Object $_ -Name "name" -Default "") })

$requiredPanelTitles = @(
    "Latest block height",
    "Service ready",
    "Public RPC ready",
    "Backup restore proof",
    "Bridge relayer loop",
    "External tester local rehearsal",
    "Dashboard UI ready",
    "No-secret scan ready"
)
$dashboardPanelTitles = @($dashboardRoundTripPanels | ForEach-Object { [string](Get-MonitoringProp -Object $_ -Name "title" -Default "") })
$missingPanelTitles = @($requiredPanelTitles | Where-Object { $_ -notin $dashboardPanelTitles })

$checks = [ordered]@{
    packageScriptPresent = Test-MonitoringPackageScript -Name "flowchain:ops:monitoring:bundle"
    metricsJsonLoaded = $null -ne $metricsJson
    metricsExportReportLoaded = $null -ne $metricsExportReport
    alertRulesLoaded = $null -ne $alertRulesReport
    sourceMetricsSufficient = $metricNames.Count -ge 50
    sourceAlertRulesSufficient = $alertRuleIds.Count -ge 10
    dashboardWritten = Test-Path -LiteralPath $dashboardPath
    dashboardJsonValid = $null -ne $dashboardRoundTrip
    dashboardPanelCountSufficient = $dashboardRoundTripPanels.Count -ge 12
    dashboardTargetsHaveKnownMetrics = $missingDashboardMetricNames.Count -eq 0
    dashboardIncludesCorePanels = $missingPanelTitles.Count -eq 0
    prometheusRulesWritten = Test-Path -LiteralPath $prometheusRulesPath
    prometheusYamlHasRules = $prometheusYamlText.Contains("groups:") -and $prometheusYamlText.Contains("FlowChainBlockProductionStalled")
    prometheusRuleCountSufficient = $prometheusRules.Count -ge 8
    prometheusRulesReferenceKnownMetrics = $missingPrometheusMetricNames.Count -eq 0
    prometheusRulesReferenceKnownAlertRuleIds = $missingSourceRuleIds.Count -eq 0
    prometheusRulesHaveRunbookCommands = $rulesWithoutCommands.Count -eq 0
    prometheusCommandsAvoidInlineEnvAssignment = $commandsWithInlineEnvAssignment.Count -eq 0
    prometheusCommandsAvoidUrls = $commandsWithUrls.Count -eq 0
    readmeWritten = Test-Path -LiteralPath $readmePath
    manifestWritten = Test-Path -LiteralPath $manifestPath
    artifactHashesPresent = $artifactHashGaps.Count -eq 0
    filesNoSecretMarkers = $secretMarkerFindings.Count -eq 0
    noNetworkDelivery = $true
    envValuesPrintedFalse = $true
    noSecrets = $true
    broadcastsFalse = $true
}
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }

$reportArtifacts = New-Object System.Collections.ArrayList
foreach ($artifactPath in $allArtifactPaths) {
    [void] $reportArtifacts.Add([ordered]@{
        path = Get-MonitoringRelativePath -BasePath $repoRoot -ChildPath $artifactPath
        sha256 = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
        byteLength = [int64](Get-Item -LiteralPath $artifactPath).Length
    })
}

$report = [ordered]@{
    schema = "flowchain.monitoring_bundle_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    bundleDir = $BundleDir
    dashboardPath = Get-MonitoringRelativePath -BasePath $repoRoot -ChildPath $dashboardPath
    prometheusRulesPath = Get-MonitoringRelativePath -BasePath $repoRoot -ChildPath $prometheusRulesPath
    manifestPath = Get-MonitoringRelativePath -BasePath $repoRoot -ChildPath $manifestPath
    sourceMetricCount = $metricNames.Count
    sourceAlertRuleCount = $alertRuleIds.Count
    dashboardPanelCount = $dashboardRoundTripPanels.Count
    prometheusRuleCount = $prometheusRules.Count
    missingDashboardMetricNames = @($missingDashboardMetricNames)
    missingPrometheusMetricNames = @($missingPrometheusMetricNames)
    missingSourceRuleIds = @($missingSourceRuleIds)
    missingPanelTitles = @($missingPanelTitles)
    rulesWithoutCommands = @($rulesWithoutCommands)
    commandsWithInlineEnvAssignment = @($commandsWithInlineEnvAssignment)
    commandsWithUrls = @($commandsWithUrls)
    artifactHashGaps = @($artifactHashGaps)
    artifacts = @($reportArtifacts)
    notificationPlan = [ordered]@{
        storesSecrets = $false
        sendsNetworkNotifications = $false
    }
    checks = $checks
    failedChecks = @($failedChecks)
    secretMarkerFindings = @($secretMarkerFindings)
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 14

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Monitoring Bundle")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This bundle renders owner-operated Grafana and Prometheus files from existing no-secret FlowChain metrics and alert-rule evidence. It does not send network notifications or store external delivery credentials.")
$markdownLines.Add("")
$markdownLines.Add("- Dashboard panels: $($report.dashboardPanelCount)")
$markdownLines.Add("- Prometheus alert rules: $($report.prometheusRuleCount)")
$markdownLines.Add("- Source metrics: $($report.sourceMetricCount)")
$markdownLines.Add("- Source alert rules: $($report.sourceAlertRuleCount)")
$markdownLines.Add("")
$markdownLines.Add("## Artifacts")
$markdownLines.Add("")
$markdownLines.Add("| Artifact | SHA256 | Bytes |")
$markdownLines.Add("| --- | --- | --- |")
foreach ($artifact in $report.artifacts) {
    $markdownLines.Add("| ``$($artifact.path)`` | ``$($artifact.sha256)`` | $($artifact.byteLength) |")
}
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
$markdownLines.Add("| Check | Result |")
$markdownLines.Add("| --- | --- |")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("| $($entry.Key) | $($entry.Value) |")
}
if ($failedChecks.Count -gt 0) {
    $markdownLines.Add("")
    $markdownLines.Add("## Failed Checks")
    $markdownLines.Add("")
    foreach ($check in $failedChecks) {
        $markdownLines.Add("- $check")
    }
}
Set-Content -LiteralPath $markdownFullPath -Value ($markdownLines -join [Environment]::NewLine) -Encoding UTF8

Write-Host "FlowChain monitoring bundle status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Bundle: $bundleFullPath"

if ($status -eq "passed") {
    exit 0
}
exit 1
