param(
    [string[]]$ScanPaths = @(
        "devnet/local/bridge-live-readiness",
        "devnet/local/production-l1-real-funds-readiness",
        "services/bridge-relayer/out"
    ),
    [string]$ReportPath = "docs/agent-runs/live-product-infra-rpc/bridge-no-secret-audit-report.json",
    [string]$MarkdownPath = "docs/agent-runs/live-product-infra-rpc/BRIDGE_NO_SECRET_AUDIT.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)

$findings = New-Object System.Collections.ArrayList
$scannedFiles = New-Object System.Collections.ArrayList
$patterns = @(
    @{ code = "private_key_block"; regex = "BEGIN (RSA |OPENSSH )?PRIVATE KEY" },
    @{ code = "labeled_private_key"; regex = "(private key|privkey|secret key)\s*[:=]\s*0x[0-9a-fA-F]{64}" },
    @{ code = "credentialed_rpc_url"; regex = "https?://[^/\s:@]+:[^/\s:@]+@" },
    @{ code = "api_key_value"; regex = "(sk|pk|rk|ghp|gho|ghu|github_pat|xox[baprs])-[-_A-Za-z0-9]{16,}" },
    @{ code = "webhook_url"; regex = "https://(hooks\.slack\.com|discord(app)?\.com/api/webhooks|[^\s`"']*webhook)[^\s`"']+" }
)

foreach ($path in $ScanPaths) {
    $fullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $path)
    if (-not (Test-Path -LiteralPath $fullPath)) {
        continue
    }
    $item = Get-Item -LiteralPath $fullPath
    $files = if ($item.PSIsContainer) {
        Get-ChildItem -LiteralPath $fullPath -Recurse -File | Where-Object { $_.Extension -in @(".json", ".md", ".txt", ".log") }
    }
    else {
        @($item)
    }
    foreach ($file in $files) {
        [void] $scannedFiles.Add($file.FullName.Replace($repoRoot, "").TrimStart("\", "/"))
        $text = Get-Content -Raw -LiteralPath $file.FullName
        foreach ($pattern in $patterns) {
            if ($text -match $pattern.regex) {
                [void] $findings.Add([ordered]@{
                    file = $file.FullName.Replace($repoRoot, "").TrimStart("\", "/")
                    reason = $pattern.code
                })
            }
        }
    }
}

$checks = [ordered]@{
    scannedPathsPresent = $ScanPaths.Count -gt 0
    scannedFileCountPositive = $scannedFiles.Count -gt 0
    findingsEmpty = $findings.Count -eq 0
    secretMarkerFindingsEmpty = $findings.Count -eq 0
    envValuesPrintedFalse = $true
    noSecrets = $findings.Count -eq 0
    broadcastsFalse = $true
}
$failedChecks = @($checks.GetEnumerator() | Where-Object { $_.Value -ne $true } | ForEach-Object { $_.Key })
$status = if ($failedChecks.Count -eq 0 -and $findings.Count -eq 0) { "passed" } else { "failed" }
$report = [ordered]@{
    schema = "flowchain.bridge_no_secret_audit_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    scannedPaths = $ScanPaths
    scannedFileCount = $scannedFiles.Count
    findings = @($findings)
    secretMarkerFindings = @($findings)
    checks = $checks
    failedChecks = @($failedChecks)
    broadcasts = $false
    printsEnvValues = $false
    envValuesPrinted = $false
    noSecrets = ($findings.Count -eq 0)
}

Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 12

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Bridge No-Secret Audit")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $status")
$markdownLines.Add("")
$markdownLines.Add("This audit scans generated bridge pilot evidence for secret-shaped material before owner-funded bridge activation.")
$markdownLines.Add("")
$markdownLines.Add("## Scanned Paths")
$markdownLines.Add("")
foreach ($path in $ScanPaths) {
    $markdownLines.Add("- $path")
}
$markdownLines.Add("")
$markdownLines.Add("## Checks")
$markdownLines.Add("")
$markdownLines.Add("| Check | Result |")
$markdownLines.Add("| --- | --- |")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("| $($entry.Key) | $($entry.Value) |")
}
$markdownLines.Add("")
$markdownLines.Add("Scanned files: $($scannedFiles.Count)")
$markdownLines.Add("Findings: $($findings.Count)")
if ($findings.Count -gt 0) {
    $markdownLines.Add("")
    $markdownLines.Add("## Findings")
    $markdownLines.Add("")
    foreach ($finding in $findings) {
        $markdownLines.Add("- $($finding.file): $($finding.reason)")
    }
}
$markdownText = ($markdownLines -join [Environment]::NewLine) + [Environment]::NewLine
Assert-FlowChainNoSecretText -Text $markdownText -Label "bridge no-secret audit markdown"
$markdownParent = Split-Path -Parent $markdownFullPath
if (-not [string]::IsNullOrWhiteSpace($markdownParent)) {
    New-Item -ItemType Directory -Force -Path $markdownParent | Out-Null
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($markdownFullPath, $markdownText, $utf8NoBom)
Write-Host "Bridge no-secret audit status: $status"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($failedChecks.Count -gt 0 -or $findings.Count -gt 0) {
    throw "Bridge no-secret audit failed."
}
