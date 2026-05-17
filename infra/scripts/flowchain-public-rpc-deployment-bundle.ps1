param(
    [string] $BundleDir = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle",
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/PUBLIC_RPC_DEPLOYMENT_BUNDLE.md"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

function Join-BundleLines {
    param([AllowEmptyCollection()][AllowEmptyString()][string[]] $Lines)
    return ($Lines -join "`n")
}

function Get-MissingTextTokens {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string[]] $Tokens
    )

    $missing = New-Object System.Collections.ArrayList
    foreach ($token in $Tokens) {
        if ($Text.IndexOf($token, [System.StringComparison]::Ordinal) -lt 0) {
            [void] $missing.Add($token)
        }
    }
    return @($missing)
}

function Test-TextContainsAllTokens {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string[]] $Tokens
    )

    return (@(Get-MissingTextTokens -Text $Text -Tokens $Tokens).Count -eq 0)
}

function Test-TextContainsNoTokens {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string[]] $Tokens
    )

    foreach ($token in $Tokens) {
        if ($Text.IndexOf($token, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            return $false
        }
    }
    return $true
}

function Test-CheckMapPassed {
    param([Parameter(Mandatory = $true)][System.Collections.Specialized.OrderedDictionary] $Checks)

    foreach ($value in $Checks.Values) {
        if ($value -ne $true) {
            return $false
        }
    }
    return $true
}

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
    "FLOWCHAIN_RPC_STATE_BACKUP_PATH",
    "FLOWCHAIN_TESTER_WRITE_ENABLED",
    "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256",
    "FLOWCHAIN_TESTER_MAX_SEND_UNITS"
)

