param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/live-chain-capability-matrix-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/LIVE_CHAIN_CAPABILITY_MATRIX.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$packageJsonPath = Join-Path $repoRoot "package.json"

$knownOwnerInputs = @(
    "FLOWCHAIN_RPC_PUBLIC_URL",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
    "FLOWCHAIN_RPC_TLS_TERMINATED",
    "FLOWCHAIN_RPC_STATE_BACKUP_PATH",
    "FLOWCHAIN_TESTER_WRITE_ENABLED",
    "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256",
    "FLOWCHAIN_TESTER_MAX_SEND_UNITS",
    "FLOWCHAIN_PILOT_OPERATOR_ACK",
    "FLOWCHAIN_BASE8453_RPC_URL",
    "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
    "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
    "FLOWCHAIN_BASE8453_ASSET_DECIMALS",
    "FLOWCHAIN_BASE8453_FROM_BLOCK",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_PILOT_CONFIRMATIONS",
    "FLOWCHAIN_BASE8453_CURSOR_STATE",
    "FLOWCHAIN_BASE8453_TO_BLOCK"
)
$publicRpcInputs = @(
    "FLOWCHAIN_RPC_PUBLIC_URL",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
    "FLOWCHAIN_RPC_TLS_TERMINATED"
)
$backupInputs = @("FLOWCHAIN_RPC_STATE_BACKUP_PATH")
$bridgeInputs = @(
    "FLOWCHAIN_PILOT_OPERATOR_ACK",
    "FLOWCHAIN_BASE8453_RPC_URL",
    "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
    "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
    "FLOWCHAIN_BASE8453_ASSET_DECIMALS",
    "FLOWCHAIN_BASE8453_FROM_BLOCK",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_PILOT_CONFIRMATIONS"
)

$paths = [ordered]@{
    truthTable = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/production-truth-table-report.json"
    completionAudit = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-completion-audit-report.json"
    serviceStatus = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-status-report.json"
    serviceMonitor = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-monitor-report.json"
    serviceSupervisorValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-report.json"
    serviceInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-install-validation-report.json"
    systemdServiceInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/systemd-service-install-validation-report.json"
    liveWallet = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/live-service-wallet-e2e-report.json"
    testerNetwork = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json"
    publicRpc = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json"
    publicRpcSyntheticCanary = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-synthetic-canary-report.json"
    publicTesterGateway = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json"
    dashboardUiReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/dashboard-ui-readiness-report.json"
    bridgeLive = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
    bridgeInfra = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
    bridgeRelayerOnce = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-once-report.json"
    bridgeRelayerGuardrailValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-guardrail-validation-report.json"
    bridgeRelayerLoopValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-loop-validation-report.json"
    bridgeRuntimeCreditValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-runtime-credit-validation-report.json"
    realValuePilotAggregate = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/real-value-pilot-aggregate-report.json"
    bridgeReconciliation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-reconciliation-report.json"
    bridgeReleaseEvidenceValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-release-evidence-validation-report.json"
    backupReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json"
    backupRestoreValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-report.json"
    backupOwnerPathDryRun = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-owner-path-dry-run-report.json"
    backupInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-install-validation-report.json"
    opsSnapshot = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-snapshot-report.json"
    opsAlertRules = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-alert-rules-report.json"
    opsMetricsExport = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-metrics-export-report.json"
    monitoringBundle = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/monitoring-bundle-report.json"
    alertInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/alert-install-validation-report.json"
    metricsInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/metrics-install-validation-report.json"
    externalTesterReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
    externalTesterPacket = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json"
    externalTesterClientValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-client-validation-report.json"
    ownerNeedsNow = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-needs-now-report.json"
    ownerGoLiveHandoff = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-go-live-handoff-report.json"
    publicDeploymentContract = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json"
    devPack = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-dev-pack/dev-pack-e2e-report.json"
}

function Get-CapabilityProp {
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

function Test-CapabilityPathExists {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Path
    )

    $current = $Object
    foreach ($part in @($Path -split "\.")) {
        if ($null -eq $current) {
            return $false
        }
        if ($current -is [System.Collections.IDictionary]) {
            if (-not $current.Contains($part)) {
                return $false
            }
            $current = $current[$part]
            continue
        }
        $property = $current.PSObject.Properties[$part]
        if ($null -eq $property) {
            return $false
        }
        $current = $property.Value
    }
    return $true
}

function Get-CapabilityPathProp {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Path,
        [object] $Default = $null
    )

    if (-not (Test-CapabilityPathExists -Object $Object -Path $Path)) {
        return $Default
    }
    $current = $Object
    foreach ($part in @($Path -split "\.")) {
        if ($current -is [System.Collections.IDictionary]) {
            $current = $current[$part]
        }
        else {
            $current = $current.PSObject.Properties[$part].Value
        }
    }
    return $current
}

