# Real-Value Pilot HQ Plan

Status: active HQ coordination pass.

Last updated: 2026-05-14.

## Assignment

Worktree: `E:\FlowMemory\flowmemory-live-hq`

Branch: `agent/real-value-pilot-hq`

Goal: coordinate the capped real-value pilot until
`npm run flowchain:real-value-pilot:e2e` exists and passes on `main`, together
with `npm run flowchain:l1-e2e`.

## Scope

Allowed folders:

- `docs/`
- `infra/scripts/`
- `package.json`
- `.github/`
- `README.md`

Forbidden folders:

- `crates/`
- `contracts/`
- `services/`
- `crypto/`
- `apps/dashboard/`
- `hardware/`

This pass is HQ coordination and gate scaffolding only. It does not implement
contract, relayer, runtime, wallet, control-plane, dashboard, or hardware
behavior.

## Source-Of-Truth Read

Read before edits:

- `docs/START_HERE.md`
- `docs/FLOWMEMORY_HQ_CONTEXT.md`
- `docs/CURRENT_STATE.md`
- `docs/ROOTFLOW_V0.md`
- `docs/FLOW_MEMORY_V0.md`
- `docs/V0_LAUNCH_ACCEPTANCE.md`
- `docs/ISSUE_BACKLOG.md`
- `docs/PR_PROCESS.md`
- `docs/AGENT_PROMPTS.md`
- `docs/DAILY_HQ_RUNBOOK.md`
- `docs/FLOWCHAIN_FULL_PRIVATE_TESTNET.md`
- `docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md`
- `docs/FLOWCHAIN_AGENT_INTEGRATION_MAP.md`
- `docs/FLOWCHAIN_SECOND_COMPUTER_SETUP.md`
- `docs/FLOWCHAIN_HQ_INTEGRATION_STATUS.md`

Current `origin/main` was checked before edits:

```text
9b025c5 Include HQ review in L1 long-loop launcher (#128)
```

GitHub source-of-truth state checked before edits:

- Draft PR #129: real-value pilot goal pack, CI passing, draft.
- Issue #130: required release gates before public-network pilot work.
- Open draft PRs #110, #112 through #117, #111, #129, #73, and #71.
- Issues #99, #100, #101, #102, #108, and #78 are closed on GitHub even where
  local docs may still mention earlier open state.

## Worktree Inspection Summary

| Worktree | Branch | Reusable work | HQ action |
| --- | --- | --- | --- |
| `E:\FlowMemory\flowmemory-chain` | `agent/l1-loop-chain-network` | Runtime and product E2E changes in `crates/` and `infra/scripts/flowchain-product-e2e.ps1`. | Record as runtime context only; do not edit or copy product code in this HQ pass. |
| `E:\FlowMemory\flowmemory-bridge-full` | `agent/l1-loop-bridge-testnet` | Bridge relayer testnet E2E draft and bridge local-credit work. | Map bridge proof to a future dedicated `flowchain:real-value-pilot:bridge` command. |
| `E:\FlowMemory\flowmemory-contracts` | `agent/l1-loop-contracts-settlement` | Settlement spine and lockbox hardening. | Map contract proof to a future dedicated `flowchain:real-value-pilot:contracts` command. |
| `E:\FlowMemory\flowmemory-crypto` | `agent/l1-loop-wallet-crypto` | Wallet/envelope validation and local transaction vectors. | Map wallet proof to a future dedicated `flowchain:real-value-pilot:wallet` command. |
| `E:\FlowMemory\flowmemory-indexer` | `agent/l1-loop-control-plane-explorer` | Expanded control-plane methods and explorer E2E draft. | Map API proof to a future dedicated `flowchain:real-value-pilot:control-dashboard` command. |
| `E:\FlowMemory\flowmemory-dashboard` | `agent/l1-loop-dashboard-workbench` | Workbench live console work and product-state data. | Map owner-view proof to the control-dashboard command. |
| `E:\FlowMemory\flowmemory-review` | `agent/l1-loop-installer-ops` | Fuller `flowchain:l1-e2e` wrapper and installer docs. | Reuse the command/report pattern, but keep this PR scoped to the pilot gate. |
| `E:\FlowMemory\flowmemory-hq-review-loop` | `agent/l1-loop-hq-review` | HQ review docs and `flowchain:l1-e2e` alias to full-smoke. | Reuse the baseline alias idea while documenting that a dedicated wrapper can replace it. |
| `E:\FlowMemory\flowchain-release` | `hq/real-value-pilot-goals` | Draft PR #129 goal prompts and launcher. | Treat as prompt source only; source of truth remains GitHub PR #129 until merged. |

