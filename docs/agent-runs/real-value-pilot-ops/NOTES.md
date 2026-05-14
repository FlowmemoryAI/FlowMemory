# Real-Value Pilot Ops Notes

## Context Read

- Required docs read: `START_HERE`, `FLOWMEMORY_HQ_CONTEXT`, `CURRENT_STATE`, `ROOTFLOW_V0`, `FLOW_MEMORY_V0`, and `V0_LAUNCH_ACCEPTANCE`.
- GitHub issue #135 is the active ops/installer proof tracker.
- The old `agent/real-value-pilot-ops` worktree had a useful dry-run E2E
  wrapper, but it predated the merged HQ final pilot gate.
- Current product E2E is `infra/scripts/flowchain-product-e2e.ps1`.
- Current `flowchain:l1-e2e` is the merged alias to `flowchain:full-smoke`.

## Implementation Notes

- The ops wrapper will not deploy or modify contracts by itself during dry-run.
- Live observer mode can call the existing bridge observer after explicit env, chain, cap, contract, and block-range checks.
- Evidence export should stage only sanitized pilot artifacts and validate the zip contents.
- Reused the old ops dry-run E2E as
  `infra/scripts/flowchain-real-value-pilot-ops-e2e.ps1` so it does not
  replace `infra/scripts/flowchain-real-value-pilot-e2e.ps1`, which is now the
  merged final HQ gate.
- Added package aliases for pilot action, ops proof, emergency stop, and
  evidence export.
- Updated `docs/FLOWCHAIN_REAL_VALUE_PILOT.md`, second-computer docs,
  checklist, troubleshooting, and README surfaces with the capped owner ops
  command path.
- Product E2E passed on the current branch. Generated tracked fixture/output
  files from the test run were restored because they are outside this task's
  intended diff.