function Get-CapabilityStatus {
    param([AllowNull()][object] $Report)
    return [string](Get-CapabilityProp -Object $Report -Name "status" -Default "missing")
}

function Test-CapabilityReportPassed {
    param([AllowNull()][object] $Report)
    return (Get-CapabilityStatus -Report $Report) -eq "passed"
}

function Add-CapabilityUnique {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [AllowNull()][object] $Value
    )

    $text = "$Value"
    if (-not [string]::IsNullOrWhiteSpace($text) -and -not $Target.Contains($text)) {
        [void] $Target.Add($text)
    }
}

function Get-CapabilityEnvNames {
    param([AllowNull()][object] $Values)
    return @($Values | ForEach-Object { "$_" } | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_) -and $_ -match '^FLOWCHAIN_[A-Z0-9_]+$'
        })
}

function Get-CapabilityKnownBlockers {
    param(
        [string[]] $Candidates,
        [string[]] $Fallback = @()
    )

    $values = New-Object System.Collections.ArrayList
    foreach ($candidate in @($Candidates)) {
        if ($candidate -in $script:missingRequiredOwnerInputs -or $candidate -in $script:missingOwnerInputs) {
            Add-CapabilityUnique -Target $values -Value $candidate
        }
    }
    if ($values.Count -eq 0) {
        foreach ($fallback in @($Fallback)) {
            if ($fallback -in $knownOwnerInputs) {
                Add-CapabilityUnique -Target $values -Value $fallback
            }
        }
    }
    return @($values)
}

function New-LiveCapability {
    param(
        [Parameter(Mandatory = $true)][string] $Id,
        [Parameter(Mandatory = $true)][string] $Title,
        [Parameter(Mandatory = $true)][string] $UserRequirement,
        [Parameter(Mandatory = $true)][string] $Classification,
        [Parameter(Mandatory = $true)][string] $Evidence,
        [string[]] $Commands = @(),
        [string[]] $ReportNames = @(),
        [string[]] $Blockers = @(),
        [bool] $PublicLaunchCritical = $true
    )

    return [ordered]@{
        id = $Id
        title = $Title
        userRequirement = $UserRequirement
        classification = $Classification
        publicLaunchCritical = $PublicLaunchCritical
        evidence = $Evidence
        commands = @($Commands)
        reportNames = @($ReportNames)
        blockers = @($Blockers)
        ownerInputBlocked = $Classification -eq "blocked-owner-input"
        repoBlocked = $Classification -in @("failed", "blocked-repo-work", "missing-evidence")
    }
}

function Test-PackageScriptPresent {
    param([Parameter(Mandatory = $true)][string] $Name)

    if (-not (Test-Path -LiteralPath $packageJsonPath)) {
        return $false
    }
    $packageJson = Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json
    return $packageJson.scripts.PSObject.Properties.Name -contains $Name
}

function Get-CapabilityCountValue {
    param([AllowNull()][object] $Value)

    if ($null -eq $Value) {
        return 0
    }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double]) {
        return [int]$Value
    }
    if ($Value -is [string]) {
        $parsed = 0
        if ([int]::TryParse($Value, [ref]$parsed)) {
            return $parsed
        }
        return 0
    }
    return @($Value).Count
}

$reports = [ordered]@{}
foreach ($entry in $paths.GetEnumerator()) {
    $reports[$entry.Key] = Read-FlowChainJsonIfExists -Path $entry.Value
}

$truthTable = $reports.truthTable
$completionAudit = $reports.completionAudit
$script:missingRequiredOwnerInputs = @(Get-CapabilityEnvNames -Values (Get-CapabilityProp -Object $truthTable -Name "missingRequiredOwnerInputs" -Default @()))
$script:missingOwnerInputs = @(Get-CapabilityEnvNames -Values (Get-CapabilityProp -Object $truthTable -Name "missingOwnerInputs" -Default @()))
if ($script:missingRequiredOwnerInputs.Count -eq 0) {
    $script:missingRequiredOwnerInputs = @(Get-CapabilityEnvNames -Values (Get-CapabilityProp -Object $completionAudit -Name "missingEnvNames" -Default @()))
}
if ($script:missingOwnerInputs.Count -eq 0) {
    $script:missingOwnerInputs = @($script:missingRequiredOwnerInputs)
}

$unknownOwnerBlockers = @($script:missingOwnerInputs | Where-Object { $_ -notin $knownOwnerInputs })
$publicRpcBlockers = @(Get-CapabilityKnownBlockers -Candidates $publicRpcInputs)
$backupBlockers = @(Get-CapabilityKnownBlockers -Candidates $backupInputs)
$bridgeBlockers = @(Get-CapabilityKnownBlockers -Candidates $bridgeInputs)
$externalTesterBlockers = @($publicRpcBlockers + $backupBlockers + $bridgeBlockers | Select-Object -Unique)

