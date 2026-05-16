param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/PUBLIC_DEPLOYMENT_CONTRACT.md",
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

$knownOwnerInputs = @(
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

$paths = [ordered]@{
    serviceStatus = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-status-report.json"
    serviceMonitor = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-monitor-report.json"
    opsSnapshot = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-snapshot-report.json"
    ownerOnboarding = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-onboarding-report.json"
    ownerSignupChecklist = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-signup-checklist-report.json"
    ownerEnvTemplate = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-env-template-report.json"
    ownerInputs = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json"
    publicRpcEdgeTemplate = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-edge-template-report.json"
    publicRpc = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json"
    publicRpcValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json"
    backup = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json"
    backupRestoreValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-report.json"
    bridgeLive = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
    bridgeInfra = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
    externalTester = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
    externalTesterPacket = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json"
    architectureAudit = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-architecture-audit-report.json"
    noSecret = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json"
}

function Get-DeploymentJson {
    param([Parameter(Mandatory = $true)][string] $Path)
    return Read-FlowChainJsonIfExists -Path $Path
}

function Get-DeploymentProp {
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

function Get-DeploymentStatus {
    param([AllowNull()][object] $Report)
    return [string](Get-DeploymentProp -Object $Report -Name "status" -Default "missing")
}

function Test-DeploymentPackageScript {
    param(
        [Parameter(Mandatory = $true)][object] $PackageJson,
        [Parameter(Mandatory = $true)][string] $Name
    )

    return $PackageJson.PSObject.Properties.Name -contains "scripts" -and $PackageJson.scripts.PSObject.Properties.Name -contains $Name
}

function Add-UniqueDeploymentName {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [object] $Value
    )
    $name = "$Value"
    if (-not [string]::IsNullOrWhiteSpace($name) -and -not $Target.Contains($name)) {
        [void] $Target.Add($name)
    }
}

function Add-DeploymentItem {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Items,
        [Parameter(Mandatory = $true)][string] $Id,
        [Parameter(Mandatory = $true)][string] $Requirement,
        [Parameter(Mandatory = $true)][string] $Status,
        [Parameter(Mandatory = $true)][string] $Evidence,
        [string[]] $Commands = @(),
        [string[]] $Blockers = @()
    )

    [void] $Items.Add([ordered]@{
        id = $Id
        requirement = $Requirement
        status = $Status
        evidence = $Evidence
        commands = $Commands
        blockers = $Blockers
    })
}

function ConvertTo-DeploymentSafeOutputLine {
    param([AllowNull()][object] $Line)

    $text = "$Line"
    foreach ($name in $knownOwnerInputs) {
        $escapedName = [System.Text.RegularExpressions.Regex]::Escape($name)
        $text = [System.Text.RegularExpressions.Regex]::Replace(
            $text,
            "(?i)($escapedName\s*[:=]\s*)([^\s,;]+)",
            {
                param([System.Text.RegularExpressions.Match] $Match)
                return "$($Match.Groups[1].Value)<redacted>"
            }
        )
    }
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "https?://[^\s,)]+", "<redacted-url>")
    return $text
}

function Invoke-DeploymentChildProcess {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string[]] $ArgumentList
    )

    $startedAt = (Get-Date).ToUniversalTime().ToString("o")
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = (& powershell @ArgumentList 2>&1) | ForEach-Object { ConvertTo-DeploymentSafeOutputLine -Line $_ }
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) {
            $exitCode = 0
        }
    }
    catch {
        $output = @(ConvertTo-DeploymentSafeOutputLine -Line $_.Exception.Message)
        $exitCode = 1
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    return [ordered]@{
        name = $Name
        startedAt = $startedAt
        finishedAt = (Get-Date).ToUniversalTime().ToString("o")
        exitCode = [int] $exitCode
        outputRedacted = @($output)
    }
}

function Add-DeploymentRefreshStep {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Steps,
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string[]] $ArgumentList
    )

    $result = Invoke-DeploymentChildProcess -Name $Name -ArgumentList $ArgumentList
    [void] $Steps.Add($result)
}

$dependencyRefreshSteps = New-Object System.Collections.ArrayList
$dependencyRefreshCommands = @(
    "npm run flowchain:service:status -- -AllowBlocked",
    "npm run flowchain:service:monitor -- -DurationSeconds 20 -PollSeconds 5 -MaxStateAgeSeconds 90",
    "npm run flowchain:ops:snapshot -- -AllowBlocked",
    "npm run flowchain:owner:onboarding",
    "npm run flowchain:owner:signup-checklist",
    "npm run flowchain:owner-env:template",
    "npm run flowchain:owner-inputs -- -AllowBlocked",
    "npm run flowchain:public-rpc:edge-template",
    "npm run flowchain:public-rpc:validate",
    "npm run flowchain:public-rpc:check -- -AllowBlocked",
    "npm run flowchain:backup:restore:validate",
    "npm run flowchain:backup:check -- -AllowBlocked",
    "npm run flowchain:bridge:live:check -- -AllowBlocked",
    "npm run flowchain:bridge:infra:check -- -AllowBlocked",
    "npm run flowchain:external-tester:packet -- -AllowBlocked",
    "npm run flowchain:no-secret:scan"
)

