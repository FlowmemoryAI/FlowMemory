# Vault Boundary Proof

Vault files are written only to ignored local paths:

```text
devnet/local/production-l1-wallet/wallet-e2e/wallet-a.vault.local.json
devnet/local/production-l1-wallet/wallet-e2e/wallet-b.vault.local.json
devnet/local/production-l1-wallet/transfer-e2e/wallet-a.vault.local.json
devnet/local/production-l1-wallet/transfer-e2e/wallet-b.vault.local.json
```

Ignore coverage:

```text
.gitignore -> devnet/local/
crypto/.gitignore -> .wallet/, devnet/local/, *.vault.local.json, *.wallet.local.json
```

Public metadata export contains:

- account label;
- local FlowChain address;
- public key;
- key scheme;
- signer role;
- chain ID binding;
- last known nonce and next nonce hint.

It excludes signing material, vault encryption payloads, local password/session data, RPC credentials, API keys, and webhooks.

Wrong password behavior is covered by `npm test --prefix crypto`; the negative test rejects signing with a wrong password and does not expose key material.
