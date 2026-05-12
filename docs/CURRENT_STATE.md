# Current State

Last updated: 2026-05-12

## Repository State

The repository is in bootstrap mode.

Before bootstrap, the repository contained:

- `README.md`

This bootstrap pass adds:

- Agent instructions
- Project docs
- Decision record directory
- Work-area directories
- GitHub issue and pull request templates
- A conservative CI workflow for repository hygiene

## Implementation State

No product implementation is present yet.

- Contracts: not implemented
- Services: not implemented
- Apps: not implemented
- Hardware files: not implemented
- Research artifacts: not implemented
- Cryptographic proof systems: not implemented
- Infrastructure scripts: not implemented

## Active Boundaries

- Storage is not free.
- Transaction hashes do not store arbitrary data.
- Uniswap v4 hooks cannot know `txHash` or `logIndex`.
- Indexers and verifiers derive `txHash` and `logIndex` after reading receipts and logs.
- Heavy AI, model, memory, and artifact data stays off-chain.
- On-chain state stores roots, receipts, commitments, attestations, proofs, and work state.
- Meshtastic and LoRa are low-bandwidth control signaling paths, not normal internet bandwidth.

## Open Questions

- What is the first minimal FlowPulse event schema?
- What belongs in Rootflow versus Rootfield?
- Which facts require cryptographic receipts or attestations?
- What is the smallest useful indexer/verifier loop?
- What hardware proof-of-concept should FlowRouter start with?
- What AI memory and neural-geometry research artifacts should be tracked first?
- What appchain/L1 research criteria would justify deeper investment?

## How To Update This File

Update this file whenever the actual repo state changes in a way that affects new agents. Keep it factual and dated.
