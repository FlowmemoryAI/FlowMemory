# FlowChain Developer Quickstart

This path starts from a clean checkout and uses local-only FlowChain runtime
state. It does not configure public RPC or live Base 8453 bridging.

## Prerequisites

- Node.js `>=20.19.0`
- npm
- Rust and Cargo
- PowerShell on Windows

Install local dependencies:

```powershell
npm install
npm install --prefix crypto
```

## Start Local Node And RPC

Initialize local state:

```powershell
npm run flowchain:init
```

Start a local node on loopback-backed file state:

```powershell
npm run flowchain:node:start
```

Start the control-plane RPC on `127.0.0.1:8787`:

```powershell
npm run control-plane:serve
```

Discover RPC methods:

```powershell
node tools/flowchain-devkit.mjs discover --json
```

Print readiness:

```powershell
node tools/flowchain-devkit.mjs readiness --json
```

Public RPC readiness should remain blocked until these deployment names are
configured: `FLOWCHAIN_RPC_PUBLIC_URL`, `FLOWCHAIN_RPC_ALLOWED_ORIGINS`,
`FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`, `FLOWCHAIN_RPC_TLS_TERMINATED`, and
`FLOWCHAIN_RPC_STATE_BACKUP_PATH`.

## Create Local Account Metadata

Create public local account metadata without custody material:

```powershell
node tools/flowchain-devkit.mjs account create-local --account-id local-account:alice --json
```

Create the matching local runtime balance row:

```powershell
node tools/flowchain-devkit.mjs account create-local --account-id local-account:alice --submit --json
```

## Submit A Transaction

Run the Node example. It submits signed local envelopes through
`transaction_submit`, produces a block with the local Rust runtime, and reads the
updated balances:

```powershell
node examples/flowchain-node-local/index.mjs
```

Submit a transfer with the CLI:

```powershell
node tools/flowchain-devkit.mjs submit-transfer --from local-account:alice --to local-account:bob --amount 1 --json
```

Produce or wait for a block:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/state.json run --blocks 1
node tools/flowchain-devkit.mjs wait-inclusion --tx-id <tx-id> --json
```

Query balances and finality:

```powershell
node tools/flowchain-devkit.mjs balance --account-id local-account:alice --json
node tools/flowchain-devkit.mjs finality --object-id <object-id> --json
```

## Restart And Verify Continuity

```powershell
npm run flowchain:node:restart
npm run flowchain:node:status
node tools/flowchain-devkit.mjs chain-status --json
```

## Verify The SDK Path

```powershell
npm run flowchain:sdk:e2e
```

The report is written to:

```text
docs/agent-runs/live-product-sdk-docs/flowchain-sdk-e2e-report.json
```
