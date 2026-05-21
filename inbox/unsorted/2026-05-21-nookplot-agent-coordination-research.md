# 2026-05-21 Nookplot full research for FlowMemory

## Raw thought

Nookplot is directly adjacent to the FlowMemory on-chain-agent idea. It is not only a website; it is a live Base-mainnet coordination stack for AI agents: identity, reputation, messaging, publishing, bounties, marketplace escrow, guilds, knowledge bundles, mining, runtime SDKs, CLI, MCP server, agent memory, and external tool/action surfaces.

The important research question for FlowMemory:

> What should FlowMemory learn from Nookplot if the target is on-chain AI agents with on-chain memory, using existing blockchain infrastructure?

Short answer:

- Nookplot is strongest as an **agent coordination network**.
- FlowMemory’s sharper opportunity is an **on-chain agent runtime and memory/state spine**.
- Nookplot already covers many coordination/economy surfaces FlowMemory should not duplicate blindly.
- FlowMemory should study Nookplot’s primitives, then build the narrower missing piece: deterministic replayable agent memory and bounded on-chain agent step execution.

## Sources reviewed

Primary public docs:

- https://nookplot.com/
- https://nookplot.com/about
- https://nookplot.com/hub
- https://nookplot.com/SKILL.md
- https://nookplot.com/docs/architecture
- `web/src/pages/docs/ArchitecturePage.tsx`
- `web/src/pages/docs/OverviewPage.tsx`
- `web/src/pages/docs/SecurityPage.tsx`
- `web/src/pages/docs/RuntimePage.tsx`
- `web/src/pages/docs/ContractsPage.tsx`
- https://nookplot.com/skills/register.md
- https://nookplot.com/skills/mining.md
- https://nookplot.com/skills/autoresearch.md
- https://nookplot.com/skills/latent-space.md
- https://nookplot.com/skills/papers.md
- https://nookplot.com/skills/ecosystem.md
- https://nookplot.com/skills/earn-more-nook.md
- https://nookplot.com/skills/community-guidelines.md

GitHub / package sources:

- https://github.com/nookprotocol/nookplot
- `web/public/llms.txt`
- `web/public/skills/*.md` for register, publish, marketplace, bounties, economy, reputation, communicate, collaborate, actions, workspaces, swarms, guilds, intents, oracle, skill registry, MCP server, addresses, email, teaching, mesh integration, errors
- `runtime/SKILL.md`
- `runtime/src/memory.ts`
- `gateway/src/routes/agentMemory.ts`
- `gateway/src/services/agentMemoryService.ts`
- `contracts/contracts/AgentRegistry.sol`
- `contracts/contracts/AgentFactory.sol`
- `contracts/contracts/KnowledgeBundle.sol`
- `schemas/soul.schema.json`
- `schemas/did-document.schema.json`
- npm pages for `@nookplot/runtime`, `@nookplot/mcp`, and `@nookplot/cli`

Access notes:

- Some deployed skill URLs render only the SPA shell through reader mode, but the same or related material was available through `/SKILL.md`, GitHub, or direct text endpoints.
- Published counts differ across sources: root `SKILL.md`, `llms.txt`, MCP README, about page, docs index, and runtime docs mention different MCP tool counts, manager counts, contract counts, and endpoint counts. Treat counts as moving product claims, not stable protocol facts.
- The docs contain a meaningful architecture tension: `OverviewPage.tsx` says “no central server, no single database, and no one entity in control,” while `ArchitecturePage.tsx` and `RuntimePage.tsx` explicitly describe a gateway, Postgres, indexer, runtime managers, and managed operations. Treat Nookplot as a hybrid protocol/product stack, not a purely serverless design.

## What Nookplot is

Nookplot describes itself as decentralized coordination infrastructure for AI agents on Base.

Its core claim:

> agents register, discover each other, communicate, publish knowledge, hire each other, earn reputation, settle payments, and take real-world actions through a gateway + contracts + indexer stack.

The home page frames it as:

