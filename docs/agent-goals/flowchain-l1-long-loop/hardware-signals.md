/goal You are the FlowChain Hardware/Signals long-loop agent.

Worktree: E:\FlowMemory\flowmemory-hardware
Branch: agent/l1-loop-hardware-signals

Baseline: FlowRouter simulator smoke exists. Extend optional operator-signal fixtures and integration hooks. Do not work on manufacturing.

Allowed folders:
- hardware/
- fixtures/hardware/ if present
- schemas/flowmemory/ hardware/operator signal schemas only
- docs/agent-runs/hardware-signals/
- hardware docs under docs/

Forbidden folders:
- crates/
- services/ except read-only API contract review
- apps/dashboard/ except read-only UI contract review
- contracts/
- crypto/

Create tracking files first:
- docs/agent-runs/hardware-signals/PLAN.md
- docs/agent-runs/hardware-signals/CHECKLIST.md
- docs/agent-runs/hardware-signals/EXPERIMENTS.md
- docs/agent-runs/hardware-signals/NOTES.md

Quantitative goal: complete 8/8 checks below:
1. `npm run flowchain:hardware:smoke` passes.
2. Deterministic fixtures exist for heartbeat, alert, receipt relay, verifier digest, bridge alert, NFC metadata, peer hint, and node health if applicable.
3. Negative fixtures reject malformed IDs, oversized payloads, stale timestamps, duplicate signals, and secret-shaped payloads.
4. Signal schemas are documented.
5. Control-plane/dashboard handoff shape is stable and documented.
6. Meshtastic/LoRa remains documented as low-bandwidth control signaling only.
7. Hardware work remains optional and cannot block local chain startup.
8. `npm run flowchain:product-e2e` still passes after your changes.

Implementation constraints:
- No hardware manufacturing.
- No normal-internet-over-LoRa claim.
- No secrets in fixtures.
- Keep payloads small and deterministic.

Feedback loop:
1. Run simulator/unit tests.
2. Run hardware smoke.
3. Run `git diff --check`.
4. Run `npm run flowchain:product-e2e`.
5. If `npm run flowchain:l1-e2e` exists, run it last.

PR output:
- Include fixture list and exact commands run.
- State optional integration points.
