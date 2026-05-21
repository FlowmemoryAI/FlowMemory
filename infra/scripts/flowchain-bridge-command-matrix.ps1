param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-command-matrix-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/BRIDGE_COMMAND_MATRIX.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$package = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "package.json") | ConvertFrom-Json
$scripts = $package.scripts

function Get-MatrixScriptCommand {
    param([Parameter(Mandatory = $true)][string] $Name)

    if ($scripts.PSObject.Properties.Name -contains $Name) {
        return [string] $scripts.$Name
    }
    return ""
}

function Get-RepoRelativeScriptPath {
    param([Parameter(Mandatory = $true)][string] $Command)

    foreach ($part in @($Command -split '\s+')) {
        $candidate = $part.Trim("`"", "'", ",")
        if ($candidate -match '^(infra[\\/]+scripts[\\/]+.+\.ps1|services[\\/]+bridge-relayer[\\/]+src[\\/]+.+\.(ts|js))$') {
            return $candidate -replace "\\", "/"
        }
    }
    return ""
}

function Read-MatrixScriptText {
    param([string] $RelativePath)

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        return ""
    }
    $fullPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path $RelativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        return ""
    }
    return Get-Content -Raw -LiteralPath $fullPath
}

function Test-AnyTextContains {
    param(
        [string] $Text,
        [string[]] $Needles
    )

    foreach ($needle in @($Needles)) {
        if (-not [string]::IsNullOrWhiteSpace($needle) -and $Text.Contains($needle)) {
            return $true
        }
    }
    return $false
}

function Test-AllTextContains {
    param(
        [string] $Text,
        [string[]] $Needles
    )

    foreach ($needle in @($Needles)) {
        if ([string]::IsNullOrWhiteSpace($needle)) {
            continue
        }
        if (-not $Text.Contains($needle)) {
            return $false
        }
    }
    return $true
}

