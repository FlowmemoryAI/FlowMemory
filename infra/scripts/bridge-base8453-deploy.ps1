param(
    [ValidateSet("DryRun", "Broadcast")]
    [string]$Mode = "DryRun",

    [switch]$AcknowledgeBroadcast,

    [string]$ReportPath = "devnet/local/bridge-live-readiness/base8453-deploy-readiness.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

$requiredAck = "I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
$broadcastAck = "I_UNDERSTAND_THIS_SENDS_A_BASE8453_BRIDGE_TRANSACTION"
$zeroAddress = "0x0000000000000000000000000000000000000000"

function Get-BridgeEnv {
    param([Parameter(Mandatory = $true)][string]$Name)
    return [Environment]::GetEnvironmentVariable($Name, "Process")
}

function Require-BridgeEnv {
    param([Parameter(Mandatory = $true)][string]$Name)
    $value = Get-BridgeEnv -Name $Name
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "$Name is required for Base 8453 bridge deploy $Mode."
    }
    return $value
}

function Assert-Address {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Value
    )
    if ($Value -notmatch '^0x[0-9a-fA-F]{40}$') {
        throw "$Name must be a 20-byte hex address."
    }
}

function Assert-Uint {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Value
    )
    if ($Value -notmatch '^[0-9]+$') {
        throw "$Name must be a decimal integer."
    }
    return [System.Numerics.BigInteger]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Invoke-BaseChainCheck {
    param([Parameter(Mandatory = $true)][string]$RpcUrl)
    $body = @{ jsonrpc = "2.0"; id = 1; method = "eth_chainId"; params = @() } | ConvertTo-Json -Compress
    try {
        $response = Invoke-RestMethod -Uri $RpcUrl -Method Post -ContentType "application/json" -Body $body -TimeoutSec 20
    }
    catch {
        throw "Could not read eth_chainId from FLOWCHAIN_BASE8453_RPC_URL. Do not print or commit the endpoint."
    }
    if ($response.result -ne "0x2105") {
        throw "Wrong chain id for Base 8453 deploy: expected 0x2105."
    }
}

function Get-DeployerAddress {
    param([Parameter(Mandatory = $true)][string]$PrivateKey)
    if (-not (Get-Command cast -ErrorAction SilentlyContinue)) {
        throw "cast is required to derive the deployer address without logging the private key."
    }
    $address = (& cast wallet address --private-key $PrivateKey 2>$null | Select-Object -First 1)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($address)) {
        throw "Could not derive deployer address from FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY."
    }
    $trimmed = ($address -as [string]).Trim()
    Assert-Address -Name "derived deployer address" -Value $trimmed
    return $trimmed
}

function Write-JsonReport {
    param([Parameter(Mandatory = $true)][object]$Value)
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $ReportPath))
    $fullRoot = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd('\')
    if (-not $fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "ReportPath must stay inside the repository."
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $fullPath) | Out-Null
    $Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $fullPath -Encoding UTF8
    Write-Host "Wrote $fullPath"
}

$requiredEnvNames = @(
    "FLOWCHAIN_BASE8453_RPC_URL",
    "FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY",
    "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_PILOT_OPERATOR_ACK"
)

$missing = @()
foreach ($name in $requiredEnvNames) {
    if ([string]::IsNullOrWhiteSpace((Get-BridgeEnv -Name $name))) {
        $missing += $name
    }
}

if ($Mode -eq "DryRun" -and $missing.Count -gt 0) {
    Write-JsonReport -Value ([ordered]@{
        schema = "flowmemory.bridge_base8453_deploy_readiness.v0"
        mode = $Mode
        status = "blocked"
        missingEnvNames = $missing
        requiredEnvNames = $requiredEnvNames
        exactDryRunCommand = "npm run flowchain:bridge:deploy:base8453"
        exactBroadcastCommand = "npm run flowchain:bridge:deploy:base8453 -- -Mode Broadcast -AcknowledgeBroadcast"
        printsEnvValues = $false
        broadcasts = $false
        noSecrets = $true
    })
    Write-Host "Deploy readiness blocked by missing env names: $($missing -join ', ')"
    throw "Base 8453 bridge deploy blocked by missing env names."
}

$rpcUrl = Require-BridgeEnv -Name "FLOWCHAIN_BASE8453_RPC_URL"
$privateKey = Require-BridgeEnv -Name "FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY"
$supportedToken = Require-BridgeEnv -Name "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN"
$maxDeposit = (Assert-Uint -Name "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI" -Value (Require-BridgeEnv -Name "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI")).ToString()
$totalCap = (Assert-Uint -Name "FLOWCHAIN_PILOT_TOTAL_CAP_WEI" -Value (Require-BridgeEnv -Name "FLOWCHAIN_PILOT_TOTAL_CAP_WEI")).ToString()
Assert-Address -Name "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN" -Value $supportedToken

if ([System.Numerics.BigInteger]::Parse($totalCap) -lt [System.Numerics.BigInteger]::Parse($maxDeposit)) {
    throw "FLOWCHAIN_PILOT_TOTAL_CAP_WEI must be greater than or equal to FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI."
}

Invoke-BaseChainCheck -RpcUrl $rpcUrl

$ack = Require-BridgeEnv -Name "FLOWCHAIN_PILOT_OPERATOR_ACK"
if ($ack -ne $requiredAck) {
    throw "FLOWCHAIN_PILOT_OPERATOR_ACK must equal $requiredAck."
}

