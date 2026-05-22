# Agent Bonds External Review Packet

Date: 2026-05-20

## Purpose

This packet is the handoff surface for an independent reviewer of the value-bearing Agent Bonds deployment.

## Contracts In Scope

- `contracts/AgentBondManager.sol`
- `contracts/TaskBondEscrow.sol`
- `contracts/AgentStakeRegistry.sol`
- `contracts/TaskPolicyRegistry.sol`
- `contracts/AgentBondTimelockedMultisig.sol`
- `contracts/shared/TwoStepOwnable.sol`

## Security-Critical Behaviors To Review

- requester escrow accounting
- agent bond accounting
- challenge-bond accounting
- verifier-fee routing
- slash split routing
- late-delivery settlement branch
- unsupported / reorged refund branch
- no-submission slash branch
- independent confirmer requirement
- emergency stop and pause semantics
- pilot-mode allowlist and cap enforcement
- owner / multisig / guardian role boundaries
- evidence-availability window enforcement

## Commands To Reproduce Current Evidence

```powershell
forge test
npm run contracts:hardening:slither
npm run flowmemory:agent-bonds:replay
npm run flowmemory:agent-bonds:simulate
npm run flowmemory:agent-bonds:readiness
npm run flowmemory:agent-bonds:pilot-config:validate -- fixtures/agent-bonds/pilot-config.template.json
```

## Current Artifacts

- readiness report: `local test runtime/local/agent-bonds-readiness/agent-bonds-readiness-report.json`
- replay report: `fixtures/agent-bonds/replay-report.json`
- economic simulation: `fixtures/agent-bonds/economic-sim-report.json`
- pilot config template: `fixtures/agent-bonds/pilot-config.template.json`
- internal review: `docs/reviews/AGENT_BONDS_V1_SECURITY_REVIEW.md`
- readiness audit: `docs/reviews/AGENT_BONDS_READINESS_AUDIT.md`

## Explicit Trust Assumptions The Reviewer Must Evaluate

- `resolutionAuthority` still resolves challenged outcomes
- artifact availability is guaranteed only through declared retention windows, not perpetual storage proofs
- confirming verifiers are assumed operationally independent, not cryptographically forced to be so
- settlement asset and stake asset selection are deployment-specific and not proven safe by this repo

## Review Exit Criteria

The reviewer should be able to answer yes/no on at least:

- can a single task cause funds to be created or destroyed?
- can a terminal task be settled twice?
- can an invalid report bypass independent confirmer requirements when policy requires them?
- can pilot caps be bypassed through state ordering or challenge paths?
- can emergency stop still leave an unsafe path for new exposure?
- can the owner path seize funds directly without going through explicit contract logic?
- are all value-moving transitions tested and statically analyzed?

## What This Packet Does Not Do

- it does not replace an independent review
- it does not certify operator independence
- it does not certify a specific deployment, settlement token, or RPC provider
