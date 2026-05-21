param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/external-tester-client-validation-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/EXTERNAL_TESTER_CLIENT_VALIDATION.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$clientPath = Join-Path $repoRoot "examples/flowchain-external-tester-client.mjs"
$connectPackPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-connect-pack.json"
$dryRunReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-client-dry-run-report.json"

function Get-ClientValidationProp {
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

$clientOutput = & node $clientPath `
    --connect-pack $connectPackPath `
    --base-url "https://flowchain.example.invalid" `
    --dry-run `
    --allow-blocked `
    --output $dryRunReportPath 2>&1
$clientExitCode = $LASTEXITCODE
$clientOutputText = @($clientOutput | ForEach-Object { "$_" }) -join "`n"
$dryRunReport = Read-FlowChainJsonIfExists -Path $dryRunReportPath
$connectPack = Read-FlowChainJsonIfExists -Path $connectPackPath
$expectedReadRoutes = @("/health", "/rpc/discover", "/rpc/readiness", "/chain/status", "/tester/status")
$expectedWriteRoutes = @("/tester/wallets/create", "/tester/faucet", "/tester/wallets/send")

$secretMarkerFindings = New-Object System.Collections.ArrayList
foreach ($entry in @(
        [ordered]@{ label = "external tester client output"; text = $clientOutputText },
        [ordered]@{ label = "external tester client dry-run report"; text = if (Test-Path -LiteralPath $dryRunReportPath) { Get-Content -Raw -LiteralPath $dryRunReportPath } else { "" } }
    )) {
    try {
        Assert-FlowChainNoSecretText -Text ([string] $entry.text) -Label ([string] $entry.label)
    }
    catch {
        [void] $secretMarkerFindings.Add([ordered]@{ label = $entry.label; reason = $_.Exception.Message })
    }
}

$plannedRoutes = @((Get-ClientValidationProp -Object $dryRunReport -Name "plannedRoutes" -Default @()))
$checks = [ordered]@{
    clientScriptExists = Test-Path -LiteralPath $clientPath
    connectPackExists = Test-Path -LiteralPath $connectPackPath
    connectPackSchemaValid = (Get-ClientValidationProp -Object $connectPack -Name "schema" -Default "") -eq "flowchain.external_tester_connect_pack.v0"
    clientExitCodeZero = $clientExitCode -eq 0
    dryRunReportWritten = Test-Path -LiteralPath $dryRunReportPath
    dryRunSchemaValid = (Get-ClientValidationProp -Object $dryRunReport -Name "schema" -Default "") -eq "flowchain.external_tester_client_report.v0"
    dryRunStatusPlanned = (Get-ClientValidationProp -Object $dryRunReport -Name "status" -Default "") -eq "planned"
    dryRunNoNetwork = (Get-ClientValidationProp -Object $dryRunReport -Name "dryRun" -Default $false) -eq $true -and @((Get-ClientValidationProp -Object $dryRunReport -Name "networkResults" -Default @{}).PSObject.Properties).Count -eq 0
    blockedConnectPackAllowedOnlyByFlag = (Get-ClientValidationProp -Object $dryRunReport -Name "shareable" -Default $true) -eq $false
    plannedRoutesCoverReads = @($expectedReadRoutes | Where-Object { $plannedRoutes -contains $_ }).Count -eq $expectedReadRoutes.Count
    plannedRoutesCoverWrites = @($expectedWriteRoutes | Where-Object { $plannedRoutes -contains $_ }).Count -eq $expectedWriteRoutes.Count
    endpointRedacted = [string](Get-ClientValidationProp -Object $dryRunReport -Name "endpoint" -Default "") -eq "https://flowchain.example.invalid"
    tokenNotConfiguredInDryRun = (Get-ClientValidationProp -Object (Get-ClientValidationProp -Object $dryRunReport -Name "token") -Name "configured" -Default $true) -eq $false
    broadcastsFalse = (Get-ClientValidationProp -Object $dryRunReport -Name "broadcasts" -Default $true) -eq $false
    envValuesPrintedFalse = (Get-ClientValidationProp -Object $dryRunReport -Name "envValuesPrinted" -Default $true) -eq $false
    noSecrets = (Get-ClientValidationProp -Object $dryRunReport -Name "noSecrets" -Default $false) -eq $true
    secretMarkerFindingsEmpty = $secretMarkerFindings.Count -eq 0
}
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
$report = [ordered]@{
    schema = "flowchain.external_tester_client_validation_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    checks = $checks
    failedChecks = @($failedChecks)
    dryRunReportPath = $dryRunReportPath
    connectPackPath = $connectPackPath
    clientPath = $clientPath
    secretMarkerFindings = @($secretMarkerFindings)
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}
$reportText = $report | ConvertTo-Json -Depth 10
Assert-FlowChainNoSecretText -Text $reportText -Label "external tester client validation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 10

$markdownLines = @(
    "# FlowChain External Tester Client Validation",
    "",
    "Generated: $($report.generatedAt)",
    "Status: $status",
    "",
    "This proves the external tester client can consume the generated connect pack, produce a no-secret dry run, cover the expected read/write routes, and avoid network calls until a tester runs it with owner-provided endpoint/token values.",
    "",
    "## Artifacts",
    "",
    "- Client: examples/flowchain-external-tester-client.mjs",
    "- Dry-run report: docs/agent-runs/live-product-infra-rpc/external-tester-client-dry-run-report.json",
    "- Validation report: docs/agent-runs/live-product-infra-rpc/external-tester-client-validation-report.json"
)
$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "external tester client validation markdown"
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain external tester client validation status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($failedChecks.Count -gt 0) {
    throw "FlowChain external tester client validation failed checks: $($failedChecks -join ', ')"
}
