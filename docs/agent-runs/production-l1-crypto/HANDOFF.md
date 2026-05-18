# Owner-Gated L1 Crypto Handoff

Status: complete for the local/private production-L1-shaped crypto foundation.

## Runtime-Safe Validation

Exported validation module path:

- `crypto/src/runtime-validation.js`
- package subpath: `@flowmemory/crypto/runtime-validation`

Runtime import example:

```js
import { verifyFlowchainEnvelope } from "@flowmemory/crypto/runtime-validation";

const result = verifyFlowchainEnvelope({
  document,
  envelope,
  context: {
    chainId: "31337",
    networkProfile: "local-chain",
    expectedNonce: envelope.nonce,
    requireCanonical: true
  }
});

if (!result.ok) {
  throw new Error(result.failureCodes.join(","));
}
```

Control-plane import example:

```ts
import { verifyFlowchainEnvelope } from "@flowmemory/crypto/runtime-validation";

export function verifySubmittedEnvelope(document: Record<string, unknown>, envelope: Record<string, unknown>) {
  return verifyFlowchainEnvelope({
    document,
    envelope,
    context: {
      chainId: "31337",
      networkProfile: "local-chain",
      requireCanonical: true
    }
  });
}
```

The runtime subpath imports validation, identity, hashing, and signature
verification only. It does not import wallet/vault modules.

## Schema And Vectors

Envelope schema path:

- `schemas/flowmemory/local-transaction-envelope.schema.json`

Production-L1 vector file:

- `crypto/fixtures/production-l1-vectors.json`

Existing compatibility vector files:

- `crypto/fixtures/local-alpha-objects.json`
- `crypto/fixtures/product-testnet-transactions.json`
- `crypto/fixtures/vectors.json`

## Hash Helper Names

Identity:

- `normalizeFlowchainPublicKey`
- `flowchainPublicKeyHash`
- `flowchainAddressFromPublicKey`
- `flowchainAccountId`
- `flowchainSignerKeyId`
- `flowchainRoleMetadata`
- `flowchainRoleRoot`

Envelope and roots:

- `flowchainTransactionId`
- `flowchainBlockHash`
- `flowchainTxRoot`
- `flowchainReceiptRoot`
- `flowchainEventRoot`
- `flowchainAccountStateRoot`
- `flowchainTokenStateRoot`
- `flowchainDexStateRoot`

Bridge and finality:

- `flowchainBridgeObservationId`
- `flowchainBridgeCreditId`
- `flowchainWithdrawalIntentId`
- `flowchainFinalityReceiptId`

Replay:

- `accountNonceReplayKey`
- `roleScopedNonceReplayKey`
- `bridgeSourceEventReplayKey`
- `withdrawalIntentReplayKey`
- `finalityVoteReplayKey`

## Commands

Other agents should run:

```powershell
npm test --prefix crypto
npm run validate:vectors --prefix crypto
npm run validate:production-l1-crypto --prefix crypto
npm run wallet:e2e --prefix crypto
npm run scan:no-secrets --prefix crypto
git diff --check
```

Wallet command examples:

```powershell
npm run wallet:sign --prefix crypto -- --vault <vault> --document <document> --chain-id 31337 --network-profile local-chain --nonce 1 --out <envelope>
npm run wallet:verify --prefix crypto -- --document <document> --envelope <envelope> --chain-id 31337 --network-profile local-chain --require-canonical
npm run wallet:derive-metadata --prefix crypto -- --public-key <public-key> --role user
npm run production-l1:vectors --prefix crypto
```

## Signed Transfer Envelope

```json
{
  "schema": "flowchain.local_transaction_envelope.v0",
  "schemaVersion": 1,
  "networkProfile": "local-chain",
  "networkProfileHash": "0xbd64b702ecdbcab44fabefc7e5836219cde02f5d6a3f0abc0026dcdb9b46a56a",
  "envelopeId": "0x99f892b8621a80b34ee71cc6585c3b453212c0af6ff01e02bb26d98a18d3fe7b",
  "domain": "flowchain.production-l1.v0.transaction-envelope:profile:local-chain:chain:31337",
  "domainSeparator": "0x6e2e8ddd3eba28f318b038b64534e672e57324225ac7e8ae19729dfda1f7a2a8",
  "chainId": "31337",
  "nonce": "1",
  "signerId": "0xd73d877ada523f7171fec59bb80a282b1c697f5ee07d126a8f0aacc0e3e28ed3",
  "signerKeyId": "0x2fc3666dfc5634ead760c895a14fda3afc55b342794962265c8bf7e3deb9e096",
  "signerRole": "user",
  "signerRoleCode": 10,
  "publicKey": "0x0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
  "publicKeyEncoding": "secp256k1-compressed-hex",
  "signerAddress": "0xfd705a53418d74f973461f4360da507b319710eb",
  "objectSchema": "flowchain.product_transfer.v0",
  "objectType": "product_transfer",
  "payloadType": "wallet_transfer",
  "payloadTypeHash": "0x14480d5cbd3e854884a374919b17d1915f1951385d1da6ed95686bac3f1d5a64",
  "objectTypeHash": "0xff7912cf8351cc2aa97d9d9a9e583a3b449c5f9902914185f288c00b83a458a1",
  "objectId": "0x369b6f050b5ae930fa5d4af76c785bdef58e3b9143e75c302cf4d05e4ad11c12",
  "payloadHash": "0x262d3c9eb6dca796cd82ac1087642f76fe08445a8415554def3e26fe3c5e48fe",
  "issuedAtUnixMs": "1778702400000",
  "expiresAtUnixMs": "1778706000000",
  "localExecutionCost": {
    "unit": "local-compute",
    "amount": "0",
    "metering": "not-metered-local-private-testnet"
  },
  "localExecutionCostHash": "0x6cad238c63ddf255495af76197783d3392f61da8bb61a7943bd4b79ed3745fb8",
  "fee": {
    "assetId": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "amount": "0",
    "policy": "no-value-local-private-testnet"
  },
  "feeHash": "0x84226d772ddfcad0ed9437e0dbccdf42f4b05660112b16fdd53b089b83781b93",
  "signatureAlgorithm": "secp256k1-keccak256-eip712-local-v0",
  "signatureAlgorithmHash": "0x1a6f483c4f6880a162cefa906f3dd9dc228115e89c04c539d63601752d3d57ae",
  "signingDigest": "0x36150db99bef7d2b0d7c10c9284f3c12840517278bd72f8eee8dfa5c83e1e850",
  "signature": "0x9aaa403f876be1ce5a9584a7e8d0fedc6610880587ee74b8c6821183d35c40b15b6038c00c1df5a3692bbf01564616ba8ac44727c856f64f913c530dd19499fb",
  "transactionId": "0x8434b0e00b03709b812c040565671c17a0e99922c556530c2a7ec882fb27fe78"
}
```

