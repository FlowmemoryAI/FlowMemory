param(
    [string] $PackageReportPath = "docs/agent-runs/live-product-infra-rpc/operator-package-report.json",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/operator-package-verify-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/OPERATOR_PACKAGE_VERIFY.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$packageReportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $PackageReportPath)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)

function Get-OperatorVerifyProp {
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

$packageReport = Read-FlowChainJsonIfExists -Path $packageReportFullPath
$packageStatus = [string](Get-OperatorVerifyProp -Object $packageReport -Name "status" -Default "missing")
$packageDir = [string](Get-OperatorVerifyProp -Object $packageReport -Name "packageDir" -Default "")
if ([string]::IsNullOrWhiteSpace($packageDir)) {
    $packageDir = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/operator-package"
}
$packageFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $packageDir)

$expectedFiles = @(
    "README.md",
    "COMMAND_MATRIX.md",
    "OPERATOR_COMMAND_MATRIX.json",
    "OPERATOR_PACKAGE_MANIFEST.json",
    "docs/FLOWCHAIN_NODE_OPERATOR.md",
    "docs/FLOWCHAIN_QUICKSTART.md",
    "docs/FLOWCHAIN_OWNER_OPERATED_PUBLIC_RPC.md",
    "docs/FLOWCHAIN_SERVICE_SUPERVISOR.md",
    "runbooks/PUBLIC_RPC_DEPLOYMENT_BUNDLE.md",
    "runbooks/WINDOWS_SERVICE_INSTALL.md",
    "runbooks/WINDOWS_BACKUP_INSTALL.md",
    "runbooks/WINDOWS_ALERT_INSTALL.md",
    "runbooks/BRIDGE_RELAYER_LOOP_VALIDATION.md",
    "runbooks/EXTERNAL_TESTER_PACKET.md",
    "runbooks/DASHBOARD_UI_READINESS.md",
    "evidence/operator-doctor-report.json",
    "evidence/service-status-report.json",
    "evidence/service-monitor-report.json",
    "evidence/service-install-validation-report.json",
    "evidence/public-rpc-deployment-bundle-report.json",
    "evidence/public-rpc-deployment-automation-report.json",
    "evidence/backup-restore-validation-report.json",
    "evidence/ops-snapshot-report.json",
    "evidence/incident-drill-report.json",
    "evidence/bridge-relayer-once-report.json",
    "evidence/bridge-relayer-loop-validation-report.json",
    "evidence/external-tester-packet-report.json",
    "evidence/dashboard-ui-readiness-report.json",
    "evidence/flowchain-architecture-audit-report.json",
    "evidence/flowchain-completion-audit-report.json",
    "evidence/production-truth-table-report.json"
)

$missingFiles = @($expectedFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $packageFullPath $_)) })
$manifestPath = Join-Path $packageFullPath "OPERATOR_PACKAGE_MANIFEST.json"
$matrixPath = Join-Path $packageFullPath "OPERATOR_COMMAND_MATRIX.json"
$manifest = Read-FlowChainJsonIfExists -Path $manifestPath
$matrix = Read-FlowChainJsonIfExists -Path $matrixPath
$manifestOwnerInputs = @((Get-OperatorVerifyProp -Object $manifest -Name "ownerInputNames" -Default @()))
$reportOwnerInputs = @((Get-OperatorVerifyProp -Object $packageReport -Name "ownerInputNames" -Default @()))
$manifestCommands = @((Get-OperatorVerifyProp -Object $manifest -Name "commandMatrix" -Default @()))
$matrixCommands = @((Get-OperatorVerifyProp -Object $matrix -Name "commands" -Default @()))
$badOwnerInputNames = @($manifestOwnerInputs | Where-Object { "$_" -notmatch '^FLOWCHAIN_[A-Z0-9_]+$' -or "$_" -match '=' -or "$_" -match 'https?://' })
$operatorDoctor = Read-FlowChainJsonIfExists -Path (Join-Path $packageFullPath "evidence/operator-doctor-report.json")
$operatorDoctorStatus = [string](Get-OperatorVerifyProp -Object $operatorDoctor -Name "status" -Default "missing")
$operatorDoctorFailedChecks = @((Get-OperatorVerifyProp -Object $operatorDoctor -Name "failedChecks" -Default @()))
$operatorDoctorBlockedOnlyOwnerInputs = (Get-OperatorVerifyProp -Object $operatorDoctor -Name "blockedOnlyOnOwnerInputs" -Default $false) -eq $true

$scanReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/operator-package-verify-no-secret-scan-report.json"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-no-secret-scan.ps1") -Paths @($packageFullPath, $packageReportFullPath) -ReportPath $scanReportPath
$scanExitCode = $LASTEXITCODE
$scanReport = Read-FlowChainJsonIfExists -Path $scanReportPath
$scanStatus = [string](Get-OperatorVerifyProp -Object $scanReport -Name "status" -Default "missing")
$secretFindings = @((Get-OperatorVerifyProp -Object $scanReport -Name "findings" -Default @()))

