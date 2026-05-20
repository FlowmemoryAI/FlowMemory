param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/ops-snapshot-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/OPS_SNAPSHOT.md",
    [int] $MonitorDurationSeconds = 20,
    [int] $MonitorPollSeconds = 5,
    [int] $MonitorMaxStateAgeSeconds = 90,
    [string] $TxIntakePath = "devnet/local/intake/transactions.ndjson",
    [string] $RuntimeSubmitDir = "devnet/local/intake/runtime-submit",
    [string] $RuntimeInboxDir = "devnet/local/node/inbox",
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
$txIntakeFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $TxIntakePath)
$runtimeSubmitFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $RuntimeSubmitDir)
$runtimeInboxFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $RuntimeInboxDir)
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
    serviceSupervisorValidation = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-report.json"
    serviceMonitor = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/service-monitor-report.json"
    serviceInstallValidation = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/service-install-validation-report.json"
    systemdServiceInstallValidation = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/systemd-service-install-validation-report.json"
    publicRpc = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json"
    publicRpcSyntheticCanary = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-synthetic-canary-report.json"
    publicRpcDeploymentBundle = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json"
    publicRpcDeploymentAutomation = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json"
    backup = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json"
    backupRestoreValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-report.json"
    backupOwnerPathDryRun = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-owner-path-dry-run-report.json"
    bridgeLive = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
    bridgeInfra = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
    bridgeDeployControl = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/bridge-deploy-control-validation-report.json"
    bridgeRelayer = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-once-report.json"
    bridgeRelayerGuardrail = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-guardrail-validation-report.json"
    bridgeRuntimeCredit = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/bridge-runtime-credit-validation-report.json"
    bridgeReconciliation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-reconciliation-report.json"
    realValuePilotAggregate = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/real-value-pilot-aggregate-report.json"
    externalTester = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
    publicTesterGateway = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json"
    externalTesterEvidence = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/external-tester-evidence-validation-report.json"
    dashboardUi = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/dashboard-ui-readiness-report.json"
    secondComputerReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/second-computer-readiness-report.json"
    ownerInputsValidation = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-validation-report.json"
    ownerActivationPlan = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/owner-activation-plan-report.json"
    ownerGoLiveHandoff = Resolve-OpsInputReportPath -Path "docs/agent-runs/live-product-infra-rpc/owner-go-live-handoff-report.json"
    devPack = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-dev-pack/dev-pack-e2e-report.json"
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
    if ($null -ne $Object -and $Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
    }
    return $Default
}

function Get-OpsStatus {
    param([AllowNull()][object] $Report)
    return [string](Get-OpsProp -Object $Report -Name "status" -Default "missing")
}

function Get-OpsStringArray {
    param([AllowNull()][object] $Value)

    return @($Value | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) } | ForEach-Object { [string] $_ })
}

function Test-OpsTruthTableCoordinationItem {
    param([AllowNull()][object] $Item)

    $id = [string](Get-OpsProp -Object $Item -Name "id" -Default "")
    $classification = [string](Get-OpsProp -Object $Item -Name "classification" -Default "")
    $rawStatus = [string](Get-OpsProp -Object $Item -Name "rawStatus" -Default "")
    $blockers = @(Get-OpsStringArray -Value (Get-OpsProp -Object $Item -Name "blockers" -Default @()))
    $ownerInputBlockers = @(Get-OpsStringArray -Value (Get-OpsProp -Object $Item -Name "ownerInputBlockers" -Default @()))
    $staleReasons = @(Get-OpsStringArray -Value (Get-OpsProp -Object $Item -Name "staleReasons" -Default @()))
    $allBlockersAreOwnerInputs = $blockers.Count -gt 0 -and (@($blockers | Where-Object { $_ -notin $ownerInputBlockers }).Count -eq 0)

    if ($id -eq "ops-snapshot" -and $classification -eq "failed" -and $rawStatus -eq "failed") {
        return $true
    }

    if ($id -eq "completion-audit" -and $classification -eq "failed" -and $rawStatus -eq "failed" -and $allBlockersAreOwnerInputs) {
        return $true
    }

    if ($id -eq "completion-audit" -and $classification -eq "stale" -and $rawStatus -in @("blocked", "failed") -and $allBlockersAreOwnerInputs) {
        return $true
    }

    if ($id -eq "live-cutover-rehearsal" -and $classification -in @("failed", "stale") -and $rawStatus -in @("blocked", "failed") -and $allBlockersAreOwnerInputs) {
        return $true
    }

    return $false
}

function ConvertTo-OpsInteger {
    param([AllowNull()][object] $Value, [int] $Default = 0)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace("$Value")) {
        return $Default
    }
    try {
        return [int] $Value
    }
    catch {
        return $Default
    }
}

