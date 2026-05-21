# Public Agent Network Execution Pack

## Purpose

Use this pack to launch coordinated Codex workstreams for the public FlowMemory Base agent network.

This pack translates the public-launch architecture into concrete tracks with exact targets, non-goals, and acceptance evidence.

Primary docs:

- `docs/base-onchain-agent-memory/README.md`
- `docs/base-onchain-agent-memory/PUBLIC_AGENT_NETWORK_ARCHITECTURE.md`
- `docs/base-onchain-agent-memory/GPT_PUBLIC_AGENT_NETWORK_DRAFT.md`
- `docs/base-onchain-agent-memory/ARCHITECTURE.md`
- `docs/base-onchain-agent-memory/SMART_CONTRACTS.md`
- `docs/base-onchain-agent-memory/SDK_RUNTIME.md`
- `docs/base-onchain-agent-memory/SDK_REFERENCE.md`
- `docs/base-onchain-agent-memory/ACCEPTANCE_MATRIX.md`
- `docs/agent-goals/PUBLIC_AGENT_NETWORK_GOAL_PROMPT.md`

## Shared constraints for every track

```text
Read AGENTS.md, docs/START_HERE.md, docs/FLOWMEMORY_HQ_CONTEXT.md, docs/CURRENT_STATE.md, docs/ARCHITECTURE.md, docs/ROOTFLOW_V0.md, docs/FLOW_MEMORY_V0.md, docs/V0_LAUNCH_ACCEPTANCE.md, and the full docs/base-onchain-agent-memory package before editing.

Keep the trust model explicit.
Keep heavy AI/model/memory artifacts off-chain unless deliberately reduced to compact public state or commitments.
Do not store secrets.
Do not claim production or mainnet readiness.
Contracts must not assume txHash or logIndex during execution.
Indexers derive receipt metadata after execution.
Do not accept arbitrary user-provided Solidity as the public launch path.

Never be conservative in product imagination, but do not weaken deterministic replay, explicit risk boundaries, or reviewability.
```

## Track 1: HQ and launch sequencing

### Target files

- `docs/agent-goals/PUBLIC_AGENT_NETWORK_GOAL_PROMPT.md`
- `docs/agent-goals/PUBLIC_AGENT_NETWORK_EXECUTION_PACK.md`
- `docs/ISSUE_BACKLOG.md` when adding milestone entries
- `docs/reviews/` when recording architecture or completion audits

### Goal

Turn the public network architecture into a sequenced program without implementation drift.

### Responsibilities

1. Convert the public network architecture into build phases.
2. Define merge order and folder ownership.
3. Keep token, swarm, launch, and runtime tracks from overlapping unsafely.
4. Track which claims are implemented versus only documented.
5. Keep a risk log for launch-spam, token misuse, and swarm complexity.

## Track 2: contract stack

### Target files

- `contracts/`
- `tests/`
- `contracts/FLOWPULSE_SCHEMA.md` when pulse vocabulary changes

### Goal

Implement the public launch contract stack on top of the existing runtime.

### Required contracts

1. `AgentClassRegistry`
2. `AgentFactory`
3. `ToolRegistry`
4. `AgentLaunchBondEscrow` or equivalent stake gate
5. `AgentProfileRegistry`
6. `SwarmRegistry`
7. `SwarmBudgetVault`
8. later-gated `AgentShellFactory` only if justified

### Required invariants

- only enabled classes can launch;
- tool requests must be allowed by registry;
- launch intent must be signed and replay-safe;
- launch bond logic must be explicit;
- runtime registration must remain replayable;
- swarm creation must bind mission root and budget root;
- no arbitrary executor path.

### Non-goals

- no production governance;
- no token emission theater;
- no broad social graph in the contracts track.

## Track 3: launch intent, schemas, and token rules

### Target files

- `crypto/`
- `schemas/`
- launch fixtures
- token and launch docs when required

### Goal

Define the signed launch flow and the token-backed launch/memory rules.

### Required artifacts

- launch intent schema;
- signed launch envelope format;
- policy/tool/profile root derivation rules;
- token-backed launch bond schema;
- swarm creation intent schema;
- profile / lineage schema;
- replay-safe ids for launches and swarms.

### Required decisions

- what token amount gates launch;
- what memory writes cost;
- what is refundable versus slashable;
- what swarm budgets lock and how they release.

## Track 4: runtime, indexer, and verifier

### Target files

- `services/indexer/`
- `services/verifier/`
- `services/flowmemory/`

### Goal

Make public launch and swarm activity fully replayable.

### Required behavior

1. Decode public launch events.
2. Decode class/tool/profile/signed-launch surfaces.
3. Decode swarm formation and budget events.
4. Project launched agents into Rootflow / AgentMemoryView surfaces where required.
5. Verify launch and swarm commitments.
6. Preserve correction and challenge semantics.
7. Keep duplicate/reorg handling explicit.

## Track 5: control-plane and discovery

### Target files

- `services/control-plane/`
- related handoff or smoke artifacts

### Goal

Expose the public network as a discoverable local/test operator surface.

### Required methods

- class list/get
- tool list/get
- public agent launch list/get
- launch bond status
- profile list/get
- swarm list/get
- swarm budget status
- lineage/provenance lookups
- launch replay / swarm replay methods when added

### Acceptance

The control-plane should answer “what agents exist, what class are they, who launched them, what can they do, and what swarms are they in?” without hidden data paths.

## Track 6: SDK, CLI, and launch builder

### Target files

- `services/agent-memory-sdk/`
- `services/flowchain-sdk/`
- launch examples/docs

### Goal

Give users and developers a public launch builder experience.

### Required APIs

- class discovery
- tool discovery
- launch config compiler
- launch intent signing helper
- public launch submit helper
- profile read helpers
- swarm create/join helpers
- launch bond status helpers
- direct runtime preview/step where appropriate

### CLI requirements

- list classes
- inspect class
- build launch config
- submit launch
- inspect launched agent
- inspect swarm
- inspect replay

## Track 7: dashboard and public network UX

### Target files

- `apps/dashboard/`
- dashboard fixtures

### Goal

Show the public network as a directory and cognitive economy, not just raw contract rows.

### Required views

- agent directory
- agent profile detail
- launch bond / risk state
- lineage / descendant view
- tool permissions view
- class detail view
- swarm directory
- swarm detail with budget/members/mission
- replay trail for launch and runtime actions

### Non-goals

- no marketing-only visuals disconnected from data;
- no fake social-feed product before the launch and swarm model are real.

## Track 8: docs and review

### Target files

- `docs/base-onchain-agent-memory/`
- `docs/agent-goals/`
- `docs/reviews/`

### Goal

Keep the public network docs strong enough that another senior builder can implement the remaining work without ambiguity.

### Required pages or updates

- public launch architecture
- launch flow
- token role
- anti-spam and bond economics
- swarms
- public discovery
- class model
- lineage model
- trust boundaries and non-goals

## Acceptance matrix for this workstream

The public network workstream is ready for the next implementation phase only when:

1. launch classes are explicitly defined;
2. launch flow is replay-safe and signature-backed;
3. tool permissions are registry-driven;
4. token-backed launch seriousness is technically specified;
5. swarm architecture is concrete;
6. discovery/control-plane/dashboard surfaces agree on the same model;
7. SDK/CLI surfaces can express the launch model;
8. docs, schemas, and code use the same terms;
9. no false production/mainnet claims are introduced.

## Handoff contract for every track

Every track handoff must include:

```text
Changed files:
Checks run:
Contracts/schemas/methods added:
Events added or changed:
Public claim boundaries touched:
Known gaps:
Next smallest safe task:
```
