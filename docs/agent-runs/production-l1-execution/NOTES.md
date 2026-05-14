# Private/Local L1 Execution Notes

## Boundaries

- Native and bridged balances are private/local testnet accounting records for execution proof only.
- Bridge credits are deterministic local pilot credits from approved fixture/handoff inputs. They are not production bridge security or custody claims.
- Local execution costs are deterministic anti-free-execution accounting for the private/local pilot, not tokenomics or a public fee market.
- DEX mechanics are deterministic local execution mechanics for product flow testing, not economic recommendations or production AMM design.

## Read-Only Inputs

- `crypto/fixtures/product-testnet-transactions.json`
- `schemas/flowmemory/product-transaction.schema.json`

## Implemented State

- `accountNonces`
- `bridgeCreditReceipts`
- `tokenTransferReceipts`
- `executionReceipts`
- `executionEvents`
- root coverage for account nonces, bridge credits, token transfers, execution receipts, and execution events

## Product Flow

The local product flow now proves:

- bridge credit to Alice
- native local transfer Alice to Bob
- `FLOWT` launch
- `FLOWT` transfer Alice to Bob
- local-unit/FLOWT pool creation
- liquidity add
- Bob exact-input swap from local units to `FLOWT`
- liquidity remove
- queryable receipts/events and deterministic roots

## Follow-Ups For Other Agents

- Control-plane/dashboard agents should expose query methods and views listed in `HANDOFF.md`.
- The broader real-value pilot coordinator still needs contracts and bridge-relayer proof gates in this checkout. Runtime proof is available as `npm run flowchain:real-value-pilot:runtime`.
- This worktree is behind `origin/main` by two real-value-pilot commits. Incoming `package.json` changes add real-value-pilot aliases near the execution alias area and should be merged before PR finalization.
