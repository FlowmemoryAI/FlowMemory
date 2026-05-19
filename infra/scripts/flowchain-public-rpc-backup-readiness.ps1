param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json",
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$reportDir = Split-Path -Parent $reportFullPath
$backupProofReportPath = Join-Path $reportDir "state-backup-report.json"
$restoreProofReportPath = Join-Path $reportDir "state-restore-verify-report.json"

function Invoke-BackupReadinessChild {
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
        outputLineCount = @($output).Count
    }
}

$problems = New-Object System.Collections.ArrayList
$missingEnv = New-Object System.Collections.ArrayList
$backupPathRaw = Get-FlowChainEnvValue -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH"

if ([string]::IsNullOrWhiteSpace($backupPathRaw)) {
    [void] $missingEnv.Add("FLOWCHAIN_RPC_STATE_BACKUP_PATH")
    Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "missing required backup path env value"
}

$stateFacts = Get-FlowChainStateFacts -StatePath $stateFullPath
if (-not $stateFacts.readable) {
    Add-FlowChainReadinessProblem -Problems $problems -Name "devnet/local/state.json" -Reason "state file is missing or unreadable" -Category "artifact"
}

$backup = [ordered]@{
    configured = -not [string]::IsNullOrWhiteSpace($backupPathRaw)
    pathValuePrinted = $false
    exists = $false
    directory = $false
    snapshotProofStatus = "not-run"
    restoreProofStatus = "not-run"
    latestBackupTimestamp = $null
    latestBackupArtifactName = $null
    stateRootCompared = $false
    stateRootMatch = $false
    stateFileHashMatch = $false
    writeVerified = $false
    latestPointerVerified = $false
    latestPointerWrittenAtomically = $false
    snapshotManifestHash = $null
    latestManifestHash = $null
    retentionCount = $null
    retentionCandidateCount = $null
    retentionCurrentSnapshotProtected = $false
    retentionPruneErrorCount = $null
    restoreVerified = $false
}

