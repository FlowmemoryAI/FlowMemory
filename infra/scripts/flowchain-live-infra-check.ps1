param(
    [string] $ReportDir = "docs/agent-runs/live-product-infra-rpc",
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportDir)
$logsDir = Join-Path $reportFullDir "logs"
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

$reportPath = Join-Path $reportFullDir "flowchain-live-infra-check-report.json"
$steps = New-Object System.Collections.ArrayList
$commandsRun = New-Object System.Collections.ArrayList

function Get-LiveInfraSafeStepName {
    param([Parameter(Mandatory = $true)][string] $Name)
    return (($Name -replace '[^A-Za-z0-9_.-]', '-') -replace '-+', '-').Trim("-")
}

function Invoke-LiveInfraStep {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Command,
        [Parameter(Mandatory = $true)][string] $FilePath,
        [string[]] $ArgumentList = @(),
        [string] $ExpectedReportPath = "",
        [switch] $AllowFailure
    )

    $safe = Get-LiveInfraSafeStepName -Name $Name
    $logPath = Join-Path $logsDir "$safe.log"
    [void] $commandsRun.Add($Command)
    Write-Host ""
    Write-Host "== $Name =="
    Write-Host $Command

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = (& $FilePath @ArgumentList 2>&1) | ForEach-Object { "$_" }
        $exitCode = $LASTEXITCODE
    }
    catch {
        $output = @($_.Exception.Message)
        $exitCode = 1
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $output | Set-Content -LiteralPath $logPath -Encoding UTF8
    $status = if ($exitCode -eq 0) { "passed" } elseif ($AllowFailure) { "blocked" } else { "failed" }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedReportPath) -and (Test-Path -LiteralPath $ExpectedReportPath)) {
        $childReport = Read-FlowChainJsonIfExists -Path $ExpectedReportPath
        if ($null -ne $childReport -and $childReport.PSObject.Properties.Name -contains "status") {
            $childStatus = "$($childReport.status)"
            if ($childStatus -in @("blocked", "failed")) {
                $status = $childStatus
            }
        }
    }
    [void] $steps.Add([ordered]@{
        name = $Name
        command = $Command
        status = $status
        exitCode = $exitCode
        logPath = $logPath
        reportPath = $ExpectedReportPath
        reason = if ($exitCode -eq 0) { "" } else { (($output | Select-Object -Last 12) -join [Environment]::NewLine) }
    })
    Write-Host "$($status.ToUpperInvariant()): $Name"
}

function Get-ReportStatus {
    param([AllowNull()][object] $Report)
    if ($null -eq $Report) { return "missing" }
    if ($Report.PSObject.Properties.Name -contains "status") { return "$($Report.status)" }
    return "unknown"
}

function Add-MissingNamesFromReport {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [AllowNull()][object] $Report,
        [ValidateSet("env", "artifact", "process")]
        [string] $Category = "env"
    )

    if ($null -eq $Report) {
        return
    }
    if ($Category -eq "env" -and $Report.PSObject.Properties.Name -contains "missingEnvNames") {
        foreach ($name in @($Report.missingEnvNames)) {
            if (-not [string]::IsNullOrWhiteSpace("$name")) {
                [void] $Target.Add("$name")
            }
        }
    }
    if ($Report.PSObject.Properties.Name -contains "problems") {
        foreach ($problem in @($Report.problems)) {
            if ($problem.PSObject.Properties.Name -contains "category" -and "$($problem.category)" -eq $Category) {
                [void] $Target.Add("$($problem.name)")
            }
        }
    }
}

$publicReportPath = Join-Path $reportFullDir "public-rpc-readiness-report.json"
$ownerInputsReportPath = Join-Path $reportFullDir "owner-inputs-report.json"
$serviceReportPath = Join-Path $reportFullDir "service-status-report.json"
$backupReportPath = Join-Path $reportFullDir "backup-readiness-report.json"
$bridgeLiveReportPath = Join-Path $reportFullDir "bridge-live-readiness-report.json"
$bridgeInfraReportPath = Join-Path $reportFullDir "bridge-infra-readiness-report.json"
$bridgeRelayerReportPath = Join-Path $reportFullDir "bridge-relayer-once-report.json"
$noSecretReportPath = Join-Path $reportFullDir "live-infra-no-secret-scan-report.json"