$forbiddenFiles = @()
if (Test-Path -LiteralPath $packageFullPath) {
    $forbiddenFiles = @(Get-ChildItem -LiteralPath $packageFullPath -Recurse -File | Where-Object {
        $name = $_.Name.ToLowerInvariant()
        $name -eq ".env" -or
        ($name.StartsWith(".env.") -and $name -ne ".env.example") -or
        $name.EndsWith(".pem") -or
        $name.EndsWith(".key") -or
        $name.EndsWith(".pfx") -or
        $name.EndsWith(".p12") -or
        $name.EndsWith(".zip")
    } | ForEach-Object { $_.FullName })
}

$checks = [ordered]@{
    packageReportExists = $null -ne $packageReport
    packageReportPassed = $packageStatus -eq "passed"
    packageDirExists = Test-Path -LiteralPath $packageFullPath
    manifestExists = $null -ne $manifest
    manifestSchemaValid = [string](Get-OperatorVerifyProp -Object $manifest -Name "schema" -Default "") -eq "flowchain.operator_package_manifest.v0"
    commandMatrixExists = $null -ne $matrix
    commandMatrixCountMatches = $manifestCommands.Count -ge 20 -and $matrixCommands.Count -eq $manifestCommands.Count
    expectedFilesPresent = $missingFiles.Count -eq 0
    reportRunbookCountEnough = [int](Get-OperatorVerifyProp -Object $packageReport -Name "runbookCount" -Default 0) -ge 10
    reportEvidenceCountEnough = [int](Get-OperatorVerifyProp -Object $packageReport -Name "evidenceReportCount" -Default 0) -ge 15
    operatorDoctorEvidencePresent = $null -ne $operatorDoctor
    operatorDoctorNoFailedChecks = $operatorDoctorFailedChecks.Count -eq 0
    operatorDoctorPassedOrOwnerBlocked = ($operatorDoctorStatus -eq "passed") -or ($operatorDoctorStatus -eq "blocked" -and $operatorDoctorBlockedOnlyOwnerInputs)
    ownerInputNamesOnly = $manifestOwnerInputs.Count -eq 17 -and $reportOwnerInputs.Count -eq 17 -and $badOwnerInputNames.Count -eq 0
    noForbiddenLocalFiles = $forbiddenFiles.Count -eq 0
    noSecretScanPassed = $scanExitCode -eq 0 -and $scanStatus -eq "passed" -and $secretFindings.Count -eq 0
    envValuesPrintedFalse = (Get-OperatorVerifyProp -Object $packageReport -Name "envValuesPrinted" -Default $true) -eq $false
    broadcastsFalse = (Get-OperatorVerifyProp -Object $packageReport -Name "broadcasts" -Default $true) -eq $false
    noSecrets = (Get-OperatorVerifyProp -Object $packageReport -Name "noSecrets" -Default $false) -eq $true
}
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.operator_package_verify_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    packageReportPath = $packageReportFullPath
    packageDir = $packageFullPath
    packageStatus = $packageStatus
    expectedFileCount = $expectedFiles.Count
    missingFiles = @($missingFiles)
    forbiddenFiles = @($forbiddenFiles)
    commandCount = $manifestCommands.Count
    operatorDoctorStatus = $operatorDoctorStatus
    operatorDoctorFailedCheckCount = $operatorDoctorFailedChecks.Count
    ownerInputNameCount = $manifestOwnerInputs.Count
    badOwnerInputNames = @($badOwnerInputNames)
    noSecretScanReportPath = $scanReportPath
    checks = $checks
    failedChecks = @($failedChecks)
    noLiveBroadcast = $true
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Operator Package Verify")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
$markdownLines.Add("| Check | Result |")
$markdownLines.Add("| --- | --- |")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("| $($entry.Key) | $($entry.Value) |")
}
$markdownLines.Add("")
$markdownLines.Add("## Package")
$markdownLines.Add("")
$markdownLines.Add("- Package report: ``$packageReportFullPath``")
$markdownLines.Add("- Package directory: ``$packageFullPath``")
$markdownLines.Add("- Expected files: $($expectedFiles.Count)")
$markdownLines.Add("- Missing files: $($missingFiles.Count)")
$markdownLines.Add("- Forbidden local files: $($forbiddenFiles.Count)")
$markdownLines.Add("- Command count: $($manifestCommands.Count)")
$markdownLines.Add("- Owner-input names: $($manifestOwnerInputs.Count)")
Set-Content -LiteralPath $markdownFullPath -Value $markdownLines -Encoding UTF8

Write-Host "FlowChain operator package verify status: $status"
Write-Host "Report: $reportFullPath"
if ($status -ne "passed") {
    throw "FlowChain operator package verify failed checks: $($failedChecks -join ', ')"
}
