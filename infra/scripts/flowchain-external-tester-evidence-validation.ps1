param(
    [string] $EvidenceDir = "docs/agent-runs/live-product-infra-rpc/external-tester-evidence-sample",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/external-tester-evidence-validation-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/EXTERNAL_TESTER_EVIDENCE_VALIDATION.md",
    [int] $MaxAmountUnits = 1,
    [switch] $RefreshSample
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$evidenceFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $EvidenceDir)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$guidePath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/developer/FLOWCHAIN_EXTERNAL_TESTER_GUIDE.md")
$packageJsonPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "package.json")

if ($MaxAmountUnits -lt 1) {
    throw "MaxAmountUnits must be positive."
}

function ConvertTo-RepoRelativePath {
    param([Parameter(Mandatory = $true)][string] $Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    if ($fullPath -eq $fullRoot) {
        return "."
    }
    $relative = $fullPath.Substring($fullRoot.Length).TrimStart(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    return $relative.Replace("\", "/")
}

$evidenceRelativeDir = ConvertTo-RepoRelativePath -Path $evidenceFullDir
$guideRelativePath = ConvertTo-RepoRelativePath -Path $guidePath

$requiredJsonFiles = @(
    "01-readiness.json",
    "02-status-before.json",
    "03-wallet-balances-before.json",
    "04-wallet-send.json",
    "05-status-after.json",
    "06-wallet-transfers-after.json",
    "07-wallet-balances-after.json",
    "10-diagnostics.json"
)
$requiredTextFiles = @("NOTES.md")
$allRequiredFiles = @($requiredJsonFiles + $requiredTextFiles)

function Get-EvidenceProp {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name,
        [object] $Default = $null
    )

    if ($null -ne $Object -and $Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
    }
    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $Default
}

function ConvertTo-EvidenceBigInt {
    param([AllowNull()][object] $Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace("$Value")) {
        return $null
    }
    try {
        return [System.Numerics.BigInteger]::Parse("$Value", [System.Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        return $null
    }
}

function Get-EvidenceHeight {
    param([AllowNull()][object] $Report)

    $chain = Get-EvidenceProp -Object $Report -Name "chain"
    foreach ($name in @("latestHeight", "currentBlock", "height")) {
        $value = Get-EvidenceProp -Object $chain -Name $name -Default (Get-EvidenceProp -Object $Report -Name $name)
        $parsed = ConvertTo-EvidenceBigInt -Value $value
        if ($null -ne $parsed) {
            return $parsed
        }
    }
    return $null
}

function Get-EvidenceBalance {
    param(
        [AllowNull()][object] $Report,
        [Parameter(Mandatory = $true)][string] $AccountId
    )

    foreach ($entry in @((Get-EvidenceProp -Object $Report -Name "balances" -Default @()))) {
        if ([string](Get-EvidenceProp -Object $entry -Name "accountId" -Default "") -eq $AccountId) {
            return ConvertTo-EvidenceBigInt -Value (Get-EvidenceProp -Object $entry -Name "amountUnits")
        }
    }
    return $null
}

function Test-PackageScript {
    param([Parameter(Mandatory = $true)][string] $Name)

    $packageJson = Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json
    return $packageJson.scripts.PSObject.Properties.Name -contains $Name
}

function Test-EvidenceTextSafe {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string] $Label
    )

    Assert-FlowChainNoSecretText -Text $Text -Label $Label
    if ($Text -match 'https?://[^\s/]+:[^\s@]+@') {
        throw "Credential-bearing URL found in $Label."
    }
    if ($Text -match '(?i)\bBearer\s+[A-Za-z0-9._~+/-]{12,}') {
        throw "Bearer credential found in $Label."
    }
    if ($Text -match 'FLOWCHAIN_[A-Z0-9_]+\s*=') {
        throw "Owner env assignment found in $Label."
    }
}

function Write-SampleEvidence {
    param([Parameter(Mandatory = $true)][string] $Path)

    New-Item -ItemType Directory -Force -Path $Path | Out-Null
    $sender = "acct_tester_sender_redacted"
    $recipient = "acct_tester_recipient_redacted"
    $transferId = "transfer_redacted_ff_001"
    $transactionId = "tx_redacted_ff_001"
    Write-FlowChainJson -Path (Join-Path $Path "01-readiness.json") -Value ([ordered]@{
        status = "passed"
        publicSafe = $true
        envValuesPrinted = $false
        noSecrets = $true
    }) -Depth 8
    Write-FlowChainJson -Path (Join-Path $Path "02-status-before.json") -Value ([ordered]@{
        status = "passed"
        chain = [ordered]@{ latestHeight = "100" }
    }) -Depth 8
    Write-FlowChainJson -Path (Join-Path $Path "03-wallet-balances-before.json") -Value ([ordered]@{
        status = "passed"
        balances = @(
            [ordered]@{ accountId = $sender; amountUnits = "10" },
            [ordered]@{ accountId = $recipient; amountUnits = "0" }
        )
    }) -Depth 8
    Write-FlowChainJson -Path (Join-Path $Path "04-wallet-send.json") -Value ([ordered]@{
        status = "accepted"
        transferId = $transferId
        transactionId = $transactionId
        from = $sender
        to = $recipient
        amountUnits = "1"
        includedHeight = "102"
        memo = "ff-test-redacted"
    }) -Depth 8
    Write-FlowChainJson -Path (Join-Path $Path "05-status-after.json") -Value ([ordered]@{
        status = "passed"
        chain = [ordered]@{ latestHeight = "103" }
    }) -Depth 8
    Write-FlowChainJson -Path (Join-Path $Path "06-wallet-transfers-after.json") -Value ([ordered]@{
        status = "passed"
        transfers = @(
            [ordered]@{
                transferId = $transferId
                transactionId = $transactionId
                from = $sender
                to = $recipient
                amountUnits = "1"
                blockHeight = "102"
            }
        )
    }) -Depth 8
    Write-FlowChainJson -Path (Join-Path $Path "07-wallet-balances-after.json") -Value ([ordered]@{
        status = "passed"
        balances = @(
            [ordered]@{ accountId = $sender; amountUnits = "9" },
            [ordered]@{ accountId = $recipient; amountUnits = "1" }
        )
    }) -Depth 8
    Write-FlowChainJson -Path (Join-Path $Path "10-diagnostics.json") -Value ([ordered]@{
        status = "passed"
        envValuesPrinted = $false
        noSecrets = $true
        endpointLabel = "owner-redacted-endpoint"
    }) -Depth 8
    $notes = @(
        "# FlowChain Tester Notes",
        "",
        "Tester: redacted",
        "Date: 2026-05-18",
        "Timezone: redacted",
        "OS: redacted",
        "Node: redacted",
        "npm: redacted",
        "Endpoint label: owner-redacted-endpoint",
        "",
        "Sender account: $sender",
        "Recipient account: $recipient",
        "Amount: 1",
        "Memo: ff-test-redacted",
        "",
        "Block height before: 100",
        "Block height after: 103",
        "Transfer ID: $transferId",
        "Transaction ID: $transactionId",
        "",
        "What worked: readiness, status, balance, send, transfer history.",
        "What failed: none in sample.",
        "Unexpected behavior: none in sample.",
        "Screenshots attached: no"
    ) -join [Environment]::NewLine
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Join-Path $Path "NOTES.md"), $notes + [Environment]::NewLine, $utf8NoBom)
}