Invoke-LiveInfraStep `
    -Name "Owner input contract" `
    -Command "powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-owner-inputs.ps1 -AllowBlocked" `
    -FilePath "powershell" `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-owner-inputs.ps1"), "-ReportPath", $ownerInputsReportPath, "-AllowBlocked") `
    -ExpectedReportPath $ownerInputsReportPath `
    -AllowFailure

Invoke-LiveInfraStep `
    -Name "Public RPC readiness" `
    -Command "powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-public-rpc-readiness.ps1 -AllowBlocked" `
    -FilePath "powershell" `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-readiness.ps1"), "-ReportPath", $publicReportPath, "-AllowBlocked") `
    -ExpectedReportPath $publicReportPath `
    -AllowFailure

Invoke-LiveInfraStep `
    -Name "Service process status" `
    -Command "powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-service-status.ps1 -AllowBlocked" `
    -FilePath "powershell" `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-status.ps1"), "-ReportPath", $serviceReportPath, "-AllowBlocked") `
    -ExpectedReportPath $serviceReportPath `
    -AllowFailure

Invoke-LiveInfraStep `
    -Name "Backup readiness" `
    -Command "powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-public-rpc-backup-readiness.ps1 -AllowBlocked" `
    -FilePath "powershell" `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-public-rpc-backup-readiness.ps1"), "-ReportPath", $backupReportPath, "-AllowBlocked") `
    -ExpectedReportPath $backupReportPath `
    -AllowFailure

Invoke-LiveInfraStep `
    -Name "Bridge live readiness" `
    -Command "powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-bridge-live-check.ps1 -AllowBlocked" `
    -FilePath "powershell" `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-live-check.ps1"), "-ReportPath", $bridgeLiveReportPath, "-AllowBlocked") `
    -ExpectedReportPath $bridgeLiveReportPath `
    -AllowFailure

Invoke-LiveInfraStep `
    -Name "Bridge infra readiness" `
    -Command "powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-live-env-bridge-readiness.ps1 -AllowBlocked" `
    -FilePath "powershell" `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-live-env-bridge-readiness.ps1"), "-ReportPath", $bridgeInfraReportPath, "-AllowBlocked") `
    -ExpectedReportPath $bridgeInfraReportPath `
    -AllowFailure

Invoke-LiveInfraStep `
    -Name "Bridge relayer once" `
    -Command "powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-bridge-relayer-once.ps1 -AllowBlocked" `
    -FilePath "powershell" `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-bridge-relayer-once.ps1"), "-ReportPath", $bridgeRelayerReportPath, "-RunDir", "devnet/local/bridge-relayer-once", "-AllowBlocked") `
    -ExpectedReportPath $bridgeRelayerReportPath `
    -AllowFailure

Invoke-LiveInfraStep `
    -Name "No-secret scan live infra reports" `
    -Command "powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-no-secret-scan.ps1 -Paths docs/agent-runs/live-product-infra-rpc devnet/local/bridge-live-readiness devnet/local/services -ReportPath docs/agent-runs/live-product-infra-rpc/live-infra-no-secret-scan-report.json" `
    -FilePath "powershell" `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-no-secret-scan.ps1"), "-Paths", "docs/agent-runs/live-product-infra-rpc", "devnet/local/bridge-live-readiness", "devnet/local/services", "-ReportPath", $noSecretReportPath) `
    -ExpectedReportPath $noSecretReportPath `
    -AllowFailure

$publicReport = Read-FlowChainJsonIfExists -Path $publicReportPath
$ownerInputsReport = Read-FlowChainJsonIfExists -Path $ownerInputsReportPath
$serviceReport = Read-FlowChainJsonIfExists -Path $serviceReportPath
$backupReport = Read-FlowChainJsonIfExists -Path $backupReportPath
$bridgeLiveReport = Read-FlowChainJsonIfExists -Path $bridgeLiveReportPath
$bridgeInfraReport = Read-FlowChainJsonIfExists -Path $bridgeInfraReportPath
$bridgeRelayerReport = Read-FlowChainJsonIfExists -Path $bridgeRelayerReportPath
$noSecretReport = Read-FlowChainJsonIfExists -Path $noSecretReportPath

$missingEnvNames = New-Object System.Collections.ArrayList
foreach ($report in @($ownerInputsReport, $publicReport, $backupReport, $bridgeLiveReport, $bridgeInfraReport, $bridgeRelayerReport)) {
    Add-MissingNamesFromReport -Target $missingEnvNames -Report $report -Category "env"
}
$invalidEnvNames = New-Object System.Collections.ArrayList
if ($null -ne $ownerInputsReport -and $ownerInputsReport.PSObject.Properties.Name -contains "invalidEnvNames") {
    foreach ($name in @($ownerInputsReport.invalidEnvNames)) {
        if (-not [string]::IsNullOrWhiteSpace("$name")) {
            [void] $invalidEnvNames.Add("$name")
        }
    }
}
$missingArtifactNames = New-Object System.Collections.ArrayList
foreach ($report in @($publicReport, $serviceReport, $backupReport, $bridgeInfraReport)) {
    Add-MissingNamesFromReport -Target $missingArtifactNames -Report $report -Category "artifact"
}
$missingProcessNames = New-Object System.Collections.ArrayList
Add-MissingNamesFromReport -Target $missingProcessNames -Report $serviceReport -Category "process"

$reportStatuses = [ordered]@{
    ownerInputs = Get-ReportStatus -Report $ownerInputsReport
    publicRpc = Get-ReportStatus -Report $publicReport
    services = Get-ReportStatus -Report $serviceReport
    backup = Get-ReportStatus -Report $backupReport
    bridgeLive = Get-ReportStatus -Report $bridgeLiveReport
    bridgeInfra = Get-ReportStatus -Report $bridgeInfraReport
    bridgeRelayer = Get-ReportStatus -Report $bridgeRelayerReport
    noSecretScan = Get-ReportStatus -Report $noSecretReport
}

$ownerInputsReady = ($ownerInputsReport -and $ownerInputsReport.PSObject.Properties.Name -contains "ownerInputReady" -and $ownerInputsReport.ownerInputReady -eq $true)
$publicReady = ($publicReport -and $publicReport.PSObject.Properties.Name -contains "publicRpcReady" -and $publicReport.publicRpcReady -eq $true)
$servicesReady = $reportStatuses.services -eq "passed"
$backupReady = $reportStatuses.backup -eq "passed"
$bridgeReady = $reportStatuses.bridgeLive -eq "passed" -and $reportStatuses.bridgeInfra -eq "passed" -and $reportStatuses.bridgeRelayer -eq "passed"
$noSecretReady = $reportStatuses.noSecretScan -eq "passed"

$failedStatuses = @($reportStatuses.GetEnumerator() | Where-Object { $_.Value -eq "failed" -or $_.Value -eq "missing" })
$overallStatus = if ($failedStatuses.Count -gt 0) {
    "failed"
}
elseif ($ownerInputsReady -and $publicReady -and $servicesReady -and $backupReady -and $bridgeReady -and $noSecretReady) {
    "passed"
}
else {
    "blocked"
}

$finalReport = [ordered]@{
    schema = "flowchain.live_infra_check_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $overallStatus
    repoPath = $repoRoot
    git = [ordered]@{
        branch = (& git rev-parse --abbrev-ref HEAD).Trim()
        commit = (& git rev-parse HEAD).Trim()
    }
    readiness = [ordered]@{
        ownerInputsReady = $ownerInputsReady
        publicRpcReady = $publicReady
        servicesReady = $servicesReady
        backupReady = $backupReady
        bridgeReady = $bridgeReady
        noSecretReady = $noSecretReady
    }
    reportStatuses = $reportStatuses
    missingEnvNames = @($missingEnvNames | Select-Object -Unique)
    invalidEnvNames = @($invalidEnvNames | Select-Object -Unique)
    missingArtifactNames = @($missingArtifactNames | Select-Object -Unique)
    blockedArtifactNames = @($missingArtifactNames | Select-Object -Unique)
    missingProcessNames = @($missingProcessNames | Select-Object -Unique)
    blockedProcessNames = @($missingProcessNames | Select-Object -Unique)
    commandList = @($commandsRun)
    steps = @($steps)
    reportPaths = [ordered]@{
        ownerInputs = $ownerInputsReportPath
        publicRpc = $publicReportPath
        services = $serviceReportPath
        backup = $backupReportPath
        bridgeLive = $bridgeLiveReportPath
        bridgeInfra = $bridgeInfraReportPath
        bridgeRelayer = $bridgeRelayerReportPath
        noSecretScan = $noSecretReportPath
        logs = $logsDir
    }
    blockedUntil = [ordered]@{
        ownerInputs = "Provide structurally valid owner public RPC, backup, and Base 8453 bridge env names without committing values."
        publicRpc = "Configure FLOWCHAIN_RPC_* env names and run the control-plane behind TLS/rate-limit/CORS enforcement."
        services = "Run npm run flowchain:service:start -- -LiveProfile after local state exists."
        backup = "Provide FLOWCHAIN_RPC_STATE_BACKUP_PATH as an existing writable directory; backup readiness will create a manifest-backed snapshot and verify restore rehearsal."
        bridge = "Provide the Base 8453 env contract and an owner-verified lockbox with deployed bytecode, then run the relayer once gate to queue new credits into the L1."
    }
    broadcasts = $false
    envValuesPrinted = $false
    noSecrets = $noSecretReady
}
Write-FlowChainJson -Path $reportPath -Value $finalReport -Depth 20

Write-Host ""
Write-Host "FlowChain live infra status: $overallStatus"
Write-Host "Report: $reportPath"
if ($finalReport.missingEnvNames.Count -gt 0) {
    Write-Host "Missing env names: $($finalReport.missingEnvNames -join ', ')"
}
if ($finalReport.invalidEnvNames.Count -gt 0) {
    Write-Host "Invalid env names: $($finalReport.invalidEnvNames -join ', ')"
}
if ($finalReport.blockedArtifactNames.Count -gt 0) {
    Write-Host "Blocked artifact names: $($finalReport.blockedArtifactNames -join ', ')"
}
if ($finalReport.blockedProcessNames.Count -gt 0) {
    Write-Host "Blocked process names: $($finalReport.blockedProcessNames -join ', ')"
}

if ($overallStatus -ne "passed" -and -not $AllowBlocked) {
    throw "FlowChain live infra check $overallStatus. See report for exact missing env, artifact, and process names."
}
