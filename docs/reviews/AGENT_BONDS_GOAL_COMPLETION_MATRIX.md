# Agent Bonds Goal Completion Matrix

Date: 2026-05-20

## Goal

Make FlowMemory Agent Bonds ready for a real public launch by proving each of these deliverables with direct current-state evidence:

1. trusted verifier path replaced or materially reduced by challengeable verification
2. audit of escrow / settlement / slashing contracts
3. multisig + timelock + emergency controls for value-bearing custody
4. capped real-value pilot controls and exposure limits
5. artifact availability guarantees for evidence used in disputes
6. adversarial economic testing for griefing, spam challenges, and verifier collusion
7. production runtime for indexer/verifier/ops with recovery drills and monitoring
8. independent operator reproducibility, not just local repo determinism
9. honest public docs for trust assumptions and failure modes
10. final public-launch approval based on direct evidence, not placeholders

## Matrix

| Deliverable | Repo-side evidence required | Current evidence | Status |
| --- | --- | --- | --- |
| Challenge-reduced verifier trust | challenge flow, confirmer requirement, tests | `contracts/AgentBondManager.sol`, `tests/AgentBondManager.t.sol` | Repo-side satisfied |
| Contract review evidence | passing tests, static analysis, internal review doc | `forge test`, `npm run contracts:hardening:slither`, `docs/reviews/AGENT_BONDS_V1_SECURITY_REVIEW.md` | Repo-side satisfied |
| Multisig/timelock/emergency controls | two-step ownership, timelocked executor, pause guardian, emergency stop | `contracts/shared/TwoStepOwnable.sol`, `contracts/AgentBondTimelockedMultisig.sol`, `contracts/AgentBondManager.sol` | Repo-side satisfied |
| Pilot caps and allowlists | pilot mode, caps, validator, deploy path | `contracts/AgentBondManager.sol`, `script/DeployAgentBondsPilot.s.sol`, `infra/scripts/agent-bonds-pilot-config-validate.mjs` | Repo-side satisfied |
| Artifact availability enforcement | availability commitment, retention windows, schema, tests | `contracts/AgentBondManager.sol`, `schemas/flowmemory/task-bond-availability-proof.schema.json`, `tests/AgentBondManager.t.sol` | Repo-side satisfied |
| Economic adversarial coverage | deterministic simulation report and validator coverage | `services/flowmemory/src/agent-bonds-simulate.ts`, `fixtures/agent-bonds/economic-sim-report.json` | Repo-side satisfied |
| Runtime / monitoring / recovery | control-plane runtime methods, readiness report, runbooks | `services/control-plane/src/methods.ts`, `local test runtime/local/agent-bonds-readiness/agent-bonds-readiness-report.json`, `local test runtime/local/agent-bonds-readiness/goal-audit-report.json`, `docs/OPERATIONS/AGENT_BONDS_MONITORING_AND_RECOVERY.md` | Repo-side satisfied |
| Independent reproducibility | replay report, operator bundle, fixture determinism | `services/flowmemory/src/agent-bonds-replay.ts`, `fixtures/agent-bonds/replay-report.json`, `out/agent-bonds-operator-bundle/` | Repo-side satisfied |
| Honest public docs | public boundary docs, checklist, review docs, claim guardrail passes | `docs/AGENT_BONDS_PUBLIC_LAUNCH_BOUNDARY.md`, `docs/OPERATIONS/AGENT_BONDS_PUBLIC_LAUNCH_APPROVAL.md`, `node infra/scripts/check-unsafe-claims.mjs` | Repo-side satisfied |
| Final public-launch approval | filled non-placeholder signoff artifacts, public-launch validator pass | `fixtures/agent-bonds/launch-approval.template.json`, `infra/scripts/agent-bonds-public-launch-validate.mjs` | Blocked on external signoffs |

## External-only blockers

The remaining launch blockers are intentionally outside the code path and are enforced by the public-launch validator:

- completed independent external review
- completed operator separation sign-off with real operators and keys
- completed live multi-operator runtime evidence on the target network
- completed final owner go/no-go decision for the actual network, contracts, assets, and caps

## Rule

Do not call the system public-launch ready until the public-launch validator passes against filled real artifacts, not templates.
