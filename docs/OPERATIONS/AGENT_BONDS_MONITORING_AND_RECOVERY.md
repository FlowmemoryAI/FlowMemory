# Agent Bonds Monitoring And Recovery

Date: 2026-05-20

## Minimum Monitoring Surface

Track and retain at least these values during any capped public pilot:

- `openExposure`
- `openTaskCount`
- `paused`
- `emergencyStopped`
- count of tasks by status (`open`, `accepted`, `evidence_committed`, `challenged`, `settled`, `slashed`, `refunded`)
- count of tasks waiting on independent verifier confirmation
- count of tasks whose evidence-availability window expires within the next challenge window
- count of challenger wins vs verifier wins
- reserve balance
- per-verifier fee flow and stake-slash events

## Recovery Drill Frequency

Run before a public pilot and after every operator-role change:

1. `npm run flowmemory:agent-bonds:replay`
2. `npm run flowmemory:agent-bonds:simulate`
3. `npm run flowmemory:agent-bonds:readiness`
4. verify the latest readiness report exists at `devnet/local/agent-bonds-readiness/agent-bonds-readiness-report.json`
5. verify the latest replay report exists at `fixtures/agent-bonds/replay-report.json`
6. verify the latest economic simulation exists at `fixtures/agent-bonds/economic-sim-report.json`

## Emergency Stop Drill

When simulating an emergency:

- set emergency stop on the manager
- verify new tasks are rejected
- verify new accept/start/evidence actions are rejected
- verify already terminal tasks still support withdrawal
- verify no readiness report or evidence export contains secrets

## Recovery Success Criteria

Recovery is only considered successful when:

- fixture replay matches exactly
- readiness report is green
- the operator can explain every open or challenged task
- no task is left in an undocumented state
- public docs still match the actual trust boundary
