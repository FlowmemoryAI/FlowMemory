param(
    [string] $StatePath = "devnet/local/state.json",
    [string] $NodeDir = "devnet/local/node",
    [string] $ServicesDir = "devnet/local/services",
    [string] $ControlPlaneHost = "127.0.0.1",
    [int] $ControlPlanePort = 8787,
    [int] $BlockMs = 1000,
    [int] $MaxBlocks = 0,
    [switch] $LiveProfile,
    [switch] $StartBridgeRelayerLoop,
    [int] $BridgePollSeconds = 30
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$servicesFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ServicesDir)
$controlPlaneScriptPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path "services/control-plane/src/server.ts")
$logsDir = Join-Path $servicesFullDir "logs"
$controlPlanePidPath = Join-Path $servicesFullDir "control-plane.pid"
$relayerPidPath = Join-Path $servicesFullDir "bridge-relayer-loop.pid"
$reportPath = Join-Path $servicesFullDir "flowchain-service-start-report.json"
$configuredControlPlaneCargoTargetDir = [Environment]::GetEnvironmentVariable("FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR", "Process")
$controlPlaneCargoTargetDir = if ([string]::IsNullOrWhiteSpace($configuredControlPlaneCargoTargetDir)) {
    Join-Path $repoRoot "devnet/local/cargo-target/control-plane-runtime"
}
else {
    [System.IO.Path]::GetFullPath($configuredControlPlaneCargoTargetDir)
}
$controlPlaneCargoTargetDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path $controlPlaneCargoTargetDir
$controlPlaneCargoTempDir = Join-Path $repoRoot "devnet/local/tmp/control-plane-runtime"
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
New-Item -ItemType Directory -Force -Path $controlPlaneCargoTargetDir | Out-Null
New-Item -ItemType Directory -Force -Path $controlPlaneCargoTempDir | Out-Null

function Get-ControlPlanePortProcess {
    param(
        [Parameter(Mandatory = $true)][int] $Port,
        [Parameter(Mandatory = $true)][string] $ExpectedScriptPath
    )

    $connections = @(Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($connections.Count -eq 0) {
        return $null
    }
    $pidValue = [int]$connections[0].OwningProcess
    try {
        $commandLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$pidValue").CommandLine
    }
    catch {
        $commandLine = ""
    }
    return [ordered]@{
        pid = $pidValue
        commandLine = "$commandLine"
        isCurrentRepoControlPlane = ("$commandLine" -like "*$ExpectedScriptPath*")
    }
}

if ($LiveProfile -and $MaxBlocks -gt 0) {
    throw "Live service profile must not use bounded MaxBlocks mode."
}
if ($ControlPlaneHost -notin @("127.0.0.1", "localhost", "::1") -and [string]::IsNullOrWhiteSpace((Get-FlowChainEnvValue -Name "FLOWCHAIN_RPC_PUBLIC_URL"))) {
    throw "Non-local bind requires FLOWCHAIN_RPC_PUBLIC_URL to be configured. Default remains 127.0.0.1."
}

$nodeArgs = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (Join-Path $PSScriptRoot "flowchain-node-start.ps1"),
    "-StatePath",
    $StatePath,
    "-NodeDir",
    $NodeDir,
    "-BlockMs",
    "$BlockMs"
)
if ($MaxBlocks -gt 0) {
    $nodeArgs += @("-MaxBlocks", "$MaxBlocks")
}
& powershell @nodeArgs
if ($LASTEXITCODE -ne 0) {
    throw "FlowChain node start failed."
}

$controlStatus = Test-FlowChainPid -PidPath $controlPlanePidPath -CommandLineIncludes @($controlPlaneScriptPath)
if ($controlStatus.running -and -not $controlStatus.commandLineMatched) {
    Remove-Item -LiteralPath $controlPlanePidPath -Force -ErrorAction SilentlyContinue
    $controlStatus = Test-FlowChainPid -PidPath $controlPlanePidPath -CommandLineIncludes @($controlPlaneScriptPath)
}
if (-not ($controlStatus.running -and $controlStatus.commandLineMatched)) {
    $portProcess = Get-ControlPlanePortProcess -Port $ControlPlanePort -ExpectedScriptPath $controlPlaneScriptPath
    if ($null -ne $portProcess) {
        if (-not $portProcess.isCurrentRepoControlPlane) {
            throw "Control-plane port $ControlPlanePort is already in use by a process that was not launched from this repository. Stop that process or choose another port."
        }
        Set-Content -LiteralPath $controlPlanePidPath -Value "$($portProcess.pid)"
        $controlStatus = Test-FlowChainPid -PidPath $controlPlanePidPath -CommandLineIncludes @($controlPlaneScriptPath)
    }
}
if (-not ($controlStatus.running -and $controlStatus.commandLineMatched)) {
    $previousFlowChainControlPlaneCargoTarget = [Environment]::GetEnvironmentVariable("FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR", "Process")
    $previousCargoTarget = [Environment]::GetEnvironmentVariable("CARGO_TARGET_DIR", "Process")
    $previousTemp = [Environment]::GetEnvironmentVariable("TEMP", "Process")
    $previousTmp = [Environment]::GetEnvironmentVariable("TMP", "Process")
    try {
        $env:FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR = $controlPlaneCargoTargetDir
        $env:CARGO_TARGET_DIR = $controlPlaneCargoTargetDir
        $env:TEMP = $controlPlaneCargoTempDir
        $env:TMP = $controlPlaneCargoTempDir
        & cargo build --manifest-path "crates/flowmemory-devnet/Cargo.toml"
        if ($LASTEXITCODE -ne 0) {
            throw "Control-plane runtime cargo warmup failed."
        }
    }
    finally {
        [Environment]::SetEnvironmentVariable("CARGO_TARGET_DIR", $previousCargoTarget, "Process")
        [Environment]::SetEnvironmentVariable("TEMP", $previousTemp, "Process")
        [Environment]::SetEnvironmentVariable("TMP", $previousTmp, "Process")
        if ([string]::IsNullOrWhiteSpace($previousFlowChainControlPlaneCargoTarget)) {
            $env:FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR = $controlPlaneCargoTargetDir
        }
        else {
            [Environment]::SetEnvironmentVariable("FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR", $previousFlowChainControlPlaneCargoTarget, "Process")
        }
    }

    $stdoutPath = Join-Path $logsDir "control-plane.stdout.log"
    $stderrPath = Join-Path $logsDir "control-plane.stderr.log"
    $cpArgs = @(
        $controlPlaneScriptPath,
        "--host",
        $ControlPlaneHost,
        "--port",
        "$ControlPlanePort"
    )
    $process = Start-Process -FilePath "node" `
        -ArgumentList (Join-FlowChainProcessArguments -ArgumentList $cpArgs) `
        -WorkingDirectory $repoRoot `
        -PassThru `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath
    Set-Content -LiteralPath $controlPlanePidPath -Value "$($process.Id)"
    $controlStatus = Test-FlowChainPid -PidPath $controlPlanePidPath -CommandLineIncludes @($controlPlaneScriptPath)
}

