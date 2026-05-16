param(
    [string] $BackupRoot = "",
    [string] $ManifestPath = "",
    [string] $RestoreRoot = "devnet/local/restore-rehearsal",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/state-restore-verify-report.json",
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$restoreFullRoot = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $RestoreRoot)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)

if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
    $BackupRoot = Get-FlowChainEnvValue -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH"
}

$problems = New-Object System.Collections.ArrayList
$missingEnv = New-Object System.Collections.ArrayList
if ([string]::IsNullOrWhiteSpace($ManifestPath) -and [string]::IsNullOrWhiteSpace($BackupRoot)) {
    [void] $missingEnv.Add("FLOWCHAIN_RPC_STATE_BACKUP_PATH")
    Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "missing backup root or manifest path for restore verification"
}

$restore = [ordered]@{
    attempted = $false
    verified = $false
    manifestFound = $false
    manifestReadable = $false
    snapshotName = $null
    stateArtifactName = $null
    expectedStateFileSha256 = $null
    restoredStateFileSha256 = $null
    hashMatchesManifest = $false
    stateReadable = $false
    latestHeight = $null
    latestHash = $null
    latestRoot = $null
    finalizedHeight = $null
    liveStateMutated = $false
}

try {
    $manifestFullPath = $null
    $backupFullRoot = $null
    if (-not [string]::IsNullOrWhiteSpace($ManifestPath)) {
        $manifestFullPath = [System.IO.Path]::GetFullPath($ManifestPath)
    }
    elseif ($problems.Count -eq 0) {
        $backupFullRoot = [System.IO.Path]::GetFullPath($BackupRoot)
        if (-not (Test-Path -LiteralPath $backupFullRoot)) {
            Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "configured backup root does not exist" -Kind "failed" -Category "artifact"
        }
        else {
            $latestPath = Join-Path $backupFullRoot "latest-manifest.json"
            if (Test-Path -LiteralPath $latestPath) {
                $manifestFullPath = $latestPath
            }
            else {
                $candidate = @(Get-ChildItem -LiteralPath $backupFullRoot -Recurse -File -Filter "manifest.json" -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTimeUtc -Descending |
                    Select-Object -First 1)
                if ($candidate.Count -gt 0) {
                    $manifestFullPath = $candidate[0].FullName
                }
            }
        }
    }

    if ($problems.Count -eq 0) {
        $restore.attempted = $true
        if ([string]::IsNullOrWhiteSpace($manifestFullPath) -or -not (Test-Path -LiteralPath $manifestFullPath)) {
            Add-FlowChainReadinessProblem -Problems $problems -Name "state-backup-manifest" -Reason "backup manifest was not found" -Kind "failed" -Category "artifact"
        }
        else {
            $restore.manifestFound = $true
            $manifest = Read-FlowChainJsonIfExists -Path $manifestFullPath
            if ($null -eq $manifest) {
                Add-FlowChainReadinessProblem -Problems $problems -Name "state-backup-manifest" -Reason "backup manifest is unreadable" -Kind "failed" -Category "artifact"
            }
            else {
                $restore.manifestReadable = $true
                $snapshotName = Get-FlowChainJsonString -Object $manifest -Names @("snapshotName")
                $stateArtifactName = Get-FlowChainJsonString -Object $manifest -Names @("stateArtifactName") -Fallback "state.json"
                $expectedHash = Get-FlowChainJsonString -Object $manifest -Names @("stateFileSha256")
                $restore.snapshotName = $snapshotName
                $restore.stateArtifactName = $stateArtifactName
                $restore.expectedStateFileSha256 = $expectedHash

                $manifestDir = Split-Path -Parent $manifestFullPath
                if ((Split-Path -Leaf $manifestFullPath) -eq "latest-manifest.json" -and -not [string]::IsNullOrWhiteSpace($snapshotName)) {
                    $candidateDir = Join-Path $manifestDir $snapshotName
                    if (Test-Path -LiteralPath (Join-Path $candidateDir $stateArtifactName)) {
                        $manifestDir = $candidateDir
                    }
                }
                $backupStatePath = Join-Path $manifestDir $stateArtifactName
                if (-not (Test-Path -LiteralPath $backupStatePath)) {
                    Add-FlowChainReadinessProblem -Problems $problems -Name "state-backup-artifact" -Reason "manifest state artifact is missing" -Kind "failed" -Category "artifact"
                }
                elseif ([string]::IsNullOrWhiteSpace($expectedHash)) {
                    Add-FlowChainReadinessProblem -Problems $problems -Name "state-backup-manifest" -Reason "manifest is missing state hash" -Kind "failed" -Category "artifact"
                }
                else {
                    New-Item -ItemType Directory -Force -Path $restoreFullRoot | Out-Null
                    $stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssfffZ")
                    $restoreDir = Join-Path $restoreFullRoot "restore-verify-$stamp"
                    New-Item -ItemType Directory -Force -Path $restoreDir | Out-Null
                    $restoredStatePath = Join-Path $restoreDir "state.json"
                    Copy-Item -LiteralPath $backupStatePath -Destination $restoredStatePath -Force
                    $restoredHash = ((Get-FileHash -Algorithm SHA256 -LiteralPath $restoredStatePath).Hash).ToLowerInvariant()
                    $restore.restoredStateFileSha256 = $restoredHash
                    $restore.hashMatchesManifest = ($restoredHash -eq "$expectedHash".ToLowerInvariant())
                    $restoredFacts = Get-FlowChainStateFacts -StatePath $restoredStatePath
                    $restore.stateReadable = $restoredFacts.readable
                    $restore.latestHeight = $restoredFacts.latestHeight
                    $restore.latestHash = $restoredFacts.latestHash
                    $restore.latestRoot = $restoredFacts.latestRoot
                    $restore.finalizedHeight = $restoredFacts.finalizedHeight
                    $restore.verified = $restore.hashMatchesManifest -and $restore.stateReadable
                    if (-not $restore.hashMatchesManifest) {
                        Add-FlowChainReadinessProblem -Problems $problems -Name "state-backup-artifact" -Reason "restored state hash does not match manifest" -Kind "failed" -Category "artifact"
                    }
                    if (-not $restore.stateReadable) {
                        Add-FlowChainReadinessProblem -Problems $problems -Name "state-backup-artifact" -Reason "restored state is unreadable" -Kind "failed" -Category "artifact"
                    }
                }
            }
        }
    }
}
catch {
    Add-FlowChainReadinessProblem -Problems $problems -Name "state-restore-verify" -Reason "restore verification failed" -Kind "failed" -Category "artifact"
}