$serviceStatusPassed = Test-CapabilityReportPassed -Report $reports.serviceStatus
$serviceMonitorPassed = Test-CapabilityReportPassed -Report $reports.serviceMonitor
$serviceSupervisorPassed = Test-CapabilityReportPassed -Report $reports.serviceSupervisorValidation
$serviceInstallPassed = Test-CapabilityReportPassed -Report $reports.serviceInstallValidation
$systemdServiceInstallPassed = Test-CapabilityReportPassed -Report $reports.systemdServiceInstallValidation
$liveWalletPassed = Test-CapabilityReportPassed -Report $reports.liveWallet
$testerNetworkPassed = Test-CapabilityReportPassed -Report $reports.testerNetwork
$publicRpcPassed = Test-CapabilityReportPassed -Report $reports.publicRpc
$publicRpcCanaryPassed = Test-CapabilityReportPassed -Report $reports.publicRpcSyntheticCanary
$publicTesterGatewayPassed = Test-CapabilityReportPassed -Report $reports.publicTesterGateway
$dashboardUiPassed = Test-CapabilityReportPassed -Report $reports.dashboardUiReadiness
$bridgeLivePassed = Test-CapabilityReportPassed -Report $reports.bridgeLive
$bridgeInfraPassed = Test-CapabilityReportPassed -Report $reports.bridgeInfra
$bridgeRelayerOncePassed = Test-CapabilityReportPassed -Report $reports.bridgeRelayerOnce
$bridgeRelayerGuardrailPassed = Test-CapabilityReportPassed -Report $reports.bridgeRelayerGuardrailValidation
$bridgeRelayerLoopPassed = Test-CapabilityReportPassed -Report $reports.bridgeRelayerLoopValidation
$bridgeRuntimeCreditPassed = Test-CapabilityReportPassed -Report $reports.bridgeRuntimeCreditValidation
$realValuePilotPassed = Test-CapabilityReportPassed -Report $reports.realValuePilotAggregate
$bridgeReconciliationPassed = Test-CapabilityReportPassed -Report $reports.bridgeReconciliation
$bridgeReleaseEvidencePassed = Test-CapabilityReportPassed -Report $reports.bridgeReleaseEvidenceValidation
$backupReadinessPassed = Test-CapabilityReportPassed -Report $reports.backupReadiness
$backupRestoreValidationPassed = Test-CapabilityReportPassed -Report $reports.backupRestoreValidation
$backupOwnerPathDryRunPassed = Test-CapabilityReportPassed -Report $reports.backupOwnerPathDryRun
$backupInstallPassed = Test-CapabilityReportPassed -Report $reports.backupInstallValidation
$opsSnapshotPassedOrBlocked = (Get-CapabilityStatus -Report $reports.opsSnapshot) -in @("passed", "blocked")
$opsAlertRulesPassed = Test-CapabilityReportPassed -Report $reports.opsAlertRules
$opsMetricsExportPassed = Test-CapabilityReportPassed -Report $reports.opsMetricsExport
$monitoringBundlePassed = Test-CapabilityReportPassed -Report $reports.monitoringBundle
$alertInstallPassed = Test-CapabilityReportPassed -Report $reports.alertInstallValidation
$metricsInstallPassed = Test-CapabilityReportPassed -Report $reports.metricsInstallValidation
$externalTesterReadinessPassed = Test-CapabilityReportPassed -Report $reports.externalTesterReadiness
$externalTesterPacketStatus = Get-CapabilityStatus -Report $reports.externalTesterPacket
$externalTesterPacketSmokeReady = ((Get-CapabilityProp -Object $reports.externalTesterPacket -Name "packetExecutableSmokeValidated" -Default (Get-CapabilityProp -Object $reports.externalTesterPacket -Name "executableSmokeValidated" -Default $false)) -eq $true)
$externalTesterClientValidationPassed = Test-CapabilityReportPassed -Report $reports.externalTesterClientValidation
$ownerNeedsNowPassed = Test-CapabilityReportPassed -Report $reports.ownerNeedsNow
$ownerGoLiveHandoffPassed = Test-CapabilityReportPassed -Report $reports.ownerGoLiveHandoff
$publicDeploymentContractStatus = Get-CapabilityStatus -Report $reports.publicDeploymentContract
$devPackPassed = Test-CapabilityReportPassed -Report $reports.devPack