$requiredOwnerEnvNamePattern = '^FLOWCHAIN_[A-Z0-9_]+$'
$commandDefinitions = @(
    [ordered]@{
        script = "flowchain:bridge:live:check"
        phase = "preflight"
        purpose = "Fail-closed bridge live readiness check before owner-funded pilot work."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
        riskClass = "read-only-owner-input-gate"
        requiredEnvNames = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_BASE8453_ASSET_DECIMALS", "FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS")
        optionalEnvNames = @("FLOWCHAIN_BASE8453_TO_BLOCK")
        requiredAckEnvNames = @("FLOWCHAIN_PILOT_OPERATOR_ACK")
        mustContain = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL")
        liveBroadcastCapable = $false
    },
    [ordered]@{
        script = "flowchain:bridge:infra:check"
        phase = "preflight"
        purpose = "Fail-closed bridge infrastructure check covering owner inputs and local bridge state."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
        riskClass = "read-only-owner-input-gate"
        requiredEnvNames = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_BASE8453_ASSET_DECIMALS", "FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS")
        optionalEnvNames = @("FLOWCHAIN_BASE8453_TO_BLOCK")
        requiredAckEnvNames = @("FLOWCHAIN_PILOT_OPERATOR_ACK")
        mustContain = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS")
        liveBroadcastCapable = $false
    },
    [ordered]@{
        script = "flowchain:bridge:deploy:base8453"
        phase = "deploy-control"
        purpose = "Dry-run or explicitly broadcast the owner-approved Base 8453 lockbox deployment."
        expectedReportPath = "devnet/local/bridge-live-readiness/base8453-deploy-readiness.json"
        riskClass = "owner-live-broadcast-gated"
        requiredEnvNames = @("FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_OPERATOR_ACK")
        optionalEnvNames = @("FLOWCHAIN_BASE8453_OWNER_ADDRESS", "FLOWCHAIN_BASE8453_RELEASE_AUTHORITY_ADDRESS", "FLOWCHAIN_BASE8453_SETTLEMENT_SUBMITTER_ADDRESS")
        requiredAckEnvNames = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_BROADCAST_ACK")
        mustContain = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_BROADCAST_ACK", "AcknowledgeBroadcast", "forge script")
        liveBroadcastCapable = $true
    },
    [ordered]@{
        script = "flowchain:bridge:deploy:control:validate"
        phase = "deploy-control"
        purpose = "Validate deploy, pause, resume, and emergency-stop fail-closed behavior without broadcasting."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-deploy-control-validation-report.json"
        riskClass = "local-validation-no-broadcast"
        requiredEnvNames = @()
        optionalEnvNames = @()
        requiredAckEnvNames = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_BROADCAST_ACK")
        mustContain = @("FLOWCHAIN_BASE8453_BROADCAST_ACK", "AcknowledgeBroadcast", "EmergencyStop")
        liveBroadcastCapable = $false
    },
    [ordered]@{
        script = "flowchain:bridge:observe:base8453"
        phase = "observe"
        purpose = "Observe owner-approved Base 8453 lockbox deposits and stage cursor movement before local crediting."
        expectedReportPath = "devnet/local/bridge-live-readiness/bridge-observe-base8453-report.json"
        riskClass = "read-only-owner-input-gate"
        requiredEnvNames = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_BASE8453_ASSET_DECIMALS", "FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS")
        optionalEnvNames = @("FLOWCHAIN_BASE8453_TO_BLOCK", "FLOWCHAIN_BASE8453_CURSOR_STATE")
        requiredAckEnvNames = @("FLOWCHAIN_PILOT_OPERATOR_ACK")
        mustContain = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "directObserveUsesStagedCursorByDefault", "UseOwnerFinalCursor", "Broadcast: false")
        liveBroadcastCapable = $false
    },
    [ordered]@{
        script = "flowchain:bridge:relayer:once"
        phase = "observe"
        purpose = "Run the production-shaped relayer once, with staged cursor and no final commit while owner inputs are missing."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-relayer-once-report.json"
        riskClass = "local-l1-credit-gated"
        requiredEnvNames = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_BASE8453_ASSET_DECIMALS", "FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS")
        optionalEnvNames = @("FLOWCHAIN_BASE8453_CURSOR_STATE", "FLOWCHAIN_BASE8453_TO_BLOCK")
        requiredAckEnvNames = @("FLOWCHAIN_PILOT_OPERATOR_ACK")
        mustContain = @("staged-cursor", "FLOWCHAIN_PILOT_OPERATOR_ACK", "finalCommitted")
        liveBroadcastCapable = $false
    },
    [ordered]@{
        script = "flowchain:bridge:relayer:guardrail:validate"
        phase = "observe"
        purpose = "Prove missing owner inputs cannot mutate the final cursor or queue credits."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-relayer-guardrail-validation-report.json"
        riskClass = "local-validation-no-broadcast"
        requiredEnvNames = @()
        optionalEnvNames = @()
        requiredAckEnvNames = @("FLOWCHAIN_PILOT_OPERATOR_ACK")
        mustContain = @("finalCursorUnchanged", "directObserveUsesStagedCursorByDefault", "FLOWCHAIN_PILOT_OPERATOR_ACK")
        liveBroadcastCapable = $false
    },
    [ordered]@{
        script = "flowchain:bridge:relayer:loop:validate"
        phase = "observe"
        purpose = "Validate relayer loop start/status/stop, PID cleanup, and recovery behavior."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-relayer-loop-validation-report.json"
        riskClass = "local-validation-no-broadcast"
        requiredEnvNames = @()
        optionalEnvNames = @()
        requiredAckEnvNames = @()
        mustContain = @("relayerPidFileRemovedAfterStop", "noValidationRelayerProcessAfterStop", "statusRelayerReportHealthy")
        liveBroadcastCapable = $false
    },
    [ordered]@{
        script = "flowchain:bridge:runtime-credit:validate"
        phase = "credit"
        purpose = "Validate Base 8453 handoff credits become spendable, transferable, replay-safe, and restart-safe."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-runtime-credit-validation-report.json"
        riskClass = "local-validation-no-broadcast"
        requiredEnvNames = @()
        optionalEnvNames = @()
        requiredAckEnvNames = @()
        mustContain = @("creditedBalanceTransferable", "replayRejected", "queueToSpendableSeconds")
        liveBroadcastCapable = $false
    },
    [ordered]@{
        script = "flowchain:real-value-pilot:e2e"
        phase = "pilot-proof"
        purpose = "Aggregate bounded pilot proof across contracts, bridge, runtime, wallet, dashboard, and ops."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/real-value-pilot-aggregate-report.json"
        riskClass = "local-validation-no-broadcast"
        requiredEnvNames = @()
        optionalEnvNames = @()
        requiredAckEnvNames = @()
        mustContain = @("knownOwnerInputs", "broadcastsFalse")
        liveBroadcastCapable = $false
    },
    [ordered]@{
        script = "flowchain:bridge:reconciliation"
        phase = "credit"
        purpose = "Reconcile live relayer counts, cursor safety, runtime credit proof, replay rejection, and release evidence."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-reconciliation-report.json"
        riskClass = "local-validation-no-broadcast"
        requiredEnvNames = @()
        optionalEnvNames = @()
        requiredAckEnvNames = @()
        mustContain = @("cursorFinalNotCommittedWhenBlocked", "runtimeCreditAppliedOnce", "localPilotDuplicateReplayRejected", "releaseEvidenceValidationPassed")
        liveBroadcastCapable = $false
    },
    [ordered]@{
        script = "flowchain:bridge:withdraw:intent"
        phase = "withdraw-release"
        purpose = "Write local withdrawal intent evidence from a credited bridge pilot handoff."
        expectedReportPath = "devnet/local/bridge-live-readiness/bridge-withdraw-intent-report.json"
        riskClass = "local-evidence-no-broadcast"
        requiredEnvNames = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS")
        optionalEnvNames = @("FLOWCHAIN_BASE8453_TO_BLOCK")
        requiredAckEnvNames = @("FLOWCHAIN_PILOT_OPERATOR_ACK")
        mustContain = @("WithdrawalIntent", "FLOWCHAIN_PILOT_OPERATOR_ACK", "broadcasts = `$false")
        liveBroadcastCapable = $false
    },
    [ordered]@{
        script = "flowchain:bridge:release:evidence"
        phase = "withdraw-release"
        purpose = "Write release evidence for the pilot without broadcasting owner release transactions."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-release-evidence-report.json"
        riskClass = "local-evidence-no-broadcast"
        requiredEnvNames = @()
        optionalEnvNames = @()
        requiredAckEnvNames = @()
        mustContain = @("release", "evidence", "broadcasts")
        liveBroadcastCapable = $false
    },
    [ordered]@{
        script = "flowchain:bridge:release:evidence:validate"
        phase = "withdraw-release"
        purpose = "Validate withdrawal and release evidence matching, mismatch rejection, and no-broadcast boundaries."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-release-evidence-validation-report.json"
        riskClass = "local-validation-no-broadcast"
        requiredEnvNames = @()
        optionalEnvNames = @()
        requiredAckEnvNames = @()
        mustContain = @("releaseBroadcastRejected", "withdrawalBroadcastRejected", "caseCount")
        liveBroadcastCapable = $false
    },
    [ordered]@{
        script = "flowchain:bridge:pause"
        phase = "emergency-control"
        purpose = "Dry-run or explicitly execute Base lockbox pause."
        expectedReportPath = "devnet/local/bridge-live-readiness/base8453-control-report.json"
        riskClass = "owner-live-broadcast-gated"
        requiredEnvNames = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS")
        optionalEnvNames = @()
        requiredAckEnvNames = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_BROADCAST_ACK")
        mustContain = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_BROADCAST_ACK", "Execute", "cast send")
        liveBroadcastCapable = $true
    },
    [ordered]@{
        script = "flowchain:bridge:resume"
        phase = "emergency-control"
        purpose = "Dry-run or explicitly execute Base lockbox resume."
        expectedReportPath = "devnet/local/bridge-live-readiness/base8453-control-report.json"
        riskClass = "owner-live-broadcast-gated"
        requiredEnvNames = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS")
        optionalEnvNames = @()
        requiredAckEnvNames = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_BROADCAST_ACK")
        mustContain = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_BROADCAST_ACK", "Execute", "cast send")
        liveBroadcastCapable = $true
    },
    [ordered]@{
        script = "flowchain:bridge:emergency-stop"
        phase = "emergency-control"
        purpose = "Dry-run or explicitly execute Base lockbox emergency stop."
        expectedReportPath = "devnet/local/bridge-live-readiness/base8453-control-report.json"
        riskClass = "owner-live-broadcast-gated"
        requiredEnvNames = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS")
        optionalEnvNames = @()
        requiredAckEnvNames = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_BROADCAST_ACK")
        mustContain = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_BROADCAST_ACK", "EmergencyStop", "cast send")
        liveBroadcastCapable = $true
    },
    [ordered]@{
        script = "flowchain:bridge:local-credit:smoke"
        phase = "local-smoke"
        purpose = "Run local bridge credit smoke path without live Base or owner funds."
        expectedReportPath = ""
        riskClass = "local-validation-no-broadcast"
        requiredEnvNames = @()
        optionalEnvNames = @()
        requiredAckEnvNames = @()
        mustContain = @("local-credit")
        liveBroadcastCapable = $false
    },
    [ordered]@{
        script = "flowchain:bridge:command-matrix"
        phase = "release"
        purpose = "Regenerate this bridge command, risk, ack, and report-path matrix."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-command-matrix-report.json"
        riskClass = "local-validation-no-broadcast"
        requiredEnvNames = @()
        optionalEnvNames = @()
        requiredAckEnvNames = @()
        mustContain = @("bridge_command_matrix_report", "liveBroadcastCapable", "requiredAckEnvNames")
        liveBroadcastCapable = $false
    },
    [ordered]@{
        script = "flowchain:bridge:no-secret-audit"
        phase = "release"
        purpose = "Scan generated bridge readiness evidence for secret-shaped material."
        expectedReportPath = "devnet/local/bridge-live-readiness/bridge-no-secret-audit-report.json"
        riskClass = "local-validation-no-broadcast"
        requiredEnvNames = @()
        optionalEnvNames = @()
        requiredAckEnvNames = @()
        mustContain = @("bridge_no_secret_audit_report", "credentialed_rpc_url", "private_key")
        liveBroadcastCapable = $false
    }
)

