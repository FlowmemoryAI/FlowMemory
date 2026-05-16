param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/flowchain-architecture-audit-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/ARCHITECTURE_AUDIT.md",
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)

$knownExternalOwnerInputs = @(
    "FLOWCHAIN_RPC_PUBLIC_URL",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
    "FLOWCHAIN_RPC_TLS_TERMINATED",
    "FLOWCHAIN_RPC_STATE_BACKUP_PATH",
    "FLOWCHAIN_PILOT_OPERATOR_ACK",
    "FLOWCHAIN_BASE8453_RPC_URL",
    "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
    "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
    "FLOWCHAIN_BASE8453_ASSET_DECIMALS",
    "FLOWCHAIN_BASE8453_FROM_BLOCK",
    "FLOWCHAIN_BASE8453_TO_BLOCK",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_PILOT_CONFIRMATIONS"
)

$reportPaths = [ordered]@{
    serviceStatus = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-status-report.json"
    serviceMonitor = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-monitor-report.json"
    opsSnapshot = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-snapshot-report.json"
    liveWallet = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/live-service-wallet-e2e-report.json"
    testerNetwork = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json"
    publicRpcReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json"
    publicRpcValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json"
    publicRpcAbuseTest = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-abuse-test-report.json"
    backupReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json"
    backupRestoreValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-report.json"
    bridgeLiveReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
    bridgeInfraReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
    bridgePilotLocal = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "services/bridge-relayer/out/real-value-pilot-e2e/bridge-real-value-pilot-e2e-report.json"
    baseTxDiagnostic = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/live-l1-bridge-e2e/base-tx-diagnostic.json"
    ownerOnboarding = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-onboarding-report.json"
    ownerSignupChecklist = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-signup-checklist-report.json"
    ownerInputs = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json"
    ownerEnvReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-env-readiness-report.json"
    ownerEnvReadinessValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-env-readiness-validation-report.json"
    publicRpcEdgeTemplate = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-edge-template-report.json"
    publicRpcDeploymentBundle = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json"
    ownerInputsValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-validation-report.json"
    liveInfra = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-live-infra-check-report.json"
    liveProduct = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-live-product-e2e-report.json"
    externalTester = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
    externalTesterPacket = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json"
    publicDeploymentContract = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json"
    noSecret = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json"
}

function Get-ArchitectureJson {
    param([Parameter(Mandatory = $true)][string] $Path)
    return Read-FlowChainJsonIfExists -Path $Path
}

function Get-ArchitectureProp {
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

function Get-ArchitectureStatus {
    param([AllowNull()][object] $Report)
    return [string](Get-ArchitectureProp -Object $Report -Name "status" -Default "missing")
}

function Test-RepoFile {
    param([Parameter(Mandatory = $true)][string] $Path)
    return Test-Path -LiteralPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $Path)
}

function Test-PackageScript {
    param(
        [Parameter(Mandatory = $true)][AllowNull()][object] $PackageJson,
        [Parameter(Mandatory = $true)][string] $Name
    )

    if ($null -eq $PackageJson -or -not ($PackageJson.PSObject.Properties.Name -contains "scripts")) {
        return $false
    }
    return $PackageJson.scripts.PSObject.Properties.Name -contains $Name
}

function Add-UniqueArchitectureName {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [object] $Value
    )
    $name = "$Value"
    if (-not [string]::IsNullOrWhiteSpace($name) -and -not $Target.Contains($name)) {
        [void] $Target.Add($name)
    }
}

function Add-ArchitectureItem {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Items,
        [Parameter(Mandatory = $true)][string] $Id,
        [Parameter(Mandatory = $true)][string] $Layer,
        [Parameter(Mandatory = $true)][string] $Requirement,
        [Parameter(Mandatory = $true)][string] $Status,
        [Parameter(Mandatory = $true)][string] $Evidence,
        [string[]] $Files = @(),
        [string[]] $Commands = @(),
        [string[]] $Blockers = @()
    )

    [void] $Items.Add([ordered]@{
        id = $Id
        layer = $Layer
        requirement = $Requirement
        status = $Status
        evidence = $Evidence
        files = $Files
        commands = $Commands
        blockers = $Blockers
    })
}

function Test-AllRepoFilesExist {
    param([string[]] $Paths)
    foreach ($path in $Paths) {
        if (-not (Test-RepoFile -Path $path)) {
            return $false
        }
    }
    return $true
}

$packageJsonPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "package.json"
$packageJson = Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json

$reports = [ordered]@{}
foreach ($entry in $reportPaths.GetEnumerator()) {
    $reports[$entry.Key] = Get-ArchitectureJson -Path $entry.Value
}

$readinessMissingEnvSourceNames = @(
    "liveProduct",
    "liveInfra",
    "externalTester",
    "ownerInputs",
    "ownerEnvReadiness",
    "externalTesterPacket",
    "publicRpcReadiness",
    "backupReadiness",
    "bridgeLiveReadiness",
    "bridgeInfraReadiness"
)
$missingOwnerInputs = New-Object System.Collections.ArrayList
foreach ($sourceName in $readinessMissingEnvSourceNames) {
    $report = $reports[$sourceName]
    foreach ($name in @((Get-ArchitectureProp -Object $report -Name "missingEnvNames" -Default @()))) {
        Add-UniqueArchitectureName -Target $missingOwnerInputs -Value $name
    }
}
foreach ($name in @((Get-ArchitectureProp -Object $reports.ownerInputs -Name "invalidEnvNames" -Default @()))) {
    Add-UniqueArchitectureName -Target $missingOwnerInputs -Value $name
}
$diagnosticMissingEnvNames = New-Object System.Collections.ArrayList
foreach ($name in @((Get-ArchitectureProp -Object $reports.baseTxDiagnostic -Name "missingEnvNames" -Default @()))) {
    Add-UniqueArchitectureName -Target $diagnosticMissingEnvNames -Value $name
}

$unknownOwnerInputs = @($missingOwnerInputs | Where-Object { $_ -notin $knownExternalOwnerInputs })
$items = New-Object System.Collections.ArrayList

