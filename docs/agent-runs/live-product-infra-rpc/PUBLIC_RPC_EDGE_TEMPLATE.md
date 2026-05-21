# FlowChain Public RPC Edge Template

Generated: 2026-05-21T10:56:37.9367467Z
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
| Public /rpc dispatch is fail-closed to explicitly public-safe JSON-RPC read methods. | passed | origin enforces explicit allowlist and rejects transaction_submit, bridge_observation_submit, raw_json_get, devnet_state, and unknown methods |
| The public edge does not proxy private write or admin routes; tester writes use the authenticated tester gateway only. | passed | template exposes /rpc, explicit read mirrors excluding /state, /tester/faucet, and /tester/wallets/create/send; fallback location returns 404 |
| Friends-and-family wallet creation, faucet funding, and sends have a dedicated bearer-authenticated gateway with a unit cap. | passed | origin requires FLOWCHAIN_TESTER_WRITE_* env names and bearer auth before /tester/faucet, /tester/wallets/create, or /tester/wallets/send executes |
| Oversized public request bodies are rejected before they reach the private origin. | passed | template sets client_max_body_size 256k and origin enforces 262144-byte JSON body cap |
| Public edge responses include baseline browser and cache hardening headers. | passed | template sets HSTS, no-sniff, no-store, frame denial, referrer policy, and a default-deny CSP |
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
    client_max_body_size 256k;
    server_tokens off;
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Cache-Control "no-store" always;
    add_header Referrer-Policy "no-referrer" always;
    add_header X-Frame-Options "DENY" always;
    add_header Content-Security-Policy "default-src 'none'; frame-ancestors 'none'; base-uri 'none'" always;

    location = /rpc {
        if ($request_method !~ ^(POST|OPTIONS)$) { return 405; }
        limit_req zone=flowchain_rpc_per_ip burst=20 nodelay;
        proxy_pass http://127.0.0.1:8787;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header Origin $http_origin;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_read_timeout 60s;
    }

    location ~ ^/(health|explorer/summary|chain/status|product-flow/status|bridge/(live-readiness|status|credits|credit-status|observations)|wallets/(balances|transfers|operator)|pilot/(status|lifecycle|deposits|credits|withdrawal-intents|release-evidence|cap-status|pause-status|retry-status|emergency-status))$ {
        if ($request_method !~ ^(GET|OPTIONS)$) { return 405; }
        limit_req zone=flowchain_rpc_per_ip burst=20 nodelay;
        proxy_pass http://127.0.0.1:8787;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header Origin $http_origin;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_read_timeout 60s;
    }

    location ~ ^/tester/(faucet|wallets/(create|send))$ {
        if ($request_method !~ ^(POST|OPTIONS)$) { return 405; }
        limit_req zone=flowchain_rpc_per_ip burst=5 nodelay;
        proxy_pass http://127.0.0.1:8787;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header Origin $http_origin;
        proxy_set_header Authorization $http_authorization;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_read_timeout 60s;
    }

    location = /tester/status {
        if ($request_method !~ ^(GET|OPTIONS)$) { return 405; }
        limit_req zone=flowchain_rpc_per_ip burst=20 nodelay;
        proxy_pass http://127.0.0.1:8787;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header Origin $http_origin;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_read_timeout 60s;
    }

    location ~ ^/rpc/(discover|readiness)$ {
        if ($request_method !~ ^(GET|OPTIONS)$) { return 405; }
        limit_req zone=flowchain_rpc_per_ip burst=20 nodelay;
        proxy_pass http://127.0.0.1:8787;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header Origin $http_origin;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_read_timeout 60s;
    }

    location / {
        return 404;
    }
}
```

## Public JSON-RPC Method Allowlist

The origin only dispatches these public-safe JSON-RPC read methods through /rpc; any other method fails closed before local handlers run.

- rpc_discover
- rpc_readiness
- health
- node_status
- peer_list
- chain_status
- bridge_live_readiness
- bridge_status
- pilot_status
- pilot_deposit_observation_list
- pilot_credit_list
- pilot_withdrawal_intent_list
- pilot_release_evidence_list
- pilot_cap_status
- pilot_pause_status
- pilot_retry_status
- pilot_emergency_status
- pilot_lifecycle_record_list
- wallet_balance_list
- wallet_transfer_history
- block_get
- block_list
- mempool_list
- transaction_get
- transaction_list
- account_get
- account_list
- balance_get
- token_get
- token_list
- token_balance_get
- token_balance_list
- pool_get
- pool_list
- lp_position_get
- lp_position_list
- swap_get
- swap_list
- product_flow_status
- faucet_event_list
- wallet_metadata_get
- wallet_metadata_list
- rootfield_get
- rootfield_list
- artifact_availability_get
- artifact_availability_list
- receipt_get
- receipt_list
- work_receipt_get
- work_receipt_list
- verifier_module_get
- verifier_module_list
- verifier_report_get
- verifier_report_list
- memory_cell_get
- memory_cell_list
- agent_get
- agent_list
- model_get
- model_list
- challenge_get
- challenge_list
- finality_get
- finality_list
- bridge_observation_get
- bridge_observation_list
- bridge_deposit_get
- bridge_deposit_list
- bridge_credit_get
- bridge_credit_list
- bridge_credit_status
- withdrawal_get
- withdrawal_list
- provenance_get

## Explicitly Rejected JSON-RPC Methods

- transaction_submit
- bridge_observation_submit
- raw_json_get
- devnet_state

## Public Read Mirror Paths

The local /state mirror is intentionally excluded from the public edge; use specific JSON-RPC read methods or explorer mirror paths instead.

- /health
- /rpc/discover
- /rpc/readiness
- /explorer/summary
- /chain/status
- /product-flow/status
- /bridge/live-readiness
- /bridge/status
- /bridge/credits
- /bridge/credit-status
- /bridge/observations
- /wallets/balances
- /wallets/transfers
- /wallets/operator
- /tester/status
- /pilot/status
- /pilot/lifecycle
- /pilot/deposits
- /pilot/credits
- /pilot/withdrawal-intents
- /pilot/release-evidence
- /pilot/cap-status
- /pilot/pause-status
- /pilot/retry-status
- /pilot/emergency-status

## Authenticated Tester Write Paths

These paths are for capped friends-and-family pilot sends only. The origin rejects them unless FLOWCHAIN_TESTER_WRITE_ENABLED=true, a bearer token matching FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256 is provided, and FLOWCHAIN_TESTER_MAX_SEND_UNITS caps the send amount.

- /tester/faucet
- /tester/wallets/create
- /tester/wallets/send

## Required Local Env Names

- FLOWCHAIN_RPC_PUBLIC_URL
- FLOWCHAIN_RPC_ALLOWED_ORIGINS
- FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE
- FLOWCHAIN_RPC_TLS_TERMINATED
- FLOWCHAIN_TESTER_WRITE_ENABLED
- FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256
- FLOWCHAIN_TESTER_MAX_SEND_UNITS

## Verification Commands

- npm run flowchain:service:restart -- -LiveProfile
- npm run flowchain:service:status
- npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30
- npm run flowchain:public-rpc:validate
- npm run flowchain:public-rpc:check
- npm run flowchain:public-deployment:contract -- -AllowBlocked
