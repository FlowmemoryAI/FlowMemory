param(
    [string] $ReportPath = "devnet/local/bridge-live-readiness/bridge-live-readiness-report.json",
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)

function Import-LivePilotEnvLoaderIfConfigured {
    $loaderPath = [Environment]::GetEnvironmentVariable("FLOWCHAIN_LIVE_PILOT_ENV_LOADER", "Process")
    if ([string]::IsNullOrWhiteSpace($loaderPath)) {
        return [ordered]@{
            configured = $false
            imported = $false
            problem = ""
        }
    }

    try {
        $fullLoaderPath = [System.IO.Path]::GetFullPath($loaderPath)
    }
    catch {
        throw "FLOWCHAIN_LIVE_PILOT_ENV_LOADER is not a valid path."
    }

    if (-not (Test-Path -LiteralPath $fullLoaderPath)) {
        throw "FLOWCHAIN_LIVE_PILOT_ENV_LOADER points to a missing file."
    }
    if ([System.IO.Path]::GetExtension($fullLoaderPath) -ne ".ps1") {
        throw "FLOWCHAIN_LIVE_PILOT_ENV_LOADER must point to a PowerShell loader script."
    }

    . $fullLoaderPath
    return [ordered]@{
        configured = $true
        imported = $true
        problem = ""
    }
}

$livePilotEnvLoader = Import-LivePilotEnvLoaderIfConfigured

$OperatorAckValue = "I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
$Base8453ChainIdHex = "0x2105"
$MaxSingleDepositWeiLimit = [System.Numerics.BigInteger]::Parse("100000000000000", [System.Globalization.CultureInfo]::InvariantCulture)
$TotalCapWeiLimit = [System.Numerics.BigInteger]::Parse("1000000000000000", [System.Globalization.CultureInfo]::InvariantCulture)
$MaxBlockRange = [System.Numerics.BigInteger]::Parse("5000", [System.Globalization.CultureInfo]::InvariantCulture)
$MinConfirmationDepth = [System.Numerics.BigInteger]::Parse("2", [System.Globalization.CultureInfo]::InvariantCulture)
$MaxConfirmationDepth = [System.Numerics.BigInteger]::Parse("256", [System.Globalization.CultureInfo]::InvariantCulture)

$requiredEnv = @(
    "FLOWCHAIN_PILOT_OPERATOR_ACK",
    "FLOWCHAIN_BASE8453_RPC_URL",
    "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
    "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
    "FLOWCHAIN_BASE8453_ASSET_DECIMALS",
    "FLOWCHAIN_BASE8453_FROM_BLOCK",
    "FLOWCHAIN_BASE8453_TO_BLOCK",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_PILOT_CONFIRMATIONS"
)

function Get-BridgeEnv {
    param([Parameter(Mandatory = $true)][string] $Name)
    return [Environment]::GetEnvironmentVariable($Name, "Process")
}

function Add-Problem {
    param(
        [System.Collections.ArrayList] $Problems,
        [Parameter(Mandatory = $true)][string] $EnvName,
        [Parameter(Mandatory = $true)][string] $Reason,
        [string] $Kind = "blocked"
    )

    [void] $Problems.Add([ordered]@{
        envName = $EnvName
        reason = $Reason
        kind = $Kind
    })
}

function Convert-DecimalEnv {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [AllowNull()][string] $Value,
        [System.Collections.ArrayList] $Problems
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }
    if ($Value -notmatch '^(0|[1-9][0-9]*)$') {
        Add-Problem -Problems $Problems -EnvName $Name -Reason "must be a uint256-compatible decimal string" -Kind "failed"
        return $null
    }
    try {
        return [System.Numerics.BigInteger]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        Add-Problem -Problems $Problems -EnvName $Name -Reason "outside supported uint256-compatible decimal range" -Kind "failed"
        return $null
    }
}

