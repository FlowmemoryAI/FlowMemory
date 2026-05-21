# Agent Bonds Dynamic Credit Scoring

Dynamic credit scoring is deterministic and receipt-based.

It is not an LLM score and not a black-box trust rating.

Inputs include:
- settled tasks;
- slashed tasks;
- timeout tasks;
- challenge outcomes;
- verifier diversity;
- value-weighted experience.

Outputs are advisory until a valid signed attestation path is present.

The score may influence:
- quote-time bond multipliers;
- quote-time capacity;
- whether confirming verifiers are recommended;
- whether an agent is eligible for underwriter backing.
