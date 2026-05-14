# Private/Local L1-Shaped RPC Experiments

## Command Log

Commands and outcomes will be recorded here as the implementation is verified.

| Command | Outcome | Notes |
| --- | --- | --- |
| `npm test --prefix services/control-plane` | Passed | 21 tests passed after signed-envelope, schema, bridge, event, sync, and error-envelope updates; re-run after generated fixture cleanup. |
| `npm run control-plane:smoke` | Passed | 91 JSON-RPC calls, 87 successful responses, 4 expected structured submit rejections, 0 no-secret findings; re-run after generated fixture cleanup. |
| `npm run flowchain:l1-e2e` | Passed | Full private/local smoke passed, including service tests, crypto/vector checks, launch candidate gate, dashboard build, bridge local-credit smoke, hardware smoke, and control-plane smoke. |
| `git diff --check` | Passed | No whitespace errors reported; Git emitted Windows LF/CRLF warnings only. |

## Smoke Coverage Notes

The smoke client must call every private/local L1-shaped method and scan every response for private keys, seed phrases, mnemonics, RPC credentials, API keys, webhook-shaped text, and unsafe raw environment data.

## Submit/Query Loop Notes

The final proof must include:

- signed transfer submission: covered by `transaction_submit` smoke with `flowchain.signed_transaction_envelope.v1`;
- transaction query by ID: covered by `transaction_get` for the submitted `txId`;
- receipt query by transaction ID: covered by `receipt_get` with `{ txId }`;
- account balance query after execution or explicit rejected receipt: covered by `balance_get` for the unique per-run `account:submit:bob:*`, amount `7`;
- invalid signature rejection: covered by `BAD_SIGNATURE`;
- duplicate transaction rejection: covered by `DUPLICATE_TX`;
- wrong-chain rejection: covered by `WRONG_CHAIN_ID`;
- stale nonce rejection: covered by `STALE_NONCE`.
