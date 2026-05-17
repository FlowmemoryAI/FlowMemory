param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/flowchain-completion-audit-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/COMPLETION_AUDIT.md",
    [int] $MonitorDurationSeconds = 20,
    [int] $MonitorPollSeconds = 5,
    [int] $MonitorMaxStateAgeSeconds = 90,
    [int] $ChildTimeoutSeconds = 10800,
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$optionalMissingEnvNames = @(
    "FLOWCHAIN_BASE8453_CURSOR_STATE",
    "FLOWCHAIN_BASE8453_TO_BLOCK"
)

$paths = [ordered]@{
    serviceStatus = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-status-report.json"
    serviceMonitor = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-monitor-report.json"
    liveProduct = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-live-product-e2e-report.json"
    liveInfra = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-live-infra-check-report.json"
    externalTester = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
    ownerInputs = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json"
    ownerOnboarding = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-onboarding-report.json"
    ownerSignupChecklist = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-signup-checklist-report.json"
    ownerEnvTemplate = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-env-template-report.json"
    ownerEnvReadiness = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-env-readiness-report.json"
    ownerEnvReadinessValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-env-readiness-validation-report.json"
    ownerInputsValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/owner-inputs-validation-report.json"
    publicRpcEdgeTemplate = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-edge-template-report.json"
    publicRpcValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json"
    publicRpcAbuseTest = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-abuse-test-report.json"
    publicTesterGateway = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json"
    publicRpcDeploymentBundle = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json"
    externalTesterPacket = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json"
    opsSnapshot = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/ops-snapshot-report.json"
    incidentDrill = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/incident-drill-report.json"
    publicDeploymentContract = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json"
    architectureAudit = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-architecture-audit-report.json"
    backupRestoreValidation = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-report.json"
    liveWallet = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/live-service-wallet-e2e-report.json"
    testerNetwork = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json"
    publicRpc = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json"
    backup = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json"
    bridgeLive = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
    bridgeInfra = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
    bridgePilotLocal = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "services/bridge-relayer/out/real-value-pilot-e2e/bridge-real-value-pilot-e2e-report.json"
    baseTxDiagnostic = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/live-l1-bridge-e2e/base-tx-diagnostic.json"
    productionL1 = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json"
    devPack = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-dev-pack/dev-pack-e2e-report.json"
    noSecret = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json"
}

function Get-AuditJson {
    param([Parameter(Mandatory = $true)][string] $Path)
    return Read-FlowChainJsonIfExists -Path $Path
}

function Get-AuditProp {
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

function Add-Unique {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [object] $Value
    )
    $text = "$Value"
    if (-not [string]::IsNullOrWhiteSpace($text) -and -not $Target.Contains($text)) {
        [void] $Target.Add($text)
    }
}

function Add-AuditItem {
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

function Get-ReportStatus {
    param([AllowNull()][object] $Report)
    return "$((Get-AuditProp -Object $Report -Name "status" -Default "missing"))"
}

function Test-StepPassed {
    param(
        [AllowNull()][object] $LiveProduct,
        [Parameter(Mandatory = $true)][string] $Name
    )
    foreach ($step in @((Get-AuditProp -Object $LiveProduct -Name "steps" -Default @()))) {
        if ("$((Get-AuditProp -Object $step -Name "name"))" -eq $Name) {
            return (Get-AuditProp -Object $step -Name "exitCode" -Default 1) -eq 0 -and "$((Get-AuditProp -Object $step -Name "status"))" -eq "passed"
        }
    }
    return $false
}

$script:AuditChildProcessResults = New-Object System.Collections.ArrayList

function Stop-AuditProcessTree {
    param([Parameter(Mandatory = $true)][int] $ProcessId)

    $children = @()
    try {
        $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$ProcessId" -ErrorAction SilentlyContinue)
    }
    catch {
        $children = @()
    }

    foreach ($child in $children) {
        Stop-AuditProcessTree -ProcessId ([int] $child.ProcessId)
    }

    try {
        Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
    }
    catch {
    }
}

function Read-AuditOutputFile {
    param([Parameter(Mandatory = $true)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }
    return @(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue | ForEach-Object { "$_" })
}

function Invoke-AuditChildProcess {
    param([Parameter(Mandatory = $true)][string[]] $ArgumentList)

    $startedAt = (Get-Date).ToUniversalTime()
    $stamp = $startedAt.ToString("yyyyMMddTHHmmssfffZ")
    $tempBase = Join-Path ([System.IO.Path]::GetTempPath()) "flowchain-completion-audit-$PID-$stamp-$([Guid]::NewGuid().ToString("N"))"
    $stdoutPath = "$tempBase.out.log"
    $stderrPath = "$tempBase.err.log"
    $timedOut = $false
    $exitCode = 1
    $processId = $null
    $output = @()

    try {
        $process = Start-Process -FilePath "powershell" -ArgumentList $ArgumentList -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -NoNewWindow -PassThru
        $processId = $process.Id
        $timeoutMs = [Math]::Max(1, $ChildTimeoutSeconds) * 1000
        if (-not $process.WaitForExit($timeoutMs)) {
            $timedOut = $true
            Stop-AuditProcessTree -ProcessId $process.Id
            $exitCode = 124
        }
        else {
            $exitCode = [int] $process.ExitCode
        }
    }
    catch {
        $output = @($_.Exception.Message)
        $exitCode = 1
    }

    $stdout = Read-AuditOutputFile -Path $stdoutPath
    $stderr = Read-AuditOutputFile -Path $stderrPath
    $output = @($output + $stdout + $stderr)
    if ($timedOut) {
        $output = @("Timed out after $ChildTimeoutSeconds seconds; child process tree was stopped.") + $output
    }
    $finishedAt = (Get-Date).ToUniversalTime()

    Remove-Item -LiteralPath $stdoutPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue

    $result = [ordered]@{
        argumentList = @($ArgumentList)
        processId = $processId
        startedAt = $startedAt.ToString("o")
        finishedAt = $finishedAt.ToString("o")
        durationSeconds = [int][Math]::Max(0, [Math]::Floor(($finishedAt - $startedAt).TotalSeconds))
        timedOut = $timedOut
        timeoutSeconds = $ChildTimeoutSeconds
        exitCode = $exitCode
        output = @($output)
    }
    [void] $script:AuditChildProcessResults.Add([ordered]@{
        argumentList = @($ArgumentList)
        processId = $processId
        startedAt = $result.startedAt
        finishedAt = $result.finishedAt
        durationSeconds = $result.durationSeconds
        timedOut = $timedOut
        timeoutSeconds = $ChildTimeoutSeconds
        exitCode = $exitCode
        outputLineCount = @($output).Count
    })

    return $result
}

$liveProductResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-live-product-e2e.ps1"), "-AllowBlocked")
$liveProductOutput = @($liveProductResult.output)
$liveProductExitCode = $liveProductResult.exitCode
$serviceStatusResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-status.ps1"), "-AllowBlocked")
$serviceStatusOutput = @($serviceStatusResult.output)
$serviceStatusExitCode = $serviceStatusResult.exitCode
$serviceMonitorResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-monitor.ps1"), "-DurationSeconds", "$MonitorDurationSeconds", "-PollSeconds", "$MonitorPollSeconds", "-MaxStateAgeSeconds", "$MonitorMaxStateAgeSeconds")
$serviceMonitorOutput = @($serviceMonitorResult.output)
$serviceMonitorExitCode = $serviceMonitorResult.exitCode
$liveWalletResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-live-service-wallet-e2e.ps1"))
$liveWalletOutput = @($liveWalletResult.output)
$liveWalletExitCode = $liveWalletResult.exitCode
$testerNetworkResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-live-service-tester-network-e2e.ps1"))
$testerNetworkOutput = @($testerNetworkResult.output)
$testerNetworkExitCode = $testerNetworkResult.exitCode
$devPackResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "npm.cmd run flowchain:dev-pack:e2e")
$devPackOutput = @($devPackResult.output)
$devPackExitCode = $devPackResult.exitCode
$bridgePilotLocalResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "npm.cmd run flowchain:real-value-pilot:bridge")
$bridgePilotLocalOutput = @($bridgePilotLocalResult.output)
$bridgePilotLocalExitCode = $bridgePilotLocalResult.exitCode
$baseTxDiagnosticResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "npm.cmd run flowchain:bridge:diagnose:tx")
$baseTxDiagnosticOutput = @($baseTxDiagnosticResult.output)
$baseTxDiagnosticExitCode = $baseTxDiagnosticResult.exitCode
$ownerInputsValidationResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-inputs-validation.ps1"))
$ownerInputsValidationOutput = @($ownerInputsValidationResult.output)
$ownerInputsValidationExitCode = $ownerInputsValidationResult.exitCode
$publicRpcValidationResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-validation.ps1"))
$publicRpcValidationOutput = @($publicRpcValidationResult.output)
$publicRpcValidationExitCode = $publicRpcValidationResult.exitCode
$publicRpcAbuseTestResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-abuse-test.ps1"))
$publicRpcAbuseTestOutput = @($publicRpcAbuseTestResult.output)
$publicRpcAbuseTestExitCode = $publicRpcAbuseTestResult.exitCode
$publicTesterGatewayResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-tester-gateway-e2e.ps1"))
$publicTesterGatewayOutput = @($publicTesterGatewayResult.output)
$publicTesterGatewayExitCode = $publicTesterGatewayResult.exitCode
$backupRestoreValidationResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-backup-restore-validation.ps1"))
$backupRestoreValidationOutput = @($backupRestoreValidationResult.output)
$backupRestoreValidationExitCode = $backupRestoreValidationResult.exitCode
$ownerInputsResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-inputs.ps1"), "-AllowBlocked")
$ownerInputsOutput = @($ownerInputsResult.output)
$ownerInputsExitCode = $ownerInputsResult.exitCode
$ownerOnboardingResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-onboarding.ps1"))
$ownerOnboardingOutput = @($ownerOnboardingResult.output)
$ownerOnboardingExitCode = $ownerOnboardingResult.exitCode
$ownerSignupChecklistResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-signup-checklist.ps1"))
$ownerSignupChecklistOutput = @($ownerSignupChecklistResult.output)
$ownerSignupChecklistExitCode = $ownerSignupChecklistResult.exitCode
$ownerEnvTemplateResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-env-template.ps1"))
$ownerEnvTemplateOutput = @($ownerEnvTemplateResult.output)
$ownerEnvTemplateExitCode = $ownerEnvTemplateResult.exitCode
$ownerEnvReadinessValidationResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-env-readiness-validation.ps1"))
$ownerEnvReadinessValidationOutput = @($ownerEnvReadinessValidationResult.output)
$ownerEnvReadinessValidationExitCode = $ownerEnvReadinessValidationResult.exitCode
$ownerEnvReadinessResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-env-readiness.ps1"), "-AllowBlocked")
$ownerEnvReadinessOutput = @($ownerEnvReadinessResult.output)
$ownerEnvReadinessExitCode = $ownerEnvReadinessResult.exitCode
$publicRpcEdgeTemplateResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-edge-template.ps1"))
$publicRpcEdgeTemplateOutput = @($publicRpcEdgeTemplateResult.output)
$publicRpcEdgeTemplateExitCode = $publicRpcEdgeTemplateResult.exitCode
$publicRpcDeploymentBundleResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-deployment-bundle.ps1"))
$publicRpcDeploymentBundleOutput = @($publicRpcDeploymentBundleResult.output)
$publicRpcDeploymentBundleExitCode = $publicRpcDeploymentBundleResult.exitCode
$liveInfraResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-live-infra-check.ps1"), "-AllowBlocked")
$liveInfraOutput = @($liveInfraResult.output)
$liveInfraExitCode = $liveInfraResult.exitCode
$externalTesterPacketResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-external-tester-packet.ps1"), "-AllowBlocked")
$externalTesterPacketOutput = @($externalTesterPacketResult.output)
$externalTesterPacketExitCode = $externalTesterPacketResult.exitCode
$incidentDrillResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-incident-drill.ps1"))
$incidentDrillOutput = @($incidentDrillResult.output)
$incidentDrillExitCode = $incidentDrillResult.exitCode
$opsSnapshotResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-ops-snapshot.ps1"), "-AllowBlocked", "-NoRefresh")
$opsSnapshotOutput = @($opsSnapshotResult.output)
$opsSnapshotExitCode = $opsSnapshotResult.exitCode
$publicDeploymentContractResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-deployment-contract.ps1"), "-AllowBlocked", "-NoRefresh")
$publicDeploymentContractOutput = @($publicDeploymentContractResult.output)
$publicDeploymentContractExitCode = $publicDeploymentContractResult.exitCode
$architectureAuditResult = Invoke-AuditChildProcess -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-architecture-audit.ps1"), "-AllowBlocked")
$architectureAuditOutput = @($architectureAuditResult.output)
$architectureAuditExitCode = $architectureAuditResult.exitCode

