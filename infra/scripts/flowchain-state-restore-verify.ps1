param(
    [string] $BackupRoot = "",
    [string] $ManifestPath = "",
    [string] $RestoreRoot = "devnet/local/restore-rehearsal",
    [Alias("LiveStatePath")]
    [string] $StatePath = "devnet/local/state.json",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/state-restore-verify-report.json",
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$restoreFullRoot = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $RestoreRoot)
$liveStateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)

if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
    $BackupRoot = Get-FlowChainEnvValue -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH"
}

function Get-RestoreProp {
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

function Get-RestoreFileSha256 {
    param([Parameter(Mandatory = $true)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    return ((Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash).ToLowerInvariant()
}

function Get-RestoreSortTicks {
    param(
        [AllowNull()][object] $Manifest,
        [AllowNull()][string] $SnapshotName
    )

    $generatedAt = Get-FlowChainJsonString -Object $Manifest -Names @("generatedAt")
    if (-not [string]::IsNullOrWhiteSpace($generatedAt)) {
        try {
            return ([DateTimeOffset]::Parse($generatedAt, [System.Globalization.CultureInfo]::InvariantCulture)).UtcTicks
        }
        catch {
        }
    }

    if ($SnapshotName -match '^flowchain-state-snapshot-(\d{8}T\d{9}Z)$') {
        try {
            return ([DateTimeOffset]::ParseExact($Matches[1], "yyyyMMddTHHmmssfffZ", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal)).UtcTicks
        }
        catch {
        }
    }

    return 0
}

function Convert-RestoreManifestCanonical {
    param([AllowNull()][object] $Manifest)

    if ($null -eq $Manifest) {
        return ""
    }
    return ($Manifest | ConvertTo-Json -Depth 20 -Compress)
}

function Test-RestoreManifestEquivalent {
    param(
        [AllowNull()][object] $Left,
        [AllowNull()][object] $Right
    )

    return (Convert-RestoreManifestCanonical -Manifest $Left) -eq (Convert-RestoreManifestCanonical -Manifest $Right)
}

function New-RestoreManifestInfo {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [AllowNull()][string] $SnapshotDir = $null
    )

    $manifest = Read-FlowChainJsonIfExists -Path $Path
    $snapshotName = Get-FlowChainJsonString -Object $manifest -Names @("snapshotName")
    if ([string]::IsNullOrWhiteSpace($SnapshotDir) -and -not [string]::IsNullOrWhiteSpace($snapshotName)) {
        $parent = Split-Path -Parent $Path
        if ((Split-Path -Leaf $Path) -eq "latest-manifest.json") {
            $SnapshotDir = Join-Path $parent $snapshotName
        }
        else {
            $SnapshotDir = $parent
        }
    }

    return [ordered]@{
        path = $Path
        manifest = $manifest
        readable = $null -ne $manifest
        snapshotName = $snapshotName
        snapshotDir = $SnapshotDir
        sortTicks = Get-RestoreSortTicks -Manifest $manifest -SnapshotName $snapshotName
    }
}

function Get-RestoreSnapshotManifestInfos {
    param([Parameter(Mandatory = $true)][string] $BackupFullRoot)

    $infos = New-Object System.Collections.ArrayList
    foreach ($directory in @(Get-ChildItem -LiteralPath $BackupFullRoot -Directory -ErrorAction SilentlyContinue)) {
        $manifestPath = Join-Path $directory.FullName "manifest.json"
        if (-not (Test-Path -LiteralPath $manifestPath)) {
            continue
        }
        $info = New-RestoreManifestInfo -Path $manifestPath -SnapshotDir $directory.FullName
        if ($info.readable -and -not [string]::IsNullOrWhiteSpace($info.snapshotName)) {
            [void] $infos.Add($info)
        }
    }

    return @($infos | Sort-Object @{ Expression = { $_.sortTicks }; Descending = $true }, @{ Expression = { $_.snapshotName }; Descending = $true })
}

function Test-RestoreSafeArtifactName {
    param([AllowNull()][string] $Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $false
    }
    if ([System.IO.Path]::IsPathRooted($Name)) {
        return $false
    }
    if ($Name -match '[\\/]') {
        return $false
    }
    return ([System.IO.Path]::GetFileName($Name)) -eq $Name
}

function Test-RestorePathInside {
    param(
        [Parameter(Mandatory = $true)][string] $Root,
        [Parameter(Mandatory = $true)][string] $Path
    )

    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $prefix = $fullRoot + [System.IO.Path]::DirectorySeparatorChar
    return $fullPath -eq $fullRoot -or $fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Compare-RestoreStateFacts {
    param(
        [AllowNull()][object] $ManifestState,
        [Parameter(Mandatory = $true)][object] $RestoredFacts
    )

    $mismatches = New-Object System.Collections.ArrayList
    foreach ($name in @("chainId", "latestHeight", "latestHash", "latestRoot", "finalizedHeight", "finalizedHash", "blockCount")) {
        $expected = Get-RestoreProp -Object $ManifestState -Name $name
        $actual = Get-RestoreProp -Object $RestoredFacts -Name $name
        if ("$expected" -ne "$actual") {
            [void] $mismatches.Add([ordered]@{
                name = $name
                expected = "$expected"
                actual = "$actual"
            })
        }
    }

    return @($mismatches)
}

$problems = New-Object System.Collections.ArrayList
$missingEnv = New-Object System.Collections.ArrayList
if ([string]::IsNullOrWhiteSpace($ManifestPath) -and [string]::IsNullOrWhiteSpace($BackupRoot)) {
    [void] $missingEnv.Add("FLOWCHAIN_RPC_STATE_BACKUP_PATH")
    Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "missing backup root or manifest path for restore verification"
}

$liveStateHashBefore = Get-RestoreFileSha256 -Path $liveStateFullPath
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
    stateFactsMatchManifest = $false
    stateFactsMismatches = @()
    manifestPath = $null
    backupStatePath = $null
    restoredStatePath = $null
    restoreRoot = $restoreFullRoot
    liveStatePath = $liveStateFullPath
    liveStateSha256Before = $liveStateHashBefore
    liveStateSha256After = $null
    liveStateHashChangedDuringRehearsal = $false
    liveStatePathProtected = $false
    restoredStatePathEqualsLiveStatePath = $false
    latestHeight = $null
    latestHash = $null
    latestRoot = $null
    finalizedHeight = $null
    liveStateMutated = $false
}
$latestSelection = [ordered]@{
    mode = ""
    latestManifestFound = $false
    selectedManifestPath = $null
    selectedSnapshotName = $null
    newestSnapshotName = $null
    latestPointerSnapshotName = $null
    latestPointerMatchesNewest = $false
    latestPointerMatchesSnapshotManifest = $false
    snapshotManifestFound = $false
    snapshotManifestReadable = $false
    candidateCount = 0
}

try {
    $selectedInfo = $null
    $backupFullRoot = $null
    if (-not [string]::IsNullOrWhiteSpace($ManifestPath)) {
        $manifestFullPath = [System.IO.Path]::GetFullPath($ManifestPath)
        $selectedInfo = New-RestoreManifestInfo -Path $manifestFullPath
        $latestSelection.mode = "explicit-manifest"
    }
    elseif ($problems.Count -eq 0) {
        $backupFullRoot = [System.IO.Path]::GetFullPath($BackupRoot)
        if (-not (Test-Path -LiteralPath $backupFullRoot)) {
            Add-FlowChainReadinessProblem -Problems $problems -Name "FLOWCHAIN_RPC_STATE_BACKUP_PATH" -Reason "configured backup root does not exist" -Kind "failed" -Category "artifact"
        }
        else {
            $snapshotInfos = @(Get-RestoreSnapshotManifestInfos -BackupFullRoot $backupFullRoot)
            $latestSelection.candidateCount = $snapshotInfos.Count
            $newestInfo = $null
            if ($snapshotInfos.Count -gt 0) {
                $newestInfo = $snapshotInfos[0]
                $latestSelection.newestSnapshotName = $newestInfo.snapshotName
            }

            $latestPath = Join-Path $backupFullRoot "latest-manifest.json"
            if (Test-Path -LiteralPath $latestPath) {
                $latestSelection.mode = "latest-pointer"
                $latestSelection.latestManifestFound = $true
                $selectedInfo = New-RestoreManifestInfo -Path $latestPath
                $latestSelection.latestPointerSnapshotName = $selectedInfo.snapshotName
                if ($null -ne $newestInfo) {
                    $latestSelection.latestPointerMatchesNewest = $selectedInfo.snapshotName -eq $newestInfo.snapshotName
                    if (-not $latestSelection.latestPointerMatchesNewest) {
                        Add-FlowChainReadinessProblem -Problems $problems -Name "latest-manifest.json" -Reason "latest manifest does not point at the newest snapshot" -Kind "failed" -Category "artifact"
                    }
                }
                else {
                    Add-FlowChainReadinessProblem -Problems $problems -Name "state-backup-manifest" -Reason "latest manifest exists but no snapshot manifest candidates were found" -Kind "failed" -Category "artifact"
                }
            }
            elseif ($null -ne $newestInfo) {
                $latestSelection.mode = "newest-snapshot-manifest"
                $selectedInfo = $newestInfo
            }
        }
    }

    if ($problems.Count -eq 0 -or $null -ne $selectedInfo) {
        $restore.attempted = $true
        if ($null -eq $selectedInfo -or [string]::IsNullOrWhiteSpace($selectedInfo.path) -or -not (Test-Path -LiteralPath $selectedInfo.path)) {
            Add-FlowChainReadinessProblem -Problems $problems -Name "state-backup-manifest" -Reason "backup manifest was not found" -Kind "failed" -Category "artifact"
        }
        else {
            $restore.manifestFound = $true
            $restore.manifestPath = $selectedInfo.path
            $manifest = $selectedInfo.manifest
            if ($null -eq $manifest) {
                Add-FlowChainReadinessProblem -Problems $problems -Name "state-backup-manifest" -Reason "backup manifest is unreadable" -Kind "failed" -Category "artifact"
            }
            else {
                $restore.manifestReadable = $true
                if ((Get-FlowChainJsonString -Object $manifest -Names @("schema")) -ne "flowchain.state_backup_manifest.v1") {
                    Add-FlowChainReadinessProblem -Problems $problems -Name "state-backup-manifest" -Reason "manifest schema is not supported" -Kind "failed" -Category "artifact"
                }

                $snapshotName = Get-FlowChainJsonString -Object $manifest -Names @("snapshotName")
                $stateArtifactName = Get-FlowChainJsonString -Object $manifest -Names @("stateArtifactName") -Fallback "state.json"
                $expectedHash = Get-FlowChainJsonString -Object $manifest -Names @("stateFileSha256")
                $restore.snapshotName = $snapshotName
                $restore.stateArtifactName = $stateArtifactName
                $restore.expectedStateFileSha256 = $expectedHash
                $latestSelection.selectedManifestPath = $selectedInfo.path
                $latestSelection.selectedSnapshotName = $snapshotName

                if (-not (Test-RestoreSafeArtifactName -Name $stateArtifactName)) {
                    Add-FlowChainReadinessProblem -Problems $problems -Name "state-backup-manifest" -Reason "manifest state artifact name is unsafe" -Kind "failed" -Category "artifact"
                }

                $manifestDir = Split-Path -Parent $selectedInfo.path
                $snapshotDir = $selectedInfo.snapshotDir
                if ([string]::IsNullOrWhiteSpace($snapshotDir)) {
                    $snapshotDir = $manifestDir
                }
                if ((Split-Path -Leaf $selectedInfo.path) -eq "latest-manifest.json" -and -not [string]::IsNullOrWhiteSpace($snapshotName)) {
                    $snapshotDir = Join-Path $manifestDir $snapshotName
                }

                $snapshotManifestPath = Join-Path $snapshotDir "manifest.json"
                $snapshotManifest = $null
                if (Test-Path -LiteralPath $snapshotManifestPath) {
                    $latestSelection.snapshotManifestFound = $true
                    $snapshotManifest = Read-FlowChainJsonIfExists -Path $snapshotManifestPath
                    $latestSelection.snapshotManifestReadable = $null -ne $snapshotManifest
                }
                if ((Split-Path -Leaf $selectedInfo.path) -eq "latest-manifest.json") {
                    if (-not $latestSelection.snapshotManifestFound) {
                        Add-FlowChainReadinessProblem -Problems $problems -Name "state-backup-manifest" -Reason "latest manifest target snapshot manifest is missing" -Kind "failed" -Category "artifact"
                    }
                    elseif (-not $latestSelection.snapshotManifestReadable) {
                        Add-FlowChainReadinessProblem -Problems $problems -Name "state-backup-manifest" -Reason "latest manifest target snapshot manifest is unreadable" -Kind "failed" -Category "artifact"
                    }
                    else {
                        $latestSelection.latestPointerMatchesSnapshotManifest = Test-RestoreManifestEquivalent -Left $manifest -Right $snapshotManifest
                        if (-not $latestSelection.latestPointerMatchesSnapshotManifest) {
                            Add-FlowChainReadinessProblem -Problems $problems -Name "latest-manifest.json" -Reason "latest manifest content does not match the snapshot manifest" -Kind "failed" -Category "artifact"
                        }
                    }
                }
                elseif ($latestSelection.mode -eq "newest-snapshot-manifest") {
                    $latestSelection.snapshotManifestFound = $true
                    $latestSelection.snapshotManifestReadable = $true
                    $latestSelection.latestPointerMatchesNewest = $true
                    $latestSelection.latestPointerMatchesSnapshotManifest = $true
                }

                $snapshotDirName = Split-Path -Leaf $snapshotDir
                if ($snapshotDirName -like "flowchain-state-snapshot-*" -and $snapshotName -ne $snapshotDirName) {
                    Add-FlowChainReadinessProblem -Problems $problems -Name "state-backup-manifest" -Reason "manifest snapshot name does not match snapshot directory" -Kind "failed" -Category "artifact"
                }

                $backupStatePath = Join-Path $snapshotDir $stateArtifactName
                $restore.backupStatePath = $backupStatePath
                if (-not (Test-RestorePathInside -Root $snapshotDir -Path $backupStatePath)) {
                    Add-FlowChainReadinessProblem -Problems $problems -Name "state-backup-artifact" -Reason "manifest state artifact resolves outside the snapshot directory" -Kind "failed" -Category "artifact"
                }
                elseif (-not (Test-Path -LiteralPath $backupStatePath)) {
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
                    $restore.restoredStatePath = $restoredStatePath
                    $restore.restoredStatePathEqualsLiveStatePath = $restoredStatePath.Equals($liveStateFullPath, [System.StringComparison]::OrdinalIgnoreCase)
                    $restore.liveStatePathProtected = -not $restore.restoredStatePathEqualsLiveStatePath
                    if (-not $restore.liveStatePathProtected) {
                        Add-FlowChainReadinessProblem -Problems $problems -Name "state-restore-target" -Reason "restore target resolves to the live state path" -Kind "failed" -Category "artifact"
                    }
                    Copy-Item -LiteralPath $backupStatePath -Destination $restoredStatePath -Force
                    $restoredHash = Get-RestoreFileSha256 -Path $restoredStatePath
                    $restore.restoredStateFileSha256 = $restoredHash
                    $restore.hashMatchesManifest = ($restoredHash -eq "$expectedHash".ToLowerInvariant())
                    $restoredFacts = Get-FlowChainStateFacts -StatePath $restoredStatePath
                    $restore.stateReadable = $restoredFacts.readable
                    $restore.latestHeight = $restoredFacts.latestHeight
                    $restore.latestHash = $restoredFacts.latestHash
                    $restore.latestRoot = $restoredFacts.latestRoot
                    $restore.finalizedHeight = $restoredFacts.finalizedHeight
                    $mismatches = @(Compare-RestoreStateFacts -ManifestState (Get-RestoreProp -Object $manifest -Name "state") -RestoredFacts $restoredFacts)
                    $restore.stateFactsMismatches = $mismatches
                    $restore.stateFactsMatchManifest = $mismatches.Count -eq 0
                    $restore.verified = $restore.hashMatchesManifest -and $restore.stateReadable -and $restore.stateFactsMatchManifest -and $restore.liveStatePathProtected
                    if (-not $restore.hashMatchesManifest) {
                        Add-FlowChainReadinessProblem -Problems $problems -Name "state-backup-artifact" -Reason "restored state hash does not match manifest" -Kind "failed" -Category "artifact"
                    }
                    if (-not $restore.stateReadable) {
                        Add-FlowChainReadinessProblem -Problems $problems -Name "state-backup-artifact" -Reason "restored state is unreadable" -Kind "failed" -Category "artifact"
                    }
                    if (-not $restore.stateFactsMatchManifest) {
                        Add-FlowChainReadinessProblem -Problems $problems -Name "state-backup-manifest" -Reason "restored state facts do not match manifest state facts" -Kind "failed" -Category "artifact"
                    }
                }
            }
        }
    }
}
catch {
    Add-FlowChainReadinessProblem -Problems $problems -Name "state-restore-verify" -Reason "restore verification failed" -Kind "failed" -Category "artifact"
}

$liveStateHashAfter = Get-RestoreFileSha256 -Path $liveStateFullPath
$restore.liveStateSha256After = $liveStateHashAfter
if ($null -ne $liveStateHashBefore -and $null -ne $liveStateHashAfter) {
    $restore.liveStateHashChangedDuringRehearsal = $liveStateHashBefore -ne $liveStateHashAfter
    $restore.liveStateMutated = $restore.restoredStatePathEqualsLiveStatePath
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
    latestSelection = $latestSelection
    restore = $restore
    problems = @($problems)
    broadcasts = $false
    envValuesPrinted = $false
    noSecrets = $true
}

$reportText = $report | ConvertTo-Json -Depth 20
Assert-FlowChainNoSecretText -Text $reportText -Label "state restore verify report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20

Write-Host "FlowChain state restore verify status: $status"
Write-Host "Report: $reportFullPath"
if ($missingEnv.Count -gt 0) {
    Write-Host "Missing env names: $((@($missingEnv | Select-Object -Unique)) -join ', ')"
}
if ($status -ne "passed" -and -not $AllowBlocked) {
    throw "FlowChain state restore verify $status. See report for env and artifact names."
}
