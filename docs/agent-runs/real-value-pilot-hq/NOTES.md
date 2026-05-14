# Real-Value Pilot HQ Notes

Status: active notes.

Last updated: 2026-05-14.

## Source-Of-Truth Notes

- GitHub is ahead of several local docs: issues #99, #100, #101, #102, #108,
  and #78 are closed, while some local docs still describe earlier open-state
  assumptions.
- Draft PR #129 is prompt/launcher-only for real-value pilot agents. It is
  useful context, not merged source of truth.
- Issue #130 is closed. PR #132 merged the release-gate boundary for observer
  reads, deposits, release/recovery, local credit application, dashboard
  display, and explicitly out-of-scope public-readiness claims.
- Missing subsystem proof commands are now tracked by GitHub issues #133
  through #138.
- Issue #131 is closed. PR #132 merged the allowed `infra/scripts/` policy fix:
  default hardening skips Slither unless the explicit audit gate is requested.
- HQ refresh comments are posted on issues #133 through #138 with each local
  worktree's current proof evidence and next integration action.

## Reusable Work

- `flowmemory-review` has a fuller `flowchain:l1-e2e` script. This HQ pass only
  adds the current baseline alias and leaves the richer wrapper to the ops
  branch or a later merge.
- `flowmemory-hq-review-loop` already uses a `flowchain:l1-e2e` alias to
  `flowchain:full-smoke`; this pass reuses that simple baseline pattern.
- `flowchain-product-e2e.ps1` provides the missing-coverage report style reused
  for the pilot gate.
- The real-value goal pack in PR #129 names the same owner proof areas used in
  `docs/FLOWCHAIN_REAL_VALUE_PILOT.md`.

## Live Pilot Branch Notes

- Contracts branch `agent/real-value-pilot-contracts` reports passing contract
  tests, hardening, deploy dry-run, and product E2E. It remains unmerged and has
  no dedicated root pilot proof command on `main`.
- Bridge branch `agent/real-value-pilot-bridge` checklist now reports the
  observer, replay, local-credit, withdrawal/release, negative, smoke, and
  product E2E proof rows complete. It remains unmerged and lacks the dedicated
  root `flowchain:real-value-pilot:bridge` command on `main`.
- Chain branch `agent/real-value-pilot-chain` checklist reports the direct
  runtime wrapper proof complete for credit-once, replay, receipt lookup,
  restart, and export/import roots. It still needs the root
  `flowchain:real-value-pilot:runtime` package script and a clean product E2E
  rerun after dependency setup.
- Wallet branch `agent/real-value-pilot-wallet` checklist reports pilot
  schemas, validation, signing, negative cases, scans, and product evidence
  complete. It remains unmerged and lacks the dedicated root
  `flowchain:real-value-pilot:wallet` command on `main`.
- Control-dashboard branch `agent/real-value-pilot-control-dashboard` checklist
  reports API/dashboard tests, build, smoke, and branch-local
  `flowchain:real-value-pilot:control-dashboard` complete. It remains unmerged.
- Ops branch `agent/real-value-pilot-ops` contains the most complete root
  wrapper/runbook path, including emergency stop and sanitized export. Its
  checklist reports product E2E complete, but the dedicated root
  `flowchain:real-value-pilot:ops` alias expected by the HQ gate is still
  missing on `main`.

## Boundaries

- This branch does not touch `crates/`, `contracts/`, `services/`, `crypto/`,
  `apps/dashboard/`, or `hardware/`.
- The pilot gate is expected to fail without `-AllowIncomplete` until subsystem
  agents add their dedicated proof commands.
- Public launch, open-validator readiness, tokenomics, broad bridge readiness,
  custody, and formal crypto-review claims remain blocked.

## Verification Notes

- `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete` passed as a
  coordination report and listed the six missing dedicated subsystem proof
  commands.
- `npm run flowchain:product-e2e` initially failed locally after dependencies
  were installed because default `contracts:hardening` ran Slither whenever it
  was present.
- After updating `infra/scripts/contracts-static-analysis.ps1` and
  `infra/scripts/contracts-static-analysis.sh`, default `contracts:hardening`,
  `npm run flowchain:product-e2e`, and `npm run flowchain:l1-e2e` pass locally.
- The explicit Slither audit gate still owns the native release findings.
- PR #132 merged: https://github.com/FlowmemoryAI/FlowMemory/pull/132.
- Post-merge local main-equivalent verification passed
  `npm run flowchain:product-e2e`, `npm run flowchain:l1-e2e`,
  `git diff --check`, and `node infra/scripts/check-unsafe-claims.mjs`.
- Completion audit result: not complete. The default pilot gate exists on
  `main`, but still fails with missing dedicated subsystem proof commands.