$reports = [ordered]@{}
foreach ($entry in $paths.GetEnumerator()) {
    $reports[$entry.Key] = Get-AuditJson -Path $entry.Value
}

$missingEnv = New-Object System.Collections.ArrayList
foreach ($sourceName in @("liveProduct", "liveInfra", "externalTester", "ownerInputs", "ownerEnvReadiness", "externalTesterPacket", "publicRpc", "bridgeLive", "bridgeInfra")) {
    foreach ($name in @((Get-AuditProp -Object $reports[$sourceName] -Name "missingEnvNames" -Default @()))) {
        if ($name -notin $optionalMissingEnvNames) {
            Add-Unique -Target $missingEnv -Value $name
        }
    }
}
foreach ($name in @((Get-AuditProp -Object $reports.ownerInputs -Name "invalidEnvNames" -Default @()))) {
    Add-Unique -Target $missingEnv -Value $name
}

$service = $reports.serviceStatus
$serviceMonitor = $reports.serviceMonitor
$nodeStatus = [string](Get-AuditProp -Object (Get-AuditProp -Object $service -Name "node") -Name "status")
$controlPlaneStatus = [string](Get-AuditProp -Object (Get-AuditProp -Object $service -Name "controlPlane") -Name "status")
$serviceReady = $serviceStatusExitCode -eq 0 `
    -and (Get-ReportStatus -Report $service) -eq "passed" `
    -and $nodeStatus -eq "running" `
    -and $controlPlaneStatus -eq "running"
$chain = Get-AuditProp -Object $service -Name "chain"
$latestHeight = [string](Get-AuditProp -Object $chain -Name "latestHeight" -Default "0")
$stateAge = [int] (Get-AuditProp -Object $chain -Name "stateFileLastWriteAgeSeconds" -Default 999999)
$chainProducing = $latestHeight -match '^\d+$' -and [int64] $latestHeight -gt 0 -and $stateAge -le 60
$monitorStatus = Get-ReportStatus -Report $serviceMonitor
$monitorHeightAdvanced = Get-AuditProp -Object $serviceMonitor -Name "heightAdvanced" -Default $false
$monitorFirstHeight = [string](Get-AuditProp -Object $serviceMonitor -Name "firstHeight" -Default "")
$monitorLatestHeight = [string](Get-AuditProp -Object $serviceMonitor -Name "latestHeight" -Default "")
$monitorSampleCount = [int](Get-AuditProp -Object $serviceMonitor -Name "sampleCount" -Default 0)
$monitorPassed = $serviceMonitorExitCode -eq 0 `
    -and $monitorStatus -eq "passed" `
    -and $monitorHeightAdvanced -eq $true `
    -and $monitorSampleCount -ge 2 `
    -and $monitorFirstHeight -match '^\d+$' `
    -and $monitorLatestHeight -match '^\d+$'
$liveProduct = $reports.liveProduct
$externalTester = $reports.externalTester
$testerNetwork = $reports.testerNetwork
$liveWallet = $reports.liveWallet
$devPack = $reports.devPack
$liveInfra = $reports.liveInfra
$ownerInputs = $reports.ownerInputs
$ownerOnboarding = $reports.ownerOnboarding
$ownerSignupChecklist = $reports.ownerSignupChecklist
$ownerEnvTemplate = $reports.ownerEnvTemplate
$ownerEnvReadiness = $reports.ownerEnvReadiness
$ownerEnvReadinessValidation = $reports.ownerEnvReadinessValidation
$ownerInputsValidation = $reports.ownerInputsValidation
$publicRpcValidation = $reports.publicRpcValidation
$publicRpcAbuseTest = $reports.publicRpcAbuseTest
$publicTesterGateway = $reports.publicTesterGateway
$externalTesterPacket = $reports.externalTesterPacket
$testerWalletCreatesCount = @((Get-AuditProp -Object $testerNetwork -Name "testerWalletCreates" -Default @())).Count
$testerTransferCount = @((Get-AuditProp -Object $testerNetwork -Name "transferResults" -Default @())).Count
$testerCount = [int](Get-AuditProp -Object $testerNetwork -Name "testerCount" -Default 0)
$testerNetworkBefore = [string](Get-AuditProp -Object $testerNetwork -Name "chainBeforeBlock")
$testerNetworkAfter = [string](Get-AuditProp -Object $testerNetwork -Name "chainAfterBlock")
$liveWalletBalances = Get-AuditProp -Object $liveWallet -Name "balances"
$liveWalletSenderAfter = [string](Get-AuditProp -Object $liveWalletBalances -Name "senderAfter")
$liveWalletRecipientAfter = [string](Get-AuditProp -Object $liveWalletBalances -Name "recipientAfter")
$liveWalletBefore = [string](Get-AuditProp -Object $liveWallet -Name "chainBeforeBlock")
$liveWalletAfter = [string](Get-AuditProp -Object $liveWallet -Name "chainAfterBlock")
$devPackChecks = Get-AuditProp -Object $devPack -Name "checks"
$devPackPassed = $devPackExitCode -eq 0 `
    -and (Get-ReportStatus -Report $devPack) -eq "passed" `
    -and (Get-AuditProp -Object $devPackChecks -Name "discoveryLoaded" -Default $false) -eq $true `
    -and (Get-AuditProp -Object $devPackChecks -Name "readinessLoaded" -Default $false) -eq $true `
    -and (Get-AuditProp -Object $devPackChecks -Name "walletTransfersReadable" -Default $false) -eq $true `
    -and (Get-AuditProp -Object $devPackChecks -Name "walletBalancesReadable" -Default $false) -eq $true `
    -and (Get-AuditProp -Object $devPackChecks -Name "walletSendRuntimeBacked" -Default $false) -eq $true `
    -and (Get-AuditProp -Object $devPackChecks -Name "cliJsonStatus" -Default $false) -eq $true `
    -and (Get-AuditProp -Object $devPackChecks -Name "heightAdvanced" -Default $false) -eq $true `
    -and (Get-AuditProp -Object $devPackChecks -Name "publicReadinessFailClosed" -Default $false) -eq $true `
    -and (Get-AuditProp -Object $devPack -Name "envValuesPrinted" -Default $true) -eq $false `
    -and (Get-AuditProp -Object $devPack -Name "noSecrets" -Default $false) -eq $true
$devPackFirstHeight = [string](Get-AuditProp -Object $devPack -Name "firstHeight" -Default "")
$devPackSecondHeight = [string](Get-AuditProp -Object $devPack -Name "secondHeight" -Default "")
$localTesterRehearsalReady = Get-AuditProp -Object $externalTester -Name "localTesterRehearsalReady"
$externalTesterHeight = [string](Get-AuditProp -Object $externalTester -Name "latestHeight")
$ownerInputsStatus = Get-ReportStatus -Report $ownerInputs
$ownerInputsReady = Get-AuditProp -Object $ownerInputs -Name "ownerInputReady" -Default $false
$ownerOnboardingStatus = Get-ReportStatus -Report $ownerOnboarding
$ownerOnboardingFlowChainRpcIsOurs = Get-AuditProp -Object $ownerOnboarding -Name "flowChainRpcIsOurs" -Default $false
$ownerOnboardingThirdPartyFlowChainRpcProviderNeeded = Get-AuditProp -Object $ownerOnboarding -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$ownerOnboardingPublicEdgeRequired = Get-AuditProp -Object $ownerOnboarding -Name "publicRpcRequiresOwnerPublicEdge" -Default $false
$ownerOnboardingBaseExternal = Get-AuditProp -Object $ownerOnboarding -Name "base8453RpcIsExternalChainDependency" -Default $false
$ownerOnboardingLocalEnvFileSupported = Get-AuditProp -Object $ownerOnboarding -Name "localEnvFileSupported" -Default $false
$ownerOnboardingPassed = $ownerOnboardingExitCode -eq 0 `
    -and $ownerOnboardingStatus -eq "passed" `
    -and $ownerOnboardingFlowChainRpcIsOurs -eq $true `
    -and $ownerOnboardingThirdPartyFlowChainRpcProviderNeeded -eq $false `
    -and $ownerOnboardingPublicEdgeRequired -eq $true `
    -and $ownerOnboardingBaseExternal -eq $true `
    -and $ownerOnboardingLocalEnvFileSupported -eq $true `
    -and ((Get-AuditProp -Object $ownerOnboarding -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $ownerOnboarding -Name "noSecrets" -Default $false) -eq $true)
