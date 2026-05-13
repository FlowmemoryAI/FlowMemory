param(
    [string]$RpcUrl = $env:BASE_SEPOLIA_RPC_URL,

    [string]$LockboxAddress = $env:BASE_BRIDGE_LOCKBOX_ADDRESS,

    [string]$FromBlock = $env:BASE_BRIDGE_FROM_BLOCK,

    [string]$ToBlock = $env:BASE_BRIDGE_TO_BLOCK,

    [string]$Out = "services/bridge-relayer/out/base-sepolia-bridge-observation.json",

    [string]$CreditOut = "services/bridge-relayer/out/base-sepolia-bridge-credit.json",

    [string]$HandoffOut = "services/bridge-relayer/out/base-sepolia-bridge-handoff.json"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

$missing = @()
if ([string]::IsNullOrWhiteSpace($RpcUrl)) { $missing += "BASE_SEPOLIA_RPC_URL or -RpcUrl" }
if ([string]::IsNullOrWhiteSpace($LockboxAddress)) { $missing += "BASE_BRIDGE_LOCKBOX_ADDRESS or -LockboxAddress" }
if ([string]::IsNullOrWhiteSpace($FromBlock)) { $missing += "BASE_BRIDGE_FROM_BLOCK or -FromBlock" }
if ([string]::IsNullOrWhiteSpace($ToBlock)) { $missing += "BASE_BRIDGE_TO_BLOCK or -ToBlock" }

if ($missing.Count -gt 0) {
    throw "Base Sepolia bridge observation needs: $($missing -join ', '). No private key is required."
}

Write-Host "Observing Base Sepolia bridge deposits." -ForegroundColor Cyan
Write-Host "Chain: Base Sepolia (84532)"
Write-Host "Lockbox: $LockboxAddress"
Write-Host "Block range: $FromBlock-$ToBlock"
Write-Host "Broadcast: false; private key not required."

npm run bridge:observe -- `
    --mode base-sepolia `
    --rpc-url $RpcUrl `
    --lockbox-address $LockboxAddress `
    --from-block $FromBlock `
    --to-block $ToBlock `
    --out $Out `
    --credit-out $CreditOut `
    --handoff-out $HandoffOut

Write-Host "Base Sepolia bridge observation wrote $Out and $HandoffOut" -ForegroundColor Green
