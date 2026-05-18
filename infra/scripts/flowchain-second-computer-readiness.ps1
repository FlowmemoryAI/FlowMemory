param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/second-computer-readiness-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/SECOND_COMPUTER_READINESS.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$packageJsonPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "package.json"
$setupDocPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/FLOWCHAIN_SECOND_COMPUTER_SETUP.md"
$bundleReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/second-computer/flowchain-second-computer-bundle-report.json"
$verifyReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/second-computer/flowchain-second-computer-verify-report.json"
$stageManifestPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/second-computer/stage/FlowMemory/SECOND_COMPUTER_BUNDLE_MANIFEST.json"
$stageScanPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/second-computer/stage/FlowMemory/SECOND_COMPUTER_BUNDLE_NO_SECRET_SCAN.json"

function Get-SecondComputerProp {
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

function Test-SecondComputerPackageScript {
    param(
        [Parameter(Mandatory = $true)][object] $PackageJson,
        [Parameter(Mandatory = $true)][string] $Name
    )

    if ($null -eq $PackageJson.scripts) {
        return $false
    }
    return $PackageJson.scripts.PSObject.Properties.Name -contains $Name
}

function Invoke-SecondComputerCommand {
    param(
        [Parameter(Mandatory = $true)][string] $Label,
        [Parameter(Mandatory = $true)][string[]] $ArgumentList
    )

    $startedAt = [DateTimeOffset]::UtcNow
    $output = @(& powershell @ArgumentList 2>&1)
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
    $finishedAt = [DateTimeOffset]::UtcNow

    Write-Host "$Label exit code: $exitCode"
    return [ordered]@{
        label = $Label
        command = "powershell $($ArgumentList -join ' ')"
        exitCode = $exitCode
        durationSeconds = [int][Math]::Max(0, [Math]::Ceiling(($finishedAt - $startedAt).TotalSeconds))
        outputLineCount = $output.Count
    }
}

$packageJson = Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json
$setupDoc = if (Test-Path -LiteralPath $setupDocPath) { Get-Content -Raw -LiteralPath $setupDocPath } else { "" }

$bundleCommandResult = Invoke-SecondComputerCommand -Label "second-computer source bundle" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-second-computer-bundle.ps1"), "-Force")
$verifyCommandResult = Invoke-SecondComputerCommand -Label "second-computer local verify" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "flowchain-second-computer-verify.ps1"), "-ReportPath", "devnet/local/second-computer/flowchain-second-computer-verify-report.json")
$commands = @($bundleCommandResult, $verifyCommandResult)

$bundleReport = Read-FlowChainJsonIfExists -Path $bundleReportPath
$verifyReport = Read-FlowChainJsonIfExists -Path $verifyReportPath
$manifest = Read-FlowChainJsonIfExists -Path $stageManifestPath
$stageScan = Read-FlowChainJsonIfExists -Path $stageScanPath
$verifyChecks = @((Get-SecondComputerProp -Object $verifyReport -Name "checks" -Default @()))
$failedVerifyChecks = @($verifyChecks | Where-Object { [string](Get-SecondComputerProp -Object $_ -Name "status" -Default "failed") -ne "passed" })
$manifestNextCommands = @((Get-SecondComputerProp -Object $manifest -Name "nextCommands" -Default @()))
$manifestExcludes = @((Get-SecondComputerProp -Object $manifest -Name "excludes" -Default @()))
$stageSecretMarkerFindings = @((Get-SecondComputerProp -Object $stageScan -Name "secretMarkerFindings" -Default @()) | Where-Object { $null -ne $_ })
$stageFindings = @((Get-SecondComputerProp -Object $stageScan -Name "findings" -Default @()) | Where-Object { $null -ne $_ })
$secretMarkerFindings = @($stageSecretMarkerFindings + $stageFindings | Where-Object { $null -ne $_ })
$bundlePath = [string](Get-SecondComputerProp -Object $bundleReport -Name "bundlePath" -Default "")
$bundlePathExists = -not [string]::IsNullOrWhiteSpace($bundlePath) -and (Test-Path -LiteralPath $bundlePath)

$requiredNextCommands = @(
    "npm install",
    "npm install --prefix apps/dashboard",
    "npm install --prefix crypto",
    "npm run flowchain:second-computer:verify",
    "npm run flowchain:production-l1:e2e"
)
$missingNextCommands = @($requiredNextCommands | Where-Object { $_ -notin $manifestNextCommands })

