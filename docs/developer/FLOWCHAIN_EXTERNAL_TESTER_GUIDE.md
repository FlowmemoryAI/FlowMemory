# FlowChain External Tester Guide

Status: friends-and-family pilot guide. This is production-oriented, but it is
not a claim that public RPC or the live bridge is ready. If any readiness command
reports `blocked`, `failed`, `productionReady=false`, or a missing owner input,
stop that part of the test and send the output back to the owner.

This guide is for testers who are helping prove that FlowChain can be reached
from outside the owner machine, that blocks are advancing, that wallet balances
and transfer history are readable, and that approved test funds or bridge
credits can be used safely.

## Roles

The owner operates the chain, public RPC, bridge, faucet or credit source, and
support channel.

The tester connects to the owner-provided endpoint, uses only the provided
wallet/account path, sends small test transactions, and returns evidence.

Do not improvise around blocked checks. A blocked bridge or public RPC check is
a correct safety result until the owner fixes the missing input.

## What The Owner Must Provide

Before a tester starts, the owner must send a tester packet with:

- Test window, timezone, and expected duration.
- Network label, for example `FlowChain friends-and-family pilot`.
- Public RPC URL ending in `/rpc`, preferably HTTPS.
- Whether the RPC URL has a bearer token, basic auth, or IP allowlist.
- Tester write gateway token if wallet creation or wallet-to-wallet sends are
  part of the test. This token is separate from the read-only RPC URL and must
  be sent out of band.
- Approved wallet path:
  - a wallet app/build with instructions, or
  - pre-created no-value test account IDs, or
  - a current wallet creation flow that keeps private material on the tester
    device.
- One funded sender account and one recipient account, or instructions for two
  testers to exchange public account IDs.
- Test amount limit. Default to `1` unit unless the owner says otherwise.
- Funding path:
  - faucet/test allocation,
  - owner-granted balance,
  - bridge credit,
  - or no funding yet.
- Bridge status and limits if the bridge is part of the test.
- Support contact and emergency stop phrase.
- What evidence is safe to send back and where to send it.

The owner should run these checks before inviting testers:

```powershell
npm run flowchain:tester:readiness -- -AllowBlocked
npm run flowchain:tester:gateway:e2e
npm run flowchain:external-tester:packet -- -AllowBlocked
npm run flowchain:public-rpc:validate
npm run flowchain:bridge:live:check
npm run flowchain:no-secret:scan
```

If these commands are blocked because owner inputs are missing, the tester packet
must say exactly which parts are unavailable.

## What Testers Need Installed

For command-line testing:

- Windows PowerShell.
- Node.js and npm.
- A clean checkout of this repo.
- Dependencies installed with `npm install`.
- The owner-provided RPC URL and account IDs.

For app-only testing:

- The owner-approved wallet app/build.
- The owner-provided RPC URL or wallet connection profile.
- The same evidence checklist at the end of this guide.

## Safety Rules

Never share:

- Private keys.
- Seed phrases or mnemonics.
- Wallet passphrases.
- Raw key files.
- `.env` files.
- RPC auth tokens.
- Bridge operator keys.
- Screenshots that show secrets, tokens, or full auth URLs.

Safe evidence usually includes:

- Public account IDs.
- Redacted RPC host.
- Block heights.
- Transaction IDs or transfer IDs.
- Bridge credit IDs if the owner says they are safe to share.
- JSON command output after checking it does not contain secrets.

If an RPC URL includes credentials, redact them before sharing:

```text
https://REDACTED@example.flowchain.net/rpc
```

## Connect To The RPC

Set the owner-provided RPC URL in PowerShell:

```powershell
$env:FLOWCHAIN_RPC_URL = "<owner-provided-rpc-url-ending-in-/rpc>"
```

Check RPC discovery:

```powershell
npm run flowchain:devkit -- discover --json --rpc $env:FLOWCHAIN_RPC_URL
```

Check readiness:

```powershell
npm run flowchain:devkit -- readiness --json --rpc $env:FLOWCHAIN_RPC_URL
```

Expected result for a real external pilot:

- The command reaches the owner-provided endpoint.
- The response is JSON.
- The response does not print env values or secrets.
- Public RPC readiness is not blocked unless the owner already told you that
  external RPC is still gated.

If you are only running a local private smoke test on the same machine as the
chain, the default RPC is:

```text
http://127.0.0.1:8787/rpc
```

Local testing is useful, but it does not prove public RPC, public networking, or
live bridge readiness.

