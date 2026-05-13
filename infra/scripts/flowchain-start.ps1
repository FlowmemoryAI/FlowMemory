param(
    [string] $StatePath = "devnet/local/state.json",
    [switch] $SkipLaunchCore
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot | Out-Null
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$statusPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/flowchain-stack-status.json")

if (-not (Test-Path -LiteralPath $stateFullPath)) {
    Write-Host "No local state found. Initializing first."
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-init.ps1") -StatePath $stateFullPath
    if ($LASTEXITCODE -ne 0) {
        throw "flowchain-init failed."
    }
}

if (-not $SkipLaunchCore) {
    Invoke-FlowChainCommand -Label "Generate launch-core fixtures" -FilePath "npm" -ArgumentList @("run", "launch:v0")
}

Invoke-FlowChainCommand -Label "Inspect local devnet state" -FilePath "cargo" -ArgumentList @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $stateFullPath,
    "inspect-state",
    "--summary"
)

$status = [ordered]@{
    schema = "flowchain.private_testnet.stack_status.v0"
    status = "started"
    startedAt = (Get-Date).ToUniversalTime().ToString("o")
    statePath = $stateFullPath
    runtimeMode = "bounded-local-cli"
    longRunningNode = "available through npm run flowchain:node"
    launchCoreGenerated = -not $SkipLaunchCore
    workbenchCommand = "npm run workbench:dev"
    smokeCommand = "npm run flowchain:smoke"
    nodeCommand = "npm run flowchain:node"
    note = "This compatibility wrapper prepares local state and launch-core fixtures. Use npm run flowchain:node for the long-running private/local runtime."
}
Write-FlowChainJson -Path $statusPath -Value $status

Write-Host ""
Write-Host "FlowChain private/local stack is ready in bounded local CLI mode."
Write-Host "Next command for a transaction demo: npm run flowchain:demo"
Write-Host "Long-running node command: npm run flowchain:node"
Write-Host "Workbench command: npm run workbench:dev"
