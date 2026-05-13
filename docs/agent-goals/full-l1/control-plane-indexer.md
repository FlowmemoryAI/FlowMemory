/goal You are the FlowChain control-plane, indexer, and verifier API agent.

You are working in `E:\FlowMemory\flowmemory-indexer`.

Mission: make the local node queryable and usable. Extend the existing
`services/` packages into the API layer for the private/local L1 testnet. This
must support live node state, submitted transactions, bridge observations, and
the full object lifecycle. Do not create a second API framework.

Read first:
- AGENTS.md
- docs/FLOWCHAIN_CONTROL_PLANE_API.md
- docs/FLOWCHAIN_FULL_PRIVATE_TESTNET.md
- docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md
- services/control-plane/
- services/indexer/
- services/verifier/
- services/bridge-relayer/

Allowed folders:
- services/
- fixtures/ when generated service fixtures are needed
- schemas/flowmemory/ only when coordinating response schemas
- package.json and package-lock.json when adding commands
- docs/FLOWCHAIN_CONTROL_PLANE_API.md
- docs/INDEXER_VERIFIER_MVP.md

Do not edit:
- apps/dashboard/
- contracts/
- crates/flowmemory-devnet/ except documented API handoff examples
- crypto/ except schema references
- hardware/

Build requirements:
1. Keep `/health`, `/state`, `/rpc`, and CORS working for the browser.
2. Add live local-node adapters so the API reads current runtime state from
   `devnet/local/` or the node API, not only committed fixtures.
3. Add JSON-RPC and HTTP helpers for:
   node status, peers, blocks, transactions, mempool, accounts, balances,
   faucet events, wallet public metadata, AgentAccount, ModelPassport,
   WorkReceipt, ArtifactAvailabilityProof, VerifierModule, VerifierReport,
   MemoryCell, Challenge, FinalityReceipt, bridge deposits, bridge credits, and
   withdrawals.
4. Add transaction submission endpoint that forwards signed/local test
   transactions to the runtime agent's intake path.
5. Add bridge observation intake/read endpoints for the bridge agent.
6. Add full smoke client coverage that queries every lifecycle object.
7. Add no-secret response scanning.

Expected commands:
- `npm run control-plane:serve`
- `npm run control-plane:smoke`
- `npm run control-plane:test`
- contribute to `npm run flowchain:full-smoke`

Acceptance:
- `npm test` passes for services.
- `npm run control-plane:smoke` proves the full local lifecycle.
- Browser workbench can consume the API without CORS failures.
- API responses contain no private keys, mnemonics, RPC secrets, or seed
  phrases.
- `git diff --check` passes.
- Open a PR and push your branch.