## Raw RPC Fallback

Use this helper if npm is unavailable but PowerShell can reach the RPC:

```powershell
function Invoke-FlowChainRpc {
  param(
    [Parameter(Mandatory=$true)][string]$Method,
    [hashtable]$Params = @{}
  )

  $body = @{
    jsonrpc = "2.0"
    id = "tester-$Method"
    method = $Method
    params = $Params
  } | ConvertTo-Json -Depth 8

  Invoke-RestMethod `
    -Uri $env:FLOWCHAIN_RPC_URL `
    -Method Post `
    -ContentType "application/json" `
    -Body $body
}
```

Then run:

```powershell
Invoke-FlowChainRpc -Method "rpc_discover"
Invoke-FlowChainRpc -Method "rpc_readiness"
Invoke-FlowChainRpc -Method "chain_status"
```

## Verify Block Production

Run chain status twice, at least 20 seconds apart:

```powershell
npm run flowchain:devkit -- status --json --rpc $env:FLOWCHAIN_RPC_URL
Start-Sleep -Seconds 20
npm run flowchain:devkit -- status --json --rpc $env:FLOWCHAIN_RPC_URL
```

The chain is alive when the status says the node is running and the height field
advances between checks. Depending on the response version, the height may be
named `currentBlock`, `latestHeight`, or `height`.

Send the owner both status outputs with timestamps.

## Wallet And Account Setup

Use only the account setup path in the owner packet.

If the owner gives a wallet app:

1. Install only the exact build or URL from the owner.
2. Create or import a test wallet as instructed.
3. Store private material locally only.
4. Share only the public account ID or public address with the owner.

If the owner gives pre-created test account IDs:

1. Treat them as no-value pilot accounts unless the owner says otherwise.
2. Do not ask for or share private keys.
3. Use the account IDs only during the approved test window.

The current devkit can read wallet balances, read transfer history, and submit a
wallet send through the owner-approved tester write gateway. It is not a
general-purpose wallet custody app.

For public friends-and-family tests, the write gateway uses these paths:

```text
POST /tester/wallets/create
POST /tester/wallets/send
```

Both require:

```powershell
$headers = @{ Authorization = "Bearer <OWNER_TESTER_WRITE_TOKEN>" }
```

Do not use the private local `/wallets/create` or `/wallets/send` routes against
a public endpoint.

## Receive Test Funds Or Bridge Credits

First check wallet balances:

```powershell
npm run flowchain:devkit -- wallet-balances --json --limit 20 --rpc $env:FLOWCHAIN_RPC_URL
```

If the owner grants test funds directly, wait until your account appears with
the expected amount.

If the owner uses bridge credits, first check bridge readiness:

```powershell
npm run flowchain:devkit -- bridge-readiness --json --rpc $env:FLOWCHAIN_RPC_URL
npm run flowchain:devkit -- bridge-status --json --rpc $env:FLOWCHAIN_RPC_URL
```

If readiness is blocked or fail-closed, do not bridge funds. Send the output to
the owner.

If the owner gives a bridge credit lookup key, check it with raw RPC:

```powershell
Invoke-FlowChainRpc -Method "bridge_credit_status" -Params @{
  creditId = "<owner-provided-credit-id>"
}
```

The lookup key can also be a `depositId`, `accountId`, `flowchainRecipient`,
`txHash`, `baseTxHash`, or `walletAddress` if the owner gives that instead.

For friends-and-family testing, use no-value test credits unless the owner
explicitly says the bridge is in an approved live-value pilot.

## Send Wallet To Wallet

Choose the smallest useful amount. Default to `1` unit.

Use a memo that identifies the test without exposing private information:

```text
ff-test-YYYYMMDD-your-initials
```

Submit the transfer:

```powershell
$base = $env:FLOWCHAIN_RPC_URL -replace '/rpc$',''
$headers = @{ Authorization = "Bearer <OWNER_TESTER_WRITE_TOKEN>" }
$sendBody = @{
  from = "<sender-account-id>"
  to = "<recipient-account-id>"
  amountUnits = "1"
  memo = "ff-test-YYYYMMDD-your-initials"
  createRecipient = $false
} | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$base/tester/wallets/send" -Headers $headers -ContentType "application/json" -Body $sendBody
```

Important:

- The tester write gateway is capped by `FLOWCHAIN_TESTER_MAX_SEND_UNITS`.
- Use it only against the owner-approved pilot endpoint.
- Never send more than the owner-approved limit.
- Never use a real-value account unless the owner explicitly confirms a
  live-value pilot in writing.

