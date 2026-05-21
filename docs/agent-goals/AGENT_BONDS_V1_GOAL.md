# Agent Bonds v1 Goal

## Mission

Build FlowMemory Agent Bonds v1 as an accountable-agent task layer. The first goal is not a broad market. The first goal is one objective task that can be traced from escrow and bond posting through verification, settlement, FlowPulse events, MemoryReceipt, RootflowTransition, and AgentMemoryView.

## Required Boundaries

- Keep heavy prompts, model outputs, traces, artifacts, media, and memory off-chain.
- Put only compact commitments, task state, escrow accounting, verifier report identifiers, roots, and lifecycle events on-chain.
- Use a settlement token for task payouts, task bonds, verifier fees, dispute bonds, refunds, and slash distribution.
- Use the FlowMemory stake token for agent eligibility, verifier eligibility, capacity limits, challenge eligibility, and protocol-abuse slashing.
- Do not use the stake token as stable requester refund collateral.
- Do not add token emissions, APY language, buyback claims, or perpetual-compute promises.
- Do not add subjective quality slashing in v1.
- Do not put payment logic into `RootfieldRegistry`.

## Contract Targets

Implement and test:

- `TaskBondEscrow`
- `AgentStakeRegistry`
- `TaskPolicyRegistry`
- `AgentBondManager`
- task lifecycle FlowPulse type constants

## Service Targets

Implement and test deterministic local/test projections for:

- task terms
- task evidence
- verifier report
- dispute/resolution object
- settlement object
- task-aware MemoryReceipt
- task-aware RootflowTransition
- task-aware AgentMemoryView

## End-To-End Local Scenario

The canonical local scenario must show:

1. requester opens an objective task and funds payout plus verifier fee and requester cancel bond;
2. agent has stake-token eligibility and posts a settlement-token task bond;
3. agent starts the task;
4. agent submits nonzero evidence commitment and an advisory evidence URI;
5. verifier submits a valid report;
6. challenge window closes;
7. settlement releases payout and returned bond to the agent, verifier fee to verifier, and requester cancel bond to requester;
8. generated FlowMemory fixture links the task to a MemoryReceipt, RootflowTransition, RootfieldBundle, and AgentMemoryView.

## Required Tests

- task opening rejects zero rootfield, zero terms hash, inactive policy, and zero payout;
- acceptance requires eligible agent stake and settlement-token bond escrow;
- evidence commitment rejects non-agent caller and zero commitment;
- valid report settles exactly once;
- failed report slashes with 85/10/5 distribution;
- expired no-submission task slashes without verifier success assumptions;
- unsupported/reorged report refunds without slashing;
- challenge path requires a dispute bond and can overturn a report through the resolution authority;
- escrow accounting cannot double-release;
- generated JSON validates against task-bond schemas.

## Definition Of Done

- Targeted contract tests pass.
- Targeted FlowMemory service tests pass.
- The task-bond fixture is deterministic.
- The architecture decision names what is implemented and what remains gated.
- No document claims open value flow readiness, public verifier trustlessness, free storage, or AI-on-chain execution.
