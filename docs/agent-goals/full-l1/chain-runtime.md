/goal You are the FlowChain full L1 runtime agent.

You are working in `E:\FlowMemory\flowmemory-chain`.

Mission: turn the existing Rust deterministic devnet into a runnable
private/local L1 testnet runtime that can run on a second Windows computer. This
must be real implementation work, not a planning-only PR.

Read first:
- AGENTS.md
- docs/FLOWCHAIN_FULL_PRIVATE_TESTNET.md
- docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md
- docs/FLOWCHAIN_AGENT_INTEGRATION_MAP.md
- docs/LOCAL_DEVNET.md
- crates/flowmemory-devnet/
- infra/scripts/flowchain-*.ps1

Allowed folders:
- crates/flowmemory-devnet/
- devnet/
- infra/scripts/
- package.json and package-lock.json when adding root commands
- docs/LOCAL_DEVNET.md
- docs/FLOWCHAIN_SECOND_COMPUTER_SETUP.md
- docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md only for acceptance evidence

Do not edit:
- apps/dashboard/
- services/ except documented handoff files if strictly necessary
- contracts/
- crypto/
- hardware/

Build requirements:
1. Add a long-running node mode to the Rust devnet. It must keep state on disk,
   accept local transactions, produce blocks on an interval or manual tick, and
   expose useful logs.
2. Add a transaction intake path for FlowChain-native objects:
   AgentAccount, ModelPassport, WorkReceipt, ArtifactAvailabilityProof,
   VerifierModule, VerifierReport, MemoryCell, Challenge, FinalityReceipt, and
   local balance/faucet records.
3. Add a local account/balance ledger for test units only. This is not
   tokenomics; it is necessary so the test chain can send transactions and
   bridge credits.
4. Add a minimal node identity and peer model. At minimum support multi-process
   local nodes with static peer config and deterministic block/state sync. LAN
   mode can be simple, but it must be documented and smoke-tested if exposed.
5. Add CLI commands and npm wrappers for:
   - start node
   - stop node
   - node status
   - submit transaction
   - faucet local account
   - run one-node smoke
   - run two-node or multi-process smoke
   - export/import runtime state
6. Keep the existing deterministic fixture/demo path working.
7. Feed handoff outputs to the existing control-plane and dashboard surfaces.

Expected commands to add or make work:
- `npm run flowchain:node`
- `npm run flowchain:node:stop`
- `npm run flowchain:tx`
- `npm run flowchain:faucet`
- `npm run flowchain:node:smoke`
- `npm run flowchain:multi-node:smoke`
- contribute to `npm run flowchain:full-smoke`

Acceptance:
- `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml` passes.
- A local node can run for at least 10 blocks.
- A signed or locally authorized transaction can be submitted and included.
- State survives restart.
- Export/import still works.
- Multi-process smoke either passes or clearly marks LAN mode as not yet exposed
  while still proving two local nodes can exchange or reconcile state.
- `git diff --check` passes.
- Open a PR and push your branch.

Do not stop because part of this is difficult. If full networking is too large
for one pass, build the smallest real local multi-process version and leave a
failing/skip-marked test naming the exact remaining gap.