## Live Pilot Worktree Snapshot

These branches contain the current real-value pilot implementation attempts.
They are useful coordination evidence only. The final gate still requires merged
root commands on `main`.

| Worktree | Branch | Current evidence | HQ state |
| --- | --- | --- | --- |
| `E:\FlowMemory\flowmemory-live-contracts` | `agent/real-value-pilot-contracts` | Checklist reports `forge test`, `npm run contracts:hardening`, deploy dry-run, and `npm run flowchain:product-e2e` passing after dependency install. Work is in `contracts/`, `script/`, and tests. | Useful contracts proof candidate; no dedicated root `flowchain:real-value-pilot:contracts` command exists on HQ/main yet. |
| `E:\FlowMemory\flowmemory-live-bridge` | `agent/real-value-pilot-bridge` | Adds bridge relayer pilot observer files, Base `8453` script, mock E2E code, and a branch-local `flowchain:real-value-pilot:e2e` script. Checklist still has implementation and verification rows unchecked. | Bridge proof remains in progress and unmerged. |
| `E:\FlowMemory\flowmemory-live-chain` | `agent/real-value-pilot-chain` | Runtime model/CLI/tests show pilot bridge-credit work in progress. Baseline cargo test passed before edits; current experiments are still pending. | Runtime proof remains in progress and unmerged. |
| `E:\FlowMemory\flowmemory-live-wallet` | `agent/real-value-pilot-wallet` | Adds pilot schemas, wallet/operator docs, and signing/validation code. Checklist still has implementation and test rows unchecked. | Wallet proof remains in progress and unmerged. |
| `E:\FlowMemory\flowmemory-live-control-dashboard` | `agent/real-value-pilot-control-dashboard` | Adds pilot control-plane API/dashboard files and a service-local `real-value-pilot:e2e` script. Checklist still shows API/dashboard/test rows unchecked. | Control-dashboard proof remains in progress and unmerged. |
| `E:\FlowMemory\flowmemory-live-ops` | `agent/real-value-pilot-ops` | Adds pilot ops/runbook scripts, emergency stop, sanitized export, and branch-local root `flowchain:real-value-pilot:e2e`; checklist reports unsafe-claims, diff check, and product E2E passing after an ops-side static-analysis wrapper change. | Ops proof candidate exists branch-locally, but it is not merged into HQ/main. |

## Implementation Plan

1. Create `docs/FLOWCHAIN_REAL_VALUE_PILOT.md` with the capped owner-pilot
   boundary, integration matrix, final gate contract, and owner go/no-go list.
2. Add `infra/scripts/flowchain-real-value-pilot-e2e.ps1` as a report-first
   final pilot gate.
3. Add root package scripts for `flowchain:l1-e2e` and
   `flowchain:real-value-pilot:e2e`.
4. Keep the gate failing by default until dedicated contracts, bridge relayer,
   runtime, wallet/operator, control-plane/dashboard, and ops commands exist.
5. Run the requested checks and record exact results in `EXPERIMENTS.md`.
6. Open a draft PR with exact commands run and current blockers.

## Initial Blockers

- No dedicated real-value pilot contracts command exists.
- No dedicated real-value pilot bridge relayer command exists.
- No dedicated real-value pilot runtime command exists.
- No dedicated real-value pilot wallet/operator command exists.
- No dedicated real-value pilot control-plane/dashboard command exists.
- No dedicated real-value pilot ops/installer command exists.
- Issue #130 must define the accepted release-gate boundary before the owner
  pilot can move beyond capped validation.
