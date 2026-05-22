# FlowMemory Cryptography

Status: draft v0.

This directory defines the cryptographic vocabulary, runnable utilities, fixtures, and tests that contracts, indexers, verifiers, workers, and future appchain research should share. The package is intentionally commitment-first and verifier-friendly. It does not claim that FlowMemory is fully trustless before proof systems, verifier enforcement, and challenge handling exist.

## Package Commands

Install dependencies from this directory:

```powershell
cd FLOWMEMORY_WORKTREE_ROOT\flowmemory-crypto\crypto
npm install
```

Requires Node.js `>=20.19.0`.

Run deterministic tests:

```powershell
npm test
```

Print the sample hash outputs:

```powershell
npm run vectors
```

Validate all package-level vector fixtures:

```powershell
npm run validate:vectors
```

Validate the production-L1-shaped crypto foundation, including canonical
identity metadata, completed transaction envelopes, runtime-safe verification,
hash helpers, positive vectors, and exact negative rejection vectors:

```powershell
npm run validate:production-l1-crypto
```

Validate the Local Alpha object and signature-envelope fixtures against the
canonical JSON Schemas:

```powershell
npm run validate:local-alpha
```

Validate Product Testnet V1 wallet transaction documents and signed envelopes:

```powershell
npm run validate:product-transactions
npm run wallet:product-smoke
```

Create and use a local encrypted no-value test vault:

```powershell
$env:FLOWMEMORY_TEST_WALLET_PASSWORD="local-test-password"
npm run wallet:create -- --vault .\tmp-local-vault.json
npm run wallet:add-account -- --vault .\tmp-local-vault.json --role agent --label product-agent
npm run wallet:list -- --vault .\tmp-local-vault.json
npm run wallet:sign -- --vault .\tmp-local-vault.json --document .\fixtures\some-object.json --chain-id 31337 --nonce 1 --out .\tmp-envelope.json
npm run wallet:verify -- --document .\fixtures\some-object.json --envelope .\tmp-envelope.json --chain-id 31337
npm run wallet:e2e
```

The wallet commands are for local/private testnet smoke use only. Public exports
contain signer metadata and public keys; private keys, mnemonics, seed material,
and ciphertext are not exported as public metadata.

`wallet:sign` now writes the completed canonical local transaction envelope
shape with `schemaVersion`, `networkProfile`, `payloadType`, expiration,
local execution cost, fee policy, signature algorithm, signature, and
`transactionId`. Legacy local-alpha envelopes without those production-L1
fields remain accepted as compatibility fixtures, but
`validate:production-l1-crypto` requires the completed field set.

Run the capped real-value pilot wallet/operator E2E:

```powershell
npm run wallet:pilot-e2e
```

Pilot helper commands:

```powershell
npm run wallet:pilot-config -- --out ..\devnet\local\pilot-wallet\operator-config.local.json
npm run wallet:pilot-metadata -- --config ..\devnet\local\pilot-wallet\operator-config.local.json --vault ..\devnet\local\pilot-wallet\operator-vault.json
npm run wallet:pilot-sign -- --config ..\devnet\local\pilot-wallet\operator-config.local.json --vault ..\devnet\local\pilot-wallet\operator-vault.json --document .\fixtures\pilot-release-evidence.json --nonce 1
npm run wallet:pilot-verify -- --config ..\devnet\local\pilot-wallet\operator-config.local.json --document .\fixtures\pilot-release-evidence.json --envelope .\out\pilot-release-envelope.json
npm run wallet:pilot-next -- --config ..\devnet\local\pilot-wallet\operator-config.local.json
```

The pilot commands stay command-line only. Runtime and control-plane consumers
that only need public verification can import
`@flowmemory/crypto/pilot-envelope-validation`; that subpath does not import
encrypted vault creation, unlock, or signing helpers.

## Read Order

1. `FLOWMEMORY_CRYPTO_SPEC.md`
2. `OBSERVATION_IDENTITY.md`
3. `RECEIPT_HASHING.md`
4. `MERKLE_AND_ROOTS.md`
5. `ATTESTATIONS.md`
6. `FLOWCHAIN_LOCAL_ALPHA_OBJECTS.md`
7. `TEST_VECTORS.md`

Runnable fixtures live in `fixtures/`. `fixtures/vectors.json` contains the current 46 package-level vectors. `fixtures/local-alpha-objects.json` contains positive and negative Local Alpha object, signed-envelope, and transaction-envelope fixtures. `fixtures/product-testnet-transactions.json` contains Product Testnet V1 wallet transaction documents, signed envelopes, and negative vectors for wrong chain, replay, wrong nonce/domain, payload mutation, malformed signer, missing signer, wrong object type, and invalid amounts. `fixtures/production-l1-vectors.json` contains the production-L1-shaped identity, hash-helper, positive transaction-family, and exact negative validation vectors. Supporting cross-language vectors live in `test-vectors/`.

Validate the current vector set with:

```powershell
python validate_test_vectors.py
```

