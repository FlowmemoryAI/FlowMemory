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
$logsDir = Join-Path $servicesFullDir "logs"
$controlPlanePidPath = Join-Path $servicesFullDir "control-plane.pid"
$relayerPidPath = Join-Path $servicesFullDir "bridge-relayer-loop.pid"
$reportPath = Join-Path $servicesFullDir "flowchain-service-start-report.json"
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

function Get-ControlPlanePortProcess {
    param(
        [Parameter(Mandatory = $true)][int] $Port
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
        isControlPlane = ("$commandLine" -like "*src/server.ts*" -or "$commandLine" -like "*services/control-plane/src/server.ts*")
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

$controlStatus = Test-FlowChainPid -PidPath $controlPlanePidPath -CommandLineIncludes @("services/control-plane/src/server.ts")
if (-not $controlStatus.running) {
    $portProcess = Get-ControlPlanePortProcess -Port $ControlPlanePort
    if ($null -ne $portProcess) {
        if (-not $portProcess.isControlPlane) {
            throw "Control-plane port $ControlPlanePort is already in use by a non-control-plane process."
        }
        Set-Content -LiteralPath $controlPlanePidPath -Value "$($portProcess.pid)"
        $controlStatus = Test-FlowChainPid -PidPath $controlPlanePidPath -CommandLineIncludes @("src/server.ts")
    }
}
if (-not $controlStatus.running) {
    $stdoutPath = Join-Path $logsDir "control-plane.stdout.log"
    $stderrPath = Join-Path $logsDir "control-plane.stderr.log"
    $cpArgs = @(
        "services/control-plane/src/server.ts",
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
    $controlStatus = Test-FlowChainPid -PidPath $controlPlanePidPath -CommandLineIncludes @("services/control-plane/src/server.ts")
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
$controlStatus = Test-FlowChainPid -PidPath $controlPlanePidPath -CommandLineIncludes @("services/control-plane/src/server.ts")
$relayerStatusFinal = Test-FlowChainPid -PidPath $relayerPidPath -CommandLineIncludes @("bridge-base-mainnet-pilot-observe.ps1")

$report = [ordered]@{
    schema = "flowchain.service_start_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = if ($nodeStatus.running -and $controlStatus.running) { "started" } else { "failed" }
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
    }
    bridgeRelayerLoop = [ordered]@{
        requested = [bool]$StartBridgeRelayerLoop
        startedThisRun = $relayerStarted
        running = $relayerStatusFinal.running
        pid = $relayerStatusFinal.pid
        pollSeconds = $BridgePollSeconds
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
