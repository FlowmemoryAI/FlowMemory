param(
    [string]$RpcUrl = $env:ANVIL_RPC_URL,

    [string]$LockboxAddress = $env:ANVIL_BRIDGE_LOCKBOX_ADDRESS,

    [string]$FromBlock = $env:ANVIL_BRIDGE_FROM_BLOCK,

    [string]$ToBlock = $env:ANVIL_BRIDGE_TO_BLOCK,

    [string]$Out = "services/bridge-relayer/out/local-anvil-bridge-observation.json",

    [string]$CreditOut = "services/bridge-relayer/out/local-anvil-bridge-credit.json",

    [string]$HandoffOut = "services/bridge-relayer/out/local-anvil-bridge-handoff.json"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

if ([string]::IsNullOrWhiteSpace($RpcUrl)) {
    $RpcUrl = "http://127.0.0.1:8545"
}

$missing = @()
if ([string]::IsNullOrWhiteSpace($LockboxAddress)) { $missing += "ANVIL_BRIDGE_LOCKBOX_ADDRESS or -LockboxAddress" }
if ([string]::IsNullOrWhiteSpace($FromBlock)) { $missing += "ANVIL_BRIDGE_FROM_BLOCK or -FromBlock" }
if ([string]::IsNullOrWhiteSpace($ToBlock)) { $missing += "ANVIL_BRIDGE_TO_BLOCK or -ToBlock" }

if ($missing.Count -gt 0) {
    throw "Local Anvil bridge observation needs: $($missing -join ', ')."
}

Write-Host "Observing local Anvil bridge deposits." -ForegroundColor Cyan
Write-Host "Chain: local Anvil (31337)"
Write-Host "Lockbox: $LockboxAddress"
Write-Host "Block range: $FromBlock-$ToBlock"
Write-Host "Broadcast: false; this command only reads logs."

npm run bridge:observe -- `
    --mode local-anvil `
    --rpc-url $RpcUrl `
    --lockbox-address $LockboxAddress `
    --from-block $FromBlock `
    --to-block $ToBlock `
    --out $Out `
    --credit-out $CreditOut `
    --handoff-out $HandoffOut

Write-Host "Local Anvil bridge observation wrote $Out and $HandoffOut" -ForegroundColor Green