$ownerSignupChecklistStatus = Get-ReportStatus -Report $ownerSignupChecklist
$ownerSignupExternalCount = [int](Get-AuditProp -Object $ownerSignupChecklist -Name "externalSignupCount" -Default 0)
$ownerSignupItemCount = [int](Get-AuditProp -Object $ownerSignupChecklist -Name "itemCount" -Default 0)
$ownerSignupMissingCoverageCount = @((Get-AuditProp -Object $ownerSignupChecklist -Name "missingChecklistCoverage" -Default @())).Count
$ownerSignupRepoOwned = Get-AuditProp -Object $ownerSignupChecklist -Name "flowChainRpcIsRepoOwned" -Default $false
$ownerSignupThirdPartyFlowChainRpcNeeded = Get-AuditProp -Object $ownerSignupChecklist -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$ownerSignupLocalEnvFileSupported = Get-AuditProp -Object $ownerSignupChecklist -Name "localEnvFileSupported" -Default $false
$ownerSignupChecklistPassed = $ownerSignupChecklistExitCode -eq 0 `
    -and $ownerSignupChecklistStatus -eq "passed" `
    -and $ownerSignupItemCount -ge 8 `
    -and $ownerSignupExternalCount -ge 3 `
    -and $ownerSignupMissingCoverageCount -eq 0 `
    -and $ownerSignupRepoOwned -eq $true `
    -and $ownerSignupThirdPartyFlowChainRpcNeeded -eq $false `
    -and $ownerSignupLocalEnvFileSupported -eq $true `
    -and ((Get-AuditProp -Object $ownerSignupChecklist -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $ownerSignupChecklist -Name "noSecrets" -Default $false) -eq $true)
$ownerEnvTemplateStatus = Get-ReportStatus -Report $ownerEnvTemplate
$ownerEnvTemplateGitIgnored = Get-AuditProp -Object $ownerEnvTemplate -Name "pathIsGitIgnored" -Default $false
$ownerEnvTemplateIncludesRequired = Get-AuditProp -Object $ownerEnvTemplate -Name "templateIncludesAllRequiredEnvNames" -Default $false
$ownerEnvTemplateRequiredCount = [int](Get-AuditProp -Object $ownerEnvTemplate -Name "requiredEnvNameCount" -Default 0)
$ownerEnvTemplateOptionalCount = @((Get-AuditProp -Object $ownerEnvTemplate -Name "optionalEnvNames" -Default @())).Count
$ownerEnvTemplatePassed = $ownerEnvTemplateExitCode -eq 0 `
    -and $ownerEnvTemplateStatus -eq "passed" `
    -and $ownerEnvTemplateGitIgnored -eq $true `
    -and $ownerEnvTemplateIncludesRequired -eq $true `
    -and $ownerEnvTemplateRequiredCount -eq 17 `
    -and $ownerEnvTemplateOptionalCount -eq 2 `
    -and ((Get-AuditProp -Object $ownerEnvTemplate -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $ownerEnvTemplate -Name "noSecrets" -Default $false) -eq $true)
$ownerEnvReadinessValidationStatus = Get-ReportStatus -Report $ownerEnvReadinessValidation
$ownerEnvReadinessValidationChecks = Get-AuditProp -Object $ownerEnvReadinessValidation -Name "checks"
$ownerEnvReadinessValidationMissingFails = Get-AuditProp -Object $ownerEnvReadinessValidationChecks -Name "missingOwnerEnvFileFailsBeforeChildGates" -Default $false
$ownerEnvReadinessValidationUnignoredFails = Get-AuditProp -Object $ownerEnvReadinessValidationChecks -Name "unignoredOwnerEnvFileFailsBeforeChildGates" -Default $false
$ownerEnvReadinessValidationPassed = $ownerEnvReadinessValidationExitCode -eq 0 `
    -and $ownerEnvReadinessValidationStatus -eq "passed" `
    -and $ownerEnvReadinessValidationMissingFails -eq $true `
    -and $ownerEnvReadinessValidationUnignoredFails -eq $true `
    -and ((Get-AuditProp -Object $ownerEnvReadinessValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $ownerEnvReadinessValidation -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $ownerEnvReadinessValidation -Name "broadcasts" -Default $true) -eq $false)
$ownerEnvReadinessStatus = Get-ReportStatus -Report $ownerEnvReadiness
$ownerEnvReadinessState = Get-AuditProp -Object $ownerEnvReadiness -Name "readiness"
$ownerEnvReadinessBlockedOnlyKnown = Get-AuditProp -Object $ownerEnvReadinessState -Name "blockedOnlyOnKnownExternalOwnerInputs" -Default $false
$ownerEnvReadinessOwnerInputsReady = Get-AuditProp -Object $ownerEnvReadinessState -Name "ownerInputsReady" -Default $false
$ownerEnvReadinessLiveInfraReady = Get-AuditProp -Object $ownerEnvReadinessState -Name "liveInfraReady" -Default $false
$ownerEnvReadinessDeploymentReady = Get-AuditProp -Object $ownerEnvReadinessState -Name "publicDeploymentContractReady" -Default $false
$ownerEnvReadinessPath = Get-AuditProp -Object $ownerEnvReadiness -Name "ownerEnvFile"
$ownerEnvReadinessGitIgnored = Get-AuditProp -Object $ownerEnvReadinessPath -Name "gitIgnored" -Default $false
$ownerEnvReadinessKnownSafe = $ownerEnvReadinessExitCode -eq 0 `
    -and $ownerEnvReadinessGitIgnored -eq $true `
    -and ((Get-AuditProp -Object $ownerEnvReadiness -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $ownerEnvReadiness -Name "noSecrets" -Default $false) -eq $true) `
    -and ($ownerEnvReadinessStatus -eq "passed" -or ($ownerEnvReadinessStatus -eq "blocked" -and $ownerEnvReadinessBlockedOnlyKnown -eq $true))
$publicRpcEdgeTemplate = $reports.publicRpcEdgeTemplate
$publicRpcEdgeTemplateStatus = Get-ReportStatus -Report $publicRpcEdgeTemplate
$publicRpcEdgeTemplateReadyFlag = Get-AuditProp -Object $publicRpcEdgeTemplate -Name "edgeTemplateReady" -Default $false
$publicRpcEdgeTemplateRepoOwned = Get-AuditProp -Object $publicRpcEdgeTemplate -Name "flowChainRpcIsRepoOwned" -Default $false
$publicRpcEdgeTemplateThirdPartyNeeded = Get-AuditProp -Object $publicRpcEdgeTemplate -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true
$publicRpcEdgeTemplateRequiresTls = Get-AuditProp -Object $publicRpcEdgeTemplate -Name "requiresTlsTermination" -Default $false
$publicRpcEdgeTemplateRequiresRateLimit = Get-AuditProp -Object $publicRpcEdgeTemplate -Name "requiresRateLimit" -Default $false
$publicRpcEdgeTemplateForwardsOrigin = Get-AuditProp -Object $publicRpcEdgeTemplate -Name "forwardsOriginForCors" -Default $false
$publicRpcEdgeTemplatePassed = $publicRpcEdgeTemplateExitCode -eq 0 `
    -and $publicRpcEdgeTemplateStatus -eq "passed" `
    -and $publicRpcEdgeTemplateReadyFlag -eq $true `
    -and $publicRpcEdgeTemplateRepoOwned -eq $true `
    -and $publicRpcEdgeTemplateThirdPartyNeeded -eq $false `
    -and $publicRpcEdgeTemplateRequiresTls -eq $true `
    -and $publicRpcEdgeTemplateRequiresRateLimit -eq $true `
    -and $publicRpcEdgeTemplateForwardsOrigin -eq $true `
    -and ((Get-AuditProp -Object $publicRpcEdgeTemplate -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $publicRpcEdgeTemplate -Name "noSecrets" -Default $false) -eq $true)
$publicRpcDeploymentBundle = $reports.publicRpcDeploymentBundle
$publicRpcDeploymentBundleStatus = Get-ReportStatus -Report $publicRpcDeploymentBundle
$publicRpcDeploymentBundleChecks = Get-AuditProp -Object $publicRpcDeploymentBundle -Name "checks"
$publicRpcDeploymentBundleRepoOwned = Get-AuditProp -Object $publicRpcDeploymentBundle -Name "flowChainRpcIsRepoOwned" -Default $false
$publicRpcDeploymentBundleNginxTemplate = Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "nginxTemplateWritten" -Default $false
$publicRpcDeploymentBundleVerifyRunbook = Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "verifyRunbookWritten" -Default $false
$publicRpcDeploymentBundleRollbackRunbook = Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "rollbackRunbookWritten" -Default $false
$publicRpcDeploymentBundlePassed = $publicRpcDeploymentBundleExitCode -eq 0 `
    -and $publicRpcDeploymentBundleStatus -eq "passed" `
    -and ($publicRpcDeploymentBundleRepoOwned -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundle -Name "thirdPartyFlowChainRpcProviderNeeded" -Default $true) -eq $false) `
    -and ($publicRpcDeploymentBundleNginxTemplate -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "ownerEnvExampleWritten" -Default $false) -eq $true) `
    -and ($publicRpcDeploymentBundleVerifyRunbook -eq $true) `
    -and ($publicRpcDeploymentBundleRollbackRunbook -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundleChecks -Name "envExampleHasAllRequiredNames" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundle -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundle -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcDeploymentBundle -Name "broadcasts" -Default $true) -eq $false)
$ownerInputsValidationStatus = Get-ReportStatus -Report $ownerInputsValidation
$ownerInputsValidationChecks = Get-AuditProp -Object $ownerInputsValidation -Name "checks"
$ownerInputsValidationMissingBlocks = Get-AuditProp -Object $ownerInputsValidationChecks -Name "missingScenarioBlocks" -Default $false
$ownerInputsValidationInvalidFails = Get-AuditProp -Object $ownerInputsValidationChecks -Name "invalidScenarioFails" -Default $false
$ownerInputsValidationValidPasses = Get-AuditProp -Object $ownerInputsValidationChecks -Name "validStructureScenarioPasses" -Default $false
$ownerInputsValidationEnvFilePasses = Get-AuditProp -Object $ownerInputsValidationChecks -Name "validOwnerEnvFileScenarioPasses" -Default $false
$ownerInputsValidationMissingEnvFileFails = Get-AuditProp -Object $ownerInputsValidationChecks -Name "missingOwnerEnvFileScenarioFails" -Default $false
$ownerInputsValidationMalformedEnvFileFails = Get-AuditProp -Object $ownerInputsValidationChecks -Name "malformedOwnerEnvFileScenarioFails" -Default $false
$ownerInputsValidationPassed = $ownerInputsValidationExitCode -eq 0 `
    -and $ownerInputsValidationStatus -eq "passed" `
    -and $ownerInputsValidationMissingBlocks -eq $true `
    -and $ownerInputsValidationInvalidFails -eq $true `
    -and $ownerInputsValidationValidPasses -eq $true `
    -and $ownerInputsValidationEnvFilePasses -eq $true `
    -and $ownerInputsValidationMissingEnvFileFails -eq $true `
    -and $ownerInputsValidationMalformedEnvFileFails -eq $true
$publicRpcValidationStatus = Get-ReportStatus -Report $publicRpcValidation
$publicRpcValidationChecks = Get-AuditProp -Object $publicRpcValidation -Name "checks"
$publicRpcValidationAllowed = Get-AuditProp -Object $publicRpcValidationChecks -Name "allowedOriginAccepted" -Default $false
$publicRpcValidationDisallowedProbe = Get-AuditProp -Object $publicRpcValidationChecks -Name "disallowedOriginProbePerformed" -Default $false
$publicRpcValidationDisallowedRejected = Get-AuditProp -Object $publicRpcValidationChecks -Name "disallowedOriginRejected" -Default $false
$publicRpcValidationEndpointChecks = Get-AuditProp -Object $publicRpcValidationChecks -Name "noFailedEndpointChecks" -Default $false
$publicRpcValidationRateLimitProbe = Get-AuditProp -Object $publicRpcValidationChecks -Name "rateLimitProbePerformed" -Default $false
$publicRpcValidationRateLimitRejected = Get-AuditProp -Object $publicRpcValidationChecks -Name "rateLimitRejected" -Default $false
$publicRpcValidationRateLimitRetryAfter = Get-AuditProp -Object $publicRpcValidationChecks -Name "rateLimitRetryAfterHeaderPresent" -Default $false
$publicRpcValidationHygiene = Get-AuditProp -Object $publicRpcValidationChecks -Name "responseHygienePassed" -Default $false
$publicRpcValidationPassed = $publicRpcValidationExitCode -eq 0 `
    -and $publicRpcValidationStatus -eq "passed" `
    -and $publicRpcValidationAllowed -eq $true `
    -and $publicRpcValidationDisallowedProbe -eq $true `
    -and $publicRpcValidationDisallowedRejected -eq $true `
    -and $publicRpcValidationEndpointChecks -eq $true `
    -and $publicRpcValidationRateLimitProbe -eq $true `
    -and $publicRpcValidationRateLimitRejected -eq $true `
    -and $publicRpcValidationRateLimitRetryAfter -eq $true `
    -and $publicRpcValidationHygiene -eq $true
