param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/production-truth-table-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/PRODUCTION_TRUTH_TABLE.md",
    [int] $MaxReportAgeHours = 24,
    [switch] $AllowBlocked
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
    "FLOWCHAIN_TESTER_WRITE_ENABLED",
    "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256",
    "FLOWCHAIN_TESTER_MAX_SEND_UNITS",
    "FLOWCHAIN_PILOT_OPERATOR_ACK",
    "FLOWCHAIN_BASE8453_RPC_URL",
    "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
    "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
    "FLOWCHAIN_BASE8453_ASSET_DECIMALS",
    "FLOWCHAIN_BASE8453_FROM_BLOCK",
    "FLOWCHAIN_BASE8453_CURSOR_STATE",
    "FLOWCHAIN_BASE8453_TO_BLOCK",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_PILOT_CONFIRMATIONS"
)

$definitions = @(
    [ordered]@{
        id = "service-status"
        requirement = "Private FlowChain node and control-plane services are running and readable."
        path = "docs/agent-runs/live-product-infra-rpc/service-status-report.json"
        command = "npm run flowchain:service:status"
        productionGate = $true
        ownerInputGate = $false
    },
    [ordered]@{
        id = "service-monitor"
        requirement = "Block production advances over multiple samples."
        path = "docs/agent-runs/live-product-infra-rpc/service-monitor-report.json"
        command = "npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30"
        productionGate = $true
        ownerInputGate = $false
    },
    [ordered]@{
        id = "live-product-e2e"
        requirement = "Local live-product e2e covers runtime, wallet, live infra, and tester rehearsal without public claims."
        path = "docs/agent-runs/live-product-infra-rpc/flowchain-live-product-e2e-report.json"
        command = "npm run flowchain:live-product:e2e -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $false
    },
    [ordered]@{
        id = "live-infra-check"
        requirement = "Live infrastructure readiness separates repo-owned checks from public owner-input blockers."
        path = "docs/agent-runs/live-product-infra-rpc/flowchain-live-infra-check-report.json"
        command = "npm run flowchain:live-infra:check -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "wallet-live-service-e2e"
        requirement = "Wallet creation and wallet-to-wallet service flow works against the running private service."
        path = "docs/agent-runs/live-product-infra-rpc/live-service-wallet-e2e-report.json"
        command = "npm run flowchain:wallet:live-service:e2e"
        productionGate = $true
        ownerInputGate = $false
    },
    [ordered]@{
        id = "tester-network-e2e"
        requirement = "Separate tester wallets can transact and observe chain state in local rehearsal."
        path = "docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json"
        command = "npm run flowchain:wallet:live-tester:e2e"
        productionGate = $true
        ownerInputGate = $false
    },
    [ordered]@{
        id = "owner-inputs"
        requirement = "Owner-provided public RPC, backup, and Base 8453 bridge inputs are configured and valid."
        path = "docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json"
        command = "npm run flowchain:owner-inputs -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "public-rpc-readiness"
        requirement = "Public FlowChain RPC has URL, TLS acknowledgement, CORS, rate limit, backup path, and response hygiene."
        path = "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json"
        command = "npm run flowchain:public-rpc:check -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "public-rpc-validation"
        requirement = "Public RPC validation harness is present and fail-closed before endpoint sharing."
        path = "docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json"
        command = "npm run flowchain:public-rpc:validate"
        productionGate = $true
        ownerInputGate = $false
    },
    [ordered]@{
        id = "public-rpc-abuse-test"
        requirement = "Public RPC abuse harness proves CORS rejection, media-type rejection, malformed JSON handling, batch/body caps, notification handling, rate limiting, and no-secret summaries."
        path = "docs/agent-runs/live-product-infra-rpc/public-rpc-abuse-test-report.json"
        command = "npm run flowchain:public-rpc:abuse-test"
        productionGate = $true
        ownerInputGate = $false
    },
    [ordered]@{
        id = "public-rpc-deployment-bundle"
        requirement = "No-secret public RPC deployment bundle exists and owner-render validation proves HTTPS reverse proxy, service, shell preflight, Windows preflight, verification, and rollback artifacts render safely."
        path = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json"
        command = "npm run flowchain:public-rpc:deployment-bundle"
        productionGate = $true
        ownerInputGate = $false
    },
    [ordered]@{
        id = "backup-readiness"
        requirement = "Configured production backup path can create and restore manifest-backed state snapshots."
        path = "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json"
        command = "npm run flowchain:backup:check -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "backup-restore-validation"
        requirement = "Local backup/restore rehearsal restores the latest snapshot safely and rejects corrupt, tampered, missing-artifact, stale-pointer, and wrong-chain evidence."
        path = "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-report.json"
        command = "npm run flowchain:backup:restore:validate"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "backupCommandPassed",
            "restoreCommandPassed",
            "backupRestoreHashRoundTrip",
            "secondBackupCommandPassed",
            "latestManifestMatchesSecondSnapshot",
            "latestRestoreCommandPassed",
            "latestRestoreUsedLatestSnapshot",
            "restoreTargetsLiveStateProtected",
            "liveStateNonMutationProven",
            "corruptedSnapshotDetected",
            "manifestTamperDetected",
            "missingStateArtifactDetected",
            "missingSnapshotManifestDetected",
            "latestPointerTamperDetected",
            "wrongChainStateMismatchDetected"
        )
    },
    [ordered]@{
        id = "bridge-live-readiness"
        requirement = "Base 8453 live bridge pilot has required owner inputs, caps, confirmations, and operator acknowledgement."
        path = "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
        command = "npm run flowchain:bridge:live:check -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "bridge-infra-readiness"
        requirement = "Bridge infrastructure readiness is safe for external funded testing."
        path = "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
        command = "npm run flowchain:bridge:infra:check -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "external-tester-readiness"
        requirement = "External tester flow remains blocked until public RPC, backup, bridge, and local tester evidence pass."
        path = "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
        command = "npm run flowchain:tester:readiness -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "external-tester-packet"
        requirement = "Friends-and-family tester packet is shareable only after all public gates pass."
        path = "docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json"
        command = "npm run flowchain:external-tester:packet -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "ops-snapshot"
        requirement = "Ops snapshot distinguishes critical incidents from expected owner-input blockers and gives incident commands."
        path = "docs/agent-runs/live-product-infra-rpc/ops-snapshot-report.json"
        command = "npm run flowchain:ops:snapshot -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "incident-drill"
        requirement = "Incident drills prove operational failures become critical incidents while owner-input blockers remain non-critical."
        path = "docs/agent-runs/live-product-infra-rpc/incident-drill-report.json"
        command = "npm run flowchain:ops:incident-drill"
        productionGate = $true
        ownerInputGate = $false
    },
    [ordered]@{
        id = "public-deployment-contract"
        requirement = "Public deployment contract is ready before endpoint exposure or tester packet sharing."
        path = "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json"
        command = "npm run flowchain:public-deployment:contract -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "architecture-audit"
        requirement = "System architecture audit covers local runtime, public RPC, backup, bridge, tester, and no-secret gates."
        path = "docs/agent-runs/live-product-infra-rpc/flowchain-architecture-audit-report.json"
        command = "npm run flowchain:architecture:audit -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "completion-audit"
        requirement = "Completion audit is fresh and is the release gate for claiming production readiness."
        path = "docs/agent-runs/live-product-infra-rpc/flowchain-completion-audit-report.json"
        command = "npm run flowchain:completion:audit -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
        staleIfOlderThan = @("backup-restore-validation", "ops-snapshot", "public-rpc-deployment-bundle", "public-deployment-contract")
    },
    [ordered]@{
        id = "no-secret-scan"
        requirement = "Generated reports, docs, and packets contain no secrets or owner-provided values."
        path = "docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json"
        command = "npm run flowchain:no-secret:scan"
        productionGate = $true
        ownerInputGate = $false
    }
)

