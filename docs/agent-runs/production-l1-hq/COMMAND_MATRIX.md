# Gated L1 HQ Command Matrix

Date: 2026-05-14

Current classification: `CODE_NOT_READY`.

This matrix reflects the scripts present in the current root `package.json`.
It does not upgrade the branch to an operator pilot state.

## Loop Gate Status

| Command | Purpose | Latest gap-loop status | Safe default |
| --- | --- | --- | --- |
| `npm run flowchain:production-l1:e2e` | Aggregate mock/local gate | failed | Safe to rerun locally; no funds. |
| `npm run flowchain:real-value-pilot:e2e` | Strict real-value pilot rehearsal gate | failed | Safe to rerun locally; no funds. |
| `npm run flowchain:real-value-pilot:control-dashboard` | Control-plane/dashboard pilot E2E | failed | Safe to rerun locally; no funds. |
| `npm run flowchain:bridge:live:check` | Base 8453 readiness check | failed closed without owner inputs | Readiness only; no broadcast. |
| `npm run flowchain:bridge:mock:e2e` | Mock bridge credit proof | passed in the gap-loop safe checks | Local/mock only. |
| `npm run bridge:local-credit:smoke` | Bridge local credit smoke | passed in the gap-loop safe checks | Local/mock only. |
| `npm run flowchain:real-value-pilot:runtime` | Runtime rehearsal slice | passed in the gap-loop safe checks | Local only. |
| `npm run flowchain:no-secret:scan` | Secret-shaped value scan | passed in the gap-loop safe checks | Read-only scan plus report write. |

## Package Script Presence

| Script | Present in `package.json` | Broadcast capable by default | Notes |
| --- | --- | --- | --- |
| `flowchain:bridge:command-matrix` | yes | no | Calls `infra/scripts/flowchain-bridge-command-matrix.ps1`; writes a JSON report. |
| `flowchain:bridge:no-secret-audit` | yes | no | Calls `infra/scripts/flowchain-bridge-no-secret-audit.ps1`; scans selected outputs and writes a JSON report. |
| `flowchain:bridge:live:check` | yes | no | Readiness check; expected to fail closed without owner inputs. |
| `flowchain:bridge:deploy:base8453` | yes | yes, when owner inputs are supplied | Do not run before `READY_FOR_OPERATOR_LIVE_PILOT`. |
| `flowchain:bridge:observe:base8453` | yes | no | Reads logs only, but still requires owner-verified inputs and narrow ranges. |
| `flowchain:bridge:pause` | yes | yes, when owner inputs are supplied | Owner-control path; do not run from a not-ready branch. |
| `flowchain:bridge:resume` | yes | yes, when owner inputs are supplied | Owner-control path; do not run from a not-ready branch. |
| `flowchain:bridge:emergency-stop` | yes | yes, when owner inputs are supplied | Owner-control path; do not run from a not-ready branch. |
| `flowchain:bridge:withdraw:intent` | yes | no broadcast by wrapper intent path | Do not use as pilot evidence until failed gates pass. |
| `flowchain:bridge:release:evidence` | yes | no | Evidence report path; requires explicit inputs. |
| `flowchain:no-secret:scan` | yes | no | Repository/report scan; writes a report. |

No package or script edit was needed in this follow-up because the optional
report/audit aliases are already present in the current dirty worktree.