Record the transfer ID, transaction ID, included block height, or receipt fields
returned by the command.

## Verify Transfer History

After sending, wait for at least one new block:

```powershell
Start-Sleep -Seconds 20
npm run flowchain:devkit -- status --json --rpc $env:FLOWCHAIN_RPC_URL
```

Then read transfer history:

```powershell
npm run flowchain:devkit -- wallet-transfers --json --limit 20 --rpc $env:FLOWCHAIN_RPC_URL
```

Confirm:

- The sender account appears.
- The recipient account appears.
- The amount matches the test amount.
- The memo matches your test memo, if memo is returned.
- The transfer or transaction ID matches the send result.
- The transfer is associated with a block or finalized status if those fields
  are present.

Then check balances again:

```powershell
npm run flowchain:devkit -- wallet-balances --json --limit 20 --rpc $env:FLOWCHAIN_RPC_URL
```

## Collect Diagnostics

Run diagnostics after the transfer test:

```powershell
npm run flowchain:devkit -- diagnostics --json --rpc $env:FLOWCHAIN_RPC_URL
```

Run discovery and readiness again:

```powershell
npm run flowchain:devkit -- discover --json --rpc $env:FLOWCHAIN_RPC_URL
npm run flowchain:devkit -- readiness --json --rpc $env:FLOWCHAIN_RPC_URL
```

Before sending diagnostics to the owner, review the output for:

- Private keys.
- Seed phrases.
- Auth tokens.
- Full RPC URLs with embedded credentials.
- Local filesystem paths you do not want to share.

The devkit is expected to redact sensitive-looking values, but testers should
still review evidence before sending it.

## Evidence To Send Back

Send one message or folder with:

- Tester name or initials.
- Date and local timezone.
- Operating system.
- Node.js version from `node --version`.
- npm version from `npm --version`.
- Redacted RPC URL or endpoint label.
- Account IDs used.
- Readiness output.
- Status output before the send.
- Status output after the send.
- Wallet balance output before the send.
- Wallet send result.
- Wallet transfer history after the send.
- Wallet balance output after the send.
- Bridge readiness and bridge status output, if bridge testing was included.
- Bridge credit status output, if the owner gave a credit lookup key.
- Diagnostics output.
- Any screenshots from the wallet app, with secrets redacted.
- A short note describing what worked and what failed.

Suggested evidence file names:

```text
01-readiness.json
02-status-before.json
03-wallet-balances-before.json
04-wallet-send.json
05-status-after.json
06-wallet-transfers-after.json
07-wallet-balances-after.json
08-bridge-readiness.json
09-bridge-status.json
10-diagnostics.json
NOTES.md
```

## Notes Template

```text
# FlowChain Tester Notes

Tester:
Date:
Timezone:
OS:
Node:
npm:
RPC endpoint label:

Sender account:
Recipient account:
Amount:
Memo:

Block height before:
Block height after:
Transfer ID:
Transaction ID:
Bridge credit ID:

What worked:

What failed:

Unexpected behavior:

Screenshots attached:
```

## When To Stop Immediately

Stop and contact the owner if:

- Readiness is blocked and the owner did not warn you.
- The RPC endpoint is not HTTPS for an external public test.
- The wallet asks you to paste a seed phrase into chat, email, or a web form.
- The bridge readiness command is blocked or fail-closed.
- A command returns a secret, private key, seed phrase, or env value.
- A transfer amount is higher than the owner-approved limit.
- You see duplicate sends, unexpected balance loss, or a transaction that keeps
  retrying.
- The emergency stop phrase is announced by the owner.

## Owner Review Checklist

For each tester, the owner should confirm:

- RPC was reachable from the tester network.
- `rpc_discover` and `rpc_readiness` returned expected public-safe metadata.
- Block height advanced during the test window.
- The sender account was funded before the send.
- The wallet send produced a receipt or transfer result.
- Transfer history includes the send.
- Balances changed as expected.
- Bridge readiness and bridge credit evidence match the pilot mode.
- Diagnostics did not include secrets.
- Any failure has a timestamp, command, redacted output, and tester environment.

Do not promote the endpoint to public production until external tester evidence,
public RPC validation, bridge readiness, backup proof, observability, incident
ops, no-secret scanning, and the completion audit all pass or are explicitly
accounted for by owner-approved blockers.
