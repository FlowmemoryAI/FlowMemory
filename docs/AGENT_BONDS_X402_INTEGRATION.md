# Agent Bonds x402 Integration

x402 is the HTTP-native payment and funding trigger surface.

FlowMemory supports two conceptual modes:

1. Service payment
   - quote generation;
   - verifier API calls;
   - receipt retrieval;
   - paid MCP tools.

2. Escrow bridge
   - payment intent linked to a Bonded Task Envelope;
   - linkage between payment intent, envelope hash, escrow task id, and final receipt.

x402 does not bypass escrow, task policy, verifier flow, or receipt generation.
