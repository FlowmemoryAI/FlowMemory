param(
    [string] $EvidenceDir = "devnet/local/real-value-pilot/evidence",
    [string] $BundlePath = "devnet/local/real-value-pilot/export/flowchain-real-value-pilot-evidence.zip",
    [switch] $DryRun,
    [switch] $Force
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

function Get-PilotRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Root,

        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if ($fullPath -eq $fullRoot) {
        return ""
    }

    $prefix = $fullRoot + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside root: $fullPath"
    }

    return $fullPath.Substring($prefix.Length)
}

function Get-PilotEvidenceExclusionReason {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RelativePath,

        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [bool] $IsDirectory
    )

    $normalized = ($RelativePath -replace "\\", "/").Trim("/")
    $lower = $normalized.ToLowerInvariant()
    $lowerName = $Name.ToLowerInvariant()

    if ($IsDirectory) {
        if ($lowerName -in @(".git", "node_modules", "target", "dist", "cache", "out", "broadcast")) {
            return "repository metadata, dependency, or build target directory"
        }
        if ($lowerName -like "*vault*") {
            return "local vault directory"
        }
        if ($lowerName -in @("secret", "secrets", ".secret", ".secrets")) {
            return "secret directory"
        }
        return ""
    }

    if ($lower -match '(^|/)(\.git|node_modules|target|dist|cache|out|broadcast)(/|$)') {
        return "repository metadata, dependency, or build target path"
    }
    if ($lowerName -eq ".env" -or ($lowerName.StartsWith(".env.") -and $lowerName -ne ".env.example")) {
        return "local environment file"
    }
    if ($lowerName.EndsWith(".local.json")) {
        return "local-only JSON file"
    }
    if ($lowerName -like "*vault*") {
        return "local vault file"
    }
    if (
        $lowerName.EndsWith(".pem") -or
        $lowerName.EndsWith(".key") -or
        $lowerName.EndsWith(".pfx") -or
        $lowerName.EndsWith(".p12") -or
        $lowerName -like "*private-key*" -or
        $lowerName -like "*private_key*"
    ) {
        return "private key material file"
    }
    if (
        $lowerName -in @("secret", "secrets", ".secret", ".secrets") -or
        $lowerName -like "secret.*" -or
        $lowerName -like "secrets.*" -or
        $lowerName -like "*.secret" -or
        $lowerName -like "*.secrets" -or
        $lowerName -like "*.secret.*" -or
        $lowerName -like "*.secrets.*"
    ) {
        return "secret-named file"
    }

    return ""
}

function Assert-PilotEvidenceTextSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $files = Get-ChildItem -LiteralPath $Path -Recurse -File | Where-Object {
        $_.Extension -in @(".json", ".txt", ".md", ".log", ".csv")
    }
    foreach ($file in $files) {
        $text = Get-Content -Raw -LiteralPath $file.FullName
        foreach ($pattern in @(
                ("BEGIN RSA " + "PRIVATE KEY"),
                ("BEGIN OPENSSH " + "PRIVATE KEY"),
                ("BEGIN " + "PRIVATE KEY"),
                "seed phrase",
                "mnemonic",
                "apiKey",
                "webhook"
            )) {
            if ($text.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                throw "Potential secret marker '$pattern' found in evidence file $($file.FullName)."
            }
        }
    }
}

function Copy-PilotEvidenceTree {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourceDir,

        [Parameter(Mandatory = $true)]
        [string] $DestinationDir,

        [Parameter(Mandatory = $true)]
        [string] $Root,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.ArrayList] $Excluded
    )

    New-Item -ItemType Directory -Force -Path $DestinationDir | Out-Null

    foreach ($item in Get-ChildItem -LiteralPath $SourceDir -Force) {
        $relativePath = Get-PilotRelativePath -Root $Root -Path $item.FullName
        $reason = Get-PilotEvidenceExclusionReason -RelativePath $relativePath -Name $item.Name -IsDirectory $item.PSIsContainer
        if (-not [string]::IsNullOrWhiteSpace($reason)) {
            [void] $Excluded.Add([ordered]@{
                    path = $relativePath
                    reason = $reason
                })
            continue
        }

        $destinationPath = Join-Path $DestinationDir $item.Name
        if ($item.PSIsContainer) {
            Copy-PilotEvidenceTree -SourceDir $item.FullName -DestinationDir $destinationPath -Root $Root -Excluded $Excluded
        }
        else {
            Copy-Item -LiteralPath $item.FullName -Destination $destinationPath
        }
    }
}

