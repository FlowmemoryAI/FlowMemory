param(
    [switch]$SkipInstall,
    [switch]$SkipSmoke,
    [switch]$NoServers
)

$ErrorActionPreference = "Stop"

Set-Location -LiteralPath $PSScriptRoot

function Run-Step {
    param(
        [string]$Name,
        [scriptblock]$Command
    )

    Write-Host ""
    Write-Host "== $Name ==" -ForegroundColor Cyan
    & $Command
}

Write-Host "FlowChain local/private testnet setup" -ForegroundColor Cyan
Write-Host "This starts a local test package only. It is not production mainnet."

if (-not $SkipInstall) {
    Run-Step "Install root dependencies" { npm install }
    Run-Step "Install dashboard dependencies" { npm install --prefix apps/dashboard }
    Run-Step "Install crypto dependencies" { npm install --prefix crypto }
}

Run-Step "Check prerequisites" { npm run flowchain:prereq }
Run-Step "Initialize local state" { npm run flowchain:init }
Run-Step "Start bounded local stack" { npm run flowchain:start }
Run-Step "Run deterministic demo" { npm run flowchain:demo }

if (-not $SkipSmoke) {
    Run-Step "Run FlowChain product testnet E2E gate" { npm run flowchain:product-e2e }
}

Run-Step "Export local bundle" { npm run flowchain:export }
Run-Step "Run bridge mock" { npm run bridge:mock }

if (-not $NoServers) {
    Write-Host ""
    Write-Host "Starting control plane and dashboard in separate PowerShell windows..." -ForegroundColor Cyan

    Start-Process powershell.exe -ArgumentList @(
        "-NoExit",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        "Set-Location -LiteralPath '$PSScriptRoot'; npm run control-plane:serve"
    )

    Start-Process powershell.exe -ArgumentList @(
        "-NoExit",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        "Set-Location -LiteralPath '$PSScriptRoot'; npm run workbench:dev"
    )
}

Write-Host ""
Write-Host "FlowChain local setup completed." -ForegroundColor Green
Write-Host "Dashboard usually opens at http://127.0.0.1:5173/"
Write-Host "Control plane listens on http://127.0.0.1:8787/ when the server window is running."
