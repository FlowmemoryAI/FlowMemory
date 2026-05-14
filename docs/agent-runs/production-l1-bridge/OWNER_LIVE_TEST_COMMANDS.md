# Owner Live Test Commands

These commands are separated into preflight and live-gated steps. Keep values local to the operator machine; committed docs and reports must contain env names only.

## Required Env Names

```powershell
$env:FLOWCHAIN_BASE8453_RPC_URL = "<owner-local-value>"
$env:FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY = "<owner-local-value-for-deploy-and-controls>"
$env:FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS = "<owner-local-value-after-deploy>"
$env:FLOWCHAIN_BASE8453_SUPPORTED_TOKEN = "<zero-address-for-native-or-erc20-address>"
$env:FLOWCHAIN_BASE8453_ASSET_DECIMALS = "<asset-decimals>"
$env:FLOWCHAIN_BASE8453_FROM_BLOCK = "<bounded-start-block>"
$env:FLOWCHAIN_BASE8453_TO_BLOCK = "<bounded-end-block>"
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

## Preflight

```powershell
npm run flowchain:bridge:command-matrix
npm run flowchain:bridge:live:check
npm run flowchain:bridge:deploy:base8453
```

## Broadcast Deploy

```powershell
npm run flowchain:bridge:deploy:base8453 -- -Mode Broadcast -AcknowledgeBroadcast
```

The deploy script checks `eth_chainId == 0x2105` and does not print the RPC URL or private key.

## Deposit

Use the owner wallet to call exactly one of:

- native ETH: `lockNative(bytes32 flowchainRecipient, bytes32 metadataHash)` with tiny `msg.value`
- ERC20: approve the lockbox, then call `lockERC20(address token, uint256 amount, bytes32 flowchainRecipient, bytes32 metadataHash)`

Use only the configured supported asset and keep the amount below `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`.

## Observe And Credit

```powershell
npm run flowchain:bridge:observe:base8453
npm run flowchain:bridge:withdraw:intent
```

Both commands are non-broadcasting. They require Base `8453`, the configured lockbox, the configured asset, the configured confirmation depth, and exact smallest-unit decimal-string amounts.

## Local Usage Gates

```powershell
npm run flowchain:bridge:local-credit:smoke
npm run flowchain:real-value-pilot:bridge
npm run flowchain:product-e2e
```

The deterministic fixture bridge E2E writes `services/bridge-relayer/out/real-value-pilot-e2e/bridge-exact-value-report.json`.

## Withdrawal And Release Evidence

```powershell
npm run flowchain:bridge:withdraw:intent
npm run flowchain:bridge:release:evidence
```

The release evidence validator rejects amount, token, recipient, credit ID, deposit ID, withdrawal intent ID, or broadcast-state mismatches.

## Operator Controls

Preflight only:

```powershell
npm run flowchain:bridge:pause
npm run flowchain:bridge:resume
npm run flowchain:bridge:emergency-stop
```

Broadcast only after `FLOWCHAIN_BASE8453_BROADCAST_ACK` is set:

```powershell
npm run flowchain:bridge:pause -- -Execute
npm run flowchain:bridge:resume -- -Execute
npm run flowchain:bridge:emergency-stop -- -Execute
```

## Evidence Export

```powershell
npm run flowchain:bridge:evidence:export
npm run flowchain:bridge:no-secret-audit
```

Export report:

- `devnet/local/bridge-live-readiness/base8453-bridge-evidence-export-report.json`
