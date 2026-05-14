/goal You are the FlowChain Contracts/Settlement long-loop agent.

Worktree: E:\FlowMemory\flowmemory-contracts
Branch: agent/l1-loop-contracts-settlement

Baseline: contract hardening and bridge lockbox tests already exist. Extend existing contracts and tests. Do not invent a parallel settlement system.

Allowed folders:
- contracts/
- tests/
- script/
- docs/agent-runs/contracts-settlement/
- contract/settlement docs under docs/

Forbidden folders:
- crates/
- services/
- apps/dashboard/
- crypto/
- hardware/

Create tracking files first:
- docs/agent-runs/contracts-settlement/PLAN.md
- docs/agent-runs/contracts-settlement/CHECKLIST.md
- docs/agent-runs/contracts-settlement/EXPERIMENTS.md
- docs/agent-runs/contracts-settlement/NOTES.md

Quantitative goal: complete 9/9 checks below:
1. `npm run contracts:hardening` passes.
2. `forge test` passes for all contract suites.
3. Bridge lockbox deposit/release/replay/pause/cap tests are complete for local/testnet needs.
4. Settlement spine emits stable events for objects consumed by bridge/control-plane.
5. Event schemas avoid txHash/logIndex assumptions inside contracts.
6. Dry-run deployment scripts exist for local Anvil or Base Sepolia test mode where appropriate.
7. Mainnet deployment remains blocked behind explicit production gate docs.
8. Contract docs name owner, authority, pause, cap, replay, and emergency assumptions.
9. `npm run flowchain:product-e2e` still passes after your changes.

Implementation constraints:
- No tokenomics.
- No production deployment.
- No unaudited real-funds bridge claim.
- Keep event/object vocabulary coordinated with bridge and control-plane agents.

Feedback loop:
1. Run focused forge test.
2. Run `forge test`.
3. Run `npm run contracts:hardening`.
4. Run `npm run flowchain:product-e2e`.
5. If `npm run flowchain:l1-e2e` exists, run it last.

PR output:
- Include exact commands run.
- State whether event schema changed.
- State production blockers.
