# FlowChain App Builder Guide

Status: local/private app builder guide.

## SDK Setup

The current SDK package is `services/flowchain-sdk` and uses FlowChain-native
JSON-RPC, not EVM JSON-RPC.

```js
import { FlowChainClient } from "../services/flowchain-sdk/src/index.ts";

const client = new FlowChainClient({ rpcUrl: "http://127.0.0.1:8787/rpc" });
const discovery = await client.rpcDiscover();
const status = await client.chainStatus();
```

## Node.js Example

Run the checked example:

```powershell
node examples/flowchain-node-quickstart.mjs --send
```

The example discovers RPC methods, reads readiness, reads blocks and
transactions, reads wallet balances, optionally sends a local no-value wallet
transfer, and prints a public-safe summary.

## Browser Example

Open `examples/flowchain-browser-readiness/index.html` while the local control
plane is running. It calls:

- `GET /rpc/discover`
- `GET /rpc/readiness`

It does not submit transactions or bridge actions.

## Common Panels

Balance panel:

```js
const balances = await client.walletBalances({ limit: 20 });
```

Activity panel:

```js
const transfers = await client.walletTransfers({ limit: 20 });
const transactions = await client.transactionList({ limit: 20 });
```

Bridge readiness panel:

```js
const bridge = await client.bridgeReadiness();
const credits = await client.bridgeCreditList({ limit: 20 });
```

Explorer panel:

```js
const blocks = await client.blockList({ limit: 10 });
const finality = await client.finalityList({ limit: 10 });
```

## Fail Closed

If `rpc_readiness` reports missing public RPC, backup, or Base bridge inputs,
the app should show the missing input names and disable public sharing or live
bridge actions.
