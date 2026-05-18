param(
    [string] $SourceDir = "devnet/local/production-l1-e2e",
    [string] $BundlePath = "devnet/local/production-l1-e2e/evidence/flowchain-production-l1-evidence.zip",
    [switch] $Force
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

function Get-RelativePath {
    param([string] $Root, [string] $Path)
    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if ($fullPath -eq $fullRoot) { return "" }
    $prefix = $fullRoot + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside root: $fullPath"
    }
    return $fullPath.Substring($prefix.Length)
}

function Get-EvidenceExclusionReason {
    param([string] $RelativePath, [string] $Name, [bool] $IsDirectory)
    $normalized = ($RelativePath -replace "\\", "/").Trim("/")
    $lower = $normalized.ToLowerInvariant()
    $lowerName = $Name.ToLowerInvariant()
    if ($IsDirectory) {
        if ($lowerName -in @(".git", "node_modules", "target", "dist", "cache", "out", "broadcast", "stage")) { return "repository metadata, dependency, or build output" }
        if ($lowerName -like "*vault*") { return "local vault directory" }
        if ($lowerName -in @("secret", "secrets", ".secret", ".secrets")) { return "secret directory" }
        return ""
    }
    if ($lower -match '(^|/)(\.git|node_modules|target|dist|cache|out|broadcast)(/|$)') { return "repository metadata, dependency, or build output path" }
    if ($lowerName -eq ".env" -or ($lowerName.StartsWith(".env.") -and $lowerName -ne ".env.example")) { return "local env file" }
    if ($lowerName.EndsWith(".local.json")) { return "local-only JSON file" }
    if ($lowerName -like "*vault*") { return "local vault file" }
    if ($lowerName.EndsWith(".pem") -or $lowerName.EndsWith(".key") -or $lowerName.EndsWith(".pfx") -or $lowerName.EndsWith(".p12")) { return "private key material file" }
    if ($lowerName -like "*private-key*" -or $lowerName -like "*private_key*" -or $lowerName -like "*mnemonic*" -or $lowerName -like "*seed-phrase*") { return "secret-named file" }
    if ($lowerName.EndsWith(".zip")) { return "nested archive" }
    return ""
}

function Copy-EvidenceTree {
    param([string] $Source, [string] $Destination, [string] $Root, [System.Collections.ArrayList] $Excluded)
    if (-not (Test-Path -LiteralPath $Source)) { return }
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    foreach ($item in Get-ChildItem -LiteralPath $Source -Force) {
        $relative = Get-RelativePath -Root $Root -Path $item.FullName
        $reason = Get-EvidenceExclusionReason -RelativePath $relative -Name $item.Name -IsDirectory $item.PSIsContainer
        if (-not [string]::IsNullOrWhiteSpace($reason)) {
            [void] $Excluded.Add([ordered]@{ path = $relative; reason = $reason })
            continue
        }
        $dest = Join-Path $Destination $item.Name
        if ($item.PSIsContainer) {
            Copy-EvidenceTree -Source $item.FullName -Destination $dest -Root $Root -Excluded $Excluded
        }
        else {
            Copy-Item -LiteralPath $item.FullName -Destination $dest
        }
    }
}

function Assert-ZipManifestSafe {
    param([string] $Path)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        foreach ($entry in $zip.Entries) {
            $entryPath = ($entry.FullName -replace "\\", "/").Trim("/")
            if ([string]::IsNullOrWhiteSpace($entryPath)) { continue }
            $entryName = [System.IO.Path]::GetFileName($entryPath.TrimEnd("/"))
            $reason = Get-EvidenceExclusionReason -RelativePath $entryPath -Name $entryName -IsDirectory $entry.FullName.EndsWith("/")
            if (-not [string]::IsNullOrWhiteSpace($reason)) {
                throw "Evidence bundle contains excluded path '$entryPath' ($reason)."
            }
        }
    }
    finally {
        $zip.Dispose()
    }
}

$repoRoot = Set-FlowChainRepoRoot
$sourceFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $SourceDir)
$bundleFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $BundlePath)
$exportRoot = Split-Path -Parent $bundleFullPath
$stageRoot = Join-Path $exportRoot "stage"
$stageEvidence = Join-Path $stageRoot "flowchain-production-l1-evidence"

