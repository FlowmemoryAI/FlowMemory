param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/owner-onboarding-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/OWNER_ONBOARDING.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$ownerInputsPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json"

function Get-OnboardingProp {
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
$missingEnvNames = @((Get-OnboardingProp -Object $ownerInputs -Name "missingEnvNames" -Default @()))
$invalidEnvNames = @((Get-OnboardingProp -Object $ownerInputs -Name "invalidEnvNames" -Default @()))
$ownerInputsStatus = [string](Get-OnboardingProp -Object $ownerInputs -Name "status" -Default "missing")

$publicRpcEnv = @(
    "FLOWCHAIN_RPC_PUBLIC_URL",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
    "FLOWCHAIN_RPC_TLS_TERMINATED"
)
$backupEnv = @("FLOWCHAIN_RPC_STATE_BACKUP_PATH")
$testerWriteEnv = @(
    "FLOWCHAIN_TESTER_WRITE_ENABLED",
    "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256",
    "FLOWCHAIN_TESTER_MAX_SEND_UNITS"
)
$bridgeEnv = @(
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
$bridgeOptionalEnv = @(
    "FLOWCHAIN_BASE8453_CURSOR_STATE",
    "FLOWCHAIN_BASE8453_TO_BLOCK"
)

$onboardingGroups = @(
    [ordered]@{
        id = "flowchain-public-rpc-edge"
        title = "FlowChain public RPC edge"
        ownsRpcImplementation = $true
        thirdPartyFlowChainRpcProviderNeeded = $false
        externalSignupNeeded = $true
        signupCategory = "Public DNS/domain plus HTTPS host, tunnel, or reverse proxy for this chain's private RPC origin."
        localOrigin = "127.0.0.1:8787"
        envNames = $publicRpcEnv
        validationCommand = "npm run flowchain:public-rpc:check"
        decision = "Do not buy or configure a third-party FlowChain RPC provider; expose this repo's control-plane RPC through an owner-operated HTTPS edge."
    },
    [ordered]@{
        id = "state-backup"
        title = "State backup"
        ownsRpcImplementation = $true
        thirdPartyFlowChainRpcProviderNeeded = $false
        externalSignupNeeded = $false
        signupCategory = "Existing writable directory or owner-managed storage mounted on the host."
        localOrigin = ""
        envNames = $backupEnv
        validationCommand = "npm run flowchain:backup:check"
        decision = "Create or mount a writable backup directory before public operation, then verify snapshot creation and restore rehearsal."
    },
    [ordered]@{
        id = "external-tester-write-gateway"
        title = "External tester write gateway"
        ownsRpcImplementation = $true
        thirdPartyFlowChainRpcProviderNeeded = $false
        externalSignupNeeded = $false
        signupCategory = "Out-of-band shared tester bearer token hash and local send cap for friends-and-family pilot writes."
        localOrigin = "127.0.0.1:8787"
        envNames = $testerWriteEnv
        validationCommand = "npm run flowchain:owner-inputs"
        decision = "Use the authenticated /tester/wallets/create and /tester/wallets/send gateway for capped pilot writes; do not expose private /wallets/* routes publicly."
    },
    [ordered]@{
        id = "base8453-bridge-observer"
        title = "Base 8453 bridge observer"
        ownsRpcImplementation = $false
        thirdPartyFlowChainRpcProviderNeeded = $false
        externalSignupNeeded = $true
        signupCategory = "Base mainnet 8453 RPC provider or owner-operated Base node, plus deployed lockbox/token details."
        localOrigin = ""
        envNames = @($bridgeEnv + $bridgeOptionalEnv)
        validationCommand = "npm run flowchain:bridge:live:check"
        decision = "This is not for FlowChain RPC. It is only for reading Base 8453 bridge events. TO_BLOCK is optional because the relayer loop uses cursor state."
    }
)

$localShellTemplate = @(
    '$env:FLOWCHAIN_OWNER_ENV_FILE="<optional local ignored env file path>"',
    '$env:FLOWCHAIN_RPC_PUBLIC_URL="<public HTTPS endpoint for this FlowChain RPC edge>"',
    '$env:FLOWCHAIN_RPC_ALLOWED_ORIGINS="<comma-separated HTTPS app origins>"',
    '$env:FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE="<positive integer>"',
    '$env:FLOWCHAIN_RPC_TLS_TERMINATED="true"',
    '$env:FLOWCHAIN_RPC_STATE_BACKUP_PATH="<existing writable backup directory>"',
    '$env:FLOWCHAIN_TESTER_WRITE_ENABLED="true"',
    '$env:FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256="<sha256 hex of out-of-band tester bearer token>"',
    '$env:FLOWCHAIN_TESTER_MAX_SEND_UNITS="<positive local test-unit cap per send>"',
    '$env:FLOWCHAIN_PILOT_OPERATOR_ACK="I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"',
    '$env:FLOWCHAIN_BASE8453_RPC_URL="<Base 8453 RPC endpoint or self-operated node endpoint>"',
    '$env:FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS="<20-byte lockbox address>"',
    '$env:FLOWCHAIN_BASE8453_SUPPORTED_TOKEN="<20-byte token address>"',
    '$env:FLOWCHAIN_BASE8453_ASSET_DECIMALS="<0 through 255>"',
    '$env:FLOWCHAIN_BASE8453_FROM_BLOCK="<first bounded Base block>"',
    '$env:FLOWCHAIN_BASE8453_CURSOR_STATE="services/bridge-relayer/out/base8453-pilot-cursor-state.json"',
    '$env:FLOWCHAIN_BASE8453_TO_BLOCK="<optional last bounded Base block>"',
    '$env:FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI="<positive capped amount>"',
    '$env:FLOWCHAIN_PILOT_TOTAL_CAP_WEI="<positive capped amount greater than or equal to max deposit>"',
    '$env:FLOWCHAIN_PILOT_CONFIRMATIONS="<2 through 256>"'
)

$nextCommands = @(
    "npm run flowchain:owner:onboarding",
    "npm run flowchain:owner:signup-checklist",
    "npm run flowchain:owner-env:template",
    "npm run flowchain:owner-env:readiness:validate",
    "npm run flowchain:owner-env:readiness -- -AllowBlocked",
    "npm run flowchain:owner-inputs",
    "npm run flowchain:public-rpc:edge-template",
    "npm run flowchain:public-rpc:validate",
    "npm run flowchain:public-rpc:check",
    "npm run flowchain:backup:restore:validate",
    "npm run flowchain:backup:create",
    "npm run flowchain:backup:restore:verify",
    "npm run flowchain:backup:check",
    "npm run flowchain:bridge:live:check",
    "npm run flowchain:bridge:infra:check",
    "npm run flowchain:completion:audit -- -AllowBlocked"
)

$report = [ordered]@{
    schema = "flowchain.owner_onboarding_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "passed"
    ownerInputsStatus = $ownerInputsStatus
    flowChainRpcIsOurs = $true
    thirdPartyFlowChainRpcProviderNeeded = $false
    publicRpcRequiresOwnerPublicEdge = $true
    base8453RpcIsExternalChainDependency = $true
    localEnvFileSupported = $true
    localEnvFileEnvName = "FLOWCHAIN_OWNER_ENV_FILE"
    ownerEnvTemplateCommand = "npm run flowchain:owner-env:template"
    ownerEnvReadinessValidationCommand = "npm run flowchain:owner-env:readiness:validate"
    ownerEnvReadinessCommand = "npm run flowchain:owner-env:readiness -- -AllowBlocked"
    valuesPrinted = $false
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
    onboardingGroups = $onboardingGroups
    localShellTemplate = $localShellTemplate
    missingEnvNames = $missingEnvNames
    invalidEnvNames = $invalidEnvNames
    nextCommands = $nextCommands
}

$reportText = $report | ConvertTo-Json -Depth 16
Assert-FlowChainNoSecretText -Text $reportText -Label "owner onboarding report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Owner Onboarding")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: passed")
$markdownLines.Add("")
$markdownLines.Add("FlowChain RPC is implemented by this repository. The owner does not need a third-party FlowChain RPC provider. Public RPC readiness means exposing the private local RPC origin through an owner-operated HTTPS edge with DNS, TLS, CORS, rate limits, and monitoring.")
$markdownLines.Add("")
$markdownLines.Add("Base 8453 is different. The bridge observer reads Base mainnet, so that path needs a Base 8453 RPC endpoint or an owner-operated Base node.")
$markdownLines.Add("")
$markdownLines.Add("## Signup And Setup Groups")
$markdownLines.Add("")
$markdownLines.Add("| Group | Need external signup? | What it is for | Env names |")
$markdownLines.Add("| --- | --- | --- | --- |")
foreach ($group in $onboardingGroups) {
    $markdownLines.Add("| $($group.title) | $($group.externalSignupNeeded) | $($group.signupCategory.Replace('|','/')) | $((@($group.envNames)) -join ', ') |")
}
$markdownLines.Add("")
$markdownLines.Add("## Local Shell Template")
$markdownLines.Add("")
$markdownLines.Add("Set real values only in the local shell or service environment. Do not commit them and do not paste provider endpoints or credentials into chat.")
$markdownLines.Add('You may also set `FLOWCHAIN_OWNER_ENV_FILE` to an ignored local NAME=value file; the repo parser imports only known FlowChain owner env names and does not execute that file.')
$markdownLines.Add('Run `npm run flowchain:owner-env:template` to create the ignored local file scaffold before filling values.')
$markdownLines.Add('Run `npm run flowchain:owner-env:readiness:validate` to confirm unsafe owner env-file paths fail before live gates run.')
$markdownLines.Add('After filling the local file, run `npm run flowchain:owner-env:readiness -- -AllowBlocked` to validate the owner values against the live gates without printing values.')
$markdownLines.Add("")
$markdownLines.Add('```powershell')
foreach ($line in $localShellTemplate) {
    $markdownLines.Add($line)
}
$markdownLines.Add('```')
$markdownLines.Add("")
$markdownLines.Add("## Remaining Inputs")
$markdownLines.Add("")
if ($missingEnvNames.Count -eq 0 -and $invalidEnvNames.Count -eq 0) {
    $markdownLines.Add("- None recorded by the latest owner input report.")
}
else {
    foreach ($name in $missingEnvNames) {
        $markdownLines.Add("- Missing: $name")
    }
    foreach ($name in $invalidEnvNames) {
        $markdownLines.Add("- Invalid: $name")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Next Commands")
$markdownLines.Add("")
foreach ($command in $nextCommands) {
    $markdownLines.Add("- $command")
}

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "owner onboarding markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain owner onboarding status: passed"
Write-Host "FlowChain RPC is repo-owned; public RPC needs an owner HTTPS edge, not a third-party FlowChain RPC provider."
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
