param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/PUBLIC_DEPLOYMENT_CONTRACT.md",
    [int] $ChildTimeoutSeconds = 1800,
    [switch] $AllowBlocked,
    [switch] $NoRefresh
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)

if ($ChildTimeoutSeconds -lt 1) {
    throw "ChildTimeoutSeconds must be at least 1."
}

$knownOwnerInputs = @(
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
    "FLOWCHAIN_BASE8453_CURSOR_STATE",
    "FLOWCHAIN_BASE8453_TO_BLOCK",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_PILOT_CONFIRMATIONS"
)

$paths = [ordered]@{
    serviceStatus = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-status-report.json"
    serviceMonitor = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-monitor-report.json"
    serviceSupervisorValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-report.json"
    serviceInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-install-validation-report.json"
    opsSnapshot = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-snapshot-report.json"
    opsAlertRules = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-alert-rules-report.json"
    alertInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/alert-install-validation-report.json"
    ownerOnboarding = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-onboarding-report.json"
    ownerSignupChecklist = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-signup-checklist-report.json"
    ownerEnvTemplate = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-env-template-report.json"
    ownerInputs = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json"
    publicRpcEdgeTemplate = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-edge-template-report.json"
    publicRpcDeploymentBundle = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json"
    publicRpc = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json"
    publicRpcValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json"
    publicRpcAbuseTest = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-abuse-test-report.json"
    publicTesterGateway = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json"
    backup = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json"
    backupRestoreValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-report.json"
    backupInstallValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-install-validation-report.json"
    bridgeLive = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
    bridgeInfra = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
    bridgeRelayerOnce = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-relayer-once-report.json"
    externalTester = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
    externalTesterPacket = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json"
    architectureAudit = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-architecture-audit-report.json"
    noSecret = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json"
}

function Get-DeploymentJson {
    param([Parameter(Mandatory = $true)][string] $Path)
    return Read-FlowChainJsonIfExists -Path $Path
}

function Get-DeploymentProp {
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

function Get-DeploymentStatus {
    param([AllowNull()][object] $Report)
    return [string](Get-DeploymentProp -Object $Report -Name "status" -Default "missing")
}

function Test-DeploymentPackageScript {
    param(
        [Parameter(Mandatory = $true)][object] $PackageJson,
        [Parameter(Mandatory = $true)][string] $Name
    )

    return $PackageJson.PSObject.Properties.Name -contains "scripts" -and $PackageJson.scripts.PSObject.Properties.Name -contains $Name
}

function Add-UniqueDeploymentName {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [object] $Value
    )
    $name = "$Value"
    if (-not [string]::IsNullOrWhiteSpace($name) -and -not $Target.Contains($name)) {
        [void] $Target.Add($name)
    }
}

function Test-DeploymentRoutePresent {
    param(
        [AllowNull()][object] $Routes,
        [Parameter(Mandatory = $true)][string] $Route
    )

    foreach ($candidate in @($Routes)) {
        if ("$candidate" -eq $Route) {
            return $true
        }
    }
    return $false
}

function Add-DeploymentItem {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Items,
        [Parameter(Mandatory = $true)][string] $Id,
        [Parameter(Mandatory = $true)][string] $Requirement,
        [Parameter(Mandatory = $true)][string] $Status,
        [Parameter(Mandatory = $true)][string] $Evidence,
        [string[]] $Commands = @(),
        [string[]] $Blockers = @()
    )

    [void] $Items.Add([ordered]@{
        id = $Id
        requirement = $Requirement
        status = $Status
        evidence = $Evidence
        commands = $Commands
        blockers = $Blockers
    })
}

function ConvertTo-DeploymentSafeOutputLine {
    param([AllowNull()][object] $Line)

    $text = "$Line"
    foreach ($name in $knownOwnerInputs) {
        $escapedName = [System.Text.RegularExpressions.Regex]::Escape($name)
        $text = [System.Text.RegularExpressions.Regex]::Replace(
            $text,
            "(?i)($escapedName\s*[:=]\s*)([^\s,;]+)",
            {
                param([System.Text.RegularExpressions.Match] $Match)
                return "$($Match.Groups[1].Value)<redacted>"
            }
        )
    }
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "https?://[^\s,)]+", "<redacted-url>")
    return $text
}

function Stop-DeploymentProcessTree {
    param([Parameter(Mandatory = $true)][int] $ProcessId)

    $children = @()
    try {
        $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$ProcessId" -ErrorAction SilentlyContinue)
    }
    catch {
        $children = @()
    }

    foreach ($child in $children) {
        Stop-DeploymentProcessTree -ProcessId ([int] $child.ProcessId)
    }

    try {
        Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
    }
    catch {
    }
}

