param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-edge-template-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/PUBLIC_RPC_EDGE_TEMPLATE.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)

$publicRpcEnvNames = @(
    "FLOWCHAIN_RPC_PUBLIC_URL",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
    "FLOWCHAIN_RPC_TLS_TERMINATED"
)

$edgeRequirements = @(
    [ordered]@{
        id = "repo-owned-origin"
        requirement = "Proxy points to the repo-owned private FlowChain RPC origin."
        status = "passed"
        evidence = "privateOrigin=127.0.0.1:8787"
    },
    [ordered]@{
        id = "https-only"
        requirement = "Public traffic terminates TLS before reaching the private origin."
        status = "passed"
        evidence = "template includes HTTPS listener and HTTP redirect"
    },
    [ordered]@{
        id = "rate-limit"
        requirement = "Public requests are rate-limited before they reach the private origin."
        status = "passed"
        evidence = "template includes limit_req zone tied to FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE"
    },
    [ordered]@{
        id = "origin-forwarding"
        requirement = "Browser Origin headers and the edge-confirmed client address are forwarded so CORS and per-client rate limits can be enforced."
        status = "passed"
        evidence = "template forwards Origin, Host, X-Forwarded-Proto, and sets X-Forwarded-For from the edge remote address"
    },
    [ordered]@{
        id = "no-values"
        requirement = "Template stores placeholders and env names only."
        status = "passed"
        evidence = "valuesPrinted=false"
    }
)

$nginxTemplate = @(
    "# FlowChain public RPC edge template.",
    "# Replace placeholders only in the owner host environment. Do not commit rendered configs.",
    "limit_req_zone `$binary_remote_addr zone=flowchain_rpc_per_ip:10m rate=<FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE>r/m;",
    "",
    "server {",
    "    listen 80;",
    "    server_name <FLOWCHAIN_RPC_PUBLIC_HOST>;",
    "    return 301 https://`$host`$request_uri;",
    "}",
    "",
    "server {",
    "    listen 443 ssl http2;",
    "    server_name <FLOWCHAIN_RPC_PUBLIC_HOST>;",
    "",
    "    ssl_certificate <PATH_TO_TLS_CERTIFICATE>;",
    "    ssl_certificate_key <PATH_TO_TLS_CERTIFICATE_KEY>;",
    "",
    "    access_log off;",
    "",
    "    location / {",
    "        limit_req zone=flowchain_rpc_per_ip burst=20 nodelay;",
    "        proxy_pass http://127.0.0.1:8787;",
    "        proxy_http_version 1.1;",
    "        proxy_set_header Host `$host;",
    "        proxy_set_header Origin `$http_origin;",
    "        proxy_set_header X-Forwarded-Proto https;",
    "        proxy_set_header X-Forwarded-For `$remote_addr;",
    "        proxy_read_timeout 60s;",
    "    }",
    "}"
)

$localCommands = @(
    "npm run flowchain:service:restart -- -LiveProfile",
    "npm run flowchain:service:status",
    "npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30",
    "npm run flowchain:public-rpc:validate",
    "npm run flowchain:public-rpc:check",
    "npm run flowchain:public-deployment:contract -- -AllowBlocked"
)

$report = [ordered]@{
    schema = "flowchain.public_rpc_edge_template_report.v0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "passed"
    edgeTemplateReady = $true
    flowChainRpcIsRepoOwned = $true
    thirdPartyFlowChainRpcProviderNeeded = $false
    privateOrigin = "127.0.0.1:8787"
    requiresOwnerDns = $true
    requiresTlsTermination = $true
    requiresRateLimit = $true
    forwardsOriginForCors = $true
    envNames = $publicRpcEnvNames
    edgeRequirements = $edgeRequirements
    nginxTemplate = $nginxTemplate
    localCommands = $localCommands
    valuesPrinted = $false
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
}

$reportText = $report | ConvertTo-Json -Depth 16
Assert-FlowChainNoSecretText -Text $reportText -Label "public RPC edge template report"
Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 16

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Public RPC Edge Template")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: passed")
$markdownLines.Add("")
$markdownLines.Add("FlowChain RPC is served by this repository on the private origin `127.0.0.1:8787`. Public RPC means placing an owner-operated HTTPS edge in front of that origin.")
$markdownLines.Add("")
$markdownLines.Add("This file contains placeholders only. Replace placeholders only on the owner host and keep rendered configs out of the repository.")
$markdownLines.Add("")
$markdownLines.Add("## Requirements")
$markdownLines.Add("")
$markdownLines.Add("| Requirement | Status | Evidence |")
$markdownLines.Add("| --- | --- | --- |")
foreach ($item in $edgeRequirements) {
    $markdownLines.Add("| $($item.requirement.Replace('|','/')) | $($item.status) | $($item.evidence.Replace('|','/')) |")
}
$markdownLines.Add("")
$markdownLines.Add("## Nginx Template")
$markdownLines.Add("")
$markdownLines.Add('```nginx')
foreach ($line in $nginxTemplate) {
    $markdownLines.Add($line)
}
$markdownLines.Add('```')
$markdownLines.Add("")
$markdownLines.Add("## Required Local Env Names")
$markdownLines.Add("")
foreach ($name in $publicRpcEnvNames) {
    $markdownLines.Add("- $name")
}
$markdownLines.Add("")
$markdownLines.Add("## Verification Commands")
$markdownLines.Add("")
foreach ($command in $localCommands) {
    $markdownLines.Add("- $command")
}

$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $markdownText -Label "public RPC edge template markdown"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $markdownFullPath) | Out-Null
Set-Content -LiteralPath $markdownFullPath -Value $markdownText -Encoding UTF8

Write-Host "FlowChain public RPC edge template status: passed"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"
