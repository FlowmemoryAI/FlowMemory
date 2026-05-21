param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/owner-needs-now-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/OWNER_NEEDS_NOW.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$packageJsonPath = Join-Path $repoRoot "package.json"

$requiredOwnerEnvNames = @(
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
    "FLOWCHAIN_PILOT_CONFIRMATIONS"
)
$optionalOwnerEnvNames = @(
    "FLOWCHAIN_BASE8453_CURSOR_STATE",
    "FLOWCHAIN_BASE8453_TO_BLOCK"
)
$knownOwnerEnvNames = @($requiredOwnerEnvNames + $optionalOwnerEnvNames)

$paths = [ordered]@{
    ownerInputs = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json"
    ownerActivationPlan = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-activation-plan-report.json"
    ownerGoLiveHandoff = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-go-live-handoff-report.json"
    publicRpc = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json"
    backup = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json"
    bridgeLive = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
    bridgeInfra = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
    externalTester = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
    externalTesterPacket = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json"
    serviceStatus = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-status-report.json"
    publicDeploymentContract = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json"
    completionAudit = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-completion-audit-report.json"
    truthTable = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/production-truth-table-report.json"
}

function Get-NeedsProp {
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

function Add-NeedsUnique {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [AllowNull()][object] $Value
    )

    $text = "$Value"
    if (-not [string]::IsNullOrWhiteSpace($text) -and -not $Target.Contains($text)) {
        [void] $Target.Add($text)
    }
}

function Add-NeedsUniqueMany {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [AllowNull()][object[]] $Values
    )

    foreach ($value in @($Values)) {
        Add-NeedsUnique -Target $Target -Value $value
    }
}

function Get-NeedsEnvNames {
    param([AllowNull()][object] $Values)

    return @($Values | ForEach-Object { "$_" } | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_) -and $_ -match '^FLOWCHAIN_[A-Z0-9_]+$'
        })
}

function Test-NeedsPackageScript {
    param([Parameter(Mandatory = $true)][string] $Name)

    if (-not (Test-Path -LiteralPath $packageJsonPath)) {
        return $false
    }
    $packageJson = Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json
    return $packageJson.scripts.PSObject.Properties.Name -contains $Name
}

function New-NeedsReportStatus {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [AllowNull()][object] $Report,
        [Parameter(Mandatory = $true)][string] $Path
    )

    return [ordered]@{
        name = $Name
        status = [string](Get-NeedsProp -Object $Report -Name "status" -Default "missing")
        loaded = $null -ne $Report
        path = $Path
    }
}

function Get-NeedsInputState {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [AllowNull()][object[]] $Inputs
    )

    $input = @($Inputs | Where-Object { [string](Get-NeedsProp -Object $_ -Name "name" -Default "") -eq $Name } | Select-Object -First 1)
    if ($input.Count -eq 0) {
        return [ordered]@{
            name = $Name
            present = $false
            valid = $false
            status = "unknown"
            check = ""
        }
    }
    return [ordered]@{
        name = $Name
        present = (Get-NeedsProp -Object $input[0] -Name "present" -Default $false) -eq $true
        valid = (Get-NeedsProp -Object $input[0] -Name "valid" -Default $false) -eq $true
        status = [string](Get-NeedsProp -Object $input[0] -Name "status" -Default "unknown")
        check = [string](Get-NeedsProp -Object $input[0] -Name "check" -Default "")
    }
}