if (-not $NoRefresh.IsPresent) {
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "service-status" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-status.ps1"), "-AllowBlocked", "-ReportPath", $paths.serviceStatus)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "service-monitor" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-monitor.ps1"), "-DurationSeconds", "20", "-PollSeconds", "5", "-MaxStateAgeSeconds", "90", "-ReportPath", $paths.serviceMonitor)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "ops-snapshot" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-ops-snapshot.ps1"), "-AllowBlocked", "-NoRefresh", "-ReportPath", $paths.opsSnapshot)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "owner-onboarding" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-onboarding.ps1"), "-ReportPath", $paths.ownerOnboarding)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "owner-signup-checklist" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-signup-checklist.ps1"), "-ReportPath", $paths.ownerSignupChecklist)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "owner-env-template" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-env-template.ps1"), "-ReportPath", $paths.ownerEnvTemplate)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "owner-inputs" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-inputs.ps1"), "-AllowBlocked", "-ReportPath", $paths.ownerInputs)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-rpc-edge-template" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-edge-template.ps1"), "-ReportPath", $paths.publicRpcEdgeTemplate)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-rpc-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-validation.ps1"), "-ReportPath", $paths.publicRpcValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-rpc-readiness" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-readiness.ps1"), "-AllowBlocked", "-ReportPath", $paths.publicRpc)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "backup-restore-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-backup-restore-validation.ps1"), "-ReportPath", $paths.backupRestoreValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-rpc-backup" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-backup-readiness.ps1"), "-AllowBlocked", "-ReportPath", $paths.backup)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "bridge-live" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-live-check.ps1"), "-AllowBlocked", "-ReportPath", $paths.bridgeLive)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "bridge-infra" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-live-env-bridge-readiness.ps1"), "-AllowBlocked", "-ReportPath", $paths.bridgeInfra)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "external-tester-packet" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-external-tester-packet.ps1"), "-AllowBlocked", "-ReportPath", $paths.externalTesterPacket)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "no-secret-scan" -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Join-Path $PSScriptRoot "flowchain-no-secret-scan.ps1"),
        "-Paths",
        "docs/agent-runs/live-product-infra-rpc",
        "docs/OPERATIONS",
        "services/bridge-relayer/out/real-value-pilot-e2e",
        "devnet/local/live-l1-bridge-e2e",
        "-ReportPath",
        $paths.noSecret
    )
}

$dependencyRefreshFailedSteps = @($dependencyRefreshSteps | Where-Object { [int] $_.exitCode -ne 0 })
$dependencyRefresh = [ordered]@{
    performed = -not $NoRefresh.IsPresent
    delegatedToCaller = $NoRefresh.IsPresent
    failedStepNames = @($dependencyRefreshFailedSteps | ForEach-Object { $_.name })
    steps = @($dependencyRefreshSteps)
}

$packageJson = Get-Content -Raw -LiteralPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "package.json") | ConvertFrom-Json
$reports = [ordered]@{}
foreach ($entry in $paths.GetEnumerator()) {
    $reports[$entry.Key] = Get-DeploymentJson -Path $entry.Value
}

$missingEnvNames = New-Object System.Collections.ArrayList
foreach ($report in $reports.Values) {
    foreach ($name in @((Get-DeploymentProp -Object $report -Name "missingEnvNames" -Default @()))) {
        if ($name -in $knownOwnerInputs) {
            Add-UniqueDeploymentName -Target $missingEnvNames -Value $name
        }
    }
}
foreach ($name in @((Get-DeploymentProp -Object $reports.ownerInputs -Name "invalidEnvNames" -Default @()))) {
    Add-UniqueDeploymentName -Target $missingEnvNames -Value $name
}
$unknownMissingEnvNames = @($missingEnvNames | Where-Object { $_ -notin $knownOwnerInputs })

$items = New-Object System.Collections.ArrayList
Add-DeploymentItem -Items $items -Id "dependency-report-refresh" `
    -Requirement "The deployment contract evaluates reports freshly generated by this command or an explicit caller such as the completion audit." `
    -Status $(if ($dependencyRefreshFailedSteps.Count -eq 0) { "passed" } else { "failed" }) `
    -Evidence "refreshPerformed=$($dependencyRefresh.performed), delegatedToCaller=$($dependencyRefresh.delegatedToCaller), failedSteps=$($dependencyRefreshFailedSteps.Count)" `
    -Commands $dependencyRefreshCommands

