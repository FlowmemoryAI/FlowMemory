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
$latestRestoreRoot = Join-Path $validationRoot "latest-restore-root"
$corruptRoot = Join-Path $validationRoot "corrupt-root"
$tamperedRoot = Join-Path $validationRoot "tampered-manifest-root"
$missingArtifactRoot = Join-Path $validationRoot "missing-artifact-root"
$missingSnapshotManifestRoot = Join-Path $validationRoot "missing-snapshot-manifest-root"
$latestPointerTamperRoot = Join-Path $validationRoot "latest-pointer-tamper-root"
$wrongChainStateMismatchRoot = Join-Path $validationRoot "wrong-chain-state-mismatch-root"
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
New-Item -ItemType Directory -Force -Path $restoreRoot | Out-Null
New-Item -ItemType Directory -Force -Path $latestRestoreRoot | Out-Null
New-Item -ItemType Directory -Force -Path $corruptRoot | Out-Null
New-Item -ItemType Directory -Force -Path $tamperedRoot | Out-Null
New-Item -ItemType Directory -Force -Path $missingArtifactRoot | Out-Null
New-Item -ItemType Directory -Force -Path $missingSnapshotManifestRoot | Out-Null
New-Item -ItemType Directory -Force -Path $latestPointerTamperRoot | Out-Null
New-Item -ItemType Directory -Force -Path $wrongChainStateMismatchRoot | Out-Null

$backupReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-backup-report.json"
$secondBackupReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-second-backup-report.json"
$restoreReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-restore-report.json"
$latestRestoreReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-latest-restore-report.json"
$corruptRestoreReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-corrupt-restore-report.json"
$tamperedRestoreReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-tampered-manifest-report.json"
$missingArtifactRestoreReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-missing-artifact-report.json"
$missingSnapshotManifestRestoreReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-missing-snapshot-manifest-report.json"
$latestPointerTamperRestoreReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-latest-pointer-tamper-report.json"
$wrongChainStateMismatchRestoreReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-wrong-chain-state-mismatch-report.json"

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

function Set-ValidationProp {
    param(
        [Parameter(Mandatory = $true)][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name,
        [AllowNull()][object] $Value
    )

    if ($Object.PSObject.Properties.Name -contains $Name) {
        $Object.$Name = $Value
    }
    else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Copy-ValidationBackupRoot {
    param([Parameter(Mandatory = $true)][string] $Destination)

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    foreach ($item in Get-ChildItem -LiteralPath $backupRoot -Force) {
        Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $Destination $item.Name) -Recurse -Force
    }
}

function Invoke-ValidationRestore {
    param(
        [Parameter(Mandatory = $true)][string] $BackupRootPath,
        [Parameter(Mandatory = $true)][string] $RestoreRootPath,
        [Parameter(Mandatory = $true)][string] $ReportPath
    )

    return Invoke-ValidationChild -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Join-Path $PSScriptRoot "flowchain-state-restore-verify.ps1"),
        "-BackupRoot",
        $BackupRootPath,
        "-RestoreRoot",
        $RestoreRootPath,
        "-StatePath",
        $stateFullPath,
        "-ReportPath",
        $ReportPath,
        "-AllowBlocked"
    )
}

function Test-ValidationRestoreFailed {
    param([Parameter(Mandatory = $true)][string] $ReportPath)
    $report = Read-FlowChainJsonIfExists -Path $ReportPath
    return $null -ne $report -and "$($report.status)" -eq "failed"
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
    "-StatePath",
    $stateFullPath,
    "-ReportPath",
    $restoreReportPath
)

$backupReport = Read-FlowChainJsonIfExists -Path $backupReportPath
$restoreReport = Read-FlowChainJsonIfExists -Path $restoreReportPath

