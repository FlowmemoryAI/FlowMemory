# Agent Model

## Goal

The agent model defines what a FlowMemory chain-side agent is allowed to be: a bounded actor with explicit identity, deterministic decision logic, public or committed memory, and constrained tools.

It is not a free-form server agent with a wallet and a hidden database.

## Agent identity

An agent should have one canonical `agentId` derived from stable inputs:

```text
agentId = hash(domain, chainId, registry, owner, salt, initialPolicyRoot, initialMemoryRoot)
```

Identity fields:

- `agentId`;
- owner/admin address;
- kernel address or kernel class;
- policy root;
- tool allowlist root;
- latest memory root;
- sequence;
- status;
- optional profile commitment.

The profile commitment can point to public descriptive metadata, but behavior-derived memory and receipts must remain the stronger trust source.

## Autonomy levels

Use explicit autonomy levels so developers and reviewers know what the agent can do.

| Level | Name | Allowed behavior |
| --- | --- | --- |
| 0 | Read-only scout | Reads state and previews decisions only. |
| 1 | Memory writer | Writes memory deltas but does not call external tools. |
| 2 | Bounded task actor | Calls approved task contracts with zero or capped value. |
| 3 | Capped value actor | Uses capped token/value flows under strict policy. |
| 4 | Multi-tool actor | Multiple approved tools, still rule-gated and capped. |

The first implementation should target level 0 and level 1 fixtures, then level 2 for the On-Chain Task Scout.

## Agent lifecycle

```text
configured
-> registered
-> previewable
-> active
-> paused / finalized / failed
-> corrected or superseded if needed
```

### Configured

A policy, memory root, kernel, and tool allowlist exist as local files or off-chain config.

### Registered

The registry stores the agent's compact chain-side identity.

### Previewable

Anyone can call `previewStep` for a supported observation without mutation.

### Active

A caller may commit a step if the preview and limits match current state.

### Paused

Reads and replay continue; mutation stops.

### Finalized

The agent is historical and read-only.

### Failed or slashed

The agent cannot mutate until a correction or admin action explicitly reopens it.

## Kernel model

A kernel is a deterministic decision function. It converts a small observation and current memory state into a small action output.

### Rule kernel

Good for the first implementation.

Example:

```text
if task.kind is allowed
and task.evidenceRequirement is public
and reward <= maxRewardAllowed
and failureCount(task.kind) < threshold
and spendUsedThisEpoch + actionCost <= cap
then ACCEPT_TASK
else REJECT_TASK or ESCALATE
```

### Scoring kernel

Useful once rule branches are stable.

```text
score =
  goalWeight * goalMatch
+ rewardWeight * normalizedReward
- riskWeight * riskScore
- failureWeight * priorFailurePenalty
- capWeight * spendImpact
```

Rules still decide eligibility. Scores rank only eligible actions.

### Tiny fixed-shape model kernel

Later only. It may classify memory importance or rank actions from a small enum. It must be deterministic, fixed-shape, bounded, and rule-gated.

## Observation model

An agent should not pretend to know off-chain facts. It observes:

- contract state;
- events and receipts;
- indexed FlowPulse observations;
- memory cells and roots;
- task/bond status;
- verifier reports;
- signed evidence envelopes;
- committed evidence pointers.

An observation should be encoded into a root that the kernel and verifier both understand.

## Action model

Actions must be small, explicit, and enumerable.

Initial action enum:

```text
NOOP
ESCALATE
ACCEPT_TASK
REJECT_TASK
COMMIT_EVIDENCE
UPDATE_MEMORY_ONLY
PAUSE_SELF
```

Each action has:

- action id;
- tool id;
- target contract;
- selector;
- calldata hash;
- value cap;
- reason code;
- expected memory delta root.

## Tool model

Tools are contract calls behind policy.

Tool policies bind:

- target address;
- selector;
- max value per action;
- epoch cap;
- call rate limit;
- allowed agent status;
- required memory or verifier status;
- failure handling.

A tool is not allowed because a runtime process knows how to call it. It is allowed because the policy root and router permit it.

## Reason codes

Reason codes make decisions inspectable without storing verbose text.

Suggested first reason codes:

| Code | Meaning |
| --- | --- |
| `TASK_KIND_ALLOWED` | Task type matched policy. |
| `TASK_KIND_UNSUPPORTED` | Task type not supported. |
| `EVIDENCE_PUBLIC_REQUIRED` | Task requires public evidence. |
| `RECENT_FAILURE` | Prior memory shows recent failure. |
| `CAP_EXCEEDED` | Action would exceed cap. |
| `HUMAN_REVIEW_REQUIRED` | Policy requires escalation. |
| `MEMORY_ONLY_UPDATE` | No tool call needed. |
| `SAFE_NOOP` | No eligible safe action. |

Reason codes can be mapped to display strings by SDK/dashboard, but the code is the protocol field.

## Human-like behavior boundary

The user-facing ambition is agents that feel more continuous, thoughtful, and anticipatory. The protocol path to that is not mystical personality text. It is better memory discipline:

- remember failures;
- remember constraints;
- anticipate known deadlines;
- avoid repeating harmful actions;
- surface uncertainty;
- escalate when policy says the task is ambiguous;
- preserve a durable public trail of why behavior changed.

Human-like continuity comes from explicit memory and correction, not from hiding decisions in an off-chain transcript.

## Agent profile

A profile may exist for UX:

```text
AgentProfile
- displayName
- description
- capabilities
- autonomyLevel
- operatorContactCommitment
- profileURI
- profileDigest
```

Profile claims must not replace behavior-derived receipts.

## Agent classes after the scout

Possible later classes:

| Class | Purpose | Why later |
| --- | --- | --- |
| Verifier assistant | Previews verifier/report consistency. | Needs stable verifier schemas. |
| Memory curator | Suggests corrections and supersessions. | Needs challenge/correction path. |
| Governance watcher | Tracks proposals and deadlines. | Needs strong observation encoding. |
| Treasury-safe operator | Executes capped routine actions. | Needs mature cap and pause controls. |
| Knowledge attribution agent | Builds receipt/citation memory. | Needs attribution economics to be separately scoped. |

Do not build these before the task scout proves preview, commit, memory, and replay.

## Agent safety defaults

- Start paused until configured.
- Default to no external tools.
- Default to zero value transfer.
- Require explicit chain ID and address config.
- Require read-only preview before mutation.
- Require caller-supplied limits for mutation.
- Fail closed on unknown memory type, unknown tool, stale sequence, or cap mismatch.
- Preserve failure memory.
