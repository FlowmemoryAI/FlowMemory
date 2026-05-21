# Agent Bonds Public Launch Boundary

Date: 2026-05-20

## Status

This document defines the honest public boundary for FlowMemory Agent Bonds.

## Product Claim Allowed

FlowMemory Agent Bonds is a task-bond and settlement protocol for bounded off-chain agent work where on-chain contracts hold escrow, enforce task-lifecycle rules, record compact commitments, and preserve challengeable receipts and reputation.

The Phase 2 public claim may also describe optional USDC-backed recourse records for narrow objective API/data tasks when a quote includes a signed recourse-policy attestation, locked pool coverage, concentration caps, epoch loss caps, and withdrawal cooldown controls.

## Claims Not Allowed

Do not claim:

- trustless AI correctness
- provably correct arbitrary agent output
- permanent artifact availability
- decentralized verifier finality
- unlimited permissionless safety
- production readiness without the readiness report, contract review, operator controls, and capped pilot evidence
- insurance coverage, deposit protection, or promise that every loss is reimbursed

## Current Trust Assumptions

Public wording must state all of the following:

- heavy task artifacts remain off-chain
- the protocol proves commitments, receipts, settlement rules, and challenge windows; it does not prove semantic truth of arbitrary AI output
- a designated verifier still exists for first report submission
- high-value or production-shaped policies should require independent verifier confirmation before settlement
- disputed outcomes still rely on an explicit resolution authority unless a later fraud-proof or on-chain adjudication path is added
- artifact availability is represented by commitments and retention windows; it is not a perpetual storage guarantee
- recourse payouts are limited to locked coverage, policy eligibility, pool loss caps, and dispute outcomes
- emergency stop and pause are operator safety controls, not decentralization features

## Required Public Safety Language

Use language like:

- "capped pilot"
- "objective task classes only"
- "challengeable settlement"
- "independent verifier confirmation required for production-shaped policies"
- "off-chain artifacts, on-chain commitments"
- "operator-controlled emergency stop"
- "task-scoped capital-backed recourse records"

## Failure Modes That Must Be Publicly Named

- verifier submits an incorrect initial report
- confirmer is unavailable and settlement is delayed
- evidence retention window is too short and report submission is blocked
- challenger opens a dispute and settlement is delayed until resolution
- emergency stop halts new exposure while existing tasks are unwound manually or through bounded rules
- capped pilot limits reject new tasks before funds are accepted
- off-chain artifact provider becomes unavailable before the retention window ends and the task can be challenged or fail verification
- recourse pool loss caps or withdrawal cooldowns prevent a new task from being backed

## Launch Rule

Public GitHub publication is allowed with this document and the linked readiness artifacts.

Open uncapped real-value launch is blocked until:

- the capped readiness report passes
- operator ownership is transferred to the timelocked multisig path
- incident and recovery drills are documented and exercised
- the internal security review is accepted
- an independent external review is scheduled or completed for the value-bearing deployment you intend to use