$ownerOnboarding = $reports.ownerOnboarding
$ownerOnboardingStatus = Get-DeploymentStatus -Report $ownerOnboarding
$flowChainRpcIsOurs = Get-DeploymentProp -Object $ownerOnboarding -Name "flowChainRpcIsOurs" -Default $false
$thirdPartyFlowChainRpcProviderNeeded = Get-DeploymentProp -Object $ownerOnboarding -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$publicRpcRequiresOwnerPublicEdge = Get-DeploymentProp -Object $ownerOnboarding -Name "publicRpcRequiresOwnerPublicEdge" -Default $false
$base8453RpcIsExternalChainDependency = Get-DeploymentProp -Object $ownerOnboarding -Name "base8453RpcIsExternalChainDependency" -Default $false
$ownerOnboardingLocalEnvFileSupported = Get-DeploymentProp -Object $ownerOnboarding -Name "localEnvFileSupported" -Default $false
$ownerOnboardingReady = ($ownerOnboardingStatus -eq "passed") `
    -and ($flowChainRpcIsOurs -eq $true) `
    -and ($thirdPartyFlowChainRpcProviderNeeded -eq $false) `
    -and ($publicRpcRequiresOwnerPublicEdge -eq $true) `
    -and ($base8453RpcIsExternalChainDependency -eq $true) `
    -and ($ownerOnboardingLocalEnvFileSupported -eq $true) `
    -and ((Get-DeploymentProp -Object $ownerOnboarding -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $ownerOnboarding -Name "noSecrets" -Default $false) -eq $true)
Add-DeploymentItem -Items $items -Id "owner-onboarding-packet" `
    -Requirement "Owner onboarding clearly distinguishes repo-owned FlowChain RPC from the external Base 8453 RPC dependency without values and documents local owner env-file loading." `
    -Status $(if ($ownerOnboardingReady) { "passed" } else { "failed" }) `
    -Evidence "onboardingStatus=$ownerOnboardingStatus, flowChainRpcIsOurs=$flowChainRpcIsOurs, publicRpcRequiresOwnerPublicEdge=$publicRpcRequiresOwnerPublicEdge, base8453RpcIsExternalChainDependency=$base8453RpcIsExternalChainDependency, localEnvFileSupported=$ownerOnboardingLocalEnvFileSupported" `
    -Commands @("npm run flowchain:owner:onboarding")

$ownerSignupChecklist = $reports.ownerSignupChecklist
$ownerSignupChecklistStatus = Get-DeploymentStatus -Report $ownerSignupChecklist
$ownerSignupExternalCount = [int](Get-DeploymentProp -Object $ownerSignupChecklist -Name "externalSignupCount" -Default 0)
$ownerSignupItemCount = [int](Get-DeploymentProp -Object $ownerSignupChecklist -Name "itemCount" -Default 0)
$ownerSignupMissingCoverageCount = @((Get-DeploymentProp -Object $ownerSignupChecklist -Name "missingChecklistCoverage" -Default @())).Count
$ownerSignupRepoOwned = Get-DeploymentProp -Object $ownerSignupChecklist -Name "flowChainRpcIsRepoOwned" -Default $false
$ownerSignupThirdPartyFlowChainRpcNeeded = Get-DeploymentProp -Object $ownerSignupChecklist -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$ownerSignupLocalEnvFileSupported = Get-DeploymentProp -Object $ownerSignupChecklist -Name "localEnvFileSupported" -Default $false
$ownerSignupChecklistReady = ($ownerSignupChecklistStatus -eq "passed") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:owner:signup-checklist") `
    -and ($ownerSignupItemCount -ge 8) `
    -and ($ownerSignupExternalCount -ge 3) `
    -and ($ownerSignupMissingCoverageCount -eq 0) `
    -and ($ownerSignupRepoOwned -eq $true) `
    -and ($ownerSignupThirdPartyFlowChainRpcNeeded -eq $false) `
    -and ($ownerSignupLocalEnvFileSupported -eq $true) `
    -and ((Get-DeploymentProp -Object $ownerSignupChecklist -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $ownerSignupChecklist -Name "noSecrets" -Default $false) -eq $true)
Add-DeploymentItem -Items $items -Id "owner-signup-checklist" `
    -Requirement "Owner signup checklist maps every public RPC, backup, and Base 8453 bridge value to the exact thing the owner must get without requesting secrets in chat." `
    -Status $(if ($ownerSignupChecklistReady) { "passed" } else { "failed" }) `
    -Evidence "signupStatus=$ownerSignupChecklistStatus, itemCount=$ownerSignupItemCount, externalSignupCount=$ownerSignupExternalCount, missingCoverage=$ownerSignupMissingCoverageCount, repoOwned=$ownerSignupRepoOwned, localEnvFileSupported=$ownerSignupLocalEnvFileSupported" `
    -Commands @("npm run flowchain:owner:signup-checklist")

