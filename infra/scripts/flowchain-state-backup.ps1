param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $BackupRoot = "",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/state-backup-report.json",
    [int] $MaxAttempts = 5,
    [switch] $CreateBackupRoot,
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)

function Get-StateBackupFileSha256 {
    param([Parameter(Mandatory = $true)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    return ((Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash).ToLowerInvariant()
}

function Convert-StateBackupManifestCanonical {
    param([AllowNull()][object] $Manifest)

    if ($null -eq $Manifest) {
        return ""
    }
    return ($Manifest | ConvertTo-Json -Depth 20 -Compress)
}

function Test-StateBackupManifestEquivalent {
    param(
        [AllowNull()][object] $Left,
        [AllowNull()][object] $Right
    )

    return (Convert-StateBackupManifestCanonical -Manifest $Left) -eq (Convert-StateBackupManifestCanonical -Manifest $Right)
}

function Write-StateBackupJsonAtomic {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][object] $Value,
        [int] $Depth = 12
    )

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    $tempPath = Join-Path $parent "$([System.IO.Path]::GetFileName($Path)).tmp-$PID-$([Guid]::NewGuid().ToString("N"))"
    try {
        Write-FlowChainJson -Path $tempPath -Value $Value -Depth $Depth
        Move-Item -LiteralPath $tempPath -Destination $Path -Force -ErrorAction Stop
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }
}

if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
    $BackupRoot = Get-FlowChainEnvValue -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH"
}

$problems = New-Object System.Collections.ArrayList
$missingEnv = New-Object System.Collections.ArrayList
if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
    [void] $missingEnv.Add("FLOWCHAIN_RPC_STATE_BACKUP_PATH")
    Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "missing required backup root for state snapshot"
}

$snapshot = [ordered]@{
    attempted = $false
    created = $false
    snapshotName = $null
    stateArtifactName = $null
    manifestName = $null
    latestManifestName = $null
    stateFileSha256 = $null
    stateBytes = $null
    sourceStateReadable = $false
    snapshotReadable = $false
    manifestReadable = $false
    writeVerified = $false
    snapshotManifestSha256 = $null
    latestManifestSha256 = $null
    latestManifestReadable = $false
    latestPointerWrittenAtomically = $false
    latestPointerMatchesSnapshotManifest = $false
    attempts = 0
    latestHeight = $null
    latestHash = $null
    latestRoot = $null
    finalizedHeight = $null
}

