param(
    [string] $ReportPath = "devnet/local/production-l1-e2e/bridge-live-readiness-report.json",
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)

$Base8453ChainId = 8453
$OperatorAckValue = "I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
$MaxSingleDepositWeiLimit = [UInt64] 100000000000000
$TotalCapWeiLimit = [UInt64] 1000000000000000
$MaxBlockRange = [UInt64] 5000
$MinConfirmationDepth = [UInt64] 2
$MaxConfirmationDepth = [UInt64] 256

$requiredEnv = @(
    "FLOWCHAIN_PILOT_OPERATOR_ACK",
    "FLOWCHAIN_BASE8453_RPC_URL",
    "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
    "FLOWCHAIN_BASE8453_FROM_BLOCK",
    "FLOWCHAIN_BASE8453_TO_BLOCK",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_BASE8453_CONFIRMATION_DEPTH"
)

function Get-EnvValue {
    param([Parameter(Mandatory = $true)][string] $Name)
    return [Environment]::GetEnvironmentVariable($Name, "Process")
}

function Add-Problem {
    param(
        [System.Collections.ArrayList] $Problems,
        [string] $EnvName,
        [string] $Reason,
        [string] $Kind = "blocked"
    )

    [void] $Problems.Add([ordered]@{
        envName = $EnvName
        reason = $Reason
        kind = $Kind
    })
}

function Convert-UInt64Env {
    param(
        [string] $Name,
        [string] $Value,
        [System.Collections.ArrayList] $Problems
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        Add-Problem -Problems $Problems -EnvName $Name -Reason "missing required env value"
        return $null
    }
    if ($Value -notmatch '^[0-9]+$') {
        Add-Problem -Problems $Problems -EnvName $Name -Reason "must be a non-negative decimal integer" -Kind "failed"
        return $null
    }
    try {
        return [UInt64]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        Add-Problem -Problems $Problems -EnvName $Name -Reason "outside supported UInt64 range" -Kind "failed"
        return $null
    }
}

function Invoke-SafeRpcChainId {
    param([string] $RpcUrl)

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

    return $response.result
}

$problems = New-Object System.Collections.ArrayList
$checks = [ordered]@{}
$missingEnv = New-Object System.Collections.ArrayList

foreach ($name in $requiredEnv) {
    if ([string]::IsNullOrWhiteSpace((Get-EnvValue -Name $name))) {
        [void] $missingEnv.Add($name)
        Add-Problem -Problems $problems -EnvName $name -Reason "missing required env value"
    }
}

$tokenMode = Get-EnvValue -Name "FLOWCHAIN_BASE8453_TOKEN_MODE"
if ([string]::IsNullOrWhiteSpace($tokenMode)) {
    $tokenMode = "native"
}
$checks.tokenMode = $tokenMode
if ($tokenMode -in @("erc20", "token", "supported-token")) {
    $supportedToken = Get-EnvValue -Name "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN"
    if ([string]::IsNullOrWhiteSpace($supportedToken)) {
        [void] $missingEnv.Add("FLOWCHAIN_BASE8453_SUPPORTED_TOKEN")
        Add-Problem -Problems $problems -EnvName "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN" -Reason "missing for token mode"
    }
    elseif ($supportedToken -notmatch '^0x[0-9a-fA-F]{40}$') {
        Add-Problem -Problems $problems -EnvName "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN" -Reason "must be a 20-byte hex address" -Kind "failed"
    }
}

$ack = Get-EnvValue -Name "FLOWCHAIN_PILOT_OPERATOR_ACK"
if (-not [string]::IsNullOrWhiteSpace($ack) -and $ack -ne $OperatorAckValue) {
    Add-Problem -Problems $problems -EnvName "FLOWCHAIN_PILOT_OPERATOR_ACK" -Reason "acknowledgement value is not the required exact string" -Kind "failed"
}

