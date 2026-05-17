param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/ops-escalation-dry-run-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/OPS_ESCALATION_DRY_RUN.md",
    [string] $OpsSnapshotPath = "docs/agent-runs/live-product-infra-rpc/ops-snapshot-report.json",
    [string] $OpsAlertRulesPath = "docs/agent-runs/live-product-infra-rpc/ops-alert-rules-report.json",
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
$opsAlertRulesFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $OpsAlertRulesPath)

function Get-EscalationProp {
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

function Add-UniqueEscalationValue {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [AllowNull()][string] $Value
    )

    if (-not [string]::IsNullOrWhiteSpace($Value) -and -not $Target.Contains($Value)) {
        [void] $Target.Add($Value)
    }
}

function Test-EscalationPackageScript {
    param(
        [Parameter(Mandatory = $true)][AllowNull()][object] $PackageJson,
        [Parameter(Mandatory = $true)][string] $Name
    )

    if ($null -eq $PackageJson -or -not ($PackageJson.PSObject.Properties.Name -contains "scripts")) {
        return $false
    }
    return $PackageJson.scripts.PSObject.Properties.Name -contains $Name
}

function Get-EscalationRuleForFindingCode {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]] $Rules,
        [Parameter(Mandatory = $true)][string] $Code
    )

    foreach ($rule in $Rules) {
        foreach ($findingCode in @((Get-EscalationProp -Object $rule -Name "findingCodes" -Default @()))) {
            if ("$findingCode" -eq $Code) {
                return $rule
            }
        }
    }
    return $null
}

function ConvertTo-EscalationSafeOutputLine {
    param([AllowNull()][object] $Line)

    $text = "$Line"
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "https?://[^\s,)]+", "<redacted-url>")
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "(?i)(FLOWCHAIN_[A-Z0-9_]+\s*[:=]\s*)([^\s,;]+)", '${1}<redacted>')
    return $text
}

if (-not $NoRefresh.IsPresent) {
    $alertOutput = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-ops-alerts.ps1") -AllowBlocked -ReportPath $opsAlertRulesFullPath -MarkdownPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/OPS_ALERT_RULES.md") -OpsSnapshotPath $opsSnapshotFullPath 2>&1) | ForEach-Object { ConvertTo-EscalationSafeOutputLine -Line $_ }
    $alertExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
}
else {
    $alertOutput = @()
    $alertExitCode = 0
}

$opsSnapshot = Read-FlowChainJsonIfExists -Path $opsSnapshotFullPath
$opsAlertRules = Read-FlowChainJsonIfExists -Path $opsAlertRulesFullPath
if ($null -eq $opsSnapshot) {
    throw "Ops snapshot report is missing: $opsSnapshotFullPath"
}
if ($null -eq $opsAlertRules) {
    throw "Ops alert rules report is missing: $opsAlertRulesFullPath"
}

$packageJsonPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "package.json"
$packageJson = Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json
$requiredPackageScripts = @(
    "flowchain:ops:snapshot",
    "flowchain:ops:alerts",
    "flowchain:ops:incident-drill",
    "flowchain:ops:escalation:dry-run"
)
$missingPackageScripts = @($requiredPackageScripts | Where-Object { -not (Test-EscalationPackageScript -PackageJson $packageJson -Name $_) })

$rules = @((Get-EscalationProp -Object $opsAlertRules -Name "rules" -Default @()))
$activeRuleIds = @((Get-EscalationProp -Object $opsAlertRules -Name "activeRuleIds" -Default @()) | ForEach-Object { "$_" })
$findings = @((Get-EscalationProp -Object $opsSnapshot -Name "findings" -Default @()))
$notificationPlan = Get-EscalationProp -Object $opsAlertRules -Name "notificationPlan"

$currentFindingCodes = New-Object System.Collections.ArrayList
foreach ($finding in $findings) {
    Add-UniqueEscalationValue -Target $currentFindingCodes -Value ([string](Get-EscalationProp -Object $finding -Name "code" -Default ""))
}

