# Issue Backlog

Last synced: 2026-05-21

This file maps existing GitHub issues and proposed next-wave work into program milestones and agent worktrees. GitHub is still the source of truth for issue state; update this index after issue or milestone changes.

## Milestones

- Public FlowMemory Launch Hardening: README/docs polish, public tester lanes, claim guardrails, dashboard/mobile operator positioning, and release hygiene.
- Rootflow and Flow Memory V0 Launch Core: cross-agent launch target for Rootfield namespaces, Rootflow transitions, Flow Memory schemas, deterministic fixtures, verifier reports, and dashboard-readable state.
- V0 Contracts Foundation: FlowPulse, RootfieldRegistry, contract test hardening, contract-boundary decisions, Agent Bonds, public-agent, and swarm surfaces.
- V0 Local Stack: local fixtures, indexer/verifier schemas, persistence boundary, and bounded live-reader boundary.
- V0 Hardware POC: FlowRouter, Meshtastic/LoRa, enclosure, indicators, NFC cartridge, and hardware demo planning.
- V0 Research Lab: AI memory, crypto vocabulary, proof-carrying receipt research, neural geometry, reliability, and bounded applied research.
- V0 Review/Audit: security process, static analysis, review workflow, audit-readiness gates, and public claim checks.

## Agent Worktrees

- Contracts: `FLOWMEMORY_WORKTREE_ROOT\flowmemory-contracts`
- Indexer/verifier: `FLOWMEMORY_WORKTREE_ROOT\flowmemory-indexer`
- Crypto: `FLOWMEMORY_WORKTREE_ROOT\flowmemory-crypto`
- Dashboard/mobile: `FLOWMEMORY_WORKTREE_ROOT\flowmemory-dashboard`
- Hardware: `FLOWMEMORY_WORKTREE_ROOT\flowmemory-hardware`
- Research: `FLOWMEMORY_WORKTREE_ROOT\flowmemory-research`
- Review/HQ: `FLOWMEMORY_WORKTREE_ROOT\flowmemory-review`

## Public FlowMemory Launch Hardening

Primary milestone: make the public repository professional, reproducible, and aligned around the FlowMemory product story without exposing unrelated private infrastructure research as the launch entrypoint.

Current public-launch lanes:

- README badges, positioning, install/test commands, and mobile app story.
- Public repo guide, tester guide, technical guide, release notes, and gaps list.
- Public hardening gate and unsafe-claim guardrails.
- FlowMemory public SDK and CLI smoke lane.
- Dashboard/browser/desktop/Android operator app packaging.
- iOS product-track documentation until a committed Xcode project and CI lane exist.

Active public launch issues:

| Issue | State | Area | Notes |
| --- | --- | --- | --- |
| #164 | Open | Public-agent launch | Public-agent launch helper and contract-backed gaps. |
| #165 | Open | SDK/CLI | Public SDK and CLI polish. |
| #166 | Open | Dashboard | Public-agent and Agent Bonds dashboard hardening. |
| #167 | Open | Swarm | Swarm helper and dashboard coverage. |
| #168 | Open | Public release | Public release readiness and tester flow. |
| #174 | Open | Mobile apps | Android evidence, iOS gap tracking, mobile operator story. |

Acceptance gates:

- `npm run public:hardening`
- `npm run public:test:quick`
- `npm run public:test:contracts`
- `npm run public:test:e2e`
- `npm run public:test:dashboard`
- `npm run public:test:cli`
- `npm run public:test:all`
- `node infra/scripts/check-unsafe-claims.mjs`

## Rootflow And Flow Memory V0 Launch Core

Primary milestone: make `docs/V0_LAUNCH_ACCEPTANCE.md` pass with concrete implementation evidence.

