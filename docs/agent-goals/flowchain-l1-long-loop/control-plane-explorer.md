/goal You are the FlowChain Control-Plane/Explorer long-loop agent.

Worktree: E:\FlowMemory\flowmemory-indexer
Branch: agent/l1-loop-control-plane-explorer

Baseline: the control plane already serves health/state/RPC and product token/DEX/bridge reads. Extend the existing service. Do not create a second explorer backend.

Allowed folders:
- services/shared/
- services/indexer/
- services/verifier/
- services/flowmemory/
- services/control-plane/
- schemas/flowmemory/ only for API schema coordination
- docs/agent-runs/control-plane-explorer/
- control-plane/indexer docs under docs/

Forbidden folders:
- crates/
- apps/dashboard/
- contracts/
- crypto/ secret-handling internals
- hardware/ implementation

Create tracking files first:
- docs/agent-runs/control-plane-explorer/PLAN.md
- docs/agent-runs/control-plane-explorer/CHECKLIST.md
- docs/agent-runs/control-plane-explorer/EXPERIMENTS.md
- docs/agent-runs/control-plane-explorer/NOTES.md

Quantitative goal: complete 10/10 checks below:
1. `npm test --prefix services/control-plane` passes.
2. `npm run control-plane:smoke` passes.
3. API reads prefer live local node state where present and fall back to fixtures only when live state is unavailable.
4. Explorer summary includes node status, peer status, blocks, txs, accounts, balances, tokens, pools, LP positions, swaps, bridge credits, hardware signals, and provenance counts.
5. Transaction submit accepts only validated signed envelopes and rejects unsigned or secret-shaped requests.
6. Bridge observation/credit reads are replay-safe and distinguish mock, Base Sepolia, local Anvil, and production-gated mainnet modes.
7. No response route returns private key, seed, mnemonic, RPC credential, API key, or webhook-shaped text.
8. A control-plane/explorer E2E command exists or is wired into `flowchain:l1-e2e`.
9. Dashboard has stable API contracts for every field it needs.
10. `npm run flowchain:product-e2e` still passes after your changes.

Implementation constraints:
- Keep a single JSON-RPC/control-plane surface.
- Do not add public production endpoints.
- Do not bypass existing no-secret scans.
- Keep schemas explicit and documented.

Feedback loop:
1. Run focused service tests.
2. Run `npm run control-plane:smoke`.
3. Run full service tests.
4. Run `npm run flowchain:product-e2e`.
5. If `npm run flowchain:l1-e2e` exists, run it last.

PR output:
- List every method/endpoint added or changed.
- Include exact commands run.
- Name dashboard/runtime dependencies.