function Read-DeploymentOutputFile {
    param([Parameter(Mandatory = $true)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }
    return @(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue | ForEach-Object { "$_" })
}

function Invoke-DeploymentChildProcess {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string[]] $ArgumentList
    )

    $startedAt = (Get-Date).ToUniversalTime()
    $stamp = $startedAt.ToString("yyyyMMddTHHmmssfffZ")
    $tempBase = Join-Path ([System.IO.Path]::GetTempPath()) "flowchain-public-deployment-$PID-$stamp-$([Guid]::NewGuid().ToString("N"))"
    $stdoutPath = "$tempBase.out.log"
    $stderrPath = "$tempBase.err.log"
    $timedOut = $false
    $exitCode = 1
    $processId = $null
    $output = @()

    try {
        $process = Start-Process -FilePath "powershell" `
            -ArgumentList (Join-FlowChainProcessArguments -ArgumentList $ArgumentList) `
            -WorkingDirectory $repoRoot `
            -PassThru `
            -WindowStyle Hidden `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath
        $processId = $process.Id
        if (-not $process.WaitForExit($ChildTimeoutSeconds * 1000)) {
            $timedOut = $true
            Stop-DeploymentProcessTree -ProcessId $process.Id
            $exitCode = 124
        }
        else {
            $process.Refresh()
            $exitCode = [int] $process.ExitCode
        }
    }
    catch {
        $output = @($_.Exception.Message)
        $exitCode = 1
    }

    $stdout = Read-DeploymentOutputFile -Path $stdoutPath
    $stderr = Read-DeploymentOutputFile -Path $stderrPath
    $output = @($output + $stdout + $stderr) | ForEach-Object { ConvertTo-DeploymentSafeOutputLine -Line $_ }
    if ($timedOut) {
        $output = @("Timed out after $ChildTimeoutSeconds seconds; child process tree was stopped.") + $output
    }
    $finishedAt = (Get-Date).ToUniversalTime()

    Remove-Item -LiteralPath $stdoutPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue

    return [ordered]@{
        name = $Name
        startedAt = $startedAt.ToString("o")
        finishedAt = $finishedAt.ToString("o")
        durationSeconds = [int][Math]::Max(0, [Math]::Floor(($finishedAt - $startedAt).TotalSeconds))
        timedOut = $timedOut
        timeoutSeconds = $ChildTimeoutSeconds
        processId = $processId
        exitCode = [int] $exitCode
        outputRedacted = @($output)
    }
}

function Add-DeploymentRefreshStep {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Steps,
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string[]] $ArgumentList
    )

    $result = Invoke-DeploymentChildProcess -Name $Name -ArgumentList $ArgumentList
    [void] $Steps.Add($result)
}

$dependencyRefreshSteps = New-Object System.Collections.ArrayList
$dependencyRefreshCommands = @(
    "npm run flowchain:service:status -- -AllowBlocked",
    "npm run flowchain:service:monitor -- -DurationSeconds 20 -PollSeconds 5 -MaxStateAgeSeconds 90",
    "npm run flowchain:service:supervisor:validate",
    "npm run flowchain:service:install:validate",
    "npm run flowchain:ops:snapshot -- -AllowBlocked",
    "npm run flowchain:ops:alerts -- -AllowBlocked",
    "npm run flowchain:ops:alerts:install:validate",
    "npm run flowchain:owner:onboarding",
    "npm run flowchain:owner:signup-checklist",
    "npm run flowchain:owner-env:template",
    "npm run flowchain:owner-inputs -- -AllowBlocked",
    "npm run flowchain:public-rpc:edge-template",
    "npm run flowchain:public-rpc:deployment-bundle",
    "npm run flowchain:public-rpc:validate",
    "npm run flowchain:public-rpc:abuse-test",
    "npm run flowchain:tester:gateway:e2e",
    "npm run flowchain:public-rpc:check -- -AllowBlocked",
    "npm run flowchain:backup:restore:validate",
    "npm run flowchain:backup:install:validate",
    "npm run flowchain:backup:check -- -AllowBlocked",
    "npm run flowchain:bridge:live:check -- -AllowBlocked",
    "npm run flowchain:bridge:infra:check -- -AllowBlocked",
    "npm run flowchain:bridge:relayer:once -- -AllowBlocked",
    "npm run flowchain:external-tester:packet -- -AllowBlocked",
    "npm run flowchain:no-secret:scan"
)

if (-not $NoRefresh.IsPresent) {
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "service-status" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-status.ps1"), "-AllowBlocked", "-ReportPath", $paths.serviceStatus)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "service-monitor" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-monitor.ps1"), "-DurationSeconds", "20", "-PollSeconds", "5", "-MaxStateAgeSeconds", "90", "-ReportPath", $paths.serviceMonitor)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "service-supervisor-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-supervisor-validation.ps1"), "-ReportPath", $paths.serviceSupervisorValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "service-install-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-install-validation.ps1"), "-ReportPath", $paths.serviceInstallValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "ops-snapshot" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-ops-snapshot.ps1"), "-AllowBlocked", "-NoRefresh", "-ReportPath", $paths.opsSnapshot)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "ops-alert-rules" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-ops-alerts.ps1"), "-AllowBlocked", "-NoRefresh", "-ReportPath", $paths.opsAlertRules)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "alert-install-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-alert-install-validation.ps1"), "-ReportPath", $paths.alertInstallValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "owner-onboarding" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-onboarding.ps1"), "-ReportPath", $paths.ownerOnboarding)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "owner-signup-checklist" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-signup-checklist.ps1"), "-ReportPath", $paths.ownerSignupChecklist)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "owner-env-template" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-env-template.ps1"), "-ReportPath", $paths.ownerEnvTemplate)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "owner-inputs" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-inputs.ps1"), "-AllowBlocked", "-ReportPath", $paths.ownerInputs)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-rpc-edge-template" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-edge-template.ps1"), "-ReportPath", $paths.publicRpcEdgeTemplate)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-rpc-deployment-bundle" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-deployment-bundle.ps1"), "-ReportPath", $paths.publicRpcDeploymentBundle)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-rpc-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-validation.ps1"), "-ReportPath", $paths.publicRpcValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-rpc-abuse-test" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-abuse-test.ps1"), "-ReportPath", $paths.publicRpcAbuseTest)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-tester-gateway-e2e" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-tester-gateway-e2e.ps1"), "-ReportPath", $paths.publicTesterGateway)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-rpc-readiness" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-readiness.ps1"), "-AllowBlocked", "-ReportPath", $paths.publicRpc)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "backup-restore-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-backup-restore-validation.ps1"), "-ReportPath", $paths.backupRestoreValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "backup-install-validation" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-backup-install-validation.ps1"), "-ReportPath", $paths.backupInstallValidation)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "public-rpc-backup" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-backup-readiness.ps1"), "-AllowBlocked", "-ReportPath", $paths.backup)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "bridge-live" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-live-check.ps1"), "-AllowBlocked", "-ReportPath", $paths.bridgeLive)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "bridge-infra" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-live-env-bridge-readiness.ps1"), "-AllowBlocked", "-ReportPath", $paths.bridgeInfra)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "bridge-relayer-once" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-relayer-once.ps1"), "-AllowBlocked", "-ReportPath", $paths.bridgeRelayerOnce)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "external-tester-packet" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-external-tester-packet.ps1"), "-AllowBlocked", "-ReportPath", $paths.externalTesterPacket)
    Add-DeploymentRefreshStep -Steps $dependencyRefreshSteps -Name "no-secret-scan" -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Join-Path $PSScriptRoot "flowchain-no-secret-scan.ps1"),
        "-Paths",
        "docs/agent-runs/live-product-infra-rpc",
        "docs/OPERATIONS",
        "services/bridge-relayer/out/real-value-pilot-e2e",
        "devnet/local/live-l1-bridge-e2e",
        "-ReportPath",
        $paths.noSecret
    )
}

$dependencyRefreshFailedSteps = @($dependencyRefreshSteps | Where-Object { [int] $_.exitCode -ne 0 })
$dependencyRefreshTimedOutSteps = @($dependencyRefreshSteps | Where-Object { $_.timedOut -eq $true })
$dependencyRefresh = [ordered]@{
    performed = -not $NoRefresh.IsPresent
    delegatedToCaller = $NoRefresh.IsPresent
    childTimeoutSeconds = $ChildTimeoutSeconds
    failedStepNames = @($dependencyRefreshFailedSteps | ForEach-Object { $_.name })
    timedOutStepNames = @($dependencyRefreshTimedOutSteps | ForEach-Object { $_.name })
    steps = @($dependencyRefreshSteps)
}

$packageJson = Get-Content -Raw -LiteralPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "package.json") | ConvertFrom-Json
$reports = [ordered]@{}
foreach ($entry in $paths.GetEnumerator()) {
    $reports[$entry.Key] = Get-DeploymentJson -Path $entry.Value
}

$optionalOwnerInputs = @("FLOWCHAIN_BASE8453_CURSOR_STATE", "FLOWCHAIN_BASE8453_TO_BLOCK")
$missingEnvNames = New-Object System.Collections.ArrayList
foreach ($report in $reports.Values) {
    foreach ($name in @((Get-DeploymentProp -Object $report -Name "missingEnvNames" -Default @()))) {
        if ($name -in $knownOwnerInputs -and $name -notin $optionalOwnerInputs) {
            Add-UniqueDeploymentName -Target $missingEnvNames -Value $name
        }
    }
}
foreach ($name in @((Get-DeploymentProp -Object $reports.ownerInputs -Name "invalidEnvNames" -Default @()))) {
    Add-UniqueDeploymentName -Target $missingEnvNames -Value $name
}
$unknownMissingEnvNames = @($missingEnvNames | Where-Object { $_ -notin $knownOwnerInputs })

$items = New-Object System.Collections.ArrayList
Add-DeploymentItem -Items $items -Id "dependency-report-refresh" `
    -Requirement "The deployment contract evaluates reports freshly generated by this command or an explicit caller such as the completion audit." `
    -Status $(if ($dependencyRefreshFailedSteps.Count -eq 0) { "passed" } else { "failed" }) `
    -Evidence "refreshPerformed=$($dependencyRefresh.performed), delegatedToCaller=$($dependencyRefresh.delegatedToCaller), failedSteps=$($dependencyRefreshFailedSteps.Count), timedOutSteps=$($dependencyRefreshTimedOutSteps.Count), childTimeoutSeconds=$ChildTimeoutSeconds" `
    -Commands $dependencyRefreshCommands

$ownerOnboarding = $reports.ownerOnboarding
$ownerOnboardingStatus = Get-DeploymentStatus -Report $ownerOnboarding
$flowChainRpcIsOurs = Get-DeploymentProp -Object $ownerOnboarding -Name "flowChainRpcIsOurs" -Default $false
$thirdPartyFlowChainRpcProviderNeeded = Get-DeploymentProp -Object $ownerOnboarding -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$publicRpcRequiresOwnerPublicEdge = Get-DeploymentProp -Object $ownerOnboarding -Name "publicRpcRequiresOwnerPublicEdge" -Default $false
$base8453RpcIsExternalChainDependency = Get-DeploymentProp -Object $ownerOnboarding -Name "base8453RpcIsExternalChainDependency" -Default $false
$ownerOnboardingLocalEnvFileSupported = Get-DeploymentProp -Object $ownerOnboarding -Name "localEnvFileSupported" -Default $false
$ownerOnboardingReady = ($ownerOnboardingStatus -eq "passed") `
    -and ($flowChainRpcIsOurs -eq $true) `
    -and ($thirdPartyFlowChainRpcProviderNeeded -eq $false) `
    -and ($publicRpcRequiresOwnerPublicEdge -eq $true) `
    -and ($base8453RpcIsExternalChainDependency -eq $true) `
    -and ($ownerOnboardingLocalEnvFileSupported -eq $true) `
    -and ((Get-DeploymentProp -Object $ownerOnboarding -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $ownerOnboarding -Name "noSecrets" -Default $false) -eq $true)
Add-DeploymentItem -Items $items -Id "owner-onboarding-packet" `
    -Requirement "Owner onboarding clearly distinguishes repo-owned FlowChain RPC from the external Base 8453 RPC dependency without values and documents local owner env-file loading." `
    -Status $(if ($ownerOnboardingReady) { "passed" } else { "failed" }) `
    -Evidence "onboardingStatus=$ownerOnboardingStatus, flowChainRpcIsOurs=$flowChainRpcIsOurs, publicRpcRequiresOwnerPublicEdge=$publicRpcRequiresOwnerPublicEdge, base8453RpcIsExternalChainDependency=$base8453RpcIsExternalChainDependency, localEnvFileSupported=$ownerOnboardingLocalEnvFileSupported" `
    -Commands @("npm run flowchain:owner:onboarding")

$ownerSignupChecklist = $reports.ownerSignupChecklist
$ownerSignupChecklistStatus = Get-DeploymentStatus -Report $ownerSignupChecklist
$ownerSignupExternalCount = [int](Get-DeploymentProp -Object $ownerSignupChecklist -Name "externalSignupCount" -Default 0)
$ownerSignupItemCount = [int](Get-DeploymentProp -Object $ownerSignupChecklist -Name "itemCount" -Default 0)
$ownerSignupMissingCoverageCount = @((Get-DeploymentProp -Object $ownerSignupChecklist -Name "missingChecklistCoverage" -Default @())).Count
$ownerSignupRepoOwned = Get-DeploymentProp -Object $ownerSignupChecklist -Name "flowChainRpcIsRepoOwned" -Default $false
$ownerSignupThirdPartyFlowChainRpcNeeded = Get-DeploymentProp -Object $ownerSignupChecklist -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$ownerSignupLocalEnvFileSupported = Get-DeploymentProp -Object $ownerSignupChecklist -Name "localEnvFileSupported" -Default $false
$ownerSignupChecklistReady = ($ownerSignupChecklistStatus -eq "passed") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:owner:signup-checklist") `
    -and ($ownerSignupItemCount -ge 8) `
    -and ($ownerSignupExternalCount -ge 3) `
    -and ($ownerSignupMissingCoverageCount -eq 0) `
    -and ($ownerSignupRepoOwned -eq $true) `
    -and ($ownerSignupThirdPartyFlowChainRpcNeeded -eq $false) `
    -and ($ownerSignupLocalEnvFileSupported -eq $true) `
    -and ((Get-DeploymentProp -Object $ownerSignupChecklist -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $ownerSignupChecklist -Name "noSecrets" -Default $false) -eq $true)
Add-DeploymentItem -Items $items -Id "owner-signup-checklist" `
    -Requirement "Owner signup checklist maps every public RPC, tester write gateway, backup, and Base 8453 bridge value to the exact thing the owner must get without requesting secrets in chat." `
    -Status $(if ($ownerSignupChecklistReady) { "passed" } else { "failed" }) `
    -Evidence "signupStatus=$ownerSignupChecklistStatus, itemCount=$ownerSignupItemCount, externalSignupCount=$ownerSignupExternalCount, missingCoverage=$ownerSignupMissingCoverageCount, repoOwned=$ownerSignupRepoOwned, localEnvFileSupported=$ownerSignupLocalEnvFileSupported" `
    -Commands @("npm run flowchain:owner:signup-checklist")

$ownerEnvTemplate = $reports.ownerEnvTemplate
$ownerEnvTemplateStatus = Get-DeploymentStatus -Report $ownerEnvTemplate
$ownerEnvTemplateGitIgnored = Get-DeploymentProp -Object $ownerEnvTemplate -Name "pathIsGitIgnored" -Default $false
$ownerEnvTemplateIncludesRequired = Get-DeploymentProp -Object $ownerEnvTemplate -Name "templateIncludesAllRequiredEnvNames" -Default $false
$ownerEnvTemplateRequiredCount = [int](Get-DeploymentProp -Object $ownerEnvTemplate -Name "requiredEnvNameCount" -Default 0)
$ownerEnvTemplateOptionalCount = @((Get-DeploymentProp -Object $ownerEnvTemplate -Name "optionalEnvNames" -Default @())).Count
$ownerEnvTemplateReady = ($ownerEnvTemplateStatus -eq "passed") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:owner-env:template") `
    -and ($ownerEnvTemplateGitIgnored -eq $true) `
    -and ($ownerEnvTemplateIncludesRequired -eq $true) `
    -and (($ownerEnvTemplateRequiredCount + $ownerEnvTemplateOptionalCount) -eq $knownOwnerInputs.Count) `
    -and ((Get-DeploymentProp -Object $ownerEnvTemplate -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $ownerEnvTemplate -Name "noSecrets" -Default $false) -eq $true)
Add-DeploymentItem -Items $items -Id "owner-env-template" `
    -Requirement "Owner env-file setup has a command-generated local scaffold whose target path is git-ignored before owner values are added." `
    -Status $(if ($ownerEnvTemplateReady) { "passed" } else { "failed" }) `
    -Evidence "templateStatus=$ownerEnvTemplateStatus, pathIsGitIgnored=$ownerEnvTemplateGitIgnored, requiredEnvNameCount=$ownerEnvTemplateRequiredCount, optionalEnvNameCount=$ownerEnvTemplateOptionalCount, includesAllRequired=$ownerEnvTemplateIncludesRequired" `
    -Commands @("npm run flowchain:owner-env:template")

$publicRpcEdgeTemplate = $reports.publicRpcEdgeTemplate
$publicRpcEdgeTemplateStatus = Get-DeploymentStatus -Report $publicRpcEdgeTemplate
$edgeTemplateReady = Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "edgeTemplateReady" -Default $false
$edgeTemplateRepoOwned = Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "flowChainRpcIsRepoOwned" -Default $false
$edgeTemplateThirdPartyNeeded = Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$edgeTemplateRequiresTls = Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "requiresTlsTermination" -Default $false
$edgeTemplateRequiresRateLimit = Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "requiresRateLimit" -Default $false
$edgeTemplateForwardsOrigin = Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "forwardsOriginForCors" -Default $false
$publicRpcDeploymentBundle = $reports.publicRpcDeploymentBundle
$publicRpcDeploymentBundleStatus = Get-DeploymentStatus -Report $publicRpcDeploymentBundle
$deploymentBundleChecks = Get-DeploymentProp -Object $publicRpcDeploymentBundle -Name "checks"
$deploymentBundleReady = $publicRpcDeploymentBundleStatus -eq "passed" `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "nginxTemplateWritten" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "windowsNginxPreflightScriptWritten" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "windowsNginxPreflightTokensPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "includesWindowsNginxConfigTest" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "ownerEnvExampleWritten" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "verifyRunbookWritten" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $deploymentBundleChecks -Name "rollbackRunbookWritten" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcDeploymentBundle -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $publicRpcDeploymentBundle -Name "noSecrets" -Default $false) -eq $true)
$publicRpcEdgeTemplateReady = ($publicRpcEdgeTemplateStatus -eq "passed") `
    -and ($edgeTemplateReady -eq $true) `
    -and ($edgeTemplateRepoOwned -eq $true) `
    -and ($edgeTemplateThirdPartyNeeded -eq $false) `
    -and ($edgeTemplateRequiresTls -eq $true) `
    -and ($edgeTemplateRequiresRateLimit -eq $true) `
    -and ($edgeTemplateForwardsOrigin -eq $true) `
    -and ((Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $publicRpcEdgeTemplate -Name "noSecrets" -Default $false) -eq $true)
Add-DeploymentItem -Items $items -Id "public-rpc-edge-template" `
    -Requirement "Public RPC exposure has a no-values owner edge template and deployment bundle for HTTPS reverse proxying, rate limiting, verification, and rollback." `
    -Status $(if ($publicRpcEdgeTemplateReady -and $deploymentBundleReady) { "passed" } else { "failed" }) `
    -Evidence "edgeTemplateStatus=$publicRpcEdgeTemplateStatus, bundleStatus=$publicRpcDeploymentBundleStatus, repoOwned=$edgeTemplateRepoOwned, requiresTls=$edgeTemplateRequiresTls, requiresRateLimit=$edgeTemplateRequiresRateLimit, forwardsOrigin=$edgeTemplateForwardsOrigin" `
    -Commands @("npm run flowchain:public-rpc:edge-template", "npm run flowchain:public-rpc:deployment-bundle")

$service = $reports.serviceStatus
$serviceStatus = Get-DeploymentStatus -Report $service
$bind = Get-DeploymentProp -Object $service -Name "bind"
$chain = Get-DeploymentProp -Object $service -Name "chain"
$node = Get-DeploymentProp -Object $service -Name "node"
$controlPlane = Get-DeploymentProp -Object $service -Name "controlPlane"
$serviceProfile = Get-DeploymentProp -Object $service -Name "serviceProfile"
$latestHeight = [string](Get-DeploymentProp -Object $chain -Name "latestHeight" -Default "")
$finalizedHeight = [string](Get-DeploymentProp -Object $chain -Name "finalizedHeight" -Default "")
$privateBind = (Get-DeploymentProp -Object $bind -Name "localDefaultPrivate" -Default $false) -eq $true
$serviceReady = ($serviceStatus -eq "passed") `
    -and ($privateBind -eq $true) `
    -and ([string](Get-DeploymentProp -Object $node -Name "status") -eq "running") `
    -and ([string](Get-DeploymentProp -Object $controlPlane -Name "status") -eq "running") `
    -and ((Get-DeploymentProp -Object $serviceProfile -Name "liveProfile" -Default $false) -eq $true) `
    -and ($latestHeight -match '^\d+$') `
    -and ($finalizedHeight -match '^\d+$')
Add-DeploymentItem -Items $items -Id "private-service-origin" `
    -Requirement "The public deployment origin service is running privately in live profile before any owner TLS edge is considered shareable." `
    -Status $(if ($serviceReady) { "passed" } else { "failed" }) `
    -Evidence "serviceStatus=$serviceStatus, privateBind=$privateBind, latestHeight=$latestHeight, finalizedHeight=$finalizedHeight" `
    -Commands @("npm run flowchain:service:status")

$monitor = $reports.serviceMonitor
$monitorStatus = Get-DeploymentStatus -Report $monitor
$monitorAdvanced = Get-DeploymentProp -Object $monitor -Name "heightAdvanced" -Default $false
$monitorSamples = [int](Get-DeploymentProp -Object $monitor -Name "sampleCount" -Default 0)
Add-DeploymentItem -Items $items -Id "pre-share-monitoring" `
    -Requirement "The deployment has recent service-monitor evidence that block height advances over multiple samples." `
    -Status $(if (($monitorStatus -eq "passed") -and ($monitorAdvanced -eq $true) -and ($monitorSamples -ge 2)) { "passed" } else { "failed" }) `
    -Evidence "monitorStatus=$monitorStatus, samples=$monitorSamples, heightAdvanced=$monitorAdvanced" `
    -Commands @("npm run flowchain:service:monitor")

$supervisorValidation = $reports.serviceSupervisorValidation
$supervisorValidationStatus = Get-DeploymentStatus -Report $supervisorValidation
$supervisorRestartAttempts = [int](Get-DeploymentProp -Object $supervisorValidation -Name "restartAttempts" -Default 0)
Add-DeploymentItem -Items $items -Id "service-autorecovery" `
    -Requirement "The owner service has an autorecovery supervisor and an isolated recovery drill proving control-plane restart without touching live state." `
    -Status $(if (($supervisorValidationStatus -eq "passed") -and ($supervisorRestartAttempts -ge 1)) { "passed" } else { "failed" }) `
    -Evidence "supervisorValidation=$supervisorValidationStatus, restartAttempts=$supervisorRestartAttempts" `
    -Commands @("npm run flowchain:service:supervisor:validate", "npm run flowchain:service:supervisor -- -IntervalSeconds 30 -MaxRestartAttempts 3")

$serviceInstallValidation = $reports.serviceInstallValidation
$serviceInstallValidationStatus = Get-DeploymentStatus -Report $serviceInstallValidation
$serviceInstallChecks = Get-DeploymentProp -Object $serviceInstallValidation -Name "checks"
$serviceInstallReady = ($serviceInstallValidationStatus -eq "passed") `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "packageScriptsPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "planCommandPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "planDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "schedulerCmdletsAvailable" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "scheduledTaskActionSupportsWorkingDirectory" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "actionUsesSupervisor" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "liveProfileDefault" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "commandOmitsNonLiveProfile" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallChecks -Name "commandsPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $serviceInstallValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $serviceInstallValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:service:install:windows") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:service:install:validate")
Add-DeploymentItem -Items $items -Id "service-install-automation" `
    -Requirement "The owner host has a no-secret Windows install, status, and uninstall path for registering the live supervisor as a reboot-persistent scheduled task." `
    -Status $(if ($serviceInstallReady) { "passed" } else { "failed" }) `
    -Evidence "serviceInstallValidation=$serviceInstallValidationStatus, planDidNotMutate=$(Get-DeploymentProp -Object $serviceInstallChecks -Name "planDidNotMutate"), liveProfileDefault=$(Get-DeploymentProp -Object $serviceInstallChecks -Name "liveProfileDefault"), commandsPresent=$(Get-DeploymentProp -Object $serviceInstallChecks -Name "commandsPresent")" `
    -Commands @("npm run flowchain:service:install:validate", "npm run flowchain:service:install:windows -- -Action Plan", "npm run flowchain:service:install:windows -- -Action Install", "npm run flowchain:service:install:windows -- -Action Status", "npm run flowchain:service:install:windows -- -Action Uninstall")

