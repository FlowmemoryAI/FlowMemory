# Agent Bonds Phase 2 Architecture

## Thesis

FlowMemory Agent Bonds Phase 2 extends the existing capped-pilot task-bond system into a portable accountability, liability, and recourse architecture for AI agents.

Phase 2 is additive. It does not replace the existing escrow, stake, verifier, challenge, cap, or launch-boundary controls.

## Foundation primitives

Phase 2 is gated on three foundation primitives:

1. Agent Bond Passport
2. Bonded Task Envelope
3. Bonded Execution Receipt

Advanced features stay blocked until those three primitives are present, fixture-backed, and validation-passing.

The repo now also contains an optional onchain USDC recourse-pool layer. That layer is additive and does not weaken the existing v1 pilot controls.

## Gate model

- Passport/Envelope/Receipt must validate.
- A2A, MCP, and x402 adapters remain scaffolds unless the foundation is ready.
- Dynamic credit scoring remains advisory until receipt-backed scoring and attestation validation are present.
- Underwriter pools remain optional and non-mandatory.
- Broad public launch claims remain blocked by default.

## Advanced features

Phase 2 scaffolds:

- A2A agent-card extension
- MCP tools/resources/prompts surface
- x402 payment-intent and escrow-bridge metadata
- deterministic credit scoring
- underwriter pool capacity/reourse simulation
- public claim package generation and validation

These do not approve public value-bearing launch.
