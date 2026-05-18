# L1 Research Inventory

Last updated: 2026-05-13

This document maps the L1, appchain, cryptography, and novelty research that exists across the accessible FlowmemoryAI GitHub repositories. It is a planning and direction artifact only. It does not approve production L1 work, tokenomics, mainnet launch, bridge deployment, or value-bearing systems.

## Sources Inspected

GitHub organization: `FlowmemoryAI`

Accessible repositories:

| Repository | Local clone | Commit inspected | Role |
| --- | --- | --- | --- |
| `FlowmemoryAI/FlowMemory` | `E:\FlowMemory\flowmemory-main` | `7140e5c` | Current source of truth for the active FlowMemory program. |
| `FlowmemoryAI/noesis-l1` | `E:\FlowMemory\github-research-sources\noesis-l1` | `df0ef56` | Main Noesis / Flow Chain L1 corpus, research waves, Rust workspace, and cryptographic primitive archive. |
| `FlowmemoryAI/rootflow` | `E:\FlowMemory\github-research-sources\rootflow` | `859fb2b` | Rootflow and FlowCodec archive: Base/Uniswap v4 proof rail, memory capsule bridge, local proof API, canary artifacts, and production-gated runbooks. |
| `FlowmemoryAI/FlowMemory-2026-05-11` | `E:\FlowMemory\github-research-sources\FlowMemory-2026-05-11` | `fc0ecb3` | Cleaned staging archive containing earlier Noesis, FlowCodec, AI-L1 research docs, app prototypes, and source maps. |

Repository searches for `polyflow`, `poly flow`, `FlowMemory L1`, `appchain`, and `Rootfield` did not reveal additional repositories under the accessible `FlowmemoryAI` account. The "poly flow chain" naming appears to map into the Noesis / Flow Chain / FlowMemory research family rather than a separate GitHub repository.

## Current FlowMemory Main Repo State

The active repo has already merged:

- repo operating system and multi-agent docs
- contracts V0 foundation
- crypto V0 foundation
- indexer/verifier fixture package
- dashboard V0
- FlowRouter hardware POC
- local no-value devnet prototype
- launch-core FlowMemory V0 integration
- contract event spine and Slither hardening pass

The current local devnet in `FlowMemory` is intentionally small: `crates/flowmemory-devnet/` models deterministic local transactions, blocks, and state roots. It is not Noesis, not a production L1, not a token system, and not a validator network.

## Noesis / Flow Chain Corpus

`FlowmemoryAI/noesis-l1` is the largest L1 body of work.

Core thesis:

```text
AI work becomes verifiable state.
```

Branding found in the corpus:

- Company umbrella: FlowMemory
- Public protocol/brand candidates: Continuum, Flow Chain
- Technical engine: Noesis L1
- Historical token name in research docs: `$NOUS`

### Built Locally

Noesis contains a large Rust workspace with local chain, state, RPC, SDK, and AI-object surfaces. The latest handoff claims:

- 161 Rust workspace crates
- 2466 workspace tests passing
- 138 architecture docs
- 84 position papers
- 189 Python tools
- 184 generated figures
- 16 interactive HTML visualizations

Local functionality documented as working includes:

- accounts, balances, signed transactions, nonces, gas/fee scaffolds, blocks, headers, roots, receipts, checkpoints, and replay tests
- persistent local state and E-drive data/build paths
- local wallet/key flows and Ed25519 dev signatures
- custom fungible tokens and constant-product DEX
- local validator registration, delegation, heartbeat, slashing evidence, governance, and proposer selection
- RPC, index/read-model, explorer JSON, metrics, state sync, snapshot, storage integrity, and light-client proof surfaces
- AI-native state objects: `ModelPassport`, `AgentAccount`, `AIWorkReceipt`, `ToolReceipt`, `EvalReceipt`, `MemoryCell`, `ArtifactAvailabilityProof`, `Challenge`, and verifier modules
- receipt lineage, artifact store, optimistic challenge flow, agent sessions, agent messages, agent actions, task bounties, and reputation counters
- deterministic app runtime and tiny no-import WASM runner scaffold
- local multi-validator simulator, E-backed validator directory launcher, TCP vote-gossip/vote-mesh smokes, consensus-round probes, and bounded local consensus loop evidence

### Hard Limits

Noesis is not production or public-network ready.

The corpus repeatedly marks these as false or blocked:

- production P2P
- production BFT
- mainnet readiness
- public token launch
- production bridge
- production wallet/custody
- production verifier/prover infrastructure
- production L1 economics
- external audit completion

Most important production gaps:

1. Long-running validator-owned P2P service.
2. Autonomous production BFT, fork choice, timeouts, and validator process ownership of consensus messages.
3. Production validator key custody and signing policy.
4. Crash-safe storage, migrations, backups, pruning, and state sync for public operators.
5. Production VM/runtime sandboxing.
6. Production verifier plugin execution, TEE, zk, or FHE adapters.
7. External audits for consensus, runtime, state tree, bridge, wallet, DEX, and app runtime.

## Noesis Cryptography And Novelty Research

The strongest crypto corpus is under `noesis-l1/docs/position-papers-v03-technical/`, `noesis-l1/docs/architecture/`, and the `flowchain-*` / `noesis-*` crates.

Primary entry points:

- `docs/HANDOFF-SUMMARY.md`
- `docs/RESEARCH-WAVES-INDEX.md`
- `docs/architecture/WHITEPAPER-V1.md`
- `docs/architecture/INVENTORY.md`
- `docs/position-papers-v03-technical/CODEX-HANDOFF.md`
- `docs/position-papers-v03-technical/AH-unified-v4.md`

Major primitive families:

- Process-Witness / PW-L1 soundness foundations
- predicate refinements
- composition primitives
- adversary models
- diagnostic primitives
- cross-domain cognitive primitives
- privacy and zk scaffolds
- recursion, STARK, lookup, and lattice proof scaffolds
- verifiable creativity and novelty attestations

Notable novelty work:

- `crates/noesis-creativity` defines verifiable creativity attestations.
- It binds a novelty commitment, edit-distance proof digest, embedding-distance proof digest, derivation-trajectory digest, output hash, and agent DID.
- It includes a challenge receipt path for third-party prior-art disputes.
- It explicitly marks production embedding model, production corpus shard, unconditional novelty guarantee, and challenge economics as not complete.

Critical crypto blockers:

- `AH-redteam-ghost.md` says Ghost Predicate is catastrophically broken as published; do not deploy it.
- Real Halo2 IPA circuit is not implemented end to end; current path is cost-model/scaffold.
- Production commitment scheme is not in place; docs call for Poseidon2 and Pasta IPA style replacements.
- PW attestations are not fully integrated as first-class production transactions through genesis, mempool, consensus, and slashing.
- Many Wave 18+ protocol crates are un-red-teamed at the protocol-composition level.
- Calibration Witness needs a large prediction count before it can be treated as cryptographic strength rather than a trust-grading signal.

## Rootflow And FlowCodec Archive

`FlowmemoryAI/rootflow` is not an L1. It is the Base/Uniswap v4 proof rail and memory-settlement archive.

Core Rootflow primitive:

```text
normal swap -> v4 afterSwap pulse -> deterministic work cursor -> dataset shard or memory slot -> worker job -> verifier quorum -> storage proof -> accepted artifact -> machine memory root -> optional fine-tuning batch
```

Rootflow status from the archive:

- contract family, deterministic fixture workers, simulations, tests, docs, and whitepaper exports exist
- Base mainnet canary artifacts exist, but public production launch remains blocked
- Rootflow V1 does not tax traders, profile wallets as the product, claim each swap directly trains an LLM, delay swap settlement, or deploy to Base mainnet without explicit approval

FlowCodec status from the archive:

- creates proof-carrying MemoryCapsules from event/state streams
- emits or consumes local `FlowCodecSignal` style evidence
- produces TracePointers, epoch roots, capsule hashes, proof metadata, reconstruction paths, and agent-memory query outputs
- integrates conceptually with Rootflow by mapping `MemoryCapsule -> storage proof -> Rootflow job/quorum/settlement`

Strong combined primitive:

```text
A settled, proof-carrying MemoryCapsule.
```

Rootflow/FlowCodec should feed FlowMemory V0 and Noesis research, but it should not be treated as approval for production Uniswap v4 deployment.

## Earlier AI-L1 Research Archive

`FlowMemory-2026-05-11/docs/ai-l1` is the earlier research package. It is useful for direction, naming, competitor analysis, source maps, and decision framing.

Key direction:

- The L1 is justified only if AI Work Receipts are the base state model.
- If receipts are merely one app, the project should be an app, appchain, or AVS instead.
- Best wedge: native receipt state for autonomous AI work.
- Avoid generic AI blockchain, GPU marketplace, chatbot token, prediction market, or generic compute-routing framing.

Recommended architecture in the archive:

- Rust node
- Move-inspired object model
- WASM verifier plugins
- TypeScript SDK after the Rust devnet works
- local content-addressed storage first, with R2/IPFS/Filecoin-style adapters later

Core MVP:

```text
An AI agent writes a response, calls tools, updates memory, and the chain proves what happened with receipts.
```

## Recommended Direction

Do not start by "building the L1 completely out" in the current FlowMemory main repo.

The correct next step is to turn the Noesis / Flow Chain corpus into a gated research and hardening program:

1. Preserve Noesis as an external research/source corpus for now.
2. Create a small source map from Noesis concepts into FlowMemory V0 objects:
   - `AIWorkReceipt` -> `MemoryReceipt` / `WorkReceiptRegistry` concepts
   - `MemoryCell` -> `AgentMemoryView` / Rootfield bundle concepts
   - checkpoints and evidence packets -> verifier report and root bundle concepts
   - verifier modules -> FlowMemory verifier schema and future registry boundaries
   - Noesis index/read-model -> FlowMemory indexer/verifier and dashboard views
3. Build no-value local test artifacts only before any public network work.
4. Extract crypto lessons into FlowMemory schemas before importing any heavy Noesis proof systems.
5. Treat Rootflow/FlowCodec as the V0 proof-carrying memory rail and Noesis as the longer-term AI-native state research path.
6. Keep production L1, tokenomics, bridge, validator economics, and mainnet out of scope until explicit go/no-go criteria pass.

## Immediate Agent Assignments

### Chain / Research Agent

Recommended worktree: `E:\FlowMemory\flowmemory-chain`

Allowed folders:

- `docs/`
- `research/`

Forbidden folders:

- `contracts/`
- `services/`
- `crypto/`
- `apps/`
- `hardware/`

Goal:

```text
/goal Research-only Noesis / Flow Chain source map.

Read docs/L1_RESEARCH_INVENTORY.md and inspect the cloned source at E:\FlowMemory\github-research-sources\noesis-l1. Create a docs/DECISIONS proposed decision or research note that maps Noesis concepts into FlowMemory V0 without importing code. Focus on AIWorkReceipt, MemoryCell, verifier modules, evidence packets, checkpoints, local devnet gaps, and production blockers. Do not build product code. Do not work on tokenomics, mainnet, production validators, bridges, or deployment. Run git diff --check.
```

### Crypto Agent

Recommended worktree: `E:\FlowMemory\flowmemory-crypto`

Allowed folders:

- `docs/`
- `crypto/`
- `schemas/`
- `fixtures/`

Forbidden folders:

- `contracts/`
- `services/`
- `apps/`
- `hardware/`

Goal:

```text
/goal Crypto research extraction from Noesis.

Read docs/L1_RESEARCH_INVENTORY.md and inspect Noesis crypto docs under E:\FlowMemory\github-research-sources\noesis-l1\docs\position-papers-v03-technical plus crates/flowchain-pw and crates/noesis-creativity. Produce a conservative FlowMemory crypto research note that identifies which primitives can inform V0 schemas now, which are unsafe or broken, and which require red-team work. Do not import Noesis code. Explicitly flag Ghost Predicate as blocked. Do not build proof circuits, GPU proofs, tokenomics, or production verifier economics. Run git diff --check.
```

### Review Agent

Recommended worktree: `E:\FlowMemory\flowmemory-review`

Allowed folders:

- `docs/`
- `.github/`

Forbidden folders:

- `contracts/`
- `services/`
- `crypto/`
- `apps/`
- `hardware/`

Goal:

```text
/goal Review L1 research boundaries.

Read docs/L1_RESEARCH_INVENTORY.md, docs/CURRENT_STATE.md, docs/ROADMAP.md, and docs/MARKETING_CLAIMS_GUARDRAILS.md. Create or update a review note listing unsafe claims that agents must not make when referencing Noesis, Rootflow, FlowCodec, Flow Chain, Continuum, PW-L1, and novelty proofs. Keep it docs-only. Do not build product code. Run git diff --check.
```

## Issues To Prioritize

Use existing issues before creating new ones:

- #18: future appchain or L1 go/no-go criteria
- #35: no-value appchain prototype criteria
- #36: Base settlement anchor spec
- #37: appchain hardware node requirements
- #41: bridge and security review requirements
- #42: zk proof-carrying receipt milestones
- #47: crypto package integration boundary
- #50: no-value appchain prototype framework
- #51: local FlowPulse receipt fixture handoff

New issues should be created only if they are narrower than the existing backlog. Suggested new issues:

1. `[research/chain] Map Noesis AI objects to FlowMemory V0 objects`
2. `[research/crypto] Audit Noesis PW-L1 primitives for FlowMemory V0 relevance`
3. `[review] Add Noesis and Flow Chain claim guardrails`
4. `[chain/devnet] Compare FlowMemory devnet and Noesis local devnet boundaries`
5. `[docs/architecture] Define Rootflow, FlowCodec, FlowMemory, and Noesis relationship map`

## Not Approved Yet

Do not assign agents to:

- production L1 implementation
- tokenomics
- public token launch
- production validator set
- mainnet genesis
- production bridge
- production Uniswap v4 hook deployment
- full dashboard
- GPU proof systems
- claim that Noesis is production-ready
- claim that novelty proofs are unconditional
- claim that AI runs on-chain