$publicRpcAbuseTestStatus = Get-ReportStatus -Report $publicRpcAbuseTest
$publicRpcAbuseTestReady = Get-AuditProp -Object $publicRpcAbuseTest -Name "abuseTestReady" -Default $false
$publicRpcAbuseTestChecks = Get-AuditProp -Object $publicRpcAbuseTest -Name "checks"
$publicRpcAbuseRequiredChecks = @(
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
    "testerWriteGatewayFailsClosed",
    "badParamsRejected",
    "emptyBatchRejected",
    "oversizedBatchRejected",
    "oversizedBodyRejected",
    "notificationNoContent",
    "rateLimitRejected",
    "responseHygienePassed"
)
$publicRpcAbuseMissingChecks = @($publicRpcAbuseRequiredChecks | Where-Object { (Get-AuditProp -Object $publicRpcAbuseTestChecks -Name $_ -Default $false) -ne $true })
$publicRpcAbuseTestPassed = $publicRpcAbuseTestExitCode -eq 0 `
    -and $publicRpcAbuseTestStatus -eq "passed" `
    -and $publicRpcAbuseTestReady -eq $true `
    -and $publicRpcAbuseMissingChecks.Count -eq 0 `
    -and ((Get-AuditProp -Object $publicRpcAbuseTest -Name "ownerValuesRequired" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $publicRpcAbuseTest -Name "noLiveBroadcast" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicRpcAbuseTest -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $publicRpcAbuseTest -Name "noSecrets" -Default $false) -eq $true)
$publicTesterGatewayStatus = Get-ReportStatus -Report $publicTesterGateway
$publicTesterGatewayPassed = $publicTesterGatewayExitCode -eq 0 `
    -and $publicTesterGatewayStatus -eq "passed" `
    -and ((Get-AuditProp -Object $publicTesterGateway -Name "testerGatewayConfigured" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicTesterGateway -Name "testerWriteTokenHashConfigured" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicTesterGateway -Name "transferAccepted" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicTesterGateway -Name "capRejected" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicTesterGateway -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $publicTesterGateway -Name "noSecrets" -Default $false) -eq $true)
$backupRestoreValidation = $reports.backupRestoreValidation
$backupRestoreValidationStatus = Get-ReportStatus -Report $backupRestoreValidation
$backupRestoreValidationChecks = Get-AuditProp -Object $backupRestoreValidation -Name "checks"
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
    (Get-AuditProp -Object $backupRestoreValidationChecks -Name $_ -Default $false) -ne $true
})
$backupRestoreValidationPassed = $backupRestoreValidationExitCode -eq 0 `
    -and $backupRestoreValidationStatus -eq "passed" `
    -and $backupRestoreValidationMissingChecks.Count -eq 0 `
    -and ((Get-AuditProp -Object $backupRestoreValidation -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $backupRestoreValidation -Name "noSecrets" -Default $false) -eq $true)
$externalTesterPacketStatus = Get-ReportStatus -Report $externalTesterPacket
$externalTesterPacketShareable = Get-AuditProp -Object $externalTesterPacket -Name "packetShareable" -Default $false
$externalTesterPacketPath = [string](Get-AuditProp -Object $externalTesterPacket -Name "packetPath" -Default $paths.externalTesterPacket)
$externalTesterPacketExecutableSmokeValidated = Get-AuditProp -Object $externalTesterPacket -Name "packetExecutableSmokeValidated" -Default $false
$externalTesterPacketSmokeChecks = Get-AuditProp -Object $externalTesterPacket -Name "packetSmokeChecks"
$externalTesterPacketSmokeRoutes = @((Get-AuditProp -Object $externalTesterPacket -Name "packetSmokeRoutes" -Default @()))
$externalTesterStatus = Get-ReportStatus -Report $externalTester
$externalSharingReady = Get-AuditProp -Object $externalTester -Name "externalSharingReady" -Default $false
$externalTesterChecks = Get-AuditProp -Object $externalTester -Name "checks"
$externalTesterNetworkFresh = Get-AuditProp -Object $externalTesterChecks -Name "testerWalletNetworkFresh" -Default $false
$externalTesterLaunchPassed = ($externalTesterStatus -eq "passed") `
    -and ($externalTesterPacketStatus -eq "passed") `
    -and ($externalSharingReady -eq $true) `
    -and ($externalTesterPacketShareable -eq $true) `
    -and ($externalTesterNetworkFresh -eq $true) `
    -and ($externalTesterPacketExecutableSmokeValidated -eq $true)
$externalTesterLaunchBlocked = ($externalTesterStatus -eq "blocked") `
    -and ($externalTesterPacketStatus -eq "blocked") `
    -and ($externalSharingReady -eq $false) `
    -and ($externalTesterPacketShareable -eq $false) `
    -and ($externalTesterNetworkFresh -eq $true) `
    -and ($externalTesterPacketExecutableSmokeValidated -eq $true)
$opsSnapshot = $reports.opsSnapshot
$opsSnapshotStatus = Get-ReportStatus -Report $opsSnapshot
$opsSnapshotCriticalCount = [int](Get-AuditProp -Object $opsSnapshot -Name "criticalCount" -Default 999999)
$opsSnapshotBlockedCount = [int](Get-AuditProp -Object $opsSnapshot -Name "blockedCount" -Default 0)
$opsSnapshotChain = Get-AuditProp -Object $opsSnapshot -Name "chain"
$opsSnapshotLatestHeight = [string](Get-AuditProp -Object $opsSnapshotChain -Name "latestHeight" -Default "")
$opsSnapshotFinalizedHeight = [string](Get-AuditProp -Object $opsSnapshotChain -Name "finalizedHeight" -Default "")
$opsSnapshotPassed = $opsSnapshotExitCode -eq 0 `
    -and $opsSnapshotStatus -in @("passed", "blocked") `
    -and $opsSnapshotCriticalCount -eq 0 `
    -and (-not [string]::IsNullOrWhiteSpace($opsSnapshotLatestHeight)) `
    -and (-not [string]::IsNullOrWhiteSpace($opsSnapshotFinalizedHeight))
$incidentDrill = $reports.incidentDrill
$incidentDrillStatus = Get-ReportStatus -Report $incidentDrill
$incidentDrillReady = Get-AuditProp -Object $incidentDrill -Name "incidentDrillReady" -Default $false
$incidentCaseCounts = Get-AuditProp -Object $incidentDrill -Name "caseCounts"
$incidentFailedCases = [int](Get-AuditProp -Object $incidentCaseCounts -Name "failed" -Default 999999)
$incidentTotalCases = [int](Get-AuditProp -Object $incidentCaseCounts -Name "total" -Default 0)
$incidentDrillPassed = $incidentDrillExitCode -eq 0 `
    -and $incidentDrillStatus -eq "passed" `
    -and $incidentDrillReady -eq $true `
    -and $incidentFailedCases -eq 0 `
    -and $incidentTotalCases -ge 8 `
    -and ((Get-AuditProp -Object $incidentDrill -Name "mutatesLiveState" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $incidentDrill -Name "noLiveBroadcast" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $incidentDrill -Name "envValuesPrinted" -Default $true) -eq $false) `
    -and ((Get-AuditProp -Object $incidentDrill -Name "noSecrets" -Default $false) -eq $true)
$productionLocalAggregateStatus = [string](Get-AuditProp -Object $liveProduct -Name "productionLocalAggregateStatus")
$liveProductLiveInfraStatus = [string](Get-AuditProp -Object $liveProduct -Name "liveInfraStatus")
$liveProductNoLiveBroadcast = Get-AuditProp -Object $liveProduct -Name "noLiveBroadcast"
$liveProductEnvValuesPrinted = Get-AuditProp -Object $liveProduct -Name "envValuesPrinted"
$liveInfraStatus = Get-ReportStatus -Report $liveInfra
$liveInfraReadiness = Get-AuditProp -Object $liveInfra -Name "readiness"
$liveInfraOwnerInputsReady = Get-AuditProp -Object $liveInfraReadiness -Name "ownerInputsReady" -Default $false
$liveInfraPublicRpcReady = Get-AuditProp -Object $liveInfraReadiness -Name "publicRpcReady" -Default $false
$liveInfraServicesReady = Get-AuditProp -Object $liveInfraReadiness -Name "servicesReady" -Default $false
$liveInfraBackupReady = Get-AuditProp -Object $liveInfraReadiness -Name "backupReady" -Default $false
$liveInfraBridgeReady = Get-AuditProp -Object $liveInfraReadiness -Name "bridgeReady" -Default $false
$liveInfraNoSecretReady = Get-AuditProp -Object $liveInfraReadiness -Name "noSecretReady" -Default $false
$bridgePilotLocal = $reports.bridgePilotLocal
$bridgePilotExactValue = Get-AuditProp -Object $bridgePilotLocal -Name "exactValueConservation"
$bridgePilotNegative = Get-AuditProp -Object $bridgePilotLocal -Name "negativeCoverage"
$bridgePilotBroadcast = Get-AuditProp -Object $bridgePilotLocal -Name "broadcast"
$bridgePilotNoSecrets = Get-AuditProp -Object $bridgePilotLocal -Name "noSecrets"
$bridgePilotAllAmountsEqual = Get-AuditProp -Object $bridgePilotExactValue -Name "allAmountsEqual"
$bridgePilotWrongChainRejected = Get-AuditProp -Object $bridgePilotNegative -Name "wrongChainRejected"
$bridgePilotUnapprovedContractRejected = Get-AuditProp -Object $bridgePilotNegative -Name "unapprovedContractRejected"
$bridgePilotLocalPassed = $bridgePilotLocalExitCode -eq 0 `
    -and $null -ne $bridgePilotLocal `
    -and $bridgePilotBroadcast -eq $false `
    -and $bridgePilotNoSecrets -eq $true `
    -and $bridgePilotAllAmountsEqual -eq $true `
    -and $bridgePilotWrongChainRejected -eq $true `
    -and $bridgePilotUnapprovedContractRejected -eq $true
$baseTxDiagnostic = $reports.baseTxDiagnostic
$baseTxDiagnosticStatus = Get-ReportStatus -Report $baseTxDiagnostic
$baseTxDiagnosticSafeReason = [string](Get-AuditProp -Object $baseTxDiagnostic -Name "safeReasonCode")
$baseTxDiagnosticBroadcasts = Get-AuditProp -Object $baseTxDiagnostic -Name "broadcasts"
$baseTxDiagnosticPrintsEnvValues = Get-AuditProp -Object $baseTxDiagnostic -Name "printsEnvValues"
$baseTxDiagnosticNoSecrets = Get-AuditProp -Object $baseTxDiagnostic -Name "noSecrets"
$baseTxDiagnosticFailClosedPassed = $null -ne $baseTxDiagnostic `
    -and $baseTxDiagnosticStatus -eq "blocked" `
    -and $baseTxDiagnosticSafeReason -eq "missing-env" `
    -and $baseTxDiagnosticBroadcasts -eq $false `
    -and $baseTxDiagnosticPrintsEnvValues -eq $false `
    -and $baseTxDiagnosticNoSecrets -eq $true
