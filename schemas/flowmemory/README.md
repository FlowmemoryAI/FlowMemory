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
- `bridge-withdrawal.schema.json`
- `local-account-balance.schema.json`
- `hardware-signal-envelope.schema.json`
- `local-signature-envelope.schema.json`
- `local-transaction-envelope.schema.json`
- `local-wallet-public-metadata.schema.json`
- `control-plane-provenance-response.schema.json`

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

`local-transaction-envelope.schema.json` describes the wallet-signed local
transaction wrapper. It binds the transaction payload hash to a domain,
chain-id, signer metadata, nonce, validity window, and secp256k1 signature
while preserving `payload.tx` as the devnet-consumable transaction object.

`local-wallet-public-metadata.schema.json` is the only wallet metadata shape
that should be exported to control-plane or workbench agents. It contains
public account IDs, signer key IDs, roles, public keys, labels, and next nonce
only; encrypted vault ciphertext and private keys stay local.

Run the canonical Local Alpha schema/fixture check from the crypto package:

```powershell
cd E:\FlowMemory\flowmemory-crypto\crypto
npm run validate:local-alpha
npm run validate:vectors
```