$service = $reports.serviceStatus
$serviceChain = Get-ArchitectureProp -Object $service -Name "chain"
$serviceProfile = Get-ArchitectureProp -Object $service -Name "serviceProfile"
$serviceNode = Get-ArchitectureProp -Object $service -Name "node"
$serviceControlPlane = Get-ArchitectureProp -Object $service -Name "controlPlane"
$serviceStatus = Get-ArchitectureStatus -Report $service
$latestHeight = [string](Get-ArchitectureProp -Object $serviceChain -Name "latestHeight" -Default "")
$finalizedHeight = [string](Get-ArchitectureProp -Object $serviceChain -Name "finalizedHeight" -Default "")
$liveProfile = Get-ArchitectureProp -Object $serviceProfile -Name "liveProfile" -Default $false
$maxBlocks = [int](Get-ArchitectureProp -Object $serviceProfile -Name "maxBlocks" -Default -1)
$nodeRunning = [string](Get-ArchitectureProp -Object $serviceNode -Name "status") -eq "running"
$controlPlaneRunning = [string](Get-ArchitectureProp -Object $serviceControlPlane -Name "status") -eq "running"
$runtimeFiles = @(
    "crates/flowmemory-devnet/src/cli.rs",
    "crates/flowmemory-devnet/src/storage.rs",
    "infra/scripts/flowchain-service-start.ps1",
    "infra/scripts/flowchain-service-status.ps1",
    "infra/scripts/flowchain-service-stop.ps1",
    "infra/scripts/flowchain-service-restart.ps1"
)
$runtimeReady = (Test-AllRepoFilesExist -Paths $runtimeFiles) `
    -and ($serviceStatus -eq "passed") `
    -and ($liveProfile -eq $true) `
    -and ($maxBlocks -eq 0) `
    -and ($nodeRunning -eq $true) `
    -and ($controlPlaneRunning -eq $true) `
    -and ($latestHeight -match '^\d+$') `
    -and ($finalizedHeight -match '^\d+$')
Add-ArchitectureItem -Items $items -Id "runtime-node-boundary" -Layer "L1 runtime" `
    -Requirement "The block-producing node and service lifecycle are separated from RPC, run in live profile, and expose fresh state evidence." `
    -Status $(if ($runtimeReady) { "passed" } else { "failed" }) `
    -Evidence "serviceStatus=$serviceStatus, liveProfile=$liveProfile, maxBlocks=$maxBlocks, nodeRunning=$nodeRunning, controlPlaneRunning=$controlPlaneRunning, latestHeight=$latestHeight, finalizedHeight=$finalizedHeight" `
    -Files $runtimeFiles `
    -Commands @("npm run flowchain:service:status", "npm run flowchain:service:restart -- -LiveProfile")

$monitor = $reports.serviceMonitor
$monitorStatus = Get-ArchitectureStatus -Report $monitor
$monitorAdvanced = Get-ArchitectureProp -Object $monitor -Name "heightAdvanced" -Default $false
$monitorSamples = [int](Get-ArchitectureProp -Object $monitor -Name "sampleCount" -Default 0)
$opsSnapshot = $reports.opsSnapshot
$opsSnapshotStatus = Get-ArchitectureStatus -Report $opsSnapshot
$opsCriticalCount = [int](Get-ArchitectureProp -Object $opsSnapshot -Name "criticalCount" -Default 999)
$observabilityFiles = @(
    "infra/scripts/flowchain-service-monitor.ps1",
    "infra/scripts/flowchain-ops-snapshot.ps1",
    "infra/scripts/flowchain-emergency-stop-local.ps1",
    "infra/scripts/flowchain-node-stop.ps1"
)
$observabilityReady = (Test-AllRepoFilesExist -Paths $observabilityFiles) `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:service:monitor") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:ops:snapshot") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:emergency:stop-local") `
    -and ($monitorStatus -eq "passed") `
    -and ($monitorAdvanced -eq $true) `
    -and ($monitorSamples -ge 2) `
    -and ($opsSnapshotStatus -in @("passed", "blocked")) `
    -and ($opsCriticalCount -eq 0)
Add-ArchitectureItem -Items $items -Id "ops-observability-boundary" -Layer "Operations" `
    -Requirement "Operations has explicit status, monitor, ops snapshot, and emergency controls that classify incidents separately from owner-input blockers." `
    -Status $(if ($observabilityReady) { "passed" } else { "failed" }) `
    -Evidence "monitorStatus=$monitorStatus, samples=$monitorSamples, heightAdvanced=$monitorAdvanced, opsSnapshot=$opsSnapshotStatus, criticalCount=$opsCriticalCount" `
    -Files $observabilityFiles `
    -Commands @("npm run flowchain:service:monitor", "npm run flowchain:ops:snapshot -- -AllowBlocked", "npm run flowchain:emergency:stop-local")

$publicRpcValidation = $reports.publicRpcValidation
$publicRpcAbuseTest = $reports.publicRpcAbuseTest
$publicRpc = $reports.publicRpcReadiness
$rpcFiles = @(
    "services/control-plane/src/server.ts",
    "services/control-plane/src/methods.ts",
    "infra/scripts/flowchain-public-rpc-readiness.ps1",
    "infra/scripts/flowchain-public-rpc-validation.ps1",
    "infra/scripts/flowchain-public-rpc-abuse-test.ps1"
)
$publicRpcValidationStatus = Get-ArchitectureStatus -Report $publicRpcValidation
$publicRpcValidationChecks = Get-ArchitectureProp -Object $publicRpcValidation -Name "checks"
$corsAllowed = Get-ArchitectureProp -Object $publicRpcValidationChecks -Name "allowedOriginAccepted" -Default $false
$corsRejected = Get-ArchitectureProp -Object $publicRpcValidationChecks -Name "disallowedOriginRejected" -Default $false
$endpointChecks = Get-ArchitectureProp -Object $publicRpcValidationChecks -Name "noFailedEndpointChecks" -Default $false
$rateLimitProbe = Get-ArchitectureProp -Object $publicRpcValidationChecks -Name "rateLimitProbePerformed" -Default $false
$rateLimitRejected = Get-ArchitectureProp -Object $publicRpcValidationChecks -Name "rateLimitRejected" -Default $false
$rateLimitRetryAfter = Get-ArchitectureProp -Object $publicRpcValidationChecks -Name "rateLimitRetryAfterHeaderPresent" -Default $false
$responseHygiene = Get-ArchitectureProp -Object $publicRpcValidationChecks -Name "responseHygienePassed" -Default $false
$publicRpcAbuseStatus = Get-ArchitectureStatus -Report $publicRpcAbuseTest
$publicRpcAbuseReady = Get-ArchitectureProp -Object $publicRpcAbuseTest -Name "abuseTestReady" -Default $false
$publicRpcAbuseChecks = Get-ArchitectureProp -Object $publicRpcAbuseTest -Name "checks"
$publicRpcAbuseRequiredChecks = @(
    "serverStarted",
    "allowedOriginAccepted",
    "disallowedOriginRejected",
    "optionsPreflightPassed",
    "unsupportedMediaTypeRejected",
    "malformedJsonRejected",
    "unknownMethodRejected",
    "badParamsRejected",
    "emptyBatchRejected",
    "oversizedBatchRejected",
    "oversizedBodyRejected",
    "notificationNoContent",
    "rateLimitRejected",
    "responseHygienePassed"
)
$publicRpcAbuseMissingChecks = @($publicRpcAbuseRequiredChecks | Where-Object { (Get-ArchitectureProp -Object $publicRpcAbuseChecks -Name $_ -Default $false) -ne $true })
$publicRpcAbusePassed = $publicRpcAbuseStatus -eq "passed" `
    -and $publicRpcAbuseReady -eq $true `
    -and $publicRpcAbuseMissingChecks.Count -eq 0 `
    -and ((Get-ArchitectureProp -Object $publicRpcAbuseTest -Name "ownerValuesRequired" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $publicRpcAbuseTest -Name "noSecrets" -Default $false) -eq $true)
