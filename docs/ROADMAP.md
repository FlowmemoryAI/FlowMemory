# Roadmap

This roadmap is the project-management view of FlowMemory. Use GitHub issues for execution and `docs/DECISIONS/` for durable decisions.

No tokenomics, production deployment, production Uniswap v4 hook deployment, hardware manufacturing, production bridge work, or unscoped dedicated network infrastructure is approved by this roadmap. Those areas remain separate from the public FlowMemory launch path unless an explicit issue and decision record scope them.

## Immediate Major Milestone: Public FlowMemory Launch Hardening

Goal: make the public repository understandable, reproducible, professional, and aligned around the FlowMemory product story:

- agent memory and Proof-of-Useful-Memory;
- Agent Bonds accountability and task-scoped recourse records;
- public-agent and swarm launch primitives;
- Base-native compact commitments and event receipts;
- dashboard, desktop, Android shell, and documented iOS product track;
- public tester commands that run from a clean clone;
- public-safe claim boundaries and gap tracking.

The public launch path must not expose unrelated infrastructure research as the user entrypoint. A reviewer should be able to clone the repo, read `README.md`, run the public tester lanes, and understand what FlowMemory can do without being redirected into separate network or token work.

Required public-reader docs:

- `README.md`
- `docs/PUBLIC_REPO_GUIDE.md`
- `docs/PUBLIC_TESTER_GUIDE.md`
- `docs/PUBLIC_AGENT_NETWORK_RELEASE.md`
- `docs/PUBLIC_AGENT_NETWORK_TECHNICAL_GUIDE.md`
- `docs/MOBILE_APPS.md`
- `docs/PUBLIC_RELEASE_GAPS.md`
- `docs/MARKETING_CLAIMS_GUARDRAILS.md`
- `docs/PRODUCTION_READINESS_CHECKLIST.md`

Completion gate: the milestone is not accepted until public docs, CI, dashboard build, public tester lanes, mobile distribution docs, and claim guardrails are green and do not surface unrelated chain, token, or network-infrastructure research in public launch paths.

Non-goals:

- No tokenomics.
- No production mainnet claim.
- No production bridge.
- No production hook deployment.
- No hardware manufacturing.
- No audited-cryptography claim.
- No hosted production dashboard or production API.
- No public iOS build claim until an Xcode project and CI lane exist.

Rootflow V0 and Flow Memory V0 remain launch-critical baseline requirements. The public launch milestone is not allowed to fork or duplicate those surfaces.

## Near-Term Phases

### Phase 0: Public Repo OS

Status: active maintenance.

- Keep source-of-truth docs accurate and public-reader safe.
- Keep worktree assignments, PR process, daily runbook, and issue backlog current.
- Keep issue templates and PR templates enforcing scope boundaries.
- Keep status scripts read-only and safe.
- Keep labels and milestones aligned with agent ownership.

### Phase 1: V0 Contracts Foundation

Status: implemented as a local/test foundation; hardening still active.

- Minimal Foundry config and contract tests exist.
- `FlowPulse`, `RootfieldRegistry`, hook-adapter scaffold, afterSwap hook candidate/planner, artifact/cursor/worker/verifier/work registries, receipt verifier, work receipt registry, verifier report registry, Agent Bonds, public-agent, and swarm contracts exist.
- FlowPulse v0 and Rootfield URI/log-data decisions are documented.
- Static-analysis runner, deployment boundary, and access-control review docs exist.
- Define status lifecycle, ownership/recovery, and namespace policy before expanding deployment scope.
- Keep dynamic fees, tokenomics, production deployment, and production hooks out of scope.

### Phase 2: Flow Memory Local/Test Stack

Status: implemented as fixture-first services plus generated launch-core state; production services still gated.

- Canonical FlowPulse observation identity is specified and implemented in crypto/services.
- Verifier statuses and report JSON schema exist for local fixture reports.
- Rootflow transition schema and parent/child state-linking behavior exist as generated local fixtures.
- Flow Memory schemas for MemorySignal, MemoryReceipt, RootfieldBundle, and AgentMemoryView exist under `schemas/flowmemory/`.
- Generated MemorySignal and RootflowTransition fixtures expose contract-event linkage through `contractEvent` and `contractEventRef`.
- Fixture-based parser and reorg-state tests exist in the indexer/verifier packages.
- Deterministic persistence exists for fixture state, constrained Base Sepolia reader checkpoints, and guarded Base canary checkpoints.
- Runtime schema validation and generated fixture drift checks exist for launch-core outputs.

### Phase 3: Public Agent Network

Status: local/test public-agent and swarm primitives are implemented; live evidence and UX hardening remain active.