$requiredPlaceholders = @(
    "<FLOWCHAIN_RPC_PUBLIC_HOST>",
    "<FLOWCHAIN_RPC_PUBLIC_URL>",
    "<FLOWCHAIN_RPC_ALLOWED_ORIGIN>",
    "<FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE>",
    "<PATH_TO_TLS_CERTIFICATE>",
    "<PATH_TO_TLS_CERTIFICATE_KEY>",
    "<FLOWCHAIN_REPO_ABSOLUTE_PATH>",
    "<FLOWCHAIN_SERVICE_USER>",
    "<FLOWCHAIN_SERVICE_GROUP>",
    "<FLOWCHAIN_OWNER_ENV_FILE>",
    "<FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR>",
    "<FLOWCHAIN_RPC_NGINX_RENDERED_CONF>",
    "<FLOWCHAIN_NGINX_PREFLIGHT_SCRIPT>",
    "<FLOWCHAIN_SYSTEMD_RENDERED_UNIT>",
    "<PREVIOUS_FLOWCHAIN_RPC_NGINX_CONF>"
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

$ownerPreflightCommands = @(
    "systemd-analyze verify <FLOWCHAIN_SYSTEMD_RENDERED_UNIT>",
    "nginx -t",
    "bash <FLOWCHAIN_NGINX_PREFLIGHT_SCRIPT>"
)

$localRollbackCommands = @(
    "npm run flowchain:ops:snapshot -- -AllowBlocked",
    "npm run flowchain:service:status",
    "npm run flowchain:service:restart -- -LiveProfile",
    "npm run flowchain:service:stop",
    "npm run flowchain:emergency:stop-local"
)

$ownerRollbackCommands = @(
    "systemctl stop flowchain-live.service",
    "cp <PREVIOUS_FLOWCHAIN_RPC_NGINX_CONF> <FLOWCHAIN_RPC_NGINX_RENDERED_CONF>",
    "nginx -t",
    "systemctl reload nginx",
    "systemctl restart flowchain-live.service"
)

$rollbackCommands = @($localRollbackCommands + $ownerRollbackCommands)

$nginxRequiredTokens = @(
    "server_name <FLOWCHAIN_RPC_PUBLIC_HOST>;",
    "ssl_certificate <PATH_TO_TLS_CERTIFICATE>;",
    "ssl_certificate_key <PATH_TO_TLS_CERTIFICATE_KEY>;",
    "limit_req_zone",
    "rate=<FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE>r/m",
    "limit_req zone=flowchain_rpc_per_ip",
    "proxy_pass http://127.0.0.1:8787;",
    'proxy_set_header Origin $http_origin;',
    'proxy_set_header Authorization $http_authorization;',
    'proxy_set_header X-Forwarded-Proto https;',
    'proxy_set_header X-Forwarded-For $remote_addr;',
    '/tester/wallets/(create|send)'
)

$systemdRequiredTokens = @(
    "[Unit]",
    "[Service]",
    "[Install]",
    "WorkingDirectory=<FLOWCHAIN_REPO_ABSOLUTE_PATH>",
    "User=<FLOWCHAIN_SERVICE_USER>",
    "Group=<FLOWCHAIN_SERVICE_GROUP>",
    "EnvironmentFile=<FLOWCHAIN_OWNER_ENV_FILE>",
    "Environment=FLOWCHAIN_OWNER_ENV_FILE=<FLOWCHAIN_OWNER_ENV_FILE>",
    "Environment=FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR=<FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR>",
    "ExecStart=/usr/bin/env npm run flowchain:service:start -- -LiveProfile",
    "ExecStartPost=/usr/bin/env npm run flowchain:service:status",
    "ExecReload=/usr/bin/env npm run flowchain:service:restart -- -LiveProfile",
    "ExecStop=/usr/bin/env npm run flowchain:service:stop",
    "NoNewPrivileges=true",
    "ReadWritePaths=<FLOWCHAIN_REPO_ABSOLUTE_PATH>/devnet"
)

$preflightRequiredTokens = @(
    'rendered_conf="<FLOWCHAIN_RPC_NGINX_RENDERED_CONF>"',
    'public_host="<FLOWCHAIN_RPC_PUBLIC_HOST>"',
    'public_url="<FLOWCHAIN_RPC_PUBLIC_URL>"',
    'allowed_origin="<FLOWCHAIN_RPC_ALLOWED_ORIGIN>"',
    'grep -Fq "proxy_pass http://127.0.0.1:8787;" "${rendered_conf}"',
    "nginx -t",
    'curl -fsS --max-time 5 "http://127.0.0.1:8787/health" >/dev/null',
    'curl -fsS --max-time 10 -H "Origin: ${allowed_origin}" "${public_url%/}/rpc/readiness" >/dev/null'
)

$forbiddenLiveBroadcastCommandTokens = @(
    "transaction_submit",
    "bridge_observation_submit",
    "eth_sendRawTransaction",
    "sendRawTransaction",
    "cast send",
    "forge script --broadcast",
    "--broadcast",
    "out/broadcast"
)

Reset-FlowChainDirectory -Path $bundleFullDir | Out-Null

$nginxTemplateLines = @($edgeTemplateReport.nginxTemplate | ForEach-Object { "$_" })
if ($nginxTemplateLines.Count -eq 0) {
    throw "Public RPC edge template report did not include nginxTemplate lines."
}

$ownerEnvExampleLines = @(
    "# FlowChain owner public RPC env example.",
    "# Copy outside the repository and fill locally on the owner host only.",
    "# This committed example intentionally leaves every value blank.",
    "FLOWCHAIN_RPC_PUBLIC_URL=",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS=",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE=",
    "FLOWCHAIN_RPC_TLS_TERMINATED=",
    "FLOWCHAIN_RPC_STATE_BACKUP_PATH=",
    "FLOWCHAIN_TESTER_WRITE_ENABLED=",
    "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256=",
    "FLOWCHAIN_TESTER_MAX_SEND_UNITS="
)

$systemdServiceTemplateLines = @(
    "# FlowChain live service systemd template.",
    "# Render on the owner host only. Keep rendered unit files and env files out of the repository.",
    "[Unit]",
    "Description=FlowChain live service",
    "Wants=network-online.target",
    "After=network-online.target",
    "",
    "[Service]",
    "Type=oneshot",
    "WorkingDirectory=<FLOWCHAIN_REPO_ABSOLUTE_PATH>",
    "User=<FLOWCHAIN_SERVICE_USER>",
    "Group=<FLOWCHAIN_SERVICE_GROUP>",
    "EnvironmentFile=<FLOWCHAIN_OWNER_ENV_FILE>",
    "Environment=FLOWCHAIN_OWNER_ENV_FILE=<FLOWCHAIN_OWNER_ENV_FILE>",
    "Environment=FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR=<FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR>",
    "ExecStart=/usr/bin/env npm run flowchain:service:start -- -LiveProfile",
    "ExecStartPost=/usr/bin/env npm run flowchain:service:status",
    "ExecReload=/usr/bin/env npm run flowchain:service:restart -- -LiveProfile",
    "ExecStop=/usr/bin/env npm run flowchain:service:stop",
    "RemainAfterExit=yes",
    "TimeoutStartSec=900",
    "TimeoutStopSec=180",
    "KillMode=process",
    "Restart=on-failure",
    "RestartSec=30",
    "NoNewPrivileges=true",
    "PrivateTmp=true",
    "ProtectSystem=full",
    "ReadWritePaths=<FLOWCHAIN_REPO_ABSOLUTE_PATH>/devnet <FLOWCHAIN_REPO_ABSOLUTE_PATH>/docs/agent-runs <FLOWCHAIN_REPO_ABSOLUTE_PATH>/services/bridge-relayer/out",
    "",
    "[Install]",
    "WantedBy=multi-user.target"
)

$nginxPreflightScriptLines = @(
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    "",
    'rendered_conf="<FLOWCHAIN_RPC_NGINX_RENDERED_CONF>"',
    'public_host="<FLOWCHAIN_RPC_PUBLIC_HOST>"',
    'public_url="<FLOWCHAIN_RPC_PUBLIC_URL>"',
    'allowed_origin="<FLOWCHAIN_RPC_ALLOWED_ORIGIN>"',
    "",
    'test "${rendered_conf}" != "<FLOWCHAIN_RPC_NGINX_RENDERED_CONF>"',
    'test "${public_host}" != "<FLOWCHAIN_RPC_PUBLIC_HOST>"',
    'test "${public_url}" != "<FLOWCHAIN_RPC_PUBLIC_URL>"',
    'test "${allowed_origin}" != "<FLOWCHAIN_RPC_ALLOWED_ORIGIN>"',
    'test -f "${rendered_conf}"',
    "",
    'case "${public_url}" in',
    '  https://*) ;;',
    '  *) echo "FLOWCHAIN_RPC_PUBLIC_URL must be https"; exit 1 ;;',
    'esac',
    "",
    'if grep -Eq ''<FLOWCHAIN_|<PATH_TO_TLS_'' "${rendered_conf}"; then',
    '  echo "Rendered Nginx config still contains placeholders."',
    '  exit 1',
    'fi',
    "",
    'grep -Fq "server_name ${public_host};" "${rendered_conf}"',
    'grep -Fq "proxy_pass http://127.0.0.1:8787;" "${rendered_conf}"',
    'grep -Fq "limit_req_zone" "${rendered_conf}"',
    'grep -Fq "limit_req zone=flowchain_rpc_per_ip" "${rendered_conf}"',
    'grep -Fq "ssl_certificate " "${rendered_conf}"',
    'grep -Fq "ssl_certificate_key " "${rendered_conf}"',
    'grep -Fq ''proxy_set_header Origin $http_origin;'' "${rendered_conf}"',
    'grep -Fq ''proxy_set_header X-Forwarded-Proto https;'' "${rendered_conf}"',
    'grep -Fq ''proxy_set_header X-Forwarded-For $remote_addr;'' "${rendered_conf}"',
    "",
    "nginx -t",
    'curl -fsS --max-time 5 "http://127.0.0.1:8787/health" >/dev/null',
    'curl -fsS --max-time 10 "${public_url%/}/health" >/dev/null',
    'curl -fsS --max-time 10 -H "Origin: ${allowed_origin}" "${public_url%/}/rpc/readiness" >/dev/null',
    'curl -fsS --max-time 10 -H "Origin: ${allowed_origin}" -H "Content-Type: application/json" --data ''{"jsonrpc":"2.0","id":1,"method":"rpc_readiness","params":{}}'' "${public_url%/}/rpc" >/dev/null',
    "",
    'echo "FlowChain public RPC Nginx preflight passed."'
)

$nginxPreflightChecklistLines = @(
    "# Nginx Public RPC Preflight",
    "",
    'Run this on the owner host after rendering `nginx-flowchain-rpc.template.conf` outside the repository and before sharing the public URL.',
    "",
    "Checklist:",
    "",
    '- Render the Nginx template to `<FLOWCHAIN_RPC_NGINX_RENDERED_CONF>`.',
    '- Replace `<FLOWCHAIN_RPC_PUBLIC_HOST>`, `<PATH_TO_TLS_CERTIFICATE>`, `<PATH_TO_TLS_CERTIFICATE_KEY>`, and `<FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE>` only on the owner host.',
    '- Confirm the private origin remains `127.0.0.1:8787`.',
    "- Confirm TLS, rate limiting, Origin forwarding, and X-Forwarded headers are present.",
    '- Run `nginx -t` before every reload.',
    '- Run `bash <FLOWCHAIN_NGINX_PREFLIGHT_SCRIPT>` after installing the rendered config.',
    "",
    "The preflight script uses only local health and public read/readiness requests. It does not send live transactions."
)

$readmeLines = @(
    "# FlowChain Public RPC Deployment Bundle",
    "",
    "This bundle is placeholder-only. It is safe to commit because it contains env names, templates, and commands, not owner values.",
    "",
    "Files:",
    "",
    '- `nginx-flowchain-rpc.template.conf`: HTTPS reverse-proxy template for the private origin `127.0.0.1:8787`.',
    '- `flowchain-live.service.template`: systemd unit template for the owner-host live service.',
    '- `nginx-preflight.template.sh`: Nginx config-test and public read preflight script template.',
    '- `NGINX_PREFLIGHT.md`: Nginx render, TLS, rate-limit, CORS, and reload checklist.',
    '- `owner-public-rpc.env.example`: local owner env-file shape with blank values.',
    '- `VERIFY.md`: pre-share verification commands.',
    '- `ROLLBACK.md`: rollback and emergency commands.',
    '- `bundle-checks.json`: machine-checkable proof that required placeholders and safety properties are present.'
)

$verifyLines = @(
    "# Verify Public RPC Before Sharing",
    "",
    "Run these on the owner host after DNS, TLS, allowed origins, rate limit, and backup path are configured locally.",
    "",
    "## Repository Checks",
    ""
)
foreach ($command in $requiredCommands) {
    $verifyLines += "- $command"
}
$verifyLines += @(
    "",
    "## Owner-Host Preflight Checks",
    ""
)
foreach ($command in $ownerPreflightCommands) {
    $verifyLines += "- $command"
}

$rollbackLines = @(
    "# Public RPC Rollback",
    "",
    "Use these commands if the public edge, RPC service, or tester sharing path behaves incorrectly.",
    "",
    "## Repository Rollback Commands",
    ""
)
foreach ($command in $localRollbackCommands) {
    $rollbackLines += "- $command"
}
$rollbackLines += @(
    "",
    "## Owner-Host Edge Rollback Commands",
    ""
)
foreach ($command in $ownerRollbackCommands) {
    $rollbackLines += "- $command"
}

$files = [ordered]@{
    readme = Join-Path $bundleFullDir "README.md"
    nginxTemplate = Join-Path $bundleFullDir "nginx-flowchain-rpc.template.conf"
    systemdServiceTemplate = Join-Path $bundleFullDir "flowchain-live.service.template"
    nginxPreflightScript = Join-Path $bundleFullDir "nginx-preflight.template.sh"
    nginxPreflightChecklist = Join-Path $bundleFullDir "NGINX_PREFLIGHT.md"
    ownerEnvExample = Join-Path $bundleFullDir "owner-public-rpc.env.example"
    verify = Join-Path $bundleFullDir "VERIFY.md"
    rollback = Join-Path $bundleFullDir "ROLLBACK.md"
    bundleChecks = Join-Path $bundleFullDir "bundle-checks.json"
}

Set-Content -LiteralPath $files.readme -Value ($readmeLines -join "`r`n") -Encoding UTF8
Set-Content -LiteralPath $files.nginxTemplate -Value ($nginxTemplateLines -join "`r`n") -Encoding UTF8
Set-Content -LiteralPath $files.systemdServiceTemplate -Value ($systemdServiceTemplateLines -join "`r`n") -Encoding UTF8
Set-Content -LiteralPath $files.nginxPreflightScript -Value ($nginxPreflightScriptLines -join "`n") -Encoding UTF8
Set-Content -LiteralPath $files.nginxPreflightChecklist -Value ($nginxPreflightChecklistLines -join "`r`n") -Encoding UTF8
Set-Content -LiteralPath $files.ownerEnvExample -Value ($ownerEnvExampleLines -join "`r`n") -Encoding UTF8
Set-Content -LiteralPath $files.verify -Value ($verifyLines -join "`r`n") -Encoding UTF8
Set-Content -LiteralPath $files.rollback -Value ($rollbackLines -join "`r`n") -Encoding UTF8

$nginxText = Join-BundleLines -Lines $nginxTemplateLines
$ownerEnvText = Join-BundleLines -Lines $ownerEnvExampleLines
$systemdText = Join-BundleLines -Lines $systemdServiceTemplateLines
$nginxPreflightScriptText = Join-BundleLines -Lines $nginxPreflightScriptLines
$nginxPreflightChecklistText = Join-BundleLines -Lines $nginxPreflightChecklistLines
$verifyText = Join-BundleLines -Lines $verifyLines
$rollbackText = Join-BundleLines -Lines $rollbackLines
$readmeText = Join-BundleLines -Lines $readmeLines
$allBundleText = @(
    $readmeText,
    $nginxText,
    $ownerEnvText,
    $systemdText,
    $nginxPreflightScriptText,
    $nginxPreflightChecklistText,
    $verifyText,
    $rollbackText
) -join "`n"
$allCommandsText = @($requiredCommands + $ownerPreflightCommands + $rollbackCommands) -join "`n"
$missingRequiredPlaceholders = @(Get-MissingTextTokens -Text $allBundleText -Tokens $requiredPlaceholders)
$ownerEnvAssignmentsWithValues = @($ownerEnvExampleLines | Where-Object { $_ -match '^[A-Z][A-Z0-9_]*=.+$' })

$checks = [ordered]@{
    edgeTemplatePassed = "$($edgeTemplateReport.status)" -eq "passed"
    readmeWritten = Test-Path -LiteralPath $files.readme
    nginxTemplateWritten = Test-Path -LiteralPath $files.nginxTemplate
    systemdServiceTemplateWritten = Test-Path -LiteralPath $files.systemdServiceTemplate
    nginxPreflightScriptWritten = Test-Path -LiteralPath $files.nginxPreflightScript
    nginxPreflightChecklistWritten = Test-Path -LiteralPath $files.nginxPreflightChecklist
    ownerEnvExampleWritten = Test-Path -LiteralPath $files.ownerEnvExample
    verifyRunbookWritten = Test-Path -LiteralPath $files.verify
    rollbackRunbookWritten = Test-Path -LiteralPath $files.rollback
    bundleChecksJsonWritten = $false
    requiredPlaceholdersPresent = ($missingRequiredPlaceholders.Count -eq 0)
    nginxRequiredTokensPresent = Test-TextContainsAllTokens -Text $nginxText -Tokens $nginxRequiredTokens
    systemdLiveServiceTemplatePresent = Test-TextContainsAllTokens -Text $systemdText -Tokens $systemdRequiredTokens
    nginxPreflightTokensPresent = Test-TextContainsAllTokens -Text $nginxPreflightScriptText -Tokens $preflightRequiredTokens
    includesPrivateOrigin = ($nginxText.Contains("127.0.0.1:8787") -and $nginxPreflightScriptText.Contains("127.0.0.1:8787"))
    includesRateLimitPlaceholder = $nginxText.Contains("<FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE>")
    includesTlsPlaceholders = ($nginxText.Contains("<PATH_TO_TLS_CERTIFICATE>") -and $nginxText.Contains("<PATH_TO_TLS_CERTIFICATE_KEY>"))
    includesCorsOriginForwarding = ($nginxText.Contains('proxy_set_header Origin $http_origin;') -and $nginxPreflightScriptText.Contains('Origin: ${allowed_origin}'))
    includesNginxConfigTest = ($nginxPreflightScriptText.Contains("nginx -t") -and $nginxPreflightChecklistText.Contains("nginx -t"))
    includesVerificationCommands = ((@(Get-MissingTextTokens -Text $verifyText -Tokens $requiredCommands).Count -eq 0) -and (@(Get-MissingTextTokens -Text $verifyText -Tokens $ownerPreflightCommands).Count -eq 0))
    includesRollbackCommands = (@(Get-MissingTextTokens -Text $rollbackText -Tokens $rollbackCommands).Count -eq 0)
    envExampleHasAllRequiredNames = (@(Get-MissingTextTokens -Text $ownerEnvText -Tokens $requiredEnvNames).Count -eq 0)
    ownerEnvExampleValuesBlank = ($ownerEnvAssignmentsWithValues.Count -eq 0)
    noLiveBroadcastCommands = (Test-TextContainsNoTokens -Text $allCommandsText -Tokens $forbiddenLiveBroadcastCommandTokens)
    noLiveBroadcastArtifacts = (Test-TextContainsNoTokens -Text $allBundleText -Tokens $forbiddenLiveBroadcastCommandTokens)
    valuesNotPrinted = $true
    envValuesNotPrinted = $true
    noSecrets = $true
    liveBroadcastsDisabled = $true
}

$bundleChecksPayload = [ordered]@{
    schema = "flowchain.public_rpc_deployment_bundle_checks.v1"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = "pending"
    requiredPlaceholders = $requiredPlaceholders
    missingRequiredPlaceholders = $missingRequiredPlaceholders
    requiredEnvNames = $requiredEnvNames
    privateOrigin = "127.0.0.1:8787"
    checks = $checks
    valuesPrinted = $false
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
    liveBroadcasts = $false
}

$checks["bundleChecksJsonWritten"] = $true
$preliminaryPassed = Test-CheckMapPassed -Checks $checks
$bundleChecksPayload["status"] = if ($preliminaryPassed) { "passed" } else { "failed" }
$bundleChecksPayload["checks"] = $checks
$bundleChecksText = $bundleChecksPayload | ConvertTo-Json -Depth 16
Assert-FlowChainNoSecretText -Text $bundleChecksText -Label "public RPC deployment bundle checks"
Write-FlowChainJson -Path $files.bundleChecks -Value $bundleChecksPayload -Depth 16
$checks["bundleChecksJsonWritten"] = Test-Path -LiteralPath $files.bundleChecks

$passed = Test-CheckMapPassed -Checks $checks
$bundleChecksPayload["status"] = if ($passed) { "passed" } else { "failed" }
$bundleChecksPayload["checks"] = $checks
$bundleChecksText = $bundleChecksPayload | ConvertTo-Json -Depth 16
Assert-FlowChainNoSecretText -Text $bundleChecksText -Label "public RPC deployment bundle checks"
Write-FlowChainJson -Path $files.bundleChecks -Value $bundleChecksPayload -Depth 16

$report = [ordered]@{
    schema = "flowchain.public_rpc_deployment_bundle_report.v2"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    status = if ($passed) { "passed" } else { "failed" }
    bundleDir = $BundleDir
    flowChainRpcIsRepoOwned = $true
    thirdPartyFlowChainRpcProviderNeeded = $false
    privateOrigin = "127.0.0.1:8787"
    requiredEnvNames = $requiredEnvNames
    requiredPlaceholders = $requiredPlaceholders
    missingRequiredPlaceholders = $missingRequiredPlaceholders
    requiredCommands = $requiredCommands
    ownerPreflightCommands = $ownerPreflightCommands
    rollbackCommands = $rollbackCommands
    files = [ordered]@{
        readme = "README.md"
        nginxTemplate = "nginx-flowchain-rpc.template.conf"
        systemdServiceTemplate = "flowchain-live.service.template"
        nginxPreflightScript = "nginx-preflight.template.sh"
        nginxPreflightChecklist = "NGINX_PREFLIGHT.md"
        ownerEnvExample = "owner-public-rpc.env.example"
        verify = "VERIFY.md"
        rollback = "ROLLBACK.md"
        bundleChecks = "bundle-checks.json"
    }
    checks = $checks
    valuesPrinted = $false
    envValuesPrinted = $false
    noSecrets = $true
    broadcasts = $false
    liveBroadcasts = $false
}

$markdownLines = New-Object System.Collections.Generic.List[string]
$markdownLines.Add("# FlowChain Public RPC Deployment Bundle")
$markdownLines.Add("")
$markdownLines.Add("Generated: $($report.generatedAt)")
$markdownLines.Add("Status: $($report.status)")
$markdownLines.Add("")
$markdownLines.Add('This bundle packages placeholder-only files for an owner-operated HTTPS edge in front of the repo-owned private RPC origin `127.0.0.1:8787`.')
$markdownLines.Add("")
$markdownLines.Add("## Files")
$markdownLines.Add("")
foreach ($entry in $report.files.GetEnumerator()) {
    $markdownLines.Add("- $($entry.Value)")
}
$markdownLines.Add("")
$markdownLines.Add("## Required Placeholders")
$markdownLines.Add("")
foreach ($placeholder in $requiredPlaceholders) {
    $markdownLines.Add("- $placeholder")
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
$markdownLines.Add("## Owner-Host Preflight Commands")
$markdownLines.Add("")
foreach ($command in $ownerPreflightCommands) {
    $markdownLines.Add("- $command")
}
$markdownLines.Add("")
$markdownLines.Add("## Rollback Commands")
$markdownLines.Add("")
foreach ($command in $rollbackCommands) {
    $markdownLines.Add("- $command")
}
$markdownLines.Add("")
$markdownLines.Add("## Bundle Checks")
$markdownLines.Add("")
foreach ($entry in $checks.GetEnumerator()) {
    $markdownLines.Add("- $($entry.Key): $($entry.Value)")
}

$reportText = $report | ConvertTo-Json -Depth 16
$markdownText = $markdownLines -join "`r`n"
Assert-FlowChainNoSecretText -Text $reportText -Label "public RPC deployment bundle report"
Assert-FlowChainNoSecretText -Text $markdownText -Label "public RPC deployment bundle markdown"
foreach ($artifactText in @($allBundleText, $bundleChecksText)) {
    Assert-FlowChainNoSecretText -Text $artifactText -Label "public RPC deployment bundle artifacts"
}
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
