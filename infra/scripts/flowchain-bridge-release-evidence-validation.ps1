param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-release-evidence-validation-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/BRIDGE_RELEASE_EVIDENCE_VALIDATION.md",
    [string] $ValidationDir = "devnet/local/bridge-release-evidence-validation"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$validationRoot = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ValidationDir)
Reset-FlowChainDirectory -Path $validationRoot | Out-Null

function Get-ReleaseValidationProp {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name,
        [object] $Default = $null
    )

    if ($null -ne $Object -and $Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
    }
    if ($null -ne $Object) {
        $property = $Object.PSObject.Properties[$Name]
        if ($null -ne $property) {
            return $property.Value
        }
    }
    return $Default
}

function Read-ReleaseValidationJson {
    param([Parameter(Mandatory = $true)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function New-ValidationWithdrawalIntent {
    return [ordered]@{
        schema = "flowmemory.bridge_withdrawal_intent.v0"
        withdrawalIntentId = "0xfd62ac06e6944fb7f26b5b88be849720357a3244ac54303396335901244bac8d"
        creditId = "0x2515a22490376060f94efded3938c1d99d653d51074662f260b0341aa64f2bc4"
        depositId = "0x8453000000000000000000000000000000000000000000000000000000000001"
        sourceChainId = 8453
        destinationChainId = 8453
        token = "0x3333333333333333333333333333333333333333"
        asset = [ordered]@{
            sourceChainId = 8453
            sourceToken = "0x3333333333333333333333333333333333333333"
            destinationAssetId = "0x9ea65e37950fafcd531e6bda593d2b54e4ecc77f04e917279f93b65edc8e4677"
            decimals = 6
        }
        amount = "20000000"
        flowchainAccount = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        baseRecipient = "0x4444444444444444444444444444444444444444"
        status = "requested"
        requestedAt = "2026-05-13T00:00:00.000Z"
        testMode = $true
        broadcast = $false
        releasePolicy = "test_record_only"
        productionReady = $false
    }
}

function New-ValidationReleaseEvidence {
    return [ordered]@{
        schema = "flowmemory.bridge_release_evidence.v0"
        releaseEvidenceId = "0xaedc67959260d1021ba56a8bb10bebc86775d8eb286640512dfd001aa431da03"
        generatedAt = "2026-05-13T00:00:00.000Z"
        withdrawalIntentId = "0xfd62ac06e6944fb7f26b5b88be849720357a3244ac54303396335901244bac8d"
        creditId = "0x2515a22490376060f94efded3938c1d99d653d51074662f260b0341aa64f2bc4"
        depositId = "0x8453000000000000000000000000000000000000000000000000000000000001"
        sourceChainId = 8453
        destinationChainId = 8453
        lockbox = "0x1111111111111111111111111111111111111111"
        asset = [ordered]@{
            sourceChainId = 8453
            sourceToken = "0x3333333333333333333333333333333333333333"
            destinationAssetId = "0x9ea65e37950fafcd531e6bda593d2b54e4ecc77f04e917279f93b65edc8e4677"
            decimals = 6
        }
        releaseCall = [ordered]@{
            method = "releaseERC20"
            recipient = "0x4444444444444444444444444444444444444444"
            token = "0x3333333333333333333333333333333333333333"
            amount = "20000000"
            evidenceHash = "0x2c520ff3228c6754a56baaca900dde0cbac6ad064fc79521c440424790f1479e"
            broadcast = $false
        }
        operatorNote = "Pilot release evidence only. Review before any separate release-authority transaction; this relayer does not broadcast."
        productionReady = $true
        localOnly = $false
    }
}

function Invoke-ReleaseValidationChild {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $WithdrawalPath,
        [Parameter(Mandatory = $true)][string] $ReleasePath,
        [Parameter(Mandatory = $true)][string] $CaseReportPath
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-bridge-release-evidence.ps1") -WithdrawalIntentPath $WithdrawalPath -ReleaseEvidencePath $ReleasePath -ReportPath $CaseReportPath 2>&1) | ForEach-Object { "$_" }
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) {
            $exitCode = 0
        }
    }
    catch {
        $output = @($_.Exception.Message)
        $exitCode = 1
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    return [ordered]@{
        name = $Name
        exitCode = [int] $exitCode
        outputTail = @($output | Select-Object -Last 10)
    }
}

$cases = New-Object System.Collections.ArrayList

function Add-ReleaseValidationCase {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $ExpectedStatus,
        [Parameter(Mandatory = $true)][bool] $ExpectedExitZero,
        [scriptblock] $MutateWithdrawal = $null,
        [scriptblock] $MutateRelease = $null,
        [string] $ExpectedProblem = "",
        [switch] $MissingInputs
    )

    $caseDir = Join-Path $validationRoot $Name
    New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
    $withdrawalPath = Join-Path $caseDir "withdrawal-intent.json"
    $releasePath = Join-Path $caseDir "release-evidence.json"
    $caseReportPath = Join-Path $caseDir "report.json"

    if (-not $MissingInputs.IsPresent) {
        $withdrawal = New-ValidationWithdrawalIntent
        $release = New-ValidationReleaseEvidence
        if ($null -ne $MutateWithdrawal) {
            & $MutateWithdrawal $withdrawal
        }
        if ($null -ne $MutateRelease) {
            & $MutateRelease $release
        }
        Write-FlowChainJson -Path $withdrawalPath -Value $withdrawal -Depth 12
        Write-FlowChainJson -Path $releasePath -Value $release -Depth 12
    }

    $child = Invoke-ReleaseValidationChild -Name $Name -WithdrawalPath $withdrawalPath -ReleasePath $releasePath -CaseReportPath $caseReportPath
    $caseReport = Read-ReleaseValidationJson -Path $caseReportPath
    $actualStatus = [string](Get-ReleaseValidationProp -Object $caseReport -Name "status" -Default "missing")
    $problems = @((Get-ReleaseValidationProp -Object $caseReport -Name "problems" -Default @()))
    $missing = @((Get-ReleaseValidationProp -Object $caseReport -Name "missingInputs" -Default @()))
    $failedChecks = @((Get-ReleaseValidationProp -Object $caseReport -Name "failedChecks" -Default @()))
    $secretFindings = @((Get-ReleaseValidationProp -Object $caseReport -Name "secretMarkerFindings" -Default @()))
    $broadcasts = (Get-ReleaseValidationProp -Object $caseReport -Name "broadcasts" -Default $true) -eq $true
    $envValuesPrinted = (Get-ReleaseValidationProp -Object $caseReport -Name "envValuesPrinted" -Default (Get-ReleaseValidationProp -Object $caseReport -Name "printsEnvValues" -Default $true)) -eq $true
    $exitMatches = if ($ExpectedExitZero) { $child.exitCode -eq 0 } else { $child.exitCode -ne 0 }
    $problemMatches = [string]::IsNullOrWhiteSpace($ExpectedProblem) -or ($ExpectedProblem -in $problems)
    $missingInputsMatch = (-not $MissingInputs.IsPresent) -or ("WithdrawalIntentPath" -in $missing -and "ReleaseEvidencePath" -in $missing)
    $passed = $actualStatus -eq $ExpectedStatus `
        -and $exitMatches `
        -and $problemMatches `
        -and $missingInputsMatch `
        -and $secretFindings.Count -eq 0 `
        -and -not $broadcasts `
        -and -not $envValuesPrinted

    [void]$cases.Add([ordered]@{
        name = $Name
        status = if ($passed) { "passed" } else { "failed" }
        expectedStatus = $ExpectedStatus
        actualStatus = $actualStatus
        exitCode = $child.exitCode
        expectedProblem = $ExpectedProblem
        problems = @($problems)
        missingInputs = @($missing)
        failedChecks = @($failedChecks)
        child = $child
    })
}

Add-ReleaseValidationCase -Name "matching-release-evidence" -ExpectedStatus "passed" -ExpectedExitZero $true
Add-ReleaseValidationCase -Name "missing-inputs-blocked" -ExpectedStatus "blocked" -ExpectedExitZero $false -MissingInputs
Add-ReleaseValidationCase -Name "amount-mismatch-failed" -ExpectedStatus "failed" -ExpectedExitZero $false -ExpectedProblem "amount mismatch" -MutateRelease {
    param($release)
    $release.releaseCall.amount = "20000001"
}
Add-ReleaseValidationCase -Name "method-mismatch-failed" -ExpectedStatus "failed" -ExpectedExitZero $false -ExpectedProblem "release method mismatch" -MutateRelease {
    param($release)
    $release.releaseCall.method = "releaseETH"
}
Add-ReleaseValidationCase -Name "token-mismatch-failed" -ExpectedStatus "failed" -ExpectedExitZero $false -ExpectedProblem "token mismatch" -MutateRelease {
    param($release)
    $release.releaseCall.token = "0x5555555555555555555555555555555555555555"
}
Add-ReleaseValidationCase -Name "recipient-mismatch-failed" -ExpectedStatus "failed" -ExpectedExitZero $false -ExpectedProblem "recipient mismatch" -MutateRelease {
    param($release)
    $release.releaseCall.recipient = "0x6666666666666666666666666666666666666666"
}
Add-ReleaseValidationCase -Name "chain-mismatch-failed" -ExpectedStatus "failed" -ExpectedExitZero $false -ExpectedProblem "sourceChainId mismatch" -MutateRelease {
    param($release)
    $release.sourceChainId = 84532
}
Add-ReleaseValidationCase -Name "asset-mismatch-failed" -ExpectedStatus "failed" -ExpectedExitZero $false -ExpectedProblem "asset destinationAssetId mismatch" -MutateRelease {
    param($release)
    $release.asset.destinationAssetId = "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
}
Add-ReleaseValidationCase -Name "release-broadcast-rejected" -ExpectedStatus "failed" -ExpectedExitZero $false -ExpectedProblem "release evidence must not be broadcast" -MutateRelease {
    param($release)
    $release.releaseCall.broadcast = $true
}
Add-ReleaseValidationCase -Name "withdrawal-broadcast-rejected" -ExpectedStatus "failed" -ExpectedExitZero $false -ExpectedProblem "withdrawal intent must not be broadcast" -MutateWithdrawal {
    param($withdrawal)
    $withdrawal.broadcast = $true
}
Add-ReleaseValidationCase -Name "release-production-ready-false-rejected" -ExpectedStatus "failed" -ExpectedExitZero $false -ExpectedProblem "release evidence must claim production readiness for Base 8453" -MutateRelease {
    param($release)
    $release.productionReady = $false
}
Add-ReleaseValidationCase -Name "release-local-only-true-rejected" -ExpectedStatus "failed" -ExpectedExitZero $false -ExpectedProblem "release evidence must not be localOnly for Base 8453" -MutateRelease {
    param($release)
    $release.localOnly = $true
}

$preScanReport = [ordered]@{
    schema = "flowchain.bridge_release_evidence_validation_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "pre-scan"
    caseCount = $cases.Count
    cases = @($cases)
    broadcasts = $false
    envValuesPrinted = $false
    noSecrets = $true
}
Write-FlowChainJson -Path $reportFullPath -Value $preScanReport -Depth 18

$scanReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-release-evidence-validation-no-secret-scan-report.json"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-no-secret-scan.ps1") -Paths @($validationRoot, $reportFullPath) -ReportPath $scanReportPath
$scanExitCode = $LASTEXITCODE
$scanReport = Read-ReleaseValidationJson -Path $scanReportPath
$scanStatus = [string](Get-ReleaseValidationProp -Object $scanReport -Name "status" -Default "missing")
$scanFindings = @((Get-ReleaseValidationProp -Object $scanReport -Name "findings" -Default @()))
$scanSecretFindings = @((Get-ReleaseValidationProp -Object $scanReport -Name "secretMarkerFindings" -Default @()))

