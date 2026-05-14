# FlowChain Private/Local Protocol Notes

## Context Notes

- The current project phase is the FlowChain private/local L1 testnet package for second-computer validation.
- Current source-of-truth docs explicitly block production mainnet readiness, public validators, tokenomics, audited cryptography, and production bridge claims.
- Existing Rust devnet model already defines local no-value accounts, faucet records, product token/DEX transactions, local object lifecycle records, deterministic roots, and blocks.
- Existing control-plane types expose local methods for chain state, accounts, balances, transactions, blocks, bridge observations, credits, withdrawals, challenges, finality, and provenance.
- Existing schemas under `schemas/flowmemory/` cover Flow Memory V0 objects, local transaction envelopes, product transactions, bridge observations, bridge credits, withdrawals, and local wallet metadata.
- New schema package covers 14 private/local protocol objects and 23 payload families.
- New fixture package covers 23 valid transactions, 23 receipts, 23 events, two bridge evidence records, a deterministic block, a state root manifest, an export snapshot, and 31 negative cases.

## Alignment Rules

- Reuse camelCase field names already present in the Rust devnet and TypeScript control plane unless the production protocol contract needs a clearer wrapper.
- Keep profile names chain-bound so a transaction signed for one profile cannot validate on another profile.
- Bridge pilot evidence may reference Base chain id `8453`; destination FlowChain profiles remain local/private.
- Genesis fixtures contain public identities only and no secret material.
