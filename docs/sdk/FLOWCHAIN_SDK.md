# FlowChain SDK And Devkit

Status: expanded local/private SDK and devkit slice.

The SDK package is:

```text
services/flowchain-sdk
```

It exposes a typed JSON-RPC client over the real FlowChain control-plane
`/rpc` endpoint and a CLI used by the developer quickstart.

## Client Example

```js
import { FlowChainClient } from "../services/flowchain-sdk/src/index.ts";

const client = new FlowChainClient({ rpcUrl: "http://127.0.0.1:8787/rpc" });
const readiness = await client.rpcReadiness();
const status = await client.chainStatus();
const blocks = await client.blockList({ limit: 5 });
const transactions = await client.transactionList({ limit: 5 });
const accounts = await client.accountList({ limit: 5 });
const transfers = await client.walletTransfers({ limit: 5 });
const send = await client.walletSend({
  fromAccountId: "local-account:sender",
  toAccountId: "local-account:recipient",
  amountUnits: "1",
  memo: "sdk-local-test"
});
const included = await client.waitForTransaction({
  txId: send.transferId,
  timeoutMs: 30000,
  pollMs: 1000
});
```

## CLI Examples

```powershell
npm run flowchain:devkit -- discover --json
npm run flowchain:devkit -- readiness --json
npm run flowchain:devkit -- health --json
npm run flowchain:devkit -- status --json
npm run flowchain:devkit -- node-status --json
npm run flowchain:devkit -- watch-height --seconds 30
npm run flowchain:devkit -- blocks --json --limit 5
npm run flowchain:devkit -- transactions --json --limit 5
npm run flowchain:devkit -- accounts --json --limit 5
npm run flowchain:devkit -- mempool --json --limit 5
npm run flowchain:devkit -- wallet-balances --json --limit 5
npm run flowchain:devkit -- wallet-transfers --json --limit 5
npm run flowchain:devkit -- wallet-send --json --from <account-id> --to <account-id> --amount-units 1
npm run flowchain:devkit -- wait-transaction --json --tx <tx-id> --seconds 30
npm run flowchain:devkit -- wallet-metadata --json --limit 5
npm run flowchain:devkit -- faucet-events --json --limit 5
npm run flowchain:devkit -- finality --json --limit 5
npm run flowchain:devkit -- bridge-readiness --json
npm run flowchain:devkit -- bridge-deposits --json --limit 5
npm run flowchain:devkit -- bridge-credits --json --limit 5
npm run flowchain:devkit -- withdrawals --json --limit 5
```

## Runnable Examples

```powershell
node examples/flowchain-node-quickstart.mjs
node examples/flowchain-node-quickstart.mjs --send
```

The browser readiness example lives at:

```text
examples/flowchain-browser-readiness/index.html
```

## Safety Rules

- Default RPC is `http://127.0.0.1:8787/rpc`.
- The devkit does not expose a public listener.
- Live Base 8453 bridge commands stay blocked until owner inputs exist.
- Diagnostics are redacted before printing or writing reports.
- Do not call this SDK EVM-compatible unless EVM JSON-RPC compatibility is
  implemented and tested.

## Verification

```powershell
npm test --prefix services/flowchain-sdk
npm run flowchain:sdk:e2e
npm run flowchain:dev-pack:e2e
```

`flowchain:sdk:e2e` checks the expanded SDK/CLI surface, the Node.js example,
the browser readiness example, and the required developer docs. `flowchain:dev-pack:e2e`
regenerates `docs/sdk/RPC_REFERENCE.generated.md` from live `rpc_discover`
output.
