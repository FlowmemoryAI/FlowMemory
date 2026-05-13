param(
  [switch]$CheckFormat,
  [switch]$RequireSlither
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command forge -ErrorAction SilentlyContinue)) {
  throw "forge is required for contract hardening checks"
}

if ($CheckFormat) {
  forge fmt --check
  if ($LASTEXITCODE -ne 0) {
    throw "forge fmt --check failed"
  }
}
forge build
if ($LASTEXITCODE -ne 0) {
  throw "forge build failed"
}
forge test
if ($LASTEXITCODE -ne 0) {
  throw "forge test failed"
}

$slither = Get-Command slither -ErrorAction SilentlyContinue
if ($slither) {
  slither . --config-file .slither.config.json
  if ($LASTEXITCODE -ne 0) {
    throw "slither failed"
  }
} elseif ($RequireSlither) {
  throw "slither is required but was not found on PATH"
} else {
  Write-Warning "slither was not found on PATH; install slither-analyzer or rerun with -RequireSlither in audit environments"
}
