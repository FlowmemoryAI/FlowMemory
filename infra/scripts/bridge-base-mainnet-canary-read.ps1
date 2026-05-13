param(
    [Parameter(Mandatory = $true)]
    [string]$RpcUrl,

    [Parameter(Mandatory = $true)]
    [string]$LockboxAddress,

    [Parameter(Mandatory = $true)]
    [string]$FromBlock,

    [Parameter(Mandatory = $true)]
    [string]$ToBlock,

    [Parameter(Mandatory = $true)]
    [switch]$AcknowledgeRealFunds,

    [Parameter(Mandatory = $true)]
    [ValidateRange(0.01, 25)]
    [double]$MaxUsd,

    [string]$Out = "services/bridge-relayer/out/base-mainnet-canary-bridge-observation.json",

    [string]$CreditOut = "services/bridge-relayer/out/base-mainnet-canary-bridge-credit.json",

    [string]$HandoffOut = "services/bridge-relayer/out/base-mainnet-canary-bridge-handoff.json"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

Write-Host "Reading Base mainnet bridge canary logs." -ForegroundColor Yellow
Write-Host "Chain: Base mainnet (8453)"
Write-Host "Lockbox: $LockboxAddress"
Write-Host "Block range: $FromBlock-$ToBlock"
Write-Host "Max USD guardrail: $MaxUsd"
Write-Host "Broadcast: false; this command is read-only."

npm run bridge:observe -- `
    --mode base-mainnet-canary `
    --rpc-url $RpcUrl `
    --lockbox-address $LockboxAddress `
    --from-block $FromBlock `
    --to-block $ToBlock `
    --acknowledge-real-funds `
    --max-usd $MaxUsd `
    --out $Out `
    --credit-out $CreditOut `
    --handoff-out $HandoffOut

Write-Host "Base mainnet canary bridge read wrote $Out and $HandoffOut" -ForegroundColor Green
