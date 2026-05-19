param(
    [string] $ValidationDir = "devnet/local/bridge-relayer-guardrail-validation",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-relayer-guardrail-validation-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/BRIDGE_RELAYER_GUARDRAIL_VALIDATION.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$validationFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ValidationDir)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$tmpDir = Join-Path $validationFullDir "tmp"
$runDir = Join-Path $validationFullDir "run"
$statePath = Join-Path $validationFullDir "state.json"
$nodeDir = Join-Path $validationFullDir "node"
$cursorPath = Join-Path $validationFullDir "final-cursor.json"
$stagedCursorPath = Join-Path $validationFullDir "staged-cursor.json"
$relayerReportPath = Join-Path $validationFullDir "bridge-relayer-once-report.json"
$directObserveReportRelPath = Join-Path $ValidationDir "direct-observe-report.json"
$directObserveReportPath = Join-Path $validationFullDir "direct-observe-report.json"
$directObserveFinalCursorPath = Join-Path $validationFullDir "direct-observe-final-cursor.json"
$directObserveStagedCursorPath = Join-Path $validationFullDir "direct-observe-staged-cursor.json"
$bridgeRelayerSourcePath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "services/bridge-relayer/src/observe-base-lockbox.ts"
$bridgeRelayerTestPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "services/bridge-relayer/test/bridge-relayer.test.ts"

$requiredEnvNames = @(
    "FLOWCHAIN_OWNER_ENV_FILE",
    "FLOWCHAIN_PILOT_OPERATOR_ACK",
    "FLOWCHAIN_BASE8453_RPC_URL",
    "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
    "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
    "FLOWCHAIN_BASE8453_ASSET_DECIMALS",
    "FLOWCHAIN_BASE8453_FROM_BLOCK",
    "FLOWCHAIN_BASE8453_CURSOR_STATE",
    "FLOWCHAIN_BASE8453_TO_BLOCK",
    "FLOWCHAIN_BASE8453_OBSERVE_CURSOR_STATE",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_PILOT_CONFIRMATIONS",
    "FLOWCHAIN_OWNER_ENV_DEFAULT_IMPORT_DISABLED"
)