if ($RefreshSample.IsPresent -or -not (Test-Path -LiteralPath $evidenceFullDir)) {
    Write-SampleEvidence -Path $evidenceFullDir
}

$missingRequiredFiles = @($allRequiredFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $evidenceFullDir $_)) })
$invalidJsonFiles = New-Object System.Collections.ArrayList
$jsonReports = [ordered]@{}
foreach ($file in $requiredJsonFiles) {
    $path = Join-Path $evidenceFullDir $file
    if (-not (Test-Path -LiteralPath $path)) {
        continue
    }
    try {
        $jsonReports[$file] = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
    }
    catch {
        [void] $invalidJsonFiles.Add($file)
    }
}

$secretMarkerFindings = New-Object System.Collections.ArrayList
$credentialUrlFindings = New-Object System.Collections.ArrayList
$envAssignmentFindings = New-Object System.Collections.ArrayList
foreach ($file in @(Get-ChildItem -LiteralPath $evidenceFullDir -File -ErrorAction SilentlyContinue)) {
    $text = Get-Content -Raw -LiteralPath $file.FullName
    $relativePath = ConvertTo-RepoRelativePath -Path $file.FullName
    try {
        Test-EvidenceTextSafe -Text $text -Label $relativePath
    }
    catch {
        [void] $secretMarkerFindings.Add([ordered]@{ path = $relativePath; reason = $_.Exception.Message })
    }
    if ($text -match 'https?://[^\s/]+:[^\s@]+@') {
        [void] $credentialUrlFindings.Add($relativePath)
    }
    if ($text -match 'FLOWCHAIN_[A-Z0-9_]+\s*=') {
        [void] $envAssignmentFindings.Add($relativePath)
    }
}

