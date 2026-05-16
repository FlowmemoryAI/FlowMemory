param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json",
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)

$requiredAck = "I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
$base8453ChainId = "0x2105"
$zeroAddress = "0x0000000000000000000000000000000000000000"
$maxBlockRange = [System.Numerics.BigInteger]::Parse("5000", [System.Globalization.CultureInfo]::InvariantCulture)
$minConfirmations = [System.Numerics.BigInteger]::Parse("2", [System.Globalization.CultureInfo]::InvariantCulture)
$maxConfirmations = [System.Numerics.BigInteger]::Parse("256", [System.Globalization.CultureInfo]::InvariantCulture)

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
$broadcastEnvNames = @(
    "FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY",
    "FLOWCHAIN_BASE8453_BROADCAST_ACK"
)

$problems = New-Object System.Collections.ArrayList
$missingEnv = New-Object System.Collections.ArrayList
$checks = [ordered]@{}

foreach ($name in $requiredEnv) {
    if ([string]::IsNullOrWhiteSpace((Get-FlowChainEnvValue -Name $name))) {
        [void] $missingEnv.Add($name)
        Add-FlowChainReadinessProblem -Problems $problems -Name $name -Reason "missing required bridge readiness env value"
    }
}

function Invoke-BaseReadOnlyRpc {
    param(
        [Parameter(Mandatory = $true)][string] $RpcEndpoint,
        [Parameter(Mandatory = $true)][string] $Method,
        [object[]] $Params = @()
    )

    $body = ([ordered]@{
        jsonrpc = "2.0"
        id = 1
        method = $Method
        params = $Params
    } | ConvertTo-Json -Depth 8 -Compress)
    try {
        $response = Invoke-RestMethod -Uri $RpcEndpoint -Method Post -ContentType "application/json" -Body $body -TimeoutSec 20
    }
    catch {
        throw "read-only Base RPC call failed"
    }
    if ($response.PSObject.Properties.Name -contains "error") {
        throw "read-only Base RPC call returned an error"
    }
    if (-not ($response.PSObject.Properties.Name -contains "result")) {
        throw "read-only Base RPC call did not return result"
    }
    return [string]$response.result
}

$ack = Get-FlowChainEnvValue -Name "FLOWCHAIN_PILOT_OPERATOR_ACK"
if (-not [string]::IsNullOrWhiteSpace($ack) -and $ack -ne $requiredAck) {
    Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_PILOT_OPERATOR_ACK" -Reason "acknowledgement value is not the required exact string" -Kind "failed"
}
$checks.operatorAcknowledgement = (-not [string]::IsNullOrWhiteSpace($ack) -and $ack -eq $requiredAck)

$rpc = Get-FlowChainEnvValue -Name "FLOWCHAIN_BASE8453_RPC_URL"
$rpcUri = $null
$rpcUsable = $false
if (-not [string]::IsNullOrWhiteSpace($rpc)) {
    if (-not [System.Uri]::TryCreate($rpc, [System.UriKind]::Absolute, [ref] $rpcUri) -or ($rpcUri.Scheme -notin @("http", "https"))) {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_BASE8453_RPC_URL" -Reason "must be an absolute HTTP(S) URL" -Kind "failed"
    }
    else {
        try {
            $chainId = Invoke-BaseReadOnlyRpc -RpcEndpoint $rpc -Method "eth_chainId"
            $checks.baseChainId8453 = ($chainId -eq $base8453ChainId)
            $rpcUsable = $chainId -eq $base8453ChainId
            if ($chainId -ne $base8453ChainId) {
                Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_BASE8453_RPC_URL" -Reason "wrong chain id; expected Base 8453" -Kind "failed"
            }
        }
        catch {
            Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_BASE8453_RPC_URL" -Reason "could not verify Base 8453 chain id" -Kind "failed"
        }
    }
}

