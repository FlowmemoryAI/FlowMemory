param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node",
    [string] $TxFile = "",
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

if ([string]::IsNullOrWhiteSpace($TxFile)) {
    $txDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/tx")
    New-Item -ItemType Directory -Force -Path $txDir | Out-Null
    $txFullPath = Join-Path $txDir "sample-agent-registration.json"
    $sampleTx = [ordered]@{
        schema = "flowmemory.local_devnet.sample_tx.v0"
        txs = @(
            [ordered]@{
                type = "RegisterModelPassport"
                modelPassportId = "model:local-cli:sample"
                issuer = "operator:local-cli"
                modelFamily = "local-cli-sample"
                modelHash = "0x1111111111111111111111111111111111111111111111111111111111111111"
                metadataHash = "0x2222222222222222222222222222222222222222222222222222222222222222"
            },
            [ordered]@{
                type = "RegisterAgent"
                agentId = "agent:local-cli:sample"
                controller = "operator:local-cli"
                modelPassportId = "model:local-cli:sample"
                metadataHash = "0x3333333333333333333333333333333333333333333333333333333333333333"
            }
        )
    }
    Write-FlowChainJson -Path $txFullPath -Value $sampleTx
}
else {
    $txFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $TxFile)
}

$arguments = @(
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
    $txFullPath,
    "--authorized-by",
    $AuthorizedBy
)

if ($Direct) {
    $arguments += "--direct"
}

Invoke-FlowChainCommand -Label "Submit FlowChain local transaction" -FilePath "cargo" -ArgumentList $arguments
