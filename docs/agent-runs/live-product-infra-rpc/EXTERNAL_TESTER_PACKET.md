# FlowChain External Tester Packet

Generated: 2026-05-16T08:59:57.1345886Z
Status: blocked
Shareable externally: False
Latest observed height: 33750

Do not share this network externally yet. Local wallet rehearsal is available, but external sharing remains blocked until the listed owner input names and live infrastructure gates pass.

## Tester Scope

- Use pilot test units only.
- Create a fresh test wallet through the service.
- Wait for a bridge credit or owner-funded pilot balance before sending.
- Send a small transfer to another tester and confirm it appears after new blocks are produced.
- Do not reuse passwords from other services.
- Do not send Base mainnet funds unless the owner has separately confirmed the bridge pilot is active and capped.

## Endpoint Checks

Replace <OWNER_PUBLIC_ENDPOINT> with the endpoint distributed by the owner outside this repository.

```powershell
Invoke-RestMethod -Method Get -Uri '<OWNER_PUBLIC_ENDPOINT>/health'
Invoke-RestMethod -Method Get -Uri '<OWNER_PUBLIC_ENDPOINT>/rpc/discover'
Invoke-RestMethod -Method Get -Uri '<OWNER_PUBLIC_ENDPOINT>/rpc/readiness'
Invoke-RestMethod -Method Get -Uri '<OWNER_PUBLIC_ENDPOINT>/chain/status'
```

## Wallet Flow

```powershell
$createBody = @{ label = "tester-one"; password = "<fresh-test-password>" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri '<OWNER_PUBLIC_ENDPOINT>/wallets/create' -ContentType 'application/json' -Body $createBody
Invoke-RestMethod -Method Get -Uri '<OWNER_PUBLIC_ENDPOINT>/wallets/balances'
$sendBody = @{ from = "<sender-account-id>"; to = "<recipient-account-id>"; amountUnits = "1"; memo = "external-tester-pilot"; applyBlock = $false; createRecipient = $false } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri '<OWNER_PUBLIC_ENDPOINT>/wallets/send' -ContentType 'application/json' -Body $sendBody
Invoke-RestMethod -Method Get -Uri '<OWNER_PUBLIC_ENDPOINT>/wallets/transfers'
```

## Current Gate Evidence

- External tester readiness: blocked
- Owner inputs: blocked
- Completion audit: blocked
- Local tester rehearsal ready: True
- External sharing ready: False

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
- FLOWCHAIN_BASE8453_TO_BLOCK
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
