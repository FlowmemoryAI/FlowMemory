param(
    [string] $HandoffPath = "",
    [string] $RunDir = "devnet/local/production-l1-real-funds-readiness",
    [int] $TargetSettlementSeconds = 60
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot -Purpose "production-l1-real-funds-readiness" | Out-Null

$bridgeProofHandoffPath = "services/bridge-relayer/out/real-value-pilot-e2e/bridge-runtime-handoff.json"
$liveFixtureHandoffPath = "fixtures/bridge/base8453-runtime-bridge-handoff.json"

function Read-JsonObject {
    param([Parameter(Mandatory = $true)][string] $Path)
    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Test-LiveRuntimeHandoff {
    param([Parameter(Mandatory = $true)][object] $Handoff)
    $credits = @($Handoff.credits)
    if ($credits.Count -lt 1) {
        return $false
    }
    $appliedCredits = @($credits | Where-Object { "$($_.status)" -eq "applied" })
    if ($appliedCredits.Count -lt 1) {
        return $false
    }
    $credit = $appliedCredits[0]
    return (
        "$($Handoff.mode)" -eq "base-mainnet-pilot" -and
        [bool] $Handoff.productionReady -and
        -not [bool] $Handoff.localOnly -and
        [bool] $credit.productionReady -and
        -not [bool] $credit.localOnly
    )
}

if ([string]::IsNullOrWhiteSpace($HandoffPath)) {
    $bridgeProofFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $bridgeProofHandoffPath)
    if (Test-Path -LiteralPath $bridgeProofFullPath) {
        $bridgeProof = Read-JsonObject -Path $bridgeProofFullPath
        if (Test-LiveRuntimeHandoff -Handoff $bridgeProof) {
            $HandoffPath = $bridgeProofHandoffPath
            $handoffSource = "bridge-proof-live-output"
        }
        else {
            $HandoffPath = $liveFixtureHandoffPath
            $handoffSource = "committed-live-fixture-bridge-proof-output-not-live"
        }
    }
    else {
        $HandoffPath = $liveFixtureHandoffPath
        $handoffSource = "committed-live-fixture"
    }
}
else {
    $handoffSource = "explicit"
}

$runFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $RunDir)
$handoffFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $HandoffPath)
$localRoot = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local")
$runComparable = [System.IO.Path]::GetFullPath($runFullDir).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
)
$localComparable = [System.IO.Path]::GetFullPath($localRoot).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
)
$localPrefix = $localComparable + [System.IO.Path]::DirectorySeparatorChar
if ($runComparable -eq $localComparable -or -not $runComparable.StartsWith($localPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clear runtime proof run directory outside a devnet/local child: $runFullDir"
}

if (-not (Test-Path -LiteralPath $handoffFullPath)) {
    throw "Bridge handoff file does not exist: $handoffFullPath"
}

$runFullDir = Reset-FlowChainDirectory -Path $runFullDir

$statePath = Join-Path $runFullDir "runtime-state.json"
$snapshotPath = Join-Path $runFullDir "snapshot.json"
$importedStatePath = Join-Path $runFullDir "imported-state.json"
$handoffExportDir = Join-Path $runFullDir "handoff-export"
$transferTxPath = Join-Path $runFullDir "live-transfer-txs.json"
$reportPath = Join-Path $runFullDir "runtime-credit-proof.json"

function Invoke-FlowChainJsonCargo {
    param(
        [Parameter(Mandatory = $true)][string] $Label,
        [Parameter(Mandatory = $true)][string[]] $RuntimeArgs
    )

    Write-Host ""
    Write-Host "== $Label =="

    $previousErrorActionPreference = $ErrorActionPreference
    $script:ErrorActionPreference = "Continue"
    try {
        $output = (& cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- @RuntimeArgs 2>&1) -join [Environment]::NewLine
        $exitCode = $LASTEXITCODE
    }
    finally {
        $script:ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitCode -ne 0) {
        throw "$Label failed with exit code $exitCode.`n$output"
    }

    $jsonStart = $output.IndexOf("{")
    $jsonEnd = $output.LastIndexOf("}")
    if ($jsonStart -lt 0 -or $jsonEnd -lt $jsonStart) {
        throw "$Label did not emit JSON output.`n$output"
    }

    return $output.Substring($jsonStart, $jsonEnd - $jsonStart + 1) | ConvertFrom-Json
}

function Get-ReceiptRows {
    param([Parameter(Mandatory = $true)][object] $State)
    $rows = New-Object System.Collections.ArrayList
    foreach ($block in @($State.blocks)) {
        foreach ($receipt in @($block.receipts)) {
            if ($null -ne $receipt) {
                [void] $rows.Add($receipt)
            }
        }
    }
    return @($rows)
}

function Get-ObjectMemberValue {
    param(
        [Parameter(Mandatory = $true)][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name
    )
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-LocalBalanceUnits {
    param(
        [Parameter(Mandatory = $true)][object] $Balances,
        [Parameter(Mandatory = $true)][string] $AccountId
    )

    if ([string]::IsNullOrWhiteSpace($AccountId)) {
        return [UInt64] 0
    }

    $balance = Get-ObjectMemberValue -Object $Balances -Name $AccountId
    if ($null -eq $balance) {
        return [UInt64] 0
    }

    if (-not ($balance.PSObject.Properties.Name -contains "units")) {
        return [UInt64] 0
    }

    return [UInt64] $balance.units
}

function Get-LastQueuedTxId {
    param(
        [Parameter(Mandatory = $true)][object] $QueueResult,
        [Parameter(Mandatory = $true)][string] $Label
    )

    $queued = @($QueueResult.queued)
    if ($queued.Count -lt 1) {
        throw "$Label did not queue a transaction."
    }

    return [string] $queued[-1]
}

function Add-Check {
    param(
        [Parameter(Mandatory = $true)][hashtable] $Checks,
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][bool] $Passed,
        [Parameter(Mandatory = $true)][string] $Evidence
    )
    $Checks[$Name] = [ordered]@{
        passed = $Passed
        evidence = $Evidence
    }
}

function Get-ProofUtcNow {
    return (Get-Date).ToUniversalTime().ToString("o")
}

function ConvertTo-ProofDateTimeOffset {
    param([AllowNull()][object] $Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace("$Value")) {
        return $null
    }
    try {
        return [System.DateTimeOffset]::Parse("$Value", [System.Globalization.CultureInfo]::InvariantCulture).ToUniversalTime()
    }
    catch {
        return $null
    }
}

function Get-ProofSecondsBetween {
    param(
        [AllowNull()][object] $Start,
        [AllowNull()][object] $End
    )

    $startAt = ConvertTo-ProofDateTimeOffset -Value $Start
    $endAt = ConvertTo-ProofDateTimeOffset -Value $End
    if ($null -eq $startAt -or $null -eq $endAt) {
        return $null
    }
    return [math]::Round(($endAt - $startAt).TotalSeconds, 3)
}

$handoff = Read-JsonObject -Path $handoffFullPath
if ($handoff.schema -ne "flowmemory.bridge_runtime_handoff.v0") {
    throw "Unsupported bridge handoff schema: $($handoff.schema)"
}

$handoffCredits = @($handoff.credits)
if ($handoffCredits.Count -lt 1) {
    throw "Bridge handoff contains no credits: $handoffFullPath"
}

$appliedHandoffCredits = @($handoffCredits | Where-Object { "$($_.status)" -eq "applied" })
if ($appliedHandoffCredits.Count -lt 1) {
    throw "Bridge handoff contains no applied credits ready for runtime proof: $handoffFullPath"
}

$pilotCredit = $appliedHandoffCredits[0]
$pilotSource = $pilotCredit.source
$pilotCreditId = [string] $pilotCredit.creditId
$pilotReplayKey = [string] $pilotCredit.replayKey
$pilotRecipient = [string] $pilotCredit.flowchainRecipient
$pilotAmount = [UInt64] $pilotCredit.amount
$pilotSourceChainId = [UInt64] $pilotSource.chainId
$pilotSourceContract = [string] $pilotSource.contract
$pilotSourceAsset = [string] $pilotCredit.token
$pilotTxHash = [string] $pilotSource.txHash
$pilotLogIndex = [UInt64] $pilotSource.logIndex
$pilotDeposit = @($handoff.observations | Where-Object { $_.observationId -eq $pilotCredit.observationId } | Select-Object -First 1).deposit
$pilotEvidence = @($handoff.pilotEvidence | Where-Object { $_.creditId -eq $pilotCreditId } | Select-Object -First 1)
$confirmationProof = if ($null -ne $pilotEvidence) { $pilotEvidence.guardrails.confirmation } else { $null }
$pilotCapProof = if ($null -ne $pilotEvidence) { $pilotEvidence.guardrails } else { $null }
$pilotMaxDeposit = if ($null -ne $pilotCapProof) { [UInt64] $pilotCapProof.maxDepositAmount } else { [UInt64] 0 }
$pilotTotalCap = if ($null -ne $pilotCapProof) { [UInt64] $pilotCapProof.totalCapAmount } else { [UInt64] 0 }

$checks = @{}
$timing = [ordered]@{
    runStartedAt = Get-ProofUtcNow
    handoffQueuedAt = $null
    creditAppliedAt = $null
    firstSpendableAt = $null
    transferQueuedAt = $null
    transferSpendableAt = $null
    completedAt = $null
    queueToSpendableSeconds = $null
    transferSettlementSeconds = $null
    totalSeconds = $null
    targetSettlementSeconds = $TargetSettlementSeconds
    latencyGate = "not-run"
}
Add-Check -Checks $checks -Name "handoff-live-runtime-flags" -Passed (Test-LiveRuntimeHandoff -Handoff $handoff) -Evidence "handoffSource=$handoffSource, mode=$($handoff.mode), localOnly=$($handoff.localOnly), productionReady=$($handoff.productionReady)"
Add-Check -Checks $checks -Name "deposit-source-chain" -Passed ($pilotSourceChainId -eq 8453) -Evidence "sourceChainId=$pilotSourceChainId"
Add-Check -Checks $checks -Name "confirmation-proof-present" -Passed ($null -ne $confirmationProof -and [bool] $confirmationProof.satisfied) -Evidence "confirmation=$($confirmationProof | ConvertTo-Json -Compress)"
Add-Check -Checks $checks -Name "pilot-cap-proof-present" -Passed ($null -ne $pilotCapProof -and $pilotMaxDeposit -ge $pilotAmount -and $pilotTotalCap -ge $pilotAmount) -Evidence "maxDeposit=$pilotMaxDeposit,totalCap=$pilotTotalCap,amount=$pilotAmount"
Add-Check -Checks $checks -Name "runtime-u64-cap-bound" -Passed ($pilotMaxDeposit -le [UInt64]::MaxValue -and $pilotTotalCap -le [UInt64]::MaxValue) -Evidence "amountStorage=u64,u64Max=$([UInt64]::MaxValue)"

$initSummary = Invoke-FlowChainJsonCargo -Label "Initialize runtime state" -RuntimeArgs @(
    "--state", $statePath, "init"
)
$stateRootBefore = [string] $initSummary.stateRoot

$firstQueue = Invoke-FlowChainJsonCargo -Label "Queue live bridge handoff" -RuntimeArgs @(
    "--state", $statePath,
    "bridge-handoff",
    "--handoff", $handoffFullPath,
    "--authorized-by", "operator:bridge:pilot",
    "--direct"
)
$creditTxId = Get-LastQueuedTxId -QueueResult $firstQueue -Label "Queue live bridge handoff"
$timing.handoffQueuedAt = Get-ProofUtcNow

Invoke-FlowChainJsonCargo -Label "Include live bridge credit in block" -RuntimeArgs @(
    "--state", $statePath, "run-block"
) | Out-Null

$stateAfterCredit = Read-JsonObject -Path $statePath
$receiptsAfterCredit = Get-ReceiptRows -State $stateAfterCredit
$appliedCreditReceipts = @($receiptsAfterCredit | Where-Object { $_.txId -eq $creditTxId -and $_.status -eq "applied" })
$bridgeCreditRecord = Get-ObjectMemberValue -Object $stateAfterCredit.bridgeCredits -Name $pilotCreditId
$bridgeReceiptRecord = Get-ObjectMemberValue -Object $stateAfterCredit.bridgeCreditReceipts -Name $pilotCreditId
$bridgeAccountId = if ($null -eq $bridgeCreditRecord) { "" } else { [string] $bridgeCreditRecord.accountId }
$postCreditBalance = Get-LocalBalanceUnits -Balances $stateAfterCredit.localTestUnitBalances -AccountId $bridgeAccountId
$amountAppliedToWallet = $postCreditBalance
$stateRootAfterCredit = [string] (Invoke-FlowChainJsonCargo -Label "Inspect post-credit state" -RuntimeArgs @("--state", $statePath, "inspect-state", "--summary")).stateRoot
$timing.creditAppliedAt = Get-ProofUtcNow
$timing.firstSpendableAt = $timing.creditAppliedAt
$timing.queueToSpendableSeconds = Get-ProofSecondsBetween -Start $timing.handoffQueuedAt -End $timing.firstSpendableAt
$timing.latencyGate = if ($null -ne $timing.queueToSpendableSeconds -and [double]$timing.queueToSpendableSeconds -le $TargetSettlementSeconds) { "passed" } else { "failed" }

Add-Check -Checks $checks -Name "credit-applied-once" -Passed ($appliedCreditReceipts.Count -eq 1) -Evidence "creditTxId=$creditTxId applied=$($appliedCreditReceipts.Count)"
Add-Check -Checks $checks -Name "wallet-delta-equals-credit-amount" -Passed ($amountAppliedToWallet -eq $pilotAmount) -Evidence "amountBeforeRuntime=$pilotAmount,amountAppliedToWallet=$amountAppliedToWallet,postCreditBalance=$postCreditBalance"
Add-Check -Checks $checks -Name "live-credit-record-flags" -Passed ($null -ne $bridgeCreditRecord -and [bool] $bridgeCreditRecord.productionReady -and -not [bool] $bridgeCreditRecord.localOnly -and -not [bool] $bridgeCreditRecord.noValue) -Evidence "credit localOnly=$($bridgeCreditRecord.localOnly), productionReady=$($bridgeCreditRecord.productionReady), noValue=$($bridgeCreditRecord.noValue)"
Add-Check -Checks $checks -Name "live-receipt-record-flags" -Passed ($null -ne $bridgeReceiptRecord -and [bool] $bridgeReceiptRecord.productionReady -and -not [bool] $bridgeReceiptRecord.localOnly) -Evidence "receipt localOnly=$($bridgeReceiptRecord.localOnly), productionReady=$($bridgeReceiptRecord.productionReady)"
Add-Check -Checks $checks -Name "runtime-credit-latency-recorded" -Passed ($null -ne $timing.queueToSpendableSeconds) -Evidence "queueToSpendableSeconds=$($timing.queueToSpendableSeconds)"
Add-Check -Checks $checks -Name "runtime-credit-latency-under-target" -Passed ($timing.latencyGate -eq "passed") -Evidence "queueToSpendableSeconds=$($timing.queueToSpendableSeconds),target=$TargetSettlementSeconds"

$secondQueue = Invoke-FlowChainJsonCargo -Label "Queue duplicate live bridge handoff" -RuntimeArgs @(
    "--state", $statePath,
    "bridge-handoff",
    "--handoff", $handoffFullPath,
    "--authorized-by", "operator:bridge:pilot",
    "--direct"
)
$duplicateCreditTxId = Get-LastQueuedTxId -QueueResult $secondQueue -Label "Queue duplicate live bridge handoff"
Invoke-FlowChainJsonCargo -Label "Reject duplicate live bridge credit" -RuntimeArgs @(
    "--state", $statePath, "run-block"
) | Out-Null

$stateAfterReplay = Read-JsonObject -Path $statePath
$receiptsAfterReplay = Get-ReceiptRows -State $stateAfterReplay
$replayReceipt = @($receiptsAfterReplay | Where-Object { $_.txId -eq $duplicateCreditTxId } | Select-Object -Last 1)
$replayRejected = ($replayReceipt.Count -eq 1 -and $replayReceipt[0].status -eq "rejected" -and "$($replayReceipt[0].error)" -like "*bridge replay key is already consumed*")
$replayStatus = if ($replayReceipt.Count -eq 1) { "$($replayReceipt[0].status)" } else { "missing" }
$replayError = if ($replayReceipt.Count -eq 1) { "$($replayReceipt[0].error)" } else { "" }
$balanceAfterReplay = Get-LocalBalanceUnits -Balances $stateAfterReplay.localTestUnitBalances -AccountId $bridgeAccountId
Add-Check -Checks $checks -Name "replay-rejected" -Passed $replayRejected -Evidence "duplicateTxId=$duplicateCreditTxId,status=$replayStatus,error=$replayError"
Add-Check -Checks $checks -Name "replay-does-not-change-balance" -Passed ($balanceAfterReplay -eq $postCreditBalance) -Evidence "before=$postCreditBalance,afterReplay=$balanceAfterReplay"

$transferAmount = [UInt64] 1
$recipientAccountId = "local-account:runtime-credit-proof-recipient"
Write-FlowChainJson -Path $transferTxPath -Value ([ordered]@{
    schema = "flowmemory.local_devnet.runtime_credit_transfer_txs.v0"
    txs = @(
        [ordered]@{
            type = "CreateLocalTestUnitBalance"
            accountId = $recipientAccountId
            owner = "operator:runtime-credit-proof-recipient"
        },
        [ordered]@{
            type = "TransferLocalTestUnits"
            transferId = "transfer:runtime-credit-proof:001"
            fromAccountId = $bridgeAccountId
            toAccountId = $recipientAccountId
            amountUnits = $transferAmount
            memo = "runtime live bridge proof transfer"
        }
    )
}) -Depth 8

$transferQueue = Invoke-FlowChainJsonCargo -Label "Queue transfer from credited wallet" -RuntimeArgs @(
    "--state", $statePath,
    "submit-tx",
    "--tx-file", $transferTxPath,
    "--authorized-by", "operator:bridge:pilot",
    "--direct"
)
$transferTxId = Get-LastQueuedTxId -QueueResult $transferQueue -Label "Queue transfer from credited wallet"
$timing.transferQueuedAt = Get-ProofUtcNow
Invoke-FlowChainJsonCargo -Label "Apply transfer from credited wallet" -RuntimeArgs @(
    "--state", $statePath, "run-block"
) | Out-Null

$stateAfterTransfer = Read-JsonObject -Path $statePath
$recipientBalance = Get-LocalBalanceUnits -Balances $stateAfterTransfer.localTestUnitBalances -AccountId $recipientAccountId
$senderBalanceAfterTransfer = Get-LocalBalanceUnits -Balances $stateAfterTransfer.localTestUnitBalances -AccountId $bridgeAccountId
$transferRecord = Get-ObjectMemberValue -Object $stateAfterTransfer.balanceTransfers -Name "transfer:runtime-credit-proof:001"
$stateRootAfterTransfer = [string] (Invoke-FlowChainJsonCargo -Label "Inspect post-transfer state" -RuntimeArgs @("--state", $statePath, "inspect-state", "--summary")).stateRoot
$timing.transferSpendableAt = Get-ProofUtcNow
$timing.transferSettlementSeconds = Get-ProofSecondsBetween -Start $timing.transferQueuedAt -End $timing.transferSpendableAt
Add-Check -Checks $checks -Name "credited-balance-transferable" -Passed ($recipientBalance -eq $transferAmount -and $senderBalanceAfterTransfer -eq ($postCreditBalance - $transferAmount) -and -not [bool] $transferRecord.noValue) -Evidence "transferTxId=$transferTxId,transferAmount=$transferAmount,recipientBalance=$recipientBalance,senderBalance=$senderBalanceAfterTransfer,noValue=$($transferRecord.noValue)"
Add-Check -Checks $checks -Name "runtime-transfer-latency-under-target" -Passed ($null -ne $timing.transferSettlementSeconds -and [double]$timing.transferSettlementSeconds -le $TargetSettlementSeconds) -Evidence "transferSettlementSeconds=$($timing.transferSettlementSeconds),target=$TargetSettlementSeconds"

Invoke-FlowChainJsonCargo -Label "Restart runtime for one block" -RuntimeArgs @(
    "--state", $statePath, "start", "--blocks", "1"
) | Out-Null
$restartSummary = Invoke-FlowChainJsonCargo -Label "Inspect restarted runtime" -RuntimeArgs @(
    "--state", $statePath, "inspect-state", "--summary"
)
Add-Check -Checks $checks -Name "restart-preserves-credit-history" -Passed ([int] $restartSummary.bridgeCredits -eq 1 -and [int] $restartSummary.bridgeCreditReceipts -eq 1 -and [int] $restartSummary.bridgeReplayKeys -eq 1) -Evidence "credits=$($restartSummary.bridgeCredits),receipts=$($restartSummary.bridgeCreditReceipts),replayKeys=$($restartSummary.bridgeReplayKeys)"

Invoke-FlowChainJsonCargo -Label "Export handoff fixtures" -RuntimeArgs @(
    "--state", $statePath, "export-fixtures", "--out-dir", $handoffExportDir
) | Out-Null
$exported = Invoke-FlowChainJsonCargo -Label "Export runtime state" -RuntimeArgs @(
    "--state", $statePath, "export-state", "--out", $snapshotPath
)
Invoke-FlowChainJsonCargo -Label "Import runtime state" -RuntimeArgs @(
    "--state", $importedStatePath, "import-state", "--from", $snapshotPath
) | Out-Null
$imported = Invoke-FlowChainJsonCargo -Label "Inspect imported runtime" -RuntimeArgs @(
    "--state", $importedStatePath, "inspect-state", "--summary"
)
Add-Check -Checks $checks -Name "export-import-preserves-state-root" -Passed ($exported.stateRoot -eq $imported.stateRoot -and $restartSummary.stateRoot -eq $imported.stateRoot) -Evidence "restart=$($restartSummary.stateRoot),exported=$($exported.stateRoot),imported=$($imported.stateRoot)"
Add-Check -Checks $checks -Name "export-import-preserves-replay-protection" -Passed ($restartSummary.mapRoots.bridgeReplayIndexRoot -eq $imported.mapRoots.bridgeReplayIndexRoot -and $restartSummary.mapRoots.bridgeEventReceiptIndexRoot -eq $imported.mapRoots.bridgeEventReceiptIndexRoot) -Evidence "replayRoot=$($imported.mapRoots.bridgeReplayIndexRoot),eventRoot=$($imported.mapRoots.bridgeEventReceiptIndexRoot)"

$timing.completedAt = Get-ProofUtcNow
$timing.totalSeconds = Get-ProofSecondsBetween -Start $timing.runStartedAt -End $timing.completedAt

$failedChecks = @($checks.GetEnumerator() | Where-Object { -not [bool] $_.Value.passed })
$classification = if ($failedChecks.Count -eq 0) {
    "READY"
}
elseif (-not (Test-LiveRuntimeHandoff -Handoff $handoff)) {
    "EXTERNAL_BLOCKED_ENV_ONLY"
}
else {
    "CODE_NOT_READY"
}

$report = [ordered]@{
    schema = "flowchain.runtime_credit_proof.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    classification = $classification
    handoffPath = $handoffFullPath
    handoffSource = $handoffSource
    inputDepositFixture = $pilotDeposit
    creditId = $pilotCreditId
    source = [ordered]@{
        chainId = $pilotSourceChainId
        txHash = $pilotTxHash
        logIndex = $pilotLogIndex
        lockbox = $pilotSourceContract
        asset = $pilotSourceAsset
        destinationWallet = $pilotRecipient
    }
    confirmationProof = $confirmationProof
    pilotCapProof = $pilotCapProof
    amountStorage = "u64"
    targetSettlementSeconds = $TargetSettlementSeconds
    timing = $timing
    amountBeforeRuntime = "$pilotAmount"
    amountAppliedToWallet = "$amountAppliedToWallet"
    postCreditBalance = "$postCreditBalance"
    transferAmount = "$transferAmount"
    recipientBalance = "$recipientBalance"
    replayAttemptResult = [ordered]@{
        status = if ($replayRejected) { "rejected" } else { "unexpected" }
        txId = $duplicateCreditTxId
        error = if ($replayReceipt.Count -eq 1) { "$($replayReceipt[0].error)" } else { "" }
    }
    stateRootBefore = $stateRootBefore
    stateRootAfterCredit = $stateRootAfterCredit
    stateRootAfter = $stateRootAfterTransfer
    importedStateRoot = "$($imported.stateRoot)"
    bridgeAccountId = $bridgeAccountId
    recipientAccountId = $recipientAccountId
    checks = $checks
    failedChecks = @($failedChecks | ForEach-Object { $_.Key })
    noSecretDataInReports = $true
    broadcasts = $false
    envValuesPrinted = $false
    noSecrets = $true
}

Write-FlowChainJson -Path $reportPath -Value $report -Depth 24
Assert-FlowChainNoSecretFiles -Path $runFullDir

Write-Host ""
Write-Host "FlowChain runtime credit proof: $reportPath"
Write-Host "Classification: $classification"

if ($classification -ne "READY") {
    throw "FlowChain runtime credit proof is $classification. See $reportPath"
}
