# Dashboard MVP

FlowMemory Dashboard V0 is a local React/Vite operator app under `apps/dashboard/`. It visualizes fixture data for the first app-facing explorer surface and acts as the local FlowChain workbench when the control-plane API is running. The workbench now has Product Testnet V1 surfaces for wallet public state, local balances, token launch records, token balances, DEX pools, liquidity, swaps, explorer records, bridge-test records, and capped owner-testing real-value pilot evidence. It does not introduce production wallet custody, production tokenomics, production DEX claims, broad public readiness, or production bridge claims.

## Scope

The MVP covers local inspection of:

- Local control-plane health and state from `http://127.0.0.1:8787/health`, `/state`, and `/rpc`
- Node status, peers, mempool, accounts, local balances, faucet events, public wallet references, and setup status
- Product Testnet V1 wallet/account public state, local/test token launch records, token balances, DEX pools, liquidity positions, swaps, and unified explorer rollups
- Real-value pilot status for capped owner testing: Base 8453 live readiness, missing env names without values, Base deposit observation, exact local credit, wallet transferability, withdrawal/release evidence, caps, pause, emergency state, and exact next operator command
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
GET http://127.0.0.1:8787/pilot/status
GET http://127.0.0.1:8787/bridge/live-readiness
GET http://127.0.0.1:8787/pilot/lifecycle
GET http://127.0.0.1:8787/wallets/balances
GET http://127.0.0.1:8787/wallets/transfers
POST http://127.0.0.1:8787/rpc
```

The JSON-RPC batch reads live local objects with the documented read-only control-plane methods. If `/rpc` is not available but `/health` or `/state` responds, the UI keeps the API status visible and falls back to deterministic public fixtures for missing object tables.

The first screen includes action cards for refresh, local faucet request, sample transaction, and bridge test-deposit inspection. Refresh is available when the control-plane API responds. The submit/inspect actions stay disabled unless the API advertises a matching local-only method; the dashboard does not invent write methods and does not handle signing keys.

The Product Testnet V1 surface uses the same pattern. Token launch, DEX pool,
liquidity, swap, and bridge action buttons only appear when the local
control-plane advertises the matching endpoint. The workbench may display empty
tables with exact recovery commands until runtime/control-plane agents export
those objects.

The real-value pilot panel is explicitly labeled `capped owner testing`. It
renders the control-plane `live`, `degraded`, or `error` state exactly, shows
the next operator command from the API, and displays whether public readiness is
false and whether the browser stores secrets. The browser must not write private
keys, mnemonics, seed phrases, RPC credentials, API keys, or webhooks to
localStorage/sessionStorage; it only consumes browser-safe control-plane
responses and fixture data.

The first screen also includes a `Bridge live readiness` panel. It shows
`BLOCKED`, `FAILED`, or `READY_FOR_OPERATOR_LIVE_PILOT`, Base chain ID `8453`,
whether the local node is running, whether the lockbox is configured, whether
confirmation depth is configured, and missing env names. It never renders env
values. Mock/local artifacts remain labeled as local or mock; the live panel
must not present mock data as real.

The `Real-Value Pilot` workbench table includes lifecycle records from
`/pilot/lifecycle`, exact value equality for deposit, observed, credited, wallet
delta, transferable, withdrawal, and release amounts, wallet balances from
`/wallets/balances`, and transfer history from `/wallets/transfers`. The global
search field can filter visible records by Base tx hash, credit id, wallet
address, and status.

## Non-Goals

- No backend service required for V0
- No wallet connect
- No private-key handling in the browser
- No private keys, mnemonics, seeds, or signing secrets in browser localStorage
- No token price, TVL, rewards, staking, or market data
- No production token launch, production liquidity, or production swap claim
- No production monitoring claims
- No production bridge or real-funds claim
- No broad public readiness claim for the capped owner-testing pilot
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
