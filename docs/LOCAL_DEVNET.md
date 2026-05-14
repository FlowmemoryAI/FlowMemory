# FlowMemory Local Devnet

Status: runnable no-value private/local runtime with local authority-set consensus

The local FlowMemory devnet is a Rust CLI that models FlowMemory appchain-style state transitions with a private/local authority-set consensus profile. It does not implement public permissionless validators, tokenomics, bridge assets, public validator onboarding, or mainnet claims. It is the current private/local FlowChain runtime surface for second-computer validation.

It is local/no-value only. It has local test-unit balance and faucet records for runtime smoke and dashboard/control-plane testing, but those records are not tokens, rewards, staking, gas economics, bridge assets, or production deployment behavior.

## Framework Decision

The prototype uses a simple custom Rust devnet under `crates/flowmemory-devnet`.

Reason:

- Rust is a better long-term fit for chain/node work than ad hoc scripts.
- The local model needs deterministic state roots, block hashes, and tests.
- A full OP Stack/Base Appchain deployment would be premature before schemas and anchors stabilize.
- Public permissionless consensus is explicitly out of scope; the current profile is a deterministic private/local authority set for local L1 validation.

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

Run the consensus smoke:

```powershell
npm run flowchain:consensus:smoke
```

Equivalent Rust command:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- consensus-smoke --out-dir devnet/local/consensus-smoke
```

The consensus smoke writes:

```text
devnet/local/consensus-smoke/consensus-report.json
devnet/local/consensus-smoke/finality-proof.json
devnet/local/consensus-smoke/fork-choice-proof.json
devnet/local/consensus-smoke/state-snapshot.json
devnet/local/consensus-smoke/handoff/
```

Verify live-L1 consensus/finality readiness:

```powershell
npm run flowchain:consensus:live-l1:verify
```

The live-L1 verifier writes:

```text
devnet/local/live-l1-consensus/consensus-finality-report.json
devnet/local/live-l1-consensus/bridge-lifecycle-evidence.json
```

The verifier fails if an existing readiness report claims public/live finality or public-L1 acceptability while the runtime is still the private/local single-process authority-set profile. In the current profile, private live pilot scope is acceptable and public L1 readiness is blocked.

Inspect consensus state:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- consensus-validate
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- validator-set
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- finality-status
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- fork-choice-test --out devnet/local/fork-choice-proof.json
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- write-finality-proof --out devnet/local/finality-proof.json
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
- `faucetRecords`
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

`localTestUnitBalances` and `faucetRecords` are deterministic, no-value local records for runtime testing only. They are not token balances and there is no gas accounting.

## Transaction Types

Supported local transactions:

- `RegisterRootfield`
- `RegisterAgent`
- `CreateLocalTestUnitBalance`
- `FaucetLocalTestUnits`
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
- Local test-unit balance records are no-value runtime fixtures only; they do not create a token, monetary claim, fee market, staking role, reward, or bridge asset.
- Faucet records require an existing local test-unit balance, a unique faucet record id, and a positive amount.
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
- Chain id.
- Genesis hash.
- Authority-set id.
- Proposer id.
- Parent hash.
- Logical time.
- Transaction ids.
- Transaction root.
- Receipts.
- Receipt root.
- Event root.
- State root.
- Local authority proof.
- Block hash.

The devnet uses deterministic logical time and canonical JSON with Keccak-256. Tests prove the same inputs produce the same state root and block hash. Blocks are proposed by the configured private/local authority set, validate parent/hash/height/time/proposer/roots, and finalize immediately under the local single-authority profile.

Consensus state includes:

- `validatorSet`
- `authoritySet`
- `consensusState`
- `chainFinalityReceipts`
- `forkEvidence`
- `misbehaviorEvidence`
- `bridgeReplayKeys`

The local finality rule is immediate finality for a validated canonical block signed by the configured private/local authority proof. Static local peer sync adopts only valid chains and uses highest height, then lexicographically lowest canonical block hash as a deterministic tie-breaker. This is not public validator readiness.

`inspect-state --summary`, exported handoff files, and Base anchor placeholders include deterministic roots for the local maps, including operator key references, agent accounts, local test-unit balances, faucet records, model passports, memory cells, challenges, finality receipts, artifact availability proofs, verifier modules, work receipts, and verifier reports.

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
- `fixtures/handoff/generated/validator-set.json`
- `fixtures/handoff/generated/consensus-state.json`
- `fixtures/handoff/generated/finality-status.json`
- `fixtures/handoff/generated/state.json`

The generated dashboard, indexer, verifier, control-plane, and state outputs include consensus/finality fields, expanded local object maps, and deterministic map roots. These are local prototype outputs. Review before committing generated copies.

The control-plane handoff contains the current chain id, latest block, blocks, pending transactions, object maps, deterministic map roots, genesis config, and operator key references. It is intended for local services to consume without reading ignored `devnet/local/` files.

Control-plane and dashboard agents should read:

- `objects.localTestUnitBalances` and `objects.faucetRecords` from `control-plane-handoff.json`.
- Top-level `localTestUnitBalances` and `faucetRecords` from `dashboard-state.json`.
- `mapRoots.localTestUnitBalanceRoot` and `mapRoots.faucetRecordRoot` anywhere map-root reconciliation is needed.

## Non-Goals

- No production consensus.
- No public or permissionless validator set.
- No public validator onboarding.
- No staking, slashing, rewards, validator economics, or public validator readiness.
- No tokenomics.
- No validator rewards.
- No staking or slashing.
- No mainnet deployment.
- No bridge security claims.
- No live Base settlement.
- No raw AI memory or artifacts on-chain.
- No hardware validator requirements.
