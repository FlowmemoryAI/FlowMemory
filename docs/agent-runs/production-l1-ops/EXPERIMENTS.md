# Private/Local Ops Wrapper Experiments

This file records commands run while building the `flowchain:production-l1:e2e` ops wrapper. The wrapper is a private/local gate and does not claim production readiness.

| Time | Command | Result | Notes |
| --- | --- | --- | --- |
| 2026-05-14 | `npm install`; `npm install --prefix apps/dashboard`; `npm install --prefix crypto` | passed | Installed local dependencies needed for strict smoke and dashboard build. |
| 2026-05-14 | PowerShell parser checks for changed scripts | passed | Parser checked new/changed ops scripts. |
| 2026-05-14 | `npm run flowchain:wallet:transfer:e2e` | passed | Local test-unit transfer recorded in devnet state. |
| 2026-05-14 | `npm run flowchain:dex:e2e` | passed | Product smoke proved token and DEX records. |
| 2026-05-14 | `npm run flowchain:production-l1:e2e` | passed with live blockers | Mock path passed; live Base pilot blocked on env and missing proof commands. |
| 2026-05-14 | `npm run flowchain:l1-e2e` | passed | Explicit compatibility alias verification. |
| 2026-05-14 | `npm run flowchain:real-value-pilot:e2e` | incomplete | Strict live pilot gate blocked by missing contracts, bridge, and runtime proof commands. |
| 2026-05-14 | `node infra/scripts/check-unsafe-claims.mjs` | passed | Claim scan clean. |
| 2026-05-14 | `git diff --check` | passed | Whitespace check clean. |
