# FlowMemory Hardware

Last updated: 2026-05-13

This directory contains the FlowRouter V0 proof-of-concept hardware package. It is production-shaped but research-safe: the docs, schemas, simulator, and field-test plans are intended to help later dashboard, services, and hardware work consume consistent data without claiming finished hardware.

## Package Map

- `flowrouter/`: FlowRouter V0 scope, BOM, assembly, enclosure, light-pipe, printing, and measurement docs.
- `lora-sidecar/`: Meshtastic/LoRa role, compact control-message inventory, and two-node demo notes.
- `memory-cartridges/`: NFC Memory Cartridge concept and metadata boundaries.
- `simulator/`: deterministic FlowRouter POC packet generator and schema validator.
- `fixtures/`: generated sample packet feeds for tests and future dashboard/service consumers.
- `field-tests/`: field-test plans and logs for controlled hardware experiments.
- `../fixtures/hardware/`: generated local-alpha FlowRouter operator-signal projection for dashboard, workbench, or control-plane consumers.

## V0 Purpose

FlowRouter V0 is a local FlowMemory gateway POC. It can model or test:

- Local node status.
- Artifact cache status.
- Compact receipt relay.
- Heartbeat messages.
- Gateway discovery.
- Local dashboard feed shape.
- Meshtastic/LoRa sidecar status and limits.
- NFC Memory Cartridge metadata.
- FlowCore light-pipe status.
- Enclosure measurement direction.
- FlowChain local-alpha operator signals derived from hardware packets, including optional control-plane/workbench fixture collections.

## V0 Non-Goals

FlowRouter V0 does not:

- Replace ISPs.
- Create global internet from nothing.
- Carry broadband over LoRa or Meshtastic.
- Move model weights, large artifacts, media, or raw memory payloads over LoRa.
- Prove hardware trustlessness.
- Mine tokens or promise passive income.
- Run a production L1 or appchain.
- Define production manufacturing, final CAD, or custom RF boards.

## Validation Entry Point

Generate and validate deterministic simulator output:

```powershell
python hardware/simulator/flowrouter_sim.py --seed 42 --out hardware/fixtures/flowrouter_sample_seed42.json
python hardware/simulator/flowrouter_sim.py --validate-file hardware/fixtures/flowrouter_sample_seed42.json
```

Generate and validate the local-alpha FlowChain operator-signal projection:

```powershell
python hardware/simulator/flowrouter_sim.py --seed 42 --out hardware/fixtures/flowrouter_sample_seed42.json --operator-out fixtures/hardware/flowrouter_local_alpha_seed42.json
python hardware/simulator/flowrouter_sim.py --validate-operator-file fixtures/hardware/flowrouter_local_alpha_seed42.json
```

The operator projection emits `flowmemory.hardware_operator_signals.local_alpha.v0`, with local-only `signalEnvelopes`, a direct `hardwareSignals` view, control-plane-style collections, and `workbenchRecords`. Hardware remains optional for the private/local testnet path.

The simulator uses only the Python standard library.
