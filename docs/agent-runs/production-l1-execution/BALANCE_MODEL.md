# Balance Model

Status: implemented for private/local execution proof.

## Native Local Unit

- Native local execution uses `asset:flowchain-local-test-unit`.
- Balances live in `localTestUnitBalances`.
- Fields include `units`, `bridgeCreditedUnits`, `reservedUnits`, `totalFaucetUnits`, `lastBridgeCreditId`, `lastFaucetRecordId`, `updatedAtBlock`, and `noValue`.
- Available balance is `units - reservedUnits`.
- `reservedUnits` is represented in state for pending/reserved accounting, but current product flow does not reserve balances across blocks.

## Bridge Credit Behavior

- Bridge credit execution is `ApplyBridgeCredit`.
- The local pilot uses bridge credit into `asset:flowchain-local-test-unit`, effectively a wrapped local asset for spend-flow testing.
- Bridged Base ETH and external ERC20 custody are not modeled by this crate.
- Each credit requires a deterministic `creditId`, `depositId`, `replayKey`, target account, asset id, positive amount, acknowledged block, and account nonce.
- Reusing either the credit id or replay key fails with a failed execution receipt.
- Credit receipts are `localOnly: true` and `productionReady: false`.

## Fee Behavior

- Execution costs are deterministic and recorded on every `executionReceipt`.
- Default mode is `record-only`; it records cost units but does not debit balances.
- Optional config mode `charge-native` debits local test units from the payer after business execution in the atomic candidate state.
- If `charge-native` cannot pay the cost, the whole transaction fails and the business mutation is discarded.

Cost table:

| Transaction | Cost units |
| --- | ---: |
| `TransferLocalTestUnits` | 1 |
| `ApplyBridgeCredit` | 1 |
| `LaunchToken` | 8 |
| `MintLocalTestToken` | 3 |
| `TransferToken` | 2 |
| `CreatePool` | 10 |
| `AddLiquidity` | 5 |
| `RemoveLiquidity` | 5 |
| `SwapExactIn` | 4 |

Other existing devnet object transactions have deterministic record-only costs in `execution_cost_units`.

## Failure Behavior

- Zero native transfer or bridge credit amount fails.
- Insufficient native balance fails with `insufficient-native-balance`.
- Duplicate nonce fails with `duplicate-nonce`.
- Stale or skipped nonce fails with `stale-nonce`.
- Insufficient execution balance in `charge-native` mode fails with `insufficient-execution-balance`.
- Failed transactions still write execution receipts and failed events, but do not partially mutate business state.

## Evidence

- `crates/flowmemory-devnet/tests/devnet_tests.rs` covers insufficient native balance, duplicate nonce, stale nonce, atomic execution-cost failure, bridge replay, and execution E2E restart/export/import.
- `devnet/local/execution-e2e/execution-e2e-report.json` records account balances, bridge credits, nonces, receipts, failed evidence, and roots.