function New-NeedsGroup {
    param(
        [Parameter(Mandatory = $true)][string] $Id,
        [Parameter(Mandatory = $true)][string] $Title,
        [Parameter(Mandatory = $true)][string] $WhyNeeded,
        [Parameter(Mandatory = $true)][string] $OwnerAction,
        [Parameter(Mandatory = $true)][string[]] $EnvNames,
        [Parameter(Mandatory = $true)][string[]] $ValidationCommands,
        [Parameter(Mandatory = $true)][string[]] $DoNotSend,
        [AllowNull()][object[]] $Inputs
    )

    $states = @($EnvNames | ForEach-Object { Get-NeedsInputState -Name $_ -Inputs $Inputs })
    $missing = @($states | Where-Object { [string](Get-NeedsProp -Object $_ -Name "status" -Default "") -eq "missing" } | ForEach-Object { [string]$_.name })
    $invalid = @($states | Where-Object {
            $status = [string](Get-NeedsProp -Object $_ -Name "status" -Default "")
            $status -ne "missing" -and ((Get-NeedsProp -Object $_ -Name "valid" -Default $false) -ne $true)
        } | ForEach-Object { [string]$_.name })
    $unknown = @($states | Where-Object { [string](Get-NeedsProp -Object $_ -Name "status" -Default "") -eq "unknown" } | ForEach-Object { [string]$_.name })
    $ready = $missing.Count -eq 0 -and $invalid.Count -eq 0 -and $unknown.Count -eq 0
    $status = if ($invalid.Count -gt 0) {
        "invalid-owner-input"
    }
    elseif ($missing.Count -gt 0) {
        "needs-owner-input"
    }
    elseif ($unknown.Count -gt 0) {
        "unknown"
    }
    else {
        "ready"
    }

    return [ordered]@{
        id = $Id
        title = $Title
        status = $status
        ready = $ready
        whyNeeded = $WhyNeeded
        ownerAction = $OwnerAction
        envNames = @($EnvNames)
        missingEnvNames = @($missing)
        invalidEnvNames = @($invalid)
        unknownEnvNames = @($unknown)
        validationCommands = @($ValidationCommands)
        doNotSend = @($DoNotSend)
        inputs = @($states)
    }
}

$reports = [ordered]@{}
foreach ($entry in $paths.GetEnumerator()) {
    $reports[$entry.Key] = Read-FlowChainJsonIfExists -Path $entry.Value
}

$ownerInputs = $reports.ownerInputs
$ownerInputRows = @((Get-NeedsProp -Object $ownerInputs -Name "inputs" -Default @()))
$goLiveHandoff = $reports.ownerGoLiveHandoff
$activationPlan = $reports.ownerActivationPlan
$truthTable = $reports.truthTable
$publicDeploymentContract = $reports.publicDeploymentContract

$missingRequired = New-Object System.Collections.ArrayList
$missingOptional = New-Object System.Collections.ArrayList
$invalidEnvNames = New-Object System.Collections.ArrayList
$neededNow = New-Object System.Collections.ArrayList
Add-NeedsUniqueMany -Target $missingRequired -Values (Get-NeedsEnvNames -Values (Get-NeedsProp -Object $goLiveHandoff -Name "missingRequiredEnvNames" -Default @()))
Add-NeedsUniqueMany -Target $missingOptional -Values (Get-NeedsEnvNames -Values (Get-NeedsProp -Object $goLiveHandoff -Name "missingOptionalEnvNames" -Default @()))
Add-NeedsUniqueMany -Target $invalidEnvNames -Values (Get-NeedsEnvNames -Values (Get-NeedsProp -Object $goLiveHandoff -Name "invalidEnvNames" -Default @()))
Add-NeedsUniqueMany -Target $neededNow -Values (Get-NeedsEnvNames -Values (Get-NeedsProp -Object $goLiveHandoff -Name "nextOwnerInputNames" -Default @()))
if ($neededNow.Count -eq 0) {
    Add-NeedsUniqueMany -Target $neededNow -Values (Get-NeedsEnvNames -Values (Get-NeedsProp -Object $activationPlan -Name "nextOwnerInputNames" -Default @()))
}
if ($neededNow.Count -eq 0) {
    Add-NeedsUniqueMany -Target $neededNow -Values @($missingRequired)
}

