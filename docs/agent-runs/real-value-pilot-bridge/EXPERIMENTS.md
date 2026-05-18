# Real-Value Pilot Bridge Relayer Experiments

## Planned Checks

| Check | Command | Result |
| --- | --- | --- |
| Bridge unit tests | `npm test --prefix services/bridge-relayer` | passed, 14 tests |
| Mock pilot E2E | `npm run pilot:e2e --prefix services/bridge-relayer` | passed |
| Root pilot bridge command | `npm run flowchain:real-value-pilot:bridge` | passed |
| Local credit smoke | `npm run bridge:local-credit:smoke` | passed |
| Product E2E | `npm run flowchain:product-e2e` | passed after default hardening made Slither optional; explicit Slither audit remains outside bridge scope |
| L1 E2E alias | `npm run flowchain:l1-e2e` | passed |
| HQ pilot gate, report-only | `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete` | passed as incomplete; only contracts #133 and runtime #134 remained missing |
| HQ pilot gate, strict | `npm run flowchain:real-value-pilot:e2e` | failed clearly as expected; only contracts #133 and runtime #134 remained missing |
| Diff whitespace | `git diff --check` | passed with line-ending warnings only |
| Unsafe-claim scan | `node infra/scripts/check-unsafe-claims.mjs` | passed |
| Live observer script syntax | `[scriptblock]::Create((Get-Content -Raw infra/scripts/bridge-base-mainnet-pilot-observe.ps1))` | passed |

## Negative Coverage

- Wrong chain ID must fail before log parsing.
- Base pilot mode must reject unapproved lockbox addresses.
- Base pilot mode must reject insufficient confirmation depth.
- Duplicate replay must produce explicit evidence and no second local
  application.
- Artifact secret scan must reject secret-shaped material.

## Product E2E

`npm run flowchain:product-e2e` now passes on current `main` after the merged
default/audit hardening split. Explicit Slither audit remains outside the
bridge-relayer scope.
