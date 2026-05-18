# Current State

Last updated: 2026-05-17

This file is the beginner-friendly source of truth for what exists in FlowMemory right now. It should stay factual, dated, and conservative. GitHub issues, pull requests, and merged files remain the final project record.

## Repo Phase

FlowMemory is in launch-candidate V0 hardening, with the next coordination
target defined as a FlowChain private/local L1 testnet package for
second-computer validation.

The bootstrap repository operating system, contracts V0 foundation, crypto V0 foundation, local indexer/verifier fixture package, dashboard V0, FlowRouter hardware POC, local no-value devnet prototype, launch-core contract-event spine, and pre-production hardening guardrails have merged into `main`. The launch-candidate work added swap-derived memory signals, stricter launch validation, and Base Sepolia testnet deploy/read commands.

On 2026-05-13 a small Base mainnet canary deployment was broadcast for V0 testing. It is documented in `docs/DEPLOYMENTS/2026-05-13-base-canary-v0.md`. A guarded Base mainnet canary reader now exists for those known canary addresses and small explicit block ranges. This is not a production launch and does not change the production/mainnet-readiness guardrails.

The launch-core V0 stack now has a single runnable local command that connects contract fixtures, local indexing/verifier outputs, crypto schema vocabulary, Rootflow transitions, Flow Memory objects, generated dashboard state, local no-value devnet output, and hardware POC output without production deployment.

Launch-critical direction: keep Rootflow V0 and Flow Memory V0 green while
packaging the next private/local testnet milestone. Rootflow defines
memory-state transitions. Flow Memory defines the agent-facing memory objects
derived from FlowPulse observations, receipts, verifier reports, and committed
roots. The FlowChain private/local testnet target must build on those surfaces;
it is not approval for production mainnet, public validators, tokenomics,
audited cryptography, or production bridge work.

## Implemented In The Merged Repo

Repository operating system:

- `AGENTS.md` with shared agent instructions.
- `docs/START_HERE.md` with required reading order and local multi-agent worktree workflow.
- Source-of-truth docs for context, roadmap, architecture, security model, project charter, agent roles, and current state.
- `docs/DECISIONS/` for durable decision records.
- GitHub issue and pull request templates.
- Conservative repository hygiene CI.
- `infra/scripts/setup-worktrees.ps1` for local multi-agent worktrees under `E:\FlowMemory`.
- Placeholder work areas for `contracts/`, `services/`, `apps/`, `hardware/`, `research/`, `crypto/`, `infra/scripts/`, and `inbox/`.

Contracts foundation:

- `contracts/FlowPulse.sol` defines the FlowPulse v0 event interface and initial pulse type constants.
- `contracts/RootfieldRegistry.sol` registers Rootfield namespaces, accepts committed roots, and emits FlowPulse events.
- `contracts/FlowMemoryHookAdapter.sol` is a compileable V0 hook-adapter scaffold. It emits `SWAP_MEMORY_SIGNAL` FlowPulse events for the launch fixture path. It is not a production Uniswap v4 hook.
- `contracts/FlowMemoryAfterSwapHook.sol` is a PoolManager-gated Uniswap v4 `afterSwap` hook candidate for the real hook path. It emits FlowPulse without custody, fee override, or `txHash`/`logIndex` assumptions.
- `contracts/FlowMemoryHookPlanner.sol` records the afterSwap-only permission flag, address-mining target, CREATE2 planning helpers, and Base Sepolia planning constants.
- `contracts/ArtifactRegistry.sol`, `CursorRegistry.sol`, `ReceiptVerifier.sol`, `WorkerRegistry.sol`, `VerifierRegistry.sol`, `WorkReceiptRegistry.sol`, `VerifierReportRegistry.sol`, and `WorkDebtScheduler.sol` provide local/test skeleton surfaces for commitments, cursors, work receipts, verifier reports, and work state.
- `contracts/FLOWPULSE_SCHEMA.md` documents event fields, receipt boundaries, and URI/log-data limitations.
- Foundry tests currently cover the registry/hook/receipt surfaces, including afterSwap hook boundaries and CREATE2 planning.
- `tests/README.md` documents the current test command.
- `contracts/STATIC_ANALYSIS.md`, `contracts/DEPLOYMENT_BOUNDARY.md`, and `contracts/ACCESS_CONTROL_REVIEW.md` define the current hardening, deployment, and access-control boundaries.
- `infra/scripts/contracts-static-analysis.ps1` and `infra/scripts/contracts-static-analysis.sh` run the contract hardening baseline. Slither is optional by default and required only when explicitly requested.

