# Security Model

This document captures initial security assumptions. It is not a final audit model.

## Assets

- Private keys and deployer credentials
- RPC credentials and service tokens
- Contract ownership and upgrade controls
- Roots, commitments, receipts, attestations, and proofs
- Indexer and verifier outputs
- Off-chain memory artifacts and research data
- Hardware device identity and operator controls
- CI, release, and deployment credentials

## Baseline Rules

- Do not hardcode secrets.
- Do not commit private keys, seed phrases, API keys, RPC credentials, or webhook URLs.
- Keep heavy AI, model, memory, and artifact data off-chain.
- Commit to data intentionally with roots, receipts, attestations, or proofs.
- Treat chain logs as observed facts only after receipts are available.
- Treat hardware control channels as adversarial unless authenticated.

## Threat Areas

### Protocol

- Incorrect assumptions about what hooks know during execution
- Event schemas that cannot be verified later
- Unclear ownership or upgrade authority
- Excessive on-chain storage
- Commitment formats that are ambiguous or replayable

#### Off-Chain Data Boundary

Initial contracts foundation assumptions:

- FlowPulse events intentionally omit `txHash` and `logIndex`; indexers derive them from receipts and logs.
- RootfieldRegistry stores compact hashes and counters, but `metadataURI` and `evidenceURI` are arbitrary strings accepted by the current skeleton contract.
- The contract does not enforce URI length, content, format, resolvability, or "short pointer" behavior.
- Emitted URI bytes are on-chain log data.
- Keeping heavy or sensitive metadata, AI memory, model artifacts, media, and evidence off-chain is currently a design convention and caller responsibility, not a contract guarantee.
- Verifiers must check referenced content against emitted commitments.
- `pulseId` values domain-separate the emitting chain and contract, but canonical indexing should still use receipt metadata.

Follow-up:

- Consider bounded `bytes32` commitments, CID/hash-only fields, URI length caps, or a URI validation policy before treating this skeleton as an enforceable off-chain-data boundary.

### Indexers And Verifiers

- Log parsing errors
- Chain reorg handling gaps
- Incorrect `txHash` or `logIndex` derivation
- Non-deterministic verification output
- Trusting off-chain artifacts without checking commitments

### AI Memory

- Sensitive memory leakage
- Unbounded artifact storage
- Weak provenance
- Confusing model output with verified state
- Embedding or retrieval data that cannot be traced to a receipt

### Hardware

- Unauthenticated control messages
- Device identity spoofing
- Physical tampering
- Unsafe power or enclosure assumptions
- Overestimating LoRa or Meshtastic bandwidth

### Supply Chain

- Unpinned dependencies
- Unreviewed scripts
- CI secrets exposure
- Binary artifacts without provenance

## PR Security Checklist

- Does this change introduce or require secrets?
- Does it change trust assumptions?
- Does it change contract, receipt, proof, or attestation semantics?
- Does it depend on `txHash` or `logIndex` before a receipt exists?
- Does it place heavy data on-chain?
- Does it assume LoRa or Meshtastic can carry high-bandwidth traffic?
- Are tests or verification steps included where practical?