$rpcBoundaryReady = (Test-AllRepoFilesExist -Paths $rpcFiles) `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:public-rpc:validate") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:public-rpc:abuse-test") `
    -and ($publicRpcValidationStatus -eq "passed") `
    -and ($corsAllowed -eq $true) `
    -and ($corsRejected -eq $true) `
    -and ($endpointChecks -eq $true) `
    -and ($rateLimitProbe -eq $true) `
    -and ($rateLimitRejected -eq $true) `
    -and ($rateLimitRetryAfter -eq $true) `
    -and ($responseHygiene -eq $true) `
    -and ($publicRpcAbusePassed -eq $true)
Add-ArchitectureItem -Items $items -Id "rpc-api-boundary" -Layer "RPC/API" `
    -Requirement "The control-plane API has explicit health/discovery/readiness/CORS/rate-limit validation and abuse rejection before it can be exposed publicly." `
    -Status $(if ($rpcBoundaryReady) { "passed" } else { "failed" }) `
    -Evidence "validationStatus=$publicRpcValidationStatus, corsAllowed=$corsAllowed, corsRejected=$corsRejected, endpointChecks=$endpointChecks, rateLimitProbe=$rateLimitProbe, rateLimitRejected=$rateLimitRejected, rateLimitRetryAfter=$rateLimitRetryAfter, responseHygiene=$responseHygiene, abuseStatus=$publicRpcAbuseStatus, abusePassed=$publicRpcAbusePassed, abuseMissingChecks=$($publicRpcAbuseMissingChecks.Count)" `
    -Files $rpcFiles `
    -Commands @("npm run flowchain:public-rpc:validate", "npm run flowchain:public-rpc:abuse-test")

$publicRpcStatus = Get-ArchitectureStatus -Report $publicRpc
$publicRpcReady = Get-ArchitectureProp -Object $publicRpc -Name "publicRpcReady" -Default $false
Add-ArchitectureItem -Items $items -Id "public-rpc-edge" -Layer "Public edge" `
    -Requirement "External RPC exposure is a distinct owner-operated edge with TLS, allowed origins, rate limits, endpoint checks, and response hygiene." `
    -Status $(if ($publicRpcStatus -eq "passed" -and $publicRpcReady -eq $true) { "passed" } elseif ($publicRpcStatus -eq "blocked") { "blocked" } else { "failed" }) `
    -Evidence "publicRpcStatus=$publicRpcStatus, publicRpcReady=$publicRpcReady" `
    -Files @("infra/scripts/flowchain-public-rpc-readiness.ps1", "docs/OPERATIONS/FLOWCHAIN_OWNER_OPERATED_PUBLIC_RPC.md") `
    -Commands @("npm run flowchain:public-rpc:check") `
    -Blockers @("FLOWCHAIN_RPC_PUBLIC_URL", "FLOWCHAIN_RPC_ALLOWED_ORIGINS", "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE", "FLOWCHAIN_RPC_TLS_TERMINATED")

$publicRpcEdgeTemplate = $reports.publicRpcEdgeTemplate
$publicRpcEdgeTemplateStatus = Get-ArchitectureStatus -Report $publicRpcEdgeTemplate
$edgeTemplateReady = Get-ArchitectureProp -Object $publicRpcEdgeTemplate -Name "edgeTemplateReady" -Default $false
$edgeTemplateRepoOwned = Get-ArchitectureProp -Object $publicRpcEdgeTemplate -Name "flowChainRpcIsRepoOwned" -Default $false
$edgeTemplateThirdPartyNeeded = Get-ArchitectureProp -Object $publicRpcEdgeTemplate -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$edgeTemplateRequiresTls = Get-ArchitectureProp -Object $publicRpcEdgeTemplate -Name "requiresTlsTermination" -Default $false
$edgeTemplateRequiresRateLimit = Get-ArchitectureProp -Object $publicRpcEdgeTemplate -Name "requiresRateLimit" -Default $false
$edgeTemplateForwardsOrigin = Get-ArchitectureProp -Object $publicRpcEdgeTemplate -Name "forwardsOriginForCors" -Default $false
$publicRpcDeploymentBundle = $reports.publicRpcDeploymentBundle
$publicRpcDeploymentBundleStatus = Get-ArchitectureStatus -Report $publicRpcDeploymentBundle
$deploymentBundleChecks = Get-ArchitectureProp -Object $publicRpcDeploymentBundle -Name "checks"
$deploymentBundleReady = $publicRpcDeploymentBundleStatus -eq "passed" `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:public-rpc:deployment-bundle") `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "nginxTemplateWritten" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "ownerEnvExampleWritten" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "verifyRunbookWritten" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentBundleChecks -Name "rollbackRunbookWritten" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $publicRpcDeploymentBundle -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $publicRpcDeploymentBundle -Name "noSecrets" -Default $false) -eq $true)
$publicRpcEdgeTemplateReady = (Test-RepoFile -Path "infra/scripts/flowchain-public-rpc-edge-template.ps1") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:public-rpc:edge-template") `
    -and ($publicRpcEdgeTemplateStatus -eq "passed") `
    -and ($edgeTemplateReady -eq $true) `
    -and ($edgeTemplateRepoOwned -eq $true) `
    -and ($edgeTemplateThirdPartyNeeded -eq $false) `
    -and ($edgeTemplateRequiresTls -eq $true) `
    -and ($edgeTemplateRequiresRateLimit -eq $true) `
    -and ($edgeTemplateForwardsOrigin -eq $true) `
    -and ((Get-ArchitectureProp -Object $publicRpcEdgeTemplate -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $publicRpcEdgeTemplate -Name "noSecrets" -Default $false) -eq $true)
Add-ArchitectureItem -Items $items -Id "public-rpc-edge-template-boundary" -Layer "Public edge" `
    -Requirement "Public RPC exposure has a no-values owner edge template and deployment bundle for HTTPS reverse proxying, rate limiting, verification, and rollback." `
    -Status $(if ($publicRpcEdgeTemplateReady -and $deploymentBundleReady) { "passed" } else { "failed" }) `
    -Evidence "edgeTemplateStatus=$publicRpcEdgeTemplateStatus, bundleStatus=$publicRpcDeploymentBundleStatus, repoOwned=$edgeTemplateRepoOwned, requiresTls=$edgeTemplateRequiresTls, requiresRateLimit=$edgeTemplateRequiresRateLimit, forwardsOrigin=$edgeTemplateForwardsOrigin" `
    -Files @("infra/scripts/flowchain-public-rpc-edge-template.ps1", "infra/scripts/flowchain-public-rpc-deployment-bundle.ps1", "docs/agent-runs/live-product-infra-rpc/PUBLIC_RPC_EDGE_TEMPLATE.md", "docs/agent-runs/live-product-infra-rpc/PUBLIC_RPC_DEPLOYMENT_BUNDLE.md") `
    -Commands @("npm run flowchain:public-rpc:edge-template", "npm run flowchain:public-rpc:deployment-bundle")

