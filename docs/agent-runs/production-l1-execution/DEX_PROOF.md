# DEX Proof

Status: implemented for private/local execution proof.

## Lifecycle

DEX lifecycle transactions:

- `CreatePool`
- `AddLiquidity`
- `RemoveLiquidity`
- `SwapExactIn`

Query state:

- `dexPools`
- `lpPositions`
- `liquidityReceipts`
- `swapReceipts`
- `tokenBalances`
- `localTestUnitBalances`
- `executionReceipts`
- `executionEvents`

## Pool Rules

Pool creation requires a deterministic pool id, distinct base and quote assets, existing creator account, valid assets, unique pool, and next expected nonce. The product flow creates a pool for `asset:flowchain-local-test-unit` and `FLOWT`.

## Liquidity Rules

Add liquidity requires positive base and quote amounts, available provider balances for both assets, `minLpUnits`, and next expected nonce.

LP units:

- Initial liquidity mints `min(baseAmount, quoteAmount)` LP units.
- Later liquidity mints the minimum of base-proportional and quote-proportional LP units using floor division.

Remove liquidity requires an existing LP position, positive LP amount, enough LP units, and minimum base/quote outputs. Withdrawn amounts are proportional to pool reserves and total LP supply using floor division.

## Swap Rules

`SwapExactIn` supports deterministic exact-input swaps in either pool direction. Output uses constant-product math without a fee term:

```text
amountOut = reserveOut * amountIn / (reserveIn + amountIn)
```

The swap fails if:

- pool id is invalid
- input asset is not one side of the pool
- input amount is zero
- reserves are insufficient
- output is zero
- output is below `minAmountOut`
- trader lacks input balance
- nonce is duplicate or stale

Successful swaps debit input balance, credit output balance, update reserves, and write a swap receipt.

## Product Evidence

The product flow:

- creates the local-unit/FLOWT pool
- adds 5,000 local units and 500,000 FLOWT
- swaps 100 local units from Bob into FLOWT with minimum output 9,000
- removes 100 LP units from Alice

The execution report records final pool reserves, LP position, and swap output. Negative tests cover invalid pool, invalid liquidity amount, invalid swap amount, min-output failure, and atomic failed-swap behavior.