function Assert-PilotEvidenceZipSafe {
    param([Parameter(Mandatory = $true)][string] $Path)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        foreach ($entry in $zip.Entries) {
            $entryPath = ($entry.FullName -replace "\\", "/").Trim("/")
            if ([string]::IsNullOrWhiteSpace($entryPath)) {
                continue
            }
            $entryName = [System.IO.Path]::GetFileName($entryPath.TrimEnd("/"))
            $reason = Get-PilotEvidenceExclusionReason -RelativePath $entryPath -Name $entryName -IsDirectory $entry.FullName.EndsWith("/")
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
$evidenceFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $EvidenceDir)
$bundleFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $BundlePath)
$exportRoot = Split-Path -Parent $bundleFullPath
$stageRoot = Join-Path $exportRoot "stage"
$stageEvidenceRoot = Join-Path $stageRoot "flowchain-real-value-pilot-evidence"

New-Item -ItemType Directory -Force -Path $evidenceFullDir | Out-Null
if ($DryRun) {
    Write-FlowChainJson -Path (Join-Path $evidenceFullDir "dry-run-evidence.json") -Value ([ordered]@{
            schema = "flowchain.real_value_pilot.dry_run_evidence.v0"
            generatedAt = (Get-Date).ToUniversalTime().ToString("o")
            dryRun = $true
            containsSecrets = $false
        })
}

if ((Test-Path -LiteralPath $bundleFullPath) -and -not $Force) {
    Remove-Item -LiteralPath $bundleFullPath -Force
}

if (Test-Path -LiteralPath $stageRoot) {
    $verifiedStageRoot = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path $stageRoot
    Remove-Item -LiteralPath $verifiedStageRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stageEvidenceRoot | Out-Null

$excluded = New-Object System.Collections.ArrayList
Copy-PilotEvidenceTree -SourceDir $evidenceFullDir -DestinationDir $stageEvidenceRoot -Root $evidenceFullDir -Excluded $excluded

$manifestPath = Join-Path $stageEvidenceRoot "evidence-export-manifest.json"
$manifest = [ordered]@{
    schema = "flowchain.real_value_pilot.evidence_export_manifest.v0"
    exportedAt = (Get-Date).ToUniversalTime().ToString("o")
    sourceEvidenceDir = $evidenceFullDir
    dryRun = [bool] $DryRun
    excludes = @(
        ".git",
        "node_modules",
        "target",
        "dist",
        "cache",
        "out",
        "broadcast",
        ".env files except .env.example",
        "*.local.json",
        "local vault paths",
        "private key material files",
        "secret-named paths"
    )
    excludedCount = $excluded.Count
    excludedSamples = @($excluded | Select-Object -First 40)
}
Write-FlowChainJson -Path $manifestPath -Value $manifest -Depth 10

Assert-PilotEvidenceTextSafe -Path $stageEvidenceRoot

New-Item -ItemType Directory -Force -Path $exportRoot | Out-Null
Compress-Archive -Path $stageEvidenceRoot -DestinationPath $bundleFullPath -Force
Assert-PilotEvidenceZipSafe -Path $bundleFullPath

$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $bundleFullPath
$reportPath = Join-Path $exportRoot "flowchain-real-value-pilot-evidence-export-report.json"
$report = [ordered]@{
    schema = "flowchain.real_value_pilot.evidence_export_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    bundlePath = $bundleFullPath
    bundleSha256 = $hash.Hash
    dryRun = [bool] $DryRun
    verifiedExclusions = @(
        ".git",
        "node_modules",
        "build targets",
        "local vaults",
        "private keys",
        "env files"
    )
    manifestPath = $manifestPath
}
Write-FlowChainJson -Path $reportPath -Value $report -Depth 10

Write-Host ""
Write-Host "FlowChain real-value pilot evidence export complete."
Write-Host "Bundle: $bundleFullPath"
Write-Host "SHA256: $($hash.Hash)"
Write-Host "Report: $reportPath"
Write-Host "After export evidence, next command: npm run flowchain:real-value-pilot -- --Mode Live --Action Restart"
