# FlowMemory Local Devnet Runtime

This directory is reserved for local runtime state from the no-value FlowMemory devnet prototype.

Default state path:

```text
devnet/local/state.json
```

`devnet/local/` is ignored by git. Do not commit local state files, generated blocks, generated handoff exports, secrets, or private keys.

Use:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- demo
```

See [docs/LOCAL_DEVNET.md](../docs/LOCAL_DEVNET.md) for full commands.