$wallet = $reports.liveWallet
$testerNetwork = $reports.testerNetwork
$walletFiles = @(
    "services/control-plane/src/wallet-runtime.ts",
    "infra/scripts/flowchain-live-service-wallet-e2e.ps1",
    "infra/scripts/flowchain-live-service-tester-network-e2e.ps1"
)
$walletStatus = Get-ArchitectureStatus -Report $wallet
$testerStatus = Get-ArchitectureStatus -Report $testerNetwork
$testerCreates = @((Get-ArchitectureProp -Object $testerNetwork -Name "testerWalletCreates" -Default @()))
$testerSecretLeak = @($testerCreates | Where-Object { (Get-ArchitectureProp -Object $_ -Name "secretMaterialReturned" -Default $true) -ne $false }).Count -gt 0
$walletReady = (Test-AllRepoFilesExist -Paths $walletFiles) `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:wallet:live-service:e2e") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:wallet:live-tester:e2e") `
    -and ($walletStatus -eq "passed") `
    -and ($testerStatus -eq "passed") `
    -and ($testerCreates.Count -ge 4) `
    -and ($testerSecretLeak -eq $false)
Add-ArchitectureItem -Items $items -Id "wallet-runtime-boundary" -Layer "Wallets" `
    -Requirement "Wallet creation and wallet-to-wallet transfer are routed through the RPC/control-plane boundary into runtime blocks without returning secret material." `
    -Status $(if ($walletReady) { "passed" } else { "failed" }) `
    -Evidence "walletStatus=$walletStatus, testerStatus=$testerStatus, testerWalletCreates=$($testerCreates.Count), testerSecretLeak=$testerSecretLeak" `
    -Files $walletFiles `
    -Commands @("npm run flowchain:wallet:live-service:e2e", "npm run flowchain:wallet:live-tester:e2e")

$bridgePilot = $reports.bridgePilotLocal
$bridgeExact = Get-ArchitectureProp -Object $bridgePilot -Name "exactValueConservation"
$bridgeNegative = Get-ArchitectureProp -Object $bridgePilot -Name "negativeCoverage"
$bridgeLocalFiles = @(
    "services/bridge-relayer/src/observe-base-lockbox.ts",
    "services/bridge-relayer/src/bridge-pilot-e2e.ts",
    "fixtures/bridge/base8453-pilot-mock-deposit.json"
)
$bridgePilotReady = (Test-AllRepoFilesExist -Paths $bridgeLocalFiles) `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:real-value-pilot:bridge") `
    -and ((Get-ArchitectureProp -Object $bridgePilot -Name "broadcast" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $bridgePilot -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeExact -Name "allAmountsEqual" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeNegative -Name "wrongChainRejected" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $bridgeNegative -Name "unapprovedContractRejected" -Default $false) -eq $true)
Add-ArchitectureItem -Items $items -Id "bridge-local-proof-boundary" -Layer "Bridge" `
    -Requirement "The bridge architecture has a deterministic local proof for exact value, replay protection, wrong-chain rejection, unapproved-lockbox rejection, and no broadcast." `
    -Status $(if ($bridgePilotReady) { "passed" } else { "failed" }) `
    -Evidence "broadcast=$(Get-ArchitectureProp -Object $bridgePilot -Name "broadcast"), allAmountsEqual=$(Get-ArchitectureProp -Object $bridgeExact -Name "allAmountsEqual"), wrongChainRejected=$(Get-ArchitectureProp -Object $bridgeNegative -Name "wrongChainRejected"), unapprovedContractRejected=$(Get-ArchitectureProp -Object $bridgeNegative -Name "unapprovedContractRejected")" `
    -Files $bridgeLocalFiles `
    -Commands @("npm run flowchain:real-value-pilot:bridge")

$bridgeLiveStatus = Get-ArchitectureStatus -Report $reports.bridgeLiveReadiness
$bridgeInfraStatus = Get-ArchitectureStatus -Report $reports.bridgeInfraReadiness
$baseTxDiagnostic = $reports.baseTxDiagnostic
$bridgeLiveFiles = @(
    "infra/scripts/flowchain-bridge-live-check.ps1",
    "infra/scripts/flowchain-live-env-bridge-readiness.ps1",
    "services/bridge-relayer/src/diagnose-base8453-tx.ts",
    "infra/scripts/bridge-base-mainnet-pilot-observe.ps1"
)
$baseTxSafe = ((Get-ArchitectureStatus -Report $baseTxDiagnostic) -in @("blocked", "valid", "invalid")) `
    -and ((Get-ArchitectureProp -Object $baseTxDiagnostic -Name "broadcasts" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $baseTxDiagnostic -Name "printsEnvValues" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $baseTxDiagnostic -Name "noSecrets" -Default $false) -eq $true)
Add-ArchitectureItem -Items $items -Id "bridge-live-edge" -Layer "Bridge" `
    -Requirement "Live Base 8453 bridge observation is isolated behind owner guardrails, read-only diagnostics, confirmation/cap settings, and no-broadcast checks." `
    -Status $(if ($bridgeLiveStatus -eq "passed" -and $bridgeInfraStatus -eq "passed" -and $baseTxSafe) { "passed" } elseif ($bridgeLiveStatus -eq "blocked" -or $bridgeInfraStatus -eq "blocked") { "blocked" } else { "failed" }) `
    -Evidence "bridgeLive=$bridgeLiveStatus, bridgeInfra=$bridgeInfraStatus, baseTxDiagnostic=$(Get-ArchitectureStatus -Report $baseTxDiagnostic), baseTxSafe=$baseTxSafe" `
    -Files $bridgeLiveFiles `
    -Commands @("npm run flowchain:bridge:live:check", "npm run flowchain:bridge:infra:check", "npm run flowchain:bridge:diagnose:tx") `
    -Blockers @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_BASE8453_ASSET_DECIMALS", "FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_BASE8453_TO_BLOCK", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS")