$opsSnapshot = $reports.opsSnapshot
$opsSnapshotStatus = Get-DeploymentStatus -Report $opsSnapshot
$opsCriticalCount = [int](Get-DeploymentProp -Object $opsSnapshot -Name "criticalCount" -Default 999)
$opsBlockedCount = [int](Get-DeploymentProp -Object $opsSnapshot -Name "blockedCount" -Default 0)
Add-DeploymentItem -Items $items -Id "ops-snapshot" `
    -Requirement "Owner deployment has a no-secret ops snapshot that separates critical incidents from expected owner-input blockers and lists incident commands." `
    -Status $(if (($opsSnapshotStatus -in @("passed", "blocked")) -and $opsCriticalCount -eq 0) { "passed" } else { "failed" }) `
    -Evidence "opsSnapshot=$opsSnapshotStatus, criticalCount=$opsCriticalCount, blockedCount=$opsBlockedCount" `
    -Commands @("npm run flowchain:ops:snapshot -- -AllowBlocked")

$opsAlertRules = $reports.opsAlertRules
$opsAlertRulesStatus = Get-DeploymentStatus -Report $opsAlertRules
$opsAlertCriticalRules = [int](Get-DeploymentProp -Object $opsAlertRules -Name "criticalRuleCount" -Default 0)
$opsAlertBlockedRules = [int](Get-DeploymentProp -Object $opsAlertRules -Name "blockedRuleCount" -Default 0)
$opsAlertUnmappedCodes = @((Get-DeploymentProp -Object $opsAlertRules -Name "unmappedCurrentFindingCodes" -Default @()))
Add-DeploymentItem -Items $items -Id "ops-alert-rules" `
    -Requirement "Owner deployment has a no-secret alert rule manifest that maps every current ops finding to operator commands without committing delivery credentials." `
    -Status $(if (($opsAlertRulesStatus -eq "passed") -and ($opsAlertCriticalRules -ge 5) -and ($opsAlertBlockedRules -ge 5) -and ($opsAlertUnmappedCodes.Count -eq 0)) { "passed" } else { "failed" }) `
    -Evidence "alertRules=$opsAlertRulesStatus, criticalRules=$opsAlertCriticalRules, blockedRules=$opsAlertBlockedRules, unmappedCurrentFindingCodes=$($opsAlertUnmappedCodes.Count)" `
    -Commands @("npm run flowchain:ops:alerts -- -AllowBlocked")