- Internet for agents;
- peer-to-peer protocol for agent networks;
- agents publish verified knowledge;
- agents carry interoperable reputation;
- agents earn royalties when peers cite their work;
- primitives: knowledge citation graph, proof of useful work, settled coordination.

The about page frames the problem as agent coordination: individual agents can reason and execute but have no persistent network identity, memory, trust, or market coordination layer.

## Core architecture

### Network

- Base Mainnet only, chain id `8453`.
- ERC-2771 gasless meta-transactions through a Nookplot forwarder.
- Agent signs EIP-712 typed data locally.
- Gateway prepares calldata, uploads IPFS content, and relays signed requests.
- Gateway does not hold private keys under the documented prepare-sign-relay model.
- Reads are normal HTTP GETs; on-chain mutations use prepare → sign → relay.

### Storage split

Nookplot uses several storage layers:

- on-chain contracts for identity, social graph, content indexes, project/bounty/marketplace/guild state, knowledge bundles, rewards, etc.;
- IPFS for content, DID docs, soul docs, bundles, traces, and artifacts;
- Postgres/indexer tables for gateway features, search, memory, messages, and off-chain state;
- optional Arweave according to `llms.txt`;
- WebSocket delivery for real-time events.

### Contracts

The public address skill lists Base-mainnet proxy addresses for:

- `NookplotForwarder` — ERC-2771 relay.
- `AgentRegistry` — agent registration and DID reference.
- `ContentIndex` — posts/comments.
- `InteractionContract` — votes.
- `SocialGraph` — follow, attest, block.
- `CommunityRegistry` — communities.
- `ProjectRegistry` — projects.
- `ContributionRegistry` — contribution tracking.
- `BountyContract` — bounties and escrow.
- `KnowledgeBundle` — curated knowledge bundles.
- `ServiceMarketplace` — service listings and agreements.
- `GuildRegistry` / legacy `CliqueRegistry` — teams.
- `AgentFactory` — agent spawning.
- `RevenueRouter` — revenue distribution.
- `CreditPurchase` — USDC credit purchases.
- ERC-8004 identity/reputation registry addresses.
- USDC on Base.

GitHub source also includes additional contracts such as `FeeDistributor`, `RewardPool`, and `GpuAttestation`.

Important: these contracts are UUPS upgradeable proxies according to the address skill and contract source. That is a major difference from Quill’s “no owner / immutable” framing.

## Core user/integration pattern

### Prepare → sign → relay

Every on-chain action follows:

```text
POST /v1/prepare/<action>
-> gateway returns ForwardRequest + EIP-712 domain/types
-> agent signs locally
-> POST /v1/relay
-> forwarder verifies signature and executes
```

This is the main thing an integrating agent must get right.

Direct mutation endpoints that would imply on-chain state often return `410 Gone`; the correct path is prepare-sign-relay.

### Registration

Registration is two-stage:

1. Off-chain API key creation after wallet ownership proof.
2. On-chain registration through prepare-sign-relay.

Identity model:

- Ethereum wallet address on Base.
- `did:nookplot:<address>` DID document stored on IPFS.
- ERC-8004 identity token auto-minted at registration.
- API key for gateway access.
- EIP-712 signatures for on-chain actions.
- Agent type can be human or agent.

New agents reportedly get 38 free credits.

### Runtime / CLI / MCP

Nookplot provides:

- TypeScript SDK `@nookplot/sdk` for lower-level contract/gateway use.
- TypeScript runtime `@nookplot/runtime` for autonomous agents and managers.
- Python runtime `nookplot-runtime`.
- CLI `@nookplot/cli` for scaffolding, registering, syncing skills, going online.
- MCP server `@nookplot/mcp` for Cursor/Windsurf/other MCP clients.

The MCP server auto-registers on first run by generating a wallet, registering with the gateway, completing gasless on-chain registration, and storing credentials locally at `~/.nookplot/credentials.json`.

This is operationally important: Nookplot optimizes for agent onboarding, not purely for trust-minimized protocol minimalism.

## Nookplot primitives

### 1. Identity and memory

Nookplot’s identity is wallet + DID + agent profile + optional external claims.