Crypto foundation:

- `crypto/` contains runnable Keccak-based V0 hash helpers, typed domains, receipt/report/root/artifact/work helpers, attestation helpers, fixtures, and test vectors.
- Crypto tests currently pass with local object, signed-envelope, wallet, and vector coverage: 21 Node tests, 38 vector validations, and 15 local-alpha documents with 15 signature envelopes plus 1 local transaction envelope.

Indexer/verifier local package:

- `services/shared/`, `services/indexer/`, `services/verifier/`, `services/flowmemory/`, `services/control-plane/`, and `services/bridge-relayer/` contain fixture-first local packages.
- The local services test suite currently passes across the shared, indexer, verifier, Flow Memory, control-plane, and bridge-relayer packages.
- `npm run e2e` currently indexes 8 observations, writes 7 cursors, rejects 2 logs, tracks 1 duplicate, and produces 8 verifier reports.
- The verifier uses local fixture evidence only. It is not a production verifier network.
- The verifier supports local fixture checks for rootfield registration, root commitments, and swap-derived memory-signal commitments.
- The control-plane API prefers live local runtime state from `devnet/local/`, falls back to deterministic fixtures, and exposes a 49-method local smoke client for node status, blocks, transactions, accounts, balances, wallets, Rootfields, receipts, verifier reports, memory cells, challenges, finality, bridge observations, bridge deposits, bridge credits, withdrawals, provenance, and raw JSON.
- Control-plane transaction and bridge-observation intake writes local ignored files under `devnet/local/intake/` and rejects private-key, mnemonic, seed phrase, RPC credential, API key, and webhook-shaped material.
- `npm run index:base-sepolia -- --rpc-url <url> --address <contract> --from-block <n> --to-block <n>` provides a constrained Base Sepolia reader path.
- The Base Sepolia reader requires an explicit RPC URL, rejects non-Base-Sepolia chain ids, rejects broad scans by default, validates resolved HTTP(S) RPC URLs, persists canonical state and a durable checkpoint atomically, and records resume fields without storing RPC URLs or keys.
- `npm run index:base-canary -- --acknowledge-mainnet-canary --rpc-url <url> --address <contract> --from-block <n> --to-block <n>` provides a guarded Base mainnet canary reader path for the documented V0 canary deployment only.
- The Base canary reader requires explicit acknowledgement, RPC URL, addresses, and block range; rejects non-Base-mainnet chain ids; refuses scans wider than 5,000 blocks; persists canonical state plus a durable canary checkpoint; and marks the checkpoint as not production-ready.
- A live canary read over blocks `45955500` to `45955540` observed 4 FlowPulse logs from the documented `RootfieldRegistry` and `FlowMemoryHookAdapter` canary addresses with 0 rejected logs and 0 duplicates.
- `fixtures/deployments/base-canary-v0.json`, committed canary reader output, and `npm run flowmemory:canary-dashboard` now generate a separate Base canary dashboard dataset.
- The dashboard has a separate Base canary mode at `/canary` that shows live-read canary FlowPulse observations, Rootflow transitions, canary boundaries, and raw canary JSON without replacing local fixture mode.
- `npm run verify:base-canary:sources` produces a dry-run source verification plan for all canary contracts and writes `fixtures/deployments/base-canary-source-verification-plan.json`; `npm run verify:base-canary:sources:submit` submits after `BASESCAN_API_KEY` is configured.
- All 10 deployed Base canary contracts are verified on BaseScan. `FlowMemoryHookAdapter` was verified against deployment-source commit `11d562c` because `main` now contains the newer v4-shaped callback path.
- `npm run deploy:base-sepolia:plan` writes a non-secret Base Sepolia rehearsal plan artifact. `npm run deploy:base-sepolia` and `npm run deploy:base-sepolia:broadcast` provide Foundry dry-run/broadcast commands for the current V0 Base Sepolia testnet contract set. They require local env values and do not commit credentials.
- `npm run hook:base-sepolia:plan`, `npm run hook:base-sepolia:env-check`,
  `npm run hook:base-sepolia:evidence`,
  `npm run hook:base-sepolia:require-live-proof`,
  `npm run hook:base-sepolia:acceptance`,
  `npm run hook:base-sepolia:check`, `npm run hook:base-sepolia:dry-run`,
  `npm run hook:base-sepolia:swap-proof:dry-run`,
  `npm run hook:base-sepolia:readback-range`,
  `npm run hook:base-sepolia:readback:auto`, and
  `npm run hook:base-sepolia:flowmemory` now provide a Base Sepolia Uniswap v4
  hook proof path for `FlowMemoryAfterSwapHook`.
  `npm run hook:base-sepolia:env-check` writes a non-secret local readiness
  artifact for RPC presence, Base Sepolia chain id, deployer key format,
  deployer address, and test ETH balance before any public testnet broadcast.
  `npm run hook:base-sepolia:readback-range` writes a non-secret post-broadcast
  readback range plan from explicit operator block numbers or, after broadcast,
  from successful receipt block numbers in the swap-proof artifact. It refuses
  dry-run artifacts as live readback evidence. The auto-readback command runs
  readback from that inferred broadcast receipt range. The manual readback
  command wraps the Base Sepolia indexer for the hook address and fails by
  default unless the selected block range contains at least one hook FlowPulse
  observation. The current mined hook address is
  `0xD24d7f807cb00D28DdF675E55879547d4F7B0040`, with afterSwap-only low bits
  `0x0040`, salt
  `0x0000000000000000000000000000000000000000000000004915000000000000`,
  and PoolManager constructor arg
  `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408`. Live code checks against
  Uniswap's Base Sepolia PoolManager, router, periphery, test helper, and
  Permit2 addresses pass. A full PoolManager swap proof has passed dry-run
  simulation. `npm run hook:base-sepolia:evidence` currently reports
  `stage: dry-run-proof-ready` and `liveProofComplete: false`; the strict
  `npm run hook:base-sepolia:require-live-proof -- --json` gate correctly fails
  until the real funded Base Sepolia broadcast and non-empty indexer readback
  are complete. `npm run hook:base-sepolia:flowmemory` now converts completed
  readback/evidence artifacts into Flow Memory, Rootflow, and dashboard JSON;
  it fails by default until live proof is complete, while
  `npm run hook:base-sepolia:flowmemory -- --allow-incomplete` writes a
  diagnostic, non-production dashboard artifact that shows the missing proof
  pieces. The strict generator also rejects weak readbacks: counts must agree
  across evidence, readback, checkpoint, and indexer state; observations must be
  successful `IFlowPulse.FlowPulse` logs from the planned Base Sepolia hook; and
  at least one non-duplicate, non-reorged observation must be pulse type `4`
  (`SWAP_MEMORY_SIGNAL`). `npm run hook:base-sepolia:acceptance` writes the
  final non-secret acceptance package and exits nonzero until env-check,
  official live code, deployed hook code, broadcast receipts, PoolManager
  initialize/liquidity/swap actions, successful receipts for those actions,
  planned hook runtime-bytecode identity, readback range, range/readback
  artifact agreement, non-empty readback, consolidated evidence, generated Flow
  Memory objects, FlowPulse observation integrity, successful
  `SWAP_MEMORY_SIGNAL` evidence, Flow Memory signal linkage to successful
  broadcast receipt transactions, and count agreement all pass.
