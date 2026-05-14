param(
    [string] $SmokeDir = "devnet/local/node-smoke"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot | Out-Null
$smokeFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $SmokeDir)

if (Test-Path -LiteralPath $smokeFullDir) {
    Remove-Item -LiteralPath $smokeFullDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $smokeFullDir | Out-Null

$statePath = Join-Path $smokeFullDir "state.json"
$nodeDir = Join-Path $smokeFullDir "node"
$txDir = Join-Path $smokeFullDir "tx"
$snapshotPath = Join-Path $smokeFullDir "state-snapshot.json"
$importedStatePath = Join-Path $smokeFullDir "imported-state.json"
$stdoutPath = Join-Path $smokeFullDir "node.stdout.jsonl"
$stderrPath = Join-Path $smokeFullDir "node.stderr.log"
$signedTxPath = Join-Path $txDir "signed-register-agent.json"
$batchTxPath = Join-Path $txDir "runtime-batch.json"
New-Item -ItemType Directory -Force -Path $txDir | Out-Null

$fixture = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "crypto/fixtures/local-transaction-vectors.json") | ConvertFrom-Json
$signedEnvelope = $fixture.positive[0].envelope
$signedTxId = $signedEnvelope.envelopeId
Write-FlowChainJson -Path $signedTxPath -Value ([ordered]@{
    schema = "flowmemory.local_devnet.signed_tx_submission.v0"
    envelope = $signedEnvelope
})

$batchTxs = @()
for ($i = 1; $i -le 20; $i++) {
    $batchTxs += [ordered]@{
        type = "CreateLocalTestUnitBalance"
        accountId = "local-account:node-smoke:$i"
        owner = "operator:node-smoke"
    }
}
$batchTxs += [ordered]@{
    type = "FaucetLocalTestUnits"
    faucetRecordId = "faucet:node-smoke:001"
    accountId = "local-account:node-smoke:1"
    recipient = "operator:node-smoke"
    amountUnits = 1000
    reason = "node-smoke-balance-update"
}
$batchTxs += [ordered]@{
    type = "CreateLocalTestUnitBalance"
    accountId = "local-account:bridge:bob"
    owner = "operator:bridge:bob"
}
$batchTxs += [ordered]@{
    type = "ApplyBridgeCredit"
    creditId = "bridge-credit:node-smoke:001"
    observationId = "bridge-observation:node-smoke:001"
    depositId = "bridge-deposit:node-smoke:001"
    replayKey = "bridge-replay:base8453:node-smoke:001"
    sourceChainId = 8453
    sourceContract = "0x1111111111111111111111111111111111111111"
    sourceTxHash = "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    sourceLogIndex = 0
    token = "0x3333333333333333333333333333333333333333"
    assetId = "asset:flowchain-local-test-unit"
    recipientAccountId = "local-account:bridge:alice"
    amountUnits = 75
    verifier = "bridge-verifier:node-smoke"
    evidenceHash = "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
}
$batchTxs += [ordered]@{
    type = "TransferLocalTestUnits"
    transferId = "transfer:bridge:node-smoke:001"
    fromAccountId = "local-account:bridge:alice"
    toAccountId = "local-account:bridge:bob"
    amountUnits = 25
    memo = "bridge-credit-spend-proof"
}
$batchTxs += [ordered]@{
    type = "RequestWithdrawal"
    withdrawalIntentId = "withdrawal-intent:node-smoke:001"
    creditId = "bridge-credit:node-smoke:001"
    accountId = "local-account:bridge:alice"
    assetId = "asset:flowchain-local-test-unit"
    amountUnits = 10
    destinationChainId = 8453
    baseRecipient = "0x4444444444444444444444444444444444444444"
    memo = "test-mode-withdrawal-intent"
}
Write-FlowChainJson -Path $batchTxPath -Value ([ordered]@{
    schema = "flowmemory.local_devnet.runtime_batch.v0"
    txs = $batchTxs
})

$nodeArgs = @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $statePath,
    "--node-dir",
    $nodeDir,
    "node",
    "--node-id",
    "node:smoke:one",
    "--block-ms",
    "500",
    "--max-blocks",
    "20"
)

$process = Start-Process -FilePath "cargo" -ArgumentList (Join-FlowChainProcessArguments -ArgumentList $nodeArgs) -WorkingDirectory $repoRoot -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
Start-Sleep -Milliseconds 900

$signedSubmit = & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $statePath --node-dir $nodeDir submit-tx --tx-file $signedTxPath | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $signedSubmit.queued.Count -ne 1) {
    throw "Signed transaction submit failed."
}
$batchSubmit = & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $statePath --node-dir $nodeDir submit-tx --tx-file $batchTxPath --authorized-by local-node-smoke-operator | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $batchSubmit.queued.Count -lt 24) {
    throw "Runtime batch submit failed or accepted fewer transactions than expected."
}

if (-not $process.WaitForExit(45000)) {
    & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $statePath --node-dir $nodeDir node-stop | Out-Null
    $process.Kill()
    throw "One-node smoke runtime did not stop after bounded 20-block run."
}
$process.Refresh()

if ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) {
    $stderr = Get-Content -Raw -LiteralPath $stderrPath
    throw "One-node smoke runtime failed with exit code $($process.ExitCode): $stderr"
}