$alertInstallValidation = $reports.alertInstallValidation
$alertInstallValidationStatus = Get-DeploymentStatus -Report $alertInstallValidation
$alertInstallChecks = Get-DeploymentProp -Object $alertInstallValidation -Name "checks"
$alertInstallReady = ($alertInstallValidationStatus -eq "passed") `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "packageScriptsPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "planCommandPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "planDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "schedulerCmdletsAvailable" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "scheduledTaskTriggerSupportsRepetition" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "actionUsesAlertsScript" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "hasAllowBlocked" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "scheduledCommandDoesNotDisableRefresh" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallChecks -Name "noExternalDelivery" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $alertInstallValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $alertInstallValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:ops:alerts:install:windows") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:ops:alerts:install:validate")
Add-DeploymentItem -Items $items -Id "ops-alert-schedule-automation" `
    -Requirement "The owner host has a no-secret Windows install, status, and uninstall path for recurring ops snapshot and alert-rule refresh without committed external delivery credentials." `
    -Status $(if ($alertInstallReady) { "passed" } else { "failed" }) `
    -Evidence "alertInstallValidation=$alertInstallValidationStatus, planDidNotMutate=$(Get-DeploymentProp -Object $alertInstallChecks -Name "planDidNotMutate"), hasAllowBlocked=$(Get-DeploymentProp -Object $alertInstallChecks -Name "hasAllowBlocked"), noExternalDelivery=$(Get-DeploymentProp -Object $alertInstallChecks -Name "noExternalDelivery")" `
    -Commands @("npm run flowchain:ops:alerts:install:validate", "npm run flowchain:ops:alerts:install:windows -- -Action Plan", "npm run flowchain:ops:alerts:install:windows -- -Action Install", "npm run flowchain:ops:alerts:install:windows -- -Action Status", "npm run flowchain:ops:alerts:install:windows -- -Action Uninstall")

$ownerInputs = $reports.ownerInputs
$ownerStatus = Get-DeploymentStatus -Report $ownerInputs
$ownerReady = Get-DeploymentProp -Object $ownerInputs -Name "ownerInputReady" -Default $false
$ownerMissingInputs = @((Get-DeploymentProp -Object $ownerInputs -Name "missingEnvNames" -Default @()))
Add-DeploymentItem -Items $items -Id "owner-input-contract" `
    -Requirement "The owner deployment contract validates the required public RPC, tester write gateway, backup, and Base 8453 input names without values." `
    -Status $(if (($ownerStatus -eq "passed") -and ($ownerReady -eq $true)) { "passed" } elseif ($ownerStatus -eq "blocked") { "blocked" } else { "failed" }) `
    -Evidence "ownerInputsStatus=$ownerStatus, ownerInputReady=$ownerReady" `
    -Commands @("npm run flowchain:owner-inputs") `
    -Blockers @($ownerMissingInputs)

