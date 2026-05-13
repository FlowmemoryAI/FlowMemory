# FlowMemory Cryptography Threat Model

Status: draft v0 for bootstrap design.

This threat model covers the draft cryptographic foundation in `crypto/`. It does not replace a full protocol audit, contract audit, verifier audit, hardware review, or storage provider review.

## Assets

- Worker signing keys and key registry state
- Verifier signing keys and verifier set roots
- Receipt hashes and cursor derivations
- Artifact manifests, Merkle openings, and artifact roots
- Storage receipt commitments and private locator metadata
- Rootflow and Rootfield roots
- Challenge evidence and responses
- Off-chain memory artifacts, embeddings, model outputs, and research data
- Chain receipts, logs, block hashes, and finality assumptions

## Trust Boundaries

### Chain Boundary

Contracts can emit events and store intentional state, but they cannot know final `txHash` or `logIndex` during execution. Indexers cross this boundary when they read receipts and logs after execution.

### Worker Boundary

Workers can observe, process, and sign claims. A worker signature proves a key signed a specific typed message; it does not prove the worker behaved honestly or that its model output is true.

### Verifier Boundary

Verifiers run checks and sign attestations. A verifier attestation proves a verifier key signed a result; it is not a zero-knowledge proof and must remain challengeable.

### Storage Boundary

Storage providers can lose, censor, mutate, or hide artifacts. Storage receipt commitments are commitments to claims and metadata, not guarantees of perpetual data availability.

### Hardware Boundary

Hardware devices and radio sidecars can be spoofed, replayed, delayed, physically tampered with, or bandwidth-constrained. Hardware control messages need authentication and small payloads.

## Threats And Mitigations

### Ambiguous Encoding

Threat: Two implementations hash different byte representations of the same logical receipt.

Mitigations:

- Use typed hashes with exact type strings.
- Hash variable-length inputs before entering typed objects.
- Use canonical JSON for JSON payloads.
- Maintain cross-language test vectors.
- Reject unknown schema versions and root schemes by default.

Residual risk: Canonical JSON libraries can differ on edge cases such as numbers and Unicode. v0 payload schemas should avoid ambiguous numeric and text encodings until conformance tests exist.

### Cursor Forgery Or Confusion

Threat: A service claims a cursor for an event that did not happen, or reuses a cursor across chains, contracts, or events.

Mitigations:

- Derive event cursors from `chainId`, `blockHash`, `blockNumber`, `txHash`, `transactionIndex`, `logIndex`, emitter, and `topic0`.
- Require indexers to recompute cursors from observed receipts and logs.
- Treat cursors as unstable until finality policy accepts the block.
- Include deployment and chain domain data in signatures.

Residual risk: RPC providers can return inconsistent data during outages or reorgs. Verifiers should support multiple RPC backends or independently indexed data before high-value acceptance.

### Replay Attacks

Threat: A valid worker signature, verifier attestation, or receipt is replayed across chains, deployments, verifier sets, or time windows.

Mitigations:

- Bind signatures to `chainId`, deployment salt, verifier set root, expiry, nonce, and worker sequence.
- Track consumed worker sequences per worker identity.
- Reject stale finality, expired signatures, and mismatched verifier sets.
- Bind receipt hashes to source-specific cursors and nonces.

Residual risk: Until a registry or contract stores accepted nonces and key state, replay prevention is partially off-chain policy.

### Artifact Substitution

Threat: An attacker swaps artifact bytes while keeping a plausible manifest or locator.

Mitigations:

- Commit to chunk hashes, Merkle root, manifest hash, byte length, chunk size, media type hash, and metadata hash.
- Require Merkle openings for challenged chunks.
- Verify byte offsets and lengths, not only chunk contents.
- Reject root scheme mismatches.

Residual risk: If the original artifact is unavailable, verifiers cannot prove it matched a root beyond available openings and prior attestations.

### Storage Availability Failure

Threat: A storage provider signs or implies availability but later cannot serve the artifact.

Mitigations:

- Treat storage receipt commitments as challengeable claims.
- Commit to retention policy, provider identity, location commitment, and availability sample roots.
- Sample availability during the retention window.
- Record failed openings and verifier failures.

Residual risk: Availability sampling is probabilistic unless backed by stronger data availability systems or replicated retrieval guarantees. This design does not yet provide that.

### Worker Key Compromise

Threat: A worker signing key is stolen and used to sign false receipts.

Mitigations:

- Use worker key identifiers and sequence tracking.
- Add expiry to signatures.
- Rotate keys through a registry when implemented.
- Require verifier checks and challenge windows before high-confidence status.
- Support revocation roots or registry state in future contracts.

Residual risk: Receipts signed before compromise detection may remain ambiguous unless the registry defines revocation time and acceptance policy.

### Verifier Collusion Or Error

Threat: Verifiers sign false pass attestations or implement checks incorrectly.

Mitigations:

- Make attestations explicit about result code, check root, finality depth, and verifier set root.
- Allow independent verifier recomputation.
- Keep deterministic verification reports.
- Challenge failed, inconsistent, or incomplete reports.
- Do not present verifier attestations as trustless proofs.

Residual risk: If all accepted verifiers collude, the system can report false verified states until challenged by an independent party.

### Chain Reorgs

Threat: A receipt is built on a log that disappears or changes position after a reorg.

Mitigations:

- Include `blockHash` in event cursors.
- Require finality policy before high-confidence verification.
- Mark pre-finality receipts as pending or observed only.
- Supersede receipts whose block is reorged out.

Residual risk: Deep reorgs or chain incidents require operational policy, not only hash schemas.

### Privacy Leakage

Threat: Receipt payload hashes, locator commitments, metadata hashes, or public roots leak sensitive information through small search spaces.

Mitigations:

- Salt low-entropy commitments.
- Use encrypted locator envelopes when locators are sensitive.
- Avoid putting raw personal, model, or hardware data in public payloads.
- Separate public receipt data from private artifact data.

Residual risk: Hashes of low-entropy data can be brute-forced. Sensitive payload schemas must include salt or encryption requirements.

### Challenge Abuse

Threat: Attackers spam challenges or force expensive openings.

Mitigations:

- Define challenge reason codes and evidence roots.
- Require structured evidence before a challenge is accepted by services.
- Add rate limits and policy gates in verifier services.
- Keep economic bonding outside this design until tokenomics is explicitly in scope.

Residual risk: Without on-chain challenge economics, abuse mitigation is operational and service-level.

## Security Assumptions

- Keccak-256 remains collision-resistant for these protocol uses.
- secp256k1 signatures are verified with strict malleability checks where used.
- Verifiers can obtain honest chain receipt/log data after finality.
- Implementations follow exact field order and encoding.
- Heavy data remains off-chain and is opened only through intended disclosure paths.

## Required Review Gates

Before production use, FlowMemory needs:

- independent review of type strings and encoding
- cross-language vector tests
- contract-level hash verification tests
- verifier replay and reorg tests
- worker and verifier key management design
- storage locator privacy review
- challenge state machine review
- decision record for Rootflow and Rootfield semantics
