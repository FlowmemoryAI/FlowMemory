param(
    [string] $OutDir = "devnet/local/production-l1-e2e/wallet-transfer",
    [string] $StatePath = "devnet/local/production-l1-e2e/wallet-transfer/state.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot -Purpose "wallet-transfer-e2e" | Out-Null
$outFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $OutDir)
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$nodeFullDir = Join-Path $outFullDir "node"
$txPath = Join-Path $outFullDir "transfer-tx.json"
$reportPath = Join-Path $outFullDir "wallet-transfer-e2e-report.json"

if (Test-Path -LiteralPath $outFullDir) {
    Remove-Item -LiteralPath $outFullDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $outFullDir | Out-Null

Invoke-FlowChainCommand -Label "Initialize wallet transfer state" -FilePath "cargo" -ArgumentList @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $stateFullPath,
    "init"
)

Invoke-FlowChainCommand -Label "Fund sender account" -FilePath "cargo" -ArgumentList @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $stateFullPath,
    "--node-dir",
    $nodeFullDir,
    "faucet",
    "--account",
    "local-account:transfer:alice",
    "--amount",
    "100",
    "--reason",
    "wallet-transfer-e2e",
    "--authorized-by",
    "operator:transfer:alice",
    "--direct"
)

Invoke-FlowChainCommand -Label "Create recipient account" -FilePath "cargo" -ArgumentList @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $stateFullPath,
    "--node-dir",
    $nodeFullDir,
    "faucet",
    "--account",
    "local-account:transfer:bob",
    "--amount",
    "1",
    "--reason",
    "wallet-transfer-e2e-recipient",
    "--authorized-by",
    "operator:transfer:bob",
    "--direct"
)

$txFixture = [ordered]@{
    schema = "flowmemory.local_devnet.fixture.txs.v0"
    txs = @(
        [ordered]@{
            type = "TransferLocalTestUnits"
            transferId = "transfer:wallet-e2e:001"
            fromAccountId = "local-account:transfer:alice"
            toAccountId = "local-account:transfer:bob"
            amountUnits = 25
            memo = "wallet-transfer-e2e"
        }
    )
}
Write-FlowChainJson -Path $txPath -Value $txFixture

Invoke-FlowChainCommand -Label "Submit local wallet transfer" -FilePath "cargo" -ArgumentList @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $stateFullPath,
    "--node-dir",
    $nodeFullDir,
    "submit-tx",
    "--tx-file",
    $txPath,
    "--authorized-by",
    "operator:transfer:alice",
    "--direct"
)

Invoke-FlowChainCommand -Label "Include wallet transfer in a block" -FilePath "cargo" -ArgumentList @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $stateFullPath,
    "run",
    "--blocks",
    "1"
)

$summary = & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $stateFullPath inspect-state --summary | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "Failed to inspect wallet transfer state."
}
$transferCount = if ($summary.PSObject.Properties.Name -contains "balanceTransfers") {
    [int] $summary.balanceTransfers
}
elseif ($summary.PSObject.Properties.Name -contains "counts" -and $summary.counts.PSObject.Properties.Name -contains "balanceTransfers") {
    [int] $summary.counts.balanceTransfers
}
else {
    0
}
if ($transferCount -lt 1) {
    throw "Wallet transfer was not recorded in state."
}

$report = [ordered]@{
    schema = "flowchain.wallet_transfer_e2e_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "passed"
    statePath = $stateFullPath
    transferFixture = $txPath
    transferCount = $transferCount
    latestHeight = $summary.blocks
    stateRoot = $summary.stateRoot
    noValueBoundary = "local test-unit transfer only; no tokenomics, fees, staking, or real value"
}
Write-FlowChainJson -Path $reportPath -Value $report -Depth 12
Assert-FlowChainNoSecretFiles -Path $outFullDir

Write-Host "FlowChain wallet transfer E2E passed."
Write-Host "State root: $($summary.stateRoot)"
Write-Host "Report: $reportPath"
