param(
    [string] $ValidationRunDir = "devnet/local/bridge-runtime-credit-validation",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-runtime-credit-validation-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/BRIDGE_RUNTIME_CREDIT_VALIDATION.md",
    [int] $TargetSettlementSeconds = 60,
    [int] $ChildTimeoutSeconds = 900
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$runFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ValidationRunDir)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$tmpDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/tmp/bridge-runtime-credit-validation")
$proofReportPath = Join-Path $runFullDir "runtime-credit-proof.json"
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

if ($TargetSettlementSeconds -lt 1) {
    throw "TargetSettlementSeconds must be at least 1."
}
if ($ChildTimeoutSeconds -lt 1) {
    throw "ChildTimeoutSeconds must be at least 1."
}

function Invoke-BridgeRuntimeCreditChild {
    $runId = "$(Get-Date -Format 'yyyyMMddHHmmssfff')-$PID-$([Guid]::NewGuid().ToString("N").Substring(0, 8))"
    $stdoutPath = Join-Path $tmpDir "$runId.stdout.log"
    $stderrPath = Join-Path $tmpDir "$runId.stderr.log"
    $timedOut = $false
    $exitCode = 1
    $output = @()

    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Join-Path $PSScriptRoot "flowchain-real-value-pilot-runtime.ps1"),
        "-RunDir",
        $ValidationRunDir,
        "-TargetSettlementSeconds",
        "$TargetSettlementSeconds"
    )

    try {
        $process = Start-Process -FilePath "powershell" `
            -ArgumentList (Join-FlowChainProcessArguments -ArgumentList $arguments) `
            -WorkingDirectory $repoRoot `
            -PassThru `
            -WindowStyle Hidden `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath
        $timedOut = -not $process.WaitForExit($ChildTimeoutSeconds * 1000)
        if ($timedOut) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            $exitCode = 124
        }
        else {
            $process.Refresh()
            $exitCode = [int]$process.ExitCode
        }
    }
    catch {
        $output += $_.Exception.Message
        $exitCode = 1
    }

    if (Test-Path -LiteralPath $stdoutPath) {
        $output += @(Get-Content -LiteralPath $stdoutPath -Tail 80)
    }
    if (Test-Path -LiteralPath $stderrPath) {
        $output += @(Get-Content -LiteralPath $stderrPath -Tail 80)
    }

    return [ordered]@{
        exitCode = [int]$exitCode
        timedOut = $timedOut
        stdoutPath = $stdoutPath
        stderrPath = $stderrPath
        outputRedacted = @($output | ForEach-Object { "$_" })
    }
}

function Get-BridgeRuntimeProp {
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

function Test-RuntimeProofCheckPassed {
    param(
        [AllowNull()][object] $Checks,
        [Parameter(Mandatory = $true)][string] $Name
    )

    $entry = Get-BridgeRuntimeProp -Object $Checks -Name $Name
    if ($null -eq $entry) {
        return $false
    }
    if ($entry -is [bool]) {
        return $entry
    }
    return (Get-BridgeRuntimeProp -Object $entry -Name "passed" -Default $false) -eq $true
}

function Get-RuntimeProofMissingChecks {
    param(
        [AllowNull()][object] $Checks,
        [Parameter(Mandatory = $true)][string[]] $Names
    )

    return @($Names | Where-Object { $null -eq (Get-BridgeRuntimeProp -Object $Checks -Name $_) })
}

function Read-BridgeRuntimeJson {
    param([Parameter(Mandatory = $true)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Test-HandoffReleaseBroadcastsFalse {
    param([AllowNull()][object] $Handoff)
    foreach ($evidence in @((Get-BridgeRuntimeProp -Object $Handoff -Name "releaseEvidences" -Default @()))) {
        $call = Get-BridgeRuntimeProp -Object $evidence -Name "releaseCall"
        if ((Get-BridgeRuntimeProp -Object $call -Name "broadcast" -Default $true) -ne $false) {
            return $false
        }
    }
    return $true
}

function Test-HandoffWithdrawalBroadcastsFalse {
    param([AllowNull()][object] $Handoff)
    foreach ($intent in @((Get-BridgeRuntimeProp -Object $Handoff -Name "withdrawalIntents" -Default @()))) {
        if ((Get-BridgeRuntimeProp -Object $intent -Name "broadcast" -Default $true) -ne $false) {
            return $false
        }
    }
    return $true
}

function Get-BridgeRuntimeSecretMarkerFindings {
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
            [void]$findings.Add([ordered]@{
                label = $Label
                marker = $pattern
            })
        }
    }
    return @($findings)
}

$child = Invoke-BridgeRuntimeCreditChild
$proof = Read-BridgeRuntimeJson -Path $proofReportPath
$proofChecks = Get-BridgeRuntimeProp -Object $proof -Name "checks"
$timing = Get-BridgeRuntimeProp -Object $proof -Name "timing"
$handoffPath = Get-BridgeRuntimeProp -Object $proof -Name "handoffPath" -Default ""
$handoff = if (-not [string]::IsNullOrWhiteSpace("$handoffPath")) { Read-BridgeRuntimeJson -Path "$handoffPath" } else { $null }

$requiredRuntimeChecks = @(
    "handoff-live-runtime-flags",
    "deposit-source-chain",
    "confirmation-proof-present",
    "pilot-cap-proof-present",
    "runtime-u64-cap-bound",
    "credit-applied-once",
    "wallet-delta-equals-credit-amount",
    "live-credit-record-flags",
    "live-receipt-record-flags",
    "runtime-credit-latency-recorded",
    "runtime-credit-latency-under-target",
    "replay-rejected",
    "replay-does-not-change-balance",
    "credited-balance-transferable",
    "runtime-transfer-latency-under-target",
    "restart-preserves-credit-history",
    "export-import-preserves-state-root",
    "export-import-preserves-replay-protection"
)
$missingRuntimeChecks = @(Get-RuntimeProofMissingChecks -Checks $proofChecks -Names $requiredRuntimeChecks)
$falseRuntimeChecks = @($requiredRuntimeChecks | Where-Object { -not (Test-RuntimeProofCheckPassed -Checks $proofChecks -Name $_) })
$proofFailedChecks = @((Get-BridgeRuntimeProp -Object $proof -Name "failedChecks" -Default @()))

$checks = [ordered]@{
    childCommandPassed = [int]$child.exitCode -eq 0
    childDidNotTimeout = [bool]$child.timedOut -eq $false
    proofReportWritten = Test-Path -LiteralPath $proofReportPath
    proofClassificationReady = "$(Get-BridgeRuntimeProp -Object $proof -Name 'classification' -Default '')" -eq "READY"
    proofFailedChecksEmpty = $proofFailedChecks.Count -eq 0
    requiredRuntimeChecksCovered = $missingRuntimeChecks.Count -eq 0
    requiredRuntimeChecksPassed = $falseRuntimeChecks.Count -eq 0
    sourceChainBase8453 = [string](Get-BridgeRuntimeProp -Object (Get-BridgeRuntimeProp -Object $proof -Name "source") -Name "chainId" -Default "") -eq "8453"
    creditAppliedOnce = Test-RuntimeProofCheckPassed -Checks $proofChecks -Name "credit-applied-once"
    creditedBalanceTransferable = Test-RuntimeProofCheckPassed -Checks $proofChecks -Name "credited-balance-transferable"
    replayRejected = Test-RuntimeProofCheckPassed -Checks $proofChecks -Name "replay-rejected"
    restartPreservesCreditHistory = Test-RuntimeProofCheckPassed -Checks $proofChecks -Name "restart-preserves-credit-history"
    exportImportPreservesReplayProtection = Test-RuntimeProofCheckPassed -Checks $proofChecks -Name "export-import-preserves-replay-protection"
    latencyRecorded = $null -ne (Get-BridgeRuntimeProp -Object $timing -Name "queueToSpendableSeconds")
    latencyGatePassed = "$(Get-BridgeRuntimeProp -Object $timing -Name 'latencyGate' -Default '')" -eq "passed"
    transferLatencyUnderTarget = Test-RuntimeProofCheckPassed -Checks $proofChecks -Name "runtime-transfer-latency-under-target"
    proofBroadcastsFalse = (Get-BridgeRuntimeProp -Object $proof -Name "broadcasts" -Default $true) -eq $false
    proofEnvValuesPrintedFalse = (Get-BridgeRuntimeProp -Object $proof -Name "envValuesPrinted" -Default $true) -eq $false
    proofNoSecrets = (Get-BridgeRuntimeProp -Object $proof -Name "noSecrets" -Default $false) -eq $true
    handoffReportReadable = $null -ne $handoff
    handoffNoReleaseBroadcast = Test-HandoffReleaseBroadcastsFalse -Handoff $handoff
    handoffNoWithdrawalBroadcast = Test-HandoffWithdrawalBroadcastsFalse -Handoff $handoff
    secretMarkerFindingsEmpty = $true
    broadcastsFalse = $true
    envValuesPrintedFalse = $true
    noSecrets = $true
}
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.bridge_runtime_credit_validation_report.v1"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    targetSettlementSeconds = $TargetSettlementSeconds
    validationRunDir = $ValidationRunDir
    runtimeProofReportPath = $proofReportPath
    handoffPath = $handoffPath
    childProcess = [ordered]@{
        exitCode = [int]$child.exitCode
        timedOut = [bool]$child.timedOut
        stdoutPath = [string]$child.stdoutPath
        stderrPath = [string]$child.stderrPath
    }
    source = Get-BridgeRuntimeProp -Object $proof -Name "source"
    creditId = Get-BridgeRuntimeProp -Object $proof -Name "creditId"
    amountBeforeRuntime = Get-BridgeRuntimeProp -Object $proof -Name "amountBeforeRuntime"
    amountAppliedToWallet = Get-BridgeRuntimeProp -Object $proof -Name "amountAppliedToWallet"
    postCreditBalance = Get-BridgeRuntimeProp -Object $proof -Name "postCreditBalance"
    transferAmount = Get-BridgeRuntimeProp -Object $proof -Name "transferAmount"
    recipientBalance = Get-BridgeRuntimeProp -Object $proof -Name "recipientBalance"
    replayAttemptResult = Get-BridgeRuntimeProp -Object $proof -Name "replayAttemptResult"
    timing = $timing
    requiredRuntimeChecks = @($requiredRuntimeChecks)
    missingRuntimeChecks = @($missingRuntimeChecks)
    falseRuntimeChecks = @($falseRuntimeChecks)
    proofFailedChecks = @($proofFailedChecks)
    checks = $checks
    failedChecks = @($failedChecks)
    secretMarkerFindings = @()
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$preliminaryReportText = $report | ConvertTo-Json -Depth 24
$secretMarkerFindings = @(
    Get-BridgeRuntimeSecretMarkerFindings -Text $preliminaryReportText -Label "bridge runtime credit validation report"
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

$reportText = $report | ConvertTo-Json -Depth 24
Assert-FlowChainNoSecretText -Text $reportText -Label "bridge runtime credit validation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 24

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Bridge Runtime Credit Validation")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This validation runs the production-shaped Base 8453 runtime credit proof in an isolated local state, verifies a bridge handoff becomes spendable within the settlement target, rejects replay, spends from the credited wallet, survives restart/export/import, and records no-secret/no-broadcast boundaries.")
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("- $($entry.Key): $($entry.Value)")
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
Assert-FlowChainNoSecretText -Text $markdownText -Label "bridge runtime credit validation markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain bridge runtime credit validation status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    Write-Host "Failed checks: $($failedChecks -join ', ')"
    exit 1
}
exit 0
