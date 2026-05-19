param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/incident-drill-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/INCIDENT_DRILL.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$runDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/incident-drills")
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

$baseReportPaths = [ordered]@{
    "service-status-report.json" = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-status-report.json"
    "service-supervisor-report.json" = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-report.json"
    "service-monitor-report.json" = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-monitor-report.json"
    "public-rpc-readiness-report.json" = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json"
    "backup-readiness-report.json" = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json"
    "bridge-live-readiness-report.json" = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
    "bridge-infra-readiness-report.json" = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
    "bridge-relayer-once-report.json" = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-once-report.json"
    "bridge-relayer-guardrail-validation-report.json" = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-guardrail-validation-report.json"
    "external-tester-readiness-report.json" = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
    "public-deployment-contract-report.json" = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json"
    "no-secret-scan-report.json" = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json"
}

function Get-DrillProp {
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

function Set-DrillProp {
    param(
        [Parameter(Mandatory = $true)][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name,
        [AllowNull()][object] $Value
    )

    if ($Object.PSObject.Properties.Name -contains $Name) {
        $Object.$Name = $Value
    }
    else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function New-DrillFallbackReport {
    param([Parameter(Mandatory = $true)][string] $LeafName)

    switch ($LeafName) {
        "service-status-report.json" {
            return [ordered]@{
                schema = "flowchain.service_status_report.v0"
                generatedAt = (Get-Date).ToUniversalTime().ToString("o")
                status = "failed"
                node = [ordered]@{ status = "missing" }
                controlPlane = [ordered]@{ status = "missing" }
                chain = [ordered]@{ latestHeight = ""; finalizedHeight = ""; stateFileLastWriteAgeSeconds = 999999 }
                problems = @([ordered]@{ category = "process"; name = "service-status-report"; reason = "fallback report created by incident drill" })
                envValuesPrinted = $false
                noSecrets = $true
            }
        }
        "service-monitor-report.json" {
            return [ordered]@{
                schema = "flowchain.service_monitor_report.v0"
                generatedAt = (Get-Date).ToUniversalTime().ToString("o")
                status = "failed"
                sampleCount = 0
                firstHeight = ""
                latestHeight = ""
                heightAdvanced = $false
                issues = @([ordered]@{ code = "missing-monitor-report"; reason = "fallback report created by incident drill" })
                envValuesPrinted = $false
                noSecrets = $true
                broadcasts = $false
            }
        }
        "service-supervisor-report.json" {
            return [ordered]@{
                schema = "flowchain.service_supervisor_report.v0"
                generatedAt = (Get-Date).ToUniversalTime().ToString("o")
                status = "passed"
                restartAttempts = 0
                bridgeRelayerLoop = [ordered]@{
                    requested = $false
                    pollSeconds = 30
                    postRestartSettleSeconds = 20
                    postRestartPollSeconds = 1
                }
                iterations = @()
                envValuesPrinted = $false
                noSecrets = $true
                broadcasts = $false
            }
        }
        "no-secret-scan-report.json" {
            return [ordered]@{
                schema = "flowchain.no_secret_scan_report.v0"
                generatedAt = (Get-Date).ToUniversalTime().ToString("o")
                status = "passed"
                noSecrets = $true
                envValuesPrinted = $false
            }
        }
        "bridge-relayer-guardrail-validation-report.json" {
            return [ordered]@{
                schema = "flowchain.bridge_relayer_guardrail_validation_report.v0"
                generatedAt = (Get-Date).ToUniversalTime().ToString("o")
                status = "failed"
                checks = [ordered]@{
                    finalCursorUnchanged = $false
                    stagedCursorNotWritten = $false
                    finalCursorNotCommitted = $false
                    noCreditsQueued = $false
                    noCreditsApplied = $false
                    ownerEnvNotImported = $false
                    directObserveFailedClosed = $false
                    directObserveReportWritten = $false
                    directObserveStatusBlocked = $false
                    directObserveUsesStagedCursorByDefault = $false
                    directObserveCursorNotFinal = $false
                    directObserveFinalCursorUnchanged = $false
                    directObserveStagedCursorNotWritten = $false
                    directObserveBroadcastsFalse = $false
                    directObserveEnvValuesPrintedFalse = $false
                    directObserveNoSecrets = $false
                    broadcastsFalse = $false
                    envValuesPrintedFalse = $false
                    noSecrets = $false
                }
                envValuesPrinted = $false
                noSecrets = $false
                broadcasts = $false
            }
        }
        default {
            return [ordered]@{
                schema = "flowchain.synthetic_incident_input.v0"
                generatedAt = (Get-Date).ToUniversalTime().ToString("o")
                status = "blocked"
                missingEnvNames = @()
                problems = @()
                envValuesPrinted = $false
                noSecrets = $true
            }
        }
    }
}

function Copy-DrillBaseReports {
    param([Parameter(Mandatory = $true)][string] $InputDir)

    New-Item -ItemType Directory -Force -Path $InputDir | Out-Null
    foreach ($entry in $baseReportPaths.GetEnumerator()) {
        $target = Join-Path $InputDir $entry.Key
        if (Test-Path -LiteralPath $entry.Value) {
            Copy-Item -LiteralPath $entry.Value -Destination $target -Force
        }
        else {
            Write-FlowChainJson -Path $target -Value (New-DrillFallbackReport -LeafName $entry.Key) -Depth 12
        }
    }
}

function Update-DrillJsonReport {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][scriptblock] $Mutator
    )

    $report = Read-FlowChainJsonIfExists -Path $Path
    if ($null -eq $report) {
        throw "Incident drill could not read synthetic report: $Path"
    }
    & $Mutator $report
    Write-FlowChainJson -Path $Path -Value $report -Depth 18
}

function Invoke-DrillChild {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string[]] $ArgumentList
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = (& powershell @ArgumentList 2>&1) | ForEach-Object { "$_" }
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) {
            $exitCode = 0
        }
    }
    catch {
        $output = @($_.Exception.Message)
        $exitCode = 1
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    return [ordered]@{
        name = $Name
        exitCode = [int] $exitCode
        outputTail = @($output | Select-Object -Last 12)
    }
}

