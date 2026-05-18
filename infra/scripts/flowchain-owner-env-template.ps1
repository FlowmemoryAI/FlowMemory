param(
    [string] $TemplatePath = "devnet/local/owner-inputs/flowchain-owner.local.env",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/owner-env-template-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/OWNER_ENV_TEMPLATE.md",
    [switch] $Force
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$templateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $TemplatePath)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)

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
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_PILOT_CONFIRMATIONS"
)
$optionalEnvNames = @(
    "FLOWCHAIN_BASE8453_CURSOR_STATE",
    "FLOWCHAIN_BASE8453_TO_BLOCK"
)

function Get-RelativeFlowChainPath {
    param(
        [Parameter(Mandatory = $true)][string] $BasePath,
        [Parameter(Mandatory = $true)][string] $ChildPath
    )

    $base = [System.IO.Path]::GetFullPath($BasePath).TrimEnd("\", "/")
    $child = [System.IO.Path]::GetFullPath($ChildPath)
    if (-not $child.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside repo."
    }
    return $child.Substring($base.Length).TrimStart("\", "/") -replace '\\', '/'
}

function Get-OwnerEnvTemplateSecretMarkerFindings {
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

$templateRelativePath = Get-RelativeFlowChainPath -BasePath $repoRoot -ChildPath $templateFullPath
$gitCheckOutput = & git -C $repoRoot check-ignore --quiet -- $templateRelativePath 2>&1
$gitCheckExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
$pathIsGitIgnored = $gitCheckExitCode -eq 0

$templateLines = New-Object System.Collections.Generic.List[string]
$templateLines.Add("# FlowChain owner input file.")
$templateLines.Add("# Keep this local file ignored. Fill values only on the machine that runs FlowChain.")
$templateLines.Add("# Point FLOWCHAIN_OWNER_ENV_FILE at this file, then run the owner/live readiness gates.")
$templateLines.Add("")
foreach ($name in $requiredEnvNames) {
    $templateLines.Add("$name=")
}
$templateLines.Add("")
$templateLines.Add("# Optional bridge scan controls.")
foreach ($name in $optionalEnvNames) {
    $templateLines.Add("$name=")
}

$templateText = $templateLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $templateText -Label "owner env template file"

$created = $false
$preservedExisting = $false
$writeSkippedReason = ""
if (-not $pathIsGitIgnored) {
    $writeSkippedReason = "target path is not git-ignored"
}
elseif ((Test-Path -LiteralPath $templateFullPath) -and -not $Force.IsPresent) {
    $preservedExisting = $true
    $writeSkippedReason = "existing local file preserved"
}
else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $templateFullPath) | Out-Null
    Set-Content -LiteralPath $templateFullPath -Value $templateText -Encoding UTF8
    $created = $true
}

$checks = [ordered]@{
    pathIsGitIgnored = $pathIsGitIgnored
    createdOrPreservedLocalFile = $created -or $preservedExisting
    templateIncludesAllRequiredEnvNames = $true
    requiredEnvNameCountExpected = $requiredEnvNames.Count -eq 17
    optionalEnvNameCountExpected = $optionalEnvNames.Count -eq 2
    valuesPrintedFalse = $true
    envValuesPrintedFalse = $true
    noSecrets = $true
    broadcastsFalse = $true
    secretMarkerFindingsEmpty = $true
}

$report = [ordered]@{
    schema = "flowchain.owner_env_template_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "pending"
    checks = $checks
    failedChecks = @()
    secretMarkerFindings = @()
    templatePath = $templateFullPath
    templateRelativePath = $templateRelativePath
    pathIsGitIgnored = $pathIsGitIgnored
    gitCheckExitCode = $gitCheckExitCode
    gitCheckOutputRedacted = @($gitCheckOutput | ForEach-Object { "$_" })
    createdOrOverwrittenEmptyTemplate = $created
    preservedExistingLocalFile = $preservedExisting
    writeSkippedReason = $writeSkippedReason
    requiredEnvNames = $requiredEnvNames
    optionalEnvNames = $optionalEnvNames
    requiredEnvNameCount = $requiredEnvNames.Count
    templateIncludesAllRequiredEnvNames = $true
    flowChainOwnerEnvFileCommand = "`$env:FLOWCHAIN_OWNER_ENV_FILE=`"$templateFullPath`""
    valuesPrinted = $false
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$preliminaryReportText = $report | ConvertTo-Json -Depth 12
$secretMarkerFindings = @(Get-OwnerEnvTemplateSecretMarkerFindings -Text $preliminaryReportText -Label "owner env template report")
$checks["secretMarkerFindingsEmpty"] = $secretMarkerFindings.Count -eq 0
$checks["noSecrets"] = $secretMarkerFindings.Count -eq 0
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
$report["status"] = $status
$report["checks"] = $checks
$report["failedChecks"] = @($failedChecks)
$report["secretMarkerFindings"] = @($secretMarkerFindings)
$report["noSecrets"] = $secretMarkerFindings.Count -eq 0

$reportText = $report | ConvertTo-Json -Depth 12
Assert-FlowChainNoSecretText -Text $reportText -Label "owner env template report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 12

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Owner Env Template")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This command creates or preserves a local ignored owner env file. It writes only empty assignments and never records owner-provided values.")
$markdownLines.Add("")
$markdownLines.Add("Template path: ``$templateRelativePath``")
$markdownLines.Add("Git ignored: $pathIsGitIgnored")
$markdownLines.Add("")
$markdownLines.Add("Use this in the local shell after you fill the local file:")
$markdownLines.Add("")
$markdownLines.Add('```powershell')
$markdownLines.Add($report.flowChainOwnerEnvFileCommand)
$markdownLines.Add("npm run flowchain:owner-inputs")
$markdownLines.Add("npm run flowchain:live-infra:check")
$markdownLines.Add("npm run flowchain:owner-env:readiness:validate")
$markdownLines.Add("npm run flowchain:owner-env:readiness -- -AllowBlocked")
$markdownLines.Add('```')
$markdownLines.Add("")
$markdownLines.Add("## Empty File Shape")
$markdownLines.Add("")
$markdownLines.Add('```env')
foreach ($line in $templateLines) {
    $markdownLines.Add($line)
}
$markdownLines.Add('```')

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "owner env template markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain owner env template status: $status"
Write-Host "Template path: $templateFullPath"
Write-Host "Git ignored: $pathIsGitIgnored"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    exit 1
}
exit 0
