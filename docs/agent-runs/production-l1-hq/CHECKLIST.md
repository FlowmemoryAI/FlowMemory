# Gated L1 HQ Checklist

Date: 2026-05-14

Current classification: `CODE_NOT_READY`.

Status terms: `passed-safe-slice` means the gap loop recorded that local/mock
slice as passing; `failed-gate` means a required gate failed; `not-authoritative`
means older reports may exist but cannot override the gap-loop classification.

| Requirement group | Required command or evidence | Current status | Notes |
| --- | --- | --- | --- |
| Aggregate mock/local gate | `npm run flowchain:production-l1:e2e` | failed-gate | Export, import, root, and restart gates failed in the final rehearsal loop. |
| Strict pilot rehearsal gate | `npm run flowchain:real-value-pilot:e2e` | failed-gate | The strict gate failed through the product/control-plane path. |
| Control dashboard pilot gate | `npm run flowchain:real-value-pilot:control-dashboard` | failed-gate | The pilot API smoke failed on malformed local devnet JSON. |
| Live-readiness check | `npm run flowchain:bridge:live:check` | passed-safe-slice | Failed closed with missing owner inputs and no broadcast; this is not enough for readiness. |
| Mock bridge proof | `npm run flowchain:bridge:mock:e2e` | passed-safe-slice | Local/mock proof only. |
| Bridge local credit smoke | `npm run bridge:local-credit:smoke` | passed-safe-slice | Local/mock proof only. |
| Runtime pilot slice | `npm run flowchain:real-value-pilot:runtime` | passed-safe-slice | Local rehearsal slice only. |
| Secret-shaped value scan | `npm run flowchain:no-secret:scan` | passed-safe-slice | Must still be rerun before handoff. |
| Prior HQ pass docs | `docs/agent-runs/production-l1-hq/` before this update | not-authoritative | Stale pass/external-blocked claims were replaced by this `CODE_NOT_READY` report. |

## Exit Criteria

Do not move this checklist out of `CODE_NOT_READY` until the aggregate gate, the
strict pilot gate, the control-dashboard pilot gate, and the no-secret scan pass
in the same fresh evidence loop.
