# Open PR Merge Readiness

Date: 2026-05-13

Status: active review summary.

This file summarizes the open PRs that contain most of the currently built FlowMemory work. It distinguishes what is already merged, what is built in PR branches, and what still needs to be built after merge.

## Already Merged Into Main

| PR | Status | What it contains |
| --- | --- | --- |
| #1 bootstrap repository scaffolding | Merged | Repo structure, initial docs, workflow scaffolding. |
| #2 contracts foundation | Merged | Initial `FlowPulse`, `RootfieldRegistry`, and Foundry test foundation. |

## Open PRs Reviewed

| PR | Area | Local checks verified | Merge readiness |
| --- | --- | --- | --- |
| #59 HQ program manager OS | Docs/HQ | `git diff --check`; non-ASCII scan; GitHub issue/PR verification | Merge first. Establishes Rootflow/Flow Memory source-of-truth docs, audit, goals, backlog, and runbook. |
| #57 contracts V0 foundation | Contracts | `forge test` -> 33 passing; `git diff --check origin/main...HEAD` | Ready after #59 if no conflicts. Provides registries, Rootfield lifecycle, hook boundary, receipts/reports/work skeletons, and tests. |
| #60 crypto V0 foundation | Crypto | `npm test` -> 13 passing; `npm run validate:vectors` -> 21 vectors; Python vector recompute passed; diff check passed | Ready after #59 if docs do not conflict. Provides canonical crypto helpers, ids, receipts, report digests, fixtures, attestations, and docs. |
| #61 indexer/verifier fixture package | Services | `npm test` -> 24 passing; `npm run e2e` -> 7 observations and 7 reports; diff check passed after cleanup commit `125f84f` | Ready after #59/#60, with one integration note: external status mapping must remain explicit. |
| #62 dashboard V0 | Dashboard | `npm test` -> 4 passing; `npm run build` passed; diff check passed after cleanup commit `4577968` | Ready after #61 if fixture shape remains compatible. |
| #58 local devnet prototype | Chain/devnet | `cargo test --manifest-path crates\flowmemory-devnet\Cargo.toml` -> 7 passing; diff check passed | Ready after source docs, but not required for first Rootflow/Flow Memory launch core. |
| #56 FlowRouter hardware POC | Hardware | simulator fixture validation passed; diff check passed | Ready as bounded hardware POC. Not blocking Rootflow/Flow Memory core. |

## Recommended Merge Order

1. #59 HQ program manager OS.
2. #60 crypto V0 foundation.
3. #57 contracts V0 foundation.
4. #61 indexer/verifier fixture package.
5. #62 dashboard V0.
6. #58 local devnet prototype.
7. #56 FlowRouter hardware POC.

Reasoning:

- #59 should merge first because it updates source-of-truth docs, launch-core goals, and review audit.
- #60 should merge before #61 because indexer/verifier depends on crypto schema and fixture boundaries.
- #57 can merge before or after #60, but it should land before services are treated as contract-adjacent truth.
- #61 should merge before #62 because dashboard should follow service fixture shapes.
- #58 and #56 are useful but not blockers for Rootflow/Flow Memory launch core.

## What Still Needs To Be Built

Launch-core missing work:

- A single end-to-end command that runs FlowPulse fixture -> indexer observation -> receipt/report -> Rootflow transition -> dashboard state.
- Concrete `RootflowTransition` output artifacts, not only docs and implicit parent-pulse links.
- Canonical Flow Memory JSON schemas for:
  - `MemorySignal`
  - `MemoryReceipt`
  - `RootfieldBundle`
  - `AgentMemoryView`
- A generated dashboard fixture that is produced from indexer/verifier output rather than hand-maintained dashboard fixture data.
- CI jobs that run area-specific checks:
  - `forge test`
  - crypto `npm test` and vector validation
  - services `npm test` and `npm run e2e`
  - dashboard `npm test` and `npm run build`
  - devnet `cargo test`
  - hardware simulator validation
- A clear external status adapter between verifier `valid`/`invalid` and Flow Memory/dashboard `verified`/`failed` or a decision to standardize the names.
- Updated `docs/CURRENT_STATE.md` after each PR merge.

Not launch blockers:

- Production L1.
- Tokenomics.
- Production Uniswap v4 hook deployment.
- Full trustless verifier network.
- Hardware manufacturing.
- Production decentralized internet claims.

## Current Bottom Line

Most of the V0 foundation exists in GitHub PR branches. It is not all merged into `main` yet.

The project is ready for a careful merge sequence, followed by one integration pass that creates the end-to-end Rootflow/Flow Memory acceptance command and generated dashboard fixture.