function Get-TruthProp {
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

function Add-UniqueTruthValue {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [AllowNull()][object] $Value
    )

    $text = "$Value"
    if (-not [string]::IsNullOrWhiteSpace($text) -and -not $Target.Contains($text)) {
        [void] $Target.Add($text)
    }
}

function Add-TruthBlockersFromList {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [AllowNull()][object] $Values
    )

    foreach ($value in @($Values)) {
        Add-UniqueTruthValue -Target $Target -Value $value
    }
}

function Get-TruthGeneratedAt {
    param([AllowNull()][object] $Report)

    $value = Get-TruthProp -Object $Report -Name "generatedAt"
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace("$value")) {
        return $null
    }

    try {
        return [DateTimeOffset]::Parse("$value", [System.Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        return $null
    }
}

function Get-TruthReportAgeSeconds {
    param([AllowNull()][DateTimeOffset] $GeneratedAt)

    if ($null -eq $GeneratedAt) {
        return $null
    }

    $age = [DateTimeOffset]::UtcNow - $GeneratedAt.ToUniversalTime()
    return [int][Math]::Max(0, [Math]::Floor($age.TotalSeconds))
}

function Get-TruthStatus {
    param([AllowNull()][object] $Report)
    return [string](Get-TruthProp -Object $Report -Name "status" -Default "missing")
}

function Get-TruthBlockers {
    param([AllowNull()][object] $Report)

    $blockers = New-Object System.Collections.ArrayList
    if ($null -eq $Report) {
        return @($blockers)
    }

    Add-TruthBlockersFromList -Target $blockers -Values (Get-TruthProp -Object $Report -Name "missingEnvNames" -Default @())
    Add-TruthBlockersFromList -Target $blockers -Values (Get-TruthProp -Object $Report -Name "invalidEnvNames" -Default @())

    foreach ($problem in @((Get-TruthProp -Object $Report -Name "problems" -Default @()))) {
        $kind = [string](Get-TruthProp -Object $problem -Name "kind" -Default "")
        if ($kind -ne "blocked") {
            continue
        }
        Add-UniqueTruthValue -Target $blockers -Value (Get-TruthProp -Object $problem -Name "name")
        Add-UniqueTruthValue -Target $blockers -Value (Get-TruthProp -Object $problem -Name "envName")
    }

    foreach ($item in @((Get-TruthProp -Object $Report -Name "items" -Default @()))) {
        $itemStatus = [string](Get-TruthProp -Object $item -Name "status" -Default "")
        if ($itemStatus -notin @("blocked", "failed")) {
            continue
        }
        Add-TruthBlockersFromList -Target $blockers -Values (Get-TruthProp -Object $item -Name "blockers" -Default @())
    }

    return @($blockers)
}

function Test-TruthAllKnownOwnerInputs {
    param([AllowNull()][object[]] $Blockers)

    $values = @($Blockers | Where-Object { -not [string]::IsNullOrWhiteSpace("$_") })
    if ($values.Count -eq 0) {
        return $false
    }

    foreach ($value in $values) {
        if ($value -notin $knownOwnerInputs) {
            return $false
        }
    }
    return $true
}

function ConvertTo-TruthEvidence {
    param(
        [AllowNull()][object] $Report,
        [string] $RawStatus,
        [AllowNull()][object[]] $Blockers
    )

    if ($null -eq $Report) {
        return "report=missing"
    }

    $facts = New-Object System.Collections.ArrayList
    Add-UniqueTruthValue -Target $facts -Value "status=$RawStatus"

    foreach ($name in @(
        "latestHeight",
        "finalizedHeight",
        "publicRpcReady",
        "ownerInputReady",
        "deploymentReady",
        "packetShareable",
        "externalSharingReady",
        "localTesterRehearsalReady",
        "completionReady",
        "blockedOnlyOnKnownExternalOwnerInputs"
    )) {
        $value = Get-TruthProp -Object $Report -Name $name
        if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace("$value")) {
            Add-UniqueTruthValue -Target $facts -Value "$name=$value"
        }
    }

    $chain = Get-TruthProp -Object $Report -Name "chain"
    if ($null -ne $chain) {
        $latest = Get-TruthProp -Object $chain -Name "latestHeight"
        $finalized = Get-TruthProp -Object $chain -Name "finalizedHeight"
        if ($null -ne $latest) {
            Add-UniqueTruthValue -Target $facts -Value "latestHeight=$latest"
        }
        if ($null -ne $finalized) {
            Add-UniqueTruthValue -Target $facts -Value "finalizedHeight=$finalized"
        }
    }

    $backup = Get-TruthProp -Object $Report -Name "backup"
    if ($null -ne $backup) {
        Add-UniqueTruthValue -Target $facts -Value "snapshotProofStatus=$(Get-TruthProp -Object $backup -Name "snapshotProofStatus" -Default "unknown")"
        Add-UniqueTruthValue -Target $facts -Value "restoreProofStatus=$(Get-TruthProp -Object $backup -Name "restoreProofStatus" -Default "unknown")"
    }

    $checks = Get-TruthProp -Object $Report -Name "checks"
    if ($null -ne $checks) {
        foreach ($name in @(
            "backupRestoreHashRoundTrip",
            "latestRestoreUsedLatestSnapshot",
            "restoreTargetsLiveStateProtected",
            "liveStateNonMutationProven",
            "corruptedSnapshotDetected",
            "manifestTamperDetected",
            "missingStateArtifactDetected",
            "missingSnapshotManifestDetected",
            "latestPointerTamperDetected",
            "wrongChainStateMismatchDetected"
        )) {
            $value = Get-TruthProp -Object $checks -Name $name
            if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace("$value")) {
                Add-UniqueTruthValue -Target $facts -Value "$name=$value"
            }
        }
    }

    if (@($Blockers).Count -gt 0) {
        Add-UniqueTruthValue -Target $facts -Value "blockers=$(@($Blockers) -join ',')"
    }

    return (@($facts) -join "; ")
}

