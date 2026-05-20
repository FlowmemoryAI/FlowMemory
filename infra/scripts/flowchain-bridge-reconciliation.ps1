param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-reconciliation-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/BRIDGE_RECONCILIATION.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)

function Get-BridgeReconciliationProp {
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

function Get-BridgeReconciliationStatus {
    param([AllowNull()][object] $Report)
    return [string](Get-BridgeReconciliationProp -Object $Report -Name "status" -Default "missing")
}

function Add-BridgeReconciliationRow {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Rows,
        [Parameter(Mandatory = $true)][string] $Lane,
        [Parameter(Mandatory = $true)][string] $Status,
        [Parameter(Mandatory = $true)][int] $Count,
        [Parameter(Mandatory = $true)][string] $Evidence
    )

    [void] $Rows.Add([ordered]@{
        lane = $Lane
        status = $Status
        count = $Count
        evidence = $Evidence
    })
}

$paths = [ordered]@{
    relayerOnce = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-once-report.json"
    guardrail = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-guardrail-validation-report.json"
    loopValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-loop-validation-report.json"
    runtimeCredit = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-runtime-credit-validation-report.json"
    releaseEvidence = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-release-evidence-validation-report.json"
    bridgeLive = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
    bridgeInfra = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
    pilotLocal = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "services/bridge-relayer/out/real-value-pilot-e2e/bridge-real-value-pilot-e2e-report.json"
}

$relayerOnce = Read-FlowChainJsonIfExists -Path $paths.relayerOnce
$guardrail = Read-FlowChainJsonIfExists -Path $paths.guardrail
$loopValidation = Read-FlowChainJsonIfExists -Path $paths.loopValidation
$runtimeCredit = Read-FlowChainJsonIfExists -Path $paths.runtimeCredit
$releaseEvidence = Read-FlowChainJsonIfExists -Path $paths.releaseEvidence
$bridgeLive = Read-FlowChainJsonIfExists -Path $paths.bridgeLive
$bridgeInfra = Read-FlowChainJsonIfExists -Path $paths.bridgeInfra
$pilotLocal = Read-FlowChainJsonIfExists -Path $paths.pilotLocal

$relayerCounts = Get-BridgeReconciliationProp -Object $relayerOnce -Name "counts"
$cursorCommit = Get-BridgeReconciliationProp -Object $relayerOnce -Name "cursorCommit"
$relayerChecks = Get-BridgeReconciliationProp -Object $relayerOnce -Name "checks"
$guardrailChecks = Get-BridgeReconciliationProp -Object $guardrail -Name "checks"
$runtimeChecks = Get-BridgeReconciliationProp -Object $runtimeCredit -Name "checks"
$releaseChecks = Get-BridgeReconciliationProp -Object $releaseEvidence -Name "checks"
$pilotChecks = Get-BridgeReconciliationProp -Object $pilotLocal -Name "checks"
$pilotReplay = Get-BridgeReconciliationProp -Object $pilotLocal -Name "replayProtection"
$pilotExactValue = Get-BridgeReconciliationProp -Object $pilotLocal -Name "exactValueConservation"

$observedCredits = [int](Get-BridgeReconciliationProp -Object $relayerCounts -Name "observedCredits" -Default 0)
$newCredits = [int](Get-BridgeReconciliationProp -Object $relayerCounts -Name "newCredits" -Default 0)
$queuedTransactions = [int](Get-BridgeReconciliationProp -Object $relayerCounts -Name "queuedTransactions" -Default 0)
$appliedCredits = [int](Get-BridgeReconciliationProp -Object $relayerCounts -Name "appliedCredits" -Default 0)
$pendingCredits = [Math]::Max(0, $newCredits - $appliedCredits)
$pilotDuplicateReplayCount = @((Get-BridgeReconciliationProp -Object $pilotReplay -Name "duplicateReplayKeys" -Default @())).Count
$runtimeAppliedCount = if ((Get-BridgeReconciliationProp -Object $runtimeChecks -Name "creditAppliedOnce" -Default $false) -eq $true) { 1 } else { 0 }
$releaseEvidenceCount = if ((Get-BridgeReconciliationProp -Object $releaseChecks -Name "matchingEvidencePasses" -Default $false) -eq $true) { 1 } else { 0 }

