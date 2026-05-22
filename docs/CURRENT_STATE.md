# Current State

Last updated: 2026-05-21

This file is the beginner-friendly source of truth for what exists in FlowMemory right now. It should stay factual, dated, and conservative. GitHub issues, pull requests, and merged files remain the final project record.

## Repo Phase

FlowMemory is in public launch-candidate hardening. The public-facing repo focuses on agent memory, Agent Bonds, public-agent infrastructure, reproducible local/test verification, dashboard/mobile operator surfaces, and claim guardrails.

The bootstrap repository operating system, contracts V0 foundation, crypto V0 foundation, local indexer/verifier fixture package, dashboard V0, FlowRouter hardware POC, launch-core contract-event spine, public-agent stack, mobile operator-app documentation, and public hardening guardrails have merged into `main`.

Public launch direction: keep Rootflow V0 and Flow Memory V0 green while making the public repo understandable to builders, testers, reviewers, and future operators. Separate token or network-infrastructure research is not part of the public FlowMemory launch entrypoint unless explicitly scoped.

A local/test Agent Bonds v1 accountability surface exists for objective off-chain task escrow, verifier confirmation, challenge flow, capped pilot controls, evidence-availability windows, and timelocked multisig administration paths. Agent Bonds Phase 2 adds Passport / Envelope / Receipt primitives, gated A2A/MCP/x402 integration scaffolds, deterministic credit-scoring scaffolds, signed recourse-policy quote attestations, requester API/data quote-create SDK helpers, and an optional task-scoped recourse-pool path through `AgentUnderwriterPool`, `UnderwriterPoolRegistry`, and `AgentBondManager.openTaskWithRecourse(...)`. Recourse remains task-scoped and capped by policy, attestations, concentration limits, pool epoch loss caps, and withdrawal cooldown controls; it does not approve broad public value flow or promise reimbursement for every loss.

On 2026-05-13 a small Base mainnet canary deployment was broadcast for V0 testing. It is documented in `docs/DEPLOYMENTS/2026-05-13-base-canary-v0.md`. A guarded Base mainnet canary reader now exists for those known canary addresses and small explicit block ranges. This is not a production launch and does not change the production/mainnet-readiness guardrails.

On 2026-05-21 the repo gained a public-agent local/test stack: shared `BaseOnchainAgentMemory` runtime integration, public agent class/tool/profile/lineage/fuel/bond/receipt contracts, `AgentFactory`, swarm policy/registry/budget/factory contracts, deterministic public launch helpers, control-plane and SDK/CLI discovery/preview methods, direct calldata builders for `AgentFactory.launchAgent(...)` and `SwarmFactory.createSwarm(...)`, dashboard projection, Foundry tests, and a local Foundry e2e script. This is public for review and local experimentation only; it is not a production launch or audited runtime.

The public-facing app story includes the mobile operator layer. The shared dashboard surface is packaged as browser/desktop and a committed Android Capacitor shell, while iOS remains an explicitly documented product track until an Xcode project and CI lane are added. Mobile is positioned as the always-available operator console for Agent Bonds, receipts, recourse, wallet/budget state, public-agent monitoring, and future alerting.

The launch-core V0 stack has a runnable local command path that connects contract fixtures, local indexing/verifier outputs, crypto schema vocabulary, Rootflow transitions, Flow Memory objects, generated dashboard state, and hardware POC output without production deployment.

## Implemented In The Merged Repo

Repository operating system:

- `AGENTS.md` with shared agent instructions.
- `docs/START_HERE.md` with required reading order and local multi-agent workflow.
- Source-of-truth docs for context, roadmap, architecture, security model, project charter, agent roles, and current state.
- Public-reader documentation starts at `docs/PUBLIC_REPO_GUIDE.md`, with tester lanes in `docs/PUBLIC_TESTER_GUIDE.md`, public-agent implementation details in `docs/PUBLIC_AGENT_NETWORK_TECHNICAL_GUIDE.md`, release status in `docs/PUBLIC_AGENT_NETWORK_RELEASE.md`, tracked public gaps in `docs/PUBLIC_RELEASE_GAPS.md`, and a `public:hardening` gate that checks public docs, scripts, CI wiring, mobile surfaces, and tester-report templates.
- `docs/DECISIONS/` for durable decision records.
- GitHub issue and pull request templates.
- Conservative repository hygiene CI.
- `infra/scripts/setup-worktrees.ps1` for local multi-agent worktrees under `FLOWMEMORY_WORKTREE_ROOT`.
- Active work areas for `contracts/`, `services/`, `apps/`, `hardware/`, `research/`, `crypto/`, `infra/scripts/`, and `inbox/`.

Contracts foundation:

- `contracts/FlowPulse.sol` defines the FlowPulse v0 event interface and initial pulse type constants.
- `contracts/RootfieldRegistry.sol` registers Rootfield namespaces, accepts committed roots, and emits FlowPulse events.
- `contracts/FlowMemoryHookAdapter.sol` is a compileable V0 hook-adapter scaffold. It emits `SWAP_MEMORY_SIGNAL` FlowPulse events for the launch fixture path. It is not a production Uniswap v4 hook.
- `contracts/FlowMemoryAfterSwapHook.sol` is a PoolManager-gated Uniswap v4 `afterSwap` hook candidate for the real hook path. It emits FlowPulse without custody, fee override, or `txHash`/`logIndex` assumptions.
- `contracts/FlowMemoryHookPlanner.sol` records the afterSwap-only permission flag, address-mining target, CREATE2 planning helpers, and Base Sepolia planning constants.
- `contracts/ArtifactRegistry.sol`, `CursorRegistry.sol`, `ReceiptVerifier.sol`, `WorkerRegistry.sol`, `VerifierRegistry.sol`, `WorkReceiptRegistry.sol`, `VerifierReportRegistry.sol`, and `WorkDebtScheduler.sol` provide local/test skeleton surfaces for commitments, cursors, work receipts, verifier reports, and work state.
- `contracts/AgentBondManager.sol`, `TaskBondEscrow.sol`, `AgentStakeRegistry.sol`, `TaskPolicyRegistry.sol`, `AgentBondTimelockedMultisig.sol`, and `shared/TwoStepOwnable.sol` provide a local/test Agent Bonds accountability path with capped-pilot controls, independent verifier confirmation, evidence-availability windows, two-step ownership, and timelocked multisig administration.
- Public-agent and swarm contracts provide local/test class/tool/profile/lineage/fuel/bond/receipt, agent factory, swarm policy, registry, factory, membership, lifecycle, and budget-vault primitives.
- `contracts/FLOWPULSE_SCHEMA.md` documents event fields, receipt boundaries, URI/log-data limitations, and reserved Agent Bonds task lifecycle pulse types.
- Foundry tests cover registry/hook/receipt surfaces, afterSwap hook boundaries, CREATE2 planning, Agent Bonds settlement/slash paths, timelocked multisig controls, public-agent launch flows, and swarm budget lifecycle.

Crypto foundation:

- `crypto/` contains runnable Keccak-based V0 hash helpers, typed domains, receipt/report/root/artifact/work helpers, attestation helpers, fixtures, local wallet helpers, and test vectors.
- Crypto tests pass with local object, signed-envelope, wallet, and vector coverage.

Indexer/verifier/service package:

- `services/shared/`, `services/indexer/`, `services/verifier/`, `services/flowmemory/`, `services/control-plane/`, `services/bridge-relayer/`, `services/flowmemory-sdk/`, and `services/agent-memory-sdk/` contain fixture-first local/test packages.
- The local services test suite covers shared helpers, indexer, verifier, Flow Memory, control-plane, bridge-relayer, public-agent helpers, Agent Bonds helpers, FlowMemory public SDK, and agent-memory SDK reads.
- The verifier uses local fixture evidence only. It is not a production verifier service.
- The verifier supports local fixture checks for rootfield registration, root commitments, and swap-derived memory-signal commitments.
- The control-plane API exposes local/test smoke methods for Rootfields, receipts, verifier reports, memory cells, public agents, swarms, Agent Bonds, wallet/budget state, provenance, and raw JSON.
- Transaction and bridge-observation intake paths reject private-key, mnemonic, seed phrase, RPC credential, API key, and webhook-shaped material.
- Base Sepolia and guarded Base canary reader paths exist for explicit addresses, explicit RPC URLs, and bounded block ranges; they do not store RPC URLs or keys.
- The Base canary dashboard mode at `/canary` shows committed canary FlowPulse observations, Rootflow transitions, canary boundaries, and raw canary JSON without replacing local fixture mode.

Dashboard and operator apps:

- `apps/dashboard/` contains a Vite/React fixture-backed dashboard.
- It renders public launch views for overview, Flow Memory / Rootflow, FlowPulse stream, Rootfields, work receipts, verifier reports, Agent Bonds, public-agent state, Base agent memory, hardware nodes, alerts, and raw JSON.
- The dashboard uses the generated canonical fixture at `fixtures/dashboard/flowmemory-dashboard-v0.json`.
- Browser, desktop, and Android app shells share the dashboard surface.
- Electron builds brand as FlowMemory.
- Android Capacitor shell exists at `apps/dashboard/android` with FlowMemory app naming.
- iOS is part of the product direction, but no committed Xcode project exists yet.

Agent Bonds:

- A local/test Agent Bonds v1 accountability surface exists for objective off-chain task escrow, verifier confirmation, challenge flow, capped pilot controls, evidence-availability windows, and timelocked administration paths.
- Agent Bonds Phase 2 adds Passport / Envelope / Receipt primitives, gated A2A/MCP/x402 integration scaffolds, deterministic credit-scoring scaffolds, signed recourse-policy quote attestations, requester API/data quote-create SDK helpers, and an optional recourse-pool path through `AgentUnderwriterPool`, `UnderwriterPoolRegistry`, and `AgentBondManager.openTaskWithRecourse(...)`.
- Recourse remains task-scoped and capped by policy, attestations, concentration limits, pool epoch loss caps, and withdrawal cooldown controls. It is not insurance and does not promise reimbursement for every loss.

