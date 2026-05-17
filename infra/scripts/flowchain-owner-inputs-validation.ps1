param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/owner-inputs-validation-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$validationDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-validation")
$backupDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/owner-inputs-validation-backup")
New-Item -ItemType Directory -Force -Path $validationDir | Out-Null
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

$requiredEnvNames = @(
    "FLOWCHAIN_RPC_PUBLIC_URL",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
    "FLOWCHAIN_RPC_TLS_TERMINATED",
    "FLOWCHAIN_RPC_STATE_BACKUP_PATH",
    "FLOWCHAIN_TESTER_WRITE_ENABLED",
    "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256",
    "FLOWCHAIN_TESTER_MAX_SEND_UNITS",
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

function Set-OwnerValidationEnv {
    param(
        [hashtable] $Values,
        [AllowNull()][string] $OwnerEnvFilePath = $null
    )

    foreach ($name in $requiredEnvNames) {
        $value = if ($Values.ContainsKey($name)) { [string] $Values[$name] } else { $null }
        [Environment]::SetEnvironmentVariable($name, $value, "Process")
    }
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_OWNER_ENV_FILE", $OwnerEnvFilePath, "Process")
}

function Get-ValidationJsonProp {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name,
        [object] $Default = $null
    )

    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $Default
}

function Invoke-OwnerValidationScenario {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][hashtable] $EnvValues,
        [Parameter(Mandatory = $true)][string] $ExpectedStatus,
        [AllowNull()][string] $OwnerEnvFilePath = $null
    )

    Set-OwnerValidationEnv -Values $EnvValues -OwnerEnvFilePath $OwnerEnvFilePath
    $scenarioReportPath = Join-Path $validationDir "$Name-report.json"
    $scenarioMarkdownPath = Join-Path $validationDir "$Name.md"
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-owner-inputs.ps1") -ReportPath $scenarioReportPath -MarkdownPath $scenarioMarkdownPath -AllowBlocked 2>&1
    $exitCode = $LASTEXITCODE
    $scenarioReport = Read-FlowChainJsonIfExists -Path $scenarioReportPath
    $actualStatus = [string](Get-ValidationJsonProp -Object $scenarioReport -Name "status" -Default "missing")
    $missingEnvNames = @((Get-ValidationJsonProp -Object $scenarioReport -Name "missingEnvNames" -Default @()))
    $invalidEnvNames = @((Get-ValidationJsonProp -Object $scenarioReport -Name "invalidEnvNames" -Default @()))
    $expectedExitCode = if ($ExpectedStatus -eq "failed") { 1 } else { 0 }
    $passed = $actualStatus -eq $ExpectedStatus -and $exitCode -eq $expectedExitCode

    return [ordered]@{
        name = $Name
        expectedStatus = $ExpectedStatus
        actualStatus = $actualStatus
        exitCode = $exitCode
        expectedExitCode = $expectedExitCode
        passed = $passed
        missingEnvCount = $missingEnvNames.Count
        invalidEnvCount = $invalidEnvNames.Count
        loadedFromOwnerEnvFile = -not [string]::IsNullOrWhiteSpace($OwnerEnvFilePath)
        reportPath = $scenarioReportPath
        markdownPath = $scenarioMarkdownPath
        outputRedacted = @($output | ForEach-Object { "$_" })
    }
}

