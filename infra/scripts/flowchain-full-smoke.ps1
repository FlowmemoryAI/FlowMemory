param(
    [switch] $SkipDashboardBuild,
    [switch] $SkipHardware
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$fullSmokeRoot = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/full-smoke")

if (Test-Path -LiteralPath $fullSmokeRoot) {
    Remove-Item -LiteralPath $fullSmokeRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $fullSmokeRoot | Out-Null

$smokeArgs = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (Join-Path $PSScriptRoot "flowchain-smoke.ps1")
)
if ($SkipDashboardBuild) {
    $smokeArgs += "-SkipDashboardBuild"
}
if ($SkipHardware) {
    $smokeArgs += "-SkipHardware"
}

Invoke-FlowChainCommand -Label "Run FlowChain private/local smoke gate" -FilePath "powershell" -ArgumentList $smokeArgs

$walletDocumentPath = Join-Path $fullSmokeRoot "wallet-document.json"
$walletVaultPath = Join-Path $fullSmokeRoot "wallet-vault.local.json"
$walletEnvelopePath = Join-Path $fullSmokeRoot "wallet-envelope.json"
$localAlphaFixtures = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "crypto/fixtures/local-alpha-objects.json") | ConvertFrom-Json
Write-FlowChainJson -Path $walletDocumentPath -Value $localAlphaFixtures.positive[0].document

$previousWalletPassword = $env:FLOWMEMORY_TEST_WALLET_PASSWORD
$env:FLOWMEMORY_TEST_WALLET_PASSWORD = "flowmemory-full-smoke-local-password"
try {
    Invoke-FlowChainCommand -Label "Create encrypted local test wallet vault" -FilePath "npm" -ArgumentList @(
        "run",
        "wallet:create",
        "--prefix",
        "crypto",
        "--",
        "--vault",
        $walletVaultPath,
        "--label",
        "full-smoke-operator",
        "--role",
        "operator"
    )
    Invoke-FlowChainCommand -Label "Sign local transaction envelope" -FilePath "npm" -ArgumentList @(
        "run",
        "wallet:sign",
        "--prefix",
        "crypto",
        "--",
        "--vault",
        $walletVaultPath,
        "--document",
        $walletDocumentPath,
        "--chain-id",
        "31337",
        "--nonce",
        "1",
        "--out",
        $walletEnvelopePath
    )
    Invoke-FlowChainCommand -Label "Verify local transaction envelope" -FilePath "npm" -ArgumentList @(
        "run",
        "wallet:verify",
        "--prefix",
        "crypto",
        "--",
        "--document",
        $walletDocumentPath,
        "--envelope",
        $walletEnvelopePath,
        "--chain-id",
        "31337"
    )
}
finally {
    $env:FLOWMEMORY_TEST_WALLET_PASSWORD = $previousWalletPassword
}

Assert-FlowChainNoSecretFiles -Path $fullSmokeRoot
Invoke-FlowChainCommand -Label "Check working tree patch whitespace" -FilePath "git" -ArgumentList @("diff", "--check")

$smokeReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/smoke/flowchain-smoke-report.json"
if (-not (Test-Path -LiteralPath $smokeReportPath)) {
    throw "Expected smoke report was not written: $smokeReportPath"
}

$smokeReport = Get-Content -Raw -LiteralPath $smokeReportPath | ConvertFrom-Json
if ($smokeReport.PSObject.Properties["blockedLifecycleCoverage"] -and $smokeReport.blockedLifecycleCoverage.Count -gt 0) {
    throw "Full smoke cannot pass with blocked merged-surface lifecycle coverage: $($smokeReport.blockedLifecycleCoverage -join ', ')"
}

$reportPath = Join-Path $fullSmokeRoot "flowchain-full-smoke-report.json"
$report = [ordered]@{
    schema = "flowchain.private_testnet.full_smoke_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    smokeReport = $smokeReportPath
    stateRoot = $smokeReport.stateRoot
    deterministicReplay = $smokeReport.deterministicReplay
    launchCandidate = $smokeReport.launchCandidate
    devnetTests = $smokeReport.devnetTests
    serviceTests = $smokeReport.serviceTests
    cryptoTests = $smokeReport.cryptoTests
    cryptoVectors = $smokeReport.cryptoVectors
    cryptoLocalAlpha = $smokeReport.cryptoLocalAlpha
    controlPlaneSmoke = $smokeReport.controlPlaneSmoke
    localWalletCli = "passed"
    localTransactionEnvelope = $walletEnvelopePath
    dashboardBuild = $smokeReport.dashboardBuild
    hardwareFixture = $smokeReport.hardwareFixture
    noSecretExportScan = $smokeReport.noSecretExportScan
    gitDiffCheck = "passed"
    acceptanceCoverage = [ordered]@{
        localRuntime = "passed"
        nativeObjectLifecycle = "passed"
        controlPlaneQueries = "passed"
        workbenchBuild = $smokeReport.dashboardBuild
        deterministicReplay = "passed"
        walletEnvelope = "passed"
        noSecretExportScan = "passed"
        unsafeClaimScan = "passed"
    }
    productionBoundary = @(
        "private/local no-value validation only",
        "no production mainnet claim",
        "no tokenomics claim",
        "no production bridge claim",
        "no audited-cryptography claim",
        "no public validator readiness claim"
    )
}
Write-FlowChainJson -Path $reportPath -Value $report

Write-Host ""
Write-Host "FlowChain full private/local smoke passed."
Write-Host "Deterministic state root: $($smokeReport.stateRoot)"
Write-Host "Full smoke report: $reportPath"
