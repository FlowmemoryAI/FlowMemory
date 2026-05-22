param(
    [string]$RpcUrl = $env:FLOWMEMORY_BASE8453_RPC_URL,

    [string]$LockboxAddress = $env:FLOWMEMORY_BASE8453_LOCKBOX_ADDRESS,

    [string]$ApprovedLockboxAddress = $(if ($env:FLOWMEMORY_BASE8453_APPROVED_LOCKBOX_ADDRESS) { $env:FLOWMEMORY_BASE8453_APPROVED_LOCKBOX_ADDRESS } else { $env:FLOWMEMORY_BASE8453_LOCKBOX_ADDRESS }),

    [string]$FromBlock = $env:FLOWMEMORY_BASE8453_FROM_BLOCK,

    [string]$ToBlock = $env:FLOWMEMORY_BASE8453_TO_BLOCK,

    [string]$Confirmations = $(if ($env:FLOWMEMORY_PILOT_CONFIRMATIONS) { $env:FLOWMEMORY_PILOT_CONFIRMATIONS } elseif ($env:FLOWMEMORY_BASE8453_CONFIRMATION_DEPTH) { $env:FLOWMEMORY_BASE8453_CONFIRMATION_DEPTH } else { $env:FLOWMEMORY_BASE8453_CONFIRMATIONS }),

    [string]$SupportedToken = $env:FLOWMEMORY_BASE8453_SUPPORTED_TOKEN,

    [string]$AssetDecimals = $env:FLOWMEMORY_BASE8453_ASSET_DECIMALS,

    [string]$MaxUsd = $(if ($env:FLOWMEMORY_PILOT_MAX_USD) { $env:FLOWMEMORY_PILOT_MAX_USD } else { "25" }),

    [string]$MaxDepositAmount = $env:FLOWMEMORY_PILOT_MAX_DEPOSIT_WEI,

    [string]$TotalCapAmount = $env:FLOWMEMORY_PILOT_TOTAL_CAP_WEI,

    [switch]$OperatorAck,

    [switch]$ApplyCredit,

    [switch]$WithdrawalIntent,

    [string]$RuntimeState = "services/bridge-relayer/out/base8453-pilot-credit-application-state.json",

    [string]$CursorState = $(if ($env:FLOWMEMORY_BASE8453_CURSOR_STATE) { $env:FLOWMEMORY_BASE8453_CURSOR_STATE } else { "services/bridge-relayer/out/base8453-pilot-cursor-state.json" }),

    [string]$Out = "services/bridge-relayer/out/base8453-pilot-bridge-observation.json",

    [string]$CreditOut = "services/bridge-relayer/out/base8453-pilot-bridge-credit.json",

    [string]$HandoffOut = "services/bridge-relayer/out/base8453-pilot-bridge-handoff.json",

    [string]$EvidenceOut = "services/bridge-relayer/out/base8453-pilot-evidence.json",

    [string]$WithdrawalOut = "services/bridge-relayer/out/base8453-pilot-withdrawal-intent.json",

    [string]$ReleaseEvidenceOut = "services/bridge-relayer/out/base8453-pilot-release-evidence.json",

    [string]$ReportPath = "local-runtime/local/bridge-live-readiness/bridge-observe-base8453-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot
$requiredAck = "I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"

function Write-JsonReport {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Value
    )
    $fullRoot = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd('\')
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $ReportPath))
    if (-not $fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "ReportPath must stay inside the repository."
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $fullPath) | Out-Null
    $Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $fullPath -Encoding UTF8
    Write-Host "Report: $fullPath"
}

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

