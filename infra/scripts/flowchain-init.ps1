param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $OperatorPath = "devnet/local/operator.local.json",
    [string] $ImportOperatorKeyPath = "",
    [switch] $Force
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot | Out-Null
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$operatorFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $OperatorPath)
$manifestPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/flowchain-init-manifest.json")

if ((Test-Path -LiteralPath $stateFullPath) -and -not $Force) {
    Write-Host "State already exists: $stateFullPath"
    Write-Host "Use npm run flowchain:demo or rerun this script with -Force to reset to genesis."
}
else {
    Invoke-FlowChainCommand -Label "Initialize deterministic local genesis" -FilePath "cargo" -ArgumentList @(
        "run",
        "--manifest-path",
        "crates/flowmemory-devnet/Cargo.toml",
        "--",
        "--state",
        $stateFullPath,
        "init"
    )
}

if (-not [string]::IsNullOrWhiteSpace($ImportOperatorKeyPath)) {
    $importFullPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ImportOperatorKeyPath
    if (-not (Test-Path -LiteralPath $importFullPath)) {
        throw "Import operator key file does not exist: $importFullPath"
    }
    if ((Test-Path -LiteralPath $operatorFullPath) -and -not $Force) {
        throw "Operator file already exists. Rerun with -Force to replace it."
    }
    $operatorParent = Split-Path -Parent $operatorFullPath
    New-Item -ItemType Directory -Force -Path $operatorParent | Out-Null
    Copy-Item -LiteralPath $importFullPath -Destination $operatorFullPath -Force:$Force
    Write-Host "Imported local-only operator file: $operatorFullPath"
}
else {
    New-FlowChainLocalOperator -OperatorPath $operatorFullPath -Force:$Force
}

$manifest = [ordered]@{
    schema = "flowchain.private_testnet.init_manifest.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    statePath = $stateFullPath
    operatorPath = $operatorFullPath
    runtime = "crates/flowmemory-devnet"
    mode = "private-local-second-computer"
    productionUse = $false
    nextCommands = @(
        "npm run flowchain:start",
        "npm run flowchain:demo",
        "npm run flowchain:smoke",
        "npm run workbench:dev"
    )
}
Write-FlowChainJson -Path $manifestPath -Value $manifest

Write-Host ""
Write-Host "FlowChain private/local init complete."
Write-Host "State: $stateFullPath"
Write-Host "Local-only operator file: $operatorFullPath"
Write-Host "Next command: npm run flowchain:start"
