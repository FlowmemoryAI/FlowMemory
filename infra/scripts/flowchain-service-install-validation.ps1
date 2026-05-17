param(
    [string] $TaskName = "FlowChainLiveSupervisor",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/service-install-validation-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/SERVICE_INSTALL_VALIDATION.md",
    [string] $PlanReportPath = "docs/agent-runs/live-product-infra-rpc/service-install-windows-report.json",
    [string] $PlanMarkdownPath = "docs/agent-runs/live-product-infra-rpc/WINDOWS_SERVICE_INSTALL.md",
    [string] $BridgeRelayerPlanReportPath = "docs/agent-runs/live-product-infra-rpc/service-install-windows-bridge-relayer-report.json",
    [string] $BridgeRelayerPlanMarkdownPath = "docs/agent-runs/live-product-infra-rpc/WINDOWS_SERVICE_INSTALL_BRIDGE_RELAYER.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$planReportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $PlanReportPath)
$planMarkdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $PlanMarkdownPath)
$bridgeRelayerPlanReportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $BridgeRelayerPlanReportPath)
$bridgeRelayerPlanMarkdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $BridgeRelayerPlanMarkdownPath)
$installScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-service-install-windows.ps1")
$supervisorScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "infra/scripts/flowchain-service-supervisor.ps1")
$validationTmpDir = Join-Path $repoRoot "devnet/local/tmp/service-install-validation"
New-Item -ItemType Directory -Force -Path $validationTmpDir | Out-Null