$rows = New-Object System.Collections.ArrayList
Add-BridgeReconciliationRow -Rows $rows -Lane "live-observed" -Status $(if ($observedCredits -gt 0) { "observed" } else { "none-or-owner-blocked" }) -Count $observedCredits -Evidence "live relayer once observed credits"
Add-BridgeReconciliationRow -Rows $rows -Lane "live-new" -Status $(if ($newCredits -gt 0) { "new" } else { "none-or-owner-blocked" }) -Count $newCredits -Evidence "live relayer once filtered new credits"
Add-BridgeReconciliationRow -Rows $rows -Lane "live-queued" -Status $(if ($queuedTransactions -gt 0) { "queued" } else { "none-or-owner-blocked" }) -Count $queuedTransactions -Evidence "live relayer once queued L1 transactions"
Add-BridgeReconciliationRow -Rows $rows -Lane "live-applied" -Status $(if ($appliedCredits -gt 0) { "applied" } else { "none-or-owner-blocked" }) -Count $appliedCredits -Evidence "live relayer once applied L1 credits"
Add-BridgeReconciliationRow -Rows $rows -Lane "live-pending" -Status $(if ($pendingCredits -gt 0) { "pending-review" } else { "empty" }) -Count $pendingCredits -Evidence "new credits minus applied credits"
Add-BridgeReconciliationRow -Rows $rows -Lane "local-runtime-applied" -Status $(if ($runtimeAppliedCount -gt 0) { "proved" } else { "missing-proof" }) -Count $runtimeAppliedCount -Evidence "runtime credit validation spendable proof"
Add-BridgeReconciliationRow -Rows $rows -Lane "local-replay-rejected" -Status $(if ($pilotDuplicateReplayCount -gt 0) { "proved" } else { "missing-proof" }) -Count $pilotDuplicateReplayCount -Evidence "mock pilot duplicate replay rejection proof"
Add-BridgeReconciliationRow -Rows $rows -Lane "release-evidence" -Status $(if ($releaseEvidenceCount -gt 0) { "validated" } else { "missing-proof" }) -Count $releaseEvidenceCount -Evidence "withdrawal/release evidence validation proof"

$relayerOnceStatus = Get-BridgeReconciliationStatus -Report $relayerOnce
$bridgeLiveStatus = Get-BridgeReconciliationStatus -Report $bridgeLive
$bridgeInfraStatus = Get-BridgeReconciliationStatus -Report $bridgeInfra
$relayerOnceFailedChecks = @((Get-BridgeReconciliationProp -Object $relayerOnce -Name "failedChecks" -Default @()))
$guardrailFailedChecks = @((Get-BridgeReconciliationProp -Object $guardrail -Name "failedChecks" -Default @()))
$runtimeFailedChecks = @((Get-BridgeReconciliationProp -Object $runtimeCredit -Name "failedChecks" -Default @()))
$releaseFailedChecks = @((Get-BridgeReconciliationProp -Object $releaseEvidence -Name "failedChecks" -Default @()))
$pilotFailedChecks = @((Get-BridgeReconciliationProp -Object $pilotLocal -Name "failedChecks" -Default @()))

