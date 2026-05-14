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
- `npm run flowchain:product-e2e` did not pass locally after dependencies were
  installed. It failed in `contracts:hardening` because local Slither reported
  existing findings in `contracts/bridge/BaseBridgeLockbox.sol`.
- The product E2E failure is not caused by the HQ docs/script changes in this
  branch; the next action belongs to the contracts/static-analysis owner.
- Draft PR opened: https://github.com/FlowmemoryAI/FlowMemory/pull/132.
- Completion audit result: not complete. PR #132 is not merged, `origin/main`
  lacks both new scripts, the default pilot gate fails with missing subsystem
  proofs, and local `flowchain:l1-e2e` fails under local Slither.
