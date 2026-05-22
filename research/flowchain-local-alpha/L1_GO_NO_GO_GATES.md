# FlowChain L1 And Appchain Go/No-Go Gates

Last updated: 2026-05-13

Status: research gate. This document does not approve production validators, a public L1, tokenomics, bridges, mainnet deployment, or production proof systems.

## Purpose

FlowChain should become chain-shaped only if the local object model proves that AI work, memory, artifacts, verifier decisions, dependencies, challenges, and finality are meaningfully stronger as native state than as app-level logs.

## Status Vocabulary

- **Implemented**: merged into FlowMemory as of `docs/CURRENT_STATE.md` dated 2026-05-13 or confirmed from `origin/main` on 2026-05-13.
- **Local-alpha target**: required before serious L1/appchain work resumes.
- **Later research**: useful future work behind explicit review.
- **Blocked**: cannot move to implementation until named prerequisites are met.
- **No-go**: condition that blocks advancement.
- **Explicitly later**: outside Local Alpha.

## Master Decision Question

**Later research**: A custom appchain or L1 is justified only if the project can answer yes:

```text
Would FlowMemory be meaningfully weaker if work receipts, memory cells, artifact proofs, dependency roots, verifier decisions, challenges, and finality receipts were only app-level logs on Base or another existing chain?
```

If the answer is no, the go decision is to keep building product, verifier, dashboard, and Base settlement paths first.

## Named Build Gates

These are the gates builders should use when deciding what may move from research into implementation.

| Gate | Status | Meaning | Allowed now | Blocked |
| --- | --- | --- | --- | --- |
| Local/private testnet | Local-alpha target | A no-value, local/private, second-computer-validatable package for FlowMemory object-state testing. | Research gates, object model specs, local control-plane acceptance criteria, fixture/release requirements, and later implementation by the owning agents after Gate 1 and Gate 2 pass. | Public validators, public sequencers, tokenomics, bridge value movement, production proof systems, production encrypted compute, or public mainnet claims. |
| Public devnet | Later research, Blocked | A public no-value, resettable experimental network where external operators may run nodes or inspect state. | Requirements drafting and threat-model review only. | Any public-network launch until the local/private testnet package is reproducible, monitored, and reviewed. |
| Public L1/mainnet | Explicitly later, Blocked | A production or value-bearing chain/network claim. | None beyond documenting blockers and review requirements. | Implementation, launch planning, validator economics, bridge deployment, token mechanics, or production proof claims. |

The local/private testnet gate is the only gate that can be targeted by the current Ralph loop. Public devnet and public L1/mainnet remain research gates.

## Gate 0: Local Alpha Research Boundary

Status: **Local-alpha target**.

Gate 0 is passed when the research-to-build boundary is clear enough for builders to implement local features without importing forbidden scope.

Required evidence:

| Requirement | Status | Pass condition |
| --- | --- | --- |
| Architecture reference | Local-alpha target | Local workbench, API, devnet, explorer, provenance, object model, releases, and later work are defined. |
| external local-chain reference competency bar | Local-alpha target | Control-plane parity is translated into FlowMemory-specific acceptance criteria. |
| L1 gates | Local-alpha target | Go/no-go gates exist before validator, public chain, token, bridge, or proof work. |
| Crypto research map | Local-alpha target | Process-Witness, SEAL, Synthetic Non-Amplification, proof-carrying receipts, and R&D/library boundaries are mapped. |
| Private state roadmap | Local-alpha target | Local vault, private references, dependency privacy, and encrypted compute sequence is explicit. |

No-go conditions:

- **No-go**: The docs imply production L1, validator, token, bridge, or encrypted-compute approval.
- **No-go**: The docs blur implemented V0 facts with later research.
- **No-go**: The docs authorize implementation outside the assigned research scope.

## Gate 1: Local Object Model Acceptance

Status: **Local-alpha target**.

Gate 1 is passed when FlowMemory can show that the native objects are useful locally before choosing any production chain framework.

Required evidence:

| Object or workflow | Status | Pass condition |
| --- | --- | --- |
| WorkReceipt lifecycle | Implemented foundation, Local-alpha target | Submit/import, index, verify, challenge, accept/reject, finalize, and recompute after dependency change. |
| MemoryCell lineage | Local-alpha target | Memory can be traced to source receipts, Rootflow transitions, artifacts, dependencies, verifier reports, and finality state. |
| Artifact availability | Implemented foundation, Local-alpha target | Missing, changed, duplicated, expired, and recovered artifacts have deterministic states. |
| Verifier module provenance | Local-alpha target | Reports identify source-visible module, schema, version, hash, and reproducible command. |
| Challenge state | Local-alpha target | Challenges can be opened, responded to, resolved, expired, or used to downgrade finality. |
| Dependency declarations | Local-alpha target | Evidence/tool/model/data dependencies can be declared, rooted, displayed, challenged, and recomputed. |
| Synthetic Non-Amplification | Local-alpha target | Synthetic outputs cannot increase empirical certainty without real-world validation. |
| Workbench/explorer explanation | Local-alpha target | A builder can inspect why a memory exists and what would invalidate it. |

No-go conditions:

- **No-go**: Receipts cannot be replayed or explained from source observations and artifacts.
- **No-go**: Memory updates can be accepted from rejected, stale, or unavailable sources without clear status.
- **No-go**: Verifier reports are opaque and cannot be reproduced from declared modules and schemas.
- **No-go**: Synthetic evidence is treated as empirical support.
- **No-go**: Dependency omissions have no challenge or downgrade path.

## Gate 2: Local Control Plane Acceptance

Status: **Local-alpha target**.

Gate 2 is passed when the local workbench, API, devnet, explorer, provenance, and release machinery can be used by builders without reading raw JSON for ordinary workflows.

Required evidence:

| Competency | Status | Pass condition |
| --- | --- | --- |
| Local vault | Local-alpha target | Local secrets are encrypted at rest, recoverable, rotatable, and never written to normal logs or committed fixtures. |
| Local API | Local-alpha target | Stable versioned methods exist for receipts, memory, artifacts, verifiers, challenges, dependencies, devnet, and releases. |
| Devnet | Implemented foundation, Local-alpha target | Deterministic no-value reset, submit-fixture, run-block, inspect-state, and export-fixture flows are covered by golden tests. |
| Explorer | Implemented foundation, Local-alpha target | Every lifecycle state is visible with clear local/test labels. |
| Provenance | Local-alpha target | Schemas, verifier modules, reports, receipts, artifacts, and releases are hash-addressed and source-visible. |
| Releases | Local-alpha target | Local-alpha releases include manifests, fixture hashes, limitations, migration notes, and reproduction commands. |

No-go conditions:

- **No-go**: Local secrets appear in logs, URIs, fixtures, public receipts, or chain data.
- **No-go**: API error shapes or ids are unstable enough that agents cannot rely on them.
- **No-go**: Explorer views hide challenge, unresolved, unsupported, reorged, or downgraded states.
- **No-go**: Releases cannot be reproduced from committed commands and fixtures.

## Gate 3: Local/Private Testnet Gate

Status: **Local-alpha target, blocked until Gates 1 and 2 pass**.

Gate 3 is the first gate that can move from research to implementation. It creates a no-value local/private testnet package that a clean second computer can clone, initialize, run, inspect, smoke-test, export, import, and rerun deterministically.

This gate is allowed to harden the current local no-value devnet and FlowMemory control plane. It is not allowed to create a public chain, validator market, bridge, token, or production proof system.

Required evidence:

| Requirement | Status | Pass condition |
| --- | --- | --- |
| Second-computer path | Local-alpha target | Clone, install, initialize local/private state, run node/runtime, run demo, run smoke, export state, import state, and rerun deterministically. |
| Object model freeze | Local-alpha target | Local Alpha has a stable receipt/memory/challenge/dependency state model with migration notes. |
| Local operator vault boundary | Local-alpha target | Local secrets are encrypted, unlock state is explicit, and normal logs/fixtures/public receipts never contain private material. |
| Data reconstruction plan | Local-alpha target | A new local/private node can reconstruct public state from defined fixture/devnet data or mark missing data unresolved. |
| Base anchor placeholder model | Implemented research placeholder, Local-alpha target | Anchor fields are reviewed for state-root, receipt-root, verifier-report-root, artifact-root, previous-anchor, finality, and replay semantics. |
| Framework trade study | Local-alpha target | Current custom Rust devnet, OP Stack/Base Appchain-style devnet, and app-level Base settlement are compared against object-model needs before replacing the current prototype. |
| Security review plan | Local-alpha target | Bridge, DA, replay, key custody, emergency pause, monitoring, and incident response review tasks are opened, even if marked later. |
| Release package | Local-alpha target | Release manifest includes commit, fixture hashes, schema hashes, verifier module hashes, local commands, limitations, and non-claims. |

