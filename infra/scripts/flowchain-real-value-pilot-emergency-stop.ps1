param(
    [ValidateSet("DryRun", "Live")]
    [string] $Mode = "Live",

    [switch] $PlanOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$args = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (Join-Path $PSScriptRoot "flowchain-real-value-pilot.ps1"),
    "-Mode",
    $Mode,
    "-Action",
    "Pause"
)

if ($Mode -eq "Live" -and -not $PlanOnly) {
    $args += "-Execute"
}

Write-Host "FlowChain real-value pilot emergency stop."
Write-Host "This routes to the guarded Pause action. Live mode requires env acknowledgement, Base 8453 chain verification, lockbox address, caps, and the owner key in the local shell."
& powershell @args
if ($LASTEXITCODE -ne 0) {
    throw "FlowChain real-value pilot emergency stop failed."
}
