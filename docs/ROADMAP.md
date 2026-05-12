# Roadmap

This roadmap is directional. Use issues and decision records for committed work.

## Phase 0: Repository Readiness

- Establish agent instructions and shared context.
- Create work-area directories.
- Add issue and pull request templates.
- Add conservative CI.
- Record architecture, security, roadmap, and current state docs.

## Phase 1: Protocol Definitions

- Define FlowPulse event vocabulary.
- Define Rootflow and Rootfield commitment semantics.
- Decide what data is on-chain, off-chain, or derived.
- Draft receipt, attestation, proof, and root formats.
- Document Uniswap v4 hook constraints and Base assumptions.

## Phase 2: Minimal Indexer And Verifier Loop

- Read chain receipts and logs.
- Derive `txHash` and `logIndex` from observed logs.
- Reconstruct FlowPulse activity.
- Verify commitments against off-chain artifacts.
- Produce deterministic verification reports.

## Phase 3: Applications

- Build an operator dashboard.
- Build a protocol explorer.
- Build a hardware console.
- Make verification state visible and understandable.

## Phase 4: Hardware Research

- Define FlowRouter hardware scope.
- Validate Meshtastic and LoRa control-signaling use cases.
- Prototype device identity and compact receipt exchange.
- Develop and test 3D-printed enclosures.

## Phase 5: AI Memory And Neural Geometry Research

- Define memory artifact formats and commitments.
- Explore embedding, retrieval, continuity, and reliability metrics.
- Connect research artifacts to verifiable receipts.
- Keep heavy artifacts off-chain.

## Phase 6: Appchain/L1 Research

- Define why an appchain or L1 would be needed.
- Compare Base-native, appchain, and L1 tradeoffs.
- Model validator, data availability, verification, and hardware implications.
- Produce a go/no-go decision record before implementation.
