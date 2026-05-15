# FlowChain SDK

The SDK in `packages/flowchain-sdk/` is a FlowChain-native JSON-RPC client for
the real control-plane `/rpc` surface. It is not an EVM JSON-RPC SDK.

## Install In This Repo

```powershell
npm install
npm test --prefix packages/flowchain-sdk
```

Import from the workspace source while the package is local:

```js
import { createFlowChainClient } from "../../packages/flowchain-sdk/src/index.ts";
```

## Local Client

```js
import { createFlowChainClient } from "../../packages/flowchain-sdk/src/index.ts";

const client = createFlowChainClient({
  rpcUrl: "http://127.0.0.1:8787/rpc",
});

const discovery = await client.discover();
const readiness = await client.readiness();
const chain = await client.chainStatus();
```

Writes are limited to signed local envelopes submitted through
`transaction_submit`:

```js
import { createLocalSignedEnvelope } from "../../packages/flowchain-sdk/src/index.ts";

const receipt = await client.submitSignedTransaction(
  createLocalSignedEnvelope({
    type: "TransferLocalTestUnits",
    transferId: "transfer:docs:001",
    fromAccountId: "local-account:alice",
    toAccountId: "local-account:bob",
    amountUnits: 1,
    memo: "docs-transfer",
  }),
  { runtimeSubmit: true, submittedBy: "operator:docs" },
);
```

The SDK rejects malformed or unsigned envelopes before sending them.

## Reference

- Generated JSON: `docs/sdk/rpc-reference.json`
- Generated Markdown: `docs/sdk/rpc-reference.md`

Update after changing the control-plane method list:

```powershell
node tools/flowchain-rpc-reference.mjs --rpc-url http://127.0.0.1:8787/rpc --write
```

Check drift:

```powershell
node tools/flowchain-rpc-reference.mjs --rpc-url http://127.0.0.1:8787/rpc --check
```
