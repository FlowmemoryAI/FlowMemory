param(
    [string] $ReportPath = "devnet/local/production-l1-e2e/wallet-e2e-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)

Invoke-FlowChainCommand -Label "Run wallet product transaction smoke" -FilePath "npm" -ArgumentList @(
    "run",
    "wallet:product-smoke",
    "--prefix",
    "crypto"
)

$metadataPath = Join-Path (Split-Path -Parent $reportFullPath) "wallet-public-metadata.json"
$metadata = [ordered]@{
    schema = "flowchain.wallet.public_metadata.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    walletEvidence = "crypto product transaction fixtures validated"
    exportsSecretMaterial = $false
    command = "npm run wallet:product-smoke --prefix crypto"
}
Write-FlowChainJson -Path $metadataPath -Value $metadata

$report = [ordered]@{
    schema = "flowchain.wallet_e2e_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "passed"
    owner = "wallet/crypto"
    command = "npm run wallet:product-smoke --prefix crypto"
    publicMetadataPath = $metadataPath
    secretMaterialExported = $false
}
Write-FlowChainJson -Path $reportFullPath -Value $report

Write-Host "FlowChain wallet E2E passed."
Write-Host "Report: $reportFullPath"