$dryRunEvents = New-Object System.Collections.ArrayList
$unmappedFindingCodes = New-Object System.Collections.ArrayList
$findingsWithoutCommands = New-Object System.Collections.ArrayList
foreach ($finding in $findings) {
    $code = [string](Get-EscalationProp -Object $finding -Name "code" -Default "")
    $rule = Get-EscalationRuleForFindingCode -Rules $rules -Code $code
    $ruleCommands = if ($null -ne $rule) { @((Get-EscalationProp -Object $rule -Name "commands" -Default @())) } else { @() }
    $findingCommands = @((Get-EscalationProp -Object $finding -Name "commands" -Default @()))
    $commands = if (@($ruleCommands).Count -gt 0) { @($ruleCommands) } else { @($findingCommands) }
    if ($null -eq $rule) {
        Add-UniqueEscalationValue -Target $unmappedFindingCodes -Value $code
    }
    if (@($commands).Count -eq 0) {
        Add-UniqueEscalationValue -Target $findingsWithoutCommands -Value $code
    }
    [void] $dryRunEvents.Add([ordered]@{
        findingCode = $code
        severity = [string](Get-EscalationProp -Object $finding -Name "severity" -Default "observed")
        ruleId = if ($null -ne $rule) { [string](Get-EscalationProp -Object $rule -Name "id" -Default "unmapped") } else { "unmapped" }
        signal = if ($null -ne $rule) { [string](Get-EscalationProp -Object $rule -Name "signal" -Default "") } else { [string](Get-EscalationProp -Object $finding -Name "message" -Default "") }
        dryRunChannels = @("local-report", "operator-terminal", "ops-markdown")
        commands = @($commands | ForEach-Object { "$_" })
        wouldSendNetworkDelivery = $false
        wouldStoreCredentials = $false
        dryRunOnly = $true
    })
}

$activeRuleIdsMissingFromManifest = New-Object System.Collections.ArrayList
$activeRuleIdsWithoutCommands = New-Object System.Collections.ArrayList
foreach ($activeRuleId in $activeRuleIds) {
    $matchingRule = @($rules | Where-Object { [string](Get-EscalationProp -Object $_ -Name "id" -Default "") -eq $activeRuleId }) | Select-Object -First 1
    if ($null -eq $matchingRule) {
        Add-UniqueEscalationValue -Target $activeRuleIdsMissingFromManifest -Value $activeRuleId
    }
    elseif (@((Get-EscalationProp -Object $matchingRule -Name "commands" -Default @())).Count -eq 0) {
        Add-UniqueEscalationValue -Target $activeRuleIdsWithoutCommands -Value $activeRuleId
    }
}

$allCommands = @()
foreach ($event in $dryRunEvents) {
    $allCommands += @((Get-EscalationProp -Object $event -Name "commands" -Default @()))
}
$commandsWithUrls = @($allCommands | Where-Object { "$_" -match "https?://" })
$commandsWithInlineEnvAssignment = @($allCommands | Where-Object { "$_" -match "(?i)(^|\s)(FLOWCHAIN_[A-Z0-9_]+|\$env:FLOWCHAIN_[A-Z0-9_]+)\s*=" })

$checks = [ordered]@{
    opsSnapshotLoaded = $null -ne $opsSnapshot
    opsAlertRulesLoaded = $null -ne $opsAlertRules
    opsSnapshotStatusSafe = [string](Get-EscalationProp -Object $opsSnapshot -Name "status" -Default "missing") -in @("passed", "blocked")
    opsAlertRulesPassed = [string](Get-EscalationProp -Object $opsAlertRules -Name "status" -Default "missing") -eq "passed"
    alertRefreshCommandPassed = [int]$alertExitCode -eq 0
    packageScriptsPresent = $missingPackageScripts.Count -eq 0
    notificationPlanNoNetworkDelivery = (Get-EscalationProp -Object $notificationPlan -Name "sendsNetworkNotifications" -Default $true) -eq $false
    notificationPlanStoresNoSecrets = (Get-EscalationProp -Object $notificationPlan -Name "storesSecrets" -Default $true) -eq $false
    notificationPlanOutOfRepo = [string](Get-EscalationProp -Object $notificationPlan -Name "deliveryMode" -Default "") -eq "owner-configured-out-of-repo"
    activeRulesExistInManifest = $activeRuleIdsMissingFromManifest.Count -eq 0
    activeRulesHaveCommands = $activeRuleIdsWithoutCommands.Count -eq 0
    everyCurrentFindingMapped = $unmappedFindingCodes.Count -eq 0
    everyCurrentFindingHasCommands = $findingsWithoutCommands.Count -eq 0
    noCommandUrls = $commandsWithUrls.Count -eq 0
    noInlineEnvAssignments = $commandsWithInlineEnvAssignment.Count -eq 0
    dryRunEventsDoNotSend = @($dryRunEvents | Where-Object { (Get-EscalationProp -Object $_ -Name "wouldSendNetworkDelivery" -Default $true) -ne $false }).Count -eq 0
    dryRunEventsStoreNoCredentials = @($dryRunEvents | Where-Object { (Get-EscalationProp -Object $_ -Name "wouldStoreCredentials" -Default $true) -ne $false }).Count -eq 0
    envValuesPrintedFalse = $true
    noSecrets = $true
    broadcastsFalse = $true
}

