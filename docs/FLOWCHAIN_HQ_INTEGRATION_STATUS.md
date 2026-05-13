# FlowChain HQ Integration Status

Status: live HQ issue, PR, branch, ownership, merge-order, and smoke map for
the FlowChain private/local L1 testnet package.

Last synced: 2026-05-13.

GitHub is the source of truth. This file is the local HQ view after checking
open GitHub PRs/issues, `status-report.ps1`, and the local package command map.

## GitHub Source Of Truth

Milestone:

- #7 `FlowChain Private/Local L1 Testnet Package`

Full-L1 workstream issues:

| Area | Issue | Primary branch/worktree | Ownership |
| --- | --- | --- | --- |
| Chain/runtime | #99 | `agent/full-l1-runtime` in `E:\FlowMemory\flowmemory-chain` | `crates/flowmemory-devnet/`, `devnet/`, runtime wrappers |
| Crypto/wallet | #100 | `agent/full-l1-crypto-wallet` in `E:\FlowMemory\flowmemory-crypto` | `crypto/`, `schemas/flowmemory/`, wallet/envelope vectors |
| Control plane/indexer | #101 | `agent/full-l1-control-plane` in `E:\FlowMemory\flowmemory-indexer` | `services/`, live API, no-secret API checks |
| Dashboard/workbench | #102 | `agent/full-l1-workbench` in `E:\FlowMemory\flowmemory-dashboard` | `apps/dashboard/`, local workbench views |
| Contracts/settlement | #103 | `agent/full-l1-contracts` in `E:\FlowMemory\flowmemory-contracts` | `contracts/`, `tests/`, bridge/settlement events |
| Bridge/test credit | #104 | `agent/full-l1-bridge` in `E:\FlowMemory\flowmemory-bridge-full` | `services/bridge-relayer/`, `contracts/bridge/`, bridge schemas/fixtures |
| Hardware signals | #105 | `agent/full-l1-hardware` in `E:\FlowMemory\flowmemory-hardware` | `hardware/`, `fixtures/hardware/`, optional signal fixtures |
| Research decisions | #106 | `agent/full-l1-research-consensus` in `E:\FlowMemory\flowmemory-research` | `research/`, `docs/DECISIONS/` |
| HQ integration | #107 | `agent/full-l1-hq-integration` in `E:\FlowMemory\flowmemory-review` | docs, runbooks, issue/PR map, smoke evidence |
| Full smoke gate | #108 | `agent/full-l1-hq-integration` plus subsystem branches | `infra/scripts/flowchain-full-smoke.ps1`, root package command |

Other relevant issues:

- #78 remains open for the real Uniswap v4 hook path beyond the adapter
  scaffold. It is not on the critical path for the private/local L1 runtime.
- #76, #77, and #79 are closed. Do not keep treating them as active canary
  follow-up issues.

## Open PRs

| PR | Branch | Status | Changed ownership | Review notes | Merge order |
| --- | --- | --- | --- | --- | --- |
| #114 `[codex] Extend local FlowChain control-plane API` | `agent/full-l1-control-plane` | Draft, CI passing | `services/control-plane/`, `docs/FLOWCHAIN_CONTROL_PLANE_API.md`, `docs/INDEXER_VERIFIER_MVP.md`, `package.json` | Matches #101 ownership. Adds live/local-file preference, submit/intake surfaces, and no-secret scan. Review should focus on whether transaction/bridge intake contracts match #99/#104 and whether package command additions conflict with #111/#113. | After #111, before #112 if dashboard depends on the expanded methods. |
| #113 `[codex] Build bridge relayer credit handoff smoke` | `agent/full-l1-bridge` | Draft, CI passing | `services/bridge-relayer/`, bridge schemas/fixtures/docs, bridge scripts, `package.json` | Matches #104 ownership. Adds bridge local-credit smoke and full-smoke wiring on its branch. Review should coordinate schema/event assumptions with #110 and runtime handoff expectations with #99/#101. | After #110 event schema is accepted, and after or alongside #114 if API intake is required. |
| #112 `[codex] Expand FlowChain workbench live console` | `agent/full-l1-workbench` | Draft, CI passing | `apps/dashboard/`, `docs/DASHBOARD_MVP.md` | Matches #102 ownership and extends the existing dashboard rather than adding a second app. PR notes say `flowchain:full-smoke` is not present on its branch, so it needs rebase after #111 before final review. Review should focus on API-gated actions, no browser private-key handling, and avoiding production/mainnet or real-funds UX claims. | After #101/#114 API surfaces are stable enough, or merge earlier only if all live API assumptions are fixture-safe and #111 is rebased in. |
| #110 `[codex] harden bridge lockbox settlement spine` | `agent/full-l1-contracts` | Draft, CI passing | `contracts/`, `tests/`, `script/`, `docs/bridge/` | Matches #103 ownership and does not touch services/apps/crates/crypto/hardware. Needs PR body or comment to link #103. Review should focus on duplicate bridge object semantics with #104 and whether `FlowChainSettlementSpine` stays optional settlement/event support rather than a second runtime. | Candidate early merge after #107 if #103 linkage is added and bridge relayer #104 accepts the event schema. |
| #71 `[codex] add terminal goal dispatcher` | `hq/terminal-dispatch` | Draft | `infra/scripts/send-goal-to-agent.ps1` | The merged launcher from #98 already starts full-L1 agents. Before merge, confirm this dispatcher still has distinct value and document how it relates to `launch-full-l1-agents.ps1`; avoid two competing dispatch paths. | After #107 refresh, or close if superseded by #98. |
| #73 `[codex] add L1 research inventory` | `hq/l1-research-inventory` | Draft | `docs/CURRENT_STATE.md`, `docs/L1_RESEARCH_INVENTORY.md`, `docs/ROADMAP.md` | Docs-only and no product implementation. Needs rebase/refresh against current `main` and the new #106 research decision issue before merge because it touches source-of-truth state docs. | Before or alongside #106 if refreshed; otherwise after #106 decisions. |

