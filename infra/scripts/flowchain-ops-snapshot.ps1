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
    publicRpcDeploymentBundle = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json"
    publicRpcDeploymentAutomation = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json"
    backup = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json"
    bridgeLive = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
    bridgeInfra = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
    bridgeRelayer = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-once-report.json"
    bridgeRelayerGuardrail = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-guardrail-validation-report.json"
    externalTester = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
    externalTesterEvidence = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/external-tester-evidence-validation-report.json"
    dashboardUi = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/dashboard-ui-readiness-report.json"
    ownerInputsValidation = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-validation-report.json"
    ownerActivationPlan = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/owner-activation-plan-report.json"
    publicDeployment = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json"
    truthTable = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/production-truth-table-report.json"
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
$publicRpcDeploymentBundle = $reports.publicRpcDeploymentBundle
$publicRpcDeploymentAutomation = $reports.publicRpcDeploymentAutomation
$publicRpcDeploymentBundleStatus = Get-OpsStatus -Report $publicRpcDeploymentBundle
$publicRpcDeploymentAutomationStatus = Get-OpsStatus -Report $publicRpcDeploymentAutomation
$publicRpcDeploymentBundleChecks = Get-OpsProp -Object $publicRpcDeploymentBundle -Name "checks"
$publicRpcDeploymentAutomationChecks = Get-OpsProp -Object $publicRpcDeploymentAutomation -Name "checks"
$publicRpcRequiredCutoverCommands = @(
    "npm run flowchain:tester:gateway:e2e",
    "npm run flowchain:wallet:live-tester:e2e",
    "npm run flowchain:live:cutover:rehearsal -- -AllowBlocked",
    "npm run flowchain:truth-table -- -AllowBlocked",
    "npm run flowchain:no-secret:scan"
)
$publicRpcDeploymentBundleRequiredCommands = @((Get-OpsProp -Object $publicRpcDeploymentBundle -Name "requiredCommands" -Default @()) | ForEach-Object { "$_" })
$publicRpcDeploymentBundleWalletCutoverProofReady = @($publicRpcRequiredCutoverCommands | Where-Object { $_ -notin $publicRpcDeploymentBundleRequiredCommands }).Count -eq 0
$publicRpcDeploymentAutomationWalletCutoverProofReady = ((Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesTesterGatewayE2e" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesWalletTesterE2e" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesCutoverRehearsal" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesTruthTable" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesNoSecretScan" -Default $false) -eq $true)
$publicRpcEdgeHardeningReady = $publicRpcDeploymentBundleStatus -eq "passed" `
    -and $publicRpcDeploymentAutomationStatus -eq "passed" `
    -and ((Get-OpsProp -Object $publicRpcDeploymentBundleChecks -Name "includesDisallowedOriginPreflight" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentBundleChecks -Name "includesBroadStateBlockedPreflight" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentBundleChecks -Name "includesPrivateWalletCreateBlockedPreflight" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentBundleChecks -Name "authorizationForwardingScopedToTesterWrite" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentBundleChecks -Name "includesSecurityHeaders" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentBundleChecks -Name "preflightsCheckSecurityHeaders" -Default $false) -eq $true) `
    -and ($publicRpcDeploymentBundleWalletCutoverProofReady -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentBundle -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentBundle -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightHasDisallowedOriginProbe" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightBlocksBroadStatePath" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightBlocksPrivateWalletCreate" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedNginxAuthorizationForwardingScoped" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedNginxHasSecurityHeaders" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightChecksSecurityHeaders" -Default $false) -eq $true) `
    -and ($publicRpcDeploymentAutomationWalletCutoverProofReady -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomation -Name "broadcasts" -Default $true) -eq $false)
$backupStatus = Get-OpsStatus -Report $reports.backup
$backupDetails = Get-OpsProp -Object $reports.backup -Name "backup"
$backupRetentionCount = Get-OpsProp -Object $backupDetails -Name "retentionCount" -Default $null
$backupRetentionCandidateCount = Get-OpsProp -Object $backupDetails -Name "retentionCandidateCount" -Default $null
$backupRetentionCurrentSnapshotProtected = Get-OpsProp -Object $backupDetails -Name "retentionCurrentSnapshotProtected" -Default $false
$backupRetentionPruneErrorCount = [int](Get-OpsProp -Object $backupDetails -Name "retentionPruneErrorCount" -Default 0)
$bridgeLiveStatus = Get-OpsStatus -Report $reports.bridgeLive
$bridgeInfraStatus = Get-OpsStatus -Report $reports.bridgeInfra
$bridgeRelayerStatus = Get-OpsStatus -Report $reports.bridgeRelayer
$bridgeRelayerChecks = Get-OpsProp -Object $reports.bridgeRelayer -Name "checks"
$bridgeRelayerFailedChecks = @((Get-OpsProp -Object $reports.bridgeRelayer -Name "failedChecks" -Default @()))
$bridgeRelayerRequiredCheckNames = @(
    "statusKnown",
    "requiredEnvNamesPresent",
    "childTimeoutRecorded",
    "childProcessesDidNotTimeout",
    "broadcastsFalse",
    "envValuesPrintedFalse",
    "noSecrets",
    "readinessInfraChecked",
    "readinessLiveCheckedWhenInfraPassed",
    "blockedBeforeLiveReadinessWhenInfraBlocked",
    "blockedBeforeObservationWhenReadinessBlocked",
    "noQueuedTransactionsWhenBlocked",
    "noAppliedCreditsWhenBlocked",
    "cursorModeStaged",
    "finalCursorNotCommittedWhenBlocked",
    "finalCursorPathInsideRepo",
    "stagedCursorPathInsideRepo",
    "issuesClassified",
    "externalBlockerClassifiedWhenBlocked",
    "latencyGateRecorded",
    "latencyGatePassedWhenApplied",
    "queueAndApplyMatchWhenPassed",
    "cursorSafeWhenPassed"
)
$bridgeRelayerMissingChecks = @($bridgeRelayerRequiredCheckNames | Where-Object {
    (Get-OpsProp -Object $bridgeRelayerChecks -Name $_ -Default $false) -ne $true
})
$bridgeRelayerCheckContractReady = $bridgeRelayerStatus -in @("passed", "blocked") `
    -and $bridgeRelayerFailedChecks.Count -eq 0 `
    -and $bridgeRelayerMissingChecks.Count -eq 0 `
    -and ((Get-OpsProp -Object $reports.bridgeRelayer -Name "broadcasts" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $reports.bridgeRelayer -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $reports.bridgeRelayer -Name "noSecrets" -Default $false) -eq $true)
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
$bridgeRelayerDirectObserveGuardrailReady = $bridgeRelayerGuardrailStatus -eq "passed" `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveFailedClosed" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveReportWritten" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveStatusBlocked" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveUsesStagedCursorByDefault" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveCursorNotFinal" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveFinalCursorUnchanged" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveStagedCursorNotWritten" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveBroadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveEnvValuesPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveNoSecrets" -Default $false) -eq $true)
$bridgeRelayerGuardrailReady = $bridgeRelayerGuardrailStatus -eq "passed" `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "finalCursorUnchanged" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "stagedCursorNotWritten" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "finalCursorNotCommitted" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "noCreditsQueued" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "noCreditsApplied" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "ownerEnvNotImported" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "broadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "envValuesPrintedFalse" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "noSecrets" -Default $false) -eq $true) `
    -and $bridgeRelayerDirectObserveGuardrailReady
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
$dashboardUiStatus = Get-OpsStatus -Report $reports.dashboardUi
$dashboardUiChecks = Get-OpsProp -Object $reports.dashboardUi -Name "checks"
$dashboardUiReady = $dashboardUiStatus -eq "passed" `
    -and ((Get-OpsProp -Object $dashboardUiChecks -Name "testerWalletCreateCovered" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $dashboardUiChecks -Name "testerFaucetCovered" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $dashboardUiChecks -Name "testerSendCovered" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $dashboardUiChecks -Name "testerLaunchRouteCovered" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $dashboardUiChecks -Name "explorerRouteCovered" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $dashboardUiChecks -Name "activationRouteCovered" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $dashboardUiChecks -Name "noSecretLeakageAsserted" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $dashboardUiChecks -Name "dashboardBrowserE2ePassed" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $dashboardUiChecks -Name "dashboardBuildPassed" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $reports.dashboardUi -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $reports.dashboardUi -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $reports.dashboardUi -Name "broadcasts" -Default $true) -eq $false)
$ownerInputsValidationStatus = Get-OpsStatus -Report $reports.ownerInputsValidation
$ownerInputsValidationScenarios = @((Get-OpsProp -Object $reports.ownerInputsValidation -Name "scenarios" -Default @()))
$ownerInputsValidationFailedScenarios = @($ownerInputsValidationScenarios | Where-Object { (Get-OpsProp -Object $_ -Name "passed" -Default $false) -ne $true })
$ownerInputsValidationRequiredEnvNames = @((Get-OpsProp -Object $reports.ownerInputsValidation -Name "requiredEnvNames" -Default @()))
$ownerInputsValidationReady = $ownerInputsValidationStatus -eq "passed" `
    -and $ownerInputsValidationScenarios.Count -ge 6 `
    -and $ownerInputsValidationFailedScenarios.Count -eq 0 `
    -and $ownerInputsValidationRequiredEnvNames.Count -gt 0 `
    -and ((Get-OpsProp -Object $reports.ownerInputsValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $reports.ownerInputsValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $reports.ownerInputsValidation -Name "broadcasts" -Default $true) -eq $false)
$ownerActivationPlanStatus = Get-OpsStatus -Report $reports.ownerActivationPlan
$ownerActivationPlanFailedChecks = @((Get-OpsProp -Object $reports.ownerActivationPlan -Name "failedChecks" -Default @()))
$ownerActivationPlanSecretFindings = @((Get-OpsProp -Object $reports.ownerActivationPlan -Name "secretMarkerFindings" -Default @()))
$ownerActivationPlanMissingEnvNames = @((Get-OpsProp -Object $reports.ownerActivationPlan -Name "missingEnvNames" -Default @()))
$ownerActivationPlanInvalidEnvNames = @((Get-OpsProp -Object $reports.ownerActivationPlan -Name "invalidEnvNames" -Default @()))
$ownerActivationPlanStageCount = [int](Get-OpsProp -Object $reports.ownerActivationPlan -Name "stageCount" -Default 0)
$ownerActivationPlanReadyStageCount = [int](Get-OpsProp -Object $reports.ownerActivationPlan -Name "readyStageCount" -Default 0)
$ownerActivationPlanActivationReady = (Get-OpsProp -Object $reports.ownerActivationPlan -Name "activationReady" -Default $false) -eq $true
$ownerActivationPlanReady = $ownerActivationPlanStatus -eq "passed" `
    -and $ownerActivationPlanFailedChecks.Count -eq 0 `
    -and $ownerActivationPlanSecretFindings.Count -eq 0 `
    -and $ownerActivationPlanStageCount -ge 8 `
    -and ((Get-OpsProp -Object $reports.ownerActivationPlan -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $reports.ownerActivationPlan -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $reports.ownerActivationPlan -Name "broadcasts" -Default $true) -eq $false)
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
$truthTableStatus = Get-OpsStatus -Report $reports.truthTable
$truthTableCounts = Get-OpsProp -Object $reports.truthTable -Name "classificationCounts"
$truthTableFailedCount = [int](Get-OpsProp -Object $truthTableCounts -Name "failed" -Default 0)
$truthTableStaleCount = [int](Get-OpsProp -Object $truthTableCounts -Name "stale" -Default 0)
$truthTableRepoBlockedCount = [int](Get-OpsProp -Object $truthTableCounts -Name "blocked-repo-work" -Default 0)
$truthTableUnsafe = $truthTableStatus -in @("missing", "failed", "stale") `
    -or $truthTableFailedCount -gt 0 `
    -or $truthTableStaleCount -gt 0 `
    -or $truthTableRepoBlockedCount -gt 0