$baseTxDiagnosticWithOwnerInputPassed = $null -ne $baseTxDiagnostic `
    -and $baseTxDiagnosticStatus -in @("valid", "invalid") `
    -and $baseTxDiagnosticBroadcasts -eq $false `
    -and $baseTxDiagnosticPrintsEnvValues -eq $false `
    -and $baseTxDiagnosticNoSecrets -eq $true
$baseTxDiagnosticPassed = $baseTxDiagnosticFailClosedPassed -or $baseTxDiagnosticWithOwnerInputPassed
$publicDeploymentContract = $reports.publicDeploymentContract
$publicDeploymentContractStatus = Get-ReportStatus -Report $publicDeploymentContract
$publicDeploymentContractCounts = Get-AuditProp -Object $publicDeploymentContract -Name "itemCounts"
$publicDeploymentContractFailed = [int](Get-AuditProp -Object $publicDeploymentContractCounts -Name "failed" -Default 1)
$publicDeploymentContractBlocked = [int](Get-AuditProp -Object $publicDeploymentContractCounts -Name "blocked" -Default 0)
$publicDeploymentContractBlockedOnlyKnown = Get-AuditProp -Object $publicDeploymentContract -Name "blockedOnlyOnKnownExternalOwnerInputs" -Default $false
$publicDeploymentContractDeploymentReady = Get-AuditProp -Object $publicDeploymentContract -Name "deploymentReady" -Default $false
$publicDeploymentContractPacketShareable = Get-AuditProp -Object $publicDeploymentContract -Name "packetShareable" -Default $false
$publicDeploymentContractPacketSmoke = Get-AuditProp -Object $publicDeploymentContract -Name "packetExecutableSmokeValidated" -Default $false
$publicDeploymentContractSafe = ($publicDeploymentContractExitCode -eq 0) `
    -and ($publicDeploymentContractStatus -in @("passed", "blocked")) `
    -and ($publicDeploymentContractFailed -eq 0) `
    -and ($publicDeploymentContractBlockedOnlyKnown -eq $true) `
    -and ($publicDeploymentContractPacketSmoke -eq $true) `
    -and ((Get-AuditProp -Object $publicDeploymentContract -Name "noSecrets" -Default $false) -eq $true) `
    -and ((Get-AuditProp -Object $publicDeploymentContract -Name "noLiveBroadcast" -Default $false) -eq $true)
$architectureAudit = $reports.architectureAudit
$architectureAuditStatus = Get-ReportStatus -Report $architectureAudit
$architectureAuditCounts = Get-AuditProp -Object $architectureAudit -Name "itemCounts"
$architectureAuditFailed = [int](Get-AuditProp -Object $architectureAuditCounts -Name "failed" -Default 1)
$architectureAuditBlocked = [int](Get-AuditProp -Object $architectureAuditCounts -Name "blocked" -Default 0)
$architectureAuditBlockedOnlyKnown = Get-AuditProp -Object $architectureAudit -Name "blockedOnlyOnKnownExternalOwnerInputs" -Default $false
$architectureAuditNoSecrets = Get-AuditProp -Object $architectureAudit -Name "noSecrets" -Default $false
$architectureAuditNoBroadcast = Get-AuditProp -Object $architectureAudit -Name "noLiveBroadcast" -Default $false
$architectureAuditReady = ($architectureAuditExitCode -eq 0) `
    -and ($architectureAuditStatus -in @("passed", "blocked")) `
    -and ($architectureAuditFailed -eq 0) `
    -and ($architectureAuditBlockedOnlyKnown -eq $true) `
    -and ($architectureAuditNoSecrets -eq $true) `
    -and ($architectureAuditNoBroadcast -eq $true)

$items = New-Object System.Collections.ArrayList

Add-AuditItem -Items $items -Id "service-live-profile" `
    -Requirement "Chain service is running in live profile and command lines match this worktree." `
    -Status $(if ($serviceReady) { "passed" } else { "failed" }) `
    -Evidence "service-status status=$(Get-ReportStatus -Report $service), node=$nodeStatus, controlPlane=$controlPlaneStatus, report=$($paths.serviceStatus)" `
    -Commands @("npm run flowchain:service:status")

Add-AuditItem -Items $items -Id "block-production" `
    -Requirement "Chain is producing/finalizing blocks and state is fresh." `
    -Status $(if ($chainProducing) { "passed" } else { "failed" }) `
    -Evidence "latestHeight=$latestHeight, stateFileLastWriteAgeSeconds=$stateAge, report=$($paths.serviceStatus)" `
    -Commands @("npm run flowchain:service:status")

Add-AuditItem -Items $items -Id "sustained-block-production" `
    -Requirement "Live service monitor observes running services and advancing block height over a sampling window." `
    -Status $(if ($monitorPassed) { "passed" } else { "failed" }) `
    -Evidence "monitorStatus=$monitorStatus, samples=$monitorSampleCount, heightAdvanced=$monitorHeightAdvanced, heights=$monitorFirstHeight->$monitorLatestHeight, report=$($paths.serviceMonitor)" `
    -Commands @("npm run flowchain:service:monitor -- -DurationSeconds $MonitorDurationSeconds -PollSeconds $MonitorPollSeconds -MaxStateAgeSeconds $MonitorMaxStateAgeSeconds")

Add-AuditItem -Items $items -Id "wallet-create" `
    -Requirement "People can create wallets through the RPC service without receiving secret material." `
    -Status $(if ($testerNetworkExitCode -eq 0 -and (Get-ReportStatus -Report $testerNetwork) -eq "passed" -and $testerCount -ge 4) { "passed" } else { "failed" }) `
    -Evidence "testerWalletCreates=$testerWalletCreatesCount, secretMaterialReturned=false, report=$($paths.testerNetwork)" `
    -Commands @("npm run flowchain:wallet:live-tester:e2e")

Add-AuditItem -Items $items -Id "wallet-transfer" `
    -Requirement "Wallet-to-wallet transfers sent through the running service settle on produced blocks." `
    -Status $(if ($liveWalletExitCode -eq 0 -and (Get-ReportStatus -Report $liveWallet) -eq "passed" -and $liveWalletSenderAfter -eq "75" -and $liveWalletRecipientAfter -eq "25") { "passed" } else { "failed" }) `
    -Evidence "single-transfer blocks $liveWalletBefore->$liveWalletAfter, report=$($paths.liveWallet)" `
    -Commands @("npm run flowchain:wallet:live-service:e2e")

Add-AuditItem -Items $items -Id "tester-network-transfer" `
    -Requirement "A small tester group can create wallets, receive funds, and send funds to each other through the running service." `
    -Status $(if ($testerNetworkExitCode -eq 0 -and (Get-ReportStatus -Report $testerNetwork) -eq "passed" -and $testerCount -ge 4 -and $testerTransferCount -ge 4) { "passed" } else { "failed" }) `
    -Evidence "testerCount=$testerCount, transfers=$testerTransferCount, blocks=$testerNetworkBefore->$testerNetworkAfter, report=$($paths.testerNetwork)" `
    -Commands @("npm run flowchain:wallet:live-tester:e2e")

Add-AuditItem -Items $items -Id "rpc-connect-local" `
    -Requirement "Clients can connect to the private RPC service for health, discovery, readiness, chain, and wallet methods." `
    -Status $(if ((Get-ReportStatus -Report $externalTester) -eq "blocked" -and $localTesterRehearsalReady -eq $true) { "passed" } else { "failed" }) `
    -Evidence "localTesterRehearsalReady=$localTesterRehearsalReady, latestHeight=$externalTesterHeight, report=$($paths.externalTester)" `
    -Commands @("npm run flowchain:tester:readiness -- -AllowBlocked")

Add-AuditItem -Items $items -Id "developer-dev-pack" `
    -Requirement "Developer SDK/devkit proof connects to the real RPC, checks readiness/discovery, reads wallet data, submits a runtime-backed local wallet send, and keeps public readiness fail-closed." `
    -Status $(if ($devPackPassed) { "passed" } else { "failed" }) `
    -Evidence "devPackStatus=$(Get-ReportStatus -Report $devPack), heights=$devPackFirstHeight->$devPackSecondHeight, methodCount=$(Get-AuditProp -Object $devPack -Name "methodCount"), publicReadyMethodCount=$(Get-AuditProp -Object $devPack -Name "publicReadyMethodCount"), report=$($paths.devPack)" `
    -Commands @("npm run flowchain:dev-pack:e2e")

Add-AuditItem -Items $items -Id "system-architecture-audit" `
    -Requirement "System architecture for runtime, RPC, wallets, bridge, backup, operations, verification, and fail-closed owner boundaries is explicit and evidence-backed." `
    -Status $(if ($architectureAuditReady) { "passed" } else { "failed" }) `
    -Evidence "architectureStatus=$architectureAuditStatus, blockedOnlyOnKnownExternalOwnerInputs=$architectureAuditBlockedOnlyKnown, blockedItems=$architectureAuditBlocked, failedItems=$architectureAuditFailed, report=$($paths.architectureAudit)" `
    -Commands @("npm run flowchain:architecture:audit -- -AllowBlocked")

Add-AuditItem -Items $items -Id "public-deployment-contract" `
    -Requirement "Owner-operated public deployment contract is machine-checkable, has rollback commands, and fails closed until public RPC, backup, bridge, and tester sharing gates pass." `
    -Status $(if ($publicDeploymentContractSafe) { "passed" } else { "failed" }) `
    -Evidence "deploymentStatus=$publicDeploymentContractStatus, deploymentReady=$publicDeploymentContractDeploymentReady, packetShareable=$publicDeploymentContractPacketShareable, packetSmoke=$publicDeploymentContractPacketSmoke, blockedOnlyKnown=$publicDeploymentContractBlockedOnlyKnown, blockedItems=$publicDeploymentContractBlocked, failedItems=$publicDeploymentContractFailed, report=$($paths.publicDeploymentContract)" `
    -Commands @("npm run flowchain:public-deployment:contract -- -AllowBlocked")

Add-AuditItem -Items $items -Id "owner-input-validator-self-test" `
    -Requirement "Owner input validator blocks missing env, fails invalid env, passes structurally valid dummy owner inputs from direct env and the local owner env-file loader, and writes failed reports for missing or malformed owner env files without printing values." `
    -Status $(if ($ownerInputsValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "validationStatus=$ownerInputsValidationStatus, missingBlocks=$ownerInputsValidationMissingBlocks, invalidFails=$ownerInputsValidationInvalidFails, validPasses=$ownerInputsValidationValidPasses, ownerEnvFilePasses=$ownerInputsValidationEnvFilePasses, missingOwnerEnvFileFails=$ownerInputsValidationMissingEnvFileFails, malformedOwnerEnvFileFails=$ownerInputsValidationMalformedEnvFileFails, report=$($paths.ownerInputsValidation)" `
    -Commands @("npm run flowchain:owner-inputs:validate")

