# Architecture

## Design target

The design target is a Base-first, replayable agent memory kernel. It should let a bounded autonomous agent operate through contracts while keeping enough state public and structured that another party can reconstruct the decision and memory transition.

The architecture favors boring deterministic machinery over vague autonomy claims:

- fixed agent classes;
- explicit policy roots;
- compact hot memory;
- append-only memory deltas;
- small action enums;
- allowlisted tools;
- receipts before interpretation;
- verifier status after reconstruction.

## Layer map

```text
Developer / Operator
  |
SDK and CLI
  |
Contracts on Base or local/test chain
  |-- AgentRegistry
  |-- AgentMemoryStore
  |-- AgentKernel / kernel modules
  |-- AgentToolRouter
  |-- FlowPulse emitter
  |
Receipts and logs
  |
Indexer
  |
Verifier / replay engine
  |
RootflowTransition + AgentMemoryView
  |
Dashboard / explorer / agent bootstrap
```

## Chain-side contract layer

The contract layer owns compact state only.

Responsibilities:

- register agents and their kernel/policy/memory roots;
- expose read-only preview of the next action when possible;
- enforce sequence, cap, status, and allowlist checks;
- commit memory deltas and action receipts;
- emit FlowPulse for agent and memory events;
- expose enough read methods for SDKs and indexers.

Boundaries:

- no secret storage;
- no heavy model or transcript storage by default;
- no dependency on `txHash` or `logIndex` during execution;
- no unrestricted external calls;
- no broad social/economic features in the first build.

## Memory layer

Memory is split into hot state and cold history.

### Hot memory

Hot memory is the bounded working set an agent needs for the next decision:

- `latestMemoryRoot`;
- `sequence`;
- active task id or goal id;
- active policy root;
- active tool allowlist root;
- recent memory hashes;
- failure counters;
- spend/cap counters;
- last verifier report id.

Hot memory must be small enough that a contract read and preview path remains realistic.

### Cold memory

Cold memory is the append-only history behind the current root:

- FlowPulse logs;
- memory delta events;
- content-addressed pointers;
- SSTORE2-style immutable pages later if justified;
- Merkleized archives;
- off-chain evidence commitments.

Cold memory can be richer, but the contract should usually store roots and short typed public cells rather than raw large content.

## Agent kernel layer

A kernel is a deterministic decision function with a small input and a small output.

```text
KernelInput:
  agent id
  current policy root
  current memory root
  hot memory snapshot
  observation commitment or typed observation
  candidate action set

KernelOutput:
  action enum
  tool id
  target contract
  encoded parameters hash
  memory delta root
  reason code
  expected cap usage
```

### Kernel classes

1. **Rule kernel** — safest first option. Uses explicit conditions and reason codes.
2. **Scoring kernel** — integer weights score candidate actions after rules gate eligibility.
3. **Hybrid rule-gated scorer** — recommended first serious kernel.
4. **Tiny fixed-shape model kernel** — later; only for bounded classification or ranking.

A kernel must not produce an unrestricted external call. It selects from an action enum and tool ids declared in policy.

## Preview and commit

The preview path is the developer and operator superpower.

```text
previewStep(agentId, observation)
  -> reads current state
  -> runs deterministic kernel in view/static context
  -> returns candidate action, memory delta hash, reason code, and cap impact
```

The commit path must match the preview inputs.

```text
step(agentId, observation, previewCommitment, limits)
  -> checks agent status and nonce
  -> recomputes or validates kernel output
  -> checks tool allowlist and caps
  -> executes action or records no-op/escalation
  -> commits MemoryDelta
  -> emits FlowPulse
  -> updates roots and sequence
```

A caller should be able to preview without paying for mutation and then commit only if the output is acceptable.

## Tool and action routing

The router is a safety boundary, not a convenience wrapper.

Rules:

- only registered agents can route actions;
- only active policies can authorize actions;
- targets and selectors must be allowlisted;
- value transfer must be capped;
- per-action and per-epoch budgets must be enforced;
- failed calls must be observable and become memory;
- escalation/no-op must be first-class outputs, not hidden failures.

Initial action enum for the On-Chain Task Scout:

| Action | Meaning |
| --- | --- |
| `NOOP` | No safe action. |
| `ESCALATE` | Requires human/off-chain review before mutation. |
| `ACCEPT_TASK` | Accept a bounded task through an allowed task contract. |
| `REJECT_TASK` | Record why a task is not eligible. |
| `COMMIT_EVIDENCE` | Commit evidence pointer/root. |
| `UPDATE_MEMORY_ONLY` | Update memory after an observed outcome without external tool call. |
| `PAUSE_SELF` | Enter safe mode after a policy or memory failure. |

## Rootflow lifecycle

```text
Parent memory root
  + Observation
  + Kernel output
  + Action receipt
  + Memory delta
  + Verifier report
= RootflowTransition
  -> new memory root
  -> AgentMemoryView projection
```

Every transition should record:

- parent root;
- new root;
- agent id;
- sequence;
- source observation id;
- action receipt id;
- verifier report id or pending marker;
- status;
- supersedes/corrects pointer when needed.

## Indexer layer

The indexer reconstructs what contracts cannot know during execution:

- transaction hash;
- log index;
- block number and block hash;
- chain id;
- event ordering;
- duplicate/reorg state;
- observation id.

It should never assume the contract knew final receipt metadata. It reads receipts and logs after the fact and constructs canonical observations for verifier input.

## Verifier layer

The verifier is deterministic and status-oriented.

Minimum checks:

- event ABI and pulse type match expected schema;
- agent id and sequence are valid;
- parent root matches indexed prior state;
- memory delta hash matches submitted content or commitment;
- action route matches policy and kernel output;
- cap accounting is consistent;
- failure/no-op/escalation statuses are preserved;
- supersession and correction links are well-formed.

Statuses should reuse existing FlowMemory vocabulary where possible: `pending`, `verified`, `failed`, `unresolved`, `unsupported`, and `reorged`.

## SDK layer

The SDK should make the state machine easy to use without hiding trust boundaries.

Primary responsibilities:

- connect to configured chain and contract addresses;
- read agent, policy, memory, and verifier state;
- encode observations;
- call `previewStep` through `eth_call`;
- send `step` transactions when allowed;
- decode FlowPulse and agent-specific events;
- reconstruct local replay traces;
- expose `AgentMemoryView` objects for apps and agents.

The SDK should not silently mutate state from a preview helper.

## Dashboard and explorer layer

The dashboard is the human review surface.

It should show:

- agent identity and status;
- current memory root and sequence;
- hot memory slots;
- policy and tool roots;
- previewed next action;
- recent action receipts;
- failed, corrected, stale, unsupported, and reorged memories;
- verifier statuses;
- replay trace from parent root to new root.

## Data flow

```text
1. Task contract emits or exposes an open task.
2. SDK/indexer builds a typed observation.
3. Agent preview reads memory and returns action candidate.
4. Caller commits step with tight limits.
5. Router executes allowed action or records no-op/escalation.
6. Memory store commits delta and updates root.
7. FlowPulse emits agent step and memory commit events.
8. Indexer derives receipt metadata and observation ids.
9. Verifier checks root/action/policy consistency.
10. AgentMemoryView updates for humans and future agents.
```

## Failure modes

| Failure | Required behavior |
| --- | --- |
| Kernel output differs between preview and commit | Reject or record failed transition without executing unsafe action. |
| Tool target is not allowlisted | Reject before external call. |
| Cap exceeded | Reject or pause depending on policy. |
| Memory parent root stale | Reject and require caller to refresh state. |
| External action reverts | Emit/record failure memory if safe; do not hide it. |
| Evidence unavailable | Mark unresolved or failed; preserve receipt. |
| Reorg | Mark affected observations reorged and project corrected view. |
| Verifier unsupported | Keep transition visible as unsupported, not verified. |
| Memory poisoning attempt | Challenge/correct through append-only supersession. |
| Admin pause | Stop mutations but keep reads and replay available. |

## Upgrade boundaries

Early local/test contracts may be simple and owner-controlled. Any later public surface must make upgrade choices explicit per contract:

- immutable primitive;
- local/test scaffold;
- owner-controlled pilot;
- governed upgradeable surface.

Docs, SDK, and dashboards must show which category each address belongs to.

## External model review lane

External model reviewers and other off-chain analysis tools can help design and review policies, generate test cases, compress rules, and attack the architecture. Their transcripts are not protocol state unless a signed digest, review result, or evidence commitment is deliberately admitted.

Use external models as compilers and auditors. The committed chain-side agent remains a deterministic bounded state machine.