- `docs/DEPLOYMENTS/BASE_SEPOLIA_REHEARSAL.md` defines the dry-run, optional broadcast, write smoke, readback, source-verification, and rollback rehearsal path.
- `docs/DEPLOYMENTS/BASE_SEPOLIA_V4_HOOK_PROOF.md` defines the exact live
  proof runbook for broadcasting the mined hook, initializing a v4 pool, adding
  tiny test liquidity, executing a real Base Sepolia swap, reading FlowPulse
  logs, and generating Flow Memory / Rootflow evidence.
- A Base mainnet V0 canary deployment exists for testing only; deployed addresses and smoke transactions are recorded in `docs/DEPLOYMENTS/2026-05-13-base-canary-v0.md`.

Dashboard V0:

- `apps/dashboard/` contains a Vite/React fixture-backed dashboard.
- It renders overview, Flow Memory / Rootflow, FlowPulse stream, Rootfields, work receipts, verifier reports, devnet blocks, hardware nodes, alerts, and raw JSON views.
- The dashboard uses the generated canonical fixture at `fixtures/dashboard/flowmemory-dashboard-v0.json`.
- Dashboard tests and production build pass after installing `apps/dashboard` dependencies.

Launch-core integration:

- `npm run launch:v0` runs the local end-to-end V0 flow.
- `npm run launch:candidate` runs contract hardening, launch generation, runtime schema validation, fixture drift checks, and launch claim guardrails.
- `npm run validate:launch` validates generated MemorySignal, MemoryReceipt, RootflowTransition, RootfieldBundle, and AgentMemoryView objects against canonical JSON schemas.
- `npm run fixtures:check` confirms committed launch and dashboard fixtures match generated output.
- `fixtures/launch-core/flowmemory-launch-v0.json` contains generated MemorySignal, MemoryReceipt, RootfieldBundle, AgentMemoryView, and RootflowTransition objects.
- `fixtures/launch-core/rootflow-transitions.json` contains concrete generated RootflowTransition output.
- `schemas/flowmemory/` contains canonical JSON schemas for MemorySignal, MemoryReceipt, RootflowTransition, RootfieldBundle, and AgentMemoryView.
- Generated MemorySignals include a `contractEvent` object tying each signal to `IFlowPulse.FlowPulse` event semantics, pulse type names, indexed fields, payload fields, and receipt-derived locator fields.
- Generated RootflowTransitions include `contractEventRef` so reviewers and dashboards can trace each transition back to the contract event that produced the MemorySignal.
- `services/flowmemory/src/status.ts` implements the explicit verifier-to-Flow-Memory status adapter: `valid` -> `verified`, `invalid` -> `failed`, `unresolved` -> `unresolved`, `unsupported` -> `unsupported`, `reorged` -> `reorged`.
- `.github/workflows/ci.yml` now includes area jobs for contracts, services/launch core, crypto, dashboard, devnet, and hardware.
- CI repository hygiene now runs `node infra/scripts/check-unsafe-claims.mjs` to block unsafe positive production, mainnet, free-storage, trustless-verifier, ISP-replacement, and AI-on-chain claims in README/docs/marketing surfaces.