function Get-TruthClassification {
    param(
        [Parameter(Mandatory = $true)][object] $Definition,
        [AllowNull()][object] $Report,
        [AllowNull()][object[]] $Blockers,
        [bool] $IsStale
    )

    if ($null -eq $Report -or $IsStale) {
        return "stale"
    }

    $rawStatus = (Get-TruthStatus -Report $Report).ToLowerInvariant()
    if ($rawStatus -in @("passed", "valid")) {
        $requiredChecks = @((Get-TruthProp -Object $Definition -Name "requiredChecks" -Default @()))
        if ($requiredChecks.Count -gt 0) {
            $checks = Get-TruthProp -Object $Report -Name "checks"
            foreach ($name in $requiredChecks) {
                if ((Get-TruthProp -Object $checks -Name $name -Default $false) -ne $true) {
                    return "failed"
                }
            }
        }
        return "passed"
    }
    if ($rawStatus -in @("failed", "error", "invalid")) {
        return "failed"
    }
    if ($rawStatus -eq "blocked") {
        $criticalFindings = @((Get-TruthProp -Object $Report -Name "findings" -Default @()) | Where-Object {
            [string](Get-TruthProp -Object $_ -Name "severity" -Default "") -eq "critical"
        })
        if ($criticalFindings.Count -gt 0) {
            return "failed"
        }
        $blockedOnlyOnKnownOwnerInputs = Get-TruthProp -Object $Report -Name "blockedOnlyOnKnownExternalOwnerInputs" -Default $false
        if ($blockedOnlyOnKnownOwnerInputs -eq $true -or (Test-TruthAllKnownOwnerInputs -Blockers $Blockers)) {
            return "blocked-owner-input"
        }
        if ((Get-TruthProp -Object $Definition -Name "ownerInputGate" -Default $false) -eq $true) {
            return "blocked-owner-input"
        }
        return "blocked-repo-work"
    }
    if ($rawStatus -eq "missing") {
        return "stale"
    }

    return "blocked-repo-work"
}

