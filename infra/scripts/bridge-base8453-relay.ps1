param(
    [string]$RpcUrl = $env:FLOWCHAIN_BASE8453_RPC_URL,
    [string]$LockboxAddress = $(if ($env:FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS) { $env:FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS } else { "0xe731Bc6b117d92deDCA40a7ccAec11d16205026a" }),
    [string]$ApprovedLockboxAddress = $(if ($env:FLOWCHAIN_BASE8453_APPROVED_LOCKBOX_ADDRESS) { $env:FLOWCHAIN_BASE8453_APPROVED_LOCKBOX_ADDRESS } elseif ($env:FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS) { $env:FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS } else { "0xe731Bc6b117d92deDCA40a7ccAec11d16205026a" }),
    [string]$SupportedToken = $(if ($env:FLOWCHAIN_BASE8453_SUPPORTED_TOKEN) { $env:FLOWCHAIN_BASE8453_SUPPORTED_TOKEN } else { "0x0000000000000000000000000000000000000000" }),
    [string]$StartBlock = $env:FLOWCHAIN_BASE8453_FROM_BLOCK,
    [string]$Confirmations = $(if ($env:FLOWCHAIN_PILOT_CONFIRMATIONS) { $env:FLOWCHAIN_PILOT_CONFIRMATIONS } else { "12" }),
    [string]$PollMs = $(if ($env:FLOWCHAIN_BASE8453_RELAY_POLL_MS) { $env:FLOWCHAIN_BASE8453_RELAY_POLL_MS } else { "5000" }),
    [string]$MaxScanBlocks = $(if ($env:FLOWCHAIN_BASE8453_RELAY_MAX_SCAN_BLOCKS) { $env:FLOWCHAIN_BASE8453_RELAY_MAX_SCAN_BLOCKS } else { "500" }),
    [string]$RecoveryWindowBlocks = $(if ($env:FLOWCHAIN_BASE8453_RELAY_RECOVERY_WINDOW_BLOCKS) { $env:FLOWCHAIN_BASE8453_RELAY_RECOVERY_WINDOW_BLOCKS } else { "128" }),
    [string]$MaxUsd = $(if ($env:FLOWCHAIN_PILOT_MAX_USD) { $env:FLOWCHAIN_PILOT_MAX_USD } else { "1" }),
    [string]$MaxDepositAmount = $env:FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,
    [string]$TotalCapAmount = $env:FLOWCHAIN_PILOT_TOTAL_CAP_WEI,
    [ValidateSet("inbox", "direct", "off")]
    [string]$NodeMode = "inbox",
    [switch]$OperatorAck,
    [switch]$Once
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

$requiredAck = "I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
$ackFromEnv = $env:FLOWCHAIN_PILOT_OPERATOR_ACK -eq $requiredAck
$acknowledged = [bool]$OperatorAck -or $ackFromEnv

$missing = @()
if ([string]::IsNullOrWhiteSpace($RpcUrl)) { $missing += "FLOWCHAIN_BASE8453_RPC_URL or -RpcUrl" }
if ([string]::IsNullOrWhiteSpace($MaxDepositAmount)) { $missing += "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI or -MaxDepositAmount" }
if ([string]::IsNullOrWhiteSpace($TotalCapAmount)) { $missing += "FLOWCHAIN_PILOT_TOTAL_CAP_WEI or -TotalCapAmount" }
if (-not $acknowledged) { $missing += "FLOWCHAIN_PILOT_OPERATOR_ACK=$requiredAck or -OperatorAck" }

if ($missing.Count -gt 0) {
    throw "Base 8453 low-latency relay needs: $($missing -join ', '). No private key is required by this relay."
}

Write-Host "Preparing Base 8453 low-latency bridge relay." -ForegroundColor Yellow
Write-Host "Chain: Base public network (8453 / 0x2105)"
Write-Host "Lockbox: $LockboxAddress"
Write-Host "Approved lockbox: $ApprovedLockboxAddress"
Write-Host "Supported token: $SupportedToken"
Write-Host "Start block: $(if ([string]::IsNullOrWhiteSpace($StartBlock)) { 'latest bounded recovery window' } else { $StartBlock })"
Write-Host "Confirmation depth: $Confirmations"
Write-Host "Polling interval: $PollMs ms"
Write-Host "Max scan blocks: $MaxScanBlocks"
Write-Host "Recovery window blocks: $RecoveryWindowBlocks"
Write-Host "Node ingest mode: $NodeMode"
Write-Host "Broadcast: false; this relay never sends release transactions."

$arguments = @(
    "run", "bridge:relay:base8453", "--",
    "--rpc-url", $RpcUrl,
    "--lockbox-address", $LockboxAddress,
    "--approved-lockbox", $ApprovedLockboxAddress,
    "--supported-token", $SupportedToken,
    "--confirmations", $Confirmations,
    "--poll-ms", $PollMs,
    "--max-scan-blocks", $MaxScanBlocks,
    "--recovery-window-blocks", $RecoveryWindowBlocks,
    "--max-usd", $MaxUsd,
    "--max-deposit-amount", $MaxDepositAmount,
    "--total-cap-amount", $TotalCapAmount,
    "--node-mode", $NodeMode,
    "--acknowledge-pilot",
    "--acknowledge-real-funds"
)

if (-not [string]::IsNullOrWhiteSpace($StartBlock)) {
    $arguments += @("--from-block", $StartBlock)
}

if ($Once) {
    $arguments += "--once"
}

npm @arguments
if ($LASTEXITCODE -ne 0) {
    throw "Base 8453 low-latency relay failed with exit code $LASTEXITCODE."
}

Write-Host "Relay artifacts: devnet/local/live-base8453-relay/" -ForegroundColor Cyan