Local no-value devnet prototype:

- `crates/flowmemory-devnet/` contains a Rust local devnet prototype.
- It models deterministic local transactions, blocks, state roots, handoff output, and native local objects for agent accounts, model passports, work receipts, verifier reports, memory cells, challenges, finality receipts, artifact availability, and no-value local test-unit/faucet records.
- It has 20 passing Rust tests.
- It is not a production L1, value-bearing token system, sequencer, validator set, or bridge.

FlowRouter hardware POC:

- `hardware/` contains FlowRouter V0 POC docs, BOM/assembly/enclosure concepts, LoRa sidecar message inventory, NFC cartridge concepts, field-test notes, JSON packet schemas, and a simulator.
- The simulator validates `hardware/fixtures/flowrouter_sample_seed42.json`.
- Hardware is still a research POC, not manufactured or field-deployed product hardware.

Launch-core specifications:

- `docs/ROOTFLOW_V0.md` defines the Rootflow V0 transition model, status vocabulary, agent ownership, and launch acceptance.
- `docs/FLOW_MEMORY_V0.md` defines MemorySignal, MemoryReceipt, RootfieldBundle, AgentMemoryView, work-lane vocabulary, and dashboard display expectations.
- `docs/V0_LAUNCH_ACCEPTANCE.md` maps the Rootflow and Flow Memory objective to concrete artifacts and evidence.
- `docs/FLOWCHAIN_FULL_PRIVATE_TESTNET.md` defines the next private/local testnet package target and build-on-existing boundaries.
- `docs/FLOWCHAIN_SECOND_COMPUTER_SETUP.md` names the current merged second-computer command path and the root-level FlowChain wrapper commands.
- `docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md` marks private/local testnet features as implemented, in flight, missing, or later gated.
- `docs/FLOWCHAIN_AGENT_INTEGRATION_MAP.md` maps the next-wave worktree ownership and cross-agent handoffs.
- `docs/FLOWCHAIN_TROUBLESHOOTING.md` and `docs/FLOWCHAIN_OPERATOR_CHECKLIST.md` provide the Windows-first second-computer troubleshooting and operator checklist layer.
- `docs/LAUNCH_DEMO_RUNBOOK.md` provides the beginner-safe browser click script, operator talk track, recovery steps, and launch-day demo checklist.
- `docs/DECISIONS/rootflow-v0.md` records the V0 decision and non-goal boundaries.
- `docs/reviews/ROOTFLOW_FLOW_MEMORY_V0_ACCEPTANCE_AUDIT.md` tracks evidence and missing work for the active launch-core goal.
- `docs/reviews/LAUNCH_CANDIDATE_SECURITY_BOUNDARY_REVIEW.md` records the current security boundary review for local/test V0 demos and guarded canary review.
- `docs/reviews/OPEN_PR_MERGE_READINESS.md` is now historical merge-readiness evidence for PRs that have merged.
- `docs/LAUNCH_CORE_AGENT_GOALS.md` provides copy-ready goals for the contracts, crypto, indexer/verifier, dashboard, and review worktrees.

