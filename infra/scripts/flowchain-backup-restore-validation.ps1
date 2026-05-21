param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-report.json",
    [int] $ChildTimeoutSeconds = 300
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$validationRoot = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/backup-restore-validation")

if ($ChildTimeoutSeconds -lt 1) {
    throw "ChildTimeoutSeconds must be at least 1."
}

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
$retentionBackupReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-retention-backup-report.json"
$retentionRestoreReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-retention-restore-report.json"

$script:ValidationChildResults = New-Object System.Collections.ArrayList

function Stop-ValidationProcessTree {
    param([Parameter(Mandatory = $true)][int] $ProcessId)

    $children = @()
    try {
        $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$ProcessId" -ErrorAction SilentlyContinue)
    }
    catch {
        $children = @()
    }

    foreach ($child in $children) {
        Stop-ValidationProcessTree -ProcessId ([int] $child.ProcessId)
    }

    try {
        Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
    }
    catch {
    }
}

function Read-ValidationOutputFile {
    param([Parameter(Mandatory = $true)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }
    return @(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue | ForEach-Object { "$_" })
}

function Invoke-ValidationChild {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string[]] $ArgumentList
    )

    $startedAt = (Get-Date).ToUniversalTime()
    $stamp = $startedAt.ToString("yyyyMMddTHHmmssfffZ")
    $tempBase = Join-Path ([System.IO.Path]::GetTempPath()) "flowchain-backup-restore-validation-$PID-$stamp-$([Guid]::NewGuid().ToString("N"))"
    $stdoutPath = "$tempBase.out.log"
    $stderrPath = "$tempBase.err.log"
    $timedOut = $false
    $exitCode = 1
    $processId = $null
    $output = @()

    try {
        $process = Start-Process -FilePath "powershell" `
            -ArgumentList (Join-FlowChainProcessArguments -ArgumentList $ArgumentList) `
            -WorkingDirectory $repoRoot `
            -PassThru `
            -WindowStyle Hidden `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath
        $processId = $process.Id
        if (-not $process.WaitForExit($ChildTimeoutSeconds * 1000)) {
            $timedOut = $true
            Stop-ValidationProcessTree -ProcessId $process.Id
            $exitCode = 124
        }
        else {
            $process.Refresh()
            $exitCode = [int] $process.ExitCode
        }
    }
    catch {
        $output = @($_.Exception.Message)
        $exitCode = 1
    }

    $stdout = Read-ValidationOutputFile -Path $stdoutPath
    $stderr = Read-ValidationOutputFile -Path $stderrPath
    $output = @($output + $stdout + $stderr)
    if ($timedOut) {
        $output = @("Timed out after $ChildTimeoutSeconds seconds; child process tree was stopped.") + $output
    }
    $finishedAt = (Get-Date).ToUniversalTime()

    Remove-Item -LiteralPath $stdoutPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue

    [void] $script:ValidationChildResults.Add([ordered]@{
        name = $Name
        startedAt = $startedAt.ToString("o")
        finishedAt = $finishedAt.ToString("o")
        durationSeconds = [int][Math]::Max(0, [Math]::Floor(($finishedAt - $startedAt).TotalSeconds))
        timedOut = $timedOut
        timeoutSeconds = $ChildTimeoutSeconds
        processId = $processId
        exitCode = [int] $exitCode
        outputLineCount = @($output).Count
    })

    return [ordered]@{
        exitCode = [int] $exitCode
        output = @($output)
        timedOut = $timedOut
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

function Get-ValidationSecretMarkerFindings {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string] $Label
    )

    $patterns = @(
        "privateKey",
        "private_key",
        "seedPhrase",
        "seed phrase",
        "mnemonic",
        "rpcUrl",
        "rpc-url",
        "apiKey",
        "webhook",
        "BEGIN RSA PRIVATE KEY",
        "BEGIN OPENSSH PRIVATE KEY"
    )

    $findings = New-Object System.Collections.ArrayList
    foreach ($pattern in $patterns) {
        if ($Text.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            [void] $findings.Add([ordered]@{
                label = $Label
                marker = $pattern
            })
        }
    }
    return @($findings)
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
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $BackupRootPath,
        [Parameter(Mandatory = $true)][string] $RestoreRootPath,
        [Parameter(Mandatory = $true)][string] $ReportPath
    )

    return Invoke-ValidationChild -Name $Name -ArgumentList @(
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

$backupResult = Invoke-ValidationChild -Name "backup" -ArgumentList @(
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

$restoreResult = Invoke-ValidationChild -Name "restore" -ArgumentList @(
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

$secondBackupResult = [ordered]@{ exitCode = 1; output = @("not-run"); timedOut = $false }
$latestRestoreResult = [ordered]@{ exitCode = 1; output = @("not-run"); timedOut = $false }
$secondBackupReport = $null
$latestRestoreReport = $null
$latestManifestMatchesSecondSnapshot = $false
$latestRestoreUsedLatestSnapshot = $false
$firstSnapshotName = ""
$secondSnapshotName = ""
if ($backupResult.exitCode -eq 0 -and $null -ne $backupReport -and "$($backupReport.status)" -eq "passed") {
    $firstSnapshotName = Get-FlowChainJsonString -Object $backupReport.snapshot -Names @("snapshotName")
    Start-Sleep -Milliseconds 20
    $secondBackupResult = Invoke-ValidationChild -Name "second-backup" -ArgumentList @(
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

        $latestRestoreResult = Invoke-ValidationRestore -Name "latest-restore" -BackupRootPath $backupRoot -RestoreRootPath $latestRestoreRoot -ReportPath $latestRestoreReportPath
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
    $corruptResult = Invoke-ValidationRestore -Name "corrupt-restore" -BackupRootPath $corruptRoot -RestoreRootPath (Join-Path $validationRoot "corrupt-restore-root") -ReportPath $corruptRestoreReportPath
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
    [void](Invoke-ValidationRestore -Name "tampered-manifest-restore" -BackupRootPath $tamperedRoot -RestoreRootPath (Join-Path $validationRoot "tampered-restore-root") -ReportPath $tamperedRestoreReportPath)
    $tamperedManifestDetected = Test-ValidationRestoreFailed -ReportPath $tamperedRestoreReportPath

    Copy-ValidationBackupRoot -Destination $missingArtifactRoot
    $missingStatePath = Join-Path (Join-Path $missingArtifactRoot $selectedSnapshotName) "state.json"
    if (Test-Path -LiteralPath $missingStatePath) {
        Remove-Item -LiteralPath $missingStatePath -Force
    }
    [void](Invoke-ValidationRestore -Name "missing-artifact-restore" -BackupRootPath $missingArtifactRoot -RestoreRootPath (Join-Path $validationRoot "missing-artifact-restore-root") -ReportPath $missingArtifactRestoreReportPath)
    $missingStateArtifactDetected = Test-ValidationRestoreFailed -ReportPath $missingArtifactRestoreReportPath

    Copy-ValidationBackupRoot -Destination $missingSnapshotManifestRoot
    $missingSnapshotManifestPath = Join-Path (Join-Path $missingSnapshotManifestRoot $selectedSnapshotName) "manifest.json"
    if (Test-Path -LiteralPath $missingSnapshotManifestPath) {
        Remove-Item -LiteralPath $missingSnapshotManifestPath -Force
    }
    [void](Invoke-ValidationRestore -Name "missing-snapshot-manifest-restore" -BackupRootPath $missingSnapshotManifestRoot -RestoreRootPath (Join-Path $validationRoot "missing-snapshot-manifest-restore-root") -ReportPath $missingSnapshotManifestRestoreReportPath)
    $missingSnapshotManifestDetected = Test-ValidationRestoreFailed -ReportPath $missingSnapshotManifestRestoreReportPath

    if (-not [string]::IsNullOrWhiteSpace($firstSnapshotName) -and -not [string]::IsNullOrWhiteSpace($secondSnapshotName) -and $firstSnapshotName -ne $secondSnapshotName) {
        Copy-ValidationBackupRoot -Destination $latestPointerTamperRoot
        Copy-Item -LiteralPath (Join-Path (Join-Path $latestPointerTamperRoot $firstSnapshotName) "manifest.json") -Destination (Join-Path $latestPointerTamperRoot "latest-manifest.json") -Force
        [void](Invoke-ValidationRestore -Name "latest-pointer-tamper-restore" -BackupRootPath $latestPointerTamperRoot -RestoreRootPath (Join-Path $validationRoot "latest-pointer-tamper-restore-root") -ReportPath $latestPointerTamperRestoreReportPath)
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
    [void](Invoke-ValidationRestore -Name "wrong-chain-state-mismatch-restore" -BackupRootPath $wrongChainStateMismatchRoot -RestoreRootPath (Join-Path $validationRoot "wrong-chain-state-mismatch-restore-root") -ReportPath $wrongChainStateMismatchRestoreReportPath)
    $wrongChainStateMismatchDetected = Test-ValidationRestoreFailed -ReportPath $wrongChainStateMismatchRestoreReportPath
}

$retentionBackupResult = [ordered]@{ exitCode = 1; output = @("not-run"); timedOut = $false }
$retentionRestoreResult = [ordered]@{ exitCode = 1; output = @("not-run"); timedOut = $false }
$retentionBackupReport = $null
$retentionRestoreReport = $null
$retentionThirdSnapshotName = ""
$retentionRemainingSnapshotNames = @()
$retentionBackupPassed = $false
$retentionPrunedOldestSnapshot = $false
$retentionRetainedNewestSnapshots = $false
$retentionLatestManifestMatchesThirdSnapshot = $false
$retentionReportShowsPrunedSnapshot = $false
$retentionReportProtectsCurrentSnapshot = $false
$retentionRestorePassed = $false
$retentionRestoreUsedThirdSnapshot = $false
if (-not [string]::IsNullOrWhiteSpace($firstSnapshotName) -and -not [string]::IsNullOrWhiteSpace($secondSnapshotName) -and $firstSnapshotName -ne $secondSnapshotName) {
    Start-Sleep -Milliseconds 20
    $retentionBackupResult = Invoke-ValidationChild -Name "retention-backup" -ArgumentList @(
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
        $retentionBackupReportPath,
        "-CreateBackupRoot",
        "-RetentionCount",
        "2"
    )
    $retentionBackupReport = Read-FlowChainJsonIfExists -Path $retentionBackupReportPath
    $retentionBackupPassed = $retentionBackupResult.exitCode -eq 0 -and $null -ne $retentionBackupReport -and "$($retentionBackupReport.status)" -eq "passed"
    if ($retentionBackupPassed) {
        $retentionThirdSnapshotName = Get-FlowChainJsonString -Object $retentionBackupReport.snapshot -Names @("snapshotName")
        $retentionRemainingSnapshotNames = @(Get-ChildItem -LiteralPath $backupRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "flowchain-state-snapshot-*" } | ForEach-Object { $_.Name })
        $retentionPrunedOldestSnapshot = -not ($retentionRemainingSnapshotNames -contains $firstSnapshotName)
        $retentionRetainedNewestSnapshots = ($retentionRemainingSnapshotNames -contains $secondSnapshotName) -and ($retentionRemainingSnapshotNames -contains $retentionThirdSnapshotName) -and $retentionRemainingSnapshotNames.Count -eq 2
        $retentionLatestManifest = Read-FlowChainJsonIfExists -Path (Join-Path $backupRoot "latest-manifest.json")
        $retentionLatestManifestMatchesThirdSnapshot = (Get-FlowChainJsonString -Object $retentionLatestManifest -Names @("snapshotName")) -eq $retentionThirdSnapshotName
        $retentionReportShowsPrunedSnapshot = @($retentionBackupReport.retention.prunedSnapshotNames).Count -ge 1 -and @($retentionBackupReport.retention.prunedSnapshotNames) -contains $firstSnapshotName
        $retentionReportProtectsCurrentSnapshot = $retentionBackupReport.retention.currentSnapshotProtected -eq $true

        $retentionRestoreResult = Invoke-ValidationRestore -Name "retention-latest-restore" -BackupRootPath $backupRoot -RestoreRootPath (Join-Path $validationRoot "retention-restore-root") -ReportPath $retentionRestoreReportPath
        $retentionRestoreReport = Read-FlowChainJsonIfExists -Path $retentionRestoreReportPath
        $retentionRestorePassed = $retentionRestoreResult.exitCode -eq 0 -and $null -ne $retentionRestoreReport -and "$($retentionRestoreReport.status)" -eq "passed"
        $retentionRestoreUsedThirdSnapshot = $retentionRestorePassed -and (Get-FlowChainJsonString -Object $retentionRestoreReport.restore -Names @("snapshotName")) -eq $retentionThirdSnapshotName
    }
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

$retentionRotationProven = $retentionBackupPassed -and $retentionPrunedOldestSnapshot -and $retentionRetainedNewestSnapshots -and $retentionLatestManifestMatchesThirdSnapshot -and $retentionReportShowsPrunedSnapshot -and $retentionReportProtectsCurrentSnapshot -and $retentionRestorePassed -and $retentionRestoreUsedThirdSnapshot
$coreStatus = if ($backupPassed -and $restorePassed -and $hashRoundTrip -and $secondBackupPassed -and $latestManifestMatchesSecondSnapshot -and $latestRestorePassed -and $latestRestoreUsedLatestSnapshot -and $restoreTargetProtected -and $liveStateNonMutationProven -and $corruptionDetected -and $tamperedManifestDetected -and $missingStateArtifactDetected -and $missingSnapshotManifestDetected -and $latestPointerTamperDetected -and $wrongChainStateMismatchDetected -and $retentionRotationProven) { "passed" } else { "failed" }
$checks = [ordered]@{
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
    manifestTamperDetected = $tamperedManifestDetected
    missingStateArtifactDetected = $missingStateArtifactDetected
    missingSnapshotManifestDetected = $missingSnapshotManifestDetected
    latestPointerTamperDetected = $latestPointerTamperDetected
    wrongChainStateMismatchDetected = $wrongChainStateMismatchDetected
    retentionBackupCommandPassed = $retentionBackupPassed
    retentionPrunedOldestSnapshot = $retentionPrunedOldestSnapshot
    retentionRetainedNewestSnapshots = $retentionRetainedNewestSnapshots
    retentionLatestManifestMatchesNewest = $retentionLatestManifestMatchesThirdSnapshot
    retentionReportShowsPrunedSnapshot = $retentionReportShowsPrunedSnapshot
    retentionReportProtectsCurrentSnapshot = $retentionReportProtectsCurrentSnapshot
    retentionRestoreCommandPassed = $retentionRestorePassed
    retentionRestoreUsedNewestSnapshot = $retentionRestoreUsedThirdSnapshot
    valuesPrintedFalse = $true
    envValuesPrintedFalse = $true
    noSecrets = $true
    secretMarkerFindingsEmpty = $true
    broadcastsFalse = $true
}
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($coreStatus -eq "passed" -and $failedChecks.Count -eq 0) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.backup_restore_validation_report.v2"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    stateReadable = (Get-FlowChainStateFacts -StatePath $stateFullPath).readable
    corruptRestoreExitCode = $corruptExitCode
    checks = $checks
    failedChecks = @($failedChecks)
    secretMarkerFindings = @()
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
        retentionBackup = $retentionBackupReportPath
        retentionRestore = $retentionRestoreReportPath
    }
    requiredCommands = @(
        "npm run flowchain:backup:create",
        "npm run flowchain:backup:restore:verify"
    )
    childTimeoutSeconds = $ChildTimeoutSeconds
    childProcessResults = @($script:ValidationChildResults)
    valuesPrinted = $false
    broadcasts = $false
    envValuesPrinted = $false
    noSecrets = $true
}

$preliminaryReportText = $report | ConvertTo-Json -Depth 16
$secretMarkerFindings = @(
    Get-ValidationSecretMarkerFindings -Text $preliminaryReportText -Label "backup restore validation report"
)
$checks["secretMarkerFindingsEmpty"] = $secretMarkerFindings.Count -eq 0
$checks["noSecrets"] = $secretMarkerFindings.Count -eq 0
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($coreStatus -eq "passed" -and $failedChecks.Count -eq 0) { "passed" } else { "failed" }
$report["status"] = $status
$report["checks"] = $checks
$report["failedChecks"] = @($failedChecks)
$report["secretMarkerFindings"] = @($secretMarkerFindings)
$report["noSecrets"] = $secretMarkerFindings.Count -eq 0

$reportText = $report | ConvertTo-Json -Depth 16
Assert-FlowChainNoSecretText -Text $reportText -Label "backup restore validation report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

Write-Host "FlowChain backup/restore validation status: $status"
Write-Host "Report: $reportFullPath"
if ($status -ne "passed") {
    throw "FlowChain backup/restore validation failed. See report for artifact names."
}