| Issue | State | Agent/worktree | Dependencies | Notes |
| --- | --- | --- | --- | --- |
| #63 `[launch-core/contracts] Build Rootflow V0 contract support and coverage` | Open | Contracts - `flowmemory-contracts` | #6, #7, #8, #22 | Launch epic for contracts-side evidence; no production hook or deployment. |
| #64 `[launch-core/crypto] Define Rootflow and Flow Memory V0 canonical schemas and fixtures` | Open | Crypto - `flowmemory-crypto` | #17, #40, #45 helpful | Canonical ids, schemas, fixtures, and validation; no proof circuits. |
| #65 `[launch-core/indexer] Implement Rootflow V0 fixture engine and verifier reports` | Open | Indexer - `flowmemory-indexer` | #13, #14, #43, #44, #45, #64 | Must output dashboard-readable Rootflow and Flow Memory fixture state. |
| #66 `[launch-core/dashboard] Render Rootflow and Flow Memory V0 fixture state` | Open | Dashboard - `flowmemory-dashboard` | #19, #65 | Fixture-backed display path; no hosted production API. |
| #67 `[launch-core/review] Audit Rootflow and Flow Memory V0 acceptance across PRs` | Open | Review/HQ - `flowmemory-review` | #63, #64, #65, #66 | Acceptance audit and merge readiness in `docs/reviews/ROOTFLOW_FLOW_MEMORY_V0_ACCEPTANCE_AUDIT.md`; no subsystem implementation. |

## V0 Contracts Foundation

| Issue | State | Agent/worktree | Dependencies | Notes |
| --- | --- | --- | --- | --- |
| #6 `[contracts] Add Foundry configuration for contract test commands` | Open | Contracts - `flowmemory-contracts` | None | Enables simple local contract tests. |
| #7 `[contracts] Expand RootfieldRegistry v0 negative-path tests` | Open | Contracts - `flowmemory-contracts` | #6 | Tests existing behavior only. |
| #8 `[contracts] Define RootfieldRegistry URI boundary policy` | Open | Contracts - `flowmemory-contracts` | None | Decision before stricter URI implementation. |
| #21 `[contracts] Assess Rootfield namespace squatting policy` | Open | Contracts - `flowmemory-contracts` | #8 | Policy first; no fees or tokenomics. |
| #22 `[contracts] Define Rootfield deactivation and status lifecycle` | Open | Contracts - `flowmemory-contracts` | #8 | Status vocabulary before implementation. |
| #23 `[contracts] Define Rootfield ownership transfer and recovery policy` | Open | Contracts - `flowmemory-contracts` | #22 | Ownership policy before mutation logic. |
| #25 `[contracts] Define future Uniswap v4 hook adapter boundary` | Open | Contracts - `flowmemory-contracts` | #13 | Boundary only; no production hook. |
| #26 `[contracts] Defer CursorRegistry until indexer identity spec stabilizes` | Open | Contracts - `flowmemory-contracts` | #13, #14 | Explicit deferral; do not implement. |
| #28 `[contracts] Define future ReceiptVerifier contract boundary` | Open | Contracts + Crypto | #14, #17, #45 | Boundary only; no verifier service. |
| #29 `[contracts] Define future WorkDebtScheduler contract boundary` | Open | Contracts - `flowmemory-contracts` | #22, #52 | Boundary only; no economics. |
| #39 `[contracts/shared] Define future on-chain verifier adapter boundary` | Closed | Contracts + Crypto | Folded into #28/#40 | Closed; keep future adapter gated. |
| #52 `[contracts] Define WorkerRegistry and VerifierRegistry authorization policy` | Open | Contracts - `flowmemory-contracts` | #23, #28 | Authorization policy only. |
| #53 `[contracts] Define ArtifactRegistry canonicalization and resolver policy` | Open | Contracts + Crypto | #8, #17, #45 | Canonicalization before contract design. |

## V0 Local Stack

| Issue | State | Agent/worktree | Dependencies | Notes |
| --- | --- | --- | --- | --- |
| #13 `[indexer/verifier] Define canonical FlowPulse observation identity` | Open | Indexer - `flowmemory-indexer` | #8 | Defines receipt/log identity. |
| #14 `[indexer/verifier] Define verifier result status vocabulary` | Open | Indexer - `flowmemory-indexer` | #13 | Status vocabulary for reports/apps. |
| #38 `[services/verifier] Validate crypto v0 test vectors` | Open | Indexer + Crypto | #17, #40 | Validate fixtures, not production verifier service. |
| #43 `[indexer/verifier] Build minimal fixture-based FlowPulse parser` | Open | Indexer - `flowmemory-indexer` | #13, #6 | Fixture-based parser before broad live RPC. |
| #44 `[indexer/verifier] Define reorg-state model and fixture tests` | Open | Indexer - `flowmemory-indexer` | #13, #43 | Fixture tests before persistence. |
| #45 `[indexer/verifier] Define verifier report JSON schema` | Open | Indexer - `flowmemory-indexer` | #14, #17 | Deterministic schema. |
| #46 `[indexer/verifier] Design future live RPC indexer boundary` | Open | Indexer - `flowmemory-indexer` | #13, #44 | Boundary only before broad live reader. |
| #47 `[services/shared] Define crypto package integration boundary` | Open | Indexer + Crypto | #17, #45 | Package boundary, not production service. |
| #54 `[indexer/verifier] Add V0 persistence layer for observations and reports` | Open | Indexer - `flowmemory-indexer` | #44, #45 | After report/reorg schemas stabilize. |
| #55 `[indexer] Promote V0 local RPC reader toward live Base test indexing` | Open | Indexer - `flowmemory-indexer` | #46, #54 | Later boundary; no production indexing. |

