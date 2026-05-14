# Envelope File Proof

Wallet signing writes envelopes to predictable ignored paths by default:

```text
devnet/local/wallet/envelopes/<tx-id>.json
```

The E2E wrote deterministic test envelopes under:

```text
devnet/local/production-l1-wallet/wallet-e2e/envelopes/
devnet/local/production-l1-wallet/transfer-e2e/envelopes/
```

Example transfer envelope file:

```text
devnet/local/production-l1-wallet/wallet-e2e/envelopes/0xfd924f967f9ea2def72347c30ab4d87c14efe0b4106266d9aa3684007046ac49.json
```

Each envelope includes:

- `txId` in the body;
- `payloadType`;
- payload body in `payload` and `tx`;
- `signerAddress`;
- public key and public key reference;
- nonce;
- fee support flag;
- validity support flag;
- signature;
- verification status.

The local control-plane accepted:

- transfer envelope: `accepted_local`;
- pool-create DEX envelope: `accepted_local`.

