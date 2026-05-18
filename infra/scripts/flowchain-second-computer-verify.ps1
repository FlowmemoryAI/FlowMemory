param(
    [string] $ReportPath = "devnet/local/second-computer/flowchain-second-computer-verify-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)

$checks = New-Object System.Collections.ArrayList
function Add-VerifyCheck {
    param([string] $Name, [bool] $Passed, [string] $NextCommand)
    [void] $checks.Add([ordered]@{
        name = $Name
        status = if ($Passed) { "passed" } else { "failed" }
        nextCommand = $NextCommand
    })
}

Add-VerifyCheck -Name "repo-root" -Passed (Test-Path -LiteralPath (Join-Path $repoRoot "package.json")) -NextCommand "cd <repo>"
Add-VerifyCheck -Name "root-node-modules" -Passed (Test-Path -LiteralPath (Join-Path $repoRoot "node_modules")) -NextCommand "npm install"
Add-VerifyCheck -Name "dashboard-node-modules" -Passed (Test-Path -LiteralPath (Join-Path $repoRoot "apps/dashboard/node_modules")) -NextCommand "npm install --prefix apps/dashboard"
Add-VerifyCheck -Name "crypto-node-modules" -Passed (Test-Path -LiteralPath (Join-Path $repoRoot "crypto/node_modules")) -NextCommand "npm install --prefix crypto"
Add-VerifyCheck -Name "local-ignore" -Passed ((Get-Content -Raw -LiteralPath (Join-Path $repoRoot ".gitignore")).Contains("devnet/local/")) -NextCommand "restore .gitignore from repo"

$failed = @($checks | Where-Object { $_.status -ne "passed" })
$report = [ordered]@{
    schema = "flowchain.second_computer.verify_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = if ($failed.Count -eq 0) { "passed" } else { "failed" }
    checks = @($checks)
    authenticatedPrivateRepoPath = @(
        "winget install --id Git.Git --exact --source winget --accept-package-agreements --accept-source-agreements",
        "winget install --id GitHub.cli --exact --source winget --accept-package-agreements --accept-source-agreements",
        "gh auth login",
        "gh repo clone FlowmemoryAI/FlowMemory `$env:USERPROFILE\FlowMemory\FlowMemory"
    )
    offlineBundlePath = @(
        "Extract flowchain-second-computer-source-bundle.zip",
        "cd FlowMemory",
        "npm install",
        "npm install --prefix apps/dashboard",
        "npm install --prefix crypto",
        "npm run flowchain:production-l1:e2e"
    )
}
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 12

Write-Host "FlowChain second-computer verify status: $($report.status)"
Write-Host "Report: $reportFullPath"
if ($failed.Count -gt 0) {
    throw "Second-computer verification found missing install steps."
}

