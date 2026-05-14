# Real-Value Pilot HQ Checklist

Status: active.

Last updated: 2026-05-14.

## Acceptance

- [x] Read required source-of-truth docs before editing.
- [x] Confirm current `origin/main` before editing.
- [x] Inspect requested active worktrees for reusable work.
- [x] Check GitHub PR and issue source-of-truth state.
- [x] Create `docs/FLOWCHAIN_REAL_VALUE_PILOT.md`.
- [x] Add `npm run flowchain:real-value-pilot:e2e`.
- [x] Make the pilot gate fail clearly until subsystem proof commands exist.
- [x] Create an integration matrix mapping required proofs to owner and command.
- [x] Create a pilot go/no-go checklist for the project owner.
- [x] Keep public-readiness claims out of the docs.
- [x] Run `node infra/scripts/check-unsafe-claims.mjs`.
- [x] Run `git diff --check`.
- [x] Run the new pilot gate in incomplete mode.
- [x] Run `npm run flowchain:product-e2e`, or document why it was not practical.
- [x] Open a draft PR with exact commands run and current blockers.

## Gate Blocker Rows

- [ ] Contracts: chain ID `8453`, lockbox config, caps, allowlist, pause,
  release/recovery, replay protections, dry-run deploy, and source instructions.
- [ ] Bridge relayer: Base observation, confirmation depth, deterministic credit,
  duplicate handling, local handoff, withdrawal/release evidence.
- [ ] Runtime: apply pilot credit exactly once, receipt lookup, restart,
  export/import, deterministic roots.
- [ ] Wallet/operator: no-secret config, pilot message signing, negative vectors,
  public metadata export, next-command UX.
- [ ] Control plane/dashboard: pilot API, redaction, owner labels, live/degraded
  state, next operator commands, browser no-secret boundary.
- [ ] Ops/installer: env validation, tiny cap checks, explicit owner ack,
  emergency stop, evidence export, restart recovery, troubleshooting.

These remain unchecked because they are not merged into `main` as dedicated
root proof commands. Current live worktree evidence is recorded in `PLAN.md`
and `NOTES.md`.

## Owner Go/No-Go

- [ ] `npm run flowchain:product-e2e` passes on `main`.
- [ ] `npm run flowchain:l1-e2e` passes on `main`.
- [ ] `npm run flowchain:real-value-pilot:e2e` passes without
  `-AllowIncomplete`.
- [ ] Pilot report has empty `missingProofs`.
- [ ] No committed files, reports, exports, API payloads, or dashboard surfaces
  contain private keys, seed phrases, mnemonics, RPC credentials, API keys, or
  webhooks.
- [ ] Owner has reviewed caps, stop/recovery path, and exact commands.

## Baseline Check Result

`npm run flowchain:product-e2e` was run after dependency installation. It failed
inside `npm run contracts:hardening` because local Slither reported existing
findings in `contracts/bridge/BaseBridgeLockbox.sol`.

Owner: contracts / static-analysis policy.

Next action: contracts owner should either address the Slither findings or
update the accepted static-analysis policy in a contracts-scoped PR. This HQ
branch does not edit `contracts/`.

Draft PR: https://github.com/FlowmemoryAI/FlowMemory/pull/132

## Completion Audit

Audit file: `docs/agent-runs/real-value-pilot-hq/COMPLETION_AUDIT.md`.

Result: not complete. `origin/main` lacks both new scripts, the default pilot
gate fails with the intended missing-proof report, and local `flowchain:l1-e2e`
currently fails in `contracts:hardening` under local Slither.
