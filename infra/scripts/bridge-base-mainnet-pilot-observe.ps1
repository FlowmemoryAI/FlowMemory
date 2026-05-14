param(
    [string]$RpcUrl = $env:FLOWCHAIN_BASE8453_RPC_URL,

    [string]$LockboxAddress = $env:FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,

    [string]$ApprovedLockboxAddress = $(if ($env:FLOWCHAIN_BASE8453_APPROVED_LOCKBOX_ADDRESS) { $env:FLOWCHAIN_BASE8453_APPROVED_LOCKBOX_ADDRESS } else { $env:FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS }),

    [string]$SupportedToken = $env:FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,

    [string]$FromBlock = $env:FLOWCHAIN_BASE8453_FROM_BLOCK,

    [string]$ToBlock = $env:FLOWCHAIN_BASE8453_TO_BLOCK,

    [string]$Confirmations = $env:FLOWCHAIN_PILOT_CONFIRMATIONS,

    [string]$MaxUsd = $(if ($env:FLOWCHAIN_PILOT_MAX_USD) { $env:FLOWCHAIN_PILOT_MAX_USD } else { "1" }),

    [string]$MaxDepositAmount = $env:FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,

    [string]$TotalCapAmount = $env:FLOWCHAIN_PILOT_TOTAL_CAP_WEI,

    [switch]$OperatorAck,

    [switch]$ApplyCredit,

    [switch]$WithdrawalIntent,

    [string]$RuntimeState = "services/bridge-relayer/out/base8453-pilot-credit-application-state.json",

    [string]$Out = "services/bridge-relayer/out/base8453-pilot-bridge-observation.json",

    [string]$CreditOut = "services/bridge-relayer/out/base8453-pilot-bridge-credit.json",

    [string]$HandoffOut = "services/bridge-relayer/out/base8453-pilot-bridge-handoff.json",

    [string]$EvidenceOut = "services/bridge-relayer/out/base8453-pilot-evidence.json",

    [string]$WithdrawalOut = "services/bridge-relayer/out/base8453-pilot-withdrawal-intent.json",

    [string]$ReleaseEvidenceOut = "services/bridge-relayer/out/base8453-pilot-release-evidence.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

function Write-NextCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Step,

        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    Write-Host "$Step complete." -ForegroundColor Green
    Write-Host "Next operator command: $Command" -ForegroundColor Cyan
}

$requiredAck = "I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
$ackFromEnv = $env:FLOWCHAIN_PILOT_OPERATOR_ACK -eq $requiredAck
$acknowledged = [bool]$OperatorAck -or $ackFromEnv

$missing = @()
if ([string]::IsNullOrWhiteSpace($RpcUrl)) { $missing += "FLOWCHAIN_BASE8453_RPC_URL or -RpcUrl" }
if ([string]::IsNullOrWhiteSpace($LockboxAddress)) { $missing += "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS or -LockboxAddress" }
if ([string]::IsNullOrWhiteSpace($ApprovedLockboxAddress)) { $missing += "FLOWCHAIN_BASE8453_APPROVED_LOCKBOX_ADDRESS or -ApprovedLockboxAddress" }
if ([string]::IsNullOrWhiteSpace($SupportedToken)) { $missing += "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN or -SupportedToken" }
if ([string]::IsNullOrWhiteSpace($FromBlock)) { $missing += "FLOWCHAIN_BASE8453_FROM_BLOCK or -FromBlock" }
if ([string]::IsNullOrWhiteSpace($ToBlock)) { $missing += "FLOWCHAIN_BASE8453_TO_BLOCK or -ToBlock" }
if ([string]::IsNullOrWhiteSpace($Confirmations)) { $missing += "FLOWCHAIN_PILOT_CONFIRMATIONS or -Confirmations" }
if ([string]::IsNullOrWhiteSpace($MaxDepositAmount)) { $missing += "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI or -MaxDepositAmount" }
if ([string]::IsNullOrWhiteSpace($TotalCapAmount)) { $missing += "FLOWCHAIN_PILOT_TOTAL_CAP_WEI or -TotalCapAmount" }
if (-not $acknowledged) { $missing += "FLOWCHAIN_PILOT_OPERATOR_ACK=$requiredAck or -OperatorAck" }

