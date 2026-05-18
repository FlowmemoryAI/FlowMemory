# Real Funds Pilot Runbook

Scope: capped owner pilot from Base chain ID `8453` into local/private FlowChain pilot state.

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
$env:FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY = "<owner-local-value-for-deploy-and-controls>"
$env:FLOWCHAIN_BASE8453_SUPPORTED_TOKEN = "<zero-address-for-native-or-erc20-address>"
$env:FLOWCHAIN_BASE8453_ASSET_DECIMALS = "<asset-decimals>"
$env:FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI = "<tiny-cap-in-smallest-units>"
$env:FLOWCHAIN_PILOT_TOTAL_CAP_WEI = "<tiny-total-cap-in-smallest-units>"
$env:FLOWCHAIN_PILOT_CONFIRMATIONS = "<confirmation-depth>"
$env:FLOWCHAIN_PILOT_OPERATOR_ACK = "I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
```

Optional guardrail:

```powershell
$env:FLOWCHAIN_PILOT_MAX_USD = "<integer-usd-cap>"
```

Broadcast-only acknowledgement:

```powershell
$env:FLOWCHAIN_BASE8453_BROADCAST_ACK = "I_UNDERSTAND_THIS_SENDS_A_BASE8453_BRIDGE_TRANSACTION"
```

## 2. Preflight Deploy

```powershell
npm run flowchain:bridge:command-matrix
npm run flowchain:bridge:live:check
npm run flowchain:bridge:deploy:base8453
```

## 3. Broadcast Deploy

```powershell
npm run flowchain:bridge:deploy:base8453 -- -Mode Broadcast -AcknowledgeBroadcast
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
npm run flowchain:bridge:observe:base8453
```

## 6. Local Credit And Usage

```powershell
npm run flowchain:bridge:withdraw:intent
npm run flowchain:bridge:local-credit:smoke
npm run flowchain:real-value-pilot:bridge
npm run flowchain:product-e2e
```

The exact-value report is written to:

- `services/bridge-relayer/out/real-value-pilot-e2e/bridge-exact-value-report.json`

## 7. Release Evidence

```powershell
npm run flowchain:bridge:release:evidence
```

Review the evidence before any operator release transaction. The default release evidence command validates files only and never broadcasts.

## 8. Controls

Preflight:

```powershell
npm run flowchain:bridge:pause
npm run flowchain:bridge:resume
npm run flowchain:bridge:emergency-stop
```

Execute only after the broadcast acknowledgement env is set:

```powershell
npm run flowchain:bridge:pause -- -Execute
npm run flowchain:bridge:resume -- -Execute
npm run flowchain:bridge:emergency-stop -- -Execute
```

## 9. Export Evidence

```powershell
npm run flowchain:bridge:evidence:export
npm run flowchain:bridge:no-secret-audit
```

Expected reports:

- `devnet/local/bridge-live-readiness/base8453-bridge-evidence-export-report.json`
- `devnet/local/bridge-live-readiness/bridge-no-secret-audit-report.json`

Current blocker for live execution:

- Owner live env values were not present in this worktree, so live deploy, deposit, observe, and release were not executed here.
