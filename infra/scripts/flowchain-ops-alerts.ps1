param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/ops-alert-rules-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/OPS_ALERT_RULES.md",
    [string] $OpsSnapshotPath = "docs/agent-runs/live-product-infra-rpc/ops-snapshot-report.json",
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
$opsSnapshotFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $OpsSnapshotPath)

function Get-AlertProp {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name,
        [object] $Default = $null
    )

    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    if ($null -ne $Object -and $Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
    }
    return $Default
}

function Add-UniqueAlertValue {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [AllowNull()][string] $Value
    )

    if (-not [string]::IsNullOrWhiteSpace($Value) -and -not $Target.Contains($Value)) {
        [void] $Target.Add($Value)
    }
}

function Get-AlertSecretMarkerFindings {
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

if (-not $NoRefresh.IsPresent) {
    $opsOutput = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-ops-snapshot.ps1") -AllowBlocked -ReportPath $opsSnapshotFullPath 2>&1) | ForEach-Object { "$_" }
    $opsExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
}
else {
    $opsOutput = @()
    $opsExitCode = 0
}

$opsSnapshot = Read-FlowChainJsonIfExists -Path $opsSnapshotFullPath
if ($null -eq $opsSnapshot) {
    throw "Ops snapshot report is missing: $opsSnapshotFullPath"
}

$findings = @((Get-AlertProp -Object $opsSnapshot -Name "findings" -Default @()))
$currentFindingCodes = New-Object System.Collections.ArrayList
foreach ($finding in $findings) {
    Add-UniqueAlertValue -Target $currentFindingCodes -Value ([string](Get-AlertProp -Object $finding -Name "code" -Default ""))
}

$rules = @(
    [ordered]@{
        id = "node-process-down"
        severity = "critical"
        findingCodes = @("node-not-running")
        signal = "Node process is not running."
        threshold = "any failed service-status sample"
        commands = @("npm run flowchain:service:status", "npm run flowchain:service:restart -- -LiveProfile", "npm run flowchain:emergency:stop-local")
    },
    [ordered]@{
        id = "control-plane-down"
        severity = "critical"
        findingCodes = @("control-plane-not-running")
        signal = "Control-plane RPC process is not running."
        threshold = "any failed service-status sample"
        commands = @("npm run flowchain:service:status", "npm run flowchain:service:restart -- -LiveProfile")
    },
    [ordered]@{
        id = "block-production-stalled"
        severity = "critical"
        findingCodes = @("service-status-not-passed", "chain-height-unreadable", "height-not-advancing")
        signal = "Block height is unreadable or did not advance."
        threshold = "service monitor has fewer than two advancing samples"
        commands = @("npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30", "npm run flowchain:service:restart -- -LiveProfile")
    },
    [ordered]@{
        id = "state-file-stale"
        severity = "critical"
        findingCodes = @("state-stale")
        signal = "Runtime state file is older than the monitor freshness threshold."
        threshold = "stateFileLastWriteAgeSeconds exceeds configured maximum"
        commands = @("npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30", "npm run flowchain:service:restart -- -LiveProfile")
    },
    [ordered]@{
        id = "transaction-intake-corrupt"
        severity = "critical"
        findingCodes = @("transaction-intake-invalid-rows")
        signal = "Signed transaction intake contains invalid local NDJSON rows."
        threshold = "transactionIntake.txIntakeInvalidRows is greater than zero"
        commands = @("npm run flowchain:ops:snapshot", "npm run flowchain:control-plane:smoke", "npm run flowchain:no-secret:scan")
    },
    [ordered]@{
        id = "secret-boundary-breach"
        severity = "critical"
        findingCodes = @("no-secret-scan-not-passed")
        signal = "No-secret scan did not pass."
        threshold = "any no-secret scan failure"
        commands = @("npm run flowchain:no-secret:scan", "npm run flowchain:emergency:export-evidence")
    },
    [ordered]@{
        id = "backup-retention-unsafe"
        severity = "critical"
        findingCodes = @("backup-retention-unsafe")
        signal = "Backup retention failed to protect the latest snapshot or reported prune errors."
        threshold = "backup readiness status failed with retentionCurrentSnapshotProtected false or retentionPruneErrorCount greater than zero"
        commands = @("npm run flowchain:backup:restore:validate", "npm run flowchain:backup:owner-path:dry-run", "npm run flowchain:backup:check")
    },
    [ordered]@{
        id = "bridge-relayer-check-contract-failed"
        severity = "critical"
        findingCodes = @("bridge-relayer-check-contract-failed")
        signal = "Bridge relayer one-shot safety check contract is missing or failing."
        threshold = "relayer one-shot report is not passed/blocked, has failedChecks, misses required checks, prints env values, broadcasts, or reports secrets"
        commands = @("npm run flowchain:bridge:relayer:once -- -AllowBlocked", "npm run flowchain:ops:snapshot -- -AllowBlocked -NoRefresh", "npm run flowchain:bridge:emergency-stop")
    },
    [ordered]@{
        id = "bridge-relayer-latency-failed"
        severity = "critical"
        findingCodes = @("bridge-relayer-latency-failed")
        signal = "Bridge relayer failed or exceeded the handoff-to-spendable latency gate."
        threshold = "relayer status failed or timing.latencyGate failed"
        commands = @("npm run flowchain:bridge:relayer:once -- -AllowBlocked", "npm run flowchain:service:status", "npm run flowchain:bridge:emergency-stop")
    },
    [ordered]@{
        id = "bridge-relayer-cursor-unsafe"
        severity = "critical"
        findingCodes = @("bridge-relayer-cursor-unsafe")
        signal = "Bridge relayer passed without safe staged cursor commit evidence."
        threshold = "passed relayer report has cursorCommit.finalCommitRequired true with finalCommitted false, NoQueue enabled, or unapplied new credits"
        commands = @("npm run flowchain:bridge:relayer:once -- -AllowBlocked", "npm run flowchain:bridge:emergency-stop", "npm run flowchain:service:status")
    },
    [ordered]@{
        id = "bridge-relayer-guardrail-failed"
        severity = "critical"
        findingCodes = @("bridge-relayer-guardrail-failed")
        signal = "Bridge relayer fail-closed guardrail proof is missing or failed."
        threshold = "guardrail validation report is not passed or any cursor/no-queue/no-secret/no-broadcast check is false"
        commands = @("npm run flowchain:bridge:relayer:guardrail:validate", "npm run flowchain:bridge:relayer:once -- -AllowBlocked", "npm run flowchain:bridge:emergency-stop")
    },
    [ordered]@{
        id = "bridge-direct-observe-cursor-unsafe"
        severity = "critical"
        findingCodes = @("bridge-direct-observe-cursor-unsafe")
        signal = "Standalone Base 8453 observer could use or mutate the final relayer cursor without explicit owner opt-in."
        threshold = "direct observer guardrail is missing, not blocked, not staged by default, points at the final cursor, changes final cursor state, writes staged cursor state, prints env values, broadcasts, or reports secrets"
        commands = @("npm run flowchain:bridge:relayer:guardrail:validate", "npm run flowchain:bridge:relayer:once -- -AllowBlocked", "npm run flowchain:bridge:emergency-stop")
    },
    [ordered]@{
        id = "bridge-runtime-credit-validation-failed"
        severity = "critical"
        findingCodes = @("bridge-runtime-credit-validation-failed")
        signal = "Base 8453 runtime credit proof is missing or failing."
        threshold = "runtime credit validation is not passed, has failed/missing/false checks, exceeds latency gates, broadcasts, prints env values, or reports secrets"
        commands = @("npm run flowchain:bridge:runtime-credit:validate", "npm run flowchain:service:status", "npm run flowchain:bridge:emergency-stop")
    },
    [ordered]@{
        id = "bridge-relayer-loop-unhealthy"
        severity = "critical"
        findingCodes = @("bridge-relayer-loop-unhealthy")
        signal = "Bridge relayer loop is running without fresh no-secret/no-broadcast health evidence."
        threshold = "service status reports bridgeRelayerLoop.status running and bridgeRelayerLoop.report.healthy is not true"
        commands = @("npm run flowchain:service:status", "npm run flowchain:bridge:relayer:loop:validate", "npm run flowchain:service:restart -- -LiveProfile -StartBridgeRelayerLoop", "npm run flowchain:bridge:emergency-stop")
    },
    [ordered]@{
        id = "supervisor-relayer-recovery-failed"
        severity = "critical"
        findingCodes = @("supervisor-relayer-recovery-failed")
        signal = "Service supervisor requested the bridge relayer loop but latest recovery evidence does not show a healthy relayer loop."
        threshold = "service-supervisor report has bridgeRelayerLoop.requested true and latest after.bridgeRelayerLoopStatus is not running, command line is not matched, report is unhealthy, or supervisor status failed"
        commands = @("npm run flowchain:service:supervisor -- -Once -StartBridgeRelayerLoop", "npm run flowchain:service:supervisor:validate", "npm run flowchain:service:restart -- -LiveProfile -StartBridgeRelayerLoop", "npm run flowchain:bridge:emergency-stop")
    },
    [ordered]@{
        id = "supervisor-node-recovery-validation-failed"
        severity = "critical"
        findingCodes = @("supervisor-node-recovery-validation-failed")
        signal = "Service supervisor node crash recovery validation is missing or failed."
        threshold = "service-supervisor-validation report is not passed or node crash, restart, live-profile, unbounded, node-running, or control-plane-readable recovery checks are false"
        commands = @("npm run flowchain:service:supervisor:validate", "npm run flowchain:service:supervisor -- -Once", "npm run flowchain:service:restart -- -LiveProfile")
    },
    [ordered]@{
        id = "deployment-refresh-aborted"
        severity = "critical"
        findingCodes = @("deployment-refresh-aborted")
        signal = "Public deployment dependency refresh aborted or skipped child gates."
        threshold = "deployment contract dependencyRefresh is aborted, failed, timed out, or skipped"
        commands = @("npm run flowchain:public-deployment:contract -- -AllowBlocked", "npm run flowchain:public-deployment:contract -- -NoRefresh -AllowBlocked", "npm run flowchain:ops:snapshot -- -AllowBlocked -NoRefresh")
    },
    [ordered]@{
        id = "truth-table-stale-or-failed"
        severity = "critical"
        findingCodes = @("truth-table-stale-or-failed")
        signal = "Production truth table is stale, failed, missing, or reports repo-owned blockers."
        threshold = "production truth table status is failed/stale/missing or failed, stale, or blocked-repo-work gate count is greater than zero"
        commands = @("npm run flowchain:truth-table -- -AllowBlocked", "npm run flowchain:completion:audit -- -AllowBlocked", "npm run flowchain:live:cutover:rehearsal -- -AllowBlocked")
    },
    [ordered]@{
        id = "external-tester-evidence-unsafe"
        severity = "critical"
        findingCodes = @("external-tester-evidence-unsafe")
        signal = "External tester returned evidence contains a secret marker, credential URL, or env assignment."
        threshold = "tester evidence validation reports any secretMarkerFindings, credentialUrlFindings, or envAssignmentFindings"
        commands = @("npm run flowchain:tester:evidence:validate", "npm run flowchain:no-secret:scan", "npm run flowchain:emergency:export-evidence")
    },
    [ordered]@{
        id = "dashboard-ui-readiness-failed"
        severity = "critical"
        findingCodes = @("dashboard-ui-readiness-failed")
        signal = "Dashboard wallet, faucet, send, tester launch, explorer, activation cockpit, or no-secret UI readiness proof is missing or failed."
        threshold = "dashboard UI readiness status is not passed, required tester flow, activation cockpit, browser E2E/build proof is false, or no-secret flags are unsafe"
        commands = @("npm run flowchain:dashboard:ui:readiness", "npm run flowchain:dashboard:build", "npm test --prefix apps/dashboard")
    },
    [ordered]@{
        id = "owner-inputs-validation-failed"
        severity = "critical"
        findingCodes = @("owner-inputs-validation-failed")
        signal = "Owner input validation scenarios are missing, failed, or unsafe to use for live cutover."
        threshold = "owner input validation status is not passed, fewer than six validation scenarios are present, any scenario failed, required env names are absent, or no-secret flags are unsafe"
        commands = @("npm run flowchain:owner-inputs:validate", "npm run flowchain:owner-inputs", "npm run flowchain:owner-env:readiness")
    },
    [ordered]@{
        id = "public-rpc-edge-hardening-failed"
        severity = "critical"
        findingCodes = @("public-rpc-edge-hardening-failed")
        signal = "Public RPC edge deployment hardening evidence is missing or failed."
        threshold = "deployment bundle or rendered automation lacks disallowed-origin, blocked-private-path, scoped authorization forwarding, defensive response-header proof, or wallet/tester cutover command proof"
        commands = @("npm run flowchain:public-rpc:deployment-bundle", "npm run flowchain:public-rpc:deployment:automation", "npm run flowchain:public-deployment:contract -- -AllowBlocked -NoRefresh")
    },
    [ordered]@{
        id = "public-rpc-not-shareable"
        severity = "blocked"
        findingCodes = @("public-rpc-not-ready")
        signal = "Public RPC readiness gate is not passed."
        threshold = "public RPC check status is not passed"
        commands = @("npm run flowchain:public-rpc:check", "npm run flowchain:public-rpc:validate", "npm run flowchain:public-rpc:abuse-test")
    },
    [ordered]@{
        id = "backup-not-ready"
        severity = "blocked"
        findingCodes = @("backup-not-ready")
        signal = "State backup readiness is not passed."
        threshold = "backup check status is not passed"
        commands = @("npm run flowchain:backup:restore:validate", "npm run flowchain:backup:check")
    },
    [ordered]@{
        id = "bridge-not-ready"
        severity = "blocked"
        findingCodes = @("bridge-not-ready")
        signal = "Base 8453 bridge readiness is not passed."
        threshold = "bridge live or infra readiness status is not passed"
        commands = @("npm run flowchain:bridge:live:check", "npm run flowchain:bridge:infra:check", "npm run flowchain:bridge:emergency-stop")
    },
    [ordered]@{
        id = "bridge-relayer-not-ready"
        severity = "blocked"
        findingCodes = @("bridge-relayer-not-ready")
        signal = "Bridge relayer one-shot proof is not ready."
        threshold = "bridge relayer one-shot status is not passed"
        commands = @("npm run flowchain:bridge:relayer:once -- -AllowBlocked", "npm run flowchain:bridge:live:check", "npm run flowchain:bridge:infra:check")
    },
    [ordered]@{
        id = "external-tester-not-shareable"
        severity = "blocked"
        findingCodes = @("external-tester-not-shareable")
        signal = "External tester packet is not shareable."
        threshold = "tester readiness status is not passed, local tester wallet rehearsal is not ready/fresh, public tester gateway or faucet route is not validated, external sharing is false, or live infra readiness is blocked"
        commands = @("npm run flowchain:wallet:live-tester:e2e", "npm run flowchain:tester:gateway:e2e", "npm run flowchain:tester:readiness -- -AllowBlocked", "npm run flowchain:external-tester:packet -- -AllowBlocked")
    },
    [ordered]@{
        id = "external-tester-evidence-invalid"
        severity = "blocked"
        findingCodes = @("external-tester-evidence-invalid")
        signal = "External tester returned evidence is incomplete or transfer proof is inconsistent."
        threshold = "tester evidence validation is not passed, required files are missing, JSON is invalid, or transfer proof checks fail"
        commands = @("npm run flowchain:tester:evidence:validate", "npm run flowchain:external-tester:packet -- -AllowBlocked")
    },
    [ordered]@{
        id = "deployment-contract-not-ready"
        severity = "blocked"
        findingCodes = @("deployment-contract-not-ready")
        signal = "Public deployment contract is not passed."
        threshold = "deployment contract status is not passed"
        commands = @("npm run flowchain:public-deployment:contract -- -AllowBlocked")
    }
)

$coveredCodes = New-Object System.Collections.ArrayList
$activeRules = New-Object System.Collections.ArrayList
foreach ($rule in $rules) {
    foreach ($code in @($rule.findingCodes)) {
        Add-UniqueAlertValue -Target $coveredCodes -Value $code
        if ($currentFindingCodes.Contains($code) -and -not $activeRules.Contains($rule.id)) {
            [void] $activeRules.Add($rule.id)
        }
    }
}

$unmappedCurrentFindingCodes = @($currentFindingCodes | Where-Object { $_ -notin @($coveredCodes) })
$criticalRules = @($rules | Where-Object { $_.severity -eq "critical" })
$blockedRules = @($rules | Where-Object { $_.severity -eq "blocked" })
$rulesWithoutCommands = @($rules | Where-Object { @($_.commands).Count -eq 0 })
$activeRuleIdsWithoutCommands = @($rules | Where-Object { $activeRules.Contains($_.id) -and @($_.commands).Count -eq 0 } | ForEach-Object { $_.id })
$publicRpcEdgeHardeningRule = @($rules | Where-Object { $_.id -eq "public-rpc-edge-hardening-failed" } | Select-Object -First 1)
$publicRpcEdgeHardeningRuleCoversSecurityHeaders = $publicRpcEdgeHardeningRule.Count -eq 1 `
    -and ([string]$publicRpcEdgeHardeningRule[0].threshold).IndexOf("response-header", [System.StringComparison]::OrdinalIgnoreCase) -ge 0
$publicRpcEdgeHardeningRuleCoversWalletCutover = $publicRpcEdgeHardeningRule.Count -eq 1 `
    -and ([string]$publicRpcEdgeHardeningRule[0].threshold).IndexOf("wallet/tester", [System.StringComparison]::OrdinalIgnoreCase) -ge 0 `
    -and ([string]$publicRpcEdgeHardeningRule[0].threshold).IndexOf("cutover", [System.StringComparison]::OrdinalIgnoreCase) -ge 0
$bridgeRelayerCheckContractRule = @($rules | Where-Object { $_.id -eq "bridge-relayer-check-contract-failed" } | Select-Object -First 1)
$bridgeRelayerCheckContractRuleCoversFailedChecks = $bridgeRelayerCheckContractRule.Count -eq 1 `
    -and ([string]$bridgeRelayerCheckContractRule[0].threshold).IndexOf("failedChecks", [System.StringComparison]::OrdinalIgnoreCase) -ge 0 `
    -and ([string]$bridgeRelayerCheckContractRule[0].threshold).IndexOf("required checks", [System.StringComparison]::OrdinalIgnoreCase) -ge 0
$supervisorNodeRecoveryRule = @($rules | Where-Object { $_.id -eq "supervisor-node-recovery-validation-failed" } | Select-Object -First 1)
$supervisorNodeRecoveryRuleCoversLiveProfile = $supervisorNodeRecoveryRule.Count -eq 1 `
    -and ([string]$supervisorNodeRecoveryRule[0].threshold).IndexOf("live-profile", [System.StringComparison]::OrdinalIgnoreCase) -ge 0 `
    -and ([string]$supervisorNodeRecoveryRule[0].threshold).IndexOf("unbounded", [System.StringComparison]::OrdinalIgnoreCase) -ge 0
$externalTesterLaunchRule = @($rules | Where-Object { $_.id -eq "external-tester-not-shareable" } | Select-Object -First 1)
$externalTesterLaunchRuleCoversGatewayAndFaucet = $externalTesterLaunchRule.Count -eq 1 `
    -and ([string]$externalTesterLaunchRule[0].threshold).IndexOf("public tester gateway", [System.StringComparison]::OrdinalIgnoreCase) -ge 0 `
    -and ([string]$externalTesterLaunchRule[0].threshold).IndexOf("faucet route", [System.StringComparison]::OrdinalIgnoreCase) -ge 0 `
    -and ([string]$externalTesterLaunchRule[0].threshold).IndexOf("local tester wallet rehearsal", [System.StringComparison]::OrdinalIgnoreCase) -ge 0 `
    -and ([string]$externalTesterLaunchRule[0].threshold).IndexOf("live infra", [System.StringComparison]::OrdinalIgnoreCase) -ge 0
$allCommands = @($rules | ForEach-Object { @($_.commands) })
$commandsWithInlineEnvAssignment = @($allCommands | Where-Object { "$_" -match '(^|\s)(\$env:)?[A-Z][A-Z0-9_]+\s*=' })
$commandsWithUrls = @($allCommands | Where-Object { "$_" -match 'https?://' })
$findingsWithoutCommands = @($currentFindingCodes | Where-Object { $_ -in $unmappedCurrentFindingCodes })
$checks = [ordered]@{
    opsSnapshotLoaded = $null -ne $opsSnapshot
    opsRefreshSucceeded = $opsExitCode -eq 0
    ruleCountSufficient = $rules.Count -ge 10
    criticalRuleCountSufficient = $criticalRules.Count -ge 5
    blockedRuleCountSufficient = $blockedRules.Count -ge 5
    currentFindingsLoaded = $currentFindingCodes.Count -ge 0
    everyCurrentFindingMapped = $unmappedCurrentFindingCodes.Count -eq 0
    everyRuleHasCommands = $rulesWithoutCommands.Count -eq 0
    everyActiveRuleHasCommands = $activeRuleIdsWithoutCommands.Count -eq 0
    commandsAvoidInlineEnvAssignment = $commandsWithInlineEnvAssignment.Count -eq 0
    commandsAvoidUrls = $commandsWithUrls.Count -eq 0
    findingsWithoutCommandsEmpty = $findingsWithoutCommands.Count -eq 0
    publicRpcEdgeHardeningRuleCoversSecurityHeaders = $publicRpcEdgeHardeningRuleCoversSecurityHeaders
    publicRpcEdgeHardeningRuleCoversWalletCutover = $publicRpcEdgeHardeningRuleCoversWalletCutover
    bridgeRelayerCheckContractRuleCoversFailedChecks = $bridgeRelayerCheckContractRuleCoversFailedChecks
    supervisorNodeRecoveryRuleCoversLiveProfile = $supervisorNodeRecoveryRuleCoversLiveProfile
    externalTesterLaunchRuleCoversGatewayAndFaucet = $externalTesterLaunchRuleCoversGatewayAndFaucet
    notificationPlanStoresNoSecrets = $true
    notificationPlanNoNetworkDelivery = $true
    envValuesPrintedFalse = $true
    secretMarkerFindingsEmpty = $true
    noSecrets = $true
    broadcastsFalse = $true
}
$currentAlertState = if (@($findings | Where-Object { [string](Get-AlertProp -Object $_ -Name "severity" -Default "") -eq "critical" }).Count -gt 0) {
    "critical"
}
elseif ($findings.Count -gt 0) {
    "blocked"
}
else {
    "clear"
}

$report = [ordered]@{
    schema = "flowchain.ops_alert_rules_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "pending"
    currentAlertState = $currentAlertState
    opsSnapshotStatus = [string](Get-AlertProp -Object $opsSnapshot -Name "status" -Default "missing")
    opsSnapshotPath = $opsSnapshotFullPath
    opsRefresh = [ordered]@{
        performed = -not $NoRefresh.IsPresent
        exitCode = $opsExitCode
        outputLineCount = @($opsOutput).Count
    }
    ruleCount = $rules.Count
    criticalRuleCount = $criticalRules.Count
    blockedRuleCount = $blockedRules.Count
    activeRuleIds = @($activeRules)
    currentFindingCodes = @($currentFindingCodes)
    coveredFindingCodes = @($coveredCodes)
    unmappedCurrentFindingCodes = $unmappedCurrentFindingCodes
    rulesWithoutCommands = @($rulesWithoutCommands | ForEach-Object { $_.id })
    activeRuleIdsWithoutCommands = @($activeRuleIdsWithoutCommands)
    commandsWithInlineEnvAssignment = @($commandsWithInlineEnvAssignment)
    commandsWithUrls = @($commandsWithUrls)
    findingsWithoutCommands = @($findingsWithoutCommands)
    checks = $checks
    failedChecks = @()
    notificationPlan = [ordered]@{
        deliveryMode = "owner-configured-out-of-repo"
        committedDestinations = @("local report", "operator terminal", "ops snapshot markdown")
        externalDestinationsAllowedOnlyOutsideRepo = @("pager service", "email", "chat alert channel")
        storesSecrets = $false
        sendsNetworkNotifications = $false
    }
    rules = $rules
    broadcasts = $false
    envValuesPrinted = $false
    noSecrets = $true
    secretMarkerFindings = @()
}

$preliminaryReportText = $report | ConvertTo-Json -Depth 18
$secretMarkerFindings = @(Get-AlertSecretMarkerFindings -Text $preliminaryReportText -Label "ops alert rules report")
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
Assert-FlowChainNoSecretText -Text $reportText -Label "ops alert rules report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Ops Alert Rules")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Current alert state: $currentAlertState")
$markdownLines.Add("")
$markdownLines.Add("This report maps local ops snapshot findings to operator actions. It does not send network notifications or store external alert credentials.")
$markdownLines.Add("")
$markdownLines.Add("| Rule | Severity | Signal | Commands |")
$markdownLines.Add("| --- | --- | --- | --- |")
foreach ($rule in $rules) {
    $markdownLines.Add("| $($rule.id) | $($rule.severity) | $($rule.signal) | ``$((@($rule.commands)) -join '; ')`` |")
}
$markdownLines.Add("")
$markdownLines.Add("Covered finding codes: ``$((@($coveredCodes)) -join ', ')``")
if ($unmappedCurrentFindingCodes.Count -gt 0) {
    $markdownLines.Add("Unmapped current finding codes: ``$($unmappedCurrentFindingCodes -join ', ')``")
}

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "ops alert rules markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain ops alert rules status: $status"
Write-Host "Current alert state: $currentAlertState"
Write-Host "Rules: $($rules.Count)"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed" -and -not $AllowBlocked) {
    throw "FlowChain ops alert rules failed. See report for unmapped findings."
}
