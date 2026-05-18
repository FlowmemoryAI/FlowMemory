/goal You are the FlowChain Real-Value Pilot Ops/Installer agent.

Worktree: E:\FlowMemory\flowmemory-live-ops
Branch: agent/real-value-pilot-ops

Goal: make the capped real-value pilot runnable by the project owner from a second Windows computer with explicit env setup, dry-run checks, live observer mode, emergency stop, export evidence, and restart recovery.

Inspect first:
- current installer and second-computer docs;
- E:\FlowMemory\flowmemory-review active installer work;
- current product E2E and long-loop l1-e2e scripts.

Allowed folders:
- infra/scripts/
- docs/
- README.md
- package.json
- .github/
- docs/agent-runs/real-value-pilot-ops/

Forbidden folders:
- crates/
- contracts/
- services/
- crypto/
- apps/dashboard/
- hardware/

Create and maintain:
- docs/agent-runs/real-value-pilot-ops/PLAN.md
- docs/agent-runs/real-value-pilot-ops/CHECKLIST.md
- docs/agent-runs/real-value-pilot-ops/EXPERIMENTS.md
- docs/agent-runs/real-value-pilot-ops/NOTES.md

Quantitative acceptance:
1. `npm run flowchain:real-value-pilot:e2e` exists.
2. Dry-run mode passes without live RPC or keys.
3. Live mode refuses to run unless all required env vars and explicit operator ack are present.
4. Script verifies Base chain ID `8453` before live observer/deploy actions.
5. Script verifies cap env values are tiny and nonzero.
6. Script prints the exact next command after deploy, observe, credit, withdraw, pause, resume, export evidence, and restart.
7. Emergency stop script exists.
8. Evidence export bundle excludes `.git`, `node_modules`, build targets, local vaults, private keys, and env files.
9. Second-computer docs include a step-by-step owner pilot path.
10. Troubleshooting covers wrong chain, wrong contract, replay, stalled relayer, locked Cargo target, port conflict, and missing credentials.
11. `node infra/scripts/check-unsafe-claims.mjs` passes.
12. `git diff --check` passes.
13. `npm run flowchain:product-e2e` still passes.

Feedback loop:
- Run script parser checks.
- Run dry-run pilot E2E.
- Run unsafe-claims scan.
- Run product E2E.

PR output:
- Include exact owner commands.
- Include exact env var list.
- Include exact commands run.
