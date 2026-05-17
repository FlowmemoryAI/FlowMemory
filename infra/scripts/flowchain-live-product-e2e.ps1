param(
    [string] $ReportDir = "docs/agent-runs/live-product-infra-rpc",
    [int] $ProductionTimeoutSeconds = 7200,
    [int] $ServiceProbeTimeoutSeconds = 180,
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportDir)
$logsDir = Join-Path $reportFullDir "logs"
$reportPath = Join-Path $reportFullDir "flowchain-live-product-e2e-report.json"
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
$optionalMissingEnvNames = @(
    "FLOWCHAIN_BASE8453_CURSOR_STATE",
    "FLOWCHAIN_BASE8453_TO_BLOCK"
)

if ($ProductionTimeoutSeconds -lt 1) {
    throw "ProductionTimeoutSeconds must be at least 1."
}
if ($ServiceProbeTimeoutSeconds -lt 1) {
    throw "ServiceProbeTimeoutSeconds must be at least 1."
}

function Stop-LiveProductProcessTree {
    param([Parameter(Mandatory = $true)][int] $ProcessId)

    $children = @()
    try {
        $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$ProcessId" -ErrorAction SilentlyContinue)
    }
    catch {
        $children = @()
    }
    foreach ($child in $children) {
        Stop-LiveProductProcessTree -ProcessId ([int] $child.ProcessId)
    }
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

function Invoke-LiveProductStep {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $FilePath,
        [string[]] $ArgumentList = @(),
        [string] $ExpectedReportPath = "",
        [int] $TimeoutSeconds = 900,
        [switch] $UseStartProcess,
        [switch] $NoWait
    )

    $safeName = ($Name -replace '[^A-Za-z0-9_.-]', '-').Trim("-")
    $logPath = Join-Path $logsDir "$safeName.log"
    $startedAt = (Get-Date).ToUniversalTime().ToString("o")
    if ($UseStartProcess) {
        try {
            $startArgs = @{
                FilePath = $FilePath
                ArgumentList = (Join-FlowChainProcessArguments -ArgumentList $ArgumentList)
                WorkingDirectory = $repoRoot
                PassThru = $true
                WindowStyle = "Hidden"
            }
            if (-not $NoWait) {
                $timeoutMs = [Math]::Max(1, $TimeoutSeconds) * 1000
            }
            $process = Start-Process @startArgs
            $timedOut = $false
            if ($NoWait) {
                $exitCode = 0
            }
            elseif (-not $process.WaitForExit($timeoutMs)) {
                $timedOut = $true
                Stop-LiveProductProcessTree -ProcessId $process.Id
                $exitCode = 124
            }
            else {
                $exitCode = $process.ExitCode
            }
            $output = @(
                "$(if ($NoWait) { "Started detached process." } else { "Started isolated process." })",
                "FilePath: $FilePath",
                "Arguments: $($ArgumentList -join ' ')",
                "ProcessId: $($process.Id)",
                "TimeoutSeconds: $TimeoutSeconds",
                "TimedOut: $timedOut",
                "ExitCode: $exitCode"
            )
        }
        catch {
            $output = @($_)
            $exitCode = 1
        }
    }
    else {
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $output = & $FilePath @ArgumentList 2>&1
            $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
        }
        catch {
            $output = @($_)
            $exitCode = 1
        }
        finally {
            $ErrorActionPreference = $previousErrorAction
        }
    }
    $output | Set-Content -LiteralPath $logPath -Encoding UTF8
    $endedAt = (Get-Date).ToUniversalTime().ToString("o")
    $childReportStatus = ""
    $childReportFresh = $false
    if (-not [string]::IsNullOrWhiteSpace($ExpectedReportPath) -and (Test-Path -LiteralPath $ExpectedReportPath)) {
        $reportItem = Get-Item -LiteralPath $ExpectedReportPath
        $startedAtUtc = [DateTimeOffset]::Parse($startedAt, [System.Globalization.CultureInfo]::InvariantCulture).UtcDateTime
        $childReportFresh = $reportItem.LastWriteTimeUtc -ge $startedAtUtc.AddSeconds(-2)
        if ($childReportFresh) {
            $childReport = Read-FlowChainJsonIfExists -Path $ExpectedReportPath
            if ($null -ne $childReport -and $childReport.PSObject.Properties.Name -contains "status") {
                $childReportStatus = "$($childReport.status)"
            }
            elseif (
                $null -ne $childReport -and
                $childReport.PSObject.Properties.Name -contains "passFailSummary" -and
                $null -ne $childReport.passFailSummary -and
                $childReport.passFailSummary.PSObject.Properties.Name -contains "overall"
            ) {
                $childReportStatus = "$($childReport.passFailSummary.overall)"
            }
        }
    }
    $stepStatus = if ($childReportStatus -eq "failed") {
        "failed"
    }
    elseif ($childReportStatus -eq "blocked" -or $childReportStatus -eq "passed-with-live-blockers") {
        "blocked"
    }
    elseif ($childReportStatus -eq "passed") {
        "passed"
    }
    elseif ($exitCode -eq 0) {
        "passed"
    }
    else {
        "failed"
    }
    return [ordered]@{
        name = $Name
        command = "$FilePath $($ArgumentList -join ' ')".Trim()
        status = $stepStatus
        childReportStatus = $childReportStatus
        exitCode = $exitCode
        startedAt = $startedAt
        endedAt = $endedAt
        logPath = $logPath
        reportPath = $ExpectedReportPath
        childReportFresh = $childReportFresh
        timedOut = $timedOut
    }
}