$secondBackupResult = [ordered]@{ exitCode = 1; output = @("not-run") }
$latestRestoreResult = [ordered]@{ exitCode = 1; output = @("not-run") }
$secondBackupReport = $null
$latestRestoreReport = $null
$latestManifestMatchesSecondSnapshot = $false
$latestRestoreUsedLatestSnapshot = $false
$firstSnapshotName = ""
$secondSnapshotName = ""
if ($backupResult.exitCode -eq 0 -and $null -ne $backupReport -and "$($backupReport.status)" -eq "passed") {
    $firstSnapshotName = Get-FlowChainJsonString -Object $backupReport.snapshot -Names @("snapshotName")
    Start-Sleep -Milliseconds 20
    $secondBackupResult = Invoke-ValidationChild -ArgumentList @(
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
        $secondBackupReportPath,
        "-CreateBackupRoot"
    )
    $secondBackupReport = Read-FlowChainJsonIfExists -Path $secondBackupReportPath
    if ($secondBackupResult.exitCode -eq 0 -and $null -ne $secondBackupReport -and "$($secondBackupReport.status)" -eq "passed") {
        $secondSnapshotName = Get-FlowChainJsonString -Object $secondBackupReport.snapshot -Names @("snapshotName")
        $latestManifest = Read-FlowChainJsonIfExists -Path (Join-Path $backupRoot "latest-manifest.json")
        $latestManifestSnapshotName = Get-FlowChainJsonString -Object $latestManifest -Names @("snapshotName")
        $latestManifestMatchesSecondSnapshot = -not [string]::IsNullOrWhiteSpace($secondSnapshotName) -and $secondSnapshotName -eq $latestManifestSnapshotName

        $latestRestoreResult = Invoke-ValidationRestore -BackupRootPath $backupRoot -RestoreRootPath $latestRestoreRoot -ReportPath $latestRestoreReportPath
        $latestRestoreReport = Read-FlowChainJsonIfExists -Path $latestRestoreReportPath
        $latestRestoreUsedLatestSnapshot = $latestRestoreResult.exitCode -eq 0 `
            -and $null -ne $latestRestoreReport `
            -and "$($latestRestoreReport.status)" -eq "passed" `
            -and (Get-FlowChainJsonString -Object $latestRestoreReport.restore -Names @("snapshotName")) -eq $secondSnapshotName
    }
}

$selectedSnapshotName = if (-not [string]::IsNullOrWhiteSpace($secondSnapshotName)) { $secondSnapshotName } else { $firstSnapshotName }
$corruptionDetected = $false
$corruptExitCode = 1
$tamperedManifestDetected = $false
$missingStateArtifactDetected = $false
$missingSnapshotManifestDetected = $false
$latestPointerTamperDetected = $false
$wrongChainStateMismatchDetected = $false
if (-not [string]::IsNullOrWhiteSpace($selectedSnapshotName)) {
    Copy-ValidationBackupRoot -Destination $corruptRoot
    $corruptStatePath = Join-Path (Join-Path $corruptRoot $selectedSnapshotName) "state.json"
    if (Test-Path -LiteralPath $corruptStatePath) {
        Add-Content -LiteralPath $corruptStatePath -Value "`n "
    }
    $corruptResult = Invoke-ValidationRestore -BackupRootPath $corruptRoot -RestoreRootPath (Join-Path $validationRoot "corrupt-restore-root") -ReportPath $corruptRestoreReportPath
    $corruptExitCode = $corruptResult.exitCode
    $corruptionDetected = Test-ValidationRestoreFailed -ReportPath $corruptRestoreReportPath

    Copy-ValidationBackupRoot -Destination $tamperedRoot
    $tamperedStatePath = Join-Path (Join-Path $tamperedRoot $selectedSnapshotName) "state.json"
    if (Test-Path -LiteralPath $tamperedStatePath) {
        Add-Content -LiteralPath $tamperedStatePath -Value "`n "
    }
    $tamperedManifestPath = Join-Path $tamperedRoot "latest-manifest.json"
    $tamperedManifest = Read-FlowChainJsonIfExists -Path $tamperedManifestPath
    if ($null -ne $tamperedManifest -and (Test-Path -LiteralPath $tamperedStatePath)) {
        Set-ValidationProp -Object $tamperedManifest -Name "stateFileSha256" -Value ((Get-FileHash -Algorithm SHA256 -LiteralPath $tamperedStatePath).Hash).ToLowerInvariant()
        Write-FlowChainJson -Path $tamperedManifestPath -Value $tamperedManifest -Depth 12
    }
    [void](Invoke-ValidationRestore -BackupRootPath $tamperedRoot -RestoreRootPath (Join-Path $validationRoot "tampered-restore-root") -ReportPath $tamperedRestoreReportPath)
    $tamperedManifestDetected = Test-ValidationRestoreFailed -ReportPath $tamperedRestoreReportPath

    Copy-ValidationBackupRoot -Destination $missingArtifactRoot
    $missingStatePath = Join-Path (Join-Path $missingArtifactRoot $selectedSnapshotName) "state.json"
    if (Test-Path -LiteralPath $missingStatePath) {
        Remove-Item -LiteralPath $missingStatePath -Force
    }
    [void](Invoke-ValidationRestore -BackupRootPath $missingArtifactRoot -RestoreRootPath (Join-Path $validationRoot "missing-artifact-restore-root") -ReportPath $missingArtifactRestoreReportPath)
    $missingStateArtifactDetected = Test-ValidationRestoreFailed -ReportPath $missingArtifactRestoreReportPath

    Copy-ValidationBackupRoot -Destination $missingSnapshotManifestRoot
    $missingSnapshotManifestPath = Join-Path (Join-Path $missingSnapshotManifestRoot $selectedSnapshotName) "manifest.json"
    if (Test-Path -LiteralPath $missingSnapshotManifestPath) {
        Remove-Item -LiteralPath $missingSnapshotManifestPath -Force
    }
    [void](Invoke-ValidationRestore -BackupRootPath $missingSnapshotManifestRoot -RestoreRootPath (Join-Path $validationRoot "missing-snapshot-manifest-restore-root") -ReportPath $missingSnapshotManifestRestoreReportPath)
    $missingSnapshotManifestDetected = Test-ValidationRestoreFailed -ReportPath $missingSnapshotManifestRestoreReportPath

    if (-not [string]::IsNullOrWhiteSpace($firstSnapshotName) -and -not [string]::IsNullOrWhiteSpace($secondSnapshotName) -and $firstSnapshotName -ne $secondSnapshotName) {
        Copy-ValidationBackupRoot -Destination $latestPointerTamperRoot
        Copy-Item -LiteralPath (Join-Path (Join-Path $latestPointerTamperRoot $firstSnapshotName) "manifest.json") -Destination (Join-Path $latestPointerTamperRoot "latest-manifest.json") -Force
        [void](Invoke-ValidationRestore -BackupRootPath $latestPointerTamperRoot -RestoreRootPath (Join-Path $validationRoot "latest-pointer-tamper-restore-root") -ReportPath $latestPointerTamperRestoreReportPath)
        $latestPointerTamperDetected = Test-ValidationRestoreFailed -ReportPath $latestPointerTamperRestoreReportPath
    }

    Copy-ValidationBackupRoot -Destination $wrongChainStateMismatchRoot
    $wrongLatestPath = Join-Path $wrongChainStateMismatchRoot "latest-manifest.json"
    $wrongSnapshotManifestPath = Join-Path (Join-Path $wrongChainStateMismatchRoot $selectedSnapshotName) "manifest.json"
    $wrongManifest = Read-FlowChainJsonIfExists -Path $wrongLatestPath
    if ($null -ne $wrongManifest) {
        $wrongState = $wrongManifest.state
        Set-ValidationProp -Object $wrongState -Name "chainId" -Value "flowchain-wrong-chain-drill"
        Write-FlowChainJson -Path $wrongLatestPath -Value $wrongManifest -Depth 12
        Write-FlowChainJson -Path $wrongSnapshotManifestPath -Value $wrongManifest -Depth 12
    }
    [void](Invoke-ValidationRestore -BackupRootPath $wrongChainStateMismatchRoot -RestoreRootPath (Join-Path $validationRoot "wrong-chain-state-mismatch-restore-root") -ReportPath $wrongChainStateMismatchRestoreReportPath)
    $wrongChainStateMismatchDetected = Test-ValidationRestoreFailed -ReportPath $wrongChainStateMismatchRestoreReportPath
}