$publicRpc = $reports.publicRpc
$publicRpcStatus = Get-DeploymentStatus -Report $publicRpc
$publicRpcReady = Get-DeploymentProp -Object $publicRpc -Name "publicRpcReady" -Default $false
$publicValidation = $reports.publicRpcValidation
$publicValidationStatus = Get-DeploymentStatus -Report $publicValidation
$publicValidationChecks = Get-DeploymentProp -Object $publicValidation -Name "checks"
$publicValidationPassed = ($publicValidationStatus -eq "passed") `
    -and ((Get-DeploymentProp -Object $publicValidationChecks -Name "allowedOriginAccepted" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicValidationChecks -Name "disallowedOriginRejected" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicValidationChecks -Name "rateLimitProbePerformed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicValidationChecks -Name "rateLimitRejected" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicValidationChecks -Name "rateLimitRetryAfterHeaderPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicValidationChecks -Name "responseHygienePassed" -Default $false) -eq $true)
$publicAbuse = $reports.publicRpcAbuseTest
$publicAbuseStatus = Get-DeploymentStatus -Report $publicAbuse
$publicAbuseReady = Get-DeploymentProp -Object $publicAbuse -Name "abuseTestReady" -Default $false
$publicAbuseChecks = Get-DeploymentProp -Object $publicAbuse -Name "checks"
$publicAbuseRequiredChecks = @(
    "serverStarted",
    "allowedOriginAccepted",
    "disallowedOriginRejected",
    "optionsPreflightPassed",
    "unsupportedMediaTypeRejected",
    "malformedJsonRejected",
    "unknownMethodRejected",
    "transactionSubmitRejected",
    "bridgeObservationSubmitRejected",
    "rawJsonGetRejected",
    "bridgeObservationPostAliasRejected",
    "badParamsRejected",
    "emptyBatchRejected",
    "oversizedBatchRejected",
    "oversizedBodyRejected",
    "notificationNoContent",
    "rateLimitRejected",
    "responseHygienePassed"
)
$publicAbuseMissingChecks = @($publicAbuseRequiredChecks | Where-Object { (Get-DeploymentProp -Object $publicAbuseChecks -Name $_ -Default $false) -ne $true })
$publicAbusePassed = ($publicAbuseStatus -eq "passed") `
    -and ($publicAbuseReady -eq $true) `
    -and ($publicAbuseMissingChecks.Count -eq 0) `
    -and ((Get-DeploymentProp -Object $publicAbuse -Name "ownerValuesRequired" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $publicAbuse -Name "noLiveBroadcast" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicAbuse -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $publicAbuse -Name "noSecrets" -Default $false) -eq $true)
Add-DeploymentItem -Items $items -Id "public-rpc-abuse-test" `
    -Requirement "The local public RPC abuse harness proves CORS rejection, media-type rejection, malformed JSON handling, batch/body caps, notification handling, rate limiting, and no-secret response summaries." `
    -Status $(if ($publicAbusePassed) { "passed" } else { "failed" }) `
    -Evidence "abuseStatus=$publicAbuseStatus, abuseReady=$publicAbuseReady, missingChecks=$($publicAbuseMissingChecks.Count)" `
    -Commands @("npm run flowchain:public-rpc:abuse-test")
