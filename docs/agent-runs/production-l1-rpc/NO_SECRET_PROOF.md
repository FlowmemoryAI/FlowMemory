# No-Secret Proof

## Scanner

The control-plane has two secret gates:

- `services/shared/src/secret-scan.ts` is used by JSON-RPC dispatch before any result is returned.
- `services/control-plane/src/no-secret.ts` is used by the smoke client to scan every response in the 91-call private/local L1-shaped batch.
- `services/control-plane/test/control-plane.test.ts` scans browser-safe HTTP route responses, including `/health`, `/state`, `/explorer/summary`, `/product-flow/status`, `/rpc`, `/bridge/observations`, and mapped `/pilot/*` routes.

The scanner rejects secret-shaped keys or values including:

- private keys and secret keys;
- seed phrases and mnemonics;
- RPC credentials and credentialed URLs;
- API keys and bearer-style tokens;
- Slack/Discord/webhook-shaped URLs;
- raw secret-bearing env maps.

## Smoke Output

`npm run control-plane:smoke` passed with:

```json
{
  "methodCount": 91,
  "successCount": 87,
  "expectedErrorCount": 4,
  "noSecretScan": {
    "schema": "flowmemory.control_plane.no_secret_scan.v1",
    "scannedResponses": 91,
    "findingCount": 0
  }
}
```

## Tested Rejections

- `transaction_submit` rejects secret-shaped signed-envelope material.
- `bridge_observation_submit` rejects private key, seed phrase, mnemonic, RPC credential, API key, and webhook-shaped payloads.
- `raw_json_get` rejects responses if a loaded local raw source contains secret-shaped keys or values.
- Browser-safe HTTP routes are scanned in the control-plane test suite before assertions use the response bodies.

No route in the smoke batch returned private keys, seed phrases, mnemonics, RPC URLs with credentials, API keys, webhooks, raw env maps, or local vault contents.