Public-agent stack:

- Shared `BaseOnchainAgentMemory` runtime integration exists.
- Public agent class/tool/profile/lineage/fuel/bond/receipt contracts and `AgentFactory` exist.
- Swarm policy/registry/budget/factory contracts exist.
- Deterministic public launch helpers, control-plane discovery/preview methods, SDK/CLI smoke lanes, direct calldata builders, dashboard projection, Foundry tests, and a local Foundry e2e script exist.
- This is public for review and local experimentation only; it is not a production launch or audited runtime.

Mobile operator layer:

- The public-facing app story includes the mobile operator layer.
- The shared dashboard surface is packaged as browser/desktop and a committed Android Capacitor shell.
- iOS remains an explicitly documented product track until an Xcode project and CI lane are added.
- Mobile is positioned as the always-available operator console for Agent Bonds, receipts, recourse, wallet/budget state, public-agent monitoring, and future alerting.

FlowRouter hardware POC:

- `hardware/` contains FlowRouter V0 POC docs, BOM/assembly/enclosure concepts, LoRa sidecar message inventory, NFC cartridge concepts, field-test notes, JSON packet schemas, and a simulator.
- The simulator validates `hardware/fixtures/flowrouter_sample_seed42.json`.
- Hardware is still a research POC, not manufactured or field-deployed product hardware.

Launch-core specifications:

- `docs/ROOTFLOW_V0.md` defines the Rootflow V0 transition model, status vocabulary, agent ownership, and launch acceptance.
- `docs/FLOW_MEMORY_V0.md` defines MemorySignal, MemoryReceipt, RootfieldBundle, AgentMemoryView, work-lane vocabulary, and dashboard display expectations.
- `docs/V0_LAUNCH_ACCEPTANCE.md` maps the Rootflow and Flow Memory objective to concrete artifacts and evidence.
- `docs/LAUNCH_DEMO_RUNBOOK.md` provides the beginner-safe browser click script, operator talk track, recovery steps, and launch-day demo checklist.
- `docs/DECISIONS/rootflow-v0.md` records the V0 decision and non-goal boundaries.
- `docs/reviews/ROOTFLOW_FLOW_MEMORY_V0_ACCEPTANCE_AUDIT.md` tracks evidence and missing work for the active launch-core goal.
- `docs/reviews/LAUNCH_CANDIDATE_SECURITY_BOUNDARY_REVIEW.md` records the current security boundary review for local/test V0 demos and guarded canary review.
- `docs/reviews/OPEN_PR_MERGE_READINESS.md` is now historical merge-readiness evidence for PRs that have merged.
- `docs/LAUNCH_CORE_AGENT_GOALS.md` records the public boundary for launch-core coordination; raw prompt packs stay out of the public repo.

## Conceptual Or Not Implemented Yet

- Production protocol deployment.
- Production ownership, upgrade, governance, fee, or uncapped public incentive mechanics.
- Dynamic fees or public tokenomics.
- Production Uniswap v4 hook deployment.
- Production Rootflow runtime implementation.
- Production Flow Memory runtime implementation.
- Hosted launch-core services or a public multi-operator Agent Bonds runtime.
- Production indexer or verifier service runtime.
- Production persistence layer, production live RPC reader, production APIs, or hosted services.
- Broad Base mainnet reader.
- Broad production source-verification process for future redeploys.
- Explorer or hardware console implementation beyond the fixture-backed dashboard surfaces.
- FlowRouter firmware, manufacturing, final enclosure work, or field deployment.
- Real Meshtastic or LoRa device integration.
- Cryptographic proof systems, GPU proofs, verifier services, or verifier economics.
- Production bridge deployment or mainnet deployment.
- Finished iOS app or App Store / Play Store availability.

## Active GitHub Work Shape

Issues #6 through #55 define the older foundation-hardening backlog. Public launch issues #164 through #168 and #174 track the current public-agent, SDK, dashboard, swarm, and mobile operator gaps.

Recently merged PRs:

- #56 FlowRouter V0 POC hardware package.
- #57 Contracts V0 foundation.
- #58 Local runtime prototype.
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
cd FLOWMEMORY_WORKTREE_ROOT\flowmemory-main
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

1. Keep public launch docs and README aligned around FlowMemory agent accountability.
2. Keep `npm run public:hardening` and `npm run public:test:all` green.
3. Keep Agent Bonds public claims task-scoped, bounded, and not framed as insurance.
4. Keep dashboard and app copy fixture-backed until a production API is explicitly scoped.
5. Keep Android app packaging reproducible and iOS accurately documented as planned.
6. Keep Base Sepolia and canary evidence explicit, bounded, and non-production.
7. Keep production mainnet, public tokenomics, audited-cryptography, production bridge, and guaranteed-recourse claims out of scope.

## Update Rule

Update this file whenever merged repository state changes in a way that affects new agents. Keep it concrete, dated, and conservative.
