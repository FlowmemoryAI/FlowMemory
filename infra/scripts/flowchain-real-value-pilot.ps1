param(
    [ValidateSet("DryRun", "Live")]
    [string] $Mode = "DryRun",

    [ValidateSet("All", "Deploy", "Observe", "Credit", "Withdraw", "Pause", "Resume", "ExportEvidence", "Restart")]
    [string] $Action = "All",

    [switch] $Execute,

    [string] $EvidenceDir = "devnet/local/real-value-pilot/evidence",

    [string] $ReportPath = "devnet/local/real-value-pilot/flowchain-real-value-pilot-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$Base8453ChainId = 8453
$OperatorAckValue = "I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
$MaxSingleDepositWeiLimit = [UInt64] 100000000000000
$TotalCapWeiLimit = [UInt64] 1000000000000000
$MaxBlockRange = [UInt64] 5000
$ZeroAddress = "0x0000000000000000000000000000000000000000"

function Get-PilotEnv {
    param([Parameter(Mandatory = $true)][string] $Name)

    return [Environment]::GetEnvironmentVariable($Name, "Process")
}

function Require-PilotEnv {
    param([Parameter(Mandatory = $true)][string] $Name)

    $value = Get-PilotEnv -Name $Name
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "$Name is required for live real-value pilot action '$Action'."
    }
    return $value
}

function Require-PilotAck {
    $ack = Require-PilotEnv -Name "FLOWCHAIN_PILOT_OPERATOR_ACK"
    if ($ack -ne $OperatorAckValue) {
        throw "FLOWCHAIN_PILOT_OPERATOR_ACK must exactly equal '$OperatorAckValue'."
    }
}

function Assert-PilotAddress {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $Value
    )

    if ($Value -notmatch '^0x[0-9a-fA-F]{40}$') {
        throw "$Name must be a 20-byte hex address."
    }
}

function Require-PilotAddressEnv {
    param([Parameter(Mandatory = $true)][string] $Name)

    $value = Require-PilotEnv -Name $Name
    Assert-PilotAddress -Name $Name -Value $value
    return $value
}

function Require-PilotPrivateKeyEnv {
    param([Parameter(Mandatory = $true)][string] $Name)

    $value = Require-PilotEnv -Name $Name
    if ($value -notmatch '^0x[0-9a-fA-F]{64}$') {
        throw "$Name must be a 32-byte hex private key. The value must stay in the local shell only."
    }
    return $value
}

function Convert-PilotUInt64 {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $Value
    )

    if ($Value -notmatch '^[0-9]+$') {
        throw "$Name must be a decimal integer."
    }

    try {
        return [UInt64]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        throw "$Name is outside the supported UInt64 range."
    }
}

function Assert-PilotCaps {
    $maxDeposit = Convert-PilotUInt64 -Name "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI" -Value (Require-PilotEnv -Name "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI")
    $totalCap = Convert-PilotUInt64 -Name "FLOWCHAIN_PILOT_TOTAL_CAP_WEI" -Value (Require-PilotEnv -Name "FLOWCHAIN_PILOT_TOTAL_CAP_WEI")

    if ($maxDeposit -eq 0) {
        throw "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI must be nonzero."
    }
    if ($totalCap -eq 0) {
        throw "FLOWCHAIN_PILOT_TOTAL_CAP_WEI must be nonzero."
    }
    if ($maxDeposit -gt $MaxSingleDepositWeiLimit) {
        throw "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI must be <= $MaxSingleDepositWeiLimit for this owner pilot."
    }
    if ($totalCap -gt $TotalCapWeiLimit) {
        throw "FLOWCHAIN_PILOT_TOTAL_CAP_WEI must be <= $TotalCapWeiLimit for this owner pilot."
    }
    if ($totalCap -lt $maxDeposit) {
        throw "FLOWCHAIN_PILOT_TOTAL_CAP_WEI must be greater than or equal to FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI."
    }

    return [ordered]@{
        maxDepositWei = $maxDeposit.ToString()
        totalCapWei = $totalCap.ToString()
        maxSingleDepositLimitWei = $MaxSingleDepositWeiLimit.ToString()
        totalCapLimitWei = $TotalCapWeiLimit.ToString()
    }
}

