param(
    [string]$EvidenceDir = "services/bridge-relayer/out",
    [string]$BundlePath = "local-runtime/local/bridge-live-readiness/base8453-bridge-evidence.zip"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $repoRoot

function Assert-InsideRepo {
    param([Parameter(Mandatory = $true)][string]$Path)
    $fullRoot = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd('\')
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
    if (-not $fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path must stay inside repository: $Path"
    }
    return $fullPath
}

function Assert-NoSecretText {
    param([Parameter(Mandatory = $true)][string]$Path)
    $patterns = @(
        ("BEGIN " + "PRIVATE KEY"),
        "BEGIN RSA PRIVATE KEY",
        "BEGIN OPENSSH PRIVATE KEY",
        "mnemonic",
        "seed phrase",
        "apiKey",
        "webhook"
    )
    foreach ($file in Get-ChildItem -LiteralPath $Path -Recurse -File -Include *.json,*.md,*.txt,*.log) {
        $text = Get-Content -Raw -LiteralPath $file.FullName
        foreach ($pattern in $patterns) {
            if ($text.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                throw "Potential secret marker found in evidence file $($file.FullName)."
            }
        }
    }
}

$source = Assert-InsideRepo -Path $EvidenceDir
$bundle = Assert-InsideRepo -Path $BundlePath
$exportRoot = Split-Path -Parent $bundle
$stage = Join-Path $exportRoot "base8453-bridge-evidence-stage"

if (-not (Test-Path -LiteralPath $source)) {
    New-Item -ItemType Directory -Force -Path $source | Out-Null
}
if (Test-Path -LiteralPath $stage) {
    Remove-Item -LiteralPath $stage -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stage | Out-Null

Get-ChildItem -LiteralPath $source -Force | Where-Object {
    $_.Name -notin @("node_modules", ".git") -and
    $_.Extension -notin @(".pem", ".key", ".pfx", ".p12") -and
    $_.Name -notlike ".env*"
} | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $stage $_.Name) -Recurse -Force
}

@{
    schema = "flowmemory.bridge_evidence_export_manifest.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    sourceDir = $source
    exclusions = @("node_modules", ".git", ".env*", "*.pem", "*.key", "*.pfx", "*.p12")
    noSecrets = $true
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $stage "evidence-export-manifest.json") -Encoding UTF8

Assert-NoSecretText -Path $stage
if (Test-Path -LiteralPath $bundle) {
    Remove-Item -LiteralPath $bundle -Force
}
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $bundle -Force
$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $bundle
$reportPath = Join-Path $exportRoot "base8453-bridge-evidence-export-report.json"
@{
    schema = "flowmemory.bridge_evidence_export_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    bundlePath = $bundle
    bundleSha256 = $hash.Hash
    sourceDir = $source
    noSecrets = $true
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding UTF8

Write-Host "Bridge evidence export complete."
Write-Host "Bundle: $bundle"
Write-Host "SHA256: $($hash.Hash)"
Write-Host "Report: $reportPath"
