param(
    [string] $Out = "devnet/local/pilot-wallet/operator-config.local.json",
    [string] $CreatedAtUnixMs = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$configPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $Out)

$args = @("run", "wallet:pilot-config", "--prefix", "crypto", "--", "--out", $configPath)
if (-not [string]::IsNullOrWhiteSpace($CreatedAtUnixMs)) {
    $args += @("--created-at-unix-ms", $CreatedAtUnixMs)
}

Invoke-FlowChainCommand -Label "Create capped pilot operator config from environment" -FilePath "npm" -ArgumentList $args

Write-Host ""
Write-Host "Pilot operator config: $configPath"
Write-Host "Next commands:"
Invoke-FlowChainCommand -Label "Print capped pilot next commands" -FilePath "npm" -ArgumentList @(
    "run",
    "wallet:pilot-next",
    "--prefix",
    "crypto",
    "--",
    "--config",
    $configPath
)