$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.ops_escalation_dry_run_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    currentAlertState = [string](Get-EscalationProp -Object $opsAlertRules -Name "currentAlertState" -Default "missing")
    opsSnapshotStatus = [string](Get-EscalationProp -Object $opsSnapshot -Name "status" -Default "missing")
    opsAlertRulesStatus = [string](Get-EscalationProp -Object $opsAlertRules -Name "status" -Default "missing")
    dryRunEventCount = $dryRunEvents.Count
    activeRuleIds = @($activeRuleIds)
    currentFindingCodes = @($currentFindingCodes)
    unmappedFindingCodes = @($unmappedFindingCodes)
    findingsWithoutCommands = @($findingsWithoutCommands)
    activeRuleIdsMissingFromManifest = @($activeRuleIdsMissingFromManifest)
    activeRuleIdsWithoutCommands = @($activeRuleIdsWithoutCommands)
    commandsWithUrls = @($commandsWithUrls)
    commandsWithInlineEnvAssignment = @($commandsWithInlineEnvAssignment)
    missingPackageScripts = @($missingPackageScripts)
    checks = $checks
    failedChecks = @($failedChecks)
    opsRefresh = [ordered]@{
        performed = -not $NoRefresh.IsPresent
        exitCode = [int]$alertExitCode
        outputLineCount = @($alertOutput).Count
        outputRedacted = @($alertOutput | Select-Object -First 20)
    }
    dryRunEvents = @($dryRunEvents)
    deliveryBoundary = [ordered]@{
        mode = "owner-configured-out-of-repo"
        repoChannels = @("local report", "operator terminal", "ops markdown")
        externalDeliveryConfiguredInRepo = $false
        sendsNetworkDelivery = $false
        storesCredentials = $false
    }
    reportPaths = [ordered]@{
        opsSnapshot = $opsSnapshotFullPath
        opsAlertRules = $opsAlertRulesFullPath
    }
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$reportText = $report | ConvertTo-Json -Depth 18
Assert-FlowChainNoSecretText -Text $reportText -Label "ops escalation dry-run report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Ops Escalation Dry Run")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Current alert state: $($report.currentAlertState)")
$markdownLines.Add("")
$markdownLines.Add("This dry run maps current ops findings to local operator actions. It does not send network delivery or store external delivery credentials.")
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("- $($entry.Key): $($entry.Value)")
}
$markdownLines.Add("")
$markdownLines.Add("## Dry Run Events")
$markdownLines.Add("")
if ($dryRunEvents.Count -eq 0) {
    $markdownLines.Add("- No current findings.")
}
else {
    foreach ($event in $dryRunEvents) {
        $markdownLines.Add("- $($event.findingCode): $($event.severity), rule $($event.ruleId), commands ``$((@($event.commands)) -join '; ')``")
    }
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
Assert-FlowChainNoSecretText -Text $markdownText -Label "ops escalation dry-run markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain ops escalation dry-run status: $status"
Write-Host "Dry-run events: $($dryRunEvents.Count)"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed" -and -not $AllowBlocked) {
    Write-Host "Failed checks: $($failedChecks -join ', ')"
    exit 1
}
exit 0