$backupStatus = Get-ArchitectureStatus -Report $reports.backupReadiness
$backupValidation = $reports.backupRestoreValidation
$backupValidationStatus = Get-ArchitectureStatus -Report $backupValidation
$backupValidationChecks = Get-ArchitectureProp -Object $backupValidation -Name "checks"
$backupValidationCorruptionDetected = Get-ArchitectureProp -Object $backupValidationChecks -Name "corruptedSnapshotDetected" -Default $false
$backupValidationPassed = $backupValidationStatus -eq "passed" `
    -and ((Get-ArchitectureProp -Object $backupValidationChecks -Name "backupCommandPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupValidationChecks -Name "restoreCommandPassed" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupValidationChecks -Name "backupRestoreHashRoundTrip" -Default $false) -eq $true) `
    -and ($backupValidationCorruptionDetected -eq $true) `
    -and ((Get-ArchitectureProp -Object $backupValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $backupValidation -Name "noSecrets" -Default $false) -eq $true)
$backupDetails = Get-ArchitectureProp -Object $reports.backupReadiness -Name "backup"
$backupSnapshotProof = Get-ArchitectureProp -Object $backupDetails -Name "snapshotProofStatus" -Default "not-run"
$backupRestoreProof = Get-ArchitectureProp -Object $backupDetails -Name "restoreProofStatus" -Default "not-run"
$backupFiles = @(
    "infra/scripts/flowchain-public-rpc-backup-readiness.ps1",
    "infra/scripts/flowchain-state-backup.ps1",
    "infra/scripts/flowchain-state-restore-verify.ps1",
    "infra/scripts/flowchain-backup-restore-validation.ps1"
)
Add-ArchitectureItem -Items $items -Id "state-backup-boundary" -Layer "Storage/recovery" `
    -Requirement "Live state backup and restore are separate configured storage boundaries with manifest hash proof, restore rehearsal, and corruption detection before public operation." `
    -Status $(if ($backupStatus -eq "passed" -and $backupValidationPassed) { "passed" } elseif ($backupStatus -eq "blocked" -and $backupValidationPassed) { "blocked" } else { "failed" }) `
    -Evidence "backupStatus=$backupStatus, validationStatus=$backupValidationStatus, snapshotProof=$backupSnapshotProof, restoreProof=$backupRestoreProof, corruptionDetected=$backupValidationCorruptionDetected" `
    -Files $backupFiles `
    -Commands @("npm run flowchain:backup:create", "npm run flowchain:backup:restore:verify", "npm run flowchain:backup:restore:validate", "npm run flowchain:backup:check") `
    -Blockers @("FLOWCHAIN_RPC_STATE_BACKUP_PATH")

$deploymentContract = $reports.publicDeploymentContract
$deploymentContractStatus = Get-ArchitectureStatus -Report $deploymentContract
$deploymentContractCounts = Get-ArchitectureProp -Object $deploymentContract -Name "itemCounts"
$deploymentContractFailed = [int](Get-ArchitectureProp -Object $deploymentContractCounts -Name "failed" -Default 1)
$deploymentContractBlocked = [int](Get-ArchitectureProp -Object $deploymentContractCounts -Name "blocked" -Default 0)
$deploymentContractBlockedOnlyKnown = Get-ArchitectureProp -Object $deploymentContract -Name "blockedOnlyOnKnownExternalOwnerInputs" -Default $false
$deploymentContractReady = (Get-ArchitectureProp -Object $deploymentContract -Name "deploymentReady" -Default $false) -eq $true
$deploymentContractSafe = ($deploymentContractStatus -in @("passed", "blocked")) `
    -and ($deploymentContractFailed -eq 0) `
    -and ($deploymentContractBlockedOnlyKnown -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentContract -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $deploymentContract -Name "noLiveBroadcast" -Default $false) -eq $true)
Add-ArchitectureItem -Items $items -Id "public-deployment-contract-boundary" -Layer "Deployment" `
    -Requirement "The owner-operated public deployment contract is machine-checkable, includes rollback commands, and blocks sharing until public RPC, backup, bridge, and tester gates pass." `
    -Status $(if ($deploymentContractStatus -eq "passed" -and $deploymentContractReady -eq $true -and $deploymentContractSafe) { "passed" } elseif ($deploymentContractStatus -eq "blocked" -and $deploymentContractSafe) { "blocked" } else { "failed" }) `
    -Evidence "deploymentStatus=$deploymentContractStatus, deploymentReady=$deploymentContractReady, blockedOnlyKnown=$deploymentContractBlockedOnlyKnown, blockedItems=$deploymentContractBlocked, failedItems=$deploymentContractFailed" `
    -Files @("infra/scripts/flowchain-public-deployment-contract.ps1", "docs/OPERATIONS/FLOWCHAIN_OWNER_OPERATED_PUBLIC_RPC.md") `
    -Commands @("npm run flowchain:public-deployment:contract -- -AllowBlocked") `
    -Blockers @($knownExternalOwnerInputs)

$ownerInputs = $reports.ownerInputs
$ownerInputsValidation = $reports.ownerInputsValidation
$ownerInputFiles = @(
    "infra/scripts/flowchain-owner-inputs.ps1",
    "infra/scripts/flowchain-owner-inputs-validation.ps1"
)
$ownerInputsStatus = Get-ArchitectureStatus -Report $ownerInputs
$ownerValidationStatus = Get-ArchitectureStatus -Report $ownerInputsValidation
$ownerChecks = Get-ArchitectureProp -Object $ownerInputsValidation -Name "checks"
$ownerValidationEnvFilePasses = (Get-ArchitectureProp -Object $ownerChecks -Name "validOwnerEnvFileScenarioPasses" -Default $false) -eq $true
$ownerValidationMissingEnvFileFails = (Get-ArchitectureProp -Object $ownerChecks -Name "missingOwnerEnvFileScenarioFails" -Default $false) -eq $true
$ownerValidationMalformedEnvFileFails = (Get-ArchitectureProp -Object $ownerChecks -Name "malformedOwnerEnvFileScenarioFails" -Default $false) -eq $true
$ownerInputBoundaryReady = (Test-AllRepoFilesExist -Paths $ownerInputFiles) `
    -and ($ownerValidationStatus -eq "passed") `
    -and ((Get-ArchitectureProp -Object $ownerChecks -Name "missingScenarioBlocks" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerChecks -Name "invalidScenarioFails" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerChecks -Name "validStructureScenarioPasses" -Default $false) -eq $true) `
    -and ($ownerValidationEnvFilePasses -eq $true) `
    -and ($ownerValidationMissingEnvFileFails -eq $true) `
    -and ($ownerValidationMalformedEnvFileFails -eq $true) `
    -and ($unknownOwnerInputs.Count -eq 0)
Add-ArchitectureItem -Items $items -Id "owner-input-fail-closed-boundary" -Layer "Governance/safety" `
    -Requirement "Live-only inputs are externally owned, listed by name only, self-tested for missing/invalid/valid direct env plus local owner env-file loading, and fail closed on missing or malformed owner env files without printing values." `
    -Status $(if ($ownerInputBoundaryReady -and $ownerInputsStatus -in @("passed", "blocked")) { "passed" } else { "failed" }) `
    -Evidence "ownerInputsStatus=$ownerInputsStatus, validationStatus=$ownerValidationStatus, ownerEnvFilePasses=$ownerValidationEnvFilePasses, missingOwnerEnvFileFails=$ownerValidationMissingEnvFileFails, malformedOwnerEnvFileFails=$ownerValidationMalformedEnvFileFails, knownMissingInputs=$($missingOwnerInputs.Count), unknownInputs=$($unknownOwnerInputs.Count)" `
    -Files $ownerInputFiles `
    -Commands @("npm run flowchain:owner-inputs:validate", "npm run flowchain:owner-inputs") `
    -Blockers @($missingOwnerInputs)

$ownerEnvReadiness = $reports.ownerEnvReadiness
$ownerEnvReadinessValidation = $reports.ownerEnvReadinessValidation
$ownerEnvReadinessStatus = Get-ArchitectureStatus -Report $ownerEnvReadiness
$ownerEnvReadinessState = Get-ArchitectureProp -Object $ownerEnvReadiness -Name "readiness"
$ownerEnvReadinessPath = Get-ArchitectureProp -Object $ownerEnvReadiness -Name "ownerEnvFile"
$ownerEnvReadinessBlockedOnlyKnown = Get-ArchitectureProp -Object $ownerEnvReadinessState -Name "blockedOnlyOnKnownExternalOwnerInputs" -Default $false
$ownerEnvReadinessGitIgnored = Get-ArchitectureProp -Object $ownerEnvReadinessPath -Name "gitIgnored" -Default $false
$ownerEnvReadinessValidationStatus = Get-ArchitectureStatus -Report $ownerEnvReadinessValidation
$ownerEnvReadinessValidationChecks = Get-ArchitectureProp -Object $ownerEnvReadinessValidation -Name "checks"
$ownerEnvReadinessValidationMissingFails = Get-ArchitectureProp -Object $ownerEnvReadinessValidationChecks -Name "missingOwnerEnvFileFailsBeforeChildGates" -Default $false
$ownerEnvReadinessValidationUnignoredFails = Get-ArchitectureProp -Object $ownerEnvReadinessValidationChecks -Name "unignoredOwnerEnvFileFailsBeforeChildGates" -Default $false
$ownerEnvReadinessSafe = (Test-RepoFile -Path "infra/scripts/flowchain-owner-env-readiness.ps1") `
    -and (Test-RepoFile -Path "infra/scripts/flowchain-owner-env-readiness-validation.ps1") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:owner-env:readiness") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:owner-env:readiness:validate") `
    -and ($ownerEnvReadinessValidationStatus -eq "passed") `
    -and ($ownerEnvReadinessValidationMissingFails -eq $true) `
    -and ($ownerEnvReadinessValidationUnignoredFails -eq $true) `
    -and ($ownerEnvReadinessGitIgnored -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerEnvReadiness -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $ownerEnvReadiness -Name "noSecrets" -Default $false) -eq $true) `
    -and ($ownerEnvReadinessStatus -eq "passed" -or ($ownerEnvReadinessStatus -eq "blocked" -and $ownerEnvReadinessBlockedOnlyKnown -eq $true))
Add-ArchitectureItem -Items $items -Id "owner-env-readiness-boundary" -Layer "Governance/safety" `
    -Requirement "The ignored owner env file is a first-class setup boundary that can drive owner-input, live-infra, and public deployment gates through one redacted command." `
    -Status $(if ($ownerEnvReadinessStatus -eq "passed" -and $ownerEnvReadinessSafe) { "passed" } elseif ($ownerEnvReadinessStatus -eq "blocked" -and $ownerEnvReadinessSafe) { "blocked" } else { "failed" }) `
    -Evidence "readinessStatus=$ownerEnvReadinessStatus, validationStatus=$ownerEnvReadinessValidationStatus, missingFails=$ownerEnvReadinessValidationMissingFails, unignoredFails=$ownerEnvReadinessValidationUnignoredFails, gitIgnored=$ownerEnvReadinessGitIgnored, blockedOnlyKnown=$ownerEnvReadinessBlockedOnlyKnown" `
    -Files @("infra/scripts/flowchain-owner-env-readiness.ps1", "infra/scripts/flowchain-owner-env-readiness-validation.ps1", "docs/agent-runs/live-product-infra-rpc/OWNER_ENV_READINESS.md") `
    -Commands @("npm run flowchain:owner-env:readiness:validate", "npm run flowchain:owner-env:readiness -- -AllowBlocked") `
    -Blockers @($missingOwnerInputs)

$ownerOnboarding = $reports.ownerOnboarding
$ownerOnboardingStatus = Get-ArchitectureStatus -Report $ownerOnboarding
$flowChainRpcIsOurs = Get-ArchitectureProp -Object $ownerOnboarding -Name "flowChainRpcIsOurs" -Default $false
$thirdPartyFlowChainRpcProviderNeeded = Get-ArchitectureProp -Object $ownerOnboarding -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$publicRpcRequiresOwnerPublicEdge = Get-ArchitectureProp -Object $ownerOnboarding -Name "publicRpcRequiresOwnerPublicEdge" -Default $false
$base8453RpcIsExternalChainDependency = Get-ArchitectureProp -Object $ownerOnboarding -Name "base8453RpcIsExternalChainDependency" -Default $false
$ownerOnboardingLocalEnvFileSupported = Get-ArchitectureProp -Object $ownerOnboarding -Name "localEnvFileSupported" -Default $false
$ownerOnboardingReady = (Test-RepoFile -Path "infra/scripts/flowchain-owner-onboarding.ps1") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:owner:onboarding") `
    -and ($ownerOnboardingStatus -eq "passed") `
    -and ($flowChainRpcIsOurs -eq $true) `
    -and ($thirdPartyFlowChainRpcProviderNeeded -eq $false) `
    -and ($publicRpcRequiresOwnerPublicEdge -eq $true) `
    -and ($base8453RpcIsExternalChainDependency -eq $true) `
    -and ($ownerOnboardingLocalEnvFileSupported -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerOnboarding -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $ownerOnboarding -Name "noSecrets" -Default $false) -eq $true)
Add-ArchitectureItem -Items $items -Id "owner-onboarding-boundary" -Layer "Governance/safety" `
    -Requirement "Owner onboarding distinguishes repo-owned FlowChain RPC from the external Base 8453 RPC dependency and gives no-values setup commands." `
    -Status $(if ($ownerOnboardingReady) { "passed" } else { "failed" }) `
    -Evidence "onboardingStatus=$ownerOnboardingStatus, flowChainRpcIsOurs=$flowChainRpcIsOurs, thirdPartyFlowChainRpcProviderNeeded=$thirdPartyFlowChainRpcProviderNeeded, publicRpcRequiresOwnerPublicEdge=$publicRpcRequiresOwnerPublicEdge, base8453RpcIsExternalChainDependency=$base8453RpcIsExternalChainDependency, localEnvFileSupported=$ownerOnboardingLocalEnvFileSupported" `
    -Files @("infra/scripts/flowchain-owner-onboarding.ps1", "docs/agent-runs/live-product-infra-rpc/OWNER_ONBOARDING.md") `
    -Commands @("npm run flowchain:owner:onboarding")