Recently merged:

- #98 `Add full L1 agent goal launcher` is merged into `main` at
  `83d33f0`. It added `docs/agent-goals/full-l1/` and
  `infra/scripts/launch-full-l1-agents.ps1`.

## Local Worktrees

Current `status-report.ps1` output showed these active branches:

| Worktree | Branch | PR | Dirty state | Notes |
| --- | --- | --- | --- | --- |
| `E:\FlowMemory\flowmemory-main` | `release/windows-beginner-installer` | none listed | clean | Main checkout is not on `main`; use for status only unless assigned. |
| `E:\FlowMemory\flowchain-release` | `hq/full-l1-master-goals` | #98 merged | clean | Historical launcher branch; main contains its files. |
| `E:\FlowMemory\flowmemory-chain` | `agent/full-l1-runtime` | none yet | clean | Owns #99. |
| `E:\FlowMemory\flowmemory-crypto` | `agent/full-l1-crypto-wallet` | none yet | clean | Owns #100. |
| `E:\FlowMemory\flowmemory-indexer` | `agent/full-l1-control-plane` | #114 draft | dirty at latest status-report snapshot | Owns #101. |
| `E:\FlowMemory\flowmemory-dashboard` | `agent/full-l1-workbench` | #112 draft | dirty at latest status-report snapshot | Owns #102. |
| `E:\FlowMemory\flowmemory-contracts` | `agent/full-l1-contracts` | #110 draft | clean at last status-report snapshot; PR now open | Owns #103 and can support #104 contract pieces. |
| `E:\FlowMemory\flowmemory-bridge-full` | `agent/full-l1-bridge` | #113 draft | dirty at latest status-report snapshot | Owns #104. |
| `E:\FlowMemory\flowmemory-hardware` | `agent/full-l1-hardware` | none yet | clean | Owns #105. |
| `E:\FlowMemory\flowmemory-research` | `agent/full-l1-research-consensus` | none yet | clean | Owns #106. |
| `E:\FlowMemory\flowmemory-review` | `agent/full-l1-hq-integration` | this PR | clean before HQ edits | Owns #107 and #108 wrapper contract. |
| `E:\FlowMemory\flowmemory-bridge` | `agent/flowchain-base-bridge-poc` | none listed | dirty/untracked | Separate bridge POC worktree. Do not reuse for unrelated work; reconcile before assigning. |

## Integration Matrix