function Convert-PositiveNumberEnv {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [AllowNull()][string] $Value,
        [decimal] $DefaultValue,
        [System.Collections.ArrayList] $Problems
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $DefaultValue
    }

    $parsed = [decimal] 0
    if (-not [decimal]::TryParse($Value, [System.Globalization.NumberStyles]::AllowDecimalPoint, [System.Globalization.CultureInfo]::InvariantCulture, [ref] $parsed)) {
        Add-Problem -Problems $Problems -EnvName $Name -Reason "must be a positive decimal number" -Kind "failed"
        return $DefaultValue
    }
    if ($parsed -le 0) {
        Add-Problem -Problems $Problems -EnvName $Name -Reason "must be greater than zero" -Kind "failed"
        return $DefaultValue
    }
    return $parsed
}

function Invoke-SafeRpcChainId {
    param([Parameter(Mandatory = $true)][string] $RpcUrl)

    $body = ([ordered]@{
        jsonrpc = "2.0"
        id = 1
        method = "eth_chainId"
        params = @()
    } | ConvertTo-Json -Depth 6 -Compress)

    try {
        $response = Invoke-RestMethod -Uri $RpcUrl -Method Post -ContentType "application/json" -Body $body -TimeoutSec 20
    }
    catch {
        throw "Could not read eth_chainId from FLOWCHAIN_BASE8453_RPC_URL."
    }

    if ($response.PSObject.Properties.Name -contains "error") {
        throw "RPC eth_chainId returned an error."
    }
    if (-not ($response.PSObject.Properties.Name -contains "result")) {
        throw "RPC eth_chainId did not return result."
    }

    return [string]$response.result
}

$problems = New-Object System.Collections.ArrayList
$missingEnv = New-Object System.Collections.ArrayList
$checks = [ordered]@{}

foreach ($name in $requiredEnv) {
    if ([string]::IsNullOrWhiteSpace((Get-BridgeEnv -Name $name))) {
        [void] $missingEnv.Add($name)
        Add-Problem -Problems $problems -EnvName $name -Reason "missing required env value"
    }
}

$ack = Get-BridgeEnv -Name "FLOWCHAIN_PILOT_OPERATOR_ACK"
if (-not [string]::IsNullOrWhiteSpace($ack) -and $ack -ne $OperatorAckValue) {
    Add-Problem -Problems $problems -EnvName "FLOWCHAIN_PILOT_OPERATOR_ACK" -Reason "acknowledgement value is not the required exact string" -Kind "failed"
}

$rpcUrl = Get-BridgeEnv -Name "FLOWCHAIN_BASE8453_RPC_URL"
if (-not [string]::IsNullOrWhiteSpace($rpcUrl)) {
    $uri = $null
    if (-not [System.Uri]::TryCreate($rpcUrl, [System.UriKind]::Absolute, [ref] $uri) -or ($uri.Scheme -ne "http" -and $uri.Scheme -ne "https")) {
        Add-Problem -Problems $problems -EnvName "FLOWCHAIN_BASE8453_RPC_URL" -Reason "must be an absolute HTTP(S) URL" -Kind "failed"
    }
    else {
        try {
            $chainHex = Invoke-SafeRpcChainId -RpcUrl $rpcUrl
            $checks.chainId = [ordered]@{
                expected = "Base 8453"
                passed = ($chainHex -eq $Base8453ChainIdHex)
            }
            if ($chainHex -ne $Base8453ChainIdHex) {
                Add-Problem -Problems $problems -EnvName "FLOWCHAIN_BASE8453_RPC_URL" -Reason "wrong chain id; expected Base 8453" -Kind "failed"
            }
        }
        catch {
            Add-Problem -Problems $problems -EnvName "FLOWCHAIN_BASE8453_RPC_URL" -Reason $_.Exception.Message -Kind "failed"
        }
    }
}

foreach ($name in @("FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN")) {
    $value = Get-BridgeEnv -Name $name
    if (-not [string]::IsNullOrWhiteSpace($value) -and $value -notmatch '^0x[0-9a-fA-F]{40}$') {
        Add-Problem -Problems $problems -EnvName $name -Reason "must be a 20-byte hex address" -Kind "failed"
    }
}

