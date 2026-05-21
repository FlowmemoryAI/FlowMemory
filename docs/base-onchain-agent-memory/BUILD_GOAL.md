# Build Goal: Base On-Chain Agent Memory

## Copy-ready principal goal

```text
You are the principal architect, protocol engineer, SDK owner, verifier designer, and documentation lead for FlowMemory's Base On-Chain Agent Memory workstream.

Read first:
- AGENTS.md
- docs/START_HERE.md
- docs/FLOWMEMORY_HQ_CONTEXT.md
- docs/CURRENT_STATE.md
- docs/ARCHITECTURE.md
- docs/ROOTFLOW_V0.md
- docs/FLOW_MEMORY_V0.md
- docs/V0_LAUNCH_ACCEPTANCE.md
- docs/base-onchain-agent-memory/README.md
- docs/base-onchain-agent-memory/OVERVIEW.md
- docs/base-onchain-agent-memory/ARCHITECTURE.md
- docs/base-onchain-agent-memory/SMART_CONTRACTS.md
- docs/base-onchain-agent-memory/SDK_RUNTIME.md
- docs/base-onchain-agent-memory/MEMORY_MODEL.md
- docs/base-onchain-agent-memory/AGENT_MODEL.md
- docs/base-onchain-agent-memory/VERIFICATION_REPLAY.md
- docs/base-onchain-agent-memory/SECURITY_TRUST_BOUNDARIES.md
- docs/base-onchain-agent-memory/DATA_FLOW.md
- docs/base-onchain-agent-memory/LOCAL_DEV_AND_SIMULATION.md
- docs/base-onchain-agent-memory/EXAMPLES.md
- docs/base-onchain-agent-memory/ACCEPTANCE_MATRIX.md
- inbox/unsorted/2026-05-21-onchain-ai-agents-with-onchain-memory.md
- inbox/unsorted/2026-05-21-nookplot-agent-coordination-research.md
- inbox/unsorted/2026-05-21-quill-for-onchain-agent-memory.md

Mission:
Build FlowMemory into the Base-native memory and replay kernel for autonomous agents. The first product is an On-Chain Task Scout: a bounded deterministic agent that reads task/bond state, reads public memory, previews its next step, commits only allowed actions, writes typed memory deltas, emits FlowPulse, and exposes replayable RootflowTransition and AgentMemoryView outputs.

The product must be better than broad coordination stacks at one specific thing: chain-side memory and deterministic replay for agent action. Do not clone social feeds, broad marketplaces, mining, tokenomics, or hosted gateway memory.

Non-negotiable boundaries:
- Keep heavy AI/model/memory artifacts off-chain unless deliberately reduced to compact public state or commitments.
- Do not write secrets or private memory into public storage/logs.
- Do not market gateway-backed memory as chain-resident memory.
- Do not add tokenomics or broad marketplace features.
- Do not claim production or mainnet readiness.
- Contracts must not assume txHash or logIndex during execution.
- Indexers derive receipt metadata after execution.
- Every mutation must be replayable from state, receipts, events, and admitted evidence.

Required deliverables:
1. Fixture-only MVP proving the complete task-scout memory loop.
2. Local/test contracts for agent registry, memory store, deterministic kernel, and step/tool router.
3. Foundry tests for preview/commit parity, stale sequence, memory root, allowlist, caps, pause, and event replay fields.
4. Schemas and crypto helpers for agent config, hot memory, task observation, preview, action receipt, memory delta, verifier report, RootflowTransition, and AgentMemoryView.
5. Indexer/verifier updates to decode events, derive observation ids, verify transitions, and project memory views.
6. SDK helpers for config, reads, observation encoding, preview, step, event decoding, replay, and errors.
7. Example flow that registers or loads a task scout, previews a task, commits a step, replays the receipt, and prints AgentMemoryView.
8. Dashboard/explorer fixture view for agent status, memory roots, memory buckets, recent actions, verifier status, and replay trace.
9. Professional docs kept consistent with implementation.
10. Acceptance matrix updated with evidence.

Implementation order:
1. Preserve existing launch-core commands and tests.
2. Add deterministic fixture and schemas before contracts.
3. Add local/test contracts and Foundry tests.
4. Add indexer/verifier replay path.
5. Add SDK helpers and example.
6. Add dashboard fixture projection.
7. Run area-specific checks and claim guardrails.
8. Only then plan Base Sepolia rehearsal.

External model review:
Use GPT, DeepSeek, Codex, or another off-chain model as an architecture critic if configured locally. Do not store API keys. Do not paste secrets. Convert accepted model feedback into concrete tests, docs, issue notes, or deterministic policy changes. Raw model output is not protocol evidence unless summarized, hashed, and intentionally admitted.

Definition of done:
A reviewer can run the local/test path and see a complete, deterministic, replayable task-scout step: prior memory root, observation, preview output, committed action, action receipt, memory delta, FlowPulse, indexed observation, verifier report, RootflowTransition, AgentMemoryView, and docs explaining every trust boundary.
```

## Decomposition tracks

| Track | Owns | Must not own |
| --- | --- | --- |
| HQ | sequencing, acceptance, cross-links, risk log | implementation shortcuts |
| Contracts | registry, memory store, kernel, router, tests | SDK, dashboard, tokenomics |
| Crypto/schemas | domains, canonical ids, schemas, vectors | proof circuits unless separately scoped |
| Indexer/verifier | event decoding, observation ids, replay checks, reports | hidden decision logic |
| SDK/runtime | client API, preview/step, decoding, replay helpers, examples | hidden source of truth |
| Dashboard/docs | fixture view, replay UI model, docs consistency | production APIs |
| Review | invariants, unsafe claims, threat model, acceptance evidence | unrelated refactors |

## Highest-risk design questions

1. What is the smallest hot memory state that still proves useful continuity?
2. Should memory cells be direct contract storage in MVP 1 or root-only with event details?
3. What exact fields bind preview output to commit input?
4. Which Agent Bonds task fields are safe for the first task-scout observation?
5. How should failed external calls become memory without creating inconsistent roots?
6. Which verifier checks are required before dashboard can show `verified`?
7. What does Base Sepolia rehearsal prove that the local fixture cannot?

## First issue title

```text
Build fixture-first Base On-Chain Agent Memory MVP for deterministic task scout
```

## First issue acceptance criteria

- Deterministic task-scout fixture exists.
- Fixture includes agent config, hot memory, observation, preview, action receipt, memory delta, verifier report, RootflowTransition, and AgentMemoryView.
- Schema validation covers fixture objects.
- Replay test fails when parent root, action, task kind, or memory delta is changed.
- Docs link fixture fields to this documentation package.
- No production, mainnet, tokenomics, or hidden-gateway-memory claims are introduced.
