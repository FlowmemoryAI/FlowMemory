# Owner Live Test Commands

These commands are separated into dry-run and live-gated steps. Do not put env values in committed files.

## Required Env Names

```powershell
$env:FLOWCHAIN_BASE8453_RPC_URL = "<owner-local-value>"
$env:FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY = "<owner-local-value>"
$env:FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS = "<owner-local-value-after-deploy>"
$env:FLOWCHAIN_BASE8453_SUPPORTED_TOKEN = "<zero-address-for-native-or-erc20-address>"
$env:FLOWCHAIN_BASE8453_FROM_BLOCK = "<bounded-start-block>"
$env:FLOWCHAIN_BASE8453_TO_BLOCK = "<bounded-end-block>"
$env:FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI = "<tiny-cap>"
$env:FLOWCHAIN_PILOT_TOTAL_CAP_WEI = "<tiny-total-cap>"
$env:FLOWCHAIN_PILOT_CONFIRMATIONS = "<confirmation-depth>"
$env:FLOWCHAIN_PILOT_OPERATOR_ACK = "I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
```

## Dry Run

```powershell
npm run bridge:deploy:dry-run
npm run bridge:pilot:live:check
```

## Broadcast Deploy

```powershell
npm run bridge:deploy:base8453 -- -AcknowledgeBroadcast
```

The deploy script checks `eth_chainId == 0x2105` and does not print the RPC URL or private key.

## Deposit

Use the owner wallet to call exactly one of:

- native ETH: `lockNative(bytes32 flowchainRecipient, bytes32 metadataHash)` with tiny `msg.value`
- ERC20: approve the lockbox, then call `lockERC20(address token, uint256 amount, bytes32 flowchainRecipient, bytes32 metadataHash)`

Use only the configured supported asset and keep the amount below `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`.

## Observe And Credit

```powershell
npm run bridge:observe:base8453 -- -ApplyCredit -WithdrawalIntent
```

Equivalent direct command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/bridge-base-mainnet-pilot-observe.ps1 -OperatorAck -ApplyCredit -WithdrawalIntent
```

## Replay Check

```powershell
npm run bridge:credit:replay-check
```

## Local Usage Gates

```powershell
npm run bridge:local-credit:smoke
npm run flowchain:product-e2e
```

The bridge E2E writes `bridge-local-usage-proof.json`; the existing product gate covers local product/DEX behavior.

## Withdrawal And Release Evidence

```powershell
npm run bridge:withdraw:intent
npm run bridge:release:evidence
```

The mock E2E writes the canonical withdrawal intent plus `bridge-withdrawal-authorization.json`, which carries nonce, local chain ID, signed payload hash, and deterministic test signature fields.

## Operator Controls

```powershell
npm run bridge:pause -- -Execute
npm run bridge:resume -- -Execute
npm run bridge:emergency-stop -- -Execute
```

## Evidence Export

```powershell
npm run bridge:evidence:export
```

Export report:

- `services/bridge-relayer/out/base8453-bridge-evidence-export-report.json`