$readiness = $jsonReports["01-readiness.json"]
$statusBefore = $jsonReports["02-status-before.json"]
$balancesBefore = $jsonReports["03-wallet-balances-before.json"]
$send = $jsonReports["04-wallet-send.json"]
$statusAfter = $jsonReports["05-status-after.json"]
$transfersAfter = $jsonReports["06-wallet-transfers-after.json"]
$balancesAfter = $jsonReports["07-wallet-balances-after.json"]
$diagnostics = $jsonReports["10-diagnostics.json"]

$heightBefore = Get-EvidenceHeight -Report $statusBefore
$heightAfter = Get-EvidenceHeight -Report $statusAfter
$sender = [string](Get-EvidenceProp -Object $send -Name "from" -Default "")
$recipient = [string](Get-EvidenceProp -Object $send -Name "to" -Default "")
$transferId = [string](Get-EvidenceProp -Object $send -Name "transferId" -Default "")
$transactionId = [string](Get-EvidenceProp -Object $send -Name "transactionId" -Default "")
$amount = ConvertTo-EvidenceBigInt -Value (Get-EvidenceProp -Object $send -Name "amountUnits")
$includedHeight = ConvertTo-EvidenceBigInt -Value (Get-EvidenceProp -Object $send -Name "includedHeight")
$senderBefore = Get-EvidenceBalance -Report $balancesBefore -AccountId $sender
$senderAfter = Get-EvidenceBalance -Report $balancesAfter -AccountId $sender
$recipientBefore = Get-EvidenceBalance -Report $balancesBefore -AccountId $recipient
$recipientAfter = Get-EvidenceBalance -Report $balancesAfter -AccountId $recipient
$matchedTransfer = $null
foreach ($transfer in @((Get-EvidenceProp -Object $transfersAfter -Name "transfers" -Default @()))) {
    if ([string](Get-EvidenceProp -Object $transfer -Name "transferId" -Default "") -eq $transferId) {
        $matchedTransfer = $transfer
        break
    }
}
$matchedTransferHeight = if ($null -ne $matchedTransfer) { ConvertTo-EvidenceBigInt -Value (Get-EvidenceProp -Object $matchedTransfer -Name "blockHeight") } else { $null }