$ownerEnvTemplate = $reports.ownerEnvTemplate
$ownerEnvTemplateStatus = Get-DeploymentStatus -Report $ownerEnvTemplate
$ownerEnvTemplateGitIgnored = Get-DeploymentProp -Object $ownerEnvTemplate -Name "pathIsGitIgnored" -Default $false
$ownerEnvTemplateIncludesRequired = Get-DeploymentProp -Object $ownerEnvTemplate -Name "templateIncludesAllRequiredEnvNames" -Default $false
$ownerEnvTemplateRequiredCount = [int](Get-DeploymentProp -Object $ownerEnvTemplate -Name "requiredEnvNameCount" -Default 0)
$ownerEnvTemplateReady = ($ownerEnvTemplateStatus -eq "passed") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:owner-env:template") `
    -and ($ownerEnvTemplateGitIgnored -eq $true) `
    -and ($ownerEnvTemplateIncludesRequired -eq $true) `
    -and ($ownerEnvTemplateRequiredCount -eq $knownOwnerInputs.Count) `
    -and ((Get-DeploymentProp -Object $ownerEnvTemplate -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $ownerEnvTemplate -Name "noSecrets" -Default $false) -eq $true)
Add-DeploymentItem -Items $items -Id "owner-env-template" `
    -Requirement "Owner env-file setup has a command-generated local scaffold whose target path is git-ignored before owner values are added." `
    -Status $(if ($ownerEnvTemplateReady) { "passed" } else { "failed" }) `
    -Evidence "templateStatus=$ownerEnvTemplateStatus, pathIsGitIgnored=$ownerEnvTemplateGitIgnored, requiredEnvNameCount=$ownerEnvTemplateRequiredCount, includesAllRequired=$ownerEnvTemplateIncludesRequired" `
    -Commands @("npm run flowchain:owner-env:template")

$publicRpcEdgeTemplate = $reports.publicRpcEdgeTemplate
$publicRpcEdgeTemplateStatus = Get-DeploymentStatus -Report $publicRpcEdgeTemplate
$edgeTemplateReady = Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "edgeTemplateReady" -Default $false
$edgeTemplateRepoOwned = Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "flowChainRpcIsRepoOwned" -Default $false
$edgeTemplateThirdPartyNeeded = Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$edgeTemplateRequiresTls = Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "requiresTlsTermination" -Default $false
$edgeTemplateRequiresRateLimit = Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "requiresRateLimit" -Default $false
$edgeTemplateForwardsOrigin = Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "forwardsOriginForCors" -Default $false
$publicRpcEdgeTemplateReady = ($publicRpcEdgeTemplateStatus -eq "passed") `
    -and ($edgeTemplateReady -eq $true) `
    -and ($edgeTemplateRepoOwned -eq $true) `
    -and ($edgeTemplateThirdPartyNeeded -eq $false) `
    -and ($edgeTemplateRequiresTls -eq $true) `
    -and ($edgeTemplateRequiresRateLimit -eq $true) `
    -and ($edgeTemplateForwardsOrigin -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "noSecrets" -Default $false) -eq $true)
Add-DeploymentItem -Items $items -Id "public-rpc-edge-template" `
    -Requirement "Public RPC exposure has a no-values owner edge template for HTTPS reverse proxying, rate limiting, and CORS-origin forwarding." `
    -Status $(if ($publicRpcEdgeTemplateReady) { "passed" } else { "failed" }) `
    -Evidence "edgeTemplateStatus=$publicRpcEdgeTemplateStatus, repoOwned=$edgeTemplateRepoOwned, requiresTls=$edgeTemplateRequiresTls, requiresRateLimit=$edgeTemplateRequiresRateLimit, forwardsOrigin=$edgeTemplateForwardsOrigin" `
    -Commands @("npm run flowchain:public-rpc:edge-template")

$service = $reports.serviceStatus
$serviceStatus = Get-DeploymentStatus -Report $service
$bind = Get-DeploymentProp -Object $service -Name "bind"
$chain = Get-DeploymentProp -Object $service -Name "chain"
$node = Get-DeploymentProp -Object $service -Name "node"
$controlPlane = Get-DeploymentProp -Object $service -Name "controlPlane"
$serviceProfile = Get-DeploymentProp -Object $service -Name "serviceProfile"
$latestHeight = [string](Get-DeploymentProp -Object $chain -Name "latestHeight" -Default "")
$finalizedHeight = [string](Get-DeploymentProp -Object $chain -Name "finalizedHeight" -Default "")
$privateBind = (Get-DeploymentProp -Object $bind -Name "localDefaultPrivate" -Default $false) -eq $true
$serviceReady = ($serviceStatus -eq "passed") `
    -and ($privateBind -eq $true) `
    -and ([string](Get-DeploymentProp -Object $node -Name "status") -eq "running") `
    -and ([string](Get-DeploymentProp -Object $controlPlane -Name "status") -eq "running") `
    -and ((Get-DeploymentProp -Object $serviceProfile -Name "liveProfile" -Default $false) -eq $true) `
    -and ($latestHeight -match '^\d+$') `
    -and ($finalizedHeight -match '^\d+$')
Add-DeploymentItem -Items $items -Id "private-service-origin" `
    -Requirement "The public deployment origin service is running privately in live profile before any owner TLS edge is considered shareable." `
    -Status $(if ($serviceReady) { "passed" } else { "failed" }) `
    -Evidence "serviceStatus=$serviceStatus, privateBind=$privateBind, latestHeight=$latestHeight, finalizedHeight=$finalizedHeight" `
    -Commands @("npm run flowchain:service:status")

$monitor = $reports.serviceMonitor
$monitorStatus = Get-DeploymentStatus -Report $monitor
$monitorAdvanced = Get-DeploymentProp -Object $monitor -Name "heightAdvanced" -Default $false
$monitorSamples = [int](Get-DeploymentProp -Object $monitor -Name "sampleCount" -Default 0)
Add-DeploymentItem -Items $items -Id "pre-share-monitoring" `
    -Requirement "The deployment has recent service-monitor evidence that block height advances over multiple samples." `
    -Status $(if (($monitorStatus -eq "passed") -and ($monitorAdvanced -eq $true) -and ($monitorSamples -ge 2)) { "passed" } else { "failed" }) `
    -Evidence "monitorStatus=$monitorStatus, samples=$monitorSamples, heightAdvanced=$monitorAdvanced" `
    -Commands @("npm run flowchain:service:monitor")

$opsSnapshot = $reports.opsSnapshot
$opsSnapshotStatus = Get-DeploymentStatus -Report $opsSnapshot
$opsCriticalCount = [int](Get-DeploymentProp -Object $opsSnapshot -Name "criticalCount" -Default 999)
$opsBlockedCount = [int](Get-DeploymentProp -Object $opsSnapshot -Name "blockedCount" -Default 0)
Add-DeploymentItem -Items $items -Id "ops-snapshot" `
    -Requirement "Owner deployment has a no-secret ops snapshot that separates critical incidents from expected owner-input blockers and lists incident commands." `
    -Status $(if (($opsSnapshotStatus -in @("passed", "blocked")) -and $opsCriticalCount -eq 0) { "passed" } else { "failed" }) `
    -Evidence "opsSnapshot=$opsSnapshotStatus, criticalCount=$opsCriticalCount, blockedCount=$opsBlockedCount" `
    -Commands @("npm run flowchain:ops:snapshot -- -AllowBlocked")

$ownerInputs = $reports.ownerInputs
$ownerStatus = Get-DeploymentStatus -Report $ownerInputs
$ownerReady = Get-DeploymentProp -Object $ownerInputs -Name "ownerInputReady" -Default $false
Add-DeploymentItem -Items $items -Id "owner-input-contract" `
    -Requirement "The owner deployment contract validates the required public RPC, backup, and Base 8453 input names without values." `
    -Status $(if (($ownerStatus -eq "passed") -and ($ownerReady -eq $true)) { "passed" } elseif ($ownerStatus -eq "blocked") { "blocked" } else { "failed" }) `
    -Evidence "ownerInputsStatus=$ownerStatus, ownerInputReady=$ownerReady" `
    -Commands @("npm run flowchain:owner-inputs") `
    -Blockers @($knownOwnerInputs)

