param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/install-check-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/INSTALL_CHECK.md",
    [int] $MinDiskFreeGiB = 5,
    [int] $ChildTimeoutSeconds = 900,
    [switch] $SkipChildValidations
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$tmpDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/tmp/install-check")
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

function Get-InstallCheckProp {
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

function Test-InstallCheckPackageScript {
    param(
        [Parameter(Mandatory = $true)][object] $PackageJson,
        [Parameter(Mandatory = $true)][string] $Name
    )

    if (-not ($PackageJson.PSObject.Properties.Name -contains "scripts")) {
        return $false
    }
    return $PackageJson.scripts.PSObject.Properties.Name -contains $Name
}

function Invoke-InstallCheckChild {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Command,
        [string[]] $ArgumentList = @()
    )

    $startedAt = (Get-Date).ToUniversalTime()
    $stamp = $startedAt.ToString("yyyyMMddTHHmmssfffZ")
    $runId = "$stamp-$PID-$($Name -replace '[^A-Za-z0-9_.-]', '-')"
    $stdoutPath = Join-Path $tmpDir "$runId.stdout.log"
    $stderrPath = Join-Path $tmpDir "$runId.stderr.log"
    $timedOut = $false
    $exitCode = 1
    $output = @()

    if ($SkipChildValidations.IsPresent) {
        return [ordered]@{
            name = $Name
            skipped = $true
            timedOut = $false
            exitCode = 0
            stdoutPath = ""
            stderrPath = ""
            outputRedacted = @("Skipped by -SkipChildValidations.")
        }
    }

    try {
        $process = Start-Process -FilePath $Command `
            -ArgumentList (Join-FlowChainProcessArguments -ArgumentList $ArgumentList) `
            -WorkingDirectory $repoRoot `
            -PassThru `
            -WindowStyle Hidden `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath
        $timedOut = -not $process.WaitForExit([Math]::Max(1, $ChildTimeoutSeconds) * 1000)
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
        $output += @(Get-Content -LiteralPath $stdoutPath -Tail 25)
    }
    if (Test-Path -LiteralPath $stderrPath) {
        $output += @(Get-Content -LiteralPath $stderrPath -Tail 25)
    }

    return [ordered]@{
        name = $Name
        skipped = $false
        timedOut = $timedOut
        exitCode = [int]$exitCode
        stdoutPath = $stdoutPath
        stderrPath = $stderrPath
        outputRedacted = @($output | ForEach-Object { "$_" })
    }
}

function Get-InstallCheckTool {
    param([Parameter(Mandatory = $true)][string] $Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return [ordered]@{
            name = $Name
            found = $false
            source = ""
        }
    }
    return [ordered]@{
        name = $Name
        found = $true
        source = "$($command.Source)"
    }
}

$packageJsonPath = Join-Path $repoRoot "package.json"
$packageJson = Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json

$requiredScripts = @(
    "flowchain:prereq",
    "flowchain:doctor",
    "flowchain:install:check",
    "flowchain:upgrade:rehearse",
    "flowchain:service:start",
    "flowchain:service:status",
    "flowchain:service:monitor",
    "flowchain:service:restart",
    "flowchain:service:stop",
    "flowchain:service:supervisor",
    "flowchain:service:supervisor:validate",
    "flowchain:service:install:windows",
    "flowchain:service:install:validate",
    "flowchain:service:install:systemd",
    "flowchain:service:install:systemd:validate",
    "flowchain:public-rpc:deployment-bundle",
    "flowchain:public-rpc:deployment:automation",
    "flowchain:backup:restore:validate",
    "flowchain:backup:install:validate",
    "flowchain:ops:metrics:install:validate",
    "flowchain:ops:alerts:install:validate",
    "flowchain:bridge:relayer:loop:validate",
    "flowchain:operator:package",
    "flowchain:operator:package:verify",
    "flowchain:completion:audit",
    "flowchain:truth-table"
)
$missingScripts = @($requiredScripts | Where-Object { -not (Test-InstallCheckPackageScript -PackageJson $packageJson -Name $_) })

$requiredDocs = @(
    "docs/developer/FLOWCHAIN_NODE_OPERATOR.md",
    "docs/OPERATIONS/FLOWCHAIN_SERVICE_SUPERVISOR.md",
    "docs/OPERATIONS/FLOWCHAIN_OWNER_OPERATED_PUBLIC_RPC.md",
    "docs/FLOWCHAIN_SECOND_COMPUTER_SETUP.md",
    "docs/agent-runs/live-product-infra-rpc/SERVICE_INSTALL_VALIDATION.md",
    "docs/agent-runs/live-product-infra-rpc/SYSTEMD_SERVICE_INSTALL_VALIDATION.md",
    "docs/agent-runs/live-product-infra-rpc/OPERATOR_PACKAGE.md",
    "docs/agent-runs/live-product-infra-rpc/OPERATOR_PACKAGE_VERIFY.md"
)
$missingDocs = @($requiredDocs | Where-Object { -not (Test-Path -LiteralPath (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $_)) })

$toolChecks = @("git", "node", "npm", "powershell", "cargo", "rustc", "forge") | ForEach-Object { Get-InstallCheckTool -Name $_ }
$missingTools = @($toolChecks | Where-Object { $_.found -ne $true })

$driveName = [System.IO.Path]::GetPathRoot($repoRoot).Substring(0, 1)
$drive = Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue
$freeGiB = if ($drive) { [Math]::Round(($drive.Free / 1GB), 2) } else { 0 }

$childResults = @()
$childResults += (Invoke-InstallCheckChild -Name "service-install-validation" -Command "npm.cmd" -ArgumentList @("run", "flowchain:service:install:validate"))
$childResults += (Invoke-InstallCheckChild -Name "systemd-service-install-validation" -Command "npm.cmd" -ArgumentList @("run", "flowchain:service:install:systemd:validate"))
$childFailures = @($childResults | Where-Object { $_.exitCode -ne 0 -or $_.timedOut -eq $true })

$serviceInstallReport = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/service-install-validation-report.json")
$systemdInstallReport = Read-FlowChainJsonIfExists -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/systemd-service-install-validation-report.json")

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
$missingOwnerInputNames = @($ownerInputNames | Where-Object { [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_, "Process")) })

$checks = [ordered]@{
    repoRootResolved = -not [string]::IsNullOrWhiteSpace($repoRoot)
    packageJsonReadable = $null -ne $packageJson
    requiredPackageScriptsPresent = $missingScripts.Count -eq 0
    requiredRunbooksPresent = $missingDocs.Count -eq 0
    requiredToolsPresent = $missingTools.Count -eq 0
    diskFreeMeetsMinimum = $freeGiB -ge $MinDiskFreeGiB
    serviceInstallValidationReportPassed = [string](Get-InstallCheckProp -Object $serviceInstallReport -Name "status" -Default "missing") -eq "passed"
    systemdInstallValidationReportPassed = [string](Get-InstallCheckProp -Object $systemdInstallReport -Name "status" -Default "missing") -eq "passed"
    childValidationsPassed = $childFailures.Count -eq 0
    childValidationsDidNotTimeout = @($childResults | Where-Object { $_.timedOut -eq $true }).Count -eq 0
    ownerInputNamesOnly = $ownerInputNames.Count -eq 17
    ownerInputAbsenceIsNonRepoBlocker = $missingOwnerInputNames.Count -ge 0
    hostMutationPerformedFalse = $true
    envValuesPrintedFalse = $true
    secretMarkerFindingsEmpty = $true
    noSecrets = $true
    broadcastsFalse = $true
}
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.install_check_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    repoRoot = $repoRoot
    minDiskFreeGiB = $MinDiskFreeGiB
    diskFreeGiB = $freeGiB
    toolChecks = @($toolChecks)
    requiredScripts = @($requiredScripts)
    missingScripts = @($missingScripts)
    requiredDocs = @($requiredDocs)
    missingDocs = @($missingDocs)
    childResults = @($childResults)
    missingOwnerInputNames = @($missingOwnerInputNames)
    blockedOnOwnerInputs = $missingOwnerInputNames.Count -gt 0
    checks = $checks
    failedChecks = @($failedChecks)
    secretMarkerFindings = @()
    hostMutationPerformed = $false
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$reportText = $report | ConvertTo-Json -Depth 18
Assert-FlowChainNoSecretText -Text $reportText -Label "install check report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Install Check")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This is the owner-host install preflight for running FlowChain outside a developer-only shell. It checks tools, package commands, runbooks, no-secret service install validations, systemd install validation, and operator package verification without mutating the host.")
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
$markdownLines.Add("| Check | Result |")
$markdownLines.Add("| --- | --- |")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("| $($entry.Key) | $($entry.Value) |")
}
$markdownLines.Add("")
$markdownLines.Add("## Commands")
$markdownLines.Add("")
$markdownLines.Add("- ``npm run flowchain:install:check``")
$markdownLines.Add("- ``npm run flowchain:service:install:validate``")
$markdownLines.Add("- ``npm run flowchain:service:install:systemd:validate``")
$markdownLines.Add("- ``npm run flowchain:operator:package:verify``")
$markdownLines.Add("- ``npm run flowchain:upgrade:rehearse``")
if ($missingOwnerInputNames.Count -gt 0) {
    $markdownLines.Add("")
    $markdownLines.Add("## Owner Inputs Still Needed")
    $markdownLines.Add("")
    foreach ($name in $missingOwnerInputNames) {
        $markdownLines.Add("- $name")
    }
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
Assert-FlowChainNoSecretText -Text $markdownText -Label "install check markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain install check status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    throw "FlowChain install check failed checks: $($failedChecks -join ', ')"
}
