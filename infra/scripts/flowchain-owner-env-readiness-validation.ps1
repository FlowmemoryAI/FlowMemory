param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/owner-env-readiness-validation-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$validationDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-env-readiness-validation")
New-Item -ItemType Directory -Force -Path $validationDir | Out-Null

function ConvertTo-OwnerEnvValidationSafeLine {
    param([AllowNull()][object] $Line)

    $text = "$Line"
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "https?://[^\s,)]+", "<redacted-url>")
    return $text
}

function Get-OwnerEnvValidationProp {
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

function Get-OwnerEnvValidationSecretMarkerFindings {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string] $Label
    )

    $patterns = @(
        "privateKey",
        "private_key",
        "seedPhrase",
        "seed phrase",
        "mnemonic",
        "rpcUrl",
        "rpc-url",
        "apiKey",
        "webhook",
        "BEGIN RSA PRIVATE KEY",
        "BEGIN OPENSSH PRIVATE KEY"
    )

    $findings = New-Object System.Collections.ArrayList
    foreach ($pattern in $patterns) {
        if ($Text.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            [void] $findings.Add([ordered]@{
                label = $Label
                marker = $pattern
            })
        }
    }
    return @($findings)
}

function Invoke-OwnerEnvReadinessValidationScenario {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $OwnerEnvFile,
        [Parameter(Mandatory = $true)][string] $ExpectedProblem,
        [int] $ExpectedExitCode = 1
    )

    $scenarioReportPath = Join-Path $validationDir "$Name-report.json"
    $scenarioMarkdownPath = Join-Path $validationDir "$Name.md"
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-owner-env-readiness.ps1") `
            -OwnerEnvFile $OwnerEnvFile `
            -ReportPath $scenarioReportPath `
            -MarkdownPath $scenarioMarkdownPath `
            -AllowBlocked 2>&1) | ForEach-Object { ConvertTo-OwnerEnvValidationSafeLine -Line $_ }
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) {
            $exitCode = 0
        }
    }
    catch {
        $output = @(ConvertTo-OwnerEnvValidationSafeLine -Line $_.Exception.Message)
        $exitCode = 1
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    $scenarioReport = Read-FlowChainJsonIfExists -Path $scenarioReportPath
    $ownerEnvFileState = Get-OwnerEnvValidationProp -Object $scenarioReport -Name "ownerEnvFile"
    $problems = @((Get-OwnerEnvValidationProp -Object $ownerEnvFileState -Name "problems" -Default @()))
    $steps = @((Get-OwnerEnvValidationProp -Object $scenarioReport -Name "steps" -Default @()))
    $actualStatus = [string](Get-OwnerEnvValidationProp -Object $scenarioReport -Name "status" -Default "missing")
    $problemMatched = @($problems | Where-Object { "$_".IndexOf($ExpectedProblem, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count -gt 0
    $passed = $actualStatus -eq "failed" `
        -and [int] $exitCode -eq $ExpectedExitCode `
        -and $problemMatched `
        -and $steps.Count -eq 0 `
        -and ((Get-OwnerEnvValidationProp -Object $scenarioReport -Name "envValuesPrinted" -Default $true) -eq $false) `
        -and ((Get-OwnerEnvValidationProp -Object $scenarioReport -Name "noSecrets" -Default $false) -eq $true) `
        -and ((Get-OwnerEnvValidationProp -Object $scenarioReport -Name "broadcasts" -Default $true) -eq $false)

    return [ordered]@{
        name = $Name
        expectedStatus = "failed"
        actualStatus = $actualStatus
        exitCode = [int] $exitCode
        expectedExitCode = $ExpectedExitCode
        passed = $passed
        expectedProblem = $ExpectedProblem
        problemMatched = $problemMatched
        stepCount = $steps.Count
        reportPath = $scenarioReportPath
        markdownPath = $scenarioMarkdownPath
        outputRedactedTail = @($output | Select-Object -Last 40)
    }
}

$missingOwnerEnvPath = Join-Path $validationDir "missing-owner-env.local"
if (Test-Path -LiteralPath $missingOwnerEnvPath) {
    Remove-Item -LiteralPath $missingOwnerEnvPath -Force
}

$unignoredOwnerEnvPath = Join-Path $validationDir "unignored-owner-env.local"
"FLOWCHAIN_RPC_PUBLIC_URL=" | Set-Content -LiteralPath $unignoredOwnerEnvPath -Encoding UTF8

$scenarios = New-Object System.Collections.ArrayList
try {
    [void] $scenarios.Add((Invoke-OwnerEnvReadinessValidationScenario `
        -Name "missing-owner-env-file" `
        -OwnerEnvFile $missingOwnerEnvPath `
        -ExpectedProblem "missing"))

    [void] $scenarios.Add((Invoke-OwnerEnvReadinessValidationScenario `
        -Name "unignored-owner-env-file" `
        -OwnerEnvFile $unignoredOwnerEnvPath `
        -ExpectedProblem "not git-ignored"))
}
finally {
    if (Test-Path -LiteralPath $unignoredOwnerEnvPath) {
        Remove-Item -LiteralPath $unignoredOwnerEnvPath -Force
    }
}

$failedScenarios = @($scenarios | Where-Object { $_.passed -ne $true })
$checks = [ordered]@{
    missingOwnerEnvFileFailsBeforeChildGates = (@($scenarios | Where-Object { $_.name -eq "missing-owner-env-file" -and $_.passed -eq $true }).Count -eq 1)
    unignoredOwnerEnvFileFailsBeforeChildGates = (@($scenarios | Where-Object { $_.name -eq "unignored-owner-env-file" -and $_.passed -eq $true }).Count -eq 1)
    scenarioCountExpected = $scenarios.Count -eq 2
    allScenariosPassed = $failedScenarios.Count -eq 0
    failedScenariosAbsent = $failedScenarios.Count -eq 0
    envValuesPrintedFalse = $true
    noSecrets = $true
    broadcastsFalse = $true
    secretMarkerFindingsEmpty = $true
}
$report = [ordered]@{
    schema = "flowchain.owner_env_readiness_validation_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "pending"
    scenarioCount = $scenarios.Count
    scenarios = @($scenarios)
    checks = $checks
    failedChecks = @()
    secretMarkerFindings = @()
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$preliminaryReportText = $report | ConvertTo-Json -Depth 18
$secretMarkerFindings = @(Get-OwnerEnvValidationSecretMarkerFindings -Text $preliminaryReportText -Label "owner env readiness validation report")
$checks["secretMarkerFindingsEmpty"] = $secretMarkerFindings.Count -eq 0
$checks["noSecrets"] = $secretMarkerFindings.Count -eq 0
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
$report["status"] = $status
$report["checks"] = $checks
$report["failedChecks"] = @($failedChecks)
$report["secretMarkerFindings"] = @($secretMarkerFindings)
$report["noSecrets"] = $secretMarkerFindings.Count -eq 0

$reportText = $report | ConvertTo-Json -Depth 18
Assert-FlowChainNoSecretText -Text $reportText -Label "owner env readiness validation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

Write-Host "FlowChain owner env readiness validation status: $status"
Write-Host "Scenarios: $($scenarios.Count)"
Write-Host "Report: $reportFullPath"
if ($status -ne "passed") {
    Write-Host "Failed scenarios: $((@($failedScenarios | ForEach-Object { $_.name }) -join ', '))"
    exit 1
}
exit 0