$failedCases = @($cases | Where-Object { $_.status -ne "passed" })
$requiredCaseNames = @(
    "matching-release-evidence",
    "missing-inputs-blocked",
    "amount-mismatch-failed",
    "method-mismatch-failed",
    "token-mismatch-failed",
    "recipient-mismatch-failed",
    "chain-mismatch-failed",
    "asset-mismatch-failed",
    "release-broadcast-rejected",
    "withdrawal-broadcast-rejected",
    "release-production-ready-false-rejected",
    "release-local-only-true-rejected"
)
$caseNames = @($cases | ForEach-Object { $_.name })
$missingRequiredCases = @($requiredCaseNames | Where-Object { $_ -notin $caseNames })

$checks = [ordered]@{
    releaseEvidenceScriptExists = Test-Path -LiteralPath (Join-Path $PSScriptRoot "flowchain-bridge-release-evidence.ps1")
    matchingEvidencePasses = @($cases | Where-Object { $_.name -eq "matching-release-evidence" -and $_.status -eq "passed" }).Count -eq 1
    missingInputsBlock = @($cases | Where-Object { $_.name -eq "missing-inputs-blocked" -and $_.status -eq "passed" }).Count -eq 1
    amountMismatchFails = @($cases | Where-Object { $_.name -eq "amount-mismatch-failed" -and $_.status -eq "passed" }).Count -eq 1
    methodMismatchFails = @($cases | Where-Object { $_.name -eq "method-mismatch-failed" -and $_.status -eq "passed" }).Count -eq 1
    tokenMismatchFails = @($cases | Where-Object { $_.name -eq "token-mismatch-failed" -and $_.status -eq "passed" }).Count -eq 1
    recipientMismatchFails = @($cases | Where-Object { $_.name -eq "recipient-mismatch-failed" -and $_.status -eq "passed" }).Count -eq 1
    chainMismatchFails = @($cases | Where-Object { $_.name -eq "chain-mismatch-failed" -and $_.status -eq "passed" }).Count -eq 1
    assetMismatchFails = @($cases | Where-Object { $_.name -eq "asset-mismatch-failed" -and $_.status -eq "passed" }).Count -eq 1
    releaseBroadcastRejected = @($cases | Where-Object { $_.name -eq "release-broadcast-rejected" -and $_.status -eq "passed" }).Count -eq 1
    withdrawalBroadcastRejected = @($cases | Where-Object { $_.name -eq "withdrawal-broadcast-rejected" -and $_.status -eq "passed" }).Count -eq 1
    releaseProductionReadyFalseRejected = @($cases | Where-Object { $_.name -eq "release-production-ready-false-rejected" -and $_.status -eq "passed" }).Count -eq 1
    releaseLocalOnlyTrueRejected = @($cases | Where-Object { $_.name -eq "release-local-only-true-rejected" -and $_.status -eq "passed" }).Count -eq 1
    allRequiredCasesCovered = $missingRequiredCases.Count -eq 0
    failedCasesAbsent = $failedCases.Count -eq 0
    noSecretScanPassed = $scanExitCode -eq 0 -and $scanStatus -eq "passed" -and $scanFindings.Count -eq 0 -and $scanSecretFindings.Count -eq 0
    broadcastsFalse = $true
    envValuesPrintedFalse = $true
    noSecrets = $scanSecretFindings.Count -eq 0
    secretMarkerFindingsEmpty = $scanSecretFindings.Count -eq 0
}
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.bridge_release_evidence_validation_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    caseCount = $cases.Count
    cases = @($cases)
    failedCases = @($failedCases | ForEach-Object { $_.name })
    missingRequiredCases = @($missingRequiredCases)
    noSecretScanReportPath = $scanReportPath
    checks = $checks
    failedChecks = @($failedChecks)
    secretMarkerFindings = @($scanSecretFindings)
    broadcasts = $false
    envValuesPrinted = $false
    noSecrets = $scanSecretFindings.Count -eq 0
}
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Bridge Release Evidence Validation")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("## Cases")
$markdownLines.Add("")
$markdownLines.Add("| Case | Status | Expected | Actual | Exit |")
$markdownLines.Add("| --- | --- | --- | --- | --- |")
foreach ($case in $cases) {
    $markdownLines.Add("| $($case.name) | $($case.status) | $($case.expectedStatus) | $($case.actualStatus) | $($case.exitCode) |")
}
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
$markdownLines.Add("| Check | Result |")
$markdownLines.Add("| --- | --- |")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("| $($entry.Key) | $($entry.Value) |")
}
Set-Content -LiteralPath $markdownFullPath -Value $markdownLines -Encoding utf8

Write-Host "FlowChain bridge release evidence validation status: $status"
Write-Host "Cases: passed=$(@($cases | Where-Object { $_.status -eq "passed" }).Count), failed=$($failedCases.Count), total=$($cases.Count)"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"

if ($status -ne "passed") {
    throw "Bridge release evidence validation failed."
}