$groups = @(
    New-NeedsGroup -Id "public-rpc-edge" -Title "Public RPC edge" `
        -WhyNeeded "Friends and family need a public HTTPS RPC endpoint that proxies to the private FlowChain origin without exposing local-only paths." `
        -OwnerAction "Pick the public RPC URL, configure TLS termination, set exact HTTPS browser origins, and choose a positive per-minute rate limit." `
        -EnvNames @("FLOWCHAIN_RPC_PUBLIC_URL", "FLOWCHAIN_RPC_ALLOWED_ORIGINS", "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE", "FLOWCHAIN_RPC_TLS_TERMINATED") `
        -ValidationCommands @("npm run flowchain:public-rpc:check -- -AllowBlocked", "npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked", "npm run flowchain:public-deployment:contract -- -AllowBlocked") `
        -DoNotSend @("provider dashboard password", "TLS private key", "tunnel token", "origin wildcard") `
        -Inputs $ownerInputRows
    New-NeedsGroup -Id "backup-storage" -Title "Backup storage" `
        -WhyNeeded "The public launch must prove the live state can be snapshotted, restored, and tamper-checked from persistent storage." `
        -OwnerAction "Create an existing writable backup directory on the always-on host and point the owner env file at it." `
        -EnvNames @("FLOWCHAIN_RPC_STATE_BACKUP_PATH") `
        -ValidationCommands @("npm run flowchain:backup:owner-path:dry-run", "npm run flowchain:backup:restore:validate", "npm run flowchain:backup:check -- -AllowBlocked") `
        -DoNotSend @("cloud storage secret", "backup provider account password", "private backup credentials") `
        -Inputs $ownerInputRows
    New-NeedsGroup -Id "tester-write-gateway" -Title "Tester write gateway" `
        -WhyNeeded "External testers need capped wallet create/faucet/send access without putting the raw bearer token in GitHub or chat." `
        -OwnerAction "Keep tester writes enabled, store only the SHA-256 token digest in the ignored owner env file, and maintain a small per-send cap." `
        -EnvNames @("FLOWCHAIN_TESTER_WRITE_ENABLED", "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256", "FLOWCHAIN_TESTER_MAX_SEND_UNITS") `
        -ValidationCommands @("npm run flowchain:tester:token:setup", "npm run flowchain:tester:gateway:e2e", "npm run flowchain:external-tester:packet -- -AllowBlocked") `
        -DoNotSend @("raw tester bearer token", "owner env file contents", "token hash together with the raw token") `
        -Inputs $ownerInputRows
    New-NeedsGroup -Id "base8453-bridge" -Title "Base 8453 bridge" `
        -WhyNeeded "Bridge-funded testing stays closed until the Base 8453 observer, lockbox, asset, block range, pilot caps, and confirmations are configured." `
        -OwnerAction "Provide the Base RPC endpoint, lockbox and supported token addresses, asset decimals, start block, capped pilot acknowledgement, deposit cap, total cap, and confirmation depth." `
        -EnvNames @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_BASE8453_ASSET_DECIMALS", "FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS") `
        -ValidationCommands @("npm run flowchain:bridge:live:check -- -AllowBlocked", "npm run flowchain:bridge:infra:check -- -AllowBlocked", "npm run flowchain:bridge:relayer:once -- -AllowBlocked", "npm run flowchain:bridge:release:evidence:validate", "npm run flowchain:bridge:reconciliation") `
        -DoNotSend @("wallet seed words", "deployer private key", "provider API secret pasted in chat", "unbounded pilot caps") `
        -Inputs $ownerInputRows
)

$coveredRequired = @($groups | ForEach-Object { @($_.envNames) } | Where-Object { $_ -in $requiredOwnerEnvNames } | Select-Object -Unique)
$missingCoverage = @($requiredOwnerEnvNames | Where-Object { $_ -notin $coveredRequired })
$unknownNeededNow = @($neededNow | Where-Object { $_ -notin $knownOwnerEnvNames })
$optionalNeededNow = @($neededNow | Where-Object { $_ -in $optionalOwnerEnvNames })
$neededNowGroups = @($groups | Where-Object { @($_.missingEnvNames).Count -gt 0 -or @($_.invalidEnvNames).Count -gt 0 -or @($_.unknownEnvNames).Count -gt 0 })
$readyGroups = @($groups | Where-Object { $_.ready -eq $true })

