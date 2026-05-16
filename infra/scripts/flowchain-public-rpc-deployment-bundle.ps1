param(
    [string] $BundleDir = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/PUBLIC_RPC_DEPLOYMENT_BUNDLE.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$bundleFullDir = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $BundleDir)
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)

$edgeTemplateReportPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path "docs/agent-runs/live-product-infra-rpc/public-rpc-edge-template-report.json"
$edgeTemplateReport = Read-FlowChainJsonIfExists -Path $edgeTemplateReportPath
if ($null -eq $edgeTemplateReport -or "$($edgeTemplateReport.status)" -ne "passed") {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "flowchain-public-rpc-edge-template.ps1") | Out-Null
    $edgeTemplateReport = Read-FlowChainJsonIfExists -Path $edgeTemplateReportPath
}

if ($null -eq $edgeTemplateReport -or "$($edgeTemplateReport.status)" -ne "passed") {
    throw "Public RPC edge template report is not passed."
}

$requiredEnvNames = @(
    "FLOWCHAIN_RPC_PUBLIC_URL",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
    "FLOWCHAIN_RPC_TLS_TERMINATED",
    "FLOWCHAIN_RPC_STATE_BACKUP_PATH"
)

$requiredCommands = @(
    "npm run flowchain:service:restart -- -LiveProfile",
    "npm run flowchain:service:status",
    "npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30",
    "npm run flowchain:ops:snapshot -- -AllowBlocked",
    "npm run flowchain:public-rpc:validate",
    "npm run flowchain:public-rpc:check",
    "npm run flowchain:backup:restore:validate",
    "npm run flowchain:backup:check",
    "npm run flowchain:public-deployment:contract -- -AllowBlocked",
    "npm run flowchain:external-tester:packet -- -AllowBlocked"
)

$rollbackCommands = @(
    "npm run flowchain:ops:snapshot -- -AllowBlocked",
    "npm run flowchain:service:status",
    "npm run flowchain:service:restart -- -LiveProfile",
    "npm run flowchain:service:stop",
    "npm run flowchain:emergency:stop-local"
)

Reset-FlowChainDirectory -Path $bundleFullDir | Out-Null

$nginxTemplateLines = @($edgeTemplateReport.nginxTemplate | ForEach-Object { "$_" })
if ($nginxTemplateLines.Count -eq 0) {
    throw "Public RPC edge template report did not include nginxTemplate lines."
}

$ownerEnvExampleLines = @(
    "# FlowChain owner public RPC env example.",
    "# Keep the real file ignored and local to the owner host. Do not commit rendered values.",
    "FLOWCHAIN_RPC_PUBLIC_URL=",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS=",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE=",
    "FLOWCHAIN_RPC_TLS_TERMINATED=true",
    "FLOWCHAIN_RPC_STATE_BACKUP_PATH="
)

$readmeLines = @(
    "# FlowChain Public RPC Deployment Bundle",
    "",
    "This bundle is placeholder-only. It is safe to commit because it contains env names, templates, and commands, not owner values.",
    "",
    "Files:",
    "",
    "- `nginx-flowchain-rpc.template.conf`: HTTPS reverse-proxy template for the private origin `127.0.0.1:8787`.",
    "- `owner-public-rpc.env.example`: local owner env-file shape with empty values.",
    "- `VERIFY.md`: pre-share verification commands.",
    "- `ROLLBACK.md`: rollback and emergency commands."
)

$verifyLines = @(
    "# Verify Public RPC Before Sharing",
    "",
    "Run these on the owner host after DNS, TLS, allowed origins, rate limit, and backup path are configured locally.",
    ""
)
foreach ($command in $requiredCommands) {
    $verifyLines += "- $command"
}

$rollbackLines = @(
    "# Public RPC Rollback",
    "",
    "Use these commands if the public edge, RPC service, or tester sharing path behaves incorrectly.",
    ""
)
foreach ($command in $rollbackCommands) {
    $rollbackLines += "- $command"
}

$files = [ordered]@{
    readme = Join-Path $bundleFullDir "README.md"
    nginxTemplate = Join-Path $bundleFullDir "nginx-flowchain-rpc.template.conf"
    ownerEnvExample = Join-Path $bundleFullDir "owner-public-rpc.env.example"
    verify = Join-Path $bundleFullDir "VERIFY.md"
    rollback = Join-Path $bundleFullDir "ROLLBACK.md"
}