Add-AuditItem -Items $items -Id "owner-input-contract" `
    -Requirement "Owner public RPC, tester write gateway, backup, and Base 8453 bridge inputs are validated without printing values." `
    -Status $(if ($ownerInputsStatus -eq "passed" -and $ownerInputsReady -eq $true) { "passed" } elseif ($ownerInputsStatus -eq "blocked") { "blocked" } else { "failed" }) `
    -Evidence "ownerInputsStatus=$ownerInputsStatus, ownerInputReady=$ownerInputsReady, report=$($paths.ownerInputs)" `
    -Commands @("npm run flowchain:owner-inputs") `
    -Blockers @($missingEnv)

Add-AuditItem -Items $items -Id "owner-onboarding-packet" `
    -Requirement "Owner onboarding distinguishes repo-owned FlowChain RPC from the external Base 8453 RPC dependency and gives no-values setup commands." `
    -Status $(if ($ownerOnboardingPassed) { "passed" } else { "failed" }) `
    -Evidence "onboardingStatus=$ownerOnboardingStatus, flowChainRpcIsOurs=$ownerOnboardingFlowChainRpcIsOurs, thirdPartyFlowChainRpcProviderNeeded=$ownerOnboardingThirdPartyFlowChainRpcProviderNeeded, publicRpcRequiresOwnerPublicEdge=$ownerOnboardingPublicEdgeRequired, base8453RpcIsExternalChainDependency=$ownerOnboardingBaseExternal, localEnvFileSupported=$ownerOnboardingLocalEnvFileSupported, report=$($paths.ownerOnboarding)" `
    -Commands @("npm run flowchain:owner:onboarding")

Add-AuditItem -Items $items -Id "owner-signup-checklist" `
    -Requirement "Owner signup checklist maps public RPC edge, tester write token/cap, always-on host, backup storage, Base 8453 RPC, bridge details, and local env-file setup to exact owner actions without requesting secrets." `
    -Status $(if ($ownerSignupChecklistPassed) { "passed" } else { "failed" }) `
    -Evidence "signupStatus=$ownerSignupChecklistStatus, itemCount=$ownerSignupItemCount, externalSignupCount=$ownerSignupExternalCount, missingCoverage=$ownerSignupMissingCoverageCount, repoOwned=$ownerSignupRepoOwned, localEnvFileSupported=$ownerSignupLocalEnvFileSupported, report=$($paths.ownerSignupChecklist)" `
    -Commands @("npm run flowchain:owner:signup-checklist")

Add-AuditItem -Items $items -Id "owner-env-template" `
    -Requirement "Owner env-file setup has a command-generated local scaffold whose target path is git-ignored before owner values are added." `
    -Status $(if ($ownerEnvTemplatePassed) { "passed" } else { "failed" }) `
    -Evidence "templateStatus=$ownerEnvTemplateStatus, pathIsGitIgnored=$ownerEnvTemplateGitIgnored, requiredEnvNameCount=$ownerEnvTemplateRequiredCount, optionalEnvNameCount=$ownerEnvTemplateOptionalCount, includesAllRequired=$ownerEnvTemplateIncludesRequired, report=$($paths.ownerEnvTemplate)" `
    -Commands @("npm run flowchain:owner-env:template")

Add-AuditItem -Items $items -Id "owner-env-readiness-validator-self-test" `
    -Requirement "Owner env readiness validator fails closed before child gates for missing owner env files and repo-local env files that are not git-ignored." `
    -Status $(if ($ownerEnvReadinessValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "validationStatus=$ownerEnvReadinessValidationStatus, missingFails=$ownerEnvReadinessValidationMissingFails, unignoredFails=$ownerEnvReadinessValidationUnignoredFails, report=$($paths.ownerEnvReadinessValidation)" `
    -Commands @("npm run flowchain:owner-env:readiness:validate")

Add-AuditItem -Items $items -Id "owner-env-readiness" `
    -Requirement "The ignored owner env file can drive owner-input, live-infra, and public deployment gates through one redacted command." `
    -Status $(if ($ownerEnvReadinessStatus -eq "passed" -and $ownerEnvReadinessKnownSafe) { "passed" } elseif ($ownerEnvReadinessStatus -eq "blocked" -and $ownerEnvReadinessKnownSafe) { "blocked" } else { "failed" }) `
    -Evidence "readinessStatus=$ownerEnvReadinessStatus, pathGitIgnored=$ownerEnvReadinessGitIgnored, ownerInputsReady=$ownerEnvReadinessOwnerInputsReady, liveInfraReady=$ownerEnvReadinessLiveInfraReady, publicDeploymentContractReady=$ownerEnvReadinessDeploymentReady, blockedOnlyKnown=$ownerEnvReadinessBlockedOnlyKnown, report=$($paths.ownerEnvReadiness)" `
    -Commands @("npm run flowchain:owner-env:readiness -- -AllowBlocked") `
    -Blockers @($missingEnv)

Add-AuditItem -Items $items -Id "public-rpc-edge-template" `
    -Requirement "Public RPC exposure has a no-values owner edge template for HTTPS reverse proxying, rate limiting, and CORS-origin forwarding." `
    -Status $(if ($publicRpcEdgeTemplatePassed) { "passed" } else { "failed" }) `
    -Evidence "edgeTemplateStatus=$publicRpcEdgeTemplateStatus, repoOwned=$publicRpcEdgeTemplateRepoOwned, requiresTls=$publicRpcEdgeTemplateRequiresTls, requiresRateLimit=$publicRpcEdgeTemplateRequiresRateLimit, forwardsOrigin=$publicRpcEdgeTemplateForwardsOrigin, report=$($paths.publicRpcEdgeTemplate)" `
    -Commands @("npm run flowchain:public-rpc:edge-template")

Add-AuditItem -Items $items -Id "public-rpc-deployment-bundle" `
    -Requirement "Public RPC deployment bundle has no-secret Nginx, owner env, verification, and rollback artifacts for exposing FlowChain's own RPC." `
    -Status $(if ($publicRpcDeploymentBundlePassed) { "passed" } else { "failed" }) `
    -Evidence "bundleStatus=$publicRpcDeploymentBundleStatus, repoOwned=$publicRpcDeploymentBundleRepoOwned, nginxTemplate=$publicRpcDeploymentBundleNginxTemplate, verifyRunbook=$publicRpcDeploymentBundleVerifyRunbook, rollbackRunbook=$publicRpcDeploymentBundleRollbackRunbook, report=$($paths.publicRpcDeploymentBundle)" `
    -Commands @("npm run flowchain:public-rpc:deployment-bundle")

Add-AuditItem -Items $items -Id "public-rpc-readiness-validator-self-test" `
    -Requirement "Public RPC readiness validator proves endpoint checks, CORS allowed-origin acceptance, disallowed-origin rejection, bounded rate-limit rejection, retry-after evidence, and response hygiene against a temporary local control plane." `
    -Status $(if ($publicRpcValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "validationStatus=$publicRpcValidationStatus, allowedOriginAccepted=$publicRpcValidationAllowed, disallowedProbe=$publicRpcValidationDisallowedProbe, disallowedRejected=$publicRpcValidationDisallowedRejected, endpointChecks=$publicRpcValidationEndpointChecks, rateLimitProbe=$publicRpcValidationRateLimitProbe, rateLimitRejected=$publicRpcValidationRateLimitRejected, rateLimitRetryAfter=$publicRpcValidationRateLimitRetryAfter, responseHygiene=$publicRpcValidationHygiene, report=$($paths.publicRpcValidation)" `
    -Commands @("npm run flowchain:public-rpc:validate")

Add-AuditItem -Items $items -Id "public-rpc-abuse-test" `
    -Requirement "Public RPC abuse harness proves CORS rejection, media-type rejection, parse-error handling, method/params failure envelopes, batch/body caps, notification 204 handling, rate limiting, and no-secret response summaries." `
    -Status $(if ($publicRpcAbuseTestPassed) { "passed" } else { "failed" }) `
    -Evidence "abuseStatus=$publicRpcAbuseTestStatus, abuseReady=$publicRpcAbuseTestReady, missingChecks=$($publicRpcAbuseMissingChecks.Count), report=$($paths.publicRpcAbuseTest)" `
    -Commands @("npm run flowchain:public-rpc:abuse-test")

Add-AuditItem -Items $items -Id "public-tester-gateway-e2e" `
    -Requirement "Public tester write gateway proves bearer auth configuration, public-only wallet creation, capped send settlement, and over-cap rejection on a temporary local control-plane." `
    -Status $(if ($publicTesterGatewayPassed) { "passed" } else { "failed" }) `
    -Evidence "gatewayStatus=$publicTesterGatewayStatus, configured=$(Get-AuditProp -Object $publicTesterGateway -Name "testerGatewayConfigured"), transferAccepted=$(Get-AuditProp -Object $publicTesterGateway -Name "transferAccepted"), capRejected=$(Get-AuditProp -Object $publicTesterGateway -Name "capRejected"), report=$($paths.publicTesterGateway)" `
    -Commands @("npm run flowchain:tester:gateway:e2e")

Add-AuditItem -Items $items -Id "backup-restore-validator-self-test" `
    -Requirement "Backup tooling creates manifest-backed live-state snapshots, verifies latest-snapshot restore rehearsal without targeting live state, and rejects corrupt, tampered, missing-artifact, stale-pointer, and wrong-chain cases." `
    -Status $(if ($backupRestoreValidationPassed) { "passed" } else { "failed" }) `
    -Evidence "validationStatus=$backupRestoreValidationStatus, requiredChecks=$($backupRestoreValidationRequiredChecks.Count), missingChecks=$($backupRestoreValidationMissingChecks.Count), report=$($paths.backupRestoreValidation)" `
    -Commands @("npm run flowchain:backup:restore:validate")

