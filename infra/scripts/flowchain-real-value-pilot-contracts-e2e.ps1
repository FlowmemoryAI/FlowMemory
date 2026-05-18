param(
    [switch] $SkipHardening
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

function Invoke-ContractsProofCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Label,

        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [string[]] $ArgumentList = @()
    )

    [void] $script:commandsRun.Add("$FilePath $(Join-FlowChainProcessArguments -ArgumentList $ArgumentList)".Trim())
    Invoke-FlowChainCommand -Label $Label -FilePath $FilePath -ArgumentList $ArgumentList
}

function Invoke-CapturedContractsCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Label,

        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [string[]] $ArgumentList = @(),

        [switch] $ExpectFailure,

        [string] $ExpectedText = ""
    )

    $display = "$FilePath $(Join-FlowChainProcessArguments -ArgumentList $ArgumentList)".Trim()
    [void] $script:commandsRun.Add($display)

    Write-Host ""
    Write-Host "== $Label =="
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = (& $FilePath @ArgumentList 2>&1) | ForEach-Object { "$_" }
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($ExpectFailure) {
        if ($exitCode -eq 0) {
            throw "Expected command to fail, but it passed: $display"
        }
    }
    elseif ($exitCode -ne 0) {
        throw "$Label failed with exit code ${exitCode}: $display`n$($output -join [Environment]::NewLine)"
    }

    $body = $output -join [Environment]::NewLine
    if (-not [string]::IsNullOrWhiteSpace($ExpectedText) -and $body -notlike "*$ExpectedText*") {
        throw "$Label did not include expected text: $ExpectedText"
    }

    Write-Host $body
    return $body
}

function Set-BridgeDeployProofEnv {
    param(
        [bool] $PilotAck,
        [string] $NativeTotalCap = "5000000000000000"
    )

    $env:FLOWCHAIN_BRIDGE_OWNER = "0x1111111111111111111111111111111111111111"
    $env:FLOWCHAIN_BRIDGE_RELEASE_AUTHORITY = "0x2222222222222222222222222222222222222222"
    $env:FLOWCHAIN_SETTLEMENT_SUBMITTER = "0x3333333333333333333333333333333333333333"
    $env:FLOWCHAIN_BRIDGE_ALLOW_NATIVE = "true"
    $env:FLOWCHAIN_BRIDGE_NATIVE_PER_DEPOSIT_CAP = "1000000000000000"
    $env:FLOWCHAIN_BRIDGE_NATIVE_TOTAL_CAP = $NativeTotalCap
    $env:FLOWCHAIN_BRIDGE_ALLOW_ERC20 = "false"
    $env:FLOWCHAIN_BRIDGE_ERC20_TOKEN = "0x0000000000000000000000000000000000000000"
    $env:FLOWCHAIN_BRIDGE_ERC20_PER_DEPOSIT_CAP = "0"
    $env:FLOWCHAIN_BRIDGE_ERC20_TOTAL_CAP = "0"
    if ($PilotAck) {
        $env:FLOWCHAIN_BASE8453_PILOT_ACK = "true"
    }
    else {
        $env:FLOWCHAIN_BASE8453_PILOT_ACK = $null
    }
}

