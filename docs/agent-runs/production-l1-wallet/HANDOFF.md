# Production L1 Wallet Handoff

What changed:

- Added human wallet document builders for transfer, token launch, token transfer, pool create, liquidity, swap, withdrawal intent, and finality receipt signing.
- Added `flowchain.wallet_signed_envelope.v0`, a control-plane-consumable wrapper around the existing local transaction envelope.
- Added local wallet public metadata export/verification with address, public key, key scheme, chain ID, and nonce hints.
- Added account lifecycle CLI coverage for create, import, unlock, lock, list, rotate/add account, metadata export, signing, verification, submit, and query.
- Added operator bridge command helpers for Base `8453` env names, lockbox/address/cap/ack checks, safe live chain validation, and evidence command planning.
- Added deterministic wallet E2E and transfer E2E commands.

Primary commands:

```powershell
npm test --prefix crypto
npm run wallet:e2e --prefix crypto
npm run wallet:transfer:e2e --prefix crypto
npm run wallet:verify --prefix crypto
npm run wallet:operator-bridge --prefix crypto -- env
```

Envelope output paths:

```text
devnet/local/wallet/envelopes/<tx-id>.json
devnet/local/production-l1-wallet/wallet-e2e/envelopes/
devnet/local/production-l1-wallet/transfer-e2e/envelopes/
```

Public metadata schema:

```text
schemas/flowmemory/local-wallet-public-metadata.schema.json
```

Envelope schema:

```text
schemas/flowmemory/wallet-signed-envelope.schema.json
```

Runtime/API dependency:

- The existing control-plane `transaction_submit` method accepts signed envelopes with `tx` and `signature` fields.
- Wallet E2E submitted the transfer envelope and pool-create envelope to local file intake and received `accepted_local`.
- Full runtime execution beyond local wallet receipt accounting remains owned by runtime/control-plane branches.

Bridge dependency:

- Base pilot live mode requires `FLOWCHAIN_BASE8453_RPC_URL`, lockbox address, block range, cap env values, withdrawal recipient, and exact owner acknowledgement.
- The wallet command validates `eth_chainId == 8453` before live action planning.

Risks and follow-ups:

- This is local/private wallet tooling, not audited production custody.
- Fee and expiry fields are support flags until the protocol binds them into the transaction hash.
- The product pool create schema does not store initial reserves directly; the command hashes the requested reserve plan into metadata and signs add-liquidity separately.
- Bridge and runtime strict pilot gates still depend on their owning subsystem proof commands.

