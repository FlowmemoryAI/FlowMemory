# Test Vectors

Canonical production-L1 vector file:

- `crypto/fixtures/production-l1-vectors.json`

Positive signed transaction families:

- wallet transfer
- faucet/test funding
- token launch
- token transfer
- pool create
- add liquidity
- remove liquidity
- swap
- bridge credit authority
- withdrawal intent
- validator/finality object

Negative vectors prove exact rejection codes for:

- wrong chain ID
- wrong network profile
- wrong domain
- wrong signer
- wrong signer role
- stale nonce
- duplicate nonce
- duplicate transaction ID
- expired transaction
- mutated payload
- malformed public key
- malformed signature
- malformed root
- duplicate bridge source event

The vector validator command is:

```powershell
npm run validate:production-l1-crypto --prefix crypto
```

Observed result:

```text
FLOWCHAIN_PRODUCTION_L1_CRYPTO_OK positive=11 negative=14 hashHelpers=13 schemas=6
```
