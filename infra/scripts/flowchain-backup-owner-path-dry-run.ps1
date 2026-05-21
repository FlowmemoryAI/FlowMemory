param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $DryRunRoot = "devnet/local/backup-owner-path-dry-run",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/backup-owner-path-dry-run-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/BACKUP_OWNER_PATH_DRY_RUN.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$dryRunFullRoot = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $DryRunRoot)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$childReportDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/backup-owner-path-dry-run")
$childReadinessReportPath = Join-Path $childReportDir "backup-readiness-report.json"
$childBackupReportPath = Join-Path $childReportDir "state-backup-report.json"
$childRestoreReportPath = Join-Path $childReportDir "state-restore-verify-report.json"

function Get-BackupDryRunProp {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name,
        [object] $Default = $null
    )

    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $Default
}

function ConvertTo-BackupDryRunSafeLine {
    param([AllowNull()][object] $Line)

    $text = "$Line"
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "https?://[^\s,)]+", "<redacted-url>")
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, "(?i)(FLOWCHAIN_[A-Z0-9_]+\s*[:=]\s*)([^\s,;]+)", '${1}<redacted>')
    return $text
}

function Get-BackupDryRunSecretMarkerFindings {
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

function Get-BackupDryRunFileSha256 {
    param([Parameter(Mandatory = $true)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    return ((Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash).ToLowerInvariant()
}

function Test-BackupDryRunPathUnder {
    param(
        [Parameter(Mandatory = $true)][string] $Parent,
        [Parameter(Mandatory = $true)][string] $Child
    )

    $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd("\", "/") + [System.IO.Path]::DirectorySeparatorChar
    $childFull = [System.IO.Path]::GetFullPath($Child)
    return $childFull.StartsWith($parentFull, [System.StringComparison]::OrdinalIgnoreCase)
}

$dryRunParent = Split-Path -Parent $dryRunFullRoot
if (-not (Test-BackupDryRunPathUnder -Parent (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local") -Child $dryRunFullRoot)) {
    throw "DryRunRoot must stay under devnet/local."
}
New-Item -ItemType Directory -Force -Path $dryRunParent | Out-Null
Reset-FlowChainDirectory -Path $dryRunFullRoot | Out-Null
New-Item -ItemType Directory -Force -Path $childReportDir | Out-Null

$backupRoot = Join-Path $dryRunFullRoot "owner-path"
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
$dryRunOwnerEnvFile = Join-Path $dryRunFullRoot "flowchain-backup-dry-run.owner.env"
Set-Content -LiteralPath $dryRunOwnerEnvFile -Value "FLOWCHAIN_RPC_STATE_BACKUP_PATH=$backupRoot" -Encoding UTF8
$stateHashBefore = Get-BackupDryRunFileSha256 -Path $stateFullPath
$hadPreviousBackupEnv = Test-Path Env:\FLOWCHAIN_RPC_STATE_BACKUP_PATH
$previousBackupEnv = $env:FLOWCHAIN_RPC_STATE_BACKUP_PATH
$hadPreviousOwnerEnvFile = Test-Path Env:\FLOWCHAIN_OWNER_ENV_FILE
$previousOwnerEnvFile = $env:FLOWCHAIN_OWNER_ENV_FILE
$childOutput = @()
$childExitCode = 1
try {
    $env:FLOWCHAIN_RPC_STATE_BACKUP_PATH = $backupRoot
    $env:FLOWCHAIN_OWNER_ENV_FILE = $dryRunOwnerEnvFile
    $childOutput = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-public-rpc-backup-readiness.ps1") `
        -StatePath $stateFullPath `
        -ReportPath $childReadinessReportPath 2>&1) | ForEach-Object { ConvertTo-BackupDryRunSafeLine -Line $_ }
    $childExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
}
finally {
    if ($hadPreviousBackupEnv) {
        $env:FLOWCHAIN_RPC_STATE_BACKUP_PATH = $previousBackupEnv
    }
    else {
        Remove-Item Env:\FLOWCHAIN_RPC_STATE_BACKUP_PATH -ErrorAction SilentlyContinue
    }
    if ($hadPreviousOwnerEnvFile) {
        $env:FLOWCHAIN_OWNER_ENV_FILE = $previousOwnerEnvFile
    }
    else {
        Remove-Item Env:\FLOWCHAIN_OWNER_ENV_FILE -ErrorAction SilentlyContinue
    }
}
$stateHashAfter = Get-BackupDryRunFileSha256 -Path $stateFullPath
$ownerEnvRestored = if ($hadPreviousBackupEnv) {
    $env:FLOWCHAIN_RPC_STATE_BACKUP_PATH -eq $previousBackupEnv
}
else {
    -not (Test-Path Env:\FLOWCHAIN_RPC_STATE_BACKUP_PATH)
}
$ownerEnvFileRestored = if ($hadPreviousOwnerEnvFile) {
    $env:FLOWCHAIN_OWNER_ENV_FILE -eq $previousOwnerEnvFile
}
else {
    -not (Test-Path Env:\FLOWCHAIN_OWNER_ENV_FILE)
}

$readinessReport = Read-FlowChainJsonIfExists -Path $childReadinessReportPath
$backupReport = Read-FlowChainJsonIfExists -Path $childBackupReportPath
$restoreReport = Read-FlowChainJsonIfExists -Path $childRestoreReportPath
$readinessBackup = Get-BackupDryRunProp -Object $readinessReport -Name "backup"
$backupSnapshot = Get-BackupDryRunProp -Object $backupReport -Name "snapshot"
$restore = Get-BackupDryRunProp -Object $restoreReport -Name "restore"

$checks = [ordered]@{
    dryRunRootInsideIgnoredLocalState = Test-BackupDryRunPathUnder -Parent (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local") -Child $dryRunFullRoot
    ownerBackupEnvRestored = $ownerEnvRestored
    ownerEnvFileRestored = $ownerEnvFileRestored
    childReadinessCommandPassed = [int]$childExitCode -eq 0
    readinessReportWritten = $null -ne $readinessReport
    readinessStatusPassed = [string](Get-BackupDryRunProp -Object $readinessReport -Name "status" -Default "missing") -eq "passed"
    backupRootConfigured = (Get-BackupDryRunProp -Object $readinessBackup -Name "configured" -Default $false) -eq $true
    backupRootValuePrintedFalse = (Get-BackupDryRunProp -Object $readinessBackup -Name "pathValuePrinted" -Default $true) -eq $false
    snapshotProofPassed = [string](Get-BackupDryRunProp -Object $readinessBackup -Name "snapshotProofStatus" -Default "missing") -eq "passed"
    restoreProofPassed = [string](Get-BackupDryRunProp -Object $readinessBackup -Name "restoreProofStatus" -Default "missing") -eq "passed"
    writeVerified = (Get-BackupDryRunProp -Object $readinessBackup -Name "writeVerified" -Default $false) -eq $true
    latestPointerVerified = (Get-BackupDryRunProp -Object $readinessBackup -Name "latestPointerVerified" -Default $false) -eq $true
    latestPointerWrittenAtomically = (Get-BackupDryRunProp -Object $readinessBackup -Name "latestPointerWrittenAtomically" -Default $false) -eq $true
    retentionCurrentSnapshotProtected = (Get-BackupDryRunProp -Object $readinessBackup -Name "retentionCurrentSnapshotProtected" -Default $false) -eq $true
    retentionPruneErrorsEmpty = [int](Get-BackupDryRunProp -Object $readinessBackup -Name "retentionPruneErrorCount" -Default 1) -eq 0
    stateRootCompared = (Get-BackupDryRunProp -Object $readinessBackup -Name "stateRootCompared" -Default $false) -eq $true
    stateRootMatch = (Get-BackupDryRunProp -Object $readinessBackup -Name "stateRootMatch" -Default $false) -eq $true
    stateFileHashMatch = (Get-BackupDryRunProp -Object $readinessBackup -Name "stateFileHashMatch" -Default $false) -eq $true
    restoreVerified = (Get-BackupDryRunProp -Object $readinessBackup -Name "restoreVerified" -Default $false) -eq $true
    backupReportPassed = [string](Get-BackupDryRunProp -Object $backupReport -Name "status" -Default "missing") -eq "passed"
    restoreReportPassed = [string](Get-BackupDryRunProp -Object $restoreReport -Name "status" -Default "missing") -eq "passed"
    backupSnapshotCreated = (Get-BackupDryRunProp -Object $backupSnapshot -Name "created" -Default $false) -eq $true
    backupRetentionProtectedSnapshot = (Get-BackupDryRunProp -Object (Get-BackupDryRunProp -Object $backupReport -Name "retention") -Name "currentSnapshotProtected" -Default $false) -eq $true
    restoreLiveStateProtected = (Get-BackupDryRunProp -Object $restore -Name "liveStatePathProtected" -Default $false) -eq $true
    restoreDidNotMutateLiveState = (Get-BackupDryRunProp -Object $restore -Name "liveStateMutated" -Default $true) -eq $false
    liveStateStillReadable = (Get-FlowChainStateFacts -StatePath $stateFullPath).readable -eq $true
    envValuesPrintedFalse = (Get-BackupDryRunProp -Object $readinessReport -Name "envValuesPrinted" -Default $true) -eq $false `
        -and (Get-BackupDryRunProp -Object $backupReport -Name "envValuesPrinted" -Default $true) -eq $false `
        -and (Get-BackupDryRunProp -Object $restoreReport -Name "envValuesPrinted" -Default $true) -eq $false
    noSecrets = (Get-BackupDryRunProp -Object $readinessReport -Name "noSecrets" -Default $false) -eq $true `
        -and (Get-BackupDryRunProp -Object $backupReport -Name "noSecrets" -Default $false) -eq $true `
        -and (Get-BackupDryRunProp -Object $restoreReport -Name "noSecrets" -Default $false) -eq $true
    secretMarkerFindingsEmpty = $true
    broadcastsFalse = (Get-BackupDryRunProp -Object $backupReport -Name "broadcasts" -Default $false) -eq $false `
        -and (Get-BackupDryRunProp -Object $restoreReport -Name "broadcasts" -Default $false) -eq $false
}

$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.backup_owner_path_dry_run_report.v1"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    dryRunScope = "ignored-local-owner-path-rehearsal"
    dryRunRoot = $dryRunFullRoot
    backupRootValuePrinted = $false
    childReadinessStatus = [string](Get-BackupDryRunProp -Object $readinessReport -Name "status" -Default "missing")
    childReadinessExitCode = [int]$childExitCode
    failedChecks = @($failedChecks)
    secretMarkerFindings = @()
    checks = $checks
    proofReports = [ordered]@{
        readiness = $childReadinessReportPath
        backup = $childBackupReportPath
        restore = $childRestoreReportPath
    }
    childOutputRedacted = @($childOutput | Select-Object -Last 30)
    liveStateSha256Before = $stateHashBefore
    liveStateSha256After = $stateHashAfter
    requiredOwnerInput = "FLOWCHAIN_RPC_STATE_BACKUP_PATH"
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$preliminaryReportText = $report | ConvertTo-Json -Depth 18
$secretMarkerFindings = @(
    Get-BackupDryRunSecretMarkerFindings -Text $preliminaryReportText -Label "backup owner path dry-run report"
)
$checks["secretMarkerFindingsEmpty"] = $secretMarkerFindings.Count -eq 0
$checks["noSecrets"] = $secretMarkerFindings.Count -eq 0
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }
$report["status"] = $status
$report["failedChecks"] = @($failedChecks)
$report["secretMarkerFindings"] = @($secretMarkerFindings)
$report["checks"] = $checks
$report["noSecrets"] = $secretMarkerFindings.Count -eq 0

$reportText = $report | ConvertTo-Json -Depth 18
Assert-FlowChainNoSecretText -Text $reportText -Label "backup owner path dry-run report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 18

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Backup Owner Path Dry Run")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This dry run sets `FLOWCHAIN_RPC_STATE_BACKUP_PATH` to an ignored local directory and runs the same backup readiness gate used for production. It does not use or record the owner's real backup path.")
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("- $($entry.Key): $($entry.Value)")
}
if ($failedChecks.Count -gt 0) {
    $markdownLines.Add("")
    $markdownLines.Add("## Failed Checks")
    $markdownLines.Add("")
    foreach ($name in $failedChecks) {
        $markdownLines.Add("- $name")
    }
}

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "backup owner path dry-run markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain backup owner path dry-run status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    Write-Host "Failed checks: $($failedChecks -join ', ')"
    exit 1
}
exit 0
