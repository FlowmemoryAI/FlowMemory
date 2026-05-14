# Bridge Credit Spend Proof

Status: implemented for private/local execution proof.

## Flow

The runnable bridge-credit spend flow is:

1. Create Alice and Bob local accounts.
2. Apply a deterministic local bridge credit to Alice.
3. Confirm Alice has credited local units.
4. Transfer part of the credited local units from Alice to Bob.
5. Launch `FLOWT`.
6. Transfer `FLOWT` from Alice to Bob.
7. Create a local-unit/FLOWT pool.
8. Add liquidity from Alice.
9. Swap Bob's credited local units for FLOWT.
10. Remove liquidity from Alice.
11. Query balances, receipts, events, pool state, LP state, and roots.

## Asset Configuration

- Pilot bridge credit asset: `asset:flowchain-local-test-unit`.
- This is a local wrapped asset for execution testing.
- Bridged Base ETH and ERC20 custody are not implemented in this devnet crate.
- Credits are marked `localOnly: true` and `productionReady: false`.

## Replay And Failure

- `creditId` is deterministic from deposit id, account id, asset id, and amount.
- `replayKey` must be unique.
- Reapplying the same credit or replay key produces a failed execution receipt with `duplicate-bridge-credit`.
- Failed bridge credit does not mint a second balance credit.

## Evidence

`npm run flowchain:execution:e2e` writes `devnet/local/execution-e2e/execution-e2e-report.json`.

Observed execution report fields:

- `bridgeCredits` includes one applied Alice credit for 10,000 local units.
- `accountBalances.local-account:product:alice.bridgeCreditedUnits` is 10,000.
- `accountBalances.local-account:product:bob.units` reflects Alice's transfer and Bob's swap spend.
- `swapResult` records Bob swapping local units into FLOWT.
- `failedTransactionEvidence` includes duplicate bridge credit evidence.
- `queryableIds` lists bridge credit, native transfer, token transfer, liquidity, swap, execution receipt, and execution event ids.
