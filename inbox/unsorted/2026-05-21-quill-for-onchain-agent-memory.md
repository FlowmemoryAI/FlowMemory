# 2026-05-21 Quill-shaped on-chain agent memory

## Raw thought

Quill is a strong adjacent project because it makes a simple promise with a tight technical boundary: fixed-shape language models, weights stored on Base, deterministic EVM inference through shared engines, and permanent inscriptions as the paid/attributed path.

The useful FlowMemory idea is not “put all AI memory or AI inference on-chain.” The useful idea is a similar separation of concerns for agents:

> compact, canonical, replayable memory commitments on-chain; heavy memory, retrieval indexes, prompts, transcripts, embeddings, model outputs, and artifacts off-chain; deterministic indexer/verifier reconstruction between them.

This should stay an intake note until promoted into a bounded research note or issue.

## Source links reviewed

- https://quill.computer/
- https://quill.computer/docs
- https://quill.computer/#how-it-works
- https://quill.computer/deploy
- https://quill.computer/gallery
- https://x.com/quillcomputer

## Source coverage notes

- The website and technical docs were readable.
- The deploy and gallery pages were readable enough to capture product flow and live public counters.
- X was not machine-readable from the harness because X blocks automated access.
- The original chat showed a `[paste #1 +47 lines]` placeholder, but the pasted content itself was not present in the visible transcript. If that paste matters, it needs to be added as a new raw input here before this note is promoted.

## Quill scope, as understood from the shared materials

### One-line claim

Quill describes itself as a permissionless factory for language models that run entirely on-chain. A user trains a model off-chain, deploys the resulting weight blob to Base, and calls a shared engine contract that computes deterministic text generation as pure EVM integer arithmetic.

### Core architecture

Quill is four contracts plus off-chain training tooling:

1. `QuillToken`: fixed-supply ERC-20 used for paid permanent inscriptions.
2. `QuillEngine`: shared stateless inference engine for small models.
3. `QuillEngine2`: shared stateless inference engine for large models.
4. `QuillFactory`: permissionless model deployment, registry, routing, pricing, prepaid credit, inscriptions, and leaderboard/accounting.
5. `trainer.js` / Python scripts: off-chain training and blob generation.

A model is not deployed as a custom logic contract. It is a blob of model weights stored as on-chain data contracts. The shared engine reads the blob and executes the fixed architecture.

### Model classes

Quill currently defines two fixed model classes:

- Small: C8 character MLP, one hidden layer, 96-character vocabulary, roughly 23k parameters, one data contract.
- Large: 3-layer character MLP, larger context/window and hidden sizes, roughly 213k parameters, nine data contracts.

The fixed architecture matters. The engines can hardcode dimensions and unroll loops. This is what makes a shared on-chain engine plausible. Arbitrary model shapes would multiply gas and complexity.

### Vocabulary and generation

Both classes use a fixed 96-character vocabulary: newline plus printable ASCII. Generation is autoregressive and greedy. There is no sampling, temperature, or seed in the current core path. Output is a deterministic pure function of prompt and requested length.

### Quantization

Weights are quantized to int8 and biases to pre-scaled int32. The EVM does not dequantize during inference. It accumulates integer products and chooses `argmax`. Since `argmax` is invariant under positive scaling, the integer forward pass can match the real-valued logits for decoding.

This is the most important engineering lesson: Quill narrows the model class until deterministic integer execution is the product, not an approximation hidden behind an oracle.

### On-chain storage

Model data is stored in SSTORE2-style data contracts: runtime bytecode starts with `STOP`, then raw bytes. The engine reads bytes with `EXTCODECOPY`. Small models fit in one data contract; large models are split across nine data contracts.

Quill treats the model bytecode itself as the inspectable artifact. The engines and factory can be verified Solidity; model contracts are inert data.

### Inference engines

The engines are stateless and deterministic. They read model bytes, build the context, run embedding gather, hidden-layer dot products, ReLU, and argmax, then repeat per output character.

The docs emphasize Yul implementation details: contiguous transposed weights, `MLOAD`, `SIGNEXTEND`, unrolled multiply-accumulate loops, and reused scratch memory.