function Test-DrillCommandGroups {
    param([AllowNull()][object] $Report)

    $commands = Get-DrillProp -Object $Report -Name "incidentCommands"
    foreach ($name in @("status", "restart", "backupRecovery", "publicExposure", "emergency")) {
        $group = Get-DrillProp -Object $commands -Name $name -Default @()
        if (@($group).Count -eq 0) {
            return $false
        }
    }
    return $true
}

function Get-DrillFindingCodes {
    param([AllowNull()][object] $Report)

    $codes = New-Object System.Collections.ArrayList
    foreach ($finding in @((Get-DrillProp -Object $Report -Name "findings" -Default @()))) {
        $code = [string](Get-DrillProp -Object $finding -Name "code" -Default "")
        if (-not [string]::IsNullOrWhiteSpace($code) -and -not $codes.Contains($code)) {
            [void] $codes.Add($code)
        }
    }
    return @($codes)
}

function Get-DrillSecretMarkerFindings {
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

$cases = New-Object System.Collections.ArrayList

function Add-DrillResult {
    param(
        [Parameter(Mandatory = $true)][string] $Id,
        [Parameter(Mandatory = $true)][string] $Requirement,
        [Parameter(Mandatory = $true)][bool] $Passed,
        [Parameter(Mandatory = $true)][string] $Evidence,
        [AllowNull()][object] $Child = $null,
        [AllowNull()][object] $Report = $null,
        [string[]] $ExpectedCodes = @()
    )

    [void] $cases.Add([ordered]@{
        id = $Id
        requirement = $Requirement
        status = if ($Passed) { "passed" } else { "failed" }
        evidence = $Evidence
        expectedCodes = $ExpectedCodes
        child = $Child
        reportStatus = Get-DrillProp -Object $Report -Name "status" -Default ""
        criticalCount = Get-DrillProp -Object $Report -Name "criticalCount" -Default $null
        blockedCount = Get-DrillProp -Object $Report -Name "blockedCount" -Default $null
        findingCodes = Get-DrillFindingCodes -Report $Report
    })
}

function Invoke-SyntheticOpsCase {
    param(
        [Parameter(Mandatory = $true)][string] $Id,
        [Parameter(Mandatory = $true)][string] $Requirement,
        [Parameter(Mandatory = $true)][string] $ExpectedStatus,
        [string[]] $ExpectedCodes = @(),
        [scriptblock] $Mutate = $null
    )

    $caseDir = Join-Path $runDir $Id
    $inputDir = Join-Path $caseDir "input"
    New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
    Copy-DrillBaseReports -InputDir $inputDir
    if ($null -ne $Mutate) {
        & $Mutate $inputDir
    }

    $caseReportPath = Join-Path $caseDir "ops-snapshot-report.json"
    $caseMarkdownPath = Join-Path $caseDir "OPS_SNAPSHOT.md"
    $child = Invoke-DrillChild -Name $Id -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Join-Path $PSScriptRoot "flowchain-ops-snapshot.ps1"),
        "-AllowBlocked",
        "-NoRefresh",
        "-InputReportDir",
        $inputDir,
        "-ReportPath",
        $caseReportPath,
        "-MarkdownPath",
        $caseMarkdownPath
    )
    $caseReport = Read-FlowChainJsonIfExists -Path $caseReportPath
    $actualStatus = [string](Get-DrillProp -Object $caseReport -Name "status" -Default "missing")
    $codes = Get-DrillFindingCodes -Report $caseReport
    $missingCodes = @($ExpectedCodes | Where-Object { $_ -notin $codes })
    $exitMatches = if ($ExpectedStatus -eq "failed") { $child.exitCode -ne 0 } else { $child.exitCode -eq 0 }
    $safeFlags = (Get-DrillProp -Object $caseReport -Name "envValuesPrinted" -Default $true) -eq $false `
        -and (Get-DrillProp -Object $caseReport -Name "noSecrets" -Default $false) -eq $true `
        -and (Get-DrillProp -Object $caseReport -Name "broadcasts" -Default $true) -eq $false
    $commandsPresent = Test-DrillCommandGroups -Report $caseReport
    $passed = $actualStatus -eq $ExpectedStatus `
        -and $missingCodes.Count -eq 0 `
        -and $exitMatches `
        -and $safeFlags `
        -and $commandsPresent

    Add-DrillResult -Id $Id `
        -Requirement $Requirement `
        -Passed $passed `
        -Evidence "expectedStatus=$ExpectedStatus, actualStatus=$actualStatus, exitCode=$($child.exitCode), missingCodes=$($missingCodes.Count), commandsPresent=$commandsPresent, safeFlags=$safeFlags" `
        -Child $child `
        -Report $caseReport `
        -ExpectedCodes $ExpectedCodes
}