$backupPassed = $backupResult.exitCode -eq 0 -and $null -ne $backupReport -and "$($backupReport.status)" -eq "passed"
$restorePassed = $restoreResult.exitCode -eq 0 -and $null -ne $restoreReport -and "$($restoreReport.status)" -eq "passed"
$secondBackupPassed = $secondBackupResult.exitCode -eq 0 -and $null -ne $secondBackupReport -and "$($secondBackupReport.status)" -eq "passed"
$latestRestorePassed = $latestRestoreResult.exitCode -eq 0 -and $null -ne $latestRestoreReport -and "$($latestRestoreReport.status)" -eq "passed"
$restoreTargetProtected = $restorePassed -and $latestRestorePassed `
    -and $restoreReport.restore.liveStatePathProtected -eq $true `
    -and $latestRestoreReport.restore.liveStatePathProtected -eq $true
$liveStateNonMutationProven = $restorePassed -and $latestRestorePassed `
    -and $restoreReport.restore.liveStateMutated -eq $false `
    -and $latestRestoreReport.restore.liveStateMutated -eq $false
$hashRoundTrip = $false
if ($backupPassed -and $restorePassed) {
    $hashRoundTrip = "$($backupReport.snapshot.stateFileSha256)" -eq "$($restoreReport.restore.restoredStateFileSha256)"
}

