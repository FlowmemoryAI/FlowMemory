$ErrorActionPreference = "Stop"

$releaseDir = Resolve-Path (Join-Path $PSScriptRoot "..\release")
$unpackedDir = Join-Path $releaseDir "win-unpacked"
$exePath = Join-Path $unpackedDir "Flowchain Wallet.exe"
$zipPath = Join-Path $releaseDir "Flowchain-Wallet-0.0.0-win-x64.zip"

if (-not (Test-Path -LiteralPath $exePath)) {
  throw "Desktop wallet executable was not found at $exePath"
}

if (Test-Path -LiteralPath $zipPath) {
  Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -Path (Join-Path $unpackedDir "*") -DestinationPath $zipPath -Force

Write-Host "Created desktop wallet package: $zipPath"
