param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node",
    [string] $NodeId = "node:local:live-pilot",
    [int] $BlockMs = 1000,
    [int] $MaxBlocks = 0,
    [string] $PeerConfig = "",
    [string] $OutDir = "devnet/local/live-l1-bridge-intake"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

function Test-FlowChainPidRunning {
    param([object] $Status)

    if ($null -eq $Status -or $null -eq $Status.pid) {
        return $false
    }

    try {
        $process = Get-Process -Id ([int] $Status.pid) -ErrorAction Stop
        return $null -ne $process
    }
    catch {
        return $false
    }
}

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot -Purpose "live-node" | Out-Null
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$nodeFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $NodeDir)
$outFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $OutDir)

New-Item -ItemType Directory -Force -Path $nodeFullDir | Out-Null
New-Item -ItemType Directory -Force -Path $outFullDir | Out-Null

$statusPath = Join-Path $nodeFullDir "status.json"
if (Test-Path -LiteralPath $statusPath) {
    $existingStatus = Get-Content -Raw -LiteralPath $statusPath | ConvertFrom-Json
    if ($existingStatus.status -eq "running" -and (Test-FlowChainPidRunning -Status $existingStatus)) {
        $report = [ordered]@{
            schema = "flowchain.live_l1.node_start.v0"
            generatedAt = (Get-Date).ToUniversalTime().ToString("o")
            reusedRunningNode = $true
            status = $existingStatus
            statePath = $stateFullPath
            nodeDir = $nodeFullDir
        }
        Write-FlowChainJson -Path (Join-Path $outFullDir "node-start-report.json") -Value $report
        $report | ConvertTo-Json -Depth 20
        exit 0
    }
}

$stopPath = Join-Path $nodeFullDir "stop"
if (Test-Path -LiteralPath $stopPath) {
    Remove-Item -LiteralPath $stopPath -Force
}

$stdoutPath = Join-Path $nodeFullDir "node.stdout.jsonl"
$stderrPath = Join-Path $nodeFullDir "node.stderr.log"

$arguments = @(
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    $stateFullPath,
    "--node-dir",
    $nodeFullDir,
    "node",
    "--node-id",
    $NodeId,
    "--block-ms",
    "$BlockMs"
)

if ($MaxBlocks -gt 0) {
    $arguments += @("--max-blocks", "$MaxBlocks")
}

if (-not [string]::IsNullOrWhiteSpace($PeerConfig)) {
    $peerConfigFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $PeerConfig)
    $arguments += @("--peer-config", $peerConfigFullPath)
}

$process = Start-Process -FilePath "cargo" -ArgumentList (Join-FlowChainProcessArguments -ArgumentList $arguments) -WorkingDirectory $repoRoot -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath

$deadline = (Get-Date).AddSeconds(30)
$status = $null
while ((Get-Date) -lt $deadline) {
    if (Test-Path -LiteralPath $statusPath) {
        try {
            $status = Get-Content -Raw -LiteralPath $statusPath | ConvertFrom-Json
            if ($status.status -eq "running" -and [int] $status.pid -eq $process.Id) {
                break
            }
        }
        catch {
        }
    }
    Start-Sleep -Milliseconds 250
}

if ($null -eq $status -or $status.status -ne "running") {
    if (-not $process.HasExited) {
        $process.Kill()
    }
    throw "FlowChain node did not report running within 30 seconds. See $stderrPath"
}

$report = [ordered]@{
    schema = "flowchain.live_l1.node_start.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    reusedRunningNode = $false
    processId = $process.Id
    statePath = $stateFullPath
    nodeDir = $nodeFullDir
    stdout = $stdoutPath
    stderr = $stderrPath
    unbounded = ($MaxBlocks -le 0)
    status = $status
}

Write-FlowChainJson -Path (Join-Path $outFullDir "node-start-report.json") -Value $report
$report | ConvertTo-Json -Depth 20