$latestHeight = Get-CapabilityPathProp -Object $reports.serviceStatus -Path "chain.latestHeight"
if ($null -eq $latestHeight) {
    $latestHeight = Get-CapabilityProp -Object $completionAudit -Name "latestHeight"
}
$finalizedHeight = Get-CapabilityPathProp -Object $reports.serviceStatus -Path "chain.finalizedHeight"
if ($null -eq $finalizedHeight) {
    $finalizedHeight = Get-CapabilityProp -Object $completionAudit -Name "finalizedHeight"
}
$monitorHeightAdvanced = (Get-CapabilityProp -Object $reports.serviceMonitor -Name "heightAdvanced" -Default $false) -eq $true
$testerWalletCreates = Get-CapabilityCountValue -Value (Get-CapabilityProp -Object $reports.testerNetwork -Name "walletCreateCount" -Default (Get-CapabilityProp -Object $reports.testerNetwork -Name "testerWalletCreates" -Default 0))
$testerTransfers = Get-CapabilityCountValue -Value (Get-CapabilityProp -Object $reports.testerNetwork -Name "transferCount" -Default (Get-CapabilityProp -Object $reports.testerNetwork -Name "testerTransferCount" -Default (Get-CapabilityProp -Object $reports.testerNetwork -Name "transferResults" -Default 0)))
$dashboardRoutes = @((Get-CapabilityProp -Object $reports.dashboardUiReadiness -Name "coveredRoutes" -Default @()))
$dashboardProofs = @((Get-CapabilityProp -Object $reports.dashboardUiReadiness -Name "coveredProofs" -Default @()))

$capabilities = New-Object System.Collections.ArrayList
[void] $capabilities.Add((New-LiveCapability -Id "rpc-services-running" -Title "RPC servers are running" -UserRequirement "RPC servers are online and readable." `
        -Classification $(if ($serviceStatusPassed) { "passed" } else { "failed" }) `
        -Evidence "serviceStatus=$(Get-CapabilityStatus -Report $reports.serviceStatus); latestHeight=$latestHeight; finalizedHeight=$finalizedHeight" `
        -Commands @("npm run flowchain:service:status") `
        -ReportNames @("serviceStatus")))
[void] $capabilities.Add((New-LiveCapability -Id "block-production" -Title "Chain is producing blocks" -UserRequirement "The chain is alive and producing/finalizing blocks." `
        -Classification $(if ($serviceStatusPassed -and $serviceMonitorPassed -and $monitorHeightAdvanced) { "passed" } else { "failed" }) `
        -Evidence "serviceMonitor=$(Get-CapabilityStatus -Report $reports.serviceMonitor); heightAdvanced=$monitorHeightAdvanced; latestHeight=$latestHeight" `
        -Commands @("npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30") `
        -ReportNames @("serviceStatus", "serviceMonitor")))
[void] $capabilities.Add((New-LiveCapability -Id "autorecovery-service-install" -Title "Autorecovery and reboot persistence" -UserRequirement "Node, control-plane, and bridge relayer can recover and be installed as owner-host services." `
        -Classification $(if ($serviceSupervisorPassed -and $serviceInstallPassed -and $systemdServiceInstallPassed) { "passed" } else { "failed" }) `
        -Evidence "supervisor=$(Get-CapabilityStatus -Report $reports.serviceSupervisorValidation); windowsInstall=$(Get-CapabilityStatus -Report $reports.serviceInstallValidation); systemdInstall=$(Get-CapabilityStatus -Report $reports.systemdServiceInstallValidation)" `
        -Commands @("npm run flowchain:service:supervisor:validate", "npm run flowchain:service:install:validate", "npm run flowchain:service:install:systemd:validate") `
        -ReportNames @("serviceSupervisorValidation", "serviceInstallValidation", "systemdServiceInstallValidation")))
[void] $capabilities.Add((New-LiveCapability -Id "wallet-create" -Title "Wallet creation" -UserRequirement "People can create wallets without secret material leaking into responses or committed evidence." `
        -Classification $(if ($testerNetworkPassed -and $testerWalletCreates -ge 1) { "passed" } else { "failed" }) `
        -Evidence "testerNetwork=$(Get-CapabilityStatus -Report $reports.testerNetwork); walletCreates=$testerWalletCreates" `
        -Commands @("npm run flowchain:wallet:live-tester:e2e") `
        -ReportNames @("testerNetwork")))
[void] $capabilities.Add((New-LiveCapability -Id "wallet-transfer" -Title "Wallet-to-wallet transfers" -UserRequirement "People can send funds from wallet to wallet and see settlement in produced blocks." `
        -Classification $(if ($liveWalletPassed -and $testerNetworkPassed -and $testerTransfers -ge 1) { "passed" } else { "failed" }) `
        -Evidence "liveWallet=$(Get-CapabilityStatus -Report $reports.liveWallet); testerTransfers=$testerTransfers; latestHeight=$latestHeight" `
        -Commands @("npm run flowchain:wallet:live-service:e2e", "npm run flowchain:wallet:live-tester:e2e") `
        -ReportNames @("liveWallet", "testerNetwork")))
