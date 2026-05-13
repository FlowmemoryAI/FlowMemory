# FlowMemory Crypto Test Vectors

Status: draft v0.

The test vectors are synthetic and contain no production secrets or signatures.

## Vector Files

- `fixtures/sample-flowpulse.json`: FlowPulse event args and expected `pulseId` / `eventArgsHash`.
- `fixtures/sample-observation.json`: observation metadata, artifact/storage inputs, and expected `observationId` / `receiptHash`.
- `fixtures/sample-report.json`: verifier report, worker signature payload, verifier signature payload, and attestation envelope expectations.
- `fixtures/local-alpha-objects.json`: positive and negative fixtures for FlowChain Local Alpha object identity, signed-envelope validation, and schema validation.
- `fixtures/vectors.json`: 33 package-level vectors for domains, canonical JSON, observation ids, receipts, artifacts, Merkle roots, reports, attestations, cursors, identities, root commitments, work receipts, devnet block hashes, Local Alpha object ids, hardware signal envelopes, and local signature envelopes.
- `test-vectors/flowpulse-observation-v0.json`: FlowPulse-specific observation, receipt, artifact, report, worker signature digest, and verifier signature digest.

## FlowPulse Observation Vector Highlights

Input:

```text
chainId = 8453
emittingContract = 0x1234567890abcdef1234567890abcdef12345678
eventSignature = 0x5d07190b9ae441b4d7b16259a48424acd451492b12f5f99a29f5bfd992c13e43
blockHash = 0x1111111111111111111111111111111111111111111111111111111111111111
txHash = 0x2222222222222222222222222222222222222222222222222222222222222222
transactionIndex = 7
logIndex = 3
```

Derived:

```text
pulseId = 0x86b8325d6da0767e12097aed29aefe4820aaf4d6b7d4bb8371f1db927fda9d9d
observationId = 0xd80d0a3b317ceae266c9b7983c5a9376529f457a01469c96d8d3fd5a6c2d8a3f
receiptHash = 0xca2ebca63e004ff4b0ca9766acbb2862b45059a480d911b67dbc25e937c2e733
artifactRoot = 0xff501ac63f870de597cdc2a28dad8aeae3b52c5f1e2a658b1ea37c440b76f644
reportId = 0x1b1c2940d6e83ee78a7e0a8285e4ce2530da1ce7964817806e61520a2e767355
attestationEnvelopeHash = 0x3e139c10ff22aea00c4442698f2d8650ba85f811c723cb7e4f28094d833fea80
```

## Verification Requirements

An implementation should reproduce:

- every type hash
- `pulseId` using the current RootfieldRegistry formula
- `observationId` from receipt/log metadata
- `eventArgsHash` from decoded FlowPulse args
- `receiptHash` from observation, event args, artifact, storage, and evidence commitments
- Merkle root and artifact root
- deterministic verifier report id
- EIP-712 signing digests without requiring test private keys
- Local Alpha object IDs for AgentAccount, ModelPassport, WorkReceipt, ArtifactAvailabilityProof, VerifierModule, VerifierReport, MemoryCell, Challenge, FinalityReceipt, hardware signal envelopes, and control-plane provenance responses
- Local Alpha signature envelope IDs and signing digests for local operator, agent, verifier, and hardware no-value test keys

Run the package test suite:

```powershell
cd E:\FlowMemory\flowmemory-crypto\crypto
npm test
```

Run the package vector validator:

```powershell
npm run validate:vectors
```

Expected output:

```text
FLOWMEMORY_CRYPTO_VECTORS_OK 33
```

Validate the Local Alpha object documents and signature envelopes against the
canonical JSON Schemas:

```powershell
npm run validate:local-alpha
```

Expected output:

```text
FLOWCHAIN_LOCAL_ALPHA_FIXTURES_OK documents=11 envelopes=11 schemas=12
```

Print the sample vector summary:

```powershell
npm run vectors
```

Run the Python cross-check validator:

```powershell
python validate_test_vectors.py
```

Expected output:

```text
FLOWPULSE_VECTOR_RECOMPUTE_OK
```

## Negative Cases Covered Or Remaining

- changed `blockHash` should change `observationId`
- changed `logIndex` should change `observationId`
- changed `uri` should change `eventArgsHash`
- swapped Merkle leaves should change `contentMerkleRoot` and therefore any recomputed `artifactRoot`
- wrong verifier set root should change verifier signing digest
- swapped Local Alpha object fields should change object IDs
- changed Local Alpha type/domain strings should change object IDs or domain separators
- malformed hex in Local Alpha fixtures should fail before an ID is accepted
- duplicate Local Alpha object IDs should be rejected by fixture validation
- canonical JSON key order should not change the control-plane provenance response body hash
- replayed Local Alpha signer/domain/sequence tuples should be rejected
- wrong signature domains should be rejected
- missing local operator/agent/verifier/hardware signer fields should be rejected
- each Local Alpha object envelope has a bad-signature invalid vector
- zero critical hashes, malformed object IDs, malformed dependency roots, bad parent/root relationships, and wrong object types should be rejected
- expired worker signature should be rejected by verifier policy
- reorged observation should not mutate into a verified report

The package tests cover the hash, schema, malformed hex, duplicate, type-string, canonical JSON, signed-envelope, replay, wrong-domain, missing-signer, bad-signature, zero-hash, malformed-dependency, bad-parent/root, and wrong-object-type checks. Expiry and reorg-to-report policy are verifier-service responsibilities because they require policy context, not just hash recomputation.
