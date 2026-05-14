# Production L1 Networking Experiments

## Log

### Rust Tests

```powershell
$env:CARGO_TARGET_DIR='devnet/local/cargo-target/manual-current'; cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml
```

Result: passed, 29 Rust integration tests.

### Network E2E

```powershell
npm run flowchain:network:e2e
```

Result: passed. Report written to `devnet/local/network-e2e/network-e2e-report.json`.

Evidence:

- Final height: `9`
- Final shared state root: `0x662b581b0723af4e6d707a150883df42c705051f3a1f7e1bfb8e6e6ab8aaf75f`
- Wrong-chain, wrong-genesis, unsupported-protocol, stale-head, and invalid-parent cases recorded.

### Multi-Node Smoke

```powershell
npm run flowchain:multi-node:smoke
```

Result: passed. Report written to `devnet/local/multi-node-smoke/multi-node-smoke-report.json`.

### Diff Check

```powershell
git diff --check
```

Result: passed.

## Expected Commands

```powershell
cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml
npm run flowchain:multi-node:smoke
npm run flowchain:network:e2e
git diff --check
```