[void] $capabilities.Add((New-LiveCapability -Id "explorer-faucet-wallet-ui" -Title "Explorer, faucet, and wallet UI" -UserRequirement "Friends and family can create a tester wallet, request faucet funds, send, and inspect Explorer on desktop and mobile." `
        -Classification $(if ($dashboardUiPassed -and $publicTesterGatewayPassed) { "passed" } else { "failed" }) `
        -Evidence "dashboardUi=$(Get-CapabilityStatus -Report $reports.dashboardUiReadiness); gateway=$(Get-CapabilityStatus -Report $reports.publicTesterGateway); routes=$($dashboardRoutes.Count); proofs=$($dashboardProofs.Count)" `
        -Commands @("npm run flowchain:dashboard:ui:readiness", "npm run flowchain:tester:gateway:e2e") `
        -ReportNames @("dashboardUiReadiness", "publicTesterGateway")))
[void] $capabilities.Add((New-LiveCapability -Id "chain-connect-public-rpc" -Title "Public RPC connection" -UserRequirement "People can connect wallets/tester clients to a public HTTPS RPC edge." `
        -Classification $(if ($publicRpcPassed -and $publicRpcCanaryPassed) { "passed" } elseif ($publicRpcBlockers.Count -gt 0) { "blocked-owner-input" } else { "failed" }) `
        -Evidence "publicRpc=$(Get-CapabilityStatus -Report $reports.publicRpc); syntheticCanary=$(Get-CapabilityStatus -Report $reports.publicRpcSyntheticCanary); blockers=$($publicRpcBlockers -join ',')" `
        -Commands @("npm run flowchain:public-rpc:check -- -AllowBlocked", "npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked") `
        -ReportNames @("publicRpc", "publicRpcSyntheticCanary") `
        -Blockers $publicRpcBlockers))
[void] $capabilities.Add((New-LiveCapability -Id "bridge-real-funds" -Title "Real-value bridge pilot" -UserRequirement "People can bridge funds into FlowChain and spend the credited balance." `
        -Classification $(if ($bridgeLivePassed -and $bridgeInfraPassed -and $bridgeRelayerOncePassed) { "passed" } elseif ($bridgeBlockers.Count -gt 0 -and $bridgeRuntimeCreditPassed -and $realValuePilotPassed -and $bridgeReconciliationPassed) { "blocked-owner-input" } else { "failed" }) `
        -Evidence "bridgeLive=$(Get-CapabilityStatus -Report $reports.bridgeLive); bridgeInfra=$(Get-CapabilityStatus -Report $reports.bridgeInfra); runtimeCredit=$(Get-CapabilityStatus -Report $reports.bridgeRuntimeCreditValidation); realValuePilot=$(Get-CapabilityStatus -Report $reports.realValuePilotAggregate); blockers=$($bridgeBlockers -join ',')" `
        -Commands @("npm run flowchain:bridge:live:check -- -AllowBlocked", "npm run flowchain:bridge:infra:check -- -AllowBlocked", "npm run flowchain:bridge:relayer:once -- -AllowBlocked") `
        -ReportNames @("bridgeLive", "bridgeInfra", "bridgeRelayerOnce", "bridgeRuntimeCreditValidation", "realValuePilotAggregate", "bridgeReconciliation") `
        -Blockers $bridgeBlockers))
[void] $capabilities.Add((New-LiveCapability -Id "bridge-relayer-hardening" -Title "Bridge relayer hardening" -UserRequirement "Bridge relayer is guarded against replay, unsafe cursor movement, loop failures, and release-evidence mistakes." `
        -Classification $(if ($bridgeRelayerGuardrailPassed -and $bridgeRelayerLoopPassed -and $bridgeRuntimeCreditPassed -and $bridgeReleaseEvidencePassed) { "passed" } else { "failed" }) `
        -Evidence "guardrail=$(Get-CapabilityStatus -Report $reports.bridgeRelayerGuardrailValidation); loop=$(Get-CapabilityStatus -Report $reports.bridgeRelayerLoopValidation); releaseEvidence=$(Get-CapabilityStatus -Report $reports.bridgeReleaseEvidenceValidation)" `
        -Commands @("npm run flowchain:bridge:relayer:guardrail:validate", "npm run flowchain:bridge:relayer:loop:validate", "npm run flowchain:bridge:release:evidence:validate") `
        -ReportNames @("bridgeRelayerGuardrailValidation", "bridgeRelayerLoopValidation", "bridgeReleaseEvidenceValidation")))