function Invoke-ServiceInstallValidationChild {
    param(
        [Parameter(Mandatory = $true)][string[]] $ArgumentList,
        [int] $TimeoutSeconds = 120
    )

    $runId = "$(Get-Date -Format 'yyyyMMddHHmmssfff')-$PID-$([System.Guid]::NewGuid().ToString('N').Substring(0, 8))"
    $stdoutPath = Join-Path $validationTmpDir "$runId.stdout.log"
    $stderrPath = Join-Path $validationTmpDir "$runId.stderr.log"
    $output = @()
    $exitCode = 1
    $timedOut = $false

    try {
        $process = Start-Process -FilePath "powershell" `
            -ArgumentList (Join-FlowChainProcessArguments -ArgumentList $ArgumentList) `
            -WorkingDirectory $repoRoot `
            -PassThru `
            -WindowStyle Hidden `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath
        $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
        if ($timedOut) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            $exitCode = 124
        }
        else {
            $process.Refresh()
            $exitCode = [int]$process.ExitCode
        }
    }
    catch {
        $output += $_.Exception.Message
        $exitCode = 1
    }

    if (Test-Path -LiteralPath $stdoutPath) {
        $output += @(Get-Content -LiteralPath $stdoutPath -Tail 30)
    }
    if (Test-Path -LiteralPath $stderrPath) {
        $output += @(Get-Content -LiteralPath $stderrPath -Tail 30)
    }

    return [ordered]@{
        exitCode = [int]$exitCode
        timedOut = $timedOut
        stdoutPath = $stdoutPath
        stderrPath = $stderrPath
        outputRedacted = @($output | ForEach-Object { "$_" })
    }
}

function Get-ServiceInstallValidationProp {
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

function Test-PackageScript {
    param(
        [Parameter(Mandatory = $true)][AllowNull()][object] $PackageJson,
        [Parameter(Mandatory = $true)][string] $Name
    )

    if ($null -eq $PackageJson -or -not ($PackageJson.PSObject.Properties.Name -contains "scripts")) {
        return $false
    }
    return $PackageJson.scripts.PSObject.Properties.Name -contains $Name
}

$packageJson = Get-Content -Raw -LiteralPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "package.json") | ConvertFrom-Json
$planResult = Invoke-ServiceInstallValidationChild -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $installScriptPath,
    "-Action",
    "Plan",
    "-TaskName",
    $TaskName,
    "-ReportPath",
    $planReportFullPath,
    "-MarkdownPath",
    $planMarkdownFullPath
)

$planReport = Read-FlowChainJsonIfExists -Path $planReportFullPath
$planChecks = Get-ServiceInstallValidationProp -Object $planReport -Name "checks"
$planCommands = Get-ServiceInstallValidationProp -Object $planReport -Name "commands"
$planScheduledTask = Get-ServiceInstallValidationProp -Object $planReport -Name "scheduledTask"

$bridgeRelayerPlanResult = Invoke-ServiceInstallValidationChild -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $installScriptPath,
    "-Action",
    "Plan",
    "-TaskName",
    "$TaskName-BridgeRelayer",
    "-StartBridgeRelayerLoop",
    "-ReportPath",
    $bridgeRelayerPlanReportFullPath,
    "-MarkdownPath",
    $bridgeRelayerPlanMarkdownFullPath
)
$bridgeRelayerPlanReport = Read-FlowChainJsonIfExists -Path $bridgeRelayerPlanReportFullPath
$bridgeRelayerPlanChecks = Get-ServiceInstallValidationProp -Object $bridgeRelayerPlanReport -Name "checks"
$bridgeRelayerPlanScheduledTask = Get-ServiceInstallValidationProp -Object $bridgeRelayerPlanReport -Name "scheduledTask"

$requiredScripts = @(
    "flowchain:service:install:windows",
    "flowchain:service:install:validate",
    "flowchain:service:supervisor",
    "flowchain:service:supervisor:validate",
    "flowchain:service:restart",
    "flowchain:service:status"
)
$missingPackageScripts = @($requiredScripts | Where-Object { -not (Test-PackageScript -PackageJson $packageJson -Name $_) })

$installScriptExists = Test-Path -LiteralPath $installScriptPath
$supervisorScriptExists = Test-Path -LiteralPath $supervisorScriptPath
$planStatus = [string](Get-ServiceInstallValidationProp -Object $planReport -Name "status" -Default "missing")
$planAction = [string](Get-ServiceInstallValidationProp -Object $planReport -Name "action" -Default "")
$planMutationPerformed = [bool](Get-ServiceInstallValidationProp -Object $planReport -Name "taskMutationPerformed" -Default $true)
$planPassed = [int]$planResult.exitCode -eq 0 -and $planStatus -eq "passed" -and $planAction -eq "Plan"
$planDidNotMutate = $planPassed -and ($planMutationPerformed -eq $false)
$scheduledTaskArguments = [string](Get-ServiceInstallValidationProp -Object $planScheduledTask -Name "arguments" -Default "")
$bridgeRelayerPlanStatus = [string](Get-ServiceInstallValidationProp -Object $bridgeRelayerPlanReport -Name "status" -Default "missing")
$bridgeRelayerPlanAction = [string](Get-ServiceInstallValidationProp -Object $bridgeRelayerPlanReport -Name "action" -Default "")
$bridgeRelayerPlanMutationPerformed = [bool](Get-ServiceInstallValidationProp -Object $bridgeRelayerPlanReport -Name "taskMutationPerformed" -Default $true)
$bridgeRelayerPlanPassed = [int]$bridgeRelayerPlanResult.exitCode -eq 0 -and $bridgeRelayerPlanStatus -eq "passed" -and $bridgeRelayerPlanAction -eq "Plan"
$bridgeRelayerPlanDidNotMutate = $bridgeRelayerPlanPassed -and ($bridgeRelayerPlanMutationPerformed -eq $false)
$bridgeRelayerScheduledTaskArguments = [string](Get-ServiceInstallValidationProp -Object $bridgeRelayerPlanScheduledTask -Name "arguments" -Default "")

$checks = [ordered]@{
    installScriptExists = $installScriptExists
    supervisorScriptExists = $supervisorScriptExists
    packageScriptsPresent = $missingPackageScripts.Count -eq 0
    planCommandPassed = $planPassed
    planDidNotMutate = $planDidNotMutate
    schedulerCmdletsAvailable = (Get-ServiceInstallValidationProp -Object $planChecks -Name "schedulerCmdletsAvailable" -Default $false) -eq $true
    scheduledTaskActionSupportsWorkingDirectory = (Get-ServiceInstallValidationProp -Object $planChecks -Name "scheduledTaskActionSupportsWorkingDirectory" -Default $false) -eq $true
    actionUsesSupervisor = (Get-ServiceInstallValidationProp -Object $planChecks -Name "actionUsesSupervisor" -Default $false) -eq $true
    actionUsesRepoWorkingDirectory = (Get-ServiceInstallValidationProp -Object $planChecks -Name "actionUsesRepoWorkingDirectory" -Default $false) -eq $true
    liveProfileDefault = (Get-ServiceInstallValidationProp -Object $planChecks -Name "liveProfileDefault" -Default $false) -eq $true
    noBridgeRelayerDefault = (Get-ServiceInstallValidationProp -Object $planChecks -Name "noBridgeRelayerDefault" -Default $false) -eq $true
    bridgeRelayerOptInPlanCommandPassed = $bridgeRelayerPlanPassed
    bridgeRelayerOptInPlanDidNotMutate = $bridgeRelayerPlanDidNotMutate
    bridgeRelayerOptInStartsLoop = (Get-ServiceInstallValidationProp -Object $bridgeRelayerPlanScheduledTask -Name "startsBridgeRelayerLoop" -Default $false) -eq $true
    bridgeRelayerOptInAddsSupervisorFlag = $bridgeRelayerScheduledTaskArguments -match "(^|\s)-StartBridgeRelayerLoop(\s|$)"
    bridgeRelayerOptInUsesSupervisor = (Get-ServiceInstallValidationProp -Object $bridgeRelayerPlanChecks -Name "actionUsesSupervisor" -Default $false) -eq $true
    hasIntervalSeconds = (Get-ServiceInstallValidationProp -Object $planChecks -Name "hasIntervalSeconds" -Default $false) -eq $true
    hasMaxRestartAttempts = (Get-ServiceInstallValidationProp -Object $planChecks -Name "hasMaxRestartAttempts" -Default $false) -eq $true
    hasMaxStateAgeSeconds = (Get-ServiceInstallValidationProp -Object $planChecks -Name "hasMaxStateAgeSeconds" -Default $false) -eq $true
    commandOmitsNonLiveProfile = $scheduledTaskArguments -notmatch "(^|\s)-NonLiveProfile(\s|$)"
    commandsPresent = -not [string]::IsNullOrWhiteSpace([string](Get-ServiceInstallValidationProp -Object $planCommands -Name "plan" -Default "")) `
        -and -not [string]::IsNullOrWhiteSpace([string](Get-ServiceInstallValidationProp -Object $planCommands -Name "install" -Default "")) `
        -and -not [string]::IsNullOrWhiteSpace([string](Get-ServiceInstallValidationProp -Object $planCommands -Name "status" -Default "")) `
        -and -not [string]::IsNullOrWhiteSpace([string](Get-ServiceInstallValidationProp -Object $planCommands -Name "uninstall" -Default "")) `
        -and -not [string]::IsNullOrWhiteSpace([string](Get-ServiceInstallValidationProp -Object $planCommands -Name "validate" -Default ""))
    envValuesPrintedFalse = (Get-ServiceInstallValidationProp -Object $planReport -Name "envValuesPrinted" -Default $true) -eq $false
    noSecrets = (Get-ServiceInstallValidationProp -Object $planReport -Name "noSecrets" -Default $false) -eq $true
    broadcastsFalse = (Get-ServiceInstallValidationProp -Object $planReport -Name "broadcasts" -Default $true) -eq $false
}

$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.service_install_validation_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    taskName = $TaskName
    checks = $checks
    failedChecks = @($failedChecks)
    missingPackageScripts = @($missingPackageScripts)
    planReportPath = $planReportFullPath
    planMarkdownPath = $planMarkdownFullPath
    childProcessResults = @(
        [ordered]@{
            name = "service-install-plan"
            exitCode = [int]$planResult.exitCode
            timedOut = [bool]$planResult.timedOut
            stdoutPath = [string]$planResult.stdoutPath
            stderrPath = [string]$planResult.stderrPath
        },
        [ordered]@{
            name = "service-install-bridge-relayer-opt-in-plan"
            exitCode = [int]$bridgeRelayerPlanResult.exitCode
            timedOut = [bool]$bridgeRelayerPlanResult.timedOut
            stdoutPath = [string]$bridgeRelayerPlanResult.stdoutPath
            stderrPath = [string]$bridgeRelayerPlanResult.stderrPath
        }
    )
    planReports = [ordered]@{
        default = $planReportFullPath
        bridgeRelayerOptIn = $bridgeRelayerPlanReportFullPath
    }
    commands = [ordered]@{
        plan = "npm run flowchain:service:install:windows -- -Action Plan"
        install = "npm run flowchain:service:install:windows -- -Action Install"
        status = "npm run flowchain:service:install:windows -- -Action Status"
        uninstall = "npm run flowchain:service:install:windows -- -Action Uninstall"
        validate = "npm run flowchain:service:install:validate"
    }
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$reportText = $report | ConvertTo-Json -Depth 18
Assert-FlowChainNoSecretText -Text $reportText -Label "service install validation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Service Install Validation")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This validation proves the Windows Scheduled Task install path is planned, no-secret, live-profile by default, and non-mutating when run in plan mode.")
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("- $($entry.Key): $($entry.Value)")
}
$markdownLines.Add("")
$markdownLines.Add("## Commands")
$markdownLines.Add("")
foreach ($entry in $report.commands.GetEnumerator()) {
    $markdownLines.Add("- $($entry.Key): $($entry.Value)")
}
if ($failedChecks.Count -gt 0) {
    $markdownLines.Add("")
    $markdownLines.Add("## Failed Checks")
    $markdownLines.Add("")
    foreach ($name in $failedChecks) {
        $markdownLines.Add("- $name")
    }
}

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "service install validation markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain service install validation status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    Write-Host "Failed checks: $($failedChecks -join ', ')"
    exit 1
}
exit 0
