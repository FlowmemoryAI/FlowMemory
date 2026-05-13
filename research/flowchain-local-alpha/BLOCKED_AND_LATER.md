# FlowChain Blocked And Later List

Last updated: 2026-05-13

Status: research gate. This document does not authorize implementation outside research and decision docs.

## Purpose

This list turns the FlowChain research packet into explicit stop signs. A builder should be able to tell whether a claim is implemented, a local/private testnet target, later research, blocked, or explicitly later.

## Status Vocabulary

- **Implemented**: merged into FlowMemory as of `docs/CURRENT_STATE.md` dated 2026-05-13 or confirmed from `origin/main` on 2026-05-13.
- **Local-alpha target**: safe to specify now and build later for the local/private no-value testnet after owner agents accept the implementation scope.
- **Later research**: useful direction, but not ready for implementation.
- **Blocked**: cannot move to implementation until named prerequisites are met.
- **Explicitly later**: intentionally outside Local Alpha and outside the current Ralph loop.

## Allowed Now

| Item | Status | Allowed action |
| --- | --- | --- |
| Research gate docs | Local-alpha target | Continue docs under `research/flowchain-local-alpha/`. |
| Chain research docs | Local-alpha target | Clarify local/private, public devnet, bridge, DA, hardware observer, and Base anchor boundaries in `chain/` docs. |
| Decision records | Local-alpha target | Record accepted boundaries under `docs/DECISIONS/`. |
| Local/private testnet requirements | Local-alpha target | Specify second-computer acceptance, object model, API/workbench, devnet/runtime, provenance, crypto vectors, release packaging, and smoke requirements. |

## Blocked Before Local/Private Testnet Implementation

| Item | Status | Blocker | Smallest useful next step |
| --- | --- | --- | --- |
| Local operator vault | Local-alpha target, Blocked for code until accepted | No accepted vault file/envelope format, no locked/unlocked API semantics, and no no-plaintext-log tests. | Draft vault schema, error semantics, and test cases. |
| Private artifact references | Local-alpha target, Blocked for code until accepted | No accepted encrypted locator envelope, resolver policy, disclosure event, or export policy. | Draft private reference schema and disclosure states. |
| Challenge/finality state machine | Local-alpha target, Blocked for code until accepted | Challenge reason codes, response states, expiry, downgrade, and recompute rules are not accepted. | Draft status transition table and fixture cases. |
| Dependency roots | Local-alpha target, Blocked for code until accepted | Dependency atom schema, dependence classes, completeness scope, and omission-challenge semantics are not accepted. | Draft dependency vocabulary and negative fixtures. |
| Release manifest | Local-alpha target, Blocked for code until accepted | Manifest fields, hash set, compatibility policy, and reproduction commands are not accepted. | Draft local-alpha release manifest schema. |

## Later Research Before Public Devnet

| Item | Status | Blocker | Smallest useful next step |
| --- | --- | --- | --- |
| Public devnet | Later research, Blocked | Local/private testnet package is not yet reproducible and reviewed. | Finish Gate 3 evidence first. |
| Public operator roles | Later research | Validator/sequencer/operator responsibilities, failure handling, monitoring, halt/reset policy, and onboarding are not accepted. | Draft public-devnet operator role document without economics. |
| DA and reconstruction | Later research | Public data source, retention, missing-data behavior, and reconstruction tests are not accepted. | Extend DA requirements from `chain/BRIDGE_SECURITY_RESEARCH.md`. |
| Public monitoring | Later research | Indexer lag, verifier outage, missing artifacts, challenge response, reorg, and incident dashboards are not specified. | Draft monitoring matrix and incident states. |
| External security review | Later research | No review plan exists for public-network threat assumptions. | Open review tasks after local/private testnet release evidence exists. |

## Explicitly Later Or Blocked From Public L1/Mainnet

| Item | Status | Why blocked |
| --- | --- | --- |
| Production L1/mainnet | Explicitly later, Blocked | Requires public devnet evidence, independent audits, governance, DA, bridge/security review, production verifier design, monitoring, and incident response. |
| Tokenomics | Explicitly later, Blocked | User scope forbids tokenomics; economics would require separate legal/economic/security scope. |
| Validator/sequencer economics | Explicitly later, Blocked | No staking, rewards, fee market, slashing, or revenue design until non-economic roles and public devnet risks are accepted. |
| Production bridge | Explicitly later, Blocked | Requires deposit/withdrawal formats, replay protection, finality, DA, custody, emergency pause, upgrade delay, monitoring, recovery, and independent review. |
| Production proof systems | Later research, Blocked | Requires exact public inputs, witnesses, setup assumptions, cost model, negative vectors, challenge semantics, and independent crypto review. |
| Process-Witness circuits | Later research, Blocked | Research primitives are not accepted as predicates, circuits, or security claims. |
| SEAL ZK dependency proofs | Later research, Blocked | Dependency schemas, completeness warranties, omission challenges, downgrade semantics, and proof rules are not accepted. |
| Advanced encrypted compute | Explicitly later, Blocked | FHE, MPC, TEE, encrypted coprocessors, encrypted mempools, and private inference need a stable object model, key custody, leakage review, and security review. |
| Production Uniswap v4 hook | Explicitly later, Blocked | Current adapter is hook-shaped but not a permission-mined, PoolManager-wired production hook. |
| Hardware validator role | Explicitly later, Blocked | FlowRouter and LoRa sidecars are observers/control signaling only, not validators, sequencers, DA providers, or bridge operators. |

## Non-Negotiable Claims

- **Implemented boundary**: Heavy AI, model, memory, media, artifact, and evidence data stays off-chain.
- **Implemented boundary**: Contracts do not know final `txHash` or `logIndex`; indexers derive them after receipts and logs exist.
- **Local-alpha target**: Public receipt metadata must be separated from private references and secrets.
- **Local-alpha target**: Synthetic outputs can create hypotheses, counterexamples, scrutiny, debt, or challenge requirements, but cannot increase empirical certainty without real-world evidence.
- **Blocked**: Dependency omissions must remain challengeable; no proof can hide an incomplete provenance story.
- **Explicitly later**: Public L1/mainnet, production validators, tokenomics, production bridges, and production encrypted compute are not part of Local Alpha.