$relayerStarted = $false
if ($StartBridgeRelayerLoop) {
    if ($BridgePollSeconds -lt 5) {
        throw "BridgePollSeconds must be at least 5."
    }
    $relayerStatus = Test-FlowChainPid -PidPath $relayerPidPath -CommandLineIncludes @("bridge-base-mainnet-pilot-observe.ps1")
    if (-not $relayerStatus.running) {
        $relayerStdout = Join-Path $logsDir "bridge-relayer-loop.stdout.log"
        $relayerStderr = Join-Path $logsDir "bridge-relayer-loop.stderr.log"
        $observeScript = Join-Path $PSScriptRoot "bridge-base-mainnet-pilot-observe.ps1"
        $loopCommand = @"
while (`$true) {
  try {
    & "$observeScript" -ReportPath "devnet/local/bridge-live-readiness/bridge-relayer-loop-report.json"
  } catch {
    Write-Error `$_.Exception.Message
  }
  Start-Sleep -Seconds $BridgePollSeconds
}
"@
        $relayerProcess = Start-Process -FilePath "powershell" `
            -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $loopCommand) `
            -WorkingDirectory $repoRoot `
            -PassThru `
            -WindowStyle Hidden `
            -RedirectStandardOutput $relayerStdout `
            -RedirectStandardError $relayerStderr
        Set-Content -LiteralPath $relayerPidPath -Value "$($relayerProcess.Id)"
        $relayerStarted = $true
    }
}

$nodePidPath = Join-Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $NodeDir) "flowchain-node.pid"
$nodeStatus = Test-FlowChainPid -PidPath $nodePidPath -CommandLineIncludes @("flowmemory-devnet")
$controlStatus = Test-FlowChainPid -PidPath $controlPlanePidPath -CommandLineIncludes @($controlPlaneScriptPath)
$relayerStatusFinal = Test-FlowChainPid -PidPath $relayerPidPath -CommandLineIncludes @("bridge-base-mainnet-pilot-observe.ps1")

$report = [ordered]@{
    schema = "flowchain.service_start_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = if ($nodeStatus.running -and $nodeStatus.commandLineMatched -and $controlStatus.running -and $controlStatus.commandLineMatched) { "started" } else { "failed" }
    liveProfile = [bool]$LiveProfile
    statePath = $StatePath
    nodeDir = $NodeDir
    servicesDir = $ServicesDir
    bind = [ordered]@{
        host = $ControlPlaneHost
        port = $ControlPlanePort
        localDefaultPrivate = ($ControlPlaneHost -eq "127.0.0.1")
    }
    blockMs = $BlockMs
    maxBlocks = $MaxBlocks
    node = [ordered]@{
        running = $nodeStatus.running
        pid = $nodeStatus.pid
    }
    controlPlane = [ordered]@{
        running = $controlStatus.running
        pid = $controlStatus.pid
        commandLineMatched = $controlStatus.commandLineMatched
    }
    bridgeRelayerLoop = [ordered]@{
        requested = [bool]$StartBridgeRelayerLoop
        startedThisRun = $relayerStarted
        running = $relayerStatusFinal.running
        pid = $relayerStatusFinal.pid
        pollSeconds = $BridgePollSeconds
    }
    controlPlaneCargoWarmup = [ordered]@{
        targetDir = $controlPlaneCargoTargetDir
        tempDir = $controlPlaneCargoTempDir
    }
    statusCommand = "npm run flowchain:service:status"
    stopCommand = "npm run flowchain:service:stop"
    envValuesPrinted = $false
    noSecrets = $true
}
Write-FlowChainJson -Path $reportPath -Value $report -Depth 14

Write-Host "FlowChain services $($report.status)."
Write-Host "Node PID: $($report.node.pid)"
Write-Host "Control plane PID: $($report.controlPlane.pid)"
Write-Host "Bind: $ControlPlaneHost`:$ControlPlanePort"
Write-Host "Report: $reportPath"
if ($report.status -ne "started") {
    throw "FlowChain service start failed."
}
