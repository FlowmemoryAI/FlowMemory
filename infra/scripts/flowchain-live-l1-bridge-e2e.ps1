param(
    [string] $ReportDir = "devnet/local/live-l1-bridge-e2e",
    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node",
    [string] $TxHash = $(if ($env:FLOWCHAIN_BASE8453_TX_HASH) { $env:FLOWCHAIN_BASE8453_TX_HASH } else { $env:FLOWCHAIN_BASE8453_OPERATOR_TX_HASH }),
    [int] $ConfirmationDepth = 2,
    [int] $TargetSettlementSeconds = 30,
    [int] $EstimatedBaseBlockSeconds = 2,
    [int] $BridgePollSeconds = 1,
    [bool] $RequirePublicLiveL1 = $true
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot -Purpose "live-l1-bridge-e2e" | Out-Null

$reportFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportDir)
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$nodeFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $NodeDir)
$logsDir = Join-Path $reportFullDir "logs"
$reportPath = Join-Path $reportFullDir "flowchain-live-l1-bridge-e2e-report.json"
$summaryPath = Join-Path $reportFullDir "flowchain-live-l1-bridge-e2e-summary.md"

$reportFullDir = Reset-FlowChainDirectory -Path $reportFullDir
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

$steps = New-Object System.Collections.ArrayList
$issues = New-Object System.Collections.ArrayList
$startedNode = $false
$controlPlaneStarted = $false
$confirmationEligibilityObservedAt = $null
$spendableCreditObservedAt = $null
$latencySeconds = $null
$selectedCreditIds = @()
$selectedReplayKeys = @()
$selectedTxHashes = @()
$selectedAccountId = ""
$recipientAccountId = ""
$transferId = ""
$stateRootAfterCredit = ""
$stateRootAfterTransfer = ""
$importedStateRoot = ""
$exportedStateRoot = ""
$rootComparePassed = $false
$nodeStatusBefore = $null
$nodeStatusAfter = $null
$chainStatus = $null
$bridgeLiveReadiness = $null
$dashboardFixtureFallback = $true
$notificationHook = [ordered]@{
    prepared = $true
    sent = $false
    reason = "notification hook intentionally does not send until completion status changes to PASS"
}

function Import-LivePilotEnvLoaderIfConfigured {
    $loaderPath = [Environment]::GetEnvironmentVariable("FLOWCHAIN_LIVE_PILOT_ENV_LOADER", "Process")
    if ([string]::IsNullOrWhiteSpace($loaderPath)) {
        return [ordered]@{ configured = $false; imported = $false; problem = "" }
    }
    $fullLoaderPath = [System.IO.Path]::GetFullPath($loaderPath)
    if (-not (Test-Path -LiteralPath $fullLoaderPath)) {
        throw "FLOWCHAIN_LIVE_PILOT_ENV_LOADER points to a missing file."
    }
    if ([System.IO.Path]::GetExtension($fullLoaderPath) -ne ".ps1") {
        throw "FLOWCHAIN_LIVE_PILOT_ENV_LOADER must point to a PowerShell loader script."
    }
    . $fullLoaderPath
    return [ordered]@{ configured = $true; imported = $true; problem = "" }
}

function Add-Step {
    param(
        [string] $Name,
        [string] $Status,
        [string] $Owner,
        [string] $LogPath = "",
        [string] $ReportPath = "",
        [string] $Reason = ""
    )
    [void] $steps.Add([ordered]@{
        name = $Name
        status = $Status
        owner = $Owner
        logPath = $LogPath
        reportPath = $ReportPath
        reason = $Reason
        at = (Get-Date).ToUniversalTime().ToString("o")
    })
}

function Add-Issue {
    param(
        [ValidateSet("code", "external")]
        [string] $Kind,
        [string] $Code,
        [string] $Reason,
        [string] $Owner = "hq"
    )
    [void] $issues.Add([ordered]@{
        kind = $Kind
        code = $Code
        reason = $Reason
        owner = $Owner
    })
}

function Get-SafeName {
    param([string] $Name)
    return (($Name -replace '[^A-Za-z0-9_.-]', '-') -replace '-+', '-').Trim("-")
}

function Invoke-LoggedExternal {
    param(
        [string] $Name,
        [string] $Owner,
        [string] $FilePath,
        [string[]] $ArgumentList = @(),
        [switch] $AllowFailure,
        [string] $ExpectedReportPath = ""
    )
    $safe = Get-SafeName -Name $Name
    $logPath = Join-Path $logsDir "$safe.log"
    Write-Host ""
    Write-Host "== $Name =="

    $previousErrorActionPreference = $ErrorActionPreference
    $script:ErrorActionPreference = "Continue"
    try {
        $output = (& $FilePath @ArgumentList 2>&1) | ForEach-Object { "$_" }
        $exitCode = $LASTEXITCODE
    }
    catch {
        $output = @($_.Exception.Message)
        $exitCode = 1
    }
    finally {
        $script:ErrorActionPreference = $previousErrorActionPreference
    }
    $output | Set-Content -LiteralPath $logPath -Encoding utf8

    $status = if ($exitCode -eq 0) { "passed" } elseif ($AllowFailure) { "blocked" } else { "failed" }
    $reason = if ($status -eq "passed") { "" } else { (($output | Select-Object -Last 8) -join [Environment]::NewLine) }
    Add-Step -Name $Name -Status $status -Owner $Owner -LogPath $logPath -ReportPath $ExpectedReportPath -Reason $reason
    Write-Host "$($status.ToUpperInvariant()): $Name"
    return [ordered]@{ status = $status; exitCode = $exitCode; logPath = $logPath; output = $output; reportPath = $ExpectedReportPath }
}