- Keep class/tool registries, AgentFactory, memory fuel, launch bond, profile, lineage, receipt-anchor, and swarm budget flows green.
- Keep deterministic preview, intent, direct-call preparation, replay, and dashboard projection methods aligned.
- Add provider-backed transaction submission only after SDK security boundaries are accepted.
- Add live dashboard discovery, fuel, bond, and swarm-budget views when event-backed data exists.
- Keep public-agent copy clear about local/test boundaries.

### Phase 4: Agent Bonds Accountability

Status: local/test Agent Bonds v1 and Phase 2 architecture surfaces exist.

- Keep settlement, challenge, slash, verifier confirmation, evidence windows, and timelocked administration tests green.
- Keep Passport / Envelope / Receipt primitives and quote attestations explicit.
- Keep recourse-pool language task-scoped and bounded.
- Keep dashboard and future mobile app surfaces focused on objective work accountability.
- Do not claim insurance, guaranteed reimbursement, or broad public value flow.

### Phase 5: Mobile Operator Apps

Status: Android shell committed; iOS product track documented.

- Keep `apps/dashboard/android` building from the shared dashboard surface.
- Add Android debug APK tester evidence.
- Add mobile-first Agent Bonds, receipts, recourse, wallet/budget, public-agent, and alert routes.
- Add iOS Capacitor/Xcode project only when a reproducible macOS CI lane can build it.
- Keep mobile signing secrets out of Git.

### Phase 6: V0 Review/Audit

Status: active.

- Define foundation PR review rules.
- Add security reporting guidance.
- Enforce claim guardrails in CI for README/docs/marketing surfaces.
- Keep Slither required for audit environments and available through `npm run contracts:hardening:slither`.
- Keep `docs/reviews/LAUNCH_CANDIDATE_SECURITY_BOUNDARY_REVIEW.md` current when launch-facing contract, reader, dashboard, wallet, or claim surfaces change.
- Enforce allowed-folder and forbidden-folder boundaries.

## Mid-Term Phases

### Phase 7: Crypto Schema Layer

Status: implemented for crypto V0 primitives and local Flow Memory object schemas.

- Receipt, attestation, commitment, root, and proof vocabulary exists in `crypto/` docs and helpers.
- Domain separation and replay boundaries exist for the V0 helper package.
- Canonical ids for MemorySignal, MemoryReceipt, RootflowTransition, RootfieldBundle, AgentMemoryView, Agent Bonds, and verifier reports exist in local/test fixtures.
- Validate test vectors through verifier specs and keep cross-language checks passing.
- Keep proof circuits, GPU proofs, verifier economics, and production crypto infrastructure out of scope.

### Phase 8: Dashboard And Operator App Display

Status: implemented as a generated fixture-backed local app, desktop app, and Android shell.

- App-facing entities exist in `apps/dashboard`.
- Observed, pending, finalized, verified, failed, unresolved, unsupported, reorged, offline, and stale states are modeled for display.
- Dashboard renders public launch views for overview, Flow Memory / Rootflow, FlowPulse stream, Agent Bonds, public agents, Rootfields, work receipts, verifier reports, hardware nodes, alerts, and raw JSON.
- Keep hosted production APIs and deployment out of scope until the public stack stabilizes.

### Phase 9: Hardware POC

Status: bounded POC specs and simulator implemented; real hardware integration still future work.

- FlowRouter v0 is defined as research hardware.
- Meshtastic/LoRa control-message candidates are documented.
- Enclosure concepts, NFC memory cartridge concepts, light-pipe indicators, two-node demos, packet schemas, and simulator validation exist.
- Keep manufacturing, firmware production, RF certification work, and field deployment out of scope.

### Phase 10: Research Lab

Status: research-only.

- Define AI memory artifact taxonomy.
- Compare Base settlement anchors, receipt models, reliability patterns, and operator workflows.
- Extract useful concepts into FlowMemory V0 schemas and decisions before importing code or expanding implementation scope.
- Treat longer-horizon infrastructure work as separate from the public launch path.

## Later Gated Work

Status: blocked until explicit go/no-go decisions exist.

- Tokenomics or value-bearing systems.
- Mainnet deployment.
- Production Uniswap v4 hook deployment.
- Verifier services, staking, slashing, or incentives.
- Hardware manufacturing or production decentralized internet claims.
- Any dedicated network infrastructure not directly required by the public FlowMemory launch path.

## Merge Order Preference

The public launch merge preference is:

1. Public repo launch polish and claim guardrails.
2. Agent Bonds public boundary and readiness gates.
3. Public-agent contract/helper/dashboard hardening.
4. Mobile operator app docs, Android build lane, and iOS gap tracking.
5. Dashboard public navigation and copy cleanup.
6. Direct contract-backed SDK completion with provider security boundaries.
7. Base Sepolia public-agent deployment/readback evidence when explicitly scoped.
8. Static analysis follow-up findings triaged for any public deployment.
9. Operator ownership separation and multisig/recovery decision before further live deployments.
