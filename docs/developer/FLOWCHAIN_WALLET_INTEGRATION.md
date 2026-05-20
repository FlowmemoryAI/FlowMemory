# FlowChain Wallet Integration

Status: local/private wallet integration guide. This is not a custody service
or production wallet certification.

## Account Shape

FlowChain account IDs are opaque strings returned by the control plane. Treat
them as public identifiers. Do not infer private key material from the account
ID, wallet ID, signer ID, or public key hint.

Use:

```powershell
npm run flowchain:devkit -- accounts --json --limit 20
npm run flowchain:devkit -- wallet-metadata --json --limit 20
npm run flowchain:devkit -- wallet-balances --json --limit 20
```

For a single account:

```powershell
npm run flowchain:devkit -- account --json --account <account-id>
npm run flowchain:devkit -- balance --json --account <account-id>
npm run flowchain:devkit -- wallet-metadata-get --json --account <account-id>
```

## Wallet Creation Boundary

Local wallet creation is available through the control-plane HTTP path used by
the external tester harness. Responses must return public metadata only:

- `secretMaterialReturned=false`
- no seed phrase or mnemonic
- no private key
- no passphrase
- no raw vault ciphertext in logs or reports

The current devkit focuses on public metadata, balance reads, transfer history,
local `wallet-send`, and signed transaction envelope submission. It is not a
hosted custody API.

## Send Flow

Use the real control-plane wallet send path:

```powershell
npm run flowchain:devkit -- wallet-send --json --from <sender-account-id> --to <recipient-account-id> --amount-units 1 --memo local-wallet-test
```

This is local no-value testing unless owner readiness gates explicitly say
otherwise. The command must never broadcast a Base bridge transaction or expose
a public RPC listener.

## Signed Envelope Flow

For wallet integrations that produce FlowChain-native signatures, use the local
signed-envelope example and submit through `transaction_submit`:

```powershell
node examples/flowchain-signed-envelope.mjs --no-submit --write devnet/local/flowchain-signed-envelope-example/signed-envelope.json
npm run flowchain:devkit -- submit-signed-transaction --json --signed-envelope devnet/local/flowchain-signed-envelope-example/signed-envelope.json --submitted-by wallet-integration-test
```

This path verifies the envelope cryptographically and records it into private
local intake through `/transactions/submit`. It does not expose a public write
endpoint, does not enable `transaction_submit` on public `/rpc`, and does not
broadcast bridge funds.

## Activity Flow

After a send, wait for block inclusion and read transfer history:

```powershell
npm run flowchain:devkit -- watch-height --json --seconds 30
npm run flowchain:devkit -- wait-transaction --json --tx <tx-id-or-hash> --seconds 30
npm run flowchain:devkit -- wallet-transfers --json --limit 20
```

Use `transaction_get` or the devkit `transaction` command if the send result
returns a transaction ID:

```powershell
npm run flowchain:devkit -- transaction --json --tx <tx-id-or-hash>
```

## Replay And Nonce Rules

Runtime-backed wallet sends are accepted through the control-plane path and
recorded into the local runtime state. Integrators should treat duplicate
submission as unsafe unless the returned receipt proves idempotency. Do not
retry blindly after a timeout; first read transfer history and account balance.

## Backup And Import

Private material remains local. Backup/import UX must keep secrets out of:

- JSON-RPC responses
- CLI output
- screenshots sent to support
- docs examples
- generated reports

## SDK Calls

```js
import { FlowChainClient } from "../services/flowchain-sdk/src/index.ts";

const client = new FlowChainClient();
const balances = await client.walletBalances({ limit: 20 });
const transfers = await client.walletTransfers({ limit: 20 });
const send = await client.walletSend({
  fromAccountId: "local-sender",
  toAccountId: "local-recipient",
  amountUnits: "1",
  memo: "local-wallet-test",
  applyBlock: true
});
const included = await client.waitForTransaction({
  txId: send.transferId,
  timeoutMs: 30000
});
const signedSubmit = await client.submitSignedEnvelope(signedEnvelope, {
  submittedBy: "wallet-integration-test",
  runtimeSubmitMode: "off"
});
```