function Wait-LiveProductServiceProfile {
    $lastStep = $null
    for ($attempt = 1; $attempt -le 18; $attempt++) {
        Start-Sleep -Seconds 5
        $probe = Invoke-LiveProductStep `
            -Name "Verify live service profile attempt $attempt" `
            -FilePath "powershell" `
            -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-status.ps1"), "-AllowBlocked") `
            -ExpectedReportPath $serviceStatusReportPath `
            -TimeoutSeconds $ServiceProbeTimeoutSeconds `
            -UseStartProcess
        $lastStep = $probe
        if ($probe.status -eq "passed") {
            return $probe
        }
    }
    return $lastStep
}

function New-LiveProductRestoreSteps {
    $restoreSteps = @()
    $restoreSteps += Invoke-LiveProductStep -Name "Restore live service profile" -FilePath "powershell" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-restart.ps1"), "-LiveProfile") -ExpectedReportPath $serviceRestartReportPath -UseStartProcess -NoWait
    $restoreSteps += Wait-LiveProductServiceProfile
    return @($restoreSteps)
}

$productionReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json"
$liveInfraReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/flowchain-live-infra-check-report.json"
$liveServiceWalletReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/live-service-wallet-e2e-report.json"
$liveServiceTesterNetworkReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json"
$serviceStatusReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-status-report.json"
$serviceStopReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-stop-report.json"
$serviceRestartReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-restart-report.json"
$liveInfraCommand = if ($AllowBlocked.IsPresent) {
    "npm.cmd run flowchain:live-infra:check -- -AllowBlocked"
}
else {
    "npm.cmd run flowchain:live-infra:check"
}

Write-Host "FlowChain live-product:e2e aggregate starting."
$steps = @()
$serviceRestoreAttempted = $false
try {
    $steps += Invoke-LiveProductStep -Name "Stop live service before aggregate" -FilePath "powershell" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-service-stop.ps1")) -ExpectedReportPath $serviceStopReportPath -TimeoutSeconds 120 -UseStartProcess
    try {
        $steps += Invoke-LiveProductStep -Name "Production-shaped local L1 aggregate" -FilePath "cmd.exe" -ArgumentList @("/d", "/s", "/c", "npm.cmd run flowchain:production-l1:e2e") -ExpectedReportPath $productionReportPath -TimeoutSeconds $ProductionTimeoutSeconds -UseStartProcess
    }
    finally {
        $steps += New-LiveProductRestoreSteps
        $serviceRestoreAttempted = $true
    }
}
finally {
    if (-not $serviceRestoreAttempted) {
        $steps += New-LiveProductRestoreSteps
        $serviceRestoreAttempted = $true
    }
}
$steps += Invoke-LiveProductStep -Name "Live service wallet transfer E2E" -FilePath "cmd.exe" -ArgumentList @("/d", "/s", "/c", "npm.cmd run flowchain:wallet:live-service:e2e") -ExpectedReportPath $liveServiceWalletReportPath -TimeoutSeconds 600 -UseStartProcess
$steps += Invoke-LiveProductStep -Name "Live service tester network E2E" -FilePath "cmd.exe" -ArgumentList @("/d", "/s", "/c", "npm.cmd run flowchain:wallet:live-tester:e2e") -ExpectedReportPath $liveServiceTesterNetworkReportPath -TimeoutSeconds 900 -UseStartProcess
$steps += Invoke-LiveProductStep -Name "Live infrastructure readiness" -FilePath "cmd.exe" -ArgumentList @("/d", "/s", "/c", $liveInfraCommand) -ExpectedReportPath $liveInfraReportPath -TimeoutSeconds 900 -UseStartProcess