function Require-PilotRpcUrl {
    $rpcUrl = Require-PilotEnv -Name "FLOWCHAIN_BASE8453_RPC_URL"
    $uri = $null
    if (-not [System.Uri]::TryCreate($rpcUrl, [System.UriKind]::Absolute, [ref] $uri)) {
        throw "FLOWCHAIN_BASE8453_RPC_URL must be an absolute HTTP(S) URL."
    }
    if ($uri.Scheme -ne "http" -and $uri.Scheme -ne "https") {
        throw "FLOWCHAIN_BASE8453_RPC_URL must use http or https."
    }
    return $rpcUrl
}

function Invoke-PilotRpc {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RpcUrl,

        [Parameter(Mandatory = $true)]
        [string] $Method,

        [object[]] $Params = @()
    )

    $body = ([ordered]@{
            jsonrpc = "2.0"
            id = 1
            method = $Method
            params = $Params
        } | ConvertTo-Json -Depth 8 -Compress)

    try {
        $response = Invoke-RestMethod -Uri $RpcUrl -Method Post -ContentType "application/json" -Body $body -TimeoutSec 20
    }
    catch {
        throw "Could not read $Method from FLOWCHAIN_BASE8453_RPC_URL. Check the endpoint without committing or printing it."
    }

    if ($response.PSObject.Properties.Name -contains "error") {
        throw "RPC $Method returned an error. Check the endpoint and credentials locally."
    }
    if (-not ($response.PSObject.Properties.Name -contains "result")) {
        throw "RPC $Method did not return a result."
    }

    return $response.result
}

function Assert-Base8453Chain {
    param([Parameter(Mandatory = $true)][string] $RpcUrl)

    $chainHex = Invoke-PilotRpc -RpcUrl $RpcUrl -Method "eth_chainId"
    if ($chainHex -notmatch '^0x[0-9a-fA-F]+$') {
        throw "eth_chainId returned an invalid hex value."
    }
    $actual = [Convert]::ToInt64($chainHex.Substring(2), 16)
    if ($actual -ne $Base8453ChainId) {
        throw "Wrong chain id: expected $Base8453ChainId for Base, got $actual."
    }

    Write-Host "Verified Base chain id: $Base8453ChainId"
    return $actual
}

function Assert-PilotBlockRange {
    $fromBlock = Convert-PilotUInt64 -Name "FLOWCHAIN_BASE8453_FROM_BLOCK" -Value (Require-PilotEnv -Name "FLOWCHAIN_BASE8453_FROM_BLOCK")
    $toBlock = Convert-PilotUInt64 -Name "FLOWCHAIN_BASE8453_TO_BLOCK" -Value (Require-PilotEnv -Name "FLOWCHAIN_BASE8453_TO_BLOCK")
    if ($fromBlock -gt $toBlock) {
        throw "FLOWCHAIN_BASE8453_FROM_BLOCK must be <= FLOWCHAIN_BASE8453_TO_BLOCK."
    }
    if (($toBlock - $fromBlock) -gt $MaxBlockRange) {
        throw "Base 8453 observer range is too wide. Max range is $MaxBlockRange blocks."
    }

    return [ordered]@{
        fromBlock = $fromBlock.ToString()
        toBlock = $toBlock.ToString()
    }
}

function Get-PilotMaxUsd {
    $value = Get-PilotEnv -Name "FLOWCHAIN_PILOT_MAX_USD"
    if ([string]::IsNullOrWhiteSpace($value)) {
        return 1.0
    }
    $parsed = 0.0
    if (-not [double]::TryParse($value, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref] $parsed)) {
        throw "FLOWCHAIN_PILOT_MAX_USD must be a decimal number."
    }
    if ($parsed -le 0 -or $parsed -gt 25) {
        throw "FLOWCHAIN_PILOT_MAX_USD must be greater than 0 and <= 25."
    }
    return $parsed
}

function Get-PilotActionList {
    if ($Action -eq "All") {
        return @("Deploy", "Observe", "Credit", "Withdraw", "Pause", "Resume", "ExportEvidence", "Restart")
    }
    return @($Action)
}

function Get-PilotActionLabel {
    param([Parameter(Mandatory = $true)][string] $Name)

    switch ($Name) {
        "ExportEvidence" { return "export evidence" }
        default { return $Name.ToLowerInvariant() }
    }
}