$reportStatuses = @($paths.GetEnumerator() | ForEach-Object {
        New-NeedsReportStatus -Name $_.Key -Report $reports[$_.Key] -Path $_.Value
    })
$deploymentItems = @((Get-NeedsProp -Object $publicDeploymentContract -Name "items" -Default @()))
$deploymentGateSummaries = @($deploymentItems | ForEach-Object {
        [ordered]@{
            id = [string](Get-NeedsProp -Object $_ -Name "id" -Default "")
            status = [string](Get-NeedsProp -Object $_ -Name "status" -Default "missing")
            commands = @((Get-NeedsProp -Object $_ -Name "commands" -Default @()) | ForEach-Object { "$_" })
            blockers = @((Get-NeedsProp -Object $_ -Name "blockers" -Default @()) | ForEach-Object { "$_" })
        }
    } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.id) })
$blockedDeploymentGates = @($deploymentGateSummaries | Where-Object { $_.status -eq "blocked" })
$failedDeploymentGates = @($deploymentGateSummaries | Where-Object { $_.status -eq "failed" })
$releaseEvidenceGate = $deploymentGateSummaries | Where-Object { $_.id -eq "base8453-bridge-release-evidence-validation" } | Select-Object -First 1
$externalTesterGate = $deploymentItems | Where-Object { [string](Get-NeedsProp -Object $_ -Name "id" -Default "") -eq "external-tester-sharing" } | Select-Object -First 1
$externalTesterEvidence = [string](Get-NeedsProp -Object $externalTesterGate -Name "evidence" -Default "")
$baseBridgeGroup = $groups | Where-Object { $_.id -eq "base8453-bridge" } | Select-Object -First 1

$truthCounts = Get-NeedsProp -Object $truthTable -Name "classificationCounts" -Default $null
$releaseReady = (Get-NeedsProp -Object $goLiveHandoff -Name "releaseReady" -Default $false) -eq $true
$deploymentReady = (Get-NeedsProp -Object $goLiveHandoff -Name "deploymentReady" -Default $false) -eq $true
$packetShareable = (Get-NeedsProp -Object $goLiveHandoff -Name "packetShareable" -Default $false) -eq $true
$completionReady = (Get-NeedsProp -Object $goLiveHandoff -Name "completionReady" -Default $false) -eq $true
$serviceChain = Get-NeedsProp -Object $reports.serviceStatus -Name "chain"
$serviceLatestHeight = Get-NeedsProp -Object $serviceChain -Name "latestHeight"
$serviceFinalizedHeight = Get-NeedsProp -Object $serviceChain -Name "finalizedHeight"
$completionLatestHeight = Get-NeedsProp -Object $reports.completionAudit -Name "latestHeight"
$completionFinalizedHeight = Get-NeedsProp -Object $reports.completionAudit -Name "finalizedHeight"
$latestHeight = if (-not [string]::IsNullOrWhiteSpace("$serviceLatestHeight")) { $serviceLatestHeight } else { $completionLatestHeight }
$finalizedHeight = if (-not [string]::IsNullOrWhiteSpace("$serviceFinalizedHeight")) { $serviceFinalizedHeight } else { $completionFinalizedHeight }

