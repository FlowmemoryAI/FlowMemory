# Hardware Fixtures

Last updated: 2026-05-13

This folder contains local-alpha hardware projections that can be consumed by dashboard, workbench, or control-plane code without depending on live FlowRouter hardware.

## Fixtures

- `flowrouter_local_alpha_seed42.json`: deterministic FlowRouter-to-FlowChain operator signal projection generated from `hardware/fixtures/flowrouter_sample_seed42.json`.

## Shape

The fixture is a `flowmemory.hardware_operator_signals.local_alpha.v0` document. It includes:

- `signalEnvelopes`: one envelope for heartbeat, receipt relay, verifier digest relay, offline alert/challenge input, and NFC memory cartridge metadata.
- `hardwareSignals`: direct workbench/control-plane signal records for the same five envelopes.
- `hardwareNodes`, `workReceipts`, `verifierReports`, `artifactCommitments`, `memoryCells`, `challenges`, `finalityReceipts`, and `alerts`: control-plane-friendly local fixture collections.
- `workbenchRecords`: ready-to-render records grouped by workbench section keys, including `hardwareSignals`.
- `boundary`: explicit local-only, advisory, optional-hardware limitations.

## Validation

```powershell
python hardware/simulator/flowrouter_sim.py --validate-operator-file fixtures/hardware/flowrouter_local_alpha_seed42.json
```

These fixtures are local-only and advisory. They do not prove hardware trustlessness, production field deployment, or receipt/verifier finality.
