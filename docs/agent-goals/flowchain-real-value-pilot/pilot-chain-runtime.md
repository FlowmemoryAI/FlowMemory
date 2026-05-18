/goal You are the FlowChain Real-Value Pilot Chain Runtime agent.

Worktree: E:\FlowMemory\flowmemory-live-chain
Branch: agent/real-value-pilot-chain

Goal: make the local FlowChain runtime consume real-value pilot bridge credits deterministically and expose receipts/state required by the relayer, control plane, and dashboard.

Inspect first:
- current `crates/flowmemory-devnet`;
- E:\FlowMemory\flowmemory-chain active long-loop work;
- bridge handoff files from bridge relayer worktrees.

Allowed folders:
- crates/flowmemory-devnet/
- devnet/
- infra/scripts/flowchain-*.ps1
- docs/agent-runs/real-value-pilot-chain/
- local runtime docs under docs/

Forbidden folders:
- contracts/
- services/bridge-relayer/
- apps/dashboard/
- crypto/ secret internals
- hardware/

Create and maintain:
- docs/agent-runs/real-value-pilot-chain/PLAN.md
- docs/agent-runs/real-value-pilot-chain/CHECKLIST.md
- docs/agent-runs/real-value-pilot-chain/EXPERIMENTS.md
- docs/agent-runs/real-value-pilot-chain/NOTES.md

Quantitative acceptance:
1. `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml` passes.
2. Runtime supports bridge-credit asset/account mapping for the pilot.
3. Bridge credits are included in blocks exactly once.
4. Replay of the same credit is rejected or idempotent with evidence.
5. Runtime exposes receipt by id and by Base event reference.
6. Restart preserves bridge credit, local balance, token, DEX, and receipt state.
7. Export/import preserves deterministic roots for pilot state.
8. Multi-node/local-network smoke remains passing or is updated.
9. `npm run flowchain:real-value-pilot:e2e` exercises runtime credit.
10. `npm run flowchain:product-e2e` still passes.

Feedback loop:
- Run focused Rust tests.
- Run cargo test.
- Run network smoke if available.
- Run pilot E2E and product E2E.

PR output:
- Include state/receipt shape.
- Include exact commands run.
- Include remaining integration blockers.
