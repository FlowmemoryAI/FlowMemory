# FlowChain Developer Troubleshooting

## Failed To Fetch

Check that the control-plane RPC is running:

```powershell
npm run control-plane:serve
node tools/flowchain-devkit.mjs discover --json
```

The default SDK URL is:

```text
http://127.0.0.1:8787/rpc
```

## 404 On Wallet Creation Or RPC Path

Wallet HTTP helpers are exposed by `services/control-plane/src/server.ts`.
Use:

```text
POST /wallets/create
POST /rpc
GET /rpc/discover
GET /rpc/readiness
```

Do not post JSON-RPC envelopes to `/wallets/create`, and do not post wallet
creation payloads to `/rpc`.

## Missing Public RPC Env

`rpc_readiness` reports public RPC blockers by name:

- `FLOWCHAIN_RPC_PUBLIC_URL`
- `FLOWCHAIN_RPC_ALLOWED_ORIGINS`
- `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`
- `FLOWCHAIN_RPC_TLS_TERMINATED`
- `FLOWCHAIN_RPC_STATE_BACKUP_PATH`

The SDK and CLI must not print values.

## Bridge Blocked On Base 8453 Inputs

Run:

```powershell
node tools/flowchain-devkit.mjs bridge-readiness --json
```

The live path remains blocked until the `FLOWCHAIN_BASE8453_*` and
`FLOWCHAIN_PILOT_*` names from `docs/developer/bridge-integration.md` are
configured locally.

## Local Node Stopped Or Max-Block Bounded Mode

If the node stopped after a bounded run:

```powershell
npm run flowchain:node:start
npm run flowchain:node:status
```

For one block:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/state.json run --blocks 1
```

## Stale Dashboard Or Wrong Endpoint

Verify the endpoint and method inventory:

```powershell
node tools/flowchain-devkit.mjs discover --json
node tools/flowchain-devkit.mjs chain-status --json
```

For browser apps, pass the local RPC explicitly if needed:

```text
http://127.0.0.1:5173/?rpc=http://127.0.0.1:8787/rpc
```
