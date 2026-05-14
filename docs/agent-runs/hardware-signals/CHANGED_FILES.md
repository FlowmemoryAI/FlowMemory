# Hardware Signals Changed Files

Last checked: 2026-05-14

## Scope Result

All files in the hardware-signals PR diff are inside the allowed scope:

- `hardware/`
- `fixtures/hardware/`
- `schemas/flowmemory/` hardware handoff schema only
- `docs/agent-runs/hardware-signals/`

No committed PR diff files are under forbidden folders such as `contracts/`,
`crates/`, `services/`, `apps/dashboard/`, or `crypto/`. Broader generated
artifacts from product/L1 e2e runs were restored after verification.

## Modified Files In PR

- `fixtures/hardware/README.md`
- `fixtures/hardware/flowrouter_control_plane_handoff_seed42.json`
- `fixtures/hardware/flowrouter_local_alpha_seed42.json`
- `fixtures/hardware/flowrouter_negative_validation_seed42.json`
- `hardware/README.md`
- `hardware/fixtures/flowrouter_sample_seed42.json`
- `hardware/flowrouter/FLOWCHAIN_LOCAL_ALPHA_SIGNALS.md`
- `hardware/flowrouter/README.md`
- `hardware/lora-sidecar/CONTROL_MESSAGE_INVENTORY.md`
- `hardware/simulator/README.md`
- `hardware/simulator/flowrouter_sim.py`
- `hardware/simulator/schemas/dashboard_feed.schema.json`
- `hardware/simulator/schemas/flowchain_operator_signals.schema.json`
- `schemas/flowmemory/hardware-control-plane-handoff.schema.json`

## Added Files In PR

- `docs/agent-runs/hardware-signals/AUDIT.md`
- `docs/agent-runs/hardware-signals/AJV_2020_VALIDATION.mjs`
- `docs/agent-runs/hardware-signals/CHECKLIST.md`
- `docs/agent-runs/hardware-signals/EXPERIMENTS.md`
- `docs/agent-runs/hardware-signals/NOTES.md`
- `docs/agent-runs/hardware-signals/NO_SECRET_FIXTURE_SCAN.mjs`
- `docs/agent-runs/hardware-signals/PLAN.md`
- `docs/agent-runs/hardware-signals/PR_SUMMARY.md`
- `docs/agent-runs/hardware-signals/CHANGED_FILES.md`
- `docs/agent-runs/hardware-signals/RETRY_AFTER_131.md`
- `docs/agent-runs/hardware-signals/SCOPE_CHECK.mjs`
- `hardware/simulator/schemas/node_health.schema.json`
- `hardware/simulator/schemas/peer_hint.schema.json`

## Final Completion Item

The changed-file scope is clean for hardware review, exact
`npm run flowchain:product-e2e` passed after rebasing onto `origin/main` at
`14f378b`, and `npm run flowchain:l1-e2e` passed last.
