# Gated L1 HQ Evidence

Date: 2026-05-14

Current classification: `EXTERNAL-BLOCKED ONLY`.

All code-controlled local/mock production L1 gates passed. The live Base 8453
bridge readiness gate fails closed only because owner-supplied inputs are
absent. No Base transaction was broadcast.

## Final Command Results

| Command | Result |
| --- | --- |
| `powershell -NoProfile -ExecutionPolicy Bypass -File E:\FlowMemory\agent-dispatch\generated\production-l1-complete\audit-production-l1-readiness.ps1 -RepoRoot E:\FlowMemory\flowmemory-prod-hq` | passed; exit 0; `BlockingIssueCount=0`; audit `production-l1-readiness-audit-20260514-111620.json` |
| `npm run flowchain:production-l1:e2e` | passed; exit 0; final aggregate status `passed-with-live-blockers`; report timestamp `2026-05-14T16:23:45.5784606Z` |
| `npm run flowchain:real-value-pilot:e2e` | passed; exit 0; report status `passed`; generated `2026-05-14T16:18:47.3193401Z`; `AllowIncomplete=false`; `SkipBaseline=false` |
| `npm run flowchain:no-secret:scan` | passed; exit 0; report generated `2026-05-14T16:24:08.6005410Z`; scanned 288 files; findings 0 |
| `npm run flowchain:bridge:live:check` | failed closed; exit 1; report status `blocked`; generated `2026-05-14T16:24:12.4188670Z`; missing owner env only; `broadcasts=false`; `printsEnvValues=false`; `noSecrets=true` |
| `git diff --check` | passed; exit 0 |

Aggregate production L1 subsystem evidence is under:

`devnet/local/production-l1-e2e/logs/`

## Machine Reports

| Report | Result |
| --- | --- |
| `devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json` | `passed-with-live-blockers`; local/mock gates passed; live-readiness blockers are owner env only |
| `devnet/local/production-l1-e2e/bridge-live-readiness-report.json` | `blocked`; missing owner env only; `broadcasts=false`; `printsEnvValues=false`; `noSecrets=true` |
| `devnet/local/bridge-live-readiness/bridge-live-readiness-report.json` | direct live-readiness report from the explicit command; `blocked` on the same owner env values only |
| `devnet/local/production-l1-e2e/no-secret-scan-report.json` | `passed`; scanned 288 files; findings 0 |
| `devnet/local/production-l1-e2e/export-import-root-compare.json` | `passed`; original, exported, and imported roots match |
| `devnet/local/production-l1-e2e/real-value-pilot-coordination/flowchain-real-value-pilot-e2e-report.json` | aggregate coordination report `passed`; `AllowIncomplete=true`; `SkipBaseline=true` |
| `devnet/local/real-value-pilot/flowchain-real-value-pilot-e2e-report.json` | standalone explicit gate report `passed`; `AllowIncomplete=false`; `SkipBaseline=false` |
| `devnet/local/production-l1-e2e/evidence/flowchain-production-l1-evidence-export-report.json` | `passed`; bundle SHA256 `982354B0BFB0DD77243C6C7869B4F6A22391FA01813CFCA106E70096B23BA728` |

Root compare:

- original state root: `0x149b8017ed2be0fb192c295383d2a198798a24e8509978c678fe78205ca8ee58`
- exported state root: `0x149b8017ed2be0fb192c295383d2a198798a24e8509978c678fe78205ca8ee58`
- imported state root: `0x149b8017ed2be0fb192c295383d2a198798a24e8509978c678fe78205ca8ee58`

## External Blocker

Direct `npm run flowchain:bridge:live:check` failed closed because these owner
inputs were absent:

- `FLOWCHAIN_PILOT_OPERATOR_ACK`
- `FLOWCHAIN_BASE8453_RPC_URL`
- `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`
- `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`
- `FLOWCHAIN_BASE8453_ASSET_DECIMALS`
- `FLOWCHAIN_BASE8453_FROM_BLOCK`
- `FLOWCHAIN_BASE8453_TO_BLOCK`
- `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`
- `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`
- `FLOWCHAIN_PILOT_CONFIRMATIONS`

No Base transaction was broadcast.