$lockbox = Get-FlowChainEnvValue -Name "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS"
if (-not [string]::IsNullOrWhiteSpace($lockbox)) {
    if ($lockbox -notmatch '^0x[0-9a-fA-F]{40}$') {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS" -Reason "must be a 20-byte hex address" -Kind "failed"
    }
    elseif ($rpcUsable) {
        try {
            $code = Invoke-BaseReadOnlyRpc -RpcEndpoint $rpc -Method "eth_getCode" -Params @($lockbox, "latest")
            $checks.lockboxBytecodeExists = (-not [string]::IsNullOrWhiteSpace($code) -and $code -ne "0x")
            if (-not $checks.lockboxBytecodeExists) {
                Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS" -Reason "no deployed bytecode found at configured lockbox address" -Kind "failed" -Category "artifact"
            }
        }
        catch {
            Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS" -Reason "could not verify lockbox bytecode" -Kind "failed" -Category "artifact"
        }
    }
}

$supportedToken = Get-FlowChainEnvValue -Name "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN"
$assetMode = "unknown"
if (-not [string]::IsNullOrWhiteSpace($supportedToken)) {
    if ($supportedToken -notmatch '^0x[0-9a-fA-F]{40}$') {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN" -Reason "must be native zero address or an ERC-20 address" -Kind "failed"
    }
    else {
        $assetMode = if ($supportedToken.ToLowerInvariant() -eq $zeroAddress) { "native-eth" } else { "erc20" }
        $checks.supportedTokenShape = $true
        if ($assetMode -eq "erc20" -and $rpcUsable) {
            try {
                $tokenCode = Invoke-BaseReadOnlyRpc -RpcEndpoint $rpc -Method "eth_getCode" -Params @($supportedToken, "latest")
                $checks.supportedTokenBytecodeExists = (-not [string]::IsNullOrWhiteSpace($tokenCode) -and $tokenCode -ne "0x")
                if (-not $checks.supportedTokenBytecodeExists) {
                    Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN" -Reason "ERC-20 token mode requires deployed token bytecode" -Kind "failed" -Category "artifact"
                }
            }
            catch {
                Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN" -Reason "could not verify ERC-20 token bytecode" -Kind "failed" -Category "artifact"
            }
        }
        elseif ($assetMode -eq "native-eth") {
            $checks.supportedTokenBytecodeExists = $null
        }
    }
}

$decimals = Convert-FlowChainUInt -Name "FLOWCHAIN_BASE8453_ASSET_DECIMALS" -Value (Get-FlowChainEnvValue -Name "FLOWCHAIN_BASE8453_ASSET_DECIMALS") -Problems $problems -AllowZero
if ($null -ne $decimals -and ($decimals -lt 0 -or $decimals -gt 255)) {
    Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_BASE8453_ASSET_DECIMALS" -Reason "must be between 0 and 255" -Kind "failed"
}

$fromBlock = Convert-FlowChainUInt -Name "FLOWCHAIN_BASE8453_FROM_BLOCK" -Value (Get-FlowChainEnvValue -Name "FLOWCHAIN_BASE8453_FROM_BLOCK") -Problems $problems -AllowZero
$toBlock = Convert-FlowChainUInt -Name "FLOWCHAIN_BASE8453_TO_BLOCK" -Value (Get-FlowChainEnvValue -Name "FLOWCHAIN_BASE8453_TO_BLOCK") -Problems $problems -AllowZero
if ($null -ne $fromBlock -and $null -ne $toBlock) {
    if ($fromBlock -gt $toBlock) {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_BASE8453_FROM_BLOCK" -Reason "from block must be less than or equal to to block" -Kind "failed"
    }
    elseif (($toBlock - $fromBlock) -gt $maxBlockRange) {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_BASE8453_TO_BLOCK" -Reason "block range exceeds pilot maximum" -Kind "failed"
    }
}

$maxDeposit = Convert-FlowChainUInt -Name "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI" -Value (Get-FlowChainEnvValue -Name "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI") -Problems $problems
$totalCap = Convert-FlowChainUInt -Name "FLOWCHAIN_PILOT_TOTAL_CAP_WEI" -Value (Get-FlowChainEnvValue -Name "FLOWCHAIN_PILOT_TOTAL_CAP_WEI") -Problems $problems
if ($null -ne $maxDeposit -and $null -ne $totalCap -and $totalCap -lt $maxDeposit) {
    Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_PILOT_TOTAL_CAP_WEI" -Reason "must be greater than or equal to max deposit" -Kind "failed"
}

