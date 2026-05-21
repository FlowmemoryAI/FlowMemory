# Agent Bonds Readiness Audit

Date: 2026-05-20

## Scope

Audit goal:

- reduce verifier trust assumptions
- provide contract-review evidence
- add multisig/timelock/emergency controls
- add capped pilot controls and exposure limits
- add artifact-availability controls
- add adversarial economic testing
- add operator reproducibility, monitoring, and recovery evidence
- keep public docs honest

## Evidence

### 1. Trusted verifier path replaced or materially reduced

Status: materially reduced, not fully trustless.

Evidence:

- `contracts/AgentBondManager.sol`
- `tests/AgentBondManager.t.sol`
- policy-controlled independent verifier confirmation before settlement
- challenge bond flow
- challenger fee routing on overturned reports
- explicit dispute `resolutionAuthority` still documented as a trust assumption

### 2. Audit of escrow / settlement / slashing contracts

Status: internal review complete; external independent review still open.

Evidence:

- `docs/reviews/AGENT_BONDS_V1_SECURITY_REVIEW.md`
- `npm run contracts:hardening:slither` passes
- `forge test --match-path tests/AgentBondManager.t.sol` passes
- `forge test --match-path tests/AgentBondTimelockedMultisig.t.sol` passes

### 3. Multisig + timelock + emergency controls

Status: implemented for production-shaped deployment paths.

Evidence:

- `contracts/shared/TwoStepOwnable.sol`
- `contracts/AgentBondTimelockedMultisig.sol`
- `AgentBondManager.pauseGuardian`
- `AgentBondManager.setEmergencyStopped`
- `tests/AgentBondTimelockedMultisig.t.sol`
- `tests/AgentBondManager.t.sol`

### 4. Capped real-value pilot controls and exposure limits

Status: implemented.

Evidence:

- pilot mode
- requester / agent / verifier allowlists
- per-task payout cap
- global open-exposure cap
- open-task count cap
- `fixtures/agent-bonds/pilot-config.template.json`
- `schemas/flowmemory/agent-bonds-pilot-config.schema.json`
- `infra/scripts/agent-bonds-pilot-config-validate.mjs`
- `testPilotModeEnforcesAllowlistsAndCaps`

### 5. Artifact availability guarantees for disputes

Status: retention-window enforcement implemented; perpetual availability not claimed.

Evidence:

- `availabilityCommitment` and `availabilityUntil` in evidence fixture/schema
- `task-bond-availability-proof.schema.json`
- `AgentBondManager.commitEvidence` and `submitVerifierReport` availability-window checks
- `testEvidenceCommitmentRequiresTaskAgentAndAvailabilityWindow`

### 6. Adversarial economic testing

Status: deterministic scenario coverage implemented.

Evidence:

- `services/flowmemory/src/agent-bonds-simulate.ts`
- `fixtures/agent-bonds/economic-sim-report.json`
- scenarios cover verified settlement, invalid-report slash, challenged overturn, spam-challenge cost floor, exposure caps, and confirmation requirement

### 7. Production runtime / recovery drills / monitoring

Status: operator evidence and control-plane runtime support added; full hosted production runtime still open.

Evidence:

- `infra/scripts/agent-bonds-readiness.mjs`
- `devnet/local/agent-bonds-readiness/agent-bonds-readiness-report.json`
- `devnet/local/agent-bonds-readiness/goal-audit-report.json`
- `services/control-plane/src/methods.ts`
- `services/control-plane/test/control-plane.test.ts`
- `services/control-plane` runtime now exposes `agent_bond_task_*`, `agent_bond_readiness_get`, and `agent_bond_public_launch_status_get`
- `docs/OPERATIONS/AGENT_BONDS_CAPPED_PILOT_RUNBOOK.md`
- `docs/OPERATIONS/AGENT_BONDS_MONITORING_AND_RECOVERY.md`
- `.github/workflows/ci.yml` now includes a dedicated Agent Bonds readiness job
- `infra/scripts/agent-bonds-public-launch-validate.mjs`
- `services/flowmemory/test/agent-bonds-validation.test.ts`
- `infra/scripts/agent-bonds-public-launch-blockers.mjs`
- `infra/scripts/agent-bonds-goal-audit.mjs`
- `infra/scripts/agent-bonds-owner-inputs-validate.mjs`
- `infra/scripts/agent-bonds-owner-inputs-materialize.mjs`
- `infra/scripts/agent-bonds-public-launch-package.mjs`

### 8. Independent operator reproducibility

Status: deterministic replay evidence and operator bundle implemented.

Evidence:

- `services/flowmemory/src/agent-bonds-replay.ts`
- `fixtures/agent-bonds/replay-report.json`
- `infra/scripts/agent-bonds-operator-bundle.mjs`
- `out/agent-bonds-operator-bundle/`
- readiness report includes replay success
- `fixtures/agent-bonds/discovered-live-references.json`
- `fixtures/agent-bonds/approvals/`
- `out/agent-bonds-operator-bundle/` now includes the goal audit report plus structured approval templates and schemas

### 9. Honest public docs for trust assumptions and failure modes

Status: implemented.

Evidence:

- `README.md`
- `docs/AGENT_BONDS_PUBLIC_LAUNCH_BOUNDARY.md`
- `docs/OPERATIONS/AGENT_BONDS_CAPPED_PILOT_RUNBOOK.md`
- `docs/reviews/AGENT_BONDS_V1_SECURITY_REVIEW.md`
- `docs/PRODUCTION_READINESS_CHECKLIST.md`
- `docs/SECURITY_MODEL.md`
- `docs/OPERATIONS/AGENT_BONDS_OWNER_INPUTS.md`
- `docs/OPERATIONS/AGENT_BONDS_PUBLIC_LAUNCH_APPROVAL.md`

## Current Launch Conclusion

### Allowed now

- public GitHub publication
- public technical write-up with the explicit boundary docs above
- capped objective-task pilot preparation
- internal / allowlisted demonstrations

### Still blocked for an uncapped public value-bearing launch

- independent external review for the exact deployment and custody configuration you will use, using `docs/OPERATIONS/AGENT_BONDS_EXTERNAL_REVIEW_PACKET.md`
- real operator separation on live keys and infrastructure, with sign-off recorded in `docs/OPERATIONS/AGENT_BONDS_OPERATOR_SEPARATION_CHECKLIST.md`
- live multi-operator runtime evidence beyond local/test readiness scripts
- a final go/no-go decision for the specific network, assets, and caps you intend to expose publicly

A direct public-launch gate now exists at `infra/scripts/agent-bonds-public-launch-validate.mjs`, and a direct blocker audit exists at `infra/scripts/agent-bonds-public-launch-blockers.mjs`. Run them against `fixtures/agent-bonds/launch-approval.template.json` plus the filled pilot config. The current template fails only on unresolved external sign-offs and live operator inputs, which is the direct repo evidence that the remaining blockers are external-only.

## Audit Result

Current branch is materially stronger and substantially closer to launch readiness.

It is ready for public repository publication and capped-pilot communication.

It is not yet honest to call it an uncapped trust-minimized public launch.