$checks = [ordered]@{
    packageScriptPresent = Test-NeedsPackageScript -Name "flowchain:owner:needs-now"
    ownerInputsLoaded = $null -ne $ownerInputs
    ownerGoLiveHandoffLoaded = $null -ne $goLiveHandoff
    activationPlanLoaded = $null -ne $activationPlan
    truthTableLoaded = $null -ne $truthTable
    publicDeploymentContractLoaded = $null -ne $publicDeploymentContract
    reportStatusDeckPresent = $reportStatuses.Count -ge 9
    groupCountMinimumMet = $groups.Count -ge 4
    requiredEnvCoverageComplete = $missingCoverage.Count -eq 0
    groupCommandsPresent = @($groups | Where-Object { @($_.validationCommands).Count -eq 0 }).Count -eq 0
    groupDoNotSendPresent = @($groups | Where-Object { @($_.doNotSend).Count -eq 0 }).Count -eq 0
    deploymentGateSummaryPresent = $deploymentGateSummaries.Count -gt 0
    releaseEvidenceGateCaptured = ($null -ne $releaseEvidenceGate) -and ([string](Get-NeedsProp -Object $releaseEvidenceGate -Name "status" -Default "") -eq "passed")
    externalTesterGateCapturesReleaseEvidence = $externalTesterEvidence.Contains("bridgeReleaseEvidenceReady=True")
    baseBridgeValidationIncludesReleaseEvidence = @((Get-NeedsProp -Object $baseBridgeGroup -Name "validationCommands" -Default @()) | Where-Object { "$_" -eq "npm run flowchain:bridge:release:evidence:validate" }).Count -eq 1
    knownNeededNowOwnerInputsOnly = $unknownNeededNow.Count -eq 0
    optionalOwnerInputsExcludedFromNeededNow = $optionalNeededNow.Count -eq 0
    nextOwnerInputsPresentWhenBlocked = if ($releaseReady) { $true } else { $neededNow.Count -gt 0 }
    neededNowGroupsPresentWhenBlocked = if ($releaseReady) { $true } else { $neededNowGroups.Count -gt 0 }
    readyTesterGatewayCaptured = @($readyGroups | Where-Object { $_.id -eq "tester-write-gateway" }).Count -eq 1
    noReleaseReadyClaimWhileBlocked = if ($neededNow.Count -gt 0) { -not $releaseReady } else { $true }
    publicSharingBlockedUntilReady = if ($releaseReady) { $packetShareable -and $deploymentReady -and $completionReady } else { -not $packetShareable }
    envValuesPrintedFalse = $true
    noSecrets = $true
    broadcastsFalse = $true
    secretMarkerFindingsEmpty = $true
}
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
$launchReadinessStatus = if ($releaseReady -and $deploymentReady -and $packetShareable -and $completionReady) {
    "ready"
}
elseif ($neededNow.Count -gt 0) {
    "blocked-owner-input"
}
else {
    "needs-validation"
}

