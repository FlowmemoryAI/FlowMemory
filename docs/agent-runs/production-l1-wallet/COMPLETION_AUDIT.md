# Owner-Gated L1 Wallet Completion Audit

Objective: make the FlowChain owner-gated L1 wallet/operator tool usable for local human wallet creation, signing, transfer E2E, bridge pilot preparation, safety checks, proof artifacts, and required tests.

## Prompt-To-Artifact Checklist

| Requirement | Evidence |
| --- | --- |
| Read repository instructions and current state first | Tracking files in this directory plus `EXPERIMENTS.md` record the read/inventory phase. |
| Create tracking files first | `PLAN.md`, `CHECKLIST.md`, `EXPERIMENTS.md`, and `NOTES.md` exist in this directory. |
| Stay inside allowed folders | Edited files are under `crypto/`, `schemas/flowmemory/`, `docs/`, `infra/scripts/flowchain-wallet-operator.ps1`, and package wallet aliases. |
| Wallet create/import/unlock/lock/list/rotate/export/verify metadata commands | `crypto/src/wallet-cli.js` implements `create`, `import`, `unlock`, `lock`, `list accounts`, `add-account`, `rotate`, `export-metadata`, and `verify-metadata`; `crypto/package.json` exposes script aliases. |
| Public account metadata data model | `schemas/flowmemory/local-wallet-public-metadata.schema.json` defines label, address, public key, key scheme, chain ID, status, and nonce hints. |
| Private vault boundary | `crypto/src/wallet.js` encrypts vault material; `crypto/.gitignore` ignores `.wallet/`, `devnet/local/`, and local vault patterns; `VAULT_BOUNDARY_PROOF.md` documents the boundary. |
| Signed envelope data model | `crypto/src/wallet-envelope.js` and `schemas/flowmemory/wallet-signed-envelope.schema.json` define version, chain ID, payload type/body, signer address, public key reference, nonce, fee/validity support, signature, tx id, and verification. |
| Verification output fields | `verifyWalletSignedEnvelope` returns signature validity, chain match, signer-derived address, payload hash, tx id, replay key, and rejection errors; `ENVELOPE_SCHEMA.md` documents the rules. |
| Transfer signing | `wallet:sign-transfer` and `buildProductTransferDocument`; covered by tests and `wallet:transfer:e2e`. |
| Token launch signing | `wallet:sign-token-launch` and `buildProductTokenLaunchDocument`; covered by `wallet:e2e` and `PRODUCT_DEX_SIGNING_PROOF.md`. |
| Token transfer signing | `wallet:sign-token-transfer`; covered by `wallet:e2e` and `PRODUCT_DEX_SIGNING_PROOF.md`. |
| Pool create signing | `wallet:sign-pool-create` and `buildProductPoolCreateDocument`; covered by `wallet:e2e`; control-plane intake accepted the pool-create envelope. |
| Add liquidity signing | `wallet:sign-add-liquidity`; covered by `wallet:e2e`. |
| Remove liquidity signing | `wallet:sign-remove-liquidity`; covered by `wallet:e2e`. |
| Swap signing with slippage guard | `wallet:sign-swap` requires `--minimum-output`; covered by `wallet:e2e`. |
| Withdrawal intent signing | `wallet:sign-withdrawal-intent` requires local account, Base address, bridge asset, amount, credit/deposit ids, nonce, and chain ID; covered by `wallet:e2e`. |
| Validator/finality action if needed | `wallet:sign-finality` signs existing finality receipt shape. |
| Operator env names | `crypto/src/operator-bridge-cli.js env` prints required Base pilot env names; proof in `BRIDGE_OPERATOR_PROOF.md`. |
| Operator lockbox/Base address validation | `operator-bridge-cli.js validate` validates 20-byte Base addresses; malformed destinations are rejected before signing. |
| Operator chain ID validation | Mock live `eth_chainId` `0x2105` passed, mock `0x1` failed with `wrong-chain-id`; proof in `BRIDGE_OPERATOR_PROOF.md`. |
| Operator caps and acknowledgement | `operator-bridge-cli.js validate` checks cap values and exact pilot acknowledgement; dry run without env fails safely. |
| Operator evidence commands | `prepare-deposit-evidence` and `prepare-release-evidence` print dry-run commands separately from live commands and do not broadcast. |
| Local two-wallet E2E | `npm run wallet:transfer:e2e --prefix crypto` created wallet A/B, credited A, signed transfer A to B, verified envelope, submitted intake envelope, and recorded balances. |
| Runtime/API can consume transfer envelope | `wallet:transfer:e2e` submitted to control-plane `transaction_submit` and got `accepted_local`. |
| Runtime/API can consume product/DEX envelope | `wallet:e2e` submitted pool-create envelope to control-plane `transaction_submit` and got `accepted_local`. |
| Bridge-funded or local pilot credit flow | `wallet:e2e` uses a local pilot credit fixture and signs withdrawal intent; root `flowchain:real-value-pilot:wallet` runs pilot wallet E2E plus wallet E2E. |
| Predictable ignored envelope files | Signing writes `devnet/local/wallet/envelopes/<tx-id>.json`; E2E writes under ignored `devnet/local/production-l1-wallet/.../envelopes/`; proof in `ENVELOPE_FILE_PROOF.md`. |
| Human runbook | `HUMAN_WALLET_RUNBOOK.md` includes wallet A/B creation, metadata, transfer sign/submit/query, token/DEX/withdrawal signing, lock/unlock, and bridge commands. |
| Wallet command reference | `WALLET_COMMANDS.md` contains exact command examples and safe sample output shapes. |
| Envelope schema doc | `ENVELOPE_SCHEMA.md` documents fields, hashing, signing, tx id, verification, and rejection behavior. |
| Two-wallet proof doc | `TWO_WALLET_TRANSFER_PROOF.md` contains public addresses, tx id, receipt status, and balance changes. |
| Product/DEX proof doc | `PRODUCT_DEX_SIGNING_PROOF.md` contains token and DEX tx ids with no local vault material. |
| Bridge operator proof doc | `BRIDGE_OPERATOR_PROOF.md` contains env names, live validation, wrong-chain refusal, and safe command planning. |
| No-secret proof doc | `NO_SECRET_PROOF.md` records `NO_SECRET_SCAN_OK paths=crypto/fixtures,docs/agent-runs/production-l1-wallet files=23 matches=0`. |
| Extra required proof docs | `BRIDGE_FUNDED_WALLET_PROOF.md`, `VAULT_BOUNDARY_PROOF.md`, `CHAIN_SAFETY_PROOF.md`, `ENVELOPE_FILE_PROOF.md`, and `HANDOFF.md` exist. |
| Wrong passphrase negative case | `npm test --prefix crypto` covers failed unlock/signing without leaking key material. |
| Wrong chain ID negative case | `npm test --prefix crypto` covers wallet envelope wrong-chain rejection; operator mock rejects `0x1`. |
| Stale nonce negative case | `npm test --prefix crypto` covers expected nonce mismatch. |
| Replayed transaction negative case | `npm test --prefix crypto` covers seen replay key rejection. |
| Malformed recipient/public key negative cases | `npm test --prefix crypto` covers malformed public key; document builders reject malformed account/Base addresses. |
| Mutated payload/signature mismatch negative cases | `npm test --prefix crypto` covers mutated payload and signer data mismatch. |
| Attempted private material export via public metadata | `npm test --prefix crypto` rejects secret-shaped public metadata. |
| Required command gate: crypto tests | `npm test --prefix crypto` passed: 24 tests. |
| Required command gate: wallet E2E | `npm run wallet:e2e --prefix crypto` passed with `apiMempool=2`. |
| Required command gate: transfer E2E | `npm run wallet:transfer:e2e --prefix crypto` passed with `apiMempool=1`. |
| Required command gate: wallet verify | `npm run wallet:verify --prefix crypto` passed with `valid: true`. |
| Root pilot wallet command | `npm run flowchain:real-value-pilot:wallet` passed, running pilot wallet E2E and wallet E2E. |
| Human CLI smoke | CLI create/list/verify metadata/sign transfer/verify envelope/unlock/lock smoke passed using ignored local paths. |
| No committed local vaults or generated wallet outputs | `crypto/devnet/local/` is ignored; generated local outputs are not in `git status`. |
| Whitespace gate | `git diff --check` passed with only line-ending warnings. |

## Residual Notes

- The branch is behind `origin/main` by 3 commits. `origin/main` adds non-wallet pilot aliases in `package.json`; they were not copied because their target files are outside this task's allowed edit scope and are absent in this worktree. A merge or rebase should reconcile that package section before PR finalization.
- Local wallet tooling is not audited production custody. It is suitable for the private/local pilot command path described in the prompt.
- Full runtime execution beyond local wallet receipt accounting remains a runtime/control-plane dependency; the wallet currently proves control-plane intake acceptance for transfer and pool-create envelopes.