Add-DeploymentItem -Items $items -Id "public-rpc-edge" `
    -Requirement "The owner TLS edge must pass endpoint, CORS, rate-limit, readiness, and response-hygiene checks before sharing." `
    -Status $(if (($publicRpcStatus -eq "passed") -and ($publicRpcReady -eq $true) -and ($publicValidationPassed -eq $true) -and ($publicAbusePassed -eq $true)) { "passed" } elseif (($publicRpcStatus -eq "blocked") -and ($publicValidationPassed -eq $true) -and ($publicAbusePassed -eq $true)) { "blocked" } else { "failed" }) `
    -Evidence "publicRpcStatus=$publicRpcStatus, publicRpcReady=$publicRpcReady, validationStatus=$publicValidationStatus, validationPassed=$publicValidationPassed, abuseStatus=$publicAbuseStatus, abusePassed=$publicAbusePassed" `
    -Commands @("npm run flowchain:public-rpc:validate", "npm run flowchain:public-rpc:abuse-test", "npm run flowchain:public-rpc:check") `
    -Blockers @("FLOWCHAIN_RPC_PUBLIC_URL", "FLOWCHAIN_RPC_ALLOWED_ORIGINS", "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE", "FLOWCHAIN_RPC_TLS_TERMINATED")

$backup = $reports.backup
$backupStatus = Get-DeploymentStatus -Report $backup
$backupDetails = Get-DeploymentProp -Object $backup -Name "backup"
$backupSnapshotProof = Get-DeploymentProp -Object $backupDetails -Name "snapshotProofStatus" -Default "not-run"
$backupRestoreProof = Get-DeploymentProp -Object $backupDetails -Name "restoreProofStatus" -Default "not-run"
$backupRestoreValidation = $reports.backupRestoreValidation
$backupRestoreValidationStatus = Get-DeploymentStatus -Report $backupRestoreValidation
$backupRestoreValidationChecks = Get-DeploymentProp -Object $backupRestoreValidation -Name "checks"
$backupRestoreValidationRequiredChecks = @(
    "backupCommandPassed",
    "restoreCommandPassed",
    "backupRestoreHashRoundTrip",
    "secondBackupCommandPassed",
    "latestManifestMatchesSecondSnapshot",
    "latestRestoreCommandPassed",
    "latestRestoreUsedLatestSnapshot",
    "restoreTargetsLiveStateProtected",
    "liveStateNonMutationProven",
    "corruptedSnapshotDetected",
    "manifestTamperDetected",
    "missingStateArtifactDetected",
    "missingSnapshotManifestDetected",
    "latestPointerTamperDetected",
    "wrongChainStateMismatchDetected"
)
$backupRestoreValidationMissingChecks = @($backupRestoreValidationRequiredChecks | Where-Object {
    (Get-DeploymentProp -Object $backupRestoreValidationChecks -Name $_ -Default $false) -ne $true
})
$backupRestoreValidationPassed = $backupRestoreValidationStatus -eq "passed" `
    -and ($backupRestoreValidationMissingChecks.Count -eq 0) `
    -and ((Get-DeploymentProp -Object $backupRestoreValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $backupRestoreValidation -Name "noSecrets" -Default $false) -eq $true)
Add-DeploymentItem -Items $items -Id "state-backup-restore-validation" `
    -Requirement "Backup tooling must create manifest-backed state snapshots, restore the latest snapshot safely, reject tampered/missing/stale/wrong-chain backup evidence, and avoid owner secrets." `
    -Status $(if ($backupRestoreValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "validationStatus=$backupRestoreValidationStatus, requiredChecks=$($backupRestoreValidationRequiredChecks.Count), missingChecks=$($backupRestoreValidationMissingChecks.Count)" `
    -Commands @("npm run flowchain:backup:restore:validate")

$backupInstallValidation = $reports.backupInstallValidation
$backupInstallValidationStatus = Get-DeploymentStatus -Report $backupInstallValidation
$backupInstallChecks = Get-DeploymentProp -Object $backupInstallValidation -Name "checks"
$backupInstallReady = ($backupInstallValidationStatus -eq "passed") `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "packageScriptsPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "planCommandPassed" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "planDidNotMutate" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "schedulerCmdletsAvailable" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "scheduledTaskActionSupportsWorkingDirectory" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "actionUsesBackupScript" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "ownerBackupEnvRequired" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "commandOmitsAllowBlocked" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallChecks -Name "commandsPresent" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $backupInstallValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $backupInstallValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:backup:install:windows") `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:backup:install:validate")
Add-DeploymentItem -Items $items -Id "state-backup-schedule-automation" `
    -Requirement "The owner host has a no-secret Windows install, status, and uninstall path for recurring manifest-backed state backups that fail closed without the owner backup path." `
    -Status $(if ($backupInstallReady) { "passed" } else { "failed" }) `
    -Evidence "backupInstallValidation=$backupInstallValidationStatus, planDidNotMutate=$(Get-DeploymentProp -Object $backupInstallChecks -Name "planDidNotMutate"), ownerBackupEnvRequired=$(Get-DeploymentProp -Object $backupInstallChecks -Name "ownerBackupEnvRequired"), commandOmitsAllowBlocked=$(Get-DeploymentProp -Object $backupInstallChecks -Name "commandOmitsAllowBlocked")" `
    -Commands @("npm run flowchain:backup:install:validate", "npm run flowchain:backup:install:windows -- -Action Plan", "npm run flowchain:backup:install:windows -- -Action Install", "npm run flowchain:backup:install:windows -- -Action Status", "npm run flowchain:backup:install:windows -- -Action Uninstall")

Add-DeploymentItem -Items $items -Id "state-backup" `
    -Requirement "The public deployment must prove the configured state backup directory can create a manifest-backed snapshot and restore it in rehearsal." `
    -Status $(if ($backupStatus -eq "passed" -and $backupRestoreValidationPassed) { "passed" } elseif ($backupStatus -eq "blocked" -and $backupRestoreValidationPassed) { "blocked" } else { "failed" }) `
    -Evidence "backupStatus=$backupStatus, snapshotProof=$backupSnapshotProof, restoreProof=$backupRestoreProof" `
    -Commands @("npm run flowchain:backup:create", "npm run flowchain:backup:restore:verify", "npm run flowchain:backup:check") `
    -Blockers @("FLOWCHAIN_RPC_STATE_BACKUP_PATH")

$bridgeLiveStatus = Get-DeploymentStatus -Report $reports.bridgeLive
$bridgeInfraStatus = Get-DeploymentStatus -Report $reports.bridgeInfra
Add-DeploymentItem -Items $items -Id "base8453-bridge-edge" `
    -Requirement "The public deployment must not invite bridge-funded testing until Base 8453 live and infra checks pass with owner guardrails." `
    -Status $(if (($bridgeLiveStatus -eq "passed") -and ($bridgeInfraStatus -eq "passed")) { "passed" } elseif (($bridgeLiveStatus -eq "blocked") -or ($bridgeInfraStatus -eq "blocked")) { "blocked" } else { "failed" }) `
    -Evidence "bridgeLive=$bridgeLiveStatus, bridgeInfra=$bridgeInfraStatus" `
    -Commands @("npm run flowchain:bridge:live:check", "npm run flowchain:bridge:infra:check") `
    -Blockers @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_BASE8453_ASSET_DECIMALS", "FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS")

$bridgeRelayer = $reports.bridgeRelayerOnce
$bridgeRelayerStatus = Get-DeploymentStatus -Report $bridgeRelayer
$bridgeRelayerCounts = Get-DeploymentProp -Object $bridgeRelayer -Name "counts"
$bridgeRelayerTiming = Get-DeploymentProp -Object $bridgeRelayer -Name "timing"
$bridgeRelayerAppliedCount = [int](Get-DeploymentProp -Object $bridgeRelayerCounts -Name "appliedCredits" -Default 0)
$bridgeRelayerLatencyGate = Get-DeploymentProp -Object $bridgeRelayerTiming -Name "latencyGate" -Default "missing"
$bridgeRelayerLatencyReady = $bridgeRelayerAppliedCount -eq 0 -or $bridgeRelayerLatencyGate -eq "passed"
$bridgeRelayerReady = ($bridgeRelayerStatus -eq "passed") `
    -and ((Get-DeploymentProp -Object $bridgeRelayer -Name "broadcasts" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $bridgeRelayer -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $bridgeRelayer -Name "noSecrets" -Default $false) -eq $true) `
    -and $bridgeRelayerLatencyReady `
    -and (Test-DeploymentPackageScript -PackageJson $packageJson -Name "flowchain:bridge:relayer:once")
Add-DeploymentItem -Items $items -Id "base8453-bridge-relayer-queue" `
    -Requirement "The bridge relayer has a no-broadcast one-shot path that checks owner guardrails, observes Base 8453 deposits, filters replays, queues new credits into the running L1, waits for main-state credit evidence, and records handoff-to-spendable latency." `
    -Status $(if ($bridgeRelayerReady) { "passed" } elseif ($bridgeRelayerStatus -eq "blocked") { "blocked" } else { "failed" }) `
    -Evidence "relayer=$bridgeRelayerStatus, observed=$(Get-DeploymentProp -Object $bridgeRelayerCounts -Name 'observedCredits' -Default 0), new=$(Get-DeploymentProp -Object $bridgeRelayerCounts -Name 'newCredits' -Default 0), queued=$(Get-DeploymentProp -Object $bridgeRelayerCounts -Name 'queuedTransactions' -Default 0), applied=$bridgeRelayerAppliedCount, latencyGate=$bridgeRelayerLatencyGate, handoffToSpendableSeconds=$(Get-DeploymentProp -Object $bridgeRelayerTiming -Name 'handoffToSpendableSeconds')" `
    -Commands @("npm run flowchain:bridge:relayer:once") `
    -Blockers @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_BASE8453_ASSET_DECIMALS", "FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS")

