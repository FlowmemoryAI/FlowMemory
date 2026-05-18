# Owner-Gated L1 Wallet Checklist

## Tracking

- [x] Read `AGENTS.md`.
- [x] Read required project context docs.
- [x] Confirm branch and worktree cleanliness.
- [x] Create tracking files before implementation edits.

## Inventory

- [x] Inspect existing wallet library and CLI.
- [x] Inspect transaction envelope helpers.
- [x] Inspect product transaction fixtures and schemas.
- [x] Inspect bridge/operator handoff docs and scripts.
- [x] Inspect existing crypto test coverage.

## Build

- [x] Account create/import/unlock/lock/list/rotate/public metadata commands.
- [x] Public metadata export and verification.
- [x] Transfer signing and verification.
- [x] Token launch and token transfer signing.
- [x] DEX pool/liquidity/swap signing.
- [x] Withdrawal intent signing.
- [x] Validator/finality action signing if supported by existing protocol shape.
- [x] Bridge operator env, lockbox, chain ID, cap, acknowledgement, and dry-run/live command checks.
- [x] Local two-wallet transfer E2E.
- [x] Bridge-funded wallet proof flow.
- [x] Predictable envelope file output with verification status.

## Tests And Proof

- [x] Wrong password negative test.
- [x] Wrong chain ID negative test.
- [x] Stale nonce negative test.
- [x] Replayed transaction negative test.
- [x] Malformed recipient/public key negative tests.
- [x] Mutated payload/signature mismatch negative tests.
- [x] Public metadata private-key export rejection test.
- [x] No-secret scan over wallet outputs, fixtures, and handoff docs.
- [x] `npm test --prefix crypto`.
- [x] `npm run wallet:e2e --prefix crypto`.
- [x] `npm run wallet:transfer:e2e --prefix crypto` if added.
- [x] `npm run wallet:verify --prefix crypto`.
- [x] `git diff --check`.

## Required Artifacts

- [x] `WALLET_COMMANDS.md`
- [x] `ENVELOPE_SCHEMA.md`
- [x] `TWO_WALLET_TRANSFER_PROOF.md`
- [x] `PRODUCT_DEX_SIGNING_PROOF.md`
- [x] `BRIDGE_OPERATOR_PROOF.md`
- [x] `NO_SECRET_PROOF.md`
- [x] `HUMAN_WALLET_RUNBOOK.md`
- [x] `BRIDGE_FUNDED_WALLET_PROOF.md`
- [x] `VAULT_BOUNDARY_PROOF.md`
- [x] `CHAIN_SAFETY_PROOF.md`
- [x] `ENVELOPE_FILE_PROOF.md`
- [x] `HANDOFF.md`
