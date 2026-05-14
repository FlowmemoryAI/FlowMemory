# FlowMemory Local Devnet

Status: runnable no-value private/local runtime

The local FlowMemory devnet is a Rust CLI that models FlowMemory appchain-style state transitions without production consensus, tokenomics, bridge assets, public validator onboarding, or mainnet claims. It is the current private/local FlowChain runtime surface for second-computer validation.

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
```

## Commands

Windows-first root wrappers:

```powershell
npm run flowchain:init
npm run flowchain:start
npm run flowchain:demo
npm run flowchain:full-smoke
npm run flowchain:export
npm run flowchain:execution:e2e
npm run flowchain:stop
```

The wrappers call the Rust CLI below and write ignored operator/status/handoff/
export files under `devnet/local/`. The current runtime is still a
deterministic local CLI, not a long-running node.

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

Run the local product execution flow:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- product-smoke
```

`product-smoke` starts from deterministic genesis, applies a local bridge credit, transfers local test units between wallets, launches a no-value local test token, transfers that token, creates a local DEX pool, adds liquidity, swaps exact input with a minimum-output guard, removes liquidity, anchors the resulting state, and checks that the product receipts are queryable.

Run the stricter execution E2E:

```powershell
npm run flowchain:execution:e2e
```

The execution E2E writes:

```text
devnet/local/execution-e2e/state.json
devnet/local/execution-e2e/execution-e2e-report.json
```

The report includes transaction ids, receipt ids, account balances, token balances, pool reserves, LP positions, swap result, state root, map roots, queryable ids, and failed transaction evidence.

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
- `operatorKeyReferences`
- `rootfields`
- `agentAccounts`
- `localTestUnitBalances`
- `accountNonces`
- `faucetRecords`
- `balanceTransfers`
- `bridgeCreditReceipts`
- `tokenDefinitions`
- `tokenBalances`
- `tokenMintReceipts`
- `tokenTransferReceipts`
- `dexPools`
- `lpPositions`
- `liquidityReceipts`
- `swapReceipts`
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
- `executionReceipts`
- `executionEvents`
- `blocks`
- `pendingTxs`

`localTestUnitBalances`, `faucetRecords`, `bridgeCreditReceipts`, token state, DEX state, execution receipts, and execution events are deterministic, no-value local records for runtime testing only. They are not production balances, rewards, staking state, public gas economics, or bridge security claims.

## Transaction Types

Supported local transactions:

- `RegisterRootfield`
- `RegisterAgent`
- `CreateLocalTestUnitBalance`
- `FaucetLocalTestUnits`
- `TransferLocalTestUnits`
- `ApplyBridgeCredit`
- `LaunchToken`
- `MintLocalTestToken`
- `TransferToken`
- `CreatePool`
- `AddLiquidity`
- `RemoveLiquidity`
- `SwapExactIn`
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

- Agent and model records are identity/provenance records only; they do not hold balances.
- Local test-unit balance records are no-value runtime fixtures only; they do not create a token, monetary claim, fee market, staking role, reward, or production bridge asset.
- Faucet records require an existing local test-unit balance, a unique faucet record id, and a positive amount.
- Native local transfers require existing source and destination balances, a positive amount, available source units, and the next expected account nonce.
- Bridge credits are local pilot credit receipts. A credit has a deterministic credit id plus replay key, must be positive, can fund the local test-unit asset, and cannot be applied twice.
- The pilot bridge-credit spend path uses `asset:flowchain-local-test-unit` as a wrapped local asset. Bridged Base ETH or ERC20 custody is not modeled in this crate.
- Account nonces are deterministic per account. Reusing the last nonce fails as duplicate; lower or skipped nonces fail as stale.
- Local execution costs use a deterministic cost table and are recorded in every execution receipt. The default fee behavior is record-only; `charge-native` mode can be enabled in config for tests that debit local test units.
- Token launch validates deterministic token id, symbol, name, decimals, initial owner balance, duplicate id, duplicate symbol, and positive supply.
- Local test mint is permitted only as explicit local/test transaction state. It records a mint receipt and updates no-value total supply.
- Token transfers require positive amount, existing accounts, existing token, available source token balance, and the next expected account nonce.
- Pool creation requires a deterministic pool id, valid distinct assets, existing creator account, and a unique pool.
- Liquidity add/remove updates reserves, LP supply, LP position accounting, and liquidity receipts with deterministic floor rounding.
- Exact-input swaps update reserves and account balances, produce a swap receipt, and fail if the pool is invalid, liquidity is insufficient, the amount is zero, or minimum output is not met.
- Failed transactions are atomic: the business state is not partially mutated, but a failed execution receipt and `execution_failed` event are recorded.
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
- Execution receipt id, success flag, execution cost units, charged flag, error code, and event ids for each transaction receipt.
- State root.
- Block hash.

The devnet uses deterministic logical time and canonical JSON with Keccak-256. Tests prove the same inputs produce the same state root and block hash.

`inspect-state --summary`, exported handoff files, and Base anchor placeholders include deterministic roots for the local maps, including operator key references, agent accounts, local test-unit balances, account nonces, faucet records, balance transfers, bridge credit receipts, token definitions, token balances, token mint receipts, token transfer receipts, DEX pools, LP positions, liquidity receipts, swap receipts, model passports, memory cells, challenges, finality receipts, artifact availability proofs, verifier modules, work receipts, verifier reports, execution receipts, and execution events.

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

Control-plane and dashboard agents should read:

- `objects.localTestUnitBalances` and `objects.faucetRecords` from `control-plane-handoff.json`.
- `objects.accountNonces`, `objects.balanceTransfers`, `objects.bridgeCreditReceipts`, `objects.tokenDefinitions`, `objects.tokenBalances`, `objects.tokenTransferReceipts`, `objects.dexPools`, `objects.lpPositions`, `objects.liquidityReceipts`, `objects.swapReceipts`, `objects.executionReceipts`, and `objects.executionEvents` from `control-plane-handoff.json`.
- Top-level `localTestUnitBalances` and `faucetRecords` from `dashboard-state.json`.
- Top-level token, DEX, receipt, nonce, and execution maps from `dashboard-state.json`.
- `mapRoots.localTestUnitBalanceRoot`, `mapRoots.accountNonceRoot`, `mapRoots.bridgeCreditReceiptRoot`, `mapRoots.tokenBalanceRoot`, `mapRoots.dexPoolRoot`, `mapRoots.lpPositionRoot`, `mapRoots.executionReceiptRoot`, and `mapRoots.executionEventRoot` anywhere map-root reconciliation is needed.

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
