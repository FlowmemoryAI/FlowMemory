# Dashboard MVP

FlowMemory Dashboard V0 is a local React/Vite operator app under `apps/dashboard/`. It visualizes fixture data for the first app-facing explorer surface and acts as the local FlowChain workbench when the control-plane API is running. It does not introduce production wallet flows, token data, or live network claims.

## Scope

The MVP covers local inspection of:

- Local control-plane health and state from `http://127.0.0.1:8787/health`, `/state`, and `/rpc`
- Node status, peers, mempool, accounts, balances, faucet events, public wallet references, and setup status
- FlowPulse observations from indexer-style receipt/log data
- Rootfield registry state
- Work lanes and work receipts
- Verifier modules and verifier reports
- Transactions, memory cells, challenges, finality rows, and bridge test-lane records when exported
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

## Non-Goals

- No backend service required for V0
- No wallet connect
- No private-key handling in the browser
- No token price, TVL, rewards, staking, or market data
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