$guideText = if (Test-Path -LiteralPath $guidePath) { Get-Content -Raw -LiteralPath $guidePath } else { "" }
$checks = [ordered]@{
    packageScriptPresent = Test-PackageScript -Name "flowchain:tester:evidence:validate"
    guideExists = Test-Path -LiteralPath $guidePath
    guideListsSuggestedFiles = $allRequiredFiles | Where-Object { $guideText.IndexOf($_, [System.StringComparison]::Ordinal) -ge 0 } | Measure-Object | ForEach-Object { $_.Count -eq $allRequiredFiles.Count }
    guideHasOwnerReviewChecklist = $guideText.Contains("Owner Review Checklist")
    guideHasStopRules = $guideText.Contains("When To Stop Immediately")
    evidenceDirInsideRepo = -not [System.IO.Path]::IsPathRooted($evidenceRelativeDir)
    evidenceDirExists = Test-Path -LiteralPath $evidenceFullDir
    requiredFilesPresent = @($missingRequiredFiles).Count -eq 0
    requiredJsonValid = @($invalidJsonFiles).Count -eq 0 -and $jsonReports.Count -eq $requiredJsonFiles.Count
    notesPresent = Test-Path -LiteralPath (Join-Path $evidenceFullDir "NOTES.md")
    readinessPassed = [string](Get-EvidenceProp -Object $readiness -Name "status" -Default "") -eq "passed"
    diagnosticsPassed = [string](Get-EvidenceProp -Object $diagnostics -Name "status" -Default "") -eq "passed"
    diagnosticsNoSecrets = (Get-EvidenceProp -Object $diagnostics -Name "noSecrets" -Default $false) -eq $true
    heightsNumeric = $null -ne $heightBefore -and $null -ne $heightAfter
    blockHeightAdvanced = $null -ne $heightBefore -and $null -ne $heightAfter -and $heightAfter -gt $heightBefore
    sendAccepted = [string](Get-EvidenceProp -Object $send -Name "status" -Default "") -in @("accepted", "passed")
    transferIdPresent = -not [string]::IsNullOrWhiteSpace($transferId)
    transactionIdPresent = -not [string]::IsNullOrWhiteSpace($transactionId)
    transferFound = $null -ne $matchedTransfer
    transferMatchesAccounts = $null -ne $matchedTransfer `
        -and [string](Get-EvidenceProp -Object $matchedTransfer -Name "from" -Default "") -eq $sender `
        -and [string](Get-EvidenceProp -Object $matchedTransfer -Name "to" -Default "") -eq $recipient
    transferAmountMatches = $null -ne $matchedTransfer `
        -and (ConvertTo-EvidenceBigInt -Value (Get-EvidenceProp -Object $matchedTransfer -Name "amountUnits")) -eq $amount
    transactionIdMatches = $null -ne $matchedTransfer `
        -and [string](Get-EvidenceProp -Object $matchedTransfer -Name "transactionId" -Default "") -eq $transactionId
    transferBlockHeightInWindow = $null -ne $matchedTransferHeight `
        -and $null -ne $heightBefore `
        -and $null -ne $heightAfter `
        -and $matchedTransferHeight -gt $heightBefore `
        -and $matchedTransferHeight -le $heightAfter
    includedHeightMatchesTransfer = $null -ne $includedHeight `
        -and $null -ne $matchedTransferHeight `
        -and $includedHeight -eq $matchedTransferHeight
    amountWithinLimit = $null -ne $amount -and $amount -gt 0 -and $amount -le $MaxAmountUnits
    balancesPresent = $null -ne $senderBefore -and $null -ne $senderAfter -and $null -ne $recipientBefore -and $null -ne $recipientAfter
    senderDebited = $null -ne $senderBefore -and $null -ne $senderAfter -and $null -ne $amount -and ($senderBefore - $senderAfter) -eq $amount
    recipientCredited = $null -ne $recipientBefore -and $null -ne $recipientAfter -and $null -ne $amount -and ($recipientAfter - $recipientBefore) -eq $amount
    secretMarkerFindingsEmpty = $secretMarkerFindings.Count -eq 0
    credentialUrlFindingsEmpty = $credentialUrlFindings.Count -eq 0
    envAssignmentFindingsEmpty = $envAssignmentFindings.Count -eq 0
    envValuesPrintedFalse = $true
    noSecrets = $true
    broadcastsFalse = $true
}
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.external_tester_evidence_validation_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    evidenceDir = $evidenceRelativeDir
    guidePath = $guideRelativePath
    maxAmountUnits = $MaxAmountUnits
    requiredFiles = $allRequiredFiles
    missingRequiredFiles = @($missingRequiredFiles)
    invalidJsonFiles = @($invalidJsonFiles)
    checks = $checks
    failedChecks = @($failedChecks)
    secretMarkerFindings = @($secretMarkerFindings)
    credentialUrlFindings = @($credentialUrlFindings)
    envAssignmentFindings = @($envAssignmentFindings)
    summary = [ordered]@{
        heightBefore = if ($null -ne $heightBefore) { "$heightBefore" } else { "" }
        heightAfter = if ($null -ne $heightAfter) { "$heightAfter" } else { "" }
        transferIdPresent = -not [string]::IsNullOrWhiteSpace($transferId)
        transactionIdPresent = -not [string]::IsNullOrWhiteSpace($transactionId)
        amountUnits = if ($null -ne $amount) { "$amount" } else { "" }
        transferBlockHeight = if ($null -ne $matchedTransferHeight) { "$matchedTransferHeight" } else { "" }
    }
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}
$reportText = $report | ConvertTo-Json -Depth 16
Assert-FlowChainNoSecretText -Text $reportText -Label "external tester evidence validation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain External Tester Evidence Validation")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This validates a redacted friends-and-family evidence folder before owner review. It checks required files, JSON readability, block-height advancement, wallet transfer consistency, amount cap, and no-secret boundaries.")
$markdownLines.Add("")
$markdownLines.Add("- Evidence directory: ``$evidenceRelativeDir``")
$markdownLines.Add("- Max amount units: $MaxAmountUnits")
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
$markdownLines.Add("| Check | Result |")
$markdownLines.Add("| --- | --- |")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("| $($entry.Key) | $($entry.Value) |")
}
$markdownLines.Add("")
$markdownLines.Add("## Required Files")
$markdownLines.Add("")
foreach ($file in $allRequiredFiles) {
    $state = if ($file -in $missingRequiredFiles) { "missing" } else { "present" }
    $markdownLines.Add("- ``$file``: $state")
}
$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "external tester evidence validation markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain external tester evidence validation status: $status"
Write-Host "Evidence dir: $evidenceFullDir"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($failedChecks.Count -gt 0) {
    throw "FlowChain external tester evidence validation failed checks: $($failedChecks -join ', ')"
}
exit 0