$externalTester = $reports.externalTester
$externalPacket = $reports.externalTesterPacket
$externalTesterStatus = Get-DeploymentStatus -Report $externalTester
$externalPacketStatus = Get-DeploymentStatus -Report $externalPacket
$externalSharingReady = Get-DeploymentProp -Object $externalTester -Name "externalSharingReady" -Default $false
$externalTesterChecks = Get-DeploymentProp -Object $externalTester -Name "checks"
$externalTesterNetworkFresh = Get-DeploymentProp -Object $externalTesterChecks -Name "testerWalletNetworkFresh" -Default $false
$externalTesterPublicGatewayReady = Get-DeploymentProp -Object $externalTesterChecks -Name "publicTesterGatewayReady" -Default $false
$externalTesterFaucetRouteValidated = Get-DeploymentProp -Object $externalTesterChecks -Name "publicTesterGatewayFaucetRouteValidated" -Default $false
$packetExecutableSmokeValidated = Get-DeploymentProp -Object $externalPacket -Name "packetExecutableSmokeValidated" -Default $false
$packetSmokeChecks = Get-DeploymentProp -Object $externalPacket -Name "packetSmokeChecks"
$packetTesterFaucet = Get-DeploymentProp -Object $packetSmokeChecks -Name "testerFaucet" -Default $false
$packetTesterCapRejected = Get-DeploymentProp -Object $packetSmokeChecks -Name "testerCapRejected" -Default $false
$localTesterRehearsalReady = Get-DeploymentProp -Object $externalTester -Name "localTesterRehearsalReady" -Default $false
$packetShareable = Get-DeploymentProp -Object $externalPacket -Name "packetShareable" -Default $false
Add-DeploymentItem -Items $items -Id "external-tester-sharing" `
    -Requirement "External tester packet must remain not-shareable until owner public RPC, backup, and bridge gates pass, and it must rely on fresh tester-wallet evidence plus authenticated tester faucet/send gateway smoke." `
    -Status $(if (($externalTesterStatus -eq "passed") -and ($externalPacketStatus -eq "passed") -and ($externalSharingReady -eq $true) -and ($packetShareable -eq $true) -and ($externalTesterNetworkFresh -eq $true) -and ($externalTesterPublicGatewayReady -eq $true) -and ($externalTesterFaucetRouteValidated -eq $true) -and ($packetExecutableSmokeValidated -eq $true) -and ($packetTesterFaucet -eq $true) -and ($packetTesterCapRejected -eq $true)) { "passed" } elseif (($externalTesterStatus -eq "blocked") -and ($externalPacketStatus -eq "blocked") -and ($externalSharingReady -eq $false) -and ($packetShareable -eq $false) -and ($externalTesterNetworkFresh -eq $true) -and ($externalTesterPublicGatewayReady -eq $true) -and ($externalTesterFaucetRouteValidated -eq $true) -and ($packetExecutableSmokeValidated -eq $true) -and ($packetTesterFaucet -eq $true) -and ($packetTesterCapRejected -eq $true)) { "blocked" } else { "failed" }) `
    -Evidence "externalTester=$externalTesterStatus, localTesterRehearsalReady=$localTesterRehearsalReady, testerNetworkFresh=$externalTesterNetworkFresh, publicTesterGatewayReady=$externalTesterPublicGatewayReady, faucetRoute=$externalTesterFaucetRouteValidated, packetSmoke=$packetExecutableSmokeValidated, testerFaucet=$packetTesterFaucet, capRejected=$packetTesterCapRejected, externalSharingReady=$externalSharingReady, packet=$externalPacketStatus, packetShareable=$packetShareable" `
    -Commands @("npm run flowchain:tester:readiness", "npm run flowchain:external-tester:packet") `
    -Blockers @($ownerMissingInputs)

$publicTesterGateway = $reports.publicTesterGateway
$publicTesterGatewayStatus = Get-DeploymentStatus -Report $publicTesterGateway
$publicTesterGatewayReady = ($publicTesterGatewayStatus -eq "passed") `
    -and ((Get-DeploymentProp -Object $publicTesterGateway -Name "testerGatewayConfigured" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicTesterGateway -Name "testerFaucetSchema" -Default "") -eq "flowmemory.control_plane.tester_faucet_result.v0") `
    -and ((Get-DeploymentProp -Object $publicTesterGateway -Name "transferAccepted" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicTesterGateway -Name "capRejected" -Default $false) -eq $true) `
    -and ((Get-DeploymentProp -Object $publicTesterGateway -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-DeploymentProp -Object $publicTesterGateway -Name "noSecrets" -Default $false) -eq $true) `
    -and (Test-DeploymentRoutePresent -Routes (Get-DeploymentProp -Object $publicTesterGateway -Name "routes" -Default @()) -Route "/tester/faucet")
Add-DeploymentItem -Items $items -Id "public-tester-write-gateway" `
    -Requirement "The public deployment has a local production-shaped proof for authenticated tester wallet creation, capped tester faucet funding, capped tester sends, balance settlement, and over-cap rejection." `
    -Status $(if ($publicTesterGatewayReady) { "passed" } else { "failed" }) `
    -Evidence "gatewayStatus=$publicTesterGatewayStatus, testerFaucetSchema=$(Get-DeploymentProp -Object $publicTesterGateway -Name "testerFaucetSchema"), transferAccepted=$(Get-DeploymentProp -Object $publicTesterGateway -Name "transferAccepted"), capRejected=$(Get-DeploymentProp -Object $publicTesterGateway -Name "capRejected")" `
    -Commands @("npm run flowchain:tester:gateway:e2e")

$requiredRollbackScripts = @(
    "flowchain:service:status",
    "flowchain:ops:snapshot",
    "flowchain:service:stop",
    "flowchain:service:restart",
    "flowchain:emergency:stop-local",
    "flowchain:completion:audit",
    "flowchain:public-deployment:contract"
)
$missingRollbackScripts = @($requiredRollbackScripts | Where-Object { -not (Test-DeploymentPackageScript -PackageJson $packageJson -Name $_) })
$rollbackReady = ($missingRollbackScripts.Count -eq 0) `
    -and (Test-Path -LiteralPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-service-stop.ps1")) `
    -and (Test-Path -LiteralPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-emergency-stop-local.ps1"))
Add-DeploymentItem -Items $items -Id "rollback-controls" `
    -Requirement "Owner deployment has explicit status, stop, restart, emergency stop, and re-audit commands before exposure." `
    -Status $(if ($rollbackReady) { "passed" } else { "failed" }) `
    -Evidence "missingRollbackScripts=$($missingRollbackScripts.Count)" `
    -Commands @($requiredRollbackScripts | ForEach-Object { "npm run $_" })

$noSecret = $reports.noSecret
$noSecretStatus = Get-DeploymentStatus -Report $noSecret
Add-DeploymentItem -Items $items -Id "no-secret-no-broadcast" `
    -Requirement "Deployment contract and current readiness reports preserve no-secret, no-env-value, and no-live-broadcast boundaries." `
    -Status $(if ($noSecretStatus -eq "passed") { "passed" } else { "failed" }) `
    -Evidence "noSecretStatus=$noSecretStatus" `
    -Commands @("npm run flowchain:no-secret:scan")

$failedItems = @($items | Where-Object { $_.status -eq "failed" })
$blockedItems = @($items | Where-Object { $_.status -eq "blocked" })
$blockedItemsWithoutBlockers = @($blockedItems | Where-Object { @($_.blockers).Count -eq 0 })
$blockedItemsWithUnknownBlockers = @($blockedItems | Where-Object {
    $itemBlockers = @($_.blockers)
    @($itemBlockers | Where-Object { $_ -notin $knownOwnerInputs }).Count -gt 0
})
$blockedOnlyOnKnownOwnerInputs = ($failedItems.Count -eq 0) `
    -and ($blockedItemsWithoutBlockers.Count -eq 0) `
    -and ($blockedItemsWithUnknownBlockers.Count -eq 0) `
    -and ($unknownMissingEnvNames.Count -eq 0)
$status = if ($failedItems.Count -gt 0) { "failed" } elseif ($blockedItems.Count -gt 0) { "blocked" } else { "passed" }

$operatorCommands = [ordered]@{
    preExposure = @(
        "npm run flowchain:service:status",
        "npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30",
        "npm run flowchain:service:install:validate",
        "npm run flowchain:service:install:windows -- -Action Plan",
        "npm run flowchain:ops:snapshot -- -AllowBlocked",
        "npm run flowchain:ops:alerts -- -AllowBlocked",
        "npm run flowchain:ops:alerts:install:validate",
        "npm run flowchain:ops:alerts:install:windows -- -Action Plan",
        "npm run flowchain:owner:onboarding",
        "npm run flowchain:owner-env:template",
        "npm run flowchain:owner-inputs",
        "npm run flowchain:public-rpc:edge-template",
        "npm run flowchain:public-rpc:deployment-bundle",
        "npm run flowchain:public-rpc:validate",
        "npm run flowchain:public-rpc:abuse-test",
        "npm run flowchain:tester:gateway:e2e",
        "npm run flowchain:public-rpc:check",
        "npm run flowchain:backup:restore:validate",
        "npm run flowchain:backup:install:validate",
        "npm run flowchain:backup:install:windows -- -Action Plan",
        "npm run flowchain:backup:create",
        "npm run flowchain:backup:restore:verify",
        "npm run flowchain:backup:check",
        "npm run flowchain:bridge:live:check",
        "npm run flowchain:bridge:infra:check",
        "npm run flowchain:bridge:relayer:once",
        "npm run flowchain:tester:readiness",
        "npm run flowchain:external-tester:packet",
        "npm run flowchain:completion:audit"
    )
    rollback = @(
        "npm run flowchain:service:status",
        "npm run flowchain:service:install:windows -- -Action Status",
        "npm run flowchain:service:install:windows -- -Action Uninstall",
        "npm run flowchain:backup:install:windows -- -Action Status",
        "npm run flowchain:backup:install:windows -- -Action Uninstall",
        "npm run flowchain:ops:alerts:install:windows -- -Action Status",
        "npm run flowchain:ops:alerts:install:windows -- -Action Uninstall",
        "npm run flowchain:service:stop",
        "npm run flowchain:service:restart -- -LiveProfile",
        "npm run flowchain:emergency:stop-local"
    )
}

$report = [ordered]@{
    schema = "flowchain.public_deployment_contract_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    deploymentReady = $status -eq "passed"
    packetShareable = $packetShareable
    packetExecutableSmokeValidated = $packetExecutableSmokeValidated
    blockedOnlyOnKnownExternalOwnerInputs = $blockedOnlyOnKnownOwnerInputs
    itemCounts = [ordered]@{
        passed = @($items | Where-Object { $_.status -eq "passed" }).Count
        blocked = $blockedItems.Count
        failed = $failedItems.Count
        total = $items.Count
    }
    items = @($items)
    dependencyRefresh = $dependencyRefresh
    missingEnvNames = @($missingEnvNames)
    unknownMissingEnvNames = @($unknownMissingEnvNames)
    knownOwnerInputs = $knownOwnerInputs
    reportPaths = $paths
    operatorCommands = $operatorCommands
    noLiveBroadcast = $true
    envValuesPrinted = $false
    noSecrets = $true
}

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Public Deployment Contract")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Deployment ready: $($report.deploymentReady)")
$markdownLines.Add("Packet shareable: $packetShareable")
$markdownLines.Add("Blocked only on known external owner inputs: $blockedOnlyOnKnownOwnerInputs")
$markdownLines.Add("")
$markdownLines.Add("This file records deployment gates, commands, and env names only. It must not contain owner-provided values.")
$markdownLines.Add("")
$markdownLines.Add("## Dependency Refresh")
$markdownLines.Add("")
$markdownLines.Add("- Performed: $($dependencyRefresh.performed)")
$markdownLines.Add("- Delegated to caller: $($dependencyRefresh.delegatedToCaller)")
$markdownLines.Add("- Child timeout seconds: $ChildTimeoutSeconds")
$markdownLines.Add("- Failed steps: $($dependencyRefreshFailedSteps.Count)")
$markdownLines.Add("- Timed out steps: $($dependencyRefreshTimedOutSteps.Count)")
if ($dependencyRefreshTimedOutSteps.Count -gt 0) {
    foreach ($step in @($dependencyRefreshTimedOutSteps)) {
        $markdownLines.Add("- Timed out: $($step.name)")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Gate Checklist")
$markdownLines.Add("")
$markdownLines.Add("| Requirement | Status | Evidence |")
$markdownLines.Add("| --- | --- | --- |")
foreach ($item in $items) {
    $markdownLines.Add("| $($item.requirement.Replace('|','/')) | $($item.status) | $($item.evidence.Replace('|','/')) |")
}
$markdownLines.Add("")
$markdownLines.Add("## Pre-Exposure Commands")
$markdownLines.Add("")
foreach ($command in @($operatorCommands.preExposure)) {
    $markdownLines.Add("- $command")
}
$markdownLines.Add("")
$markdownLines.Add("## Rollback Commands")
$markdownLines.Add("")
foreach ($command in @($operatorCommands.rollback)) {
    $markdownLines.Add("- $command")
}
$markdownLines.Add("")
$markdownLines.Add("## Remaining Owner Inputs")
$markdownLines.Add("")
if ($missingEnvNames.Count -eq 0) {
    $markdownLines.Add("- None")
}
else {
    foreach ($name in @($missingEnvNames)) {
        $markdownLines.Add("- $name")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Deployment Decision")
$markdownLines.Add("")
if ($status -eq "passed") {
    $markdownLines.Add("All public deployment contract gates are passed. External sharing still requires the owner to distribute endpoint values out of band.")
}
elseif ($status -eq "blocked") {
    $markdownLines.Add("Do not expose or share the public endpoint yet. The deployment contract is fail-closed on the listed owner inputs.")
}
else {
    $markdownLines.Add("Do not expose or share the public endpoint. At least one local deployment contract gate failed.")
}

$reportText = $report | ConvertTo-Json -Depth 18
Assert-FlowChainNoSecretText -Text $reportText -Label "public deployment contract report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "public deployment contract markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain public deployment contract status: $status"
Write-Host "Deployment ready: $($report.deploymentReady)"
Write-Host "Packet shareable: $packetShareable"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($missingEnvNames.Count -gt 0) {
    Write-Host "Missing env names: $((@($missingEnvNames)) -join ', ')"
}

if ($status -eq "passed" -or ($status -eq "blocked" -and $AllowBlocked)) {
    exit 0
}
exit 1
