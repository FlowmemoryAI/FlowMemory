# Receipt and Event Catalog

Receipts validate through `production-receipt.schema.json`. Events validate through `production-event.schema.json`.

| Payload type | Success receipt | Emitted event | Bridge evidence required |
| --- | --- | --- | --- |
| `native_transfer` | balance delta and cost | `NativeTransferRecorded` | no |
| `faucet_funding` | faucet credit and cost | `FaucetFundingRecorded` | no |
| `bridge_credit` | credit applied and cost | `BridgeCreditApplied` | yes, deposit observation |
| `token_launch` | token registry write and cost | `TokenLaunched` | no |
| `token_mint` | mint write and cost | `TokenMinted` | no |
| `token_transfer` | token balance delta and cost | `TokenTransferred` | no |
| `pool_create` | pool registry write and cost | `PoolCreated` | no |
| `add_liquidity` | reserve/LP delta and cost | `LiquidityAdded` | no |
| `remove_liquidity` | reserve/LP delta and cost | `LiquidityRemoved` | no |
| `swap` | reserve/balance delta and cost | `SwapExecuted` | no |
| `withdrawal_intent` | withdrawal queue write and cost | `WithdrawalIntentRecorded` | yes, release evidence when completed |
| `validator_authority_config` | validator-state write and cost | `ValidatorAuthorityConfigured` | no |
| `finality_vote` | vote-set write and cost | `FinalityVoteRecorded` | no |
| `finality_certificate` | certificate write and cost | `FinalityCertificateRecorded` | no |
| object lifecycle updates | object-store write and cost | `ObjectLifecycleUpdated` | no |

## Failure Shape

Failed execution still produces a receipt with:

- `status: "failed"`
- `errorCode: "FC_..."`
- `failureReason.reasonCode`
- `failureReason.displayMessage`
- `failureReason.retryable`

The RPC and dashboard agents should display `failureReason.displayMessage` and use `reasonCode` for filtering. Negative fixture validation returns stable `FC_PROTO_*` codes rather than a generic invalid result.

## Deterministic IDs

Receipt IDs are Keccak-256 hashes over `{ txId, payloadType, status }` under the receipt ID domain. Event IDs are Keccak-256 hashes over `{ txId, receiptId, eventType, index }` under the event ID domain. The validator recomputes the IDs and roots through `npm run validate:production-l1-fixtures`.
