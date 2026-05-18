# FlowMemory Local Devnet Runtime

This directory is reserved for local runtime state from the no-value FlowMemory devnet prototype.

Default state path:

```text
devnet/local/state.json
```

`devnet/local/` is ignored by git. Do not commit local state files, generated blocks, generated handoff exports, secrets, or private keys.

Use:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- init
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- smoke
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- bridge-handoff --handoff fixtures/bridge/local-runtime-bridge-handoff.json --direct
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- bridge-receipt --receipt-id 0xff3efb8221533cfc836bffbcee10bdd2d7d4a5615efce9516574245a3b7d74a6
powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-real-value-pilot-runtime.ps1
```

The pilot runtime proof writes `devnet/local/real-value-pilot-e2e/flowchain-real-value-pilot-e2e-report.json`, prefers the bridge proof handoff above when present, falls back to `fixtures/bridge/local-runtime-bridge-handoff.json` for standalone runtime development, and checks bridge credit inclusion, replay rejection, receipt lookup, restart/export/import roots, and bridge state in dashboard, indexer, verifier, and control-plane handoff files.

See [docs/LOCAL_DEVNET.md](../docs/LOCAL_DEVNET.md) for full commands.