$failed = @($problems | Where-Object { $_.kind -eq "failed" })
$status = if ($failed.Count -gt 0) { "failed" } elseif ($problems.Count -gt 0) { "blocked" } else { "passed" }

$report = [ordered]@{
    schema = "flowchain.state_restore_verify_report.v1"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    requiredEnvNames = @("FLOWCHAIN_RPC_STATE_BACKUP_PATH")
    missingEnvNames = @($missingEnv | Select-Object -Unique)
    backupRootConfigured = -not [string]::IsNullOrWhiteSpace($BackupRoot)
    backupRootValuePrinted = $false
    manifestPathValuePrinted = $false
    restore = $restore
    problems = @($problems)
    broadcasts = $false
    envValuesPrinted = $false
    noSecrets = $true
}

$reportText = $report | ConvertTo-Json -Depth 16
Assert-FlowChainNoSecretText -Text $reportText -Label "state restore verify report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

Write-Host "FlowChain state restore verify status: $status"
Write-Host "Report: $reportFullPath"
if ($missingEnv.Count -gt 0) {
    Write-Host "Missing env names: $((@($missingEnv | Select-Object -Unique)) -join ', ')"
}
if ($status -ne "passed" -and -not $AllowBlocked) {
    throw "FlowChain state restore verify $status. See report for env and artifact names."
}
