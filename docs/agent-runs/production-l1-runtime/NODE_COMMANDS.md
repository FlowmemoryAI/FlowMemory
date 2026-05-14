# Production L1 Runtime Node Commands

All commands run from the repository root.

## Root npm aliases

```powershell
npm run flowchain:node
npm run flowchain:node:stop
npm run flowchain:node:status
npm run flowchain:node:restart
npm run flowchain:tx -- --tx-file devnet/local/node-smoke/tx/signed-register-agent.json
npm run flowchain:node:smoke
```

## Rust CLI commands

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- node --node-id node:local:one --block-ms 1000
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- node-stop
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- node-status
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- node-restart --node-id node:local:one --max-blocks 1
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- tick
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- submit-tx --tx-file <path>
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- list-mempool
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- query-block --id 1
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- query-tx --id <tx-id>
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- query-receipt --id <tx-id>
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- query-account --id <account-id>
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- query-token --id <token-id>
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- query-pool --id <pool-id>
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- query-bridge-credit --id <credit-id>
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- query-finality --id <receipt-id>
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- export-state --out devnet/local/state-snapshot.json
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- import-state --from devnet/local/state-snapshot.json
```

Use `--state <path>` and `--node-dir <path>` before the command to isolate a runtime data directory.

## Node process contract

- Start: `node` opens or creates the local data directory, writes status, and produces blocks until stopped or until `--max-blocks` is reached.
- Stop: `node-stop` writes a stop file and updates stopped status.
- Restart: `node-restart` performs a stop then starts from the same state path and node directory.
- Status: `node-status` prints chain id, height, latest hash, finalized height, state root, mempool size, log path, and last error.
- Log path: `<node-dir>/node.log.jsonl`.
- Status path: `<node-dir>/status.json`.