$publicRpc = $reports.publicRpc
$publicRpcStatus = Get-DeploymentStatus -Report $publicRpc
$publicRpcReady = Get-DeploymentProp -Object $publicRpc -Name "publicRpcReady" -Default $false
$publicValidation = $reports.publicRpcValidation
$publicValidationStatus = Get-DeploymentStatus -Report $publicValidation
$publicValidationChecks = Get-DeploymentProp -Object $publicValidation -Name "checks"
$publicValidationPassed = ($publicValidationStatus -eq "passed") `
    -and ((Get-DeploymentProp -Object $publicValidationChecks -Name "allowedOriginAccepted" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicValidationChecks -Name "disallowedOriginRejected" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicValidationChecks -Name "rateLimitProbePerformed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicValidationChecks -Name "rateLimitRejected" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicValidationChecks -Name "rateLimitRetryAfterHeaderPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicValidationChecks -Name "responseHygienePassed" -Default $false) -eq $true)
Add-DeploymentItem -Items $items -Id "public-rpc-edge" `
    -Requirement "The owner TLS edge must pass endpoint, CORS, rate-limit, readiness, and response-hygiene checks before sharing." `
    -Status $(if (($publicRpcStatus -eq "passed") -and ($publicRpcReady -eq $true) -and ($publicValidationPassed -eq $true)) { "passed" } elseif (($publicRpcStatus -eq "blocked") -and ($publicValidationPassed -eq $true)) { "blocked" } else { "failed" }) `
    -Evidence "publicRpcStatus=$publicRpcStatus, publicRpcReady=$publicRpcReady, validationStatus=$publicValidationStatus, validationPassed=$publicValidationPassed" `
    -Commands @("npm run flowchain:public-rpc:validate", "npm run flowchain:public-rpc:check") `
    -Blockers @("FLOWCHAIN_RPC_PUBLIC_URL", "FLOWCHAIN_RPC_ALLOWED_ORIGINS", "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE", "FLOWCHAIN_RPC_TLS_TERMINATED")

