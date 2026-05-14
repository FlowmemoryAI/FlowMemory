/goal You are the FlowChain Dashboard/Workbench long-loop agent.

Worktree: E:\FlowMemory\flowmemory-dashboard
Branch: agent/l1-loop-dashboard-workbench

Baseline: the workbench already shows product testnet surfaces and live API status. Extend that app. Do not create another dashboard.

Allowed folders:
- apps/dashboard/
- docs/agent-runs/dashboard-workbench/
- dashboard/workbench docs under docs/

Forbidden folders:
- crates/
- contracts/
- crypto/ secret internals
- services/ except read-only API contract review
- hardware/ implementation

Create tracking files first:
- docs/agent-runs/dashboard-workbench/PLAN.md
- docs/agent-runs/dashboard-workbench/CHECKLIST.md
- docs/agent-runs/dashboard-workbench/EXPERIMENTS.md
- docs/agent-runs/dashboard-workbench/NOTES.md

Quantitative goal: complete 10/10 checks below:
1. `npm test --prefix apps/dashboard` passes.
2. `npm run build --prefix apps/dashboard` passes.
3. Workbench shows live/offline state for node, API, wallet, bridge, explorer, and product flow.
4. Workbench renders blocks, txs, accounts, balances, tokens, pools, LP positions, swaps, bridge credits, hardware signals, and provenance.
5. Workbench has clear recovery commands when node/API are offline.
6. Workbench never stores or asks for private keys, seed phrases, mnemonics, RPC credentials, API keys, or webhooks in browser state.
7. Workbench can trigger only safe local/testnet actions through signed-envelope or local command guidance.
8. A dashboard E2E or browser verification path exists for local `127.0.0.1:5173`.
9. Mobile and desktop layouts do not overlap text or controls.
10. `npm run flowchain:product-e2e` still passes after your changes.

Implementation constraints:
- Build operational UI, not a marketing page.
- Keep controls dense, clear, and local/testnet labeled.
- Do not imply production mainnet or real funds.
- Use existing design system and app structure.

Feedback loop:
1. Run focused component/data tests.
2. Run dashboard tests/build.
3. Run browser verification if the dev server is available.
4. Run `npm run flowchain:product-e2e`.
5. If `npm run flowchain:l1-e2e` exists, run it last.

PR output:
- Include screenshots or browser verification notes when possible.
- Include exact commands run.
- Name API fields that are required from control plane.
