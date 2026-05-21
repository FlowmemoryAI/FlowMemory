# Memory Model

## Goal

The memory model gives agents continuity without turning contract storage into a database. It separates small public working memory from richer history and private/heavy evidence commitments.

A memory update should always answer:

1. What was remembered?
2. Why was it admitted?
3. What root did it replace?
4. Which receipt or observation caused it?
5. Who or what verified it?
6. How can it be corrected later?

## Memory categories

FlowMemory should use typed memory instead of generic transcript blobs.

| Type | Purpose | Example |
| --- | --- | --- |
| Episodic | Record concrete events and outcomes. | `task 0x12 accepted; evidence unavailable; settlement failed`. |
| Semantic | Store compact public facts and constraints. | `docs-review tasks require public evidence`. |
| Procedural | Store rules, tool policies, and operating constraints. | `never call target outside allowlist root X`. |
| Goal | Store current objective and blocked objectives. | `active goal: accept low-risk docs tasks only`. |
| Scar tissue | Store failures, slashes, reorgs, and corrections. | `task kind Y caused slash; require human review`. |
| Self-model | Store bounded public capability and limitation notes. | `kernel class: conservative task scout v1`. |

Self-model memory must stay operational and modest. It is not an excuse to store a personality transcript on-chain.

## `MemoryCell`

A `MemoryCell` is a typed memory unit. It may be public content or a commitment.

```text
MemoryCell
- memoryCellId
- agentId
- memoryType
- subject
- contentMode
- contentCommitment
- shortPublicContentHash
- sourceObservationId
- sourceReceiptId
- parentMemoryRoot
- newMemoryRoot
- verifierReportId
- status
- confidence
- createdAtBlock
- expiresAtBlock
- supersededBy
```

### Content modes

| Mode | Meaning |
| --- | --- |
| `PUBLIC_SHORT` | A deliberately public short value or label. |
| `COMMITMENT_ONLY` | Hash/root of private or heavy evidence. |
| `POINTER_COMMITMENT` | Content-addressed pointer plus digest. |
| `CONTRACT_PAGE` | Later immutable bytecode/data page. |
| `EVENT_ONLY` | Memory reconstructed from emitted events. |

Default to `COMMITMENT_ONLY` unless public readability is essential.

## `MemoryDelta`

A `MemoryDelta` is an append-only transition.

```text
MemoryDelta
- memoryDeltaId
- agentId
- sequence
- parentMemoryRoot
- deltaRoot
- newMemoryRoot
- readSetRoot
- writeSetRoot
- actionReceiptId
- sourceObservationId
- memoryCellIds
- status
```

Rules:

- parent root must equal the prior accepted root;
- new root must be derived from parent root plus delta;
- sequence increments once per committed step;
- a correction creates a new delta; it does not silently edit history;
- failed or unsupported deltas remain visible as failed/unsupported.

## Hot memory

Hot memory is contract-readable working state.

```text
HotMemory
- latestMemoryRoot
- sequence
- activeGoal
- activePolicyRoot
- activeToolAllowlistRoot
- recentMemoryRootA
- recentMemoryRootB
- lastActionReceiptId
- lastVerifierReportId
- failureCount
- spendUsedThisEpoch
```

Hot memory is for the next decision. Keep it bounded.

## Cold memory

Cold memory is historical and append-only. It may live in:

- event logs;
- Rootflow transitions;
- memory delta fixtures;
- content-addressed objects;
- SSTORE2-style contract pages later;
- Merkleized archives;
- dashboard/indexer state.

Cold memory can be queried by indexers and agents, but the contract should usually keep only roots, counters, and short commitments.

## Root construction

Use stable domains and canonical encodings from the FlowMemory crypto package where possible.

Recommended conceptual hash domains:

```text
FLOWMEMORY_AGENT_V1
FLOWMEMORY_MEMORY_CELL_V1
FLOWMEMORY_MEMORY_DELTA_V1
FLOWMEMORY_AGENT_POLICY_V1
FLOWMEMORY_AGENT_ACTION_RECEIPT_V1
```

A memory root should bind:

- chain id;
- agent id;
- sequence;
- parent root;
- memory cell ids;
- source receipt root;
- verifier status when finalized;
- schema version.

Do not hash display-only strings as canonical state unless the schema explicitly says so.

## Admission lifecycle

```text
observed
-> proposed
-> committed
-> indexed
-> verified / failed / unresolved / unsupported / reorged
-> corrected or superseded when needed
```

### `observed`

A chain event, contract state read, task state, or signed/evidence-backed input exists.

### `proposed`

Kernel preview proposes a memory delta.

### `committed`

A transaction updates memory root or emits a memory commitment event.

### `indexed`

Indexer derives receipt metadata and observation id.

### `verified`

Verifier confirms the transition under current local/test rules.

### `failed`

Verifier found a contradiction.

### `unresolved`

Required evidence is missing or unavailable.

### `unsupported`

The event or memory type is valid but outside current verifier support.

### `reorged`

The source observation is no longer canonical.

## Correction model

Memory corrections are append-only.

```text
MemoryCorrection
- correctionId
- targetMemoryCellId
- targetMemoryDeltaId
- correctionReason
- evidenceRoot
- parentMemoryRoot
- correctedMemoryRoot
- resolver
- status
```

A correction should:

- preserve the original memory and receipt;
- explain the reason code;
- point to evidence or a verifier report;
- produce a new memory root;
- mark the old cell as superseded in `AgentMemoryView`.

## Expiry and decay

On-chain memory should not rely on silent deletion. Use explicit expiry and status.

Suggested fields:

- `expiresAtBlock` for time-sensitive facts;
- `decayClass` for indexer/UI ranking;
- `supersededBy` for corrections;
- `importance` for replay/read prioritization, not truth.

Expired memory can remain part of history while being excluded from current decision reads.

## Memory privacy boundary

If it is in contract storage or event logs, it is public.

Rules:

- do not write secrets;
- do not write private prompts by default;
- do not write private user memory by accident;
- prefer public summaries only when public permanence is intended;
- use commitments for private/heavy evidence;
- document the source of any admitted off-chain fact.

## Memory read set

Each committed step should make its read set reconstructable.

Minimum read-set fields:

- agent id;
- sequence;
- current memory root;
- active policy root;
- active tool allowlist root;
- observation root;
- hot memory snapshot hash;
- candidate action set hash.

A verifier should be able to recompute whether the selected action was valid from the read set and policy.

## Memory write set

Each committed step should bind its write set.

Minimum write-set fields:

- memory type;
- subject;
- content mode;
- content commitment;
- source receipt root;
- action receipt id;
- parent root;
- new root;
- sequence.

## First task-scout memory schema

For the first fixture, use a tiny schema:

```text
TaskScoutMemory
- agentId
- taskKind
- successCount
- failureCount
- lastFailureReason
- requiresHumanReview
- maxRewardAllowed
- maxSpendAllowed
- evidenceRequirementHash
- updatedAtSequence
```

This is enough to prove useful memory:

- remember prior failures;
- avoid unsupported task classes;
- keep budget/cap state;
- explain why a task was accepted or rejected.

## What not to store first

- long chat transcripts;
- full documents;
- embeddings;
- image or media content;
- raw model completions;
- private operator notes;
- API keys, RPC URLs, private keys, seed phrases, or webhook URLs;
- unrestricted personality memory.
