# FlowRouter Simulator

Last updated: 2026-05-13

The simulator emits deterministic FlowRouter V0 proof-of-concept packets for dashboard, services, hardware, and field-test planning. It uses only the Python standard library.

## Generate Sample Output

```powershell
python hardware/simulator/flowrouter_sim.py --seed 42 --out hardware/fixtures/flowrouter_sample_seed42.json
```

## Validate Existing Fixture

```powershell
python hardware/simulator/flowrouter_sim.py --validate-file hardware/fixtures/flowrouter_sample_seed42.json
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

The packets are JSON versions of compact, binary-inspired fields. They are not production protocol commitments and should remain small enough to reason about LoRa constraints.
