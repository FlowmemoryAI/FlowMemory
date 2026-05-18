# Bridge Operator Proof

Env name command:

```powershell
npm run wallet:operator-bridge --prefix crypto -- env
```

Required env names:

```text
FLOWCHAIN_PILOT_OPERATOR_ACK
FLOWCHAIN_BASE8453_RPC_URL
FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS
FLOWCHAIN_BASE8453_FROM_BLOCK
FLOWCHAIN_BASE8453_TO_BLOCK
FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI
FLOWCHAIN_PILOT_TOTAL_CAP_WEI
FLOWCHAIN_PILOT_WITHDRAWAL_RECIPIENT
FLOWCHAIN_PILOT_MAX_USD
```

Dry-run command planning:

```powershell
npm run wallet:operator-bridge --prefix crypto -- prepare-deposit-evidence
npm run wallet:operator-bridge --prefix crypto -- prepare-release-evidence
```

Both commands print dry-run commands separately from live commands and do not print RPC values.

Live chain validation proof used a local mock RPC returning `0x2105`:

```json
{
  "valid": true,
  "baseChainId": 8453,
  "rpcConfigured": true,
  "rpcValuePrinted": false,
  "chainIdValid": true,
  "lockboxAddressValid": true,
  "operatorAckPresent": true,
  "errors": []
}
```

Wrong-chain refusal proof used a local mock RPC returning `0x1`:

```json
{
  "valid": false,
  "chainIdValid": false,
  "errors": ["wrong-chain-id"]
}
```

Live actions must run one of:

```powershell
npm run wallet:operator-bridge --prefix crypto -- validate --live
npm run flowchain:real-value-pilot -- --Mode Live --Action Observe
npm run flowchain:real-value-pilot -- --Mode Live --Action Withdraw
```