$reportsById = [ordered]@{}
$generatedAtById = [ordered]@{}
foreach ($definition in $definitions) {
    $fullPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path $definition.path
    $report = Read-FlowChainJsonIfExists -Path $fullPath
    $reportsById[$definition.id] = $report
    $generatedAtById[$definition.id] = Get-TruthGeneratedAt -Report $report
}

$items = New-Object System.Collections.ArrayList
$now = [DateTimeOffset]::UtcNow
$maxAgeSeconds = [int]([TimeSpan]::FromHours($MaxReportAgeHours).TotalSeconds)

foreach ($definition in $definitions) {
    $id = [string] $definition.id
    $fullPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path $definition.path
    $report = $reportsById[$id]
    $generatedAt = $generatedAtById[$id]
    $ageSeconds = Get-TruthReportAgeSeconds -GeneratedAt $generatedAt
    $staleReasons = New-Object System.Collections.ArrayList

    if ($null -eq $report) {
        Add-UniqueTruthValue -Target $staleReasons -Value "missing-or-unreadable-report"
    }
    elseif ($null -eq $generatedAt) {
        Add-UniqueTruthValue -Target $staleReasons -Value "missing-generatedAt"
    }
    elseif ($ageSeconds -gt $maxAgeSeconds) {
        Add-UniqueTruthValue -Target $staleReasons -Value "older-than-$MaxReportAgeHours-hours"
    }

    foreach ($dependencyId in @((Get-TruthProp -Object $definition -Name "staleIfOlderThan" -Default @()))) {
        $dependencyGeneratedAt = $generatedAtById[$dependencyId]
        if ($null -ne $generatedAt -and $null -ne $dependencyGeneratedAt -and $generatedAt.ToUniversalTime() -lt $dependencyGeneratedAt.ToUniversalTime()) {
            Add-UniqueTruthValue -Target $staleReasons -Value "older-than-$dependencyId"
        }
    }

    $blockers = @(Get-TruthBlockers -Report $report)
    $rawStatus = Get-TruthStatus -Report $report
    $classification = Get-TruthClassification -Definition $definition -Report $report -Blockers $blockers -IsStale (@($staleReasons).Count -gt 0)
    $evidence = ConvertTo-TruthEvidence -Report $report -RawStatus $rawStatus -Blockers $blockers

    [void] $items.Add([ordered]@{
        id = $id
        requirement = [string] $definition.requirement
        classification = $classification
        rawStatus = $rawStatus
        evidence = $evidence
        command = [string] $definition.command
        reportPath = [string] $definition.path
        reportExists = $null -ne $report
        generatedAt = if ($null -ne $generatedAt) { $generatedAt.ToUniversalTime().ToString("o") } else { $null }
        ageSeconds = $ageSeconds
        staleReasons = @($staleReasons)
        blockers = @($blockers)
        ownerInputBlockers = @($blockers | Where-Object { $_ -in $knownOwnerInputs })
        productionGate = [bool] $definition.productionGate
    })
}

