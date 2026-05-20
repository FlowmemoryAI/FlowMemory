param(
    [string] $RpcUrl = $env:FLOWCHAIN_RPC_URL,
    [string] $ReportPath = "docs/agent-runs/live-product-dev-pack/python-sdk-e2e-report.json",
    [string] $WaitTxId = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$previousPythonPath = $env:PYTHONPATH
try {
    $env:PYTHONPATH = (Join-Path $repoRoot "sdks\python")
    $args = @("-m", "flowchain.e2e", "--report", $ReportPath)
    if (-not [string]::IsNullOrWhiteSpace($RpcUrl)) {
        $args += @("--rpc", $RpcUrl)
    }
    if (-not [string]::IsNullOrWhiteSpace($WaitTxId)) {
        $args += @("--wait-tx", $WaitTxId)
    }
    & python @args
    exit $LASTEXITCODE
}
finally {
    $env:PYTHONPATH = $previousPythonPath
}
