# FlowMemory HQ Context

This document is the shared context packet for FlowMemory agents and contributors. Read it before proposing architecture, implementation, research, hardware, or protocol changes.

## Project Identity

FlowMemory is a Base-native AI memory, neural-geometry, reliability, decentralized hardware, and operator-app infrastructure project.

The long-term project shape combines:

- On-chain roots, receipts, commitments, attestations, proofs, and work state
- Off-chain AI memory, model, artifact, retrieval, and neural-geometry data
- Indexer and verifier services that reconstruct facts from chain receipts and logs
- FlowRouter hardware for resilient local and decentralized connectivity experiments
- Meshtastic and LoRa sidecar signaling for low-bandwidth coordination
- Dashboards, explorers, and hardware consoles for operators and researchers
- Longer-horizon infrastructure research only after the public FlowMemory surfaces are mature enough

## Core Concepts

### Base And Uniswap v4 Hooks

FlowMemory is expected to explore Base-native protocol mechanics and Uniswap v4 hooks. Hooks can emit events and update intentional on-chain state, but they cannot know final transaction metadata such as `txHash` or `logIndex` during hook execution.

### FlowPulse Events

FlowPulse events are the intended event stream for protocol activity, work lifecycle, routing signals, memory updates, and reliability checkpoints. A v0 schema and Solidity interface now exist in `contracts/FLOWPULSE_SCHEMA.md` and `contracts/FlowPulse.sol`; future schema changes should be versioned and documented before contracts, indexers, or verifiers depend on them.

### Rootflow And Rootfield

Rootflow and Rootfield refer to state commitment concepts for FlowMemory. They should be treated as commitment layers, not as unlimited data storage. Agents should define what is committed, what stays off-chain, and how verifiers reconstruct or challenge the claimed state.

`contracts/RootfieldRegistry.sol` is the current Rootfield foundation. It registers Rootfield namespaces, accepts committed roots, and emits FlowPulse events. It is not a production protocol deployment and does not implement hook integration, tokenomics, fees, upgrades, governance, verifier policy, or production ownership controls.

### AI Memory And Neural Geometry

The project includes research into AI memory structures, retrieval, embeddings, semantic geometry, compression, continuity, and reliability. Heavy memory and model artifacts stay off-chain. On-chain records should point to commitments, receipts, and verification state rather than raw model data.

### FlowRouter Hardware

FlowRouter is the decentralized internet and local resilience hardware track. It may include routing experiments, operator interfaces, physical enclosures, radio sidecars, and device identity. Hardware tasks must distinguish between product ideas, test rigs, electrical design, firmware, enclosure design, and field validation.

### Meshtastic And LoRa

Meshtastic and LoRa are low-bandwidth control signaling paths. They are useful for coordination, pings, device state, compact receipts, or emergency signaling. They are not normal internet bandwidth and must not be designed as if they can carry heavy app, model, media, or artifact payloads.

## Technical Boundaries

- Storage is not free.
- Transaction hashes do not store arbitrary data.
- Uniswap v4 hooks cannot know `txHash` or `logIndex`.
- Indexers and verifiers derive `txHash` and `logIndex` after reading receipts and logs.
- Heavy AI, model, memory, and artifact data stays off-chain.
- On-chain state stores roots, receipts, commitments, attestations, proofs, and work state.
- `metadataURI` and `evidenceURI` values in the current RootfieldRegistry are arbitrary strings emitted as on-chain log bytes. The contract does not enforce short-pointer behavior or off-chain-storage boundaries.
- Meshtastic and LoRa are low-bandwidth control signaling paths, not normal internet bandwidth.

## Intended Work Areas

- `contracts/`: Base contracts, Uniswap v4 hooks, events, commitments, and protocol state
- `services/`: indexer, verifier, worker, API, and background processing services
- `apps/`: dashboard, explorer, and hardware console experiences
- `hardware/`: FlowRouter, radio sidecars, firmware notes, enclosure models, and field test notes
- `research/`: AI memory, neural geometry, reliability, and applied infrastructure research
- `crypto/`: receipts, attestations, roots, proofs, verification design, and threat analysis
- `infra/scripts/`: CI, automation, local setup, and maintenance scripts
- `docs/DECISIONS/`: accepted architectural decisions
- `inbox/`: temporary intake area for private notes, raw research, and unsorted context

## Collaboration Defaults

Contributors should assume the repo may have multiple active worktrees at once. Keep changes small, avoid unrelated edits, write down decisions, and finish each task with a PR-ready summary.
