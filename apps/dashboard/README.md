# FlowMemory Dashboard V0

Local operator/explorer app for inspecting FlowMemory V0 fixture output. It is intentionally fixture-backed and does not claim production live data, wallet support, token pricing, or hosted deployment.

## Run Locally

From this directory:

```powershell
npm install
npm run dev
```

Default Vite URL:

```text
http://127.0.0.1:5173/
```

Useful checks:

```powershell
npm run typecheck
npm test
npm run build
```

## Data Boundary

The canonical dashboard fixture lives at:

```text
fixtures/dashboard/flowmemory-dashboard-v0.json
```

The app loads its runtime copy from:

```text
apps/dashboard/public/data/flowmemory-dashboard-v0.json
```

The `dev` and `build` scripts run `npm run sync:fixtures`, which copies the canonical fixture into the Vite public data folder before the app starts or builds.

Future generated local outputs should land under the fixture boundary first:

```text
fixtures/dashboard/generated/indexer-state.json
fixtures/dashboard/generated/verifier-reports.json
fixtures/dashboard/generated/devnet-state.json
fixtures/dashboard/generated/hardware-heartbeats.json
```

The dashboard schema can then be updated to merge those generated files into `flowmemory-dashboard-v0.json` or replace the loader with a local API once that boundary exists.

## Current Views

- Overview
- FlowPulse stream
- Rootfields
- Work lanes and receipts
- Verifier reports
- Devnet blocks
- Hardware nodes
- Alerts
- Raw JSON inspector

Every displayed record carries source subsystem, fixture/local origin, chain context, ID/hash, status, and last-updated metadata when available.

## Status Vocabulary

Dashboard V0 visually distinguishes:

```text
observed, pending, finalized, verified, unresolved, invalid, unsupported, reorged, offline, stale
```

These are app-facing display states for local fixture inspection. They should stay aligned with indexer and verifier terminology as those packages mature.