function Get-PilotNextCommand {
    param([Parameter(Mandatory = $true)][string] $Name)

    switch ($Name) {
        "Deploy" { return "npm run flowchain:real-value-pilot -- --Mode Live --Action Observe" }
        "Observe" { return "npm run flowchain:real-value-pilot -- --Mode Live --Action Credit" }
        "Credit" { return "npm run flowchain:real-value-pilot -- --Mode Live --Action Withdraw" }
        "Withdraw" { return "npm run flowchain:real-value-pilot:export" }
        "Pause" { return "npm run flowchain:real-value-pilot -- --Mode Live --Action Resume -Execute" }
        "Resume" { return "npm run flowchain:real-value-pilot -- --Mode Live --Action Observe" }
        "ExportEvidence" { return "npm run flowchain:real-value-pilot -- --Mode Live --Action Restart" }
        "Restart" { return "npm run flowchain:real-value-pilot -- --Mode Live --Action Observe" }
        default { throw "Unknown action for next command: $Name" }
    }
}

function Write-PilotNextCommand {
    param([Parameter(Mandatory = $true)][string] $Name)

    $label = Get-PilotActionLabel -Name $Name
    $next = Get-PilotNextCommand -Name $Name
    Write-Host "After $label, next command: $next"
    return $next
}

function Get-PilotCommit {
    $commit = (& git rev-parse HEAD 2>$null | Select-Object -First 1)
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($commit)) {
        return ($commit -as [string]).Trim()
    }
    return "unknown"
}

function Invoke-PilotBridgeObserver {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot,

        [Parameter(Mandatory = $true)]
        [string] $RpcUrl,

        [Parameter(Mandatory = $true)]
        [string] $LockboxAddress,

        [Parameter(Mandatory = $true)]
        [string] $FromBlock,

        [Parameter(Mandatory = $true)]
        [string] $ToBlock,

        [Parameter(Mandatory = $true)]
        [string] $OutPath,

        [Parameter(Mandatory = $true)]
        [string] $CreditOutPath,

        [Parameter(Mandatory = $true)]
        [string] $HandoffOutPath,

        [string] $WithdrawalOutPath = "",

        [switch] $ApplyCredit,

        [switch] $WithdrawalIntent
    )

    $args = @(
        "run",
        "bridge:observe",
        "--",
        "--mode",
        "base-mainnet-canary",
        "--rpc-url",
        $RpcUrl,
        "--lockbox-address",
        $LockboxAddress,
        "--from-block",
        $FromBlock,
        "--to-block",
        $ToBlock,
        "--expected-chain-id",
        "$Base8453ChainId",
        "--acknowledge-real-funds",
        "--max-usd",
        ((Get-PilotMaxUsd).ToString([System.Globalization.CultureInfo]::InvariantCulture)),
        "--out",
        $OutPath,
        "--credit-out",
        $CreditOutPath,
        "--handoff-out",
        $HandoffOutPath
    )

    if ($ApplyCredit) {
        $args += "--apply-credit"
    }
    if ($WithdrawalIntent) {
        if ([string]::IsNullOrWhiteSpace($WithdrawalOutPath)) {
            throw "WithdrawalOutPath is required when WithdrawalIntent is set."
        }
        $recipient = Require-PilotAddressEnv -Name "FLOWCHAIN_PILOT_WITHDRAWAL_RECIPIENT"
        $args += @("--withdrawal-intent", "--withdrawal-base-recipient", $recipient, "--withdrawal-out", $WithdrawalOutPath)
    }

    Write-Host "Running Base 8453 bridge observer. RPC URL is supplied from env and is not printed."
    & npm @args
    if ($LASTEXITCODE -ne 0) {
        throw "Base 8453 bridge observer failed."
    }
}

