# FlowChain Real-Value Pilot Chain Runtime Completion Audit

## Result

The runtime implementation is complete on branch
`agent/real-value-pilot-runtime-proof` pending PR merge.

## Acceptance Mapping

| Requirement | Evidence | Status |
| --- | --- | --- |
| Root runtime proof command exists. | `package.json` adds `flowchain:real-value-pilot:runtime`. | Complete |
| Pilot bridge-credit intake applies exactly once. | Runtime proof and Rust tests apply the first handoff credit once. | Complete |
| Replay is rejected or idempotent with evidence. | Runtime proof and Rust tests reject duplicate replay with persisted evidence. | Complete |
| Receipt lookup by id and Base event reference. | `bridge-receipt` CLI path and runtime proof cover id, event, wrong id, and wrong event lookup. | Complete |
| Restart preserves pilot state. | Runtime proof checks token, DEX, bridge credit, receipt, and replay state after restart. | Complete |
| Export/import preserves roots. | Runtime proof compares state root plus bridge-specific roots after import. | Complete |
| Downstream handoff exports include bridge runtime state. | Runtime proof checks dashboard, indexer, verifier, and control-plane exports. | Complete |
| Public-readiness claims remain out of scope. | Docs keep the local/testnet and capped owner-pilot boundary. | Complete |

## Residual Risk

- The proof is local and fixture-driven; it does not perform a live Base RPC read
  or broadcast any transaction.
- The final HQ gate passes on this branch only after the runtime proof command is
  present. It still needs PR merge before `main` can be final-green.
