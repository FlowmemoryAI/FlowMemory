# FlowChain Local Alpha Control-Plane Boundary

Date: 2026-05-13

## Status

Accepted for research and implementation gating.

## Context

The Octra comparison showed that an advanced chain feels credible only when its local developer and operator control plane is coherent. FlowMemory should absorb that lesson without copying Octra's bridge, token, encrypted-coprocessor, or public-network ambitions into Local Alpha.

FlowMemory already has launch-core fixtures, local verifier reports, a fixture-backed dashboard, a no-value local devnet prototype, and guarded canary evidence. The missing local-alpha surface is a unified way to inspect and operate receipts, memory lineage, artifacts, verifier reports, dependencies, challenges, finality, provenance, and releases.

## Decision

FlowChain Local Alpha must treat the local control plane as a requirement before public appchain or L1 work resumes.

The accepted local/private surface bar is:

- **Wallet/operator vault**: local encrypted boundary for operator, agent, test wallet, API, hardware, and private-reference secrets.
- **Local API**: one versioned local interface for receipts, memory, artifacts, verifiers, challenges, dependencies, finality, devnet state, and releases.
- **Explorer/workbench**: local UI surface that explains lineage, artifact state, verifier decisions, challenge state, dependency roots, and finality without raw JSON inspection.
- **Devnet/runtime**: deterministic no-value runtime with reset, fixture import/export, state-root visibility, failure fixtures, and release handoff.
- **Source/provenance**: schemas, verifier modules, generated reports, fixtures, canary artifacts, release outputs, and dashboard data identify source paths, versions, hashes, and commands.
- **Crypto vectors**: accepted ids and hashes have deterministic vectors, negative vectors, domain separation, and replay-boundary tests before library promotion.
- **Release packaging**: local-alpha releases include commit, hashes, reproduction commands, migration notes, known limitations, and non-claims.

This decision makes those surfaces Local Alpha requirements. It does not authorize implementation in this research task.

## Alternatives Considered

- **Choose an L1 framework first**: rejected because framework choice is premature until the local object model and control plane prove useful.
- **Build only a chain CLI without workbench/API requirements**: rejected because receipts, memory lineage, dependencies, and challenge/finality state must be explainable to builders and reviewers.
- **Copy Octra's bridge/encrypted-compute ambitions**: rejected because FlowMemory's near-term edge is proof-carrying memory and receipt provenance, not broad encrypted-chain parity.

## Consequences

- Future local/private testnet work has concrete surface acceptance criteria.
- Public devnet and public L1 decisions remain gated behind local evidence.
- Operator vault and private-reference work can be scoped as local safety infrastructure, not production wallet or encrypted-compute work.
- API, explorer, provenance, vectors, and release packaging become part of the go/no-go bar, not optional polish.

## Scope Boundaries

This decision does not approve:

- implementation outside an explicitly assigned folder and issue;
- production wallet or custody product work;
- hosted production APIs;
- public RPC;
- public validators or sequencers;
- tokenomics, fees, rewards, staking, or slashing;
- bridges or value movement;
- encrypted compute;
- production proof systems;
- production L1/mainnet launch planning.

## Follow-Ups

- Use `research/flowchain-local-alpha/OCTRA_COMPETENCY_BAR.md` as the surface checklist.
- Use `research/flowchain-local-alpha/L1_GO_NO_GO_GATES.md` before approving implementation scope.
- Draft separate schemas for vault, private references, challenge/finality, dependency roots, and release manifests before code work.
- Require `git diff --check` and area-specific tests in any future implementation PR.