if ((Test-Path -LiteralPath $bundleFullPath) -and -not $Force) {
    Remove-Item -LiteralPath $bundleFullPath -Force
}
if (Test-Path -LiteralPath $stageRoot) {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stageEvidence | Out-Null

$excluded = New-Object System.Collections.ArrayList
Copy-EvidenceTree -Source $sourceFullDir -Destination (Join-Path $stageEvidence "production-l1-e2e") -Root $sourceFullDir -Excluded $excluded

foreach ($optional in @(
        "devnet/local/smoke",
        "devnet/local/full-smoke",
        "devnet/local/product-e2e",
        "devnet/local/real-value-pilot/ops-e2e",
        "devnet/local/real-value-pilot/export",
        "services/bridge-relayer/out"
    )) {
    $optionalFull = Resolve-FlowChainPath -RepoRoot $repoRoot -Path $optional
    if (Test-Path -LiteralPath $optionalFull) {
        $safeName = ($optional -replace '[:\\/]+', '-')
        Copy-EvidenceTree -Source $optionalFull -Destination (Join-Path $stageEvidence $safeName) -Root $optionalFull -Excluded $excluded
    }
}

$schemas = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "schemas/flowmemory"
if (Test-Path -LiteralPath $schemas) {
    Copy-EvidenceTree -Source $schemas -Destination (Join-Path $stageEvidence "public-schemas-flowmemory") -Root $schemas -Excluded $excluded
}

$safeConfigPath = Join-Path $stageEvidence "safe-config-summary.json"
$packageJson = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "package.json") | ConvertFrom-Json
$safeConfig = [ordered]@{
    schema = "flowchain.production_l1.safe_config_summary.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    packageScripts = @($packageJson.scripts.PSObject.Properties.Name | Sort-Object)
    ignoredLocalPaths = @("devnet/local/", ".env", ".env.*", "node_modules/", "target/", "dist/", "cache/", "out/", "broadcast/")
    localUrls = @("http://127.0.0.1:8787/health", "http://127.0.0.1:5173/")
    printsSecrets = $false
}
Write-FlowChainJson -Path $safeConfigPath -Value $safeConfig -Depth 8

$manifestPath = Join-Path $stageEvidence "evidence-export-manifest.json"
$manifest = [ordered]@{
    schema = "flowchain.production_l1.evidence_export_manifest.v0"
    exportedAt = (Get-Date).ToUniversalTime().ToString("o")
    sourceDir = $sourceFullDir
    excludes = @(
        ".git",
        "node_modules",
        "Rust target directories",
        "build outputs",
        "env files",
        "vaults",
        "private keys",
        "seed phrases",
        "mnemonics",
        "RPC credentials",
        "API keys",
        "webhooks",
        "nested archives"
    )
    excludedCount = $excluded.Count
    excludedSamples = @($excluded | Select-Object -First 50)
}
Write-FlowChainJson -Path $manifestPath -Value $manifest -Depth 12

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-no-secret-scan.ps1") -Paths @($stageEvidence) -ReportPath (Join-Path $stageEvidence "no-secret-scan-report.json")
if ($LASTEXITCODE -ne 0) {
    throw "Evidence stage no-secret scan failed."
}

New-Item -ItemType Directory -Force -Path $exportRoot | Out-Null
Compress-Archive -Path $stageEvidence -DestinationPath $bundleFullPath -Force
Assert-ZipManifestSafe -Path $bundleFullPath

$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $bundleFullPath
$reportPath = Join-Path $exportRoot "flowchain-production-l1-evidence-export-report.json"
$report = [ordered]@{
    schema = "flowchain.production_l1.evidence_export_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "passed"
    bundlePath = $bundleFullPath
    bundleSha256 = $hash.Hash
    manifestPath = $manifestPath
    excludedCount = $excluded.Count
}
Write-FlowChainJson -Path $reportPath -Value $report -Depth 10

Write-Host "FlowChain production-l1 evidence export complete."
Write-Host "Bundle: $bundleFullPath"
Write-Host "Report: $reportPath"
