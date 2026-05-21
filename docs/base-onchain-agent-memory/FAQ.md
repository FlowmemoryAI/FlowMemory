# FAQ and Common Misconceptions

## Is the first version a chat agent?

No. The first serious product should be an On-Chain Task Scout: a bounded contract actor that watches tasks, previews actions, writes memory, and exposes replay.

## Does this put full LLM inference in contracts?

No. The first kernel should be deterministic rule or rule-gated scoring logic. A tiny fixed-shape model kernel can be researched later for bounded classification or ranking, not unrestricted text generation.

## Why call it agent memory if heavy memory stays off-chain?

Because the chain-side state contains the public working set, roots, deltas, receipts, statuses, and correction history that make the agent's continuity replayable. Heavy/private evidence can still be committed by root without putting raw content in storage.

## Is chain-side memory private?

No. Contract storage and logs are public. Private or heavy evidence should be represented by commitments and admitted only through explicit receipts, signatures, or verifier reports.

## How is this better than a hosted memory database?

A hosted memory database can be faster and richer, but it requires trust in the operator. FlowMemory's wedge is public, compact, replayable state transitions: parent root, memory delta, action receipt, verifier status, and current view.

## How is this different from Nookplot?

Nookplot is broad coordination infrastructure: identity, reputation, social surfaces, marketplace, bounties, MCP, gateway, and hosted memory. FlowMemory should focus on the narrower memory/replay kernel: deterministic preview, chain-side memory roots, action receipts, verifier reports, and `AgentMemoryView`.

## Does FlowMemory compete with Nookplot?

It can be independent and complementary. Nookplot-like systems need coordination breadth. FlowMemory should provide a sharper state spine that such agents could use if they need public memory continuity and replay.

## Why Base first?

Base has the adjacent agent ecosystem, EVM tooling, lower-cost execution, ERC infrastructure, Base Sepolia rehearsal path, and current FlowMemory contract direction. Keeping Base explicit reduces drift in docs, SDKs, readers, and deployment gates.

## What does `eth_call` preview give developers?

It lets anyone inspect the next deterministic action before mutation. A caller can see action enum, reason code, target, selector, cap impact, and memory delta root before submitting a transaction.

## Who pays for steps?

The first design does not require a new token. A keeper, owner, test account, or approved operator can submit transactions. Any incentive or fee design remains separately gated.

## Can agents spend funds?

Not in the first safe path except zero-value or tightly capped actions. Value-bearing behavior requires caps, tests, pause controls, reviews, and separate approval.

## What happens when memory is wrong?

Wrong memory is corrected through append-only supersession. The old memory stays visible as failed, corrected, stale, unsupported, unresolved, or reorged. It is not silently deleted.

## What happens if an off-chain document disappears?

Verifier status becomes `unresolved` if the evidence is required. The memory view should show the uncertainty instead of pretending the memory is verified.

## Can the agent act on off-chain facts?

Only if those facts enter through an explicit source: oracle, signed envelope, content commitment, verifier report, or operator transaction. The agent must not pretend external facts are known just because a runtime saw them.

## Does a verifier report mean absolute truth?

No. It means the transition passed a named ruleset with available evidence. The report must identify status and scope.

## What should the first dashboard show?

Agent status, memory root, sequence, hot memory, recent actions, memory buckets by status, last verifier report, previewed next action, and replay trace.

## What should the first SDK make easy?

Read agent state, encode task observations, preview steps, submit expected previews, decode events, replay receipts, and fetch `AgentMemoryView`.

## Why not build a marketplace first?

Because the core differentiator is memory and replay. A marketplace without a verified memory state machine would duplicate broader coordination products before proving FlowMemory's unique kernel.

## Why not store full chat logs as memory?

Full transcripts are expensive, public if on-chain, and usually not the best decision input. Store typed memory: episodic facts, semantic constraints, procedural rules, goals, and scar tissue.

## How do external models fit?

GPT, DeepSeek, Codex, and similar systems can design policies, attack assumptions, generate tests, and compress behavior into deterministic rules. Their raw transcripts stay off-chain unless intentionally summarized and committed.

## What is the definition of done for the first build?

A local/test On-Chain Task Scout can be registered, preview a deterministic action, commit a bounded step, write memory, emit events, be indexed, be verified, and produce an `AgentMemoryView` that can be replayed from receipts and state.
