# Agent Bonds v1 Boundary

Date: 2026-05-20

## Status

Accepted for local/test implementation.

## Context

FlowMemory needs a concrete accountability primitive for autonomous agent work. The useful primitive is not a generic reputation score. It is a task-scoped surety bond: an agent accepts explicit terms, posts collateral, submits committed evidence, receives a verifier report, and leaves a durable FlowMemory receipt that future agents can cite.

The current repository remains a V0/local/test/canary foundation. This decision does not approve open value-bearing deployment, public verifier markets, token emissions, dynamic fees, bridge settlement, or uncapped user funds.

## Decision

Agent Bonds v1 is a task-accountability layer that composes with FlowPulse, MemoryReceipt, RootflowTransition, RootfieldBundle, and AgentMemoryView.

The asset split is mandatory:

- USDC-like settlement token for requester payouts, task bonds, verifier fees, dispute bonds, refunds, and slash distribution.
- FlowMemory stake token for agent eligibility, verifier eligibility, capacity limits, challenge eligibility, and slashable protocol abuse.

The stake token does not back stable requester refunds. Task cash liability stays in the settlement token.

## Implemented Token Utility

If a FlowMemory project token is launched against the current repo state, the grounded utility is:

- agent eligibility stake
- verifier eligibility stake
- open-liability capacity scaling through stake size
- slash exposure for protocol abuse or overturned verifier behavior

The project token is not the stable settlement asset for requester refunds, payouts, or verifier fees.


## On-Chain Surfaces

Agent Bonds v1 adds these isolated surfaces:

- `TaskBondEscrow`: custody and pull-payment accounting for the settlement token.
- `AgentStakeRegistry`: stake deposits, agent/verifier eligibility, task-capacity accounting, and stake slashing authority.
- `TaskPolicyRegistry`: versioned objective task policies, bond ratios, fee floors, dispute windows, grace windows, and evidence schema commitments.
- `AgentBondManager`: task lifecycle, FlowPulse emission, evidence commitments, verifier reports, expiry, settlement, slashing, and challenge resolution.

`RootfieldRegistry` remains a namespace/root commitment contract. It must not become an escrow or payment router.

## FlowPulse Task Types

Agent Bonds reserves task lifecycle pulse types after the V0 root and swap types:

- `5` / `TASK_OPENED`
- `6` / `TASK_ACCEPTED`
- `7` / `TASK_STARTED`
- `8` / `TASK_EVIDENCE_COMMITTED`
- `9` / `TASK_VERIFIED`
- `10` / `TASK_FAILED`
- `11` / `TASK_CHALLENGED`
- `12` / `TASK_SETTLED`
- `13` / `TASK_SLASHED`

The event still excludes receipt-only metadata such as `txHash` and `logIndex`; indexers derive those fields after reading receipts and logs.

## State Machine

The v1 task lifecycle is intentionally narrow:

```text
Open
-> Accepted
-> Started
-> EvidenceCommitted
-> Verified | Failed | Unsupported | Reorged
-> Challenged
-> Settled | Refunded | Slashed
```

Expiry from `Accepted` or `Started` without evidence can move directly to `Slashed` after the policy grace window.

## Bond Formula

For payout `P` in settlement-token units:

```text
agentBond = max(policy.minAgentBond, P * policy.agentBondBps / 10_000)
verifierFee = max(policy.minVerifierFee, P * policy.verifierFeeBps / 10_000)
requesterCancelBond = max(policy.minRequesterCancelBond, P * policy.requesterCancelBondBps / 10_000)
disputeBond = max(policy.minDisputeBond, agentBond * policy.disputeBondBps / 10_000)
```

The first supported task classes are objective tasks only: deterministic code, data transforms, retrieval/citation checks, and schema/API completion checks.

## Settlement Rules

- Verified task: agent receives payout and returned task bond; verifier receives the verifier fee; requester receives the requester cancel bond.
- Verified but late within grace: a small task-bond slash is applied before the agent bond is returned.
- Failed task: requester receives payout, requester cancel bond, and the requester share of the slashed agent bond; verifier/challenger receives the verifier share; reserve receives the reserve share.
- Unsupported or reorged task: requester receives payout and requester cancel bond; agent receives the task bond back; verifier receives the verifier fee if it submitted the report.
- Expired no-submission task: requester receives payout, requester cancel bond, and the requester share of the task bond slash.

Default slash split:

```text
85% requester
10% verifier or successful challenger
5% protocol reserve
```

## What v1 Excludes

- Subjective quality slashing.
- Safety-critical real-world tasks.
- Medical, legal, or financial correctness judgments.
- Hardware or physical-world evidence adjudication.
- Token-denominated requester refunds.
- Token emissions or yield promises.
- Open anonymous verifier markets.
- Cross-chain task portability.
- Uncapped value-bearing tasks.
- Claims that the current verifier path is trustless.

## Build Goal

The first complete local/test goal is one deterministic task traced end-to-end:

```text
requester funds task
-> agent posts task bond
-> agent submits committed evidence
-> verifier submits report
-> settlement executes
-> FlowPulse lifecycle is emitted
-> MemoryReceipt records evidence/status
-> RootflowTransition records the state delta
-> AgentMemoryView exposes portable task reputation
```

## Cutover Gates Before Any Open Value Flow

Open value flow remains blocked until separate evidence exists for:

- contract invariant coverage for escrow accounting and terminal states;
- independent security review;
- multisig/timelock ownership plan;
- settlement-token address and pause/freeze risk documentation;
- verifier operator policy;
- evidence retention policy;
- monitoring and incident runbooks;
- capped participant allowlist and global exposure limits;
- public wording that describes non-trustless components honestly.

## Implemented After Acceptance

The local/test implementation now includes:

- two-step ownership for escrow, stake, policy, and manager contracts;
- a timelocked multisig administration contract;
- a separate pause guardian and emergency stop path for new exposure;
- capped-pilot controls for requester, agent, verifier, payout, open exposure, and open task count;
- minimum evidence-availability windows and availability commitments before report acceptance;
- policy-controlled independent verifier confirmation before settlement.

These controls materially reduce trust assumptions for capped objective-task pilots, but they do not remove the need for an explicit dispute `resolutionAuthority` or an independent external review before uncapped public value flow.