$rows = foreach ($definition in $commandDefinitions) {
    $name = [string] $definition.script
    $command = Get-MatrixScriptCommand -Name $name
    $exists = -not [string]::IsNullOrWhiteSpace($command)
    $relativeScriptPath = Get-RepoRelativeScriptPath -Command $command
    $scriptText = Read-MatrixScriptText -RelativePath $relativeScriptPath
    $combinedText = "$command`n$scriptText"
    $requiredEnvNames = @($definition.requiredEnvNames)
    $optionalEnvNames = @($definition.optionalEnvNames)
    $requiredAckEnvNames = @($definition.requiredAckEnvNames)
    $mustContain = @($definition.mustContain)
    $requiredEnvReferencesPresent = if ($requiredEnvNames.Count -eq 0) { $true } else { Test-AllTextContains -Text $combinedText -Needles $requiredEnvNames }
    $requiredAcksPresent = if ($requiredAckEnvNames.Count -eq 0) { $true } else { Test-AllTextContains -Text $combinedText -Needles $requiredAckEnvNames }
    $mustContainPresent = if ($mustContain.Count -eq 0) { $true } else { Test-AllTextContains -Text $combinedText -Needles $mustContain }
    $commandAvoidsInlineEnvAssignment = $command -notmatch 'FLOWCHAIN_[A-Z0-9_]+\s*='
    $commandAvoidsUrls = $command -notmatch 'https?://'
    $commandAvoidsKeyMaterial = $command -notmatch '(?i)(private[-_ ]?key\s*[=:]|secret\s*[=:]|token\s*[=:]|0x[0-9a-f]{64})'
    $ownerInputNamesOnly = @(($requiredEnvNames + $optionalEnvNames + $requiredAckEnvNames) | Where-Object { "$_" -notmatch $requiredOwnerEnvNamePattern }).Count -eq 0
    [ordered]@{
        script = $name
        phase = [string] $definition.phase
        purpose = [string] $definition.purpose
        exists = $exists
        packageCommand = $command
        scriptPath = $relativeScriptPath
        scriptTextAvailable = -not [string]::IsNullOrWhiteSpace($scriptText)
        riskClass = [string] $definition.riskClass
        liveBroadcastCapable = [bool] $definition.liveBroadcastCapable
        requiredEnvNames = $requiredEnvNames
        optionalEnvNames = $optionalEnvNames
        requiredAckEnvNames = $requiredAckEnvNames
        requiredEnvReferencesPresent = $requiredEnvReferencesPresent
        requiredAcksPresent = $requiredAcksPresent
        requiredValidationSignalsPresent = $mustContainPresent
        expectedReportPath = [string] $definition.expectedReportPath
        committedEvidencePath = ([string] $definition.expectedReportPath).StartsWith("docs/agent-runs/live-product-infra-rpc/")
        commandAvoidsInlineEnvAssignment = $commandAvoidsInlineEnvAssignment
        commandAvoidsUrls = $commandAvoidsUrls
        commandAvoidsKeyMaterial = $commandAvoidsKeyMaterial
        ownerInputNamesOnly = $ownerInputNamesOnly
    }
}

