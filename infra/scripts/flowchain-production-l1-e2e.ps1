param(
    [string] $ReportDir = "devnet/local/production-l1-e2e"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot -Purpose "production-l1-e2e" | Out-Null
$reportFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportDir)
$logsDir = Join-Path $reportFullDir "logs"
$reportPath = Join-Path $reportFullDir "flowchain-production-l1-e2e-report.json"

if (Test-Path -LiteralPath $reportFullDir) {
    Remove-Item -LiteralPath $reportFullDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

$steps = New-Object System.Collections.ArrayList

function Get-SafeStepName {
    param([string] $Name)
    return (($Name -replace '[^A-Za-z0-9_.-]', '-') -replace '-+', '-').Trim("-")
}

function Invoke-ProductionL1Step {
    param(
        [string] $Name,
        [string] $Command,
        [string] $FilePath,
        [string[]] $ArgumentList = @()
    )

    $safeName = Get-SafeStepName -Name $Name
    $logPath = Join-Path $logsDir "$safeName.log"
    $startedAt = (Get-Date).ToUniversalTime().ToString("o")
    Write-Host ""
    Write-Host "== $Name =="
    Write-Host $Command

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = (& $FilePath @ArgumentList 2>&1) | ForEach-Object { "$_" }
        $exitCode = $LASTEXITCODE
    }
    catch {
        $output = @($_.Exception.Message)
        $exitCode = 1
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $output | Set-Content -LiteralPath $logPath -Encoding utf8
    $status = if ($exitCode -eq 0) { "passed" } else { "failed" }
    [void] $steps.Add([ordered]@{
        name = $Name
        command = $Command
        status = $status
        exitCode = $exitCode
        logPath = $logPath
        startedAt = $startedAt
        endedAt = (Get-Date).ToUniversalTime().ToString("o")
        reason = if ($exitCode -eq 0) { "" } else { (($output | Select-Object -Last 12) -join [Environment]::NewLine) }
    })
    if ($exitCode -ne 0) {
        Write-Host "FAILED: $Name"
    }
    else {
        Write-Host "PASSED: $Name"
    }
}

Invoke-ProductionL1Step -Name "Devnet consensus tests" -Command "cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml" -FilePath "cargo" -ArgumentList @("test", "--manifest-path", "crates/flowmemory-devnet/Cargo.toml")
Invoke-ProductionL1Step -Name "Node start bounded" -Command "npm run flowchain:node:start -- -MaxBlocks 3 -Wait" -FilePath "npm" -ArgumentList @("run", "flowchain:node:start", "--", "-MaxBlocks", "3", "-Wait")
Invoke-ProductionL1Step -Name "Node status" -Command "npm run flowchain:node:status" -FilePath "npm" -ArgumentList @("run", "flowchain:node:status")
Invoke-ProductionL1Step -Name "Live L1 consensus readiness" -Command "npm run flowchain:consensus:live-l1:verify" -FilePath "npm" -ArgumentList @("run", "flowchain:consensus:live-l1:verify")
Invoke-ProductionL1Step -Name "Bridge local credit handoff" -Command "npm run bridge:local-credit:smoke" -FilePath "npm" -ArgumentList @("run", "bridge:local-credit:smoke")
Invoke-ProductionL1Step -Name "No-secret scan" -Command "npm run flowchain:no-secret:scan" -FilePath "npm" -ArgumentList @("run", "flowchain:no-secret:scan")
Invoke-ProductionL1Step -Name "Patch whitespace check" -Command "git diff --check" -FilePath "git" -ArgumentList @("diff", "--check")

$failed = @($steps | Where-Object { $_.status -ne "passed" })
$overall = if ($failed.Count -eq 0) { "passed-with-public-l1-blocked" } else { "failed" }
$liveReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/live-l1-consensus/consensus-finality-report.json"
$bridgeEvidencePath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "devnet/local/live-l1-consensus/bridge-lifecycle-evidence.json"

$report = [ordered]@{
    schema = "flowchain.production_l1.e2e_report.v0"
    timestamp = (Get-Date).ToUniversalTime().ToString("o")
    status = $overall
    publicL1Status = "blocked-single-process-private-local"
    privateLivePilotStatus = if ($failed.Count -eq 0) { "passed" } else { "failed" }
    reportDir = $reportFullDir
    liveConsensusReport = $liveReportPath
    bridgeLifecycleEvidence = $bridgeEvidencePath
    steps = @($steps)
    productionBoundary = @(
        "single-process private/local authority set",
        "no public L1 finality claim",
        "no public validator readiness claim",
        "no production bridge security claim"
    )
}
Write-FlowChainJson -Path $reportPath -Value $report -Depth 16

Write-Host ""
Write-Host "FlowChain production-l1:e2e status: $overall"
Write-Host "Report: $reportPath"
Write-Host "Live consensus report: $liveReportPath"
if ($failed.Count -gt 0) {
    throw "FlowChain production-l1:e2e failed. See $reportPath"
}
