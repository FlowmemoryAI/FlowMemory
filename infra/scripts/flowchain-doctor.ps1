param(
    [string] $ReportPath = "devnet/local/doctor/flowchain-doctor-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$checks = New-Object System.Collections.ArrayList

function Get-DoctorProp {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name,
        [object] $Default = $null
    )

    if ($null -ne $Object -and $Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
    }
    if ($null -ne $Object) {
        $property = $Object.PSObject.Properties[$Name]
        if ($null -ne $property) {
            return $property.Value
        }
    }
    return $Default
}

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
        "flowchain:doctor",
        "flowchain:install:check",
        "flowchain:upgrade:rehearse",
        "flowchain:init",
        "flowchain:operator:package",
        "flowchain:operator:package:verify",
        "flowchain:service:start",
        "flowchain:service:status",
        "flowchain:service:monitor",
        "flowchain:service:restart",
        "flowchain:service:stop",
        "flowchain:node:start",
        "flowchain:node:status",
        "flowchain:node:stop",
        "flowchain:wallet:e2e",
        "flowchain:wallet:transfer:e2e",
        "flowchain:bridge:mock:e2e",
        "flowchain:bridge:live:check",
        "flowchain:bridge:relayer:once",
        "flowchain:bridge:reconciliation",
        "flowchain:public-rpc:deployment-bundle",
        "flowchain:public-rpc:deployment:automation",
        "flowchain:backup:restore:validate",
        "flowchain:backup:install:validate",
        "flowchain:backup:install:systemd",
        "flowchain:backup:install:systemd:validate",
        "flowchain:ops:incident-drill",
        "flowchain:external-tester:packet",
        "flowchain:completion:audit",
        "flowchain:truth-table",
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

$driveName = [System.IO.Path]::GetPathRoot($repoRoot).Substring(0, 1)
$drive = Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue
$freeGb = if ($drive) { [Math]::Round(($drive.Free / 1GB), 2) } else { 0 }
Add-DoctorCheck `
    -Name "disk-free:$driveName" `
    -Status $(if ($drive -and $freeGb -ge 5) { "running" } elseif ($drive) { "warning" } else { "misconfigured" }) `
    -Owner "storage" `
    -Detail $(if ($drive) { "$freeGb GiB free on $driveName`:" } else { "drive not found for repo root" }) `
    -NextCommand "free disk space before public operation"

$statePath = Join-Path $repoRoot "devnet/local/state.json"
$stateExists = Test-Path -LiteralPath $statePath
$stateAgeSeconds = $null
if ($stateExists) {
    $stateAgeSeconds = [int][Math]::Max(0, [Math]::Floor(((Get-Date) - (Get-Item -LiteralPath $statePath).LastWriteTime).TotalSeconds))
}
Add-DoctorCheck `
    -Name "state-file" `
    -Status $(if ($stateExists) { "running" } else { "stopped" }) `
    -Owner "storage" `
    -Detail $(if ($stateExists) { "devnet/local/state.json age seconds: $stateAgeSeconds" } else { "devnet/local/state.json missing" }) `
    -NextCommand "npm run flowchain:service:start -- -LiveProfile"

$serviceStatusPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-status-report.json"
$serviceStatus = Read-FlowChainJsonIfExists -Path $serviceStatusPath
$chain = Get-DoctorProp -Object $serviceStatus -Name "chain"
$latestHeight = [string](Get-DoctorProp -Object $chain -Name "latestHeight" -Default "")
$finalizedHeight = [string](Get-DoctorProp -Object $chain -Name "finalizedHeight" -Default "")
$reportedStateAge = Get-DoctorProp -Object $chain -Name "stateFileLastWriteAgeSeconds" -Default $null
Add-DoctorCheck `
    -Name "service-status-report" `
    -Status $(if ($null -ne $serviceStatus -and [string](Get-DoctorProp -Object $serviceStatus -Name "status" -Default "") -eq "passed") { "running" } else { "stopped" }) `
    -Owner "service" `
    -Detail $(if ($null -ne $serviceStatus) { "latestHeight=$latestHeight finalizedHeight=$finalizedHeight stateAge=$reportedStateAge" } else { "service status report missing" }) `
    -NextCommand "npm run flowchain:service:status -- -AllowBlocked"

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

$ownerInputNames = @(
    "FLOWCHAIN_RPC_PUBLIC_URL",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
    "FLOWCHAIN_RPC_TLS_TERMINATED",
    "FLOWCHAIN_RPC_STATE_BACKUP_PATH",
    "FLOWCHAIN_TESTER_WRITE_ENABLED",
    "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256",
    "FLOWCHAIN_TESTER_MAX_SEND_UNITS",
    "FLOWCHAIN_PILOT_OPERATOR_ACK",
    "FLOWCHAIN_BASE8453_RPC_URL",
    "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
    "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
    "FLOWCHAIN_BASE8453_ASSET_DECIMALS",
    "FLOWCHAIN_BASE8453_FROM_BLOCK",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_PILOT_CONFIRMATIONS"
)
$missingLive = @($ownerInputNames | Where-Object { [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_, "Process")) })
Add-DoctorCheck `
    -Name "owner-input-env" `
    -Status $(if ($missingLive.Count -eq 0) { "running" } else { "blocked-on-env" }) `
    -Owner "public-rpc/backup/tester/bridge" `
    -Detail $(if ($missingLive.Count -eq 0) { "owner input env names are present" } else { "missing owner input names: $($missingLive -join ', ')" }) `
    -NextCommand "npm run flowchain:owner-inputs -- -AllowBlocked"