$ownerSignupChecklist = $reports.ownerSignupChecklist
$ownerSignupChecklistStatus = Get-ArchitectureStatus -Report $ownerSignupChecklist
$ownerSignupExternalCount = [int](Get-ArchitectureProp -Object $ownerSignupChecklist -Name "externalSignupCount" -Default 0)
$ownerSignupItemCount = [int](Get-ArchitectureProp -Object $ownerSignupChecklist -Name "itemCount" -Default 0)
$ownerSignupMissingCoverageCount = @((Get-ArchitectureProp -Object $ownerSignupChecklist -Name "missingChecklistCoverage" -Default @())).Count
$ownerSignupRepoOwned = Get-ArchitectureProp -Object $ownerSignupChecklist -Name "flowChainRpcIsRepoOwned" -Default $false
$ownerSignupThirdPartyFlowChainRpcNeeded = Get-ArchitectureProp -Object $ownerSignupChecklist -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$ownerSignupLocalEnvFileSupported = Get-ArchitectureProp -Object $ownerSignupChecklist -Name "localEnvFileSupported" -Default $false
$ownerSignupChecklistReady = (Test-RepoFile -Path "infra/scripts/flowchain-owner-signup-checklist.ps1") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:owner:signup-checklist") `
    -and ($ownerSignupChecklistStatus -eq "passed") `
    -and ($ownerSignupItemCount -ge 8) `
    -and ($ownerSignupExternalCount -ge 3) `
    -and ($ownerSignupMissingCoverageCount -eq 0) `
    -and ($ownerSignupRepoOwned -eq $true) `
    -and ($ownerSignupThirdPartyFlowChainRpcNeeded -eq $false) `
    -and ($ownerSignupLocalEnvFileSupported -eq $true) `
    -and ((Get-ArchitectureProp -Object $ownerSignupChecklist -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $ownerSignupChecklist -Name "noSecrets" -Default $false) -eq $true)
Add-ArchitectureItem -Items $items -Id "owner-signup-checklist-boundary" -Layer "Governance/safety" `
    -Requirement "Owner signup checklist maps public RPC edge, always-on host, backup storage, Base 8453 RPC, bridge details, and local env-file setup to exact owner actions without requesting secrets." `
    -Status $(if ($ownerSignupChecklistReady) { "passed" } else { "failed" }) `
    -Evidence "signupStatus=$ownerSignupChecklistStatus, itemCount=$ownerSignupItemCount, externalSignupCount=$ownerSignupExternalCount, missingCoverage=$ownerSignupMissingCoverageCount, repoOwned=$ownerSignupRepoOwned, localEnvFileSupported=$ownerSignupLocalEnvFileSupported" `
    -Files @("infra/scripts/flowchain-owner-signup-checklist.ps1", "docs/agent-runs/live-product-infra-rpc/OWNER_SIGNUP_CHECKLIST.md") `
    -Commands @("npm run flowchain:owner:signup-checklist")

