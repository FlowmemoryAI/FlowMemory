# Issue Backlog

Last synced: 2026-05-13

This file maps existing GitHub issues #6-#55 into program milestones and agent worktrees. GitHub is still the source of truth for issue state; update this index after issue or milestone changes.

## Milestones

- V0 Repo OS: management layer, docs, templates, labels, scripts, review process.
- Rootflow and Flow Memory V0 Launch Core: cross-agent launch target for Rootfield namespaces, Rootflow transitions, Flow Memory schemas, deterministic fixtures, verifier reports, and dashboard-readable state.
- V0 Contracts Foundation: FlowPulse, RootfieldRegistry, contract test hardening, contract-boundary decisions.
- V0 Local Stack: local fixtures, indexer/verifier schemas, local devnet gates, persistence boundary, live-reader boundary.
- V0 Hardware POC: FlowRouter, Meshtastic/LoRa, enclosure, indicators, NFC cartridge, hardware demo planning.
- V0 Research Lab: AI memory, crypto vocabulary, no-value devnet/appchain research, proof-carrying receipt research.
- V0 Review/Audit: security process, static analysis, review workflow, audit-readiness gates.

## Agent Worktrees

- Contracts: `E:\FlowMemory\flowmemory-contracts`
- Indexer/verifier: `E:\FlowMemory\flowmemory-indexer`
- Crypto: `E:\FlowMemory\flowmemory-crypto`
- Chain/devnet research: `E:\FlowMemory\flowmemory-chain`
- Dashboard: `E:\FlowMemory\flowmemory-dashboard`
- Hardware: `E:\FlowMemory\flowmemory-hardware`
- Research: `E:\FlowMemory\flowmemory-research`
- Review/HQ: `E:\FlowMemory\flowmemory-review`

## V0 Repo OS

| Issue | State | Agent/worktree | Dependencies | Notes |
| --- | --- | --- | --- | --- |
| #9 `[infrastructure] Add CI validation for setup-worktrees.ps1 syntax` | Open | Review/HQ - `flowmemory-review` | None | Read-only CI validation; no worktree creation in CI. |
| #10 `[infrastructure] Align issue templates with repo labels and agent scopes` | Open | Review/HQ - `flowmemory-review` | Label audit | Keep issue fields aligned with allowed/forbidden folders. |
| #15 `[docs/architecture] Add Rootflow and Rootfield glossary and boundary notes` | Open | Review/HQ - `flowmemory-review` | #8 | Architecture vocabulary; no contract changes. |
| #16 `[docs/architecture] Map observed, committed, and verified state boundaries` | Closed | Review/HQ - `flowmemory-review` | Folded into #14/#15 | Closed as not planned; keep as historical note. |
| #48 `[infrastructure] Ignore generated Foundry artifacts` | Open | Review/HQ - `flowmemory-review` | #6 | `.gitignore` or docs hygiene only. |

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
| #28 `[contracts] Define future ReceiptVerifier contract boundary` | Open | Contracts + Crypto | #14, #17, #45 | Boundary only; no verifier network. |
| #29 `[contracts] Define future WorkDebtScheduler contract boundary` | Open | Contracts - `flowmemory-contracts` | #22, #52 | Boundary only; no economics. |
| #39 `[contracts/shared] Define future on-chain verifier adapter boundary` | Closed | Contracts + Crypto | Folded into #28/#40 | Closed; keep future adapter gated. |
| #52 `[contracts] Define WorkerRegistry and VerifierRegistry authorization policy` | Open | Contracts - `flowmemory-contracts` | #23, #28 | Authorization policy only. |
| #53 `[contracts] Define ArtifactRegistry canonicalization and resolver policy` | Open | Contracts + Crypto | #8, #17, #45 | Canonicalization before contract design. |

## V0 Local Stack

