# Chain Safety Proof

Wallet metadata binds each account to `chainId`.

Metadata verification command:

```powershell
npm run wallet:verify-metadata --prefix crypto -- --metadata devnet/local/production-l1-wallet/cli-smoke/wallet-a-public-metadata.json --chain-id 31337
```

Result:

```json
{
  "valid": true,
  "secretFree": true,
  "chainIdMatch": true,
  "accountCount": 1,
  "errors": []
}
```

Envelope verification rejects wrong chain IDs. `npm test --prefix crypto` covers:

- wrong chain ID;
- stale nonce;
- replay nonce;
- malformed public key;
- mutated payload;
- signature mismatch through malformed signer data.

Bridge operator safety:

- `wallet:operator-bridge validate --live` calls `eth_chainId`.
- Base chain must be `8453`.
- The command reports `rpcValuePrinted: false`.
- A mock wrong chain returned `wrong-chain-id` and nonzero exit status.

Withdrawal safety:

- `sign-withdrawal-intent` requires a 20-byte Base destination address.
- malformed Base destination addresses are rejected before signing.
- withdrawal intent stays `testMode: true`, `broadcast: false`, and `productionReady: false`.
