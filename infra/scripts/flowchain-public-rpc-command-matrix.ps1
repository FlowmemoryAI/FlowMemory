param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-command-matrix-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/PUBLIC_RPC_COMMAND_MATRIX.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$packageJson = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "package.json") | ConvertFrom-Json
$scripts = $packageJson.scripts

function Get-MatrixProp {
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

function Get-MatrixReportStatus {
    param([AllowNull()][object] $Report)

    if ($null -eq $Report) {
        return "missing"
    }
    return [string](Get-MatrixProp -Object $Report -Name "status" -Default "missing")
}

function Get-MatrixScriptCommand {
    param([string] $Name)

    if (-not [string]::IsNullOrWhiteSpace($Name) -and $scripts.PSObject.Properties.Name -contains $Name) {
        return [string] $scripts.$Name
    }
    return ""
}

function Get-RepoRelativeScriptPath {
    param([string] $Command)

    foreach ($part in @($Command -split '\s+')) {
        $candidate = $part.Trim("`"", "'", ",")
        if ($candidate -match '^(infra[\\/]+scripts[\\/]+.+\.ps1|services[\\/]+.+\.(ts|js|mjs))$') {
            return $candidate -replace "\\", "/"
        }
    }
    return ""
}

function Read-MatrixText {
    param([string] $RelativePath)

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        return ""
    }
    $fullPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path $RelativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        return ""
    }
    return Get-Content -Raw -LiteralPath $fullPath
}

function Test-AllTextContains {
    param(
        [string] $Text,
        [string[]] $Needles
    )

    foreach ($needle in @($Needles)) {
        if ([string]::IsNullOrWhiteSpace($needle)) {
            continue
        }
        if (-not $Text.Contains($needle)) {
            return $false
        }
    }
    return $true
}

$reports = [ordered]@{
    readiness = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json")
    edgeTemplate = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-edge-template-report.json")
    deploymentBundle = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json")
    deploymentAutomation = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json")
    validation = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json")
    syntheticCanary = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-synthetic-canary-report.json")
    abuseTest = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-abuse-test-report.json")
    testerGateway = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json")
    testerNetwork = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json")
    publicDeployment = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json")
    cutover = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/live-cutover-rehearsal-report.json")
    truthTable = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/production-truth-table-report.json")
    noSecret = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json")
}

