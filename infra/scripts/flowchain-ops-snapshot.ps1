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
    serviceSupervisor = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-report.json"
    serviceMonitor = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/service-monitor-report.json"
    publicRpc = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json"
    backup = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json"
    bridgeLive = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
    bridgeInfra = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
    bridgeRelayer = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-once-report.json"
    bridgeRelayerGuardrail = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-guardrail-validation-report.json"
    externalTester = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
    externalTesterEvidence = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/external-tester-evidence-validation-report.json"
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
$serviceSupervisor = $reports.serviceSupervisor
$monitor = $reports.serviceMonitor
$serviceStatus = Get-OpsStatus -Report $service
$monitorStatus = Get-OpsStatus -Report $monitor
$node = Get-OpsProp -Object $service -Name "node"
$controlPlane = Get-OpsProp -Object $service -Name "controlPlane"
$bridgeRelayerLoop = Get-OpsProp -Object $service -Name "bridgeRelayerLoop"
$bridgeRelayerLoopReport = Get-OpsProp -Object $bridgeRelayerLoop -Name "report"
$chain = Get-OpsProp -Object $service -Name "chain"
$nodeStatus = [string](Get-OpsProp -Object $node -Name "status" -Default "missing")
$controlPlaneStatus = [string](Get-OpsProp -Object $controlPlane -Name "status" -Default "missing")
$bridgeRelayerLoopStatus = [string](Get-OpsProp -Object $bridgeRelayerLoop -Name "status" -Default "stopped")
$bridgeRelayerLoopReportStatus = [string](Get-OpsProp -Object $bridgeRelayerLoopReport -Name "status" -Default "missing")
$bridgeRelayerLoopReportFresh = Get-OpsProp -Object $bridgeRelayerLoopReport -Name "fresh" -Default $false
$bridgeRelayerLoopReportHealthy = Get-OpsProp -Object $bridgeRelayerLoopReport -Name "healthy" -Default $false
$bridgeRelayerLoopReportNoSecrets = Get-OpsProp -Object $bridgeRelayerLoopReport -Name "noSecrets" -Default $false
$bridgeRelayerLoopReportNoBroadcasts = Get-OpsProp -Object $bridgeRelayerLoopReport -Name "noBroadcasts" -Default $false
$bridgeRelayerLoopReportBlockedOnlyOnOwnerInputs = Get-OpsProp -Object $bridgeRelayerLoopReport -Name "blockedOnlyOnOwnerInputs" -Default $false
$supervisorStatus = Get-OpsStatus -Report $serviceSupervisor
$supervisorBridgeRelayerLoop = Get-OpsProp -Object $serviceSupervisor -Name "bridgeRelayerLoop"
$supervisorBridgeRelayerRequested = Get-OpsProp -Object $supervisorBridgeRelayerLoop -Name "requested" -Default $false
$supervisorIterations = @((Get-OpsProp -Object $serviceSupervisor -Name "iterations" -Default @()))
$supervisorLatestIteration = if ($supervisorIterations.Count -gt 0) { $supervisorIterations[$supervisorIterations.Count - 1] } else { $null }
$supervisorLatestAfter = Get-OpsProp -Object $supervisorLatestIteration -Name "after"
$supervisorLatestRestartReasons = @((Get-OpsProp -Object $supervisorLatestIteration -Name "restartReasons" -Default @()))
$supervisorRelayerAfterStatus = [string](Get-OpsProp -Object $supervisorLatestAfter -Name "bridgeRelayerLoopStatus" -Default "missing")
$supervisorRelayerAfterCommandLineMatched = Get-OpsProp -Object $supervisorLatestAfter -Name "bridgeRelayerLoopCommandLineMatched" -Default $false
$supervisorRelayerAfterReportHealthy = Get-OpsProp -Object $supervisorLatestAfter -Name "bridgeRelayerLoopReportHealthy" -Default $false
$supervisorRelayerRecoveryHealthy = (-not ($supervisorBridgeRelayerRequested -eq $true)) -or ($supervisorStatus -in @("passed", "watching") -and $supervisorRelayerAfterStatus -eq "running" -and $supervisorRelayerAfterCommandLineMatched -eq $true -and $supervisorRelayerAfterReportHealthy -eq $true)
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
if ($bridgeRelayerLoopStatus -eq "running" -and $bridgeRelayerLoopReportHealthy -ne $true) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "bridge-relayer-loop-unhealthy" -Message "Bridge relayer loop is running without fresh no-secret/no-broadcast health evidence." -Commands @("npm run flowchain:service:status", "npm run flowchain:bridge:relayer:loop:validate", "npm run flowchain:service:restart -- -LiveProfile -StartBridgeRelayerLoop", "npm run flowchain:bridge:emergency-stop")
}
if ($supervisorBridgeRelayerRequested -eq $true -and $supervisorRelayerRecoveryHealthy -ne $true) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "supervisor-relayer-recovery-failed" -Message "Service supervisor requested the bridge relayer loop but latest recovery evidence does not show a healthy relayer loop." -Commands @("npm run flowchain:service:supervisor -- -Once -StartBridgeRelayerLoop", "npm run flowchain:service:supervisor:validate", "npm run flowchain:service:restart -- -LiveProfile -StartBridgeRelayerLoop", "npm run flowchain:bridge:emergency-stop")
}