No-go conditions:

- **No-go**: Appchain work would require raw memory, artifacts, model outputs, media, or secrets on-chain.
- **No-go**: Anchor roots cannot be reconciled by indexers.
- **No-go**: Verifier reports can be marked verified without available evidence.
- **No-go**: The team cannot explain inherited proof, DA, and finality assumptions of the selected framework.
- **No-go**: A local/private release requires a public RPC, production wallet, bridge, or deployed public network to pass.

## Gate 4: Public Devnet Gate

Status: **Later research, Blocked until Gate 3 passes**.

Gate 4 is the earliest gate where a public no-value, resettable devnet can be discussed. It is not approved by Local Alpha. It requires the local/private testnet package to be reproducible first.

Required evidence:

| Requirement | Status | Pass condition |
| --- | --- | --- |
| Local/private release evidence | Later research | Gate 3 has a reproducible release, smoke test, export/import path, and known-limitation manifest. |
| Independent architecture review | Later research | Object model, state transition rules, DA assumptions, finality, and challenge semantics are reviewed. |
| Threat model update | Later research | The cryptography, verifier, appchain, bridge, private state, hardware observer, and operator threat models are current. |
| Public inputs and witnesses | Later research | Any proof-carrying receipt or dependency proof has exact public inputs, witness formats, privacy rules, and cost model. |
| Validator/sequencer role analysis | Later research | Roles, failures, monitoring, handoff, equivocation handling, and governance are documented without tokenomics. |
| Validator/sequencer economics boundary | Blocked | Public devnet may document cost and abuse constraints, but staking, rewards, fees, slashing, or token mechanics remain blocked until a separate economics decision exists. |
| Operational monitoring plan | Later research | Indexer lag, verifier outage, reorg, missing data, and challenge response workflows are observable. |
| Public operator policy | Later research | Key custody, source verification, release signing, operator onboarding, and incident response are documented. |

No-go conditions:

- **No-go**: Production validators are proposed before local object-model acceptance.
- **No-go**: Tokenomics, rewards, staking, or slashing are introduced as a workaround for missing security design.
- **No-go**: Public chain claims rely on unreviewed Process-Witness, SEAL, encrypted compute, or proof systems.
- **No-go**: Hardware observers are treated as validators, sequencers, DA providers, or bridge operators.
- **No-go**: The public devnet cannot be reset, halted, rolled back, or labeled experimental without confusing users.

## Gate 5: Public L1/Mainnet Or Value-Bearing Production

Status: **Explicitly later, Blocked**.

Gate 5 is blocked until a separate production-readiness program exists. Local Alpha and the local/private testnet loop must not plan, imply, or market this gate.

Required before this gate can even be drafted:

- **Later research**: Gate 4 public devnet evidence and incident-history review.
- **Later research**: Bridge design review.
- **Later research**: DA review and reconstruction tests.
- **Later research**: Replay-protection review.
- **Later research**: Key custody review.
- **Later research**: Governance and upgrade policy.
- **Later research**: Emergency pause policy.
- **Later research**: Monitoring and incident response drill.
- **Later research**: Independent cryptography and contract audits.
- **Later research**: Production verifier network design.
- **Later research**: Legal and economic review if value or token mechanics are proposed.
- **Blocked**: Validator/sequencer economics, staking, rewards, fees, or slashing until a separate token/economics scope is explicitly approved.

Immediate no-go conditions from the existing chain research:

- **No-go**: Unclear withdrawal finality.
- **No-go**: Unclear DA source or retention.
- **No-go**: No replay protection.
- **No-go**: No emergency pause policy.
- **No-go**: No independent bridge/security review.
- **No-go**: Anchor roots cannot be reconciled by indexers.
- **No-go**: Verified status can be assigned without available evidence.
- **No-go**: Appchain value requires moving raw memory, artifacts, or evidence on-chain.

## Topic Boundary Table

