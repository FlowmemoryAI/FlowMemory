# Real-Value Pilot Control-Plane/Dashboard Checklist

## Required Tracking

- [x] Read required repository source-of-truth docs.
- [x] Confirm branch and initially clean worktree before edits.
- [x] Inspect current `services/control-plane`.
- [x] Inspect current `apps/dashboard`.
- [x] Inspect active `E:\FlowMemory\flowmemory-indexer` long-loop work.
- [x] Inspect active `E:\FlowMemory\flowmemory-dashboard` long-loop work.
- [x] Inspect bridge relayer and runtime handoff shapes.
- [x] Implement pilot lifecycle API methods/endpoints.
- [x] Implement pilot dashboard rendering.
- [x] Add/update schemas where needed.
- [x] Update control-plane/dashboard docs.
- [x] Update `docs/FLOWCHAIN_REAL_VALUE_PILOT.md` control-dashboard rows for the branch-local proof command.
- [x] Add PR-ready summary artifact.
- [x] Add completion audit artifact.
- [x] Add blocker handoff artifact.
- [x] Add file inventory artifact.
- [x] Add upstream reconciliation artifact.
- [x] Add machine-readable control-dashboard proof artifact.
- [x] Add command matrix artifact.
- [x] Add dedicated upstream HQ proof command `flowchain:real-value-pilot:control-dashboard`.
- [x] Add GitHub issue #137 evidence comment.
- [x] Add focused tests.
- [x] Run required test and smoke commands.
- [x] Run browser verification if available.

## Quantitative Acceptance

- [x] `npm test --prefix services/control-plane`
- [x] `npm run control-plane:smoke`
- [x] `npm test --prefix apps/dashboard`
- [x] `npm run build --prefix apps/dashboard`
- [x] API exposes pilot status, deposit observations, credits, withdrawal intents, release evidence, cap status, pause status, retry status, and emergency status.
- [x] API rejects or redacts private key, seed phrase, mnemonic, RPC credential, API key, and webhook-shaped material.
- [x] Dashboard shows exact live/degraded/error state and next operator command.
- [x] Dashboard labels the pilot as capped owner testing, not broad public readiness.
- [x] Browser stores no private keys or RPC secrets.
- [ ] `npm run flowchain:real-value-pilot:e2e` final HQ gate passes without `-AllowIncomplete`.
- [x] `npm run flowchain:real-value-pilot:control-dashboard` verifies the API/dashboard evidence row expected by the upstream HQ pilot gate.
- [x] `npm run flowchain:product-e2e` still passes without environment changes.
- [x] `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete` writes an upstream HQ coordination report showing the control-dashboard row present and only non-control-dashboard rows missing.

## Known Blockers

- [x] Rebased onto `origin/main` commit `f384236`, keeping the upstream final HQ `flowchain:real-value-pilot:e2e` gate and adding this branch's `flowchain:real-value-pilot:control-dashboard` proof command.
- [x] Local unsanitized `npm run flowchain:product-e2e` now passes after the upstream optional Slither policy is present.
- [ ] Upstream final `npm run flowchain:real-value-pilot:e2e` remains incomplete because contracts, bridge, runtime, wallet, and ops pilot proof commands are missing outside this agent's control-plane/dashboard scope.

## Verification Limitations

- In-app browser screenshot verification could not run because the Browser plugin Node REPL `js` tool was not exposed; HTTP server verification passed instead.
