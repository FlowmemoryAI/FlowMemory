$ErrorActionPreference = "Stop"

$releaseDir = Resolve-Path (Join-Path $PSScriptRoot "..\release")
$unpackedDir = Join-Path $releaseDir "win-unpacked"
$exePath = Join-Path $unpackedDir "FlowMemory Operator.exe"
$packageJsonPath = Resolve-Path (Join-Path $PSScriptRoot "..\package.json")
$packageJson = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json
$zipPath = Join-Path $releaseDir "FlowMemory-Operator-$($packageJson.version)-win-x64.zip"

if (-not (Test-Path -LiteralPath $exePath)) {
  throw "Desktop wallet executable was not found at $exePath"
}

if (Test-Path -LiteralPath $zipPath) {
  Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -Path (Join-Path $unpackedDir "*") -DestinationPath $zipPath -Force

Write-Host "Created desktop wallet package: $zipPath"
