# Real Funds Pilot Runbook

Scope: capped owner test from Base chain ID `8453` into local/private FlowChain pilot state.

## Safety Rules

- Use a tiny amount only.
- Configure one supported asset only.
- Keep per-deposit and total caps low.
- Use a bounded block range.
- Require confirmation depth.
- Require operator acknowledgement.
- Never commit env files, RPC URLs, keys, or wallet secrets.

## 1. Set Local Env

Set these locally only:

```powershell
$env:FLOWCHAIN_BASE8453_RPC_URL = "<owner-local-value>"
$env:FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY = "<owner-local-value>"
$env:FLOWCHAIN_BASE8453_SUPPORTED_TOKEN = "<zero-address-for-native-or-erc20-address>"
$env:FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI = "<tiny-cap>"
$env:FLOWCHAIN_PILOT_TOTAL_CAP_WEI = "<tiny-total-cap>"
$env:FLOWCHAIN_PILOT_CONFIRMATIONS = "<confirmation-depth>"
$env:FLOWCHAIN_PILOT_OPERATOR_ACK = "I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
```

## 2. Dry-Run Deploy

```powershell
npm run bridge:deploy:dry-run
```

## 3. Broadcast Deploy

```powershell
npm run bridge:deploy:base8453 -- -AcknowledgeBroadcast
```

Record the deployed lockbox locally:

```powershell
$env:FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS = "<deployed-lockbox>"
```

## 4. Deposit From Owner Wallet

Native ETH path:

```text
lockNative(flowchainRecipient, metadataHash) with tiny msg.value
```

ERC20 path:

```text
approve(lockbox, tinyAmount)
lockERC20(token, tinyAmount, flowchainRecipient, metadataHash)
```

## 5. Observe Confirmed Deposit

Set a narrow range around the deposit block:

```powershell
$env:FLOWCHAIN_BASE8453_FROM_BLOCK = "<deposit-block>"
$env:FLOWCHAIN_BASE8453_TO_BLOCK = "<deposit-block-or-small-end>"
npm run bridge:observe:base8453 -- -ApplyCredit -WithdrawalIntent
```

## 6. Local Credit And Usage

```powershell
npm run bridge:local-credit:smoke
npm run flowchain:product-e2e
```

Bridge-local transfer evidence is written by:

```powershell
npm run bridge:pilot:mock:e2e
```

## 7. Withdrawal Intent

```powershell
npm run bridge:withdraw:intent
```

The canonical intent includes Base recipient, asset, and amount. The mock E2E also writes `bridge-withdrawal-authorization.json` with nonce, local chain ID, signed payload hash, and deterministic test signature fields.

## 8. Release Evidence

```powershell
npm run bridge:release:evidence
```

Review the evidence before any operator release transaction.

## 9. Controls

Pause deposits:

```powershell
npm run bridge:pause -- -Execute
```

Resume deposits:

```powershell
npm run bridge:resume -- -Execute
```

Emergency stop:

```powershell
npm run bridge:emergency-stop -- -Execute
```

## 10. Export Evidence

```powershell
npm run bridge:evidence:export
```

Expected report:

- `services/bridge-relayer/out/base8453-bridge-evidence-export-report.json`

Current blocker for live execution:

- Owner live env values were not present in this worktree, so live deploy/deposit/observe was not executed here.