$liveStateBefore = Get-FlowChainStateFacts -StatePath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/state.json")

Invoke-SyntheticOpsCase -Id "baseline-owner-blockers-only" `
    -Requirement "Expected owner-input blockers remain blocked without being classified as critical incidents." `
    -ExpectedStatus "blocked" `
    -ExpectedCodes @("public-rpc-not-ready", "backup-not-ready", "bridge-not-ready", "external-tester-not-shareable", "deployment-contract-not-ready")

Invoke-SyntheticOpsCase -Id "deployment-refresh-aborted-critical" `
    -Requirement "A public deployment dependency refresh abort is classified as a critical incident with recovery commands." `
    -ExpectedStatus "failed" `
    -ExpectedCodes @("deployment-refresh-aborted") `
    -Mutate {
        param([string] $InputDir)
        Update-DrillJsonReport -Path (Join-Path $InputDir "public-deployment-contract-report.json") -Mutator {
            param($report)
            Set-DrillProp -Object $report -Name "status" -Value "failed"
            $refresh = Get-DrillProp -Object $report -Name "dependencyRefresh"
            if ($null -eq $refresh) {
                $refresh = [ordered]@{}
                Set-DrillProp -Object $report -Name "dependencyRefresh" -Value $refresh
            }
            Set-DrillProp -Object $refresh -Name "aborted" -Value $true
            Set-DrillProp -Object $refresh -Name "abortStepName" -Value "service-status"
            Set-DrillProp -Object $refresh -Name "abortReason" -Value "synthetic incident drill deployment refresh abort"
            Set-DrillProp -Object $refresh -Name "failedStepNames" -Value @("service-status")
            Set-DrillProp -Object $refresh -Name "timedOutStepNames" -Value @("service-status")
            Set-DrillProp -Object $refresh -Name "skippedStepNames" -Value @("service-monitor")
        }
    }

Invoke-SyntheticOpsCase -Id "node-down-critical" `
    -Requirement "A stopped block-producing node is classified as a critical incident with restart commands." `
    -ExpectedStatus "failed" `
    -ExpectedCodes @("service-status-not-passed", "node-not-running") `
    -Mutate {
        param([string] $InputDir)
        Update-DrillJsonReport -Path (Join-Path $InputDir "service-status-report.json") -Mutator {
            param($report)
            Set-DrillProp -Object $report -Name "status" -Value "failed"
            Set-DrillProp -Object (Get-DrillProp -Object $report -Name "node") -Name "status" -Value "stopped"
            Set-DrillProp -Object $report -Name "problems" -Value @([ordered]@{ category = "process"; name = "node"; reason = "synthetic incident drill node-down" })
        }
    }

Invoke-SyntheticOpsCase -Id "control-plane-down-critical" `
    -Requirement "A stopped control-plane RPC service is classified as a critical incident." `
    -ExpectedStatus "failed" `
    -ExpectedCodes @("service-status-not-passed", "control-plane-not-running") `
    -Mutate {
        param([string] $InputDir)
        Update-DrillJsonReport -Path (Join-Path $InputDir "service-status-report.json") -Mutator {
            param($report)
            Set-DrillProp -Object $report -Name "status" -Value "failed"
            Set-DrillProp -Object (Get-DrillProp -Object $report -Name "controlPlane") -Name "status" -Value "stopped"
            Set-DrillProp -Object $report -Name "problems" -Value @([ordered]@{ category = "process"; name = "control-plane"; reason = "synthetic incident drill control-plane-down" })
        }
    }

Invoke-SyntheticOpsCase -Id "stale-state-critical" `
    -Requirement "A stale state file is classified as a critical incident even when service reports are otherwise readable." `
    -ExpectedStatus "failed" `
    -ExpectedCodes @("state-stale") `
    -Mutate {
        param([string] $InputDir)
        Update-DrillJsonReport -Path (Join-Path $InputDir "service-status-report.json") -Mutator {
            param($report)
            $chain = Get-DrillProp -Object $report -Name "chain"
            Set-DrillProp -Object $chain -Name "stateFileLastWriteAgeSeconds" -Value 999999
        }
    }

Invoke-SyntheticOpsCase -Id "height-not-advancing-critical" `
    -Requirement "A monitor window with stagnant block height is classified as a critical incident." `
    -ExpectedStatus "failed" `
    -ExpectedCodes @("height-not-advancing") `
    -Mutate {
        param([string] $InputDir)
        Update-DrillJsonReport -Path (Join-Path $InputDir "service-monitor-report.json") -Mutator {
            param($report)
            Set-DrillProp -Object $report -Name "status" -Value "failed"
            Set-DrillProp -Object $report -Name "sampleCount" -Value 2
            Set-DrillProp -Object $report -Name "heightAdvanced" -Value $false
            Set-DrillProp -Object $report -Name "firstHeight" -Value "100"
            Set-DrillProp -Object $report -Name "latestHeight" -Value "100"
            Set-DrillProp -Object $report -Name "issues" -Value @([ordered]@{ code = "height-did-not-advance"; reason = "synthetic incident drill stagnant height" })
        }
    }

Invoke-SyntheticOpsCase -Id "no-secret-scan-critical" `
    -Requirement "A failed no-secret scan is classified as a critical incident before sharing any public artifacts." `
    -ExpectedStatus "failed" `
    -ExpectedCodes @("no-secret-scan-not-passed") `
    -Mutate {
        param([string] $InputDir)
        Update-DrillJsonReport -Path (Join-Path $InputDir "no-secret-scan-report.json") -Mutator {
            param($report)
            Set-DrillProp -Object $report -Name "status" -Value "failed"
            Set-DrillProp -Object $report -Name "noSecrets" -Value $false
            Set-DrillProp -Object $report -Name "findings" -Value @([ordered]@{ path = "synthetic"; reason = "incident drill synthetic secret finding" })
        }
    }

Invoke-SyntheticOpsCase -Id "bridge-relayer-guardrail-critical" `
    -Requirement "A failed bridge relayer guardrail proof is classified as a critical incident before any relayer loop can be trusted." `
    -ExpectedStatus "failed" `
    -ExpectedCodes @("bridge-relayer-guardrail-failed") `
    -Mutate {
        param([string] $InputDir)
        Update-DrillJsonReport -Path (Join-Path $InputDir "bridge-relayer-guardrail-validation-report.json") -Mutator {
            param($report)
            Set-DrillProp -Object $report -Name "status" -Value "failed"
            $checks = Get-DrillProp -Object $report -Name "checks"
            foreach ($name in @("finalCursorUnchanged", "stagedCursorNotWritten", "finalCursorNotCommitted", "noCreditsQueued", "noCreditsApplied", "ownerEnvNotImported", "broadcastsFalse", "envValuesPrintedFalse", "noSecrets")) {
                Set-DrillProp -Object $checks -Name $name -Value $false
            }
            Set-DrillProp -Object $report -Name "envValuesPrinted" -Value $false
            Set-DrillProp -Object $report -Name "noSecrets" -Value $false
            Set-DrillProp -Object $report -Name "broadcasts" -Value $false
        }
    }

Invoke-SyntheticOpsCase -Id "bridge-direct-observe-cursor-critical" `
    -Requirement "A standalone Base observer that does not default to staged cursor state is classified as a critical incident." `
    -ExpectedStatus "failed" `
    -ExpectedCodes @("bridge-direct-observe-cursor-unsafe") `
    -Mutate {
        param([string] $InputDir)
        Update-DrillJsonReport -Path (Join-Path $InputDir "bridge-relayer-guardrail-validation-report.json") -Mutator {
            param($report)
            Set-DrillProp -Object $report -Name "status" -Value "passed"
            $checks = Get-DrillProp -Object $report -Name "checks"
            if ($null -eq $checks) {
                $checks = [ordered]@{}
                Set-DrillProp -Object $report -Name "checks" -Value $checks
            }
            foreach ($name in @("finalCursorUnchanged", "stagedCursorNotWritten", "finalCursorNotCommitted", "noCreditsQueued", "noCreditsApplied", "ownerEnvNotImported", "broadcastsFalse", "envValuesPrintedFalse", "noSecrets", "secretMarkerFindingsEmpty")) {
                Set-DrillProp -Object $checks -Name $name -Value $true
            }
            foreach ($name in @("directObserveFailedClosed", "directObserveReportWritten", "directObserveStatusBlocked", "directObserveBroadcastsFalse", "directObserveEnvValuesPrintedFalse", "directObserveNoSecrets")) {
                Set-DrillProp -Object $checks -Name $name -Value $true
            }
            foreach ($name in @("directObserveUsesStagedCursorByDefault", "directObserveCursorNotFinal", "directObserveFinalCursorUnchanged", "directObserveStagedCursorNotWritten")) {
                Set-DrillProp -Object $checks -Name $name -Value $false
            }
            $directObserve = Get-DrillProp -Object $report -Name "directObserve"
            if ($null -eq $directObserve) {
                $directObserve = [ordered]@{}
                Set-DrillProp -Object $report -Name "directObserve" -Value $directObserve
            }
            Set-DrillProp -Object $directObserve -Name "finalCursorAfterSha256" -Value "synthetic-final-cursor-changed"
            $cursor = Get-DrillProp -Object $directObserve -Name "cursor"
            if ($null -eq $cursor) {
                $cursor = [ordered]@{}
                Set-DrillProp -Object $directObserve -Name "cursor" -Value $cursor
            }
            Set-DrillProp -Object $cursor -Name "mode" -Value "unsafe-final-cursor"
            Set-DrillProp -Object $cursor -Name "cursorStateIsFinalCursor" -Value $true
            Set-DrillProp -Object $cursor -Name "directObserveUsesStagedCursorByDefault" -Value $false
            Set-DrillProp -Object $cursor -Name "ownerFinalCursorRequested" -Value $false
            Set-DrillProp -Object $report -Name "failedChecks" -Value @()
            Set-DrillProp -Object $report -Name "secretMarkerFindings" -Value @()
            Set-DrillProp -Object $report -Name "envValuesPrinted" -Value $false
            Set-DrillProp -Object $report -Name "noSecrets" -Value $true
            Set-DrillProp -Object $report -Name "broadcasts" -Value $false
        }
    }

Invoke-SyntheticOpsCase -Id "bridge-relayer-loop-unhealthy-critical" `
    -Requirement "A running bridge relayer loop without fresh no-secret/no-broadcast health evidence is classified as a critical incident." `
    -ExpectedStatus "failed" `
    -ExpectedCodes @("bridge-relayer-loop-unhealthy") `
    -Mutate {
        param([string] $InputDir)
        Update-DrillJsonReport -Path (Join-Path $InputDir "service-status-report.json") -Mutator {
            param($report)
            Set-DrillProp -Object $report -Name "status" -Value "passed"
            $loop = Get-DrillProp -Object $report -Name "bridgeRelayerLoop"
            if ($null -eq $loop) {
                $loop = [ordered]@{}
                Set-DrillProp -Object $report -Name "bridgeRelayerLoop" -Value $loop
            }
            Set-DrillProp -Object $loop -Name "status" -Value "running"
            Set-DrillProp -Object $loop -Name "commandLineMatched" -Value $true
            Set-DrillProp -Object $loop -Name "report" -Value ([ordered]@{
                path = "devnet/local/bridge-live-readiness/bridge-relayer-loop-report.json"
                status = "blocked"
                ageSeconds = 999999
                maxAgeSeconds = 180
                fresh = $false
                acceptableStatus = $true
                blockedOnlyOnOwnerInputs = $true
                codeIssueCount = 0
                noSecrets = $true
                noBroadcasts = $true
                healthy = $false
            })
        }
    }

Invoke-SyntheticOpsCase -Id "supervisor-relayer-recovery-failed-critical" `
    -Requirement "A supervisor configured for bridge relayer loop recovery that still reports an unhealthy relayer after restart is classified as a critical incident." `
    -ExpectedStatus "failed" `
    -ExpectedCodes @("supervisor-relayer-recovery-failed") `
    -Mutate {
        param([string] $InputDir)
        Update-DrillJsonReport -Path (Join-Path $InputDir "service-supervisor-report.json") -Mutator {
            param($report)
            Set-DrillProp -Object $report -Name "status" -Value "failed"
            Set-DrillProp -Object $report -Name "restartAttempts" -Value 1
            Set-DrillProp -Object $report -Name "bridgeRelayerLoop" -Value ([ordered]@{
                requested = $true
                pollSeconds = 5
                postRestartSettleSeconds = 30
                postRestartPollSeconds = 1
            })
            Set-DrillProp -Object $report -Name "iterations" -Value @(
                [ordered]@{
                    sampledAt = (Get-Date).ToUniversalTime().ToString("o")
                    restartReasons = @("bridge-relayer-loop-not-running")
                    restartNeeded = $true
                    restartPerformed = $true
                    after = [ordered]@{
                        exitCode = 0
                        reportStatus = "passed"
                        nodeStatus = "running"
                        controlPlaneStatus = "running"
                        latestHeight = "100"
                        finalizedHeight = "100"
                        stateFileLastWriteAgeSeconds = 1
                        liveProfile = $true
                        maxBlocks = 0
                        bridgeRelayerLoopStatus = "stopped"
                        bridgeRelayerLoopPid = 0
                        bridgeRelayerLoopCommandLineMatched = $false
                        bridgeRelayerLoopReportStatus = "missing"
                        bridgeRelayerLoopReportHealthy = $false
                    }
                }
            )
            Set-DrillProp -Object $report -Name "envValuesPrinted" -Value $false
            Set-DrillProp -Object $report -Name "noSecrets" -Value $true
            Set-DrillProp -Object $report -Name "broadcasts" -Value $false
        }
    }

$recoveryReportPath = Join-Path $runDir "recovery-commands-report.json"
$recoveryChild = Invoke-DrillChild -Name "recovery-command-print" -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (Join-Path $PSScriptRoot "flowchain-emergency-print-recovery.ps1"),
    "-ReportPath",
    $recoveryReportPath
)
$recoveryReport = Read-FlowChainJsonIfExists -Path $recoveryReportPath
$recoverySteps = @((Get-DrillProp -Object $recoveryReport -Name "steps" -Default @()))
$recoveryEmergencyCommands = @((Get-DrillProp -Object $recoveryReport -Name "emergencyStopCommands" -Default @()))
$recoveryPassed = $recoveryChild.exitCode -eq 0 `
    -and $recoverySteps -contains "npm run flowchain:emergency:export-evidence" `
    -and $recoverySteps -contains "npm run flowchain:bridge:live:check" `
    -and $recoveryEmergencyCommands -contains "npm run flowchain:emergency:stop-local" `
    -and $recoveryEmergencyCommands -contains "npm run flowchain:bridge:emergency-stop"
Add-DrillResult -Id "recovery-command-print" `
    -Requirement "Emergency recovery commands are printable to a no-values report without stopping live services." `
    -Passed $recoveryPassed `
    -Evidence "exitCode=$($recoveryChild.exitCode), recoverySteps=$($recoverySteps.Count), emergencyCommands=$($recoveryEmergencyCommands.Count)" `
    -Child $recoveryChild `
    -Report $recoveryReport