## Signed Bridge-Credit Envelope

```json
{
  "schema": "flowchain.local_transaction_envelope.v0",
  "schemaVersion": 1,
  "networkProfile": "local-chain",
  "networkProfileHash": "0xbd64b702ecdbcab44fabefc7e5836219cde02f5d6a3f0abc0026dcdb9b46a56a",
  "envelopeId": "0x9e9d285d55c42e3ebfe63946042e2ec0cc8bb2d213f17ae7a4e5f2e41c2c6ec2",
  "domain": "flowchain.production-l1.v0.transaction-envelope:profile:local-chain:chain:31337",
  "domainSeparator": "0x6e2e8ddd3eba28f318b038b64534e672e57324225ac7e8ae19729dfda1f7a2a8",
  "chainId": "31337",
  "nonce": "9",
  "signerId": "0x40ea93e387b044dbb56c9e543ec503857a31c45aead019cf6088e60f1ceb2ac1",
  "signerKeyId": "0x4ae4fee7df34c54114adc91abe9fe874839b9fbbb23186939256b7681ad5cf67",
  "signerRole": "bridgeReleaseAuthority",
  "signerRoleCode": 13,
  "publicKey": "0x022f8bde4d1a07209355b4a7250a5c5128e88b84bddc619ab7cba8d569b240efe4",
  "publicKeyEncoding": "secp256k1-compressed-hex",
  "signerAddress": "0xb8d39c1dc062e9ce826020d0bf0ac2a3d92c52a3",
  "objectSchema": "flowchain.bridge_credit.v0",
  "objectType": "bridge_credit",
  "payloadType": "bridge_credit",
  "payloadTypeHash": "0x99c0a6dcd28db25cdab5deb9c9b59cca3e5aa98b434f03645a6b6d5e08bb13be",
  "objectTypeHash": "0x5c492a94b36aa3beb3b9ceb9dc5124464beeba9ac9fd2d04f88118cf73f3e912",
  "objectId": "0xfdf8329f54e438c79a8a58675fa3f6bcbe8354d6912c98651243e2d7c70455d5",
  "payloadHash": "0x201b8fad58b4f58b91ab870833da8e8009bf80f0b3b60b1a787f14e0a29961c2",
  "issuedAtUnixMs": "1778702400000",
  "expiresAtUnixMs": "1778706000000",
  "localExecutionCost": {
    "unit": "local-compute",
    "amount": "0",
    "metering": "not-metered-local-private-testnet"
  },
  "localExecutionCostHash": "0x6cad238c63ddf255495af76197783d3392f61da8bb61a7943bd4b79ed3745fb8",
  "fee": {
    "assetId": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "amount": "0",
    "policy": "no-value-local-private-testnet"
  },
  "feeHash": "0x84226d772ddfcad0ed9437e0dbccdf42f4b05660112b16fdd53b089b83781b93",
  "signatureAlgorithm": "secp256k1-keccak256-eip712-local-v0",
  "signatureAlgorithmHash": "0x1a6f483c4f6880a162cefa906f3dd9dc228115e89c04c539d63601752d3d57ae",
  "signingDigest": "0x38ed9b76d7684f8708ff1376dedfdf71b3cb81a58f1691325a629c2b6d04bc18",
  "signature": "0xcc7adfd27b431abbb8e95f029fe1c89d7450cd5d23edd696df8d5b5cdbc6e58161c982d0bcb28c95687745bb5532139df7fdb89148879ff561c529bf92ce3834",
  "transactionId": "0x8bfeeda684a9e9d7680bdef28820b7345c5724d25b50a43cfc0dbf9ad8b106dc"
}
```

## Unresolved Crypto Boundary

No blocker remains for local/private runtime/API/wallet agents to consume the
canonical envelope. Later production deployment, validator operations, custody
hardening, and bridge operation remain gated by separate decisions and review.
