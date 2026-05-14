param(
    [string[]]$ScanPaths = @(
        "devnet/local/bridge-live-readiness",
        "devnet/local/production-l1-real-funds-readiness",
        "services/bridge-relayer/out"
    ),
    [string]$ReportPath = "devnet/local/bridge-live-readiness/bridge-no-secret-audit-report.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)

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

$status = if ($findings.Count -eq 0) { "passed" } else { "failed" }
$report = [ordered]@{
    schema = "flowchain.bridge_no_secret_audit_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = $status
    scannedPaths = $ScanPaths
    scannedFileCount = $scannedFiles.Count
    findings = @($findings)
    broadcasts = $false
    printsEnvValues = $false
    noSecrets = ($findings.Count -eq 0)
}

Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 12
Write-Host "Bridge no-secret audit status: $status"
Write-Host "Report: $reportFullPath"
if ($findings.Count -gt 0) {
    throw "Bridge no-secret audit failed."
}
