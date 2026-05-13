# FlowRouter Simulator

Last updated: 2026-05-13

The simulator emits deterministic FlowRouter V0 proof-of-concept packets for dashboard, services, hardware, and field-test planning. It uses only the Python standard library.

## Generate Sample Output

```powershell
python hardware/simulator/flowrouter_sim.py --seed 42 --out hardware/fixtures/flowrouter_sample_seed42.json
```

## Generate Local-Alpha Operator Signals

```powershell
python hardware/simulator/flowrouter_sim.py --seed 42 --out hardware/fixtures/flowrouter_sample_seed42.json --operator-out fixtures/hardware/flowrouter_local_alpha_seed42.json
```

This is also the simulator smoke command: generation validates the raw packet fixture and the local-alpha operator projection before writing either output file.

## Validate Existing Fixture

```powershell
python hardware/simulator/flowrouter_sim.py --validate-file hardware/fixtures/flowrouter_sample_seed42.json
```

## Validate Local-Alpha Operator Signals

```powershell
python hardware/simulator/flowrouter_sim.py --validate-operator-file fixtures/hardware/flowrouter_local_alpha_seed42.json
```

## Packet Types

- Device manifest
- Heartbeat
- FlowPulse digest relay
- Verifier report digest relay
- Compact receipt relay
- Local cache status
- Gateway discovery
- Sidecar status
- NFC Memory Cartridge metadata
- Emergency/offline signal
- Dashboard feed
- FlowChain local-alpha operator signal projection

The packets are JSON versions of compact, binary-inspired fields. They are not production protocol commitments and should remain small enough to reason about LoRa constraints.

The local-alpha projection is a `flowmemory.hardware_operator_signals.local_alpha.v0` document. It uses camelCase, a top-level `schema`, local-only `signalEnvelopes`, a direct `hardwareSignals` view, and workbench/control-plane-ready collections:

- `heartbeat` -> `hardwareNodes`
- `compact_receipt_relay` -> `workReceipts`
- `verifier_report_digest_relay` -> `verifierReports`
- `emergency_offline_signal` -> `alerts` and `challenges`
- `nfc_memory_cartridge_metadata` -> `artifactCommitments` and `memoryCells`

It also includes `workbenchRecords` grouped by `receipts`, `verifierReports`, `artifacts`, `memoryCells`, `challenges`, `hardwareSignals`, and `provenance`. These projection objects are local-only and advisory until reconciled through normal FlowMemory indexer, receipt, verifier, or operator workflows.
