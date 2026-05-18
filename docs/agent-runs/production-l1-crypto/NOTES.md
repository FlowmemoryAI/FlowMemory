# Owner-Gated L1 Crypto Notes

## Initial Boundaries

- GitHub is the source of truth for merged project state.
- Local worktree branch: `agent/production-l1-crypto`.
- Current repository state describes FlowChain as a private/local L1 testnet package target, not production deployment approval.
- The work must extend `crypto/` rather than adding a second crypto package, wallet format, transaction envelope, or hashing system.
- Runtime/control-plane validation must not import wallet vault code.
- Fixtures and public metadata must contain deterministic public test material only.

## Read Context

- `AGENTS.md`
- `docs/START_HERE.md`
- `docs/FLOWMEMORY_HQ_CONTEXT.md`
- `docs/CURRENT_STATE.md`
- `docs/ROOTFLOW_V0.md`
- `docs/FLOW_MEMORY_V0.md`
- `docs/V0_LAUNCH_ACCEPTANCE.md`
- `docs/DECISIONS/`
- `crates/flowmemory-devnet/src/model.rs` as read-only consumer context
- `services/control-plane/src/types.ts` as read-only consumer context

The optional production protocol handoff file was not present at the expected path during the first read.

## Inventory

Current crypto package root exports before this task included:

- attestations
- constants
- domains
- encoding
- FlowPulse helpers
- hashes
- Merkle helpers
- object ID helpers and local-alpha envelope validation
- pilot envelope validation and pilot operator helpers
- local transaction helpers
- wallet/vault helpers

Wallet-only exports:

- `createEncryptedTestVault`
- `unlockEncryptedTestVault`
- `addEncryptedTestVaultAccount`
- `rotateEncryptedTestVaultAccount`
- `signLocalTransactionWithVault`
- wallet CLI commands under `crypto/src/wallet-cli.js`

Runtime-safe exports after this task:

- `@flowmemory/crypto/runtime-validation`
- `verifyFlowchainEnvelope`
- identity and hash helpers reachable from the runtime validation dependency graph

Current transaction fixture sets:

- `crypto/fixtures/local-alpha-objects.json`
- `crypto/fixtures/product-testnet-transactions.json`
- `crypto/fixtures/local-transaction-vectors.json`
- `crypto/fixtures/production-l1-vectors.json`

Schemas that mention signatures, signers, accounts, nonces, addresses, or bridge IDs include:

- `schemas/flowmemory/local-transaction-envelope.schema.json`
- `schemas/flowmemory/local-signature-envelope.schema.json`
- `schemas/flowmemory/local-wallet-public-metadata.schema.json`
- `schemas/flowmemory/product-transaction.schema.json`
- `schemas/flowmemory/agent-account.schema.json`
- `schemas/flowmemory/local-balance-record.schema.json`
- `schemas/flowmemory/bridge-observation.schema.json`
- `schemas/flowmemory/bridge-deposit.schema.json`
- `schemas/flowmemory/bridge-credit.schema.json`
- `schemas/flowmemory/bridge-withdrawal-intent.schema.json`
- `schemas/flowmemory/bridge-withdrawal.schema.json`
- `schemas/flowmemory/finality-receipt.schema.json`
- `schemas/flowmemory/real-value-pilot-message.schema.json`
