# FlowChain SDK And Devkit

Status: first local/private SDK slice.

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
const transfers = await client.walletTransfers({ limit: 5 });
```

## CLI Examples

```powershell
npm run flowchain:devkit -- discover --json
npm run flowchain:devkit -- readiness --json
npm run flowchain:devkit -- status --json
npm run flowchain:devkit -- wallet-balances --json --limit 5
npm run flowchain:devkit -- wallet-transfers --json --limit 5
npm run flowchain:devkit -- bridge-readiness --json
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
npm run flowchain:dev-pack:e2e
```

`flowchain:dev-pack:e2e` regenerates
`docs/sdk/RPC_REFERENCE.generated.md` from live `rpc_discover` output.