$classificationCounts = [ordered]@{}
foreach ($classification in @("passed", "blocked-owner-input", "blocked-repo-work", "failed", "stale")) {
    $classificationCounts[$classification] = @($items | Where-Object { $_.classification -eq $classification }).Count
}

$missingOwnerInputs = New-Object System.Collections.ArrayList
foreach ($item in @($items)) {
    foreach ($name in @($item.ownerInputBlockers)) {
        Add-UniqueTruthValue -Target $missingOwnerInputs -Value $name
    }
}

$staleItems = @($items | Where-Object { $_.classification -eq "stale" })
$failedItems = @($items | Where-Object { $_.classification -eq "failed" })
$repoBlockedItems = @($items | Where-Object { $_.classification -eq "blocked-repo-work" })
$ownerBlockedItems = @($items | Where-Object { $_.classification -eq "blocked-owner-input" })

$overallStatus = if ($failedItems.Count -gt 0) {
    "failed"
}
elseif ($staleItems.Count -gt 0) {
    "stale"
}
elseif ($repoBlockedItems.Count -gt 0) {
    "blocked-repo-work"
}
elseif ($ownerBlockedItems.Count -gt 0) {
    "blocked-owner-input"
}
else {
    "passed"
}

$nextRepoTasks = New-Object System.Collections.ArrayList
foreach ($item in @($staleItems + $repoBlockedItems + $failedItems)) {
    [void] $nextRepoTasks.Add([ordered]@{
        id = Get-TruthProp -Object $item -Name "id"
        classification = Get-TruthProp -Object $item -Name "classification"
        command = Get-TruthProp -Object $item -Name "command"
        reason = if (@((Get-TruthProp -Object $item -Name "staleReasons" -Default @())).Count -gt 0) { @((Get-TruthProp -Object $item -Name "staleReasons" -Default @())) -join "," } else { Get-TruthProp -Object $item -Name "rawStatus" }
    })
}
if ($nextRepoTasks.Count -eq 0 -and $ownerBlockedItems.Count -gt 0) {
    [void] $nextRepoTasks.Add([ordered]@{
        id = "owner-inputs"
        classification = "blocked-owner-input"
        command = "npm run flowchain:owner-inputs -- -AllowBlocked"
        reason = "Only known owner-input blockers remain in the current truth table."
    })
}

$report = [ordered]@{
    schema = "flowchain.production_truth_table_report.v1"
    generatedAt = $now.ToString("o")
    status = $overallStatus
    maxReportAgeHours = $MaxReportAgeHours
    classificationCounts = $classificationCounts
    productionGateCount = @($items | Where-Object { $_.productionGate -eq $true }).Count
    completionReady = $overallStatus -eq "passed"
    blockedOnlyOnKnownOwnerInputs = $overallStatus -eq "blocked-owner-input"
    missingOwnerInputs = @($missingOwnerInputs)
    nextRepoOwnedTasks = @($nextRepoTasks)
    items = @($items)
}

Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20