$deployer = Get-DeployerAddress -PrivateKey $privateKey
$owner = $(if (Get-BridgeEnv -Name "FLOWCHAIN_BASE8453_OWNER_ADDRESS") { Get-BridgeEnv -Name "FLOWCHAIN_BASE8453_OWNER_ADDRESS" } else { $deployer })
$releaseAuthority = $(if (Get-BridgeEnv -Name "FLOWCHAIN_BASE8453_RELEASE_AUTHORITY_ADDRESS") { Get-BridgeEnv -Name "FLOWCHAIN_BASE8453_RELEASE_AUTHORITY_ADDRESS" } else { $deployer })
$settlementSubmitter = $(if (Get-BridgeEnv -Name "FLOWCHAIN_BASE8453_SETTLEMENT_SUBMITTER_ADDRESS") { Get-BridgeEnv -Name "FLOWCHAIN_BASE8453_SETTLEMENT_SUBMITTER_ADDRESS" } else { $deployer })
Assert-Address -Name "owner" -Value $owner
Assert-Address -Name "release authority" -Value $releaseAuthority
Assert-Address -Name "settlement submitter" -Value $settlementSubmitter

$allowNative = ($supportedToken.ToLowerInvariant() -eq $zeroAddress)
$allowErc20 = -not $allowNative
$erc20PerDepositCap = if ($allowErc20) { $maxDeposit } else { "0" }
$erc20TotalCap = if ($allowErc20) { $totalCap } else { "0" }
$nativePerDepositCap = if ($allowNative) { $maxDeposit } else { "0" }
$nativeTotalCap = if ($allowNative) { $totalCap } else { "0" }

$report = [ordered]@{
    schema = "flowmemory.bridge_base8453_deploy_readiness.v0"
    mode = $Mode
    status = if ($Mode -eq "DryRun") { "ready-no-broadcast" } else { "broadcast-requested" }
    baseChainId = 8453
    assetPath = if ($allowNative) { "native-eth" } else { "erc20" }
    configuredEnvNames = @(
        "FLOWCHAIN_BASE8453_RPC_URL",
        "FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY",
        "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
        "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
        "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
        "FLOWCHAIN_PILOT_OPERATOR_ACK"
    )
    pausedAfterDeploy = $false
    emergencyStoppedAfterDeploy = $false
    exactDryRunCommand = "npm run flowchain:bridge:deploy:base8453"
    exactBroadcastCommand = "npm run flowchain:bridge:deploy:base8453 -- -Mode Broadcast -AcknowledgeBroadcast"
    printsEnvValues = $false
    broadcasts = ($Mode -eq "Broadcast")
    noSecrets = $true
}

if ($Mode -eq "DryRun") {
    Write-JsonReport -Value $report
    Write-Host "Deploy dry-run passed. No transaction was broadcast."
    return
}

if (-not $AcknowledgeBroadcast) {
    throw "Broadcast mode requires -AcknowledgeBroadcast."
}
$broadcastAckValue = Get-BridgeEnv -Name "FLOWCHAIN_BASE8453_BROADCAST_ACK"
if ($broadcastAckValue -ne $broadcastAck) {
    throw "FLOWCHAIN_BASE8453_BROADCAST_ACK must equal $broadcastAck."
}
if (-not (Get-Command forge -ErrorAction SilentlyContinue)) {
    throw "forge is required for Base 8453 deployment broadcast."
}

$mappedEnv = @{
    FLOWCHAIN_BRIDGE_OWNER = $owner
    FLOWCHAIN_BRIDGE_RELEASE_AUTHORITY = $releaseAuthority
    FLOWCHAIN_SETTLEMENT_SUBMITTER = $settlementSubmitter
    FLOWCHAIN_BRIDGE_ALLOW_NATIVE = if ($allowNative) { "true" } else { "false" }
    FLOWCHAIN_BRIDGE_NATIVE_PER_DEPOSIT_CAP = $nativePerDepositCap
    FLOWCHAIN_BRIDGE_NATIVE_TOTAL_CAP = $nativeTotalCap
    FLOWCHAIN_BRIDGE_ALLOW_ERC20 = if ($allowErc20) { "true" } else { "false" }
    FLOWCHAIN_BRIDGE_ERC20_TOKEN = if ($allowErc20) { $supportedToken } else { $zeroAddress }
    FLOWCHAIN_BRIDGE_ERC20_PER_DEPOSIT_CAP = $erc20PerDepositCap
    FLOWCHAIN_BRIDGE_ERC20_TOTAL_CAP = $erc20TotalCap
}

$previous = @{}
try {
    foreach ($name in $mappedEnv.Keys) {
        $previous[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
        [Environment]::SetEnvironmentVariable($name, [string]$mappedEnv[$name], "Process")
    }
    Write-Host "Broadcasting Base 8453 bridge deploy. RPC URL and private key are not printed."
    & forge script script/DeployBridgeSpine.s.sol:DeployBridgeSpine --rpc-url $rpcUrl --private-key $privateKey --broadcast
    if ($LASTEXITCODE -ne 0) {
        throw "forge broadcast failed."
    }
}
finally {
    foreach ($name in $mappedEnv.Keys) {
        [Environment]::SetEnvironmentVariable($name, $previous[$name], "Process")
    }
}

$report.status = "broadcast-complete"
Write-JsonReport -Value $report
