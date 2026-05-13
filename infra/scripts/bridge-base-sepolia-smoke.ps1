param(
    [Parameter(Mandatory = $true)]
    [string]$RpcUrl,

    [Parameter(Mandatory = $true)]
    [string]$LockboxAddress,

    [Parameter(Mandatory = $true)]
    [string]$FromBlock,

    [Parameter(Mandatory = $true)]
    [string]$ToBlock,

    [string]$Out = "services/bridge-relayer/out/base-sepolia-bridge-observation.json"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

npm run bridge:observe -- `
    --mode base-sepolia `
    --rpc-url $RpcUrl `
    --lockbox-address $LockboxAddress `
    --from-block $FromBlock `
    --to-block $ToBlock `
    --out $Out

Write-Host "Base Sepolia bridge smoke wrote $Out" -ForegroundColor Green
