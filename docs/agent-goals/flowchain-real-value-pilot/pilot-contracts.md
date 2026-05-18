/goal You are the FlowChain Real-Value Pilot Contracts agent.

Worktree: E:\FlowMemory\flowmemory-live-contracts
Branch: agent/real-value-pilot-contracts

Goal: build the contract side of the capped Base public-network pilot bridge. Reuse existing bridge/settlement contracts and active worktree changes where practical. Do not create a parallel bridge architecture.

Inspect first:
- current main contracts and tests;
- E:\FlowMemory\flowmemory-contracts active long-loop work;
- E:\FlowMemory\flowmemory-bridge-full bridge event expectations.

Allowed folders:
- contracts/
- tests/
- script/
- docs/bridge/
- docs/agent-runs/real-value-pilot-contracts/

Forbidden folders:
- crates/
- services/
- apps/dashboard/
- crypto/
- hardware/

Create and maintain:
- docs/agent-runs/real-value-pilot-contracts/PLAN.md
- docs/agent-runs/real-value-pilot-contracts/CHECKLIST.md
- docs/agent-runs/real-value-pilot-contracts/EXPERIMENTS.md
- docs/agent-runs/real-value-pilot-contracts/NOTES.md

Quantitative acceptance:
1. `forge test` passes.
2. `npm run contracts:hardening` passes.
3. Lockbox supports chain ID `8453` deployment configuration.
4. Contract enforces per-deposit cap and total pilot cap.
5. Contract supports allowlisted asset(s) only.
6. Pause blocks deposits.
7. Authorized release/recovery path remains possible while paused.
8. Replay protection prevents duplicate release/deposit accounting.
9. Events contain enough deterministic data for the relayer to derive bridge observation IDs without assuming txHash/logIndex inside the contract.
10. Dry-run deployment script exists.
11. Broadcast deployment script requires explicit local env ack and never commits keys.
12. Verification/source command or instructions exist.
13. Contract docs explain owner, release authority, cap, pause, replay, and emergency assumptions.
14. `npm run flowchain:product-e2e` still passes or the breakage is assigned.

Feedback loop:
- Run focused forge tests.
- Run `forge test`.
- Run `npm run contracts:hardening`.
- Run deployment dry run against local Anvil if scripts support it.
- Run `git diff --check`.

PR output:
- Include deployed-address handling design.
- Include exact commands run.
- Include remaining real-value pilot blockers.
