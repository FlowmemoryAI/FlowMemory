# Bridge Integration

FlowChain bridge integration is fail-closed. Local/mock bridge reads exist for
developer verification. Live Base 8453 operation is blocked until owner/operator
inputs are configured and verified.

## Base 8453 Inputs

Live bridge checks require these names:

- `FLOWCHAIN_PILOT_OPERATOR_ACK`
- `FLOWCHAIN_BASE8453_RPC_URL`
- `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`
- `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`
- `FLOWCHAIN_BASE8453_ASSET_DECIMALS`
- `FLOWCHAIN_BASE8453_FROM_BLOCK`
- `FLOWCHAIN_BASE8453_TO_BLOCK`
- `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`
- `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`
- `FLOWCHAIN_PILOT_CONFIRMATIONS`

The acknowledgement value is:

```text
I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT
```

Readiness responses must print names only, not values.

## Readiness

```powershell
node tools/flowchain-devkit.mjs bridge-readiness --json
node examples/flowchain-bridge-readiness/index.mjs
```

To require live inputs and fail closed:

```powershell
node tools/flowchain-devkit.mjs bridge-readiness --require-live --json
```

## Confirmations And Finality

`FLOWCHAIN_PILOT_CONFIRMATIONS` defines the Base 8453 confirmation depth for
the owner pilot. FlowChain local finality is inspected with:

```powershell
node tools/flowchain-devkit.mjs finality --object-id <object-id> --json
```

## Exact-Credit Accounting

Bridge lifecycle rows expose equality fields for:

- deposit amount;
- observed amount;
- credited amount;
- wallet delta;
- transferable amount;
- withdrawal amount;
- release amount.

Query lifecycle rows:

```powershell
node tools/flowchain-devkit.mjs bridge-lifecycle --credit-id <credit-id> --json
```

## Replay Protection

Bridge lifecycle records include replay identifiers derived from Base tx hash,
log index, recipient, asset, and amount. Replay acceptance/rejection is a bridge
runtime concern; SDK clients should show the status and not re-submit a known
credit.

## Withdrawal Intent And Release Evidence

Use:

- `pilot_withdrawal_intent_list`
- `pilot_release_evidence_list`
- `withdrawal_list`
- `withdrawal_get`

Release/broadcast back to Base is not enabled by SDK examples.

## Local, Configured-Live, Blocked

- Local/mock: read lifecycle records, deposits, credits, withdrawals, and
  readiness from local control-plane/runtime handoff files.
- Configured-live: only after the Base 8453 env and deployment names above are
  supplied locally and live gates pass.
- Blocked: public live bridge PASS, release broadcast, and broad public funds
  usage remain blocked in this worktree.