DID document fields include:

- DID id/controller;
- verification method/public key;
- agent profile;
- self-reported model provider/name/version;
- capabilities;
- avatar and website;
- service endpoints;
- previous-version CID metadata.

Soul document fields include:

- identity/name/tagline/description;
- personality traits and communication style;
- values;
- mission/domains/goals;
- autonomy level and boundaries;
- discovery interests/strategies/budget/cadence;
- avatar config;
- parent soul CID for spawned agents.

Nookplot has explicit agent memory:

- endpoint family: `/v1/agent-memory/*`;
- memory types: `episodic`, `semantic`, `procedural`, `self_model`;
- store is free;
- semantic recall costs credits;
- import costs credits;
- export produces a portable memory pack with a SHA-256 hash;
- proof endpoint returns content hash and creation time;
- memory has importance, decay rate, access count, tags, source, parent memory id, metadata;
- recall reinforces accessed memories;
- decay periodically reduces importance;
- low-importance non-self memories can be pruned;
- dream-cycle consolidation groups episodic memories into semantic/procedural memory.

Critical distinction for FlowMemory:

- Nookplot’s agent memory implementation, from the gateway source, is primarily **gateway/Postgres memory**, not fully on-chain memory.
- It is persistent and hashable, but not the same as contract-resident memory cells.
- It is closer to “hosted persistent agent memory with proofs/export” than “agent memory in EVM state.”

### 2. Publishing and knowledge bundles

Posts/comments/votes use on-chain content indexing with IPFS content.

Knowledge bundles are curated collections of content CIDs with contributor weights. Contributor weights are on-chain and must sum to 10000 basis points. Bundles support revenue attribution when used to deploy or teach/spawn agents.

This is very close to FlowMemory’s “memory objects should carry attribution and evidence” direction.

### 3. Reputation and trust

Nookplot’s reputation model includes:

- on-chain attestations;
- follows/blocks;
- PageRank-style graph trust;
- recency decay;
- multi-dimensional leaderboard: commits, projects, lines, collaboration, bounties, content, social, marketplace, citations, velocity;
- external identity claims: GitHub, Twitter, email, arXiv.

The core idea: reputation is behavior-derived and graph-weighted, not a flat score.

### 4. Economy and credits

Nookplot uses two economic layers:

- internal credits for protocol service usage;
- USDC/NOOK for marketplace, bounties, staking, mining, guild treasuries, etc.

Credit costs cover posts, comments, votes, bounty claims, MCP calls, egress requests, sandbox execution, AI review, preview deployment, etc.

Credits can be earned through daily activity and passive engagement, bought with USDC, or included in subscription plans.

NOOK appears in mining, staking, bounties/marketplace, guild treasuries, and token pages. The about page states a NOOK ERC-20 address: `0xb233BDFFD437E60fA451F62c6c09D3804d285Ba3`, 100B supply, 18 decimals.

### 5. Bounties and marketplace

Bounties:

```text
create bounty with escrow
-> agent requests to claim
-> creator approves claimer
-> agent claims
-> agent submits work
-> creator approves or disputes
-> reward releases or remains disputed/cancelled
```

Marketplace:

```text
provider lists service
-> buyer creates escrow-backed agreement
-> provider delivers
-> buyer settles/disputes/cancels
-> review after settlement
```

This overlaps heavily with FlowMemory Agent Bonds. Nookplot has broader market UX; FlowMemory’s Agent Bonds are more narrowly about objective task accountability, evidence windows, verifier confirmation, challenges, and slashing.

### 6. Collaboration

Nookplot supports:

- projects registered on-chain;
- off-chain files, commits, tasks, milestones;
- project discussion channels;
- forks and merge requests;
- GitHub import;
- sandbox code execution;
- AI code review;
- task and bounty verification.

This is essentially a lightweight GitHub-for-agents plus escrow/bounties.

### 7. Communication

Communication layer includes:

- direct messages;
- channels;
- project-scoped group messaging;
- WebSocket event delivery;
- signed messages according to docs;
- @ai.nookplot.com real email inboxes.

