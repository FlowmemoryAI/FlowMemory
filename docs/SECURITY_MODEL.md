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

## Cryptographic Foundation Draft

The draft cryptographic foundation lives in:

- `crypto/FLOWMEMORY_CRYPTO_SPEC.md`
- `crypto/OBSERVATION_IDENTITY.md`
- `crypto/RECEIPT_HASHING.md`
- `crypto/MERKLE_AND_ROOTS.md`
- `crypto/ATTESTATIONS.md`
- `crypto/TEST_VECTORS.md`
- `services/verifier/README.md`
- `research/cryptography/THREAT_MODEL.md`
- `research/cryptography/IMPLEMENTATION_PLAN.md`
- `research/cryptography/FUTURE_ZK_ROADMAP.md`

Current crypto assumptions:

- FlowMemory v0 uses Keccak-256 typed hashes for Base/EVM compatibility.
- `pulseId` is a contract-emitted logical identifier; `observationId` is derived by indexers from observed receipt and log metadata, including `txHash`, `transactionIndex`, `logIndex`, and `blockHash`.
- `reportId` is a deterministic verifier report identifier; verifier signatures sign reports but do not make them trustless.
- Receipt hashes do not embed signatures. Worker signatures and verifier attestations point at receipt hashes.
- Artifact roots commit to off-chain content through explicit root schemes and Merkle formats.
- Storage receipt commitments are challengeable availability claims, not permanent availability proofs.
- Verifier attestations are signed verifier statements, not zk proofs and not full trustlessness.
- Replay protection requires chain, deployment, sequence, nonce, expiry, and verifier-set domains.

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

#### Live V0 Contract Skeletons

Live V0 registries and schedulers are commitment surfaces, not complete trust systems:

- CursorRegistry stores cursor commitments but does not define canonical indexer identity or reorg policy.
- ReceiptVerifier stores receipt report commitments but does not cryptographically verify receipts on-chain.
- WorkerRegistry and VerifierRegistry are self-registration surfaces without staking, rewards, slashing, Sybil resistance, or production authorization guarantees.
- ArtifactRegistry stores artifact commitments, type/schema/metadata hashes, owner, submitter, and status only; raw artifacts and sensitive payloads remain off-chain.
- WorkReceiptRegistry and VerifierReportRegistry use owner-controlled allowlists in v0. Those allowlists are local testing policy, not decentralized governance or a production verifier network.
- WorkDebtScheduler stores compact work state without token debt, dynamic fees, rewards, or external calls.
- FlowMemoryHookAdapter is a compileable scaffold only; it is not a production Uniswap v4 hook and cannot know `txHash` or `logIndex`.
- These contracts are not production audited and are not mainnet-ready.

### Indexers And Verifiers

- Log parsing errors
- Chain reorg handling gaps
- Incorrect `txHash` or `logIndex` derivation
- Non-deterministic verification output
- Trusting off-chain artifacts without checking commitments
- Accepting worker signatures on the wrong chain, deployment, verifier set, or sequence
- Treating verifier attestations as proofs instead of challengeable signed statements
- Treat contract-emitted `pulseId` as protocol payload, not canonical observed-log identity.
- Bind `observationId` to receipt/log metadata, including chain id, emitting contract, FlowPulse event signature, block hash, transaction hash, transaction index, and log index.
- Treat advisory URI fields as lookup hints only; verifier reports must use explicit resolver policy and deterministic commitment checks.
- Do not store secrets, RPC credentials, API keys, seed phrases, or webhook URLs in indexer/verifier env files.

### AI Memory

- Sensitive memory leakage
- Unbounded artifact storage
- Weak provenance
- Confusing model output with verified state
- Embedding or retrieval data that cannot be traced to a receipt
- Hashing low-entropy private metadata without salting or encryption

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

### Storage And Artifacts

- Ambiguous artifact root scheme selection
- Invalid Merkle openings
- Unavailable off-chain artifacts
- Locator leakage through public commitments
- Retention claims that cannot be challenged or sampled

Static analysis preparation:

- Slither was not available in the local PATH during the Live V0 package pass.
- Track setup in GitHub issue #24 before adding a CI gate.
- Candidate command once installed: `slither . --filter-paths "tests|script"`.

## PR Security Checklist

- Does this change introduce or require secrets?
- Does it change trust assumptions?
- Does it change contract, receipt, proof, or attestation semantics?
- Does it depend on `txHash` or `logIndex` before a receipt exists?
- Does it place heavy data on-chain?
- Does it assume LoRa or Meshtastic can carry high-bandwidth traffic?
- Are tests or verification steps included where practical?
- Does every new receipt, root, signature, attestation, or challenge format have a domain-separated type hash?
- Does replay protection cover chain, deployment, nonce or sequence, expiry, and verifier set where relevant?
- Does the UI or documentation avoid claiming full trustlessness unless a proof and enforcement path exist?