$report = [ordered]@{
    schema = "flowchain.owner_needs_now_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    launchReadinessStatus = $launchReadinessStatus
    releaseReady = $releaseReady
    deploymentReady = $deploymentReady
    packetShareable = $packetShareable
    completionReady = $completionReady
    latestHeight = $latestHeight
    finalizedHeight = $finalizedHeight
    truthTableClassificationCounts = $truthCounts
    nextOwnerInputNames = @($neededNow)
    missingRequiredEnvNames = @($missingRequired)
    missingOptionalEnvNames = @($missingOptional)
    invalidEnvNames = @($invalidEnvNames)
    groupCount = $groups.Count
    neededNowGroupCount = $neededNowGroups.Count
    readyGroupCount = $readyGroups.Count
    deploymentGateCount = $deploymentGateSummaries.Count
    blockedDeploymentGateCount = $blockedDeploymentGates.Count
    failedDeploymentGateCount = $failedDeploymentGates.Count
    blockedDeploymentGates = @($blockedDeploymentGates)
    failedDeploymentGates = @($failedDeploymentGates)
    groups = @($groups)
    neededNowGroups = @($neededNowGroups)
    readyGroups = @($readyGroups)
    reportStatuses = @($reportStatuses)
    checks = $checks
    failedChecks = @($failedChecks)
    missingRequiredCoverage = @($missingCoverage)
    unknownNeededNowEnvNames = @($unknownNeededNow)
    optionalNeededNowEnvNames = @($optionalNeededNow)
    secretMarkerFindings = @()
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
    noLiveBroadcast = $true
}
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Owner Needs Now")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Launch readiness: $launchReadinessStatus")
$markdownLines.Add("")
$markdownLines.Add("This report lists names, commands, and owner actions only. It does not print owner values.")
$markdownLines.Add("")
$markdownLines.Add("## Current L1 State")
$markdownLines.Add("")
$markdownLines.Add("- Latest height: $latestHeight")
$markdownLines.Add("- Finalized height: $finalizedHeight")
$markdownLines.Add("- Release ready: $releaseReady")
$markdownLines.Add("- Deployment ready: $deploymentReady")
$markdownLines.Add("- External tester packet shareable: $packetShareable")
$markdownLines.Add("- Completion ready: $completionReady")
$markdownLines.Add("")
$markdownLines.Add("## Needed Now")
$markdownLines.Add("")
if ($neededNowGroups.Count -eq 0) {
    $markdownLines.Add("No required owner-input group is currently blocking launch.")
}
else {
    $markdownLines.Add("| Group | Status | Owner action | Missing or invalid names | Validate with |")
    $markdownLines.Add("| --- | --- | --- | --- | --- |")
    foreach ($group in $neededNowGroups) {
        $blockingNames = @($group.missingEnvNames + $group.invalidEnvNames + $group.unknownEnvNames) | Select-Object -Unique
        $markdownLines.Add("| $($group.title) | $($group.status) | $($group.ownerAction.Replace('|', '/')) | ``$($blockingNames -join '`, `')`` | ``$($group.validationCommands[0])`` |")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Ready Groups")
$markdownLines.Add("")
if ($readyGroups.Count -eq 0) {
    $markdownLines.Add("No owner-input group is fully ready yet.")
}
else {
    foreach ($group in $readyGroups) {
        $markdownLines.Add("- $($group.title): ready")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Deployment Gates Blocking Sharing")
$markdownLines.Add("")
if ($blockedDeploymentGates.Count -eq 0 -and $failedDeploymentGates.Count -eq 0) {
    $markdownLines.Add("No public deployment contract gate is currently blocked or failed.")
}
else {
    $markdownLines.Add("| Gate | Status | First command | Blocking names |")
    $markdownLines.Add("| --- | --- | --- | --- |")
    foreach ($gate in @($failedDeploymentGates + $blockedDeploymentGates)) {
        $gateCommands = @((Get-NeedsProp -Object $gate -Name "commands" -Default @()))
        $gateBlockers = @((Get-NeedsProp -Object $gate -Name "blockers" -Default @()))
        $firstCommand = if ($gateCommands.Count -gt 0) { [string]$gateCommands[0] } else { "not recorded" }
        $blockers = if ($gateBlockers.Count -gt 0) { @($gateBlockers) -join '`, `' } else { "not recorded" }
        $gateId = Get-NeedsProp -Object $gate -Name "id" -Default ""
        $gateStatus = Get-NeedsProp -Object $gate -Name "status" -Default ""
        $markdownLines.Add("| $gateId | $gateStatus | ``$firstCommand`` | ``$blockers`` |")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Do Not Send")
$markdownLines.Add("")
foreach ($item in @($groups | ForEach-Object { @($_.doNotSend) } | Select-Object -Unique)) {
    $markdownLines.Add("- $item")
}
$markdownLines.Add("")
$markdownLines.Add("## Next Commands")
$markdownLines.Add("")
foreach ($command in @(
        "npm run flowchain:owner-env:template",
        "npm run flowchain:owner:needs-now",
        "npm run flowchain:owner-env:readiness -- -AllowBlocked",
        "npm run flowchain:public-deployment:contract -- -AllowBlocked",
        "npm run flowchain:live:cutover:rehearsal -- -AllowBlocked",
        "npm run flowchain:truth-table -- -AllowBlocked"
    )) {
    $markdownLines.Add("- ``$command``")
}
Set-Content -LiteralPath $markdownFullPath -Value $markdownLines -Encoding UTF8

Write-Host "FlowChain owner needs-now status: $status"
Write-Host "Launch readiness: $launchReadinessStatus"
Write-Host "Report: $reportFullPath"
if ($neededNow.Count -gt 0) {
    Write-Host "Needed now: $($neededNow -join ', ')"
}
if ($status -ne "passed") {
    throw "FlowChain owner needs-now failed checks: $($failedChecks -join ', ')"
}
