/goal You are the FlowChain live-product HQ orchestrator.

Worktree: `E:\FlowMemory\flowmemory-live-hq`
Branch: `agent/live-product-hq`

Mission: own the full FlowChain live L1 product build across all workstreams.
Your job is not to write a status-only report. You must turn vague readiness
claims into a concrete checklist, coordinate code contracts between agents, and
keep looping until every product gate is green or has a precise failing test and
owner.

Read first:
- `AGENTS.md`
- `docs/agent-goals/production-l1-live-chain/README.md`
- `docs/ARCHITECTURE.md`
- `docs/FLOWCHAIN_FULL_PRIVATE_TESTNET.md`
- `docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md`
- `docs/agent-runs/production-l1-hq/`
- current PRs and branch history for the live L1, bridge, and wallet work

Own:
- integration checklist and product readiness matrix
- cross-workstream contracts for runtime, bridge, wallet, API, and app builds
- root `package.json` command additions for final E2E orchestration
- docs under `docs/agent-runs/live-product-hq/`

Build loop:
1. Create `PLAN.md`, `CHECKLIST.md`, `EXPERIMENTS.md`, and `NOTES.md`.
2. Inventory what already exists and classify each item as `working`,
   `partial`, `mock-only`, `blocked`, or `missing`.
3. Define the single source of truth for readiness:
   `npm run flowchain:live-product:e2e`.
4. Ensure every other agent has a machine-readable handoff contract.
5. Add or update root scripts that run focused subsystem checks before the
   final gate.
6. Open issues or TODO test failures only when they include exact commands,
   expected results, actual results, owner, and file paths.
7. Re-run the matrix after every merged dependency.

Acceptance gates:
- `npm run flowchain:production-l1:e2e` still passes or any failure is assigned.
- `npm run flowchain:live-l1-bridge:e2e` still passes or any failure is assigned.
- `npm run flowchain:wallet:e2e` passes.
- `npm run flowchain:dashboard:verify` passes.
- A new `npm run flowchain:live-product:e2e` command exists, runs all required
  checks, and fails closed if live dependencies are missing.
- The readiness matrix states exactly whether the current build can accept a
  Base 8453 deposit, credit FlowChain, spend it, swap it, and export evidence.
- Do not close until every non-green cell has a concrete implementation prompt
  and a failing or skipped test that names the blocker.