$noSecretStatus = Get-OpsStatus -Report $reports.noSecret

if ($publicRpcStatus -ne "passed") {
    Add-OpsFinding -Findings $findings -Severity "blocked" -Code "public-rpc-not-ready" -Message "Public RPC is not ready to share." -Commands @("npm run flowchain:public-rpc:check", "npm run flowchain:public-rpc:validate", "npm run flowchain:public-rpc:abuse-test")
}
if (-not $publicRpcEdgeHardeningReady) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "public-rpc-edge-hardening-failed" -Message "Public RPC edge deployment hardening evidence is missing or failed." -Commands @("npm run flowchain:public-rpc:deployment-bundle", "npm run flowchain:public-rpc:deployment:automation", "npm run flowchain:public-deployment:contract -- -AllowBlocked -NoRefresh")
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
if (-not $bridgeRelayerCheckContractReady) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "bridge-relayer-check-contract-failed" -Message "Bridge relayer one-shot safety check contract is missing or has failed checks." -Commands @("npm run flowchain:bridge:relayer:once -- -AllowBlocked", "npm run flowchain:ops:snapshot -- -AllowBlocked -NoRefresh", "npm run flowchain:bridge:emergency-stop")
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
if (-not $bridgeRelayerDirectObserveGuardrailReady) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "bridge-direct-observe-cursor-unsafe" -Message "Standalone Base 8453 observer cursor guardrail is missing, failed, or could touch the final relayer cursor without explicit owner opt-in." -Commands @("npm run flowchain:bridge:relayer:guardrail:validate", "npm run flowchain:bridge:relayer:once -- -AllowBlocked", "npm run flowchain:bridge:emergency-stop")
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
if (-not $dashboardUiReady) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "dashboard-ui-readiness-failed" -Message "Dashboard wallet, faucet, send, tester launch, explorer, activation cockpit, or no-secret UI readiness proof is missing or failed." -Commands @("npm run flowchain:dashboard:ui:readiness", "npm run flowchain:dashboard:build", "npm test --prefix apps/dashboard")
}
if (-not $ownerInputsValidationReady) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "owner-inputs-validation-failed" -Message "Owner input validation scenarios are missing, failed, or unsafe to use for live cutover." -Commands @("npm run flowchain:owner-inputs:validate", "npm run flowchain:owner-inputs", "npm run flowchain:owner-env:readiness")
}
if ($deploymentRefreshUnsafe) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "deployment-refresh-aborted" -Message "Public deployment dependency refresh aborted or skipped dependency gates." -Commands @("npm run flowchain:public-deployment:contract -- -AllowBlocked", "npm run flowchain:public-deployment:contract -- -NoRefresh -AllowBlocked", "npm run flowchain:ops:snapshot -- -AllowBlocked -NoRefresh")
}
if ($deploymentStatus -ne "passed") {
    Add-OpsFinding -Findings $findings -Severity "blocked" -Code "deployment-contract-not-ready" -Message "Public deployment contract is not ready." -Commands @("npm run flowchain:public-deployment:contract -- -AllowBlocked")
}
if ($truthTableUnsafe) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "truth-table-stale-or-failed" -Message "Production truth table is stale, failed, missing, or reports repo-owned blockers." -Commands @("npm run flowchain:truth-table -- -AllowBlocked", "npm run flowchain:completion:audit -- -AllowBlocked", "npm run flowchain:live:cutover:rehearsal -- -AllowBlocked")
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
        "npm run flowchain:public-rpc:deployment-bundle",
        "npm run flowchain:public-rpc:deployment:automation",
        "npm run flowchain:external-tester:packet"
    )
    productSurface = @(
        "npm run flowchain:dashboard:ui:readiness",
        "npm run flowchain:tester:evidence:validate",
        "npm run flowchain:external-tester:packet"
    )
    ownerInputs = @(
        "npm run flowchain:owner-inputs:validate",
        "npm run flowchain:owner-inputs",
        "npm run flowchain:owner-env:readiness"
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
        publicRpcDeploymentBundle = $publicRpcDeploymentBundleStatus
        publicRpcDeploymentAutomation = $publicRpcDeploymentAutomationStatus
        publicRpcEdgeHardeningReady = $publicRpcEdgeHardeningReady
        publicRpcDisallowedOriginPreflight = Get-OpsProp -Object $publicRpcDeploymentBundleChecks -Name "includesDisallowedOriginPreflight" -Default $false
        publicRpcBroadStateBlockedPreflight = Get-OpsProp -Object $publicRpcDeploymentBundleChecks -Name "includesBroadStateBlockedPreflight" -Default $false
        publicRpcPrivateWalletCreateBlockedPreflight = Get-OpsProp -Object $publicRpcDeploymentBundleChecks -Name "includesPrivateWalletCreateBlockedPreflight" -Default $false
        publicRpcAuthorizationForwardingScoped = Get-OpsProp -Object $publicRpcDeploymentBundleChecks -Name "authorizationForwardingScopedToTesterWrite" -Default $false
        publicRpcSecurityHeaders = Get-OpsProp -Object $publicRpcDeploymentBundleChecks -Name "includesSecurityHeaders" -Default $false
        publicRpcSecurityHeaderPreflight = Get-OpsProp -Object $publicRpcDeploymentBundleChecks -Name "preflightsCheckSecurityHeaders" -Default $false
        publicRpcWalletCutoverCommands = $publicRpcDeploymentBundleWalletCutoverProofReady
        publicRpcRenderedDisallowedOriginProbe = Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightHasDisallowedOriginProbe" -Default $false
        publicRpcRenderedBroadStateBlockedProbe = Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightBlocksBroadStatePath" -Default $false
        publicRpcRenderedPrivateWalletCreateBlockedProbe = Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightBlocksPrivateWalletCreate" -Default $false
        publicRpcRenderedAuthorizationForwardingScoped = Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedNginxAuthorizationForwardingScoped" -Default $false
        publicRpcRenderedSecurityHeaders = Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedNginxHasSecurityHeaders" -Default $false
        publicRpcRenderedSecurityHeaderPreflight = Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "renderedPreflightChecksSecurityHeaders" -Default $false
        publicRpcCommandPlanWalletCutoverProof = $publicRpcDeploymentAutomationWalletCutoverProofReady
        publicRpcCommandPlanTesterGatewayE2e = Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesTesterGatewayE2e" -Default $false
        publicRpcCommandPlanWalletTesterE2e = Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesWalletTesterE2e" -Default $false
        publicRpcCommandPlanCutoverRehearsal = Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesCutoverRehearsal" -Default $false
        publicRpcCommandPlanTruthTable = Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesTruthTable" -Default $false
        publicRpcCommandPlanNoSecretScan = Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "commandPlanIncludesNoSecretScan" -Default $false
        backup = $backupStatus
        backupRetentionCount = $backupRetentionCount
        backupRetentionCandidateCount = $backupRetentionCandidateCount
        backupRetentionCurrentSnapshotProtected = $backupRetentionCurrentSnapshotProtected
        backupRetentionPruneErrorCount = $backupRetentionPruneErrorCount
        bridgeLive = $bridgeLiveStatus
        bridgeInfra = $bridgeInfraStatus
        bridgeRelayer = $bridgeRelayerStatus
        bridgeRelayerCheckContractReady = $bridgeRelayerCheckContractReady
        bridgeRelayerFailedChecks = $bridgeRelayerFailedChecks.Count
        bridgeRelayerMissingChecks = $bridgeRelayerMissingChecks.Count
        bridgeRelayerGuardrail = $bridgeRelayerGuardrailStatus
        bridgeRelayerGuardrailReady = $bridgeRelayerGuardrailReady
        bridgeRelayerDirectObserveGuardrailReady = $bridgeRelayerDirectObserveGuardrailReady
        bridgeDirectObserveUsesStagedCursorByDefault = Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveUsesStagedCursorByDefault" -Default $false
        bridgeDirectObserveCursorNotFinal = Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveCursorNotFinal" -Default $false
        bridgeDirectObserveFinalCursorUnchanged = Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveFinalCursorUnchanged" -Default $false
        bridgeDirectObserveStagedCursorNotWritten = Get-OpsProp -Object $bridgeRelayerGuardrailChecks -Name "directObserveStagedCursorNotWritten" -Default $false
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
        dashboardUi = $dashboardUiStatus
        dashboardUiReady = $dashboardUiReady
        dashboardUiBrowserE2e = Get-OpsProp -Object $dashboardUiChecks -Name "dashboardBrowserE2ePassed" -Default $false
        dashboardUiBuild = Get-OpsProp -Object $dashboardUiChecks -Name "dashboardBuildPassed" -Default $false
        dashboardUiTesterWalletCreateCovered = Get-OpsProp -Object $dashboardUiChecks -Name "testerWalletCreateCovered" -Default $false
        dashboardUiTesterFaucetCovered = Get-OpsProp -Object $dashboardUiChecks -Name "testerFaucetCovered" -Default $false
        dashboardUiTesterSendCovered = Get-OpsProp -Object $dashboardUiChecks -Name "testerSendCovered" -Default $false
        dashboardUiTesterLaunchRouteCovered = Get-OpsProp -Object $dashboardUiChecks -Name "testerLaunchRouteCovered" -Default $false
        dashboardUiExplorerRouteCovered = Get-OpsProp -Object $dashboardUiChecks -Name "explorerRouteCovered" -Default $false
        dashboardUiActivationRouteCovered = Get-OpsProp -Object $dashboardUiChecks -Name "activationRouteCovered" -Default $false
        ownerInputsValidation = $ownerInputsValidationStatus
        ownerInputsValidationReady = $ownerInputsValidationReady
        ownerInputsValidationScenarioCount = $ownerInputsValidationScenarios.Count
        ownerInputsValidationFailedScenarios = $ownerInputsValidationFailedScenarios.Count
        ownerInputsValidationRequiredEnvCount = $ownerInputsValidationRequiredEnvNames.Count
        ownerActivationPlan = $ownerActivationPlanStatus
        ownerActivationPlanReady = $ownerActivationPlanReady
        ownerActivationReady = $ownerActivationPlanActivationReady
        ownerActivationStageCount = $ownerActivationPlanStageCount
        ownerActivationReadyStageCount = $ownerActivationPlanReadyStageCount
        ownerActivationMissingEnvCount = $ownerActivationPlanMissingEnvNames.Count
        ownerActivationInvalidEnvCount = $ownerActivationPlanInvalidEnvNames.Count
        publicDeployment = $deploymentStatus
        deploymentRefreshAborted = $deploymentRefreshAborted
        deploymentRefreshAbortStep = $deploymentRefreshAbortStep
        deploymentRefreshAbortReason = $deploymentRefreshAbortReason
        deploymentRefreshFailedSteps = $deploymentRefreshFailedSteps
        deploymentRefreshTimedOutSteps = $deploymentRefreshTimedOutSteps
        deploymentRefreshSkippedSteps = $deploymentRefreshSkippedSteps
        truthTable = $truthTableStatus
        truthTableFailedGates = $truthTableFailedCount
        truthTableStaleGates = $truthTableStaleCount
        truthTableRepoBlockedGates = $truthTableRepoBlockedCount
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
