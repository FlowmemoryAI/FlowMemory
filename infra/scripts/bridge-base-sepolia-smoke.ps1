param(
    [string]$RpcUrl = $env:BASE_SEPOLIA_RPC_URL,

    [string]$LockboxAddress = $env:BASE_SEPOLIA_BRIDGE_LOCKBOX_ADDRESS,

    [string]$FromBlock = $env:BASE_SEPOLIA_BRIDGE_FROM_BLOCK,

    [string]$ToBlock = $env:BASE_SEPOLIA_BRIDGE_TO_BLOCK,

    [string]$Out = $(if ($env:BASE_SEPOLIA_BRIDGE_OBSERVATION_OUT) { $env:BASE_SEPOLIA_BRIDGE_OBSERVATION_OUT } else { "services/bridge-relayer/out/base-sepolia-bridge-observation.json" }),

    [string]$CreditOut = $(if ($env:BASE_SEPOLIA_BRIDGE_CREDIT_OUT) { $env:BASE_SEPOLIA_BRIDGE_CREDIT_OUT } else { "services/bridge-relayer/out/base-sepolia-bridge-credit.json" }),

    [string]$HandoffOut = $(if ($env:BASE_SEPOLIA_BRIDGE_HANDOFF_OUT) { $env:BASE_SEPOLIA_BRIDGE_HANDOFF_OUT } else { "services/bridge-relayer/out/base-sepolia-bridge-handoff.json" })
)

$ErrorActionPreference = "Stop"

function Require-Value {
    param(
        [string]$Name,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Name is required. Pass the parameter explicitly or set the matching Base Sepolia environment variable."
    }
}

Require-Value -Name "BASE_SEPOLIA_RPC_URL / -RpcUrl" -Value $RpcUrl
Require-Value -Name "BASE_SEPOLIA_BRIDGE_LOCKBOX_ADDRESS / -LockboxAddress" -Value $LockboxAddress
Require-Value -Name "BASE_SEPOLIA_BRIDGE_FROM_BLOCK / -FromBlock" -Value $FromBlock
Require-Value -Name "BASE_SEPOLIA_BRIDGE_TO_BLOCK / -ToBlock" -Value $ToBlock

if ($LockboxAddress -notmatch '^0x[0-9a-fA-F]{40}$') {
    throw "LockboxAddress must be a 20-byte hex address."
}

if ($FromBlock -notmatch '^\d+$' -or $ToBlock -notmatch '^\d+$') {
    throw "FromBlock and ToBlock must be decimal block numbers."
}

if ([UInt64]$FromBlock -gt [UInt64]$ToBlock) {
    throw "FromBlock must be less than or equal to ToBlock."
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "bridge-base-sepolia-observe.ps1") `
    -RpcUrl $RpcUrl `
    -LockboxAddress $LockboxAddress `
    -FromBlock $FromBlock `
    -ToBlock $ToBlock `
    -Out $Out `
    -CreditOut $CreditOut `
    -HandoffOut $HandoffOut

Write-Host "Base Sepolia bridge smoke wrote $Out and $HandoffOut" -ForegroundColor Green