| Area | Implemented now | Running now | Remaining before full chain | Next prompt |
| --- | --- | --- | --- | --- |
| Chain | Deterministic no-value Rust devnet, demo, export/import, bounded wrappers | `flowchain:init`, `flowchain:start`, `flowchain:demo`, `flowchain:smoke` merged-surface path | Long-running node, signed tx intake, local balance/faucet records, multi-process smoke, native object lifecycle | `docs/agent-goals/full-l1/chain-runtime.md` |
| Crypto | Keccak V0 helpers, vectors, receipt/report/root helpers | `npm test --prefix crypto`, `npm run validate:vectors --prefix crypto` | Wallet/vault, signed envelopes, object IDs for full native lifecycle and bridge objects, negative vectors | `docs/agent-goals/full-l1/crypto-wallet.md` |
| Control plane | Local fixture-backed API, `/health`, `/state`, `/rpc`, smoke command | `npm run control-plane:serve`, `npm run control-plane:smoke` | Live node adapters, transaction submission, full lifecycle queries, bridge intake, no-secret response scans | `docs/agent-goals/full-l1/control-plane-indexer.md` |
| Dashboard | Existing Vite dashboard/workbench and fixture-backed views | `npm run workbench:dev`, dashboard build/test | Live API-backed local chain console, transaction/account/bridge/hardware views, second-computer status states | `docs/agent-goals/full-l1/dashboard-workbench.md` |
| Contracts | FlowPulse/registry surfaces and bridge POC foundation | `forge test`, `npm run contracts:hardening` | Harden BaseBridgeLockbox, settlement/event spine tests, dry-run deploy scripts, bridge event docs | `docs/agent-goals/full-l1/contracts-settlement.md` |
| Bridge | Test-only bridge POC docs, relayer package, mock command | `npm run bridge:mock`, `npm run bridge:test` | Base Sepolia observation command, BridgeCredit local runtime handoff, withdrawal intent, local-credit smoke | `docs/agent-goals/full-l1/bridge-relayer.md` |
| Hardware | FlowRouter POC simulator and seed fixture | Python simulator validation through current smoke | Operator signal fixtures for heartbeat, alerts, receipt relay, verifier digest, bridge alert, NFC metadata; optional API/workbench ingestion | `docs/agent-goals/full-l1/hardware-signals.md` |
| Research | Local-alpha and deployment-gate decisions exist | Docs only | Concrete consensus, transaction/state, storage, wallet, and bridge decision records for implementation | `docs/agent-goals/full-l1/research-consensus.md` |

## Merge Order

1. HQ #107 documentation, issue map, and temporary full-smoke wrapper.
2. Research #106 if builder agents need decisions before changing protocol
   behavior.
3. Chain #99 and crypto #100 in parallel if their envelope/object contracts are
   coordinated.
4. Control-plane #101 after the chain handoff shape and crypto object IDs are
   stable enough to query.
5. Contracts #103 and bridge #104 in parallel only after bridge event/object
   vocabulary is stable; bridge local-credit smoke depends on runtime/control
   plane intake.
6. Dashboard #102 after the control-plane API methods settle.
7. Hardware #105 after control-plane/dashboard labels for optional signals are
   stable.
8. Ops #108 finalizes `flowchain:full-smoke` after subsystem smoke commands
   exist and produce evidence.

If two PRs touch the same source-of-truth doc, merge the HQ/process PR first,
then rebase the subsystem PR and update only its evidence rows.

## Full Smoke Status

`npm run flowchain:full-smoke` now exists as the HQ wrapper contract. Until
issues #99 through #105 land their subsystem commands, it:

- runs the current merged-surface `flowchain:smoke` unless skipped;
- writes `devnet/local/smoke/flowchain-full-smoke-report.json`;
- reports missing command coverage with owning issue numbers;
- exits nonzero by default while the full private/local L1 lifecycle is
  incomplete;
- can be run with `-AllowIncomplete` only to validate the temporary wrapper.

Latest local evidence from this HQ pass:

| Command | Result | Evidence |
| --- | --- | --- |
| `npm run flowchain:smoke` | Passed after installing dashboard and crypto package dependencies | `devnet/local/smoke/flowchain-smoke-report.json` reported deterministic replay `true`, state root `0x75373cc47666ed9bcad605ce0f5d0aeb1bc8100a1087840d755205aef8a6bb50`, service/crypto/launch/devnet/dashboard/hardware/no-secret checks passed. |
| `npm run flowchain:full-smoke -- -SkipMergedSmoke -AllowIncomplete` | Passed as temporary blocker-report mode | `devnet/local/smoke/flowchain-full-smoke-report.json` reported `fullAcceptance: false` and missing command coverage for #99, #100, #104, and #105. |
| `git diff --check` | Passed | Only line-ending warnings were emitted by Git on this Windows checkout; no whitespace errors were reported. |

Required final promotion for #108:

- start or verify a long-running local node;
- create/unlock local test wallet;
- submit signed transactions and include them in blocks;
- query the control plane for every lifecycle object;
- build or verify the workbench;
- run bridge mock/local-credit smoke;
- validate optional hardware signal fixtures;
- export/import and compare deterministic roots;
- write a non-secret smoke report.

## Follow-Up Prompts

When an agent finishes early, assign the next smallest prompt in this order:

1. Chain: add the smallest transaction intake and one-node smoke that can feed
   control-plane state.
2. Crypto: ship object IDs and envelope validation before wallet UX polish.
3. Control plane: add no-secret response scanning as soon as live adapters are
   present.
4. Dashboard: add down/offline command guidance before adding submit actions.
5. Contracts: stabilize bridge event tests before Base Sepolia scripts.
6. Bridge: keep mock observation and local handoff green before any Base
   Sepolia read.
7. Hardware: deliver deterministic fixture shape before optional dashboard
   polish.
8. Research: land decision records that unblock currently active builder PRs
   first.
