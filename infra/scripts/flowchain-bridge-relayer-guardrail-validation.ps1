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
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_PILOT_CONFIRMATIONS"
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
        $process = Start-Process -FilePath "powershell" `
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

    return [ordered]@{
        exitCode = [int]$exitCode
        timedOut = $timedOut
        stdoutPath = $stdoutPath
        stderrPath = $stderrPath
        outputRedacted = @($output | ForEach-Object { "$_" })
    }
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

$savedEnv = @{}
foreach ($name in $requiredEnvNames) {
    $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
    [Environment]::SetEnvironmentVariable($name, $null, "Process")
}

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

$checks = [ordered]@{
    relayerCommandExitedZeroWithAllowBlocked = ([int]$child.exitCode -eq 0)
    relayerReportWritten = Test-Path -LiteralPath $relayerReportPath
    relayerStatusBlocked = "$(Get-GuardrailProp -Object $relayerReport -Name "status")" -eq "blocked"
    blockedBeforeLiveReadiness = "$(Get-GuardrailProp -Object $readiness -Name "infra")" -eq "blocked" -and "$(Get-GuardrailProp -Object $readiness -Name "live")" -eq "not-run"
    externalOwnerIssueRecorded = Get-GuardrailIssueCodePresent -Issues $issues -Code "bridge-infra-not-passed" -Kind "external"
    finalCursorUnchanged = $cursorHashBefore -eq $cursorHashAfter
    stagedCursorNotWritten = -not (Test-Path -LiteralPath $stagedCursorPath)
    finalCursorNotCommitted = (Get-GuardrailProp -Object $cursorCommit -Name "finalCommitted" -Default $true) -eq $false
    noCreditsObserved = [int](Get-GuardrailProp -Object $counts -Name "observedCredits" -Default -1) -eq 0
    noCreditsQueued = [int](Get-GuardrailProp -Object $counts -Name "queuedTransactions" -Default -1) -eq 0
    noCreditsApplied = [int](Get-GuardrailProp -Object $counts -Name "appliedCredits" -Default -1) -eq 0
    ownerEnvNotImported = (Get-GuardrailProp -Object $ownerEnvFile -Name "imported" -Default $true) -eq $false
    broadcastsFalse = (Get-GuardrailProp -Object $relayerReport -Name "broadcasts" -Default $true) -eq $false
    envValuesPrintedFalse = (Get-GuardrailProp -Object $relayerReport -Name "envValuesPrinted" -Default $true) -eq $false
    noSecrets = (Get-GuardrailProp -Object $relayerReport -Name "noSecrets" -Default $false) -eq $true
}
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.bridge_relayer_guardrail_validation_report.v0"
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
    cursor = [ordered]@{
        finalCursorPath = $cursorPath
        stagedCursorPath = $stagedCursorPath
        beforeSha256 = $cursorHashBefore
        afterSha256 = $cursorHashAfter
    }
    requiredEnvNamesClearedForScenario = @($requiredEnvNames)
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$reportText = $report | ConvertTo-Json -Depth 18
Assert-FlowChainNoSecretText -Text $reportText -Label "bridge relayer guardrail validation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Bridge Relayer Guardrail Validation")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This validation proves a relayer run with missing owner Base 8453 inputs exits as an allowed blocked state without mutating the final Base scan cursor, staging a cursor, queueing credits, printing env values, or broadcasting.")
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
