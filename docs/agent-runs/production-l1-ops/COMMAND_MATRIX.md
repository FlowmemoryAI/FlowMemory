# Command Matrix

Boundary: `flowchain:production-l1:e2e` is a private/local ops wrapper command. It does not claim production readiness or live-funds readiness.

| Command | Owner | Subsystem | Latest status | Evidence |
| --- | --- | --- | --- | --- |
| `npm run flowchain:prereq` | installer | install/prereq | passed | final report step `Prerequisite check` |
| `npm run flowchain:doctor` | ops | install/config/status | passed | `devnet/local/doctor/flowchain-doctor-report.json` |
| `npm run flowchain:init` | runtime/storage | local state | passed | final report step `Initialize local state` |
| `npm run flowchain:second-computer:bundle` | ops | offline bundle | command exists | `infra/scripts/flowchain-second-computer-bundle.ps1` |
| `npm run flowchain:second-computer:verify` | ops | second computer | command exists | `infra/scripts/flowchain-second-computer-verify.ps1` |
| `npm run flowchain:node:start` | runtime | node lifecycle | passed in bounded mode | final report step `Node start bounded` |
| `npm run flowchain:node:stop` | runtime | node lifecycle | command exists | existing stop wrapper |
| `npm run flowchain:node:status` | runtime | node lifecycle | passed | final report step `Node status` |
| `npm run flowchain:node:restart` | runtime | node lifecycle | command exists | `infra/scripts/flowchain-node-restart.ps1` |
| `npm run flowchain:node:logs` | runtime/ops | observability | command exists | `infra/scripts/flowchain-node-logs.ps1` |
| `npm run flowchain:wallet:e2e` | wallet/crypto | wallet | passed | `devnet/local/production-l1-e2e/wallet-e2e-report.json` |
| `npm run flowchain:wallet:transfer:e2e` | wallet/runtime | transfer | passed | `devnet/local/production-l1-e2e/wallet-transfer/wallet-transfer-e2e-report.json` |
| `npm run flowchain:product:e2e` | runtime/product | product flow | passed with `-SkipFullSmoke` after baseline | `devnet/local/product-e2e/flowchain-product-e2e-report.json` |
| `npm run flowchain:dex:e2e` | runtime/token-dex | token/DEX | passed | `devnet/local/production-l1-e2e/dex/dex-e2e-report.json` |
| `npm run flowchain:bridge:mock:e2e` | bridge-relayer | mock bridge | passed | final report step `Bridge mock pilot E2E` |
| `npm run flowchain:bridge:live:check` | bridge/ops | Base 8453 readiness | blocked on env | `devnet/local/production-l1-e2e/bridge-live-readiness-report.json` |
| `npm run flowchain:bridge:evidence:export` | ops/security | evidence | passed through emergency alias | `devnet/local/production-l1-e2e/evidence/flowchain-production-l1-evidence-export-report.json` |
| `npm run flowchain:bridge:emergency-stop` | bridge/ops | emergency | command exists | guarded pause wrapper |
| `npm run flowchain:control-plane:smoke` | control-plane | RPC/API | passed | final report step `Control-plane smoke` |
| `npm run flowchain:dashboard:build` | dashboard | workbench | passed | final report step `Dashboard build` |
| `npm run flowchain:dashboard:verify` | dashboard | workbench | command exists | build-backed verification |
| `npm run flowchain:export` | storage | backup/export | passed | final report step `Export local state` |
| `npm run flowchain:import` | storage | restore/import | passed | final report step `Import local state` |
| `npm run flowchain:restart:verify` | runtime/storage | restart recovery | passed | `devnet/local/node-smoke/one-node-smoke-report.json` |
| `npm run flowchain:l1:e2e` | integration | full local gate | passed | `devnet/local/full-smoke/flowchain-full-smoke-report.json` |
| `npm run flowchain:l1-e2e` | integration | compatibility alias | passed | explicit verification run passed |
| `npm run flowchain:real-value-pilot:e2e` | HQ/ops + subsystem owners | live pilot proof | incomplete by design | missing contracts, bridge-relayer, and runtime proof commands |
| `npm run flowchain:production-l1:e2e` | ops | final wrapper | passed with live blockers | `devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json` |
| `npm run flowchain:no-secret:scan` | security | secret hygiene | passed | `devnet/local/production-l1-e2e/no-secret-scan-report.json` |
| `npm run flowchain:emergency:stop-local` | ops | emergency | command exists | stop-node plus port stop plan |
| `npm run flowchain:emergency:pause-bridge` | bridge/ops | emergency | command exists | guarded Base 8453 pause wrapper |
| `npm run flowchain:emergency:export-evidence` | ops/security | emergency/evidence | passed | evidence export report |
| `npm run flowchain:emergency:print-recovery` | ops | emergency/recovery | command exists | recovery report script |

Missing strict live-pilot proof commands:

- `flowchain:real-value-pilot:contracts`, owner `contracts`, reason: chain ID, lockbox, caps, pause, release/recovery, and replay proof; GitHub issue #133.
- `flowchain:real-value-pilot:bridge`, owner `bridge-relayer`, reason: Base observation, deterministic credit, duplicate handling, and withdrawal/release evidence; GitHub issue #138.
- `flowchain:real-value-pilot:runtime`, owner `chain-runtime`, reason: credit-once, restart, export/import preservation; GitHub issue #134.

