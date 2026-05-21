param(
    [string] $RenderedConfig = "<FLOWCHAIN_RPC_NGINX_RENDERED_CONF>",
    [string] $NginxExe = "<FLOWCHAIN_NGINX_EXE>",
    [string] $PublicUrl = "<FLOWCHAIN_RPC_PUBLIC_URL>",
    [string] $AllowedOrigin = "<FLOWCHAIN_RPC_ALLOWED_ORIGIN>",
    [string] $DisallowedOrigin = "<FLOWCHAIN_RPC_DISALLOWED_ORIGIN>"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $RenderedConfig)) { throw "Rendered Nginx config was not found." }
if (-not (Test-Path -LiteralPath $NginxExe)) { throw "nginx.exe was not found." }
if (-not $PublicUrl.StartsWith("https://", [System.StringComparison]::OrdinalIgnoreCase)) { throw "FLOWCHAIN_RPC_PUBLIC_URL must be https." }
if ([string]::IsNullOrWhiteSpace($AllowedOrigin) -or -not $AllowedOrigin.StartsWith("https://", [System.StringComparison]::OrdinalIgnoreCase)) { throw "FLOWCHAIN_RPC_ALLOWED_ORIGIN must be an exact https origin." }
if ([string]::IsNullOrWhiteSpace($DisallowedOrigin) -or -not $DisallowedOrigin.StartsWith("https://", [System.StringComparison]::OrdinalIgnoreCase)) { throw "FLOWCHAIN_RPC_DISALLOWED_ORIGIN must be an exact https origin." }

$rendered = Get-Content -Raw -LiteralPath $RenderedConfig
$placeholderPattern = [regex]::Escape("<") + "(FLOWCHAIN_|PATH_TO_TLS_|FLOWCHAIN_NGINX_)"
if ($rendered -match $placeholderPattern) { throw "Rendered Nginx config still contains placeholders." }
@(
    "proxy_pass http://127.0.0.1:8787;",
    "limit_req_zone",
    "limit_req zone=flowchain_rpc_per_ip",
    "client_max_body_size 256k;",
    "client_body_timeout 10s;",
    "proxy_connect_timeout 5s;",
    "proxy_send_timeout 30s;",
    "proxy_read_timeout 60s;",
    "send_timeout 30s;",
    "ssl_certificate ",
    "ssl_certificate_key ",
    "server_tokens off;",
    "add_header Strict-Transport-Security ",
    "add_header X-Content-Type-Options ",
    "add_header Cache-Control ",
    "add_header Referrer-Policy ",
    "add_header X-Frame-Options ",
    "add_header Content-Security-Policy ",
    'proxy_set_header Origin $http_origin;',
    'proxy_set_header X-Forwarded-Proto https;',
    'proxy_set_header X-Forwarded-For $remote_addr;'
) | ForEach-Object {
    if ($rendered.IndexOf($_, [System.StringComparison]::Ordinal) -lt 0) {
        throw "Rendered Nginx config missing required token: $_"
    }
}

