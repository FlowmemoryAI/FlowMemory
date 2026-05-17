param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/owner-signup-checklist-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/OWNER_SIGNUP_CHECKLIST.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$ownerInputsPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json"

function Get-SignupProp {
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

$ownerInputs = Read-FlowChainJsonIfExists -Path $ownerInputsPath
$missingEnvNames = @((Get-SignupProp -Object $ownerInputs -Name "missingEnvNames" -Default @()))
$invalidEnvNames = @((Get-SignupProp -Object $ownerInputs -Name "invalidEnvNames" -Default @()))
$ownerInputsStatus = [string](Get-SignupProp -Object $ownerInputs -Name "status" -Default "missing")

$checklistItems = @(
    [ordered]@{
        id = "public-rpc-hostname"
        title = "Public RPC domain or subdomain"
        externalSignupNeeded = $true
        acceptableOptions = @("Cloudflare-managed domain/subdomain", "Existing registrar plus DNS provider", "Owner-operated reverse proxy with valid TLS")
        producesEnvNames = @("FLOWCHAIN_RPC_PUBLIC_URL")
        ownerMustGet = "A public HTTPS URL for this FlowChain RPC edge, for example an rpc subdomain."
        ownerMustNotSend = @("Registrar password", "Cloudflare account password", "raw TLS private key")
        validationCommand = "npm run flowchain:public-rpc:check"
    },
    [ordered]@{
        id = "public-rpc-tunnel-or-proxy"
        title = "HTTPS tunnel or reverse proxy to the private RPC origin"
        externalSignupNeeded = $true
        acceptableOptions = @("Cloudflare Tunnel public hostname", "Nginx/Caddy/Traefik on an owner host", "Load balancer that proxies to the private origin")
        producesEnvNames = @("FLOWCHAIN_RPC_TLS_TERMINATED")
        ownerMustGet = "A TLS-terminating edge that routes public traffic to http://127.0.0.1:8787 on the host running FlowChain."
        ownerMustNotSend = @("Tunnel token", "TLS certificate private key", "admin dashboard session cookie")
        validationCommand = "npm run flowchain:public-rpc:check"
    },
    [ordered]@{
        id = "public-rpc-cors-and-rate-limit"
        title = "Allowed origins and public rate limit"
        externalSignupNeeded = $false
        acceptableOptions = @("Exact HTTPS app/tester origin list", "Small pilot rate limit such as requests per minute per IP")
        producesEnvNames = @("FLOWCHAIN_RPC_ALLOWED_ORIGINS", "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE")
        ownerMustGet = "The exact HTTPS app origins allowed to call the public RPC and a positive per-minute request limit."
        ownerMustNotSend = @("Wildcard CORS policy", "unbounded public rate limit")
        validationCommand = "npm run flowchain:public-rpc:check"
    },
    [ordered]@{
        id = "always-on-host"
        title = "Always-on host for the chain service"
        externalSignupNeeded = $false
        acceptableOptions = @("This machine if it stays online", "Small VPS or cloud VM", "Dedicated owner server")
        producesEnvNames = @()
        ownerMustGet = "A host that can keep the node/control-plane running continuously and expose only the public edge, not raw private services."
        ownerMustNotSend = @("SSH private key", "root password")
        validationCommand = "npm run flowchain:service:status"
    },
    [ordered]@{
        id = "state-backup-storage"
        title = "Writable backup storage"
        externalSignupNeeded = $false
        acceptableOptions = @("Mounted disk/volume", "Owner-managed backup directory", "Persistent path on the always-on host")
        producesEnvNames = @("FLOWCHAIN_RPC_STATE_BACKUP_PATH")
        ownerMustGet = "An existing writable directory path that the FlowChain service process can use for manifest-backed snapshots and restore rehearsals."
        ownerMustNotSend = @("Cloud backup access key", "storage account secret")
        validationCommand = "npm run flowchain:backup:restore:validate; npm run flowchain:backup:check"
    },
    [ordered]@{
        id = "external-tester-write-gateway"
        title = "External tester write token and send cap"
        externalSignupNeeded = $false
        acceptableOptions = @("Owner-generated random bearer token stored out of band", "SHA-256 digest in ignored owner env file", "Small per-send local test-unit cap")
        producesEnvNames = @(
            "FLOWCHAIN_TESTER_WRITE_ENABLED",
            "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256",
            "FLOWCHAIN_TESTER_MAX_SEND_UNITS"
        )
        ownerMustGet = "A random tester bearer token for friends-and-family wallet writes, its SHA-256 hex digest for the owner env file, and a positive per-send local test-unit cap."
        ownerMustNotSend = @("Raw tester bearer token in chat or GitHub", "owner env file contents", "token hash and raw token together")
        validationCommand = "npm run flowchain:owner-inputs; npm run flowchain:external-tester:packet -- -AllowBlocked"
    },
    [ordered]@{
        id = "base8453-rpc"
        title = "Base mainnet RPC endpoint"
        externalSignupNeeded = $true
        acceptableOptions = @("Alchemy Base mainnet endpoint", "QuickNode Base endpoint", "Infura Base endpoint", "Owner-operated Base node")
        producesEnvNames = @("FLOWCHAIN_BASE8453_RPC_URL")
        ownerMustGet = "A Base chain 8453 HTTPS JSON-RPC endpoint for read-only bridge observation."
        ownerMustNotSend = @("Provider dashboard password", "API key pasted into chat", "billing credential")
        validationCommand = "npm run flowchain:bridge:live:check"
    },
    [ordered]@{
        id = "base8453-bridge-details"
        title = "Base bridge pilot contract and caps"
        externalSignupNeeded = $false
        acceptableOptions = @("Owner-provided deployed lockbox and token addresses", "Bootstrap Base from-block plus cursor-state scanning", "Optional bounded upper block for one-off scans", "Pilot caps and confirmations")
        producesEnvNames = @(
            "FLOWCHAIN_PILOT_OPERATOR_ACK",
            "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
            "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
            "FLOWCHAIN_BASE8453_ASSET_DECIMALS",
            "FLOWCHAIN_BASE8453_FROM_BLOCK",
            "FLOWCHAIN_BASE8453_CURSOR_STATE",
            "FLOWCHAIN_BASE8453_TO_BLOCK",
            "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
            "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
            "FLOWCHAIN_PILOT_CONFIRMATIONS"
        )
        ownerMustGet = "The bridge pilot lockbox/token details, bootstrap Base from-block, cursor-state location, optional one-off upper block, max deposit, total cap, confirmations, and explicit capped-pilot acknowledgement."
        ownerMustNotSend = @("Private key for deploying or controlling contracts", "wallet recovery words", "wallet recovery material")
        validationCommand = "npm run flowchain:bridge:live:check"
    },
    [ordered]@{
        id = "local-owner-env-file"
        title = "Local owner env file"
        externalSignupNeeded = $false
        acceptableOptions = @("Ignored local NAME=value file referenced by FLOWCHAIN_OWNER_ENV_FILE", "Process/service environment variables")
        producesEnvNames = @("FLOWCHAIN_OWNER_ENV_FILE")
        ownerMustGet = "A local-only file path for real values, kept outside committed reports and loaded by the parser-only env-file importer. Run npm run flowchain:owner-env:template to create the ignored local scaffold, npm run flowchain:owner-env:readiness:validate to test path safety, then npm run flowchain:owner-env:readiness -- -AllowBlocked to verify it."
        ownerMustNotSend = @("The env file contents in chat", "provider URLs that contain secret tokens")
        validationCommand = "npm run flowchain:owner-env:template; npm run flowchain:owner-env:readiness:validate; npm run flowchain:owner-env:readiness -- -AllowBlocked; npm run flowchain:owner-inputs:validate"
    }
)

$allProducedEnvNames = New-Object System.Collections.ArrayList
foreach ($item in $checklistItems) {
    foreach ($name in @($item.producesEnvNames)) {
        if (-not $allProducedEnvNames.Contains($name)) {
            [void] $allProducedEnvNames.Add($name)
        }
    }
}

$requiredOwnerEnvNames = @(
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
$missingChecklistCoverage = @($requiredOwnerEnvNames | Where-Object { $_ -notin @($allProducedEnvNames) })

$report = [ordered]@{
    schema = "flowchain.owner_signup_checklist_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $(if ($missingChecklistCoverage.Count -eq 0) { "passed" } else { "failed" })
    ownerInputsStatus = $ownerInputsStatus
    flowChainRpcIsRepoOwned = $true
    thirdPartyFlowChainRpcProviderNeeded = $false
    externalSignupCount = @($checklistItems | Where-Object { $_.externalSignupNeeded -eq $true }).Count
    itemCount = $checklistItems.Count
    checklistItems = $checklistItems
    requiredOwnerEnvNames = $requiredOwnerEnvNames
    producedEnvNames = @($allProducedEnvNames)
    missingChecklistCoverage = $missingChecklistCoverage
    missingEnvNames = $missingEnvNames
    invalidEnvNames = $invalidEnvNames
    localEnvFileSupported = $true
    localEnvFileEnvName = "FLOWCHAIN_OWNER_ENV_FILE"
    ownerEnvTemplateCommand = "npm run flowchain:owner-env:template"
    ownerEnvReadinessValidationCommand = "npm run flowchain:owner-env:readiness:validate"
    ownerEnvReadinessCommand = "npm run flowchain:owner-env:readiness -- -AllowBlocked"
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$reportText = $report | ConvertTo-Json -Depth 18
Assert-FlowChainNoSecretText -Text $reportText -Label "owner signup checklist report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Owner Signup Checklist")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $($report.status)")
$markdownLines.Add("")
$markdownLines.Add('FlowChain RPC is implemented by this repository. Do not sign up for a third-party FlowChain RPC provider. Public RPC means putting an owner-operated HTTPS edge in front of the private origin `127.0.0.1:8787`.')
$markdownLines.Add("")
$markdownLines.Add('Put real values in a local service environment or an ignored `FLOWCHAIN_OWNER_ENV_FILE` file. Run `npm run flowchain:owner-env:template` to create the ignored local scaffold, run `npm run flowchain:owner-env:readiness:validate` to test path safety, then run `npm run flowchain:owner-env:readiness -- -AllowBlocked` after filling it. Do not paste private keys, wallet recovery material, provider API keys, tunnel tokens, TLS private keys, or secret-bearing RPC URLs into chat or committed files.')
$markdownLines.Add("")
$markdownLines.Add("## Signup And Setup Items")
$markdownLines.Add("")
$markdownLines.Add("| Item | External signup? | Acceptable options | Produces env names | Validation |")
$markdownLines.Add("| --- | --- | --- | --- | --- |")
foreach ($item in $checklistItems) {
    $markdownLines.Add("| $($item.title) | $($item.externalSignupNeeded) | $((@($item.acceptableOptions)) -join ', ') | $((@($item.producesEnvNames)) -join ', ') | $($item.validationCommand) |")
}
$markdownLines.Add("")
$markdownLines.Add("## What You Need To Get")
$markdownLines.Add("")
foreach ($item in $checklistItems) {
    $markdownLines.Add("- $($item.title): $($item.ownerMustGet)")
}
$markdownLines.Add("")
$markdownLines.Add("## Do Not Send")
$markdownLines.Add("")
foreach ($item in $checklistItems) {
    foreach ($forbidden in @($item.ownerMustNotSend)) {
        $markdownLines.Add("- $forbidden")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Remaining Env Inputs")
$markdownLines.Add("")
foreach ($name in $requiredOwnerEnvNames) {
    $statusText = if ($name -in $missingEnvNames) { "missing" } elseif ($name -in $invalidEnvNames) { "invalid" } else { "not flagged by latest owner input report" }
    $markdownLines.Add("- ${name}: $statusText")
}

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "owner signup checklist markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain owner signup checklist status: $($report.status)"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($report.status -ne "passed") {
    Write-Host "Missing checklist coverage: $($missingChecklistCoverage -join ', ')"
    exit 1
}
exit 0
