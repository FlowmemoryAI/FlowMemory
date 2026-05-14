# Runtime Verify Contract

Runtime/API-safe import:

```js
import { verifyFlowchainEnvelope } from "@flowmemory/crypto/runtime-validation";
```

Source path:

- `crypto/src/runtime-validation.js`

The runtime subpath does not import wallet vault code. It returns:

- `ok`
- `failureCodes`
- `signerAddress`
- `signerAccountId`
- `signerPublicIdentity`
- `payloadHash`
- `transactionId`
- `envelopeId`
- `signingDigest`
- `nonce`
- `chainId`
- `networkProfile`
- `payloadType`
- `signerRole`
- `signerKeyId`

Runtime agents should call it with:

```js
const result = verifyFlowchainEnvelope({
  document,
  envelope,
  context: {
    chainId: "31337",
    networkProfile: "local-chain",
    expectedNonce: "1",
    requireCanonical: true
  }
});
```

Reject when `result.ok !== true`. Use `failureCodes` as the stable local/private
error contract.
