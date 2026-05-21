param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/dashboard-ui-readiness-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/DASHBOARD_UI_READINESS.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$dashboardPackagePath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "apps/dashboard/package.json"
$rootPackagePath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "package.json"
$playwrightConfigPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "apps/dashboard/playwright.config.ts"
$browserSpecPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "apps/dashboard/e2e/flowchain-ui-readiness.spec.ts"
$npmCommand = (Get-Command "npm.cmd" -ErrorAction Stop).Source

function Read-JsonObject {
    param([Parameter(Mandatory = $true)][string] $Path)
    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Test-ScriptExists {
    param(
        [Parameter(Mandatory = $true)][object] $PackageJson,
        [Parameter(Mandatory = $true)][string] $Name
    )

    $scripts = $PackageJson.scripts
    if ($null -eq $scripts) {
        return $false
    }
    return $null -ne $scripts.PSObject.Properties[$Name]
}

function Stop-DashboardUiProcessTree {
    param([Parameter(Mandatory = $true)][int] $ProcessId)

    $children = @(Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $ProcessId })
    foreach ($child in $children) {
        Stop-DashboardUiProcessTree -ProcessId ([int] $child.ProcessId)
    }

    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

function Invoke-DashboardUiCommand {
    param(
        [Parameter(Mandatory = $true)][string] $Label,
        [Parameter(Mandatory = $true)][string[]] $ArgumentList,
        [int] $TimeoutSeconds = 300
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $npmCommand
    $psi.Arguments = Join-FlowChainProcessArguments -ArgumentList $ArgumentList
    $psi.WorkingDirectory = $repoRoot
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $startedAt = [DateTimeOffset]::UtcNow
    [void] $process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        Stop-DashboardUiProcessTree -ProcessId $process.Id
        [void] $process.WaitForExit(5000)
    }
    else {
        $process.WaitForExit()
    }
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    $finishedAt = [DateTimeOffset]::UtcNow
    $exitCode = if ($timedOut) { 124 } else { $process.ExitCode }

    $command = "npm $($ArgumentList -join ' ')"
    Write-Host "$Label exit code: $exitCode"
    return [ordered]@{
        label = $Label
        command = $command
        exitCode = $exitCode
        timeoutSeconds = $TimeoutSeconds
        timedOut = $timedOut
        durationSeconds = [int][Math]::Max(0, [Math]::Ceiling(($finishedAt - $startedAt).TotalSeconds))
        stdoutLineCount = @($stdout -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
        stderrLineCount = @($stderr -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
    }
}

function Get-DashboardUiSecretMarkerFindings {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string] $Label
    )

    $findings = New-Object System.Collections.ArrayList
    foreach ($pattern in @(
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
        )) {
        if ($Text.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            [void] $findings.Add([ordered]@{ label = $Label; pattern = $pattern })
        }
    }
    return @($findings)
}

$dashboardPackage = Read-JsonObject -Path $dashboardPackagePath
$rootPackage = Read-JsonObject -Path $rootPackagePath
$specText = if (Test-Path -LiteralPath $browserSpecPath) { Get-Content -Raw -LiteralPath $browserSpecPath } else { "" }
$configText = if (Test-Path -LiteralPath $playwrightConfigPath) { Get-Content -Raw -LiteralPath $playwrightConfigPath } else { "" }
$workbenchViewPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "apps/dashboard/src/views/WorkbenchView.tsx"
$ownerActivationViewPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "apps/dashboard/src/views/OwnerActivationView.tsx"
$opsViewPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "apps/dashboard/src/views/OpsView.tsx"
$alertsViewPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "apps/dashboard/src/views/AlertsView.tsx"
$workbenchDataPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "apps/dashboard/src/data/workbench.ts"
$fixtureSyncPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "apps/dashboard/scripts/sync-fixtures.mjs"
$workbenchText = @(
    if (Test-Path -LiteralPath $workbenchViewPath) { Get-Content -Raw -LiteralPath $workbenchViewPath } else { "" }
    if (Test-Path -LiteralPath $ownerActivationViewPath) { Get-Content -Raw -LiteralPath $ownerActivationViewPath } else { "" }
    if (Test-Path -LiteralPath $opsViewPath) { Get-Content -Raw -LiteralPath $opsViewPath } else { "" }
    if (Test-Path -LiteralPath $alertsViewPath) { Get-Content -Raw -LiteralPath $alertsViewPath } else { "" }
    if (Test-Path -LiteralPath $workbenchDataPath) { Get-Content -Raw -LiteralPath $workbenchDataPath } else { "" }
    if (Test-Path -LiteralPath $fixtureSyncPath) { Get-Content -Raw -LiteralPath $fixtureSyncPath } else { "" }
) -join "`n"

$commands = @(
    (Invoke-DashboardUiCommand -Label "dashboard unit render tests" -ArgumentList @("test", "--prefix", "apps/dashboard") -TimeoutSeconds 180),
    (Invoke-DashboardUiCommand -Label "dashboard browser wallet faucet explorer loop" -ArgumentList @("run", "browser:e2e", "--prefix", "apps/dashboard", "--", "--workers=1") -TimeoutSeconds 300),
    (Invoke-DashboardUiCommand -Label "dashboard production build" -ArgumentList @("run", "build", "--prefix", "apps/dashboard") -TimeoutSeconds 300),
    (Invoke-DashboardUiCommand -Label "control-plane tester gateway tests" -ArgumentList @("test", "--prefix", "services/control-plane") -TimeoutSeconds 600)
)

$checks = [ordered]@{
    dashboardPackageScriptPresent = Test-ScriptExists -PackageJson $dashboardPackage -Name "browser:e2e"
    rootPackageScriptPresent = Test-ScriptExists -PackageJson $rootPackage -Name "flowchain:dashboard:ui:readiness"
    playwrightConfigExists = Test-Path -LiteralPath $playwrightConfigPath
    browserSpecExists = Test-Path -LiteralPath $browserSpecPath
    desktopProjectConfigured = $configText.Contains("chromium-desktop")
    mobileProjectConfigured = $configText.Contains("chromium-mobile")
    walletTesterRouteCovered = $specText.Contains("/wallet?panel=tester")
    testerWalletCreateCovered = $specText.Contains("/tester/wallets/create")
    testerFaucetCovered = $specText.Contains("/tester/faucet")
    testerSendCovered = $specText.Contains("/tester/wallets/send")
    explorerRouteCovered = $specText.Contains("/explorer")
    testerLaunchRouteCovered = $specText.Contains("/tester")
    activationRouteCovered = $specText.Contains("/activation")
    bridgeRouteCovered = $specText.Contains("/bridge")
    opsRouteCovered = $specText.Contains("/ops")
    alertsRouteCovered = $specText.Contains("/alerts")
    bridgePilotRuntimeProofCovered = $specText.Contains("Bridge runtime proof") -and $specText.Contains("Runtime credit") -and $specText.Contains("Relayer guardrail") -and $specText.Contains("Pilot aggregate")
    bridgeRuntimeCreditProofCovered = $specText.Contains("Bridge runtime credit") -and $specText.Contains("flowchain:bridge:runtime-credit:validate") -and $workbenchText.Contains("base8453-bridge-runtime-credit-proof")
    bridgeCommandMatrixProofCovered = $specText.Contains("Bridge command matrix") -and $specText.Contains("flowchain:bridge:command-matrix") -and $workbenchText.Contains("bridgeCommandMatrix")
    bridgeReconciliationScheduleProofCovered = $specText.Contains("Reconciliation schedule") -and $specText.Contains("flowchain:bridge:reconciliation:schedule:validate") -and $workbenchText.Contains("bridgeReconciliationSchedule")
    realValuePilotAggregateProofCovered = $specText.Contains("Pilot aggregate") -and $specText.Contains("proof commands") -and $workbenchText.Contains("pilot aggregate")
    opsObservabilityProofCovered = $specText.Contains("Ops center") -and $specText.Contains("Active rules") -and $specText.Contains("Ops install proof") -and $workbenchText.Contains("opsMetricCount")
    alertsListProofCovered = $specText.Contains("Verifier failed") -and $specText.Contains("UPSTREAM_LOSS") -and $workbenchText.Contains("recommendedAction")
    publicRpcHeaderProofCovered = $specText.Contains("RPC headers")
    publicRpcCommandMatrixProofCovered = $specText.Contains("RPC command matrix") -and $specText.Contains("flowchain:public-rpc:command-matrix") -and $workbenchText.Contains("publicRpcCommandMatrix")
    ownerHostApplyPlanProofCovered = $specText.Contains("owner-host-apply.sh plan") -and $workbenchText.Contains("launchSequence") -and $workbenchText.Contains("Owner host apply proof")
    ownerHostApplyExecutionProofCovered = $specText.Contains("owner-host-apply.sh apply") -and $workbenchText.Contains("launchSequenceCoversOwnerHostApplyExecution")
    ownerHostApplyRollbackProofCovered = $specText.Contains("owner-host-apply.sh rollback") -and $workbenchText.Contains("rollbackCommands")
    ownerNeedsNowReportCopied = $workbenchText.Contains("owner-needs-now-report.json") -and $workbenchText.Contains("ownerNeedsNow")
    ownerNeedsNowGroupsCovered = $specText.Contains("Owner setup groups") -and $specText.Contains("Public RPC edge validation commands") -and $workbenchText.Contains("neededNowGroups")
    ownerNeedsNowActionsCovered = $specText.Contains("Pick the public RPC URL") -and $workbenchText.Contains("ownerAction")
    ownerNeedsNowReadyGroupCovered = $specText.Contains("Ready setup groups") -and $specText.Contains("Tester write gateway") -and $workbenchText.Contains("readyGroups")
    noSecretLeakageAsserted = $specText.Contains("expectNoUiLeakage")
    noHorizontalOverflowAsserted = $specText.Contains("expectNoHorizontalOverflow")
    dashboardUnitTestsPassed = ($commands | Where-Object { $_.label -eq "dashboard unit render tests" } | Select-Object -First 1).exitCode -eq 0
    dashboardBrowserE2ePassed = ($commands | Where-Object { $_.label -eq "dashboard browser wallet faucet explorer loop" } | Select-Object -First 1).exitCode -eq 0
    dashboardBuildPassed = ($commands | Where-Object { $_.label -eq "dashboard production build" } | Select-Object -First 1).exitCode -eq 0
    controlPlaneTesterGatewayTestsPassed = ($commands | Where-Object { $_.label -eq "control-plane tester gateway tests" } | Select-Object -First 1).exitCode -eq 0
    commandsCompletedWithoutTimeout = @($commands | Where-Object { $_.timedOut -eq $true }).Count -eq 0
    secretMarkerFindingsEmpty = $true
    envValuesPrintedFalse = $true
    noSecrets = $true
    broadcastsFalse = $true
}

$report = [ordered]@{
    schema = "flowchain.dashboard_ui_readiness_report.v0"
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    status = "pending"
    checks = $checks
    failedChecks = @()
    secretMarkerFindings = @()
    commands = @($commands)
    browserProjects = @("chromium-desktop", "chromium-mobile")
    coveredRoutes = @("/wallet?panel=tester", "/tester/wallets/create", "/tester/faucet", "/tester/wallets/send", "/explorer", "/tester", "/activation", "/bridge", "/ops", "/alerts")
    coveredProofs = @("base8453-bridge-command-matrix-proof", "base8453-bridge-runtime-credit-proof", "base8453-bridge-reconciliation-schedule-proof", "real-value-pilot-aggregate-proof", "public-rpc-command-matrix-proof", "owner-needs-now-groups", "owner-host-apply-plan", "owner-host-apply-execution", "owner-host-apply-rollback", "ops-observability-proof", "alerts-list-proof")
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$preliminaryReportText = $report | ConvertTo-Json -Depth 12
$secretMarkerFindings = @(Get-DashboardUiSecretMarkerFindings -Text $preliminaryReportText -Label "dashboard UI readiness report")
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
Assert-FlowChainNoSecretText -Text $reportText -Label "dashboard UI readiness report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 12

$markdownLines = New-Object System.Collections.ArrayList
[void] $markdownLines.Add("# FlowChain Dashboard UI Readiness")
[void] $markdownLines.Add("")
[void] $markdownLines.Add("Generated: $($report.generatedAt)")
[void] $markdownLines.Add("Status: $status")
[void] $markdownLines.Add("")
[void] $markdownLines.Add("## Coverage")
[void] $markdownLines.Add("")
[void] $markdownLines.Add("- Browser projects: chromium-desktop, chromium-mobile")
[void] $markdownLines.Add("- Loop: wallet tester panel -> tester wallet create -> tester faucet -> tester send -> explorer inspection -> tester launch RPC header proof -> tester launch RPC command-matrix proof -> activation cockpit owner-input proof -> owner needs-now grouped action proof -> owner host apply plan/apply/rollback proof -> bridge pilot command-matrix proof -> bridge pilot runtime proof -> bridge runtime credit proof -> bridge reconciliation schedule proof -> real-value pilot aggregate proof -> ops observability proof -> alert list proof")
[void] $markdownLines.Add("- Assertions: no secret text/storage leakage, no horizontal viewport overflow, no browser console errors")
[void] $markdownLines.Add("")
[void] $markdownLines.Add("## Commands")
[void] $markdownLines.Add("")
foreach ($command in @($commands)) {
    [void] $markdownLines.Add("- $($command.command): exit $($command.exitCode)")
}
[void] $markdownLines.Add("")
if ($failedChecks.Count -gt 0) {
    [void] $markdownLines.Add("## Failed Checks")
    [void] $markdownLines.Add("")
    foreach ($check in @($failedChecks)) {
        [void] $markdownLines.Add("- $check")
    }
}
else {
    [void] $markdownLines.Add("All dashboard UI readiness checks passed.")
}

$markdownText = (@($markdownLines) -join [Environment]::NewLine) + [Environment]::NewLine
Assert-FlowChainNoSecretText -Text $markdownText -Label "dashboard UI readiness markdown"
$markdownParent = Split-Path -Parent $markdownFullPath
if (-not [string]::IsNullOrWhiteSpace($markdownParent)) {
    New-Item -ItemType Directory -Force -Path $markdownParent | Out-Null
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($markdownFullPath, $markdownText, $utf8NoBom)

Write-Host "FlowChain dashboard UI readiness status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"

if ($status -ne "passed") {
    exit 1
}
