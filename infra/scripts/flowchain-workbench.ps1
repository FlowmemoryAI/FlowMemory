param(
    [switch] $BuildOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$dashboardModules = Join-Path $repoRoot "apps/dashboard/node_modules"
if (-not (Test-Path -LiteralPath $dashboardModules)) {
    throw "Dashboard dependencies are missing. Run: npm install --prefix apps/dashboard"
}

if ($BuildOnly) {
    Invoke-FlowChainCommand -Label "Build FlowChain workbench" -FilePath "npm" -ArgumentList @("run", "build", "--prefix", "apps/dashboard")
    Write-Host "Workbench build complete."
    return
}

Write-Host "Starting the existing dashboard as the FlowChain local workbench."
Write-Host "The Vite server will print the local URL, usually http://127.0.0.1:5173/."
Write-Host "Press Ctrl+C in this PowerShell window to stop it."

Invoke-FlowChainCommand -Label "Start FlowChain workbench" -FilePath "npm" -ArgumentList @("run", "dev", "--prefix", "apps/dashboard")

