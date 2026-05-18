# Product And DEX Signing Proof

Command:

```powershell
npm run wallet:e2e --prefix crypto
```

Result:

```text
FLOWCHAIN_WALLET_E2E_OK transferTxId=0xfd924f967f9ea2def72347c30ab4d87c14efe0b4106266d9aa3684007046ac49 walletA=0x70cc34b88ea98239192ca6329498fdb7bf92173206f5f7d33e97b9e09d9add9f walletB=0x43df29be6dcbf171c042f86227b45acf58938e981c539759335d76798778fde3 apiMempool=2
```

Signed product and DEX actions:

- Token launch: `0x90c0c7c915a7b59cb37716ffaf9a79c76079b709153d20f5d85dde2b8530fad1`
- Token transfer: `0xf56655c75ac9594abecaf037c1c5af95aa5685606afcdb4f4af0e9a6b9dcaecf`
- Pool create: `0xb322122020a06e03a261b6852827b693810c81ad1d03e3e126d9549e731fe42c`
- Add liquidity: `0x8732f11127e8d568b605bf4bb804618a946077f186c4cc964e04818c59fdd5f4`
- Swap: `0x59d325b565147b7fb128e5f9f12fb3593803ada9655f35546d25adb5320e8043`
- Remove liquidity: `0x9d6cb1b19e010b0dbd67504ef4983f0d967d0329317ed6e4287addc49d8d1b4b`
- Withdrawal intent: `0xec2b34b57f559ffc85f44b3a5a6f7c4a3d3741d03006325be8725560ec605e36`

Product identifiers:

- Token id: `0x9c15300bdb2e1548fdae65372706eb87cedc5a0f0dc6f01f112f074d5de10eed`
- Pool id: `0x72451c601965c788ed20124121e03e3b7b65521a1bdb6e353094cbafd4df8483`
- Submitted DEX envelope accepted by control-plane intake: `0x5612cb6a5d7e1860159c43144cb5e1f9669e1d1385efa7f15a6cd121e7208f12`

Every signed action returned:

```json
{
  "valid": true,
  "signatureValid": true,
  "chainIdMatch": true,
  "errors": []
}
```

Ignored proof path:

```text
devnet/local/production-l1-wallet/wallet-e2e/wallet-e2e-proof.json
```

