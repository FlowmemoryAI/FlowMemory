# Real-Value Pilot HQ Notes

Status: active notes.

Last updated: 2026-05-14.

## Source-Of-Truth Notes

- GitHub is ahead of several local docs: issues #99, #100, #101, #102, #108,
  and #78 are closed, while some local docs still describe earlier open-state
  assumptions.
- Draft PR #129 is prompt/launcher-only for real-value pilot agents. It is
  useful context, not merged source of truth.
- Issue #130 is the active gate issue for defining release boundaries before
  public-network pilot work.
- PR #132 now expands `docs/FLOWCHAIN_REAL_VALUE_PILOT.md` with the issue #130
  release-gate boundary for observer reads, deposits, release/recovery, local
  credit application, dashboard display, and explicitly out-of-scope public
  readiness claims.
- Missing subsystem proof commands are now tracked by GitHub issues #133
  through #138.
- Issue #131 is the active contracts/static-analysis issue for reconciling
  local Slither findings that block product and L1 E2E evidence.
- PR #132 now includes an allowed `infra/scripts/` fix for #131: the default
  hardening path skips Slither unless the explicit audit gate is requested.

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
- Bridge branch `agent/real-value-pilot-bridge` contains Base `8453` observer
  and mock pilot E2E work, but its run checklist still records the key proof
  commands as pending.
- Chain branch `agent/real-value-pilot-chain` has runtime bridge-credit work in
  progress. Baseline cargo test passed before edits; current pilot experiments
  are not recorded as complete.
- Wallet branch `agent/real-value-pilot-wallet` contains pilot signing,
  validation, schemas, and operator-doc work, with test rows still pending in
  its checklist.
- Control-dashboard branch `agent/real-value-pilot-control-dashboard` contains
  pilot API and dashboard work plus a service-local E2E, but its checklist still
  marks implementation and verification rows incomplete.
- Ops branch `agent/real-value-pilot-ops` contains the most complete root
  wrapper/runbook path, including emergency stop and sanitized export. Its
  product E2E result depends on an ops-side static-analysis wrapper change that
  is not present in this HQ PR.

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
- GitHub issue #131 remains open until this static-analysis policy update is
  reviewed and merged; the explicit Slither audit gate still owns the native
  release findings.
- Draft PR opened: https://github.com/FlowmemoryAI/FlowMemory/pull/132.
- Completion audit result: not complete. PR #132 is not merged, `origin/main`
  lacks both new scripts, and the default pilot gate fails with missing
  subsystem proofs.
