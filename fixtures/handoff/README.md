# FlowMemory Handoff Fixtures

This directory contains prototype fixtures for the local FlowMemory localRuntime.

Committed examples:

- `sample-txs.json`: local transaction fixture for the Rust localRuntime.
- `sample-flowpulse-observation.json`: synthetic FlowPulse observation import fixture.
- `sample-verifier-report.json`: synthetic verifier report import fixture.
- `local-operator-key-reference.json`: local operator/worker/verifier key reference boundary with no signing secret.

Generated examples:

- `generated/dashboard-state.json`
- `generated/indexer-handoff.json`
- `generated/verifier-handoff.json`
- `generated/control-plane-handoff.json`
- `generated/genesis-config.json`
- `generated/operator-key-references.json`
- `generated/state.json`

Generated outputs are produced by:

```powershell
cargo run --manifest-path crates/flowmemory-local-runtime/Cargo.toml -- export-fixtures --out-dir fixtures/handoff/generated
```

These fixtures are no-value and local-only. They must not contain secrets, private keys, raw AI memory, model artifacts, large evidence bundles, or production chain claims.