The docs state DMs/channels are off-chain/gateway DB, not on-chain.

### 8. Workspaces, swarms, teaching

Nookplot has off-chain coordination objects:

- workspaces: shared key-value state with versioning, snapshots, members, proposals, quorum rules;
- swarms: task decomposition, subtask claiming/submission/aggregation;
- specialization: emergent skill niches from observed activity;
- teaching exchanges: proposed/accepted/delivered/approved skill transfer;
- insights: strategic notes propagated over trust network.

These are product primitives for multi-agent work. Most are off-chain for speed.

### 9. Latent-space coordination

Nookplot’s latent-space skill describes advanced model-native coordination:

- compressed reasoning objects as graph-structured knowledge bundles;
- evaluator bundles with binary/scale/rubric/threshold/model-judged scoring;
- cognitive workspaces with regions: hypotheses, evidence, decisions, open questions, constraints, artifacts, evaluators;
- intention/attention manifests for geometric matching;
- clarification request/offer/resolve loops;
- artifact embedding discovery;
- embedding packets and cross-model translation registry;
- cognitive fingerprints;
- workspace embedding evolution.

This is highly relevant to FlowMemory’s neural-geometry/agent-memory direction, but most of it appears to be gateway/runtime/API design, not contract-resident memory.

### 10. Mining and knowledge economy

Nookplot knowledge mining is reasoning-work mining, not GPU mining:

```text
browse challenge
-> submit reasoning trace to IPFS
-> verifiers score correctness/reasoning/efficiency/novelty
-> verified trace earns from epoch pool
-> learning insight joins knowledge base
-> trace joins dataset with royalty access
```

Mining features:

- 24-hour epochs;
- reward pool split: 70% solvers, 20% guilds, 5% verifiers, 5% challenge posters;
- challenge types: open scoring, python/js tests, exact answer, crowd jury, replication, prediction, paper reproduction;
- verifier quorum and outlier/collusion handling;
- artifact inspection and rerun/probe gates;
- RLM spot-check verification using cosine replay;
- NOOK staking tiers and 7-day unstake cooldown;
- mining guilds with pooled stake and boost;
- dataset access royalties: 60% solver, 20% verifiers, 10% poster, 10% treasury.

This is conceptually close to FlowMemory’s verifier/report/evidence surfaces, but with a live token economy and public-mainnet claims that FlowMemory currently keeps gated.

### 11. Real-world actions

Agents can use:

- egress proxy for outbound HTTP;
- webhooks for external service events;
- MCP bridge for external tool servers;
- tool registry;
- sandbox code execution;
- gateway action registry.

This is important for on-chain-agent design: true on-chain agents cannot directly make HTTP calls, but a gateway/action layer can produce signed receipts about external actions.

### 12. Ecosystem integration

Nookplot positions itself as a home base for agents that can also participate in external partner protocols.

Example: BOTCOIN integration.

Nookplot does not proxy the partner protocol’s mining loop. It indexes partner contracts and surfaces external activity on agent profiles. This is a useful pattern for FlowMemory: observe external agent work and convert it into memory/reputation without owning every subsystem.

## Product and protocol tension

Nookplot is ambitious and broad. It mixes:

- smart-contract protocol;
- hosted gateway;
- database-backed messaging/memory/workspaces;
- credit economy;
- token economy;
- public social network;
- agent runtime;
- MCP tools;
- research/mining platform;
- marketplace;
- code collaboration;
- email;
- external action bridge.

This breadth is powerful, but it creates several trust-boundary questions:

1. Which facts are contract state versus gateway DB state?
2. Which reputation/leaderboard values are recomputable from chain logs versus server-computed?
3. Which memory proofs are content hashes only versus Merkleized/replayable memory roots?
4. Which relayer/oracle signatures are trusted server outputs?
5. What can be upgraded by UUPS owners?
6. What happens if the gateway disappears?
7. What data is public forever on IPFS/chain versus deletable in Postgres?
8. Does “decentralized” mean contract-settled coordination or fully serverless operation?

FlowMemory should learn from Nookplot while keeping these boundaries explicit.

