# FlowChain Public RPC Deployment Bundle

Generated: 2026-05-16T13:38:53.1546096Z
Status: passed

This bundle packages placeholder-only files for an owner-operated HTTPS edge in front of the repo-owned private RPC origin `127.0.0.1:8787`.

## Files

- README.md
- nginx-flowchain-rpc.template.conf
- owner-public-rpc.env.example
- VERIFY.md
- ROLLBACK.md

## Required Env Names

- FLOWCHAIN_RPC_PUBLIC_URL
- FLOWCHAIN_RPC_ALLOWED_ORIGINS
- FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE
- FLOWCHAIN_RPC_TLS_TERMINATED
- FLOWCHAIN_RPC_STATE_BACKUP_PATH

## Verification Commands

- npm run flowchain:service:restart -- -LiveProfile
- npm run flowchain:service:status
- npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30
- npm run flowchain:ops:snapshot -- -AllowBlocked
- npm run flowchain:public-rpc:validate
- npm run flowchain:public-rpc:check
- npm run flowchain:backup:restore:validate
- npm run flowchain:backup:check
- npm run flowchain:public-deployment:contract -- -AllowBlocked
- npm run flowchain:external-tester:packet -- -AllowBlocked

## Rollback Commands

- npm run flowchain:ops:snapshot -- -AllowBlocked
- npm run flowchain:service:status
- npm run flowchain:service:restart -- -LiveProfile
- npm run flowchain:service:stop
- npm run flowchain:emergency:stop-local