$postStatusReportPath = Join-Path $runDir "post-drill-service-status-report.json"
$postStatusChild = Invoke-DrillChild -Name "post-drill-live-status" -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (Join-Path $PSScriptRoot "flowchain-service-status.ps1"),
    "-AllowBlocked",
    "-ReportPath",
    $postStatusReportPath
)
$postStatusReport = Read-FlowChainJsonIfExists -Path $postStatusReportPath
$postStatus = [string](Get-DrillProp -Object $postStatusReport -Name "status" -Default "missing")
$postNodeStatus = [string](Get-DrillProp -Object (Get-DrillProp -Object $postStatusReport -Name "node") -Name "status" -Default "")
$postControlStatus = [string](Get-DrillProp -Object (Get-DrillProp -Object $postStatusReport -Name "controlPlane") -Name "status" -Default "")
$postStatusPassed = $postStatusChild.exitCode -eq 0 -and $postStatus -eq "passed" -and $postNodeStatus -eq "running" -and $postControlStatus -eq "running"
Add-DrillResult -Id "post-drill-live-status" `
    -Requirement "Incident drills leave the live local chain services running and readable." `
    -Passed $postStatusPassed `
    -Evidence "exitCode=$($postStatusChild.exitCode), status=$postStatus, node=$postNodeStatus, controlPlane=$postControlStatus" `
    -Child $postStatusChild `
    -Report $postStatusReport

$liveStateAfter = Get-FlowChainStateFacts -StatePath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/state.json")
$failedCases = @($cases | Where-Object { $_.status -ne "passed" })
$requiredScenarios = @(
    "baseline-owner-blockers-only",
    "deployment-refresh-aborted-critical",
    "node-down-critical",
    "control-plane-down-critical",
    "stale-state-critical",
    "height-not-advancing-critical",
    "no-secret-scan-critical",
    "bridge-relayer-guardrail-critical",
    "bridge-direct-observe-cursor-critical",
    "bridge-relayer-loop-unhealthy-critical",
    "supervisor-relayer-recovery-failed-critical",
    "recovery-command-print",
    "post-drill-live-status"
)
$caseIds = @($cases | ForEach-Object { $_.id })
$missingRequiredScenarios = @($requiredScenarios | Where-Object { $_ -notin $caseIds })
$liveBlockBefore = [int64](Get-DrillProp -Object $liveStateBefore -Name "blockCount" -Default 0)
$liveBlockAfter = [int64](Get-DrillProp -Object $liveStateAfter -Name "blockCount" -Default 0)
$checks = [ordered]@{
    incidentDrillReady = $false
    ownerValuesRequiredFalse = $true
    mutatesLiveStateFalse = $true
    syntheticIncidentInputs = $true
    allRequiredScenariosCovered = $missingRequiredScenarios.Count -eq 0
    allCasesPassed = $failedCases.Count -eq 0
    failedCasesAbsent = $failedCases.Count -eq 0
    minimumCaseCountMet = $cases.Count -ge 13
    recoveryCommandPrinted = $recoveryPassed
    postDrillLiveStatusPassed = $postStatusPassed
    liveStateBeforeReadable = (Get-DrillProp -Object $liveStateBefore -Name "readable" -Default $false) -eq $true
    liveStateAfterReadable = (Get-DrillProp -Object $liveStateAfter -Name "readable" -Default $false) -eq $true
    liveBlockHeightAdvancedOrEqual = $liveBlockAfter -ge $liveBlockBefore
    noLiveBroadcast = $true
    broadcastsFalse = $true
    envValuesPrintedFalse = $true
    noSecrets = $true
    secretMarkerFindingsEmpty = $true
}
$report = [ordered]@{
    schema = "flowchain.incident_drill_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "pending"
    incidentDrillReady = $false
    validationScope = "synthetic-ops-snapshot-incidents-plus-live-postcheck"
    ownerValuesRequired = $false
    mutatesLiveState = $false
    syntheticIncidentInputs = $true
    checks = $checks
    failedChecks = @()
    secretMarkerFindings = @()
    caseCounts = [ordered]@{
        passed = @($cases | Where-Object { $_.status -eq "passed" }).Count
        failed = $failedCases.Count
        total = $cases.Count
    }
    requiredScenarios = @($requiredScenarios)
    missingRequiredScenarios = @($missingRequiredScenarios)
    cases = @($cases)
    liveStateBefore = $liveStateBefore
    liveStateAfter = $liveStateAfter
    reportPaths = [ordered]@{
        report = $reportFullPath
        markdown = $markdownFullPath
        runDir = $runDir
        recovery = $recoveryReportPath
        postDrillServiceStatus = $postStatusReportPath
    }
    noLiveBroadcast = $true
    broadcasts = $false
    envValuesPrinted = $false
    noSecrets = $true
}

$preliminaryReportText = $report | ConvertTo-Json -Depth 24
$secretMarkerFindings = @(Get-DrillSecretMarkerFindings -Text $preliminaryReportText -Label "incident drill report")
$checks["secretMarkerFindingsEmpty"] = $secretMarkerFindings.Count -eq 0
$checks["noSecrets"] = $secretMarkerFindings.Count -eq 0
$preReadyFailedChecks = @($checks.GetEnumerator() | Where-Object { $_.Key -ne "incidentDrillReady" -and $_.Value -ne $true } | ForEach-Object { $_.Key })
$checks["incidentDrillReady"] = $preReadyFailedChecks.Count -eq 0
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
$report["status"] = $status
$report["incidentDrillReady"] = $status -eq "passed"
$report["checks"] = $checks
$report["failedChecks"] = @($failedChecks)
$report["secretMarkerFindings"] = @($secretMarkerFindings)
$report["noSecrets"] = $secretMarkerFindings.Count -eq 0

$reportText = $report | ConvertTo-Json -Depth 24
Assert-FlowChainNoSecretText -Text $reportText -Label "incident drill report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 24

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Incident Drill")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Incident drill ready: $($report.incidentDrillReady)")
$markdownLines.Add("")
$markdownLines.Add("This drill uses synthetic ops input reports for incident conditions, then checks the live local services are still running. It does not stop services, mutate chain state, broadcast bridge transactions, or require owner values.")
$markdownLines.Add("")
$markdownLines.Add("## Cases")
$markdownLines.Add("")
$markdownLines.Add("| Case | Status | Evidence |")
$markdownLines.Add("| --- | --- | --- |")
foreach ($case in @($cases)) {
    $markdownLines.Add("| $($case.id) | $($case.status) | $($case.evidence.Replace('|','/')) |")
}
$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "incident drill markdown"
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain incident drill status: $status"
Write-Host "Cases: passed=$($report.caseCounts.passed), failed=$($report.caseCounts.failed), total=$($report.caseCounts.total)"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($failedCases.Count -gt 0) {
    Write-Host "Failed cases: $((@($failedCases | ForEach-Object { $_.id })) -join ', ')"
    exit 1
}
exit 0
