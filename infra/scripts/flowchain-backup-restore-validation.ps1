param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$validationRoot = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/backup-restore-validation")

Reset-FlowChainDirectory -Path $validationRoot | Out-Null
$backupRoot = Join-Path $validationRoot "backup-root"
$restoreRoot = Join-Path $validationRoot "restore-root"
$corruptRoot = Join-Path $validationRoot "corrupt-root"
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
New-Item -ItemType Directory -Force -Path $restoreRoot | Out-Null
New-Item -ItemType Directory -Force -Path $corruptRoot | Out-Null

$backupReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-backup-report.json"
$restoreReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-restore-report.json"
$corruptRestoreReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-corrupt-restore-report.json"

function Invoke-ValidationChild {
    param([Parameter(Mandatory = $true)][string[]] $ArgumentList)

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = (& powershell @ArgumentList 2>&1) | ForEach-Object { "$_" }
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) {
            $exitCode = 0
        }
    }
    catch {
        $output = @($_.Exception.Message)
        $exitCode = 1
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    return [ordered]@{
        exitCode = [int] $exitCode
        output = @($output)
    }
}

$backupResult = Invoke-ValidationChild -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (Join-Path $PSScriptRoot "flowchain-state-backup.ps1"),
    "-StatePath",
    $stateFullPath,
    "-BackupRoot",
    $backupRoot,
    "-ReportPath",
    $backupReportPath,
    "-CreateBackupRoot"
)

$restoreResult = Invoke-ValidationChild -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (Join-Path $PSScriptRoot "flowchain-state-restore-verify.ps1"),
    "-BackupRoot",
    $backupRoot,
    "-RestoreRoot",
    $restoreRoot,
    "-ReportPath",
    $restoreReportPath
)

$backupReport = Read-FlowChainJsonIfExists -Path $backupReportPath
$restoreReport = Read-FlowChainJsonIfExists -Path $restoreReportPath

$corruptionDetected = $false
$corruptExitCode = 1
if ($backupResult.exitCode -eq 0 -and $null -ne $backupReport) {
    $snapshotName = Get-FlowChainJsonString -Object $backupReport.snapshot -Names @("snapshotName")
    if (-not [string]::IsNullOrWhiteSpace($snapshotName)) {
        Copy-Item -LiteralPath (Join-Path $backupRoot $snapshotName) -Destination (Join-Path $corruptRoot $snapshotName) -Recurse -Force
        Copy-Item -LiteralPath (Join-Path $backupRoot "latest-manifest.json") -Destination (Join-Path $corruptRoot "latest-manifest.json") -Force
        $corruptStatePath = Join-Path (Join-Path $corruptRoot $snapshotName) "state.json"
        Add-Content -LiteralPath $corruptStatePath -Value "`n "
        $corruptResult = Invoke-ValidationChild -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            (Join-Path $PSScriptRoot "flowchain-state-restore-verify.ps1"),
            "-BackupRoot",
            $corruptRoot,
            "-RestoreRoot",
            (Join-Path $validationRoot "corrupt-restore-root"),
            "-ReportPath",
            $corruptRestoreReportPath,
            "-AllowBlocked"
        )
        $corruptExitCode = $corruptResult.exitCode
        $corruptReport = Read-FlowChainJsonIfExists -Path $corruptRestoreReportPath
        $corruptionDetected = $null -ne $corruptReport -and "$($corruptReport.status)" -eq "failed"
    }
}

$backupPassed = $backupResult.exitCode -eq 0 -and $null -ne $backupReport -and "$($backupReport.status)" -eq "passed"
$restorePassed = $restoreResult.exitCode -eq 0 -and $null -ne $restoreReport -and "$($restoreReport.status)" -eq "passed"
$hashRoundTrip = $false
if ($backupPassed -and $restorePassed) {
    $hashRoundTrip = "$($backupReport.snapshot.stateFileSha256)" -eq "$($restoreReport.restore.restoredStateFileSha256)"
}

$status = if ($backupPassed -and $restorePassed -and $hashRoundTrip -and $corruptionDetected) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.backup_restore_validation_report.v1"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    stateReadable = (Get-FlowChainStateFacts -StatePath $stateFullPath).readable
    checks = [ordered]@{
        backupCommandPassed = $backupPassed
        restoreCommandPassed = $restorePassed
        backupRestoreHashRoundTrip = $hashRoundTrip
        corruptedSnapshotDetected = $corruptionDetected
        corruptRestoreExitCode = $corruptExitCode
    }
    reports = [ordered]@{
        backup = $backupReportPath
        restore = $restoreReportPath
        corruptRestore = $corruptRestoreReportPath
    }
    requiredCommands = @(
        "npm run flowchain:backup:create",
        "npm run flowchain:backup:restore:verify"
    )
    broadcasts = $false
    envValuesPrinted = $false
    noSecrets = $true
}

$reportText = $report | ConvertTo-Json -Depth 16
Assert-FlowChainNoSecretText -Text $reportText -Label "backup restore validation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

Write-Host "FlowChain backup/restore validation status: $status"
Write-Host "Report: $reportFullPath"
if ($status -ne "passed") {
    throw "FlowChain backup/restore validation failed. See report for artifact names."
}
