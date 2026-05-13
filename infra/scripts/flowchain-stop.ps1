param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node",
    [switch] $ResetLocalState
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot | Out-Null
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$nodeFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $NodeDir)
$statusPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/flowchain-stack-status.json")

Invoke-FlowChainCommand -Label "Request long-running node stop" -FilePath "cargo" -ArgumentList @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $stateFullPath,
    "--node-dir",
    $nodeFullDir,
    "node-stop"
)

if ($ResetLocalState) {
    Invoke-FlowChainCommand -Label "Reset local devnet state" -FilePath "cargo" -ArgumentList @(
        "run",
        "--manifest-path",
        "crates/flowmemory-devnet/Cargo.toml",
        "--",
        "--state",
        $stateFullPath,
        "reset-local"
    )
}

$status = [ordered]@{
    schema = "flowchain.private_testnet.stack_status.v0"
    status = "stopped"
    stoppedAt = (Get-Date).ToUniversalTime().ToString("o")
    statePath = $stateFullPath
    nodeDir = $nodeFullDir
    nodeStopRequested = $true
    resetLocalState = [bool] $ResetLocalState
    note = "Stop records operator state, requests the long-running local node to stop through its stop file, and can reset ignored local devnet state when explicitly requested."
}
Write-FlowChainJson -Path $statusPath -Value $status

Write-Host "FlowChain private/local stack marked stopped."
if ($ResetLocalState) {
    Write-Host "Local state was reset to deterministic genesis."
}
else {
    Write-Host "Local state was preserved. Use -ResetLocalState for a clean reset."
}
