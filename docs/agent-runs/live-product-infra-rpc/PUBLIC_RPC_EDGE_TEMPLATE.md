# FlowChain Public RPC Edge Template

Generated: 2026-05-16T04:56:27.4864730Z
Status: passed

FlowChain RPC is served by this repository on the private origin 127.0.0.1:8787. Public RPC means placing an owner-operated HTTPS edge in front of that origin.

This file contains placeholders only. Replace placeholders only on the owner host and keep rendered configs out of the repository.

## Requirements

| Requirement | Status | Evidence |
| --- | --- | --- |
| Proxy points to the repo-owned private FlowChain RPC origin. | passed | privateOrigin=127.0.0.1:8787 |
| Public traffic terminates TLS before reaching the private origin. | passed | template includes HTTPS listener and HTTP redirect |
| Public requests are rate-limited before they reach the private origin. | passed | template includes limit_req zone tied to FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE |
| Browser Origin headers and the edge-confirmed client address are forwarded so CORS and per-client rate limits can be enforced. | passed | template forwards Origin, Host, X-Forwarded-Proto, and sets X-Forwarded-For from the edge remote address |
| Template stores placeholders and env names only. | passed | valuesPrinted=false |

## Nginx Template

```nginx
# FlowChain public RPC edge template.
# Replace placeholders only in the owner host environment. Do not commit rendered configs.
limit_req_zone $binary_remote_addr zone=flowchain_rpc_per_ip:10m rate=<FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE>r/m;

server {
    listen 80;
    server_name <FLOWCHAIN_RPC_PUBLIC_HOST>;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name <FLOWCHAIN_RPC_PUBLIC_HOST>;

    ssl_certificate <PATH_TO_TLS_CERTIFICATE>;
    ssl_certificate_key <PATH_TO_TLS_CERTIFICATE_KEY>;

    access_log off;

    location / {
        limit_req zone=flowchain_rpc_per_ip burst=20 nodelay;
        proxy_pass http://127.0.0.1:8787;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header Origin $http_origin;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_read_timeout 60s;
    }
}
```

## Required Local Env Names

- FLOWCHAIN_RPC_PUBLIC_URL
- FLOWCHAIN_RPC_ALLOWED_ORIGINS
- FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE
- FLOWCHAIN_RPC_TLS_TERMINATED

## Verification Commands

- npm run flowchain:service:restart -- -LiveProfile
- npm run flowchain:service:status
- npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30
- npm run flowchain:public-rpc:validate
- npm run flowchain:public-rpc:check
- npm run flowchain:public-deployment:contract -- -AllowBlocked
