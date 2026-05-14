/goal You are the FlowChain Bridge/Testnet long-loop agent.

Worktree: E:\FlowMemory\flowmemory-bridge-full
Branch: agent/l1-loop-bridge-testnet

Baseline: bridge local-credit handoff smoke exists and product E2E proves mock bridge-credit visibility. Extend the existing bridge path. Do not create a second bridge system.

Allowed folders:
- services/bridge-relayer/
- fixtures/bridge/
- schemas/flowmemory/bridge*.json
- infra/scripts/bridge-*.ps1
- docs/agent-runs/bridge-testnet/
- bridge docs under docs/

Forbidden folders:
- apps/dashboard/
- crates/ except read-only handoff review
- contracts/ except read-only event/schema review
- crypto/ secret internals
- production deployment files

Create tracking files first:
- docs/agent-runs/bridge-testnet/PLAN.md
- docs/agent-runs/bridge-testnet/CHECKLIST.md
- docs/agent-runs/bridge-testnet/EXPERIMENTS.md
- docs/agent-runs/bridge-testnet/NOTES.md

Quantitative goal: complete 10/10 checks below:
1. `npm test --prefix services/bridge-relayer` passes.
2. `npm run bridge:local-credit:smoke` passes.
3. A bridge E2E command exists for mock/local Anvil/Base Sepolia test mode.
4. Deposit observation produces deterministic bridge observation and credit IDs.
5. Replaying the same deposit is rejected or idempotent with clear evidence.
6. Withdrawal intent is generated for local/testnet only and is queryable by control plane.
7. Base mainnet real-funds behavior remains blocked unless a separate production gate exists.
8. No bridge output contains private keys, seed phrases, RPC credentials, API keys, or webhooks.
9. Bridge state is visible through the control-plane contracts agreed with the explorer agent.
10. `npm run flowchain:product-e2e` still passes after your changes.

Implementation constraints:
- Mock, local Anvil, and Base Sepolia are allowed.
- Base mainnet must remain read-only/canary or blocked.
- No custody keys or real $20 bridge path until audited production gate.
- Keep replay protection explicit.

Feedback loop:
1. Run bridge unit tests.
2. Run local-credit smoke.
3. Run new bridge E2E.
4. Run `npm run flowchain:product-e2e`.
5. If `npm run flowchain:l1-e2e` exists, run it last.

PR output:
- State mode: mock, local Anvil, Base Sepolia, or blocked mainnet.
- Include exact commands run.
- Name security risks that remain.