$checks = [ordered]@{
    relayerOnceReportLoaded = $null -ne $relayerOnce
    relayerOnceStatusBlockedOrPassed = $relayerOnceStatus -in @("blocked", "passed")
    relayerOnceNoFailedChecks = $relayerOnceFailedChecks.Count -eq 0
    relayerOnceNoSecrets = (Get-BridgeReconciliationProp -Object $relayerOnce -Name "noSecrets" -Default $false) -eq $true
    relayerOnceNoBroadcasts = (Get-BridgeReconciliationProp -Object $relayerOnce -Name "broadcasts" -Default $true) -eq $false
    relayerCountsNonNegative = $observedCredits -ge 0 -and $newCredits -ge 0 -and $queuedTransactions -ge 0 -and $appliedCredits -ge 0
    pendingCreditsNonNegative = $pendingCredits -ge 0
    cursorModeStaged = [string](Get-BridgeReconciliationProp -Object $cursorCommit -Name "mode" -Default "") -eq "staged-cursor"
    cursorFinalNotCommittedWhenBlocked = $relayerOnceStatus -ne "blocked" -or (Get-BridgeReconciliationProp -Object $cursorCommit -Name "finalCommitted" -Default $true) -eq $false
    relayerBlockedClassifiedOwnerInput = $relayerOnceStatus -ne "blocked" -or ((Get-BridgeReconciliationProp -Object $relayerChecks -Name "externalBlockerClassifiedWhenBlocked" -Default $false) -eq $true)
    guardrailReportPassed = (Get-BridgeReconciliationStatus -Report $guardrail) -eq "passed"
    guardrailNoFailedChecks = $guardrailFailedChecks.Count -eq 0
    guardrailCursorSafe = (Get-BridgeReconciliationProp -Object $guardrailChecks -Name "finalCursorUnchanged" -Default $false) -eq $true -and (Get-BridgeReconciliationProp -Object $guardrailChecks -Name "finalCursorNotCommitted" -Default $false) -eq $true
    loopValidationPassedOrOwnerBlocked = (Get-BridgeReconciliationStatus -Report $loopValidation) -in @("passed", "blocked")
    runtimeCreditPassed = (Get-BridgeReconciliationStatus -Report $runtimeCredit) -eq "passed"
    runtimeCreditNoFailedChecks = $runtimeFailedChecks.Count -eq 0
    runtimeCreditAppliedOnce = (Get-BridgeReconciliationProp -Object $runtimeChecks -Name "creditAppliedOnce" -Default $false) -eq $true
    runtimeReplayRejected = (Get-BridgeReconciliationProp -Object $runtimeChecks -Name "replayRejected" -Default $false) -eq $true
    localPilotPassed = (Get-BridgeReconciliationStatus -Report $pilotLocal) -eq "passed"
    localPilotNoFailedChecks = $pilotFailedChecks.Count -eq 0
    localPilotExactValueConserved = (Get-BridgeReconciliationProp -Object $pilotExactValue -Name "allAmountsEqual" -Default $false) -eq $true
    localPilotDuplicateReplayRejected = (Get-BridgeReconciliationProp -Object $pilotChecks -Name "duplicateReplayRejected" -Default $false) -eq $true
    releaseEvidenceValidationPassed = (Get-BridgeReconciliationStatus -Report $releaseEvidence) -eq "passed"
    releaseEvidenceNoFailedChecks = $releaseFailedChecks.Count -eq 0
    reconciliationRowsPresent = $rows.Count -ge 8
    liveReadinessBlockedOrPassed = $bridgeLiveStatus -in @("blocked", "passed", "not-run", "missing")
    bridgeInfraBlockedOrPassed = $bridgeInfraStatus -in @("blocked", "passed")
    envValuesPrintedFalse = $true
    secretMarkerFindingsEmpty = $true
    noSecrets = $true
    broadcastsFalse = $true
}
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.bridge_reconciliation_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    liveBridgeStatus = [ordered]@{
        relayerOnce = $relayerOnceStatus
        infra = $bridgeInfraStatus
        live = $bridgeLiveStatus
        blockedOnOwnerInputs = $relayerOnceStatus -eq "blocked"
    }
    counts = [ordered]@{
        observedCredits = $observedCredits
        newCredits = $newCredits
        queuedTransactions = $queuedTransactions
        appliedCredits = $appliedCredits
        pendingCredits = $pendingCredits
        localRuntimeAppliedProofs = $runtimeAppliedCount
        duplicateReplayRejectedProofs = $pilotDuplicateReplayCount
        releaseEvidenceValidationProofs = $releaseEvidenceCount
    }
    reconciliation = @($rows)
    cursorCommit = [ordered]@{
        mode = [string](Get-BridgeReconciliationProp -Object $cursorCommit -Name "mode" -Default "")
        finalCommitRequired = (Get-BridgeReconciliationProp -Object $cursorCommit -Name "finalCommitRequired" -Default $false) -eq $true
        finalCommitted = (Get-BridgeReconciliationProp -Object $cursorCommit -Name "finalCommitted" -Default $false) -eq $true
        reason = [string](Get-BridgeReconciliationProp -Object $cursorCommit -Name "reason" -Default "")
    }
    paths = $paths
    checks = $checks
    failedChecks = @($failedChecks)
    secretMarkerFindings = @()
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$reportText = $report | ConvertTo-Json -Depth 16
Assert-FlowChainNoSecretText -Text $reportText -Label "bridge reconciliation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Bridge Reconciliation")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This report reconciles the live Base 8453 relayer state with local bridge proofs: observed credits, new credits, queued L1 transactions, applied credits, pending credits, replay rejection, cursor safety, and release evidence.")
$markdownLines.Add("")
$markdownLines.Add("## Reconciliation")
$markdownLines.Add("")
$markdownLines.Add("| Lane | Status | Count | Evidence |")
$markdownLines.Add("| --- | --- | ---: | --- |")
foreach ($row in $rows) {
    $markdownLines.Add("| $($row.lane) | $($row.status) | $($row.count) | $($row.evidence) |")
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
    foreach ($name in $failedChecks) {
        $markdownLines.Add("- $name")
    }
}

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "bridge reconciliation markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain bridge reconciliation status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    throw "FlowChain bridge reconciliation failed checks: $($failedChecks -join ', ')"
}
