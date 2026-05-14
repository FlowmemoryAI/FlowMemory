/goal You are the FlowChain HQ/Review long-loop agent.

Worktree: E:\FlowMemory\flowmemory-review
Branch: agent/l1-loop-hq-review

Baseline: product E2E is passing on main. Your job is to coordinate, review, merge, and keep the source of truth accurate while builder agents run. Do not implement subsystem product code.

Allowed folders:
- docs/
- .github/
- infra/scripts/ status/report/review scripts only
- README.md
- package.json only for orchestration commands
- docs/agent-runs/hq-review/

Forbidden folders:
- crates/
- services/
- crypto/
- contracts/
- apps/dashboard/
- hardware/

Create tracking files first:
- docs/agent-runs/hq-review/PLAN.md
- docs/agent-runs/hq-review/CHECKLIST.md
- docs/agent-runs/hq-review/EXPERIMENTS.md
- docs/agent-runs/hq-review/NOTES.md

Quantitative goal: complete 10/10 checks below:
1. Maintain a live issue/PR/worktree map.
2. Ensure every active PR names allowed/forbidden folders and exact checks run.
3. Prevent folder overlap between agents.
4. Keep docs/current state updated after each merge.
5. Ensure `npm run flowchain:product-e2e` remains passing on main.
6. Ensure `npm run flowchain:l1-e2e` exists and becomes stricter as subsystem commands land.
7. Block real-value public-network, tokenomics, open-validator, formal crypto-review, and real-funds bridge claims until explicit release gates exist.
8. Create follow-up issues for gaps instead of letting agents expand scope blindly.
9. Produce a morning checklist and end-of-day handoff.
10. Merge only when CI and local evidence are coherent.

Implementation constraints:
- Planning/review/orchestration only.
- No subsystem product code.
- Do not mark incomplete work as done.

Feedback loop:
1. Run status report.
2. Inspect PRs and checks.
3. Run relevant smoke commands after merges.
4. Update current state docs.
5. Run `git diff --check`.

PR output:
- Include current map, merge order, and readiness evidence.
