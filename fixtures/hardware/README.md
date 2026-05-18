# Hardware Fixtures

Last updated: 2026-05-14

This folder contains local-alpha hardware projections that can be consumed by dashboard, workbench, or control-plane code without depending on live FlowRouter hardware.

## Fixtures

- `flowrouter_local_alpha_seed42.json`: deterministic FlowRouter-to-FlowChain operator signal projection generated from `hardware/fixtures/flowrouter_sample_seed42.json`.
- `flowrouter_control_plane_handoff_seed42.json`: read-only optional hardware handoff shaped for local control-plane ingestion.
- `flowrouter_negative_validation_seed42.json`: deterministic report proving malformed hardware/operator handoff cases are rejected.

## Shape

The fixture is a `flowmemory.hardware_operator_signals.local_alpha.v0` document. It includes:

- `signalEnvelopes`: envelopes for operator metadata, heartbeat, node health, peer hint, receipt relay, verifier digest relay, offline alert/challenge input, bridge alert, and NFC memory cartridge metadata.
- `hardwareSignals`: direct workbench/control-plane signal records for the same envelopes.
- `operatorMetadata`, `hardwareNodes`, `nodeHealth`, `peerHints`, `workReceipts`, `verifierReports`, `bridgeAlerts`, `artifactCommitments`, `memoryCells`, `challenges`, `finalityReceipts`, and `alerts`: control-plane-friendly local fixture collections.
- `workbenchRecords`: ready-to-render records grouped by workbench section keys, including `nodeHealth`, `peerHints`, and `hardwareSignals`.
- `boundary`: explicit local-only, advisory, optional-hardware limitations.

The handoff fixture is a `flowmemory.hardware_control_plane_handoff.local_alpha.v0` document. It mirrors the stable control-plane state keys under `collections`, declares read-only merge id fields, and carries an optional full-smoke row:

```powershell
python hardware/simulator/flowrouter_sim.py --smoke
```

## Validation

```powershell
python hardware/simulator/flowrouter_sim.py --smoke --seed 42
python hardware/simulator/flowrouter_sim.py --validate-operator-file fixtures/hardware/flowrouter_local_alpha_seed42.json
python hardware/simulator/flowrouter_sim.py --validate-handoff-file fixtures/hardware/flowrouter_control_plane_handoff_seed42.json
python hardware/simulator/flowrouter_sim.py --validate-negative-report-file fixtures/hardware/flowrouter_negative_validation_seed42.json
```

These fixtures are local-only and advisory. They do not prove hardware trustlessness, production field deployment, or receipt/verifier finality.

The negative validation report proves rejection of malformed IDs, oversized control payloads, stale timestamps, duplicate signal IDs, secret-shaped payload strings, required-hardware claims, and missing required handoff collections.
