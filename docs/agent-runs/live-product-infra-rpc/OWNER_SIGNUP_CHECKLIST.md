# FlowChain Owner Signup Checklist

Generated: 2026-05-21T02:05:30.6784434Z
Status: passed

FlowChain RPC is implemented by this repository. Do not sign up for a third-party FlowChain RPC provider. Public RPC means putting an owner-operated HTTPS edge in front of the private origin `127.0.0.1:8787`.

Put real values in a local service environment or an ignored `FLOWCHAIN_OWNER_ENV_FILE` file. Run `npm run flowchain:owner-env:template` to create the ignored local scaffold, run `npm run flowchain:owner-env:readiness:validate` to test path safety, then run `npm run flowchain:owner-env:readiness -- -AllowBlocked` after filling it. Do not paste private keys, wallet recovery material, provider API keys, tunnel tokens, TLS private keys, or secret-bearing RPC URLs into chat or committed files.

## Signup And Setup Items

| Item | External signup? | Acceptable options | Produces env names | Validation |
| --- | --- | --- | --- | --- |
| Public RPC domain or subdomain | True | Cloudflare-managed domain/subdomain, Existing registrar plus DNS provider, Owner-operated reverse proxy with valid TLS | FLOWCHAIN_RPC_PUBLIC_URL | npm run flowchain:public-rpc:check |
| HTTPS tunnel or reverse proxy to the private RPC origin | True | Cloudflare Tunnel public hostname, Nginx/Caddy/Traefik on an owner host, Load balancer that proxies to the private origin | FLOWCHAIN_RPC_TLS_TERMINATED | npm run flowchain:public-rpc:check |
| Allowed origins and public rate limit | False | Exact HTTPS app/tester origin list, Small pilot rate limit such as requests per minute per IP | FLOWCHAIN_RPC_ALLOWED_ORIGINS, FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE | npm run flowchain:public-rpc:check |
| Always-on host for the chain service | False | This machine if it stays online, Small VPS or cloud VM, Dedicated owner server |  | npm run flowchain:service:status |
| Writable backup storage | False | Mounted disk/volume, Owner-managed backup directory, Persistent path on the always-on host | FLOWCHAIN_RPC_STATE_BACKUP_PATH | npm run flowchain:backup:restore:validate; npm run flowchain:backup:check |
| External tester write token and send cap | False | Owner-generated random bearer token stored out of band, SHA-256 digest in ignored owner env file, Small per-send local test-unit cap | FLOWCHAIN_TESTER_WRITE_ENABLED, FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256, FLOWCHAIN_TESTER_MAX_SEND_UNITS | npm run flowchain:owner-inputs; npm run flowchain:external-tester:packet -- -AllowBlocked |
| Base mainnet RPC endpoint | True | Alchemy Base mainnet endpoint, QuickNode Base endpoint, Infura Base endpoint, Owner-operated Base node | FLOWCHAIN_BASE8453_RPC_URL | npm run flowchain:bridge:live:check |
| Base bridge pilot contract and caps | False | Owner-provided deployed lockbox and token addresses, Bootstrap Base from-block plus cursor-state scanning, Optional bounded upper block for one-off scans, Pilot caps and confirmations | FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS, FLOWCHAIN_BASE8453_SUPPORTED_TOKEN, FLOWCHAIN_BASE8453_ASSET_DECIMALS, FLOWCHAIN_BASE8453_FROM_BLOCK, FLOWCHAIN_BASE8453_CURSOR_STATE, FLOWCHAIN_BASE8453_TO_BLOCK, FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI, FLOWCHAIN_PILOT_TOTAL_CAP_WEI, FLOWCHAIN_PILOT_CONFIRMATIONS | npm run flowchain:bridge:live:check |
| Local owner env file | False | Ignored local NAME=value file referenced by FLOWCHAIN_OWNER_ENV_FILE, Process/service environment variables | FLOWCHAIN_OWNER_ENV_FILE | npm run flowchain:owner-env:template; npm run flowchain:owner-env:readiness:validate; npm run flowchain:owner-env:readiness -- -AllowBlocked; npm run flowchain:owner-inputs:validate |

## What You Need To Get

- Public RPC domain or subdomain: A public HTTPS URL for this FlowChain RPC edge, for example an rpc subdomain.
- HTTPS tunnel or reverse proxy to the private RPC origin: A TLS-terminating edge that routes public traffic to http://127.0.0.1:8787 on the host running FlowChain.
- Allowed origins and public rate limit: The exact HTTPS app origins allowed to call the public RPC and a positive per-minute request limit.
- Always-on host for the chain service: A host that can keep the node/control-plane running continuously and expose only the public edge, not raw private services.
- Writable backup storage: An existing writable directory path that the FlowChain service process can use for manifest-backed snapshots and restore rehearsals.
- External tester write token and send cap: A random tester bearer token for friends-and-family wallet writes, its SHA-256 hex digest for the owner env file, and a positive per-send local test-unit cap.
- Base mainnet RPC endpoint: A Base chain 8453 HTTPS JSON-RPC endpoint for read-only bridge observation.
- Base bridge pilot contract and caps: The bridge pilot lockbox/token details, bootstrap Base from-block, cursor-state location, optional one-off upper block, max deposit, total cap, confirmations, and explicit capped-pilot acknowledgement.
- Local owner env file: A local-only file path for real values, kept outside committed reports and loaded by the parser-only env-file importer. Run npm run flowchain:owner-env:template to create the ignored local scaffold, npm run flowchain:owner-env:readiness:validate to test path safety, then npm run flowchain:owner-env:readiness -- -AllowBlocked to verify it.

## Do Not Send

- Registrar password
- Cloudflare account password
- raw TLS private key
- Tunnel token
- TLS certificate private key
- admin dashboard session cookie
- Wildcard CORS policy
- unbounded public rate limit
- SSH private key
- root password
- Cloud backup access key
- storage account secret
- Raw tester bearer token in chat or GitHub
- owner env file contents
- token hash and raw token together
- Provider dashboard password
- API key pasted into chat
- billing credential
- Private key for deploying or controlling contracts
- wallet recovery words
- wallet recovery material
- The env file contents in chat
- provider URLs that contain secret tokens

## Remaining Env Inputs

- FLOWCHAIN_RPC_PUBLIC_URL: missing
- FLOWCHAIN_RPC_ALLOWED_ORIGINS: missing
- FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE: missing
- FLOWCHAIN_RPC_TLS_TERMINATED: missing
- FLOWCHAIN_RPC_STATE_BACKUP_PATH: missing
- FLOWCHAIN_TESTER_WRITE_ENABLED: not flagged by latest owner input report
- FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256: not flagged by latest owner input report
- FLOWCHAIN_TESTER_MAX_SEND_UNITS: not flagged by latest owner input report
- FLOWCHAIN_PILOT_OPERATOR_ACK: missing
- FLOWCHAIN_BASE8453_RPC_URL: missing
- FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS: missing
- FLOWCHAIN_BASE8453_SUPPORTED_TOKEN: missing
- FLOWCHAIN_BASE8453_ASSET_DECIMALS: missing
- FLOWCHAIN_BASE8453_FROM_BLOCK: missing
- FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI: missing
- FLOWCHAIN_PILOT_TOTAL_CAP_WEI: missing
- FLOWCHAIN_PILOT_CONFIRMATIONS: missing