function Invoke-PilotDeploy {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RpcUrl,

        [Parameter(Mandatory = $true)]
        [string] $PrivateKey,

        [Parameter(Mandatory = $true)]
        [hashtable] $DeployEnv
    )

    if (-not $Execute) {
        Write-Host "Deploy preflight passed. Plan only; no transaction was broadcast."
        Write-Host 'Exact deploy command when ready: npm run flowchain:real-value-pilot -- --Mode Live --Action Deploy -Execute'
        return "planned"
    }

    if (-not (Get-Command forge -ErrorAction SilentlyContinue)) {
        throw "forge is required for deploy execution."
    }

    $previous = @{}
    foreach ($name in $DeployEnv.Keys) {
        $previous[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
        [Environment]::SetEnvironmentVariable($name, [string] $DeployEnv[$name], "Process")
    }

    try {
        Write-Host "Broadcasting deploy with private key from FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY. The key is not logged or stored."
        & forge @(
            "script",
            "script/DeployBridgeSpine.s.sol:DeployBridgeSpine",
            "--rpc-url",
            $RpcUrl,
            "--private-key",
            $PrivateKey,
            "--broadcast"
        )
        if ($LASTEXITCODE -ne 0) {
            throw "forge deploy failed."
        }
    }
    finally {
        foreach ($name in $DeployEnv.Keys) {
            [Environment]::SetEnvironmentVariable($name, $previous[$name], "Process")
        }
    }

    return "executed"
}

