# Dashboard MVP

FlowMemory Dashboard V0 is a local React/Vite operator app under `apps/dashboard/`. It visualizes fixture data for the first app-facing explorer surface without introducing production APIs, wallet flows, token data, or live network claims.

## Scope

The MVP covers local inspection of:

- FlowPulse observations from indexer-style receipt/log data
- Rootfield registry state
- Work lanes and work receipts
- Verifier reports
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

## Non-Goals

- No backend service required for V0
- No wallet connect
- No token price, TVL, rewards, staking, or market data
- No production monitoring claims
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
