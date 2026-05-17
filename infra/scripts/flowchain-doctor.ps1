param(
    [string] $ReportPath = "devnet/local/doctor/flowchain-doctor-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$checks = New-Object System.Collections.ArrayList

function Add-DoctorCheck {
    param([string] $Name, [string] $Status, [string] $Owner, [string] $Detail, [string] $NextCommand = "")
    [void] $checks.Add([ordered]@{
        name = $Name
        status = $Status
        owner = $Owner
        detail = $Detail
        nextCommand = $NextCommand
    })
}

foreach ($tool in @("git", "node", "npm", "cargo", "rustc", "forge", "python")) {
    $found = Get-Command $tool -ErrorAction SilentlyContinue
    Add-DoctorCheck `
        -Name "tool:$tool" `
        -Status $(if ($found) { "running" } else { "misconfigured" }) `
        -Owner "installer" `
        -Detail $(if ($found) { "$tool found at $($found.Source)" } else { "$tool missing from PATH" }) `
        -NextCommand "npm run flowchain:prereq"
}

$packageJson = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "package.json") | ConvertFrom-Json
$scripts = @($packageJson.scripts.PSObject.Properties.Name)
foreach ($scriptName in @(
        "flowchain:prereq",
        "flowchain:init",
        "flowchain:node:start",
        "flowchain:node:status",
        "flowchain:node:stop",
        "flowchain:wallet:e2e",
        "flowchain:wallet:transfer:e2e",
        "flowchain:bridge:mock:e2e",
        "flowchain:bridge:live:check",
        "flowchain:production-l1:e2e",
        "flowchain:emergency:stop-local"
    )) {
    Add-DoctorCheck `
        -Name "script:$scriptName" `
        -Status $(if ($scripts -contains $scriptName) { "running" } else { "misconfigured" }) `
        -Owner "ops" `
        -Detail $(if ($scripts -contains $scriptName) { "root package script exists" } else { "root package script missing" })
}

$dataDir = Join-Path $repoRoot "devnet/local"
Add-DoctorCheck `
    -Name "data-dir" `
    -Status $(if (Test-Path -LiteralPath $dataDir) { "running" } else { "stopped" }) `
    -Owner "storage" `
    -Detail $dataDir `
    -NextCommand "npm run flowchain:init"

$gitignore = Get-Content -Raw -LiteralPath (Join-Path $repoRoot ".gitignore")
foreach ($ignored in @("devnet/local/", ".env", ".env.*", "node_modules/", "crates/flowmemory-devnet/target/")) {
    Add-DoctorCheck `
        -Name "ignored:$ignored" `
        -Status $(if ($gitignore.Contains($ignored)) { "running" } else { "misconfigured" }) `
        -Owner "security" `
        -Detail $(if ($gitignore.Contains($ignored)) { "ignored by .gitignore" } else { "missing from .gitignore" })
}

foreach ($port in @(8787, 5173)) {
    $connections = @(Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue)
    $status = if ($connections.Count -gt 0) { "running" } else { "stopped" }
    $owner = if ($port -eq 8787) { "control-plane" } else { "dashboard" }
    $next = if ($port -eq 8787) { "npm run control-plane:serve" } else { "npm run workbench:dev" }
    $pidSummary = (($connections | Select-Object -ExpandProperty OwningProcess -Unique) -join ", ")
    Add-DoctorCheck -Name "port:$port" -Status $status -Owner $owner -Detail $(if ($pidSummary) { "owned by PID(s): $pidSummary" } else { "not listening" }) -NextCommand $next
}

$liveEnvNames = @(
    "FLOWCHAIN_PILOT_OPERATOR_ACK",
    "FLOWCHAIN_BASE8453_RPC_URL",
    "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
    "FLOWCHAIN_BASE8453_FROM_BLOCK",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_BASE8453_CONFIRMATION_DEPTH"
)
$missingLive = @($liveEnvNames | Where-Object { [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_, "Process")) })
Add-DoctorCheck `
    -Name "base-live-env" `
    -Status $(if ($missingLive.Count -eq 0) { "running" } else { "blocked-on-env" }) `
    -Owner "bridge/ops" `
    -Detail $(if ($missingLive.Count -eq 0) { "live readiness env names are present" } else { "missing env names: $($missingLive -join ', ')" }) `
    -NextCommand "npm run flowchain:bridge:live:check"

$failed = @($checks | Where-Object { $_.status -eq "misconfigured" })
$blocked = @($checks | Where-Object { $_.status -eq "blocked-on-env" })
$report = [ordered]@{
    schema = "flowchain.doctor_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = if ($failed.Count -gt 0) { "failed" } elseif ($blocked.Count -gt 0) { "degraded" } else { "passed" }
    repoRoot = $repoRoot
    localUrls = [ordered]@{
        controlPlaneHealth = "http://127.0.0.1:8787/health"
        dashboard = "http://127.0.0.1:5173/"
    }
    checks = @($checks)
    missingLiveEnvNames = $missingLive
}
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 14

Write-Host "FlowChain doctor status: $($report.status)"
Write-Host "Report: $reportFullPath"
if ($failed.Count -gt 0) {
    throw "FlowChain doctor found misconfigured checks."
}