$noSecret = $reports.noSecret
$liveProduct = $reports.liveProduct
$noSecretStatus = Get-ArchitectureStatus -Report $noSecret
$safetyReady = ($noSecretStatus -eq "passed") `
    -and ((Get-ArchitectureProp -Object $liveProduct -Name "noLiveBroadcast" -Default $false) -eq $true) `
    -and ((Get-ArchitectureProp -Object $liveProduct -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $baseTxDiagnostic -Name "broadcasts" -Default $true) -eq $false) `
    -and ((Get-ArchitectureProp -Object $baseTxDiagnostic -Name "printsEnvValues" -Default $true) -eq $false)
Add-ArchitectureItem -Items $items -Id "secret-broadcast-boundary" -Layer "Security" `
    -Requirement "Architecture reports and live-readiness commands preserve the no-secret and no-live-broadcast safety boundary." `
    -Status $(if ($safetyReady) { "passed" } else { "failed" }) `
    -Evidence "noSecretStatus=$noSecretStatus, liveProductNoLiveBroadcast=$(Get-ArchitectureProp -Object $liveProduct -Name "noLiveBroadcast"), liveProductEnvValuesPrinted=$(Get-ArchitectureProp -Object $liveProduct -Name "envValuesPrinted"), baseTxBroadcasts=$(Get-ArchitectureProp -Object $baseTxDiagnostic -Name "broadcasts")" `
    -Files @("infra/scripts/flowchain-no-secret-scan.ps1") `
    -Commands @("npm run flowchain:no-secret:scan")

$liveInfra = $reports.liveInfra
$externalTester = $reports.externalTester
$externalTesterPacket = $reports.externalTesterPacket
$productGateFiles = @(
    "infra/scripts/flowchain-live-infra-check.ps1",
    "infra/scripts/flowchain-live-product-e2e.ps1",
    "infra/scripts/flowchain-completion-audit.ps1",
    "infra/scripts/flowchain-public-deployment-contract.ps1",
    "infra/scripts/flowchain-external-tester-readiness.ps1",
    "infra/scripts/flowchain-external-tester-packet.ps1"
)
$liveInfraGateStatus = Get-ArchitectureStatus -Report $liveInfra
$liveProductGateStatus = Get-ArchitectureStatus -Report $liveProduct
$externalTesterStatus = Get-ArchitectureStatus -Report $externalTester
$externalTesterPacketStatus = Get-ArchitectureStatus -Report $externalTesterPacket
$externalTesterChecks = Get-ArchitectureProp -Object $externalTester -Name "checks"
$externalTesterNetworkFresh = Get-ArchitectureProp -Object $externalTesterChecks -Name "testerWalletNetworkFresh" -Default $false
$productGateReady = (Test-AllRepoFilesExist -Paths $productGateFiles) `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:live-infra:check") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:live-product:e2e") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:public-deployment:contract") `
    -and (Test-PackageScript -PackageJson $packageJson -Name "flowchain:completion:audit") `
    -and ($liveInfraGateStatus -in @("passed", "blocked")) `
    -and ($liveProductGateStatus -in @("passed", "blocked")) `
    -and ($externalTesterStatus -in @("passed", "blocked")) `
    -and ($externalTesterNetworkFresh -eq $true) `
    -and ($externalTesterPacketStatus -in @("passed", "blocked"))
Add-ArchitectureItem -Items $items -Id "aggregate-verification-boundary" -Layer "Verification" `
    -Requirement "Product-level verification composes runtime, RPC, wallets, bridge, backup, public deployment contract, external tester packet, and completion evidence into one auditable path." `
    -Status $(if ($productGateReady) { "passed" } else { "failed" }) `
    -Evidence "liveInfra=$liveInfraGateStatus, liveProduct=$liveProductGateStatus, externalTester=$externalTesterStatus, testerNetworkFresh=$externalTesterNetworkFresh, externalTesterPacket=$externalTesterPacketStatus" `
    -Files $productGateFiles `
    -Commands @("npm run flowchain:live-infra:check", "npm run flowchain:live-product:e2e", "npm run flowchain:completion:audit", "npm run flowchain:external-tester:packet")