$missingScripts = @($rows | Where-Object { -not $_.exists } | ForEach-Object { $_.script })
$commandsWithInlineEnvAssignment = @($rows | Where-Object { -not $_.commandAvoidsInlineEnvAssignment } | ForEach-Object { $_.script })
$commandsWithUrls = @($rows | Where-Object { -not $_.commandAvoidsUrls } | ForEach-Object { $_.script })
$commandsWithKeyMaterialReference = @($rows | Where-Object { -not $_.commandAvoidsKeyMaterial } | ForEach-Object { $_.script })
$rowsMissingEnvReferences = @($rows | Where-Object { -not $_.requiredEnvReferencesPresent } | ForEach-Object { $_.script })
$rowsMissingAckReferences = @($rows | Where-Object { -not $_.requiredAcksPresent } | ForEach-Object { $_.script })
$rowsMissingValidationSignals = @($rows | Where-Object { -not $_.requiredValidationSignalsPresent } | ForEach-Object { $_.script })
$badOwnerInputRows = @($rows | Where-Object { -not $_.ownerInputNamesOnly } | ForEach-Object { $_.script })
$phases = @($rows | ForEach-Object { $_.phase } | Sort-Object -Unique)
$requiredPhases = @("preflight", "deploy-control", "observe", "credit", "pilot-proof", "withdraw-release", "emergency-control", "local-smoke", "release")
$missingPhases = @($requiredPhases | Where-Object { $_ -notin $phases })
$liveBroadcastRows = @($rows | Where-Object { $_.liveBroadcastCapable })
$liveBroadcastRowsWithoutAck = @($liveBroadcastRows | Where-Object { $_.requiredAckEnvNames -notcontains "FLOWCHAIN_BASE8453_BROADCAST_ACK" -or -not $_.requiredAcksPresent } | ForEach-Object { $_.script })
$committedEvidenceRows = @($rows | Where-Object { $_.committedEvidencePath })
$checks = [ordered]@{
    allRequiredScriptsPresent = $missingScripts.Count -eq 0
    phaseCoverageComplete = $missingPhases.Count -eq 0
    deployObserveRelayerControlReleaseCovered = @(
        "flowchain:bridge:deploy:base8453",
        "flowchain:bridge:observe:base8453",
        "flowchain:bridge:relayer:once",
        "flowchain:bridge:pause",
        "flowchain:bridge:resume",
        "flowchain:bridge:emergency-stop",
        "flowchain:bridge:release:evidence",
        "flowchain:bridge:release:evidence:validate"
    ) | Where-Object { $_ -notin @($rows | ForEach-Object { $_.script }) } | Measure-Object | ForEach-Object { $_.Count -eq 0 }
    liveBroadcastCommandsAckGated = $liveBroadcastRowsWithoutAck.Count -eq 0
    observeCommandOperatorAckGated = @($rows | Where-Object { $_.script -eq "flowchain:bridge:observe:base8453" -and $_.requiredAckEnvNames -contains "FLOWCHAIN_PILOT_OPERATOR_ACK" -and $_.requiredAcksPresent }).Count -eq 1
    relayerOnceOperatorAckGated = @($rows | Where-Object { $_.script -eq "flowchain:bridge:relayer:once" -and $_.requiredAckEnvNames -contains "FLOWCHAIN_PILOT_OPERATOR_ACK" -and $_.requiredAcksPresent }).Count -eq 1
    controlCommandsBroadcastAckGated = @($rows | Where-Object { $_.script -in @("flowchain:bridge:pause", "flowchain:bridge:resume", "flowchain:bridge:emergency-stop") -and $_.requiredAckEnvNames -contains "FLOWCHAIN_BASE8453_BROADCAST_ACK" -and $_.requiredAcksPresent }).Count -eq 3
    deployCommandBroadcastAckGated = @($rows | Where-Object { $_.script -eq "flowchain:bridge:deploy:base8453" -and $_.requiredAckEnvNames -contains "FLOWCHAIN_BASE8453_BROADCAST_ACK" -and $_.requiredAcksPresent }).Count -eq 1
    requiredEnvReferencesPresent = $rowsMissingEnvReferences.Count -eq 0
    requiredAckReferencesPresent = $rowsMissingAckReferences.Count -eq 0
    validationSignalsPresent = $rowsMissingValidationSignals.Count -eq 0
    commandsAvoidInlineEnvAssignment = $commandsWithInlineEnvAssignment.Count -eq 0
    commandsAvoidUrls = $commandsWithUrls.Count -eq 0
    commandsAvoidKeyMaterial = $commandsWithKeyMaterialReference.Count -eq 0
    ownerInputNamesOnly = $badOwnerInputRows.Count -eq 0
    committedEvidencePathsCovered = $committedEvidenceRows.Count -ge 10
    envValuesPrintedFalse = $true
    broadcastsFalse = $true
    noSecrets = $true
}