FlowChain private/local testnet snapshot:

- Implemented: V0 launch-core generation and validation, no-value deterministic
  Rust devnet prototype, native private/local object lifecycle, local
  control-plane API and smoke client, contract event/settlement spine,
  Uniswap v4 afterSwap hook candidate/planner, crypto V0 helpers and vectors,
  fixture indexer/verifier, fixture-backed dashboard/workbench, hardware POC
  simulator, Base Sepolia reader/deploy commands, guarded canary reader, and
  Windows-first root wrapper commands for prerequisite checks, init, bounded
  start/stop, demo, smoke, full smoke, export/import, and workbench dev mode.
- In flight: optional hardware operator signal fixtures, Base Sepolia live
  rehearsal execution against a funded testnet deployer, the real Base Sepolia
  Uniswap v4 PoolManager hook swap proof and indexer readback, and advanced L1
  research gates.
- Missing: long-running multi-process node behavior, LAN peer mode, encrypted
  local operator vault, and second-computer smoke evidence for the latest
  full-smoke branch.
- Later gated: production L1/mainnet, public validators, tokenomics,
  production bridge, production hook deployment, audited cryptography,
  proof-circuit infrastructure, production hardware, and hosted production
  services.

## Conceptual Or Not Implemented Yet

- Production protocol deployment.
- Production ownership, upgrade, governance, fee, token, or incentive mechanics.
- Dynamic fees or tokenomics.
- Production Uniswap v4 hook deployment.
- Live deployed Uniswap v4 pool proof using the mined Base Sepolia hook address
  and a real Base Sepolia PoolManager swap. The tooling and dry-run proof path
  exist; the funded public-testnet broadcast/readback is still pending.
- Production Rootflow runtime implementation.
- Production Flow Memory runtime implementation.
- Hosted launch-core services.
- Production indexer or verifier service runtime.
- Production persistence layer, production live RPC reader, production APIs, or hosted services.
- Broad Base mainnet reader.
- Broad production source-verification process for future redeploys. The current Base canary addresses are verified, but future deployments must be verified again before any production claim.
- Explorer or hardware console implementation.
- FlowRouter firmware, manufacturing, final enclosure work, or field deployment.
- Real Meshtastic or LoRa device integration.
- Cryptographic proof systems, GPU proofs, verifier networks, or verifier economics.
- Production appchain/L1 implementation, validator planning, sequencer planning, bridge deployment, or mainnet deployment.

## Active GitHub Work Shape

Issues #6 through #55 define the current foundation-hardening backlog. They are organized into program milestones in `docs/ISSUE_BACKLOG.md`.

Closed issue notes:

- #16 was closed as not planned because its scope was folded into other architecture/status issues.
- #39 was closed; future on-chain verifier adapter work should stay gated behind accepted verifier and crypto boundaries.

As of the 2026-05-13 HQ review for the private/local testnet next wave, GitHub
shows open draft PRs #71 and #73, plus open canary follow-up issues #76 through
#79. Local sibling worktrees contain unmerged Local Alpha work; those changes
are useful context but are not source of truth until merged.

Recently merged PRs:

- #56 FlowRouter V0 POC hardware package.
- #57 Contracts V0 foundation.
- #58 Local FlowMemory devnet prototype.
- #59 FlowMemory HQ program manager OS.
- #60 Crypto V0 foundation.
- #61 Indexer/verifier V0 fixture package.
- #62 Dashboard V0.
- #68 Launch-core FlowMemory V0 integration.
- #69 Contract event spine for launch-core Flow Memory objects.

## Active Local Work

Local worktrees may contain unmerged work. Unmerged files are not source of truth until reviewed and merged.

Use:

```powershell
cd E:\FlowMemory\flowmemory-main
.\infra\scripts\status-report.ps1
```

Before assigning agents, check for dirty worktrees and avoid overlapping folders.

## Active Technical Boundaries

- AI does not run on-chain.
- Storage is not free.
- Transaction hashes do not store arbitrary data.
- Uniswap v4 hooks cannot know `txHash` or `logIndex` during execution.
- Indexers and verifiers derive `txHash` and `logIndex` after receipts and logs exist.
- Heavy AI, model, memory, media, and artifact data stays off-chain.
- On-chain state stores only intentional roots, receipts, commitments, attestations, proofs, and work state.
- `RootfieldRegistry` is a skeleton/foundation contract, not a production protocol surface.
- `metadataURI` and `evidenceURI` are arbitrary caller-supplied strings emitted as log data.
- The current contract does not enforce URI length, content, format, resolvability, or short-pointer behavior.
- Meshtastic and LoRa are low-bandwidth control-signaling paths, not normal internet bandwidth.

## Current Operator Priorities

1. Keep the generated launch-core command stable in CI.
2. Keep the new root wrapper path usable on Windows: `flowchain:prereq`, `flowchain:init`, `flowchain:start`, `flowchain:demo`, `flowchain:smoke`, `flowchain:full-smoke`, `flowchain:export`, and `workbench:dev`.
3. Use `npm run flowchain:full-smoke` as the private/local package acceptance gate before claiming a branch is demo-ready.
4. Keep improving the missing subsystem pieces behind the wrappers: long-running runtime behavior, LAN peer mode, encrypted local operator vault, workbench polish, and Base Sepolia hook deployment planning.
5. Keep the guarded Base canary reader and dashboard canary artifacts fresh when canary smoke actions change.
6. Complete the Base Sepolia v4 hook proof with a funded testnet key: broadcast
   after `npm run hook:base-sepolia:env-check -- --json` reports
   `broadcastReady: true`, then run
   `npm run hook:base-sepolia:swap-proof:broadcast -- --json`, run
   `npm run hook:base-sepolia:readback-range -- --infer-readback-range --json`,
   run `npm run hook:base-sepolia:readback:auto -- --json` or the explicit
   `npm run hook:base-sepolia:readback -- --rpc-url $env:BASE_SEPOLIA_RPC_URL --from-block <deployBlock> --to-block <latestBlock> --finalized-block <safeFinalizedBlock> --json`,
   require `npm run hook:base-sepolia:require-live-proof -- --json` to pass, and
   run `npm run hook:base-sepolia:flowmemory` to generate Flow Memory /
   Rootflow dashboard evidence from the live observation, then require
   `npm run hook:base-sepolia:acceptance -- --json` to pass before calling the
   Base Sepolia hook proof accepted.
7. Continue contracts hardening without production mainnet deployment or token mechanics.
8. Keep dashboard work fixture-backed until a production API is explicitly scoped.
9. Keep production mainnet, public validator, tokenomics, audited-cryptography, and production bridge claims out of scope.

## Update Rule

Update this file whenever merged repository state changes in a way that affects new agents. Keep it concrete, dated, and conservative.