$assetDecimals = Convert-DecimalEnv -Name "FLOWCHAIN_BASE8453_ASSET_DECIMALS" -Value (Get-BridgeEnv -Name "FLOWCHAIN_BASE8453_ASSET_DECIMALS") -Problems $problems
if ($null -ne $assetDecimals -and ($assetDecimals -lt 0 -or $assetDecimals -gt 255)) {
    Add-Problem -Problems $problems -EnvName "FLOWCHAIN_BASE8453_ASSET_DECIMALS" -Reason "must be between 0 and 255" -Kind "failed"
}

$maxDeposit = Convert-DecimalEnv -Name "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI" -Value (Get-BridgeEnv -Name "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI") -Problems $problems
$totalCap = Convert-DecimalEnv -Name "FLOWCHAIN_PILOT_TOTAL_CAP_WEI" -Value (Get-BridgeEnv -Name "FLOWCHAIN_PILOT_TOTAL_CAP_WEI") -Problems $problems
if ($null -ne $maxDeposit) {
    if ($maxDeposit -eq 0) { Add-Problem -Problems $problems -EnvName "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI" -Reason "must be nonzero" -Kind "failed" }
    if ($maxDeposit -gt $MaxSingleDepositWeiLimit) { Add-Problem -Problems $problems -EnvName "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI" -Reason "above documented pilot cap" -Kind "failed" }
}
if ($null -ne $totalCap) {
    if ($totalCap -eq 0) { Add-Problem -Problems $problems -EnvName "FLOWCHAIN_PILOT_TOTAL_CAP_WEI" -Reason "must be nonzero" -Kind "failed" }
    if ($totalCap -gt $TotalCapWeiLimit) { Add-Problem -Problems $problems -EnvName "FLOWCHAIN_PILOT_TOTAL_CAP_WEI" -Reason "above documented pilot cap" -Kind "failed" }
}
if ($null -ne $maxDeposit -and $null -ne $totalCap -and $totalCap -lt $maxDeposit) {
    Add-Problem -Problems $problems -EnvName "FLOWCHAIN_PILOT_TOTAL_CAP_WEI" -Reason "must be greater than or equal to max deposit" -Kind "failed"
}

$confirmations = Convert-DecimalEnv -Name "FLOWCHAIN_PILOT_CONFIRMATIONS" -Value (Get-BridgeEnv -Name "FLOWCHAIN_PILOT_CONFIRMATIONS") -Problems $problems
if ($null -ne $confirmations) {
    if ($confirmations -lt $MinConfirmationDepth) { Add-Problem -Problems $problems -EnvName "FLOWCHAIN_PILOT_CONFIRMATIONS" -Reason "confirmation depth is unsafe" -Kind "failed" }
    if ($confirmations -gt $MaxConfirmationDepth) { Add-Problem -Problems $problems -EnvName "FLOWCHAIN_PILOT_CONFIRMATIONS" -Reason "confirmation depth is unexpectedly high for the pilot" -Kind "failed" }
}
$targetSettlementSeconds = Convert-PositiveNumberEnv -Name "FLOWCHAIN_BRIDGE_TARGET_SETTLEMENT_SECONDS" -Value (Get-BridgeEnv -Name "FLOWCHAIN_BRIDGE_TARGET_SETTLEMENT_SECONDS") -DefaultValue ([decimal] 30) -Problems $problems
$estimatedBaseBlockSeconds = Convert-PositiveNumberEnv -Name "FLOWCHAIN_BASE8453_ESTIMATED_BLOCK_SECONDS" -Value (Get-BridgeEnv -Name "FLOWCHAIN_BASE8453_ESTIMATED_BLOCK_SECONDS") -DefaultValue ([decimal] 2) -Problems $problems
$pollSeconds = Convert-PositiveNumberEnv -Name "FLOWCHAIN_BRIDGE_POLL_SECONDS" -Value (Get-BridgeEnv -Name "FLOWCHAIN_BRIDGE_POLL_SECONDS") -DefaultValue ([decimal] 30) -Problems $problems
$estimatedConfirmationSeconds = $null
$estimatedDetectionSeconds = $null
$settlementTargetFeasible = $false
if ($null -ne $confirmations) {
    $estimatedConfirmationSeconds = ([decimal] $confirmations) * $estimatedBaseBlockSeconds
    $estimatedDetectionSeconds = $estimatedConfirmationSeconds + $pollSeconds
    $settlementTargetFeasible = $estimatedDetectionSeconds -le $targetSettlementSeconds
    if (-not $settlementTargetFeasible) {
        Add-Problem -Problems $problems -EnvName "FLOWCHAIN_BRIDGE_TARGET_SETTLEMENT_SECONDS" -Reason "confirmation depth plus polling cannot meet the fast settlement target" -Kind "failed"
    }
}

