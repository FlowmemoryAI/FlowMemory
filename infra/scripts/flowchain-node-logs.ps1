param(
    [string] $NodeDir = "devnet/local/node",
    [int] $Tail = 80
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$nodeFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $NodeDir)
$logsDir = Join-Path $nodeFullDir "logs"
$stdoutPath = Join-Path $logsDir "node.stdout.jsonl"
$stderrPath = Join-Path $logsDir "node.stderr.log"
$statusPath = Join-Path $nodeFullDir "node-status.json"

Write-Host "FlowChain node log paths:"
Write-Host "stdout: $stdoutPath"
Write-Host "stderr: $stderrPath"
Write-Host "status: $statusPath"

foreach ($path in @($stdoutPath, $stderrPath, $statusPath)) {
    if (Test-Path -LiteralPath $path) {
        Write-Host ""
        Write-Host "== Tail: $path =="
        Get-Content -LiteralPath $path -Tail $Tail
    }
}