$summary = & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $statePath --node-dir $nodeDir node-status | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "node-status failed after one-node smoke."
}
if ($summary.state.blocks -lt 20) {
    throw "Expected one-node smoke to produce at least 20 blocks, got $($summary.state.blocks)."
}
if ($summary.state.transactions -lt 25 -or $summary.state.receipts -lt 25) {
    throw "Expected at least 25 accepted/queryable transactions and receipts."
}
if ($summary.state.bridgeCredits -lt 1 -or $summary.state.withdrawalIntents -lt 1) {
    throw "Expected bridge credit and withdrawal intent state in one-node smoke."
}

$signedQuery = & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $statePath query-tx --id $signedTxId | ConvertFrom-Json
$signedReceipt = & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $statePath query-receipt --id $signedTxId | ConvertFrom-Json
$bridgeCredit = & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $statePath query-bridge-credit --id "bridge-credit:node-smoke:001" | ConvertFrom-Json
$bridgeRecipient = & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $statePath query-account --id "local-account:bridge:bob" | ConvertFrom-Json
if ($signedQuery.transaction.status -ne "applied" -or $signedReceipt.receipt.status -ne "applied") {
    throw "Signed transaction was not queryable as applied."
}
if ($bridgeCredit.credit.status -ne "applied" -or $bridgeRecipient.localTestUnitBalance.units -ne 25) {
    throw "Bridge credit spend proof did not produce expected queryable state."
}

Invoke-FlowChainCommand -Label "Restart node for persistence check" -FilePath "cargo" -ArgumentList @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $statePath,
    "--node-dir",
    $nodeDir,
    "node",
    "--node-id",
    "node:smoke:one",
    "--block-ms",
    "50",
    "--max-blocks",
    "1"
)

$restartedSummary = & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $statePath --node-dir $nodeDir node-status | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "node-status failed after persistence restart."
}
if ($restartedSummary.state.blocks -lt 21) {
    throw "Expected restart to preserve state and add a block."
}
$signedReceiptAfterRestart = & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $statePath query-receipt --id $signedTxId | ConvertFrom-Json
if ($signedReceiptAfterRestart.receipt.status -ne "applied") {
    throw "Receipt query failed after restart."
}

$replay = & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $statePath submit-tx --tx-file $signedTxPath --direct | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $replay.rejected.Count -lt 1) {
    throw "Expected signed replay to be rejected."
}

Invoke-FlowChainCommand -Label "Export runtime state snapshot" -FilePath "cargo" -ArgumentList @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $statePath,
    "export-state",
    "--out",
    $snapshotPath
)

Invoke-FlowChainCommand -Label "Import runtime state snapshot" -FilePath "cargo" -ArgumentList @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $importedStatePath,
    "import-state",
    "--from",
    $snapshotPath
)

$original = & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $statePath inspect-state --summary | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "Failed to inspect original smoke state."
}
$imported = & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $importedStatePath inspect-state --summary | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "Failed to inspect imported smoke state."
}
if ($original.stateRoot -ne $imported.stateRoot -or $original.latestHash -ne $imported.latestHash) {
    throw "Export/import roots or latest hashes differ."
}

$stateJson = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
$appliedReceiptIds = @($stateJson.receipts.PSObject.Properties | Where-Object { $_.Value.status -eq "applied" } | ForEach-Object { $_.Name })
$allTxIds = @($signedSubmit.queued + $batchSubmit.queued)
$reportPath = Join-Path $smokeFullDir "production-node-smoke-report.json"
$report = [ordered]@{
    schema = "flowchain.private_testnet.production_node_smoke.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    commandsRun = @(
        "npm run flowchain:node:smoke",
        "flowmemory-devnet node --max-blocks 20",
        "flowmemory-devnet submit-tx signed",
        "flowmemory-devnet submit-tx local batch",
        "flowmemory-devnet query-tx",
        "flowmemory-devnet query-receipt",
        "flowmemory-devnet query-bridge-credit",
        "flowmemory-devnet export-state",
        "flowmemory-devnet import-state"
    )
    statePath = $statePath
    nodeDir = $nodeDir
    blockCount = $restartedSummary.state.blocks
    txIds = $allTxIds
    receiptIds = $appliedReceiptIds
    stateRoot = $original.stateRoot
    latestHash = $original.latestHash
    restartProof = [ordered]@{
        beforeRestartStateRoot = $summary.state.stateRoot
        afterRestartStateRoot = $restartedSummary.state.stateRoot
        beforeRestartLatestHash = $summary.state.parentHash
        afterRestartLatestHash = $restartedSummary.state.parentHash
        receiptsQueryableAfterRestart = $true
    }
    signedSubmit = [ordered]@{
        txId = $signedTxId
        acceptedOnce = $true
        replayRejected = $true
        replayReason = $replay.rejected[0].reason
    }
    bridgeCreditSpend = [ordered]@{
        creditId = "bridge-credit:node-smoke:001"
        recipientCanSpend = $true
        bobBalance = $bridgeRecipient.localTestUnitBalance.units
        withdrawalIntentRecorded = $true
    }
    exportImportProof = [ordered]@{
        importedStateRoot = $imported.stateRoot
        importedLatestHash = $imported.latestHash
        preserved = $true
    }
    failureDetails = @()
}
Write-FlowChainJson -Path $reportPath -Value $report

Write-Host ""
Write-Host "FlowChain one-node runtime smoke passed."
Write-Host "Blocks after restart: $($restartedSummary.state.blocks)"
Write-Host "Accepted tx IDs: $($allTxIds.Count)"
Write-Host "State root: $($original.stateRoot)"
Write-Host "Report: $reportPath"
