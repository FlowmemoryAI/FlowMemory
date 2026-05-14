# Capped Base 8453 Bridge Pilot Experiments

This file records runnable checks, commands, outcomes, and evidence paths.

| Time | Command | Outcome | Notes |
| --- | --- | --- | --- |
| 2026-05-14 | Initial setup | Passed | Tracking files created before implementation edits. |
| 2026-05-14 | `forge test --match-path tests/bridge/BaseBridgeLockbox.t.sol` | Passed | 16 lockbox tests. |
| 2026-05-14 | `forge test` | Passed | 85 Foundry tests. |
| 2026-05-14 | `npm test --prefix services/bridge-relayer` | Passed | 15 relayer tests. |
| 2026-05-14 | `npm run bridge:local-credit:smoke` | Passed | Regenerated local runtime handoff and withdrawal intent. |
| 2026-05-14 | `npm run bridge:pilot:mock:e2e` | Passed | Wrote observation, credit, replay, withdrawal, release, and local usage artifacts. |
| 2026-05-14 | `npm run bridge:pilot:live:check` | Passed | Self-test proved fail-closed live gates without live env values. |
| 2026-05-14 | `npm run bridge:deploy:dry-run` | Passed | Wrote missing-env-safe deploy readiness report. |
| 2026-05-14 | `npm run bridge:evidence:export` | Passed | Wrote secret-free evidence export report and zip; latest SHA256 `2D0C1CB36915E98B50EC2473B5CBA5166F49CC0777DB20526CC11BE17ADC92BE`. |
| 2026-05-14 | `npm run flowchain:real-value-pilot:e2e` | Passed | Full owner pilot gate passed with bridge, runtime, wallet, dashboard/control, ops, and baseline checks. |
| 2026-05-14 | `node infra/scripts/check-unsafe-claims.mjs` | Passed | Docs/contracts contain no unsafe launch claims. |
| 2026-05-14 | `git diff --check` | Passed | No whitespace errors. |
