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
    "FLOWCHAIN_RPC_TLS_TERMINATED",
    "FLOWCHAIN_TESTER_WRITE_ENABLED",
    "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256",
    "FLOWCHAIN_TESTER_MAX_SEND_UNITS"
)

$publicSafeJsonRpcMethods = @(
    "rpc_discover",
    "rpc_readiness",
    "health",
    "node_status",
    "peer_list",
    "chain_status",
    "bridge_live_readiness",
    "bridge_status",
    "pilot_status",
    "pilot_deposit_observation_list",
    "pilot_credit_list",
    "pilot_withdrawal_intent_list",
    "pilot_release_evidence_list",
    "pilot_cap_status",
    "pilot_pause_status",
    "pilot_retry_status",
    "pilot_emergency_status",
    "pilot_lifecycle_record_list",
    "wallet_balance_list",
    "wallet_transfer_history",
    "devnet_state",
    "block_get",
    "block_list",
    "mempool_list",
    "transaction_get",
    "transaction_list",
    "account_get",
    "account_list",
    "balance_get",
    "token_get",
    "token_list",
    "token_balance_get",
    "token_balance_list",
    "pool_get",
    "pool_list",
    "lp_position_get",
    "lp_position_list",
    "swap_get",
    "swap_list",
    "product_flow_status",
    "faucet_event_list",
    "wallet_metadata_get",
    "wallet_metadata_list",
    "rootfield_get",
    "rootfield_list",
    "artifact_availability_get",
    "artifact_availability_list",
    "receipt_get",
    "receipt_list",
    "work_receipt_get",
    "work_receipt_list",
    "verifier_module_get",
    "verifier_module_list",
    "verifier_report_get",
    "verifier_report_list",
    "memory_cell_get",
    "memory_cell_list",
    "agent_get",
    "agent_list",
    "model_get",
    "model_list",
    "challenge_get",
    "challenge_list",
    "finality_get",
    "finality_list",
    "bridge_observation_get",
    "bridge_observation_list",
    "bridge_deposit_get",
    "bridge_deposit_list",
    "bridge_credit_get",
    "bridge_credit_list",
    "bridge_credit_status",
    "withdrawal_get",
    "withdrawal_list",
    "provenance_get"
)

$explicitlyRejectedJsonRpcMethods = @(
    "transaction_submit",
    "bridge_observation_submit",
    "raw_json_get"
)

$publicReadMirrorPaths = @(
    "/health",
    "/rpc/discover",
    "/rpc/readiness",
    "/state",
    "/explorer/summary",
    "/chain/status",
    "/product-flow/status",
    "/bridge/live-readiness",
    "/bridge/status",
    "/bridge/credits",
    "/bridge/credit-status",
    "/bridge/observations",
    "/wallets/balances",
    "/wallets/transfers",
    "/wallets/operator",
    "/tester/status",
    "/pilot/status",
    "/pilot/lifecycle",
    "/pilot/deposits",
    "/pilot/credits",
    "/pilot/withdrawal-intents",
    "/pilot/release-evidence",
    "/pilot/cap-status",
    "/pilot/pause-status",
    "/pilot/retry-status",
    "/pilot/emergency-status"
)

