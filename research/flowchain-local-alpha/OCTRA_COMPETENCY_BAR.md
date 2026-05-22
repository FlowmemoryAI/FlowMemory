# external local-chain reference Competency Bar For FlowChain Local Alpha

Last updated: 2026-05-13

Status: comparison-derived research reference. The external local-chain reference material is treated as a user-supplied design reference, not as an independently re-crawled live audit.

## Purpose

The external local-chain reference comparison is useful because it highlights an alpha-stage chain pattern: ambitious cryptography becomes credible only when the local control plane is coherent. FlowChain Local Alpha should copy that discipline, not external local-chain reference's product category or bridge/encrypted-coprocessor ambition.

## Status Vocabulary

- **Implemented**: merged into FlowMemory as of `docs/CURRENT_STATE.md` dated 2026-05-13 or confirmed from `origin/main` on 2026-05-13.
- **Local-alpha target**: required bar for a future FlowChain Local Alpha build.
- **Later research**: useful later, blocked behind review.
- **Blocked**: cannot move to implementation until named prerequisites are met.
- **Explicitly later**: outside Local Alpha.

## Competency Matrix

| external local-chain reference signal | FlowChain interpretation | Status | Local Alpha evidence required |
| --- | --- | --- | --- |
| Local encrypted wallet/vault | FlowMemory needs a local secret vault for agent keys, wallet keys, API keys, hardware keys, and private receipt workspaces. | Local-alpha target | Import, export, unlock, rotate, lock, corrupt-file recovery, and no plaintext secret persistence in logs or fixtures. |
| Unified JSON-RPC/control API | FlowMemory needs one local API for receipt, memory, artifact, verifier, challenge, dependency, finality, and devnet resources. | Local-alpha target | Versioned schemas, idempotent commands, pagination, retry semantics, stable error shapes, and compatibility snapshots. |
| Public and encrypted state lanes | FlowMemory must separate public receipt metadata from private artifact references and secret material. | Local-alpha target | Public receipt views show commitments and statuses; private views require local vault unlock and never publish locators by accident. |
| Stealth/discovery/claim lifecycle | FlowMemory equivalent is artifact and memory discovery, selection, finalization, and reconciliation. | Local-alpha target | Workbench can show discovered references, claim/reconcile status, missing evidence, and finality changes. |
| Source-visible compile/tool pipeline | FlowMemory equivalent is source-visible schemas, verifier modules, generated reports, and fixture pipelines. | Local-alpha target | Every report names schema hash, verifier module hash, fixture/release hash, and deterministic command path. |
| Integrated browser workbench | FlowMemory needs a receipt and memory workbench before broad app ecosystem claims. | Local-alpha target | A user can inspect the full path from FlowPulse observation to receipt to verifier report to memory/root transition. |
| Source verification/provenance registry | FlowMemory needs artifact and verifier provenance. | Local-alpha target | Registry or manifest links objects to source path, version, hash, schema, generated artifact, and release bundle. |
| Explorer/history observability | FlowMemory must make lineage, challenge state, artifact state, verifier reports, dependency roots, and finality visible. | Implemented foundation, Local-alpha target for completeness | Dashboard/explorer shows every lifecycle state without requiring raw JSON inspection. |
| Bridge orchestration | FlowMemory should not attempt production bridge parity yet. | Explicitly later | Only no-value Base anchor placeholders and bridge-security research docs are acceptable in Local Alpha. |
| Node role topology | FlowMemory needs explicit local node, indexer, verifier, dashboard, hardware observer, and review roles. | Implemented foundation, Local-alpha target for polish | Topology docs and release manifests tell operators which role does what and what it cannot claim. |

## Concrete Surface Bar

This is the external local-chain reference-level comparison reduced to the surfaces FlowMemory actually needs. These are local/private testnet targets, not public chain claims.