$backup = $reports.backup
$backupStatus = Get-DeploymentStatus -Report $backup
$backupDetails = Get-DeploymentProp -Object $backup -Name "backup"
$backupSnapshotProof = Get-DeploymentProp -Object $backupDetails -Name "snapshotProofStatus" -Default "not-run"
$backupRestoreProof = Get-DeploymentProp -Object $backupDetails -Name "restoreProofStatus" -Default "not-run"
$backupRestoreValidation = $reports.backupRestoreValidation
$backupRestoreValidationStatus = Get-DeploymentStatus -Report $backupRestoreValidation
$backupRestoreValidationChecks = Get-DeploymentProp -Object $backupRestoreValidation -Name "checks"
$backupRestoreHashRoundTrip = Get-DeploymentProp -Object $backupRestoreValidationChecks -Name "backupRestoreHashRoundTrip" -Default $false
$backupRestoreCorruptionDetected = Get-DeploymentProp -Object $backupRestoreValidationChecks -Name "corruptedSnapshotDetected" -Default $false
$backupRestoreValidationPassed = $backupRestoreValidationStatus -eq "passed" `
    -and ((Get-DeploymentProp -Object $backupRestoreValidationChecks -Name "backupCommandPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupRestoreValidationChecks -Name "restoreCommandPassed" -Default $false) -eq $true) `
    -and ($backupRestoreHashRoundTrip -eq $true) `
    -and ($backupRestoreCorruptionDetected -eq $true) `
    -and ((Get-DeploymentProp -Object $backupRestoreValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $backupRestoreValidation -Name "noSecrets" -Default $false) -eq $true)