### Gas and call model

`generate` is a view function, so users can try models through `eth_call` without paying transaction gas. The node still executes expensive computation under RPC gas caps. The docs report roughly:

- small: about 974k gas per generated character;
- large: about 9.9M gas per generated character;
- small 32-character generation around 31M gas;
- large generations capped shorter.

Deployment is gas-paid in ETH. Small model deployment is around 5M gas; large around 50M.

### Factory and economy

The factory is permissionless and has no owner according to the docs. Deploying a model is gas-only and requires no QUILL. Trying a model through `generate` is free. Permanently recording an output through `inscribe` is paid.

Each model has a creator-set `rate` in QUILL per generated character, capped by `MAX_RATE`. `quote(id, count)` returns the price. `inscribe` records the generation on-chain and emits prompt/output in a log. Fees split 70% to the model creator and 30% burned.

Users can deposit prepaid QUILL credit and withdraw unused balances. The factory tracks model inscriptions, creator earnings, total inscriptions, total burned, total spent, and leaderboard state.

The token allocation described by the docs is fixed supply: 85% liquidity, 10% team vesting, 5% grants. The protocol does not route inscription fees to a treasury in the described design.

### In-browser training and product flow

The deploy page flow is:

1. paste corpus;
2. train small model in browser;
3. preview output locally;
4. set name, note, and QUILL-per-character rate;
5. connect wallet;
6. deploy to Base.

The deploy page states small browser training needs at least 300 characters of corpus and supports up to 32,768 characters. Preview is claimed bit-identical to on-chain because the browser uses the same integer forward pass.

Large models use bundled Python tooling today; browser training for large models is roadmap.

### Gallery and live surface

The gallery shows Quill as a model registry/leaderboard. At review time, it showed three small models, two inscriptions, QUILL burned, Base chain block height, and contract links for factory, engine1, engine2, and token.

The public product loop is therefore:

- browse models;
- call/generate for free;
- deploy a model from your own corpus;
- optionally inscribe outputs permanently;
- creators earn when others inscribe from their models;
- burned QUILL and inscriptions become public leaderboard/accounting state.

### Roadmap from docs

Quill’s stated next directions are:

- XL/XXL model classes via additional engine contracts;
- browser training for every class;
- transformer engine as another shared contract class;
- longer context windows and optional sampling;
- inference-cost compression through tighter encodings, sparse loops, and L2/EVM improvements;
- richer discovery, collections, remixes, and attribution.

The roadmap keeps v1 immutable and adds new contracts alongside it.

## Why this matters for FlowMemory

Quill’s value is not that FlowMemory should copy its tokenomics or put AI runtime on-chain. The value is the project shape:

1. Choose a small, fixed, canonical object model.
2. Keep the heavyweight work off-chain.
3. Store compact, inspectable commitments on-chain.
4. Use a shared deterministic interpreter/verifier path.
5. Make replay and attribution first-class.
6. Separate free/local/private use from permanent public inscription.

FlowMemory already has most of the safer version of this shape in V0:

- `FlowPulse` is the compact on-chain signal.
- `MemorySignal` is the smallest agent-readable event.
- `MemoryReceipt` links a signal to evidence and verifier output.
- `RootflowTransition` gives the state-transition record.
- `RootfieldBundle` gives current namespace state.
- `AgentMemoryView` is the safe agent-facing projection.

The Quill-shaped extension should therefore start by asking: what is missing from those existing surfaces for durable agent memory continuity?

## FlowMemory translation

### Off-chain data

Keep these off-chain:

- raw agent memories;
- prompts and transcripts;
- retrieval indexes;
- embeddings and vector stores;
- model outputs;
- tool outputs and artifacts;
- private evidence bundles;
- media and generated datasets;
- local/browser/worker memory-compaction outputs before commitment.

### On-chain commitment/state

Only commit compact intentional state:

- memory namespace registration;
- memory snapshot root;
- memory update commitment;
- receipt commitment;
- evidence pointer commitment or URI when intentionally public;
- verifier report status;
- challenge/correction state if later scoped;
- short permanent summaries only when the user explicitly chooses public inscription semantics.

### Shared-engine analogue