$failedItems = @($items | Where-Object { $_.status -eq "failed" })
$blockedItems = @($items | Where-Object { $_.status -eq "blocked" })
$blockedItemsWithoutBlockers = @($blockedItems | Where-Object { @($_.blockers).Count -eq 0 })
$blockedItemsWithUnknownBlockers = @($blockedItems | Where-Object {
    $itemBlockers = @($_.blockers)
    @($itemBlockers | Where-Object { $_ -notin $knownExternalOwnerInputs }).Count -gt 0
})
$blockedOnlyOnKnownOwnerInputs = ($failedItems.Count -eq 0) `
    -and ($blockedItemsWithoutBlockers.Count -eq 0) `
    -and ($blockedItemsWithUnknownBlockers.Count -eq 0) `
    -and ($unknownOwnerInputs.Count -eq 0)
$status = if ($failedItems.Count -gt 0) { "failed" } elseif ($blockedItems.Count -gt 0) { "blocked" } else { "passed" }

$dataFlows = @(
    [ordered]@{
        name = "private-local-wallet-transfer"
        path = @("tester wallet create", "control-plane /wallets/create", "wallet public metadata", "control-plane /wallets/send", "live node inbox", "runtime block", "wallet balance/transfer reads")
        latestEvidence = $reportPaths.testerNetwork
    },
    [ordered]@{
        name = "public-rpc-exposure"
        path = @("owner TLS endpoint", "allowed-origin/rate-limit gate", "control-plane HTTP server", "JSON-RPC/REST methods", "runtime state reads")
        latestEvidence = $reportPaths.publicRpcReadiness
        blockedBy = @("FLOWCHAIN_RPC_PUBLIC_URL", "FLOWCHAIN_RPC_ALLOWED_ORIGINS", "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE", "FLOWCHAIN_RPC_TLS_TERMINATED")
    },
    [ordered]@{
        name = "public-rpc-edge-template"
        path = @("placeholder edge config", "owner DNS/TLS", "rate-limited reverse proxy", "private FlowChain RPC origin", "readiness gates")
        latestEvidence = $reportPaths.publicRpcEdgeTemplate
    },
    [ordered]@{
        name = "owner-public-edge-onboarding"
        path = @("owner signup decisions", "public DNS/TLS/proxy", "repo-owned FlowChain RPC origin", "local-only env values", "public readiness gates")
        latestEvidence = $reportPaths.ownerOnboarding
    },
    [ordered]@{
        name = "owner-signup-checklist"
        path = @("owner signup/setup list", "public RPC hostname", "always-on host", "backup storage", "Base 8453 RPC", "bridge pilot values", "local env-file loader")
        latestEvidence = $reportPaths.ownerSignupChecklist
    },
    [ordered]@{
        name = "base8453-bridge-credit"
        path = @("Base 8453 lockbox event", "read-only bridge observer", "deposit validation", "bridge credit handoff", "runtime block inclusion", "wallet spend path")
        latestEvidence = $reportPaths.bridgeInfraReadiness
        blockedBy = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_BASE8453_ASSET_DECIMALS", "FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_BASE8453_TO_BLOCK", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS")
    },
    [ordered]@{
        name = "state-recovery"
        path = @("runtime state file", "service status/readiness", "owner backup path", "write/read backup proof", "operator recovery command")
        latestEvidence = $reportPaths.backupReadiness
        blockedBy = @("FLOWCHAIN_RPC_STATE_BACKUP_PATH")
    }
)

$objectiveDeliverables = @(
    "A live-profile L1 node produces and finalizes blocks.",
    "RPC clients can connect through a private service now and through a public owner-operated edge only after TLS/CORS/rate-limit checks pass.",
    "Public RPC exposure has a no-values owner edge template for HTTPS reverse proxying, rate limiting, and CORS-origin forwarding.",
    "Wallets can be created without returned secret material and can send wallet-to-wallet transfers that settle in produced blocks.",
    "Bridge funds are modeled through a Base 8453 observer/credit path that is local-proven and live-blocked until owner guardrails are configured.",
    "State backup, monitoring, service lifecycle, emergency stop, and external tester packet are explicit operational boundaries.",
    "Owner onboarding explicitly separates the repo-owned FlowChain RPC public edge from the external Base 8453 bridge RPC dependency.",
    "Owner signup checklist maps the external services and local setup values needed for public operation without requesting secrets.",
    "The owner-operated public deployment contract has pre-exposure and rollback commands and cannot become shareable until all public gates pass.",
    "Every missing production edge fails closed on exact owner input names, with no secrets, env values, or live broadcasts."
)

$report = [ordered]@{
    schema = "flowchain.architecture_audit_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    blockedOnlyOnKnownExternalOwnerInputs = $blockedOnlyOnKnownOwnerInputs
    objectiveDeliverables = $objectiveDeliverables
    itemCounts = [ordered]@{
        passed = @($items | Where-Object { $_.status -eq "passed" }).Count
        blocked = $blockedItems.Count
        failed = $failedItems.Count
        total = $items.Count
    }
    items = @($items)
    dataFlows = $dataFlows
    missingEnvNames = @($missingOwnerInputs)
    diagnosticMissingEnvNames = @($diagnosticMissingEnvNames)
    unknownMissingEnvNames = @($unknownOwnerInputs)
    knownExternalOwnerInputs = $knownExternalOwnerInputs
    reportPaths = $reportPaths
    architectureMarkdownPath = $markdownFullPath
    noLiveBroadcast = $true
    envValuesPrinted = $false
    noSecrets = $true
}

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Architecture Audit")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Blocked only on known external owner inputs: $blockedOnlyOnKnownOwnerInputs")
$markdownLines.Add("")
$markdownLines.Add("## Concrete Deliverables")
$markdownLines.Add("")
foreach ($deliverable in $objectiveDeliverables) {
    $markdownLines.Add("- $deliverable")
}
$markdownLines.Add("")
$markdownLines.Add("## Architecture Checklist")
$markdownLines.Add("")
$markdownLines.Add("| Layer | Requirement | Status | Evidence |")
$markdownLines.Add("| --- | --- | --- | --- |")
foreach ($item in $items) {
    $markdownLines.Add("| $($item.layer.Replace('|','/')) | $($item.requirement.Replace('|','/')) | $($item.status) | $($item.evidence.Replace('|','/')) |")
}
$markdownLines.Add("")
$markdownLines.Add("## Data Flows")
$markdownLines.Add("")
foreach ($flow in $dataFlows) {
    $markdownLines.Add("- $($flow.name): $((@($flow.path)) -join ' -> ')")
}
$markdownLines.Add("")
$markdownLines.Add("## Remaining External Owner Inputs")
$markdownLines.Add("")
if ($missingOwnerInputs.Count -eq 0) {
    $markdownLines.Add("- None")
}
else {
    foreach ($name in @($missingOwnerInputs)) {
        $markdownLines.Add("- $name")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Architecture Decision")
$markdownLines.Add("")
if ($status -eq "failed") {
    $markdownLines.Add("The architecture audit found failed local evidence. Do not treat the L1 architecture as ready.")
}
elseif ($status -eq "blocked") {
    $markdownLines.Add("The local architecture is explicit and evidence-backed, but public RPC, backup, and/or Base 8453 live edges remain blocked until exact owner inputs are configured.")
}
else {
    $markdownLines.Add("All audited architecture boundaries are passed.")
}

$reportText = $report | ConvertTo-Json -Depth 20
Assert-FlowChainNoSecretText -Text $reportText -Label "architecture audit report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "architecture audit markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain architecture audit status: $status"
Write-Host "Blocked only on known external owner inputs: $blockedOnlyOnKnownOwnerInputs"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($missingOwnerInputs.Count -gt 0) {
    Write-Host "Missing env names: $((@($missingOwnerInputs)) -join ', ')"
}

if ($status -eq "passed" -or ($status -eq "blocked" -and $AllowBlocked)) {
    exit 0
}
exit 1
