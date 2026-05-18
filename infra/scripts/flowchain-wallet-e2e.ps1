param(
    [string] $ReportPath = "devnet/local/production-l1-e2e/wallet-e2e-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)

Invoke-FlowChainCommand -Label "Run wallet production L1 E2E" -FilePath "npm" -ArgumentList @(
    "run",
    "wallet:e2e",
    "--prefix",
    "crypto"
)

$metadataPath = Join-Path (Split-Path -Parent $reportFullPath) "wallet-public-metadata.json"
$metadata = [ordered]@{
    schema = "flowchain.wallet.public_metadata.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    walletEvidence = "crypto wallet E2E created deterministic local wallets, signed transactions, submitted to local intake, and exported public metadata"
    exportsSecretMaterial = $false
    command = "npm run wallet:e2e --prefix crypto"
    proofPath = (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/production-l1-wallet/wallet-e2e/wallet-e2e-proof.json")
}
Write-FlowChainJson -Path $metadataPath -Value $metadata

$report = [ordered]@{
    schema = "flowchain.wallet_e2e_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "passed"
    owner = "wallet/crypto"
    command = "npm run wallet:e2e --prefix crypto"
    publicMetadataPath = $metadataPath
    proofPath = (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/production-l1-wallet/wallet-e2e/wallet-e2e-proof.json")
    secretMaterialExported = $false
}
Write-FlowChainJson -Path $reportFullPath -Value $report

Write-Host "FlowChain wallet E2E passed."
Write-Host "Report: $reportFullPath"
