# Verification and Replay

## Goal

Replay is the trust story. A reviewer should not need to believe an agent, gateway, or dashboard. They should be able to reconstruct the transition from public contract state, receipts, logs, schemas, and admitted evidence.

## Replay question

For every committed step, answer:

```text
Given the prior agent state and observation,
did the deterministic kernel select this action,
did the router enforce policy and caps,
did the memory delta follow from the receipt,
and does the projected AgentMemoryView reflect the result?
```

## Replay inputs

Minimum inputs:

- chain id;
- contract addresses;
- agent id;
- transaction receipt;
- FlowPulse logs;
- agent-specific events;
- prior agent config;
- prior hot memory;
- parent memory root;
- observation root;
- kernel address/class and policy root;
- expected tool allowlist root;
- action receipt;
- memory delta commitment;
- verifier rules version.

Optional inputs:

- content-addressed evidence;
- signed envelopes;
- off-chain review digests;
- dashboard fixture state;
- challenge/correction records.

## What contracts know vs what indexers derive

Contracts know during execution:

- `msg.sender`;
- current contract storage;
- input parameters;
- call success/failure;
- emitted event payload;
- block fields available in EVM.

Contracts do not know final receipt metadata such as transaction hash and log index during execution.

Indexers derive after execution:

- transaction hash;
- log index;
- block number;
- block hash;
- event ordering;
- canonical/reorg status;
- observation id.

This split must remain visible in schemas and docs.

## Replay pipeline

```text
1. Read transaction receipt.
2. Decode FlowPulse and agent events.
3. Derive observation id from chain id, tx hash, log index, address, event signature, and payload hash.
4. Load prior indexed agent state.
5. Rebuild kernel input.
6. Recompute or validate kernel output.
7. Check router/tool policy.
8. Check action receipt.
9. Check memory parent root and new root.
10. Produce verifier report.
11. Project RootflowTransition.
12. Project AgentMemoryView.
```

## Observation identity

Observation identity should be derived from receipt data, not from a contract-supplied transaction hash.

Conceptual fields:

```text
ObservationIdentity
- chainId
- contractAddress
- blockNumber
- blockHash
- transactionHash
- logIndex
- eventSignature
- payloadHash
```

Use existing `services/shared` and crypto helpers where possible.

## Verifier report

```text
VerifierReport
- verifierReportId
- verifierRulesVersion
- observationId
- agentId
- actionReceiptId
- memoryDeltaId
- parentMemoryRoot
- newMemoryRoot
- status
- checks
- evidenceRoot
- createdAt
```

Check result:

```text
ReplayCheck
- name
- status: pass | fail | not_applicable
- expected
- actual
- detail
```

## Required checks

| Check | Failure status |
| --- | --- |
| Event ABI matches expected schema | `failed` or `unsupported` |
| Chain id and contract address match configured surface | `failed` |
| Agent exists and was active at sequence | `failed` |
| Parent memory root matches prior state | `failed` |
| Kernel input hash matches event/receipt fields | `failed` |
| Kernel output matches committed action | `failed` |
| Tool target and selector are allowlisted | `failed` |
| Value and epoch caps are respected | `failed` |
| External call result is recorded | `failed` if hidden or inconsistent |
| Memory delta root is non-zero and schema-valid | `failed` |
| New memory root matches parent plus delta | `failed` |
| Evidence commitment resolves when required | `unresolved` |
| Event is known but verifier lacks support | `unsupported` |
| Source receipt is no longer canonical | `reorged` |

## Status semantics

Reuse FlowMemory status vocabulary.

| Status | Meaning |
| --- | --- |
| `pending` | Indexed but not verified. |
| `verified` | All applicable checks pass. |
| `failed` | A required check fails. |
| `unresolved` | Required evidence is missing or unavailable. |
| `unsupported` | The event or memory type is valid but outside current verifier support. |
| `reorged` | The source observation is no longer canonical. |

Do not use `verified` as a synonym for true in the abstract. It means verified by the named ruleset and evidence available to that verifier.

## Rootflow transition projection

```text
RootflowTransition
- transitionId
- agentId
- chainId
- sourceObservationId
- parentRoot
- newRoot
- actionReceiptId
- verifierReportId
- status
- sequence
- pulseId
- contractEventRef
- createdAtBlock
```

The transition is the bridge between raw contract events and memory views.

## Agent memory view projection

`AgentMemoryView` should separate current usable memory from history.

```text
AgentMemoryView
- agentId
- latestMemoryRoot
- sequence
- activeGoal
- hotMemory
- verifiedMemory
- pendingMemory
- failedMemory
- correctedMemory
- staleOrExpiredMemory
- recentActions
- nextActionPreview
- replayWarnings
```

A failed or corrected memory does not disappear. It moves to the right bucket.

## Reorg handling

If a receipt/log is no longer canonical:

1. mark derived observation as `reorged`;
2. mark dependent verifier reports and transitions as `reorged` or superseded;
3. rebuild `AgentMemoryView` from canonical observations;
4. preserve historical record for operator review;
5. never silently keep a memory root derived from non-canonical data.

## Challenge handling

A challenge is a claim that a memory cell or transition should not be treated as current verified memory.

Minimum challenge record:

```text
MemoryChallenge
- challengeId
- targetMemoryCellId
- targetTransitionId
- challenger
- evidenceRoot
- reasonCode
- status
- resolutionReportId
```

Challenge outcomes:

- accepted: create correction transition;
- rejected: retain original memory;
- unresolved: show warning in `AgentMemoryView`;
- unsupported: mark as not currently verifiable.

## Local/test replay fixture

The first fixture should include:

1. registered task-scout agent;
2. parent memory root;
3. observed task;
4. preview output;
5. committed step event;
6. action receipt;
7. memory delta;
8. verifier report;
9. Rootflow transition;
10. AgentMemoryView.

The fixture should make it impossible to pass verification if:

- the task kind is changed;
- the parent memory root is changed;
- the action is changed;
- the tool target is changed;
- the memory delta is changed;
- the evidence requirement is removed;
- the sequence is stale.

## External review admission

External model review can produce useful architecture critique, but a model transcript is not automatically verifier evidence.

To admit review output:

1. summarize the review into a bounded artifact;
2. hash it with a stable schema;
3. record reviewer/model/source metadata if appropriate;
4. reconcile contradictions manually;
5. commit only the accepted digest or memory delta;
6. keep private prompts out of public memory unless intentionally public.

## Replay success standard

A replay is successful when an independent process can reproduce:

- selected action;
- reason code;
- cap decision;
- action receipt id;
- memory delta id;
- new memory root;
- verifier status;
- projected `AgentMemoryView` bucket changes.