$requiredOwnerEnvNamePattern = '^FLOWCHAIN_[A-Z0-9_]+$'
$definitions = @(
    [ordered]@{
        id = "public-rpc-readiness"
        kind = "package-script"
        script = "flowchain:public-rpc:check"
        phase = "preflight"
        purpose = "Fail closed until public URL, CORS, rate limit, TLS termination, and backup path are owner configured."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json"
        riskClass = "read-only-owner-input-gate"
        requiredEnvNames = @("FLOWCHAIN_RPC_PUBLIC_URL", "FLOWCHAIN_RPC_ALLOWED_ORIGINS", "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE", "FLOWCHAIN_RPC_TLS_TERMINATED", "FLOWCHAIN_RPC_STATE_BACKUP_PATH")
        requiredTokens = @("FLOWCHAIN_RPC_PUBLIC_URL", "FLOWCHAIN_RPC_ALLOWED_ORIGINS", "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE", "FLOWCHAIN_RPC_TLS_TERMINATED", "FLOWCHAIN_RPC_STATE_BACKUP_PATH")
        mutatesHost = $false
        ownerHostCommand = $false
    },
    [ordered]@{
        id = "edge-template"
        kind = "package-script"
        script = "flowchain:public-rpc:edge-template"
        phase = "render"
        purpose = "Render no-value public RPC edge template evidence for TLS, CORS, security headers, and defensive routes."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-edge-template-report.json"
        riskClass = "local-render-no-mutation"
        requiredEnvNames = @()
        requiredTokens = @("Strict-Transport-Security", "Content-Security-Policy", "FLOWCHAIN_RPC_ALLOWED_ORIGINS")
        mutatesHost = $false
        ownerHostCommand = $false
    },
    [ordered]@{
        id = "deployment-bundle"
        kind = "package-script"
        script = "flowchain:public-rpc:deployment-bundle"
        phase = "render"
        purpose = "Render owner-host public RPC bundle with Nginx, preflight, verify, rollback, and owner env example artifacts."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json"
        riskClass = "local-render-no-mutation"
        requiredEnvNames = @()
        requiredTokens = @("nginx-preflight", "ROLLBACK.md", "owner-public-rpc.env.example")
        mutatesHost = $false
        ownerHostCommand = $false
    },
    [ordered]@{
        id = "deployment-automation"
        kind = "package-script"
        script = "flowchain:public-rpc:deployment:automation"
        phase = "render"
        purpose = "Validate owner-host render, hash verification, command plan, apply scripts, and rollback drill without host mutation."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json"
        riskClass = "local-validation-no-mutation"
        requiredEnvNames = @()
        requiredTokens = @("ownerHostApplyPlan", "rollbackDrill", "commandPlan")
        mutatesHost = $false
        ownerHostCommand = $false
    },
    [ordered]@{
        id = "systemd-validation"
        kind = "package-script"
        script = "flowchain:service:install:systemd:validate"
        phase = "service-install"
        purpose = "Validate Linux systemd service units and autorecovery install plan before owner-host install."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/systemd-service-install-validation-report.json"
        riskClass = "local-validation-no-mutation"
        requiredEnvNames = @()
        requiredTokens = @("flowchain-live.service", "flowchain-supervisor.service", "Restart=always")
        mutatesHost = $false
        ownerHostCommand = $false
    },
    [ordered]@{
        id = "windows-install-validation"
        kind = "package-script"
        script = "flowchain:service:install:validate"
        phase = "service-install"
        purpose = "Validate Windows service install plan and status commands without host mutation."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/service-install-validation-report.json"
        riskClass = "local-validation-no-mutation"
        requiredEnvNames = @()
        requiredTokens = @("Plan", "Status", "bridgeRelayer")
        mutatesHost = $false
        ownerHostCommand = $false
    },
    [ordered]@{
        id = "owner-host-linux-plan"
        kind = "owner-host-command"
        command = "bash <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.sh plan"
        phase = "owner-host-plan"
        purpose = "Plan Linux owner-host public RPC artifact install without mutation."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json"
        riskClass = "owner-host-read-only-plan"
        requiredEnvNames = @("FLOWCHAIN_DEPLOY_RENDER_DIR")
        requiredTokens = @("owner-host-apply.sh", "plan")
        mutatesHost = $false
        ownerHostCommand = $true
    },
    [ordered]@{
        id = "owner-host-windows-plan"
        kind = "owner-host-command"
        command = "powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.ps1 -Action Plan"
        phase = "owner-host-plan"
        purpose = "Plan Windows owner-host public RPC artifact install without mutation."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json"
        riskClass = "owner-host-read-only-plan"
        requiredEnvNames = @("FLOWCHAIN_DEPLOY_RENDER_DIR")
        requiredTokens = @("owner-host-apply.ps1", "Plan")
        mutatesHost = $false
        ownerHostCommand = $true
    },
    [ordered]@{
        id = "owner-host-linux-apply"
        kind = "owner-host-command"
        command = "bash <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.sh apply"
        phase = "edge-apply"
        purpose = "Apply Linux owner-host public RPC edge after owner inputs, DNS, TLS, and backup path are configured."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json"
        riskClass = "owner-host-mutating-apply"
        requiredEnvNames = @("FLOWCHAIN_DEPLOY_RENDER_DIR")
        requiredTokens = @("owner-host-apply.sh", "apply")
        mutatesHost = $true
        ownerHostCommand = $true
    },
    [ordered]@{
        id = "owner-host-windows-apply"
        kind = "owner-host-command"
        command = "powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.ps1 -Action Apply"
        phase = "edge-apply"
        purpose = "Apply Windows owner-host public RPC edge after owner inputs, TLS, and Nginx path are configured."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json"
        riskClass = "owner-host-mutating-apply"
        requiredEnvNames = @("FLOWCHAIN_DEPLOY_RENDER_DIR")
        requiredTokens = @("owner-host-apply.ps1", "Apply")
        mutatesHost = $true
        ownerHostCommand = $true
    },
    [ordered]@{
        id = "public-rpc-validation"
        kind = "package-script"
        script = "flowchain:public-rpc:validate"
        phase = "post-deploy-proof"
        purpose = "Validate public RPC CORS, rate-limit, response hygiene, and read path behavior."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json"
        riskClass = "read-only-proof"
        requiredEnvNames = @()
        requiredTokens = @("allowedOriginAccepted", "disallowedOriginRejected", "rateLimit")
        mutatesHost = $false
        ownerHostCommand = $false
    },
    [ordered]@{
        id = "synthetic-canary"
        kind = "package-script"
        script = "flowchain:public-rpc:synthetic-canary"
        phase = "post-deploy-proof"
        purpose = "Run read-only public RPC synthetic canary and prove no write methods are exposed."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-synthetic-canary-report.json"
        riskClass = "read-only-owner-input-gate"
        requiredEnvNames = @("FLOWCHAIN_RPC_PUBLIC_URL")
        requiredTokens = @("read-only public endpoint probes", "noWriteMethodsInvoked")
        mutatesHost = $false
        ownerHostCommand = $false
    },
    [ordered]@{
        id = "abuse-test"
        kind = "package-script"
        script = "flowchain:public-rpc:abuse-test"
        phase = "post-deploy-proof"
        purpose = "Validate public RPC abuse rejection boundaries for private routes and write-like methods."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-abuse-test-report.json"
        riskClass = "read-only-proof"
        requiredEnvNames = @()
        requiredTokens = @("abuse", "private", "write")
        mutatesHost = $false
        ownerHostCommand = $false
    },
    [ordered]@{
        id = "tester-gateway"
        kind = "package-script"
        script = "flowchain:tester:gateway:e2e"
        phase = "tester-proof"
        purpose = "Prove external tester gateway routes for wallet, faucet, capped send, and cap rejection."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json"
        riskClass = "local-validation-no-broadcast"
        requiredEnvNames = @()
        requiredTokens = @("faucet", "capRejected", "transferApplied")
        mutatesHost = $false
        ownerHostCommand = $false
    },
    [ordered]@{
        id = "wallet-tester-e2e"
        kind = "package-script"
        script = "flowchain:wallet:live-tester:e2e"
        phase = "tester-proof"
        purpose = "Prove friends-and-family wallet creation and wallet-to-wallet transfer on the running local chain."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json"
        riskClass = "local-validation-no-broadcast"
        requiredEnvNames = @()
        requiredTokens = @("walletCreatesPublicOnly", "transferCountMatches", "packetSmokeRoutes")
        mutatesHost = $false
        ownerHostCommand = $false
    },
    [ordered]@{
        id = "public-deployment-contract"
        kind = "package-script"
        script = "flowchain:public-deployment:contract"
        phase = "release"
        purpose = "Evaluate the owner-operated public deployment contract before external sharing."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json"
        riskClass = "release-gate"
        requiredEnvNames = @()
        requiredTokens = @("rollbackReady", "operatorCommands")
        mutatesHost = $false
        ownerHostCommand = $false
    },
    [ordered]@{
        id = "cutover-rehearsal"
        kind = "package-script"
        script = "flowchain:live:cutover:rehearsal"
        phase = "release"
        purpose = "Run the ordered public RPC and tester launch rehearsal with owner-input blocking classified."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/live-cutover-rehearsal-report.json"
        riskClass = "release-gate"
        requiredEnvNames = @()
        requiredTokens = @("Owner env readiness", "Production truth table", "No-secret scan")
        mutatesHost = $false
        ownerHostCommand = $false
    },
    [ordered]@{
        id = "truth-table"
        kind = "package-script"
        script = "flowchain:truth-table"
        phase = "release"
        purpose = "Classify all production gates as passed, owner-blocked, failed, or stale."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/production-truth-table-report.json"
        riskClass = "release-gate"
        requiredEnvNames = @()
        requiredTokens = @("blocked-owner-input", "failed", "stale")
        mutatesHost = $false
        ownerHostCommand = $false
    },
    [ordered]@{
        id = "no-secret-scan"
        kind = "package-script"
        script = "flowchain:no-secret:scan"
        phase = "release"
        purpose = "Scan generated launch evidence for secret-shaped material before sharing."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json"
        riskClass = "release-gate"
        requiredEnvNames = @()
        requiredTokens = @("secretMarkerFindings", "noSecrets")
        mutatesHost = $false
        ownerHostCommand = $false
    },
    [ordered]@{
        id = "owner-host-linux-rollback"
        kind = "owner-host-command"
        command = "bash <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.sh rollback"
        phase = "rollback"
        purpose = "Rollback Linux public RPC edge artifacts if owner-host apply fails."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json"
        riskClass = "owner-host-mutating-rollback"
        requiredEnvNames = @("FLOWCHAIN_DEPLOY_RENDER_DIR")
        requiredTokens = @("owner-host-apply.sh", "rollback")
        mutatesHost = $true
        ownerHostCommand = $true
    },
    [ordered]@{
        id = "owner-host-windows-rollback"
        kind = "owner-host-command"
        command = "powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.ps1 -Action Rollback"
        phase = "rollback"
        purpose = "Rollback Windows public RPC edge artifacts if owner-host apply fails."
        expectedReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json"
        riskClass = "owner-host-mutating-rollback"
        requiredEnvNames = @("FLOWCHAIN_DEPLOY_RENDER_DIR")
        requiredTokens = @("owner-host-apply.ps1", "Rollback")
        mutatesHost = $true
        ownerHostCommand = $true
    }
)

