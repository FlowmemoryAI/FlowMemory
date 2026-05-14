# FlowMemory Local Devnet

Status: runnable no-value private/local node runtime

The local FlowMemory devnet is a Rust node/CLI that models FlowMemory appchain-style state transitions without production consensus, tokenomics, public validator onboarding, or mainnet claims. It is the current private/local FlowChain runtime surface for second-computer validation.

It is local/no-value only. It has local test-unit balance and faucet records for runtime smoke and dashboard/control-plane testing, but those records are not tokens, rewards, staking, gas economics, bridge assets, or production deployment behavior.

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
npm run flowchain:node:smoke
```

## Commands

Windows-first root wrappers:

```powershell
npm run flowchain:init
npm run flowchain:start
npm run flowchain:node:start
npm run flowchain:node
npm run flowchain:node:stop
npm run flowchain:node:status
npm run flowchain:node:restart
npm run flowchain:bridge:ingest -- -HandoffPath <path>
npm run flowchain:tx -- --tx-file <path>
npm run flowchain:wallet:transfer:e2e
npm run flowchain:restart:verify
npm run flowchain:live-bridge:status
npm run flowchain:node:smoke
npm run flowchain:demo
npm run flowchain:full-smoke
npm run flowchain:export
npm run flowchain:stop
```

The wrappers call the Rust CLI below and write ignored operator/status/handoff/
export files under `devnet/local/`. The node wrapper starts the persistent
private/local runtime. Compatibility wrappers such as `flowchain:start` still
prepare launch-core fixtures and point operators at the node command.

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

Start the persistent local node:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- node --node-id node:local:one --block-ms 1000
npm run flowchain:node:start
```

Run a bounded node loop for automation:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- node --max-blocks 10
```

Stop, restart, and inspect node status:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- node-stop
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- node-restart --max-blocks 1
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- node-status
```

The status output includes chain id, height, latest hash, finalized height,
state root, receipt root, event root, mempool size, log path, and last error.

## Live Pilot Bridge Intake

The live pilot intake path is explicit and handoff-file based. It does not
broadcast Base transactions. A running node consumes a
`flowmemory.bridge_runtime_handoff.v0` file only when the handoff is marked
`productionReady: true`, `localOnly: false`, uses Base source chain id `8453`,
and includes satisfied 12-confirmation evidence.

```powershell
npm run flowchain:node:start
npm run flowchain:bridge:ingest -- -HandoffPath devnet/local/live-base8453-pilot-runtime/base8453-handoff-applied.json
npm run flowchain:wallet:transfer:e2e
npm run flowchain:restart:verify
npm run flowchain:live-bridge:status
npm run flowchain:no-secret:scan
```

Reports are written under:

```text
devnet/local/live-l1-bridge-intake/
```

The main runtime state is still `devnet/local/state.json`; bridge credits,
bridge credit receipts, replay keys, credited balances, and transfer receipts
must land there rather than in a temporary proof-only directory.

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

Submit a signed or locally authorized transaction file:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- submit-tx --tx-file devnet/local/node-smoke/tx/signed-register-agent.json
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- list-mempool
```

`submit-tx` accepts signed local transaction envelopes, a single `tx`, or a
batch under `txs`. A running node also ingests transaction JSON files from its
local inbox under `<node-dir>/tx/`, moves accepted or processed files under
`<node-dir>/processed/`, and writes structured rejection evidence for invalid
submissions.

Build a block from pending transactions:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- run-block
```

Manually tick the node block producer:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- tick
```

Run a bounded local block-production loop:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- start --blocks 3
```

`run --blocks 3` is an alias for `start --blocks 3`.

Run the single-node runtime for at least 10 persisted local blocks:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- start --blocks 10
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- inspect-state --summary
```

The second command reloads `devnet/local/state.json`, so it verifies the latest block height and parent hash survived process restart.

Run the full smoke flow:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- smoke
```

`smoke` now builds the native object lifecycle, writes state and handoff files, produces 10 deterministic local blocks, and proves deterministic single-node reconciliation by replaying the same flow twice and comparing block hashes, latest parent hash, state root, and map roots. LAN and multi-node networking are not exposed in this crate yet.

Run the production node smoke:

```powershell
npm run flowchain:node:smoke
```

The node smoke starts a node process, submits a signed envelope and a local
batch, produces at least 10 blocks, queries the tx and receipt, restarts the
node, rejects a replay, verifies bridge credit spendability, exports/imports
state, and writes `devnet/local/node-smoke/production-node-smoke-report.json`.

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

