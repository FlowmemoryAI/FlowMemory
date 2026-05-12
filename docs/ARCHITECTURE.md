# Architecture

## Overview

FlowMemory is organized as a layered system:

1. On-chain protocol layer on Base
2. Off-chain indexing and verification layer
3. AI memory and neural-geometry research layer
4. Hardware and control-signaling layer
5. Operator apps and explorer layer
6. Future appchain/L1 research layer

No layer is fully implemented yet.

## On-Chain Layer

Expected responsibilities:

- Emit FlowPulse events.
- Store intentional protocol state.
- Store roots, receipts, commitments, attestations, proofs, and work state where appropriate.
- Integrate with Base and possibly Uniswap v4 hooks.

Boundaries:

- On-chain storage is expensive.
- Transaction hashes are identifiers, not arbitrary data storage.
- Uniswap v4 hooks cannot know final `txHash` or `logIndex`.
- Contracts should not pretend to know receipt metadata that only exists after execution.

## Indexer And Verifier Layer

Expected responsibilities:

- Read receipts and logs.
- Derive `txHash` and `logIndex`.
- Reconstruct FlowPulse streams.
- Resolve off-chain artifacts.
- Verify roots, receipts, commitments, attestations, and proofs.
- Produce deterministic verification outputs.

## AI Memory Layer

Expected responsibilities:

- Store and process heavy memory, model, embedding, and artifact data off-chain.
- Commit to important data through roots or receipts.
- Support research into neural geometry, retrieval, continuity, compression, and reliability.

## Hardware Layer

Expected responsibilities:

- Explore FlowRouter hardware.
- Test Meshtastic and LoRa sidecar signaling.
- Prototype 3D-printed enclosures.
- Define device identity, operator controls, and field diagnostics.

Boundaries:

- LoRa and Meshtastic are low-bandwidth control channels.
- Heavy data transfer must use appropriate network paths, not radio sidecar links.

## App Layer

Expected responsibilities:

- Dashboard for operators.
- Explorer for protocol and verification state.
- Hardware console for FlowRouter and sidecar status.

## Future Appchain/L1 Layer

Expected responsibilities:

- Research whether FlowMemory needs a dedicated execution, settlement, or verification environment.
- Compare appchain/L1 options against Base-native design.
- Define criteria before implementation.

## Data Flow Sketch

1. A protocol action emits events and updates intentional on-chain state.
2. Indexers read receipts and logs after execution.
3. Indexers derive transaction and log metadata.
4. Verifiers check off-chain artifacts against commitments and roots.
5. Apps present state, proofs, and operational health.
6. Hardware sidecars exchange compact control signals where useful.