Add-AuditItem -Items $items -Id "external-tester-packet" `
    -Requirement "External tester handoff packet is generated, executable packet-route smoke is validated, and sharing fails closed until public gates pass." `
    -Status $(if (($externalTesterPacketStatus -eq "passed" -and $externalTesterPacketShareable -eq $true -and $externalTesterPacketExecutableSmokeValidated -eq $true) -or ($externalTesterPacketStatus -eq "blocked" -and $externalTesterPacketShareable -eq $false -and $externalTesterPacketExecutableSmokeValidated -eq $true)) { "passed" } else { "failed" }) `
    -Evidence "packetStatus=$externalTesterPacketStatus, shareable=$externalTesterPacketShareable, packetSmoke=$externalTesterPacketExecutableSmokeValidated, smokeRoutes=$($externalTesterPacketSmokeRoutes.Count), packet=$externalTesterPacketPath" `
    -Commands @("npm run flowchain:external-tester:packet")

Add-AuditItem -Items $items -Id "friends-and-family-launch" `
    -Requirement "Friends-and-family tester launch requires fresh tester-wallet evidence and executable packet-route smoke, and remains blocked until public RPC, backup, and Base bridge gates pass." `
    -Status $(if ($externalTesterLaunchPassed) { "passed" } elseif ($externalTesterLaunchBlocked) { "blocked" } else { "failed" }) `
    -Evidence "externalTester=$externalTesterStatus, testerNetworkFresh=$externalTesterNetworkFresh, packetStatus=$externalTesterPacketStatus, shareable=$externalTesterPacketShareable, packetSmoke=$externalTesterPacketExecutableSmokeValidated, smokeRoutes=$($externalTesterPacketSmokeRoutes.Count), externalSharingReady=$externalSharingReady" `
    -Commands @("npm run flowchain:tester:readiness -- -AllowBlocked", "npm run flowchain:external-tester:packet -- -AllowBlocked") `
    -Blockers @($missingEnv)

Add-AuditItem -Items $items -Id "ops-snapshot" `
    -Requirement "Ops snapshot separates critical incidents from expected owner-input blockers and records incident commands." `
    -Status $(if ($opsSnapshotPassed) { "passed" } else { "failed" }) `
    -Evidence "opsStatus=$opsSnapshotStatus, criticalCount=$opsSnapshotCriticalCount, blockedCount=$opsSnapshotBlockedCount, latestHeight=$opsSnapshotLatestHeight, finalizedHeight=$opsSnapshotFinalizedHeight, report=$($paths.opsSnapshot)" `
    -Commands @("npm run flowchain:ops:snapshot -- -AllowBlocked")

Add-AuditItem -Items $items -Id "incident-drill" `
    -Requirement "Incident drills prove node-down, control-plane-down, stale-state, stalled-height, and no-secret failures classify as critical while owner-input blockers stay non-critical." `
    -Status $(if ($incidentDrillPassed) { "passed" } else { "failed" }) `
    -Evidence "incidentStatus=$incidentDrillStatus, ready=$incidentDrillReady, cases=$incidentTotalCases, failedCases=$incidentFailedCases, report=$($paths.incidentDrill)" `
    -Commands @("npm run flowchain:ops:incident-drill")

Add-AuditItem -Items $items -Id "public-rpc-external-sharing" `
    -Requirement "External/public RPC is configured behind owner TLS, CORS, rate limit, endpoint checks, and response hygiene." `
    -Status $(if ((Get-ReportStatus -Report $reports.publicRpc) -eq "passed") { "passed" } else { "blocked" }) `
    -Evidence "publicRpcStatus=$(Get-ReportStatus -Report $reports.publicRpc), report=$($paths.publicRpc)" `
    -Commands @("npm run flowchain:public-rpc:check") `
    -Blockers @("FLOWCHAIN_RPC_PUBLIC_URL", "FLOWCHAIN_RPC_ALLOWED_ORIGINS", "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE", "FLOWCHAIN_RPC_TLS_TERMINATED")

$backupReadinessStatus = Get-ReportStatus -Report $reports.backup
$backupReadinessDetails = Get-AuditProp -Object $reports.backup -Name "backup"
$backupSnapshotProofStatus = Get-AuditProp -Object $backupReadinessDetails -Name "snapshotProofStatus" -Default "not-run"
$backupRestoreProofStatus = Get-AuditProp -Object $backupReadinessDetails -Name "restoreProofStatus" -Default "not-run"
$backupRestoreVerified = Get-AuditProp -Object $backupReadinessDetails -Name "restoreVerified" -Default $false
Add-AuditItem -Items $items -Id "state-backup" `
    -Requirement "State backup path is configured and can create a manifest-backed snapshot that is verified through a restore rehearsal for live RPC operations." `
    -Status $(if ($backupReadinessStatus -eq "passed" -and $backupRestoreValidationPassed) { "passed" } elseif ($backupReadinessStatus -eq "blocked" -and $backupRestoreValidationPassed) { "blocked" } else { "failed" }) `
    -Evidence "backupStatus=$backupReadinessStatus, snapshotProof=$backupSnapshotProofStatus, restoreProof=$backupRestoreProofStatus, restoreVerified=$backupRestoreVerified, validationStatus=$backupRestoreValidationStatus, report=$($paths.backup)" `
    -Commands @("npm run flowchain:backup:create", "npm run flowchain:backup:restore:verify", "npm run flowchain:backup:check") `
    -Blockers @("FLOWCHAIN_RPC_STATE_BACKUP_PATH")

Add-AuditItem -Items $items -Id "bridge-funds" `
    -Requirement "Bridge readiness for owner-operated Base 8453 funds is verified fail-closed without live broadcasts." `
    -Status $(if ((Get-ReportStatus -Report $reports.bridgeLive) -eq "passed" -and (Get-ReportStatus -Report $reports.bridgeInfra) -eq "passed") { "passed" } else { "blocked" }) `
    -Evidence "bridgeLive=$(Get-ReportStatus -Report $reports.bridgeLive), bridgeInfra=$(Get-ReportStatus -Report $reports.bridgeInfra), reports=$($paths.bridgeLive), $($paths.bridgeInfra)" `
    -Commands @("npm run flowchain:bridge:live:check", "npm run flowchain:bridge:infra:check") `
    -Blockers @("FLOWCHAIN_PILOT_OPERATOR_ACK", "FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN", "FLOWCHAIN_BASE8453_ASSET_DECIMALS", "FLOWCHAIN_BASE8453_FROM_BLOCK", "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", "FLOWCHAIN_PILOT_TOTAL_CAP_WEI", "FLOWCHAIN_PILOT_CONFIRMATIONS")

Add-AuditItem -Items $items -Id "bridge-local-pilot-proof" `
    -Requirement "Local/mock bridge pilot proof preserves exact value, rejects replay/wrong-chain/unapproved-lockbox cases, and performs no broadcast." `
    -Status $(if ($bridgePilotLocalPassed) { "passed" } else { "failed" }) `
    -Evidence "broadcast=$bridgePilotBroadcast, allAmountsEqual=$bridgePilotAllAmountsEqual, wrongChainRejected=$bridgePilotWrongChainRejected, unapprovedContractRejected=$bridgePilotUnapprovedContractRejected, report=$($paths.bridgePilotLocal)" `
    -Commands @("npm run flowchain:real-value-pilot:bridge")

Add-AuditItem -Items $items -Id "base-tx-diagnostic-fail-closed" `
    -Requirement "Owner-supplied Base 8453 transaction diagnostic is read-only, no-secret, and fails closed when tx/env inputs are absent." `
    -Status $(if ($baseTxDiagnosticPassed) { "passed" } else { "failed" }) `
    -Evidence "diagnosticStatus=$baseTxDiagnosticStatus, safeReason=$baseTxDiagnosticSafeReason, broadcasts=$baseTxDiagnosticBroadcasts, printsEnvValues=$baseTxDiagnosticPrintsEnvValues, noSecrets=$baseTxDiagnosticNoSecrets, report=$($paths.baseTxDiagnostic)" `
    -Commands @("npm run flowchain:bridge:diagnose:tx")

Add-AuditItem -Items $items -Id "live-infra-aggregate-refresh" `
    -Requirement "Completion audit refreshes the live-infra aggregate gate before deciding readiness." `
    -Status $(if ($liveInfraStatus -eq "passed") { "passed" } elseif ($liveInfraStatus -eq "blocked") { "blocked" } else { "failed" }) `
    -Evidence "liveInfraStatus=$liveInfraStatus, ownerInputsReady=$liveInfraOwnerInputsReady, publicRpcReady=$liveInfraPublicRpcReady, servicesReady=$liveInfraServicesReady, backupReady=$liveInfraBackupReady, bridgeReady=$liveInfraBridgeReady, noSecretReady=$liveInfraNoSecretReady, report=$($paths.liveInfra)" `
    -Commands @("npm run flowchain:live-infra:check -- -AllowBlocked") `
    -Blockers @($missingEnv)

Add-AuditItem -Items $items -Id "aggregate-gate" `
    -Requirement "Full product gate runs production local L1 aggregate, restores live service, proves wallet flows, and runs live infra readiness." `
    -Status $(if ($liveProductExitCode -eq 0 -and (Get-ReportStatus -Report $liveProduct) -eq "passed") { "passed" } elseif ($liveProductExitCode -eq 0 -and $productionLocalAggregateStatus -eq "passed-with-live-blockers" -and (Test-StepPassed -LiveProduct $liveProduct -Name "Live service wallet transfer E2E") -and (Test-StepPassed -LiveProduct $liveProduct -Name "Live service tester network E2E")) { "blocked" } else { "failed" }) `
    -Evidence "liveProductExitCode=$liveProductExitCode, liveProductStatus=$(Get-ReportStatus -Report $liveProduct), productionLocalAggregate=$productionLocalAggregateStatus, liveInfra=$liveProductLiveInfraStatus, report=$($paths.liveProduct)" `
    -Commands @("npm run flowchain:live-product:e2e -- -AllowBlocked") `
    -Blockers @($missingEnv)

Add-AuditItem -Items $items -Id "no-secrets-no-broadcasts" `
    -Requirement "Reports and gates do not print secrets/env values and no live Base broadcast occurred." `
    -Status $(if ((Get-ReportStatus -Report $reports.noSecret) -eq "passed" -and $liveProductNoLiveBroadcast -eq $true -and $liveProductEnvValuesPrinted -eq $false -and $baseTxDiagnosticBroadcasts -eq $false -and $baseTxDiagnosticPrintsEnvValues -eq $false -and $baseTxDiagnosticNoSecrets -eq $true -and (Get-AuditProp -Object $devPack -Name "noSecrets" -Default $false) -eq $true -and (Get-AuditProp -Object $devPack -Name "envValuesPrinted" -Default $true) -eq $false) { "passed" } else { "failed" }) `
    -Evidence "noSecretStatus=$(Get-ReportStatus -Report $reports.noSecret), liveProductNoLiveBroadcast=$liveProductNoLiveBroadcast, baseTxDiagnosticBroadcasts=$baseTxDiagnosticBroadcasts, baseTxDiagnosticNoSecrets=$baseTxDiagnosticNoSecrets, devPackNoSecrets=$(Get-AuditProp -Object $devPack -Name "noSecrets" -Default $false), reports=$($paths.noSecret), $($paths.baseTxDiagnostic), $($paths.devPack)" `
    -Commands @("npm run flowchain:no-secret:scan")

