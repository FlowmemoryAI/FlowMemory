# Capped Base 8453 Bridge Pilot Experiments

This file records runnable checks, commands, outcomes, and evidence paths.

| Time | Command | Outcome | Notes |
| --- | --- | --- | --- |
| 2026-05-14 | Initial setup | Passed | Tracking files created before implementation edits. |
| 2026-05-14 | `forge test --match-path tests/bridge/BaseBridgeLockbox.t.sol` | Passed | 16 lockbox tests. |
| 2026-05-14 | `forge test` | Passed | 85 Foundry tests. |
| 2026-05-14 | `npm test --prefix services/bridge-relayer` | Passed | 19 relayer tests. |
| 2026-05-14 | `npm run flowchain:bridge:local-credit:smoke` | Passed | Regenerated local runtime handoff and withdrawal intent. |
| 2026-05-14 | `npm run flowchain:real-value-pilot:bridge` | Passed | Wrote exact-value, observation, credit, replay, withdrawal, release, and local usage artifacts. |
| 2026-05-14 | `npm run flowchain:bridge:live:check` | Blocked as expected without owner env | Proved fail-closed live gates without printing env values. |
| 2026-05-14 | `npm run flowchain:bridge:deploy:base8453` | Blocked as expected without owner env | Wrote missing-env-safe deploy readiness report. |
| 2026-05-14 | `npm run flowchain:bridge:evidence:export` | Passed | Wrote secret-free evidence export report and zip. |
| 2026-05-14 | `npm run flowchain:real-value-pilot:e2e` | Passed | Full owner pilot gate passed with bridge, runtime, wallet, dashboard/control, ops, and baseline checks. |
| 2026-05-14 | `node infra/scripts/check-unsafe-claims.mjs` | Passed | Docs/contracts contain no unsafe launch claims. |
| 2026-05-14 | `git diff --check` | Passed | No whitespace errors. |
