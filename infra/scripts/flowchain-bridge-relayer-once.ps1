param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node",
    [string] $RunDir = "devnet/local/bridge-relayer-once",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-relayer-once-report.json",
    [string] $InfraReportPath = "",
    [string] $LiveReportPath = "",
    [string] $ObservationPath = "services/bridge-relayer/out/base8453-pilot-bridge-observation.json",
    [string] $CreditPath = "services/bridge-relayer/out/base8453-pilot-bridge-credit.json",
    [string] $HandoffPath = "services/bridge-relayer/out/base8453-pilot-bridge-handoff.json",
    [string] $FilteredHandoffPath = "",
    [string] $EvidencePath = "services/bridge-relayer/out/base8453-pilot-evidence.json",
    [string] $RuntimeStatePath = "services/bridge-relayer/out/base8453-pilot-credit-application-state.json",
    [string] $CursorState = $(if ($env:FLOWCHAIN_BASE8453_CURSOR_STATE) { $env:FLOWCHAIN_BASE8453_CURSOR_STATE } else { "services/bridge-relayer/out/base8453-pilot-cursor-state.json" }),
    [string] $AuthorizedBy = "operator:bridge-relayer-once",
    [int] $WaitSeconds = 60,
    [switch] $NoQueue,
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot -Purpose "bridge-relayer-once" | Out-Null

$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$nodeFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $NodeDir)
$runFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $RunDir)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$observationFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ObservationPath)
$creditFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $CreditPath)
$handoffFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $HandoffPath)
$evidenceFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $EvidencePath)
$runtimeStateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $RuntimeStatePath)
$cursorStateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $CursorState)

if ([string]::IsNullOrWhiteSpace($InfraReportPath)) {
    $InfraReportPath = Join-Path $RunDir "bridge-infra-readiness-report.json"
}
if ([string]::IsNullOrWhiteSpace($LiveReportPath)) {
    $LiveReportPath = Join-Path $RunDir "bridge-live-readiness-report.json"
}
if ([string]::IsNullOrWhiteSpace($FilteredHandoffPath)) {
    $FilteredHandoffPath = Join-Path $RunDir "base8453-handoff-new-credits-only.json"
}
$infraReportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $InfraReportPath)
$liveReportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $LiveReportPath)
$filteredHandoffFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $FilteredHandoffPath)

if ($WaitSeconds -lt 0) {
    throw "WaitSeconds must be at least 0."
}

New-Item -ItemType Directory -Force -Path $runFullDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $runFullDir "logs") | Out-Null

$steps = New-Object System.Collections.ArrayList
$issues = New-Object System.Collections.ArrayList
$artifacts = [ordered]@{
    runDir = $runFullDir
    statePath = $stateFullPath
    nodeDir = $nodeFullDir
    infraReadinessReport = $infraReportFullPath
    liveReadinessReport = $liveReportFullPath
    observation = $observationFullPath
    credit = $creditFullPath
    handoff = $handoffFullPath
    filteredHandoff = $filteredHandoffFullPath
    evidence = $evidenceFullPath
    runtimeState = $runtimeStateFullPath
    cursorState = $cursorStateFullPath
}
$counts = [ordered]@{
    observedCredits = 0
    newCredits = 0
    queuedTransactions = 0
    appliedCredits = 0
}
$readiness = [ordered]@{
    infra = "not-run"
    live = "not-run"
}
$ownerEnvState = [ordered]@{
    configured = $false
    imported = $false
    importedEnvNames = @()
    ignoredEnvNames = @()
    problem = ""
}

function Add-RelayerStep {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Status,
        [string] $LogPath = "",
        [string] $ReportPath = "",
        [string] $Reason = ""
    )

    [void] $steps.Add([ordered]@{
        name = $Name
        status = $Status
        logPath = $LogPath
        reportPath = $ReportPath
        reason = $Reason
        at = (Get-Date).ToUniversalTime().ToString("o")
    })
}

