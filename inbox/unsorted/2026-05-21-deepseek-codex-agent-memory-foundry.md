# 2026-05-21 DeepSeek + Codex Agent Memory Foundry

## Raw thought

Use the Quill-shaped pattern, but for AI-agent memory instead of on-chain language-model inference.

Quill’s useful idea is: fixed object class, compact on-chain data, one shared deterministic engine, free read path, paid/permanent inscription path, and public replayability.

The FlowMemory version should be:

> A memory foundry where Codex turns raw work into canonical memory deltas, DeepSeek-style review attacks the claims and boundaries, and FlowMemory commits only compact roots, receipts, verifier reports, and agent-readable state.

The chain does not run DeepSeek or Codex. The chain does not store full memory. The chain anchors the memory lineage so future agents can reconstruct what was known, what was challenged, what was accepted, and what still needs work.

## Correction from follow-up

The user clarified the stronger target after this note was written: they are thinking about **actual on-chain AI agents with on-chain memory**, using existing blockchain infrastructure, not only off-chain agents with on-chain commitments.

A corrected architecture note now exists at `inbox/unsorted/2026-05-21-onchain-ai-agents-with-onchain-memory.md`. Treat that as the sharper follow-on direction. This note remains useful for the Codex/DeepSeek distillation-review workflow, but it is more conservative than the user’s intended product shape.

## Source links and inputs

- Quill home: https://quill.computer/
- Quill docs: https://quill.computer/docs
- Quill how it works: https://quill.computer/#how-it-works
- Prior local note: `inbox/unsorted/2026-05-21-quill-for-onchain-agent-memory.md`
- Existing FlowMemory objects: `MemorySignal`, `MemoryReceipt`, `RootflowTransition`, `RootfieldBundle`, `AgentMemoryView`
- Existing Local Alpha objects: `AgentAccount`, `MemoryCell`, `WorkReceipt`, verifier reports, signature envelopes
- Existing DeepSeek-review pattern in the repo: conservative pushback, adversarial coverage, invariant focus, operational transition skepticism

## Working name

**Agent Memory Foundry**

Other possible names:

- RootMemory Foundry
- Memory Forge
- Agent Recall Spine
- FlowMemory Foundry

Use **Agent Memory Foundry** for now because it says what it does without implying new tokenomics, public mainnet, or AI-on-chain inference.

## One-line product idea

A user or agent can drop raw ideas, runs, prompts, reviews, or code-session outcomes into FlowMemory; Codex distills them into canonical memory deltas; DeepSeek-style review attacks the assumptions; FlowMemory commits the resulting memory roots and receipts so later agents can replay the project’s memory instead of starting from scattered chat history.

## What DeepSeek and Codex do

### Codex role

Codex is the builder and canonicalizer.

It should:

1. read the raw idea, links, files, and current project state;
2. extract claims, requirements, boundaries, open questions, and next steps;
3. map the idea onto existing FlowMemory objects before proposing new ones;
4. produce deterministic, schema-shaped memory deltas;
5. update docs, fixtures, tests, or implementation when work is explicitly scoped;
6. emit a `WorkReceipt`-like record that says what changed and what was verified.

Codex should not be trusted just because it wrote the summary. Its output becomes evidence to verify, not truth by default.

### DeepSeek role

DeepSeek is the skeptic and adversarial reviewer.

It should:

1. find overclaims, missing invariants, and unsafe shortcuts;
2. challenge whether the idea accidentally becomes tokenomics, public validator work, production mainnet, or AI-on-chain claims;
3. look for privacy leaks in evidence and memory summaries;
4. ask what breaks under hostile agents, stale memory, reorgs, unavailable evidence, or colluding operators;
5. separate repo-side blockers from external blockers;
6. produce a `ReviewReceipt`-like record with accepted objections, rejected objections, and unresolved risks.

DeepSeek should not be trusted just because it is skeptical. Its review also becomes evidence to verify.

### FlowMemory role

FlowMemory is the memory spine.

It should:

1. store raw heavy material off-chain;
2. hash and canonicalize compact memory objects;
3. emit or ingest compact FlowPulse/fixture signals;
4. derive `MemorySignal`, `MemoryReceipt`, and `RootflowTransition` objects;
5. expose `AgentMemoryView` for future agent runs;
6. preserve correction history instead of rewriting memory.

## How it would work

### 1. Intake: raw idea dump

A user drops raw material into `inbox/unsorted/` or a UI equivalent:

- links;
- pasted model output;
- screenshots or references;
- operator notes;
- unfinished product ideas;
- failed runs;
- code review findings;
- agent handoffs.

The raw dump is explicitly not accepted architecture. It is just source material.

Output:

```text
RawIdeaDump
- local path or evidence URI
- source link list
- author or agent
- created time
- rough scope tag
```

On-chain state: none yet.

### 2. Codex distillation: idea packet

Codex reads the raw dump and creates an **IdeaPacket**:

```text
IdeaPacket
- ideaId
- title
- sourceRefs
- claims
- nonClaims
- existingSurfacesToCheck
- proposedFlowMemoryMapping
- offChainData
- onChainCommitments
- indexerVerifierStory
- openQuestions
- smallestNextStep
```

The packet is deterministic enough to hash, but it still points back to raw context.

Output roots:

- `ideaPacketHash`
- `sourceRefsRoot`
- `claimSetRoot`
- `openQuestionsRoot`

On-chain state: optional root commitment only if the user wants to preserve the idea lineage.

### 3. DeepSeek review: adversarial pass

DeepSeek-style review reads the IdeaPacket and produces an **AdversarialReviewPacket**:

```text
AdversarialReviewPacket
- reviewId
- reviewedIdeaId
- modelOrAgent
- overclaimFindings
- securityFindings
- privacyFindings
- missingEvidence
- scopeExpansionRisks
- verifierGaps
- recommendedNarrowing
- requiredTestsOrChecks
- unresolvedBlockers
```

This is the same pattern as the repo’s existing DeepSeek review artifact: conservative pushback is useful because it catches optimism before it becomes architecture.

Output roots:

- `reviewPacketHash`
- `findingRoot`
- `requiredChecksRoot`

On-chain state: still optional; if committed, it is a review commitment, not proof that the review is correct.

### 4. Codex reconciliation: memory delta candidate

Codex reconciles the idea and review into a **MemoryDeltaCandidate**:

```text
MemoryDeltaCandidate
- deltaId
- parentMemoryRoot
- acceptedClaims
- rejectedClaims
- unresolvedClaims
- changedBoundaries
- newOpenQuestions
- nextAction
- evidenceRefs
- reviewRefs
```

This is the first object that looks like actual memory. It states what the project should remember next time.

Important rule: memory updates are append-only. If a claim is wrong, later deltas correct or retract it. The old delta stays part of the record.

Output roots:

- `memoryDeltaRoot`
- `acceptedClaimsRoot`
- `rejectedClaimsRoot`
- `unresolvedClaimsRoot`
- `evidenceRefsRoot`

### 5. Local verifier: deterministic checks

A local/test verifier checks the candidate before it becomes accepted memory.

Minimum checks:

1. all source references exist or are explicitly marked unavailable;
2. no secret-shaped values are included;
3. no prohibited claims are present:
   - AI runs on-chain;
   - all memory is stored on-chain;
   - storage is free;
   - V0 is production trustless verification;
   - public validator or tokenomics claims;
4. every accepted claim has evidence or is marked as inference;
5. every open question remains open unless evidence resolves it;
6. the object hashes recompute;
7. the parent memory root matches the previous accepted state.

Output:

```text
VerifierReport
- verifierReportId
- targetDeltaId
- status: pending | verified | failed | reorged | unsupported
- failedChecks
- evidenceRefs
- computedRoots
```

On-chain state: compact verifier report commitment if scoped.

### 6. FlowPulse / Rootfield commitment

If the user wants durable public lineage, the system commits the memory delta root into a Rootfield namespace.

Possible namespace policy:

```text
rootfieldId = hash("flowmemory.agent_memory", projectId, agentOrUserNamespace)
```

V0 should prefer existing root commitment semantics before adding new contract pulse types. A later accepted design could add a specific pulse type like `AGENT_MEMORY_COMMITTED`, but this note does not require it.

On-chain/log fields should stay compact:

```text
FlowPulse
- pulseId
- rootfieldId
- actor
- pulseType: ROOT_COMMITTED or later AGENT_MEMORY_COMMITTED
- subject: memoryCellId or ideaId
- commitment: memoryDeltaRoot or newMemoryRoot
- parentPulseId
- sequence
- occurredAt
- uri: short pointer only when intentionally public
```

The contract still cannot know `txHash` or `logIndex`. The indexer adds those after reading receipts/logs.

### 7. Indexer reconstruction

The indexer observes the FlowPulse and reconstructs:

```text
FlowPulse observation
-> MemorySignal
-> MemoryReceipt
-> RootflowTransition
-> RootfieldBundle
-> AgentMemoryView
```

For this idea:

- `MemorySignal` says a memory commitment happened.
- `MemoryReceipt` links the signal to the off-chain IdeaPacket, ReviewPacket, and MemoryDeltaCandidate roots.
- `RootflowTransition` moves parent memory root to new memory root.
- `RootfieldBundle` gives the current state for the memory namespace.
- `AgentMemoryView` tells the next agent what it can safely use.

