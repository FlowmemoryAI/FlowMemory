param(
    [string] $SmokeDir = "devnet/local/multi-node-smoke"
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

$stateA = Join-Path $smokeFullDir "node-a-state.json"
$stateB = Join-Path $smokeFullDir "node-b-state.json"
$nodeA = Join-Path $smokeFullDir "node-a"
$nodeB = Join-Path $smokeFullDir "node-b"
$peerA = Join-Path $smokeFullDir "node-a-peers.json"
$peerB = Join-Path $smokeFullDir "node-b-peers.json"
$stdoutA = Join-Path $smokeFullDir "node-a.stdout.jsonl"
$stderrA = Join-Path $smokeFullDir "node-a.stderr.log"
$stdoutB = Join-Path $smokeFullDir "node-b.stdout.jsonl"
$stderrB = Join-Path $smokeFullDir "node-b.stderr.log"

Write-FlowChainJson -Path $peerA -Value ([ordered]@{
    schema = "flowmemory.local_devnet.static_peers.v0"
    nodeId = "node:smoke:a"
    peers = @(
        [ordered]@{
            nodeId = "node:smoke:b"
            statePath = $stateB
        }
    )
})

Write-FlowChainJson -Path $peerB -Value ([ordered]@{
    schema = "flowmemory.local_devnet.static_peers.v0"
    nodeId = "node:smoke:b"
    peers = @(
        [ordered]@{
            nodeId = "node:smoke:a"
            statePath = $stateA
        }
    )
})

$argsA = @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $stateA,
    "--node-dir",
    $nodeA,
    "node",
    "--node-id",
    "node:smoke:a",
    "--block-ms",
    "250",
    "--max-blocks",
    "12",
    "--peer-config",
    $peerA
)

$processA = Start-Process -FilePath "cargo" -ArgumentList (Join-FlowChainProcessArguments -ArgumentList $argsA) -WorkingDirectory $repoRoot -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutA -RedirectStandardError $stderrA
Start-Sleep -Milliseconds 500

Invoke-FlowChainCommand -Label "Submit locally authorized transaction to node A" -FilePath "cargo" -ArgumentList @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $stateA,
    "--node-dir",
    $nodeA,
    "faucet",
    "--account",
    "local-account:multi-node",
    "--amount",
    "77",
    "--reason",
    "multi-node-smoke",
    "--authorized-by",
    "local-smoke-operator"
)

$argsB = @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $stateB,
    "--node-dir",
    $nodeB,
    "node",
    "--node-id",
    "node:smoke:b",
    "--block-ms",
    "250",
    "--max-blocks",
    "12",
    "--peer-config",
    $peerB
)

$processB = Start-Process -FilePath "cargo" -ArgumentList (Join-FlowChainProcessArguments -ArgumentList $argsB) -WorkingDirectory $repoRoot -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutB -RedirectStandardError $stderrB

foreach ($process in @($processA, $processB)) {
    if (-not $process.WaitForExit(45000)) {
        & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $stateA --node-dir $nodeA node-stop | Out-Null
        & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $stateB --node-dir $nodeB node-stop | Out-Null
        $process.Kill()
        throw "Multi-node smoke runtime did not stop after bounded run."
    }
    $process.Refresh()
    if ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) {
        throw "Multi-node smoke process $($process.Id) failed with exit code $($process.ExitCode)."
    }
}

$summaryA = & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $stateA --node-dir $nodeA node-status | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "node-status failed for node A."
}
$summaryB = & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $stateB --node-dir $nodeB node-status | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "node-status failed for node B."
}

if ($summaryA.state.localBalances -lt 1) {
    throw "Node A did not include the local balance transaction."
}
if ($summaryB.state.localBalances -lt 1) {
    throw "Node B did not reconcile the local balance transaction from node A."
}
if ($summaryA.state.stateRoot -ne $summaryB.state.stateRoot) {
    throw "Multi-node deterministic reconciliation failed. Node A root $($summaryA.state.stateRoot), node B root $($summaryB.state.stateRoot)."
}

$reportPath = Join-Path $smokeFullDir "multi-node-smoke-report.json"
$report = [ordered]@{
    schema = "flowchain.private_testnet.multi_node_smoke.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    nodeAState = $stateA
    nodeBState = $stateB
    nodeABlocks = $summaryA.state.blocks
    nodeBBlocks = $summaryB.state.blocks
    reconciledStateRoot = $summaryA.state.stateRoot
    staticPeerConfig = @($peerA, $peerB)
    lanMode = "not exposed; this smoke proves two local processes reconcile through static local-file peer state paths"
}
Write-FlowChainJson -Path $reportPath -Value $report

Write-Host ""
Write-Host "FlowChain multi-node local-file smoke passed."
Write-Host "Reconciled state root: $($summaryA.state.stateRoot)"
Write-Host "Report: $reportPath"