$productionReport = Read-FlowChainJsonIfExists -Path $productionReportPath
$liveInfraReport = Read-FlowChainJsonIfExists -Path $liveInfraReportPath
$missingEnv = New-Object System.Collections.ArrayList
if ($null -ne $productionReport -and $productionReport.PSObject.Properties.Name -contains "missingEnvNamesForLiveMode") {
    foreach ($name in @($productionReport.missingEnvNamesForLiveMode)) {
        if (-not [string]::IsNullOrWhiteSpace("$name") -and $name -notin $optionalMissingEnvNames) { [void] $missingEnv.Add("$name") }
    }
}
if ($null -ne $liveInfraReport -and $liveInfraReport.PSObject.Properties.Name -contains "missingEnvNames") {
    foreach ($name in @($liveInfraReport.missingEnvNames)) {
        if (-not [string]::IsNullOrWhiteSpace("$name") -and $name -notin $optionalMissingEnvNames) { [void] $missingEnv.Add("$name") }
    }
}

$failedSteps = @($steps | Where-Object { $_.status -eq "failed" })
$blockedSteps = @($steps | Where-Object { $_.status -eq "blocked" })
$productionOverall = if ($null -ne $productionReport -and $productionReport.PSObject.Properties.Name -contains "passFailSummary") {
    $productionReport.passFailSummary.overall
} else {
    "unknown"
}
$liveInfraStatus = if ($null -ne $liveInfraReport -and $liveInfraReport.PSObject.Properties.Name -contains "status") {
    $liveInfraReport.status
} else {
    "unknown"
}
$overallStatus = if ($failedSteps.Count -gt 0 -or $productionOverall -eq "failed" -or $liveInfraStatus -eq "failed") {
    "failed"
} elseif ($blockedSteps.Count -gt 0 -or $productionOverall -ne "passed" -or $liveInfraStatus -ne "passed") {
    "blocked"
} else {
    "passed"
}

$report = [ordered]@{
    schema = "flowchain.live_product_e2e_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $overallStatus
    productionLocalAggregateStatus = $productionOverall
    liveInfraStatus = $liveInfraStatus
    stepCounts = [ordered]@{
        passed = @($steps | Where-Object { $_.status -eq "passed" }).Count
        blocked = $blockedSteps.Count
        failed = $failedSteps.Count
        total = $steps.Count
    }
    blockedStepNames = @($blockedSteps | ForEach-Object { $_.name })
    failedStepNames = @($failedSteps | ForEach-Object { $_.name })
    steps = $steps
    serviceRestoreAttempted = $serviceRestoreAttempted
    productionTimeoutSeconds = $ProductionTimeoutSeconds
    serviceProbeTimeoutSeconds = $ServiceProbeTimeoutSeconds
    missingEnvNames = @($missingEnv | Select-Object -Unique)
    reportPaths = [ordered]@{
        serviceStop = $serviceStopReportPath
        productionLocalAggregate = $productionReportPath
        serviceRestart = $serviceRestartReportPath
        liveServiceWallet = $liveServiceWalletReportPath
        liveServiceTesterNetwork = $liveServiceTesterNetworkReportPath
        liveInfra = $liveInfraReportPath
        liveProduct = $reportPath
    }
    noLiveBroadcast = $true
    envValuesPrinted = $false
    noSecrets = $true
}
Write-FlowChainJson -Path $reportPath -Value $report -Depth 16

Write-Host "FlowChain live-product:e2e status: $overallStatus"
Write-Host "Report: $reportPath"
if ($missingEnv.Count -gt 0) {
    Write-Host "Missing env names: $((@($missingEnv | Select-Object -Unique)) -join ', ')"
}
if ($overallStatus -eq "blocked" -and $AllowBlocked) {
    [System.Environment]::Exit(0)
}
if ($overallStatus -ne "passed") {
    Write-Error "FlowChain live-product:e2e $overallStatus. See report for exact missing env, report, and log paths."
    [System.Environment]::Exit(1)
}
[System.Environment]::Exit(0)