$originalEnv = @{}
foreach ($name in $requiredEnvNames) {
    $originalEnv[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}
$originalOwnerEnvFile = [Environment]::GetEnvironmentVariable("FLOWCHAIN_OWNER_ENV_FILE", "Process")

$invalidBackupFile = Join-Path $validationDir "invalid-backup-path.txt"
"not-a-directory" | Set-Content -LiteralPath $invalidBackupFile -Encoding UTF8
$missingOwnerEnvFile = Join-Path $validationDir "missing-owner-env.local"
if (Test-Path -LiteralPath $missingOwnerEnvFile) {
    Remove-Item -LiteralPath $missingOwnerEnvFile -Force
}
$malformedOwnerEnvFile = Join-Path $validationDir "malformed-owner-env.local"
"FLOWCHAIN_RPC_PUBLIC_URL" | Set-Content -LiteralPath $malformedOwnerEnvFile -Encoding UTF8
$validEnvFile = Join-Path $backupDir ".env.owner-validation.local"
@(
    "FLOWCHAIN_RPC_PUBLIC_URL=https://flowchain-owner.example",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS=https://tester.example",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE=60",
    "FLOWCHAIN_RPC_TLS_TERMINATED=true",
    "FLOWCHAIN_RPC_STATE_BACKUP_PATH=$backupDir",
    "FLOWCHAIN_TESTER_WRITE_ENABLED=true",
    "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "FLOWCHAIN_TESTER_MAX_SEND_UNITS=1",
    "FLOWCHAIN_PILOT_OPERATOR_ACK=I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT",
    "FLOWCHAIN_BASE8453_RPC_URL=https://base-rpc.example",
    "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS=0x1111111111111111111111111111111111111111",
    "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN=0x0000000000000000000000000000000000000000",
    "FLOWCHAIN_BASE8453_ASSET_DECIMALS=18",
    "FLOWCHAIN_BASE8453_FROM_BLOCK=1",
    "FLOWCHAIN_BASE8453_TO_BLOCK=2",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI=1000000000000000",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI=2000000000000000",
    "FLOWCHAIN_PILOT_CONFIRMATIONS=3"
) | Set-Content -LiteralPath $validEnvFile -Encoding UTF8

$scenarios = New-Object System.Collections.ArrayList
try {
    [void] $scenarios.Add((Invoke-OwnerValidationScenario -Name "missing" -ExpectedStatus "blocked" -EnvValues @{}))

    [void] $scenarios.Add((Invoke-OwnerValidationScenario -Name "invalid" -ExpectedStatus "failed" -EnvValues @{
        FLOWCHAIN_RPC_PUBLIC_URL = "http://127.0.0.1:8787"
        FLOWCHAIN_RPC_ALLOWED_ORIGINS = "*"
        FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE = "0"
        FLOWCHAIN_RPC_TLS_TERMINATED = "false"
        FLOWCHAIN_RPC_STATE_BACKUP_PATH = $invalidBackupFile
        FLOWCHAIN_TESTER_WRITE_ENABLED = "false"
        FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256 = "not-a-hash"
        FLOWCHAIN_TESTER_MAX_SEND_UNITS = "0"
        FLOWCHAIN_PILOT_OPERATOR_ACK = "WRONG_ACK"
        FLOWCHAIN_BASE8453_RPC_URL = "not-a-url"
        FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS = "bad-address"
        FLOWCHAIN_BASE8453_SUPPORTED_TOKEN = "0x123"
        FLOWCHAIN_BASE8453_ASSET_DECIMALS = "999"
        FLOWCHAIN_BASE8453_FROM_BLOCK = "-1"
        FLOWCHAIN_BASE8453_TO_BLOCK = "not-a-block"
        FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI = "0"
        FLOWCHAIN_PILOT_TOTAL_CAP_WEI = "-1"
        FLOWCHAIN_PILOT_CONFIRMATIONS = "nope"
    }))

    [void] $scenarios.Add((Invoke-OwnerValidationScenario -Name "valid-structure" -ExpectedStatus "passed" -EnvValues @{
        FLOWCHAIN_RPC_PUBLIC_URL = "https://flowchain-owner.example"
        FLOWCHAIN_RPC_ALLOWED_ORIGINS = "https://tester.example"
        FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE = "60"
        FLOWCHAIN_RPC_TLS_TERMINATED = "true"
        FLOWCHAIN_RPC_STATE_BACKUP_PATH = $backupDir
        FLOWCHAIN_TESTER_WRITE_ENABLED = "true"
        FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        FLOWCHAIN_TESTER_MAX_SEND_UNITS = "1"
        FLOWCHAIN_PILOT_OPERATOR_ACK = "I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
        FLOWCHAIN_BASE8453_RPC_URL = "https://base-rpc.example"
        FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS = "0x1111111111111111111111111111111111111111"
        FLOWCHAIN_BASE8453_SUPPORTED_TOKEN = "0x0000000000000000000000000000000000000000"
        FLOWCHAIN_BASE8453_ASSET_DECIMALS = "18"
        FLOWCHAIN_BASE8453_FROM_BLOCK = "1"
        FLOWCHAIN_BASE8453_TO_BLOCK = "2"
        FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI = "1000000000000000"
        FLOWCHAIN_PILOT_TOTAL_CAP_WEI = "2000000000000000"
        FLOWCHAIN_PILOT_CONFIRMATIONS = "3"
    }))

    [void] $scenarios.Add((Invoke-OwnerValidationScenario -Name "valid-owner-env-file" -ExpectedStatus "passed" -EnvValues @{} -OwnerEnvFilePath $validEnvFile))
    [void] $scenarios.Add((Invoke-OwnerValidationScenario -Name "missing-owner-env-file" -ExpectedStatus "failed" -EnvValues @{} -OwnerEnvFilePath $missingOwnerEnvFile))
    [void] $scenarios.Add((Invoke-OwnerValidationScenario -Name "malformed-owner-env-file" -ExpectedStatus "failed" -EnvValues @{} -OwnerEnvFilePath $malformedOwnerEnvFile))
}
finally {
    foreach ($name in $requiredEnvNames) {
        [Environment]::SetEnvironmentVariable($name, $originalEnv[$name], "Process")
    }
    [Environment]::SetEnvironmentVariable("FLOWCHAIN_OWNER_ENV_FILE", $originalOwnerEnvFile, "Process")
}

$failedScenarios = @($scenarios | Where-Object { $_.passed -ne $true })
$status = if ($failedScenarios.Count -eq 0) { "passed" } else { "failed" }
$report = [ordered]@{
    schema = "flowchain.owner_inputs_validation_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    requiredEnvNames = $requiredEnvNames
    scenarioCount = $scenarios.Count
    scenarios = @($scenarios)
    checks = [ordered]@{
        missingScenarioBlocks = (@($scenarios | Where-Object { $_.name -eq "missing" -and $_.actualStatus -eq "blocked" -and $_.missingEnvCount -eq $requiredEnvNames.Count }).Count -eq 1)
        invalidScenarioFails = (@($scenarios | Where-Object { $_.name -eq "invalid" -and $_.actualStatus -eq "failed" -and $_.invalidEnvCount -gt 0 }).Count -eq 1)
        validStructureScenarioPasses = (@($scenarios | Where-Object { $_.name -eq "valid-structure" -and $_.actualStatus -eq "passed" -and $_.missingEnvCount -eq 0 -and $_.invalidEnvCount -eq 0 }).Count -eq 1)
        validOwnerEnvFileScenarioPasses = (@($scenarios | Where-Object { $_.name -eq "valid-owner-env-file" -and $_.actualStatus -eq "passed" -and $_.missingEnvCount -eq 0 -and $_.invalidEnvCount -eq 0 -and $_.loadedFromOwnerEnvFile -eq $true }).Count -eq 1)
        missingOwnerEnvFileScenarioFails = (@($scenarios | Where-Object { $_.name -eq "missing-owner-env-file" -and $_.actualStatus -eq "failed" -and $_.invalidEnvCount -gt 0 -and $_.loadedFromOwnerEnvFile -eq $true }).Count -eq 1)
        malformedOwnerEnvFileScenarioFails = (@($scenarios | Where-Object { $_.name -eq "malformed-owner-env-file" -and $_.actualStatus -eq "failed" -and $_.invalidEnvCount -gt 0 -and $_.loadedFromOwnerEnvFile -eq $true }).Count -eq 1)
    }
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$reportText = $report | ConvertTo-Json -Depth 18
Assert-FlowChainNoSecretText -Text $reportText -Label "owner inputs validation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

Write-Host "FlowChain owner inputs validation status: $status"
Write-Host "Scenarios: $($scenarios.Count)"
Write-Host "Report: $reportFullPath"
if ($status -ne "passed") {
    Write-Host "Failed scenarios: $((@($failedScenarios | ForEach-Object { $_.name }) -join ', '))"
    exit 1
}
exit 0