$failedItems = @($items | Where-Object { $_.status -eq "failed" })
$blockedItems = @($items | Where-Object { $_.status -eq "blocked" })
$status = if ($failedItems.Count -gt 0) { "failed" } elseif ($blockedItems.Count -gt 0) { "blocked" } else { "passed" }
$completionReady = $status -eq "passed"

$report = [ordered]@{
    schema = "flowchain.completion_audit_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    completionReady = $completionReady
    objective = "FlowChain live infrastructure/public RPC/deployment readiness with wallets, RPC connectivity, bridge readiness, block production, fail-closed owner inputs, no secrets, and no live broadcasts."
    latestHeight = $latestHeight
    liveProductExitCode = $liveProductExitCode
    liveProductOutputRedacted = @($liveProductOutput | ForEach-Object { "$_" })
    serviceStatusExitCode = $serviceStatusExitCode
    serviceStatusOutputRedacted = @($serviceStatusOutput | ForEach-Object { "$_" })
    serviceMonitorExitCode = $serviceMonitorExitCode
    serviceMonitorOutputRedacted = @($serviceMonitorOutput | ForEach-Object { "$_" })
    liveWalletExitCode = $liveWalletExitCode
    liveWalletOutputRedacted = @($liveWalletOutput | ForEach-Object { "$_" })
    testerNetworkExitCode = $testerNetworkExitCode
    testerNetworkOutputRedacted = @($testerNetworkOutput | ForEach-Object { "$_" })
    devPackExitCode = $devPackExitCode
    devPackOutputRedacted = @($devPackOutput | ForEach-Object { "$_" })
    bridgePilotLocalExitCode = $bridgePilotLocalExitCode
    bridgePilotLocalOutputRedacted = @($bridgePilotLocalOutput | ForEach-Object { "$_" })
    baseTxDiagnosticExitCode = $baseTxDiagnosticExitCode
    baseTxDiagnosticOutputRedacted = @($baseTxDiagnosticOutput | ForEach-Object { "$_" })
    ownerInputsValidationExitCode = $ownerInputsValidationExitCode
    ownerInputsValidationOutputRedacted = @($ownerInputsValidationOutput | ForEach-Object { "$_" })
    publicRpcValidationExitCode = $publicRpcValidationExitCode
    publicRpcValidationOutputRedacted = @($publicRpcValidationOutput | ForEach-Object { "$_" })
    publicRpcAbuseTestExitCode = $publicRpcAbuseTestExitCode
    publicRpcAbuseTestOutputRedacted = @($publicRpcAbuseTestOutput | ForEach-Object { "$_" })
    publicTesterGatewayExitCode = $publicTesterGatewayExitCode
    publicTesterGatewayOutputRedacted = @($publicTesterGatewayOutput | ForEach-Object { "$_" })
    backupRestoreValidationExitCode = $backupRestoreValidationExitCode
    backupRestoreValidationOutputRedacted = @($backupRestoreValidationOutput | ForEach-Object { "$_" })
    ownerInputsExitCode = $ownerInputsExitCode
    ownerInputsOutputRedacted = @($ownerInputsOutput | ForEach-Object { "$_" })
    ownerOnboardingExitCode = $ownerOnboardingExitCode
    ownerOnboardingOutputRedacted = @($ownerOnboardingOutput | ForEach-Object { "$_" })
    ownerSignupChecklistExitCode = $ownerSignupChecklistExitCode
    ownerSignupChecklistOutputRedacted = @($ownerSignupChecklistOutput | ForEach-Object { "$_" })
    ownerEnvTemplateExitCode = $ownerEnvTemplateExitCode
    ownerEnvTemplateOutputRedacted = @($ownerEnvTemplateOutput | ForEach-Object { "$_" })
    ownerEnvReadinessValidationExitCode = $ownerEnvReadinessValidationExitCode
    ownerEnvReadinessValidationOutputRedacted = @($ownerEnvReadinessValidationOutput | ForEach-Object { "$_" })
    ownerEnvReadinessExitCode = $ownerEnvReadinessExitCode
    ownerEnvReadinessOutputRedacted = @($ownerEnvReadinessOutput | ForEach-Object { "$_" })
    publicRpcEdgeTemplateExitCode = $publicRpcEdgeTemplateExitCode
    publicRpcEdgeTemplateOutputRedacted = @($publicRpcEdgeTemplateOutput | ForEach-Object { "$_" })
    publicRpcDeploymentBundleExitCode = $publicRpcDeploymentBundleExitCode
    publicRpcDeploymentBundleOutputRedacted = @($publicRpcDeploymentBundleOutput | ForEach-Object { "$_" })
    liveInfraExitCode = $liveInfraExitCode
    liveInfraOutputRedacted = @($liveInfraOutput | ForEach-Object { "$_" })
    externalTesterPacketExitCode = $externalTesterPacketExitCode
    externalTesterPacketOutputRedacted = @($externalTesterPacketOutput | ForEach-Object { "$_" })
    incidentDrillExitCode = $incidentDrillExitCode
    incidentDrillOutputRedacted = @($incidentDrillOutput | ForEach-Object { "$_" })
    opsSnapshotExitCode = $opsSnapshotExitCode
    opsSnapshotOutputRedacted = @($opsSnapshotOutput | ForEach-Object { "$_" })
    publicDeploymentContractExitCode = $publicDeploymentContractExitCode
    publicDeploymentContractOutputRedacted = @($publicDeploymentContractOutput | ForEach-Object { "$_" })
    architectureAuditExitCode = $architectureAuditExitCode
    architectureAuditOutputRedacted = @($architectureAuditOutput | ForEach-Object { "$_" })
    packetExecutableSmokeValidated = $externalTesterPacketExecutableSmokeValidated
    externalTesterLaunchEvidence = [ordered]@{
        externalTesterStatus = $externalTesterStatus
        externalSharingReady = $externalSharingReady
        testerNetworkFresh = $externalTesterNetworkFresh
        packetStatus = $externalTesterPacketStatus
        packetShareable = $externalTesterPacketShareable
        packetExecutableSmokeValidated = $externalTesterPacketExecutableSmokeValidated
        packetSmokeChecks = $externalTesterPacketSmokeChecks
        packetSmokeRoutes = @($externalTesterPacketSmokeRoutes)
        packetPath = $externalTesterPacketPath
        readinessStatus = (Get-ReportStatus -Report $externalTester)
        publicTesterGatewayStatus = $publicTesterGatewayStatus
        publicTesterGatewayPassed = $publicTesterGatewayPassed
        publicDeploymentContractPacketSmoke = $publicDeploymentContractPacketSmoke
    }
    childProcessTimeoutSeconds = $ChildTimeoutSeconds
    childProcessResults = @($script:AuditChildProcessResults)
    itemCounts = [ordered]@{
        passed = @($items | Where-Object { $_.status -eq "passed" }).Count
        blocked = $blockedItems.Count
        failed = $failedItems.Count
        total = $items.Count
    }
    items = @($items)
    missingEnvNames = @($missingEnv)
    exactExternalOwnerInputsRemaining = @($missingEnv)
    reportPaths = $paths
    nextCommandsAfterOwnerInputs = @(
        "npm run flowchain:owner-inputs:validate",
        "npm run flowchain:owner:onboarding",
        "npm run flowchain:owner:signup-checklist",
        "npm run flowchain:owner-env:template",
        "npm run flowchain:owner-env:readiness:validate",
        "npm run flowchain:owner-env:readiness -- -AllowBlocked",
        "npm run flowchain:owner-inputs",
        "npm run flowchain:public-rpc:edge-template",
        "npm run flowchain:public-rpc:deployment-bundle",
        "npm run flowchain:public-rpc:validate",
        "npm run flowchain:public-rpc:abuse-test",
        "npm run flowchain:tester:gateway:e2e",
        "npm run flowchain:backup:restore:validate",
        "npm run flowchain:backup:create",
        "npm run flowchain:backup:restore:verify",
        "npm run flowchain:backup:check",
        "npm run flowchain:service:monitor",
        "npm run flowchain:dev-pack:e2e",
        "npm run flowchain:ops:snapshot",
        "npm run flowchain:ops:incident-drill",
        "npm run flowchain:live-infra:check",
        "npm run flowchain:bridge:diagnose:tx",
        "npm run flowchain:tester:readiness",
        "npm run flowchain:external-tester:packet",
        "npm run flowchain:public-deployment:contract",
        "npm run flowchain:architecture:audit",
        "npm run flowchain:live-product:e2e"
    )
    noLiveBroadcast = $true
    envValuesPrinted = $false
    noSecrets = $true
}

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Completion Audit")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("Completion ready: $completionReady")
$markdownLines.Add("Latest observed height: $latestHeight")
$markdownLines.Add("")
$markdownLines.Add("## Prompt-To-Artifact Checklist")
$markdownLines.Add("")
$markdownLines.Add("| Requirement | Status | Evidence | Commands |")
$markdownLines.Add("| --- | --- | --- | --- |")
foreach ($item in $items) {
    $markdownLines.Add("| $($item.requirement.Replace('|','/')) | $($item.status) | $($item.evidence.Replace('|','/')) | $((@($item.commands)) -join '; ') |")
}
$markdownLines.Add("")
$markdownLines.Add("## Remaining External Owner Inputs")
$markdownLines.Add("")
if ($missingEnv.Count -eq 0) {
    $markdownLines.Add("- None")
}
else {
    foreach ($name in @($missingEnv)) {
        $markdownLines.Add("- $name")
    }
}
$markdownLines.Add("")
$markdownLines.Add("## Completion Decision")
$markdownLines.Add("")
if ($completionReady) {
    $markdownLines.Add("All audited requirements are passed.")
}
else {
    $markdownLines.Add("Do not mark the goal complete. The local L1 and private tester rehearsal are working, but public RPC, tester write gateway, backup, and Base 8453 bridge readiness remain blocked on exact owner inputs.")
}

$reportText = $report | ConvertTo-Json -Depth 20
Assert-FlowChainNoSecretText -Text $reportText -Label "completion audit report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "completion audit markdown"
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain completion audit status: $status"
Write-Host "Completion ready: $completionReady"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($missingEnv.Count -gt 0) {
    Write-Host "Missing env names: $((@($missingEnv)) -join ', ')"
}
if ($status -eq "passed" -or ($status -eq "blocked" -and $AllowBlocked)) {
    exit 0
}
exit 1
