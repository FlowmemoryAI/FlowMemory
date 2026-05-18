param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/service-monitor-report.json",
    [int] $DurationSeconds = 300,
    [int] $PollSeconds = 30,
    [int] $MaxStateAgeSeconds = 90
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$serviceStatusReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-status-report.json"

if ($DurationSeconds -lt 1) {
    throw "DurationSeconds must be at least 1."
}
if ($PollSeconds -lt 1) {
    throw "PollSeconds must be at least 1."
}
if ($MaxStateAgeSeconds -lt 1) {
    throw "MaxStateAgeSeconds must be at least 1."
}

function Get-MonitorProp {
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

function Add-MonitorIssue {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Issues,
        [Parameter(Mandatory = $true)][string] $Code,
        [Parameter(Mandatory = $true)][string] $Reason
    )

    [void] $Issues.Add([ordered]@{
        code = $Code
        reason = $Reason
    })
}

function Get-MonitorSecretMarkerFindings {
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

$startedAt = Get-Date
$deadline = $startedAt.AddSeconds($DurationSeconds)
$samples = New-Object System.Collections.ArrayList
$issues = New-Object System.Collections.ArrayList
$lastHeight = $null
$heightAdvanced = $false

while ((Get-Date) -lt $deadline -or $samples.Count -lt 2) {
    $sampledAt = (Get-Date).ToUniversalTime().ToString("o")
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-service-status.ps1") -AllowBlocked 2>&1
    $exitCode = $LASTEXITCODE
    $report = Read-FlowChainJsonIfExists -Path $serviceStatusReportPath
    $chain = Get-MonitorProp -Object $report -Name "chain"
    $node = Get-MonitorProp -Object $report -Name "node"
    $controlPlane = Get-MonitorProp -Object $report -Name "controlPlane"
    $latestHeight = [string](Get-MonitorProp -Object $chain -Name "latestHeight" -Default "")
    $finalizedHeight = [string](Get-MonitorProp -Object $chain -Name "finalizedHeight" -Default "")
    $stateAge = [int](Get-MonitorProp -Object $chain -Name "stateFileLastWriteAgeSeconds" -Default 999999)
    $serviceStatus = [string](Get-MonitorProp -Object $report -Name "status" -Default "missing")
    $nodeStatus = [string](Get-MonitorProp -Object $node -Name "status" -Default "missing")
    $controlPlaneStatus = [string](Get-MonitorProp -Object $controlPlane -Name "status" -Default "missing")

    if ($exitCode -ne 0 -or $serviceStatus -ne "passed") {
        Add-MonitorIssue -Issues $issues -Code "service-status-not-passed" -Reason "service-status did not pass at sample $sampledAt"
    }
    if ($nodeStatus -ne "running") {
        Add-MonitorIssue -Issues $issues -Code "node-not-running" -Reason "node was not running at sample $sampledAt"
    }
    if ($controlPlaneStatus -ne "running") {
        Add-MonitorIssue -Issues $issues -Code "control-plane-not-running" -Reason "control plane was not running at sample $sampledAt"
    }
    if ($latestHeight -notmatch '^\d+$') {
        Add-MonitorIssue -Issues $issues -Code "height-unreadable" -Reason "latest height was unreadable at sample $sampledAt"
    }
    elseif ($null -ne $lastHeight) {
        if ([int64]$latestHeight -lt [int64]$lastHeight) {
            Add-MonitorIssue -Issues $issues -Code "height-regressed" -Reason "latest height regressed at sample $sampledAt"
        }
        if ([int64]$latestHeight -gt [int64]$lastHeight) {
            $heightAdvanced = $true
        }
    }
    if ($stateAge -gt $MaxStateAgeSeconds) {
        Add-MonitorIssue -Issues $issues -Code "state-stale" -Reason "state file age exceeded $MaxStateAgeSeconds seconds at sample $sampledAt"
    }

    [void] $samples.Add([ordered]@{
        sampledAt = $sampledAt
        exitCode = $exitCode
        serviceStatus = $serviceStatus
        nodeStatus = $nodeStatus
        controlPlaneStatus = $controlPlaneStatus
        latestHeight = $latestHeight
        finalizedHeight = $finalizedHeight
        stateFileLastWriteAgeSeconds = $stateAge
        outputRedacted = @($output | ForEach-Object { "$_" })
    })

    if ($latestHeight -match '^\d+$') {
        $lastHeight = $latestHeight
    }

    if ((Get-Date) -ge $deadline -and $samples.Count -ge 2) {
        break
    }
    $remainingSeconds = [int](($deadline - (Get-Date)).TotalSeconds)
    $sleepSeconds = if ($remainingSeconds -lt 1 -and $samples.Count -lt 2) {
        1
    }
    else {
        [Math]::Min($PollSeconds, [Math]::Max(1, $remainingSeconds))
    }
    Start-Sleep -Seconds $sleepSeconds
}

$firstSample = $samples[0]
$lastSample = $samples[$samples.Count - 1]
$firstHeight = [string](Get-MonitorProp -Object $firstSample -Name "latestHeight" -Default "")
$lastObservedHeight = [string](Get-MonitorProp -Object $lastSample -Name "latestHeight" -Default "")
if ($samples.Count -lt 2) {
    Add-MonitorIssue -Issues $issues -Code "insufficient-samples" -Reason "service monitor requires at least two samples to prove height progression"
}
if (-not $heightAdvanced) {
    Add-MonitorIssue -Issues $issues -Code "height-did-not-advance" -Reason "latest height did not advance during the monitor window"
}

$issueCodes = @($issues | ForEach-Object { [string](Get-MonitorProp -Object $_ -Name "code" -Default "") })
$uniqueIssueCodes = @($issueCodes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
$checks = [ordered]@{
    sampleCountSufficient = $samples.Count -ge 2
    serviceStatusSamplesPassed = ($uniqueIssueCodes -notcontains "service-status-not-passed")
    nodeRunningEverySample = ($uniqueIssueCodes -notcontains "node-not-running")
    controlPlaneRunningEverySample = ($uniqueIssueCodes -notcontains "control-plane-not-running")
    heightsReadable = ($uniqueIssueCodes -notcontains "height-unreadable")
    heightNeverRegressed = ($uniqueIssueCodes -notcontains "height-regressed")
    stateFreshEverySample = ($uniqueIssueCodes -notcontains "state-stale")
    heightAdvanced = $heightAdvanced -eq $true
    issuesEmpty = $issues.Count -eq 0
    envValuesPrintedFalse = $true
    secretMarkerFindingsEmpty = $true
    noSecrets = $true
    broadcastsFalse = $true
}

$report = [ordered]@{
    schema = "flowchain.service_monitor_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "pending"
    durationSeconds = $DurationSeconds
    pollSeconds = $PollSeconds
    maxStateAgeSeconds = $MaxStateAgeSeconds
    sampleCount = $samples.Count
    firstHeight = $firstHeight
    latestHeight = $lastObservedHeight
    heightAdvanced = $heightAdvanced
    samples = @($samples)
    issues = @($issues)
    issueCodes = @($uniqueIssueCodes)
    checks = $checks
    failedChecks = @()
    secretMarkerFindings = @()
    reportPaths = [ordered]@{
        serviceStatus = $serviceStatusReportPath
        serviceMonitor = $reportFullPath
    }
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$preliminaryReportText = $report | ConvertTo-Json -Depth 16
$secretMarkerFindings = @(Get-MonitorSecretMarkerFindings -Text $preliminaryReportText -Label "service monitor report")
$checks["secretMarkerFindingsEmpty"] = $secretMarkerFindings.Count -eq 0
$checks["noSecrets"] = $secretMarkerFindings.Count -eq 0
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
$report["status"] = $status
$report["checks"] = $checks
$report["failedChecks"] = @($failedChecks)
$report["secretMarkerFindings"] = @($secretMarkerFindings)
$report["noSecrets"] = $secretMarkerFindings.Count -eq 0

$reportText = $report | ConvertTo-Json -Depth 16
Assert-FlowChainNoSecretText -Text $reportText -Label "service monitor report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

Write-Host "FlowChain service monitor status: $status"
Write-Host "Samples: $($samples.Count)"
Write-Host "Height: $firstHeight -> $lastObservedHeight"
Write-Host "Report: $reportFullPath"
if ($issues.Count -gt 0) {
    Write-Host "Issues: $((@($issues | ForEach-Object { $_.code }) | Select-Object -Unique) -join ', ')"
    exit 1
}
exit 0