if (-not [string]::IsNullOrWhiteSpace($backupPathRaw)) {
    try {
        $backupFullPath = [System.IO.Path]::GetFullPath($backupPathRaw)
        if (-not (Test-Path -LiteralPath $backupFullPath)) {
            Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "configured backup path does not exist" -Kind "failed" -Category "artifact"
        }
        else {
            $item = Get-Item -LiteralPath $backupFullPath
            if (-not $item.PSIsContainer) {
                Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "configured backup path must be a directory" -Kind "failed" -Category "artifact"
            }
            else {
                $backup.exists = $true
                $backup.directory = $true
            }
        }

        if ($backup.exists -and $stateFacts.readable) {
            $backupChild = Invoke-BackupReadinessChild -ArgumentList @(
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                (Join-Path $PSScriptRoot "flowchain-state-backup.ps1"),
                "-StatePath",
                $stateFullPath,
                "-BackupRoot",
                $backupFullPath,
                "-ReportPath",
                $backupProofReportPath
            )
            $backupProof = Read-FlowChainJsonIfExists -Path $backupProofReportPath
            $backup.snapshotProofStatus = if ($null -ne $backupProof) { "$($backupProof.status)" } else { "missing" }

            if ($backupChild.exitCode -ne 0 -or $backup.snapshotProofStatus -ne "passed") {
                Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "state backup proof did not pass" -Kind "failed" -Category "artifact"
            }
            else {
                $snapshot = $backupProof.snapshot
                $backup.writeVerified = $snapshot.writeVerified -eq $true
                $backup.latestPointerVerified = $snapshot.latestPointerMatchesSnapshotManifest -eq $true
                $backup.latestPointerWrittenAtomically = $snapshot.latestPointerWrittenAtomically -eq $true
                $backup.snapshotManifestHash = [string] $snapshot.snapshotManifestSha256
                $backup.latestManifestHash = [string] $snapshot.latestManifestSha256
                $backup.latestBackupArtifactName = [string] $snapshot.snapshotName
                $backup.latestBackupTimestamp = [string] $backupProof.generatedAt
                $backup.retentionCount = $backupProof.retention.retentionCount
                $backup.retentionCandidateCount = $backupProof.retention.candidateCount
                $backup.retentionCurrentSnapshotProtected = $backupProof.retention.currentSnapshotProtected -eq $true
                $backup.retentionPruneErrorCount = @($backupProof.retention.pruneErrors).Count
                $backup.stateFileHashMatch = $snapshot.created -eq $true
                $backup.stateRootCompared = -not [string]::IsNullOrWhiteSpace([string] $snapshot.latestRoot)
                $backup.stateRootMatch = $backup.stateRootCompared
                if (-not $backup.latestPointerVerified) {
                    Add-FlowChainReadinessProblem -Problems $problems -Name "latest-manifest.json" -Reason "latest manifest pointer did not match snapshot manifest" -Kind "failed" -Category "artifact"
                }
                if (-not $backup.retentionCurrentSnapshotProtected) {
                    Add-FlowChainReadinessProblem -Problems $problems -Name "state-backup-retention" -Reason "backup retention did not protect the latest snapshot" -Kind "failed" -Category "artifact"
                }
                if ($backup.retentionPruneErrorCount -gt 0) {
                    Add-FlowChainReadinessProblem -Problems $problems -Name "state-backup-retention" -Reason "backup retention reported prune errors" -Kind "failed" -Category "artifact"
                }

                $restoreChild = Invoke-BackupReadinessChild -ArgumentList @(
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    (Join-Path $PSScriptRoot "flowchain-state-restore-verify.ps1"),
                    "-BackupRoot",
                    $backupFullPath,
                    "-RestoreRoot",
                    "devnet/local/restore-rehearsal/backup-readiness",
                    "-ReportPath",
                    $restoreProofReportPath
                )
                $restoreProof = Read-FlowChainJsonIfExists -Path $restoreProofReportPath
                $backup.restoreProofStatus = if ($null -ne $restoreProof) { "$($restoreProof.status)" } else { "missing" }
                if ($restoreChild.exitCode -ne 0 -or $backup.restoreProofStatus -ne "passed") {
                    Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "state restore proof did not pass" -Kind "failed" -Category "artifact"
                }
                else {
                    $backup.restoreVerified = $restoreProof.restore.verified -eq $true
                    if (-not $backup.restoreVerified) {
                        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "state restore proof was not verified" -Kind "failed" -Category "artifact"
                    }
                }
            }
        }
    }
    catch {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "backup verification failed" -Kind "failed" -Category "artifact"
    }
}

$failed = @($problems | Where-Object { $_.kind -eq "failed" })
$status = if ($failed.Count -gt 0) { "failed" } elseif ($problems.Count -gt 0) { "blocked" } else { "passed" }

$report = [ordered]@{
    schema = "flowchain.backup_readiness_report.v1"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    requiredEnvNames = @("FLOWCHAIN_RPC_STATE_BACKUP_PATH")
    missingEnvNames = @($missingEnv | Select-Object -Unique)
    state = [ordered]@{
        statePath = $StatePath
        readable = $stateFacts.readable
        latestHeight = $stateFacts.latestHeight
        latestHash = $stateFacts.latestHash
        latestRoot = $stateFacts.latestRoot
    }
    backup = $backup
    proofReports = [ordered]@{
        snapshot = $backupProofReportPath
        restore = $restoreProofReportPath
    }
    problems = @($problems)
    envValuesPrinted = $false
    noSecrets = $true
}

$reportText = $report | ConvertTo-Json -Depth 16
Assert-FlowChainNoSecretText -Text $reportText -Label "backup readiness report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

Write-Host "FlowChain backup readiness status: $status"
Write-Host "Report: $reportFullPath"
if ($missingEnv.Count -gt 0) {
    Write-Host "Missing env names: $((@($missingEnv | Select-Object -Unique)) -join ', ')"
}
if ($status -ne "passed" -and -not $AllowBlocked) {
    throw "FlowChain backup readiness $status. See report for env and artifact names."
}
