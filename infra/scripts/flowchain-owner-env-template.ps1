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

$ownerEnvSpecs = @(
    [ordered]@{
        name = "FLOWCHAIN_RPC_PUBLIC_URL"
        group = "public-rpc"
        required = $true
        purpose = "Public HTTPS URL testers and wallets use for FlowChain RPC."
        validation = "absolute non-local HTTPS endpoint"
        source = "owner DNS, tunnel, or reverse proxy hostname"
        doNotSend = "provider login password, tunnel token, or TLS private key"
    },
    [ordered]@{
        name = "FLOWCHAIN_RPC_ALLOWED_ORIGINS"
        group = "public-rpc"
        required = $true
        purpose = "Comma-separated HTTPS browser origins allowed to call the public RPC edge."
        validation = "one or more explicit HTTPS origins; wildcard is rejected"
        source = "dashboard/tester site origin list"
        doNotSend = "wildcard origin or private browser session data"
    },
    [ordered]@{
        name = "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE"
        group = "public-rpc"
        required = $true
        purpose = "Per-origin or per-client public RPC request limit."
        validation = "positive decimal integer"
        source = "owner public edge rate-limit policy"
        doNotSend = "provider account credentials"
    },
    [ordered]@{
        name = "FLOWCHAIN_RPC_TLS_TERMINATED"
        group = "public-rpc"
        required = $true
        purpose = "Acknowledgement that HTTPS termination is configured at the public edge."
        validation = "must equal true"
        source = "owner TLS edge configuration"
        doNotSend = "TLS private key or certificate account credentials"
    },
    [ordered]@{
        name = "FLOWCHAIN_RPC_STATE_BACKUP_PATH"
        group = "backup"
        required = $true
        purpose = "Existing writable directory for live state backup and restore proof."
        validation = "existing writable directory"
        source = "owner host durable disk or mounted backup volume"
        doNotSend = "cloud storage secret or host login password"
    },
    [ordered]@{
        name = "FLOWCHAIN_TESTER_WRITE_ENABLED"
        group = "tester-write"
        required = $true
        purpose = "Enables authenticated capped tester write routes."
        validation = "must equal true"
        source = "owner launch decision after public gates are ready"
        doNotSend = "raw tester token"
    },
    [ordered]@{
        name = "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256"
        group = "tester-write"
        required = $true
        purpose = "Digest of the out-of-band tester bearer token."
        validation = "64-character SHA-256 hex digest"
        source = "npm run flowchain:tester:token:setup"
        doNotSend = "raw tester token or token hash together with the raw token"
    },
    [ordered]@{
        name = "FLOWCHAIN_TESTER_MAX_SEND_UNITS"
        group = "tester-write"
        required = $true
        purpose = "Maximum units a tester can send per capped write request."
        validation = "positive decimal integer"
        source = "owner tester pilot cap"
        doNotSend = "uncapped launch policy"
    },
    [ordered]@{
        name = "FLOWCHAIN_PILOT_OPERATOR_ACK"
        group = "base8453-bridge"
        required = $true
        purpose = "Explicit acknowledgement for the capped Base 8453 bridge pilot."
        validation = "must equal I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
        source = "owner go-live decision"
        doNotSend = "wallet recovery words or private key"
    },
    [ordered]@{
        name = "FLOWCHAIN_BASE8453_RPC_URL"
        group = "base8453-bridge"
        required = $true
        purpose = "Base chain endpoint used by the bridge observer."
        validation = "absolute HTTP(S) endpoint"
        source = "Base RPC provider or owner-operated Base node"
        doNotSend = "provider URLs that embed account tokens"
    },
    [ordered]@{
        name = "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS"
        group = "base8453-bridge"
        required = $true
        purpose = "Deployed Base 8453 lockbox contract address."
        validation = "20-byte hex address"
        source = "bridge deployment artifact or verified owner contract"
        doNotSend = "deployer private key"
    },
    [ordered]@{
        name = "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN"
        group = "base8453-bridge"
        required = $true
        purpose = "Base 8453 token address accepted by the capped pilot."
        validation = "20-byte hex address"
        source = "owner-approved bridge token contract"
        doNotSend = "wallet private key"
    },
    [ordered]@{
        name = "FLOWCHAIN_BASE8453_ASSET_DECIMALS"
        group = "base8453-bridge"
        required = $true
        purpose = "Decimals for the supported Base 8453 asset."
        validation = "integer from 0 through 255"
        source = "token metadata or deployment checklist"
        doNotSend = "provider account credentials"
    },
    [ordered]@{
        name = "FLOWCHAIN_BASE8453_FROM_BLOCK"
        group = "base8453-bridge"
        required = $true
        purpose = "First Base 8453 block the bridge observer scans."
        validation = "non-negative decimal block number"
        source = "lockbox deployment block or chosen pilot start block"
        doNotSend = "provider account credentials"
    },
    [ordered]@{
        name = "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI"
        group = "base8453-bridge"
        required = $true
        purpose = "Maximum single deposit credited during the capped pilot."
        validation = "positive decimal integer"
        source = "owner pilot risk cap"
        doNotSend = "uncapped value"
    },
    [ordered]@{
        name = "FLOWCHAIN_PILOT_TOTAL_CAP_WEI"
        group = "base8453-bridge"
        required = $true
        purpose = "Total bridge credit cap for the capped pilot."
        validation = "positive decimal integer"
        source = "owner pilot risk cap"
        doNotSend = "uncapped value"
    },
    [ordered]@{
        name = "FLOWCHAIN_PILOT_CONFIRMATIONS"
        group = "base8453-bridge"
        required = $true
        purpose = "Base confirmations required before observer credit."
        validation = "positive decimal integer"
        source = "owner bridge finality policy"
        doNotSend = "provider account credentials"
    },
    [ordered]@{
        name = "FLOWCHAIN_BASE8453_CURSOR_STATE"
        group = "base8453-bridge"
        required = $false
        purpose = "Optional local cursor state path for Base scan progress."
        validation = "local path controlled by the owner host"
        source = "default relayer state path unless overridden"
        doNotSend = "cursor file contents if they include local paths you want private"
    },
    [ordered]@{
        name = "FLOWCHAIN_BASE8453_TO_BLOCK"
        group = "base8453-bridge"
        required = $false
        purpose = "Optional upper Base 8453 block for bounded observer scans."
        validation = "non-negative decimal block number"
        source = "owner bounded scan plan"
        doNotSend = "provider account credentials"
    }
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
    fieldGuideCoversAllRequiredEnvNames = @($requiredEnvNames | Where-Object { $_ -notin @($ownerEnvSpecs | Where-Object { $_.required -eq $true } | ForEach-Object { $_.name }) }).Count -eq 0
    fieldGuideCoversAllOptionalEnvNames = @($optionalEnvNames | Where-Object { $_ -notin @($ownerEnvSpecs | Where-Object { $_.required -ne $true } | ForEach-Object { $_.name }) }).Count -eq 0
    fieldGuideHasValidationForEveryName = @($ownerEnvSpecs | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.validation) }).Count -eq 0
    fieldGuideHasDoNotSendForEveryName = @($ownerEnvSpecs | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.doNotSend) }).Count -eq 0
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
    fieldGuide = @($ownerEnvSpecs)
    requiredEnvNameCount = $requiredEnvNames.Count
    fieldGuideCount = $ownerEnvSpecs.Count
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
$markdownLines.Add("")
$markdownLines.Add("## Field Guide")
$markdownLines.Add("")
$markdownLines.Add("Use this table while filling the ignored local file. It lists names and validation rules only; keep real values in the local file or service environment.")
$markdownLines.Add("")
$markdownLines.Add("| Name | Group | Required | Purpose | Validation | Where to get it | Do not send |")
$markdownLines.Add("| --- | --- | --- | --- | --- | --- | --- |")
foreach ($spec in $ownerEnvSpecs) {
    $requiredText = if ($spec.required -eq $true) { "yes" } else { "optional" }
    $markdownLines.Add("| ``$($spec.name)`` | $($spec.group) | $requiredText | $($spec.purpose) | $($spec.validation) | $($spec.source) | $($spec.doNotSend) |")
}

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