$publicRpcStatus = Get-OpsStatus -Report $reports.publicRpc
$backupStatus = Get-OpsStatus -Report $reports.backup
$backupDetails = Get-OpsProp -Object $reports.backup -Name "backup"
$backupRetentionCount = Get-OpsProp -Object $backupDetails -Name "retentionCount" -Default $null
$backupRetentionCandidateCount = Get-OpsProp -Object $backupDetails -Name "retentionCandidateCount" -Default $null
$backupRetentionCurrentSnapshotProtected = Get-OpsProp -Object $backupDetails -Name "retentionCurrentSnapshotProtected" -Default $false
$backupRetentionPruneErrorCount = [int](Get-OpsProp -Object $backupDetails -Name "retentionPruneErrorCount" -Default 0)
$bridgeLiveStatus = Get-OpsStatus -Report $reports.bridgeLive
$bridgeInfraStatus = Get-OpsStatus -Report $reports.bridgeInfra
$bridgeRelayerStatus = Get-OpsStatus -Report $reports.bridgeRelayer
$bridgeRelayerCounts = Get-OpsProp -Object $reports.bridgeRelayer -Name "counts"
$bridgeRelayerTiming = Get-OpsProp -Object $reports.bridgeRelayer -Name "timing"
$bridgeRelayerLatencyGate = [string](Get-OpsProp -Object $bridgeRelayerTiming -Name "latencyGate" -Default "missing")
$bridgeRelayerCursorCommit = Get-OpsProp -Object $reports.bridgeRelayer -Name "cursorCommit"
$bridgeRelayerNewCount = [int](Get-OpsProp -Object $bridgeRelayerCounts -Name "newCredits" -Default 0)
$bridgeRelayerQueuedCount = [int](Get-OpsProp -Object $bridgeRelayerCounts -Name "queuedTransactions" -Default 0)
$bridgeRelayerAppliedCount = [int](Get-OpsProp -Object $bridgeRelayerCounts -Name "appliedCredits" -Default 0)
$bridgeRelayerQueueDisabled = Get-OpsProp -Object $reports.bridgeRelayer -Name "queueDisabled" -Default $true
$bridgeRelayerCursorCommitRequired = Get-OpsProp -Object $bridgeRelayerCursorCommit -Name "finalCommitRequired" -Default $true
$bridgeRelayerCursorCommitted = Get-OpsProp -Object $bridgeRelayerCursorCommit -Name "finalCommitted" -Default $false
$bridgeRelayerCursorReason = [string](Get-OpsProp -Object $bridgeRelayerCursorCommit -Name "reason" -Default "missing")
$bridgeRelayerGuardrailStatus = Get-OpsStatus -Report $reports.bridgeRelayerGuardrail
$bridgeRelayerGuardrailChecks = Get-OpsProp -Object $reports.bridgeRelayerGuardrail -Name "checks"
$bridgeRelayerGuardrailReady = $bridgeRelayerGuardrailStatus -eq "passed" `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "finalCursorUnchanged" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "stagedCursorNotWritten" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "finalCursorNotCommitted" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "noCreditsQueued" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "noCreditsApplied" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "ownerEnvNotImported" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "broadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "envValuesPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "noSecrets" -Default $false) -eq $true)
$externalTesterStatus = Get-OpsStatus -Report $reports.externalTester
$externalTesterEvidenceStatus = Get-OpsStatus -Report $reports.externalTesterEvidence
$externalTesterEvidenceChecks = Get-OpsProp -Object $reports.externalTesterEvidence -Name "checks"
$externalTesterEvidenceFailedChecks = @((Get-OpsProp -Object $reports.externalTesterEvidence -Name "failedChecks" -Default @()))
$externalTesterEvidenceMissingFiles = @((Get-OpsProp -Object $reports.externalTesterEvidence -Name "missingRequiredFiles" -Default @()))
$externalTesterEvidenceInvalidJson = @((Get-OpsProp -Object $reports.externalTesterEvidence -Name "invalidJsonFiles" -Default @()))
$externalTesterEvidenceSecretFindings = @((Get-OpsProp -Object $reports.externalTesterEvidence -Name "secretMarkerFindings" -Default @()))
$externalTesterEvidenceCredentialUrls = @((Get-OpsProp -Object $reports.externalTesterEvidence -Name "credentialUrlFindings" -Default @()))
$externalTesterEvidenceEnvAssignments = @((Get-OpsProp -Object $reports.externalTesterEvidence -Name "envAssignmentFindings" -Default @()))
$externalTesterEvidenceTransferConsistent = (Get-OpsProp -Object $externalTesterEvidenceChecks -Name "transferFound" -Default $false) -eq $true `
    -and (Get-OpsProp -Object $externalTesterEvidenceChecks -Name "transferMatchesAccounts" -Default $false) -eq $true `
    -and (Get-OpsProp -Object $externalTesterEvidenceChecks -Name "transferAmountMatches" -Default $false) -eq $true `
    -and (Get-OpsProp -Object $externalTesterEvidenceChecks -Name "transactionIdMatches" -Default $false) -eq $true `
    -and (Get-OpsProp -Object $externalTesterEvidenceChecks -Name "senderDebited" -Default $false) -eq $true `
    -and (Get-OpsProp -Object $externalTesterEvidenceChecks -Name "recipientCredited" -Default $false) -eq $true