The accepted control-plane boundary is recorded in `docs/DECISIONS/2026-05-13-flowchain-local-alpha-control-plane-boundary.md`.

| Surface | Status | Local/private testnet bar | Later or blocked boundary |
| --- | --- | --- | --- |
| Wallet/operator vault | Local-alpha target | Local operator secrets, agent keys, test wallet keys, API credentials, hardware channel keys, and private reference keys are encrypted at rest, unlockable, lockable, exportable only through explicit encrypted export, rotatable, and recoverable after corrupt-file detection without silent identity replacement. | Not a production wallet, MPC system, custody product, token wallet, or public validator key manager. |
| Local API | Local-alpha target | One versioned local API exposes receipts, memory cells/views, artifacts, verifier modules/reports, challenges, dependencies, finality, devnet state, release manifests, stable ids, pagination, retries, and typed errors. | Not a hosted production API or public RPC. |
| Explorer/workbench | Implemented foundation, Local-alpha target | A builder can inspect the path from FlowPulse observation to receipt, verifier report, Rootflow transition, memory lineage, artifact state, dependency root, challenge, and finality without raw JSON inspection. | Not a public validator explorer, bridge explorer, token explorer, or production encrypted-compute console. |
| Devnet/runtime | Implemented foundation, Local-alpha target | The no-value runtime supports deterministic genesis/reset, fixture import/export, submit/run/inspect flows, state-root and block-hash visibility, Base anchor placeholders, and failure fixtures. | Not production consensus, public sequencer operation, value movement, or bridge settlement. |
| Source/provenance | Local-alpha target | Schemas, verifier modules, generated reports, deployment/canary artifacts, fixture inputs, release outputs, and dashboard data identify source paths, versions, hashes, commands, and compatibility notes. | Provenance is reproducibility evidence, not proof of truth or trustless verification. |
| Crypto vectors | Implemented foundation, Local-alpha target | Accepted object ids and hashes have deterministic vectors, negative vectors, cross-language checks where practical, schema ids, domain separation, and replay-boundary tests before library promotion. | No speculative Process-Witness, SEAL, encrypted compute, or proof-carrying receipt primitives enter production libraries without accepted decisions and review. |
| Release packaging | Local-alpha target | A local-alpha release includes git commit, fixture hashes, schema hashes, verifier module hashes, generated output hashes, devnet handoff hash, reproduction commands, migration notes, known limitations, and non-claims. | Not a public devnet, public L1, mainnet, bridge, token, validator, or production proof release. |

## 1. Local Workbench

**Local-alpha target**: The workbench is the center of FlowChain Local Alpha. It should be a receipt and memory control plane, not a wallet-first marketing surface.

Minimum workbench areas:

| Area | Status | Required behavior |
| --- | --- | --- |
| Accounts and local vault | Local-alpha target | Manage local accounts, agent identities, hardware links, and secrets through an encrypted vault boundary. |
| Work receipts | Implemented foundation, Local-alpha target | List, inspect, submit/import fixtures, replay verification, and show status transitions. |
| Memory lineage | Implemented foundation, Local-alpha target | Show memory objects, parent receipts, root transitions, source observations, and stale/rejected dependencies. |
| Artifact availability | Implemented foundation, Local-alpha target | Show artifact roots, manifests/references, availability reports, missing evidence, and challenge state. |
| Verifier modules and reports | Implemented foundation, Local-alpha target | Show verifier identity, module provenance, report digest, check list, status, evidence commitment, and reproducibility path. |
| Challenges and finality | Local-alpha target | Show open, responded, upheld, dismissed, expired, superseded, downgraded, and finalized states. |
| Dependency roots | Local-alpha target | Show declared dependencies and dependency-class assumptions without implying SEAL ZK proofs exist. |
| Fixture runner and devnet state | Implemented foundation, Local-alpha target | Run or inspect deterministic no-value fixtures, local blocks, state roots, and Base anchor placeholders. |

Acceptance evidence:

- **Local-alpha target**: A builder can answer "why does this memory exist?" from the workbench.
- **Local-alpha target**: A builder can answer "which verifier accepted this receipt and under what module?" from the workbench.
- **Local-alpha target**: A builder can answer "what happens if this artifact is missing or this dependency is rejected?" from the workbench.
- **Explicitly later**: The workbench does not need public validator management, token management, bridge withdrawals, or encrypted compute jobs.

## 2. API

**Local-alpha target**: The local API should be the shared control plane for agents, the workbench, explorer, tests, and release tooling.

Minimum resource families:

| Resource family | Status | Required local methods |
| --- | --- | --- |
| Receipts | Implemented foundation, Local-alpha target | create/import, get, list, replay, attach artifact, attach verifier report, transition status. |
| Memory | Implemented foundation, Local-alpha target | get cell/view, list lineage, explain source receipts, mark stale/downgraded, export capsule. |
| Artifacts | Implemented foundation, Local-alpha target | register commitment, attach manifest/reference, check availability, challenge missing or changed data. |
| Verifiers | Implemented foundation, Local-alpha target | register module metadata, run deterministic check, get report, list module provenance. |
| Challenges | Local-alpha target | open, respond, resolve, expire, recompute affected receipt/memory state. |
| Dependencies | Local-alpha target | declare dependency atoms, group by root, set dependence class, mark omission challenge. |
| Devnet | Implemented foundation, Local-alpha target | reset, submit fixture, run block, inspect state, export handoff, inspect anchor placeholder. |
| Releases | Local-alpha target | produce manifest, verify fixture hash, check schema compatibility, list known limitations. |

API acceptance rules:

- **Local-alpha target**: Methods are deterministic against the same fixture inputs.
- **Local-alpha target**: Errors are typed and stable enough for agents and tests to consume.
- **Local-alpha target**: API results include status labels that distinguish observed, pending, verified, failed, unresolved, unsupported, reorged, challenged, downgraded, and finalized states.
- **Explicitly later**: No hosted production API is implied.

## 3. Devnet

**Implemented foundation**: The current Rust local devnet already provides deterministic local transactions, blocks, state roots, block hashes, and handoff fixtures.

**Local-alpha target**: FlowChain Local Alpha should harden the devnet into a reliable object-model test rig.

Required capabilities:

- Deterministic genesis and reset.
- Fixture import and export for indexer, verifier, dashboard, and workbench.
- Explicit no-value transaction types for receipts, memory transitions, verifier reports, challenges, artifact commitments, and dependency declarations.
- State-root and block-hash inspection.
- Base anchor placeholder inspection.
- Golden fixture snapshots for releases.
- Failure fixtures for malformed receipt, missing artifact, stale verifier report, reorged observation, dependency omission, and challenge downgrade.

Forbidden claims:

- **Explicitly later**: No production consensus.
- **Explicitly later**: No public validators.
- **Explicitly later**: No sequencer or validator economics.
- **Explicitly later**: No bridge or value movement.
- **Explicitly later**: No mainnet-readiness claim.

## 4. Explorer

**Implemented foundation**: Dashboard V0 already renders fixture-backed views across Flow Memory, Rootflow, FlowPulse, Rootfields, receipts, reports, devnet blocks, hardware nodes, alerts, and raw JSON.

**Local-alpha target**: The explorer should become the public truth table for local state, while still labeling local/test data clearly.

Explorer requirements:

- Receipt lifecycle timeline.
- Memory lineage graph or table.
- Artifact state and availability history.
- Verifier report checks and provenance.
- Challenge windows and outcomes.
- Dependency roots and declared dependence class.
- Finality and downgrade history.
- Devnet block/state-root view.
- Release manifest and schema compatibility view.

Explorer non-goals:

- **Explicitly later**: Public network validator explorer.
- **Explicitly later**: Bridge explorer.
- **Explicitly later**: Token or fee explorer.
- **Explicitly later**: Production encrypted compute job explorer.