## V0 Hardware POC

| Issue | State | Agent/worktree | Dependencies | Notes |
| --- | --- | --- | --- | --- |
| #11 `[hardware] Define FlowRouter v0 research scope and non-goals` | Open | Hardware - `flowmemory-hardware` | None | Scope guard for all hardware work. |
| #12 `[hardware] Draft Meshtastic and LoRa control-message inventory` | Open | Hardware - `flowmemory-hardware` | #11 | Low-bandwidth control messages only. |
| #30 `[hardware] Draft FlowRouter enclosure concept v0` | Open | Hardware - `flowmemory-hardware` | #11 | Concept only; no manufacturing. |
| #31 `[hardware] Prototype NFC memory cartridge v0` | Open | Hardware - `flowmemory-hardware` | #11, #17 | Prototype planning; no production BOM. |
| #32 `[hardware] Prototype FlowCore light-pipe status indicator` | Open | Hardware - `flowmemory-hardware` | #11 | Concept/prototype only. |
| #33 `[hardware] Plan two-node FlowRouter Meshtastic demo` | Open | Hardware - `flowmemory-hardware` | #12 | Demo plan; no field deployment claim. |
| #34 `[hardware] Measure FlowRouter v0 CAD dimensions` | Open | Hardware - `flowmemory-hardware` | #30 | Measurement only; no final CAD/manufacturing. |

## V0 Research Lab

| Issue | State | Agent/worktree | Dependencies | Notes |
| --- | --- | --- | --- | --- |
| #17 `[crypto] Define v0 receipt, attestation, and commitment schema vocabulary` | Open | Crypto - `flowmemory-crypto` | #13, #14 helpful | Schema vocabulary only. |
| #40 `[crypto/verifier] Implement verifier signature envelope validation` | Open | Crypto - `flowmemory-crypto` | #17, #45 | Keep bounded; no verifier economics. |
| #42 `[research/cryptography] Define zk proof-carrying receipt milestones` | Open | Research + Crypto | #17 | Milestones only; no GPU proofs. |

## V0 Dashboard

| Issue | State | Agent/worktree | Dependencies | Notes |
| --- | --- | --- | --- | --- |
| #19 `[dashboard/app data model] Define operator and explorer state model` | Open | Dashboard - `flowmemory-dashboard` | #14, #45 | Data model only; no UI replacement. |

## V0 Review/Audit

Primary milestone: V0 Review/Audit.

| Issue | State | Agent/worktree | Dependencies | Notes |
| --- | --- | --- | --- | --- |
| #20 `[review] Define foundation review and audit workflow` | Open | Review/HQ - `flowmemory-review` | #10 | Base review process. |
| #24 `[contracts] Add Slither and static-analysis plan for v0 contracts` | Open | Review/Audit + Contracts | #6 | Static-analysis plan. |
| #27 `[security/process] Add SECURITY.md and private reporting guidance` | Open | Review/HQ - `flowmemory-review` | #20 | Reporting process. |

## Priority Notes

P0 sequence:

1. Public launch docs, public tester lanes, claim guardrails, and mobile story.
2. #10, #20, #9
3. #6, #7, #8
4. #13, #14, #17
5. #63, #64, #65, #66, #67
6. #43, #44, #45

P1 sequence:

1. #21, #22, #23, #24
2. #11, #12, #19
3. #40, #42

Blocked or gated:

- #25, #26, #28, #29, #39, #52, #53, #54, #55 require earlier specs or decisions.
- Any tokenomics, dynamic-fee, production mainnet deployment, hardware manufacturing, production hook, hosted production API, or guaranteed-recourse task is out of scope until a later explicit gate.
