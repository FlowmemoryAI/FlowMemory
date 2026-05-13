param(
    [Parameter(Mandatory = $true)]
    [string]$RpcUrl,

    [Parameter(Mandatory = $true)]
    [string]$LockboxAddress,

    [Parameter(Mandatory = $true)]
    [string]$FromBlock,

    [Parameter(Mandatory = $true)]
    [string]$ToBlock,

    [string]$Out = "services/bridge-relayer/out/base-sepolia-bridge-observation.json",

    [string]$CreditOut = "services/bridge-relayer/out/base-sepolia-bridge-credit.json",

    [string]$HandoffOut = "services/bridge-relayer/out/base-sepolia-bridge-handoff.json"
)

$ErrorActionPreference = "Stop"

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