The Python validator is a cross-check for the FlowPulse aggregate vector. The primary local/test package paths are `npm test`, `npm run validate:vectors`, and `npm run validate:local-alpha`.

## Core Vocabulary

- `pulseId`: contract-emitted logical FlowPulse identifier. It is produced during contract execution and intentionally excludes receipt-only metadata.
- `observationId`: indexer/verifier identifier for a specific observed FlowPulse log after receipt metadata exists.
- `receiptHash`: commitment to a FlowPulse observation, event args, artifact root, storage commitment, and evidence root.
- `artifactRoot`: commitment to off-chain artifact bytes and metadata.
- `reportId`: deterministic identifier for a verifier report.
- `attestation`: signed worker or verifier envelope over a receipt, report, artifact, or root.
- Local Alpha object IDs: canonical IDs for `AgentAccount`, `ModelPassport`, `WorkReceipt`, `ArtifactAvailabilityProof`, `VerifierModule`, `VerifierReport`, `MemoryCell`, `Challenge`, `FinalityReceipt`, `BridgeDeposit`, `BridgeCredit`, `BridgeWithdrawal`, local balance records, hardware signal envelopes, and control-plane provenance responses.
- Local Alpha signature envelopes: local operator, agent, verifier, and hardware secp256k1 test signatures over typed object IDs. These are no-value local/test keys and are not wallet custody or production key-management claims.
- Local transaction envelopes: chain-bound signed envelopes over canonical JSON payload hashes, object IDs, signer IDs, signer key IDs, signer roles, nonces, and domain separators.
- Production-L1 local transaction envelopes: the same canonical envelope extended with schema version, network profile, payload type, expiration, local execution cost, fee policy, signature algorithm, transaction ID, role metadata, and runtime-safe verification result fields.
- Product Testnet V1 transaction documents: canonical transfer, token launch, DEX pool create, add liquidity, remove liquidity, swap, bridge credit acknowledgement, and bridge withdrawal intent documents that reuse the local transaction envelope and local test vault.

## Implemented Helpers

The package exports Keccak helpers, canonical JSON hashing, typed hash utilities, FlowPulse observation ids, cursor ids, report digests, receipt hashes, artifact/root commitments, work receipt ids, Local Alpha object ids, bridge/balance object ids, Product Testnet V1 transaction ids, hardware signal envelope ids, Local Alpha signature and transaction envelope payloads, envelope validators, Merkle roots, encrypted local test-vault helpers, worker/verifier signature payloads, verifier attestation envelope hashes, and local secp256k1 sign/verify helpers for tests.

Runtime/API-safe import path:

```js
import { verifyFlowchainEnvelope } from "@flowmemory/crypto/runtime-validation";
```

This subpath imports validation, identity, hashing, and signature verification
helpers only. It does not import encrypted vault creation, unlock, rotation, or
wallet signing code.

Wallet/vault-only exports remain in the root compatibility export and wallet
CLI paths: `createEncryptedTestVault`, `unlockEncryptedTestVault`,
`addEncryptedTestVaultAccount`, `rotateEncryptedTestVaultAccount`, and
`signLocalTransactionWithVault`.

The implementation is ESM JavaScript with `src/index.d.ts` declarations for TypeScript consumers.

## MVP Boundary

MVP crypto can provide tamper-evident facts, deterministic IDs, replay-resistant signatures, artifact inclusion checks, and verifier reports. MVP crypto cannot prove data availability forever, prove model output correctness, or make verifier attestations trustless.

## Future Boundary

Future work may add proof-carrying receipts, zk circuits for receipt consistency, recursive report aggregation, and appchain/L1 verification tracks. Those remain research until public inputs, witnesses, circuits, and enforcement paths are specified.

## Integration Notes

There is a fixture-first `services/shared/` package in this repository, but the crypto package remains the authoritative source for the hash formats in this directory. Services should either:

- import this package directly from `crypto/` in local development, or
- mirror the exported functions from `crypto/src/index.js` with tests against `crypto/fixtures/`.

Indexer and verifier services must not hand-roll different hash formats. If a service cannot import this package, it should copy the type strings and vectors exactly and prove compatibility by passing the same fixture hashes.

Private RD crypto sources are research inputs only for this package. They should not replace these Keccak typed-hash vectors unless a compatibility adapter and matching cross-language vectors are accepted.

## Downstream Consumption

- Chain/devnet agents should use the object ID helpers as transaction/object keys and reject zero roots, malformed IDs, wrong object types, replayed signer sequences, and bad parent/root relationships before state updates.
- Services and verifiers should use `validateLocalAlphaEnvelope` before accepting object documents from local transactions, API calls, hardware packets, or fixture imports.
- Dashboard/workbench agents should display IDs, domains, signer roles, status labels, and validation errors from these fixtures without implying production proof security.
- Hardware agents should treat hardware signal envelopes as low-bandwidth authenticated control messages only; payloads remain off-chain and signal roots are commitments, not radio bandwidth or field-deployment claims.
