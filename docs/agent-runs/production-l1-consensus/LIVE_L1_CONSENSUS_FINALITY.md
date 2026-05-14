# Live L1 Consensus And Finality Evidence

Date: 2026-05-14

Final status: PASS

Public L1 status: BLOCKED

## Scope

This run made the live local L1 path honest about consensus and finality. The current runtime is a single-process private/local authority-set pilot. It is acceptable for private live pilot validation and is not acceptable for public L1 claims.

Generated local reports:

- `devnet/local/live-l1-consensus/consensus-finality-report.json`
- `devnet/local/live-l1-consensus/bridge-lifecycle-evidence.json`

## Consensus Readiness

The live readiness report now states:

- Current consensus mode: `single-process-private-local-authority-set`
- Validator set source: local genesis metadata from `crates/flowmemory-devnet/src/model.rs`
- Validator key material: public consensus key and key references only
- Block signing status: local private authority proof present and validated
- Finality rule: validated canonical blocks finalize immediately under the single local authority profile
- Fork choice: valid highest height, with deterministic hash tie-break for static local-file peer sync
- Peer mode: single-process local-file private mode, no public peer discovery
- Private live pilot: acceptable with local/private scope
- Public L1: blocked

The verifier command fails if an existing report claims public/live finality, production readiness, or public-L1 acceptability while the runtime is still this local single-process mode.

## Bridge Finality Lifecycle

Bridge local credit evidence now records and validates:

- Credit transaction included in block N
- Credit block hash covers the credited transaction and receipt
- State root changes after the credit
- Finality receipt covers the credited block under the private/local rule
- Transfer after credit references the credited block hash, credited state root, and finality receipt id

The local bridge credit is spendable only through this accepted/finalized private-pilot evidence path. It does not claim production bridge or public L1 finality.

## Tests And Gates

Passed:

- `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml`
- `npm run flowchain:node:start -- -MaxBlocks 3 -Wait`
- `npm run flowchain:node:start`; `npm run flowchain:node:status`; `npm run flowchain:node:stop`
- `npm run flowchain:node:status`
- `npm run flowchain:consensus:live-l1:verify`
- `npm run flowchain:production-l1:e2e`
- `npm run flowchain:no-secret:scan`
- `git diff --check`

The production L1 e2e report status is `passed-with-public-l1-blocked`.

## Negative Coverage

Rust tests cover:

- Invalid validator key reference
- Mutated block header
- Wrong state root in a block proposal
- Missing finality receipt where bridge spend finality is required
- Duplicate finality receipt for the same block
- Existing live-L1 report that falsely claims public finality

## Source-Of-Truth Notes

The requested production protocol files were absent from this worktree and from `origin/main` at run time:

- `docs/agent-runs/production-l1-protocol/GENESIS_PROOF.md`
- `schemas/flowmemory/production-validator-authority.schema.json`
- `schemas/flowmemory/production-finality-receipt.schema.json`
- `schemas/flowmemory/production-block-header.schema.json`

Matching files were read from sibling unmerged protocol worktree context only. The live report records this and keeps public-L1 readiness blocked until those artifacts and real multi-validator mechanics are merged and wired.

## Risks And Follow-Ups

- This is not public consensus. There is one local authority and no public validator onboarding, BFT network, staking, slashing, or audited production cryptography.
- Public L1 readiness remains blocked until the protocol schemas, genesis proof, production validator authority model, finality certificate model, peer networking, and fork-choice rules are merged and enforced end to end.
- Reports intentionally export no private validator keys or seed material.