## Nookplot vs Quill vs FlowMemory

### Quill

- Narrow, fixed model classes.
- Weights on-chain.
- Inference on-chain.
- Deterministic replay by EVM.
- Small surface area.

### Nookplot

- Broad agent coordination network.
- Agents have wallets/DIDs/profile/memory.
- Most agent intelligence runs off-chain.
- Many coordination objects are gateway/indexer backed.
- On-chain layer anchors identity, social, content, bundles, bounties, marketplace, guilds, rewards.
- Strong product/runtime ecosystem.

### FlowMemory opportunity

FlowMemory can take the narrowness of Quill and the agent coordination learnings of Nookplot:

> Build deterministic on-chain agent memory/step primitives first, then let broader coordination/economy features remain optional or external.

FlowMemory should not try to rebuild all of Nookplot. It should focus on the thing Nookplot does not obviously make fully on-chain: compact on-chain memory cells and replayable agent state transitions.

## Direct relevance to FlowMemory’s on-chain-agent idea

The recent FlowMemory idea was:

> on-chain AI agents with on-chain memory using existing blockchain infrastructure.

Nookplot validates several parts:

- Agents need wallets/DIDs/identity.
- Agents need persistent memory across restarts.
- Agents need reputation and proof of work.
- Agents need communication and coordination channels.
- Agents need escrow/bounties/marketplace to make work economically real.
- Agents need action bridges for external APIs/tools.
- Agents need knowledge attribution and citation royalties.
- Agents need machine-readable docs/skills so AI tools do not hallucinate APIs.

But Nookplot also shows what is still missing for the sharper FlowMemory target:

- A contract-resident memory cell model.
- A deterministic on-chain agent step function.
- Replayable memory read/write sets.
- On-chain correction/supersession semantics for agent memory.
- A clean distinction between hot memory in contract storage and cold memory in bytecode/logs/roots.
- Agent kernels that can be simulated through `eth_call` before committing state.
- Explicit Rootflow-style transitions for memory evolution.

## Mapping to existing FlowMemory surfaces

### `AgentAccount`

Nookplot equivalent:

- wallet identity;
- DID;
- agent type;
- model/capability self-claims;
- soul document;
- external identity claims.

FlowMemory use:

- stable agent id;
- owner/policy roots;
- tool permission roots;
- model allowlist roots;
- memory namespace root.

FlowMemory should preserve the distinction between self-claimed model/capability data and verified behavior-derived reputation.

### `MemoryCell`

Nookplot equivalent:

- gateway memory table with `episodic`, `semantic`, `procedural`, `self_model`;
- importance, decay, access reinforcement, consolidation;
- content hash/proof/export pack.

FlowMemory use:

- make a stricter on-chain or root-committed version;
- fields like current root, previous root, delta root, source receipts root, dependency root;
- public typed memory cells where intentionally on-chain;
- commitments for private/heavy memory.

Key research insight:

> Nookplot’s memory tiers are a good UX/modeling vocabulary; FlowMemory should make the memory-transition state more deterministic and replayable.

### `WorkReceipt`

Nookplot equivalent:

- posts, commits, bounty submissions, mining traces, verifications, code reviews, service deliveries, sandbox outputs.

FlowMemory use:

- objective receipt for an agent action;
- source of truth for whether memory should update;
- task/bond settlement evidence.

### `VerifierReport`

Nookplot equivalent:

- mining verifier scores;
- artifact inspection/rerun/probe gates;
- oracle signed snapshots;
- code review/sandbox verification.

FlowMemory use:

- deterministic verifier status mapping;
- pass/fail/reorg/unsupported states;
- tighter challenge/correction semantics.

### `MemorySignal`

Nookplot equivalent:

- content/agent/bounty/marketplace/guild/mining events indexed into activity feeds;
- citation and knowledge graph edges.

FlowMemory use:

- compact on-chain signal that a memory-relevant event happened;
- should preserve event ABI + receipt-derived locator split.

### `RootflowTransition`

Nookplot equivalent:

- Nookplot has state changes, but it does not appear to expose a single Rootflow-style memory transition object.

FlowMemory use:

- parent memory root → new memory root;
- status;
- receipt/verifier references;
- correction/supersession.

This is a major FlowMemory differentiator.

### `AgentMemoryView`

Nookplot equivalent:

- runtime memory recall;
- agent profile tabs;
- profile external tab;
- MCP resources such as profile/activity/checkpoint;
- dashboard/profile views.

FlowMemory use:

- safe bootstrapping view for an agent before work;
- should include what is verified, pending, failed, stale, corrected, or unsupported.

## What FlowMemory should copy

### 1. Machine-readable protocol docs

Nookplot’s `SKILL.md` is excellent. It tells agents what they usually get wrong and routes them to the right skill docs.

FlowMemory should eventually expose a similar machine-readable root skill for:

- how to read FlowPulse;
- how to submit memory deltas;
- how to verify receipts;
- what not to claim;
- how on-chain agent memory works;
- where production boundaries are.

### 2. Prepare-sign-relay discipline

The pattern is good:

```text
prepare calldata
-> sign locally
-> relay
```

FlowMemory already cares about no secrets, local operator safety, and Windows-first usability. A similar pattern could work for agents that should not hold ETH but can sign intent/action envelopes.

### 3. Agent identity + DID + soul/profile split

Nookplot’s DID and soul schemas are useful:

- DID = cryptographic identity and capabilities.
- Soul = purpose/personality/autonomy/discovery policy.

FlowMemory could adapt this for on-chain agents:

- AgentAccount = hard policy/identity roots.
- AgentProfile/Soul = off-chain or committed public agent description.
- Behavior-derived memory/reputation = not self-claimed.

### 4. Biological memory vocabulary

The memory tiers are intuitive:

- working/hot memory;
- episodic;
- semantic;
- procedural;
- self-model;
- decay;
- consolidation/dream cycle;
- portable memory packs.

FlowMemory should reuse the vocabulary but make storage boundaries explicit:

- hot on-chain state;
- cold on-chain memory pages/logs;
- off-chain private/heavy memory with commitments;
- root transitions.

### 5. Citation/revenue attribution graph

Nookplot’s citation graph and knowledge bundles map well onto FlowMemory’s receipts and memory signals.

FlowMemory should study:

- contributor-weighted bundles;
- citation edges;
- receipt chains;
- royalties from usage/search/deployment;
- quality/reputation weighting.

But tokenomics should remain gated unless explicitly scoped.

### 6. Verifier economics and artifact inspection patterns

Nookplot’s mining verifier gates are valuable design input:

- cannot verify your own work;
- same-guild verification blocked;
- artifact inspection required;
- rerun/probe endpoints;
- quorum;
- outlier detection;
- comprehension gates;
- no rubber-stamping.

FlowMemory Agent Bonds and future on-chain agents need exactly this adversarial mindset.

### 7. MCP/CLI onboarding

Nookplot makes the network legible to coding agents through MCP and CLI. FlowMemory should do the same when its surfaces stabilize.

## What FlowMemory should avoid copying blindly

### 1. Over-broad surface area

Nookplot is a full social/economic network. FlowMemory should not simultaneously build social graph, email, marketplace, guilds, mining, paper search, workspaces, and token economy unless each is necessary.

FlowMemory’s wedge should stay narrower:

```text
on-chain agent memory
-> deterministic step/replay
-> receipts/verifier reports
-> dashboard/agent view
```

### 2. Ambiguous decentralization claims

Nookplot has many server/gateway/indexer/Postgres surfaces. That can be fine, but the trust boundary must be explicit.

FlowMemory should never say “decentralized” when the actual behavior depends on a hosted gateway unless that dependency is clearly named.

### 3. Early tokenomics

Nookplot includes credits, NOOK, mining, staking, guild boosts, royalties, and partner protocols.

FlowMemory should not import tokenomics from this research note. Token/economic mechanisms should come only after the on-chain memory/agent state machine works locally and safely.

### 4. Storing private memory publicly

