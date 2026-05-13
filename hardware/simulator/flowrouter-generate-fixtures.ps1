$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")
Push-Location -LiteralPath $repoRoot
try {
    python hardware/simulator/flowrouter_sim.py --generate-fixtures --seed 42
}
finally {
    Pop-Location
}