### 8. Retrieval: agent reads memory before work

Before a new Codex or DeepSeek run starts, it reads the current `AgentMemoryView`:

```text
AgentMemoryView
- verified memory deltas
- pending deltas
- failed or rejected claims
- open questions
- limitations
- source refs
- next smallest action
```

This is the FlowMemory equivalent of Quill’s free `generate` path: a low-friction read path that lets agents benefit from the public committed state without writing new state.

The read path can start as local JSON and fixture-backed dashboard/API output. It does not need new on-chain compute.

### 9. Correction: false memory handling

If a future agent finds a bad memory:

1. create a new raw correction note;
2. Codex distills it into a correction IdeaPacket;
3. DeepSeek-style review tests the correction;
4. verifier checks that the correction references the old delta;
5. Rootflow creates a new transition that marks the prior claim as corrected, superseded, or failed.

Do not delete history. Do not mutate old accepted memory in place.

## Data objects, concept only

These are conceptual names for the idea. They are not approved schemas yet.

### `IdeaPacket`

Smallest structured form of an idea after Codex distillation.

Important fields:

- `ideaId`
- `title`
- `sourceRefsRoot`
- `claimSetRoot`
- `boundaryRoot`
- `openQuestionsRoot`
- `flowMemoryMappingRoot`

### `AdversarialReviewPacket`

DeepSeek-style critique of an IdeaPacket.

Important fields:

- `reviewId`
- `reviewedIdeaId`
- `findingRoot`
- `missingEvidenceRoot`
- `scopeRiskRoot`
- `requiredChecksRoot`

### `MemoryDeltaCandidate`

Candidate update to project/agent memory.

Important fields:

- `deltaId`
- `parentMemoryRoot`
- `newMemoryRoot`
- `acceptedClaimsRoot`
- `rejectedClaimsRoot`
- `unresolvedClaimsRoot`
- `evidenceRefsRoot`
- `reviewRefsRoot`

### `AgentRecallView`

Possible future richer form of `AgentMemoryView` specialized for agent bootstrapping.

Important fields:

- `rootfieldId`
- `currentMemoryRoot`
- `usableClaims`
- `doNotClaim`
- `openQuestions`
- `knownRisks`
- `nextActions`
- `limitations`

## How it maps to existing FlowMemory surfaces

### `AgentAccount`

Use for stable agent identity if later needed. Codex, DeepSeek, verifier, and operator agents can each have an agent id or signer policy. This is a local/test identity concept first, not a public validator system.

### `MemoryCell`

Best existing fit for the actual memory state:

- `currentMemoryRoot` = latest accepted memory root;
- `previousMemoryRoot` = parent root;
- `lastDeltaRoot` = most recent memory delta;
- `sourceReceiptsRoot` = root of Codex/DeepSeek/work receipts;
- `dependencyRoot` = source links, parent ideas, or required context.

### `WorkReceipt`

Best fit for Codex work output:

- distillation completed;
- files read;
- docs changed;
- checks run;
- output hash.

### `VerifierReport`

Best fit for the local verifier status:

- accepted;
- failed;
- unresolved;
- unsupported;
- reorged.

### `MemorySignal`

Best fit for the indexed event:

- “a memory root was committed”;
- “a memory review was attached”;
- “a correction superseded a previous memory root.”

### `MemoryReceipt`

Best fit for the evidence linkage:

- source refs;
- raw dump hash;
- Codex packet hash;
- DeepSeek review hash;
- verifier report id.

### `RootflowTransition`

Best fit for the state update:

- previous memory root to new memory root;
- status;
- sequence;
- event reference.

### `AgentMemoryView`

Best fit for the next-run bootstrap view:

- accepted project memory;
- known false claims;
- pending claims;
- limitations;
- next useful action.

## Example: the Quill-inspired idea

### Raw input

User shares Quill links and says the idea is “for memory and for AI agents like on-chain.”

### Codex output

Accepted interpretation:

- Quill is a useful analogy for deterministic commitment/replay.
- FlowMemory should not claim on-chain AI inference.
- Heavy memory must remain off-chain.
- Existing Flow Memory V0 objects should be checked before creating new protocol surface.

### DeepSeek-style objections

Likely objections:

- This can accidentally become tokenomics if copied from Quill.
- Permanent public summaries can leak private memory.
- “DeepSeek + Codex” outputs can both hallucinate unless tied to evidence.
- A memory root is useless unless a verifier can reconstruct what it means.
- Correction semantics are mandatory because agents can commit false memory.

### Reconciled memory delta

Project should remember:

- Build an agent-memory commitment pipeline, not an on-chain LLM.
- Use Codex for distillation and implementation.
- Use DeepSeek-style review for adversarial critique.
- Commit roots/receipts/status only.
- Start fixture-backed; no production contracts until schemas prove insufficient.

## User experience

### Operator view

1. Paste an idea or link into FlowMemory.
2. Click “Distill with Codex.”
3. Click “Review with DeepSeek.”
4. See accepted claims, rejected claims, risks, and open questions.
5. Choose:
   - keep private/local only;
   - commit root to local/test FlowMemory;
   - publish short public summary if explicitly intended.

### Agent view

Before work:

1. load `AgentMemoryView`;
2. see relevant accepted memory;
3. see things not to claim;
4. see open questions;
5. continue from the next action instead of re-discovering context.

After work:

1. write a WorkReceipt;
2. propose a memory delta;
3. wait for review/verifier status;
4. update the namespace root if accepted.

### Dashboard view

Show:

- memory namespace list;
- idea lineage;
- Codex distillation receipts;
- DeepSeek review receipts;
- accepted/rejected/unresolved claims;
- memory root timeline;
- current AgentMemoryView JSON;
- correction history.

## Invariants

- Raw memory is not on-chain.
- Every accepted memory delta has a parent root.
- Every accepted claim has evidence or is explicitly marked as inference.
- Every DeepSeek objection is either accepted, rejected with evidence, or left unresolved.
- A false memory is corrected by appending a new delta, not by mutating history.
- The current agent view must expose limitations and open questions.
- The indexer, not the contract, supplies `txHash` and `logIndex`.
- No model output is trusted without a receipt and verifier status.
- No new production contract is required for the first local/test version.

## MVP path

### MVP 0: docs-only intake

- Keep raw ideas in `inbox/unsorted/`.
- Use this note as the product concept.
- Manually write Codex distillation and DeepSeek-style review sections.
- No schemas, no contracts, no generated fixtures.

### MVP 1: local fixture prototype

- Add sample JSON fixture for one idea packet, review packet, memory delta, and agent recall view.
- Validate secret scanning and prohibited claims.
- Generate an `AgentMemoryView` from the fixture.
- No contract changes.

### MVP 2: Flow Memory V0 mapping

- Convert the fixture into existing `MemorySignal`, `MemoryReceipt`, `RootflowTransition`, `RootfieldBundle`, and `AgentMemoryView` output.
- Use existing launch-core generator patterns.
- Add dashboard display only if the data shape proves useful.
- Still no production claims.

### MVP 3: local/test root commitment

- Use existing Rootfield root commitment path to anchor one memory namespace in local/test fixtures.
- Index and verify it through the existing V0 pipeline.
- Document exactly what is committed and what remains off-chain.

### Later gated work

Only after MVPs prove value:

- dedicated agent-memory pulse type;
- dedicated schemas for `IdeaPacket`, `AdversarialReviewPacket`, and `MemoryDeltaCandidate`;
- signed model/agent review envelopes;
- privacy-preserving evidence commitments;
- production verifier policy;
- public commitment UX.

## Hard boundaries

- Do not claim FlowMemory runs DeepSeek or Codex on-chain.
- Do not store raw prompts, transcripts, embeddings, model outputs, or private evidence on-chain.
- Do not copy Quill tokenomics into FlowMemory.
- Do not create a public token, public validator plan, or bridge scope from this idea.
- Do not call local/test verifier output a production trustless proof.
- Do not commit private user memory publicly by default.
- Do not let “agent memory” become an excuse to preserve secrets.

## Open questions

1. Should DeepSeek and Codex outputs be signed by agent keys, operator keys, or only hashed as local evidence?
2. Should the first memory namespace be project-wide, user-owned, per-agent, or per-idea?
3. What is the minimum useful `AgentMemoryView` for a future Codex run?
4. How should private source evidence be referenced without leaking it?
5. Should review packets be mandatory before a memory delta can become verified?
6. What status should apply when DeepSeek and Codex disagree and no verifier can resolve the conflict?
7. Can existing `MemoryCell` cover this fully, or does the project need a dedicated `IdeaMemoryCell` later?
8. How much of the correction flow belongs in schemas versus verifier logic?
9. What should be visible in a public dashboard versus local-only operator UI?
10. How do we prevent stale accepted memory from steering future agents incorrectly?

## Smallest useful next step

Create one local fixture by hand for the Quill-inspired idea:

1. raw source refs;
2. Codex idea packet;
3. DeepSeek-style adversarial review packet;
4. reconciled memory delta;
5. generated agent recall view.

Then compare that fixture to existing `MemoryCell`, `MemorySignal`, `MemoryReceipt`, `RootflowTransition`, `RootfieldBundle`, and `AgentMemoryView` schemas before adding any new schema or contract surface.
