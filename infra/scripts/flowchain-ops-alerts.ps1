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
        id = "secret-boundary-breach"
        severity = "critical"
        findingCodes = @("no-secret-scan-not-passed")
        signal = "No-secret scan did not pass."
        threshold = "any no-secret scan failure"
        commands = @("npm run flowchain:no-secret:scan", "npm run flowchain:emergency:export-evidence")
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
        id = "bridge-relayer-loop-unhealthy"
        severity = "critical"
        findingCodes = @("bridge-relayer-loop-unhealthy")
        signal = "Bridge relayer loop is running without fresh no-secret/no-broadcast health evidence."
        threshold = "service status reports bridgeRelayerLoop.status running and bridgeRelayerLoop.report.healthy is not true"
        commands = @("npm run flowchain:service:status", "npm run flowchain:bridge:relayer:loop:validate", "npm run flowchain:service:restart -- -LiveProfile -StartBridgeRelayerLoop", "npm run flowchain:bridge:emergency-stop")
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
        threshold = "tester readiness status is not passed"
        commands = @("npm run flowchain:tester:readiness", "npm run flowchain:external-tester:packet")
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
$status = if ($unmappedCurrentFindingCodes.Count -eq 0 -and $criticalRules.Count -ge 5 -and $blockedRules.Count -ge 5 -and $rulesWithoutCommands.Count -eq 0) { "passed" } else { "failed" }
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
    status = $status
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
}

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
