# Node Operator Guide

This guide is for local/private FlowChain operation.

## Local Start / Stop / Restart

```powershell
npm run flowchain:init
npm run flowchain:node:start
npm run flowchain:node:status
npm run flowchain:node:stop
npm run flowchain:node:restart
```

Bounded local mode:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/state.json run --blocks 1
```

## Unbounded / Pilot Node Mode

```powershell
npm run flowchain:node:start -- --MaxBlocks 0
```

Keep this bound to local interfaces unless a separate public RPC deployment
review approves otherwise.

## Public RPC Prerequisites

`rpc_readiness` must not report public RPC ready until these names are present:

- `FLOWCHAIN_RPC_PUBLIC_URL`
- `FLOWCHAIN_RPC_ALLOWED_ORIGINS`
- `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`
- `FLOWCHAIN_RPC_TLS_TERMINATED`
- `FLOWCHAIN_RPC_STATE_BACKUP_PATH`

## TLS, CORS, And Rate Limits

The local control-plane server exposes permissive CORS for local browser
testing. A public deployment needs TLS termination, explicit allowed origins,
and rate limiting before it can be considered configured.

## State Backup

Default local state:

```text
devnet/local/state.json
```

Export and import:

```powershell
npm run flowchain:export
npm run flowchain:import
```

For isolated SDK testing, set:

```powershell
$env:FLOWCHAIN_CONTROL_PLANE_LOCAL_DEVNET_PATH="devnet/local/sdk-e2e/runtime/state.json"
```

## Health And Monitoring

Use:

```powershell
node tools/flowchain-devkit.mjs readiness --json
node tools/flowchain-devkit.mjs chain-status --json
node tools/flowchain-devkit.mjs discover --json
```

Monitor `localRuntimeReadable`, `sourceStatuses`, `currentBlock`,
`finalizedBlock`, and bridge readiness status.
