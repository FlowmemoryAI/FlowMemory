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

    [string]$Out = "services/bridge-relayer/out/base-mainnet-canary-bridge-observation.json"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

npm run bridge:observe -- `
    --mode base-mainnet-canary `
    --rpc-url $RpcUrl `
    --lockbox-address $LockboxAddress `
    --from-block $FromBlock `
    --to-block $ToBlock `
    --acknowledge-real-funds `
    --max-usd $MaxUsd `
    --out $Out

Write-Host "Base mainnet canary bridge read wrote $Out" -ForegroundColor Green
