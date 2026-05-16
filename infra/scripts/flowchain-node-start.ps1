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
$pidPath = Join-Path $nodeFullDir "flowchain-node.pid"
$reportPath = Join-Path $nodeFullDir "flowchain-node-start-report.json"
$stdoutPath = Join-Path $logsDir "node.stdout.jsonl"
$stderrPath = Join-Path $logsDir "node.stderr.log"
$stopPath = Join-Path $nodeFullDir "stop"

New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

function Test-FlowChainNodePid {
    param([int] $ProcessId)

    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if (-not $process) {
        return $false
    }

    try {
        $commandLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId").CommandLine
        return ($commandLine -like "*flowmemory-devnet*" -or $commandLine -like "*cargo*")
    }
    catch {
        return $false
    }
}

if (-not (Test-Path -LiteralPath $stateFullPath)) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-init.ps1") -StatePath $stateFullPath
    if ($LASTEXITCODE -ne 0) {
        throw "flowchain-init failed before node start."
    }
}

if (Test-Path -LiteralPath $pidPath) {
    $existingPid = (Get-Content -Raw -LiteralPath $pidPath).Trim()
    if ($existingPid -match '^[0-9]+$') {
        if (Test-FlowChainNodePid -ProcessId ([int] $existingPid)) {
            if ($Wait -and $MaxBlocks -gt 0) {
                & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-node-stop.ps1") -StatePath $stateFullPath -NodeDir $nodeFullDir | Out-Null
                if (Test-FlowChainNodePid -ProcessId ([int] $existingPid)) {
                    throw "FlowChain bounded node proof could not stop existing node PID $existingPid."
                }
            }
            else {
                $report = [ordered]@{
                    schema = "flowchain.private_testnet.node_start_report.v0"
                    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
                    status = "already-running"
                    pid = [int] $existingPid
                    statePath = $stateFullPath
                    nodeDir = $nodeFullDir
                    stdoutLog = $stdoutPath
                    stderrLog = $stderrPath
                    stopCommand = "npm run flowchain:node:stop"
                    statusCommand = "npm run flowchain:node:status"
                }
                Write-FlowChainJson -Path $reportPath -Value $report
                Write-Host "FlowChain node is already running with PID $existingPid."
                Write-Host "Status command: npm run flowchain:node:status"
                return
            }
        }
    }
}

& cargo build --manifest-path crates/flowmemory-devnet/Cargo.toml
if ($LASTEXITCODE -ne 0) {
    throw "cargo build failed before node start."
}

$binaryName = if ($env:OS -eq "Windows_NT") { "flowmemory-devnet.exe" } else { "flowmemory-devnet" }
$binaryPath = Join-Path (Join-Path $env:CARGO_TARGET_DIR "debug") $binaryName
if (-not (Test-Path -LiteralPath $binaryPath)) {
    throw "Built FlowChain node binary was not found at $binaryPath."
}

$arguments = @(
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

if (Test-Path -LiteralPath $stopPath) {
    Remove-Item -LiteralPath $stopPath -Force
}

$process = Start-Process -FilePath $binaryPath `
    -ArgumentList (Join-FlowChainProcessArguments -ArgumentList $arguments) `
    -WorkingDirectory $repoRoot `
    -PassThru `
    -WindowStyle Hidden `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError $stderrPath

Set-Content -LiteralPath $pidPath -Value "$($process.Id)"
$status = "started"
$exitCode = $null

if ($Wait) {
    $timeoutMs = if ($MaxBlocks -gt 0) { [Math]::Max(120000, $MaxBlocks * $BlockMs * 30) } else { 120000 }
    if (-not $process.WaitForExit($timeoutMs)) {
        & cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state $stateFullPath --node-dir $nodeFullDir node-stop | Out-Null
        $process.Kill()
        throw "FlowChain node did not exit within ${timeoutMs}ms."
    }
    $process.Refresh()
    if ($process.HasExited) {
        $exitCode = $process.ExitCode
    }
    elseif ($MaxBlocks -gt 0 -and (Test-Path -LiteralPath $stdoutPath) -and ((Get-Content -Raw -LiteralPath $stdoutPath) -like "*max blocks reached*")) {
        $exitCode = 0
    }
    if ($null -ne $exitCode -and $exitCode -ne 0) {
        $status = "failed"
    }
    else {
        $status = "completed"
    }
}

$report = [ordered]@{
    schema = "flowchain.private_testnet.node_start_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    pid = $process.Id
    exitCode = $exitCode
    statePath = $stateFullPath
    nodeDir = $nodeFullDir
    nodeId = $NodeId
    blockMs = $BlockMs
    maxBlocks = $MaxBlocks
    waited = [bool] $Wait
    stdoutLog = $stdoutPath
    stderrLog = $stderrPath
    pidPath = $pidPath
    stopCommand = "npm run flowchain:node:stop"
    statusCommand = "npm run flowchain:node:status"
    logsCommand = "npm run flowchain:node:logs"
}
Write-FlowChainJson -Path $reportPath -Value $report -Depth 12

if ($status -eq "failed") {
    throw "FlowChain node exited with code $exitCode. See $stderrPath"
}

Write-Host "FlowChain node $status."
Write-Host "PID: $($process.Id)"
Write-Host "Logs: $logsDir"
Write-Host "Status command: npm run flowchain:node:status"