if ($missing.Count -gt 0) {
    throw "Base 8453 pilot observation needs: $($missing -join ', '). No private key is required by this relayer."
}

Write-Host "Preparing Base 8453 bridge pilot observation." -ForegroundColor Yellow
Write-Host "Chain: Base public network (8453 / 0x2105)"
Write-Host "Lockbox: $LockboxAddress"
Write-Host "Approved lockbox: $ApprovedLockboxAddress"
Write-Host "Supported token: $SupportedToken"
Write-Host "Block range: $FromBlock-$ToBlock"
Write-Host "Confirmation depth: $Confirmations"
Write-Host "Max USD guardrail: $MaxUsd"
Write-Host "Max deposit amount: $MaxDepositAmount"
Write-Host "Total cap amount: $TotalCapAmount"
Write-Host "Broadcast: false; this relayer never sends release transactions."

Write-NextCommand `
    -Step "Step 1" `
    -Command "npm run bridge:observe -- --mode base-mainnet-pilot --rpc-url `$env:FLOWCHAIN_BASE8453_RPC_URL --lockbox-address `$env:FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS --approved-lockbox `$env:FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS --supported-token `$env:FLOWCHAIN_BASE8453_SUPPORTED_TOKEN --from-block `$env:FLOWCHAIN_BASE8453_FROM_BLOCK --to-block `$env:FLOWCHAIN_BASE8453_TO_BLOCK --confirmations `$env:FLOWCHAIN_PILOT_CONFIRMATIONS --acknowledge-pilot --acknowledge-real-funds --max-usd `$env:FLOWCHAIN_PILOT_MAX_USD --max-deposit-amount `$env:FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI --total-cap-amount `$env:FLOWCHAIN_PILOT_TOTAL_CAP_WEI"

$arguments = @(
    "run", "bridge:observe", "--",
    "--mode", "base-mainnet-pilot",
    "--rpc-url", $RpcUrl,
    "--lockbox-address", $LockboxAddress,
    "--approved-lockbox", $ApprovedLockboxAddress,
    "--supported-token", $SupportedToken,
    "--from-block", $FromBlock,
    "--to-block", $ToBlock,
    "--confirmations", $Confirmations,
    "--acknowledge-pilot",
    "--acknowledge-real-funds",
    "--max-usd", $MaxUsd,
    "--max-deposit-amount", $MaxDepositAmount,
    "--total-cap-amount", $TotalCapAmount,
    "--runtime-state", $RuntimeState,
    "--out", $Out,
    "--credit-out", $CreditOut,
    "--handoff-out", $HandoffOut,
    "--evidence-out", $EvidenceOut
)

if ($ApplyCredit) {
    $arguments += "--apply-credit"
}
if ($WithdrawalIntent) {
    $arguments += @("--withdrawal-intent", "--withdrawal-out", $WithdrawalOut, "--release-evidence-out", $ReleaseEvidenceOut)
}

npm @arguments
if ($LASTEXITCODE -ne 0) {
    throw "Base 8453 pilot bridge observer failed with exit code $LASTEXITCODE."
}

Write-NextCommand -Step "Step 2" -Command "Get-Content $EvidenceOut"

if ($WithdrawalIntent) {
    Write-NextCommand -Step "Step 3" -Command "Get-Content $ReleaseEvidenceOut"
}
else {
    Write-NextCommand -Step "Step 3" -Command "powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/bridge-base-mainnet-pilot-observe.ps1 -OperatorAck -ApplyCredit -WithdrawalIntent"
}

Write-NextCommand -Step "Step 4" -Command "npm run flowchain:product-e2e"