function Invoke-CargoJson {
    param(
        [string] $Name,
        [string[]] $RuntimeArgs
    )
    $result = Invoke-LoggedExternal -Name $Name -Owner "runtime" -FilePath "cargo" -ArgumentList (@("run", "--manifest-path", "crates/flowmemory-devnet/Cargo.toml", "--") + $RuntimeArgs)
    if ($result.status -ne "passed") {
        throw "$Name failed."
    }
    $text = ($result.output -join [Environment]::NewLine)
    $jsonStart = $text.IndexOf("{")
    $jsonEnd = $text.LastIndexOf("}")
    if ($jsonStart -lt 0 -or $jsonEnd -lt $jsonStart) {
        throw "$Name did not emit JSON."
    }
    return $text.Substring($jsonStart, $jsonEnd - $jsonStart + 1) | ConvertFrom-Json
}

function Read-JsonIfExists {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
        }
        catch {
            Start-Sleep -Milliseconds (100 * $attempt)
        }
    }
    return $null
}

function Get-ObjectMemberValue {
    param(
        [AllowNull()][object] $Object,
        [string] $Name
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
    return ($Object.PSObject.Properties.Name -contains $Name)
}

function Get-LocalBalanceUnits {
    param([AllowNull()][object] $State, [string] $AccountId)
    if ($null -eq $State -or [string]::IsNullOrWhiteSpace($AccountId)) { return [UInt64] 0 }
    $balance = Get-ObjectMemberValue -Object $State.localTestUnitBalances -Name $AccountId
    if ($null -eq $balance -or -not ($balance.PSObject.Properties.Name -contains "units")) { return [UInt64] 0 }
    return [UInt64] $balance.units
}

function Get-FirstAppliedReceiptForTx {
    param([object] $State, [string] $TxId)
    foreach ($block in @($State.blocks)) {
        foreach ($receipt in @($block.receipts)) {
            if ($null -ne $receipt -and "$($receipt.txId)" -eq $TxId -and "$($receipt.status)" -eq "applied") {
                return $receipt
            }
        }
    }
    return $null
}

function Get-NodeStatusJson {
    return Invoke-CargoJson -Name "Inspect node status" -RuntimeArgs @("--state", $stateFullPath, "--node-dir", $nodeFullDir, "node-status")
}

function Get-NodeRuntimeStatusPath {
    return (Join-Path $nodeFullDir "status.json")
}

function Get-NodePidPath {
    return (Join-Path $nodeFullDir "flowchain-node.pid")
}

function Read-NodeRuntimeStatus {
    return Read-JsonIfExists -Path (Get-NodeRuntimeStatusPath)
}

function Read-NodePid {
    $pidPath = Get-NodePidPath
    if (-not (Test-Path -LiteralPath $pidPath)) {
        return ""
    }
    return (Get-Content -Raw -LiteralPath $pidPath).Trim()
}

function New-NodeStatusRecord {
    param([AllowNull()][object] $RuntimeStatus)
    return [ordered]@{
        schema = "flowchain.live_l1_bridge.node_runtime_status_record.v0"
        statePath = $stateFullPath
        nodeDir = $nodeFullDir
        stopRequested = Test-Path -LiteralPath (Join-Path $nodeFullDir "stop")
        persistedStatus = $RuntimeStatus
        source = Get-NodeRuntimeStatusPath
    }
}

function Test-ProcessAlive {
    param([AllowNull()][object] $PidValue)
    if ($null -eq $PidValue -or "$PidValue" -notmatch '^[0-9]+$') { return $false }
    return $null -ne (Get-Process -Id ([int] "$PidValue") -ErrorAction SilentlyContinue)
}

function Start-UnboundedNodeDirect {
    $nodeCargoTargetDir = Join-Path $repoRoot "devnet/local/cargo-target/live-l1-node-$PID"
    New-Item -ItemType Directory -Force -Path $nodeCargoTargetDir | Out-Null

    $previousCargoTargetDir = [Environment]::GetEnvironmentVariable("CARGO_TARGET_DIR", "Process")
    $env:CARGO_TARGET_DIR = $nodeCargoTargetDir
    try {
        $buildResult = Invoke-LoggedExternal -Name "Build FlowChain node binary for live gate" -Owner "runtime" -FilePath "cargo" -ArgumentList @(
            "build",
            "--manifest-path",
            "crates/flowmemory-devnet/Cargo.toml"
        )
    }
    finally {
        if ($null -eq $previousCargoTargetDir) {
            Remove-Item Env:\CARGO_TARGET_DIR -ErrorAction SilentlyContinue
        }
        else {
            $env:CARGO_TARGET_DIR = $previousCargoTargetDir
        }
    }

    if ($buildResult.status -ne "passed") {
        Add-Issue -Kind "code" -Code "node-build-failed" -Owner "runtime" -Reason "The FlowChain node binary could not be built for the live L1 bridge gate."
        return ""
    }

    $binaryName = if ($env:OS -eq "Windows_NT") { "flowmemory-devnet.exe" } else { "flowmemory-devnet" }
    $binaryPath = Join-Path (Join-Path $nodeCargoTargetDir "debug") $binaryName
    if (-not (Test-Path -LiteralPath $binaryPath)) {
        Add-Issue -Kind "code" -Code "node-binary-missing" -Owner "runtime" -Reason "The built FlowChain node binary was not found after cargo build."
        return ""
    }

    $nodeLogsDir = Join-Path $nodeFullDir "logs"
    New-Item -ItemType Directory -Force -Path $nodeLogsDir | Out-Null
    $stdoutPath = Join-Path $nodeLogsDir "node.stdout.jsonl"
    $stderrPath = Join-Path $nodeLogsDir "node.stderr.log"
    $pidPath = Get-NodePidPath
    $startReportPath = Join-Path $nodeFullDir "flowchain-node-start-report.json"
    $stopPath = Join-Path $nodeFullDir "stop"
    if (Test-Path -LiteralPath $stopPath) {
        Remove-Item -LiteralPath $stopPath -Force
    }

    $arguments = @(
        "--state", $stateFullPath,
        "--node-dir", $nodeFullDir,
        "node",
        "--node-id", "node:local:alpha",
        "--block-ms", "1000"
    )

    try {
        $process = Start-Process -FilePath $binaryPath `
            -ArgumentList (Join-FlowChainProcessArguments -ArgumentList $arguments) `
            -WorkingDirectory $repoRoot `
            -PassThru `
            -WindowStyle Hidden `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath
    }
    catch {
        Add-Step -Name "Start unbounded FlowChain node" -Status "failed" -Owner "runtime" -LogPath $stderrPath -ReportPath $startReportPath -Reason $_.Exception.Message
        Add-Issue -Kind "code" -Code "node-start-failed" -Owner "runtime" -Reason "The FlowChain node process could not be started."
        return ""
    }

    Set-Content -LiteralPath $pidPath -Value "$($process.Id)"
    Write-FlowChainJson -Path $startReportPath -Value ([ordered]@{
        schema = "flowchain.private_testnet.node_start_report.v0"
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        status = "started"
        pid = $process.Id
        exitCode = $null
        statePath = $stateFullPath
        nodeDir = $nodeFullDir
        nodeId = "node:local:alpha"
        blockMs = 1000
        maxBlocks = 0
        waited = $false
        stdoutLog = $stdoutPath
        stderrLog = $stderrPath
        pidPath = $pidPath
        stopCommand = "npm run flowchain:node:stop"
        statusCommand = "npm run flowchain:node:status"
        logsCommand = "npm run flowchain:node:logs"
    }) -Depth 12

    Add-Step -Name "Start unbounded FlowChain node" -Status "passed" -Owner "runtime" -LogPath $stdoutPath -ReportPath $startReportPath
    Write-Host "PASSED: Start unbounded FlowChain node"
    return "$($process.Id)"
}

function Ensure-UnboundedNodeRunning {
    $status = Get-NodeStatusJson
    $script:nodeStatusBefore = $status
    $runtimeStatus = Read-NodeRuntimeStatus
    $persisted = if ($null -ne $runtimeStatus) { $runtimeStatus } else { $status.persistedStatus }
    $persistedState = if ($null -ne $persisted -and ($persisted.PSObject.Properties.Name -contains "status")) { "$($persisted.status)" } else { "missing" }
    $processAlive = $false
    if ($null -ne $persisted -and ($persisted.PSObject.Properties.Name -contains "pid")) {
        $processAlive = Test-ProcessAlive -PidValue $persisted.pid
    }

    if ($persistedState -eq "running" -and $processAlive -and -not [bool] $status.stopRequested) {
        Add-Step -Name "Verify unbounded node already running" -Status "passed" -Owner "runtime"
        $script:nodeStatusAfter = New-NodeStatusRecord -RuntimeStatus $runtimeStatus
        return
    }

    $startedPid = Start-UnboundedNodeDirect
    $script:startedNode = $true

    $expectedPid = if ([string]::IsNullOrWhiteSpace($startedPid)) { Read-NodePid } else { $startedPid }
    $deadline = (Get-Date).AddSeconds(35)
    do {
        Start-Sleep -Milliseconds 800
        $runtimeStatus = Read-NodeRuntimeStatus
        $persistedState = if ($null -ne $runtimeStatus -and ($runtimeStatus.PSObject.Properties.Name -contains "status")) { "$($runtimeStatus.status)" } else { "missing" }
        $statusPid = if ($null -ne $runtimeStatus -and ($runtimeStatus.PSObject.Properties.Name -contains "pid")) { "$($runtimeStatus.pid)" } else { "" }
        $pidToCheck = if (-not [string]::IsNullOrWhiteSpace($expectedPid)) { $expectedPid } else { $statusPid }
        $processAlive = Test-ProcessAlive -PidValue $pidToCheck
        if (-not $processAlive) {
            $latestPid = Read-NodePid
            if (-not [string]::IsNullOrWhiteSpace($latestPid) -and $latestPid -ne $pidToCheck) {
                $expectedPid = $latestPid
                $pidToCheck = $latestPid
                $processAlive = Test-ProcessAlive -PidValue $pidToCheck
            }
        }
        $pidMatchesStatus = [string]::IsNullOrWhiteSpace($statusPid) -or [string]::IsNullOrWhiteSpace($expectedPid) -or $statusPid -eq $expectedPid
        $stopRequested = Test-Path -LiteralPath (Join-Path $nodeFullDir "stop")
        if ($persistedState -eq "running" -and $processAlive -and $pidMatchesStatus -and -not $stopRequested) {
            Add-Step -Name "Verify unbounded node running after start" -Status "passed" -Owner "runtime"
            $script:nodeStatusAfter = New-NodeStatusRecord -RuntimeStatus $runtimeStatus
            return
        }
    } while ((Get-Date) -lt $deadline)

    Add-Issue -Kind "code" -Code "node-not-running" -Owner "runtime" -Reason "FlowChain node was not running unbounded after start attempt."
}

function Write-FilteredHandoff {
    param(
        [object] $Handoff,
        [object[]] $Credits,
        [string] $Path
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

function Wait-ForCreditsSpendable {
    param([object[]] $Credits)
    $deadline = (Get-Date).AddSeconds(55)
    do {
        Start-Sleep -Milliseconds 900
        $state = Read-JsonIfExists -Path $stateFullPath
        if ($null -eq $state) { continue }

        $allPresent = $true
        foreach ($credit in $Credits) {
            $creditId = "$($credit.creditId)"
            $replayKey = "$($credit.replayKey)"
            $record = Get-ObjectMemberValue -Object $state.bridgeCredits -Name $creditId
            $receipt = Get-ObjectMemberValue -Object $state.bridgeCreditReceipts -Name $creditId
            if ($null -eq $record -or $null -eq $receipt -or -not (Test-ObjectHasKey -Object $state.bridgeReplayIndex -Name $replayKey)) {
                $allPresent = $false
                break
            }
            $accountId = "$($record.accountId)"
            $balance = Get-LocalBalanceUnits -State $state -AccountId $accountId
            if ($balance -lt ([UInt64] "$($credit.amount)")) {
                $allPresent = $false
                break
            }
            $script:selectedAccountId = $accountId
        }
        if ($allPresent) {
            $summary = Invoke-CargoJson -Name "Inspect post-credit main state" -RuntimeArgs @("--state", $stateFullPath, "inspect-state", "--summary")
            $script:stateRootAfterCredit = "$($summary.stateRoot)"
            $script:spendableCreditObservedAt = Get-Date
            return $state
        }
    } while ((Get-Date) -lt $deadline)
    return $null
}

function Wait-ForTransferApplied {
    param([string] $TransferTxId, [string] $Recipient, [UInt64] $Amount)
    $deadline = (Get-Date).AddSeconds(55)
    do {
        Start-Sleep -Milliseconds 900
        $state = Read-JsonIfExists -Path $stateFullPath
        if ($null -eq $state) { continue }
        $receipt = Get-FirstAppliedReceiptForTx -State $state -TxId $TransferTxId
        $recipientBalance = Get-LocalBalanceUnits -State $state -AccountId $Recipient
        $transfer = Get-ObjectMemberValue -Object $state.balanceTransfers -Name $script:transferId
        if ($null -ne $receipt -and $recipientBalance -ge $Amount -and $null -ne $transfer) {
            $summary = Invoke-CargoJson -Name "Inspect post-transfer main state" -RuntimeArgs @("--state", $stateFullPath, "inspect-state", "--summary")
            $script:stateRootAfterTransfer = "$($summary.stateRoot)"
            return $state
        }
    } while ((Get-Date) -lt $deadline)
    return $null
}

function Start-ControlPlaneIfNeeded {
    $healthUrl = "http://127.0.0.1:8787/health"
    try {
        $health = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 2
        if ($null -ne $health) {
            Add-Step -Name "Verify control-plane API available" -Status "passed" -Owner "control-plane"
            return
        }
    }
    catch {
        # Start the local API below.
    }

    $stdout = Join-Path $logsDir "control-plane.stdout.log"
    $stderr = Join-Path $logsDir "control-plane.stderr.log"
    $npmPath = (Get-Command "npm" -ErrorAction Stop).Source
    Start-Process -FilePath $npmPath `
        -ArgumentList (Join-FlowChainProcessArguments -ArgumentList @("run", "control-plane:serve")) `
        -WorkingDirectory $repoRoot `
        -PassThru `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr | Out-Null
    $script:controlPlaneStarted = $true

    $deadline = (Get-Date).AddSeconds(25)
    do {
        Start-Sleep -Milliseconds 800
        try {
            $health = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 2
            if ($null -ne $health) {
                Add-Step -Name "Start control-plane API for dashboard live mode" -Status "passed" -Owner "control-plane" -LogPath $stdout
                return
            }
        }
        catch {
        }
    } while ((Get-Date) -lt $deadline)

    Add-Issue -Kind "code" -Code "control-plane-unavailable" -Owner "control-plane" -Reason "Dashboard would remain fixture fallback because the local control-plane API did not become reachable."
}

function Write-FinalReport {
    param([string] $Status)
    $report = [ordered]@{
        schema = "flowchain.live_l1_bridge_e2e_report.v0"
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        status = $Status
        repoPath = $repoRoot
        branch = (& git rev-parse --abbrev-ref HEAD).Trim()
        commit = (& git rev-parse HEAD).Trim()
        standard = "A user can bridge a small amount of real ETH from Base 8453 into FlowChain, wait no more than $TargetSettlementSeconds seconds after confirmation eligibility, see the credit in the running FlowChain L1 node state, and spend/transfer it on FlowChain. Nothing required for that path is mock-only."
        confirmationDepthRequired = $ConfirmationDepth
        settlementTargetSeconds = $TargetSettlementSeconds
        estimatedBaseBlockSeconds = $EstimatedBaseBlockSeconds
        bridgePollSeconds = $BridgePollSeconds
        requirePublicLiveL1 = $RequirePublicLiveL1
        livePilotEnvLoader = $livePilotEnvLoader
        node = [ordered]@{
            statePath = $stateFullPath
            nodeDir = $nodeFullDir
            startedByGate = $startedNode
            statusBefore = $nodeStatusBefore
            statusAfter = $nodeStatusAfter
        }
        bridge = [ordered]@{
            txHashSupplied = -not [string]::IsNullOrWhiteSpace($TxHash)
            observedTxHashes = @($selectedTxHashes)
            creditIds = @($selectedCreditIds)
            replayKeys = @($selectedReplayKeys)
            creditedAccountId = $selectedAccountId
            recipientAccountId = $recipientAccountId
            transferId = $transferId
            latencySecondsFromConfirmationEligibilityToSpendableCredit = $latencySeconds
        }
        roots = [ordered]@{
            stateRootAfterCredit = $stateRootAfterCredit
            stateRootAfterTransfer = $stateRootAfterTransfer
            exportedStateRoot = $exportedStateRoot
            importedStateRoot = $importedStateRoot
            exportImportRootsMatch = $rootComparePassed
        }
        readiness = [ordered]@{
            chainStatus = $chainStatus
            bridgeLiveReadiness = $bridgeLiveReadiness
            dashboardFixtureFallback = $dashboardFixtureFallback
            releaseAutomation = "absent; release evidence is separate and broadcast remains false"
            releaseAutomationImplied = $false
            latencyMeasured = $null -ne $latencySeconds
        }
        artifacts = [ordered]@{
            reportDir = $reportFullDir
            bridgeLiveReadinessReport = Join-Path $reportFullDir "bridge-live-readiness-report.json"
            baseTxDiagnostic = Join-Path $reportFullDir "base-tx-diagnostic.json"
            bridgeObservation = Join-Path $reportFullDir "base8453-observation.json"
            bridgeCredit = Join-Path $reportFullDir "base8453-credit.json"
            bridgeHandoff = Join-Path $reportFullDir "base8453-handoff.json"
            filteredBridgeHandoff = Join-Path $reportFullDir "base8453-handoff-new-credits-only.json"
            bridgeEvidence = Join-Path $reportFullDir "base8453-evidence.json"
            transferTxs = Join-Path $reportFullDir "spend-transfer-txs.json"
            snapshot = Join-Path $reportFullDir "snapshot.json"
            importedState = Join-Path $reportFullDir "imported-state.json"
        }
        steps = @($steps)
        issues = @($issues)
        notificationHook = $notificationHook
        broadcasts = $false
        printsEnvValues = $false
        noSecrets = $true
    }
    Write-FlowChainJson -Path $reportPath -Value $report -Depth 32

    @(
        "# FlowChain live-l1-bridge:e2e Summary",
        "",
        "- Status: $Status",
        "- Report: $reportPath",
        "- Confirmation depth: $ConfirmationDepth",
        "- Settlement target seconds: $TargetSettlementSeconds",
        "- Latency seconds: $(if ($null -eq $latencySeconds) { 'unmeasured' } else { $latencySeconds })",
        "- Credits in main state: $($selectedCreditIds.Count)",
        "- Export/import roots match: $rootComparePassed",
        "",
        "## Issues",
        $(if ($issues.Count -eq 0) { "- None." } else { @($issues | ForEach-Object { "- $($_.kind): $($_.code) - $($_.reason)" }) })
    ) | ForEach-Object {
        if ($_ -is [System.Array]) { $_ } else { "$_" }
    } | Set-Content -LiteralPath $summaryPath -Encoding utf8
}

$livePilotEnvLoader = Import-LivePilotEnvLoaderIfConfigured
Write-Host "FlowChain live-l1-bridge:e2e gate starting."
Write-Host "Report directory: $reportFullDir"
Write-Host "Live env values are not printed by this gate."

Ensure-UnboundedNodeRunning

$requiredEnv = @(
    "FLOWCHAIN_PILOT_OPERATOR_ACK",
    "FLOWCHAIN_BASE8453_RPC_URL",
    "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
    "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
    "FLOWCHAIN_BASE8453_ASSET_DECIMALS",
    "FLOWCHAIN_BASE8453_FROM_BLOCK",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI"
)
$missingEnv = @($requiredEnv | Where-Object { [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_, "Process")) })
if ($missingEnv.Count -gt 0) {
    Add-Issue -Kind "external" -Code "missing-live-env" -Owner "owner/operator" -Reason "Missing required live Base env names: $($missingEnv -join ', ')"
    Write-FinalReport -Status "EXTERNAL-BLOCKED"
    throw "FlowChain live-l1-bridge:e2e is EXTERNAL-BLOCKED. See $reportPath"
}

$requiredAck = "I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
if ([Environment]::GetEnvironmentVariable("FLOWCHAIN_PILOT_OPERATOR_ACK", "Process") -ne $requiredAck) {
    Add-Issue -Kind "external" -Code "operator-ack-mismatch" -Owner "owner/operator" -Reason "FLOWCHAIN_PILOT_OPERATOR_ACK is not the required exact acknowledgement string."
    Write-FinalReport -Status "EXTERNAL-BLOCKED"
    throw "FlowChain live-l1-bridge:e2e is EXTERNAL-BLOCKED. See $reportPath"
}

$previousConfirmations = [Environment]::GetEnvironmentVariable("FLOWCHAIN_PILOT_CONFIRMATIONS", "Process")
$previousConfirmationDepthAlias = [Environment]::GetEnvironmentVariable("FLOWCHAIN_BASE8453_CONFIRMATION_DEPTH", "Process")
$previousTargetSettlementSeconds = [Environment]::GetEnvironmentVariable("FLOWCHAIN_BRIDGE_TARGET_SETTLEMENT_SECONDS", "Process")
$previousEstimatedBaseBlockSeconds = [Environment]::GetEnvironmentVariable("FLOWCHAIN_BASE8453_ESTIMATED_BLOCK_SECONDS", "Process")
$previousBridgePollSeconds = [Environment]::GetEnvironmentVariable("FLOWCHAIN_BRIDGE_POLL_SECONDS", "Process")
$env:FLOWCHAIN_PILOT_CONFIRMATIONS = "$ConfirmationDepth"
$env:FLOWCHAIN_BASE8453_CONFIRMATION_DEPTH = "$ConfirmationDepth"
$env:FLOWCHAIN_BRIDGE_TARGET_SETTLEMENT_SECONDS = "$TargetSettlementSeconds"
$env:FLOWCHAIN_BASE8453_ESTIMATED_BLOCK_SECONDS = "$EstimatedBaseBlockSeconds"
$env:FLOWCHAIN_BRIDGE_POLL_SECONDS = "$BridgePollSeconds"

try {
    $beforeState = Read-JsonIfExists -Path $stateFullPath
    $beforeCreditIds = if ($null -eq $beforeState) { @() } else { Get-ObjectKeys -Object $beforeState.bridgeCredits }
    $beforeReplayKeys = if ($null -eq $beforeState) { @() } else { Get-ObjectKeys -Object $beforeState.bridgeReplayIndex }

    $bridgeLiveReadinessPath = Join-Path $reportFullDir "bridge-live-readiness-report.json"
    Invoke-LoggedExternal -Name "Bridge live readiness check at $ConfirmationDepth confirmations / $TargetSettlementSeconds sec target" -Owner "bridge/ops" -FilePath "powershell" -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-live-check.ps1"),
        "-ReportPath", $bridgeLiveReadinessPath,
        "-AllowBlocked"
    ) -ExpectedReportPath $bridgeLiveReadinessPath | Out-Null
    $bridgeLiveCheckReport = Read-JsonIfExists -Path $bridgeLiveReadinessPath
    if ($null -eq $bridgeLiveCheckReport -or "$($bridgeLiveCheckReport.status)" -ne "passed") {
        Add-Issue -Kind "external" -Code "bridge-live-readiness-not-passed" -Owner "owner/operator" -Reason "Base live readiness did not pass using the $ConfirmationDepth-confirmation / $TargetSettlementSeconds-second policy."
        Write-FinalReport -Status "EXTERNAL-BLOCKED"
        throw "FlowChain live-l1-bridge:e2e is EXTERNAL-BLOCKED. See $reportPath"
    }

    $diagnosticPath = Join-Path $reportFullDir "base-tx-diagnostic.json"
    if (-not [string]::IsNullOrWhiteSpace($TxHash)) {
        $env:FLOWCHAIN_BASE8453_TX_HASH = $TxHash
        Invoke-LoggedExternal -Name "Diagnostic for operator-provided Base tx hash" -Owner "bridge/ops" -FilePath "node" -ArgumentList @(
            "services/bridge-relayer/src/diagnose-base8453-tx.ts",
            "--confirmations", "$ConfirmationDepth",
            "--target-settlement-seconds", "$TargetSettlementSeconds",
            "--estimated-base-block-seconds", "$EstimatedBaseBlockSeconds",
            "--poll-seconds", "$BridgePollSeconds",
            "--out", $diagnosticPath
        ) -AllowFailure -ExpectedReportPath $diagnosticPath | Out-Null
        $diagnostic = Read-JsonIfExists -Path $diagnosticPath
        if ($null -eq $diagnostic -or "$($diagnostic.status)" -ne "valid") {
            $safeReason = if ($null -ne $diagnostic -and ($diagnostic.PSObject.Properties.Name -contains "safeReasonCode")) { "$($diagnostic.safeReasonCode)" } else { "diagnostic-missing" }
            Add-Issue -Kind "external" -Code "operator-tx-invalid" -Owner "owner/operator" -Reason "Operator-provided tx hash did not pass the safe diagnostic: $safeReason"
            Write-FinalReport -Status "EXTERNAL-BLOCKED"
            throw "FlowChain live-l1-bridge:e2e is EXTERNAL-BLOCKED. See $reportPath"
        }
    }
    else {
        Write-FlowChainJson -Path $diagnosticPath -Value ([ordered]@{
            schema = "flowchain.bridge_base8453_tx_diagnostic.v0"
            status = "not-run"
            safeReasonCode = "no-operator-tx-hash-supplied"
            broadcasts = $false
            printsEnvValues = $false
            noSecrets = $true
        })
    }

    $observationPath = Join-Path $reportFullDir "base8453-observation.json"
    $creditPath = Join-Path $reportFullDir "base8453-credit.json"
    $handoffPath = Join-Path $reportFullDir "base8453-handoff.json"
    $evidencePath = Join-Path $reportFullDir "base8453-evidence.json"
    $relayerRuntimeStatePath = Join-Path $reportFullDir "relayer-credit-application-state.json"
    $observeReportPath = Join-Path $reportFullDir "bridge-observe-base8453-report.json"
    $observeResult = Invoke-LoggedExternal -Name "Observe Base 8453 bridge deposit and build handoff" -Owner "bridge-relayer" -FilePath "powershell" -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "bridge-base-mainnet-pilot-observe.ps1"),
        "-Confirmations", "$ConfirmationDepth",
        "-ApplyCredit",
        "-RuntimeState", $relayerRuntimeStatePath,
        "-Out", $observationPath,
        "-CreditOut", $creditPath,
        "-HandoffOut", $handoffPath,
        "-EvidenceOut", $evidencePath,
        "-ReportPath", $observeReportPath
    ) -AllowFailure -ExpectedReportPath $observeReportPath
    if ($observeResult.status -ne "passed") {
        Add-Issue -Kind "external" -Code "base-observation-failed" -Owner "bridge-relayer/operator" -Reason "Base 8453 observer did not complete. See the sanitized observer log."
        Write-FinalReport -Status "EXTERNAL-BLOCKED"
        throw "FlowChain live-l1-bridge:e2e is EXTERNAL-BLOCKED. See $reportPath"
    }
    $confirmationEligibilityObservedAt = Get-Date

    $handoff = Read-JsonIfExists -Path $handoffPath
    if ($null -eq $handoff -or "$($handoff.schema)" -ne "flowmemory.bridge_runtime_handoff.v0") {
        Add-Issue -Kind "code" -Code "handoff-missing" -Owner "bridge-relayer" -Reason "Base observation did not produce a bridge runtime handoff."
        Write-FinalReport -Status "CODE-BLOCKED"
        throw "FlowChain live-l1-bridge:e2e is CODE-BLOCKED. See $reportPath"
    }

    $candidateCredits = @($handoff.credits | Where-Object {
        "$($_.status)" -ne "rejected" -and
        $beforeCreditIds -notcontains "$($_.creditId)" -and
        $beforeReplayKeys -notcontains "$($_.replayKey)" -and
        ([string]::IsNullOrWhiteSpace($TxHash) -or "$($_.source.txHash)".ToLowerInvariant() -eq $TxHash.ToLowerInvariant())
    })
    if ($candidateCredits.Count -lt 1) {
        Add-Issue -Kind "external" -Code "no-new-live-credit" -Owner "owner/operator" -Reason "No new Base 8453 bridge credit was available for this gate after replay filtering."
        Write-FinalReport -Status "EXTERNAL-BLOCKED"
        throw "FlowChain live-l1-bridge:e2e is EXTERNAL-BLOCKED. See $reportPath"
    }

    $selectedCreditIds = @($candidateCredits | ForEach-Object { "$($_.creditId)" })
    $selectedReplayKeys = @($candidateCredits | ForEach-Object { "$($_.replayKey)" })
    $selectedTxHashes = @($candidateCredits | ForEach-Object { "$($_.source.txHash)" } | Select-Object -Unique)

    $filteredHandoffPath = Join-Path $reportFullDir "base8453-handoff-new-credits-only.json"
    Write-FilteredHandoff -Handoff $handoff -Credits $candidateCredits -Path $filteredHandoffPath

    $queueSummary = Invoke-CargoJson -Name "Queue new live bridge credits into running node inbox" -RuntimeArgs @(
        "--state", $stateFullPath,
        "--node-dir", $nodeFullDir,
        "bridge-handoff",
        "--handoff", $filteredHandoffPath,
        "--authorized-by", "operator:live-l1-bridge:e2e"
    )
    $queuedCreditTxIds = @($queueSummary.queued | ForEach-Object { "$_" })
    if ($queuedCreditTxIds.Count -lt 1) {
        Add-Issue -Kind "code" -Code "bridge-credit-not-queued" -Owner "runtime" -Reason "No runtime transactions were queued for new live bridge credits."
    }

    $postCreditState = Wait-ForCreditsSpendable -Credits $candidateCredits
    if ($null -eq $postCreditState) {
        Add-Issue -Kind "code" -Code "live-credit-not-spendable-in-main-state" -Owner "runtime" -Reason "Live bridge credit did not become spendable in devnet/local/state.json within the gate timeout."
        Write-FinalReport -Status "CODE-BLOCKED"
        throw "FlowChain live-l1-bridge:e2e is CODE-BLOCKED. See $reportPath"
    }

    $latencySeconds = [Math]::Round((New-TimeSpan -Start $confirmationEligibilityObservedAt -End $spendableCreditObservedAt).TotalSeconds, 3)
    if ($latencySeconds -gt $TargetSettlementSeconds) {
        Add-Issue -Kind "code" -Code "latency-over-target" -Owner "runtime/bridge" -Reason "Spendable credit latency after confirmation eligibility was $latencySeconds seconds; target is $TargetSettlementSeconds seconds."
    }

    $firstCredit = $candidateCredits[0]
    $transferAmount = [UInt64] 1
    $stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmssfff")
    $recipientAccountId = "local-account:live-l1-bridge-recipient:$stamp"
    $transferId = "transfer:live-l1-bridge:$stamp"
    $transferTxPath = Join-Path $reportFullDir "spend-transfer-txs.json"
    Write-FlowChainJson -Path $transferTxPath -Value ([ordered]@{
        schema = "flowmemory.local_devnet.live_l1_bridge_transfer_txs.v0"
        txs = @(
            [ordered]@{
                type = "CreateLocalTestUnitBalance"
                accountId = $recipientAccountId
                owner = "operator:live-l1-bridge-recipient"
            },
            [ordered]@{
                type = "TransferLocalTestUnits"
                transferId = $transferId
                fromAccountId = $selectedAccountId
                toAccountId = $recipientAccountId
                amountUnits = $transferAmount
                memo = "live Base bridge credited balance transfer"
            }
        )
    }) -Depth 12

    $transferQueue = Invoke-CargoJson -Name "Queue one-unit spend from credited account" -RuntimeArgs @(
        "--state", $stateFullPath,
        "--node-dir", $nodeFullDir,
        "submit-tx",
        "--tx-file", $transferTxPath,
        "--authorized-by", "operator:live-l1-bridge:e2e"
    )
    $transferTxId = "$(@($transferQueue.queued)[-1])"
    $postTransferState = Wait-ForTransferApplied -TransferTxId $transferTxId -Recipient $recipientAccountId -Amount $transferAmount
    if ($null -eq $postTransferState) {
        Add-Issue -Kind "code" -Code "credited-balance-transfer-failed" -Owner "runtime" -Reason "The credited account did not spend/transfer one smallest unit within the gate timeout."
        Write-FinalReport -Status "CODE-BLOCKED"
        throw "FlowChain live-l1-bridge:e2e is CODE-BLOCKED. See $reportPath"
    }

    $snapshotPath = Join-Path $reportFullDir "snapshot.json"
    $importedStatePath = Join-Path $reportFullDir "imported-state.json"
    $exported = Invoke-CargoJson -Name "Export main state snapshot after spend" -RuntimeArgs @("--state", $stateFullPath, "export-state", "--out", $snapshotPath)
    Invoke-CargoJson -Name "Import state snapshot for root comparison" -RuntimeArgs @("--state", $importedStatePath, "import-state", "--from", $snapshotPath) | Out-Null
    $imported = Invoke-CargoJson -Name "Inspect imported state snapshot" -RuntimeArgs @("--state", $importedStatePath, "inspect-state", "--summary")
    $exportedStateRoot = "$($exported.stateRoot)"
    $importedStateRoot = "$($imported.stateRoot)"
    $rootComparePassed = ($exportedStateRoot -eq $importedStateRoot -and $stateRootAfterTransfer -eq $importedStateRoot)
    if (-not $rootComparePassed) {
        Add-Issue -Kind "code" -Code "export-import-root-mismatch" -Owner "runtime/storage" -Reason "Exported/imported state roots did not match after live bridge spend."
    }

    $nodeStatusAfter = Get-NodeStatusJson
    $persisted = $nodeStatusAfter.persistedStatus
    if ($null -eq $persisted -or "$($persisted.status)" -ne "running") {
        Add-Issue -Kind "code" -Code "node-stopped" -Owner "runtime" -Reason "Node status was not running in the final readiness check."
    }

    Start-ControlPlaneIfNeeded
    try {
        $chainStatus = Invoke-RestMethod -Uri "http://127.0.0.1:8787/chain/status" -TimeoutSec 5
        $bridgeLiveReadiness = Invoke-RestMethod -Uri "http://127.0.0.1:8787/bridge/live-readiness" -TimeoutSec 5
        $dashboardFixtureFallback = $false
    }
    catch {
        $dashboardFixtureFallback = $true
        Add-Issue -Kind "code" -Code "dashboard-fixture-fallback" -Owner "control-plane/dashboard" -Reason "Dashboard/control-plane live API was unavailable, so dashboard would fall back to fixtures."
    }

    if ($RequirePublicLiveL1 -and $null -ne $chainStatus -and [bool] $chainStatus.localOnly) {
        Add-Issue -Kind "external" -Code "control-plane-local-only" -Owner "owner/infra" -Reason "Control-plane reports localOnly while this gate was asked to assess public live L1 readiness."
    }
    if ($dashboardFixtureFallback) {
        Add-Issue -Kind "code" -Code "dashboard-fixture-fallback" -Owner "dashboard/control-plane" -Reason "Readiness fails while the dashboard is in fixture fallback."
    }
    if ($null -eq $latencySeconds) {
        Add-Issue -Kind "code" -Code "latency-unmeasured" -Owner "bridge/runtime" -Reason "Latency from confirmation eligibility to spendable credit could not be measured."
    }

    foreach ($credit in $candidateCredits) {
        $creditId = "$($credit.creditId)"
        if (-not (Test-ObjectHasKey -Object $postTransferState.bridgeCredits -Name $creditId)) {
            Add-Issue -Kind "code" -Code "credit-only-in-proof-artifacts" -Owner "runtime" -Reason "A bridge credit exists in proof artifacts but not in the main node state."
        }
    }

    $releaseEvidence = Read-JsonIfExists -Path (Join-Path $reportFullDir "base8453-release-evidence.json")
    if ($null -ne $releaseEvidence -and [bool] $releaseEvidence.broadcast) {
        Add-Issue -Kind "code" -Code "release-automation-implied" -Owner "bridge/wallet" -Reason "Release evidence implies broadcast automation; release must remain separate unless explicitly authorized."
    }

    $codeIssues = @($issues | Where-Object { $_.kind -eq "code" })
    $externalIssues = @($issues | Where-Object { $_.kind -eq "external" })
    $finalStatus = if ($codeIssues.Count -gt 0) { "CODE-BLOCKED" } elseif ($externalIssues.Count -gt 0) { "EXTERNAL-BLOCKED" } else { "PASS" }
    if ($finalStatus -eq "PASS") {
        $notificationHook.sent = $true
        $notificationHook.reason = "completion status changed to PASS"
    }
    Write-FinalReport -Status $finalStatus
    Write-Host ""
    Write-Host "FlowChain live-l1-bridge:e2e status: $finalStatus"
    Write-Host "Report: $reportPath"
    if ($finalStatus -ne "PASS") {
        throw "FlowChain live-l1-bridge:e2e is $finalStatus. See $reportPath"
    }
}
finally {
    if ($null -eq $previousConfirmations) {
        Remove-Item Env:\FLOWCHAIN_PILOT_CONFIRMATIONS -ErrorAction SilentlyContinue
    }
    else {
        $env:FLOWCHAIN_PILOT_CONFIRMATIONS = $previousConfirmations
    }
    if ($null -eq $previousConfirmationDepthAlias) {
        Remove-Item Env:\FLOWCHAIN_BASE8453_CONFIRMATION_DEPTH -ErrorAction SilentlyContinue
    }
    else {
        $env:FLOWCHAIN_BASE8453_CONFIRMATION_DEPTH = $previousConfirmationDepthAlias
    }
    if ($null -eq $previousTargetSettlementSeconds) {
        Remove-Item Env:\FLOWCHAIN_BRIDGE_TARGET_SETTLEMENT_SECONDS -ErrorAction SilentlyContinue
    }
    else {
        $env:FLOWCHAIN_BRIDGE_TARGET_SETTLEMENT_SECONDS = $previousTargetSettlementSeconds
    }
    if ($null -eq $previousEstimatedBaseBlockSeconds) {
        Remove-Item Env:\FLOWCHAIN_BASE8453_ESTIMATED_BLOCK_SECONDS -ErrorAction SilentlyContinue
    }
    else {
        $env:FLOWCHAIN_BASE8453_ESTIMATED_BLOCK_SECONDS = $previousEstimatedBaseBlockSeconds
    }
    if ($null -eq $previousBridgePollSeconds) {
        Remove-Item Env:\FLOWCHAIN_BRIDGE_POLL_SECONDS -ErrorAction SilentlyContinue
    }
    else {
        $env:FLOWCHAIN_BRIDGE_POLL_SECONDS = $previousBridgePollSeconds
    }
}