| Topic | Status | Allowed next action | Blocked action |
| --- | --- | --- | --- |
| Local workbench | Local-alpha target | Specify and later build receipt/memory/artifact/verifier/challenge views. | Claim hosted production product readiness. |
| Local API | Local-alpha target | Specify stable local resource methods and schemas. | Launch production API. |
| No-value devnet | Implemented foundation, Local-alpha target | Harden deterministic fixtures and handoff outputs. | Public validator or sequencer deployment. |
| Base anchors | Implemented placeholder, Later research | Review compact anchor fields and reconciliation. | Production settlement or bridge claim. |
| Process-Witness | Later research | Map candidate primitives to receipt obligations and proof candidates. | Build production cognition proof system. |
| SEAL/dependency proofs | Later research | Define dependency vocabulary and challenge model. | Claim ZK dependence proofs are available. |
| Synthetic Non-Amplification | Local-alpha target | Enforce as a state invariant in specs and tests. | Let synthetic data increase empirical certainty. |
| Private state | Local-alpha target, Later research | Start with local vault and private artifact references. | Build encrypted compute. |
| Tokenomics | Explicitly later | None in Local Alpha. | Any fee, staking, reward, token, or slashing design. |
| Bridges | Explicitly later | Keep bridge security research gates. | Bridge deployment or value movement. |
| Production proof systems | Later research | Define public inputs, witnesses, setup assumptions, costs, and review gates. | Production circuits or verifier economics. |

## Requirements Before Moving Research Topics To Implementation

Status: **Local-alpha target for vocabulary, Blocked or Later research for protocol implementation**.

These topics may shape local/private testnet schemas and fixtures, but they do not move to production code merely because they appear in research docs.

| Topic | Current status | Minimum before implementation | Implementation still blocked from |
| --- | --- | --- | --- |
| Process-Witness | Later research | Accepted receipt obligation vocabulary, exact predicates, public inputs, witness formats, adversary model, cost model, and independent crypto review. | Cognitive proof circuits, claims that the chain proves intelligence/truth, or mandatory dependency for Local Alpha. |
| SEAL/dependency privacy | Later research; local vocabulary target | Dependency atom schema, dependency root format, completeness attestation scope, omitted-dependency challenge flow, downgrade semantics, public inputs, witness privacy rules, and review. | ZK dependence claims, hidden dependency omissions, or evidence independence claims without completeness warranties. |
| Synthetic Non-Amplification | Local-alpha target | Receipt/report/memory status rules that mark synthetic outputs as hypothesis, counterexample, challenge debt, or validation requirement unless deterministic formal verification applies. | Empirical certainty increases, biological/scientific finality, or memory trust upgrades based only on generated data. |
| Proof-carrying receipts | Later research | Stable receipt/report schemas, canonical vectors, exact proof public inputs, witness privacy rules, proof system choice, setup assumptions, challenge semantics, and cost model versus replay. | Production circuits, contract proof verification, or replacing deterministic verifier reports before review. |
| Advanced encrypted compute | Explicitly later, Blocked | Stable public/private data model, local vault, private reference envelope, threat model, key custody, side-channel/leakage review, DA/auditability policy, incident response, and independent security review. | FHE/MPC/TEE/coprocessor runtime, encrypted mempool, private inference, or production encrypted smart-contract claims. |
| Bridge security | Explicitly later, Blocked | Deposit/withdrawal messages, nonce/replay rules, source/destination binding, withdrawal finality, DA source, emergency pause, upgrade delay, monitoring, recovery, and independent review. | Value movement, production bridge deployment, public withdrawal claims, or any bridge that can move assets. |
| Validator/sequencer economics | Explicitly later, Blocked | Non-economic role analysis first: responsibilities, failures, equivocation, monitoring, governance, emergency operations, and public-devnet operating constraints. Separate economics/token scope required after that. | Tokenomics, staking, rewards, fee markets, slashing, validator incentives, or revenue claims. |

## Minimum Go Packet For Any Future Appchain Discussion

Status: **Later research**.

A future appchain discussion should include:

1. Gate 1 and Gate 2 evidence.
2. A precise state-machine diff showing what cannot be represented well as app-level Base logs.
3. A data availability and reconstruction plan.
4. A finality and downgrade model.
5. A challenge state machine.
6. A public input and witness map for any proofs.
7. A bridge/security non-goal statement if no bridge is proposed.
8. A release and rollback plan.
9. A claim guardrail review.
10. A list of independent reviewers needed before public testnet.
