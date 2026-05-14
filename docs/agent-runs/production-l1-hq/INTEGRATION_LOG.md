# Gated L1 Integration Log

Date: 2026-05-14

## Current Follow-Up Entry

The final live pilot rehearsal gap loop reclassified the branch as
`CODE_NOT_READY`. This log now treats earlier integration/pass notes as
historical and not sufficient for a live pilot.

## Current Evidence

| Area | Current result |
| --- | --- |
| Aggregate gate | `npm run flowchain:production-l1:e2e` failed in the gap loop. |
| Strict pilot gate | `npm run flowchain:real-value-pilot:e2e` failed in the gap loop. |
| Control dashboard pilot gate | `npm run flowchain:real-value-pilot:control-dashboard` failed in the gap loop. |
| Live-readiness check | Failed closed without owner inputs and no broadcast. |
| Bridge mock/local checks | Passed in the gap-loop safe checks. |
| Command matrix aliases | Present in current `package.json`; no edit required. |

## Files Updated By This Follow-Up

- `docs/FLOWCHAIN_PRODUCTION_L1_GO_NO_GO.md`
- `docs/agent-runs/production-l1-hq/BASE8453_PILOT_LEDGER.md`
- `docs/agent-runs/production-l1-hq/CHECKLIST.md`
- `docs/agent-runs/production-l1-hq/COMMAND_MATRIX.md`
- `docs/agent-runs/production-l1-hq/COMPLETION_AUDIT.md`
- `docs/agent-runs/production-l1-hq/EVIDENCE.md`
- `docs/agent-runs/production-l1-hq/FOLLOWUP_PROMPTS.md`
- `docs/agent-runs/production-l1-hq/INTEGRATION_PLAN.md`
- `docs/agent-runs/production-l1-hq/OWNER_RUNBOOK.md`
- `docs/agent-runs/production-l1-hq/PLAN.md`

## Verification To Run

- `node infra/scripts/check-unsafe-claims.mjs`
- `git diff --check`
- `npm run flowchain:no-secret:scan`
- `git status --short --branch`