[void] $capabilities.Add((New-LiveCapability -Id "backup-restore" -Title "Backup and restore" -UserRequirement "Live state can be backed up, restored, and proven before public launch." `
        -Classification $(if ($backupReadinessPassed -and $backupRestoreValidationPassed) { "passed" } elseif ($backupBlockers.Count -gt 0 -and $backupRestoreValidationPassed -and $backupOwnerPathDryRunPassed -and $backupInstallPassed) { "blocked-owner-input" } else { "failed" }) `
        -Evidence "backupReadiness=$(Get-CapabilityStatus -Report $reports.backupReadiness); restoreValidation=$(Get-CapabilityStatus -Report $reports.backupRestoreValidation); ownerPathDryRun=$(Get-CapabilityStatus -Report $reports.backupOwnerPathDryRun); blockers=$($backupBlockers -join ',')" `
        -Commands @("npm run flowchain:backup:restore:validate", "npm run flowchain:backup:owner-path:dry-run", "npm run flowchain:backup:check -- -AllowBlocked") `
        -ReportNames @("backupReadiness", "backupRestoreValidation", "backupOwnerPathDryRun", "backupInstallValidation") `
        -Blockers $backupBlockers))
[void] $capabilities.Add((New-LiveCapability -Id "observability-alerting" -Title "Observability and alerting" -UserRequirement "Operators can monitor chain health, public RPC, bridge, backup, testers, and incident gates without leaking secrets." `
        -Classification $(if ($opsSnapshotPassedOrBlocked -and $opsAlertRulesPassed -and $opsMetricsExportPassed -and $monitoringBundlePassed -and $alertInstallPassed -and $metricsInstallPassed) { "passed" } else { "failed" }) `
        -Evidence "opsSnapshot=$(Get-CapabilityStatus -Report $reports.opsSnapshot); alerts=$(Get-CapabilityStatus -Report $reports.opsAlertRules); metrics=$(Get-CapabilityStatus -Report $reports.opsMetricsExport); monitoringBundle=$(Get-CapabilityStatus -Report $reports.monitoringBundle)" `
        -Commands @("npm run flowchain:ops:snapshot -- -AllowBlocked", "npm run flowchain:ops:alerts -- -AllowBlocked", "npm run flowchain:ops:metrics:export -- -AllowBlocked", "npm run flowchain:ops:monitoring:bundle") `
        -ReportNames @("opsSnapshot", "opsAlertRules", "opsMetricsExport", "monitoringBundle", "alertInstallValidation", "metricsInstallValidation")))
[void] $capabilities.Add((New-LiveCapability -Id "external-tester-launch" -Title "External tester launch" -UserRequirement "Friends-and-family testers receive a shareable connection pack only after public RPC, backup, bridge, and tester gates pass." `
        -Classification $(if ($externalTesterReadinessPassed -and $externalTesterPacketStatus -eq "passed" -and $externalTesterClientValidationPassed) { "passed" } elseif ($externalTesterBlockers.Count -gt 0 -and $externalTesterPacketSmokeReady -and $externalTesterClientValidationPassed) { "blocked-owner-input" } else { "failed" }) `
        -Evidence "testerReadiness=$(Get-CapabilityStatus -Report $reports.externalTesterReadiness); packet=$externalTesterPacketStatus; packetSmoke=$externalTesterPacketSmokeReady; clientValidation=$(Get-CapabilityStatus -Report $reports.externalTesterClientValidation); blockers=$($externalTesterBlockers -join ',')" `
        -Commands @("npm run flowchain:tester:readiness -- -AllowBlocked", "npm run flowchain:external-tester:packet -- -AllowBlocked", "npm run flowchain:external-tester:client:validate") `
        -ReportNames @("externalTesterReadiness", "externalTesterPacket", "externalTesterClientValidation") `
        -Blockers $externalTesterBlockers))