Add-DeploymentItem -Items $items -Id "state-backup-restore-validation" `
    -Requirement "Backup tooling must create a manifest-backed state snapshot, verify a restore rehearsal, and detect corrupted snapshots without owner secrets." `
    -Status $(if ($backupRestoreValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "validationStatus=$backupRestoreValidationStatus, hashRoundTrip=$backupRestoreHashRoundTrip, corruptionDetected=$backupRestoreCorruptionDetected" `
    -Commands @("npm run flowchain:backup:restore:validate")

Add-DeploymentItem -Items $items -Id "state-backup" `
    -Requirement "The public deployment must prove the configured state backup directory can create a manifest-backed snapshot and restore it in rehearsal." `
    -Status $(if ($backupStatus -eq "passed" -and $backupRestoreValidationPassed) { "passed" } elseif ($backupStatus -eq "blocked" -and $backupRestoreValidationPassed) { "blocked" } else { "failed" }) `
    -Evidence "backupStatus=$backupStatus, snapshotProof=$backupSnapshotProof, restoreProof=$backupRestoreProof" `
    -Commands @("npm run flowchain:backup:create", "npm run flowchain:backup:restore:verify", "npm run flowchain:backup:check") `
    -Blockers @("FLOWCHAIN_RPC_STATE_BACKUP_PATH")

$bridgeLiveStatus = Get-DeploymentStatus -Report $reports.bridgeLive
$bridgeInfraStatus = Get-DeploymentStatus -Report $reports.bridgeInfra
Add-DeploymentItem -Items $items -Id "base8453-bridge-edge" `
    -Requirement "The public deployment must not invite bridge-funded testing until Base 8453 live and infra checks pass with owner guardrails." `
    -Status $(if (($bridgeLiveStatus -eq "passed") -and ($bridgeInfraStatus -eq "passed")) { "passed" } elseif (($bridgeLiveStatus -eq "blocked") -or ($bridgeInfraStatus -eq "blocked")) { "blocked" } else { "failed" }) `
    -Evidence "bridgeLive=$bridgeLiveStatus, bridgeInfra=$bridgeInfraStatus" `
    -Commands @("npm run flowchain:bridge:live:check", "npm run flowchain:bridge:infra:check") `
    -Blockers @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_BASE8453_ASSET_DECIMALS", "FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_BASE8453_TO_BLOCK", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS")

$externalTester = $reports.externalTester
$externalPacket = $reports.externalTesterPacket
$externalTesterStatus = Get-DeploymentStatus -Report $externalTester
$externalPacketStatus = Get-DeploymentStatus -Report $externalPacket
$externalSharingReady = Get-DeploymentProp -Object $externalTester -Name "externalSharingReady" -Default $false
$externalTesterChecks = Get-DeploymentProp -Object $externalTester -Name "checks"
$externalTesterNetworkFresh = Get-DeploymentProp -Object $externalTesterChecks -Name "testerWalletNetworkFresh" -Default $false
$localTesterRehearsalReady = Get-DeploymentProp -Object $externalTester -Name "localTesterRehearsalReady" -Default $false
$packetShareable = Get-DeploymentProp -Object $externalPacket -Name "packetShareable" -Default $false
Add-DeploymentItem -Items $items -Id "external-tester-sharing" `
    -Requirement "External tester packet must remain not-shareable until owner public RPC, backup, and bridge gates pass, and it must rely on fresh tester-wallet evidence." `
    -Status $(if (($externalTesterStatus -eq "passed") -and ($externalPacketStatus -eq "passed") -and ($externalSharingReady -eq $true) -and ($packetShareable -eq $true) -and ($externalTesterNetworkFresh -eq $true)) { "passed" } elseif (($externalTesterStatus -eq "blocked") -and ($externalPacketStatus -eq "blocked") -and ($externalSharingReady -eq $false) -and ($packetShareable -eq $false) -and ($externalTesterNetworkFresh -eq $true)) { "blocked" } else { "failed" }) `
    -Evidence "externalTester=$externalTesterStatus, localTesterRehearsalReady=$localTesterRehearsalReady, testerNetworkFresh=$externalTesterNetworkFresh, externalSharingReady=$externalSharingReady, packet=$externalPacketStatus, packetShareable=$packetShareable" `
    -Commands @("npm run flowchain:tester:readiness", "npm run flowchain:external-tester:packet") `
    -Blockers @($knownOwnerInputs)

$requiredRollbackScripts = @(
    "flowchain:service:status",
    "flowchain:ops:snapshot",
    "flowchain:service:stop",
    "flowchain:service:restart",
    "flowchain:emergency:stop-local",
    "flowchain:completion:audit",
    "flowchain:public-deployment:contract"
)
$missingRollbackScripts = @($requiredRollbackScripts | Where-Object { -not (Test-DeploymentPackageScript -PackageJson $packageJson -Name $_) })
$rollbackReady = ($missingRollbackScripts.Count -eq 0) `
    -and (Test-Path -LiteralPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-service-stop.ps1")) `
    -and (Test-Path -LiteralPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-emergency-stop-local.ps1"))
Add-DeploymentItem -Items $items -Id "rollback-controls" `
    -Requirement "Owner deployment has explicit status, stop, restart, emergency stop, and re-audit commands before exposure." `
    -Status $(if ($rollbackReady) { "passed" } else { "failed" }) `
    -Evidence "missingRollbackScripts=$($missingRollbackScripts.Count)" `
    -Commands @($requiredRollbackScripts | ForEach-Object { "npm run $_" })

$noSecret = $reports.noSecret
$noSecretStatus = Get-DeploymentStatus -Report $noSecret
Add-DeploymentItem -Items $items -Id "no-secret-no-broadcast" `
    -Requirement "Deployment contract and current readiness reports preserve no-secret, no-env-value, and no-live-broadcast boundaries." `
    -Status $(if ($noSecretStatus -eq "passed") { "passed" } else { "failed" }) `
    -Evidence "noSecretStatus=$noSecretStatus" `
    -Commands @("npm run flowchain:no-secret:scan")

$failedItems = @($items | Where-Object { $_.status -eq "failed" })
$blockedItems = @($items | Where-Object { $_.status -eq "blocked" })
$blockedItemsWithoutBlockers = @($blockedItems | Where-Object { @($_.blockers).Count -eq 0 })
$blockedItemsWithUnknownBlockers = @($blockedItems | Where-Object {
    $itemBlockers = @($_.blockers)
    @($itemBlockers | Where-Object { $_ -notin $knownOwnerInputs }).Count -gt 0
})
$blockedOnlyOnKnownOwnerInputs = ($failedItems.Count -eq 0) `
    -and ($blockedItemsWithoutBlockers.Count -eq 0) `
    -and ($blockedItemsWithUnknownBlockers.Count -eq 0) `
    -and ($unknownMissingEnvNames.Count -eq 0)
$status = if ($failedItems.Count -gt 0) { "failed" } elseif ($blockedItems.Count -gt 0) { "blocked" } else { "passed" }

$operatorCommands = [ordered]@{
    preExposure = @(
        "npm run flowchain:service:status",
        "npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30",
        "npm run flowchain:ops:snapshot -- -AllowBlocked",
        "npm run flowchain:owner:onboarding",
        "npm run flowchain:owner-env:template",
        "npm run flowchain:owner-inputs",
        "npm run flowchain:public-rpc:edge-template",
        "npm run flowchain:public-rpc:validate",
        "npm run flowchain:public-rpc:check",
        "npm run flowchain:backup:restore:validate",
        "npm run flowchain:backup:create",
        "npm run flowchain:backup:restore:verify",
        "npm run flowchain:backup:check",
        "npm run flowchain:bridge:live:check",
        "npm run flowchain:bridge:infra:check",
        "npm run flowchain:tester:readiness",
        "npm run flowchain:external-tester:packet",
        "npm run flowchain:completion:audit"
    )
    rollback = @(
        "npm run flowchain:service:status",
        "npm run flowchain:service:stop",
        "npm run flowchain:service:restart -- -LiveProfile",
        "npm run flowchain:emergency:stop-local"
    )
}

$report = [ordered]@{
    schema = "flowchain.public_deployment_contract_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    deploymentReady = $status -eq "passed"
    packetShareable = $packetShareable
    blockedOnlyOnKnownExternalOwnerInputs = $blockedOnlyOnKnownOwnerInputs
    itemCounts = [ordered]@{
        passed = @($items | Where-Object { $_.status -eq "passed" }).Count
        blocked = $blockedItems.Count
        failed = $failedItems.Count
        total = $items.Count
    }
    items = @($items)
    dependencyRefresh = $dependencyRefresh
    missingEnvNames = @($missingEnvNames)
    unknownMissingEnvNames = @($unknownMissingEnvNames)
    knownOwnerInputs = $knownOwnerInputs
    reportPaths = $paths
    operatorCommands = $operatorCommands
    noLiveBroadcast = $true
    envValuesPrinted = $false
    noSecrets = $true
}

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Public Deployment Contract")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Deployment ready: $($report.deploymentReady)")
$markdownLines.Add("Packet shareable: $packetShareable")
$markdownLines.Add("Blocked only on known external owner inputs: $blockedOnlyOnKnownOwnerInputs")
$markdownLines.Add("")
$markdownLines.Add("This file records deployment gates, commands, and env names only. It must not contain owner-provided values.")
$markdownLines.Add("")
$markdownLines.Add("## Gate Checklist")
$markdownLines.Add("")
$markdownLines.Add("| Requirement | Status | Evidence |")
$markdownLines.Add("| --- | --- | --- |")
foreach ($item in $items) {
    $markdownLines.Add("| $($item.requirement.Replace('|','/')) | $($item.status) | $($item.evidence.Replace('|','/')) |")
}
$markdownLines.Add("")
$markdownLines.Add("## Pre-Exposure Commands")
$markdownLines.Add("")
foreach ($command in @($operatorCommands.preExposure)) {
    $markdownLines.Add("- $command")
}
$markdownLines.Add("")
$markdownLines.Add("## Rollback Commands")
$markdownLines.Add("")
foreach ($command in @($operatorCommands.rollback)) {
    $markdownLines.Add("- $command")
}
$markdownLines.Add("")
$markdownLines.Add("## Remaining Owner Inputs")
$markdownLines.Add("")
if ($missingEnvNames.Count -eq 0) {
    $markdownLines.Add("- None")
}
else {
    foreach ($name in @($missingEnvNames)) {
        $markdownLines.Add("- $name")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Deployment Decision")
$markdownLines.Add("")
if ($status -eq "passed") {
    $markdownLines.Add("All public deployment contract gates are passed. External sharing still requires the owner to distribute endpoint values out of band.")
}
elseif ($status -eq "blocked") {
    $markdownLines.Add("Do not expose or share the public endpoint yet. The deployment contract is fail-closed on the listed owner inputs.")
}
else {
    $markdownLines.Add("Do not expose or share the public endpoint. At least one local deployment contract gate failed.")
}

$reportText = $report | ConvertTo-Json -Depth 18
Assert-FlowChainNoSecretText -Text $reportText -Label "public deployment contract report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "public deployment contract markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain public deployment contract status: $status"
Write-Host "Deployment ready: $($report.deploymentReady)"
Write-Host "Packet shareable: $packetShareable"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($missingEnvNames.Count -gt 0) {
    Write-Host "Missing env names: $((@($missingEnvNames)) -join ', ')"
}

if ($status -eq "passed" -or ($status -eq "blocked" -and $AllowBlocked)) {
    exit 0
}
exit 1
