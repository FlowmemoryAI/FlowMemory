# FlowChain Gated L1 Go/No-Go

Date: 2026-05-14

Status: `EXTERNAL-BLOCKED ONLY`.

## Decision

The branch is runnable for the private/local production L1 path. The final
aggregate production L1 gate completed as `passed-with-live-blockers`: every
code-controlled local/mock subsystem passed, and the only remaining live
readiness blocker is missing owner-supplied Base 8453 pilot inputs.

No Base transaction was broadcast. The live gate fails closed until the owner
supplies the required RPC, lockbox, bounded block range, caps, confirmation
depth, and explicit acknowledgement in a local shell.

## Latest Evidence

| Command | Result |
| --- | --- |
| `powershell -NoProfile -ExecutionPolicy Bypass -File E:\FlowMemory\agent-dispatch\generated\production-l1-complete\audit-production-l1-readiness.ps1 -RepoRoot E:\FlowMemory\flowmemory-prod-hq` | passed, exit 0; `BlockingIssueCount=0`; audit `E:\FlowMemory\agent-dispatch\generated\production-l1-complete\audit\production-l1-readiness-audit-20260514-111620.json` |
| `npm run flowchain:production-l1:e2e` | passed, exit 0; final status `passed-with-live-blockers`; report timestamp `2026-05-14T16:23:45.5784606Z` |
| `npm run flowchain:real-value-pilot:e2e` | passed, exit 0; status `passed`; `AllowIncomplete=false`; `SkipBaseline=false`; report generated `2026-05-14T16:18:47.3193401Z` |
| `npm run flowchain:no-secret:scan` | passed, exit 0; report generated `2026-05-14T16:24:08.6005410Z`; scanned 288 files; findings 0 |
| `npm run flowchain:bridge:live:check` | failed closed, exit 1; report generated `2026-05-14T16:24:12.4188670Z`; status `blocked`; missing owner env only; `broadcasts=false`; `printsEnvValues=false`; `noSecrets=true` |
| `git diff --check` | passed, exit 0 |

The final aggregate report records:

- status `passed-with-live-blockers`
- local/mock path `passed`
- live readiness `blocked`
- dashboard build `passed`
- bridge mock path `passed`
- restart recovery `passed`
- export/import root compare `passed`
- no-secret scan `passed`
- local state root `0x149b8017ed2be0fb192c295383d2a198798a24e8509978c678fe78205ca8ee58`

## Required Owner Inputs

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

Acknowledgement value:

`I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT`

## Final Reports

- `devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json`
- `devnet/local/production-l1-e2e/flowchain-production-l1-e2e-summary.md`
- `devnet/local/production-l1-e2e/bridge-live-readiness-report.json`
- `devnet/local/production-l1-e2e/no-secret-scan-report.json`
- `devnet/local/production-l1-e2e/export-import-root-compare.json`
- `devnet/local/production-l1-e2e/real-value-pilot-coordination/flowchain-real-value-pilot-e2e-report.json`
- `devnet/local/production-l1-e2e/evidence/flowchain-production-l1-evidence-export-report.json`
- `devnet/local/production-l1-e2e/evidence/flowchain-production-l1-evidence.zip`

The standalone real-value pilot report from the explicit gate is also present
at `devnet/local/real-value-pilot/flowchain-real-value-pilot-e2e-report.json`.

## Operator Boundary

Do not send funds or broadcast transactions until the owner supplies the inputs
above in a local shell and reruns:

```powershell
npm run flowchain:bridge:live:check
```
