# Production L1 Storage Plan

Status: complete

## Scope

- Worktree: `E:\FlowMemory\flowmemory-prod-storage`
- Branch: `agent/production-l1-storage`
- Editable scope: `crates/flowmemory-devnet/`, `devnet/`, storage-related `infra/scripts/flowchain-*.ps1`, `docs/LOCAL_DEVNET.md`, `docs/agent-runs/production-l1-storage/`, and `package.json` storage aliases only.
- Forbidden scope: `services/`, `contracts/`, `crypto/`, `apps/dashboard/`, `hardware/`, and local secret files.

## Source Context Read

- `AGENTS.md`
- `docs/START_HERE.md`
- `docs/FLOWMEMORY_HQ_CONTEXT.md`
- `docs/CURRENT_STATE.md`
- `docs/LOCAL_DEVNET.md`
- `docs/agent-goals/full-l1/chain-runtime.md`
- `docs/agent-goals/full-l1/bridge-relayer.md`
- `docs/agent-runs/real-value-pilot-control-dashboard/PLAN.md`
- `docs/agent-runs/real-value-pilot-control-dashboard/NOTES.md`
- `crates/flowmemory-devnet/src/storage.rs`
- `crates/flowmemory-devnet/src/model.rs`
- `crates/flowmemory-devnet/src/cli.rs`
- `infra/scripts/flowchain-export.ps1`
- `infra/scripts/flowchain-import.ps1`

## Current Runtime Inventory

Mutable `ChainState` fields:

- Chain metadata: `schema`, `config`, `chain_id`, `genesis_hash`, `next_block_number`, `logical_time`, `parent_hash`.
- Local operator references: `operator_key_references`.
- Protocol/rootflow objects: `rootfields`, `artifact_commitments`, `artifact_availability_proofs`, `work_receipts`, `verifier_reports`, `verifier_modules`, `memory_cells`, `challenges`, `finality_receipts`, `base_anchors`.
- Account and no-value ledger objects: `agent_accounts`, `local_test_unit_balances`, `faucet_records`, `balance_transfers`.
- Token and DEX objects: `token_definitions`, `token_balances`, `token_mint_receipts`, `dex_pools`, `lp_positions`, `liquidity_receipts`, `swap_receipts`.
- Imported evidence objects: `imported_observations`, `imported_verifier_reports`.
- Chain execution objects: `blocks`, `pending_txs`.

Current transaction payload types:

- Rootflow/protocol: `RegisterRootfield`, `CommitRoot`, `SubmitArtifactCommitment`, `MarkArtifactAvailability`, `SubmitWorkReceipt`, `SubmitVerifierReport`, `RegisterVerifierModule`, `UpdateMemoryCell`, `OpenChallenge`, `ResolveChallenge`, `FinalizeWorkReceipt`, `AnchorBatchToBasePlaceholder`.
- Account and ledger: `RegisterAgent`, `CreateLocalTestUnitBalance`, `FaucetLocalTestUnits`, `TransferLocalTestUnits`.
- Token and DEX: `LaunchToken`, `MintLocalTestToken`, `CreatePool`, `AddLiquidity`, `RemoveLiquidity`, `SwapExactIn`.
- Imported evidence: `ImportFlowPulseObservation`, `ImportVerifierReport`.
- Gap to add: bridge observation, bridge credit, withdrawal intent, release evidence, replay-key consumption.

Current receipt fields:

- `BlockReceipt`: `tx_id`, `status`, `error`, `authorization`.
- Domain receipt-like records: faucet records, balance transfers, token mint receipts, liquidity receipts, swap receipts, work receipts, verifier reports, artifact availability proofs, finality receipts, imported verifier reports, base anchors.
- Gap: no persisted receipt index or receipt path per transaction.

Current event types:

- No separate event enum exists. Queryable events must be derived from applied transaction records and persisted as durable event records.
- Required event families: account registration, local balance create/faucet/transfer, token launch/mint, pool create, liquidity add/remove, swap, rootfield registration/root commit, artifact availability, work receipt, verifier report, memory update, challenge open/resolve, finality, imported FlowPulse observation, imported verifier report, bridge observation, bridge credit, withdrawal intent, release evidence.