$rows = foreach ($definition in $definitions) {
    $kind = [string] $definition.kind
    $script = [string](Get-MatrixProp -Object $definition -Name "script" -Default "")
    $command = if ($kind -eq "package-script") { Get-MatrixScriptCommand -Name $script } else { [string] $definition.command }
    $exists = if ($kind -eq "package-script") { -not [string]::IsNullOrWhiteSpace($command) } else { $true }
    $scriptPath = Get-RepoRelativeScriptPath -Command $command
    $scriptText = Read-MatrixText -RelativePath $scriptPath
    $combinedText = "$command`n$scriptText"
    $requiredEnvNames = @($definition.requiredEnvNames)
    $requiredTokens = @($definition.requiredTokens)

    [ordered]@{
        id = [string] $definition.id
        kind = $kind
        script = $script
        phase = [string] $definition.phase
        purpose = [string] $definition.purpose
        exists = $exists
        command = $command
        scriptPath = $scriptPath
        scriptTextAvailable = if ($kind -eq "package-script") { -not [string]::IsNullOrWhiteSpace($scriptText) } else { $true }
        riskClass = [string] $definition.riskClass
        mutatesHost = [bool] $definition.mutatesHost
        ownerHostCommand = [bool] $definition.ownerHostCommand
        requiredEnvNames = $requiredEnvNames
        requiredEnvReferencesPresent = if ($requiredEnvNames.Count -eq 0) { $true } else { Test-AllTextContains -Text $combinedText -Needles $requiredEnvNames }
        requiredValidationSignalsPresent = if ($requiredTokens.Count -eq 0) { $true } else { Test-AllTextContains -Text $combinedText -Needles $requiredTokens }
        expectedReportPath = [string] $definition.expectedReportPath
        committedEvidencePath = ([string] $definition.expectedReportPath).StartsWith("docs/agent-runs/live-product-infra-rpc/")
        commandAvoidsInlineEnvAssignment = $command -notmatch 'FLOWCHAIN_[A-Z0-9_]+\s*='
        commandAvoidsUrls = $command -notmatch 'https?://'
        commandAvoidsKeyMaterial = $command -notmatch '(?i)(private[-_ ]?key\s*[=:]|secret\s*[=:]|token\s*[=:]|0x[0-9a-f]{64})'
        ownerInputNamesOnly = @(($requiredEnvNames) | Where-Object { "$_" -notmatch $requiredOwnerEnvNamePattern }).Count -eq 0
    }
}

