# Gated L1 Follow-Up Prompts

Date: 2026-05-14

Current classification: `CODE_NOT_READY`.

Implementation follow-up prompts are required before any owner live pilot.
Missing owner inputs are not the only blocker.

## Required Follow-Ups

| Follow-up | Blocking evidence | Expected scope |
| --- | --- | --- |
| Runtime/storage/export/import/restart | `npm run flowchain:production-l1:e2e` failed in the gap loop | Fix aggregate gate failures without changing live-funds behavior. |
| Product/control-plane strict pilot | `npm run flowchain:real-value-pilot:e2e` failed in the gap loop | Fix stale chain-status capability snapshot and smoke count expectations. |
| Control dashboard pilot API | `npm run flowchain:real-value-pilot:control-dashboard` failed in the gap loop | Fix malformed local devnet JSON handling. |
| HQ final verification | Current docs were stale before this follow-up | Rerun final focused checks after implementation fixes land. |
| Security/no-secret readiness | Required before handoff | Keep scans passing and avoid secret or env value output. |

Do not send funds before `READY_FOR_OPERATOR_LIVE_PILOT`. The owner must verify
the lockbox address before any funds move.

## 2026-05-14 Live Bridge Go/No-Go Prompts

Current result: `NO_GO_FOR_100_USD_BRIDGE`.

Evidence:

- `npm run flowchain:bridge:live:check` is blocked because the Base 8453 live env is missing.
- `GET /bridge/credit-status?txHash=0x2502e4ca8e4fa10f908e11b8c228d604e65e960ee1dcbb9b5c806cdb51f58091` returns `found: false`.
- `GET /bridge/status` reports `publicProductionL1Ready: false`, `productionReadyCredits: 0`, and `localOnlyCredits: 2`.
- Wallet metadata for `0xa33b70dfd9a5d5d8ddb96eb2b88e4ae1cfccb450373b58a3c3462a7031c5b212` verifies as valid and secret-free.
- Local runtime proof credits that wallet when a valid bridge handoff exists, but this is not live Base evidence.

Do not claim the bridge is ready for a $100 Base deposit until every goal below is complete.

### /goal live-base-observer-env-and-transaction-credit

Build and verify the live Base 8453 observer path so a real Base lockbox transaction is observed, validated, converted into a bridge credit, and made queryable by transaction hash.

Acceptance criteria:

- `npm run flowchain:bridge:live:check` passes with no missing env names and no failed checks.
- The observer verifies `eth_chainId == 0x2105`.
- The observer refuses broad block ranges and only scans a bounded range around the known tx block.
- The observer validates lockbox address, supported token/native asset, asset decimals, deposit caps, total caps, confirmation depth, and operator acknowledgement.
- The observer rejects `0x555...` placeholder recipients and zero recipients.
- Given a real Base tx hash, `/bridge/credit-status?txHash=<hash>` returns `found: true`.
- The resulting credit has `status: applied`, `productionReady: true`, `localOnly: false`, exact amount equality, and `accountId == flowchainRecipient`.
- No RPC URL, API key, private key, wallet password, or vault ciphertext is printed in logs or committed files.

### /goal sub-30-second-bridge-settlement-loop

Implement a live bridge settlement loop that can move an owner pilot deposit from Base observation to FlowChain spendable balance within the configured target window, while making the risk tradeoff explicit.

Acceptance criteria:

- A documented `FLOWCHAIN_BRIDGE_TARGET_SETTLEMENT_SECONDS=30` path exists.
- The loop polls Base receipt/log status, confirmation count, relayer credit status, runtime intake, block inclusion, and wallet balance until success or timeout.
- The loop writes a local status JSON with timestamps for `baseReceiptSeenAt`, `bridgeLogParsedAt`, `creditWrittenAt`, `runtimeBlockIncludedAt`, and `walletSpendableAt`.
- If the configured confirmation depth makes 30 seconds impossible, the command fails closed and reports the exact reason.
- If provisional credit is implemented for faster UX, it is clearly marked reversible until final confirmations, cannot be withdrawn/released, and is replaced by final credit after confirmation.
- A passing test proves a deposit reaches spendable wallet state within the configured target in mock/local mode.
- A live run cannot be marked passed unless the measured wall-clock duration is at or below the target and the amount is exact.

### /goal runtime-auto-ingest-live-bridge-credits

Build the runtime side so live bridge handoffs are automatically ingested into FlowChain blocks without manual file copying or one-off commands.

Acceptance criteria:

- A long-running or scheduled runtime worker watches the bridge handoff/output path.
- New applied bridge credits are queued, block-included, and persisted automatically.
- Duplicate replay keys are rejected without mutating balances.
- The wallet account id is exactly the 32-byte FlowChain recipient from calldata.
- Export/import/restart preserves bridge credits, receipts, replay keys, balances, and account mappings.
- `/bridge/credit-status` and `/wallets/balances` agree on account id and amount after restart.
- Tests cover live handoff, duplicate replay, restart recovery, and wallet transfer after credit.

### /goal wallet-spend-after-bridge-credit

Prove the wallet can use funds after a live bridge credit, not merely display a credited balance.

Acceptance criteria:

- The operator wallet vault remains local/ignored and encrypted.
- Public metadata remains secret-free and verifies with `wallet:verify-metadata`.
- After a bridge credit lands, the wallet can sign a transfer from the credited FlowChain address to a second FlowChain address.
- The runtime accepts the signed transfer, includes it in a block, and updates both balances exactly.
- Dashboard/control-plane shows the credited wallet, transfer tx, receipt, balance delta, and replay protection state.
- A failed signature, wrong signer, wrong nonce, or overspend is rejected without state mutation.