$confirmations = Convert-FlowChainUInt -Name "FLOWCHAIN_PILOT_CONFIRMATIONS" -Value (Get-FlowChainEnvValue -Name "FLOWCHAIN_PILOT_CONFIRMATIONS") -Problems $problems
if ($null -ne $confirmations) {
    if ($confirmations -lt $minConfirmations) {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_PILOT_CONFIRMATIONS" -Reason "confirmation depth is below pilot minimum" -Kind "failed"
    }
    if ($confirmations -gt $maxConfirmations) {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_PILOT_CONFIRMATIONS" -Reason "confirmation depth is above pilot maximum" -Kind "failed"
    }
}

$scripts = Get-FlowChainPackageScripts -RepoRoot $repoRoot
$emergencyCommands = @(
    "flowchain:bridge:pause",
    "flowchain:bridge:resume",
    "flowchain:bridge:emergency-stop",
    "flowchain:emergency:stop-local"
)
$diagnosticCommands = @(
    "flowchain:bridge:diagnose:tx"
)
$missingEmergencyCommands = @($emergencyCommands | Where-Object { $scripts -notcontains $_ })
if ($missingEmergencyCommands.Count -gt 0) {
    foreach ($command in $missingEmergencyCommands) {
        Add-FlowChainReadinessProblem -Problems $problems -Name $command -Reason "emergency command is not discoverable in package.json" -Kind "failed" -Category "artifact"
    }
}
$missingDiagnosticCommands = @($diagnosticCommands | Where-Object { $scripts -notcontains $_ })
if ($missingDiagnosticCommands.Count -gt 0) {
    foreach ($command in $missingDiagnosticCommands) {
        Add-FlowChainReadinessProblem -Problems $problems -Name $command -Reason "Base transaction diagnostic command is not discoverable in package.json" -Kind "failed" -Category "artifact"
    }
}
$checks.emergencyCommandsDiscoverable = $missingEmergencyCommands.Count -eq 0
$checks.diagnosticCommandsDiscoverable = $missingDiagnosticCommands.Count -eq 0

$failed = @($problems | Where-Object { $_.kind -eq "failed" })
$status = if ($failed.Count -gt 0) { "failed" } elseif ($problems.Count -gt 0) { "blocked" } else { "passed" }

$report = [ordered]@{
    schema = "flowchain.bridge_infra_readiness_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    requiredEnvNames = $requiredEnv
    deploymentBroadcastEnvNames = $broadcastEnvNames
    missingEnvNames = @($missingEnv | Select-Object -Unique)
    baseChainId = 8453
    assetMode = $assetMode
    checks = $checks
    blockRangePolicy = [ordered]@{
        maxRange = $maxBlockRange.ToString()
        fromBlockConfigured = $null -ne $fromBlock
        toBlockConfigured = $null -ne $toBlock
    }
    capPolicy = [ordered]@{
        maxDepositConfigured = $null -ne $maxDeposit
        totalCapConfigured = $null -ne $totalCap
    }
    confirmationPolicy = [ordered]@{
        confirmationsConfigured = $null -ne $confirmations
        minConfirmations = $minConfirmations.ToString()
        maxConfirmations = $maxConfirmations.ToString()
    }
    emergencyCommands = @(
        "npm run flowchain:bridge:pause",
        "npm run flowchain:bridge:resume",
        "npm run flowchain:bridge:emergency-stop",
        "npm run flowchain:emergency:stop-local"
    )
    diagnosticCommands = @(
        "npm run flowchain:bridge:diagnose:tx -- --tx-hash <owner-supplied-base-tx-hash>"
    )
    diagnosticEnvNames = @(
        "FLOWCHAIN_BASE8453_TX_HASH",
        "FLOWCHAIN_BASE8453_OPERATOR_TX_HASH"
    )
    problems = @($problems)
    broadcasts = $false
    readOnlyBaseRpcMethods = @("eth_chainId", "eth_getCode")
    envValuesPrinted = $false
    noSecrets = $true
}
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

Write-Host "FlowChain bridge infra readiness status: $status"
Write-Host "Report: $reportFullPath"
if ($missingEnv.Count -gt 0) {
    Write-Host "Missing env names: $((@($missingEnv | Select-Object -Unique)) -join ', ')"
}
if ($status -ne "passed" -and -not $AllowBlocked) {
    throw "Bridge infra readiness $status. See report for env and artifact names."
}
