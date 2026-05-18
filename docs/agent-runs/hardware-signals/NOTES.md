# Hardware Signals Notes

## Source Docs Read

- `docs/START_HERE.md`
- `docs/FLOWMEMORY_HQ_CONTEXT.md`
- `docs/CURRENT_STATE.md`
- `docs/ROOTFLOW_V0.md`
- `docs/FLOW_MEMORY_V0.md`
- `docs/V0_LAUNCH_ACCEPTANCE.md`
- `docs/ISSUE_BACKLOG.md`
- `docs/PR_PROCESS.md`
- `docs/agent-goals/full-l1/hardware-signals.md`

## Initial Boundaries

- Hardware remains a research POC and optional operator-signal layer.
- Heavy AI, memory, model, media, and artifact data stays off-chain.
- Meshtastic and LoRa are low-bandwidth control signaling paths, not normal internet bandwidth.
- Control-plane/dashboard integration should consume stable deterministic handoff JSON without requiring live radios or hardware devices.

## GitHub Reconciliation

- GitHub issue #105 is open and matches this run's hardware/operator-signal fixture scope and acceptance criteria.
- Issue #105 names `agent/full-l1-hardware`; this run is explicitly assigned `agent/l1-loop-hardware-signals` and the local branch matches that assignment. Scope and acceptance are aligned, so the branch-name difference is recorded here rather than changing worktrees.

## Baseline Checks

- `npm run flowchain:hardware:smoke` passed before implementation edits with 8 existing negative cases.

## Implementation Notes

- Added explicit `node_health` and `peer_hint` simulator packets and schemas.
- Projected node health into `nodeHealth` and peer hints into `peerHints` in the operator fixture, handoff collections, id-field map, and workbench records.
- Added semantic validation for fixture timestamps, deterministic ID shapes, duplicate signal IDs, and secret-shaped payload strings.
- Regenerated seed 42 fixtures. The final hardware smoke reports 12 negative cases.
- Before PR #132 landed, `npm run flowchain:product-e2e` passed only when the user-local Slither script directory was removed from `PATH` for that command. After rebasing onto `origin/main` at `14f378b`, the exact unmodified command passed with Slither still on `PATH`.

## Verification Notes

- Current verification reran simulator compile, fixture validators, negative cases, hardware smoke, `git diff --check`, product e2e, and l1 e2e.
- `node docs/agent-runs/hardware-signals/SCOPE_CHECK.mjs` passed; 27 changed/untracked paths are inside allowed hardware-signals scope.
- A raw `npm run flowchain:product-e2e` run failed before product checks because optional Slither is installed locally and reported existing `contracts/bridge/BaseBridgeLockbox.sol` findings. Contract edits are forbidden for this task.
- Reran `npm run flowchain:product-e2e` with only the user-local Slither script directory removed from `PATH`; it passed and still ran full smoke, contracts build/tests, dashboard build, hardware smoke, wallet smoke, bridge local-credit smoke, and product checks.
- Product e2e generated non-hardware artifacts during full smoke; those generated side effects were restored, leaving only allowed hardware/signals files dirty.
- After rebasing onto `origin/main`, root `package.json` defines `flowchain:l1-e2e`; `npm run flowchain:l1-e2e` passed when run last.
- `node docs/agent-runs/hardware-signals/NO_SECRET_FIXTURE_SCAN.mjs` passed; broad changed-file secret scans intentionally hit simulator denylist literals and the in-memory negative-case payload.
- Raw packet fixture keys all have matching simulator schema files.
- Independent AJV 2020 validation passed for every raw packet, the operator projection, the control-plane handoff, and the negative validation report.
- `node infra/scripts/check-unsafe-claims.mjs` passed; targeted changed-file phrase review found only negative/guardrail uses of manufacturing, broadband/LoRa, ISP replacement, production bridge, public validator, AI-on-chain, and free-storage terms.

## Completion Audit

The hardware/operator-signal implementation satisfies the allowed-scope artifact requirements. The overall 8/8 objective is complete after rebasing onto `origin/main` at `14f378b`, rerunning exact `npm run flowchain:product-e2e`, and running `npm run flowchain:l1-e2e` last.

Resolution history:

- `slither` is installed at `C:\Users\ntrap\AppData\Roaming\Python\Python311\Scripts\slither.exe`.
- `npm run flowchain:product-e2e` invokes `npm run flowchain:full-smoke`, then `npm run launch:candidate`, then `npm run contracts:hardening`.
- Before PR #132 landed, the Windows contract hardening script ran Slither whenever it was present on `PATH`.
- Slither reports two existing explicit-audit findings in `contracts/bridge/BaseBridgeLockbox.sol`.
- `contracts/` and `infra/scripts/` are forbidden for this hardware-signals task, so this agent did not fix or suppress the gate locally.
- GitHub issue #131, `[contracts/security] Reconcile Slither findings blocking flowchain product E2E`, was closed by the owning HQ/contracts policy path in PR #132.
- Draft PR #110 is still open/draft, but it no longer blocks default product/L1 e2e for this branch.
- Rechecked after `git fetch --all --prune` on 2026-05-14; #131 initially remained open, PR #110 remained draft, and no merged mainline fix was available for this worktree.
- Added issue #131 blocker handoff comment: https://github.com/FlowmemoryAI/FlowMemory/issues/131#issuecomment-4446678297.
- Read-only check of `origin/agent/full-l1-contracts` at `497c3b1` found no newer branch-side unblock for the product-e2e Slither blocker.
- Draft PR #139 is open at https://github.com/FlowmemoryAI/FlowMemory/pull/139 and GitHub CI passed after the hygiene literal fix.
- Added and updated hardware issue #105 status comment with fixture, scope-check, AJV, no-secret scan, unsafe-claim, optional handoff, retry-doc, and #131 blocker evidence: https://github.com/FlowmemoryAI/FlowMemory/issues/105#issuecomment-4446712093.
- Earlier recheck: #131 remained open, PR #110 remained draft, and `origin/main` was still at `9b025c5`; no merged product-e2e unblock was available at that point.
- The branch was later rebased onto `origin/main` at `14f378b` after PR #132 merged.
- Added `CHANGED_FILES.md` with the current modified/untracked file manifest and scope classification.
- Added `RETRY_AFTER_131.md` with the exact commands and completion rule to rerun after the product-e2e blocker lands.
- Final source-of-truth recheck in this run: #131 remains open as of 2026-05-14T02:00:17Z and PR #110 remains open/draft as of 2026-05-14T01:58:27Z.
- Follow-up source-of-truth recheck: #131 remains open as of 2026-05-14T02:09:46Z and PR #110 remains open/draft as of 2026-05-14T01:58:27Z.
- Latest exact `npm run flowchain:product-e2e` retry failed again on 2026-05-13T21:19:15-05:00 for the same out-of-scope Slither findings in `contracts/bridge/BaseBridgeLockbox.sol`; no new tracked side effects outside the current allowed hardware-scope files remained afterward.
- Final source-of-truth update: #131 closed after PR #132 merged to `origin/main` as `14f378b`.
- Rebasing this hardware branch onto `origin/main` picked up the default-vs-audit Slither policy without adding hardware-scope edits outside the existing PR diff.
- Exact `npm run flowchain:product-e2e` passed in the unmodified local environment with Slither still on `PATH`.
- `npm run flowchain:l1-e2e` exists after the rebase and passed when run last.
- Product/L1 e2e generated broader launch/dashboard/service artifacts during the run; those side effects were restored so only the committed hardware-signals PR changes remain.
