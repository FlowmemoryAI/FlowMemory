param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node",
    [string] $Account = "local-account:operator",
    [UInt64] $Amount = 1000,
    [string] $Reason = "local-private-testnet-faucet",
    [string] $AuthorizedBy = "local-operator",
    [switch] $Direct
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
    "faucet",
    "--account",
    $Account,
    "--amount",
    "$Amount",
    "--reason",
    $Reason,
    "--authorized-by",
    $AuthorizedBy
)

if ($Direct) {
    $arguments += "--direct"
}

Invoke-FlowChainCommand -Label "Submit FlowChain local faucet transaction" -FilePath "cargo" -ArgumentList $arguments