$rpcUrl = Get-EnvValue -Name "FLOWCHAIN_BASE8453_RPC_URL"
if (-not [string]::IsNullOrWhiteSpace($rpcUrl)) {
    $uri = $null
    if (-not [System.Uri]::TryCreate($rpcUrl, [System.UriKind]::Absolute, [ref] $uri) -or ($uri.Scheme -ne "http" -and $uri.Scheme -ne "https")) {
        Add-Problem -Problems $problems -EnvName "FLOWCHAIN_BASE8453_RPC_URL" -Reason "must be an absolute HTTP(S) URL" -Kind "failed"
    }
    else {
        try {
            $chainHex = Invoke-SafeRpcChainId -RpcUrl $rpcUrl
            if ($chainHex -notmatch '^0x[0-9a-fA-F]+$') {
                Add-Problem -Problems $problems -EnvName "FLOWCHAIN_BASE8453_RPC_URL" -Reason "eth_chainId returned invalid hex" -Kind "failed"
            }
            else {
                $actualChainId = [Convert]::ToInt64($chainHex.Substring(2), 16)
                $checks.chainId = [ordered]@{
                    expected = $Base8453ChainId
                    actual = $actualChainId
                    passed = ($actualChainId -eq $Base8453ChainId)
                }
                if ($actualChainId -ne $Base8453ChainId) {
                    Add-Problem -Problems $problems -EnvName "FLOWCHAIN_BASE8453_RPC_URL" -Reason "wrong chain id; expected Base 8453" -Kind "failed"
                }
            }
        }
        catch {
            Add-Problem -Problems $problems -EnvName "FLOWCHAIN_BASE8453_RPC_URL" -Reason $_.Exception.Message -Kind "failed"
        }
    }
}

$lockbox = Get-EnvValue -Name "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS"
if (-not [string]::IsNullOrWhiteSpace($lockbox) -and $lockbox -notmatch '^0x[0-9a-fA-F]{40}$') {
    Add-Problem -Problems $problems -EnvName "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS" -Reason "must be a 20-byte hex address" -Kind "failed"
}

$maxDeposit = Convert-UInt64Env -Name "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI" -Value (Get-EnvValue -Name "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI") -Problems $problems
$totalCap = Convert-UInt64Env -Name "FLOWCHAIN_PILOT_TOTAL_CAP_WEI" -Value (Get-EnvValue -Name "FLOWCHAIN_PILOT_TOTAL_CAP_WEI") -Problems $problems
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

$confirmations = Convert-UInt64Env -Name "FLOWCHAIN_BASE8453_CONFIRMATION_DEPTH" -Value (Get-EnvValue -Name "FLOWCHAIN_BASE8453_CONFIRMATION_DEPTH") -Problems $problems
if ($null -ne $confirmations) {
    if ($confirmations -lt $MinConfirmationDepth) { Add-Problem -Problems $problems -EnvName "FLOWCHAIN_BASE8453_CONFIRMATION_DEPTH" -Reason "confirmation depth is unsafe" -Kind "failed" }
    if ($confirmations -gt $MaxConfirmationDepth) { Add-Problem -Problems $problems -EnvName "FLOWCHAIN_BASE8453_CONFIRMATION_DEPTH" -Reason "confirmation depth is unexpectedly high for the pilot" -Kind "failed" }
}

$fromBlock = Convert-UInt64Env -Name "FLOWCHAIN_BASE8453_FROM_BLOCK" -Value (Get-EnvValue -Name "FLOWCHAIN_BASE8453_FROM_BLOCK") -Problems $problems
$toBlock = Convert-UInt64Env -Name "FLOWCHAIN_BASE8453_TO_BLOCK" -Value (Get-EnvValue -Name "FLOWCHAIN_BASE8453_TO_BLOCK") -Problems $problems
if ($null -ne $fromBlock -and $null -ne $toBlock) {
    if ($fromBlock -gt $toBlock) {
        Add-Problem -Problems $problems -EnvName "FLOWCHAIN_BASE8453_FROM_BLOCK" -Reason "from block must be <= to block" -Kind "failed"
    }
    elseif (($toBlock - $fromBlock) -gt $MaxBlockRange) {
        Add-Problem -Problems $problems -EnvName "FLOWCHAIN_BASE8453_TO_BLOCK" -Reason "block range is too broad" -Kind "failed"
    }
}

$failed = @($problems | Where-Object { $_.kind -eq "failed" })
$status = if ($failed.Count -gt 0) {
    "failed"
}
elseif ($problems.Count -gt 0) {
    "blocked"
}
else {
    "passed"
}

$report = [ordered]@{
    schema = "flowchain.bridge_live_readiness_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    owner = "bridge/ops"
    baseChainId = $Base8453ChainId
    command = "npm run flowchain:bridge:live:check"
    missingEnvNames = @($missingEnv | Select-Object -Unique)
    envNames = @($requiredEnv + @("FLOWCHAIN_BASE8453_TOKEN_MODE", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN"))
    checks = $checks
    problems = @($problems)
    capLimits = [ordered]@{
        maxSingleDepositWei = $MaxSingleDepositWeiLimit.ToString()
        totalCapWei = $TotalCapWeiLimit.ToString()
        maxBlockRange = $MaxBlockRange.ToString()
        minConfirmationDepth = $MinConfirmationDepth.ToString()
    }
    broadcasts = $false
    printsEnvValues = $false
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