$deploymentStatus = Get-OpsStatus -Report $reports.publicDeployment
$deploymentRefresh = Get-OpsProp -Object $reports.publicDeployment -Name "dependencyRefresh"
$deploymentRefreshAborted = (Get-OpsProp -Object $deploymentRefresh -Name "aborted" -Default $false) -eq $true
$deploymentRefreshAbortStep = [string](Get-OpsProp -Object $deploymentRefresh -Name "abortStepName" -Default "")
$deploymentRefreshAbortReason = [string](Get-OpsProp -Object $deploymentRefresh -Name "abortReason" -Default "")
$deploymentRefreshFailedSteps = @((Get-OpsProp -Object $deploymentRefresh -Name "failedStepNames" -Default @()) | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) })
$deploymentRefreshTimedOutSteps = @((Get-OpsProp -Object $deploymentRefresh -Name "timedOutStepNames" -Default @()) | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) })
$deploymentRefreshSkippedSteps = @((Get-OpsProp -Object $deploymentRefresh -Name "skippedStepNames" -Default @()) | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) })
$deploymentRefreshUnsafe = $deploymentRefreshAborted `
    -or $deploymentRefreshFailedSteps.Count -gt 0 `
    -or $deploymentRefreshTimedOutSteps.Count -gt 0 `
    -or $deploymentRefreshSkippedSteps.Count -gt 0
$noSecretStatus = Get-OpsStatus -Report $reports.noSecret

if ($publicRpcStatus -ne "passed") {
    Add-OpsFinding -Findings $findings -Severity "blocked" -Code "public-rpc-not-ready" -Message "Public RPC is not ready to share." -Commands @("npm run flowchain:public-rpc:check", "npm run flowchain:public-rpc:validate", "npm run flowchain:public-rpc:abuse-test")
}
if ($backupStatus -ne "passed") {
    Add-OpsFinding -Findings $findings -Severity "blocked" -Code "backup-not-ready" -Message "State backup is not ready for public operation." -Commands @("npm run flowchain:backup:restore:validate", "npm run flowchain:backup:check")
}
if ($backupStatus -eq "failed" -and $null -ne $backupRetentionCount -and ($backupRetentionCurrentSnapshotProtected -ne $true -or $backupRetentionPruneErrorCount -gt 0)) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "backup-retention-unsafe" -Message "State backup retention failed to protect the latest snapshot or reported prune errors." -Commands @("npm run flowchain:backup:restore:validate", "npm run flowchain:backup:owner-path:dry-run", "npm run flowchain:backup:check")
}
if ($bridgeLiveStatus -ne "passed" -or $bridgeInfraStatus -ne "passed") {
    Add-OpsFinding -Findings $findings -Severity "blocked" -Code "bridge-not-ready" -Message "Base 8453 bridge readiness is not ready for external funded testing." -Commands @("npm run flowchain:bridge:live:check", "npm run flowchain:bridge:infra:check", "npm run flowchain:bridge:emergency-stop")
}
if ($bridgeRelayerStatus -eq "failed" -or $bridgeRelayerLatencyGate -eq "failed") {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "bridge-relayer-latency-failed" -Message "Bridge relayer failed or exceeded the handoff-to-spendable latency gate." -Commands @("npm run flowchain:bridge:relayer:once -- -AllowBlocked", "npm run flowchain:service:status", "npm run flowchain:bridge:emergency-stop")
}
elseif ($bridgeRelayerStatus -eq "passed" -and ((($bridgeRelayerCursorCommitRequired -eq $true) -and ($bridgeRelayerCursorCommitted -ne $true)) -or ($bridgeRelayerQueueDisabled -eq $true) -or (($bridgeRelayerNewCount -gt 0) -and (($bridgeRelayerQueuedCount -lt $bridgeRelayerNewCount) -or ($bridgeRelayerAppliedCount -ne $bridgeRelayerNewCount))))) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "bridge-relayer-cursor-unsafe" -Message "Bridge relayer passed without a safe final cursor commit after L1 credit proof." -Commands @("npm run flowchain:bridge:relayer:once -- -AllowBlocked", "npm run flowchain:bridge:emergency-stop", "npm run flowchain:service:status")
}
elseif ($bridgeRelayerStatus -ne "passed") {
    Add-OpsFinding -Findings $findings -Severity "blocked" -Code "bridge-relayer-not-ready" -Message "Bridge relayer one-shot proof is not ready." -Commands @("npm run flowchain:bridge:relayer:once -- -AllowBlocked", "npm run flowchain:bridge:live:check", "npm run flowchain:bridge:infra:check")
}
if (-not $bridgeRelayerGuardrailReady) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "bridge-relayer-guardrail-failed" -Message "Bridge relayer fail-closed guardrail proof is not passed." -Commands @("npm run flowchain:bridge:relayer:guardrail:validate", "npm run flowchain:bridge:relayer:once -- -AllowBlocked", "npm run flowchain:bridge:emergency-stop")
}
if ($externalTesterStatus -ne "passed") {
    Add-OpsFinding -Findings $findings -Severity "blocked" -Code "external-tester-not-shareable" -Message "External tester packet must remain not-shareable." -Commands @("npm run flowchain:tester:readiness", "npm run flowchain:external-tester:packet")
}
if ($externalTesterEvidenceSecretFindings.Count -gt 0 -or $externalTesterEvidenceCredentialUrls.Count -gt 0 -or $externalTesterEvidenceEnvAssignments.Count -gt 0) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "external-tester-evidence-unsafe" -Message "External tester returned evidence contains a secret marker, credential URL, or env assignment." -Commands @("npm run flowchain:tester:evidence:validate", "npm run flowchain:no-secret:scan", "npm run flowchain:emergency:export-evidence")
}
elseif ($externalTesterEvidenceStatus -ne "passed" -or $externalTesterEvidenceFailedChecks.Count -gt 0 -or $externalTesterEvidenceMissingFiles.Count -gt 0 -or $externalTesterEvidenceInvalidJson.Count -gt 0 -or $externalTesterEvidenceTransferConsistent -ne $true) {
    Add-OpsFinding -Findings $findings -Severity "blocked" -Code "external-tester-evidence-invalid" -Message "External tester returned evidence validation is not passed or transfer proof is inconsistent." -Commands @("npm run flowchain:tester:evidence:validate", "npm run flowchain:external-tester:packet -- -AllowBlocked")
}
if ($deploymentRefreshUnsafe) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "deployment-refresh-aborted" -Message "Public deployment dependency refresh aborted or skipped dependency gates." -Commands @("npm run flowchain:public-deployment:contract -- -AllowBlocked", "npm run flowchain:public-deployment:contract -- -NoRefresh -AllowBlocked", "npm run flowchain:ops:snapshot -- -AllowBlocked -NoRefresh")
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
    bridgeRelayerLoop = @(
        "npm run flowchain:service:status",
        "npm run flowchain:service:supervisor -- -Once -StartBridgeRelayerLoop",
        "npm run flowchain:bridge:relayer:loop:validate",
        "npm run flowchain:service:restart -- -LiveProfile -StartBridgeRelayerLoop"
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
        serviceSupervisor = $supervisorStatus
        serviceMonitor = $monitorStatus
        bridgeRelayerLoop = $bridgeRelayerLoopStatus
        bridgeRelayerLoopReport = $bridgeRelayerLoopReportStatus
        bridgeRelayerLoopReportFresh = $bridgeRelayerLoopReportFresh
        bridgeRelayerLoopReportHealthy = $bridgeRelayerLoopReportHealthy
        bridgeRelayerLoopReportNoSecrets = $bridgeRelayerLoopReportNoSecrets
        bridgeRelayerLoopReportNoBroadcasts = $bridgeRelayerLoopReportNoBroadcasts
        bridgeRelayerLoopBlockedOnlyOnOwnerInputs = $bridgeRelayerLoopReportBlockedOnlyOnOwnerInputs
        supervisorBridgeRelayerRequested = $supervisorBridgeRelayerRequested
        supervisorBridgeRelayerRecoveryHealthy = $supervisorRelayerRecoveryHealthy
        supervisorBridgeRelayerAfterStatus = $supervisorRelayerAfterStatus
        supervisorBridgeRelayerAfterCommandLineMatched = $supervisorRelayerAfterCommandLineMatched
        supervisorBridgeRelayerAfterReportHealthy = $supervisorRelayerAfterReportHealthy
        supervisorLatestRestartReasons = @($supervisorLatestRestartReasons)
        publicRpc = $publicRpcStatus
        backup = $backupStatus
        backupRetentionCount = $backupRetentionCount
        backupRetentionCandidateCount = $backupRetentionCandidateCount
        backupRetentionCurrentSnapshotProtected = $backupRetentionCurrentSnapshotProtected
        backupRetentionPruneErrorCount = $backupRetentionPruneErrorCount
        bridgeLive = $bridgeLiveStatus
        bridgeInfra = $bridgeInfraStatus
        bridgeRelayer = $bridgeRelayerStatus
        bridgeRelayerGuardrail = $bridgeRelayerGuardrailStatus
        bridgeRelayerGuardrailReady = $bridgeRelayerGuardrailReady
        bridgeRelayerLatencyGate = $bridgeRelayerLatencyGate
        bridgeRelayerCursorCommitRequired = $bridgeRelayerCursorCommitRequired
        bridgeRelayerCursorCommitted = $bridgeRelayerCursorCommitted
        bridgeRelayerCursorReason = $bridgeRelayerCursorReason
        externalTester = $externalTesterStatus
        externalTesterEvidence = $externalTesterEvidenceStatus
        externalTesterEvidenceFailedChecks = $externalTesterEvidenceFailedChecks.Count
        externalTesterEvidenceMissingFiles = $externalTesterEvidenceMissingFiles.Count
        externalTesterEvidenceInvalidJson = $externalTesterEvidenceInvalidJson.Count
        externalTesterEvidenceSecretFindings = $externalTesterEvidenceSecretFindings.Count
        externalTesterEvidenceCredentialUrls = $externalTesterEvidenceCredentialUrls.Count
        externalTesterEvidenceEnvAssignments = $externalTesterEvidenceEnvAssignments.Count
        externalTesterEvidenceTransferConsistent = $externalTesterEvidenceTransferConsistent
        publicDeployment = $deploymentStatus
        deploymentRefreshAborted = $deploymentRefreshAborted
        deploymentRefreshAbortStep = $deploymentRefreshAbortStep
        deploymentRefreshAbortReason = $deploymentRefreshAbortReason
        deploymentRefreshFailedSteps = $deploymentRefreshFailedSteps
        deploymentRefreshTimedOutSteps = $deploymentRefreshTimedOutSteps
        deploymentRefreshSkippedSteps = $deploymentRefreshSkippedSteps
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
