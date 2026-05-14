param(
    [string] $SmokeDir = "devnet/local/node-smoke"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot | Out-Null
$smokeFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $SmokeDir)

$smokeFullDir = Reset-FlowChainDirectory -Path $smokeFullDir

$statePath = Join-Path $smokeFullDir "state.json"
$nodeDir = Join-Path $smokeFullDir "node"
$snapshotPath = Join-Path $smokeFullDir "state-snapshot.json"
$importedStatePath = Join-Path $smokeFullDir "imported-state.json"
$stdoutPath = Join-Path $smokeFullDir "node.stdout.jsonl"
$stderrPath = Join-Path $smokeFullDir "node.stderr.log"

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
    "250",
    "--max-blocks",
    "10"
)

$process = Start-Process -FilePath "cargo" -ArgumentList (Join-FlowChainProcessArguments -ArgumentList $nodeArgs) -WorkingDirectory $repoRoot -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
Start-Sleep -Milliseconds 700

Invoke-FlowChainCommand -Label "Submit locally authorized faucet transaction to running node" -FilePath "cargo" -ArgumentList @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $statePath,
    "--node-dir",
    $nodeDir,
    "faucet",
    "--account",
    "local-account:node-smoke",
    "--amount",
    "42",
    "--reason",
    "one-node-smoke",
    "--authorized-by",
    "local-smoke-operator"
)

if (-not $process.WaitForExit(30000)) {
    & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $statePath --node-dir $nodeDir node-stop | Out-Null
    $process.Kill()
    throw "One-node smoke runtime did not stop after bounded 10-block run."
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
if ($summary.state.blocks -lt 10) {
    throw "Expected one-node smoke to produce at least 10 blocks, got $($summary.state.blocks)."
}
if ($summary.state.localBalances -lt 1 -or $summary.state.faucetRecords -lt 1) {
    throw "Expected locally authorized faucet transaction to be included in one-node smoke."
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
if ($restartedSummary.state.blocks -lt 11) {
    throw "Expected restart to preserve state and add a block."
}
if ($restartedSummary.state.localBalances -lt 1 -or $restartedSummary.state.faucetRecords -lt 1) {
    throw "Expected local balance state to survive restart."
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
if ($original.stateRoot -ne $imported.stateRoot) {
    throw "Export/import state roots differ: $($original.stateRoot) vs $($imported.stateRoot)"
}

$reportPath = Join-Path $smokeFullDir "one-node-smoke-report.json"
$report = [ordered]@{
    schema = "flowchain.private_testnet.one_node_smoke.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    statePath = $statePath
    nodeDir = $nodeDir
    blocksAfterRestart = $restartedSummary.state.blocks
    locallyAuthorizedTxIncluded = $true
    stateSurvivedRestart = $true
    exportImportStateRoot = $original.stateRoot
    lanMode = "not exposed; static local-file peers only"
}
Write-FlowChainJson -Path $reportPath -Value $report

Write-Host ""
Write-Host "FlowChain one-node runtime smoke passed."
Write-Host "Blocks after restart: $($restartedSummary.state.blocks)"
Write-Host "State root: $($original.stateRoot)"
Write-Host "Report: $reportPath"