$repoRoot = Set-FlowChainRepoRoot
$reportDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/real-value-pilot/contracts-e2e")
if (Test-Path -LiteralPath $reportDir) {
    Remove-Item -LiteralPath $reportDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

$script:commandsRun = New-Object System.Collections.ArrayList
$envNames = @(
    "FLOWCHAIN_BRIDGE_OWNER",
    "FLOWCHAIN_BRIDGE_RELEASE_AUTHORITY",
    "FLOWCHAIN_SETTLEMENT_SUBMITTER",
    "FLOWCHAIN_BRIDGE_ALLOW_NATIVE",
    "FLOWCHAIN_BRIDGE_NATIVE_PER_DEPOSIT_CAP",
    "FLOWCHAIN_BRIDGE_NATIVE_TOTAL_CAP",
    "FLOWCHAIN_BRIDGE_ALLOW_ERC20",
    "FLOWCHAIN_BRIDGE_ERC20_TOKEN",
    "FLOWCHAIN_BRIDGE_ERC20_PER_DEPOSIT_CAP",
    "FLOWCHAIN_BRIDGE_ERC20_TOTAL_CAP",
    "FLOWCHAIN_BASE8453_PILOT_ACK"
)
$savedEnv = @{}
foreach ($name in $envNames) {
    $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

try {
    Invoke-ContractsProofCommand `
        -Label "Bridge lockbox focused tests" `
        -FilePath "forge" `
        -ArgumentList @("test", "--match-path", "tests/bridge/BaseBridgeLockbox.t.sol")

    Invoke-ContractsProofCommand `
        -Label "Settlement spine focused tests" `
        -FilePath "forge" `
        -ArgumentList @("test", "--match-path", "tests/FlowChainSettlementSpine.t.sol")

    if (-not $SkipHardening) {
        Invoke-ContractsProofCommand `
            -Label "Contract hardening gate" `
            -FilePath "npm" `
            -ArgumentList @("run", "contracts:hardening")
    }

    Set-BridgeDeployProofEnv -PilotAck $false
    Invoke-CapturedContractsCommand `
        -Label "Local Anvil bridge-spine dry run" `
        -FilePath "forge" `
        -ArgumentList @("script", "script/DeployBridgeSpine.s.sol:DeployBridgeSpine", "--chain-id", "31337") `
        -ExpectedText "chainId: 31337" | Out-Null

    Invoke-CapturedContractsCommand `
        -Label "Base 8453 dry run rejects missing pilot ack" `
        -FilePath "forge" `
        -ArgumentList @("script", "script/DeployBridgeSpine.s.sol:DeployBridgeSpine", "--chain-id", "8453") `
        -ExpectFailure `
        -ExpectedText "Base8453PilotAckRequired" | Out-Null

    Set-BridgeDeployProofEnv -PilotAck $true
    Invoke-CapturedContractsCommand `
        -Label "Base 8453 bridge-spine dry run with pilot ack" `
        -FilePath "forge" `
        -ArgumentList @("script", "script/DeployBridgeSpine.s.sol:DeployBridgeSpine", "--chain-id", "8453") `
        -ExpectedText "chainId: 8453" | Out-Null
}
finally {
    foreach ($name in $envNames) {
        [Environment]::SetEnvironmentVariable($name, $savedEnv[$name], "Process")
    }
}

$bridgeDoc = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "docs/bridge/FLOWCHAIN_BASE_BRIDGE_POC.md")
foreach ($expected in @(
        "FLOWCHAIN_BASE8453_PILOT_ACK",
        "forge verify-contract",
        "Do not commit RPC URLs or private keys",
        "BRIDGE_CREDIT_OBJECT",
        "BRIDGE_WITHDRAWAL_INTENT_OBJECT"
    )) {
    if ($bridgeDoc -notlike "*$expected*") {
        throw "Bridge contract documentation is missing expected evidence text: $expected"
    }
}

$deploymentBoundary = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "contracts/DEPLOYMENT_BOUNDARY.md")
foreach ($expected in @("8453", "nonzero total caps", "FLOWCHAIN_BASE8453_PILOT_ACK=true")) {
    if ($deploymentBoundary -notlike "*$expected*") {
        throw "Deployment boundary documentation is missing expected evidence text: $expected"
    }
}

$reportPath = Join-Path $reportDir "flowchain-real-value-pilot-contracts-e2e-report.json"
$report = [ordered]@{
    schema = "flowchain.real_value_pilot.contracts_e2e_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "passed"
    productionReady = $false
    commandsRun = @($commandsRun)
    checks = [ordered]@{
        bridgeLockboxTests = "passed"
        settlementSpineTests = "passed"
        contractHardening = $(if ($SkipHardening) { "skipped" } else { "passed" })
        localAnvilDryRun = "passed"
        base8453MissingAckRejection = "passed"
        base8453PilotAckDryRun = "passed"
        documentationEvidence = "passed"
    }
    evidence = [ordered]@{
        chainIds = @(31337, 84532, 8453)
        base8453AckEnv = "FLOWCHAIN_BASE8453_PILOT_ACK=true"
        deploymentScript = "script/DeployBridgeSpine.s.sol"
        lockboxTests = "tests/bridge/BaseBridgeLockbox.t.sol"
        settlementTests = "tests/FlowChainSettlementSpine.t.sol"
        deploymentBoundary = "contracts/DEPLOYMENT_BOUNDARY.md"
        bridgeDoc = "docs/bridge/FLOWCHAIN_BASE_BRIDGE_POC.md"
    }
    boundary = @(
        "capped owner pilot only",
        "dry-run by default",
        "no committed private key",
        "no broad bridge readiness claim"
    )
}
Write-FlowChainJson -Path $reportPath -Value $report -Depth 12

Write-Host ""
Write-Host "FlowChain real-value pilot contracts E2E passed."
Write-Host "Report: $reportPath"