function Protect-ObserverOutputLine {
    param([Parameter(Mandatory = $true)][string]$Line)

    foreach ($pair in @(
            @{ value = $RpcUrl; label = "<FLOWMEMORY_BASE8453_RPC_URL>" },
            @{ value = $LockboxAddress; label = "<FLOWMEMORY_BASE8453_LOCKBOX_ADDRESS>" },
            @{ value = $ApprovedLockboxAddress; label = "<FLOWMEMORY_BASE8453_APPROVED_LOCKBOX_ADDRESS>" },
            @{ value = $FromBlock; label = "<FLOWMEMORY_BASE8453_FROM_BLOCK>" },
            @{ value = $ToBlock; label = "<FLOWMEMORY_BASE8453_TO_BLOCK>" },
            @{ value = $CursorState; label = "<FLOWMEMORY_BASE8453_CURSOR_STATE>" },
            @{ value = $SupportedToken; label = "<FLOWMEMORY_BASE8453_SUPPORTED_TOKEN>" },
            @{ value = $MaxDepositAmount; label = "<FLOWMEMORY_PILOT_MAX_DEPOSIT_WEI>" },
            @{ value = $TotalCapAmount; label = "<FLOWMEMORY_PILOT_TOTAL_CAP_WEI>" }
        )) {
        $value = [string]$pair.value
        if (-not [string]::IsNullOrWhiteSpace($value) -and $value.Length -ge 6) {
            $Line = $Line -replace [regex]::Escape($value), [string]$pair.label
        }
    }

    if ($Line -match '^(Lockbox|Block range|Confirmation depth|Base pilot acknowledged|Supported tokens|Pilot max USD):') {
        return $null
    }
    return $Line
}

$ackFromEnv = $env:FLOWMEMORY_PILOT_OPERATOR_ACK -eq $requiredAck
$acknowledged = $ackFromEnv

$missing = @()
if ([string]::IsNullOrWhiteSpace($RpcUrl)) { $missing += "FLOWMEMORY_BASE8453_RPC_URL" }
if ([string]::IsNullOrWhiteSpace($LockboxAddress)) { $missing += "FLOWMEMORY_BASE8453_LOCKBOX_ADDRESS" }
if ([string]::IsNullOrWhiteSpace($ApprovedLockboxAddress)) { $missing += "FLOWMEMORY_BASE8453_APPROVED_LOCKBOX_ADDRESS or FLOWMEMORY_BASE8453_LOCKBOX_ADDRESS" }
if ([string]::IsNullOrWhiteSpace($FromBlock)) { $missing += "FLOWMEMORY_BASE8453_FROM_BLOCK" }
if ([string]::IsNullOrWhiteSpace($ToBlock) -and [string]::IsNullOrWhiteSpace($CursorState)) { $missing += "FLOWMEMORY_BASE8453_TO_BLOCK or CursorState" }
if ([string]::IsNullOrWhiteSpace($Confirmations)) { $missing += "FLOWMEMORY_PILOT_CONFIRMATIONS" }
if ([string]::IsNullOrWhiteSpace($SupportedToken)) { $missing += "FLOWMEMORY_BASE8453_SUPPORTED_TOKEN" }
if ([string]::IsNullOrWhiteSpace($AssetDecimals)) { $missing += "FLOWMEMORY_BASE8453_ASSET_DECIMALS" }
if ([string]::IsNullOrWhiteSpace($MaxDepositAmount)) { $missing += "FLOWMEMORY_PILOT_MAX_DEPOSIT_WEI" }
if ([string]::IsNullOrWhiteSpace($TotalCapAmount)) { $missing += "FLOWMEMORY_PILOT_TOTAL_CAP_WEI" }
if (-not $acknowledged) { $missing += "FLOWMEMORY_PILOT_OPERATOR_ACK" }

if ($missing.Count -gt 0) {
    Write-JsonReport -Value ([ordered]@{
        schema = "flowmemory.bridge_observe_base8453_report.v0"
        status = "blocked"
        command = "npm run flowmemory:bridge:observe:base8453"
        missingEnvNames = $missing
        broadcasts = $false
        noSecrets = $true
    })
    throw "Base 8453 pilot observation blocked by missing env names: $($missing -join ', ')."
}