function Invoke-PilotSetPaused {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RpcUrl,

        [Parameter(Mandatory = $true)]
        [string] $PrivateKey,

        [Parameter(Mandatory = $true)]
        [string] $LockboxAddress,

        [Parameter(Mandatory = $true)]
        [bool] $Paused
    )

    $pausedText = if ($Paused) { "true" } else { "false" }
    if (-not $Execute) {
        Write-Host "Pause/resume preflight passed. Plan only; no transaction was broadcast."
        Write-Host "Exact cast command when ready: cast send $LockboxAddress `"setPaused(bool)`" $pausedText --rpc-url `$env:FLOWCHAIN_BASE8453_RPC_URL --private-key `$env:FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY"
        return "planned"
    }

    if (-not (Get-Command cast -ErrorAction SilentlyContinue)) {
        throw "cast is required for pause/resume execution."
    }

    Write-Host "Broadcasting setPaused($pausedText) with private key from FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY. The key is not logged or stored."
    & cast @(
        "send",
        $LockboxAddress,
        "setPaused(bool)",
        $pausedText,
        "--rpc-url",
        $RpcUrl,
        "--private-key",
        $PrivateKey
    )
    if ($LASTEXITCODE -ne 0) {
        throw "cast setPaused($pausedText) failed."
    }

    return "executed"
}

function Invoke-PilotAction {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $RepoRoot,

        [Parameter(Mandatory = $true)]
        [string] $EvidenceFullDir
    )

    Write-Host ""
    Write-Host "== Real-value pilot action: $Name ($Mode) =="

    $result = [ordered]@{
        action = $Name
        mode = $Mode
        status = "planned"
        execute = [bool] $Execute
        outputs = [ordered]@{}
        checks = [ordered]@{}
    }

    if ($Mode -eq "DryRun") {
        $result.status = "dry-run-passed"
        $result.checks.requiresNoRpcOrKeys = $true
        $result.checks.base8453ChainCheck = "skipped-dry-run"
        $result.checks.capCheck = "skipped-dry-run"
        if ($Name -eq "ExportEvidence") {
            & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-real-value-pilot-export.ps1") -DryRun
            if ($LASTEXITCODE -ne 0) {
                throw "Dry-run evidence export failed."
            }
        }
        $result.nextCommand = Write-PilotNextCommand -Name $Name
        return $result
    }

    Require-PilotAck
    $result.checks.operatorAck = "present"
    $result.checks.caps = Assert-PilotCaps

    switch ($Name) {
        "Deploy" {
            $rpcUrl = Require-PilotRpcUrl
            Assert-Base8453Chain -RpcUrl $rpcUrl | Out-Null
            $result.checks.chainId = "$Base8453ChainId"
            $privateKey = Require-PilotPrivateKeyEnv -Name "FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY"
            $owner = Require-PilotAddressEnv -Name "FLOWCHAIN_PILOT_OWNER_ADDRESS"
            $releaseAuthority = Require-PilotAddressEnv -Name "FLOWCHAIN_PILOT_RELEASE_AUTHORITY_ADDRESS"
            $settlementSubmitter = Require-PilotAddressEnv -Name "FLOWCHAIN_PILOT_SETTLEMENT_SUBMITTER_ADDRESS"
            $caps = $result.checks.caps
            $deployEnv = @{
                FLOWCHAIN_BRIDGE_OWNER = $owner
                FLOWCHAIN_BRIDGE_RELEASE_AUTHORITY = $releaseAuthority
                FLOWCHAIN_SETTLEMENT_SUBMITTER = $settlementSubmitter
                FLOWCHAIN_BRIDGE_ALLOW_NATIVE = "true"
                FLOWCHAIN_BRIDGE_NATIVE_PER_DEPOSIT_CAP = $caps.maxDepositWei
                FLOWCHAIN_BRIDGE_NATIVE_TOTAL_CAP = $caps.totalCapWei
                FLOWCHAIN_BRIDGE_ALLOW_ERC20 = "false"
                FLOWCHAIN_BRIDGE_ERC20_TOKEN = $ZeroAddress
                FLOWCHAIN_BRIDGE_ERC20_PER_DEPOSIT_CAP = "0"
                FLOWCHAIN_BRIDGE_ERC20_TOTAL_CAP = "0"
            }
            $result.status = Invoke-PilotDeploy -RpcUrl $rpcUrl -PrivateKey $privateKey -DeployEnv $deployEnv
        }
        "Observe" {
            $rpcUrl = Require-PilotRpcUrl
            Assert-Base8453Chain -RpcUrl $rpcUrl | Out-Null
            $lockbox = Require-PilotAddressEnv -Name "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS"
            $range = Assert-PilotBlockRange
            $result.checks.chainId = "$Base8453ChainId"
            $result.checks.lockboxAddress = "valid"
            $result.checks.blockRange = $range
            $out = Join-Path $EvidenceFullDir "base8453-observation.json"
            $creditOut = Join-Path $EvidenceFullDir "base8453-credit-pending.json"
            $handoffOut = Join-Path $EvidenceFullDir "base8453-handoff-pending.json"
            Invoke-PilotBridgeObserver -RepoRoot $RepoRoot -RpcUrl $rpcUrl -LockboxAddress $lockbox -FromBlock $range.fromBlock -ToBlock $range.toBlock -OutPath $out -CreditOutPath $creditOut -HandoffOutPath $handoffOut
            $result.status = "executed"
            $result.outputs.observation = $out
            $result.outputs.credit = $creditOut
            $result.outputs.handoff = $handoffOut
        }
        "Credit" {
            $rpcUrl = Require-PilotRpcUrl
            Assert-Base8453Chain -RpcUrl $rpcUrl | Out-Null
            $lockbox = Require-PilotAddressEnv -Name "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS"
            $range = Assert-PilotBlockRange
            $out = Join-Path $EvidenceFullDir "base8453-observation-for-credit.json"
            $creditOut = Join-Path $EvidenceFullDir "base8453-credit-applied.json"
            $handoffOut = Join-Path $EvidenceFullDir "base8453-handoff-applied.json"
            Invoke-PilotBridgeObserver -RepoRoot $RepoRoot -RpcUrl $rpcUrl -LockboxAddress $lockbox -FromBlock $range.fromBlock -ToBlock $range.toBlock -OutPath $out -CreditOutPath $creditOut -HandoffOutPath $handoffOut -ApplyCredit
            $result.status = "executed"
            $result.outputs.observation = $out
            $result.outputs.credit = $creditOut
            $result.outputs.handoff = $handoffOut
        }
        "Withdraw" {
            $rpcUrl = Require-PilotRpcUrl
            Assert-Base8453Chain -RpcUrl $rpcUrl | Out-Null
            $lockbox = Require-PilotAddressEnv -Name "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS"
            $range = Assert-PilotBlockRange
            $out = Join-Path $EvidenceFullDir "base8453-observation-for-withdrawal.json"
            $creditOut = Join-Path $EvidenceFullDir "base8453-credit-for-withdrawal.json"
            $handoffOut = Join-Path $EvidenceFullDir "base8453-handoff-with-withdrawal.json"
            $withdrawalOut = Join-Path $EvidenceFullDir "base8453-withdrawal-intent.json"
            Invoke-PilotBridgeObserver -RepoRoot $RepoRoot -RpcUrl $rpcUrl -LockboxAddress $lockbox -FromBlock $range.fromBlock -ToBlock $range.toBlock -OutPath $out -CreditOutPath $creditOut -HandoffOutPath $handoffOut -WithdrawalOutPath $withdrawalOut -ApplyCredit -WithdrawalIntent
            $result.status = "executed"
            $result.outputs.withdrawalIntent = $withdrawalOut
        }
        "Pause" {
            $rpcUrl = Require-PilotRpcUrl
            Assert-Base8453Chain -RpcUrl $rpcUrl | Out-Null
            $privateKey = Require-PilotPrivateKeyEnv -Name "FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY"
            $lockbox = Require-PilotAddressEnv -Name "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS"
            $result.status = Invoke-PilotSetPaused -RpcUrl $rpcUrl -PrivateKey $privateKey -LockboxAddress $lockbox -Paused $true
        }
        "Resume" {
            $rpcUrl = Require-PilotRpcUrl
            Assert-Base8453Chain -RpcUrl $rpcUrl | Out-Null
            $privateKey = Require-PilotPrivateKeyEnv -Name "FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY"
            $lockbox = Require-PilotAddressEnv -Name "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS"
            $result.status = Invoke-PilotSetPaused -RpcUrl $rpcUrl -PrivateKey $privateKey -LockboxAddress $lockbox -Paused $false
        }
        "ExportEvidence" {
            & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-real-value-pilot-export.ps1")
            if ($LASTEXITCODE -ne 0) {
                throw "Evidence export failed."
            }
            $result.status = "executed"
        }
        "Restart" {
            Write-Host "Restart recovery commands:"
            Write-Host "npm run flowchain:start"
            Write-Host "npm run control-plane:serve"
            Write-Host "npm run workbench:dev"
            Write-Host "npm run flowchain:real-value-pilot -- --Mode Live --Action Observe"
            $result.status = "restart-commands-printed"
        }
        default {
            throw "Unsupported action: $Name"
        }
    }

    $result.nextCommand = Write-PilotNextCommand -Name $Name
    return $result
}

$repoRoot = Set-FlowChainRepoRoot
if ($Mode -eq "Live" -and $Action -eq "All") {
    throw "Live mode must run one action at a time. Use -Action Deploy, Observe, Credit, Withdraw, Pause, Resume, ExportEvidence, or Restart."
}

$evidenceFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $EvidenceDir)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
New-Item -ItemType Directory -Force -Path $evidenceFullDir | Out-Null

$actionResults = @()
foreach ($name in Get-PilotActionList) {
    $actionResults += Invoke-PilotAction -Name $name -RepoRoot $repoRoot -EvidenceFullDir $evidenceFullDir
}

$report = [ordered]@{
    schema = "flowchain.real_value_pilot.ops_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    commit = Get-PilotCommit
    mode = $Mode
    action = $Action
    status = "passed"
    baseChainId = $Base8453ChainId
    operatorAckRequiredValue = $OperatorAckValue
    capLimits = [ordered]@{
        maxDepositWeiLimit = $MaxSingleDepositWeiLimit.ToString()
        totalCapWeiLimit = $TotalCapWeiLimit.ToString()
    }
    evidenceDir = $evidenceFullDir
    actions = $actionResults
    envVarNames = @(
        "FLOWCHAIN_PILOT_OPERATOR_ACK",
        "FLOWCHAIN_BASE8453_RPC_URL",
        "FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY",
        "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
        "FLOWCHAIN_BASE8453_FROM_BLOCK",
        "FLOWCHAIN_BASE8453_TO_BLOCK",
        "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
        "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
        "FLOWCHAIN_PILOT_OWNER_ADDRESS",
        "FLOWCHAIN_PILOT_RELEASE_AUTHORITY_ADDRESS",
        "FLOWCHAIN_PILOT_SETTLEMENT_SUBMITTER_ADDRESS",
        "FLOWCHAIN_PILOT_WITHDRAWAL_RECIPIENT",
        "FLOWCHAIN_PILOT_MAX_USD"
    )
    boundaries = @(
        "capped owner pilot only",
        "Base public network chain id 8453 is checked before live observer/deploy actions",
        "dry-run uses no RPC URL or private key",
        "private keys and RPC URLs are read from the local shell only and are not written to reports"
    )
}

Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

Write-Host ""
Write-Host "FlowChain real-value pilot ops check passed."
Write-Host "Report: $reportFullPath"
Write-Host "Evidence directory: $evidenceFullDir"
