param(
    [string] $RenderedConfig = "<FLOWCHAIN_RPC_NGINX_RENDERED_CONF>",
    [string] $NginxExe = "<FLOWCHAIN_NGINX_EXE>",
    [string] $PublicUrl = "<FLOWCHAIN_RPC_PUBLIC_URL>",
    [string] $AllowedOrigin = "<FLOWCHAIN_RPC_ALLOWED_ORIGIN>"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $RenderedConfig)) { throw "Rendered Nginx config was not found." }
if (-not (Test-Path -LiteralPath $NginxExe)) { throw "nginx.exe was not found." }
if (-not $PublicUrl.StartsWith("https://", [System.StringComparison]::OrdinalIgnoreCase)) { throw "FLOWCHAIN_RPC_PUBLIC_URL must be https." }
if ([string]::IsNullOrWhiteSpace($AllowedOrigin) -or -not $AllowedOrigin.StartsWith("https://", [System.StringComparison]::OrdinalIgnoreCase)) { throw "FLOWCHAIN_RPC_ALLOWED_ORIGIN must be an exact https origin." }

$rendered = Get-Content -Raw -LiteralPath $RenderedConfig
if ($rendered -match "<FLOWCHAIN_|<PATH_TO_TLS_|<FLOWCHAIN_NGINX_") { throw "Rendered Nginx config still contains placeholders." }
@(
    "proxy_pass http://127.0.0.1:8787;",
    "limit_req_zone",
    "limit_req zone=flowchain_rpc_per_ip",
    "ssl_certificate ",
    "ssl_certificate_key ",
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

Write-Host "FlowChain public RPC Windows Nginx preflight passed."
