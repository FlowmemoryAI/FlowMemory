# FlowMemory Local Devnet

Status: runnable no-value local runtime with bounded and long-running node modes

The local FlowMemory devnet is a Rust CLI that models FlowMemory appchain-style state transitions without production consensus, tokenomics, bridge assets, public validator onboarding, or mainnet claims.

It is local/no-value only. It has no rewards, staking, gas economics, bridge security, or production deployment behavior. It includes a local test-unit ledger so private/local transactions can be funded and smoke-tested; those records are not tokenomics and have no external value.

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
npm run flowchain:node
npm run flowchain:node:status
npm run flowchain:tx
npm run flowchain:faucet
npm run flowchain:demo
npm run flowchain:export
npm run flowchain:node:stop
npm run flowchain:stop
npm run flowchain:node:smoke
npm run flowchain:multi-node:smoke
```

The wrappers call the Rust CLI below and write ignored operator/status/handoff/
export files under `devnet/local/`. `flowchain:start` remains a compatibility
wrapper for launch-core preparation and summary inspection. `flowchain:node`
starts the long-running private/local runtime.

Initialize state:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- init
```

`init` writes deterministic genesis state plus local boundary files next to the state file:

```text
devnet/local/state.json
devnet/local/genesis-config.json
devnet/local/operator-key-references.json
```

The operator key file is a reference boundary only. It records local fixture identifiers and crypto schema references, but no signing secret material.

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

Start a long-running local node:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/state.json --node-dir devnet/local/node node --node-id node:local:alpha --block-ms 1000
```

The node writes:

```text
devnet/local/node/node-identity.json
devnet/local/node/status.json
devnet/local/node/inbox/
devnet/local/node/processed/
devnet/local/node/rejected/
devnet/local/node/stop
```

Stop and inspect the node:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/state.json --node-dir devnet/local/node node-status
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/state.json --node-dir devnet/local/node node-stop
```

Submit a local transaction to the node inbox:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/state.json --node-dir devnet/local/node submit-tx --tx-file devnet/local/tx/sample-agent-registration.json --authorized-by local-operator
```

Credit a local test-unit account through the faucet transaction path:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/state.json --node-dir devnet/local/node faucet --account local-account:operator --amount 1000 --authorized-by local-operator
```

Run one manual node tick:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/state.json --node-dir devnet/local/node tick --node-id node:local:alpha
```

Run the bounded node smokes:

```powershell
npm run flowchain:node:smoke
npm run flowchain:multi-node:smoke
```

Run a bounded local block-production loop:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- start --blocks 3
```

`run --blocks 3` is an alias for `start --blocks 3`.

Run the full smoke flow:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- smoke
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

`export` is an alias for `export-fixtures`.

Export and import a full state snapshot:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- export-state --out fixtures/handoff/generated/state-snapshot.json
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/imported-state.json import-state --from fixtures/handoff/generated/state-snapshot.json
```

Use a custom state path:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/custom-state.json demo
```

## What The Demo Builds

The demo:

1. Starts from deterministic genesis.
2. Initializes local no-value genesis config and operator key references.
3. Registers a rootfield.
4. Registers a model passport.
5. Registers an agent account.
6. Credits local test units through the faucet record path.
7. Transfers local test units to the demo agent id.
8. Registers a verifier module identity.
9. Submits an artifact commitment.
10. Marks artifact availability with a local proof/status object.
11. Commits a latest root.
12. Submits a work receipt.
13. Submits an accepted verifier report.
14. Updates a memory cell from the accepted receipt.
15. Opens and resolves a challenge.
16. Finalizes the work receipt.
17. Builds block 1.
18. Creates a Base settlement anchor placeholder with deterministic map roots.
19. Builds block 2.
20. Writes state to `devnet/local/state.json`.
21. Exports dashboard, indexer, verifier, control-plane, config, key-reference, and full-state handoff files to `fixtures/handoff/generated/`.

## State Model

The prototype stores:

- `config`
- `operatorKeyReferences`
- `localBalances`
- `faucetRecords`
- `balanceTransfers`
- `rootfields`
- `agentAccounts`
- `modelPassports`
- `memoryCells`
- `challenges`
- `finalityReceipts`
- `artifactCommitments`
- `artifactAvailabilityProofs`
- `verifierModules`
- `workReceipts`
- `verifierReports`
- `importedObservations`
- `importedVerifierReports`
- `baseAnchors`
- `blocks`
- `pendingTxs`

The local balance maps are private/local test-unit records only. There are no token balances, rewards, fees, staking, or gas accounting.

## Transaction Types

Supported local transactions:

- `RegisterRootfield`
- `FaucetLocalBalance`
- `TransferLocalBalance`
- `RegisterAgent`
- `RegisterModelPassport`
- `CommitRoot`
- `SubmitArtifactCommitment`
- `MarkArtifactAvailability`
- `SubmitWorkReceipt`
- `SubmitVerifierReport`
- `RegisterVerifierModule`
- `UpdateMemoryCell`
- `OpenChallenge`
- `ResolveChallenge`
- `FinalizeWorkReceipt`
- `AnchorBatchToBasePlaceholder`
- `ImportFlowPulseObservation`
- `ImportVerifierReport`

## Local Lifecycle Rules

- Agent and model records are identity/provenance records only. Local test-unit balances live in the separate local balance ledger and do not imply tokenomics.
- Faucet records can credit local test units to an account id for smoke testing.
- Local balance transfers require sufficient local test-unit balance and produce deterministic transfer records.
- Work receipts must reference an existing artifact commitment in the same rootfield.
- Verifier reports must reference an existing active verifier module and an existing receipt in the same rootfield.
- Memory cells can be created or updated only from an existing work receipt with an accepted local verifier report.
- A failed, invalid, rejected, unsupported, reorged, missing, or still-unaccepted receipt cannot update memory.
- Challenges can be opened only against existing receipts.
- Finality receipts can be created only for accepted receipts with no unresolved challenge.
- Artifact availability is a local proof/status record over an existing artifact commitment; it does not store raw artifact data.
- Verifier modules are local identity records for verifier provenance; they do not introduce staking, rewards, or verifier economics.

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

`inspect-state --summary`, exported handoff files, and Base anchor placeholders include deterministic roots for the local maps, including operator key references, local balances, faucet records, balance transfers, agent accounts, model passports, memory cells, challenges, finality receipts, artifact availability proofs, verifier modules, work receipts, and verifier reports.

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
- `fixtures/handoff/generated/control-plane-handoff.json`
- `fixtures/handoff/generated/genesis-config.json`
- `fixtures/handoff/generated/operator-key-references.json`
- `fixtures/handoff/generated/state.json`

The generated dashboard, indexer, verifier, and state outputs include the expanded local object maps and deterministic map roots. These are local prototype outputs. Review before committing generated copies.

The control-plane handoff contains the current chain id, latest block, blocks, pending transactions, object maps, deterministic map roots, genesis config, and operator key references. It is intended for local services to consume without reading ignored `devnet/local/` files.

Node identity and status files are local operator files under `devnet/local/node/`.
They are not committed handoff fixtures, but they provide the local node id,
process id, state path, latest block, state root, inbox counts, and LAN boundary
for second-computer debugging.

## Static Local Peers

LAN mode is not exposed in this package. Multi-node smoke uses static local-file
peer state paths. A peer config has this shape:

```json
{
  "schema": "flowmemory.local_devnet.static_peers.v0",
  "nodeId": "node:local:a",
  "peers": [
    {
      "nodeId": "node:local:b",
      "statePath": "devnet/local/node-b/state.json"
    }
  ]
}
```

When a node sees a peer state file for the same chain with a longer height, or
an equal-height deterministic lower state root, it adopts that state. This is a
local deterministic reconciliation model for second-computer validation, not a
production networking or consensus protocol.

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