$fromBlock = Convert-DecimalEnv -Name "FLOWCHAIN_BASE8453_FROM_BLOCK" -Value (Get-BridgeEnv -Name "FLOWCHAIN_BASE8453_FROM_BLOCK") -Problems $problems
$toBlock = Convert-DecimalEnv -Name "FLOWCHAIN_BASE8453_TO_BLOCK" -Value (Get-BridgeEnv -Name "FLOWCHAIN_BASE8453_TO_BLOCK") -Problems $problems
if ($null -ne $fromBlock -and $null -ne $toBlock) {
    if ($fromBlock -gt $toBlock) {
        Add-Problem -Problems $problems -EnvName "FLOWCHAIN_BASE8453_FROM_BLOCK" -Reason "from block must be <= to block" -Kind "failed"
    }
    elseif (($toBlock - $fromBlock) -gt $MaxBlockRange) {
        Add-Problem -Problems $problems -EnvName "FLOWCHAIN_BASE8453_TO_BLOCK" -Reason "block range is too broad" -Kind "failed"
    }
}

$failed = @($problems | Where-Object { $_.kind -eq "failed" })
$status = if ($failed.Count -gt 0) { "failed" } elseif ($problems.Count -gt 0) { "blocked" } else { "passed" }

$report = [ordered]@{
    schema = "flowchain.bridge_live_readiness_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    owner = "bridge/ops"
    command = "npm run flowchain:bridge:live:check"
    requiredEnvNames = $requiredEnv
    missingEnvNames = @($missingEnv | Select-Object -Unique)
    checks = $checks
    settlementPolicy = [ordered]@{
        targetSettlementSeconds = "$targetSettlementSeconds"
        estimatedBaseBlockSeconds = "$estimatedBaseBlockSeconds"
        confirmationDepth = $(if ($null -eq $confirmations) { $null } else { $confirmations.ToString() })
        estimatedConfirmationSeconds = $(if ($null -eq $estimatedConfirmationSeconds) { $null } else { "$estimatedConfirmationSeconds" })
        pollSeconds = "$pollSeconds"
        estimatedDetectionSeconds = $(if ($null -eq $estimatedDetectionSeconds) { $null } else { "$estimatedDetectionSeconds" })
        targetFeasible = $settlementTargetFeasible
    }
    problems = @($problems)
    capLimits = [ordered]@{
        maxSingleDepositWei = $MaxSingleDepositWeiLimit.ToString()
        totalCapWei = $TotalCapWeiLimit.ToString()
        maxBlockRange = $MaxBlockRange.ToString()
        minConfirmationDepth = $MinConfirmationDepth.ToString()
    }
    livePilotEnvLoader = $livePilotEnvLoader
    broadcasts = $false
    printsEnvValues = $false
    noSecrets = $true
}
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

Write-Host "FlowChain bridge live readiness status: $status"
Write-Host "Report: $reportFullPath"
if ($missingEnv.Count -gt 0) {
    Write-Host "Missing env names: $((@($missingEnv | Select-Object -Unique)) -join ', ')"
}
if ($status -ne "passed" -and -not $AllowBlocked) {
    throw "Bridge live readiness $status. See report for env names and reasons."
}