function Add-RelayerIssue {
    param(
        [ValidateSet("external", "code")]
        [string] $Kind,
        [Parameter(Mandatory = $true)][string] $Code,
        [Parameter(Mandatory = $true)][string] $Reason,
        [string] $Owner = "bridge-relayer"
    )

    [void] $issues.Add([ordered]@{
        kind = $Kind
        code = $Code
        reason = $Reason
        owner = $Owner
    })
}

function ConvertTo-RelayerSafeLine {
    param([AllowNull()][object] $Line)

    $text = "$Line"
    $envNames = @(
        "FLOWCHAIN_PILOT_OPERATOR_ACK",
        "FLOWCHAIN_BASE8453_RPC_URL",
        "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
        "FLOWCHAIN_BASE8453_APPROVED_LOCKBOX_ADDRESS",
        "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
        "FLOWCHAIN_BASE8453_ASSET_DECIMALS",
        "FLOWCHAIN_BASE8453_FROM_BLOCK",
        "FLOWCHAIN_BASE8453_CURSOR_STATE",
        "FLOWCHAIN_BASE8453_TO_BLOCK",
        "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
        "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
        "FLOWCHAIN_PILOT_CONFIRMATIONS"
    )
    foreach ($name in $envNames) {
        $value = [Environment]::GetEnvironmentVariable($name, "Process")
        if (-not [string]::IsNullOrWhiteSpace($value) -and $value.Length -ge 6) {
            $text = $text.Replace($value, "<$name>")
        }
    }
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "https?://[^\s,)]+", "<redacted-url>")
    return $text
}

function Invoke-RelayerExternal {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $FilePath,
        [string[]] $ArgumentList = @(),
        [string] $ExpectedReportPath = ""
    )

    $safeName = (($Name -replace '[^A-Za-z0-9_.-]', '-') -replace '-+', '-').Trim("-")
    $logPath = Join-Path (Join-Path $runFullDir "logs") "$safeName.log"
    $previousErrorActionPreference = $ErrorActionPreference
    $script:ErrorActionPreference = "Continue"
    try {
        $output = (& $FilePath @ArgumentList 2>&1) | ForEach-Object { ConvertTo-RelayerSafeLine -Line $_ }
        $exitCode = $LASTEXITCODE
    }
    catch {
        $output = @(ConvertTo-RelayerSafeLine -Line $_.Exception.Message)
        $exitCode = 1
    }
    finally {
        $script:ErrorActionPreference = $previousErrorActionPreference
    }

    $output | Set-Content -LiteralPath $logPath -Encoding utf8
    $status = if ($exitCode -eq 0) { "passed" } else { "failed" }
    $reason = if ($status -eq "passed") { "" } else { (@($output) | Select-Object -Last 6) -join [Environment]::NewLine }
    Add-RelayerStep -Name $Name -Status $status -LogPath $logPath -ReportPath $ExpectedReportPath -Reason $reason

    return [ordered]@{
        status = $status
        exitCode = [int]$exitCode
        logPath = $logPath
        output = @($output)
        reportPath = $ExpectedReportPath
    }
}

function Invoke-RelayerCargoJson {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string[]] $RuntimeArgs
    )

    $result = Invoke-RelayerExternal -Name $Name -FilePath "cargo" -ArgumentList (@("run", "--manifest-path", "crates/flowmemory-devnet/Cargo.toml", "--") + $RuntimeArgs)
    if ([int]$result.exitCode -ne 0) {
        throw "$Name failed."
    }
    $text = (@($result.output) -join [Environment]::NewLine)
    $jsonStart = $text.IndexOf("{")
    $jsonEnd = $text.LastIndexOf("}")
    if ($jsonStart -lt 0 -or $jsonEnd -lt $jsonStart) {
        throw "$Name did not emit JSON."
    }
    return $text.Substring($jsonStart, $jsonEnd - $jsonStart + 1) | ConvertFrom-Json
}

function Get-RelayerReportStatus {
    param([AllowNull()][object] $Report)
    if ($null -ne $Report -and $Report.PSObject.Properties.Name -contains "status") {
        return [string]$Report.status
    }
    return "missing"
}

