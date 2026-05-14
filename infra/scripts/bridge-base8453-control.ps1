param(
    [ValidateSet("Pause", "Resume", "EmergencyStop")]
    [string]$Action,

    [switch]$Execute
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

$requiredAck = "I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"

function Require-Env {
    param([Parameter(Mandatory = $true)][string]$Name)
    $value = [Environment]::GetEnvironmentVariable($Name, "Process")
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "$Name is required for bridge $Action."
    }
    return $value
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
        throw "Wrong chain id for bridge $Action: expected 0x2105."
    }
}

$ack = Require-Env -Name "FLOWCHAIN_PILOT_OPERATOR_ACK"
if ($ack -ne $requiredAck) {
    throw "FLOWCHAIN_PILOT_OPERATOR_ACK must equal $requiredAck."
}
$rpcUrl = Require-Env -Name "FLOWCHAIN_BASE8453_RPC_URL"
$privateKey = Require-Env -Name "FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY"
$lockbox = Require-Env -Name "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS"
if ($lockbox -notmatch '^0x[0-9a-fA-F]{40}$') {
    throw "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS must be a 20-byte hex address."
}
Invoke-ChainCheck -RpcUrl $rpcUrl

$method = if ($Action -eq "EmergencyStop") { "setEmergencyStopped(bool)" } else { "setPaused(bool)" }
$value = if ($Action -eq "Resume") { "false" } else { "true" }

if (-not $Execute) {
    $scriptName = switch ($Action) {
        "Pause" { "bridge:pause" }
        "Resume" { "bridge:resume" }
        "EmergencyStop" { "bridge:emergency-stop" }
    }
    Write-Host "Bridge $Action preflight passed. No transaction was broadcast."
    Write-Host "Exact execute command: npm run $scriptName -- -Execute"
    return
}

if (-not (Get-Command cast -ErrorAction SilentlyContinue)) {
    throw "cast is required for bridge $Action execution."
}

Write-Host "Broadcasting bridge $Action. RPC URL and private key are not printed."
& cast send $lockbox $method $value --rpc-url $rpcUrl --private-key $privateKey
if ($LASTEXITCODE -ne 0) {
    throw "cast send failed for bridge $Action."
}
