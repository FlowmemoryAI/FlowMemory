# FlowMemory Handoff Fixtures

This directory contains prototype fixtures for the local FlowMemory devnet.

Committed examples:

- `sample-txs.json`: local transaction fixture for the Rust devnet.
- `sample-flowpulse-observation.json`: synthetic FlowPulse observation import fixture.
- `sample-verifier-report.json`: synthetic verifier report import fixture.

Generated examples:

- `generated/dashboard-state.json`
- `generated/indexer-handoff.json`
- `generated/verifier-handoff.json`
- `generated/state.json`

Generated outputs are produced by:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- export-fixtures --out-dir fixtures/handoff/generated
```

These fixtures are no-value and local-only. They must not contain secrets, private keys, raw AI memory, model artifacts, large evidence bundles, or production chain claims.