& $NginxExe -t
Invoke-RestMethod -Uri "http://127.0.0.1:8787/health" -Method Get -TimeoutSec 5 | Out-Null
$publicBase = $PublicUrl.TrimEnd("/")
$headers = @{ Origin = $AllowedOrigin }
Invoke-WebRequest -Uri "$publicBase/health" -Method Get -Headers $headers -TimeoutSec 10 | Out-Null
Invoke-WebRequest -Uri "$publicBase/rpc/readiness" -Method Get -Headers $headers -TimeoutSec 10 | Out-Null
$body = '{"jsonrpc":"2.0","id":1,"method":"rpc_readiness","params":{}}'
Invoke-WebRequest -Uri "$publicBase/rpc" -Method Post -ContentType "application/json" -Headers $headers -Body $body -TimeoutSec 10 | Out-Null
$rpcGetStatusCode = 0
try {
    Invoke-WebRequest -Uri "$publicBase/rpc" -Method Get -Headers $headers -TimeoutSec 10 | Out-Null
    $rpcGetStatusCode = 200
}
catch {
    if ($_.Exception.PSObject.Properties.Name -contains "Response" -and $null -ne $_.Exception.Response) {
        $rpcGetStatusCode = [int]$_.Exception.Response.StatusCode
    } else { throw }
}
if ($rpcGetStatusCode -ne 405) { throw "RPC endpoint GET preflight did not return HTTP 405." }
$readOnlyPostStatusCode = 0
try {
    Invoke-WebRequest -Uri "$publicBase/rpc/readiness" -Method Post -ContentType "application/json" -Headers $headers -Body "{}" -TimeoutSec 10 | Out-Null
    $readOnlyPostStatusCode = 200
}
catch {
    if ($_.Exception.PSObject.Properties.Name -contains "Response" -and $null -ne $_.Exception.Response) {
        $readOnlyPostStatusCode = [int]$_.Exception.Response.StatusCode
    } else { throw }
}
if ($readOnlyPostStatusCode -ne 405) { throw "Read-only RPC readiness POST preflight did not return HTTP 405." }
$disallowedStatusCode = 0
try {
    Invoke-WebRequest -Uri "$publicBase/rpc/readiness" -Method Get -Headers @{ Origin = $DisallowedOrigin } -TimeoutSec 10 | Out-Null
    $disallowedStatusCode = 200
}
catch {
    if ($_.Exception.PSObject.Properties.Name -contains "Response" -and $null -ne $_.Exception.Response) {
        $disallowedStatusCode = [int]$_.Exception.Response.StatusCode
    } else { throw }
}
if ($disallowedStatusCode -ne 403) { throw "Disallowed origin public preflight did not return HTTP 403." }
$blockedPathStatusCodes = @{}
foreach ($blockedPath in @("/devnet/local/state.json", "/wallets/create")) {
    try {
        Invoke-WebRequest -Uri "$publicBase$blockedPath" -Method Post -ContentType "application/json" -Headers $headers -Body "{}" -TimeoutSec 10 | Out-Null
        $blockedPathStatusCodes[$blockedPath] = 200
    }
    catch {
        if ($_.Exception.PSObject.Properties.Name -contains "Response" -and $null -ne $_.Exception.Response) {
            $blockedPathStatusCodes[$blockedPath] = [int]$_.Exception.Response.StatusCode
        } else { throw }
    }
}
if ($blockedPathStatusCodes["/devnet/local/state.json"] -ne 404) { throw "Broad local state path public preflight did not return HTTP 404." }
if ($blockedPathStatusCodes["/wallets/create"] -ne 404) { throw "Private wallet create path public preflight did not return HTTP 404." }
$testerStatus = Invoke-WebRequest -Uri "$publicBase/tester/status" -Method Get -Headers $headers -TimeoutSec 10
if ([int]$testerStatus.StatusCode -ne 200) { throw "Tester status preflight did not return HTTP 200." }
$testerUnauthStatusCode = 0
$testerUnauthBody = ""
try {
    Invoke-WebRequest -Uri "$publicBase/tester/wallets/create" -Method Post -ContentType "application/json" -Headers $headers -Body "{}" -TimeoutSec 10 | Out-Null
    $testerUnauthStatusCode = 200
}
catch {
    if ($_.Exception.PSObject.Properties.Name -contains "Response" -and $null -ne $_.Exception.Response) {
        $testerUnauthStatusCode = [int]$_.Exception.Response.StatusCode
        $stream = $_.Exception.Response.GetResponseStream()
        if ($null -ne $stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            try { $testerUnauthBody = $reader.ReadToEnd() } finally { $reader.Dispose() }
        }
    } else { throw }
}
if ($testerUnauthStatusCode -ne 401) { throw "Tester write unauthenticated preflight did not return HTTP 401." }
if ($testerUnauthBody.IndexOf("flowmemory.control_plane.tester_write_auth_required.v0", [System.StringComparison]::Ordinal) -lt 0) { throw "Tester write unauthenticated preflight did not return auth-required schema." }

Write-Host "FlowChain public RPC Windows Nginx preflight passed."