### /goal hard-go-no-go-before-100-usd

Create a single command that blocks any $100 owner bridge attempt unless the bridge, runtime, and wallet are actually ready.

Acceptance criteria:

- Command exits nonzero unless all live gates pass.
- Command confirms the exact FlowChain recipient to use: `0xa33b70dfd9a5d5d8ddb96eb2b88e4ae1cfccb450373b58a3c3462a7031c5b212`.
- Command confirms the configured lockbox address and supported asset without printing secrets.
- Command refuses to proceed if `publicProductionL1Ready` is false, if the last live tx hash is not found/applied, if production-ready credit count is zero, or if any required env value is missing.
- Command performs a small live pilot first, proves spendability on FlowChain, then writes `READY_FOR_100_USD_OWNER_TEST` only after exact amount, recipient, latency, and transfer tests pass.
- Command writes a no-secret evidence bundle and dashboard/control-plane URLs for the operator.

## 2026-05-14 Placeholder Recipient Follow-Up

Current result: `NO_GO_FOR_100_USD_BRIDGE`.

Updated evidence:

- Live Base 8453 env can be loaded with `FLOWCHAIN_LIVE_PILOT_ENV_LOADER`, and `npm run flowchain:bridge:live:check` passes through that loader.
- The live monitor no longer crashes on old placeholder-recipient deposits.
- The owner tx `0xdfa65c54c191582d9cf6819ab52df133f1bd76ce4e03997824e63c70fe98beba` is found but rejected because the on-chain FlowChain recipient is `0x555...`.
- The owner tx `0x2502e4ca8e4fa10f908e11b8c228d604e65e960ee1dcbb9b5c806cdb51f58091` is found but rejected because the on-chain FlowChain recipient is `0x555...`.
- Correct live API for this evidence is currently `http://127.0.0.1:8793`, started with `FLOWCHAIN_CONTROL_PLANE_BRIDGE_RUNTIME_HANDOFF_PATH=services/bridge-relayer/out/base8453-pilot-bridge-handoff.json`.
- Main node is running, but main node state still has `bridgeCredits: 0`, `bridgeCreditReceipts: 0`, and `bridgeReplayKeys: 0`.
- Wallet transfer E2E passes in isolated local runtime, but there is no live Base credit spendable from the owner wallet yet.
- Current pilot caps are below a $100 transfer. A $100 deposit must fail closed until caps, lockbox config, relayer config, and go/no-go evidence explicitly support that amount.

### /goal placeholder-recipient-recovery-or-explicit-refund-path

Build a safe owner-only path for old Base deposits that were sent with the blocked `0x555...` FlowChain recipient, without pretending they are normal bridge credits.

Acceptance criteria:

- Existing `0x555...` deposits remain rejected by the normal bridge path.
- A separate recovery path requires explicit tx hash allowlist, sender allowlist, lockbox match, amount match, token match, confirmation depth, and operator acknowledgement.
- Recovery output must clearly mark `recoveryOverride: true`, `normalBridgeCredit: false`, and the reason `placeholder_recipient`.
- Recovery must never broadly map all `0x555...` deposits to a wallet.
- Recovery must not broadcast Base release transactions.
- If recovery credits FlowChain, the credit must be visible as operator recovery credit, not production bridge credit.
- If refund/release is implemented instead, it must require separate release authority proof and must not be auto-broadcast by the monitor.
- Tests cover rejected normal path, allowed recovery tx, wrong sender, wrong tx hash, wrong amount, duplicate recovery replay, and no-secret evidence.

### /goal owner-correct-recipient-live-pilot

Run a new live owner pilot using the actual FlowChain wallet recipient, not the old placeholder.

Acceptance criteria:

- The owner bridge UI/link pre-fills or requires recipient `0xa33b70dfd9a5d5d8ddb96eb2b88e4ae1cfccb450373b58a3c3462a7031c5b212`.
- The UI blocks `0x555...`, `0x666...`, zero bytes32, blank recipient, and malformed bytes32 values before a wallet transaction can be sent.
- The tx calldata is decoded before sending and proves the first `lockNative(bytes32,bytes32)` argument equals the owner FlowChain wallet address.
- The live monitor observes the new tx after configured confirmations and writes an applied credit with `productionReady: true`, `localOnly: false`, exact amount, and account id equal to the owner wallet.
- The main running FlowChain node ingests that credit into `devnet/local/state.json`.
- `/bridge/credit-status?txHash=<new-tx>` returns `found: true`, `status: applied`, `productionReady: true`, `localOnly: false`.
- `/wallets/balances?accountId=0xa33b70dfd9a5d5d8ddb96eb2b88e4ae1cfccb450373b58a3c3462a7031c5b212` shows the exact credited amount.
- The wallet signs and spends a small amount from that credited account inside FlowChain.

### /goal raise-or-refuse-100-usd-cap-with-proof

Handle the owner request to bridge $100 without silently bypassing pilot guardrails.

Acceptance criteria:

- The command reads current lockbox per-deposit cap, total cap, relayer max deposit, relayer total cap, and configured token decimals.
- If any cap is below the requested $100 equivalent, the command exits nonzero before the wallet sends a Base tx.
- If caps are intentionally raised, the change is explicit, documented, verified on-chain, and reflected in relayer env.
- A small live amount must pass first with correct recipient, applied credit, wallet balance, and spend proof.
- Only after the small live pilot passes can a `$100` go/no-go command write `READY_FOR_100_USD_OWNER_TEST`.
- The final command must include tx hash, amount, recipient, confirmation count, credit status, wallet balance, spend tx, and elapsed seconds.
