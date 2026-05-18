# CLI Proof

Commands added or kept working:

```powershell
npm test --prefix crypto
npm run validate:vectors --prefix crypto
npm run validate:production-l1-crypto --prefix crypto
npm run wallet:e2e --prefix crypto
npm run scan:no-secrets --prefix crypto
```

Wallet signing command:

```powershell
npm run wallet:sign --prefix crypto -- --vault <vault> --document <document> --chain-id 31337 --network-profile local-chain --nonce 1 --out <envelope>
```

Wallet verification command:

```powershell
npm run wallet:verify --prefix crypto -- --document <document> --envelope <envelope> --chain-id 31337 --network-profile local-chain --require-canonical
```

Public metadata derivation command:

```powershell
npm run wallet:derive-metadata --prefix crypto -- --public-key <public-key> --role user
```

Vector print command:

```powershell
npm run production-l1:vectors --prefix crypto
```

No-secret scan command:

```powershell
npm run scan:no-secrets --prefix crypto
```
