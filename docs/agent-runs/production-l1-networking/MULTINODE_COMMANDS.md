# Multinode Commands

## Required Smoke

```powershell
npm run flowchain:multi-node:smoke
```

Writes:

```text
devnet/local/multi-node-smoke/multi-node-smoke-report.json
```

## Strict Network E2E

```powershell
npm run flowchain:network:e2e
```

Writes:

```text
devnet/local/network-e2e/network-e2e-report.json
```

## Manual Node Operations

Start a bounded local node:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/network-e2e/node-a-state.json --node-dir devnet/local/network-e2e/node-a node --node-id node:network:a --peer-config devnet/local/network-e2e/node-a-peers.json --max-blocks 3
```

Stop a node:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/network-e2e/node-a-state.json --node-dir devnet/local/network-e2e/node-a node-stop
```

Print status:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/network-e2e/node-a-state.json --node-dir devnet/local/network-e2e/node-a node-status
```

Run deterministic sync without producing a block:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/network-e2e/node-b-state.json --node-dir devnet/local/network-e2e/node-b sync --node-id node:network:b --peer-config devnet/local/network-e2e/node-b-peers.json
```

Submit a locally authorized transaction:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/network-e2e/node-a-state.json --node-dir devnet/local/network-e2e/node-a faucet --account local-account:network-e2e --amount 77 --reason network-e2e --authorized-by local-network-operator
```
