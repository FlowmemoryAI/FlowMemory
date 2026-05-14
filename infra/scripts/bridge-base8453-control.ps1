param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Pause", "Resume", "EmergencyStop")]
    [string]$Action,

    [switch]$Execute,

    [string]$ReportPath = "devnet/local/bridge-live-readiness/base8453-control-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

$requiredAck = "I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
$broadcastAck = "I_UNDERSTAND_THIS_SENDS_A_BASE8453_BRIDGE_TRANSACTION"

function Get-BridgeEnv {
    param([Parameter(Mandatory = $true)][string]$Name)
    return [Environment]::GetEnvironmentVariable($Name, "Process")
}

function Write-JsonReport {
    param([Parameter(Mandatory = $true)][object]$Value)
    $fullRoot = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd('\')
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $ReportPath))
    if (-not $fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "ReportPath must stay inside the repository."
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $fullPath) | Out-Null
    $Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $fullPath -Encoding UTF8
    Write-Host "Report: $fullPath"
}

function Invoke-ChainCheck {
    param([Parameter(Mandatory = $true)][string]$RpcUrl)
    $body = @{ jsonrpc = "2.0"; id = 1; method = "eth_chainId"; params = @() } | ConvertTo-Json -Compress
    try {
        $response = Invoke-RestMethod -Uri $RpcUrl -Method Post -ContentType "application/json" -Body $body -TimeoutSec 20
    }
    catch {
        throw "Could not read eth_chainId from FLOWCHAIN_BASE8453_RPC_URL. The endpoint is not printed."
    }
    if ($response.result -ne "0x2105") {
        throw "Wrong chain id for bridge ${Action}: expected Base 8453."
    }
}

$requiredEnv = @(
    "FLOWCHAIN_PILOT_OPERATOR_ACK",
    "FLOWCHAIN_BASE8453_RPC_URL",
    "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS"
)
if ($Execute) {
    $requiredEnv += @("FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY", "FLOWCHAIN_BASE8453_BROADCAST_ACK")
}

$missing = @()
foreach ($name in $requiredEnv) {
    if ([string]::IsNullOrWhiteSpace((Get-BridgeEnv -Name $name))) {
        $missing += $name
    }
}
if ($missing.Count -gt 0) {
    Write-JsonReport -Value ([ordered]@{
        schema = "flowmemory.bridge_base8453_control_report.v0"
        action = $Action
        status = "blocked"
        missingEnvNames = $missing
        broadcasts = $false
        noSecrets = $true
    })
    Write-Host "Bridge $Action blocked by missing env names: $($missing -join ', ')"
    throw "Bridge $Action blocked by missing env names."
}

if ((Get-BridgeEnv -Name "FLOWCHAIN_PILOT_OPERATOR_ACK") -ne $requiredAck) {
    throw "FLOWCHAIN_PILOT_OPERATOR_ACK must equal $requiredAck."
}
if ($Execute -and (Get-BridgeEnv -Name "FLOWCHAIN_BASE8453_BROADCAST_ACK") -ne $broadcastAck) {
    throw "FLOWCHAIN_BASE8453_BROADCAST_ACK must equal $broadcastAck."
}

$rpcUrl = Get-BridgeEnv -Name "FLOWCHAIN_BASE8453_RPC_URL"
$lockbox = Get-BridgeEnv -Name "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS"
if ($lockbox -notmatch '^0x[0-9a-fA-F]{40}$') {
    throw "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS must be a 20-byte hex address."
}
Invoke-ChainCheck -RpcUrl $rpcUrl

$method = if ($Action -eq "EmergencyStop") { "setEmergencyStopped(bool)" } else { "setPaused(bool)" }
$value = if ($Action -eq "Resume") { "false" } else { "true" }

if (-not $Execute) {
    $scriptName = switch ($Action) {
        "Pause" { "flowchain:bridge:pause" }
        "Resume" { "flowchain:bridge:resume" }
        "EmergencyStop" { "flowchain:bridge:emergency-stop" }
    }
    Write-JsonReport -Value ([ordered]@{
        schema = "flowmemory.bridge_base8453_control_report.v0"
        action = $Action
        status = "ready-no-broadcast"
        command = "npm run $scriptName"
        executeCommand = "npm run $scriptName -- -Execute"
        requiredEnvNames = $requiredEnv
        broadcasts = $false
        printsEnvValues = $false
        noSecrets = $true
    })
    Write-Host "Bridge $Action preflight passed. No transaction was broadcast."
    Write-Host "Exact execute command: npm run $scriptName -- -Execute"
    return
}

if (-not (Get-Command cast -ErrorAction SilentlyContinue)) {
    throw "cast is required for bridge $Action execution."
}

Write-Host "Broadcasting bridge $Action. RPC URL and private key are not printed."
$privateKey = Get-BridgeEnv -Name "FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY"
& cast send $lockbox $method $value --rpc-url $rpcUrl --private-key $privateKey
if ($LASTEXITCODE -ne 0) {
    throw "cast send failed for bridge $Action."
}

Write-JsonReport -Value ([ordered]@{
    schema = "flowmemory.bridge_base8453_control_report.v0"
    action = $Action
    status = "broadcast-complete"
    requiredEnvNames = $requiredEnv
    broadcasts = $true
    printsEnvValues = $false
    noSecrets = $true
})
