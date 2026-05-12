# FlowMemory

FlowMemory is a Base-native AI memory, neural-geometry, reliability, decentralized hardware, and future appchain/L1 research project.

This repository is currently in bootstrap mode. It contains project context, collaboration rules, planning documents, GitHub templates, and placeholder directories for future implementation work. Do not treat the current repo as containing production product features yet.

## What FlowMemory Is Exploring

- Base and Uniswap v4 hook integrations
- FlowPulse events
- Rootflow and Rootfield state commitments
- AI memory and neural geometry research
- FlowRouter decentralized internet hardware
- Meshtastic and LoRa sidecar signaling
- 3D-printed hardware enclosures
- Dashboard, explorer, and hardware console applications
- Indexer, verifier, and worker services
- Cryptographic receipts, attestations, roots, and proofs
- Future FlowMemory appchain/L1 research

## Important Boundaries

- AI does not run on-chain.
- Storage is not free.
- Transaction hashes do not store arbitrary data.
- Uniswap v4 hooks cannot know `txHash` or `logIndex`.
- Indexers and verifiers derive `txHash` and `logIndex` after reading receipts and logs.
- Heavy AI, model, memory, and artifact data stays off-chain.
- On-chain state stores roots, receipts, commitments, attestations, proofs, and work state.
- Meshtastic and LoRa are low-bandwidth control signaling paths, not normal internet bandwidth.

## Start Here

Every contributor and agent should read:

1. `AGENTS.md`
2. `docs/START_HERE.md`
3. `docs/FLOWMEMORY_HQ_CONTEXT.md`
4. `docs/CURRENT_STATE.md`

Then work only inside the assigned scope.

## Repository Map

- `apps/`: future dashboard, explorer, and hardware console applications
- `contracts/`: future on-chain protocol and hook contracts
- `crypto/`: future cryptographic receipt, proof, and attestation work
- `docs/`: project context, architecture, roadmap, security model, and decisions
- `hardware/`: future FlowRouter, LoRa, Meshtastic, and enclosure work
- `infra/scripts/`: future automation and repository maintenance scripts
- `inbox/`: staging area for imported prompts, notes, and unsorted context
- `research/`: future AI memory, neural geometry, and appchain/L1 research
- `services/`: future indexer, verifier, worker, and API services

## Current Status

See `docs/CURRENT_STATE.md` for the latest repo state.
