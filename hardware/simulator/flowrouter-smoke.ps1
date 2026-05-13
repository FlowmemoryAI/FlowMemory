$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")
Push-Location -LiteralPath $repoRoot
try {
    python hardware/simulator/flowrouter_sim.py --smoke --seed 42
}
finally {
    Pop-Location
}
