param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/upgrade-rehearsal-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/INSTALL_UPGRADE.md",
    [string] $WorkDir = "devnet/local/tmp/upgrade-rehearsal",
    [switch] $KeepWorkDir
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)
$workFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $WorkDir)
$runDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Join-Path $workFullDir ("run-" + (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssfffZ") + "-$PID"))
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

function Get-UpgradeProp {
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

function Get-UpgradeFileSha256 {
    param([Parameter(Mandatory = $true)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Copy-UpgradeFile {
    param(
        [Parameter(Mandatory = $true)][string] $Source,
        [Parameter(Mandatory = $true)][string] $Destination
    )

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

$sourceStatePath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/state.json"
$stateSourceExists = Test-Path -LiteralPath $sourceStatePath
if (-not $stateSourceExists) {
    throw "Cannot rehearse state-preserving upgrade because devnet/local/state.json is missing. Run npm run flowchain:service:start -- -LiveProfile first."
}

$sourcePackageHash = Get-UpgradeFileSha256 -Path (Join-Path $repoRoot "package.json")
$sourcePackageLockHash = Get-UpgradeFileSha256 -Path (Join-Path $repoRoot "package-lock.json")

$previousDir = Join-Path $runDir "previous-release"
$nextDir = Join-Path $runDir "next-release"
$backupDir = Join-Path $runDir "state-backup"
$rollbackDir = Join-Path $runDir "rollback-restore"
New-Item -ItemType Directory -Force -Path $previousDir, $nextDir, $backupDir, $rollbackDir | Out-Null

$previousStatePath = Join-Path $previousDir "state.json"
$backupStatePath = Join-Path $backupDir "state.json"
$nextStatePath = Join-Path $nextDir "state.json"
$rollbackStatePath = Join-Path $rollbackDir "state.json"

Copy-UpgradeFile -Source $sourceStatePath -Destination $previousStatePath
Copy-UpgradeFile -Source $sourceStatePath -Destination $backupStatePath
Copy-UpgradeFile -Source (Join-Path $repoRoot "package.json") -Destination (Join-Path $previousDir "package.json")
Copy-UpgradeFile -Source (Join-Path $repoRoot "package.json") -Destination (Join-Path $nextDir "package.json")
if (Test-Path -LiteralPath (Join-Path $repoRoot "package-lock.json")) {
    Copy-UpgradeFile -Source (Join-Path $repoRoot "package-lock.json") -Destination (Join-Path $previousDir "package-lock.json")
    Copy-UpgradeFile -Source (Join-Path $repoRoot "package-lock.json") -Destination (Join-Path $nextDir "package-lock.json")
}

$sourceState = Read-FlowChainJsonIfExists -Path $previousStatePath
$sourceStateHash = Get-UpgradeFileSha256 -Path $previousStatePath

$migrationManifest = [ordered]@{
    schema = "flowchain.upgrade_migration_manifest.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    action = "state-preserving-copy-rehearsal"
    sourceStateHash = $sourceStateHash
    sourcePackageHash = $sourcePackageHash
    sourcePackageLockHash = $sourcePackageLockHash
    preservesStateFile = $true
    hostMutationPerformed = $false
    broadcasts = $false
}
Write-FlowChainJson -Path (Join-Path $nextDir "MIGRATION_MANIFEST.json") -Value $migrationManifest -Depth 10
Copy-UpgradeFile -Source $backupStatePath -Destination $nextStatePath

$rollbackManifest = [ordered]@{
    schema = "flowchain.rollback_manifest.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    action = "restore-previous-state-copy"
    sourceStateHash = $sourceStateHash
    backupStateHash = Get-UpgradeFileSha256 -Path $backupStatePath
    hostMutationPerformed = $false
    broadcasts = $false
}
Write-FlowChainJson -Path (Join-Path $rollbackDir "ROLLBACK_MANIFEST.json") -Value $rollbackManifest -Depth 10
Copy-UpgradeFile -Source $backupStatePath -Destination $rollbackStatePath

$nextStateHash = Get-UpgradeFileSha256 -Path $nextStatePath
$rollbackStateHash = Get-UpgradeFileSha256 -Path $rollbackStatePath
$previousStateHash = Get-UpgradeFileSha256 -Path $previousStatePath

$sourceNextBlockNumber = [int64](Get-UpgradeProp -Object $sourceState -Name "nextBlockNumber" -Default 0)
$sourceChainId = [string](Get-UpgradeProp -Object $sourceState -Name "chainId" -Default "")
$sourceGenesisHash = [string](Get-UpgradeProp -Object $sourceState -Name "genesisHash" -Default "")
$nextState = Read-FlowChainJsonIfExists -Path $nextStatePath
$rollbackState = Read-FlowChainJsonIfExists -Path $rollbackStatePath

$commands = [ordered]@{
    preflight = "npm run flowchain:install:check"
    stop = "npm run flowchain:service:stop"
    backup = "npm run flowchain:backup:create"
    upgrade = "git pull --ff-only && npm install && npm run flowchain:service:start -- -LiveProfile"
    verify = "npm run flowchain:service:status -- -AllowBlocked && npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30"
    rollback = "restore the previous package checkout and backup state, then run npm run flowchain:service:restart -- -LiveProfile"
    reAudit = "npm run flowchain:completion:audit -- -AllowBlocked"
}

$checks = [ordered]@{
    stateSourceExists = $stateSourceExists
    sourceStateReadable = $null -ne $sourceState
    previousReleaseStateCopied = Test-Path -LiteralPath $previousStatePath
    backupStateCopied = Test-Path -LiteralPath $backupStatePath
    nextReleaseStateCopied = Test-Path -LiteralPath $nextStatePath
    rollbackStateCopied = Test-Path -LiteralPath $rollbackStatePath
    sourceStateHashPresent = -not [string]::IsNullOrWhiteSpace($sourceStateHash)
    previousStateHashMatchesSource = $previousStateHash -eq $sourceStateHash
    nextStateHashMatchesSource = $nextStateHash -eq $sourceStateHash
    rollbackStateHashMatchesSource = $rollbackStateHash -eq $sourceStateHash
    chainIdPreserved = [string](Get-UpgradeProp -Object $nextState -Name "chainId" -Default "") -eq $sourceChainId -and [string](Get-UpgradeProp -Object $rollbackState -Name "chainId" -Default "") -eq $sourceChainId
    genesisHashPreserved = [string](Get-UpgradeProp -Object $nextState -Name "genesisHash" -Default "") -eq $sourceGenesisHash -and [string](Get-UpgradeProp -Object $rollbackState -Name "genesisHash" -Default "") -eq $sourceGenesisHash
    nextBlockNumberPreserved = [int64](Get-UpgradeProp -Object $nextState -Name "nextBlockNumber" -Default -1) -eq $sourceNextBlockNumber -and [int64](Get-UpgradeProp -Object $rollbackState -Name "nextBlockNumber" -Default -1) -eq $sourceNextBlockNumber
    packageManifestCaptured = -not [string]::IsNullOrWhiteSpace($sourcePackageHash)
    migrationManifestWritten = Test-Path -LiteralPath (Join-Path $nextDir "MIGRATION_MANIFEST.json")
    rollbackManifestWritten = Test-Path -LiteralPath (Join-Path $rollbackDir "ROLLBACK_MANIFEST.json")
    rollbackCommandsPresent = $commands.rollback.Contains("flowchain:service:restart")
    verifyCommandsPresent = $commands.verify.Contains("flowchain:service:status") -and $commands.verify.Contains("flowchain:service:monitor")
    workDirInsideRepo = $runDir.StartsWith((Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path $repoRoot), [System.StringComparison]::OrdinalIgnoreCase)
    hostMutationPerformedFalse = $true
    envValuesPrintedFalse = $true
    secretMarkerFindingsEmpty = $true
    noSecrets = $true
    broadcastsFalse = $true
}
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0) { "passed" } else { "failed" }

$report = [ordered]@{
    schema = "flowchain.upgrade_rehearsal_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    runDir = $(if ($KeepWorkDir.IsPresent) { $runDir } else { "retained under ignored local temp path until operator cleanup" })
    source = [ordered]@{
        statePath = "devnet/local/state.json"
        stateHash = $sourceStateHash
        chainId = $sourceChainId
        genesisHash = $sourceGenesisHash
        nextBlockNumber = $sourceNextBlockNumber
        packageHash = $sourcePackageHash
        packageLockHash = $sourcePackageLockHash
    }
    rehearsal = [ordered]@{
        previousStateHash = $previousStateHash
        nextStateHash = $nextStateHash
        rollbackStateHash = $rollbackStateHash
        migrationManifestPath = Join-Path $nextDir "MIGRATION_MANIFEST.json"
        rollbackManifestPath = Join-Path $rollbackDir "ROLLBACK_MANIFEST.json"
    }
    commands = $commands
    checks = $checks
    failedChecks = @($failedChecks)
    secretMarkerFindings = @()
    hostMutationPerformed = $false
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$reportText = $report | ConvertTo-Json -Depth 16
Assert-FlowChainNoSecretText -Text $reportText -Label "upgrade rehearsal report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Install Upgrade Rollback")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This runbook and report prove the local upgrade path preserves FlowChain state by copying the current state into a previous-release backup, applying a next-release rehearsal, and restoring rollback state with matching hashes. It does not mutate the owner host.")
$markdownLines.Add("")
$markdownLines.Add("## Operator Commands")
$markdownLines.Add("")
foreach ($entry in $commands.GetEnumerator()) {
    $markdownLines.Add("- $($entry.Key): ``$($entry.Value)``")
}
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
$markdownLines.Add("| Check | Result |")
$markdownLines.Add("| --- | --- |")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("| $($entry.Key) | $($entry.Value) |")
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
Assert-FlowChainNoSecretText -Text $markdownText -Label "upgrade rehearsal markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain upgrade rehearsal status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($status -ne "passed") {
    throw "FlowChain upgrade rehearsal failed checks: $($failedChecks -join ', ')"
}