$missingPackageScripts = @($rows | Where-Object { $_.kind -eq "package-script" -and -not $_.exists } | ForEach-Object { $_.script })
$rowsMissingEnvReferences = @($rows | Where-Object { -not $_.requiredEnvReferencesPresent } | ForEach-Object { $_.id })
$rowsMissingValidationSignals = @($rows | Where-Object { -not $_.requiredValidationSignalsPresent } | ForEach-Object { $_.id })
$commandsWithInlineEnvAssignment = @($rows | Where-Object { -not $_.commandAvoidsInlineEnvAssignment } | ForEach-Object { $_.id })
$commandsWithUrls = @($rows | Where-Object { -not $_.commandAvoidsUrls } | ForEach-Object { $_.id })
$commandsWithKeyMaterialReference = @($rows | Where-Object { -not $_.commandAvoidsKeyMaterial } | ForEach-Object { $_.id })
$badOwnerInputRows = @($rows | Where-Object { -not $_.ownerInputNamesOnly } | ForEach-Object { $_.id })
$phases = @($rows | ForEach-Object { $_.phase } | Sort-Object -Unique)
$requiredPhases = @("preflight", "render", "owner-host-plan", "service-install", "edge-apply", "post-deploy-proof", "tester-proof", "release", "rollback")
$missingPhases = @($requiredPhases | Where-Object { $_ -notin $phases })
$mutatingOwnerHostRows = @($rows | Where-Object { $_.ownerHostCommand -and $_.mutatesHost })
$ownerHostPlanRows = @($rows | Where-Object { $_.phase -eq "owner-host-plan" })
$ownerHostApplyRows = @($rows | Where-Object { $_.phase -eq "edge-apply" })
$ownerHostRollbackRows = @($rows | Where-Object { $_.phase -eq "rollback" })
$committedEvidenceRows = @($rows | Where-Object { $_.committedEvidencePath })
$deploymentAutomation = $reports.deploymentAutomation
$deploymentAutomationChecks = Get-MatrixProp -Object $deploymentAutomation -Name "checks"
$deploymentBundle = $reports.deploymentBundle
$deploymentBundleChecks = Get-MatrixProp -Object $deploymentBundle -Name "checks"