$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
$report = [ordered]@{
    schema = "flowchain.bridge_command_matrix_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    commandCount = $rows.Count
    phaseCount = $phases.Count
    liveBroadcastCapableCommandCount = $liveBroadcastRows.Count
    committedEvidencePathCount = $committedEvidenceRows.Count
    requiredPhases = $requiredPhases
    missingPhases = $missingPhases
    rows = @($rows)
    missingScripts = $missingScripts
    commandsWithInlineEnvAssignment = $commandsWithInlineEnvAssignment
    commandsWithUrls = $commandsWithUrls
    commandsWithKeyMaterialReference = $commandsWithKeyMaterialReference
    rowsMissingEnvReferences = $rowsMissingEnvReferences
    rowsMissingAckReferences = $rowsMissingAckReferences
    rowsMissingValidationSignals = $rowsMissingValidationSignals
    liveBroadcastRowsWithoutAck = $liveBroadcastRowsWithoutAck
    badOwnerInputRows = $badOwnerInputRows
    checks = $checks
    failedChecks = $failedChecks
    broadcasts = $false
    envValuesPrinted = $false
    noSecrets = $true
}

Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

$markdownLines = New-Object System.Collections.ArrayList
[void] $markdownLines.Add("# FlowChain Bridge Command Matrix")
[void] $markdownLines.Add("")
[void] $markdownLines.Add("Generated: $($report.generatedAt)")
[void] $markdownLines.Add("Status: $status")
[void] $markdownLines.Add("")
[void] $markdownLines.Add("This matrix maps bridge pilot commands to their phase, live-broadcast risk, owner input names, acknowledgement gates, and expected evidence paths. It prints names only, not owner values.")
[void] $markdownLines.Add("")
[void] $markdownLines.Add("## Summary")
[void] $markdownLines.Add("")
[void] $markdownLines.Add("- Commands: $($rows.Count)")
[void] $markdownLines.Add("- Phases: $($phases -join ', ')")
[void] $markdownLines.Add("- Live-broadcast-capable commands: $($liveBroadcastRows.Count)")
[void] $markdownLines.Add("- Committed evidence paths: $($committedEvidenceRows.Count)")
[void] $markdownLines.Add("- Failed checks: $($failedChecks.Count)")
[void] $markdownLines.Add("")
[void] $markdownLines.Add("## Checks")
[void] $markdownLines.Add("")
[void] $markdownLines.Add("| Check | Passed |")
[void] $markdownLines.Add("| --- | --- |")
foreach ($check in $checks.GetEnumerator()) {
    [void] $markdownLines.Add("| $($check.Key) | $($check.Value) |")
}
[void] $markdownLines.Add("")
[void] $markdownLines.Add("## Commands")
[void] $markdownLines.Add("")
[void] $markdownLines.Add("| Phase | Script | Risk | Ack gates | Evidence |")
[void] $markdownLines.Add("| --- | --- | --- | --- | --- |")
foreach ($row in $rows) {
    $acks = if ($row.requiredAckEnvNames.Count -gt 0) { $row.requiredAckEnvNames -join ", " } else { "none" }
    $evidence = if ([string]::IsNullOrWhiteSpace($row.expectedReportPath)) { "command-local" } else { $row.expectedReportPath }
    [void] $markdownLines.Add("| $($row.phase) | ``$($row.script)`` | $($row.riskClass) | $acks | $evidence |")
}
[void] $markdownLines.Add("")
[void] $markdownLines.Add("## Owner Input Names")
[void] $markdownLines.Add("")
$ownerNames = @($rows | ForEach-Object { @($_.requiredEnvNames) + @($_.optionalEnvNames) + @($_.requiredAckEnvNames) } | Sort-Object -Unique)
foreach ($name in $ownerNames) {
    if (-not [string]::IsNullOrWhiteSpace($name)) {
        [void] $markdownLines.Add("- $name")
    }
}

Set-Content -LiteralPath $markdownFullPath -Value $markdownLines -Encoding UTF8
Write-Host "Bridge command matrix status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($failedChecks.Count -gt 0) {
    throw "Bridge command matrix failed checks: $($failedChecks -join ', ')"
}