if ($problems.Count -eq 0) {
    try {
        $backupFullRoot = [System.IO.Path]::GetFullPath($BackupRoot)
        if (-not (Test-Path -LiteralPath $backupFullRoot)) {
            if ($CreateBackupRoot) {
                New-Item -ItemType Directory -Force -Path $backupFullRoot | Out-Null
            }
            else {
                Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "configured backup root does not exist" -Kind "failed" -Category "artifact"
            }
        }

        if ($problems.Count -eq 0) {
            $backupRootItem = Get-Item -LiteralPath $backupFullRoot
            if (-not $backupRootItem.PSIsContainer) {
                Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "configured backup root must be a directory" -Kind "failed" -Category "artifact"
            }
        }

        if ($problems.Count -eq 0 -and -not (Test-Path -LiteralPath $stateFullPath)) {
            Add-FlowChainReadinessProblem -Problems $problems -Name "devnet/local/state.json" -Reason "state file is missing" -Kind "failed" -Category "artifact"
        }

        if ($problems.Count -eq 0) {
            $snapshot.attempted = $true
            $snapshot.sourceStateReadable = (Get-FlowChainStateFacts -StatePath $stateFullPath).readable
            if (-not $snapshot.sourceStateReadable) {
                Add-FlowChainReadinessProblem -Problems $problems -Name "devnet/local/state.json" -Reason "state file is unreadable" -Kind "failed" -Category "artifact"
            }
        }

        if ($problems.Count -eq 0) {
            $lastError = $null
            $snapshotManifest = $null
            $snapshotDir = $null
            for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
                $snapshot.attempts = $attempt
                $stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssfffZ")
                $snapshotName = "flowchain-state-snapshot-$stamp"
                $tempName = "$snapshotName.tmp-$PID"
                $tempDir = Join-Path $backupFullRoot $tempName
                $finalDir = Join-Path $backupFullRoot $snapshotName
                try {
                    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
                    $stateCopyPath = Join-Path $tempDir "state.json"
                    Copy-Item -LiteralPath $stateFullPath -Destination $stateCopyPath -Force

                    $copyFacts = Get-FlowChainStateFacts -StatePath $stateCopyPath
                    if (-not $copyFacts.readable) {
                        throw "snapshot state copy was not readable"
                    }

                    $stateHash = ((Get-FileHash -Algorithm SHA256 -LiteralPath $stateCopyPath).Hash).ToLowerInvariant()
                    $stateItem = Get-Item -LiteralPath $stateCopyPath
                    $snapshotManifest = [ordered]@{
                        schema = "flowchain.state_backup_manifest.v1"
                        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
                        snapshotName = $snapshotName
                        stateArtifactName = "state.json"
                        stateFileSha256 = $stateHash
                        stateBytes = [int64] $stateItem.Length
                        state = [ordered]@{
                            chainId = $copyFacts.chainId
                            latestHeight = $copyFacts.latestHeight
                            latestHash = $copyFacts.latestHash
                            latestRoot = $copyFacts.latestRoot
                            finalizedHeight = $copyFacts.finalizedHeight
                            finalizedHash = $copyFacts.finalizedHash
                            blockCount = $copyFacts.blockCount
                        }
                        restoreCommand = "npm run flowchain:backup:restore:verify"
                        envValuesPrinted = $false
                        noSecrets = $true
                    }

                    Write-FlowChainJson -Path (Join-Path $tempDir "manifest.json") -Value $snapshotManifest -Depth 12
                    Move-Item -LiteralPath $tempDir -Destination $finalDir -ErrorAction Stop
                    $finalManifestPath = Join-Path $finalDir "manifest.json"
                    $latestManifestPath = Join-Path $backupFullRoot "latest-manifest.json"
                    Write-StateBackupJsonAtomic -Path $latestManifestPath -Value $snapshotManifest -Depth 12
                    $latestManifest = Read-FlowChainJsonIfExists -Path $latestManifestPath

                    $snapshotDir = $finalDir
                    $snapshot.snapshotName = $snapshotName
                    $snapshot.stateArtifactName = "state.json"
                    $snapshot.manifestName = "manifest.json"
                    $snapshot.latestManifestName = "latest-manifest.json"
                    $snapshot.stateFileSha256 = $stateHash
                    $snapshot.stateBytes = [int64] $stateItem.Length
                    $snapshot.snapshotReadable = (Get-FlowChainStateFacts -StatePath (Join-Path $snapshotDir "state.json")).readable
                    $snapshotManifestReadback = Read-FlowChainJsonIfExists -Path $finalManifestPath
                    $snapshot.manifestReadable = $null -ne $snapshotManifestReadback
                    $snapshot.latestManifestReadable = $null -ne $latestManifest
                    $snapshot.latestPointerWrittenAtomically = $snapshot.latestManifestReadable
                    $snapshot.latestPointerMatchesSnapshotManifest = Test-StateBackupManifestEquivalent -Left $snapshotManifestReadback -Right $latestManifest
                    $snapshot.snapshotManifestSha256 = Get-StateBackupFileSha256 -Path $finalManifestPath
                    $snapshot.latestManifestSha256 = Get-StateBackupFileSha256 -Path $latestManifestPath
                    $snapshot.writeVerified = $snapshot.snapshotReadable `
                        -and $snapshot.manifestReadable `
                        -and $snapshot.latestManifestReadable `
                        -and $snapshot.latestPointerMatchesSnapshotManifest `
                        -and (-not [string]::IsNullOrWhiteSpace([string] $snapshot.snapshotManifestSha256)) `
                        -and $snapshot.snapshotManifestSha256 -eq $snapshot.latestManifestSha256
                    $snapshot.latestHeight = $copyFacts.latestHeight
                    $snapshot.latestHash = $copyFacts.latestHash
                    $snapshot.latestRoot = $copyFacts.latestRoot
                    $snapshot.finalizedHeight = $copyFacts.finalizedHeight
                    $snapshot.created = $snapshot.writeVerified
                    break
                }
                catch {
                    $lastError = $_
                    if (Test-Path -LiteralPath $tempDir) {
                        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Start-Sleep -Milliseconds (150 * $attempt)
                }
            }

            if (-not $snapshot.created) {
                Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "state backup snapshot could not be created" -Kind "failed" -Category "artifact"
            }
            elseif (-not $snapshot.latestPointerMatchesSnapshotManifest) {
                Add-FlowChainReadinessProblem -Problems $problems -Name "latest-manifest.json" -Reason "latest backup pointer does not match the snapshot manifest" -Kind "failed" -Category "artifact"
            }
        }
    }
    catch {
        Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "state backup failed" -Kind "failed" -Category "artifact"
    }
}

$failed = @($problems | Where-Object { $_.kind -eq "failed" })
$status = if ($failed.Count -gt 0) { "failed" } elseif ($problems.Count -gt 0) { "blocked" } else { "passed" }

$report = [ordered]@{
    schema = "flowchain.state_backup_report.v1"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    requiredEnvNames = @("FLOWCHAIN_RPC_STATE_BACKUP_PATH")
    missingEnvNames = @($missingEnv | Select-Object -Unique)
    backupRootConfigured = -not [string]::IsNullOrWhiteSpace($BackupRoot)
    backupRootValuePrinted = $false
    snapshot = $snapshot
    problems = @($problems)
    broadcasts = $false
    envValuesPrinted = $false
    noSecrets = $true
}

$reportText = $report | ConvertTo-Json -Depth 16
Assert-FlowChainNoSecretText -Text $reportText -Label "state backup report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

Write-Host "FlowChain state backup status: $status"
Write-Host "Report: $reportFullPath"
if ($missingEnv.Count -gt 0) {
    Write-Host "Missing env names: $((@($missingEnv | Select-Object -Unique)) -join ', ')"
}
if ($status -ne "passed" -and -not $AllowBlocked) {
    throw "FlowChain state backup $status. See report for env and artifact names."
}
