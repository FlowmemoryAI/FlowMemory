# FlowMemory Local Devnet

Status: runnable no-value prototype

The local FlowMemory devnet is a Rust CLI that models FlowMemory appchain-style state transitions without production consensus, tokenomics, bridge assets, or mainnet claims.

## Framework Decision

The prototype uses a simple custom Rust devnet under `crates/flowmemory-devnet`.

Reason:

- Rust is a better long-term fit for chain/node work than ad hoc scripts.
- The local model needs deterministic state roots, block hashes, and tests.
- A full OP Stack/Base Appchain deployment would be premature before schemas and anchors stabilize.
- Custom consensus is explicitly out of scope.

Decision record: [2026-05-13-no-value-local-appchain-prototype.md](DECISIONS/2026-05-13-no-value-local-appchain-prototype.md)

## Install/Build

From repo root:

```powershell
cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml
```

## Commands

Windows-first root wrappers:

```powershell
npm run flowchain:init
npm run flowchain:start
npm run flowchain:demo
npm run flowchain:export
npm run flowchain:stop
```

The wrappers call the Rust CLI below and write ignored operator/status/handoff/
export files under `devnet/local/`. The current runtime is still a
deterministic local CLI, not a long-running node.

Initialize state:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- init
```

Reset local state:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- reset-local
```

Run the full deterministic demo:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- demo
```

Inspect summary:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- inspect-state --summary
```

Submit a transaction fixture:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- submit-fixture --fixture fixtures/handoff/sample-txs.json
```

Build a block from pending transactions:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- run-block
```

Import a FlowPulse observation fixture:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- submit-fixture --fixture fixtures/handoff/sample-flowpulse-observation.json
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- run-block
```

Import a verifier report fixture:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- submit-fixture --fixture fixtures/handoff/sample-verifier-report.json
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- run-block
```

Export handoff fixtures:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- export-fixtures --out-dir fixtures/handoff/generated
```

Use a custom state path:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/custom-state.json demo
```

## What The Demo Builds

The demo:

1. Starts from deterministic genesis.
2. Registers a rootfield.
3. Submits an artifact commitment.
4. Commits a latest root.
5. Submits a work receipt.
6. Submits a verifier report.
7. Builds block 1.
8. Creates a Base settlement anchor placeholder.
9. Builds block 2.
10. Writes state to `devnet/local/state.json`.
11. Exports handoff files to `fixtures/handoff/generated/`.

## State Model

The prototype stores:

- `rootfields`
- `artifactCommitments`
- `workReceipts`
- `verifierReports`
- `importedObservations`
- `importedVerifierReports`
- `baseAnchors`
- `blocks`
- `pendingTxs`

There are no token balances and no gas accounting.

## Transaction Types

Supported local transactions:

- `RegisterRootfield`
- `CommitRoot`
- `SubmitArtifactCommitment`
- `SubmitWorkReceipt`
- `SubmitVerifierReport`
- `AnchorBatchToBasePlaceholder`
- `ImportFlowPulseObservation`
- `ImportVerifierReport`

## Blocks And Roots

Each block has:

- Block number.
- Parent hash.
- Logical time.
- Transaction ids.
- Receipts.
- State root.
- Block hash.

The devnet uses deterministic logical time and canonical JSON with Keccak-256. Tests prove the same inputs produce the same state root and block hash.

## Persistence

Default local state:

```text
devnet/local/state.json
```

`devnet/local/` is ignored by git.

## Handoff Files

Generated exports:

- `fixtures/handoff/generated/dashboard-state.json`
- `fixtures/handoff/generated/indexer-handoff.json`
- `fixtures/handoff/generated/verifier-handoff.json`
- `fixtures/handoff/generated/state.json`

These are local prototype outputs. Review before committing generated copies.

## Non-Goals

- No production consensus.
- No validator set.
- No tokenomics.
- No validator rewards.
- No staking or slashing.
- No mainnet deployment.
- No bridge security claims.
- No live Base settlement.
- No raw AI memory or artifacts on-chain.
- No hardware validator requirements.