API/query surfaces that need indexes:

- By block height/hash.
- By transaction id.
- By receipt id and transaction id.
- By event id.
- By account id/controller/owner and account transaction ids.
- By token id/symbol and token events.
- By pool id and liquidity/swap/LP events.
- By rootfield id, work receipt id, verifier report id, finality receipt id.
- By bridge observation id, bridge credit id, withdrawal intent id, replay key, and source event key.

## Existing Storage Gaps

- `storage.rs` stores the whole runtime in `devnet/local/state.json`; block bodies, receipts, indexes, snapshots, and manifest are not first-class durable files.
- `save_state` writes directly to the final path, so interrupted writes can corrupt the only canonical state file.
- Export/import currently copies state JSON without schema/root validation, clean-destination enforcement, or chain/genesis rejection.
- Indexes are missing and queries would have to scan state or blocks.
- Bridge observation/credit/withdrawal/release persistence is not present in the Rust runtime.
- Pruning/archival behavior is not documented as a storage policy.

## Durable Data Contract Direction

- Introduce a data directory alongside the configured state path. For `devnet/local/state.json`, durable storage lives under `devnet/local/storage/`.
- Store a manifest atomically with schema version, chain id, genesis hash, data directory, latest height/hash, finalized height/hash, state root, archival/pruning policy, and tool version.
- Keep `state.json` as a compatibility snapshot, but make it an atomic snapshot emitted from the durable data directory.
- Persist block, header, transaction, receipt, event, object, snapshot, and index records as deterministic JSON.
- Use temp-write-then-rename for manifest, state snapshot, block records, receipt/event files, indexes, and export files.
- Rebuild or validate indexes from durable records on startup and during explicit health checks.

## Implementation Phases

1. Add bridge persistence fields and transaction payloads to the Rust model.
2. Add deterministic event generation from transactions and receipts.
3. Implement storage manifest, directory layout, atomic write helper, export snapshot schema, import validation, and index records.
4. Replace direct state writes with durable storage commits while preserving existing CLI behavior.
5. Add startup validation/recovery and index health checks.
6. Add CLI commands and root wrapper behavior for storage export/import/e2e.
7. Add restart, malformed import, wrong chain, missing receipt, duplicate index, canonical mismatch, finalized mismatch, and crash injection tests.
8. Write proof documents and update `docs/LOCAL_DEVNET.md`.

## Policy Choices

- Default storage mode: archival for this private/local runtime. No pruning is performed unless a future explicit pruning command is added.
- Mempool persistence: pending transactions remain in the state snapshot and are also exported/imported. Inbox files remain node-local intake artifacts and are not promoted to chain history until included in a block.
- Bridge persistence: store public evidence references only. Do not export env files, network endpoints, signing secrets, recovery phrases, API credentials, or callback URLs.

## Implemented Output

- Durable storage layout under `storage/` beside `state.json`.
- Atomic JSON writes for state snapshots, manifests, blocks, headers, transactions, receipts, events, object maps, indexes, exports, and handoff JSON.
- Manifest validation for schema, storage version, chain id, genesis hash, canonical tip, finalized point, and state root.
- Bridge runtime persistence for observations, credits, replay-key consumption, withdrawal intents, and release evidence.
- Deterministic state root includes schema, chain id, genesis hash, latest/finalized point, accounts, balances, tokens, DEX state, bridge state, receipts, memory/verifier state, and base anchors.
- Durable indexes for transaction, receipt, event, account, balance-change, token, pool, rootfield, bridge observation, bridge credit, withdrawal intent, release evidence, and replay-key lookup.
- Deterministic export/import with clean-destination enforcement and bad-export rejection.
- Legacy raw state migration with backup under `storage/backups/`.
- Restart and corruption recovery coverage in Rust tests and the storage E2E command.
