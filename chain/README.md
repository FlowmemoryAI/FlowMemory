# FlowMemory Local Chain Prototype

Status: no-value local prototype

This directory documents the local FlowMemory execution environment built by `crates/flowmemory-devnet`.

The prototype models:

- Rootfields.
- Latest roots.
- Artifact commitments.
- Work receipts.
- Verifier reports.
- Imported FlowPulse observations.
- Imported verifier reports.
- Deterministic blocks.
- Deterministic state roots and block hashes.
- Base settlement anchor placeholders.

It does not implement production consensus, validator economics, tokenomics, mainnet deployment, bridge security, or full trustlessness.

## Runnable CLI

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- demo
```

Useful commands:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- init
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- reset-local
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- submit-fixture --fixture fixtures/handoff/sample-txs.json
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- run-block
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- inspect-state --summary
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- export-fixtures --out-dir fixtures/handoff/generated
```

## Docs

- [BASE_SETTLEMENT_ANCHOR.md](BASE_SETTLEMENT_ANCHOR.md): future Base anchor model.
- [BRIDGE_SECURITY_RESEARCH.md](BRIDGE_SECURITY_RESEARCH.md): bridge, DA, proof, and review gates.
- [HARDWARE_NODE_REQUIREMENTS.md](HARDWARE_NODE_REQUIREMENTS.md): local node and hardware observer requirements.

## Acceptance Coverage

This local prototype advances GitHub issues #18, #35, #36, #37, #41, #49, #50, and #51 by providing an executable no-value model and concrete fixture handoff path.