foreach ($group in @(
    [ordered]@{ name = "public-rpc-env"; owner = "public-rpc"; names = @("FLOWCHAIN_RPC_PUBLIC_URL", "FLOWCHAIN_RPC_ALLOWED_ORIGINS", "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE", "FLOWCHAIN_RPC_TLS_TERMINATED"); next = "npm run flowchain:public-rpc:check -- -AllowBlocked" },
    [ordered]@{ name = "backup-env"; owner = "backup"; names = @("FLOWCHAIN_RPC_STATE_BACKUP_PATH"); next = "npm run flowchain:backup:check -- -AllowBlocked" },
    [ordered]@{ name = "tester-env"; owner = "tester"; names = @("FLOWCHAIN_TESTER_WRITE_ENABLED", "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256", "FLOWCHAIN_TESTER_MAX_SEND_UNITS"); next = "npm run flowchain:tester:readiness -- -AllowBlocked" },
    [ordered]@{ name = "bridge-env"; owner = "bridge"; names = @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_BASE8453_ASSET_DECIMALS", "FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS"); next = "npm run flowchain:bridge:live:check -- -AllowBlocked" }
)) {
    $missingGroup = @($group.names | Where-Object { [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_, "Process")) })
    Add-DoctorCheck `
        -Name $group.name `
        -Status $(if ($missingGroup.Count -eq 0) { "running" } else { "blocked-on-env" }) `
        -Owner $group.owner `
        -Detail $(if ($missingGroup.Count -eq 0) { "required env names are present" } else { "missing names: $($missingGroup -join ', ')" }) `
        -NextCommand $group.next
}

$ownerEnvFile = [Environment]::GetEnvironmentVariable("FLOWCHAIN_OWNER_ENV_FILE", "Process")
Add-DoctorCheck `
    -Name "owner-env-file" `
    -Status $(if ([string]::IsNullOrWhiteSpace($ownerEnvFile)) { "stopped" } elseif (Test-Path -LiteralPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ownerEnvFile)) { "running" } else { "blocked-on-env" }) `
    -Owner "ops" `
    -Detail $(if ([string]::IsNullOrWhiteSpace($ownerEnvFile)) { "FLOWCHAIN_OWNER_ENV_FILE is not set; direct env values or the template can be used" } else { "FLOWCHAIN_OWNER_ENV_FILE is set to a local path name; value not printed" }) `
    -NextCommand "npm run flowchain:owner-env:template"

$failed = @($checks | Where-Object { $_.status -eq "misconfigured" })
$blocked = @($checks | Where-Object { $_.status -eq "blocked-on-env" })
$warnings = @($checks | Where-Object { $_.status -eq "warning" })
$report = [ordered]@{
    schema = "flowchain.doctor_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = if ($failed.Count -gt 0) { "failed" } elseif ($blocked.Count -gt 0) { "blocked" } elseif ($warnings.Count -gt 0) { "degraded" } else { "passed" }
    repoRoot = $repoRoot
    diskFreeGiB = $freeGb
    stateFileLastWriteAgeSeconds = $stateAgeSeconds
    latestHeight = $latestHeight
    finalizedHeight = $finalizedHeight
    localUrls = [ordered]@{
        controlPlaneHealth = "http://127.0.0.1:8787/health"
        dashboard = "http://127.0.0.1:5173/"
    }
    checks = @($checks)
    failedChecks = @($failed)
    blockedChecks = @($blocked)
    warningChecks = @($warnings)
    missingLiveEnvNames = $missingLive
    missingOwnerInputNames = $missingLive
    blockedOnlyOnOwnerInputs = $failed.Count -eq 0 -and $blocked.Count -gt 0
}
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 14

Write-Host "FlowChain doctor status: $($report.status)"
Write-Host "Report: $reportFullPath"
if ($failed.Count -gt 0) {
    throw "FlowChain doctor found misconfigured checks."
}

