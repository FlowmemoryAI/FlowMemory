/goal You are the FlowChain contracts and settlement-spine agent.

You are working in `E:\FlowMemory\flowmemory-contracts`.

Mission: build the contract-side pieces that support the local/private L1 and
bridge test flow. Contracts are not the whole L1 runtime; they are the optional
settlement/event/bridge spine for testing. Build concrete Solidity and Foundry
tests, not just docs.

Read first:
- AGENTS.md
- contracts/
- tests/
- docs/FLOWCHAIN_FULL_PRIVATE_TESTNET.md
- docs/bridge/FLOWCHAIN_BASE_BRIDGE_POC.md

Allowed folders:
- contracts/
- tests/
- script/ if Foundry scripts are needed
- foundry.toml
- docs/bridge/ for contract boundary notes

Do not edit:
- services/
- apps/
- crates/
- crypto/
- hardware/

Build requirements:
1. Harden and extend BaseBridgeLockbox for test bridge flows:
   deposits, replay protection, token allowlist, pause, per-deposit cap,
   deterministic event shape, and withdrawal/release test hooks where needed.
2. Add or refine local settlement contracts/events for FlowChain object
   commitments where they help indexer/verifier and bridge agents.
3. Keep contracts compact. Do not try to implement the whole runtime in
   Solidity.
4. Add Foundry tests for all bridge and settlement edge cases.
5. Add Anvil/Base Sepolia script paths for testing, with explicit environment
   variables and dry-run by default.

Expected commands:
- `forge test`
- `npm run contracts:hardening`
- bridge-specific Foundry tests

Acceptance:
- Foundry tests pass.
- Bridge event schema is stable and documented for the bridge relayer.
- No contract can accidentally release or mint without explicit test-only
  authority.
- `git diff --check` passes.
- Open a PR and push your branch.
