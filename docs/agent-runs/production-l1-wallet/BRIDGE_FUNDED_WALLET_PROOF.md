# Bridge-Funded Wallet Proof

The wallet E2E accepts a local pilot credit fixture as the funding source before transferring from wallet A to wallet B.

Command:

```powershell
npm run wallet:e2e --prefix crypto
```

Funding proof:

```json
{
  "source": "local pilot credit fixture",
  "account": "0x70cc34b88ea98239192ca6329498fdb7bf92173206f5f7d33e97b9e09d9add9f",
  "assetId": "0x6a49beb2187e7ac4b3191f3066b7ff63b24a6b4f41d241559d8ba102edc8366b",
  "amount": "1000000"
}
```

The funded wallet then signed:

- Transfer to wallet B: `0xfd924f967f9ea2def72347c30ab4d87c14efe0b4106266d9aa3684007046ac49`
- Buy/sell-style swap action: `0x59d325b565147b7fb128e5f9f12fb3593803ada9655f35546d25adb5320e8043`
- Withdrawal intent to Base address: `0xec2b34b57f559ffc85f44b3a5a6f7c4a3d3741d03006325be8725560ec605e36`

The root pilot wallet proof command now includes this bridge-funded wallet flow:

```powershell
npm run flowchain:real-value-pilot:wallet
```

It runs:

```powershell
npm run wallet:pilot-e2e --prefix crypto
npm run wallet:e2e --prefix crypto
```

