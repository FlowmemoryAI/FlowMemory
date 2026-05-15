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
    exists = $false
    writable = $false
    latestBackupTimestamp = $null
    latestBackupArtifactName = $null
    stateRootCompared = $false
    stateRootMatch = $false
    stateFileHashMatch = $false
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
                $stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
                $artifactName = "flowchain-state-backup-check-$stamp.json"
                $artifactPath = Join-Path $backupFullPath $artifactName
                if ($stateFacts.readable) {
                    Copy-Item -LiteralPath $stateFullPath -Destination $artifactPath -Force
                    $backup.writable = Test-Path -LiteralPath $artifactPath
                    $backup.latestBackupArtifactName = $artifactName
                    $backup.latestBackupTimestamp = (Get-Item -LiteralPath $artifactPath).LastWriteTimeUtc.ToString("o")

                    $backupFacts = Get-FlowChainStateFacts -StatePath $artifactPath
                    $backup.stateRootCompared = $true
                    $backup.stateRootMatch = (
                        -not [string]::IsNullOrWhiteSpace($stateFacts.latestRoot) -and
                        $stateFacts.latestRoot -eq $backupFacts.latestRoot
                    )
                    $sourceHash = ((Get-FileHash -Algorithm SHA256 -LiteralPath $stateFullPath).Hash).ToLowerInvariant()
                    $backupHash = ((Get-FileHash -Algorithm SHA256 -LiteralPath $artifactPath).Hash).ToLowerInvariant()
                    $backup.stateFileHashMatch = ($sourceHash -eq $backupHash)
                    if (-not $backup.stateRootMatch -and -not $backup.stateFileHashMatch) {
                        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "backup readback did not match source state root or file hash" -Kind "failed" -Category "artifact"
                    }
                }
                else {
                    $probePath = Join-Path $backupFullPath ".flowchain-backup-write-check-$PID.tmp"
                    "flowchain-backup-write-check" | Set-Content -LiteralPath $probePath -Encoding UTF8
                    $readBack = Get-Content -Raw -LiteralPath $probePath
                    Remove-Item -LiteralPath $probePath -Force
                    $backup.writable = ($readBack -like "flowchain-backup-write-check*")
                }

                $latest = @(Get-ChildItem -LiteralPath $backupFullPath -File -Filter "flowchain-state-*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1)
                if ($latest.Count -gt 0) {
                    $backup.latestBackupTimestamp = $latest[0].LastWriteTimeUtc.ToString("o")
                    $backup.latestBackupArtifactName = $latest[0].Name
                }
                if (-not $backup.writable) {
                    Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "backup path is not writable/readable" -Kind "failed" -Category "artifact"
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
    schema = "flowchain.backup_readiness_report.v0"
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
    problems = @($problems)
    envValuesPrinted = $false
    noSecrets = $true
}
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 14

Write-Host "FlowChain backup readiness status: $status"
Write-Host "Report: $reportFullPath"
if ($missingEnv.Count -gt 0) {
    Write-Host "Missing env names: $((@($missingEnv | Select-Object -Unique)) -join ', ')"
}
if ($status -ne "passed" -and -not $AllowBlocked) {
    throw "FlowChain backup readiness $status. See report for env and artifact names."
}
