# Agent Bonds Capped Pilot Runbook

Date: 2026-05-20

## Scope

This runbook is for a capped objective-task pilot of FlowMemory Agent Bonds. It is not approval for an open uncapped launch.

## Required Roles

- timelocked multisig owners
- pause guardian
- designated verifier
- independent confirming verifier
- operator responsible for evidence retention and export

No single EOA should hold every role in a public value-bearing deployment.

## Required Contract Control Shape

Deploy production-shaped Agent Bonds with:

- `AgentBondTimelockedMultisig` as owner or pending owner for policy, stake, escrow, and manager controls
- a separate `pauseGuardian` address that can stop new exposure immediately
- `pilotMode = true`
- explicit requester, agent, and verifier allowlists
- nonzero `maxPayoutPerTask`, `maxOpenExposure`, and `maxOpenTasks`
- a policy with `requiredConfirmations >= 1` for production-shaped objective tasks


## Pilot Config Validation

Before public pilot sign-off, fill `fixtures/agent-bonds/pilot-config.template.json` with the actual pilot addresses and caps, then run:

```powershell
npm run flowmemory:agent-bonds:pilot-config:validate -- fixtures/agent-bonds/pilot-config.template.json
```

## Evidence Retention Rule

Do not accept a task unless the evidence retention window covers:

- task execution
- verifier reporting
- challenge window
- operator export / dispute response buffer

The current contract enforces nonzero availability commitment and a minimum availability window before evidence can be committed and before a report can be accepted.

## Capped Pilot Checklist

1. Run `npm run flowmemory:agent-bonds:v1`.
2. Run `npm run flowmemory:agent-bonds:replay`.
3. Run `npm run flowmemory:agent-bonds:simulate`.
4. Run `npm run flowmemory:agent-bonds:pilot-config:validate -- fixtures/agent-bonds/pilot-config.template.json`.
5. Run `npm run flowmemory:agent-bonds:readiness`.
6. Confirm the readiness report is green.
7. Confirm public docs still describe the system as capped and challengeable, not trustless.
8. Confirm the designated verifier and confirming verifier are different operators.
9. Confirm pause guardian and multisig owners are different operators.
10. Confirm the settlement asset, caps, and allowlists match the intended public pilot.
11. Confirm evidence retention/export storage is configured for the pilot window.

## Emergency Rules

If verification, settlement, or evidence availability looks unsafe:

- set `emergencyStopped = true`
- keep `paused = true`
- do not open new tasks
- finish only the minimum safe unwind path
- preserve evidence, replay report, readiness report, and operator notes

Emergency stop is for safety. It is not a market event.

## Safe Recovery Steps

1. export the latest evidence and readiness artifacts
2. replay the committed fixture and compare hashes
3. verify which tasks are open, challenged, or already terminal
4. decide whether each open task should:
   - continue,
   - expire into slash,
   - or be explicitly unwound before broader public exposure
5. only lift pause after the root cause is documented and retested

## Public Launch Boundary

This runbook supports:

- public GitHub publication
- capped pilot communication
- objective-task demonstrations
- allowlisted value-bearing pilot preparation

This runbook does not support:

- uncapped mainnet launch
- subjective work arbitration
- trustless verifier marketing
- permanent artifact availability claims
