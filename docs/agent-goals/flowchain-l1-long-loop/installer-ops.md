/goal You are the FlowChain Installer/Ops long-loop agent.

Worktree: E:\FlowMemory\flowmemory-review
Branch: agent/l1-loop-installer-ops

Baseline: second-computer setup works when the repo is present, and product E2E passed on `FalconXtreme`. Build the beginner/offline install path and final orchestration gate. Do not build protocol features.

Allowed folders:
- infra/scripts/
- docs/
- .github/
- README.md
- package.json
- docs/agent-runs/installer-ops/

Forbidden folders:
- crates/
- services/
- crypto/
- contracts/
- apps/dashboard/
- hardware/

Create tracking files first:
- docs/agent-runs/installer-ops/PLAN.md
- docs/agent-runs/installer-ops/CHECKLIST.md
- docs/agent-runs/installer-ops/EXPERIMENTS.md
- docs/agent-runs/installer-ops/NOTES.md

Quantitative goal: complete 10/10 checks below:
1. `npm run flowchain:l1-e2e` exists.
2. `flowchain:l1-e2e` runs product E2E plus all available subsystem E2E commands and fails clearly for missing ones.
3. One script creates an offline second-computer bundle without `.git`, `node_modules`, `target`, secrets, or local vaults.
4. One script installs/verifies prerequisites and runs the local package from that bundle.
5. Setup docs include a no-GitHub-login/offline-bundle path.
6. Setup docs include the authenticated private-repo path.
7. Troubleshooting docs cover offline node/API, Windows Cargo target locks, port conflicts, GitHub auth failures, and missing Build Tools.
8. The final local URLs and restart commands are printed by scripts.
9. `git diff --check` passes.
10. `npm run flowchain:product-e2e` still passes after your changes.

Implementation constraints:
- Docs/scripts only.
- No product protocol implementation.
- No secret collection.
- No production claims.

Feedback loop:
1. Run PowerShell syntax checks for changed scripts.
2. Run dry-run/offline-bundle creation.
3. Run `git diff --check`.
4. Run `npm run flowchain:product-e2e`.
5. If subsystem commands exist, run `npm run flowchain:l1-e2e`.

PR output:
- Include exact setup command for non-technical second-computer use.
- Include exact commands run.
- List missing subsystem E2E commands.
