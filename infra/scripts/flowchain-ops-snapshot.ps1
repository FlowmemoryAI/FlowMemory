param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/ops-snapshot-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/OPS_SNAPSHOT.md",
    [int] $MonitorDurationSeconds = 20,
    [int] $MonitorPollSeconds = 5,
    [int] $MonitorMaxStateAgeSeconds = 90,
    [string] $InputReportDir = "",
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
$inputReportFullDir = ""
if (-not [string]::IsNullOrWhiteSpace($InputReportDir)) {
    if (-not $NoRefresh.IsPresent) {
        throw "InputReportDir is only supported with -NoRefresh so synthetic incident drills cannot overwrite live evidence."
    }
    $inputReportFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $InputReportDir)
}

function Resolve-OpsInputReportPath {
    param([Parameter(Mandatory = $true)][string] $Path)

    if (-not [string]::IsNullOrWhiteSpace($inputReportFullDir)) {
        return Join-Path $inputReportFullDir (Split-Path -Leaf $Path)
    }

    return Resolve-FlowChainPath -RepoRoot $repoRoot -Path $Path
}

$paths = [ordered]@{
    serviceStatus = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/service-status-report.json"
    serviceMonitor = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/service-monitor-report.json"
    publicRpc = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json"
    backup = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json"
    bridgeLive = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
    bridgeInfra = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
    externalTester = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
    publicDeployment = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json"
    noSecret = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json"
}

function Get-OpsProp {
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

function Get-OpsStatus {
    param([AllowNull()][object] $Report)
    return [string](Get-OpsProp -Object $Report -Name "status" -Default "missing")
}

function Add-OpsFinding {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Findings,
        [Parameter(Mandatory = $true)][string] $Severity,
        [Parameter(Mandatory = $true)][string] $Code,
        [Parameter(Mandatory = $true)][string] $Message,
        [string[]] $Commands = @()
    )

    [void] $Findings.Add([ordered]@{
        severity = $Severity
        code = $Code
        message = $Message
        commands = $Commands
    })
}

function Invoke-OpsChild {
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
        outputLineCount = @($output).Count
    }
}

