param(
    [string] $BundlePath = "devnet/local/second-computer/flowchain-second-computer-source-bundle.zip",
    [switch] $Force
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

function Get-BundleExclusionReason {
    param([string] $RelativePath, [string] $Name, [bool] $IsDirectory)
    $normalized = ($RelativePath -replace "\\", "/").Trim("/")
    $lower = $normalized.ToLowerInvariant()
    $lowerName = $Name.ToLowerInvariant()
    if ($IsDirectory) {
        if ($lowerName -in @(".git", "node_modules", "target", "dist", "cache", "out", "broadcast")) { return "metadata, dependency, or build output directory" }
        if ($lower -eq "devnet/local" -or $lower.StartsWith("devnet/local/")) { return "ignored local runtime output" }
        if ($lowerName -like "*vault*") { return "local vault directory" }
        return ""
    }
    if ($lower -match '(^|/)(\.git|node_modules|target|dist|cache|out|broadcast)(/|$)') { return "metadata, dependency, or build output path" }
    if ($lower -eq "devnet/local" -or $lower.StartsWith("devnet/local/")) { return "ignored local runtime output" }
    if ($lowerName -eq ".env" -or ($lowerName.StartsWith(".env.") -and $lowerName -ne ".env.example")) { return "local env file" }
    if ($lowerName.EndsWith(".local.json")) { return "local-only JSON file" }
    if ($lowerName -like "*vault*" -or $lowerName -like "*private-key*" -or $lowerName -like "*private_key*" -or $lowerName -like "*mnemonic*" -or $lowerName -like "*seed-phrase*") { return "secret-named file" }
    if ($lowerName.EndsWith(".pem") -or $lowerName.EndsWith(".key") -or $lowerName.EndsWith(".pfx") -or $lowerName.EndsWith(".p12")) { return "private key material file" }
    return ""
}

$repoRoot = Set-FlowChainRepoRoot
$bundleFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $BundlePath)
$bundleRoot = Split-Path -Parent $bundleFullPath
$stageRoot = Join-Path $bundleRoot "stage"
$stageRepo = Join-Path $stageRoot "FlowMemory"
if ((Test-Path -LiteralPath $bundleFullPath) -and -not $Force) {
    Remove-Item -LiteralPath $bundleFullPath -Force
}
if (Test-Path -LiteralPath $stageRoot) {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stageRepo | Out-Null

$excluded = New-Object System.Collections.ArrayList
$repoPrefix = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
foreach ($item in Get-ChildItem -LiteralPath $repoRoot -Force) {
    $stack = New-Object System.Collections.Stack
    $stack.Push($item)
    while ($stack.Count -gt 0) {
        $current = $stack.Pop()
        $relative = [System.IO.Path]::GetFullPath($current.FullName).Substring($repoPrefix.Length)
        $reason = Get-BundleExclusionReason -RelativePath $relative -Name $current.Name -IsDirectory $current.PSIsContainer
        if (-not [string]::IsNullOrWhiteSpace($reason)) {
            [void] $excluded.Add([ordered]@{ path = $relative; reason = $reason })
            continue
        }
        $dest = Join-Path $stageRepo $relative
        if ($current.PSIsContainer) {
            New-Item -ItemType Directory -Force -Path $dest | Out-Null
            foreach ($child in Get-ChildItem -LiteralPath $current.FullName -Force) {
                $stack.Push($child)
            }
        }
        else {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
            Copy-Item -LiteralPath $current.FullName -Destination $dest
        }
    }
}

$manifestPath = Join-Path $stageRepo "SECOND_COMPUTER_BUNDLE_MANIFEST.json"
$manifest = [ordered]@{
    schema = "flowchain.second_computer.source_bundle_manifest.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    sourceRepo = $repoRoot
    excludes = @(".git", "node_modules", "devnet/local", "target", "dist/cache/out/broadcast", "env files", "vaults", "private keys")
    excludedCount = $excluded.Count
    nextCommands = @(
        "npm install",
        "npm install --prefix apps/dashboard",
        "npm install --prefix crypto",
        "npm run flowchain:second-computer:verify",
        "npm run flowchain:production-l1:e2e"
    )
}
Write-FlowChainJson -Path $manifestPath -Value $manifest -Depth 10

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-no-secret-scan.ps1") -Paths @($stageRepo) -ReportPath (Join-Path $stageRepo "SECOND_COMPUTER_BUNDLE_NO_SECRET_SCAN.json")
if ($LASTEXITCODE -ne 0) {
    throw "Second-computer bundle no-secret scan failed."
}

New-Item -ItemType Directory -Force -Path $bundleRoot | Out-Null
Compress-Archive -Path $stageRepo -DestinationPath $bundleFullPath -Force
$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $bundleFullPath
$reportPath = Join-Path $bundleRoot "flowchain-second-computer-bundle-report.json"
$report = [ordered]@{
    schema = "flowchain.second_computer.bundle_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "passed"
    bundlePath = $bundleFullPath
    bundleSha256 = $hash.Hash
    manifestPath = $manifestPath
}
Write-FlowChainJson -Path $reportPath -Value $report -Depth 10

Write-Host "FlowChain second-computer offline source bundle created."
Write-Host "Bundle: $bundleFullPath"
Write-Host "Report: $reportPath"

