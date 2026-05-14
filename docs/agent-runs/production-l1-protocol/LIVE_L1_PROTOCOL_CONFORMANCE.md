# Live L1 Protocol Conformance

Date: 2026-05-14

Final status: PASS

Scope: private/local FlowChain L1 protocol gate for bridge lifecycle and spending. This is not a public validator or value-bearing launch approval.

## Machine Reports

- `devnet/local/live-l1-protocol/protocol-conformance-report.json`
- `devnet/local/live-l1-protocol/bridge-mock-e2e-report.json`
- `devnet/local/live-l1-protocol/no-secret-scan-report.json`

The protocol conformance report currently records:

- Protocol version: `flowchain.private_local_l1.protocol.v0`
- Chain ID: `7428453`
- Network profile: `flowchain-base8453-pilot`
- Genesis hash: `0x0826d4c5093c967d57dd5239b8c24e089dc898942291b5f3050a129887041e7f`
- Live state root after bridge credit and transaction catalog execution: `0x5b06d140f4e0bb68879d41933640a31d9e2bd5c13d8e7702e40784db9bf9c2fb`

## Code-Enforced Coverage

The live Rust state machine now owns the private/local production protocol objects instead of treating them as side fixtures:

- Genesis profile, chain ID, network profile, genesis hash, account signer identity, payload hash, transaction ID, and nonce are checked when production envelopes enter `apply_transaction`.
- Bridge evidence is accepted through the same pending transaction and block path as wallet, transfer, token, DEX, withdrawal, finality, and object lifecycle transactions.
- Bridge credits generate normal protocol receipts, events, event-receipt indexes, replay indexes, account balance updates, and state-root changes.
- State roots now commit protocol accounts, balances, validator authorities, bridge evidence, bridge credits, replay index, receipts, events, event receipt index, withdrawals, object store, finality votes, and finality certificates.
- Export/import preserves bridge credit, receipt, replay index, account balance, event receipt index, and finality state.

The conformance gate fails if any live bridge/spending item is fixture-only or doc-only.

## Negative Behavior

`npm run flowchain:protocol:live-l1:verify` exercises these invalid bridge cases through live blocks and expects stable `FC_PROTO_*` errors:

- Duplicate Base source event: `FC_PROTO_DUPLICATE_BRIDGE_EVENT`
- Invalid source chain: `FC_PROTO_INVALID_BRIDGE_SOURCE_CHAIN`
- Wrong lockbox: `FC_PROTO_WRONG_LOCKBOX`
- Over-cap amount: `FC_PROTO_BRIDGE_AMOUNT_OVER_CAP`
- Unsatisfied confirmation proof: `FC_PROTO_BRIDGE_CONFIRMATION_UNSATISFIED`
- Mutated bridge evidence: `FC_PROTO_MUTATED_BRIDGE_EVIDENCE`

## Root Gates

Added root scripts:

- `npm run flowchain:protocol:live-l1:verify`
- `npm run flowchain:production-l1:e2e`
- `npm run flowchain:bridge:mock:e2e`
- `npm run flowchain:no-secret:scan`

## Checks Run

- `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml` - PASS, 30 tests
- `npm run flowchain:protocol:live-l1:verify` - PASS
- `npm run flowchain:production-l1:e2e` - PASS
- `npm run flowchain:bridge:mock:e2e` - PASS
- `npm run flowchain:no-secret:scan` - PASS
- `git diff --check` - PASS

## Blockers

Public/value-bearing launch remains CODE-BLOCKED:

- Production consensus is incomplete: local finality vote/certificate rows are code-backed, but public validator consensus, fork choice, slashing, and quorum operation are not proven.
- Validator and audit readiness are incomplete: validator authority state exists, but independent validator operation and security audit evidence are not complete.
- Proof system is incomplete: proof circuits, audited proving, and public verifier economics are not implemented.
- Public bridge release remains blocked: Base evidence validation and local accounting are enforced only for the private/local no-value lifecycle gate.

## Follow-Ups

- Consensus lane must replace local finality rows with proven validator/fork-choice semantics before any broader launch claim.
- Crypto/proof lane must replace fixture digest signatures and proof placeholders with audited signing and proving paths.
- Bridge lane must connect bounded Base readers to live evidence production without weakening replay, lockbox, source-chain, finality, or cap checks.