The FlowMemory analogue to Quill’s engine should not be an on-chain neural network. It should be a shared memory-transition reconstruction contract between contracts, indexers, verifiers, and agents:

1. canonical object schemas;
2. deterministic serialization and hashing;
3. bounded transition kinds;
4. receipt-derived locators added by indexers;
5. verifier reports with explicit statuses;
6. agent views that never pretend raw memory is on-chain.

This can begin as local/test verifier code and schemas. A production on-chain verifier or proof system is a separate later gate.

### Product surface

Possible user/agent language:

- “Drop this idea into the inbox.”
- “Compress this run into an agent memory note.”
- “Commit a memory snapshot root.”
- “Replay this agent’s memory chain across runs.”
- “Show which memories are verified, pending, failed, reorged, or unsupported.”
- “Permanently publish this short memory summary.”

Avoid language like:

- “AI memory lives on-chain.”
- “The chain stores the agent’s whole mind.”
- “FlowMemory runs AI inference on-chain.”
- “This is production trustless memory.”

## Mapping to existing V0 objects

### `MemorySignal`

Potential fit: a memory update signal derived from a FlowPulse event or local fixture.

Question: does V0 need a new `signalType` such as `agent_memory_commitment`, or can early work use existing root commitment semantics?

### `MemoryReceipt`

Potential fit: link a memory signal to an artifact commitment and evidence pointer.

Question: what is the minimum evidence pointer that proves a memory summary was derived from a real run without exposing private transcript content?

### `RootflowTransition`

Potential fit: one memory snapshot root moves from parent root to new root.

Question: what transition kinds are allowed: append-only memory, correction, retraction, merge, compaction, or namespace migration?

### `RootfieldBundle`

Potential fit: current state of an agent memory namespace.

Question: should rootfields be organized by agent, task, work lane, user, or memory class?

### `AgentMemoryView`

Potential fit: safe projection that an agent can consume before a run.

Question: how much detail can this view expose while preserving privacy and avoiding false certainty?

## Hard boundaries

- Heavy AI, model, memory, media, and artifact data stays off-chain.
- On-chain state stores only roots, receipts, commitments, attestations, proofs, and intentional work state.
- FlowMemory must not claim AI inference runs on-chain unless a separate bounded prototype actually does that.
- Do not import Quill tokenomics, permanent model storage, creator-fee design, or public value mechanics by default.
- Do not turn this idea into production L1, public validator, bridge, tokenomics, or mainnet scope.
- Treat Quill as an analogy and external reference, not a dependency or authority for FlowMemory architecture.

## Open questions

1. What is the smallest useful agent-memory object worth committing?
2. Is a memory snapshot root enough, or do agents need append-level receipts?
3. How should a false or stale memory be corrected without rewriting history?
4. How should private memory evidence be committed without leaking content?
5. Does the existing `RootfieldRegistry` already cover memory namespaces, or is a narrower memory namespace policy needed?
6. Is there a useful read-only reconstruction call analogous to Quill’s free `generate`, where agents can retrieve an `AgentMemoryView` from committed roots and local evidence?
7. Should “permanent inscription” exist for short public memory summaries, or is that too close to tokenized social posting?
8. What are the verifier rules for a memory compaction step?
9. Should memory commitments be per agent, per task bond, per rootfield, or per user-controlled namespace?
10. What is the challenge window for an incorrect agent memory?

## Smallest useful next step

A concrete follow-on concept note exists at `inbox/unsorted/2026-05-21-deepseek-codex-agent-memory-foundry.md`.

The user then clarified the sharper target: **actual on-chain AI agents with on-chain memory**, using existing blockchain infrastructure. That corrected architecture note is `inbox/unsorted/2026-05-21-onchain-ai-agents-with-onchain-memory.md`.

The corrected note still maps back to the existing FlowMemory path:

```text
FlowPulse
-> MemorySignal
-> MemoryReceipt
-> RootflowTransition
-> RootfieldBundle
-> AgentMemoryView
```

It keeps the first build path local/test and bounded: start with a deterministic on-chain task agent and on-chain memory cells before attempting any tiny Quill-like neural kernel.
