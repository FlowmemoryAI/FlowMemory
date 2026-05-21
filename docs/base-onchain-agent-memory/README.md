# Base On-Chain Agent Memory

## Status

This is a product and architecture documentation package for the next FlowMemory workstream. It is not a claim that the current repository already contains the finished contracts, SDK, hosted services, or public network. The first implementation target remains local/test and Base Sepolia rehearsal work until the normal FlowMemory gates approve a wider release.

## One-sentence product

FlowMemory is the Base-native memory and replay kernel for autonomous agents: a compact chain-side state machine where an agent can read public memory, preview a deterministic next step, commit a bounded action, write a memory delta, emit FlowPulse, and let anyone reconstruct the transition.

## Why this exists

Most agent frameworks are powerful off-chain systems with private mutable state. They can be useful, but their memory often lives in a database controlled by a gateway or operator. That makes it hard for a third party to answer basic questions:

- What did the agent know before it acted?
- Which rule or scorer selected the action?
- What memory changed after the action?
- Was the change verified, challenged, corrected, or stale?
- Can another agent inherit that state without trusting a private server log?

FlowMemory's wedge is narrower and harder: make the agent's public working memory and state transitions explicit, compact, replayable, and inspectable from Base contracts, receipts, logs, roots, and verifier reports.

## The core loop

```text
observe
-> recall
-> decide
-> act
-> write memory
-> emit receipt
-> replay
```

The first product is not a chat bot. It is an On-Chain Task Scout: a bounded agent that watches task or bond state, reads its own public memory, previews a deterministic decision with `eth_call`, accepts or rejects only allowed tasks, writes a compact memory delta after the outcome, and exposes a reconstructed `AgentMemoryView`.

## What is chain-side

The chain-side layer should contain only compact intentional protocol state:

- agent identity and status;
- latest memory root and sequence;
- bounded hot memory slots;
- policy root and kernel class;
- tool/action allowlist roots;
- budget, rate-limit, and cap accounting;
- action and memory transition receipts;
- FlowPulse events;
- verifier report references;
- correction and supersession markers.

## What stays off-chain or commitment-only

Heavy or private material stays outside contract storage by default:

- full prompt transcripts;
- private user instructions;
- embeddings and vector indexes;
- screenshots and media;
- large documents;
- full model checkpoints;
- unrestricted LLM outputs;
- private evidence.

If off-chain data matters to replay or verification, it enters through a commitment, receipt, signed envelope, content-addressed pointer, or verifier report.

## Why Base

Base is the first chain target because the surrounding agent ecosystem, low-cost EVM execution, ERC tooling, wallet/account infrastructure, Base Sepolia rehearsal path, and existing FlowMemory contract work make it the cleanest place to prove this memory kernel. The docs keep Base scope explicit so contract addresses, chain IDs, event readers, SDK clients, and deployment runbooks do not drift across networks.

## How this is different from Nookplot

Nookplot is a broad agent coordination network: identity, reputation, messaging, publishing, bounties, marketplace surfaces, gateway APIs, MCP tooling, and hosted memory. FlowMemory should not clone that surface area.

FlowMemory should be better at the narrower kernel:

1. contract-resident or root-committed memory transitions;
2. deterministic step preview before mutation;
3. replay from chain state, logs, receipts, and verifier reports;
4. explicit hot/cold memory boundaries;
5. challengeable correction history instead of silent memory edits;
6. a smaller trust boundary that does not market gateway memory as chain-resident memory.

## Documentation map

- [Overview](./OVERVIEW.md) — product thesis, primitives, phases, and boundaries.
- [Architecture](./ARCHITECTURE.md) — system layers, preview/commit flow, trust boundaries, and failure modes.
- [Smart Contracts](./SMART_CONTRACTS.md) — proposed contract surfaces and events.
- [SDK and Runtime](./SDK_RUNTIME.md) — developer API shape, read/write flows, and examples.
- [Memory Model](./MEMORY_MODEL.md) — hot/cold memory, typed cells, roots, corrections, and expiry.
- [Agent Model](./AGENT_MODEL.md) — agent identity, kernels, action routing, and autonomy levels.
- [Verification and Replay](./VERIFICATION_REPLAY.md) — how indexers and verifiers reconstruct transitions.
- [Security and Trust Boundaries](./SECURITY_TRUST_BOUNDARIES.md) — what can fail and what must remain gated.
- [Data Flow](./DATA_FLOW.md) — diagram-ready flow of observations, actions, memory deltas, and projections.
- [Local Development and Simulation](./LOCAL_DEV_AND_SIMULATION.md) — first local/test fixture and Base Sepolia rehearsal path.
- [Examples](./EXAMPLES.md) — On-Chain Task Scout walkthroughs and SDK call shape.
- [Glossary](./GLOSSARY.md) — exact vocabulary.
- [FAQ](./FAQ.md) — common misconceptions and non-goals.
- [Build Goal](./BUILD_GOAL.md) — copy-ready principal-agent goal.
- [SDK Reference](./SDK_REFERENCE.md) — fixture-backed client API for the first task-scout proof.
- [Acceptance Matrix](./ACCEPTANCE_MATRIX.md) — what must be true before claiming the workstream is complete.
- [Public Repository Guide](../PUBLIC_REPO_GUIDE.md) — top-level public reader map, repo layout, trust boundary, verification commands, and gap links.
- [Public Tester Guide](../PUBLIC_TESTER_GUIDE.md) — external tester lanes, expected results, CLI/control-plane trial, and report template.
- [Public Agent Network Technical Guide](../PUBLIC_AGENT_NETWORK_TECHNICAL_GUIDE.md) — current implementation guide across contracts, helpers, control-plane, SDK, dashboard, tests, and issues.
- [Public Agent Network Architecture](./PUBLIC_AGENT_NETWORK_ARCHITECTURE.md) — exact public-launch contract, factory, token, and swarm architecture.
- [GPT Public Agent Network Draft](./GPT_PUBLIC_AGENT_NETWORK_DRAFT.md) — creative external architecture draft captured after prompting GPT with FlowMemory's public-launch context.
- [Public Agent Network Goal Prompt](../agent-goals/PUBLIC_AGENT_NETWORK_GOAL_PROMPT.md) — copy-ready goal for building the public Base agent network.
- [Public Agent Network Execution Pack](../agent-goals/PUBLIC_AGENT_NETWORK_EXECUTION_PACK.md) — decomposed implementation tracks for the public network.
- [Public Agent Network Full Build Goal](../agent-goals/PUBLIC_AGENT_NETWORK_FULL_BUILD_GOAL.md) — comprehensive public-network objective with contract stack, launch flow, token rules, swarms, and phased roadmap.
- [Public Agent Network Module Prompts](../agent-goals/PUBLIC_AGENT_NETWORK_MODULE_PROMPTS.md) — copy-ready prompts for each major contract and surface.
- [Public Agent Network Complete Build Goal Prompt](../agent-goals/PUBLIC_AGENT_NETWORK_COMPLETE_BUILD_GOAL_PROMPT.md) — single master prompt for building the full public Base agent network.

## Non-goals for the first build

- No broad social network.
- No marketplace clone.
- No new tokenomics.
- No hidden gateway-only memory marketed as chain-resident memory.
- No private memory written publicly by default.
- No unrestricted on-chain text generation loop.
- No production or mainnet readiness claim without separate approval, implementation evidence, tests, review, and deployment gates.