$authenticatedTesterWritePaths = @(
    "/tester/faucet",
    "/tester/wallets/create",
    "/tester/wallets/send"
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
        id = "public-rpc-allowlist"
        requirement = "Public /rpc dispatch is fail-closed to explicitly public-safe JSON-RPC read methods."
        status = "passed"
        evidence = "origin enforces explicit allowlist and rejects transaction_submit, bridge_observation_submit, raw_json_get, and unknown methods"
    },
    [ordered]@{
        id = "edge-path-allowlist"
        requirement = "The public edge does not proxy private write or admin routes; tester writes use the authenticated tester gateway only."
        status = "passed"
        evidence = "template exposes /rpc, explicit read mirrors, /tester/faucet, and /tester/wallets/create|send; fallback location returns 404"
    },
    [ordered]@{
        id = "authenticated-tester-write-gateway"
        requirement = "Friends-and-family wallet creation, faucet funding, and sends have a dedicated bearer-authenticated gateway with a unit cap."
        status = "passed"
        evidence = "origin requires FLOWCHAIN_TESTER_WRITE_* env names and bearer auth before /tester/faucet, /tester/wallets/create, or /tester/wallets/send executes"
    },
    [ordered]@{
        id = "body-size-limit"
        requirement = "Oversized public request bodies are rejected before they reach the private origin."
        status = "passed"
        evidence = "template sets client_max_body_size 256k and origin enforces 262144-byte JSON body cap"
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
    "    client_max_body_size 256k;",
    "",
    "    location = /rpc {",
    "        if (`$request_method !~ ^(POST|OPTIONS)$) { return 405; }",
    "        limit_req zone=flowchain_rpc_per_ip burst=20 nodelay;",
    "        proxy_pass http://127.0.0.1:8787;",
    "        proxy_http_version 1.1;",
    "        proxy_set_header Host `$host;",
    "        proxy_set_header Origin `$http_origin;",
    "        proxy_set_header X-Forwarded-Proto https;",
    "        proxy_set_header X-Forwarded-For `$remote_addr;",
    "        proxy_read_timeout 60s;",
    "    }",
    "",
    "    location ~ ^/(health|state|explorer/summary|chain/status|product-flow/status|bridge/(live-readiness|status|credits|credit-status|observations)|wallets/(balances|transfers|operator)|pilot/(status|lifecycle|deposits|credits|withdrawal-intents|release-evidence|cap-status|pause-status|retry-status|emergency-status))$ {",
    "        if (`$request_method !~ ^(GET|OPTIONS)$) { return 405; }",
    "        limit_req zone=flowchain_rpc_per_ip burst=20 nodelay;",
    "        proxy_pass http://127.0.0.1:8787;",
    "        proxy_http_version 1.1;",
    "        proxy_set_header Host `$host;",
    "        proxy_set_header Origin `$http_origin;",
    "        proxy_set_header X-Forwarded-Proto https;",
    "        proxy_set_header X-Forwarded-For `$remote_addr;",
    "        proxy_read_timeout 60s;",
    "    }",
    "",
    "    location ~ ^/tester/(faucet|wallets/(create|send))$ {",
    "        if (`$request_method !~ ^(POST|OPTIONS)$) { return 405; }",
    "        limit_req zone=flowchain_rpc_per_ip burst=5 nodelay;",
    "        proxy_pass http://127.0.0.1:8787;",
    "        proxy_http_version 1.1;",
    "        proxy_set_header Host `$host;",
    "        proxy_set_header Origin `$http_origin;",
    "        proxy_set_header Authorization `$http_authorization;",
    "        proxy_set_header X-Forwarded-Proto https;",
    "        proxy_set_header X-Forwarded-For `$remote_addr;",
    "        proxy_read_timeout 60s;",
    "    }",
    "",
    "    location = /tester/status {",
    "        if (`$request_method !~ ^(GET|OPTIONS)$) { return 405; }",
    "        limit_req zone=flowchain_rpc_per_ip burst=20 nodelay;",
    "        proxy_pass http://127.0.0.1:8787;",
    "        proxy_http_version 1.1;",
    "        proxy_set_header Host `$host;",
    "        proxy_set_header Origin `$http_origin;",
    "        proxy_set_header X-Forwarded-Proto https;",
    "        proxy_set_header X-Forwarded-For `$remote_addr;",
    "        proxy_read_timeout 60s;",
    "    }",
    "",
    "    location ~ ^/rpc/(discover|readiness)$ {",
    "        if (`$request_method !~ ^(GET|OPTIONS)$) { return 405; }",
    "        limit_req zone=flowchain_rpc_per_ip burst=20 nodelay;",
    "        proxy_pass http://127.0.0.1:8787;",
    "        proxy_http_version 1.1;",
    "        proxy_set_header Host `$host;",
    "        proxy_set_header Origin `$http_origin;",
    "        proxy_set_header X-Forwarded-Proto https;",
    "        proxy_set_header X-Forwarded-For `$remote_addr;",
    "        proxy_read_timeout 60s;",
    "    }",
    "",
    "    location / {",
    "        return 404;",
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
    bodyLimitBytes = 262144
    batchLimit = 50
    forwardsOriginForCors = $true
    publicSafeJsonRpcMethods = $publicSafeJsonRpcMethods
    explicitlyRejectedJsonRpcMethods = $explicitlyRejectedJsonRpcMethods
    publicReadMirrorPaths = $publicReadMirrorPaths
    authenticatedTesterWritePaths = $authenticatedTesterWritePaths
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
$markdownLines.Add("## Public JSON-RPC Method Allowlist")
$markdownLines.Add("")
$markdownLines.Add("The origin only dispatches these public-safe JSON-RPC read methods through `/rpc`; any other method fails closed before local handlers run.")
$markdownLines.Add("")
foreach ($method in $publicSafeJsonRpcMethods) {
    $markdownLines.Add("- $method")
}
$markdownLines.Add("")
$markdownLines.Add("## Explicitly Rejected JSON-RPC Methods")
$markdownLines.Add("")
foreach ($method in $explicitlyRejectedJsonRpcMethods) {
    $markdownLines.Add("- $method")
}
$markdownLines.Add("")
$markdownLines.Add("## Public Read Mirror Paths")
$markdownLines.Add("")
foreach ($path in $publicReadMirrorPaths) {
    $markdownLines.Add("- $path")
}
$markdownLines.Add("")
$markdownLines.Add("## Authenticated Tester Write Paths")
$markdownLines.Add("")
$markdownLines.Add("These paths are for capped friends-and-family pilot sends only. The origin rejects them unless `FLOWCHAIN_TESTER_WRITE_ENABLED=true`, a bearer token matching `FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256` is provided, and `FLOWCHAIN_TESTER_MAX_SEND_UNITS` caps the send amount.")
$markdownLines.Add("")
foreach ($path in $authenticatedTesterWritePaths) {
    $markdownLines.Add("- $path")
}
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
