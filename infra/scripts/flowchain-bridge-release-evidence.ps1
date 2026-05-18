param(
    [string]$WithdrawalIntentPath = "services/bridge-relayer/out/base8453-pilot-withdrawal-intent.json",
    [string]$ReleaseEvidencePath = "services/bridge-relayer/out/base8453-pilot-release-evidence.json",
    [string]$ReportPath = "devnet/local/bridge-live-readiness/bridge-release-evidence-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$withdrawalFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $WithdrawalIntentPath)
$releaseFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReleaseEvidencePath)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)

$missing = @()
if (-not (Test-Path -LiteralPath $withdrawalFullPath)) { $missing += "WithdrawalIntentPath" }
if (-not (Test-Path -LiteralPath $releaseFullPath)) { $missing += "ReleaseEvidencePath" }
if ($missing.Count -gt 0) {
    $report = [ordered]@{
        schema = "flowchain.bridge_release_evidence_report.v0"
        status = "blocked"
        missingInputs = $missing
        nextCommand = "npm run flowchain:bridge:withdraw:intent"
        broadcasts = $false
        noSecrets = $true
    }
    Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 12
    Write-Host "Bridge release evidence blocked by missing inputs: $($missing -join ', ')"
    Write-Host "Report: $reportFullPath"
    throw "Bridge release evidence blocked by missing inputs."
}

$withdrawal = Get-Content -Raw -LiteralPath $withdrawalFullPath | ConvertFrom-Json
$release = Get-Content -Raw -LiteralPath $releaseFullPath | ConvertFrom-Json

$problems = @()
if ($withdrawal.withdrawalIntentId -ne $release.withdrawalIntentId) { $problems += "withdrawalIntentId mismatch" }
if ($withdrawal.creditId -ne $release.creditId) { $problems += "creditId mismatch" }
if ($withdrawal.depositId -ne $release.depositId) { $problems += "depositId mismatch" }
if ($withdrawal.amount -ne $release.releaseCall.amount) { $problems += "amount mismatch" }
if ($withdrawal.token -ne $release.releaseCall.token) { $problems += "token mismatch" }
if ($withdrawal.baseRecipient -ne $release.releaseCall.recipient) { $problems += "recipient mismatch" }
if ($release.releaseCall.broadcast -ne $false) { $problems += "release evidence must not be broadcast" }

$status = if ($problems.Count -eq 0) { "passed" } else { "failed" }
$report = [ordered]@{
    schema = "flowchain.bridge_release_evidence_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    checkedFields = @("withdrawalIntentId", "creditId", "depositId", "amount", "token", "recipient", "broadcast")
    problems = $problems
    broadcasts = $false
    printsEnvValues = $false
    noSecrets = $true
}
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 12
Write-Host "Bridge release evidence status: $status"
Write-Host "Report: $reportFullPath"
if ($problems.Count -gt 0) {
    throw "Bridge release evidence validation failed."
}