Nookplot’s memory service stores content in a gateway DB and exports hashes. FlowMemory’s corrected idea includes on-chain memory, but on-chain memory is public forever.

FlowMemory must distinguish:

- public agent memory cells;
- private committed memory;
- heavy off-chain evidence;
- intentionally permanent public summaries.

### 5. Upgrade/admin ambiguity

Nookplot’s contracts are UUPS upgradeable. That gives product flexibility but weakens immutability claims.

FlowMemory must decide per surface:

- immutable primitive;
- upgradeable local/test scaffold;
- owner-controlled pilot;
- production-governed surface.

## FlowMemory architecture idea after Nookplot research

### New framing

FlowMemory should be the **Rootflow memory kernel for on-chain agents**.

Nookplot is an agent coordination society. FlowMemory can be the memory/state transition spine that such agents could use.

### Proposed core primitive

An on-chain agent memory loop:

```text
AgentAccount
-> observe Chain/Event/Receipt
-> read MemoryCell hot state
-> run deterministic AgentKernel via eth_call
-> execute allowlisted action
-> write MemoryDelta
-> emit FlowPulse
-> index into RootflowTransition
-> expose AgentMemoryView
```

### First agent class

Do not start with a chat agent. Start with a deterministic task scout:

- reads task/bond state;
- checks public memory of prior successes/failures;
- accepts or rejects only simple bounded tasks;
- updates public memory after outcome;
- emits receipts;
- can be replayed.

This is where FlowMemory can differ from Nookplot: not just agent coordination, but agent memory and action state that can be recomputed.

### Later neural kernel

Quill suggests a path for tiny fixed on-chain neural kernels.

A later FlowMemory agent kernel could:

- classify memory cell importance;
- rank candidate actions;
- choose whether to store/reject an observation;
- select from a small action enum;
- generate short public labels.

All external actions must remain rule-gated. No unbounded free-text agent action as the first target.

## Hard boundaries for FlowMemory

- Nookplot is a reference, not a dependency.
- Do not copy NOOK, credits, staking, or mining into FlowMemory by default.
- Do not claim FlowMemory has a Nookplot-style live network unless built.
- Do not claim on-chain memory is private.
- Do not put heavy prompts/transcripts/embeddings/model outputs on-chain by default.
- Do not skip indexer/verifier reconstruction.
- Do not conflate gateway memory with on-chain memory.
- Do not build a broad social network before proving the on-chain memory kernel.

## Open questions

1. Should FlowMemory’s first on-chain agent identity use existing `AgentAccount`, an ERC-8004 bridge, or a simpler local/test registry?
2. Should FlowMemory adopt biological memory tiers (`episodic`, `semantic`, `procedural`, `self_model`) directly?
3. Which memory cells are public content versus commitments to private/off-chain memory?
4. What is the exact on-chain memory cell format that is small enough for EVM storage?
5. Should cold memory use event logs, SSTORE2-style data contracts, or Merkle roots first?
6. How should a deterministic agent kernel declare its read set and action candidates?
7. Can an `eth_call` preview provide the same UX benefit as Nookplot prepare-sign-relay and Quill generate?
8. How do corrections/supersessions appear in `AgentMemoryView`?
9. Should FlowMemory integrate with Nookplot later via MCP/skill docs or remain independent?
10. What minimum local fixture would prove FlowMemory is doing something Nookplot does not already do?

## Smallest useful next step

Create one local/test fixture for an **on-chain task scout with typed public memory**:

1. `AgentAccount` with policy/tool/memory roots.
2. Public `MemoryCell` hot state using biological tier tags.
3. One observed task/bond event.
4. Deterministic rule/scoring decision.
5. Action receipt.
6. Memory delta root.
7. `FlowPulse`-like signal.
8. `RootflowTransition` from parent memory root to new memory root.
9. `AgentMemoryView` showing accepted memory, failed/stale memory, and next action.

The fixture should explicitly compare itself against Nookplot:

- Nookplot-style coordination: identity, marketplace, memory service, MCP.
- FlowMemory differentiator: contract-resident or root-committed memory transition with deterministic replay.
