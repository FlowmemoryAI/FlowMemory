# App Builder Guide

Apps should use the SDK from `packages/flowchain-sdk/` and target the
FlowChain-native JSON-RPC path.

## Node.js

```js
import { createFlowChainClient } from "../../packages/flowchain-sdk/src/index.ts";

const client = createFlowChainClient({
  rpcUrl: "http://127.0.0.1:8787/rpc",
});

console.log(await client.chainStatus());
```

Run the complete Node example:

```powershell
node examples/flowchain-node-local/index.mjs
```

## Browser / Vite / React

The browser example uses `fetch` only and calls browser-safe readiness mirrors:

```powershell
cd examples/flowchain-browser-vite
npm install
npm run dev
```

Open the Vite URL and keep the control-plane server running at
`http://127.0.0.1:8787/rpc`.

## Balance Widget

```js
const balance = await client.balanceGet("local-account:alice");
```

## Send Transaction Flow

```js
const receipt = await client.submitSignedTransaction(envelope, {
  runtimeSubmit: true,
  submittedBy: "operator:app",
});
```

Then poll:

```js
await client.transactionGet({ txId: receipt.txId });
await client.finalityGet({ objectId: receipt.txId });
```

## Bridge Readiness Panel

```js
const readiness = await client.bridgeReadiness();
```

Display `failClosedStatus`, `readyForOperatorLivePilot`, and
`missingEnvNames`. Do not display env values.

## Activity List

Use:

```js
const activity = await client.transferHistory({ limit: 10 });
const txs = await client.transactionList({ limit: 10 });
```
