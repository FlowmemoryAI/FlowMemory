# Hardware Signals Plan

Branch: `agent/l1-loop-hardware-signals`
Worktree: `E:\FlowMemory\flowmemory-hardware`

## Scope

Allowed folders:

- `hardware/`
- `fixtures/hardware/`
- `schemas/flowmemory/` hardware/operator signal schemas only
- `docs/agent-runs/hardware-signals/`
- hardware docs under `docs/`

Forbidden folders:

- `crates/`
- `services/` except read-only API contract review
- `apps/dashboard/` except read-only UI contract review
- `contracts/`
- `crypto/`

## Objective

Extend optional FlowRouter/operator-signal fixtures and simulator integration hooks for the FlowChain private/local L1 package without making hardware mandatory for local chain startup.

## Current Status

Hardware/signals scope is implemented and PR-ready. The full 8/8 goal is now
green after rebasing onto `origin/main` at `14f378b`, which includes the
accepted PR #132 default-vs-audit Slither policy fix. Exact
`npm run flowchain:product-e2e` passed in the unmodified local environment, and
`npm run flowchain:l1-e2e` passed last.

## Acceptance Checks

1. `npm run flowchain:hardware:smoke` passes.
2. Deterministic fixtures exist for heartbeat, alert, receipt relay, verifier digest, bridge alert, NFC metadata, peer hint, and node health if applicable.
3. Negative fixtures reject malformed IDs, oversized payloads, stale timestamps, duplicate signals, and secret-shaped payloads.
4. Signal schemas are documented.
5. Control-plane/dashboard handoff shape is stable and documented.
6. Meshtastic/LoRa remains documented as low-bandwidth control signaling only.
7. Hardware work remains optional and cannot block local chain startup.
8. `npm run flowchain:product-e2e` still passes after changes.

## Working Plan

1. Read the required source-of-truth docs and inspect Git/GitHub state.
2. Map existing simulator fixtures, schemas, package scripts, and hardware docs.
3. Extend deterministic positive and negative operator-signal fixtures.
4. Update schema/docs for signal inventory and control-plane/dashboard handoff shape.
5. Run simulator/unit checks, hardware smoke, `git diff --check`, product e2e, and `flowchain:l1-e2e` if present.

## Final E2E Status

`docs/agent-runs/hardware-signals/RETRY_AFTER_131.md` records the historical
retry path used after #131 closed. The final retry passed for both exact
product E2E and L1 E2E.