Write-Host "Preparing Base 8453 bridge pilot observation." -ForegroundColor Yellow
Write-Host "Required env names present: FLOWMEMORY_BASE8453_RPC_URL, FLOWMEMORY_BASE8453_LOCKBOX_ADDRESS, FLOWMEMORY_BASE8453_SUPPORTED_TOKEN, FLOWMEMORY_BASE8453_ASSET_DECIMALS, FLOWMEMORY_BASE8453_FROM_BLOCK, FLOWMEMORY_PILOT_CONFIRMATIONS, FLOWMEMORY_PILOT_MAX_DEPOSIT_WEI, FLOWMEMORY_PILOT_TOTAL_CAP_WEI, FLOWMEMORY_PILOT_OPERATOR_ACK"
Write-Host "Optional guardrail env names: FLOWMEMORY_PILOT_MAX_USD"
Write-Host "Optional scan upper bound env name: FLOWMEMORY_BASE8453_TO_BLOCK"
Write-Host "Broadcast: false; this relayer never sends release transactions."

Write-NextCommand `
    -Step "Step 1" `
    -Command "npm run flowmemory:bridge:observe:base8453"

$observerScript = Join-Path $repoRoot "services/bridge-relayer/src/observe-base-lockbox.ts"
$arguments = @(
    $observerScript,
    "--mode", "base-mainnet-pilot",
    "--rpc-url", $RpcUrl,
    "--lockbox-address", $LockboxAddress,
    "--approved-lockbox", $ApprovedLockboxAddress,
    "--from-block", $FromBlock,
    "--confirmations", $Confirmations,
    "--acknowledge-pilot",
    "--acknowledge-real-funds",
    "--max-usd", $MaxUsd,
    "--max-deposit-amount", $MaxDepositAmount,
    "--total-cap-amount", $TotalCapAmount,
    "--supported-token", $SupportedToken,
    "--asset-decimals", $AssetDecimals,
    "--runtime-state", $RuntimeState,
    "--cursor-state", $CursorState,
    "--out", $Out,
    "--credit-out", $CreditOut,
    "--handoff-out", $HandoffOut,
    "--evidence-out", $EvidenceOut
)

if (-not [string]::IsNullOrWhiteSpace($ToBlock)) {
    $arguments += @("--to-block", $ToBlock)
}
if ($ApplyCredit) {
    $arguments += "--apply-credit"
}
if ($WithdrawalIntent) {
    $arguments += @("--withdrawal-intent", "--withdrawal-out", $WithdrawalOut, "--release-evidence-out", $ReleaseEvidenceOut)
}

$observerOutput = (& node @arguments 2>&1) | ForEach-Object { "$_" }
$observerExitCode = $LASTEXITCODE
foreach ($line in $observerOutput) {
    $safeLine = Protect-ObserverOutputLine -Line $line
    if ($null -ne $safeLine -and -not [string]::IsNullOrWhiteSpace($safeLine)) {
        Write-Host $safeLine
    }
}
if ($observerExitCode -ne 0) {
    throw "Base 8453 pilot bridge observer failed with exit code $observerExitCode."
}

Write-JsonReport -Value ([ordered]@{
    schema = "flowmemory.bridge_observe_base8453_report.v0"
    status = "completed"
    command = "npm run flowmemory:bridge:observe:base8453"
    outputEnvNames = @("Out", "CreditOut", "HandoffOut", "EvidenceOut", "WithdrawalOut", "ReleaseEvidenceOut", "CursorState")
    cursorStatePath = $CursorState
    broadcasts = $false
    printsEnvValues = $false
    envValuesPrinted = $false
    noSecrets = $true
})

Write-NextCommand -Step "Step 2" -Command "Get-Content $EvidenceOut"

if ($WithdrawalIntent) {
    Write-NextCommand -Step "Step 3" -Command "Get-Content $ReleaseEvidenceOut"
}
else {
    Write-NextCommand -Step "Step 3" -Command "npm run flowmemory:bridge:withdraw:intent"
}

Write-NextCommand -Step "Step 4" -Command "npm run flowmemory:product-e2e"
