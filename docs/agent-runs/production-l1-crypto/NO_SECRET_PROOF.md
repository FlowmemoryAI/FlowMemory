# No-Secret Proof

Secret boundary:

- Private key files remain ignored by Git through `.gitignore` and
  `crypto/.gitignore`.
- Production-L1 fixtures contain only public account metadata, payload
  documents, signatures, IDs, and expected validation failures.
- Deterministic test signing keys are generated in memory by helper functions;
  committed fixtures do not contain private keys, seed phrases, mnemonics,
  RPC credentials, API keys, or webhook-shaped strings.
- Public metadata exports exclude private key material and ciphertext.

No-secret scan command:

```powershell
npm run scan:no-secrets --prefix crypto
```

Observed result:

```json
{
  "schema": "flowmemory.crypto.no_secret_scan.v0",
  "ok": true
}
```
