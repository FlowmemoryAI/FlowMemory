# FlowMemory V0 JSON Schemas

These schemas are the canonical local/test V0 shapes for generated Flow Memory and Rootflow objects:

- `memory-signal.schema.json`
- `memory-receipt.schema.json`
- `rootflow-transition.schema.json`
- `rootfield-bundle.schema.json`
- `agent-memory-view.schema.json`
- `agent-account.schema.json`
- `model-passport.schema.json`
- `work-receipt.schema.json`
- `memory-cell.schema.json`
- `artifact-availability-proof.schema.json`
- `verifier-module.schema.json`
- `verifier-report.schema.json`
- `challenge.schema.json`
- `finality-receipt.schema.json`
- `bridge-deposit.schema.json`
- `bridge-credit.schema.json`
- `control-plane-real-value-pilot-status.schema.json`
- `bridge-withdrawal.schema.json`
- `local-balance-record.schema.json`
- `hardware-signal-envelope.schema.json`
- `local-signature-envelope.schema.json`
- `local-transaction-envelope.schema.json`
- `product-transaction.schema.json`
- `real-value-pilot-message.schema.json`
- `real-value-pilot-operator-config.schema.json`
- `real-value-pilot-public-metadata.schema.json`
- `control-plane-provenance-response.schema.json`
- `production-network-profile.schema.json`
- `production-genesis.schema.json`
- `production-validator-authority.schema.json`
- `production-account-public-metadata.schema.json`
- `production-transaction-envelope.schema.json`
- `production-transaction-payload.schema.json`
- `production-block-header.schema.json`
- `production-block-body.schema.json`
- `production-receipt.schema.json`
- `production-event.schema.json`
- `production-state-root-manifest.schema.json`
- `production-bridge-evidence.schema.json`
- `production-finality-receipt.schema.json`
- `production-export-snapshot.schema.json`

`memory-signal.schema.json` also embeds the `flowmemory.flowpulse_contract_event.v0`
shape, which records the `IFlowPulse.FlowPulse` event signature, indexed fields,
payload fields, and receipt-derived locator fields that the indexer added after
reading logs and receipts.

They describe local fixture objects only. They do not claim production L1 readiness, trustless verification, free storage, AI running on-chain, or production Uniswap v4 deployment.

The `flowchain.*.v0` schemas describe Local Alpha object documents whose IDs
are defined in `crypto/src/objects.js` and pinned by
`crypto/fixtures/local-alpha-objects.json`. They map the research object names
from the Noesis/FlowChain corpus into the current FlowMemory crypto package
without importing research-only SHA-256 or proof-system scaffolds.

`local-signature-envelope.schema.json` describes the local/test operator,
agent, verifier, and hardware signature envelope that wraps these object IDs.
The schema is paired with the validator in `crypto/src/objects.js`; consumers
should validate both JSON shape and recomputed cryptographic fields.

`local-transaction-envelope.schema.json` describes the chain-bound local/private
transaction envelope consumed by the private L1 package. It binds the chain id,
domain separator, nonce, signer, payload hash, object ID, and signature.

`product-transaction.schema.json` describes the Product Testnet V1 wallet
transaction documents that can be wrapped by `local-transaction-envelope`:
transfer, token launch, pool create, add liquidity, remove liquidity, swap, and
bridge credit acknowledgement. Bridge withdrawal intent uses
`bridge-withdrawal-intent.schema.json` and the same local transaction envelope.

The `real-value-pilot-*` schemas describe capped pilot operator messages,
env-derived non-secret config, and secret-free public metadata export. Pilot
messages include cap fields and are verified through the crypto package without
loading vault signing helpers.

The `production-*` schema names define the private/local FlowChain protocol
contract for downstream agents. The names are historical command and folder
vocabulary only; each schema carries `productionReady: false` where applicable
and does not claim public mainnet readiness. Owners are:

| Schema | Producer | Consumers |
| --- | --- | --- |
| `production-network-profile.schema.json` | protocol/HQ | runtime, wallet, bridge, RPC, dashboard |
| `production-genesis.schema.json` | runtime | wallet, bridge, consensus, RPC, dashboard |
| `production-validator-authority.schema.json` | consensus | runtime, RPC, dashboard |
| `production-account-public-metadata.schema.json` | wallet | runtime, RPC, bridge, dashboard |
| `production-transaction-envelope.schema.json` | wallet/crypto | runtime, RPC, dashboard |
| `production-transaction-payload.schema.json` | wallet/runtime/bridge/consensus | runtime, indexer, dashboard |
| `production-block-header.schema.json` | runtime | consensus, RPC, indexer, dashboard |
| `production-block-body.schema.json` | runtime | RPC, indexer, dashboard |
| `production-receipt.schema.json` | runtime | RPC, indexer, dashboard |
| `production-event.schema.json` | indexer/runtime | RPC, dashboard |
| `production-state-root-manifest.schema.json` | runtime/crypto | consensus, RPC, dashboard |
| `production-bridge-evidence.schema.json` | bridge relayer | runtime, RPC, dashboard |
| `production-finality-receipt.schema.json` | consensus | runtime, RPC, dashboard |
| `production-export-snapshot.schema.json` | runtime/RPC | dashboard, operators, review |

Run the canonical Local Alpha schema/fixture check from the crypto package:

```powershell
cd E:\FlowMemory\flowmemory-crypto\crypto
npm run validate:local-alpha
```