function Get-ObjectMemberValue {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name
    )
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-ObjectKeys {
    param([AllowNull()][object] $Object)
    if ($null -eq $Object) { return @() }
    return @($Object.PSObject.Properties | ForEach-Object { $_.Name })
}

function Test-ObjectHasKey {
    param([AllowNull()][object] $Object, [string] $Name)
    if ($null -eq $Object) { return $false }
    return $Object.PSObject.Properties.Name -contains $Name
}

function Read-RelayerJson {
    param([Parameter(Mandatory = $true)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Write-FilteredBridgeHandoff {
    param(
        [Parameter(Mandatory = $true)][object] $Handoff,
        [Parameter(Mandatory = $true)][object[]] $Credits,
        [Parameter(Mandatory = $true)][string] $Path
    )

    $creditIds = @($Credits | ForEach-Object { "$($_.creditId)" })
    $observationIds = @($Credits | ForEach-Object { "$($_.observationId)" })
    $depositIds = @($Credits | ForEach-Object { "$($_.depositId)" })
    $replayKeys = @($Credits | ForEach-Object { "$($_.replayKey)" })
    $filtered = $Handoff | ConvertTo-Json -Depth 64 | ConvertFrom-Json
    $filtered.credits = @($Credits)
    $filtered.observations = @($Handoff.observations | Where-Object { $observationIds -contains "$($_.observationId)" -or $depositIds -contains "$($_.deposit.depositId)" })
    $filtered.runtimeApplications = @($Handoff.runtimeApplications | Where-Object { $creditIds -contains "$($_.creditId)" })
    $filtered.pilotEvidence = @($Handoff.pilotEvidence | Where-Object { $creditIds -contains "$($_.creditId)" })
    $filtered.withdrawalIntents = @($Handoff.withdrawalIntents | Where-Object { $creditIds -contains "$($_.creditId)" })
    $filtered.releaseEvidences = @($Handoff.releaseEvidences | Where-Object { $creditIds -contains "$($_.creditId)" })
    if ($null -ne $filtered.replayProtection) {
        $filtered.replayProtection.replayKeys = @($replayKeys)
        $filtered.replayProtection.duplicateReplayKeys = @()
    }
    Write-FlowChainJson -Path $Path -Value $filtered -Depth 64
}

function Wait-ForRelayerCredits {
    param(
        [Parameter(Mandatory = $true)][object[]] $Credits,
        [Parameter(Mandatory = $true)][string] $Path,
        [int] $TimeoutSeconds
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $applied = New-Object System.Collections.ArrayList
    do {
        $state = Read-RelayerJson -Path $Path
        if ($null -ne $state) {
            $allPresent = $true
            $applied.Clear()
            foreach ($credit in $Credits) {
                $creditId = "$($credit.creditId)"
                $replayKey = "$($credit.replayKey)"
                $record = Get-ObjectMemberValue -Object $state.bridgeCredits -Name $creditId
                $receipt = Get-ObjectMemberValue -Object $state.bridgeCreditReceipts -Name $creditId
                if ($null -eq $record -or $null -eq $receipt -or -not (Test-ObjectHasKey -Object $state.bridgeReplayIndex -Name $replayKey)) {
                    $allPresent = $false
                    break
                }
                [void]$applied.Add([ordered]@{
                    creditId = $creditId
                    replayKey = $replayKey
                    accountId = "$($record.accountId)"
                    amount = "$($credit.amount)"
                })
            }
            if ($allPresent) {
                return @($applied)
            }
        }
        if ($TimeoutSeconds -le 0) {
            break
        }
        Start-Sleep -Milliseconds 900
    } while ((Get-Date) -lt $deadline)

    return @($applied)
}

function Complete-RelayerRun {
    param([Parameter(Mandatory = $true)][string] $Status)

    $report = [ordered]@{
        schema = "flowchain.bridge_relayer_once_report.v0"
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        status = $Status
        mode = "base8453-pilot"
        queueDisabled = [bool]$NoQueue
        waitSeconds = $WaitSeconds
        readiness = $readiness
        counts = $counts
        ownerEnvFile = $ownerEnvState
        artifacts = $artifacts
        steps = @($steps)
        issues = @($issues)
        requiredEnvNames = @(
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
        command = "npm run flowchain:bridge:relayer:once"
        broadcasts = $false
        envValuesPrinted = $false
        noSecrets = $true
    }
    $reportText = $report | ConvertTo-Json -Depth 24
    Assert-FlowChainNoSecretText -Text $reportText -Label "bridge relayer once report"
    Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 24

    Write-Host "FlowChain bridge relayer once status: $Status"
    Write-Host "Observed credits: $($counts.observedCredits)"
    Write-Host "New credits: $($counts.newCredits)"
    Write-Host "Queued transactions: $($counts.queuedTransactions)"
    Write-Host "Applied credits: $($counts.appliedCredits)"
    Write-Host "Report: $reportFullPath"

    if ($Status -eq "passed" -or ($Status -eq "blocked" -and $AllowBlocked)) {
        exit 0
    }
    exit 1
}

try {
    $ownerEnvState = Get-FlowChainOwnerEnvFileState

    $infraResult = Invoke-RelayerExternal -Name "bridge-infra-readiness" -FilePath "powershell" -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-live-env-bridge-readiness.ps1"),
        "-ReportPath", $infraReportFullPath,
        "-AllowBlocked"
    ) -ExpectedReportPath $infraReportFullPath
    $infraReport = Read-RelayerJson -Path $infraReportFullPath
    $readiness.infra = Get-RelayerReportStatus -Report $infraReport
    if ($readiness.infra -ne "passed") {
        Add-RelayerIssue -Kind "external" -Code "bridge-infra-not-passed" -Owner "owner/operator" -Reason "Base 8453 bridge infra readiness is $($readiness.infra)."
        Complete-RelayerRun -Status $(if ($readiness.infra -eq "blocked") { "blocked" } else { "failed" })
    }
    if ([int]$infraResult.exitCode -ne 0) {
        Add-RelayerIssue -Kind "code" -Code "bridge-infra-command-failed" -Reason "Bridge infra readiness command failed unexpectedly."
        Complete-RelayerRun -Status "failed"
    }

    $liveResult = Invoke-RelayerExternal -Name "bridge-live-readiness" -FilePath "powershell" -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-live-check.ps1"),
        "-ReportPath", $liveReportFullPath,
        "-AllowBlocked"
    ) -ExpectedReportPath $liveReportFullPath
    $liveReport = Read-RelayerJson -Path $liveReportFullPath
    $readiness.live = Get-RelayerReportStatus -Report $liveReport
    if ($readiness.live -ne "passed") {
        Add-RelayerIssue -Kind "external" -Code "bridge-live-not-passed" -Owner "owner/operator" -Reason "Base 8453 bridge live readiness is $($readiness.live)."
        Complete-RelayerRun -Status $(if ($readiness.live -eq "blocked") { "blocked" } else { "failed" })
    }
    if ([int]$liveResult.exitCode -ne 0) {
        Add-RelayerIssue -Kind "code" -Code "bridge-live-command-failed" -Reason "Bridge live readiness command failed unexpectedly."
        Complete-RelayerRun -Status "failed"
    }

    $beforeState = Read-RelayerJson -Path $stateFullPath
    if ($null -eq $beforeState) {
        Add-RelayerIssue -Kind "code" -Code "state-unreadable" -Owner "runtime" -Reason "The FlowChain state file could not be read before bridge handoff queueing."
        Complete-RelayerRun -Status "failed"
    }
    $beforeCreditIds = Get-ObjectKeys -Object $beforeState.bridgeCredits
    $beforeReplayKeys = Get-ObjectKeys -Object $beforeState.bridgeReplayIndex

    $observeArgs = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "bridge-base-mainnet-pilot-observe.ps1"),
        "-ApplyCredit",
        "-RuntimeState", $runtimeStateFullPath,
        "-CursorState", $cursorStateFullPath,
        "-Out", $observationFullPath,
        "-CreditOut", $creditFullPath,
        "-HandoffOut", $handoffFullPath,
        "-EvidenceOut", $evidenceFullPath,
        "-ReportPath", (Join-Path $runFullDir "bridge-observe-base8453-report.json")
    )
    $observeResult = Invoke-RelayerExternal -Name "observe-base8453-and-build-handoff" -FilePath "powershell" -ArgumentList $observeArgs -ExpectedReportPath (Join-Path $runFullDir "bridge-observe-base8453-report.json")
    if ([int]$observeResult.exitCode -ne 0) {
        Add-RelayerIssue -Kind "external" -Code "base-observation-failed" -Owner "bridge-relayer/operator" -Reason "Base 8453 observation did not complete."
        Complete-RelayerRun -Status "blocked"
    }

    $handoff = Read-RelayerJson -Path $handoffFullPath
    if ($null -eq $handoff -or "$($handoff.schema)" -ne "flowmemory.bridge_runtime_handoff.v0") {
        Add-RelayerIssue -Kind "code" -Code "handoff-missing" -Reason "Base observation did not produce a bridge runtime handoff."
        Complete-RelayerRun -Status "failed"
    }

    $credits = @($handoff.credits | Where-Object { "$($_.status)" -ne "rejected" })
    $counts.observedCredits = $credits.Count
    $newCredits = @($credits | Where-Object {
        $beforeCreditIds -notcontains "$($_.creditId)" -and $beforeReplayKeys -notcontains "$($_.replayKey)"
    })
    $counts.newCredits = $newCredits.Count
    if ($newCredits.Count -eq 0) {
        Add-RelayerStep -Name "queue-new-bridge-credits" -Status "passed" -Reason "No new accepted credits were available after replay filtering."
        Complete-RelayerRun -Status "passed"
    }

    Write-FilteredBridgeHandoff -Handoff $handoff -Credits $newCredits -Path $filteredHandoffFullPath
    Add-RelayerStep -Name "filter-new-bridge-handoff" -Status "passed" -ReportPath $filteredHandoffFullPath

    if ($NoQueue.IsPresent) {
        Complete-RelayerRun -Status "passed"
    }

    $queueSummary = Invoke-RelayerCargoJson -Name "queue-new-bridge-credits" -RuntimeArgs @(
        "--state", $stateFullPath,
        "--node-dir", $nodeFullDir,
        "bridge-handoff",
        "--handoff", $filteredHandoffFullPath,
        "--authorized-by", $AuthorizedBy
    )
    $queued = @($queueSummary.queued)
    $counts.queuedTransactions = $queued.Count
    if ($queued.Count -lt 1) {
        Add-RelayerIssue -Kind "code" -Code "bridge-credit-not-queued" -Owner "runtime" -Reason "No runtime transactions were queued for new bridge credits."
        Complete-RelayerRun -Status "failed"
    }

    $applied = Wait-ForRelayerCredits -Credits $newCredits -Path $stateFullPath -TimeoutSeconds $WaitSeconds
    $counts.appliedCredits = @($applied).Count
    if ($counts.appliedCredits -ne $newCredits.Count) {
        Add-RelayerIssue -Kind "code" -Code "bridge-credit-not-applied" -Owner "runtime" -Reason "Queued bridge credits did not appear in the main L1 state before the wait timeout."
        Complete-RelayerRun -Status "failed"
    }

    Add-RelayerStep -Name "verify-bridge-credits-in-main-state" -Status "passed" -ReportPath $stateFullPath
    Complete-RelayerRun -Status "passed"
}
catch {
    Add-RelayerIssue -Kind "code" -Code "bridge-relayer-exception" -Reason (ConvertTo-RelayerSafeLine -Line $_.Exception.Message)
    Complete-RelayerRun -Status "failed"
}
