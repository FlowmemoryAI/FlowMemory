# FlowChain L1 Pilot Explorer Dashboard Plan

## Scope

- Worktree: `E:\FlowMemory\flowmemory-prod-explorer-dashboard`
- Branch: `agent/production-l1-explorer-dashboard`
- Allowed implementation areas: `services/indexer/`, `services/control-plane/`, `services/shared/`, `apps/dashboard/`, `schemas/flowmemory/`, `fixtures/dashboard/`, `docs/DASHBOARD_MVP.md`, `docs/FLOWCHAIN_CONTROL_PLANE_API.md`, this agent-run directory, and root `package.json` only for explorer/dashboard aliases.
- Forbidden areas: crates implementation, contracts, crypto secret internals, hardware, and committed local secrets.

## Phases

1. Inventory existing indexer, control-plane, dashboard, fixtures, schemas, and package commands.
2. Define the explorer data contract and source routes.
3. Extend fixture-backed indexing and control-plane explorer/search surfaces for L1 blocks, transactions, receipts, events, accounts, tokens, DEX, bridge, finality, health, and errors.
4. Update the existing dashboard to render all owner-facing L1 pilot explorer surfaces with explicit provenance and degraded/offline states; this does not claim public production readiness.
5. Add search coverage for block height/hash, transaction IDs, accounts, tokens, pools, bridge observations, credits, withdrawal intents, Base tx hashes, transfer/swap tx IDs, and release evidence.
6. Add operator-safe UI and no-secret browser-state checks.
7. Verify desktop/mobile rendering and save screenshot or DOM evidence in this directory.
8. Run requested tests/builds/smokes/E2E commands and document any unavailable runtime dependencies.

## Guardrails

- Do not create a second API or second dashboard.
- Do not request, display, persist, or fixture secret-shaped values.
- Do not label fallback data as live runtime data.
- Preserve provenance for live runtime, fixture fallback, Base observation, and local import records.
- Keep production readiness and bridge claims constrained to capped owner-testing/local-private testnet language.
