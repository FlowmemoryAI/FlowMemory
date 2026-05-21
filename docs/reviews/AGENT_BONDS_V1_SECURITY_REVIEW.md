# Agent Bonds V1 Security Review

Date: 2026-05-20

## Scope

Reviewed files:

- `contracts/AgentBondManager.sol`
- `contracts/TaskBondEscrow.sol`
- `contracts/AgentStakeRegistry.sol`
- `contracts/TaskPolicyRegistry.sol`
- `contracts/AgentBondTimelockedMultisig.sol`
- `contracts/shared/TwoStepOwnable.sol`
- `tests/AgentBondManager.t.sol`
- `tests/AgentBondTimelockedMultisig.t.sol`

## Review Result

Status: internally reviewed for local/test and capped-pilot hardening.

This is not an independent external audit.

## Positive Findings

- escrow custody is isolated in `TaskBondEscrow`
- settlement uses pull-withdrawal accounting
- bond-slash splits are explicit and deterministic
- challenge bonds are separate from task bonds
- emergency stop and pause exist for new-exposure controls
- capped-pilot controls exist for requester, agent, verifier, payout, open exposure, and open task count
- production-shaped policies can require independent verifier confirmation before settlement
- evidence availability commitments and minimum retention windows are enforced before report acceptance
- owner controls are no longer permanently bound to the deployer EOA model; two-step ownership and a timelocked multisig path exist
- `npm run contracts:hardening:slither` passes on this branch.

## Remaining Risks

### 1. Resolution Authority Trust

Disputed outcomes still depend on an explicit `resolutionAuthority`.

Impact:
- incorrect dispute resolution can still affect funds
- trust is reduced, not eliminated

Required public wording:
- disputes are challengeable
- dispute finality is not yet trustless

### 2. Overturned Report Incentives

The current implementation routes the verifier fee to a successful challenger when a challenged report is overturned, while stake slash remains the heavier penalty.

Residual risk:
- production payout sizing and dispute-bond sizing still need live pilot tuning under real operator behavior

Follow-up:
- monitor challenger win rates and fee flow during the capped pilot before widening exposure

### 3. Artifact Availability Is Windowed, Not Permanent

The contract now enforces retention windows but cannot prove future storage availability on-chain.

Risk:
- a provider can still fail after the declared window or lie off-chain without additional proof infrastructure

### 4. Pilot Allowlist Governance

Allowlists and caps are owner-controlled.

Risk:
- governance mistakes or compromised operator controls can widen exposure incorrectly

### 5. Economic Griefing Still Needs Broader Scenario Coverage

The deterministic simulation covers core payout and slash invariants, but not every market-behavior edge case.

Risk:
- capital lock and challenge spam must still be monitored during pilot rollout

## Required Production Gates Still Open

Before uncapped public value flow:

- independent external review for the exact deployment surface
- final operator key custody plan
- production monitoring and alert routing
- rehearsal of emergency stop and restart on the target operator stack
- formalized verifier operator policy

## Reviewer Guidance

Merge approval is reasonable for:

- public repository publication
- local/test demonstrations
- capped pilot preparation

Merge approval is not by itself approval for:

- uncapped public mainnet launch
- subjective or safety-critical task settlement
- trustless marketing claims