Query runtime state:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- query-block --id 1
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- query-tx --id <tx-id>
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- query-receipt --id <tx-id>
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- query-account --id <account-id>
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- query-token --id <token-id>
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- query-pool --id <pool-id>
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- query-bridge-credit --id <credit-id>
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- query-finality --id <finality-receipt-id>
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
6. Creates a local no-value test-unit balance record for the agent.
7. Credits that balance with a local no-value faucet record.
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
- `latestHeight`
- `latestHash`
- `finalizedHeight`
- `operatorKeyReferences`
- `rootfields`
- `agentAccounts`
- `accountNonces`
- `localTestUnitBalances`
- `faucetRecords`
- `balanceTransfers`
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
- `tokenDefinitions`
- `tokenBalances`
- `tokenMintReceipts`
- `tokenTransferReceipts`
- `dexPools`
- `lpPositions`
- `liquidityReceipts`
- `swapReceipts`
- `bridgeObservations`
- `bridgeCredits`
- `bridgeReplayKeys`
- `withdrawalIntents`
- `transactions`
- `receipts`
- `events`
- `consumedTxs`
- `replayKeys`
- `blocks`
- `pendingTxs`

`localTestUnitBalances`, `faucetRecords`, bridge credits, and withdrawal intents
are deterministic, no-value local records for runtime testing only. They are not
production assets and there is no gas accounting.

## Transaction Types

Supported local transactions:

- `RegisterRootfield`
- `RegisterAgent`
- `CreateLocalTestUnitBalance`
- `FaucetLocalTestUnits`
- `TransferLocalTestUnits`
- `RegisterModelPassport`
- `LaunchLocalTestToken`
- `MintLocalTestToken`
- `TransferLocalTestToken`
- `CreateLocalTestPool`
- `AddLocalTestLiquidity`
- `RemoveLocalTestLiquidity`
- `SwapLocalTestTokens`
- `ApplyBridgeCredit`
- `RequestWithdrawal`
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

- Agent and model records are identity/provenance records only; they do not hold balances.
- Local test-unit balance records are no-value runtime fixtures only; they do not create a token, monetary claim, fee market, staking role, reward, or bridge asset.
- Faucet records require an existing local test-unit balance, a unique faucet record id, and a positive amount.
- Local test-unit transfers require positive amounts and sufficient local balance.
- Bridge credits require Base source chain id `8453`, a unique replay key, and positive credit amount; they are local/private handoff records only.
- Withdrawal intents debit local spendable balance and record a test-mode intent without broadcasting a production withdrawal.
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
- Events.
- State root.
- Receipt root.
- Event root.
- Finalized height.
- Block hash.

The devnet uses deterministic logical time and canonical JSON with Keccak-256. Tests prove the same inputs produce the same state root and block hash.

`inspect-state --summary`, exported handoff files, and Base anchor placeholders include deterministic roots for the local maps, including operator key references, agent accounts, local test-unit balances, faucet records, model passports, memory cells, challenges, finality receipts, artifact availability proofs, verifier modules, work receipts, and verifier reports.

## Persistence

Default local state:

```text
devnet/local/state.json
devnet/local/node/status.json
devnet/local/node/node.log.jsonl
devnet/local/runtime-handoff.json
devnet/local/handoff/
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

Runtime handoff files:

- `devnet/local/runtime-handoff.json`
- `devnet/local/handoff/dashboard-state.json`
- `devnet/local/handoff/indexer-handoff.json`
- `devnet/local/handoff/verifier-handoff.json`
- `devnet/local/handoff/control-plane-handoff.json`
- `devnet/local/handoff/genesis-config.json`
- `devnet/local/handoff/operator-key-references.json`
- `devnet/local/handoff/state.json`

The generated dashboard, indexer, verifier, and state outputs include the expanded local object maps, transaction indexes, receipt/event indexes, bridge-credit state, withdrawal intents, and deterministic map roots. These are local prototype outputs. Review before committing generated copies.

The control-plane handoff contains the current chain id, latest block, blocks, pending transactions, object maps, deterministic map roots, genesis config, and operator key references. It is intended for local services to consume without reading ignored `devnet/local/` files.

Control-plane, RPC, and dashboard agents should read:

- `latestHeight`, `latestHash`, `finalizedHeight`, `stateRoot`, `receiptRoot`, and `eventRoot` for chain status.
- `pendingTxs`, `accountNonces`, `consumedTxs`, and `bridgeReplayKeys` for mempool/replay state.
- `transactions`, `receipts`, and `events` for query surfaces.
- `objects.localTestUnitBalances` and `objects.faucetRecords` from `control-plane-handoff.json`.
- `objects.bridgeCredits`, `objects.bridgeObservations`, and `objects.withdrawalIntents` from `control-plane-handoff.json`.
- Top-level `localTestUnitBalances` and `faucetRecords` from `dashboard-state.json`.
- Top-level `transactions`, `receipts`, `events`, `bridgeCredits`, and `withdrawalIntents` from `dashboard-state.json`.
- `mapRoots.localTestUnitBalanceRoot` and `mapRoots.faucetRecordRoot` anywhere map-root reconciliation is needed.

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