$status = if ($backupPassed -and $restorePassed -and $hashRoundTrip -and $secondBackupPassed -and $latestManifestMatchesSecondSnapshot -and $latestRestorePassed -and $latestRestoreUsedLatestSnapshot -and $restoreTargetProtected -and $liveStateNonMutationProven -and $corruptionDetected -and $tamperedManifestDetected -and $missingStateArtifactDetected -and $missingSnapshotManifestDetected -and $latestPointerTamperDetected -and $wrongChainStateMismatchDetected) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.backup_restore_validation_report.v1"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    stateReadable = (Get-FlowChainStateFacts -StatePath $stateFullPath).readable
    checks = [ordered]@{
        backupCommandPassed = $backupPassed
        restoreCommandPassed = $restorePassed
        backupRestoreHashRoundTrip = $hashRoundTrip
        secondBackupCommandPassed = $secondBackupPassed
        latestManifestMatchesSecondSnapshot = $latestManifestMatchesSecondSnapshot
        latestRestoreCommandPassed = $latestRestorePassed
        latestRestoreUsedLatestSnapshot = $latestRestoreUsedLatestSnapshot
        restoreTargetsLiveStateProtected = $restoreTargetProtected
        liveStateNonMutationProven = $liveStateNonMutationProven
        corruptedSnapshotDetected = $corruptionDetected
        corruptRestoreExitCode = $corruptExitCode
        manifestTamperDetected = $tamperedManifestDetected
        missingStateArtifactDetected = $missingStateArtifactDetected
        missingSnapshotManifestDetected = $missingSnapshotManifestDetected
        latestPointerTamperDetected = $latestPointerTamperDetected
        wrongChainStateMismatchDetected = $wrongChainStateMismatchDetected
    }
    reports = [ordered]@{
        backup = $backupReportPath
        secondBackup = $secondBackupReportPath
        restore = $restoreReportPath
        latestRestore = $latestRestoreReportPath
        corruptRestore = $corruptRestoreReportPath
        tamperedManifest = $tamperedRestoreReportPath
        missingStateArtifact = $missingArtifactRestoreReportPath
        missingSnapshotManifest = $missingSnapshotManifestRestoreReportPath
        latestPointerTamper = $latestPointerTamperRestoreReportPath
        wrongChainStateMismatch = $wrongChainStateMismatchRestoreReportPath
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