| Issue | State | Agent/worktree | Dependencies | Notes |
| --- | --- | --- | --- | --- |
| #13 `[indexer/verifier] Define canonical FlowPulse observation identity` | Open | Indexer - `flowmemory-indexer` | #8 | Defines receipt/log identity. |
| #14 `[indexer/verifier] Define verifier result status vocabulary` | Open | Indexer - `flowmemory-indexer` | #13 | Status vocabulary for reports/apps. |
| #38 `[services/verifier] Validate crypto v0 test vectors` | Open | Indexer + Crypto | #17, #40 | Validate fixtures, not production verifier network. |
| #43 `[indexer/verifier] Build minimal fixture-based FlowPulse parser` | Open | Indexer - `flowmemory-indexer` | #13, #6 | Fixture-based parser before live RPC. |
| #44 `[indexer/verifier] Define reorg-state model and fixture tests` | Open | Indexer - `flowmemory-indexer` | #13, #43 | Fixture tests before persistence. |
| #45 `[indexer/verifier] Define verifier report JSON schema` | Open | Indexer - `flowmemory-indexer` | #14, #17 | Deterministic schema. |
| #46 `[indexer/verifier] Design future live RPC indexer boundary` | Open | Indexer - `flowmemory-indexer` | #13, #44 | Boundary only before live reader. |
| #47 `[services/shared] Define crypto package integration boundary` | Open | Indexer + Crypto | #17, #45 | Package boundary, not production service. |
| #49 `[chain/devnet] Define local devnet smoke-test gate` | Open | Chain - `flowmemory-chain` | #6, #43, #51 | No mainnet; local smoke gate only. |
| #51 `[chain/devnet] Define local FlowPulse receipt fixture handoff` | Open | Chain + Indexer | #13, #43 | Fixture handoff for local stack. |
| #54 `[indexer/verifier] Add V0 persistence layer for observations and reports` | Open | Indexer - `flowmemory-indexer` | #44, #45 | After report/reorg schemas stabilize. |
| #55 `[indexer] Promote V0 local RPC reader toward live Base test indexing` | Open | Indexer - `flowmemory-indexer` | #46, #49, #54 | Later boundary; no production indexing. |

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
| #18 `[chain/appchain research] Define future appchain or L1 go/no-go criteria` | Open | Chain - `flowmemory-chain` | None | Research gate; no chain design. |
| #35 `[chain/appchain] Define no-value appchain prototype criteria` | Open | Chain - `flowmemory-chain` | #18 | No-value prototype criteria only. |
| #36 `[chain/appchain] Define Base settlement anchor spec` | Open | Chain - `flowmemory-chain` | #35 | Research/spec; no deployment. |
| #37 `[chain/appchain] Define appchain hardware node requirements` | Open | Chain + Hardware | #35, #11 | Requirements only. |
| #40 `[crypto/verifier] Implement verifier signature envelope validation` | Open | Crypto - `flowmemory-crypto` | #17, #45 | Keep bounded; no verifier economics. |
| #41 `[chain/appchain] Research bridge and security review requirements` | Open | Chain - `flowmemory-chain` | #35, #36 | Research requirements; no bridge implementation. |
| #42 `[research/cryptography] Define zk proof-carrying receipt milestones` | Open | Research + Crypto | #17 | Milestones only; no GPU proofs. |
| #50 `[chain/appchain] Select no-value appchain prototype framework` | Open | Chain - `flowmemory-chain` | #35, #41, #49 | Framework selection only after gates. |

## V0 Dashboard

| Issue | State | Agent/worktree | Dependencies | Notes |
| --- | --- | --- | --- | --- |
| #19 `[dashboard/app data model] Define operator and explorer state model` | Open | Dashboard - `flowmemory-dashboard` | #14, #45 | Data model only; no UI scaffold. |

## V0 Review/Audit

Primary milestone: V0 Review/Audit.

| Issue | State | Agent/worktree | Dependencies | Notes |
| --- | --- | --- | --- | --- |
| #20 `[review] Define foundation review and audit workflow` | Open | Review/HQ - `flowmemory-review` | #10 | Base review process. |
| #24 `[contracts] Add Slither and static-analysis plan for v0 contracts` | Open | Review/Audit + Contracts | #6 | Static-analysis plan. |
| #27 `[security/process] Add SECURITY.md and private reporting guidance` | Open | Review/HQ - `flowmemory-review` | #20 | Reporting process. |

## Priority Notes

P0 sequence:

1. #10, #20, #9
2. #6, #7, #8
3. #13, #14, #17
4. #63, #64, #65, #66, #67
5. #43, #44, #45, #49, #51

P1 sequence:

1. #21, #22, #23, #24
2. #11, #12, #19
3. #35, #36, #41

Blocked or gated:

- #25, #26, #28, #29, #39, #50, #52, #53, #54, #55 require earlier specs or decisions.
- Any tokenomics, dynamic-fee, production L1, mainnet deployment, hardware manufacturing, or production hook task is out of scope until a later explicit gate.
