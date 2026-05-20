# FlowChain Node Operator Package

Generated: 2026-05-20T08:48:05.6645264Z

This package collects no-secret runbooks, command matrices, and current evidence for operating the private live-profile FlowChain L1 and for preparing the owner-operated public RPC edge. It does not contain owner values.

## First Commands

- `npm run flowchain:prereq`
- `npm run flowchain:doctor`
- `npm run flowchain:service:start -- -LiveProfile`
- `npm run flowchain:service:status -- -AllowBlocked`
- `npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30`
- `npm run flowchain:service:restart -- -LiveProfile`
- `npm run flowchain:service:stop`
- `npm run flowchain:service:supervisor:validate`
- `npm run flowchain:service:install:windows -- -Action Plan`
- `npm run flowchain:service:install:validate`

## Public Launch Boundary

Public sharing stays blocked until these owner inputs are configured outside the repository:

- FLOWCHAIN_RPC_PUBLIC_URL
- FLOWCHAIN_RPC_ALLOWED_ORIGINS
- FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE
- FLOWCHAIN_RPC_TLS_TERMINATED
- FLOWCHAIN_RPC_STATE_BACKUP_PATH
- FLOWCHAIN_TESTER_WRITE_ENABLED
- FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256
- FLOWCHAIN_TESTER_MAX_SEND_UNITS
- FLOWCHAIN_PILOT_OPERATOR_ACK
- FLOWCHAIN_BASE8453_RPC_URL
- FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS
- FLOWCHAIN_BASE8453_SUPPORTED_TOKEN
- FLOWCHAIN_BASE8453_ASSET_DECIMALS
- FLOWCHAIN_BASE8453_FROM_BLOCK
- FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI
- FLOWCHAIN_PILOT_TOTAL_CAP_WEI
- FLOWCHAIN_PILOT_CONFIRMATIONS

FlowChain RPC is repo-owned. The public endpoint is an owner-operated HTTPS edge in front of the private local origin, not a third-party FlowChain RPC provider.

## Package Contents

- `OPERATOR_PACKAGE_MANIFEST.json`
- `OPERATOR_COMMAND_MATRIX.json`
- `COMMAND_MATRIX.md`
- `docs/` copied developer and operations docs
- `runbooks/` copied generated public RPC, service, backup, alert, activation, dashboard, dev-pack, and tester packet runbooks
- `evidence/` copied latest readiness and validation reports
