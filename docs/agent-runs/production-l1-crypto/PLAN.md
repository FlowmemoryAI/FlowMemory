# Production L1 Crypto Plan

Status: in progress

## Mission

Build the canonical FlowChain production-L1-shaped crypto foundation inside the existing `crypto/` package. The work must keep one wallet format, one transaction envelope, one canonical encoding path, and one runtime-safe validation surface.

## Assigned Scope

Allowed folders:

- `crypto/`
- `schemas/flowmemory/`
- `fixtures/crypto/`
- `docs/DECISIONS/`
- `docs/agent-runs/production-l1-crypto/`
- root `package.json` only if root aliases become necessary

Forbidden implementation folders:

- `crates/`
- `services/`
- `contracts/`
- `apps/dashboard/`
- `hardware/`
- local vault files

## Phases

1. Inventory existing crypto exports, wallet-only exports, runtime-safe exports, fixtures, schemas, and transaction shapes.
2. Define canonical public identity, FlowChain address derivation, account IDs, role metadata, and role-specific identity vectors.
3. Complete the transaction envelope with chain/profile/nonce/signer-role/payload hash/expiration/cost/signature fields.
4. Add domain-separated hash helpers for transactions, blocks, roots, bridge objects, withdrawals, and finality.
5. Add runtime-safe validation that imports no wallet/vault code and returns structured success or failure codes.
6. Add deterministic positive and negative vectors for all production-L1 transaction families.
7. Add CLI commands for wallet metadata, signing, verification, vector printing, production crypto validation, and no-secret scans.
8. Update schemas, README, decision notes, proof docs, and final handoff.
9. Run required checks and record exact results.

## Stop Condition

Stop only when runtime/API/wallet agents can use one canonical envelope and the required crypto commands prove every production-L1 transaction type and expected rejection class.