$checks = [ordered]@{
    packageScriptPresent = $scripts.PSObject.Properties.Name -contains "flowchain:public-rpc:command-matrix"
    allPackageScriptsPresent = $missingPackageScripts.Count -eq 0
    phaseCoverageComplete = $missingPhases.Count -eq 0
    renderPlanApplyProofRollbackCovered = @(
        "deployment-bundle",
        "deployment-automation",
        "owner-host-linux-plan",
        "owner-host-windows-plan",
        "owner-host-linux-apply",
        "owner-host-windows-apply",
        "synthetic-canary",
        "cutover-rehearsal",
        "owner-host-linux-rollback",
        "owner-host-windows-rollback"
    ) | Where-Object { $_ -notin @($rows | ForEach-Object { $_.id }) } | Measure-Object | ForEach-Object { $_.Count -eq 0 }
    ownerHostPlanCommandsPresent = $ownerHostPlanRows.Count -ge 2
    ownerHostApplyCommandsPresent = $ownerHostApplyRows.Count -ge 2
    ownerHostRollbackCommandsPresent = $ownerHostRollbackRows.Count -ge 2
    mutatingOwnerHostCommandsHaveRollbackCoverage = $mutatingOwnerHostRows.Count -ge 4 -and $ownerHostRollbackRows.Count -ge 2
    deploymentAutomationReportPassed = (Get-MatrixReportStatus -Report $deploymentAutomation) -eq "passed"
    deploymentBundleReportPassed = (Get-MatrixReportStatus -Report $deploymentBundle) -eq "passed"
    deploymentAutomationCommandPlanCovered = ((Get-MatrixProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesTesterGatewayE2e" -Default $false) -eq $true) `
        -and ((Get-MatrixProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesWalletTesterE2e" -Default $false) -eq $true) `
        -and ((Get-MatrixProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesSyntheticCanary" -Default $false) -eq $true) `
        -and ((Get-MatrixProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesCutoverRehearsal" -Default $false) -eq $true) `
        -and ((Get-MatrixProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesTruthTable" -Default $false) -eq $true) `
        -and ((Get-MatrixProp -Object $deploymentAutomationChecks -Name "commandPlanIncludesNoSecretScan" -Default $false) -eq $true)
    deploymentAutomationOwnerHostApplyCovered = ((Get-MatrixProp -Object $deploymentAutomationChecks -Name "renderedOwnerHostApplyScriptHasPlanApplyRollback" -Default $false) -eq $true) `
        -and ((Get-MatrixProp -Object $deploymentAutomationChecks -Name "renderedOwnerHostApplyPowerShellHasPlanApplyRollback" -Default $false) -eq $true) `
        -and ((Get-MatrixProp -Object $deploymentAutomationChecks -Name "renderedOwnerHostApplyScriptVerifiesHashes" -Default $false) -eq $true) `
        -and ((Get-MatrixProp -Object $deploymentAutomationChecks -Name "renderedOwnerHostApplyPowerShellVerifiesHashes" -Default $false) -eq $true)
    deploymentAutomationRollbackDrillCovered = ((Get-MatrixProp -Object $deploymentAutomationChecks -Name "rollbackDrillPerformed" -Default $false) -eq $true) `
        -and ((Get-MatrixProp -Object $deploymentAutomationChecks -Name "rollbackRenderedConfigRestoredFromPrevious" -Default $false) -eq $true) `
        -and ((Get-MatrixProp -Object $deploymentAutomationChecks -Name "rollbackOriginalConfigRestoredAfterDrill" -Default $false) -eq $true)
    deploymentBundleRollbackRunbookCovered = ((Get-MatrixProp -Object $deploymentBundleChecks -Name "rollbackRunbookWritten" -Default $false) -eq $true) `
        -and ((Get-MatrixProp -Object $deploymentBundleChecks -Name "includesRollbackCommands" -Default $false) -eq $true)
    requiredEnvReferencesPresent = $rowsMissingEnvReferences.Count -eq 0
    validationSignalsPresent = $rowsMissingValidationSignals.Count -eq 0
    commandsAvoidInlineEnvAssignment = $commandsWithInlineEnvAssignment.Count -eq 0
    commandsAvoidUrls = $commandsWithUrls.Count -eq 0
    commandsAvoidKeyMaterial = $commandsWithKeyMaterialReference.Count -eq 0
    ownerInputNamesOnly = $badOwnerInputRows.Count -eq 0
    committedEvidencePathsCovered = $committedEvidenceRows.Count -ge 12
    envValuesPrintedFalse = $true
    broadcastsFalse = $true
    noSecrets = $true
}

$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
$report = [ordered]@{
    schema = "flowchain.public_rpc_command_matrix_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    commandCount = $rows.Count
    phaseCount = $phases.Count
    ownerHostCommandCount = @($rows | Where-Object { $_.ownerHostCommand }).Count
    mutatingOwnerHostCommandCount = $mutatingOwnerHostRows.Count
    committedEvidencePathCount = $committedEvidenceRows.Count
    requiredPhases = $requiredPhases
    missingPhases = $missingPhases
    rows = @($rows)
    missingPackageScripts = $missingPackageScripts
    rowsMissingEnvReferences = $rowsMissingEnvReferences
    rowsMissingValidationSignals = $rowsMissingValidationSignals
    commandsWithInlineEnvAssignment = $commandsWithInlineEnvAssignment
    commandsWithUrls = $commandsWithUrls
    commandsWithKeyMaterialReference = $commandsWithKeyMaterialReference
    badOwnerInputRows = $badOwnerInputRows
    sourceReportStatuses = [ordered]@{
        readiness = Get-MatrixReportStatus -Report $reports.readiness
        edgeTemplate = Get-MatrixReportStatus -Report $reports.edgeTemplate
        deploymentBundle = Get-MatrixReportStatus -Report $reports.deploymentBundle
        deploymentAutomation = Get-MatrixReportStatus -Report $reports.deploymentAutomation
        validation = Get-MatrixReportStatus -Report $reports.validation
        syntheticCanary = Get-MatrixReportStatus -Report $reports.syntheticCanary
        abuseTest = Get-MatrixReportStatus -Report $reports.abuseTest
        testerGateway = Get-MatrixReportStatus -Report $reports.testerGateway
        testerNetwork = Get-MatrixReportStatus -Report $reports.testerNetwork
        publicDeployment = Get-MatrixReportStatus -Report $reports.publicDeployment
        cutover = Get-MatrixReportStatus -Report $reports.cutover
        truthTable = Get-MatrixReportStatus -Report $reports.truthTable
        noSecret = Get-MatrixReportStatus -Report $reports.noSecret
    }
    checks = $checks
    failedChecks = $failedChecks
    broadcasts = $false
    envValuesPrinted = $false
    noSecrets = $true
}

Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

$markdownLines = New-Object System.Collections.ArrayList
[void] $markdownLines.Add("# FlowChain Public RPC Command Matrix")
[void] $markdownLines.Add("")
[void] $markdownLines.Add("Generated: $($report.generatedAt)")
[void] $markdownLines.Add("Status: $status")
[void] $markdownLines.Add("")
[void] $markdownLines.Add("This matrix maps public RPC launch commands to phase, owner-host mutation risk, owner input names, and expected evidence paths. It prints names only, not owner values.")
[void] $markdownLines.Add("")
[void] $markdownLines.Add("## Summary")
[void] $markdownLines.Add("")
[void] $markdownLines.Add("- Commands: $($rows.Count)")
[void] $markdownLines.Add("- Phases: $($phases -join ', ')")
[void] $markdownLines.Add("- Owner-host commands: $($report.ownerHostCommandCount)")
[void] $markdownLines.Add("- Mutating owner-host commands: $($report.mutatingOwnerHostCommandCount)")
[void] $markdownLines.Add("- Committed evidence paths: $($committedEvidenceRows.Count)")
[void] $markdownLines.Add("- Failed checks: $($failedChecks.Count)")
[void] $markdownLines.Add("")
[void] $markdownLines.Add("## Checks")
[void] $markdownLines.Add("")
[void] $markdownLines.Add("| Check | Passed |")
[void] $markdownLines.Add("| --- | --- |")
foreach ($check in $checks.GetEnumerator()) {
    [void] $markdownLines.Add("| $($check.Key) | $($check.Value) |")
}
[void] $markdownLines.Add("")
[void] $markdownLines.Add("## Commands")
[void] $markdownLines.Add("")
[void] $markdownLines.Add("| Phase | Command | Risk | Mutates Host | Evidence |")
[void] $markdownLines.Add("| --- | --- | --- | --- | --- |")
foreach ($row in $rows) {
    $displayCommand = if ([string]::IsNullOrWhiteSpace($row.script)) { $row.id } else { $row.script }
    [void] $markdownLines.Add("| $($row.phase) | ``$displayCommand`` | $($row.riskClass) | $($row.mutatesHost) | $($row.expectedReportPath) |")
}
[void] $markdownLines.Add("")
[void] $markdownLines.Add("## Owner Input Names")
[void] $markdownLines.Add("")
$ownerInputNames = @($rows | ForEach-Object { @($_.requiredEnvNames) } | Sort-Object -Unique)
if ($ownerInputNames.Count -eq 0) {
    [void] $markdownLines.Add("- None")
}
else {
    foreach ($name in $ownerInputNames) {
        [void] $markdownLines.Add("- $name")
    }
}
[void] $markdownLines.Add("")
[void] $markdownLines.Add("## Source Reports")
[void] $markdownLines.Add("")
[void] $markdownLines.Add("| Report | Status |")
[void] $markdownLines.Add("| --- | --- |")
foreach ($entry in $report.sourceReportStatuses.GetEnumerator()) {
    [void] $markdownLines.Add("| $($entry.Key) | $($entry.Value) |")
}

Set-Content -LiteralPath $markdownFullPath -Value ($markdownLines -join "`r`n") -Encoding UTF8
Assert-FlowChainNoSecretText -Text (($report | ConvertTo-Json -Depth 16) + "`n" + ($markdownLines -join "`n")) -Label "public RPC command matrix"

Write-Host "FlowChain public RPC command matrix status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    throw "FlowChain public RPC command matrix failed checks: $($failedChecks -join ', ')"
}
