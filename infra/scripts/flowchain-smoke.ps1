param(
    [switch] $SkipDashboardBuild,
    [switch] $SkipHardware
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot | Out-Null
$smokeRoot = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/smoke")

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-check-prereqs.ps1") -Strict
if ($LASTEXITCODE -ne 0) {
    throw "Prerequisite check failed."
}

$smokeRoot = Reset-FlowChainDirectory -Path $smokeRoot

Invoke-FlowChainCommand -Label "Run service tests" -FilePath "npm" -ArgumentList @("test")
Invoke-FlowChainCommand -Label "Run crypto tests" -FilePath "npm" -ArgumentList @("test", "--prefix", "crypto")
Invoke-FlowChainCommand -Label "Validate crypto vectors" -FilePath "npm" -ArgumentList @("run", "validate:vectors", "--prefix", "crypto")
Invoke-FlowChainCommand -Label "Validate local alpha crypto objects" -FilePath "npm" -ArgumentList @("run", "validate:local-alpha", "--prefix", "crypto")
Invoke-FlowChainCommand -Label "Run launch candidate gate" -FilePath "npm" -ArgumentList @("run", "launch:candidate")
Invoke-FlowChainCommand -Label "Run devnet tests" -FilePath "cargo" -ArgumentList @("test", "--manifest-path", "crates/flowmemory-devnet/Cargo.toml")
Invoke-FlowChainCommand -Label "Run control-plane full smoke client" -FilePath "npm" -ArgumentList @("run", "control-plane:smoke")

$runAState = Join-Path $smokeRoot "run-a/state.json"
$runAOut = Join-Path $smokeRoot "run-a/export"
$runBState = Join-Path $smokeRoot "run-b/state.json"
$runBOut = Join-Path $smokeRoot "run-b/export"

Invoke-FlowChainCommand -Label "Run deterministic demo A" -FilePath "cargo" -ArgumentList @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $runAState,
    "demo",
    "--out-dir",
    $runAOut
)
Invoke-FlowChainCommand -Label "Run deterministic demo B" -FilePath "cargo" -ArgumentList @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $runBState,
    "demo",
    "--out-dir",
    $runBOut
)

$runADashboard = Get-Content -Raw -LiteralPath (Join-Path $runAOut "dashboard-state.json") | ConvertFrom-Json
$runBDashboard = Get-Content -Raw -LiteralPath (Join-Path $runBOut "dashboard-state.json") | ConvertFrom-Json
if ($runADashboard.stateRoot -ne $runBDashboard.stateRoot) {
    throw "Deterministic replay failed. State roots differ: $($runADashboard.stateRoot) vs $($runBDashboard.stateRoot)"
}

Assert-FlowChainNoSecretFiles -Path $runAOut
Assert-FlowChainNoSecretFiles -Path $runBOut

if (-not $SkipDashboardBuild) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-workbench.ps1") -BuildOnly
    if ($LASTEXITCODE -ne 0) {
        throw "Workbench build failed."
    }
}

if (-not $SkipHardware) {
    Invoke-FlowChainCommand -Label "Validate FlowRouter simulator fixture" -FilePath "python" -ArgumentList @(
        "hardware/simulator/flowrouter_sim.py",
        "--validate-file",
        "hardware/fixtures/flowrouter_sample_seed42.json"
    )
}

Invoke-FlowChainCommand -Label "Check unsafe launch claims" -FilePath "node" -ArgumentList @("infra/scripts/check-unsafe-claims.mjs")

$reportPath = Join-Path $smokeRoot "flowchain-smoke-report.json"
$report = [ordered]@{
    schema = "flowchain.private_testnet.smoke_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    stateRoot = $runADashboard.stateRoot
    deterministicReplay = $true
    runAExport = $runAOut
    runBExport = $runBOut
    launchCandidate = "passed"
    devnetTests = "passed"
    serviceTests = "passed"
    cryptoTests = "passed"
    cryptoVectors = "passed"
    cryptoLocalAlpha = "passed"
    controlPlaneSmoke = "passed"
    dashboardBuild = $(if ($SkipDashboardBuild) { "skipped" } else { "passed" })
    hardwareFixture = $(if ($SkipHardware) { "skipped" } else { "passed" })
    noSecretExportScan = "passed"
    currentLifecycleCoverage = @(
        "rootfield namespace",
        "root commitment",
        "artifact commitment",
        "artifact availability proof",
        "agent account",
        "local no-value test-unit balance",
        "local faucet record",
        "local object ids",
        "local signed envelope vectors",
        "model passport",
        "work receipt",
        "verifier module",
        "verifier report",
        "memory cell",
        "challenge",
        "finality receipt",
        "Base anchor placeholder",
        "control-plane query evidence",
        "launch-core Flow Memory objects",
        "workbench build"
    )
    blockedLifecycleCoverage = @()
    productionNonGoals = @(
        "production mainnet",
        "public validators",
        "tokenomics",
        "production bridge",
        "audited cryptography",
        "production Uniswap v4 hook deployment"
    )
}
Write-FlowChainJson -Path $reportPath -Value $report

Write-Host ""
Write-Host "FlowChain private/local smoke passed for merged private/local surfaces."
Write-Host "Deterministic state root: $($runADashboard.stateRoot)"
Write-Host "Smoke report: $reportPath"
Write-Host "Production-gated non-goals remain recorded in docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md."
