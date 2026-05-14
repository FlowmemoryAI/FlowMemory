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
- [x] Open a PR with exact commands run and current blockers.
- [x] Merge the HQ gate PR to `main`.
- [x] Post HQ refresh comments on subsystem issues #133 through #138.

## Gate Blocker Rows

- [ ] Contracts (#133): chain ID `8453`, lockbox config, caps, allowlist, pause,
  release/recovery, replay protections, dry-run deploy, and source instructions.
- [ ] Bridge relayer (#138): Base observation, confirmation depth, deterministic credit,
  duplicate handling, local handoff, withdrawal/release evidence.
- [ ] Runtime (#134): apply pilot credit exactly once, receipt lookup, restart,
  export/import, deterministic roots.
- [ ] Wallet/operator (#136): no-secret config, pilot message signing, negative vectors,
  public metadata export, next-command UX.
- [ ] Control plane/dashboard (#137): pilot API, redaction, owner labels, live/degraded
  state, next operator commands, browser no-secret boundary.
- [ ] Ops/installer (#135): env validation, tiny cap checks, explicit owner ack,
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

## Release-Gate Boundary

- [x] `main` documents issue #130 capped owner-pilot boundary in
  `docs/FLOWCHAIN_REAL_VALUE_PILOT.md`.
- [x] Issue #130 boundary is reviewed and accepted on GitHub.

## Baseline Check Result

`npm run flowchain:product-e2e` initially failed inside
`npm run contracts:hardening` because local Slither reported existing findings
in `contracts/bridge/BaseBridgeLockbox.sol`.

PR #132 updated the allowed `infra/scripts/` static-analysis wrappers
so default `contracts:hardening` matches the documented policy: Slither is
optional by default and required only through `contracts:hardening:slither`,
`-RequireSlither`, or `REQUIRE_SLITHER=1`.

Post-merge main-equivalent result: `npm run contracts:hardening`,
`npm run flowchain:product-e2e`, and `npm run flowchain:l1-e2e` pass locally.

Closed GitHub blocker: https://github.com/FlowmemoryAI/FlowMemory/issues/131

Merged PR: https://github.com/FlowmemoryAI/FlowMemory/pull/132

## Completion Audit

Audit file: `docs/agent-runs/real-value-pilot-hq/COMPLETION_AUDIT.md`.

Result: not complete. `origin/main` contains the HQ scripts and
`flowchain:l1-e2e` passes locally, but the default pilot gate still fails with
the intended missing-proof report until the six dedicated subsystem proof
commands land on `main`.