function Get-OpsFileAgeSeconds {
    param([Parameter(Mandatory = $true)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    return [math]::Round(((Get-Date).ToUniversalTime() - (Get-Item -LiteralPath $Path).LastWriteTimeUtc).TotalSeconds, 3)
}

function Get-OpsDirectoryFacts {
    param([Parameter(Mandatory = $true)][string] $Path)

    $files = @()
    if (Test-Path -LiteralPath $Path) {
        $files = @(Get-ChildItem -LiteralPath $Path -File -ErrorAction SilentlyContinue)
    }
    $newestAge = $null
    if ($files.Count -gt 0) {
        $newest = @($files | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1)[0]
        $newestAge = [math]::Round(((Get-Date).ToUniversalTime() - $newest.LastWriteTimeUtc).TotalSeconds, 3)
    }

    return [ordered]@{
        exists = Test-Path -LiteralPath $Path
        fileCount = $files.Count
        newestFileAgeSeconds = $newestAge
    }
}

function Get-OpsTransactionIntakeFacts {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][string] $PathLabel
    )

    $rowCount = 0
    $acceptedRows = 0
    $invalidRows = 0
    $lastWriteAgeSeconds = Get-OpsFileAgeSeconds -Path $Path

    if (Test-Path -LiteralPath $Path) {
        foreach ($line in @(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue)) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            $rowCount += 1
            try {
                $row = $line | ConvertFrom-Json
                if ([string](Get-OpsProp -Object $row -Name "status" -Default "") -like "accepted*") {
                    $acceptedRows += 1
                }
            }
            catch {
                $invalidRows += 1
            }
        }
    }

    return [ordered]@{
        path = $PathLabel
        exists = Test-Path -LiteralPath $Path
        rowCount = $rowCount
        acceptedRows = $acceptedRows
        invalidRows = $invalidRows
        lastWriteAgeSeconds = $lastWriteAgeSeconds
    }
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
    [void] $refreshSteps.Add((Invoke-OpsChild -Name "public-rpc-synthetic-canary" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-synthetic-canary.ps1"), "-AllowBlocked", "-ReportPath", $paths.publicRpcSyntheticCanary)))
}

$reports = [ordered]@{}
foreach ($entry in $paths.GetEnumerator()) {
    $reports[$entry.Key] = Read-FlowChainJsonIfExists -Path $entry.Value
}

$findings = New-Object System.Collections.ArrayList
$service = $reports.serviceStatus
$serviceSupervisor = $reports.serviceSupervisor
$serviceSupervisorValidation = $reports.serviceSupervisorValidation
$serviceInstallValidation = $reports.serviceInstallValidation
$systemdServiceInstallValidation = $reports.systemdServiceInstallValidation
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
$supervisorValidationStatus = Get-OpsStatus -Report $serviceSupervisorValidation
$supervisorValidationChecks = Get-OpsProp -Object $serviceSupervisorValidation -Name "checks"
$supervisorNodeRecovery = Get-OpsProp -Object $serviceSupervisorValidation -Name "nodeRecovery"
$supervisorNodeAfterRecovery = Get-OpsProp -Object $supervisorNodeRecovery -Name "afterRecovery"
$supervisorNodeRestartAttempts = [int](Get-OpsProp -Object $supervisorNodeRecovery -Name "restartAttempts" -Default 0)
$supervisorNodeCrashDetected = (Get-OpsProp -Object $supervisorValidationChecks -Name "nodeCrashDetected" -Default $false) -eq $true
$supervisorNodeRecovered = (Get-OpsProp -Object $supervisorValidationChecks -Name "afterNodeRecoveryNodeRunning" -Default $false) -eq $true
$supervisorNodeRecoveryControlPlaneRunning = (Get-OpsProp -Object $supervisorValidationChecks -Name "afterNodeRecoveryControlPlaneRunning" -Default $false) -eq $true
$supervisorNodeRecoveryLiveProfile = (Get-OpsProp -Object $supervisorValidationChecks -Name "afterNodeRecoveryLiveProfile" -Default $false) -eq $true
$supervisorNodeRecoveryMaxBlocksUnbounded = (Get-OpsProp -Object $supervisorValidationChecks -Name "afterNodeRecoveryMaxBlocksUnbounded" -Default $false) -eq $true
$supervisorNodeRecoveryHealthy = $supervisorValidationStatus -eq "passed" `
    -and $supervisorNodeRestartAttempts -ge 1 `
    -and $supervisorNodeCrashDetected `
    -and $supervisorNodeRecovered `
    -and $supervisorNodeRecoveryControlPlaneRunning `
    -and $supervisorNodeRecoveryLiveProfile `
    -and $supervisorNodeRecoveryMaxBlocksUnbounded
$serviceInstallValidationStatus = Get-OpsStatus -Report $serviceInstallValidation
$serviceInstallValidationChecks = Get-OpsProp -Object $serviceInstallValidation -Name "checks"
$serviceInstallValidationFailedChecks = @((Get-OpsProp -Object $serviceInstallValidation -Name "failedChecks" -Default @()))
$serviceInstallValidationSecretFindings = @((Get-OpsProp -Object $serviceInstallValidation -Name "secretMarkerFindings" -Default @()))
$serviceInstallValidationMissingPackageScripts = @((Get-OpsProp -Object $serviceInstallValidation -Name "missingPackageScripts" -Default @()))
$serviceInstallValidationReady = $serviceInstallValidationStatus -eq "passed" `
    -and $serviceInstallValidationFailedChecks.Count -eq 0 `
    -and $serviceInstallValidationSecretFindings.Count -eq 0 `
    -and $serviceInstallValidationMissingPackageScripts.Count -eq 0 `
    -and ((Get-OpsProp -Object $serviceInstallValidationChecks -Name "planDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $serviceInstallValidationChecks -Name "liveProfileDefault" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $serviceInstallValidationChecks -Name "bridgeRelayerOptInStartsLoop" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $serviceInstallValidationChecks -Name "statusActionReadOnly" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $serviceInstallValidationChecks -Name "statusDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $serviceInstallValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $serviceInstallValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $serviceInstallValidation -Name "broadcasts" -Default $true) -eq $false)
$systemdServiceInstallValidationStatus = Get-OpsStatus -Report $systemdServiceInstallValidation
$systemdServiceInstallValidationChecks = Get-OpsProp -Object $systemdServiceInstallValidation -Name "checks"
$systemdServiceInstallValidationFailedChecks = @((Get-OpsProp -Object $systemdServiceInstallValidation -Name "failedChecks" -Default @()))
$systemdServiceInstallValidationSecretFindings = @((Get-OpsProp -Object $systemdServiceInstallValidation -Name "secretMarkerFindings" -Default @()))
$systemdServiceInstallValidationReady = $systemdServiceInstallValidationStatus -eq "passed" `
    -and $systemdServiceInstallValidationFailedChecks.Count -eq 0 `
    -and $systemdServiceInstallValidationSecretFindings.Count -eq 0 `
    -and ((Get-OpsProp -Object $systemdServiceInstallValidationChecks -Name "installPlanDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $systemdServiceInstallValidationChecks -Name "installPlanUsesRenderedUnits" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $systemdServiceInstallValidationChecks -Name "supervisorUsesAutorecoveryLoop" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $systemdServiceInstallValidationChecks -Name "supervisorRestartAlways" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $systemdServiceInstallValidationChecks -Name "leastPrivilegeHardeningPresent" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $systemdServiceInstallValidation -Name "hostMutationPerformed" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $systemdServiceInstallValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $systemdServiceInstallValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $systemdServiceInstallValidation -Name "broadcasts" -Default $true) -eq $false)
$latestHeight = [string](Get-OpsProp -Object $chain -Name "latestHeight" -Default "")
$finalizedHeight = [string](Get-OpsProp -Object $chain -Name "finalizedHeight" -Default "")
$stateAge = [int](Get-OpsProp -Object $chain -Name "stateFileLastWriteAgeSeconds" -Default 999999)
$mempoolDepth = ConvertTo-OpsInteger -Value (Get-OpsProp -Object $chain -Name "mempoolDepth" -Default 0) -Default 0
$monitorHeightAdvanced = Get-OpsProp -Object $monitor -Name "heightAdvanced" -Default $false
$monitorSamples = [int](Get-OpsProp -Object $monitor -Name "sampleCount" -Default 0)
$txIntakeFacts = Get-OpsTransactionIntakeFacts -Path $txIntakeFullPath -PathLabel $TxIntakePath
$runtimeSubmitFacts = Get-OpsDirectoryFacts -Path $runtimeSubmitFullDir
$runtimeInboxFacts = Get-OpsDirectoryFacts -Path $runtimeInboxFullDir
$txIntakeInvalidRows = [int](Get-OpsProp -Object $txIntakeFacts -Name "invalidRows" -Default 0)

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
if ($txIntakeInvalidRows -gt 0) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "transaction-intake-invalid-rows" -Message "Signed transaction intake contains invalid NDJSON rows." -Commands @("npm run flowchain:ops:snapshot", "npm run flowchain:control-plane:smoke", "npm run flowchain:no-secret:scan")
}
if ($bridgeRelayerLoopStatus -eq "running" -and $bridgeRelayerLoopReportHealthy -ne $true) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "bridge-relayer-loop-unhealthy" -Message "Bridge relayer loop is running without fresh no-secret/no-broadcast health evidence." -Commands @("npm run flowchain:service:status", "npm run flowchain:bridge:relayer:loop:validate", "npm run flowchain:service:restart -- -LiveProfile -StartBridgeRelayerLoop", "npm run flowchain:bridge:emergency-stop")
}
if ($supervisorBridgeRelayerRequested -eq $true -and $supervisorRelayerRecoveryHealthy -ne $true) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "supervisor-relayer-recovery-failed" -Message "Service supervisor requested the bridge relayer loop but latest recovery evidence does not show a healthy relayer loop." -Commands @("npm run flowchain:service:supervisor -- -Once -StartBridgeRelayerLoop", "npm run flowchain:service:supervisor:validate", "npm run flowchain:service:restart -- -LiveProfile -StartBridgeRelayerLoop", "npm run flowchain:bridge:emergency-stop")
}
if ($supervisorNodeRecoveryHealthy -ne $true) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "supervisor-node-recovery-validation-failed" -Message "Service supervisor node crash recovery validation is missing or failed." -Commands @("npm run flowchain:service:supervisor:validate", "npm run flowchain:service:supervisor -- -Once", "npm run flowchain:service:restart -- -LiveProfile")
}
if ($serviceInstallValidationReady -ne $true -or $systemdServiceInstallValidationReady -ne $true) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "service-install-validation-failed" -Message "Windows or systemd service install validation is missing, unsafe, or failed." -Commands @("npm run flowchain:service:install:validate", "npm run flowchain:service:install:systemd:validate", "npm run flowchain:service:status")
}

$publicRpcStatus = Get-OpsStatus -Report $reports.publicRpc
$publicRpcSyntheticCanary = $reports.publicRpcSyntheticCanary
$publicRpcSyntheticCanaryStatus = Get-OpsStatus -Report $publicRpcSyntheticCanary
$publicRpcSyntheticCanaryReady = (Get-OpsProp -Object $publicRpcSyntheticCanary -Name "syntheticCanaryReady" -Default $false) -eq $true
$publicRpcSyntheticCanaryBlockedOnlyOnOwnerInputs = (Get-OpsProp -Object $publicRpcSyntheticCanary -Name "blockedOnlyOnKnownExternalOwnerInputs" -Default $false) -eq $true
$publicRpcSyntheticCanaryMissingEnvNames = @((Get-OpsProp -Object $publicRpcSyntheticCanary -Name "missingEnvNames" -Default @()))
$publicRpcSyntheticCanaryProbeCount = [int](Get-OpsProp -Object $publicRpcSyntheticCanary -Name "probeCount" -Default 0)
$publicRpcSyntheticCanaryFailedProbeCount = [int](Get-OpsProp -Object $publicRpcSyntheticCanary -Name "failedProbeCount" -Default 0)
$publicRpcDeploymentBundle = $reports.publicRpcDeploymentBundle
$publicRpcDeploymentAutomation = $reports.publicRpcDeploymentAutomation
$publicRpcDeploymentBundleStatus = Get-OpsStatus -Report $publicRpcDeploymentBundle
$publicRpcDeploymentAutomationStatus = Get-OpsStatus -Report $publicRpcDeploymentAutomation
$publicRpcChecks = Get-OpsProp -Object $reports.publicRpc -Name "checks"
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
$publicRpcDeploymentAutomationRollbackReady = ((Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "rollbackDrillPerformed" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "rollbackRenderedConfigExists" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "rollbackPreviousConfigWritten" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "rollbackRenderedConfigRestoredFromPrevious" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "rollbackOriginalConfigRestoredAfterDrill" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "rollbackArtifactsStayedInsideRenderDir" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "rollbackDrillNoSecrets" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "rollbackDrillBroadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "hostMutationPerformedFalse" -Default $false) -eq $true)
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
    -and ($publicRpcDeploymentAutomationRollbackReady -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicRpcDeploymentAutomation -Name "broadcasts" -Default $true) -eq $false)
$backupStatus = Get-OpsStatus -Report $reports.backup
$backupDetails = Get-OpsProp -Object $reports.backup -Name "backup"
$backupRetentionCount = Get-OpsProp -Object $backupDetails -Name "retentionCount" -Default $null
$backupRetentionCandidateCount = Get-OpsProp -Object $backupDetails -Name "retentionCandidateCount" -Default $null
$backupRetentionCurrentSnapshotProtected = Get-OpsProp -Object $backupDetails -Name "retentionCurrentSnapshotProtected" -Default $false
$backupRetentionPruneErrorCount = [int](Get-OpsProp -Object $backupDetails -Name "retentionPruneErrorCount" -Default 0)
$backupRestoreValidationStatus = Get-OpsStatus -Report $reports.backupRestoreValidation
$backupRestoreValidationChecks = Get-OpsProp -Object $reports.backupRestoreValidation -Name "checks"
$backupRestoreValidationFailedChecks = @((Get-OpsProp -Object $reports.backupRestoreValidation -Name "failedChecks" -Default @()))
$backupRestoreValidationSecretFindings = @((Get-OpsProp -Object $reports.backupRestoreValidation -Name "secretMarkerFindings" -Default @()))
$backupRestoreValidationRequiredChecks = @(
    "backupCommandPassed",
    "restoreCommandPassed",
    "backupRestoreHashRoundTrip",
    "latestRestoreUsedLatestSnapshot",
    "restoreTargetsLiveStateProtected",
    "liveStateNonMutationProven",
    "corruptedSnapshotDetected",
    "manifestTamperDetected",
    "missingStateArtifactDetected",
    "missingSnapshotManifestDetected",
    "latestPointerTamperDetected",
    "wrongChainStateMismatchDetected",
    "retentionPrunedOldestSnapshot",
    "retentionRetainedNewestSnapshots",
    "retentionReportProtectsCurrentSnapshot",
    "retentionRestoreUsedNewestSnapshot",
    "envValuesPrintedFalse",
    "noSecrets",
    "secretMarkerFindingsEmpty",
    "broadcastsFalse"
)
$backupRestoreValidationMissingChecks = @($backupRestoreValidationRequiredChecks | Where-Object { (Get-OpsProp -Object $backupRestoreValidationChecks -Name $_ -Default $false) -ne $true })
$backupRestoreValidationReady = $backupRestoreValidationStatus -eq "passed" `
    -and $backupRestoreValidationFailedChecks.Count -eq 0 `
    -and $backupRestoreValidationSecretFindings.Count -eq 0 `
    -and $backupRestoreValidationMissingChecks.Count -eq 0 `
    -and ((Get-OpsProp -Object $reports.backupRestoreValidation -Name "valuesPrinted" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $reports.backupRestoreValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $reports.backupRestoreValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $reports.backupRestoreValidation -Name "broadcasts" -Default $true) -eq $false)
$backupOwnerPathDryRunStatus = Get-OpsStatus -Report $reports.backupOwnerPathDryRun
$backupOwnerPathDryRunChecks = Get-OpsProp -Object $reports.backupOwnerPathDryRun -Name "checks"
$backupOwnerPathDryRunFailedChecks = @((Get-OpsProp -Object $reports.backupOwnerPathDryRun -Name "failedChecks" -Default @()))
$backupOwnerPathDryRunSecretFindings = @((Get-OpsProp -Object $reports.backupOwnerPathDryRun -Name "secretMarkerFindings" -Default @()))
$backupOwnerPathDryRunRequiredChecks = @(
    "readinessStatusPassed",
    "snapshotProofPassed",
    "restoreProofPassed",
    "retentionCurrentSnapshotProtected",
    "retentionPruneErrorsEmpty",
    "backupRetentionProtectedSnapshot",
    "restoreLiveStateProtected",
    "restoreDidNotMutateLiveState",
    "ownerBackupEnvRestored",
    "secretMarkerFindingsEmpty",
    "envValuesPrintedFalse",
    "noSecrets",
    "broadcastsFalse"
)
$backupOwnerPathDryRunMissingChecks = @($backupOwnerPathDryRunRequiredChecks | Where-Object { (Get-OpsProp -Object $backupOwnerPathDryRunChecks -Name $_ -Default $false) -ne $true })
$backupOwnerPathDryRunReady = $backupOwnerPathDryRunStatus -eq "passed" `
    -and $backupOwnerPathDryRunFailedChecks.Count -eq 0 `
    -and $backupOwnerPathDryRunSecretFindings.Count -eq 0 `
    -and $backupOwnerPathDryRunMissingChecks.Count -eq 0 `
    -and ((Get-OpsProp -Object $reports.backupOwnerPathDryRun -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $reports.backupOwnerPathDryRun -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $reports.backupOwnerPathDryRun -Name "broadcasts" -Default $true) -eq $false)
$bridgeLiveStatus = Get-OpsStatus -Report $reports.bridgeLive
$bridgeInfraStatus = Get-OpsStatus -Report $reports.bridgeInfra
$bridgeDeployControlStatus = Get-OpsStatus -Report $reports.bridgeDeployControl
$bridgeDeployControlChecks = Get-OpsProp -Object $reports.bridgeDeployControl -Name "checks"
$bridgeDeployControlFailedChecks = @((Get-OpsProp -Object $reports.bridgeDeployControl -Name "failedChecks" -Default @()))
$bridgeDeployControlSecretFindings = @((Get-OpsProp -Object $reports.bridgeDeployControl -Name "secretMarkerFindings" -Default @()))
$bridgeDeployControlRequiredChecks = @(
    "packageScriptDeployPresent",
    "packageScriptPausePresent",
    "packageScriptResumePresent",
    "packageScriptEmergencyStopPresent",
    "packageScriptValidationPresent",
    "deployScriptExists",
    "controlScriptExists",
    "foundryScriptExists",
    "lockboxContractExists",
    "deploymentRunbookExists",
    "deployMissingEnvCommandFailedClosed",
    "deployMissingEnvReportWritten",
    "deployMissingEnvReportBlockedNoBroadcast",
    "pauseMissingEnvCommandFailedClosed",
    "pauseMissingEnvReportBlockedNoBroadcast",
    "resumeMissingEnvCommandFailedClosed",
    "resumeMissingEnvReportBlockedNoBroadcast",
    "emergencyStopMissingEnvCommandFailedClosed",
    "emergencyStopMissingEnvReportBlockedNoBroadcast",
    "deployRequiresBase8453ChainId",
    "deployRequiresPilotAck",
    "deployRequiresBroadcastAck",
    "deployRequiresAcknowledgeBroadcastSwitch",
    "deployMapsFoundryPilotAck",
    "deployMapsNativeAndErc20Caps",
    "deployDryRunNoBroadcastStatus",
    "deployBroadcastUsesForgeBroadcast",
    "controlExecuteRequiresOwnerKeyAndBroadcastAck",
    "controlNoExecuteReportsReadyNoBroadcast",
    "controlSupportsPauseResumeEmergency",
    "controlExecuteUsesCastSend",
    "foundryScriptGatesBase8453",
    "foundryScriptRequiresTotalCapOnBase",
    "foundryScriptDeploysLockboxAndSpine",
    "lockboxHasNonReentrantPauseEmergency",
    "lockboxHasCapsAndReplayProtection",
    "lockboxRejectsPlaceholderRecipient",
    "lockboxHasReleaseAuthority",
    "runbookHasDryRunBroadcastVerifyRollback",
    "childProcessesDidNotTimeout",
    "validationArtifactsInsideRepo",
    "secretMarkerFindingsEmpty",
    "envValuesPrintedFalse",
    "noSecrets",
    "broadcastsFalse"
)
$bridgeDeployControlMissingChecks = @($bridgeDeployControlRequiredChecks | Where-Object {
    (Get-OpsProp -Object $bridgeDeployControlChecks -Name $_ -Default $false) -ne $true
})
$bridgeDeployControlMissingEnvFailClosed = ((Get-OpsProp -Object $bridgeDeployControlChecks -Name "deployMissingEnvCommandFailedClosed" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeDeployControlChecks -Name "pauseMissingEnvCommandFailedClosed" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeDeployControlChecks -Name "resumeMissingEnvCommandFailedClosed" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeDeployControlChecks -Name "emergencyStopMissingEnvCommandFailedClosed" -Default $false) -eq $true)
$bridgeDeployControlBroadcastAckRequired = ((Get-OpsProp -Object $bridgeDeployControlChecks -Name "deployRequiresBroadcastAck" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeDeployControlChecks -Name "deployRequiresAcknowledgeBroadcastSwitch" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeDeployControlChecks -Name "controlExecuteRequiresOwnerKeyAndBroadcastAck" -Default $false) -eq $true)
$bridgeDeployControlPauseResumeEmergencyReady = ((Get-OpsProp -Object $bridgeDeployControlChecks -Name "packageScriptPausePresent" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeDeployControlChecks -Name "packageScriptResumePresent" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeDeployControlChecks -Name "packageScriptEmergencyStopPresent" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeDeployControlChecks -Name "controlSupportsPauseResumeEmergency" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeDeployControlChecks -Name "controlExecuteUsesCastSend" -Default $false) -eq $true)
$bridgeDeployControlReady = $bridgeDeployControlStatus -eq "passed" `
    -and $bridgeDeployControlFailedChecks.Count -eq 0 `
    -and $bridgeDeployControlSecretFindings.Count -eq 0 `
    -and $bridgeDeployControlMissingChecks.Count -eq 0 `
    -and $bridgeDeployControlMissingEnvFailClosed `
    -and $bridgeDeployControlBroadcastAckRequired `
    -and $bridgeDeployControlPauseResumeEmergencyReady `
    -and ((Get-OpsProp -Object $bridgeDeployControlChecks -Name "runbookHasDryRunBroadcastVerifyRollback" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $reports.bridgeDeployControl -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $reports.bridgeDeployControl -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $reports.bridgeDeployControl -Name "broadcasts" -Default $true) -eq $false)
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
$bridgeRuntimeCreditStatus = Get-OpsStatus -Report $reports.bridgeRuntimeCredit
$bridgeRuntimeCreditChecks = Get-OpsProp -Object $reports.bridgeRuntimeCredit -Name "checks"
$bridgeRuntimeCreditTiming = Get-OpsProp -Object $reports.bridgeRuntimeCredit -Name "timing"
$bridgeRuntimeCreditFailedChecks = @((Get-OpsProp -Object $reports.bridgeRuntimeCredit -Name "failedChecks" -Default @()))
$bridgeRuntimeCreditMissingChecks = @((Get-OpsProp -Object $reports.bridgeRuntimeCredit -Name "missingRuntimeChecks" -Default @()))
$bridgeRuntimeCreditFalseChecks = @((Get-OpsProp -Object $reports.bridgeRuntimeCredit -Name "falseRuntimeChecks" -Default @()))
$bridgeRuntimeCreditProofFailedChecks = @((Get-OpsProp -Object $reports.bridgeRuntimeCredit -Name "proofFailedChecks" -Default @()))
$bridgeRuntimeCreditLatencySeconds = Get-OpsProp -Object $bridgeRuntimeCreditTiming -Name "queueToSpendableSeconds" -Default $null
$bridgeRuntimeTransferLatencySeconds = Get-OpsProp -Object $bridgeRuntimeCreditTiming -Name "transferSettlementSeconds" -Default $null
$bridgeRuntimeCreditReady = $bridgeRuntimeCreditStatus -eq "passed" `
    -and $bridgeRuntimeCreditFailedChecks.Count -eq 0 `
    -and $bridgeRuntimeCreditMissingChecks.Count -eq 0 `
    -and $bridgeRuntimeCreditFalseChecks.Count -eq 0 `
    -and $bridgeRuntimeCreditProofFailedChecks.Count -eq 0 `
    -and ((Get-OpsProp -Object $bridgeRuntimeCreditChecks -Name "sourceChainBase8453" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRuntimeCreditChecks -Name "creditAppliedOnce" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRuntimeCreditChecks -Name "creditedBalanceTransferable" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRuntimeCreditChecks -Name "replayRejected" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRuntimeCreditChecks -Name "restartPreservesCreditHistory" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRuntimeCreditChecks -Name "exportImportPreservesReplayProtection" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRuntimeCreditChecks -Name "latencyRecorded" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRuntimeCreditChecks -Name "latencyGatePassed" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeRuntimeCreditChecks -Name "transferLatencyUnderTarget" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $reports.bridgeRuntimeCredit -Name "broadcasts" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $reports.bridgeRuntimeCredit -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $reports.bridgeRuntimeCredit -Name "noSecrets" -Default $false) -eq $true)
$bridgeReconciliationStatus = Get-OpsStatus -Report $reports.bridgeReconciliation
$bridgeReconciliationChecks = Get-OpsProp -Object $reports.bridgeReconciliation -Name "checks"
$bridgeReconciliationCounts = Get-OpsProp -Object $reports.bridgeReconciliation -Name "counts"
$bridgeReconciliationCursorCommit = Get-OpsProp -Object $reports.bridgeReconciliation -Name "cursorCommit"
$bridgeReconciliationRows = @((Get-OpsProp -Object $reports.bridgeReconciliation -Name "reconciliation" -Default @()))
$bridgeReconciliationFailedChecks = @((Get-OpsProp -Object $reports.bridgeReconciliation -Name "failedChecks" -Default @()))
$bridgeReconciliationSecretFindings = @((Get-OpsProp -Object $reports.bridgeReconciliation -Name "secretMarkerFindings" -Default @()))
$bridgeReconciliationReady = $bridgeReconciliationStatus -eq "passed" `
    -and $bridgeReconciliationFailedChecks.Count -eq 0 `
    -and $bridgeReconciliationSecretFindings.Count -eq 0 `
    -and $bridgeReconciliationRows.Count -ge 8 `
    -and ((Get-OpsProp -Object $bridgeReconciliationChecks -Name "relayerOnceReportLoaded" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeReconciliationChecks -Name "relayerCountsNonNegative" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeReconciliationChecks -Name "pendingCreditsNonNegative" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeReconciliationChecks -Name "cursorModeStaged" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeReconciliationChecks -Name "cursorFinalNotCommittedWhenBlocked" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeReconciliationChecks -Name "relayerBlockedClassifiedOwnerInput" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeReconciliationChecks -Name "runtimeCreditAppliedOnce" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeReconciliationChecks -Name "runtimeReplayRejected" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeReconciliationChecks -Name "localPilotDuplicateReplayRejected" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $bridgeReconciliationChecks -Name "releaseEvidenceValidationPassed" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $reports.bridgeReconciliation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $reports.bridgeReconciliation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $reports.bridgeReconciliation -Name "broadcasts" -Default $true) -eq $false)
$realValuePilotAggregateStatus = Get-OpsStatus -Report $reports.realValuePilotAggregate
$realValuePilotAggregateChecks = Get-OpsProp -Object $reports.realValuePilotAggregate -Name "checks"
$realValuePilotAggregateTimedOutCommands = @((Get-OpsProp -Object $reports.realValuePilotAggregate -Name "timedOutCommands" -Default @()))
$realValuePilotAggregateFailedCommands = @((Get-OpsProp -Object $reports.realValuePilotAggregate -Name "failedCommands" -Default @()))
$realValuePilotAggregateMissingProofs = @((Get-OpsProp -Object $reports.realValuePilotAggregate -Name "missingProofs" -Default @()))
$realValuePilotAggregateMissingExpectedCommands = @((Get-OpsProp -Object $reports.realValuePilotAggregate -Name "missingExpectedCommands" -Default @()))
$realValuePilotAggregateCommandsRun = @((Get-OpsProp -Object $reports.realValuePilotAggregate -Name "commandsRun" -Default @()))
$realValuePilotAggregateOwnerGoNoGo = Get-OpsProp -Object (Get-OpsProp -Object $reports.realValuePilotAggregate -Name "ownerGoNoGo") -Name "go" -Default $false
$realValuePilotAggregateReady = $realValuePilotAggregateStatus -eq "passed" `
    -and $realValuePilotAggregateCommandsRun.Count -ge 6 `
    -and $realValuePilotAggregateTimedOutCommands.Count -eq 0 `
    -and $realValuePilotAggregateFailedCommands.Count -eq 0 `
    -and $realValuePilotAggregateMissingProofs.Count -eq 0 `
    -and $realValuePilotAggregateMissingExpectedCommands.Count -eq 0 `
    -and $realValuePilotAggregateOwnerGoNoGo -eq $true `
    -and ((Get-OpsProp -Object $realValuePilotAggregateChecks -Name "requiredProofCommandsRun" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $realValuePilotAggregateChecks -Name "commandsDidNotTimeout" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $realValuePilotAggregateChecks -Name "commandsDidNotFail" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $realValuePilotAggregateChecks -Name "outputTailsRedacted" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $reports.realValuePilotAggregate -Name "broadcasts" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $reports.realValuePilotAggregate -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $reports.realValuePilotAggregate -Name "noSecrets" -Default $false) -eq $true)
$externalTesterStatus = Get-OpsStatus -Report $reports.externalTester
$externalTesterChecks = Get-OpsProp -Object $reports.externalTester -Name "checks"
$externalTesterLocalRehearsalReady = (Get-OpsProp -Object $reports.externalTester -Name "localTesterRehearsalReady" -Default $false) -eq $true
$externalTesterExternalSharingReady = (Get-OpsProp -Object $reports.externalTester -Name "externalSharingReady" -Default $false) -eq $true
$externalTesterMissingEnvNames = @((Get-OpsProp -Object $reports.externalTester -Name "missingEnvNames" -Default @()))
$externalTesterTesterNetwork = Get-OpsProp -Object $reports.externalTester -Name "testerNetwork"
$externalTesterTesterCount = [int](Get-OpsProp -Object $externalTesterTesterNetwork -Name "testerCount" -Default 0)
$externalTesterServiceReady = (Get-OpsProp -Object $externalTesterChecks -Name "serviceReady" -Default $false) -eq $true
$externalTesterChainProducing = (Get-OpsProp -Object $externalTesterChecks -Name "chainProducing" -Default $false) -eq $true
$externalTesterWalletNetworkReady = (Get-OpsProp -Object $externalTesterChecks -Name "testerWalletNetworkReady" -Default $false) -eq $true
$externalTesterWalletNetworkFresh = (Get-OpsProp -Object $externalTesterChecks -Name "testerWalletNetworkFresh" -Default $false) -eq $true
$externalTesterPacketSmokeValidated = (Get-OpsProp -Object $externalTesterChecks -Name "packetExecutableSmokeValidated" -Default $false) -eq $true
$externalTesterPublicGatewayReady = (Get-OpsProp -Object $externalTesterChecks -Name "publicTesterGatewayReady" -Default $false) -eq $true
$externalTesterPublicGatewayFresh = (Get-OpsProp -Object $externalTesterChecks -Name "publicTesterGatewayFresh" -Default $false) -eq $true
$externalTesterFaucetRouteValidated = (Get-OpsProp -Object $externalTesterChecks -Name "publicTesterGatewayFaucetRouteValidated" -Default $false) -eq $true
$externalTesterLiveInfraReady = (Get-OpsProp -Object $externalTesterChecks -Name "liveInfraReady" -Default $false) -eq $true
$publicTesterGatewayStatus = Get-OpsStatus -Report $reports.publicTesterGateway
$publicTesterGatewayChecks = Get-OpsProp -Object $reports.publicTesterGateway -Name "checks"
$publicTesterGatewayFailedChecks = @((Get-OpsProp -Object $reports.publicTesterGateway -Name "failedChecks" -Default @()))
$publicTesterGatewaySecretFindings = @((Get-OpsProp -Object $reports.publicTesterGateway -Name "secretMarkerFindings" -Default @()))
$publicTesterGatewayRoutes = @((Get-OpsProp -Object $reports.publicTesterGateway -Name "routes" -Default @()))
$publicTesterGatewayAccountCount = ConvertTo-OpsInteger -Value (Get-OpsProp -Object $reports.publicTesterGateway -Name "accountCount" -Default 0)
$publicTesterGatewayTransferApplied = (Get-OpsProp -Object $publicTesterGatewayChecks -Name "transferAppliedLocalRuntime" -Default $false) -eq $true
$publicTesterGatewayCapRejected = (Get-OpsProp -Object $publicTesterGatewayChecks -Name "capRejected" -Default $false) -eq $true
$publicTesterGatewayRoutesCovered = (Get-OpsProp -Object $publicTesterGatewayChecks -Name "routesCoverRequired" -Default $false) -eq $true
$publicTesterGatewayNoSecrets = ((Get-OpsProp -Object $reports.publicTesterGateway -Name "noSecrets" -Default $false) -eq $true) `
    -and $publicTesterGatewaySecretFindings.Count -eq 0 `
    -and ((Get-OpsProp -Object $publicTesterGatewayChecks -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicTesterGatewayChecks -Name "secretMarkerFindingsEmpty" -Default $false) -eq $true)
$publicTesterGatewayNoBroadcasts = ((Get-OpsProp -Object $reports.publicTesterGateway -Name "broadcasts" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $reports.publicTesterGateway -Name "noLiveBroadcast" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicTesterGatewayChecks -Name "broadcastsFalse" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicTesterGatewayChecks -Name "noLiveBroadcast" -Default $false) -eq $true)
$publicTesterGatewayReady = $publicTesterGatewayStatus -eq "passed" `
    -and $publicTesterGatewayFailedChecks.Count -eq 0 `
    -and $publicTesterGatewayAccountCount -ge 2 `
    -and ((Get-OpsProp -Object $publicTesterGatewayChecks -Name "walletCreateSchemaOk" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicTesterGatewayChecks -Name "testerFaucetSchemaOk" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $publicTesterGatewayChecks -Name "walletSendSchemaOk" -Default $false) -eq $true) `
    -and $publicTesterGatewayTransferApplied `
    -and $publicTesterGatewayCapRejected `
    -and ((Get-OpsProp -Object $publicTesterGatewayChecks -Name "capRejectNoSecrets" -Default $false) -eq $true) `
    -and $publicTesterGatewayRoutesCovered `
    -and $publicTesterGatewayNoSecrets `
    -and $publicTesterGatewayNoBroadcasts `
    -and ((Get-OpsProp -Object $reports.publicTesterGateway -Name "envValuesPrinted" -Default $true) -eq $false)
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
$secondComputerStatus = Get-OpsStatus -Report $reports.secondComputerReadiness
$secondComputerChecks = Get-OpsProp -Object $reports.secondComputerReadiness -Name "checks"
$secondComputerFailedChecks = @((Get-OpsProp -Object $reports.secondComputerReadiness -Name "failedChecks" -Default @()))
$secondComputerMissingNextCommands = @((Get-OpsProp -Object $reports.secondComputerReadiness -Name "missingNextCommands" -Default @()))
$secondComputerFailedVerifyChecks = @((Get-OpsProp -Object $reports.secondComputerReadiness -Name "failedVerifyChecks" -Default @()))
$secondComputerSecretFindings = @((Get-OpsProp -Object $reports.secondComputerReadiness -Name "secretMarkerFindings" -Default @()))
$secondComputerReady = $secondComputerStatus -eq "passed" `
    -and $secondComputerFailedChecks.Count -eq 0 `
    -and $secondComputerMissingNextCommands.Count -eq 0 `
    -and $secondComputerFailedVerifyChecks.Count -eq 0 `
    -and $secondComputerSecretFindings.Count -eq 0 `
    -and ((Get-OpsProp -Object $secondComputerChecks -Name "bundleCommandPassed" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $secondComputerChecks -Name "verifyCommandPassed" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $secondComputerChecks -Name "stageNoSecretScanPassed" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $secondComputerChecks -Name "bundleZipCreated" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $secondComputerChecks -Name "bundleSha256Present" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $secondComputerChecks -Name "manifestNextCommandsPresent" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $secondComputerChecks -Name "excludesEnvFiles" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $secondComputerChecks -Name "excludesLocalRuntime" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $secondComputerChecks -Name "verifyChecksPassed" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $reports.secondComputerReadiness -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $reports.secondComputerReadiness -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $reports.secondComputerReadiness -Name "broadcasts" -Default $true) -eq $false)
$devPackStatus = Get-OpsStatus -Report $reports.devPack
$devPackChecks = Get-OpsProp -Object $reports.devPack -Name "checks"
$devPackFailedChecks = @((Get-OpsProp -Object $reports.devPack -Name "failedChecks" -Default @()))
$devPackLanguageSdks = @((Get-OpsProp -Object $reports.devPack -Name "languageSdks" -Default @()))
$devPackImplementedLanguageSdks = @($devPackLanguageSdks | Where-Object { [string](Get-OpsProp -Object $_ -Name "status" -Default "") -eq "implemented" })
$devPackMethodCount = ConvertTo-OpsInteger -Value (Get-OpsProp -Object $reports.devPack -Name "methodCount" -Default 0)
$devPackPublicReadyMethodCount = ConvertTo-OpsInteger -Value (Get-OpsProp -Object $reports.devPack -Name "publicReadyMethodCount" -Default -1) -Default -1
$devPackReady = $devPackStatus -eq "passed" `
    -and $devPackFailedChecks.Count -eq 0 `
    -and $devPackMethodCount -ge 20 `
    -and $devPackPublicReadyMethodCount -eq 0 `
    -and ((Get-OpsProp -Object $devPackChecks -Name "discoveryLoaded" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $devPackChecks -Name "readinessLoaded" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $devPackChecks -Name "walletSendRuntimeBacked" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $devPackChecks -Name "signedEnvelopeExamplePassed" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $devPackChecks -Name "cliSignedTransactionSubmit" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $devPackChecks -Name "pythonSdkE2ePassed" -Default $false) -eq $true) `
    -and ($devPackImplementedLanguageSdks.Count -ge 1) `
    -and ((Get-OpsProp -Object $devPackChecks -Name "browserExampleViteReactPackaged" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $devPackChecks -Name "browserExampleBuildPassed" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $devPackChecks -Name "browserExampleSmokePassed" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $devPackChecks -Name "publicReadinessFailClosed" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $reports.devPack -Name "noLiveBroadcast" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $reports.devPack -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $reports.devPack -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $reports.devPack -Name "broadcasts" -Default $true) -eq $false)
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
$ownerGoLiveHandoffStatus = Get-OpsStatus -Report $reports.ownerGoLiveHandoff
$ownerGoLiveHandoffFailedChecks = @((Get-OpsProp -Object $reports.ownerGoLiveHandoff -Name "failedChecks" -Default @()))
$ownerGoLiveHandoffSecretFindings = @((Get-OpsProp -Object $reports.ownerGoLiveHandoff -Name "secretMarkerFindings" -Default @()))
$ownerGoLiveHandoffNextInputs = @((Get-OpsProp -Object $reports.ownerGoLiveHandoff -Name "nextOwnerInputNames" -Default @()))
$ownerGoLiveHandoffChecks = Get-OpsProp -Object $reports.ownerGoLiveHandoff -Name "checks"
$ownerGoLiveHandoffStageCount = [int](Get-OpsProp -Object $reports.ownerGoLiveHandoff -Name "stageCount" -Default 0)
$ownerGoLiveHandoffLaunchSequenceCount = [int](Get-OpsProp -Object $reports.ownerGoLiveHandoff -Name "launchSequenceCount" -Default 0)
$ownerGoLiveHandoffLaunchSequenceCommandCount = [int](Get-OpsProp -Object $reports.ownerGoLiveHandoff -Name "launchSequenceCommandCount" -Default 0)
$ownerGoLiveHandoffRollbackCommandCount = [int](Get-OpsProp -Object $reports.ownerGoLiveHandoff -Name "rollbackCommandCount" -Default 0)
$ownerGoLiveHandoffReleaseReady = (Get-OpsProp -Object $reports.ownerGoLiveHandoff -Name "releaseReady" -Default $false) -eq $true
$ownerGoLiveHandoffReady = $ownerGoLiveHandoffStatus -eq "passed" `
    -and $ownerGoLiveHandoffFailedChecks.Count -eq 0 `
    -and $ownerGoLiveHandoffSecretFindings.Count -eq 0 `
    -and $ownerGoLiveHandoffStageCount -ge 8 `
    -and $ownerGoLiveHandoffLaunchSequenceCount -ge 8 `
    -and $ownerGoLiveHandoffLaunchSequenceCommandCount -ge 20 `
    -and $ownerGoLiveHandoffRollbackCommandCount -ge 4 `
    -and ((Get-OpsProp -Object $ownerGoLiveHandoffChecks -Name "launchSequencePresent" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $ownerGoLiveHandoffChecks -Name "launchSequenceEveryStepStopsOnFailure" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $ownerGoLiveHandoffChecks -Name "launchSequenceCoversCutoverAudit" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $ownerGoLiveHandoffChecks -Name "launchSequenceCoversTruthAndNoSecret" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $ownerGoLiveHandoffChecks -Name "rollbackCommandsPresent" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $ownerGoLiveHandoffChecks -Name "rollbackCoversLocalStop" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $ownerGoLiveHandoffChecks -Name "rollbackCoversBridgeEmergencyStop" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $reports.ownerGoLiveHandoff -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-OpsProp -Object $reports.ownerGoLiveHandoff -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-OpsProp -Object $reports.ownerGoLiveHandoff -Name "broadcasts" -Default $true) -eq $false)
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
$truthTableItems = @(Get-OpsProp -Object $reports.truthTable -Name "items" -Default @())
$truthTableUnsafeItems = @($truthTableItems | Where-Object {
    $classification = [string](Get-OpsProp -Object $_ -Name "classification" -Default "")
    $classification -in @("failed", "stale", "blocked-repo-work") -and -not (Test-OpsTruthTableCoordinationItem -Item $_)
})
$truthTableUnsafe = $false
if ($truthTableStatus -eq "missing") {
    $truthTableUnsafe = $true
}
elseif ($truthTableItems.Count -gt 0) {
    $truthTableUnsafe = $truthTableUnsafeItems.Count -gt 0
}
else {
    $truthTableUnsafe = $truthTableStatus -in @("failed", "stale") `
        -or $truthTableFailedCount -gt 0 `
        -or $truthTableStaleCount -gt 0 `
        -or $truthTableRepoBlockedCount -gt 0
}
$noSecretStatus = Get-OpsStatus -Report $reports.noSecret

if ($publicRpcStatus -ne "passed") {
    Add-OpsFinding -Findings $findings -Severity "blocked" -Code "public-rpc-not-ready" -Message "Public RPC is not ready to share." -Commands @("npm run flowchain:public-rpc:check", "npm run flowchain:public-rpc:validate", "npm run flowchain:public-rpc:abuse-test")
}
if ($publicRpcSyntheticCanaryStatus -eq "failed") {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "public-rpc-synthetic-canary-failed" -Message "Public RPC synthetic canary failed one or more read-only live probes." -Commands @("npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked", "npm run flowchain:public-rpc:check -- -AllowBlocked", "npm run flowchain:public-rpc:validate")
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
if (-not $backupRestoreValidationReady) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "backup-restore-validation-failed" -Message "Backup restore validation is missing or unsafe; snapshot/restore round-trip, tamper/corruption detection, retention, live-state protection, and no-secret checks must pass." -Commands @("npm run flowchain:backup:restore:validate", "npm run flowchain:backup:create", "npm run flowchain:backup:restore:verify")
}
if (-not $backupOwnerPathDryRunReady) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "backup-owner-path-dry-run-failed" -Message "Backup owner-path dry run is missing or unsafe; ignored local owner-path injection, snapshot proof, restore proof, retention proof, and live-state non-mutation must pass." -Commands @("npm run flowchain:backup:owner-path:dry-run", "npm run flowchain:backup:check -- -AllowBlocked", "npm run flowchain:backup:restore:validate")
}
if ($bridgeLiveStatus -ne "passed" -or $bridgeInfraStatus -ne "passed") {
    Add-OpsFinding -Findings $findings -Severity "blocked" -Code "bridge-not-ready" -Message "Base 8453 bridge readiness is not ready for external funded testing." -Commands @("npm run flowchain:bridge:live:check", "npm run flowchain:bridge:infra:check", "npm run flowchain:bridge:emergency-stop")
}
if (-not $bridgeDeployControlReady) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "bridge-deploy-control-validation-failed" -Message "Bridge deploy/control validation is missing or failed: deploy, pause, resume, and emergency-stop paths must fail closed and require explicit owner broadcast acknowledgement." -Commands @("npm run flowchain:bridge:deploy:control:validate", "npm run flowchain:bridge:deploy:base8453", "npm run flowchain:bridge:emergency-stop")
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
if (-not $bridgeRuntimeCreditReady) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "bridge-runtime-credit-validation-failed" -Message "Bridge runtime credit validation is missing or failed: Base 8453 handoff must become L1 spendable, reject replay, transfer, and survive restart/export/import." -Commands @("npm run flowchain:bridge:runtime-credit:validate", "npm run flowchain:service:status", "npm run flowchain:bridge:emergency-stop")
}
if (-not $bridgeReconciliationReady) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "bridge-reconciliation-failed" -Message "Bridge reconciliation is missing or unsafe: relayer counts, staged cursor safety, runtime credit, replay rejection, and release evidence validation must reconcile without secrets or broadcasts." -Commands @("npm run flowchain:bridge:reconciliation", "npm run flowchain:bridge:relayer:once -- -AllowBlocked", "npm run flowchain:bridge:runtime-credit:validate", "npm run flowchain:bridge:emergency-stop")
}
if (-not $realValuePilotAggregateReady) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "real-value-pilot-aggregate-failed" -Message "Real-value pilot aggregate proof is missing or failed: contracts, bridge, runtime, wallet, control-dashboard, and ops proofs must pass without timeouts, failed commands, missing proofs, secrets, or broadcasts." -Commands @("npm run flowchain:real-value-pilot:e2e -- -SkipBaseline -ChildTimeoutSeconds 1800", "npm run flowchain:completion:audit -- -AllowBlocked", "npm run flowchain:bridge:emergency-stop")
}
if ($externalTesterStatus -ne "passed") {
    Add-OpsFinding -Findings $findings -Severity "blocked" -Code "external-tester-not-shareable" -Message "External tester launch is not shareable; local rehearsal, public tester gateway, faucet route, external sharing, and live infra readiness must all pass first." -Commands @("npm run flowchain:wallet:live-tester:e2e", "npm run flowchain:tester:gateway:e2e", "npm run flowchain:tester:readiness -- -AllowBlocked", "npm run flowchain:external-tester:packet -- -AllowBlocked")
}
if (-not $publicTesterGatewayReady) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "public-tester-gateway-e2e-failed" -Message "Public tester gateway E2E proof is missing or unsafe; wallet create, faucet, capped send, cap rejection, routes, no-secret, and no-broadcast checks must pass." -Commands @("npm run flowchain:tester:gateway:e2e", "npm run flowchain:tester:readiness -- -AllowBlocked", "npm run flowchain:external-tester:packet -- -AllowBlocked")
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
if (-not $secondComputerReady) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "second-computer-readiness-failed" -Message "Second-computer readiness is missing or unsafe; the offline source bundle, verifier, manifest commands, local-output exclusions, and no-secret scan must pass before sharing setup packages." -Commands @("npm run flowchain:second-computer:readiness", "npm run flowchain:second-computer:bundle -- -Force", "npm run flowchain:second-computer:verify")
}
if (-not $devPackReady) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "developer-dev-pack-readiness-failed" -Message "Developer pack readiness proof is missing or unsafe; SDK/devkit, Python SDK, signed-envelope submission, packaged browser starter build/smoke, no-secret, and fail-closed public readiness checks must pass." -Commands @("npm run flowchain:dev-pack:e2e", "npm run flowchain:browser-readiness:build", "npm run flowchain:browser-readiness:smoke", "npm run flowchain:python-sdk:e2e")
}
if (-not $ownerInputsValidationReady) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "owner-inputs-validation-failed" -Message "Owner input validation scenarios are missing, failed, or unsafe to use for live cutover." -Commands @("npm run flowchain:owner-inputs:validate", "npm run flowchain:owner-inputs", "npm run flowchain:owner-env:readiness")
}
if (-not $ownerGoLiveHandoffReady) {
    Add-OpsFinding -Findings $findings -Severity "critical" -Code "owner-go-live-handoff-failed" -Message "Owner go-live handoff is missing or unsafe; the operator needs a no-secret stage deck, ordered launch sequence, rollback commands, next-input list, validation commands, and release-ready guardrail before public launch." -Commands @("npm run flowchain:owner:go-live-handoff", "npm run flowchain:owner:activation-plan", "npm run flowchain:truth-table -- -AllowBlocked")
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
        "npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked",
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
    serviceInstall = @(
        "npm run flowchain:service:install:validate",
        "npm run flowchain:service:install:systemd:validate",
        "npm run flowchain:service:status"
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
        mempoolDepth = $mempoolDepth
    }
    transactionIntake = [ordered]@{
        txIntakePath = $TxIntakePath
        txIntakeExists = Get-OpsProp -Object $txIntakeFacts -Name "exists" -Default $false
        txIntakeRows = Get-OpsProp -Object $txIntakeFacts -Name "rowCount" -Default 0
        txIntakeAcceptedRows = Get-OpsProp -Object $txIntakeFacts -Name "acceptedRows" -Default 0
        txIntakeInvalidRows = $txIntakeInvalidRows
        txIntakeLastWriteAgeSeconds = Get-OpsProp -Object $txIntakeFacts -Name "lastWriteAgeSeconds" -Default $null
        runtimeSubmitDir = $RuntimeSubmitDir
        runtimeSubmitFileCount = Get-OpsProp -Object $runtimeSubmitFacts -Name "fileCount" -Default 0
        runtimeSubmitNewestFileAgeSeconds = Get-OpsProp -Object $runtimeSubmitFacts -Name "newestFileAgeSeconds" -Default $null
        runtimeInboxDir = $RuntimeInboxDir
        runtimeInboxFileCount = Get-OpsProp -Object $runtimeInboxFacts -Name "fileCount" -Default 0
        runtimeInboxNewestFileAgeSeconds = Get-OpsProp -Object $runtimeInboxFacts -Name "newestFileAgeSeconds" -Default $null
        mempoolDepth = $mempoolDepth
    }
    reportStatuses = [ordered]@{
        serviceStatus = $serviceStatus
        serviceSupervisor = $supervisorStatus
        serviceSupervisorValidation = $supervisorValidationStatus
        serviceMonitor = $monitorStatus
        serviceInstallValidation = $serviceInstallValidationStatus
        serviceInstallValidationReady = $serviceInstallValidationReady
        serviceInstallValidationFailedChecks = $serviceInstallValidationFailedChecks.Count
        serviceInstallValidationMissingScripts = $serviceInstallValidationMissingPackageScripts.Count
        serviceInstallValidationNoSecrets = (Get-OpsProp -Object $serviceInstallValidation -Name "noSecrets" -Default $false)
        serviceInstallValidationNoBroadcasts = ((Get-OpsProp -Object $serviceInstallValidation -Name "broadcasts" -Default $true) -eq $false)
        systemdServiceInstallValidation = $systemdServiceInstallValidationStatus
        systemdServiceInstallValidationReady = $systemdServiceInstallValidationReady
        systemdServiceInstallValidationFailedChecks = $systemdServiceInstallValidationFailedChecks.Count
        systemdServiceInstallAutorecoveryLoop = Get-OpsProp -Object $systemdServiceInstallValidationChecks -Name "supervisorUsesAutorecoveryLoop" -Default $false
        systemdServiceInstallRestartAlways = Get-OpsProp -Object $systemdServiceInstallValidationChecks -Name "supervisorRestartAlways" -Default $false
        systemdServiceInstallHardening = Get-OpsProp -Object $systemdServiceInstallValidationChecks -Name "leastPrivilegeHardeningPresent" -Default $false
        systemdServiceInstallNoSecrets = (Get-OpsProp -Object $systemdServiceInstallValidation -Name "noSecrets" -Default $false)
        systemdServiceInstallNoBroadcasts = ((Get-OpsProp -Object $systemdServiceInstallValidation -Name "broadcasts" -Default $true) -eq $false)
        transactionIntake = if ($txIntakeInvalidRows -eq 0) { "passed" } else { "failed" }
        transactionIntakeInvalidRows = $txIntakeInvalidRows
        transactionIntakeRows = Get-OpsProp -Object $txIntakeFacts -Name "rowCount" -Default 0
        transactionIntakeAcceptedRows = Get-OpsProp -Object $txIntakeFacts -Name "acceptedRows" -Default 0
        runtimeSubmitFileCount = Get-OpsProp -Object $runtimeSubmitFacts -Name "fileCount" -Default 0
        runtimeInboxFileCount = Get-OpsProp -Object $runtimeInboxFacts -Name "fileCount" -Default 0
        mempoolDepth = $mempoolDepth
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
        supervisorNodeRecoveryHealthy = $supervisorNodeRecoveryHealthy
        supervisorNodeRestartAttempts = $supervisorNodeRestartAttempts
        supervisorNodeCrashDetected = $supervisorNodeCrashDetected
        supervisorNodeRecovered = $supervisorNodeRecovered
        supervisorNodeRecoveryControlPlaneRunning = $supervisorNodeRecoveryControlPlaneRunning
        supervisorNodeRecoveryLiveProfile = $supervisorNodeRecoveryLiveProfile
        supervisorNodeRecoveryMaxBlocksUnbounded = $supervisorNodeRecoveryMaxBlocksUnbounded
        supervisorNodeRecoveryLatestHeight = [string](Get-OpsProp -Object $supervisorNodeAfterRecovery -Name "latestHeight" -Default "")
        supervisorLatestRestartReasons = @($supervisorLatestRestartReasons)
        publicRpc = $publicRpcStatus
        publicRpcSyntheticCanary = $publicRpcSyntheticCanaryStatus
        publicRpcSyntheticCanaryReady = $publicRpcSyntheticCanaryReady
        publicRpcSyntheticCanaryBlockedOnlyOnOwnerInputs = $publicRpcSyntheticCanaryBlockedOnlyOnOwnerInputs
        publicRpcSyntheticCanaryProbeCount = $publicRpcSyntheticCanaryProbeCount
        publicRpcSyntheticCanaryFailedProbeCount = $publicRpcSyntheticCanaryFailedProbeCount
        publicRpcSyntheticCanaryMissingEnvCount = $publicRpcSyntheticCanaryMissingEnvNames.Count
        publicRpcLiveSecurityHeaderProbe = Get-OpsProp -Object $publicRpcChecks -Name "securityHeadersProbePerformed" -Default $false
        publicRpcLiveSecurityHeaders = ((Get-OpsProp -Object $publicRpcChecks -Name "securityHeadersProbePerformed" -Default $false) -eq $true) -and ((Get-OpsProp -Object $publicRpcChecks -Name "securityHeadersAllRequiredPresent" -Default $false) -eq $true)
        publicRpcSecurityHeaderPolicyReady = Get-OpsProp -Object $publicRpcChecks -Name "securityHeadersAllRequiredPresent" -Default $false
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
        publicRpcRollbackDrillReady = $publicRpcDeploymentAutomationRollbackReady
        publicRpcRollbackDrillPerformed = Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "rollbackDrillPerformed" -Default $false
        publicRpcRollbackRestoredPrevious = Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "rollbackRenderedConfigRestoredFromPrevious" -Default $false
        publicRpcRollbackRestoredOriginal = Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "rollbackOriginalConfigRestoredAfterDrill" -Default $false
        publicRpcRollbackArtifactsScoped = Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "rollbackArtifactsStayedInsideRenderDir" -Default $false
        publicRpcRollbackNoSecrets = Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "rollbackDrillNoSecrets" -Default $false
        publicRpcRollbackNoBroadcasts = Get-OpsProp -Object $publicRpcDeploymentAutomationChecks -Name "rollbackDrillBroadcastsFalse" -Default $false
        backup = $backupStatus
        backupRetentionCount = $backupRetentionCount
        backupRetentionCandidateCount = $backupRetentionCandidateCount
        backupRetentionCurrentSnapshotProtected = $backupRetentionCurrentSnapshotProtected
        backupRetentionPruneErrorCount = $backupRetentionPruneErrorCount
        backupRestoreValidation = $backupRestoreValidationStatus
        backupRestoreValidationReady = $backupRestoreValidationReady
        backupRestoreValidationFailedChecks = $backupRestoreValidationFailedChecks.Count
        backupRestoreValidationMissingChecks = $backupRestoreValidationMissingChecks.Count
        backupRestoreValidationSecretFindings = $backupRestoreValidationSecretFindings.Count
        backupRestoreValidationHashRoundTrip = Get-OpsProp -Object $backupRestoreValidationChecks -Name "backupRestoreHashRoundTrip" -Default $false
        backupRestoreValidationLiveStateProtected = Get-OpsProp -Object $backupRestoreValidationChecks -Name "restoreTargetsLiveStateProtected" -Default $false
        backupRestoreValidationRetentionProtected = Get-OpsProp -Object $backupRestoreValidationChecks -Name "retentionReportProtectsCurrentSnapshot" -Default $false
        backupOwnerPathDryRun = $backupOwnerPathDryRunStatus
        backupOwnerPathDryRunReady = $backupOwnerPathDryRunReady
        backupOwnerPathDryRunFailedChecks = $backupOwnerPathDryRunFailedChecks.Count
        backupOwnerPathDryRunMissingChecks = $backupOwnerPathDryRunMissingChecks.Count
        backupOwnerPathDryRunSecretFindings = $backupOwnerPathDryRunSecretFindings.Count
        backupOwnerPathDryRunSnapshotProof = Get-OpsProp -Object $backupOwnerPathDryRunChecks -Name "snapshotProofPassed" -Default $false
        backupOwnerPathDryRunRestoreProof = Get-OpsProp -Object $backupOwnerPathDryRunChecks -Name "restoreProofPassed" -Default $false
        backupOwnerPathDryRunLiveStateProtected = Get-OpsProp -Object $backupOwnerPathDryRunChecks -Name "restoreLiveStateProtected" -Default $false
        backupOwnerPathDryRunDidNotMutateLiveState = Get-OpsProp -Object $backupOwnerPathDryRunChecks -Name "restoreDidNotMutateLiveState" -Default $false
        bridgeLive = $bridgeLiveStatus
        bridgeInfra = $bridgeInfraStatus
        bridgeDeployControl = $bridgeDeployControlStatus
        bridgeDeployControlReady = $bridgeDeployControlReady
        bridgeDeployControlFailedChecks = $bridgeDeployControlFailedChecks.Count
        bridgeDeployControlMissingChecks = $bridgeDeployControlMissingChecks.Count
        bridgeDeployControlMissingEnvFailClosed = $bridgeDeployControlMissingEnvFailClosed
        bridgeDeployControlBroadcastAckRequired = $bridgeDeployControlBroadcastAckRequired
        bridgeDeployControlPauseResumeEmergencyReady = $bridgeDeployControlPauseResumeEmergencyReady
        bridgeDeployControlRunbookRollback = Get-OpsProp -Object $bridgeDeployControlChecks -Name "runbookHasDryRunBroadcastVerifyRollback" -Default $false
        bridgeDeployControlNoSecrets = ((Get-OpsProp -Object $reports.bridgeDeployControl -Name "noSecrets" -Default $false) -eq $true) -and $bridgeDeployControlSecretFindings.Count -eq 0
        bridgeDeployControlNoBroadcasts = (Get-OpsProp -Object $reports.bridgeDeployControl -Name "broadcasts" -Default $true) -eq $false
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
        bridgeRuntimeCredit = $bridgeRuntimeCreditStatus
        bridgeRuntimeCreditReady = $bridgeRuntimeCreditReady
        bridgeRuntimeCreditLatencySeconds = $bridgeRuntimeCreditLatencySeconds
        bridgeRuntimeTransferLatencySeconds = $bridgeRuntimeTransferLatencySeconds
        bridgeRuntimeCreditFailedChecks = $bridgeRuntimeCreditFailedChecks.Count
        bridgeRuntimeCreditMissingRuntimeChecks = $bridgeRuntimeCreditMissingChecks.Count
        bridgeRuntimeCreditFalseRuntimeChecks = $bridgeRuntimeCreditFalseChecks.Count
        bridgeRuntimeCreditProofFailedChecks = $bridgeRuntimeCreditProofFailedChecks.Count
        bridgeReconciliation = $bridgeReconciliationStatus
        bridgeReconciliationReady = $bridgeReconciliationReady
        bridgeReconciliationRows = $bridgeReconciliationRows.Count
        bridgeReconciliationFailedChecks = $bridgeReconciliationFailedChecks.Count
        bridgeReconciliationObservedCredits = ConvertTo-OpsInteger -Value (Get-OpsProp -Object $bridgeReconciliationCounts -Name "observedCredits" -Default 0)
        bridgeReconciliationNewCredits = ConvertTo-OpsInteger -Value (Get-OpsProp -Object $bridgeReconciliationCounts -Name "newCredits" -Default 0)
        bridgeReconciliationQueuedTransactions = ConvertTo-OpsInteger -Value (Get-OpsProp -Object $bridgeReconciliationCounts -Name "queuedTransactions" -Default 0)
        bridgeReconciliationAppliedCredits = ConvertTo-OpsInteger -Value (Get-OpsProp -Object $bridgeReconciliationCounts -Name "appliedCredits" -Default 0)
        bridgeReconciliationPendingCredits = ConvertTo-OpsInteger -Value (Get-OpsProp -Object $bridgeReconciliationCounts -Name "pendingCredits" -Default 0)
        bridgeReconciliationCursorMode = Get-OpsProp -Object $bridgeReconciliationCursorCommit -Name "mode" -Default ""
        bridgeReconciliationCursorCommitted = Get-OpsProp -Object $bridgeReconciliationCursorCommit -Name "finalCommitted" -Default $false
        bridgeReconciliationRuntimeApplied = Get-OpsProp -Object $bridgeReconciliationChecks -Name "runtimeCreditAppliedOnce" -Default $false
        bridgeReconciliationReplayRejected = Get-OpsProp -Object $bridgeReconciliationChecks -Name "localPilotDuplicateReplayRejected" -Default $false
        bridgeReconciliationReleaseEvidenceValidated = Get-OpsProp -Object $bridgeReconciliationChecks -Name "releaseEvidenceValidationPassed" -Default $false
        realValuePilotAggregate = $realValuePilotAggregateStatus
        realValuePilotAggregateReady = $realValuePilotAggregateReady
        realValuePilotAggregateCommandsRun = $realValuePilotAggregateCommandsRun.Count
        realValuePilotAggregateTimedOutCommands = $realValuePilotAggregateTimedOutCommands.Count
        realValuePilotAggregateFailedCommands = $realValuePilotAggregateFailedCommands.Count
        realValuePilotAggregateMissingProofs = $realValuePilotAggregateMissingProofs.Count
        realValuePilotAggregateMissingExpectedCommands = $realValuePilotAggregateMissingExpectedCommands.Count
        realValuePilotAggregateOwnerGoNoGo = $realValuePilotAggregateOwnerGoNoGo
        externalTester = $externalTesterStatus
        externalTesterLocalRehearsalReady = $externalTesterLocalRehearsalReady
        externalTesterExternalSharingReady = $externalTesterExternalSharingReady
        externalTesterServiceReady = $externalTesterServiceReady
        externalTesterChainProducing = $externalTesterChainProducing
        externalTesterWalletNetworkReady = $externalTesterWalletNetworkReady
        externalTesterWalletNetworkFresh = $externalTesterWalletNetworkFresh
        externalTesterPacketSmokeValidated = $externalTesterPacketSmokeValidated
        externalTesterPublicGatewayReady = $externalTesterPublicGatewayReady
        externalTesterPublicGatewayFresh = $externalTesterPublicGatewayFresh
        externalTesterFaucetRouteValidated = $externalTesterFaucetRouteValidated
        externalTesterLiveInfraReady = $externalTesterLiveInfraReady
        externalTesterMissingEnvCount = $externalTesterMissingEnvNames.Count
        externalTesterTesterCount = $externalTesterTesterCount
        publicTesterGateway = $publicTesterGatewayStatus
        publicTesterGatewayReady = $publicTesterGatewayReady
        publicTesterGatewayAccountCount = $publicTesterGatewayAccountCount
        publicTesterGatewayFailedChecks = $publicTesterGatewayFailedChecks.Count
        publicTesterGatewayRouteCount = $publicTesterGatewayRoutes.Count
        publicTesterGatewayTransferApplied = $publicTesterGatewayTransferApplied
        publicTesterGatewayCapRejected = $publicTesterGatewayCapRejected
        publicTesterGatewayRoutesCovered = $publicTesterGatewayRoutesCovered
        publicTesterGatewayNoSecrets = $publicTesterGatewayNoSecrets
        publicTesterGatewayNoBroadcasts = $publicTesterGatewayNoBroadcasts
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
        secondComputerReadiness = $secondComputerStatus
        secondComputerReady = $secondComputerReady
        secondComputerFailedChecks = $secondComputerFailedChecks.Count
        secondComputerMissingNextCommands = $secondComputerMissingNextCommands.Count
        secondComputerFailedVerifyChecks = $secondComputerFailedVerifyChecks.Count
        secondComputerSecretFindings = $secondComputerSecretFindings.Count
        secondComputerBundleCreated = Get-OpsProp -Object $secondComputerChecks -Name "bundleZipCreated" -Default $false
        secondComputerBundleSha256Present = Get-OpsProp -Object $secondComputerChecks -Name "bundleSha256Present" -Default $false
        secondComputerStageNoSecretScan = Get-OpsProp -Object $secondComputerChecks -Name "stageNoSecretScanPassed" -Default $false
        secondComputerVerifyChecksPassed = Get-OpsProp -Object $secondComputerChecks -Name "verifyChecksPassed" -Default $false
        devPack = $devPackStatus
        devPackReady = $devPackReady
        devPackFailedChecks = $devPackFailedChecks.Count
        devPackMethodCount = $devPackMethodCount
        devPackPublicReadyMethodCount = $devPackPublicReadyMethodCount
        devPackLanguageSdkCount = $devPackLanguageSdks.Count
        devPackImplementedLanguageSdkCount = $devPackImplementedLanguageSdks.Count
        devPackPythonSdkReady = Get-OpsProp -Object $devPackChecks -Name "pythonSdkE2ePassed" -Default $false
        devPackBrowserStarterPackaged = Get-OpsProp -Object $devPackChecks -Name "browserExampleViteReactPackaged" -Default $false
        devPackBrowserStarterBuild = Get-OpsProp -Object $devPackChecks -Name "browserExampleBuildPassed" -Default $false
        devPackBrowserStarterSmoke = Get-OpsProp -Object $devPackChecks -Name "browserExampleSmokePassed" -Default $false
        devPackPublicReadinessFailClosed = Get-OpsProp -Object $devPackChecks -Name "publicReadinessFailClosed" -Default $false
        devPackNoSecrets = Get-OpsProp -Object $reports.devPack -Name "noSecrets" -Default $false
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
        ownerGoLiveHandoff = $ownerGoLiveHandoffStatus
        ownerGoLiveHandoffReady = $ownerGoLiveHandoffReady
        ownerGoLiveReleaseReady = $ownerGoLiveHandoffReleaseReady
        ownerGoLiveStageCount = $ownerGoLiveHandoffStageCount
        ownerGoLiveLaunchSequenceCount = $ownerGoLiveHandoffLaunchSequenceCount
        ownerGoLiveLaunchSequenceCommandCount = $ownerGoLiveHandoffLaunchSequenceCommandCount
        ownerGoLiveRollbackCommandCount = $ownerGoLiveHandoffRollbackCommandCount
        ownerGoLiveNextInputCount = $ownerGoLiveHandoffNextInputs.Count
        ownerGoLiveFailedChecks = $ownerGoLiveHandoffFailedChecks.Count
        ownerGoLiveSecretFindings = $ownerGoLiveHandoffSecretFindings.Count
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
        truthTableUnsafeGateIds = @($truthTableUnsafeItems | ForEach-Object { Get-OpsProp -Object $_ -Name "id" -Default "" })
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
$markdownLines.Add("Transaction intake rows: $((Get-OpsProp -Object $txIntakeFacts -Name "rowCount" -Default 0))")
$markdownLines.Add("Runtime inbox files: $((Get-OpsProp -Object $runtimeInboxFacts -Name "fileCount" -Default 0))")
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
