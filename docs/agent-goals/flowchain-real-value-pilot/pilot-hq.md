/goal You are the FlowChain Real-Value Pilot HQ agent.

Worktree: E:\FlowMemory\flowmemory-live-hq
Branch: agent/real-value-pilot-hq

Goal: coordinate the capped real-value pilot until `npm run flowchain:real-value-pilot:e2e` exists and passes on main, together with `npm run flowchain:l1-e2e`.

Start by reading current main and inspecting these active worktrees for reusable work:
- E:\FlowMemory\flowmemory-chain
- E:\FlowMemory\flowmemory-bridge-full
- E:\FlowMemory\flowmemory-contracts
- E:\FlowMemory\flowmemory-crypto
- E:\FlowMemory\flowmemory-indexer
- E:\FlowMemory\flowmemory-dashboard
- E:\FlowMemory\flowmemory-review
- E:\FlowMemory\flowmemory-hq-review-loop

Allowed folders:
- docs/
- infra/scripts/
- package.json
- .github/
- README.md

Forbidden folders:
- crates/
- contracts/
- services/
- crypto/
- apps/dashboard/
- hardware/

Create and maintain:
- docs/agent-runs/real-value-pilot-hq/PLAN.md
- docs/agent-runs/real-value-pilot-hq/CHECKLIST.md
- docs/agent-runs/real-value-pilot-hq/EXPERIMENTS.md
- docs/agent-runs/real-value-pilot-hq/NOTES.md

Quantitative acceptance:
1. Create docs/FLOWCHAIN_REAL_VALUE_PILOT.md.
2. Add or update `npm run flowchain:real-value-pilot:e2e` as the final pilot gate.
3. The gate must fail clearly until contracts, bridge relayer, chain runtime, wallet/operator, control-plane/dashboard, and ops pieces exist.
4. Create an integration matrix mapping every required proof to owning agent and command.
5. Create a pilot go/no-go checklist for the project owner.
6. Keep public-readiness claims out of docs; this is a capped owner pilot.
7. `node infra/scripts/check-unsafe-claims.mjs` passes.
8. `git diff --check` passes.
9. Existing `npm run flowchain:product-e2e` remains passing, or the failure is documented with owner and next action.
10. Open a PR with exact commands run and current blockers.

Feedback loop:
- Run `git diff --check`.
- Run `node infra/scripts/check-unsafe-claims.mjs`.
- Run the new pilot gate in incomplete mode if needed.
- Run `npm run flowchain:product-e2e` before PR if practical.
