param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node",
    [string] $NodeId = "node:local:alpha",
    [int] $BlockMs = 1000,
    [int] $MaxBlocks = 1,
    [string] $PeerConfig = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot | Out-Null
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$nodeFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $NodeDir)

$arguments = @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $stateFullPath,
    "--node-dir",
    $nodeFullDir,
    "node-restart",
    "--node-id",
    $NodeId,
    "--block-ms",
    "$BlockMs",
    "--max-blocks",
    "$MaxBlocks"
)

if (-not [string]::IsNullOrWhiteSpace($PeerConfig)) {
    $peerConfigFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $PeerConfig)
    $arguments += @("--peer-config", $peerConfigFullPath)
}

Invoke-FlowChainCommand -Label "Restart FlowChain private/local node" -FilePath "cargo" -ArgumentList $arguments

