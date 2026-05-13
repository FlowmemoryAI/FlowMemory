/goal You are the FlowChain hardware/operator signal agent.

You are working in `E:\FlowMemory\flowmemory-hardware`.

Mission: make FlowRouter/Meshtastic-style signals useful to the local L1
testnet without blocking the chain. Hardware is optional, but the simulator
should produce real control-plane/workbench-visible signals.

Read first:
- AGENTS.md
- hardware/
- fixtures/hardware/
- docs/FLOWCHAIN_FULL_PRIVATE_TESTNET.md
- docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md

Allowed folders:
- hardware/
- fixtures/hardware/
- schemas/flowmemory/hardware-*.json
- docs/hardware docs if present

Do not edit:
- crates/
- services/
- apps/
- contracts/
- crypto/

Build requirements:
1. Extend the simulator to emit node heartbeat, offline alert, receipt relay,
   verifier digest relay, bridge alert, and NFC/operator metadata fixtures.
2. Add deterministic fixture validation and negative cases.
3. Provide handoff JSON that the control-plane can ingest.
4. Keep LoRa/Meshtastic as low-bandwidth control signaling. Do not require
   hardware for `flowchain:full-smoke`.
5. Add commands for simulator smoke and fixture generation.

Expected commands:
- hardware simulator validation
- hardware fixture generation
- contribute optional row to `npm run flowchain:full-smoke`

Acceptance:
- Simulator checks pass.
- Fixture schema validation passes.
- Control-plane/dashboard agents have a stable handoff shape.
- `git diff --check` passes.
- Open a PR and push your branch.
