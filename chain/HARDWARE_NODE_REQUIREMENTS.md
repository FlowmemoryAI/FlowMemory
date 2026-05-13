# Local Node And Hardware Observer Requirements

Status: prototype requirements

The local FlowMemory devnet can run on ordinary developer hardware. Hardware sidecars are optional observers, not validators, sequencers, or data availability providers.

## Local Developer Node

Minimum practical profile:

- CPU: any modern laptop/desktop CPU.
- Memory: 1 GB available for the Rust CLI and JSON state files.
- Storage: tens of MB for local state and handoff fixtures.
- Network: none required for local demo after dependencies are fetched.
- Secrets: none.

## Optional Hardware Observer Role

An optional FlowRouter or sidecar node may eventually:

- Cache compact state roots.
- Cache block hashes.
- Cache Base anchor placeholders.
- Relay small status messages.
- Provide local diagnostics.

It must not be treated as:

- A validator.
- A sequencer.
- A data availability provider.
- A bridge operator.
- A source of raw artifact data.

## Low-Bandwidth Boundary

Meshtastic and LoRa can carry compact status only:

- Current local block height.
- Current state root.
- Latest anchor id.
- Health or liveness flags.

They must not carry:

- Raw memory.
- Artifacts.
- Model output.
- Media.
- Full blocks.
- Data availability payloads.

## Future Production Questions

- How does a hardware observer prove freshness?
- How does it detect stale state?
- How does it authenticate compact status?
- What happens when local cached state conflicts with an online indexer?
- What is the operator response path?
