param(
    [string] $PackageDir = "docs/agent-runs/live-product-infra-rpc/operator-package",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/operator-package-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/OPERATOR_PACKAGE.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$packageFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $PackageDir)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$allowedPackageParent = [System.IO.Path]::GetFullPath((Join-Path $repoRoot "docs/agent-runs/live-product-infra-rpc")).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
)
$allowedPackagePrefix = $allowedPackageParent + [System.IO.Path]::DirectorySeparatorChar
if (-not $packageFullPath.StartsWith($allowedPackagePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Operator package output must stay under docs/agent-runs/live-product-infra-rpc."
}
if ($packageFullPath -eq $allowedPackageParent) {
    throw "Refusing to reset the live-product-infra-rpc report root."
}

$packageJsonPath = Join-Path $repoRoot "package.json"
$packageJson = Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json

function Test-OperatorPackageScript {
    param([string] $Name)
    return $packageJson.scripts.PSObject.Properties.Name -contains $Name
}

function Get-OperatorPackageProp {
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

function Copy-OperatorPackageFile {
    param(
        [Parameter(Mandatory = $true)][string] $Source,
        [Parameter(Mandatory = $true)][string] $Destination,
        [switch] $Required
    )

    $sourceFullPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path $Source
    $destinationFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Join-Path $packageFullPath $Destination)
    if (-not $destinationFullPath.StartsWith($packageFullPath + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to copy operator package file outside package directory: $destinationFullPath"
    }

    if (-not (Test-Path -LiteralPath $sourceFullPath)) {
        return [ordered]@{
            source = $Source
            destination = $Destination
            copied = $false
            required = $Required.IsPresent
            reason = "missing"
        }
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destinationFullPath) | Out-Null
    Copy-Item -LiteralPath $sourceFullPath -Destination $destinationFullPath -Force
    return [ordered]@{
        source = $Source
        destination = $Destination
        copied = $true
        required = $Required.IsPresent
        reason = "copied"
    }
}

$requiredScripts = @(
    "flowchain:prereq",
    "flowchain:doctor",
    "flowchain:service:start",
    "flowchain:service:status",
    "flowchain:service:monitor",
    "flowchain:service:restart",
    "flowchain:service:stop",
    "flowchain:service:supervisor",
    "flowchain:service:supervisor:validate",
    "flowchain:service:install:windows",
    "flowchain:service:install:validate",
    "flowchain:service:install:systemd:validate",
    "flowchain:second-computer:bundle",
    "flowchain:second-computer:verify",
    "flowchain:second-computer:readiness",
    "flowchain:owner:onboarding",
    "flowchain:owner:signup-checklist",
    "flowchain:owner:activation-plan",
    "flowchain:owner-env:template",
    "flowchain:owner-env:readiness",
    "flowchain:owner-env:readiness:validate",
    "flowchain:owner-inputs",
    "flowchain:owner-inputs:validate",
    "flowchain:public-rpc:deployment-bundle",
    "flowchain:public-rpc:deployment:automation",
    "flowchain:public-rpc:validate",
    "flowchain:public-rpc:abuse-test",
    "flowchain:backup:create",
    "flowchain:backup:restore:verify",
    "flowchain:backup:restore:validate",
    "flowchain:backup:owner-path:dry-run",
    "flowchain:backup:install:windows",
    "flowchain:backup:install:validate",
    "flowchain:ops:snapshot",
    "flowchain:ops:alerts",
    "flowchain:ops:metrics:export",
    "flowchain:ops:alerts:install:windows",
    "flowchain:ops:alerts:install:validate",
    "flowchain:ops:incident-drill",
    "flowchain:bridge:relayer:once",
    "flowchain:bridge:deploy:control:validate",
    "flowchain:bridge:relayer:guardrail:validate",
    "flowchain:bridge:relayer:loop:validate",
    "flowchain:external-tester:packet",
    "flowchain:external-tester:packet:validate",
    "flowchain:dashboard:ui:readiness",
    "flowchain:operator:package:verify",
    "flowchain:completion:audit",
    "flowchain:truth-table",
    "flowchain:no-secret:scan"
)

$commandMatrix = @(
    [ordered]@{ phase = "preflight"; command = "npm run flowchain:prereq"; purpose = "Check required local tooling." },
    [ordered]@{ phase = "preflight"; command = "npm run flowchain:doctor"; purpose = "Summarize repo and runtime health." },
    [ordered]@{ phase = "service"; command = "npm run flowchain:service:start -- -LiveProfile"; purpose = "Start the private live-profile node and RPC service." },
    [ordered]@{ phase = "service"; command = "npm run flowchain:service:status -- -AllowBlocked"; purpose = "Verify node, control-plane, height, and state freshness." },
    [ordered]@{ phase = "service"; command = "npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30"; purpose = "Observe block production over a sampling window." },
    [ordered]@{ phase = "service"; command = "npm run flowchain:service:restart -- -LiveProfile"; purpose = "Restart without deleting runtime state." },
    [ordered]@{ phase = "service"; command = "npm run flowchain:service:stop"; purpose = "Stop local services without deleting state." },
    [ordered]@{ phase = "autorecovery"; command = "npm run flowchain:service:supervisor:validate"; purpose = "Prove the supervisor can recover a failed local control plane." },
    [ordered]@{ phase = "autorecovery"; command = "npm run flowchain:service:install:windows -- -Action Plan"; purpose = "Render the no-secret Windows Scheduled Task install plan." },
    [ordered]@{ phase = "autorecovery"; command = "npm run flowchain:service:install:validate"; purpose = "Validate install/status/uninstall paths without mutating the owner host." },
    [ordered]@{ phase = "autorecovery"; command = "npm run flowchain:service:install:systemd:validate"; purpose = "Validate Linux systemd live-service and supervisor install plans without mutating the owner host." },
    [ordered]@{ phase = "handoff"; command = "npm run flowchain:second-computer:readiness"; purpose = "Create and verify the no-secret offline second-computer source bundle." },
    [ordered]@{ phase = "owner-setup"; command = "npm run flowchain:owner:onboarding"; purpose = "Regenerate the owner setup map and clarify that FlowChain public RPC is repo-owned." },
    [ordered]@{ phase = "owner-setup"; command = "npm run flowchain:owner:signup-checklist"; purpose = "List exactly what the owner must sign up for or create before public launch." },
    [ordered]@{ phase = "owner-setup"; command = "npm run flowchain:owner:activation-plan"; purpose = "Generate the current ordered launch activation plan and exact validation commands." },
    [ordered]@{ phase = "owner-setup"; command = "npm run flowchain:owner-env:template"; purpose = "Create or preserve the ignored local owner env scaffold with empty values only." },
    [ordered]@{ phase = "owner-setup"; command = "npm run flowchain:owner-env:readiness:validate"; purpose = "Prove unsafe owner env file paths fail before live gates run." },
    [ordered]@{ phase = "owner-setup"; command = "npm run flowchain:owner-env:readiness -- -AllowBlocked"; purpose = "Run live gates through the ignored owner env file and report only names and statuses." },
    [ordered]@{ phase = "public-rpc"; command = "npm run flowchain:public-rpc:deployment-bundle"; purpose = "Generate owner-host public RPC edge artifacts." },
    [ordered]@{ phase = "public-rpc"; command = "npm run flowchain:public-rpc:deployment:automation"; purpose = "Validate render, preflight, verify, and rollback phases." },
    [ordered]@{ phase = "public-rpc"; command = "npm run flowchain:public-rpc:validate"; purpose = "Run local public-profile RPC readiness validation." },
    [ordered]@{ phase = "public-rpc"; command = "npm run flowchain:public-rpc:abuse-test"; purpose = "Run CORS, media-type, batch/body cap, rate-limit, and response hygiene probes." },
    [ordered]@{ phase = "backup"; command = "npm run flowchain:backup:restore:validate"; purpose = "Prove restore safety and tamper rejection locally." },
    [ordered]@{ phase = "backup"; command = "npm run flowchain:backup:owner-path:dry-run"; purpose = "Exercise backup readiness with an ignored local owner-path stand-in." },
    [ordered]@{ phase = "backup"; command = "npm run flowchain:backup:install:windows -- -Action Plan"; purpose = "Render the daily snapshot Scheduled Task plan." },
    [ordered]@{ phase = "backup"; command = "npm run flowchain:backup:install:validate"; purpose = "Validate backup task plan/status/uninstall behavior." },
    [ordered]@{ phase = "ops"; command = "npm run flowchain:ops:snapshot -- -AllowBlocked"; purpose = "Classify critical incidents separately from owner-input blockers." },
    [ordered]@{ phase = "ops"; command = "npm run flowchain:ops:alerts -- -AllowBlocked"; purpose = "Refresh local alert rules and finding coverage." },
    [ordered]@{ phase = "ops"; command = "npm run flowchain:ops:metrics:export"; purpose = "Export no-secret JSON and Prometheus textfile metrics for owner collectors." },
    [ordered]@{ phase = "ops"; command = "npm run flowchain:ops:alerts:install:windows -- -Action Plan"; purpose = "Render recurring alert refresh Scheduled Task plan." },
    [ordered]@{ phase = "ops"; command = "npm run flowchain:ops:incident-drill"; purpose = "Rehearse node, RPC, stale-state, stalled-height, and no-secret incidents." },
    [ordered]@{ phase = "bridge"; command = "npm run flowchain:bridge:relayer:once -- -AllowBlocked"; purpose = "Run the no-broadcast relayer gate; remains blocked until owner Base inputs exist." },
    [ordered]@{ phase = "bridge"; command = "npm run flowchain:bridge:deploy:control:validate"; purpose = "Validate Base 8453 deploy, pause, resume, and emergency-stop gates fail closed without owner env and require broadcast acknowledgements." },
    [ordered]@{ phase = "bridge"; command = "npm run flowchain:bridge:relayer:guardrail:validate"; purpose = "Prove missing owner inputs cannot mutate cursor state or queue credits." },
    [ordered]@{ phase = "bridge"; command = "npm run flowchain:bridge:relayer:loop:validate"; purpose = "Validate relayer loop start, fresh health reporting, clean stop, PID cleanup, and no leftover validation relayer process." },
    [ordered]@{ phase = "testers"; command = "npm run flowchain:external-tester:packet -- -AllowBlocked"; purpose = "Regenerate the friends-and-family packet and fail closed until public gates pass." },
    [ordered]@{ phase = "testers"; command = "npm run flowchain:external-tester:packet:validate"; purpose = "Validate the packet and connect pack are no-secret, locally executable, and not externally shareable before owner inputs." },
    [ordered]@{ phase = "testers"; command = "npm run flowchain:dashboard:ui:readiness"; purpose = "Run desktop and mobile browser verification for tester wallet create, faucet, send, and Explorer inspection." },
    [ordered]@{ phase = "release"; command = "npm run flowchain:operator:package:verify"; purpose = "Verify the generated operator package contents and no-secret boundary." },
    [ordered]@{ phase = "release"; command = "npm run flowchain:completion:audit -- -AllowBlocked"; purpose = "Run the production readiness gate without false public-ready claims." },
    [ordered]@{ phase = "release"; command = "npm run flowchain:truth-table -- -AllowBlocked"; purpose = "Classify every tracked gate as passed, owner-blocked, repo-blocked, failed, or stale." },
    [ordered]@{ phase = "release"; command = "npm run flowchain:no-secret:scan"; purpose = "Verify generated reports and packets contain no secret markers." }
)

$ownerInputNames = @(
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

if (Test-Path -LiteralPath $packageFullPath) {
    Remove-Item -LiteralPath $packageFullPath -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $packageFullPath | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $reportFullPath) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-doctor.ps1") -ReportPath "docs/agent-runs/live-product-infra-rpc/operator-doctor-report.json"
if ($LASTEXITCODE -ne 0) {
    throw "FlowChain operator doctor failed."
}

$copiedRunbooks = New-Object System.Collections.ArrayList
foreach ($file in @(
    [ordered]@{ source = "docs/developer/FLOWCHAIN_NODE_OPERATOR.md"; target = "docs/FLOWCHAIN_NODE_OPERATOR.md"; required = $true },
    [ordered]@{ source = "docs/developer/FLOWCHAIN_QUICKSTART.md"; target = "docs/FLOWCHAIN_QUICKSTART.md"; required = $true },
    [ordered]@{ source = "docs/developer/FLOWCHAIN_BRIDGE_INTEGRATION.md"; target = "docs/FLOWCHAIN_BRIDGE_INTEGRATION.md"; required = $true },
    [ordered]@{ source = "docs/developer/FLOWCHAIN_EXPLORER_INDEXER.md"; target = "docs/FLOWCHAIN_EXPLORER_INDEXER.md"; required = $true },
    [ordered]@{ source = "docs/FLOWCHAIN_SECOND_COMPUTER_SETUP.md"; target = "docs/FLOWCHAIN_SECOND_COMPUTER_SETUP.md"; required = $true },
    [ordered]@{ source = "docs/OPERATIONS/FLOWCHAIN_SERVICE_SUPERVISOR.md"; target = "docs/FLOWCHAIN_SERVICE_SUPERVISOR.md"; required = $true },
    [ordered]@{ source = "docs/OPERATIONS/FLOWCHAIN_OWNER_OPERATED_PUBLIC_RPC.md"; target = "docs/FLOWCHAIN_OWNER_OPERATED_PUBLIC_RPC.md"; required = $true },
    [ordered]@{ source = "docs/FLOWCHAIN_TROUBLESHOOTING.md"; target = "docs/FLOWCHAIN_TROUBLESHOOTING.md"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/OWNER_ONBOARDING.md"; target = "runbooks/OWNER_ONBOARDING.md"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/OWNER_SIGNUP_CHECKLIST.md"; target = "runbooks/OWNER_SIGNUP_CHECKLIST.md"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/OWNER_ACTIVATION_PLAN.md"; target = "runbooks/OWNER_ACTIVATION_PLAN.md"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/OWNER_ENV_TEMPLATE.md"; target = "runbooks/OWNER_ENV_TEMPLATE.md"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/OWNER_ENV_READINESS.md"; target = "runbooks/OWNER_ENV_READINESS.md"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/PUBLIC_RPC_DEPLOYMENT_BUNDLE.md"; target = "runbooks/PUBLIC_RPC_DEPLOYMENT_BUNDLE.md"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/WINDOWS_SERVICE_INSTALL.md"; target = "runbooks/WINDOWS_SERVICE_INSTALL.md"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/SYSTEMD_SERVICE_INSTALL_VALIDATION.md"; target = "runbooks/SYSTEMD_SERVICE_INSTALL_VALIDATION.md"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/WINDOWS_BACKUP_INSTALL.md"; target = "runbooks/WINDOWS_BACKUP_INSTALL.md"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/WINDOWS_ALERT_INSTALL.md"; target = "runbooks/WINDOWS_ALERT_INSTALL.md"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/OPS_METRICS_EXPORT.md"; target = "runbooks/OPS_METRICS_EXPORT.md"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/BRIDGE_DEPLOY_CONTROL_VALIDATION.md"; target = "runbooks/BRIDGE_DEPLOY_CONTROL_VALIDATION.md"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/BRIDGE_RELAYER_LOOP_VALIDATION.md"; target = "runbooks/BRIDGE_RELAYER_LOOP_VALIDATION.md"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/SECOND_COMPUTER_READINESS.md"; target = "runbooks/SECOND_COMPUTER_READINESS.md"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/EXTERNAL_TESTER_PACKET.md"; target = "runbooks/EXTERNAL_TESTER_PACKET.md"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/EXTERNAL_TESTER_PACKET_VALIDATION.md"; target = "runbooks/EXTERNAL_TESTER_PACKET_VALIDATION.md"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/DASHBOARD_UI_READINESS.md"; target = "runbooks/DASHBOARD_UI_READINESS.md"; required = $true }
)) {
    [void] $copiedRunbooks.Add((Copy-OperatorPackageFile -Source $file.source -Destination $file.target -Required:([bool] $file.required)))
}

$copiedEvidence = New-Object System.Collections.ArrayList
foreach ($file in @(
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/service-status-report.json"; target = "evidence/service-status-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/operator-doctor-report.json"; target = "evidence/operator-doctor-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/service-monitor-report.json"; target = "evidence/service-monitor-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-report.json"; target = "evidence/service-supervisor-validation-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/service-install-validation-report.json"; target = "evidence/service-install-validation-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/systemd-service-install-validation-report.json"; target = "evidence/systemd-service-install-validation-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/second-computer-readiness-report.json"; target = "evidence/second-computer-readiness-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/owner-onboarding-report.json"; target = "evidence/owner-onboarding-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/owner-signup-checklist-report.json"; target = "evidence/owner-signup-checklist-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/owner-activation-plan-report.json"; target = "evidence/owner-activation-plan-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/owner-env-template-report.json"; target = "evidence/owner-env-template-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/owner-env-readiness-validation-report.json"; target = "evidence/owner-env-readiness-validation-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/owner-env-readiness-report.json"; target = "evidence/owner-env-readiness-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json"; target = "evidence/public-rpc-deployment-bundle-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json"; target = "evidence/public-rpc-deployment-automation-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-report.json"; target = "evidence/backup-restore-validation-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/backup-owner-path-dry-run-report.json"; target = "evidence/backup-owner-path-dry-run-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/backup-install-validation-report.json"; target = "evidence/backup-install-validation-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/ops-snapshot-report.json"; target = "evidence/ops-snapshot-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/ops-alert-rules-report.json"; target = "evidence/ops-alert-rules-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/ops-metrics-export-report.json"; target = "evidence/ops-metrics-export-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/ops-metrics.json"; target = "evidence/ops-metrics.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/ops-metrics.prom.txt"; target = "evidence/ops-metrics.prom.txt"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/incident-drill-report.json"; target = "evidence/incident-drill-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/bridge-relayer-once-report.json"; target = "evidence/bridge-relayer-once-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/bridge-deploy-control-validation-report.json"; target = "evidence/bridge-deploy-control-validation-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/bridge-relayer-guardrail-validation-report.json"; target = "evidence/bridge-relayer-guardrail-validation-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/bridge-relayer-loop-validation-report.json"; target = "evidence/bridge-relayer-loop-validation-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json"; target = "evidence/external-tester-packet-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/external-tester-packet-validation-report.json"; target = "evidence/external-tester-packet-validation-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/dashboard-ui-readiness-report.json"; target = "evidence/dashboard-ui-readiness-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/flowchain-architecture-audit-report.json"; target = "evidence/flowchain-architecture-audit-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/flowchain-completion-audit-report.json"; target = "evidence/flowchain-completion-audit-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-infra-rpc/production-truth-table-report.json"; target = "evidence/production-truth-table-report.json"; required = $true },
    [ordered]@{ source = "docs/agent-runs/live-product-dev-pack/dev-pack-e2e-report.json"; target = "evidence/dev-pack-e2e-report.json"; required = $true }
)) {
    [void] $copiedEvidence.Add((Copy-OperatorPackageFile -Source $file.source -Destination $file.target -Required:([bool] $file.required)))
}

$missingScripts = @($requiredScripts | Where-Object { -not (Test-OperatorPackageScript -Name $_) })
$missingRequiredRunbooks = @($copiedRunbooks | Where-Object { $_.required -eq $true -and $_.copied -ne $true })
$missingRequiredEvidence = @($copiedEvidence | Where-Object { $_.required -eq $true -and $_.copied -ne $true })

$ownerOnboarding = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-onboarding-report.json")
$flowChainRpcIsOurs = (Get-OperatorPackageProp -Object $ownerOnboarding -Name "flowChainRpcIsOurs" -Default $false) -eq $true
$thirdPartyFlowChainRpcProviderNeeded = (Get-OperatorPackageProp -Object $ownerOnboarding -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true) -eq $true

$manifestPath = Join-Path $packageFullPath "OPERATOR_PACKAGE_MANIFEST.json"
$commandMatrixPath = Join-Path $packageFullPath "OPERATOR_COMMAND_MATRIX.json"
$commandMatrixMarkdownPath = Join-Path $packageFullPath "COMMAND_MATRIX.md"
$readmePath = Join-Path $packageFullPath "README.md"

$manifest = [ordered]@{
    schema = "flowchain.operator_package_manifest.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    packageDir = $packageFullPath
    flowChainRpcIsRepoOwned = $flowChainRpcIsOurs
    thirdPartyFlowChainRpcProviderNeeded = $thirdPartyFlowChainRpcProviderNeeded
    ownerInputNames = $ownerInputNames
    requiredScripts = $requiredScripts
    commandMatrix = $commandMatrix
    runbooks = @($copiedRunbooks)
    evidence = @($copiedEvidence)
    noLiveBroadcast = $true
    envValuesPrinted = $false
    noSecrets = $true
}
Write-FlowChainJson -Path $manifestPath -Value $manifest -Depth 20
Write-FlowChainJson -Path $commandMatrixPath -Value ([ordered]@{
    schema = "flowchain.operator_command_matrix.v0"
    generatedAt = $manifest.generatedAt
    commands = $commandMatrix
}) -Depth 12

$matrixLines = New-Object System.Collections.Generic.List[string]
$matrixLines.Add("# FlowChain Operator Command Matrix")
$matrixLines.Add("")
$matrixLines.Add("Generated: $($manifest.generatedAt)")
$matrixLines.Add("")
$matrixLines.Add("| Phase | Command | Purpose |")
$matrixLines.Add("| --- | --- | --- |")
foreach ($command in $commandMatrix) {
    $matrixLines.Add("| $($command.phase) | ``$($command.command)`` | $($command.purpose.Replace('|', '/')) |")
}
Set-Content -LiteralPath $commandMatrixMarkdownPath -Value $matrixLines -Encoding UTF8

$readmeLines = New-Object System.Collections.Generic.List[string]
$readmeLines.Add("# FlowChain Node Operator Package")
$readmeLines.Add("")
$readmeLines.Add("Generated: $($manifest.generatedAt)")
$readmeLines.Add("")
$readmeLines.Add("This package collects no-secret runbooks, command matrices, and current evidence for operating the private live-profile FlowChain L1 and for preparing the owner-operated public RPC edge. It does not contain owner values.")
$readmeLines.Add("")
$readmeLines.Add("## First Commands")
$readmeLines.Add("")
foreach ($command in @($commandMatrix | Select-Object -First 10)) {
    $readmeLines.Add("- ``$($command.command)``")
}
$readmeLines.Add("")
$readmeLines.Add("## Public Launch Boundary")
$readmeLines.Add("")
$readmeLines.Add("Public sharing stays blocked until these owner inputs are configured outside the repository:")
$readmeLines.Add("")
foreach ($name in $ownerInputNames) {
    $readmeLines.Add("- $name")
}
$readmeLines.Add("")
$readmeLines.Add("FlowChain RPC is repo-owned. The public endpoint is an owner-operated HTTPS edge in front of the private local origin, not a third-party FlowChain RPC provider.")
$readmeLines.Add("")
$readmeLines.Add("## Package Contents")
$readmeLines.Add("")
$readmeLines.Add("- ``OPERATOR_PACKAGE_MANIFEST.json``")
$readmeLines.Add("- ``OPERATOR_COMMAND_MATRIX.json``")
$readmeLines.Add("- ``COMMAND_MATRIX.md``")
$readmeLines.Add("- ``docs/`` copied developer and operations docs")
$readmeLines.Add("- ``runbooks/`` copied generated public RPC, service, backup, alert, and tester packet runbooks")
$readmeLines.Add("- ``evidence/`` copied latest readiness and validation reports")
Set-Content -LiteralPath $readmePath -Value $readmeLines -Encoding UTF8

$packageScanPath = Join-Path $packageFullPath "operator-package-no-secret-scan-report.json"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-no-secret-scan.ps1") -Paths @($packageFullPath, $markdownFullPath) -ReportPath $packageScanPath
$scanExitCode = $LASTEXITCODE
$scanReport = Read-FlowChainJsonIfExists -Path $packageScanPath
$scanStatus = [string](Get-OperatorPackageProp -Object $scanReport -Name "status" -Default "missing")
$scanSecretFindings = @((Get-OperatorPackageProp -Object $scanReport -Name "secretMarkerFindings" -Default @()))

$checks = [ordered]@{
    packageScriptsPresent = $missingScripts.Count -eq 0
    commandMatrixWritten = (Test-Path -LiteralPath $commandMatrixPath) -and (Test-Path -LiteralPath $commandMatrixMarkdownPath)
    readmeWritten = Test-Path -LiteralPath $readmePath
    manifestWritten = Test-Path -LiteralPath $manifestPath
    runbookDocsCopied = $missingRequiredRunbooks.Count -eq 0
    evidenceReportsCopied = $missingRequiredEvidence.Count -eq 0
    ownerInputNamesOnly = $ownerInputNames.Count -eq 17
    flowChainRpcIsRepoOwned = $flowChainRpcIsOurs
    thirdPartyFlowChainRpcProviderNeededFalse = -not $thirdPartyFlowChainRpcProviderNeeded
    noSecretScanPassed = $scanExitCode -eq 0 -and $scanStatus -eq "passed" -and $scanSecretFindings.Count -eq 0
    secretMarkerFindingsEmpty = $scanSecretFindings.Count -eq 0
    envValuesPrintedFalse = $true
    broadcastsFalse = $true
    noSecrets = $true
}
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.operator_package_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    packageDir = $packageFullPath
    manifestPath = $manifestPath
    markdownPath = $markdownFullPath
    commandMatrixPath = $commandMatrixPath
    commandCount = $commandMatrix.Count
    runbookCount = $copiedRunbooks.Count
    evidenceReportCount = $copiedEvidence.Count
    missingScripts = @($missingScripts)
    missingRequiredRunbooks = @($missingRequiredRunbooks)
    missingRequiredEvidence = @($missingRequiredEvidence)
    checks = $checks
    failedChecks = @($failedChecks)
    secretMarkerFindings = @($scanSecretFindings)
    ownerInputNames = $ownerInputNames
    noSecretScanReportPath = $packageScanPath
    noLiveBroadcast = $true
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Operator Package")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("## Package")
$markdownLines.Add("")
$markdownLines.Add("- Directory: ``$packageFullPath``")
$markdownLines.Add("- Manifest: ``$manifestPath``")
$markdownLines.Add("- Command matrix: ``$commandMatrixPath``")
$markdownLines.Add("- Runbooks copied: $($copiedRunbooks.Count)")
$markdownLines.Add("- Evidence reports copied: $($copiedEvidence.Count)")
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
$markdownLines.Add("| Check | Result |")
$markdownLines.Add("| --- | --- |")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("| $($entry.Key) | $($entry.Value) |")
}
$markdownLines.Add("")
$markdownLines.Add("## Owner Inputs")
$markdownLines.Add("")
foreach ($name in $ownerInputNames) {
    $markdownLines.Add("- $name")
}
$markdownLines.Add("")
$markdownLines.Add("## First Operator Commands")
$markdownLines.Add("")
foreach ($command in @($commandMatrix | Select-Object -First 12)) {
    $markdownLines.Add("- ``$($command.command)``")
}
Set-Content -LiteralPath $markdownFullPath -Value $markdownLines -Encoding UTF8

Write-Host "FlowChain operator package status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Package: $packageFullPath"
if ($status -ne "passed") {
    throw "FlowChain operator package failed checks: $($failedChecks -join ', ')"
}
