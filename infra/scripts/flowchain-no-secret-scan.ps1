param(
    [string[]] $Paths = @(
        "apps/dashboard/public/data",
        "devnet/local/live-product-e2e",
        "devnet/local/production-l1-e2e",
        "devnet/local/live-l1-bridge-e2e",
        "devnet/local/full-smoke",
        "devnet/local/product-e2e",
        "devnet/local/production-l1-wallet",
        "devnet/local/real-value-pilot",
        "fixtures/dashboard",
        "services/bridge-relayer/out",
        "services/control-plane/out"
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
    if ($name -eq "no-secret-scan-report.json") { return $true }
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

function Add-ReadFailureFinding {
    param(
        [string] $Path,
        [string] $Operation,
        [object] $ErrorRecord
    )

    $errorKind = "unknown"
    if ($null -ne $ErrorRecord -and $null -ne $ErrorRecord.Exception) {
        $errorKind = $ErrorRecord.Exception.GetType().Name
    }

    Add-Finding -Path $Path -Reason "$Operation failed ($errorKind)"
}

function Read-SecretScanFileText {
    param([System.IO.FileInfo] $File)

    try {
        $text = [System.IO.File]::ReadAllText($File.FullName)
        if ($null -eq $text) {
            return ""
        }

        return [string] $text
    }
    catch {
        Add-ReadFailureFinding -Path $File.FullName -Operation "read" -ErrorRecord $_
        return $null
    }
}

function Test-AllowedSecretMarkerOccurrence {
    param([string] $Text, [string] $Pattern, [int] $Index)

    if ($Pattern -notin @("privateKey", "private_key", "webhookUrl", "webhook_url")) {
        return $false
    }

    $start = $Index
    while ($start -gt 0 -and $Text[$start - 1].ToString() -match '[A-Za-z0-9_]') {
        $start -= 1
    }
    $end = $Index + $Pattern.Length
    while ($end -lt $Text.Length -and $Text[$end].ToString() -match '[A-Za-z0-9_]') {
        $end += 1
    }

    $token = $Text.Substring($start, $end - $start)
    return $token -cmatch '^[A-Z][A-Z0-9_]*(PRIVATE_KEY|PRIVATEKEY|WEBHOOK_URL|WEBHOOKURL)[A-Z0-9_]*$'
}

foreach ($path in $Paths) {
    $full = Resolve-FlowChainPath -RepoRoot $repoRoot -Path $path
    if (-not (Test-Path -LiteralPath $full)) {
        continue
    }

    try {
        $item = Get-Item -LiteralPath $full
    }
    catch {
        Add-ReadFailureFinding -Path $full -Operation "stat" -ErrorRecord $_
        continue
    }

    try {
        $files = if ($item.PSIsContainer) {
            @(Get-ChildItem -LiteralPath $full -Recurse -File | Where-Object {
                $_.Extension -in @(".json", ".txt", ".md", ".log", ".csv", ".jsonl") -and
                -not (Test-ExcludedSecretScanPath -Path $_.FullName)
            })
        }
        else {
            @($item)
        }
    }
    catch {
        Add-ReadFailureFinding -Path $full -Operation "enumerate" -ErrorRecord $_
        continue
    }

    foreach ($file in $files) {
        [void] $scanned.Add($file.FullName)
        $text = Read-SecretScanFileText -File $file
        if ($null -eq $text) {
            continue
        }

        foreach ($pattern in @(
                "BEGIN RSA PRIVATE KEY",
                "BEGIN OPENSSH PRIVATE KEY",
                "BEGIN PRIVATE KEY",
                "seedPhrase",
                "mnemonicPhrase",
                "privateKey",
                "private_key",
                "webhookUrl",
                "webhook_url"
            )) {
            $searchFrom = 0
            $hasFinding = $false
            while ($true) {
                $matchIndex = $text.IndexOf($pattern, $searchFrom, [System.StringComparison]::OrdinalIgnoreCase)
                if ($matchIndex -lt 0) {
                    break
                }
                if (-not (Test-AllowedSecretMarkerOccurrence -Text $text -Pattern $pattern -Index $matchIndex)) {
                    $hasFinding = $true
                    break
                }
                $searchFrom = $matchIndex + $pattern.Length
            }
            if ($hasFinding) {
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
        "no-secret scan self-reports",
        "*.local.json",
        "vault paths",
        "zip files"
    )
}
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 12

Write-Host "FlowChain no-secret scan status: $status"
Write-Host "Report: $reportFullPath"
if ($status -ne "passed") {
    throw "No-secret scan found redacted findings."
}