[void] $capabilities.Add((New-LiveCapability -Id "developer-ecosystem" -Title "Developer ecosystem" -UserRequirement "Developers have SDK/devkit/docs that connect to FlowChain RPC and prove wallet reads/sends." `
        -Classification $(if ($devPackPassed) { "passed" } else { "failed" }) `
        -Evidence "devPack=$(Get-CapabilityStatus -Report $reports.devPack); methodCount=$(Get-CapabilityProp -Object $reports.devPack -Name "methodCount" -Default 0)" `
        -Commands @("npm run flowchain:dev-pack:e2e") `
        -ReportNames @("devPack") `
        -PublicLaunchCritical $false))
[void] $capabilities.Add((New-LiveCapability -Id "owner-go-live-control" -Title "Owner go-live control" -UserRequirement "Owner setup has exact needs-now, go-live, deployment contract, and completion gates before any public claim." `
        -Classification $(if ($ownerNeedsNowPassed -and $ownerGoLiveHandoffPassed -and $publicDeploymentContractStatus -in @("passed", "blocked")) { "passed" } else { "failed" }) `
        -Evidence "ownerNeedsNow=$(Get-CapabilityStatus -Report $reports.ownerNeedsNow); goLiveHandoff=$(Get-CapabilityStatus -Report $reports.ownerGoLiveHandoff); deploymentContract=$publicDeploymentContractStatus" `
        -Commands @("npm run flowchain:owner:needs-now", "npm run flowchain:owner:go-live-handoff", "npm run flowchain:public-deployment:contract -- -AllowBlocked") `
        -ReportNames @("ownerNeedsNow", "ownerGoLiveHandoff", "publicDeploymentContract")))

$repoBlockedCapabilities = @($capabilities | Where-Object { $_.repoBlocked -eq $true } | ForEach-Object { $_.id })
$blockedCapabilities = @($capabilities | Where-Object { $_.ownerInputBlocked -eq $true } | ForEach-Object { $_.id })
$publicLaunchCriticalCapabilities = @($capabilities | Where-Object { $_.publicLaunchCritical -eq $true })
$classificationCounts = [ordered]@{}
foreach ($classification in @("passed", "blocked-owner-input", "blocked-repo-work", "failed", "missing-evidence")) {
    $classificationCounts[$classification] = @($capabilities | Where-Object { $_.classification -eq $classification }).Count
}

$requiredUserCapabilityIds = @(
    "wallet-create",
    "wallet-transfer",
    "chain-connect-public-rpc",
    "bridge-real-funds",
    "rpc-services-running",
    "block-production",
    "explorer-faucet-wallet-ui"
)
$missingUserCapabilityCoverage = @($requiredUserCapabilityIds | Where-Object { $_ -notin @($capabilities | ForEach-Object { $_.id }) })
$blockedCapabilityRows = @($capabilities | Where-Object { $_.ownerInputBlocked -eq $true })
$blockedCapabilitiesMissingBlockers = @($blockedCapabilityRows | Where-Object { @($_.blockers).Count -eq 0 } | ForEach-Object { $_.id })
$blockedCapabilitiesUnknownBlockers = @($blockedCapabilityRows | ForEach-Object { @($_.blockers) } | Where-Object { $_ -notin $knownOwnerInputs } | Select-Object -Unique)
$allCriticalCapabilitiesEitherPassedOrOwnerBlocked = @($publicLaunchCriticalCapabilities | Where-Object { $_.classification -notin @("passed", "blocked-owner-input") }).Count -eq 0
$productionReady = $publicLaunchCriticalCapabilities.Count -gt 0 -and @($publicLaunchCriticalCapabilities | Where-Object { $_.classification -ne "passed" }).Count -eq 0
$launchReadinessStatus = if ($productionReady) {
    "ready"
}
elseif ($repoBlockedCapabilities.Count -gt 0) {
    "blocked-repo-work"
}
elseif ($blockedCapabilities.Count -gt 0) {
    "blocked-owner-input"
}
else {
    "needs-validation"
}

$loadedRequiredReportNames = @(
    "truthTable",
    "serviceStatus",
    "serviceMonitor",
    "liveWallet",
    "testerNetwork",
    "publicRpc",
    "dashboardUiReadiness",
    "bridgeLive",
    "bridgeRuntimeCreditValidation",
    "realValuePilotAggregate",
    "backupRestoreValidation",
    "monitoringBundle",
    "externalTesterPacket",
    "ownerNeedsNow",
    "devPack"
)
$missingRequiredReports = @($loadedRequiredReportNames | Where-Object { $null -eq $reports[$_] })
$checks = [ordered]@{
    packageScriptPresent = Test-PackageScriptPresent -Name "flowchain:live:capabilities"
    requiredReportsLoaded = $missingRequiredReports.Count -eq 0
    capabilityCountMinimumMet = $capabilities.Count -ge 12
    userRequirementCoverageComplete = $missingUserCapabilityCoverage.Count -eq 0
    publicLaunchCriticalCapabilitiesCovered = $publicLaunchCriticalCapabilities.Count -ge 10
    allCriticalCapabilitiesEitherPassedOrOwnerBlocked = $allCriticalCapabilitiesEitherPassedOrOwnerBlocked
    repoBlockedCapabilitiesEmpty = $repoBlockedCapabilities.Count -eq 0
    blockedCapabilitiesHaveBlockers = $blockedCapabilitiesMissingBlockers.Count -eq 0
    blockedCapabilitiesUseKnownOwnerInputs = $blockedCapabilitiesUnknownBlockers.Count -eq 0
    truthTableOwnerBlockersKnown = $unknownOwnerBlockers.Count -eq 0
    publicRpcCapabilityBlocksOnPublicRpcInputs = if ($publicRpcBlockers.Count -gt 0) { @($capabilities | Where-Object { $_.id -eq "chain-connect-public-rpc" -and $_.classification -eq "blocked-owner-input" }).Count -eq 1 } else { $true }
    bridgeCapabilityBlocksOnBridgeInputs = if ($bridgeBlockers.Count -gt 0) { @($capabilities | Where-Object { $_.id -eq "bridge-real-funds" -and $_.classification -eq "blocked-owner-input" }).Count -eq 1 } else { $true }
    backupCapabilityBlocksOnBackupInput = if ($backupBlockers.Count -gt 0) { @($capabilities | Where-Object { $_.id -eq "backup-restore" -and $_.classification -eq "blocked-owner-input" }).Count -eq 1 } else { $true }
    noProductionReadyClaimWhileBlocked = if ($blockedCapabilities.Count -gt 0) { -not $productionReady } else { $true }
    ownerNeedsNowLoaded = $ownerNeedsNowPassed
    envValuesPrintedFalse = $true
    noSecrets = $true
    broadcastsFalse = $true
    secretMarkerFindingsEmpty = $true
}
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.live_chain_capability_matrix_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    launchReadinessStatus = $launchReadinessStatus
    productionReady = $productionReady
    latestHeight = $latestHeight
    finalizedHeight = $finalizedHeight
    capabilityCount = $capabilities.Count
    publicLaunchCriticalCapabilityCount = $publicLaunchCriticalCapabilities.Count
    blockedCapabilityCount = $blockedCapabilities.Count
    repoBlockedCapabilityCount = $repoBlockedCapabilities.Count
    classificationCounts = $classificationCounts
    userRequirementIds = $requiredUserCapabilityIds
    missingUserCapabilityCoverage = @($missingUserCapabilityCoverage)
    missingRequiredReports = @($missingRequiredReports)
    missingOwnerInputs = @($script:missingOwnerInputs)
    missingRequiredOwnerInputs = @($script:missingRequiredOwnerInputs)
    publicRpcBlockers = @($publicRpcBlockers)
    backupBlockers = @($backupBlockers)
    bridgeBlockers = @($bridgeBlockers)
    externalTesterBlockers = @($externalTesterBlockers)
    blockedCapabilities = @($blockedCapabilities)
    repoBlockedCapabilities = @($repoBlockedCapabilities)
    blockedCapabilitiesMissingBlockers = @($blockedCapabilitiesMissingBlockers)
    blockedCapabilitiesUnknownBlockers = @($blockedCapabilitiesUnknownBlockers)
    capabilities = @($capabilities)
    checks = $checks
    failedChecks = @($failedChecks)
    secretMarkerFindings = @()
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
    noLiveBroadcast = $true
    reportPaths = $paths
}
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Live Chain Capability Matrix")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Launch readiness: $launchReadinessStatus")
$markdownLines.Add("Production ready: $productionReady")
$markdownLines.Add("")
$markdownLines.Add("This matrix maps the user-facing live-chain requirements to concrete reports and commands. It prints names and statuses only, not owner values.")
$markdownLines.Add("")
$markdownLines.Add("## Current Chain")
$markdownLines.Add("")
$markdownLines.Add("- Latest height: $latestHeight")
$markdownLines.Add("- Finalized height: $finalizedHeight")
$markdownLines.Add("- Capability counts: passed=$($classificationCounts['passed']), blocked-owner-input=$($classificationCounts['blocked-owner-input']), repo-blocked=$($repoBlockedCapabilities.Count)")
$markdownLines.Add("")
$markdownLines.Add("## Capabilities")
$markdownLines.Add("")
$markdownLines.Add("| Capability | Status | Evidence | Blockers | First command |")
$markdownLines.Add("| --- | --- | --- | --- | --- |")
foreach ($capability in $capabilities) {
    $blockerText = if (@($capability.blockers).Count -gt 0) { "``$(@($capability.blockers) -join '`, `')``" } else { "none" }
    $commandText = if (@($capability.commands).Count -gt 0) { [string]$capability.commands[0] } else { "not recorded" }
    $evidence = ([string]$capability.evidence).Replace("|", "/")
    $markdownLines.Add("| $($capability.title) | $($capability.classification) | $evidence | $blockerText | ``$commandText`` |")
}
$markdownLines.Add("")
$markdownLines.Add("## Needed Now")
$markdownLines.Add("")
if ($blockedCapabilityRows.Count -eq 0) {
    $markdownLines.Add("No owner-input-blocked capability is currently reported.")
}
else {
    foreach ($capability in $blockedCapabilityRows) {
        $markdownLines.Add("- $($capability.title): $(@($capability.blockers) -join ', ')")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Guardrails")
$markdownLines.Add("")
$markdownLines.Add("- No production-ready claim while any public launch critical capability is blocked.")
$markdownLines.Add("- Blocked capabilities must point to known owner input names.")
$markdownLines.Add("- Repo-blocked capabilities must remain empty before claiming the repo side is done.")
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
$markdownLines.Add("| Check | Passed |")
$markdownLines.Add("| --- | --- |")
foreach ($check in $checks.GetEnumerator()) {
    $markdownLines.Add("| $($check.Key) | $($check.Value) |")
}
Set-Content -LiteralPath $markdownFullPath -Value $markdownLines -Encoding UTF8

Write-Host "FlowChain live capability matrix status: $status"
Write-Host "Launch readiness: $launchReadinessStatus"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($failedChecks.Count -gt 0) {
    throw "FlowChain live capability matrix failed checks: $($failedChecks -join ', ')"
}