Set-Content -LiteralPath $files.readme -Value ($readmeLines -join "`r`n") -Encoding UTF8
Set-Content -LiteralPath $files.nginxTemplate -Value ($nginxTemplateLines -join "`r`n") -Encoding UTF8
Set-Content -LiteralPath $files.ownerEnvExample -Value ($ownerEnvExampleLines -join "`r`n") -Encoding UTF8
Set-Content -LiteralPath $files.verify -Value ($verifyLines -join "`r`n") -Encoding UTF8
Set-Content -LiteralPath $files.rollback -Value ($rollbackLines -join "`r`n") -Encoding UTF8

$checks = [ordered]@{
    edgeTemplatePassed = "$($edgeTemplateReport.status)" -eq "passed"
    nginxTemplateWritten = Test-Path -LiteralPath $files.nginxTemplate
    ownerEnvExampleWritten = Test-Path -LiteralPath $files.ownerEnvExample
    verifyRunbookWritten = Test-Path -LiteralPath $files.verify
    rollbackRunbookWritten = Test-Path -LiteralPath $files.rollback
    includesPrivateOrigin = (($nginxTemplateLines -join "`n").Contains("127.0.0.1:8787"))
    includesRateLimitPlaceholder = (($nginxTemplateLines -join "`n").Contains("<FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE>"))
    includesTlsPlaceholders = (($nginxTemplateLines -join "`n").Contains("<PATH_TO_TLS_CERTIFICATE>") -and ($nginxTemplateLines -join "`n").Contains("<PATH_TO_TLS_CERTIFICATE_KEY>"))
    envExampleHasAllRequiredNames = (@($requiredEnvNames | Where-Object { ($ownerEnvExampleLines -join "`n") -notmatch [System.Text.RegularExpressions.Regex]::Escape($_) }).Count -eq 0)
}
$passed = $true
foreach ($value in $checks.Values) {
    if ($value -ne $true) {
        $passed = $false
    }
}

$report = [ordered]@{
    schema = "flowchain.public_rpc_deployment_bundle_report.v1"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = if ($passed) { "passed" } else { "failed" }
    bundleDir = $BundleDir
    flowChainRpcIsRepoOwned = $true
    thirdPartyFlowChainRpcProviderNeeded = $false
    privateOrigin = "127.0.0.1:8787"
    requiredEnvNames = $requiredEnvNames
    requiredCommands = $requiredCommands
    rollbackCommands = $rollbackCommands
    files = [ordered]@{
        readme = "README.md"
        nginxTemplate = "nginx-flowchain-rpc.template.conf"
        ownerEnvExample = "owner-public-rpc.env.example"
        verify = "VERIFY.md"
        rollback = "ROLLBACK.md"
    }
    checks = $checks
    valuesPrinted = $false
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Public RPC Deployment Bundle")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $($report.status)")
$markdownLines.Add("")
$markdownLines.Add("This bundle packages placeholder-only files for an owner-operated HTTPS edge in front of the repo-owned private RPC origin `127.0.0.1:8787`.")
$markdownLines.Add("")
$markdownLines.Add("## Files")
$markdownLines.Add("")
foreach ($entry in $report.files.GetEnumerator()) {
    $markdownLines.Add("- $($entry.Value)")
}
$markdownLines.Add("")
$markdownLines.Add("## Required Env Names")
$markdownLines.Add("")
foreach ($name in $requiredEnvNames) {
    $markdownLines.Add("- $name")
}
$markdownLines.Add("")
$markdownLines.Add("## Verification Commands")
$markdownLines.Add("")
foreach ($command in $requiredCommands) {
    $markdownLines.Add("- $command")
}
$markdownLines.Add("")
$markdownLines.Add("## Rollback Commands")
$markdownLines.Add("")
foreach ($command in $rollbackCommands) {
    $markdownLines.Add("- $command")
}

$reportText = $report | ConvertTo-Json -Depth 16
$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $reportText -Label "public RPC deployment bundle report"
Assert-FlowChainNoSecretText -Text $markdownText -Label "public RPC deployment bundle markdown"
Assert-FlowChainNoSecretFiles -Path $bundleFullDir
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain public RPC deployment bundle status: $($report.status)"
Write-Host "Bundle: $bundleFullDir"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
if ($report.status -ne "passed") {
    throw "FlowChain public RPC deployment bundle failed."
}
