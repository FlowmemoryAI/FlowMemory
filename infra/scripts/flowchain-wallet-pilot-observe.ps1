param(
    [string] $ConfigPath = "devnet/local/pilot-wallet/operator-config.local.json",
    [Parameter(Mandatory = $true)]
    [string] $FromBlock,
    [Parameter(Mandatory = $true)]
    [string] $ToBlock
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$configFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ConfigPath)
if (-not (Test-Path -LiteralPath $configFullPath)) {
    throw "Pilot operator config does not exist: $configFullPath"
}

$config = Get-Content -Raw -LiteralPath $configFullPath | ConvertFrom-Json
$rpcUrl = $env:FLOWCHAIN_PILOT_RPC_URL
if ([string]::IsNullOrWhiteSpace($rpcUrl)) {
    $rpcUrl = $env:BASE_SEPOLIA_RPC_URL
}
if ([string]::IsNullOrWhiteSpace($rpcUrl)) {
    throw "Set FLOWCHAIN_PILOT_RPC_URL in the local shell before observing. The value is not written to the pilot config."
}

if ([int] $config.chainId -eq 84532) {
    & "$PSScriptRoot\bridge-base-sepolia-observe.ps1" `
        -RpcUrl $rpcUrl `
        -LockboxAddress $config.contractAddress `
        -FromBlock $FromBlock `
        -ToBlock $ToBlock
    if ($LASTEXITCODE -ne 0) {
        throw "Pilot Base Sepolia observation failed."
    }
}
elseif ([int] $config.chainId -eq 8453) {
    if ($env:FLOWCHAIN_PILOT_REAL_FUNDS_ACK -ne "I_ACCEPT_CAPPED_REAL_VALUE_PILOT") {
        throw "Base mainnet canary read requires FLOWCHAIN_PILOT_REAL_FUNDS_ACK=I_ACCEPT_CAPPED_REAL_VALUE_PILOT."
    }
    if ($config.pilotCap.unit -ne "USDC-6") {
        throw "Base mainnet canary max-USD guard currently supports pilotCap.unit USDC-6 only."
    }
    $maxUsd = [double] ([decimal]::Parse($config.pilotCap.maxAmount) / 1000000)
    if ($maxUsd -gt 25) {
        throw "Pilot cap exceeds the current 25 USD real-funds read guardrail."
    }
    & "$PSScriptRoot\bridge-base-mainnet-canary-read.ps1" `
        -RpcUrl $rpcUrl `
        -LockboxAddress $config.contractAddress `
        -FromBlock $FromBlock `
        -ToBlock $ToBlock `
        -AcknowledgeRealFunds `
        -MaxUsd $maxUsd
    if ($LASTEXITCODE -ne 0) {
        throw "Pilot Base mainnet canary observation failed."
    }
}
else {
    throw "Pilot bridge observation supports Base Sepolia 84532 and capped Base mainnet canary 8453 only."
}
