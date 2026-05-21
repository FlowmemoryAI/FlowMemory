param(
    [string]$WithdrawalIntentPath = "services/bridge-relayer/out/base8453-pilot-withdrawal-intent.json",
    [string]$ReleaseEvidencePath = "services/bridge-relayer/out/base8453-pilot-release-evidence.json",
    [string]$ReportPath = "devnet/local/bridge-live-readiness/bridge-release-evidence-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$withdrawalFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $WithdrawalIntentPath)
$releaseFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReleaseEvidencePath)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)

function Get-BridgeReleaseProp {
    param(
        [AllowNull()][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [object]$Default = $null
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

function Read-BridgeReleaseJson {
    param([Parameter(Mandatory = $true)][string]$Path)

    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Add-BridgeReleaseCheck {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Checks,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$Problems,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Passed,
        [Parameter(Mandatory = $true)][string]$Problem
    )

    $Checks[$Name] = $Passed
    if (-not $Passed) {
        [void]$Problems.Add($Problem)
    }
}

function Get-BridgeReleaseSecretMarkerFindings {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $findings = New-Object System.Collections.ArrayList
    try {
        Assert-FlowChainNoSecretText -Text $Text -Label $Label
    }
    catch {
        [void]$findings.Add([ordered]@{
            label = $Label
            message = $_.Exception.Message
        })
    }
    return @($findings)
}

$missing = @()
if (-not (Test-Path -LiteralPath $withdrawalFullPath)) { $missing += "WithdrawalIntentPath" }
if (-not (Test-Path -LiteralPath $releaseFullPath)) { $missing += "ReleaseEvidencePath" }
if ($missing.Count -gt 0) {
    $report = [ordered]@{
        schema = "flowchain.bridge_release_evidence_report.v0"
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        status = "blocked"
        missingInputs = $missing
        nextCommand = "npm run flowchain:bridge:withdraw:intent"
        checks = [ordered]@{
            missingInputsRecorded = $missing.Count -gt 0
            blockedWithoutBroadcast = $true
            envValuesPrintedFalse = $true
            noSecrets = $true
            broadcastsFalse = $true
        }
        failedChecks = @()
        secretMarkerFindings = @()
        broadcasts = $false
        envValuesPrinted = $false
        printsEnvValues = $false
        noSecrets = $true
    }
    Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 12
    Write-Host "Bridge release evidence blocked by missing inputs: $($missing -join ', ')"
    Write-Host "Report: $reportFullPath"
    throw "Bridge release evidence blocked by missing inputs."
}

$withdrawalText = Get-Content -Raw -LiteralPath $withdrawalFullPath
$releaseText = Get-Content -Raw -LiteralPath $releaseFullPath
$withdrawal = Read-BridgeReleaseJson -Path $withdrawalFullPath
$release = Read-BridgeReleaseJson -Path $releaseFullPath

$checks = [ordered]@{}
$problems = New-Object System.Collections.ArrayList
$secretMarkerFindings = @(
    Get-BridgeReleaseSecretMarkerFindings -Text $withdrawalText -Label $WithdrawalIntentPath
    Get-BridgeReleaseSecretMarkerFindings -Text $releaseText -Label $ReleaseEvidencePath
)

$releaseCall = Get-BridgeReleaseProp -Object $release -Name "releaseCall"
$withdrawalAsset = Get-BridgeReleaseProp -Object $withdrawal -Name "asset"
$releaseAsset = Get-BridgeReleaseProp -Object $release -Name "asset"

Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "withdrawalJsonReadable" -Passed ($null -ne $withdrawal) -Problem "withdrawal intent JSON unreadable"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "releaseJsonReadable" -Passed ($null -ne $release) -Problem "release evidence JSON unreadable"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "withdrawalSchemaKnown" -Passed ((Get-BridgeReleaseProp -Object $withdrawal -Name "schema" -Default "") -eq "flowmemory.bridge_withdrawal_intent.v0") -Problem "withdrawal intent schema mismatch"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "releaseSchemaKnown" -Passed ((Get-BridgeReleaseProp -Object $release -Name "schema" -Default "") -eq "flowmemory.bridge_release_evidence.v0") -Problem "release evidence schema mismatch"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "withdrawalIntentIdMatches" -Passed ((Get-BridgeReleaseProp -Object $withdrawal -Name "withdrawalIntentId" -Default "") -eq (Get-BridgeReleaseProp -Object $release -Name "withdrawalIntentId" -Default "__missing_release_withdrawal_intent__")) -Problem "withdrawalIntentId mismatch"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "creditIdMatches" -Passed ((Get-BridgeReleaseProp -Object $withdrawal -Name "creditId" -Default "") -eq (Get-BridgeReleaseProp -Object $release -Name "creditId" -Default "__missing_release_credit__")) -Problem "creditId mismatch"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "depositIdMatches" -Passed ((Get-BridgeReleaseProp -Object $withdrawal -Name "depositId" -Default "") -eq (Get-BridgeReleaseProp -Object $release -Name "depositId" -Default "__missing_release_deposit__")) -Problem "depositId mismatch"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "sourceChainIdMatches" -Passed ([string](Get-BridgeReleaseProp -Object $withdrawal -Name "sourceChainId" -Default "") -eq [string](Get-BridgeReleaseProp -Object $release -Name "sourceChainId" -Default "__missing_release_source_chain__")) -Problem "sourceChainId mismatch"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "destinationChainIdMatches" -Passed ([string](Get-BridgeReleaseProp -Object $withdrawal -Name "destinationChainId" -Default "") -eq [string](Get-BridgeReleaseProp -Object $release -Name "destinationChainId" -Default "__missing_release_destination_chain__")) -Problem "destinationChainId mismatch"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "amountMatches" -Passed ((Get-BridgeReleaseProp -Object $withdrawal -Name "amount" -Default "") -eq (Get-BridgeReleaseProp -Object $releaseCall -Name "amount" -Default "__missing_release_amount__")) -Problem "amount mismatch"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "releaseCallMethodKnown" -Passed ((Get-BridgeReleaseProp -Object $releaseCall -Name "method" -Default "") -eq "releaseERC20") -Problem "release method mismatch"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "tokenMatches" -Passed ((Get-BridgeReleaseProp -Object $withdrawal -Name "token" -Default "") -eq (Get-BridgeReleaseProp -Object $releaseCall -Name "token" -Default "__missing_release_token__")) -Problem "token mismatch"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "recipientMatches" -Passed ((Get-BridgeReleaseProp -Object $withdrawal -Name "baseRecipient" -Default "") -eq (Get-BridgeReleaseProp -Object $releaseCall -Name "recipient" -Default "__missing_release_recipient__")) -Problem "recipient mismatch"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "assetSourceChainMatches" -Passed ([string](Get-BridgeReleaseProp -Object $withdrawalAsset -Name "sourceChainId" -Default "") -eq [string](Get-BridgeReleaseProp -Object $releaseAsset -Name "sourceChainId" -Default "__missing_release_asset_source_chain__")) -Problem "asset sourceChainId mismatch"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "assetSourceTokenMatches" -Passed ((Get-BridgeReleaseProp -Object $withdrawalAsset -Name "sourceToken" -Default "") -eq (Get-BridgeReleaseProp -Object $releaseAsset -Name "sourceToken" -Default "__missing_release_asset_source_token__")) -Problem "asset sourceToken mismatch"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "assetDestinationMatches" -Passed ((Get-BridgeReleaseProp -Object $withdrawalAsset -Name "destinationAssetId" -Default "") -eq (Get-BridgeReleaseProp -Object $releaseAsset -Name "destinationAssetId" -Default "__missing_release_asset_destination__")) -Problem "asset destinationAssetId mismatch"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "assetDecimalsMatch" -Passed ([string](Get-BridgeReleaseProp -Object $withdrawalAsset -Name "decimals" -Default "") -eq [string](Get-BridgeReleaseProp -Object $releaseAsset -Name "decimals" -Default "__missing_release_asset_decimals__")) -Problem "asset decimals mismatch"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "withdrawalBroadcastFalse" -Passed ((Get-BridgeReleaseProp -Object $withdrawal -Name "broadcast" -Default $true) -eq $false) -Problem "withdrawal intent must not be broadcast"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "releaseCallBroadcastFalse" -Passed ((Get-BridgeReleaseProp -Object $releaseCall -Name "broadcast" -Default $true) -eq $false) -Problem "release evidence must not be broadcast"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "withdrawalTestModeTrue" -Passed ((Get-BridgeReleaseProp -Object $withdrawal -Name "testMode" -Default $false) -eq $true) -Problem "withdrawal intent must remain testMode"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "withdrawalProductionReadyFalse" -Passed ((Get-BridgeReleaseProp -Object $withdrawal -Name "productionReady" -Default $true) -eq $false) -Problem "withdrawal intent must not claim production readiness"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "releaseProductionReadyTrue" -Passed ((Get-BridgeReleaseProp -Object $release -Name "productionReady" -Default $false) -eq $true) -Problem "release evidence must claim production readiness for Base 8453"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "releaseLocalOnlyFalse" -Passed ((Get-BridgeReleaseProp -Object $release -Name "localOnly" -Default $true) -eq $false) -Problem "release evidence must not be localOnly for Base 8453"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "releaseEvidenceIdPresent" -Passed (-not [string]::IsNullOrWhiteSpace([string](Get-BridgeReleaseProp -Object $release -Name "releaseEvidenceId" -Default ""))) -Problem "releaseEvidenceId missing"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "releaseEvidenceHashPresent" -Passed (-not [string]::IsNullOrWhiteSpace([string](Get-BridgeReleaseProp -Object $releaseCall -Name "evidenceHash" -Default ""))) -Problem "release evidenceHash missing"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "secretMarkerFindingsEmpty" -Passed ($secretMarkerFindings.Count -eq 0) -Problem "release evidence contains secret markers"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "envValuesPrintedFalse" -Passed $true -Problem "env values printed"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "noSecrets" -Passed ($secretMarkerFindings.Count -eq 0) -Problem "noSecrets false"
Add-BridgeReleaseCheck -Checks $checks -Problems $problems -Name "broadcastsFalse" -Passed (((Get-BridgeReleaseProp -Object $withdrawal -Name "broadcast" -Default $true) -eq $false) -and ((Get-BridgeReleaseProp -Object $releaseCall -Name "broadcast" -Default $true) -eq $false)) -Problem "broadcast field was true"

$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
$report = [ordered]@{
    schema = "flowchain.bridge_release_evidence_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    checkedFields = @("schema", "withdrawalIntentId", "creditId", "depositId", "sourceChainId", "destinationChainId", "amount", "method", "token", "recipient", "asset", "broadcast", "productionReady", "localOnly", "evidenceHash")
    checks = $checks
    failedChecks = @($failedChecks)
    problems = @($problems)
    secretMarkerFindings = @($secretMarkerFindings)
    broadcasts = $false
    envValuesPrinted = $false
    printsEnvValues = $false
    noSecrets = $secretMarkerFindings.Count -eq 0
}
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 12
Write-Host "Bridge release evidence status: $status"
Write-Host "Report: $reportFullPath"
if ($failedChecks.Count -gt 0) {
    throw "Bridge release evidence validation failed."
}
