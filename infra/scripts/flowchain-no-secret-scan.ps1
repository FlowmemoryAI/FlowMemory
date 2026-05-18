param(
    [string[]] $Paths = @(
        "devnet/local/production-l1-e2e",
        "devnet/local/full-smoke",
        "devnet/local/product-e2e",
        "devnet/local/real-value-pilot",
        "fixtures/dashboard",
        "services/bridge-relayer/out"
    ),
    [string] $ReportPath = "devnet/local/production-l1-e2e/no-secret-scan-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$findings = New-Object System.Collections.ArrayList
$scanned = New-Object System.Collections.ArrayList

function Test-ExcludedSecretScanPath {
    param([string] $Path)

    $normalized = ($Path -replace "\\", "/").ToLowerInvariant()
    $name = [System.IO.Path]::GetFileName($normalized)
    if ($normalized -match '(^|/)(\.git|node_modules|target|dist|cache|out/broadcast|broadcast)(/|$)') { return $true }
    if ($name -eq ".env" -or ($name.StartsWith(".env.") -and $name -ne ".env.example")) { return $true }
    if ($name.EndsWith(".local.json")) { return $true }
    if ($name -like "*vault*") { return $true }
    if ($name.EndsWith(".zip")) { return $true }
    return $false
}

function Add-Finding {
    param([string] $Path, [string] $Reason)
    [void] $findings.Add([ordered]@{
        path = $Path
        reason = $Reason
    })
}

foreach ($path in $Paths) {
    $full = Resolve-FlowChainPath -RepoRoot $repoRoot -Path $path
    if (-not (Test-Path -LiteralPath $full)) {
        continue
    }
    $item = Get-Item -LiteralPath $full
    $files = if ($item.PSIsContainer) {
        Get-ChildItem -LiteralPath $full -Recurse -File | Where-Object {
            $_.Extension -in @(".json", ".txt", ".md", ".log", ".csv", ".jsonl") -and
            -not (Test-ExcludedSecretScanPath -Path $_.FullName)
        }
    }
    else {
        @($item)
    }

    foreach ($file in $files) {
        [void] $scanned.Add($file.FullName)
        $text = Get-Content -Raw -LiteralPath $file.FullName
        foreach ($pattern in @(
                ("BEGIN RSA " + "PRIVATE KEY"),
                ("BEGIN OPENSSH " + "PRIVATE KEY"),
                ("BEGIN " + "PRIVATE KEY"),
                "seedPhrase",
                "mnemonicPhrase",
                "privateKey",
                "private_key",
                "webhookUrl",
                "webhook_url"
            )) {
            if ($text.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                Add-Finding -Path $file.FullName -Reason "secret marker '$pattern'"
            }
        }
        if ($text -match 'https?://[^\s"<>]*(alchemy|infura|apikey|api-key|token=|key=)[^\s"<>]*') {
            Add-Finding -Path $file.FullName -Reason "credential-shaped RPC or API URL"
        }
    }
}

$status = if ($findings.Count -eq 0) { "passed" } else { "failed" }
$report = [ordered]@{
    schema = "flowchain.no_secret_scan_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    scannedCount = $scanned.Count
    scannedPaths = @($Paths)
    findings = @($findings)
    excluded = @(
        ".git",
        "node_modules",
        "target",
        "dist/cache/build outputs",
        "env files",
        "*.local.json",
        "vault paths",
        "zip files"
    )
}
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 12

Write-Host "FlowChain no-secret scan status: $status"
Write-Host "Report: $reportFullPath"
if ($status -ne "passed") {
    throw "No-secret scan found secret-shaped output."
}
