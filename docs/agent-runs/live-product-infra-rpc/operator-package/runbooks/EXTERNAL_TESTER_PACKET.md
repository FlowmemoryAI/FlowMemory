# FlowChain External Tester Packet

Generated: 2026-05-20T07:34:40.4013738Z
Status: blocked
Shareable externally: False
Latest observed height: 99457

Do not share this network externally yet. Local wallet rehearsal is available, but external sharing remains blocked until the listed owner input names and live infrastructure gates pass.

## Tester Scope

- Use pilot test units only.
- Create a fresh test wallet through the service.
- Use only the owner-provided tester bearer token for write requests.
- Request a capped tester faucet credit, bridge credit, or owner-funded pilot balance before sending.
- Send a small transfer to another tester and confirm it appears after new blocks are produced.
- Do not reuse passwords from other services.
- Do not send Base mainnet funds unless the owner has separately confirmed the bridge pilot is active and capped.

## Endpoint Checks

Replace <OWNER_PUBLIC_ENDPOINT> with the endpoint distributed by the owner outside this repository.

## Connection Profile

Machine-readable connection profile: docs/agent-runs/live-product-infra-rpc/external-tester-connect-pack.json

```json
{
  "network": "FlowChain friends-and-family pilot",
  "chainId": "flowmemory-local-devnet-v0",
  "rpcEndpoint": "<OWNER_PUBLIC_ENDPOINT>/rpc",
  "explorerSummary": "<OWNER_PUBLIC_ENDPOINT>/explorer/summary",
  "testerWriteAuth": "Authorization: Bearer <OWNER_TESTER_WRITE_TOKEN>"
}
```

```powershell
Invoke-RestMethod -Method Get -Uri '<OWNER_PUBLIC_ENDPOINT>/health'
Invoke-RestMethod -Method Get -Uri '<OWNER_PUBLIC_ENDPOINT>/rpc/discover'
Invoke-RestMethod -Method Get -Uri '<OWNER_PUBLIC_ENDPOINT>/rpc/readiness'
Invoke-RestMethod -Method Get -Uri '<OWNER_PUBLIC_ENDPOINT>/chain/status'
Invoke-RestMethod -Method Get -Uri '<OWNER_PUBLIC_ENDPOINT>/tester/status'
```

## Wallet Flow

```powershell
$headers = @{ Authorization = "Bearer <OWNER_TESTER_WRITE_TOKEN>" }
$createBody = @{ label = "tester-one"; password = "<fresh-test-password>" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri '<OWNER_PUBLIC_ENDPOINT>/tester/wallets/create' -Headers $headers -ContentType 'application/json' -Body $createBody
Invoke-RestMethod -Method Get -Uri '<OWNER_PUBLIC_ENDPOINT>/wallets/balances'
$faucetBody = @{ accountId = "<sender-account-id>"; amountUnits = "1"; reason = "external-tester-pilot-faucet" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri '<OWNER_PUBLIC_ENDPOINT>/tester/faucet' -Headers $headers -ContentType 'application/json' -Body $faucetBody
$sendBody = @{ from = "<sender-account-id>"; to = "<recipient-account-id>"; amountUnits = "1"; memo = "external-tester-pilot"; createRecipient = $false } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri '<OWNER_PUBLIC_ENDPOINT>/tester/wallets/send' -Headers $headers -ContentType 'application/json' -Body $sendBody
Invoke-RestMethod -Method Get -Uri '<OWNER_PUBLIC_ENDPOINT>/wallets/transfers'
```

## Current Gate Evidence

- External tester readiness: blocked
- Owner inputs: blocked
- Completion audit: blocked
- Local tester rehearsal ready: True
- External sharing ready: False
- Packet executable smoke validated: True
- Authenticated tester gateway ready: True

## Blocking Env Names

- FLOWCHAIN_RPC_PUBLIC_URL
- FLOWCHAIN_RPC_ALLOWED_ORIGINS
- FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE
- FLOWCHAIN_RPC_TLS_TERMINATED
- FLOWCHAIN_RPC_STATE_BACKUP_PATH
- FLOWCHAIN_PILOT_OPERATOR_ACK
- FLOWCHAIN_BASE8453_RPC_URL
- FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS
- FLOWCHAIN_BASE8453_SUPPORTED_TOKEN
- FLOWCHAIN_BASE8453_ASSET_DECIMALS
- FLOWCHAIN_BASE8453_FROM_BLOCK
- FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI
- FLOWCHAIN_PILOT_TOTAL_CAP_WEI
- FLOWCHAIN_PILOT_CONFIRMATIONS

## Owner Verification Commands

- npm run flowchain:owner-inputs
- npm run flowchain:owner-env:readiness -- -AllowBlocked
- npm run flowchain:live-infra:check
- npm run flowchain:tester:readiness
- npm run flowchain:completion:audit
- npm run flowchain:live-product:e2e
