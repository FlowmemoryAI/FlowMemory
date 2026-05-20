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

function Get-OperatorVerifyFileHash {
    param([Parameter(Mandatory = $true)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-OperatorVerifyHashProblems {
    param(
        [AllowNull()][object[]] $Entries,
        [Parameter(Mandatory = $true)][string] $Kind,
        [Parameter(Mandatory = $true)][string] $PackageRoot
    )

    $problems = New-Object System.Collections.ArrayList
    foreach ($entry in @($Entries)) {
        $required = (Get-OperatorVerifyProp -Object $entry -Name "required" -Default $false) -eq $true
        if (-not $required) {
            continue
        }
        $destination = [string](Get-OperatorVerifyProp -Object $entry -Name "destination" -Default "")
        $manifestDestinationHash = [string](Get-OperatorVerifyProp -Object $entry -Name "destinationSha256" -Default "")
        $manifestSourceHash = [string](Get-OperatorVerifyProp -Object $entry -Name "sourceSha256" -Default "")
        $manifestMatched = (Get-OperatorVerifyProp -Object $entry -Name "contentHashMatches" -Default $false) -eq $true
        $destinationPath = Join-Path $PackageRoot $destination
        $actualDestinationHash = Get-OperatorVerifyFileHash -Path $destinationPath
        $reason = ""
        if ([string]::IsNullOrWhiteSpace($destination)) {
            $reason = "missing-destination"
        }
        elseif ([string]::IsNullOrWhiteSpace($manifestDestinationHash) -or [string]::IsNullOrWhiteSpace($manifestSourceHash)) {
            $reason = "missing-manifest-hash"
        }
        elseif (-not $manifestMatched -or $manifestDestinationHash -ne $manifestSourceHash) {
            $reason = "source-destination-hash-mismatch-at-copy"
        }
        elseif ([string]::IsNullOrWhiteSpace($actualDestinationHash) -or $actualDestinationHash -ne $manifestDestinationHash) {
            $reason = "destination-hash-mismatch"
        }

        if (-not [string]::IsNullOrWhiteSpace($reason)) {
            [void] $problems.Add([ordered]@{
                kind = $Kind
                destination = $destination
                reason = $reason
            })
        }
    }

    return @($problems)
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
    "docs/FLOWCHAIN_SECOND_COMPUTER_SETUP.md",
    "docs/FLOWCHAIN_OWNER_OPERATED_PUBLIC_RPC.md",
    "docs/FLOWCHAIN_SERVICE_SUPERVISOR.md",
    "runbooks/OWNER_ONBOARDING.md",
    "runbooks/OWNER_SIGNUP_CHECKLIST.md",
    "runbooks/OWNER_ACTIVATION_PLAN.md",
    "runbooks/OWNER_GO_LIVE_HANDOFF.md",
    "runbooks/OWNER_ENV_TEMPLATE.md",
    "runbooks/OWNER_ENV_READINESS.md",
    "runbooks/PUBLIC_RPC_DEPLOYMENT_BUNDLE.md",
    "runbooks/PUBLIC_RPC_SYNTHETIC_CANARY.md",
    "runbooks/INSTALL_CHECK.md",
    "runbooks/INSTALL_UPGRADE.md",
    "runbooks/WINDOWS_SERVICE_INSTALL.md",
    "runbooks/SYSTEMD_SERVICE_INSTALL_VALIDATION.md",
    "runbooks/WINDOWS_BACKUP_INSTALL.md",
    "runbooks/SYSTEMD_BACKUP_INSTALL.md",
    "runbooks/SYSTEMD_BACKUP_INSTALL_VALIDATION.md",
    "runbooks/WINDOWS_ALERT_INSTALL.md",
    "runbooks/SYSTEMD_ALERT_INSTALL.md",
    "runbooks/SYSTEMD_ALERT_INSTALL_VALIDATION.md",
    "runbooks/OPS_METRICS_EXPORT.md",
    "runbooks/WINDOWS_METRICS_INSTALL.md",
    "runbooks/SYSTEMD_METRICS_INSTALL.md",
    "runbooks/SYSTEMD_METRICS_INSTALL_VALIDATION.md",
    "runbooks/METRICS_INSTALL_VALIDATION.md",
    "runbooks/BRIDGE_DEPLOY_CONTROL_VALIDATION.md",
    "runbooks/BRIDGE_RELAYER_LOOP_VALIDATION.md",
    "runbooks/BRIDGE_RECONCILIATION.md",
    "runbooks/BRIDGE_RELEASE_EVIDENCE_VALIDATION.md",
    "runbooks/SECOND_COMPUTER_READINESS.md",
    "runbooks/EXTERNAL_TESTER_PACKET.md",
    "runbooks/EXTERNAL_TESTER_PACKET_VALIDATION.md",
    "runbooks/DASHBOARD_UI_READINESS.md",
    "runbooks/DEV_PACK.md",
    "runbooks/DEV_PACK_HANDOFF.md",
    "runbooks/DEV_PACK_INVENTORY.md",
    "evidence/operator-doctor-report.json",
    "evidence/service-status-report.json",
    "evidence/service-monitor-report.json",
    "evidence/install-check-report.json",
    "evidence/upgrade-rehearsal-report.json",
    "evidence/service-install-validation-report.json",
    "evidence/systemd-service-install-validation-report.json",
    "evidence/second-computer-readiness-report.json",
    "evidence/owner-onboarding-report.json",
    "evidence/owner-signup-checklist-report.json",
    "evidence/owner-activation-plan-report.json",
    "evidence/owner-go-live-handoff-report.json",
    "evidence/owner-env-template-report.json",
    "evidence/owner-env-readiness-validation-report.json",
    "evidence/owner-env-readiness-report.json",
    "evidence/public-rpc-deployment-bundle-report.json",
    "evidence/public-rpc-deployment-automation-report.json",
    "evidence/public-rpc-synthetic-canary-report.json",
    "evidence/backup-restore-validation-report.json",
    "evidence/backup-owner-path-dry-run-report.json",
    "evidence/backup-install-validation-report.json",
    "evidence/backup-install-systemd-validation-report.json",
    "evidence/ops-snapshot-report.json",
    "evidence/ops-metrics-export-report.json",
    "evidence/metrics-install-validation-report.json",
    "evidence/metrics-install-systemd-validation-report.json",
    "evidence/ops-metrics.json",
    "evidence/ops-metrics.prom.txt",
    "evidence/incident-drill-report.json",
    "evidence/bridge-relayer-once-report.json",
    "evidence/bridge-deploy-control-validation-report.json",
    "evidence/bridge-relayer-guardrail-validation-report.json",
    "evidence/bridge-relayer-loop-validation-report.json",
    "evidence/bridge-runtime-credit-validation-report.json",
    "evidence/real-value-pilot-aggregate-report.json",
    "evidence/bridge-reconciliation-report.json",
    "evidence/bridge-release-evidence-validation-report.json",
    "evidence/external-tester-packet-report.json",
    "evidence/external-tester-packet-validation-report.json",
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
$manifestRunbooks = @((Get-OperatorVerifyProp -Object $manifest -Name "runbooks" -Default @()))
$manifestEvidence = @((Get-OperatorVerifyProp -Object $manifest -Name "evidence" -Default @()))
$runbookHashProblems = @(Get-OperatorVerifyHashProblems -Entries $manifestRunbooks -Kind "runbook" -PackageRoot $packageFullPath)
$evidenceHashProblems = @(Get-OperatorVerifyHashProblems -Entries $manifestEvidence -Kind "evidence" -PackageRoot $packageFullPath)
$hashProblems = @($runbookHashProblems + $evidenceHashProblems)
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
$scanSecretFindings = @((Get-OperatorVerifyProp -Object $scanReport -Name "secretMarkerFindings" -Default @()))

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
    manifestRunbookHashesPresent = $manifestRunbooks.Count -ge 10 -and $runbookHashProblems.Count -eq 0
    manifestEvidenceHashesPresent = $manifestEvidence.Count -ge 15 -and $evidenceHashProblems.Count -eq 0
    manifestDestinationHashesMatch = $hashProblems.Count -eq 0
    reportRunbookCountEnough = [int](Get-OperatorVerifyProp -Object $packageReport -Name "runbookCount" -Default 0) -ge 10
    reportEvidenceCountEnough = [int](Get-OperatorVerifyProp -Object $packageReport -Name "evidenceReportCount" -Default 0) -ge 15
    operatorDoctorEvidencePresent = $null -ne $operatorDoctor
    operatorDoctorNoFailedChecks = $operatorDoctorFailedChecks.Count -eq 0
    operatorDoctorPassedOrOwnerBlocked = ($operatorDoctorStatus -eq "passed") -or ($operatorDoctorStatus -eq "blocked" -and $operatorDoctorBlockedOnlyOwnerInputs)
    ownerInputNamesOnly = $manifestOwnerInputs.Count -eq 17 -and $reportOwnerInputs.Count -eq 17 -and $badOwnerInputNames.Count -eq 0
    noForbiddenLocalFiles = $forbiddenFiles.Count -eq 0
    noSecretScanPassed = $scanExitCode -eq 0 -and $scanStatus -eq "passed" -and $secretFindings.Count -eq 0 -and $scanSecretFindings.Count -eq 0
    secretMarkerFindingsEmpty = $scanSecretFindings.Count -eq 0
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
    hashProblems = @($hashProblems)
    hashProblemCount = $hashProblems.Count
    commandCount = $manifestCommands.Count
    operatorDoctorStatus = $operatorDoctorStatus
    operatorDoctorFailedCheckCount = $operatorDoctorFailedChecks.Count
    ownerInputNameCount = $manifestOwnerInputs.Count
    badOwnerInputNames = @($badOwnerInputNames)
    noSecretScanReportPath = $scanReportPath
    checks = $checks
    failedChecks = @($failedChecks)
    secretMarkerFindings = @($scanSecretFindings)
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
$markdownLines.Add("- Hash problems: $($hashProblems.Count)")
$markdownLines.Add("- Command count: $($manifestCommands.Count)")
$markdownLines.Add("- Owner-input names: $($manifestOwnerInputs.Count)")
Set-Content -LiteralPath $markdownFullPath -Value $markdownLines -Encoding UTF8

Write-Host "FlowChain operator package verify status: $status"
Write-Host "Report: $reportFullPath"
if ($status -ne "passed") {
    throw "FlowChain operator package verify failed checks: $($failedChecks -join ', ')"
}
