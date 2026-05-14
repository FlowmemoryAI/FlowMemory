# Dashboard MVP

FlowMemory Dashboard V0 is a local React/Vite operator app under `apps/dashboard/`. It visualizes fixture data for the first app-facing explorer surface and acts as the local FlowChain workbench when the control-plane API is running. The workbench now has Product Testnet V1 surfaces for wallet public state, local balances, token launch records, token balances, DEX pools, liquidity, swaps, explorer records, and bridge-test records. It does not introduce production wallet custody, production tokenomics, production DEX claims, or live value-bearing bridge claims.

## Scope

The MVP covers local inspection of:

- Local control-plane health and state from `http://127.0.0.1:8787/health`, `/state`, and `/rpc`
- Node status, peers, mempool, accounts, local balances, faucet events, public wallet references, and setup status
- Product Testnet V1 wallet/account public state, local/test token launch records, token balances, DEX pools, liquidity positions, swaps, and unified explorer rollups
- FlowPulse observations from indexer-style receipt/log data
- Rootfield registry state
- Work lanes and work receipts
- Verifier modules and verifier reports
- Transactions, memory cells, challenges, finality rows, and bridge test-lane records when exported or loaded from the bridge test fixture
- Devnet blocks and state roots
- Hardware node heartbeats
- Alerts and incidents
- Raw JSON fixture data

## Fixture Contract

Canonical fixture:

```text
fixtures/dashboard/flowmemory-dashboard-v0.json
```

Runtime copy loaded by Vite:

```text
apps/dashboard/public/data/flowmemory-dashboard-v0.json
apps/dashboard/public/data/flowchain-local-devnet-state.json
apps/dashboard/public/data/flowchain-local-devnet-dashboard-state.json
apps/dashboard/public/data/flowchain-bridge-test-deposit.json
```

Copy command:

```powershell
npm run sync:fixtures --prefix apps/dashboard
```

Each displayed object should include:

- `id` or hash
- `status`
- `lastUpdated` when available
- `provenance.subsystem`
- `provenance.origin`
- `provenance.chainContext`
- fixture or generated local path hints when known

## Future Generated Inputs

Future local jobs can write generated data here before a live API exists:

```text
fixtures/dashboard/generated/indexer-state.json
fixtures/dashboard/generated/verifier-reports.json
fixtures/dashboard/generated/devnet-state.json
fixtures/dashboard/generated/hardware-heartbeats.json
```

The app should keep treating those files as local/fixture data until a separate API decision defines authentication, caching, freshness, and failure semantics.

When `npm run control-plane:serve` is running, the workbench probes:

```text
GET http://127.0.0.1:8787/health
GET http://127.0.0.1:8787/state
POST http://127.0.0.1:8787/rpc
```

The JSON-RPC batch reads live local objects with the documented read-only control-plane methods. If `/rpc` is not available but `/health` or `/state` responds, the UI keeps the API status visible and falls back to deterministic public fixtures for missing object tables.

The first screen includes action cards for refresh, local faucet request, sample transaction, and bridge test-deposit inspection. Refresh is available when the control-plane API responds. The submit/inspect actions stay disabled unless the API advertises a matching local-only method; the dashboard does not invent write methods and does not handle signing keys.

The Product Testnet V1 surface uses the same pattern. Token launch, DEX pool,
liquidity, swap, and bridge action buttons only appear when the local
control-plane advertises the matching endpoint. The workbench may display empty
tables with exact recovery commands until runtime/control-plane agents export
those objects.

## Non-Goals

- No backend service required for V0
- No wallet connect
- No private-key handling in the browser
- No private keys, mnemonics, seeds, or signing secrets in browser localStorage
- No token price, TVL, rewards, staking, or market data
- No production token launch, production liquidity, or production swap claim
- No production monitoring claims
- No production bridge or real-funds claim
- No secrets or RPC credentials
- No contract, service, or hardware behavior changes

## Local Checks

From `apps/dashboard/`:

```powershell
npm install
npm run typecheck
npm test
npm run build
```
