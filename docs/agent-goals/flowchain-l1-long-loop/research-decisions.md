/goal You are the FlowChain Research/Decisions long-loop agent.

Worktree: E:\FlowMemory\flowmemory-research
Branch: agent/l1-loop-research-decisions

Baseline: the project has a local/product testnet. Your job is to lock decisions that keep builders coherent. Do not implement product code.

Allowed folders:
- research/
- docs/DECISIONS/
- docs/agent-runs/research-decisions/
- research architecture docs under docs/

Forbidden folders:
- crates/
- services/
- apps/dashboard/
- contracts/
- crypto/
- hardware/

Create tracking files first:
- docs/agent-runs/research-decisions/PLAN.md
- docs/agent-runs/research-decisions/CHECKLIST.md
- docs/agent-runs/research-decisions/EXPERIMENTS.md
- docs/agent-runs/research-decisions/NOTES.md

Quantitative goal: complete 8/8 decision records:
1. Local consensus and fork-choice direction for the next private testnet.
2. Transaction envelope and account model boundary.
3. State storage, state-root, export/import, and pruning policy.
4. Wallet/key custody boundary for local/testnet and production-gated future.
5. Bridge security model for mock, local Anvil, Base Sepolia, and blocked mainnet.
6. Explorer/control-plane source-of-truth policy.
7. Hardware signal boundary and low-bandwidth assumptions.
8. Production gate checklist before public validators, mainnet, tokenomics, audited crypto, or real-funds bridge.

Implementation constraints:
- Decisions must distinguish implemented, planned, and blocked.
- Cite current repo files where possible.
- Do not authorize production deployment.
- Do not create speculative tokenomics.

Feedback loop:
1. Read current docs and issues.
2. Draft one decision record at a time.
3. Run `git diff --check`.
4. Run docs link/path checks if available.

PR output:
- Include a decision summary table.
- Name builder issues unblocked by each decision.
