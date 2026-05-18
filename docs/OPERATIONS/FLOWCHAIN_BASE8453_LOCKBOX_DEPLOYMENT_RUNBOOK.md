# FlowChain Base 8453 Lockbox Deployment Runbook

Status: owner-operated capped pilot procedure. No transaction is broadcast by readiness checks.

## Owner Inputs

Deployment scripts require these names in the local shell only:

```powershell
$env:FLOWCHAIN_PILOT_OPERATOR_ACK="I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
$env:FLOWCHAIN_BASE8453_RPC_URL="<Base 8453 RPC endpoint>"
$env:FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY = "<deployer key in local shell only>"
$env:FLOWCHAIN_BASE8453_SUPPORTED_TOKEN="<0x0000000000000000000000000000000000000000 or ERC-20 address>"
$env:FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI="<per-deposit cap>"
$env:FLOWCHAIN_PILOT_TOTAL_CAP_WEI="<total cap>"
```

Optional owner-role overrides:

```powershell
$env:FLOWCHAIN_BASE8453_OWNER_ADDRESS="<owner address>"
$env:FLOWCHAIN_BASE8453_RELEASE_AUTHORITY_ADDRESS="<release authority address>"
$env:FLOWCHAIN_BASE8453_SETTLEMENT_SUBMITTER_ADDRESS="<settlement submitter address>"
```

Never commit these values.

## Step 1: Dry-Run

Run:

```powershell
npm run flowchain:bridge:deploy:base8453
```

Expected dry-run evidence:

```text
devnet/local/bridge-live-readiness/base8453-deploy-readiness.json
```

The dry-run must report `ready-no-broadcast` before broadcast is considered.

## Step 2: Broadcast

Broadcast requires an additional acknowledgement:

```powershell
$env:FLOWCHAIN_BASE8453_BROADCAST_ACK="I_UNDERSTAND_THIS_SENDS_A_BASE8453_BRIDGE_TRANSACTION"
npm run flowchain:bridge:deploy:base8453 -- -Mode Broadcast -AcknowledgeBroadcast
```

Record the deployment evidence without private keys:

```text
transactionHash=<owner-recorded Base transaction hash>
lockboxAddress=<owner-recorded deployed lockbox address>
blockNumber=<owner-recorded Base block number>
deployerAddress=<owner-recorded deployer address>
```

Put those fields in a local evidence file outside committed source first. Only commit a redacted deployment note after review.

## Step 3: Verify Before Any Funds

Configure:

```powershell
$env:FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS="<owner-verified lockbox address>"
$env:FLOWCHAIN_BASE8453_ASSET_DECIMALS="<decimal count>"
$env:FLOWCHAIN_BASE8453_FROM_BLOCK="<deployment or first observation block>"
$env:FLOWCHAIN_BASE8453_TO_BLOCK="<bounded latest block>"
$env:FLOWCHAIN_PILOT_CONFIRMATIONS="<confirmation depth>"
```

Then run:

```powershell
npm run flowchain:bridge:infra:check
npm run flowchain:bridge:live:check
```

Required verification:

- Base RPC reports chain ID `8453`.
- Lockbox address is a 20-byte hex address.
- `eth_getCode` returns deployed bytecode for the lockbox.
- Token mode is native ETH via zero address or ERC-20 with deployed token bytecode.
- Caps, range, decimals, and confirmations are numeric and bounded.
- Operator acknowledgement is exact.

Do not send funds until both checks pass with the owner-verified lockbox.

## Step 4: Observe Deposits

For a bounded owner-supplied block range:

```powershell
npm run flowchain:bridge:observe:base8453
```

Evidence paths:

```text
services/bridge-relayer/out/base8453-pilot-bridge-observation.json
services/bridge-relayer/out/base8453-pilot-bridge-credit.json
services/bridge-relayer/out/base8453-pilot-bridge-handoff.json
services/bridge-relayer/out/base8453-pilot-evidence.json
devnet/local/bridge-live-readiness/bridge-observe-base8453-report.json
```

## Emergency Commands

Dry-run control command discovery:

```powershell
npm run flowchain:bridge:pause
npm run flowchain:bridge:resume
npm run flowchain:bridge:emergency-stop
npm run flowchain:emergency:stop-local
```

The Base control script has an `-Execute` mode for owner-authorized changes. Do not use `-Execute` unless the owner intentionally provides the deployer key and broadcast acknowledgement in the local shell.

## Transaction Diagnosis

For an owner-supplied Base transaction hash:

```powershell
$env:FLOWCHAIN_BASE8453_TX_HASH="<Base transaction hash>"
npm run flowchain:bridge:diagnose:tx
```

Alternative env name:

```powershell
$env:FLOWCHAIN_BASE8453_OPERATOR_TX_HASH="<Base transaction hash>"
npm run flowchain:bridge:diagnose:tx
```

The diagnostic path does not require private keys and must not print the Base RPC endpoint value.

## Verification Handoff

After dry-run, broadcast, and post-deploy verification, hand these paths to the verification owner:

```text
devnet/local/bridge-live-readiness/base8453-deploy-readiness.json
docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json
docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json
devnet/local/bridge-live-readiness/bridge-observe-base8453-report.json
services/bridge-relayer/out/base8453-pilot-evidence.json
```
