param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node",
    [string] $NodeId = "node:local:alpha",
    [int] $BlockMs = 1000,
    [int] $MaxBlocks = 0,
    [switch] $Wait
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
Set-FlowChainCargoTargetDir -RepoRoot $repoRoot -Purpose "node-start" | Out-Null
$stateFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $StatePath)
$nodeFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $NodeDir)
$logsDir = Join-Path $nodeFullDir "logs"
$reportPath = Join-Path $nodeFullDir "flowchain-node-start-report.json"
$stdoutPath = Join-Path $logsDir "node.stdout.jsonl"
$stderrPath = Join-Path $logsDir "node.stderr.log"
$pidPath = Join-Path $nodeFullDir "flowchain-node.pid"

New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

if (-not (Test-Path -LiteralPath $stateFullPath)) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-init.ps1") -StatePath $stateFullPath
    if ($LASTEXITCODE -ne 0) {
        throw "flowchain-init failed before node start."
    }
}

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

if ($Wait) {
    $startedAt = (Get-Date).ToUniversalTime().ToString("o")
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = (& cargo @arguments 2>&1) | ForEach-Object { "$_" }
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $output | Set-Content -LiteralPath $stdoutPath -Encoding utf8
    "" | Set-Content -LiteralPath $stderrPath -Encoding utf8
    $status = if ($exitCode -eq 0) { "completed" } else { "failed" }
    $report = [ordered]@{
        schema = "flowchain.private_testnet.node_start_report.v0"
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        startedAt = $startedAt
        status = $status
        pid = $PID
        exitCode = $exitCode
        statePath = $stateFullPath
        nodeDir = $nodeFullDir
        nodeId = $NodeId
        blockMs = $BlockMs
        maxBlocks = $MaxBlocks
        waited = $true
        stdoutLog = $stdoutPath
        stderrLog = $stderrPath
        statusCommand = "npm run flowchain:node:status"
    }
    Write-FlowChainJson -Path $reportPath -Value $report -Depth 12
    if ($exitCode -ne 0) {
        throw "FlowChain node start failed. See $stdoutPath"
    }
    Write-Host "FlowChain node completed bounded run."
    Write-Host "Report: $reportPath"
    return
}

$cargoPath = (Get-Command "cargo" -ErrorAction Stop).Source
$process = Start-Process -FilePath $cargoPath `
    -ArgumentList (Join-FlowChainProcessArguments -ArgumentList $arguments) `
    -WorkingDirectory $repoRoot `
    -PassThru `
    -WindowStyle Hidden `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError $stderrPath

Set-Content -LiteralPath $pidPath -Value "$($process.Id)"
$report = [ordered]@{
    schema = "flowchain.private_testnet.node_start_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "started"
    pid = $process.Id
    exitCode = $null
    statePath = $stateFullPath
    nodeDir = $nodeFullDir
    nodeId = $NodeId
    blockMs = $BlockMs
    maxBlocks = $MaxBlocks
    waited = $false
    stdoutLog = $stdoutPath
    stderrLog = $stderrPath
    pidPath = $pidPath
    stopCommand = "npm run flowchain:node:stop"
    statusCommand = "npm run flowchain:node:status"
}
Write-FlowChainJson -Path $reportPath -Value $report -Depth 12
Write-Host "FlowChain node started."
Write-Host "PID: $($process.Id)"
Write-Host "Status command: npm run flowchain:node:status"