## 5. Provenance

**Local-alpha target**: Provenance is the anti-chaos layer. Every important local-alpha object should say what produced it.

Minimum provenance fields:

| Object | Status | Provenance fields |
| --- | --- | --- |
| Schema | Implemented foundation, Local-alpha target | schema id, version, hash, source path, compatibility notes. |
| Verifier module | Local-alpha target | module id, source path, version, hash, input schemas, output schemas, deterministic command. |
| Verifier report | Implemented foundation, Local-alpha target | report id, verifier id, module id/hash, schema hash, evidence commitment, command/version, result status. |
| Receipt | Implemented foundation, Local-alpha target | receipt id/hash, schema hash, source observation, artifact root, dependency root, parent receipt, verifier reports. |
| Artifact reference | Local-alpha target | artifact root, manifest hash, locator policy, privacy class, availability checks, challenge state. |
| Release | Local-alpha target | release id, git commit, fixture hashes, schema hashes, verifier module hashes, generated output hashes, known limitations. |

Provenance limits:

- **Local-alpha target**: Provenance proves reproducibility and lineage, not truth.
- **Later research**: Proof-carrying provenance can replace some verifier claims only after public inputs, witnesses, costs, and challenge rules are reviewed.

## 6. Object Model

**Local-alpha target**: FlowChain should be judged by whether its object model is useful before any L1/appchain work resumes.

Minimum Local Alpha objects:

- `WorkReceipt`: compact record of work claim, roots, artifact, parent receipt, status, and verifier reports.
- `MemoryCell`: memory unit derived from receipts, Rootflow transitions, dependency declarations, and finality.
- `ArtifactAvailabilityProof`: availability claim or report tied to artifact root, manifest, locator policy, and challenge status.
- `VerifierModule`: source-visible check policy that produces deterministic reports.
- `Challenge`: state object for disputes, missing artifacts, dependency omissions, stale finality, or invalid reports.
- `FinalityReceipt`: status explanation for accepted, rejected, unresolved, downgraded, superseded, or finalized outcomes.
- `DependencyRoot`: declared evidence/tool/model/data dependency commitment.
- `AIWorkReceipt`: research-specific extension of `WorkReceipt`; useful in research docs, not required as product naming.

## 7. Releases

**Local-alpha target**: Local Alpha releases should be reproducible, not aspirational.

Release bundle requirements:

- Git commit and branch.
- Schema versions and hashes.
- Fixture input and generated output hashes.
- Devnet handoff output hash.
- Verifier module hashes.
- Dashboard/workbench data snapshot hash.
- Migration notes from prior local-alpha release.
- Known limitations and non-claims.
- Reproduction commands.
- `git diff --check` and area checks used for that release.

Release non-claims:

- **Explicitly later**: No production mainnet.
- **Explicitly later**: No public L1.
- **Explicitly later**: No production validators.
- **Explicitly later**: No tokenomics.
- **Explicitly later**: No production bridge.
- **Explicitly later**: No production proof system.

## Competency Bar Summary

FlowChain Local Alpha reaches the external local-chain reference-level bar when a local developer can:

1. **Local-alpha target**: unlock local secrets without leaking them to logs, fixtures, public receipts, or chain data.
2. **Local-alpha target**: use one local API to create or inspect receipts, memory, artifacts, verifier reports, challenges, dependencies, and devnet state.
3. **Local-alpha target**: run deterministic no-value fixtures and inspect resulting state roots.
4. **Local-alpha target**: open an explorer/workbench and understand lineage, challenge state, and finality without reading raw JSON.
5. **Local-alpha target**: verify which source, schema, verifier module, and release produced each object.
6. **Local-alpha target**: ship a reproducible local-alpha release that says exactly what is implemented and what is not.

If these are not true, FlowMemory should not resume serious public L1/appchain work.
