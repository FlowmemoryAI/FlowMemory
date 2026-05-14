# FlowChain Private/Local Protocol Plan

Date: 2026-05-13

## Scope

Define the canonical private/local FlowChain protocol contract that downstream runtime, crypto, RPC, wallet, bridge, and dashboard agents can validate against.

## Allowed Writes

- `docs/`
- `docs/DECISIONS/`
- `schemas/flowmemory/`
- `fixtures/`
- `research/`
- `package.json` validation aliases only
- `docs/agent-runs/production-l1-protocol/`

## Plan

1. Read required repo context and existing schemas, fixtures, devnet model, and control-plane types.
2. Inventory existing field names and align the production protocol contract with them where practical.
3. Add canonical protocol schemas for profiles, genesis, accounts, authorities, transactions, payloads, blocks, receipts, events, state roots, bridge evidence, finality receipts, and export snapshots.
4. Add deterministic positive fixtures for genesis, all transaction families, receipts/events, bridge evidence, state roots, and a block containing at least five transaction types.
5. Add deterministic negative fixtures with stable expected error codes.
6. Add local validation tooling and npm aliases.
7. Run production protocol and fixture validation, genesis hash print/validation, deterministic state-root validation, and `git diff --check`.
8. Write handoff, catalog, matrix, state-transition, bridge, genesis-proof, and implementation-contract docs.

## Non-Goals

- No production mainnet readiness claim.
- No public validator onboarding.
- No tokenomics or validator economics.
- No production bridge readiness claim.
- No private key material in committed fixtures.
- No implementation changes under crates, services, contracts, crypto, apps, hardware, or local secret files.
