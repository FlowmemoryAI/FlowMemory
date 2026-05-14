# Gated L1 Owner Runbook

Date: 2026-05-14

## Current State

Current classification: `CODE_NOT_READY`.

Do not broadcast transactions and do not send funds before a later report marks
the branch `READY_FOR_OPERATOR_LIVE_PILOT`.

The final rehearsal gap loop failed the aggregate and strict pilot gates. Missing
owner inputs are not the only blocker.

## Safe Commands While Not Ready

These commands may be used for local diagnosis and reporting:

```powershell
npm run flowchain:production-l1:e2e
npm run flowchain:real-value-pilot:e2e
npm run flowchain:real-value-pilot:control-dashboard
npm run flowchain:bridge:command-matrix
npm run flowchain:bridge:no-secret-audit
npm run flowchain:no-secret:scan
```

`npm run flowchain:bridge:live:check` is a readiness-only command and should
fail closed without owner inputs. It does not make the branch ready while the
failed gates remain open.

## Owner Checklist Before Any Future Live Pilot

- Wait for `READY_FOR_OPERATOR_LIVE_PILOT`.
- Independently verify the lockbox address against the intended owner-approved
  deployment before sending funds.
- Use a tiny cap and funded owner-controlled account only.
- Use a narrow block range.
- Confirm chain ID `8453` from the RPC endpoint.
- Run `npm run flowchain:bridge:live:check` and read the report before any
  owner-controlled broadcast command.
- Keep env values in the local shell only; do not commit, paste, print, or
  screenshot them.

No live transaction was broadcast by this follow-up.
