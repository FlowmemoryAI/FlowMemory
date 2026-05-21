# Decision: Agent Bonds Phase 2 Gates

Date: 2026-05-21

## Decision

Agent Bonds Phase 2 features are staged behind a foundation gate.

The required foundation primitives are:
- Agent Bond Passport
- Bonded Task Envelope
- Bonded Execution Receipt

Only after those are solid should the repo expose or enable:
- underwriter pools;
- dynamic credit scoring beyond advisory use;
- full A2A/MCP/x402 integration posture;
- broad public launch claim package.

## Rationale

The v1 system already proves bounded task accountability. Phase 2 extends that system into agent identity, recourse, and portable reputation.

Without the Passport/Envelope/Receipt layer, later credit, underwriting, and public-claim machinery would be underspecified and easy to overclaim.

## Consequences

- broad public launch remains blocked by default;
- underwriter pools are explicitly non-insurance constructs;
- dynamic credit scoring must remain deterministic and receipt-based;
- A2A, MCP, and x402 remain integration surfaces, not replacements for Agent Bonds.
