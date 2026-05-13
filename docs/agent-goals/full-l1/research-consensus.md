/goal You are the FlowChain consensus, storage, and architecture research agent.

You are working in `E:\FlowMemory\flowmemory-research`.

Mission: make fast architecture decisions that unblock implementation. This is
not open-ended research. Produce accepted decisions, concrete protocol shapes,
and testable acceptance gates for the builder agents.

Read first:
- AGENTS.md
- research/flowchain-local-alpha/
- docs/DECISIONS/
- docs/FLOWCHAIN_FULL_PRIVATE_TESTNET.md
- docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md

Allowed folders:
- research/
- docs/DECISIONS/
- docs/ARCHITECTURE.md only if needed
- docs/ROADMAP.md only if needed

Do not edit:
- crates/
- services/
- apps/
- contracts/
- crypto/
- hardware/

Deliver decisions for:
1. Local/private consensus model for V0: single-node, multi-process, LAN mode,
   fork choice, block interval, validator identity, and state sync.
2. Transaction and state model: nonce, account, fee/test-unit semantics,
   mempool ordering, replay protection, state root commitments.
3. Storage model: what is in state, what is in files, what is artifact metadata,
   what is never stored in the chain.
4. Bridge model: observed deposit, local credit, withdrawal intent, replay
   handling, testnet/mainnet boundary.
5. Wallet/key model: local encrypted vault, public account metadata, signing
   domains, rotation.
6. Acceptance gates for claiming "full local/private L1 testnet".

Acceptance:
- Decision records are concrete enough that each builder agent can implement
  without inventing protocol rules.
- `git diff --check` passes.
- Open a PR and push your branch.