function Invoke-GuardrailChild {
    param(
        [Parameter(Mandatory = $true)][string[]] $ArgumentList,
        [int] $TimeoutSeconds = 180
    )

    New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
    $runId = "$(Get-Date -Format 'yyyyMMddHHmmssfff')-$PID-$([Guid]::NewGuid().ToString("N").Substring(0, 8))"
    $stdoutPath = Join-Path $tmpDir "$runId.stdout.log"
    $stderrPath = Join-Path $tmpDir "$runId.stderr.log"
    $timedOut = $false
    $exitCode = 1

    try {
        $process = Start-Process -FilePath "powershell.exe" `
            -ArgumentList (Join-FlowChainProcessArguments -ArgumentList $ArgumentList) `
            -WorkingDirectory $repoRoot `
            -PassThru `
            -WindowStyle Hidden `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath
        $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
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
        Set-Content -LiteralPath $stderrPath -Value $_.Exception.Message -Encoding UTF8
        $exitCode = 1
    }

    $output = @()
    if (Test-Path -LiteralPath $stdoutPath) {
        $output += @(Get-Content -LiteralPath $stdoutPath -Tail 40)
    }
    if (Test-Path -LiteralPath $stderrPath) {
        $output += @(Get-Content -LiteralPath $stderrPath -Tail 40)
    }

    return [pscustomobject]([ordered]@{
        exitCode = [int]$exitCode
        timedOut = $timedOut
        stdoutPath = $stdoutPath
        stderrPath = $stderrPath
        outputRedacted = @($output | ForEach-Object { "$_" })
    })
}

function Get-GuardrailProp {
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

function Get-GuardrailIssueCodePresent {
    param(
        [AllowNull()][object[]] $Issues,
        [Parameter(Mandatory = $true)][string] $Code,
        [Parameter(Mandatory = $true)][string] $Kind
    )

    foreach ($issue in @($Issues)) {
        if ("$(Get-GuardrailProp -Object $issue -Name "code")" -eq $Code -and "$(Get-GuardrailProp -Object $issue -Name "kind")" -eq $Kind) {
            return $true
        }
    }
    return $false
}

function Get-GuardrailSecretMarkerFindings {
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

Reset-FlowChainDirectory -Path $validationFullDir | Out-Null
New-Item -ItemType Directory -Force -Path $nodeDir, $runDir | Out-Null

$cursorSeed = [ordered]@{
    schema = "flowchain.bridge_cursor_state.guardrail_validation.v0"
    validationSentinel = "final-cursor-must-not-change"
    lastScannedBlock = "12345"
    generatedAt = "2026-05-17T00:00:00.0000000Z"
}
Write-FlowChainJson -Path $cursorPath -Value $cursorSeed -Depth 8
$cursorHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $cursorPath).Hash
Write-FlowChainJson -Path $directObserveFinalCursorPath -Value $cursorSeed -Depth 8
$directObserveFinalCursorHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $directObserveFinalCursorPath).Hash

$savedEnv = @{}
foreach ($name in $requiredEnvNames) {
    $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
    [Environment]::SetEnvironmentVariable($name, $null, "Process")
}
[Environment]::SetEnvironmentVariable("FLOWCHAIN_OWNER_ENV_DEFAULT_IMPORT_DISABLED", "1", "Process")

$child = $null
try {
    $child = Invoke-GuardrailChild -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Join-Path $PSScriptRoot "flowchain-bridge-relayer-once.ps1"),
        "-StatePath",
        $statePath,
        "-NodeDir",
        $nodeDir,
        "-RunDir",
        $runDir,
        "-ReportPath",
        $relayerReportPath,
        "-CursorState",
        $cursorPath,
        "-CursorStagingPath",
        $stagedCursorPath,
        "-AllowBlocked"
    )
}
finally {
    foreach ($name in $requiredEnvNames) {
        [Environment]::SetEnvironmentVariable($name, $savedEnv[$name], "Process")
    }
}

$relayerReport = Read-FlowChainJsonIfExists -Path $relayerReportPath
$cursorHashAfter = if (Test-Path -LiteralPath $cursorPath) { (Get-FileHash -Algorithm SHA256 -LiteralPath $cursorPath).Hash } else { "" }
$readiness = Get-GuardrailProp -Object $relayerReport -Name "readiness"
$cursorCommit = Get-GuardrailProp -Object $relayerReport -Name "cursorCommit"
$counts = Get-GuardrailProp -Object $relayerReport -Name "counts"
$ownerEnvFile = Get-GuardrailProp -Object $relayerReport -Name "ownerEnvFile"
$issues = @(Get-GuardrailProp -Object $relayerReport -Name "issues" -Default @())
$relayerSteps = @(Get-GuardrailProp -Object $relayerReport -Name "steps" -Default @())
$relayerTimedOutSteps = @($relayerSteps | Where-Object { (Get-GuardrailProp -Object $_ -Name "timedOut" -Default $false) -eq $true })

$directObserveSavedEnv = @{}
$directObserveEnvNames = @($requiredEnvNames + @("FLOWCHAIN_BASE8453_CURSOR_STATE") | Select-Object -Unique)
foreach ($name in $directObserveEnvNames) {
    $directObserveSavedEnv[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
    [Environment]::SetEnvironmentVariable($name, $null, "Process")
}
[Environment]::SetEnvironmentVariable("FLOWCHAIN_OWNER_ENV_DEFAULT_IMPORT_DISABLED", "1", "Process")
[Environment]::SetEnvironmentVariable("FLOWCHAIN_BASE8453_CURSOR_STATE", $directObserveFinalCursorPath, "Process")
[Environment]::SetEnvironmentVariable("FLOWCHAIN_BASE8453_OBSERVE_CURSOR_STATE", $directObserveStagedCursorPath, "Process")
$directObserveChild = $null
try {
    $directObserveChild = Invoke-GuardrailChild -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Join-Path $PSScriptRoot "bridge-base-mainnet-pilot-observe.ps1"),
        "-ReportPath",
        $directObserveReportRelPath
    )
}
finally {
    foreach ($name in $directObserveEnvNames) {
        [Environment]::SetEnvironmentVariable($name, $directObserveSavedEnv[$name], "Process")
    }
}
$directObserveReport = Read-FlowChainJsonIfExists -Path $directObserveReportPath
$directObserveCursor = Get-GuardrailProp -Object $directObserveReport -Name "cursor"
$directObserveFinalCursorHashAfter = if (Test-Path -LiteralPath $directObserveFinalCursorPath) { (Get-FileHash -Algorithm SHA256 -LiteralPath $directObserveFinalCursorPath).Hash } else { "" }
$directObserveOutputText = @($directObserveChild.outputRedacted) -join "`n"
if (-not [string]::IsNullOrWhiteSpace($directObserveOutputText)) {
    Assert-FlowChainNoSecretText -Text $directObserveOutputText -Label "bridge direct observe guardrail output"
}

$bridgeTestChild = Invoke-GuardrailChild -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-Command",
    "npm run bridge:test"
) -TimeoutSeconds 300
$bridgeTestOutputText = @($bridgeTestChild.outputRedacted) -join "`n"
if (-not [string]::IsNullOrWhiteSpace($bridgeTestOutputText)) {
    Assert-FlowChainNoSecretText -Text $bridgeTestOutputText -Label "bridge relayer test output"
}
$bridgeRelayerSourceText = Get-Content -Raw -LiteralPath $bridgeRelayerSourcePath
$bridgeRelayerTestText = Get-Content -Raw -LiteralPath $bridgeRelayerTestPath

$checks = [ordered]@{
    relayerCommandExitedZeroWithAllowBlocked = ([int]$child.exitCode -eq 0)
    relayerReportWritten = Test-Path -LiteralPath $relayerReportPath
    relayerStatusBlocked = "$(Get-GuardrailProp -Object $relayerReport -Name "status")" -eq "blocked"
    relayerChildTimeoutRecorded = [int](Get-GuardrailProp -Object $relayerReport -Name "childTimeoutSeconds" -Default 0) -ge 1
    relayerNoChildTimeouts = $relayerTimedOutSteps.Count -eq 0
    blockedBeforeLiveReadiness = "$(Get-GuardrailProp -Object $readiness -Name "infra")" -eq "blocked" -and "$(Get-GuardrailProp -Object $readiness -Name "live")" -eq "not-run"
    externalOwnerIssueRecorded = Get-GuardrailIssueCodePresent -Issues $issues -Code "bridge-infra-not-passed" -Kind "external"
    finalCursorUnchanged = $cursorHashBefore -eq $cursorHashAfter
    stagedCursorNotWritten = -not (Test-Path -LiteralPath $stagedCursorPath)
    finalCursorNotCommitted = (Get-GuardrailProp -Object $cursorCommit -Name "finalCommitted" -Default $true) -eq $false
    noCreditsObserved = [int](Get-GuardrailProp -Object $counts -Name "observedCredits" -Default -1) -eq 0
    noCreditsQueued = [int](Get-GuardrailProp -Object $counts -Name "queuedTransactions" -Default -1) -eq 0
    noCreditsApplied = [int](Get-GuardrailProp -Object $counts -Name "appliedCredits" -Default -1) -eq 0
    ownerEnvNotImported = (Get-GuardrailProp -Object $ownerEnvFile -Name "imported" -Default $true) -eq $false
    directObserveFailedClosed = "$(Get-GuardrailProp -Object $directObserveReport -Name "status")" -eq "blocked"
    directObserveReportWritten = Test-Path -LiteralPath $directObserveReportPath
    directObserveStatusBlocked = "$(Get-GuardrailProp -Object $directObserveReport -Name "status")" -eq "blocked"
    directObserveUsesStagedCursorByDefault = (Get-GuardrailProp -Object $directObserveCursor -Name "directObserveUsesStagedCursorByDefault" -Default $false) -eq $true
    directObserveCursorNotFinal = (Get-GuardrailProp -Object $directObserveCursor -Name "cursorStateIsFinalCursor" -Default $true) -eq $false
    directObserveFinalCursorUnchanged = $directObserveFinalCursorHashBefore -eq $directObserveFinalCursorHashAfter
    directObserveStagedCursorNotWritten = -not (Test-Path -LiteralPath $directObserveStagedCursorPath)
    directObserveBroadcastsFalse = (Get-GuardrailProp -Object $directObserveReport -Name "broadcasts" -Default $true) -eq $false
    directObserveEnvValuesPrintedFalse = (Get-GuardrailProp -Object $directObserveReport -Name "envValuesPrinted" -Default $true) -eq $false
    directObserveNoSecrets = (Get-GuardrailProp -Object $directObserveReport -Name "noSecrets" -Default $false) -eq $true
    bridgeRelayerTestsPassed = ([int]$bridgeTestChild.exitCode -eq 0)
    bridgeRelayerConcurrencyTestCovered = $bridgeRelayerTestText.Contains("Base public-network pilot cursor serializes concurrent same-process scans")
    bridgeCursorAsyncLockImplemented = $bridgeRelayerSourceText.Contains("async function acquireBridgeStateFileLock")
    bridgeCursorLockUsesAsyncRetry = $bridgeRelayerSourceText.Contains("await sleep(APPLICATION_STATE_LOCK_RETRY_MS)")
    broadcastsFalse = (Get-GuardrailProp -Object $relayerReport -Name "broadcasts" -Default $true) -eq $false
    envValuesPrintedFalse = (Get-GuardrailProp -Object $relayerReport -Name "envValuesPrinted" -Default $true) -eq $false
    noSecrets = (Get-GuardrailProp -Object $relayerReport -Name "noSecrets" -Default $false) -eq $true
    secretMarkerFindingsEmpty = $true
}
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.bridge_relayer_guardrail_validation_report.v1"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    validationDir = $ValidationDir
    relayerReportPath = $relayerReportPath
    childProcess = [ordered]@{
        exitCode = [int]$child.exitCode
        timedOut = [bool]$child.timedOut
        stdoutPath = [string]$child.stdoutPath
        stderrPath = [string]$child.stderrPath
    }
    checks = $checks
    failedChecks = @($failedChecks)
    secretMarkerFindings = @()
    cursor = [ordered]@{
        finalCursorPath = $cursorPath
        stagedCursorPath = $stagedCursorPath
        beforeSha256 = $cursorHashBefore
        afterSha256 = $cursorHashAfter
    }
    directObserve = [ordered]@{
        reportPath = $directObserveReportPath
        finalCursorPath = $directObserveFinalCursorPath
        stagedCursorPath = $directObserveStagedCursorPath
        finalCursorBeforeSha256 = $directObserveFinalCursorHashBefore
        finalCursorAfterSha256 = $directObserveFinalCursorHashAfter
        childProcess = [ordered]@{
            exitCode = [int]$directObserveChild.exitCode
            timedOut = [bool]$directObserveChild.timedOut
        }
        cursor = $directObserveCursor
    }
    bridgeRelayerTests = [ordered]@{
        exitCode = [int]$bridgeTestChild.exitCode
        timedOut = [bool]$bridgeTestChild.timedOut
        stdoutPath = [string]$bridgeTestChild.stdoutPath
        stderrPath = [string]$bridgeTestChild.stderrPath
    }
    requiredEnvNamesClearedForScenario = @($requiredEnvNames)
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$preliminaryReportText = $report | ConvertTo-Json -Depth 18
$secretMarkerFindings = @(
    Get-GuardrailSecretMarkerFindings -Text $preliminaryReportText -Label "bridge relayer guardrail validation report"
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
Assert-FlowChainNoSecretText -Text $reportText -Label "bridge relayer guardrail validation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Bridge Relayer Guardrail Validation")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This validation proves a relayer run with missing owner Base 8453 inputs exits as an allowed blocked state without mutating the final Base scan cursor, staging a cursor, queueing credits, printing env values, or broadcasting. It also runs the bridge relayer unit suite and requires the same-process cursor concurrency test so the Base scan cursor cannot double-scan under concurrent SDK or harness calls.")
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
Assert-FlowChainNoSecretText -Text $markdownText -Label "bridge relayer guardrail validation markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain bridge relayer guardrail validation status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    Write-Host "Failed checks: $($failedChecks -join ', ')"
    exit 1
}
exit 0
