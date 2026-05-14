# FlowRouter Simulator

Last updated: 2026-05-14

The simulator emits deterministic FlowRouter V0 proof-of-concept packets for dashboard, services, hardware, and field-test planning. It uses only the Python standard library.

## Generate Sample Output

```powershell
python hardware/simulator/flowrouter_sim.py --seed 42 --out hardware/fixtures/flowrouter_sample_seed42.json
```

## Generate Canonical Fixtures

```powershell
python hardware/simulator/flowrouter_sim.py --generate-fixtures --seed 42
```

This writes the raw packet fixture, the local-alpha operator projection, the control-plane handoff fixture, and the negative validation report.

The PowerShell wrapper is:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File hardware/simulator/flowrouter-generate-fixtures.ps1
```

## Simulator Smoke

```powershell
python hardware/simulator/flowrouter_sim.py --smoke --seed 42
```

The smoke command validates all canonical fixtures, compares them against deterministic regenerated output, and runs negative validation cases.

The PowerShell wrapper is:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File hardware/simulator/flowrouter-smoke.ps1
```

## Validate Existing Fixture

```powershell
python hardware/simulator/flowrouter_sim.py --validate-file hardware/fixtures/flowrouter_sample_seed42.json
```

## Validate Local-Alpha Operator Signals

```powershell
python hardware/simulator/flowrouter_sim.py --validate-operator-file fixtures/hardware/flowrouter_local_alpha_seed42.json
```

## Validate Control-Plane Handoff

```powershell
python hardware/simulator/flowrouter_sim.py --validate-handoff-file fixtures/hardware/flowrouter_control_plane_handoff_seed42.json
```

## Validate Negative Cases

```powershell
python hardware/simulator/flowrouter_sim.py --run-negative-cases --seed 42
python hardware/simulator/flowrouter_sim.py --validate-negative-report-file fixtures/hardware/flowrouter_negative_validation_seed42.json
```

## Packet Types

- Device manifest
- Heartbeat
- FlowPulse digest relay
- Verifier report digest relay
- Compact receipt relay
- Bridge alert
- Node health
- Peer hint
- Local cache status
- Gateway discovery
- Sidecar status
- NFC Memory Cartridge metadata
- Emergency/offline signal
- Dashboard feed
- FlowChain local-alpha operator signal projection

The packets are JSON versions of compact, binary-inspired fields. They are not production protocol commitments and should remain small enough to reason about LoRa constraints.

The local-alpha projection is a `flowmemory.hardware_operator_signals.local_alpha.v0` document. It uses camelCase, a top-level `schema`, local-only `signalEnvelopes`, a direct `hardwareSignals` view, and workbench/control-plane-ready collections:

- `device_manifest` -> `operatorMetadata`
- `heartbeat` -> `hardwareNodes`
- `node_health` -> `nodeHealth`
- `peer_hint` -> `peerHints`
- `compact_receipt_relay` -> `workReceipts`
- `verifier_report_digest_relay` -> `verifierReports`
- `emergency_offline_signal` -> `alerts` and `challenges`
- `bridge_alert` -> `bridgeAlerts` and `alerts`
- `nfc_memory_cartridge_metadata` -> `artifactCommitments` and `memoryCells`

It also includes `workbenchRecords` grouped by `operatorMetadata`, `nodeHealth`, `peerHints`, `receipts`, `verifierReports`, `bridgeAlerts`, `artifacts`, `memoryCells`, `challenges`, `hardwareSignals`, and `provenance`. The companion `flowmemory.hardware_control_plane_handoff.local_alpha.v0` fixture carries the same state keys under `collections` plus an optional `flowchain:full-smoke` row that runs `python hardware/simulator/flowrouter_sim.py --smoke`. These projection objects are local-only and advisory until reconciled through normal FlowMemory indexer, receipt, verifier, or operator workflows.

Negative validation covers missing required IDs, malformed IDs, oversized control payloads, stale timestamps, duplicate operator signal IDs, secret-shaped payload strings, hardware-required handoff claims, and missing required handoff collections.