$lines = New-Object System.Collections.ArrayList
[void] $lines.Add("# FlowChain Production Truth Table")
[void] $lines.Add("")
[void] $lines.Add("Generated: $($report.generatedAt)")
[void] $lines.Add("Status: $overallStatus")
[void] $lines.Add("Completion ready: $($report.completionReady)")
[void] $lines.Add("Blocked only on known owner inputs: $($report.blockedOnlyOnKnownOwnerInputs)")
[void] $lines.Add("")
[void] $lines.Add("## Classification Counts")
[void] $lines.Add("")
[void] $lines.Add("| Classification | Count |")
[void] $lines.Add("| --- | ---: |")
foreach ($entry in $classificationCounts.GetEnumerator()) {
    [void] $lines.Add("| $($entry.Key) | $($entry.Value) |")
}
[void] $lines.Add("")

if (@($missingOwnerInputs).Count -gt 0) {
    [void] $lines.Add("## Missing Owner Inputs")
    [void] $lines.Add("")
    foreach ($name in @($missingOwnerInputs)) {
        [void] $lines.Add("- $name")
    }
    [void] $lines.Add("")
}

if ($nextRepoTasks.Count -gt 0) {
    [void] $lines.Add("## Next Repo-Owned Tasks")
    [void] $lines.Add("")
    foreach ($task in @($nextRepoTasks | Select-Object -First 8)) {
        $taskId = Get-TruthProp -Object $task -Name "id"
        $taskClassification = Get-TruthProp -Object $task -Name "classification"
        $taskReason = Get-TruthProp -Object $task -Name "reason"
        $taskCommand = Get-TruthProp -Object $task -Name "command"
        [void] $lines.Add("- ${taskId}: ${taskClassification} - ${taskReason}")
        [void] $lines.Add("  Command: $taskCommand")
    }
    [void] $lines.Add("")
}

[void] $lines.Add("## Gate Table")
[void] $lines.Add("")
[void] $lines.Add("| Gate | Classification | Raw Status | Evidence | Command |")
[void] $lines.Add("| --- | --- | --- | --- | --- |")
foreach ($item in @($items)) {
    $itemId = Get-TruthProp -Object $item -Name "id"
    $itemClassification = Get-TruthProp -Object $item -Name "classification"
    $itemRawStatus = Get-TruthProp -Object $item -Name "rawStatus"
    $itemCommand = Get-TruthProp -Object $item -Name "command"
    $safeEvidence = "$(Get-TruthProp -Object $item -Name "evidence")".Replace("|", "\|")
    [void] $lines.Add("| $itemId | $itemClassification | $itemRawStatus | $safeEvidence | ``$itemCommand`` |")
}
[void] $lines.Add("")
[void] $lines.Add("## Release Decision")
[void] $lines.Add("")
if ($overallStatus -eq "passed") {
    [void] $lines.Add("All tracked production gates are passed from fresh evidence.")
}
elseif ($overallStatus -eq "blocked-owner-input") {
    [void] $lines.Add("Do not claim public production readiness yet. The current tracked blockers are known owner inputs.")
}
elseif ($overallStatus -eq "stale") {
    [void] $lines.Add("Do not claim public production readiness yet. At least one required report is stale or missing.")
}
elseif ($overallStatus -eq "blocked-repo-work") {
    [void] $lines.Add("Do not claim public production readiness yet. At least one repo-owned gate is blocked.")
}
else {
    [void] $lines.Add("Do not claim public production readiness yet. At least one gate failed.")
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$markdownParent = Split-Path -Parent $markdownFullPath
if (-not [string]::IsNullOrWhiteSpace($markdownParent)) {
    New-Item -ItemType Directory -Force -Path $markdownParent | Out-Null
}
[System.IO.File]::WriteAllText($markdownFullPath, (@($lines) -join [Environment]::NewLine) + [Environment]::NewLine, $utf8NoBom)

Write-Host "FlowChain production truth table status: $overallStatus"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"

if ($overallStatus -ne "passed" -and -not $AllowBlocked) {
    exit 1
}
