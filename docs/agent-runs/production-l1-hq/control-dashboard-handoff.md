# Control Dashboard Pilot Handoff

Generated: 2026-05-14

## Scope

Focused ownership was control-plane/dashboard pilot readiness API and strict pilot gate blockers.

## Changes

- Hardened control-plane fixture loading so malformed active JSON or partial NDJSON is marked degraded and skipped instead of crashing the API or dashboard smoke.
- Made bridge live readiness fail closed when the active local devnet source is degraded.
- Updated control-plane tests to assert the intended bridge readiness, lifecycle, wallet balance, and transfer API surface instead of stale response counts.
- Exposed replay key, withdrawal intent, release evidence, and exact amount equality fields in bridge lifecycle records and dashboard workbench records.

## Checks Run

- `npm test --prefix services/control-plane` passed.
- `npm test --prefix apps/dashboard` passed.
- `npm run typecheck --prefix apps/dashboard` passed.
- `npm run flowchain:real-value-pilot:control-dashboard` passed.
- `npm run flowchain:control-plane:smoke` passed with 70 responses.
- `npm run flowchain:real-value-pilot:e2e` failed outside this ownership area in `services/bridge-relayer` schema validation.

## Remaining Blocker

`npm run flowchain:real-value-pilot:e2e` still fails during `flowchain:product-e2e` because bridge-relayer tests emit a bridge withdrawal intent object with an `asset` property that `bridge-withdrawal-intent.schema.json` rejects as an additional property. The failing area is outside this task's allowed write set.

## Evidence Note

The requested `devnet/local/production-l1-real-funds-readiness/command-logs` directory was not present in this checkout at handoff time. The gap-loop `failing-status.json` and current focused command outputs were used for this handoff.