$refreshSteps = New-Object System.Collections.ArrayList
if (-not $NoRefresh) {
    [void] $refreshSteps.Add((Invoke-OpsChild -Name "service-status" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-status.ps1"), "-AllowBlocked", "-ReportPath", $paths.serviceStatus)))
    [void] $refreshSteps.Add((Invoke-OpsChild -Name "service-monitor" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-monitor.ps1"), "-DurationSeconds", "$MonitorDurationSeconds", "-PollSeconds", "$MonitorPollSeconds", "-MaxStateAgeSeconds", "$MonitorMaxStateAgeSeconds", "-ReportPath", $paths.serviceMonitor)))
}

$reports = [ordered]@{}
foreach ($entry in $paths.GetEnumerator()) {
    $reports[$entry.Key] = Read-FlowChainJsonIfExists -Path $entry.Value
}

$findings = New-Object System.Collections.ArrayList
$service = $reports.serviceStatus
$monitor = $reports.serviceMonitor
$serviceStatus = Get-OpsStatus -Report $service
$monitorStatus = Get-OpsStatus -Report $monitor
$node = Get-OpsProp -Object $service -Name "node"
$controlPlane = Get-OpsProp -Object $service -Name "controlPlane"
$chain = Get-OpsProp -Object $service -Name "chain"
$nodeStatus = [string](Get-OpsProp -Object $node -Name "status" -Default "missing")
$controlPlaneStatus = [string](Get-OpsProp -Object $controlPlane -Name "status" -Default "missing")
$latestHeight = [string](Get-OpsProp -Object $chain -Name "latestHeight" -Default "")
$finalizedHeight = [string](Get-OpsProp -Object $chain -Name "finalizedHeight" -Default "")
$stateAge = [int](Get-OpsProp -Object $chain -Name "stateFileLastWriteAgeSeconds" -Default 999999)
$monitorHeightAdvanced = Get-OpsProp -Object $monitor -Name "heightAdvanced" -Default $false
$monitorSamples = [int](Get-OpsProp -Object $monitor -Name "sampleCount" -Default 0)

if ($serviceStatus -ne "passed") {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "service-status-not-passed" -Message "FlowChain service status is not passed." -Commands @("npm run flowchain:service:status", "npm run flowchain:service:restart -- -LiveProfile")
}
if ($nodeStatus -ne "running") {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "node-not-running" -Message "The block-producing node is not running." -Commands @("npm run flowchain:service:restart -- -LiveProfile", "npm run flowchain:emergency:stop-local")
}
if ($controlPlaneStatus -ne "running") {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "control-plane-not-running" -Message "The control-plane RPC service is not running." -Commands @("npm run flowchain:service:restart -- -LiveProfile")
}
if ($latestHeight -notmatch '^\d+$' -or $finalizedHeight -notmatch '^\d+$') {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "chain-height-unreadable" -Message "Latest/finalized block height is unreadable." -Commands @("npm run flowchain:service:status")
}
if ($stateAge -gt $MonitorMaxStateAgeSeconds) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "state-stale" -Message "State file is stale relative to the monitor threshold." -Commands @("npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30")
}
if ($monitorStatus -ne "passed" -or $monitorHeightAdvanced -ne $true -or $monitorSamples -lt 2) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "height-not-advancing" -Message "Service monitor did not prove advancing block height." -Commands @("npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30", "npm run flowchain:service:restart -- -LiveProfile")
}

$publicRpcStatus = Get-OpsStatus -Report $reports.publicRpc
$backupStatus = Get-OpsStatus -Report $reports.backup
$bridgeLiveStatus = Get-OpsStatus -Report $reports.bridgeLive
$bridgeInfraStatus = Get-OpsStatus -Report $reports.bridgeInfra
$externalTesterStatus = Get-OpsStatus -Report $reports.externalTester
$deploymentStatus = Get-OpsStatus -Report $reports.publicDeployment
$noSecretStatus = Get-OpsStatus -Report $reports.noSecret

if ($publicRpcStatus -ne "passed") {
    Add-OpsFinding -Findings $findings -Severity "blocked" -Code "public-rpc-not-ready" -Message "Public RPC is not ready to share." -Commands @("npm run flowchain:public-rpc:check", "npm run flowchain:public-rpc:validate", "npm run flowchain:public-rpc:abuse-test")
}
if ($backupStatus -ne "passed") {
    Add-OpsFinding -Findings $findings -Severity "blocked" -Code "backup-not-ready" -Message "State backup is not ready for public operation." -Commands @("npm run flowchain:backup:restore:validate", "npm run flowchain:backup:check")
}
if ($bridgeLiveStatus -ne "passed" -or $bridgeInfraStatus -ne "passed") {
    Add-OpsFinding -Findings $findings -Severity "blocked" -Code "bridge-not-ready" -Message "Base 8453 bridge readiness is not ready for external funded testing." -Commands @("npm run flowchain:bridge:live:check", "npm run flowchain:bridge:infra:check", "npm run flowchain:bridge:emergency-stop")
}
if ($externalTesterStatus -ne "passed") {
    Add-OpsFinding -Findings $findings -Severity "blocked" -Code "external-tester-not-shareable" -Message "External tester packet must remain not-shareable." -Commands @("npm run flowchain:tester:readiness", "npm run flowchain:external-tester:packet")
}
if ($deploymentStatus -ne "passed") {
    Add-OpsFinding -Findings $findings -Severity "blocked" -Code "deployment-contract-not-ready" -Message "Public deployment contract is not ready." -Commands @("npm run flowchain:public-deployment:contract -- -AllowBlocked")
}
if ($noSecretStatus -ne "passed") {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "no-secret-scan-not-passed" -Message "No-secret scan is not passed." -Commands @("npm run flowchain:no-secret:scan")
}

$criticalFindings = @($findings | Where-Object { $_.severity -eq "critical" })
$blockedFindings = @($findings | Where-Object { $_.severity -eq "blocked" })
$status = if ($criticalFindings.Count -gt 0) { "failed" } elseif ($blockedFindings.Count -gt 0) { "blocked" } else { "passed" }

$incidentCommands = [ordered]@{
    status = @(
        "npm run flowchain:ops:snapshot",
        "npm run flowchain:service:status",
        "npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30"
    )
    restart = @(
        "npm run flowchain:service:restart -- -LiveProfile",
        "npm run flowchain:service:status"
    )
    backupRecovery = @(
        "npm run flowchain:backup:restore:validate",
        "npm run flowchain:backup:create",
        "npm run flowchain:backup:restore:verify"
    )
    publicExposure = @(
        "npm run flowchain:public-rpc:check",
        "npm run flowchain:public-rpc:abuse-test",
        "npm run flowchain:external-tester:packet"
    )
    drills = @(
        "npm run flowchain:ops:incident-drill",
        "npm run flowchain:ops:snapshot -- -AllowBlocked -NoRefresh"
    )
    emergency = @(
        "npm run flowchain:emergency:stop-local",
        "npm run flowchain:bridge:emergency-stop",
        "npm run flowchain:emergency:export-evidence"
    )
}

$report = [ordered]@{
    schema = "flowchain.ops_snapshot_report.v1"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    refresh = [ordered]@{
        performed = -not $NoRefresh
        steps = @($refreshSteps)
        inputReportDir = $inputReportFullDir
    }
    chain = [ordered]@{
        latestHeight = $latestHeight
        finalizedHeight = $finalizedHeight
        stateFileLastWriteAgeSeconds = $stateAge
        monitorStatus = $monitorStatus
        monitorSamples = $monitorSamples
        monitorHeightAdvanced = $monitorHeightAdvanced
    }
    reportStatuses = [ordered]@{
        serviceStatus = $serviceStatus
        serviceMonitor = $monitorStatus
        publicRpc = $publicRpcStatus
        backup = $backupStatus
        bridgeLive = $bridgeLiveStatus
        bridgeInfra = $bridgeInfraStatus
        externalTester = $externalTesterStatus
        publicDeployment = $deploymentStatus
        noSecret = $noSecretStatus
    }
    findings = @($findings)
    criticalCount = $criticalFindings.Count
    blockedCount = $blockedFindings.Count
    incidentCommands = $incidentCommands
    reportPaths = $paths
    broadcasts = $false
    envValuesPrinted = $false
    noSecrets = $true
}

$reportText = $report | ConvertTo-Json -Depth 18
Assert-FlowChainNoSecretText -Text $reportText -Label "ops snapshot report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Ops Snapshot")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Latest height: $latestHeight")
$markdownLines.Add("Finalized height: $finalizedHeight")
$markdownLines.Add("")
$markdownLines.Add("## Findings")
$markdownLines.Add("")
if ($findings.Count -eq 0) {
    $markdownLines.Add("- None")
}
else {
    foreach ($finding in @($findings)) {
        $markdownLines.Add("- $($finding.severity): $($finding.code) - $($finding.message)")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Incident Commands")
foreach ($group in $incidentCommands.GetEnumerator()) {
    $markdownLines.Add("")
    $markdownLines.Add("### $($group.Key)")
    foreach ($command in @($group.Value)) {
        $markdownLines.Add("- $command")
    }
}
$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "ops snapshot markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain ops snapshot status: $status"
Write-Host "Latest height: $latestHeight"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($criticalFindings.Count -gt 0) {
    Write-Host "Critical findings: $((@($criticalFindings | ForEach-Object { $_.code }) | Select-Object -Unique) -join ', ')"
}
if ($blockedFindings.Count -gt 0) {
    Write-Host "Blocked findings: $((@($blockedFindings | ForEach-Object { $_.code }) | Select-Object -Unique) -join ', ')"
}
if ($status -eq "passed" -or ($status -eq "blocked" -and $AllowBlocked)) {
    exit 0
}
exit 1
