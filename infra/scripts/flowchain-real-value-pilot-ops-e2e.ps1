param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

function Invoke-PilotParserCheck {
    param([Parameter(Mandatory = $true)][string] $Path)

    $tokens = $null
    $errors = $null
    [System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw -LiteralPath $Path), [ref] $errors) | Out-Null
    if ($errors -and $errors.Count -gt 0) {
        $messages = $errors | ForEach-Object { "$($_.Message) at line $($_.Token.StartLine)" }
        throw "PowerShell parser errors in ${Path}: $($messages -join '; ')"
    }
}

function Invoke-CapturedPowerShell {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments,

        [switch] $ExpectFailure
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = (& powershell @Arguments 2>&1) | ForEach-Object { "$_" }
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($ExpectFailure) {
        if ($exitCode -eq 0) {
            throw "Expected command to fail, but it passed: powershell $($Arguments -join ' ')"
        }
    }
    elseif ($exitCode -ne 0) {
        throw "Command failed with exit code ${exitCode}: powershell $($Arguments -join ' ')`n$($output -join [Environment]::NewLine)"
    }

    return ($output -join [Environment]::NewLine)
}

$repoRoot = Set-FlowChainRepoRoot
$reportDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/real-value-pilot/ops-e2e")
if (Test-Path -LiteralPath $reportDir) {
    Remove-Item -LiteralPath $reportDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

$scriptPaths = @(
    (Join-Path $PSScriptRoot "flowchain-real-value-pilot.ps1"),
    (Join-Path $PSScriptRoot "flowchain-real-value-pilot-export.ps1"),
    (Join-Path $PSScriptRoot "flowchain-real-value-pilot-emergency-stop.ps1"),
    (Join-Path $PSScriptRoot "flowchain-real-value-pilot-ops-e2e.ps1")
)

foreach ($scriptPath in $scriptPaths) {
    Invoke-PilotParserCheck -Path $scriptPath
}

$pilotEnvNames = @(
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

$savedEnv = @{}
foreach ($name in $pilotEnvNames) {
    $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
    [Environment]::SetEnvironmentVariable($name, $null, "Process")
}

try {
    $dryRunOutput = Invoke-CapturedPowerShell -Arguments @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Join-Path $PSScriptRoot "flowchain-real-value-pilot.ps1"),
        "-Mode",
        "DryRun",
        "-Action",
        "All"
    )

    foreach ($expected in @(
            "After deploy, next command:",
            "After observe, next command:",
            "After credit, next command:",
            "After withdraw, next command:",
            "After pause, next command:",
            "After resume, next command:",
            "After export evidence, next command:",
            "After restart, next command:"
        )) {
        if ($dryRunOutput -notlike "*$expected*") {
            throw "Dry-run output did not include expected next-command line: $expected"
        }
    }

    $emergencyDryRunOutput = Invoke-CapturedPowerShell -Arguments @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Join-Path $PSScriptRoot "flowchain-real-value-pilot-emergency-stop.ps1"),
        "-Mode",
        "DryRun",
        "-PlanOnly"
    )

    if ($emergencyDryRunOutput -notlike "*After pause, next command:*") {
        throw "Emergency stop dry-run did not print the pause next command."
    }

    $liveFailureOutput = Invoke-CapturedPowerShell -ExpectFailure -Arguments @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Join-Path $PSScriptRoot "flowchain-real-value-pilot.ps1"),
        "-Mode",
        "Live",
        "-Action",
        "Observe"
    )
}
finally {
    foreach ($name in $pilotEnvNames) {
        [Environment]::SetEnvironmentVariable($name, $savedEnv[$name], "Process")
    }
}

if ($liveFailureOutput -notlike "*FLOWCHAIN_PILOT_OPERATOR_ACK*") {
    throw "Live missing-env refusal did not name FLOWCHAIN_PILOT_OPERATOR_ACK."
}

$exportReport = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/real-value-pilot/export/flowchain-real-value-pilot-evidence-export-report.json"
if (-not (Test-Path -LiteralPath $exportReport)) {
    throw "Expected evidence export report was not written: $exportReport"
}

$reportPath = Join-Path $reportDir "flowchain-real-value-pilot-ops-e2e-report.json"
$report = [ordered]@{
    schema = "flowchain.real_value_pilot.ops_e2e_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "passed"
    parserChecks = "passed"
    dryRunPilot = "passed"
    dryRunEmergencyStop = "passed"
    liveMissingEnvRefusal = "passed"
    evidenceExportReport = $exportReport
    checkedNextCommands = @(
        "deploy",
        "observe",
        "credit",
        "withdraw",
        "pause",
        "resume",
        "export evidence",
        "restart"
    )
}
Write-FlowChainJson -Path $reportPath -Value $report -Depth 12

Write-Host ""
Write-Host "FlowChain real-value pilot ops dry-run E2E passed."
Write-Host "Report: $reportPath"