$checks = [ordered]@{
    bundlePackageScriptPresent = Test-SecondComputerPackageScript -PackageJson $packageJson -Name "flowchain:second-computer:bundle"
    verifyPackageScriptPresent = Test-SecondComputerPackageScript -PackageJson $packageJson -Name "flowchain:second-computer:verify"
    readinessPackageScriptPresent = Test-SecondComputerPackageScript -PackageJson $packageJson -Name "flowchain:second-computer:readiness"
    setupDocExists = Test-Path -LiteralPath $setupDocPath
    setupDocMentionsBundle = $setupDoc.Contains("flowchain:second-computer:bundle")
    setupDocMentionsVerify = $setupDoc.Contains("flowchain:second-computer:verify")
    bundleCommandPassed = [int](Get-SecondComputerProp -Object $bundleCommandResult -Name "exitCode" -Default 1) -eq 0
    verifyCommandPassed = [int](Get-SecondComputerProp -Object $verifyCommandResult -Name "exitCode" -Default 1) -eq 0
    bundleReportPassed = [string](Get-SecondComputerProp -Object $bundleReport -Name "status" -Default "missing") -eq "passed"
    verifyReportPassed = [string](Get-SecondComputerProp -Object $verifyReport -Name "status" -Default "missing") -eq "passed"
    stageNoSecretScanPassed = [string](Get-SecondComputerProp -Object $stageScan -Name "status" -Default "missing") -eq "passed"
    bundleZipCreated = $bundlePathExists
    bundleSha256Present = -not [string]::IsNullOrWhiteSpace([string](Get-SecondComputerProp -Object $bundleReport -Name "bundleSha256" -Default ""))
    manifestWritten = $null -ne $manifest
    manifestNextCommandsPresent = $missingNextCommands.Count -eq 0
    excludesGitMetadata = ".git" -in $manifestExcludes
    excludesNodeModules = "node_modules" -in $manifestExcludes
    excludesLocalRuntime = "devnet/local" -in $manifestExcludes
    excludesEnvFiles = "env files" -in $manifestExcludes
    excludesSecretMarkerFiles = "nonessential files with secret-marker field names" -in $manifestExcludes
    verifyChecksPassed = $failedVerifyChecks.Count -eq 0
    secretMarkerFindingsEmpty = $secretMarkerFindings.Count -eq 0
    envValuesPrintedFalse = $true
    noSecrets = ([string](Get-SecondComputerProp -Object $stageScan -Name "status" -Default "missing") -eq "passed") -and ($secretMarkerFindings.Count -eq 0) -and ((Get-SecondComputerProp -Object $stageScan -Name "noSecrets" -Default $false) -eq $true)
    broadcastsFalse = $true
}

$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.second_computer_readiness_report.v0"
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    status = $status
    checks = $checks
    failedChecks = @($failedChecks)
    missingNextCommands = @($missingNextCommands)
    failedVerifyChecks = @($failedVerifyChecks)
    secretMarkerFindings = @($secretMarkerFindings)
    commandResults = @($commands)
    bundleReportPath = $bundleReportPath
    verifyReportPath = $verifyReportPath
    stageNoSecretScanPath = $stageScanPath
    bundleExists = $bundlePathExists
    bundleSha256Present = $checks.bundleSha256Present
    envValuesPrinted = $false
    noSecrets = $checks.noSecrets
    broadcasts = $false
}

$reportText = $report | ConvertTo-Json -Depth 12
Assert-FlowChainNoSecretText -Text $reportText -Label "second-computer readiness report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 12

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Second-Computer Readiness")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("## Evidence")
$markdownLines.Add("")
$markdownLines.Add("- Bundle command: $($checks.bundleCommandPassed)")
$markdownLines.Add("- Verify command: $($checks.verifyCommandPassed)")
$markdownLines.Add("- Bundle no-secret scan: $($checks.stageNoSecretScanPassed)")
$markdownLines.Add("- Bundle created: $($checks.bundleZipCreated)")
$markdownLines.Add("- Required next commands present: $($checks.manifestNextCommandsPresent)")
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
$markdownLines.Add("| Check | Result |")
$markdownLines.Add("| --- | --- |")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("| $($entry.Key) | $($entry.Value) |")
}
if ($failedChecks.Count -gt 0) {
    $markdownLines.Add("")
    $markdownLines.Add("## Failed Checks")
    $markdownLines.Add("")
    foreach ($check in $failedChecks) {
        $markdownLines.Add("- $check")
    }
}

$markdownText = ($markdownLines -join [Environment]::NewLine) + [Environment]::NewLine
Assert-FlowChainNoSecretText -Text $markdownText -Label "second-computer readiness markdown"
$markdownParent = Split-Path -Parent $markdownFullPath
if (-not [string]::IsNullOrWhiteSpace($markdownParent)) {
    New-Item -ItemType Directory -Force -Path $markdownParent | Out-Null
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($markdownFullPath, $markdownText, $utf8NoBom)

Write-Host "FlowChain second-computer readiness status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    exit 1
}
