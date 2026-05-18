# Two-Wallet Transfer Proof

Command:

```powershell
npm run wallet:transfer:e2e --prefix crypto
```

Result:

```text
FLOWCHAIN_WALLET_E2E_OK transferTxId=0xfd924f967f9ea2def72347c30ab4d87c14efe0b4106266d9aa3684007046ac49 walletA=0x70cc34b88ea98239192ca6329498fdb7bf92173206f5f7d33e97b9e09d9add9f walletB=0x43df29be6dcbf171c042f86227b45acf58938e981c539759335d76798778fde3 apiMempool=1
```

Public transfer details:

- Wallet A: `0x70cc34b88ea98239192ca6329498fdb7bf92173206f5f7d33e97b9e09d9add9f`
- Wallet B: `0x43df29be6dcbf171c042f86227b45acf58938e981c539759335d76798778fde3`
- Asset: `0x6a49beb2187e7ac4b3191f3066b7ff63b24a6b4f41d241559d8ba102edc8366b`
- Transfer amount: `125000`
- Wallet tx id: `0xfd924f967f9ea2def72347c30ab4d87c14efe0b4106266d9aa3684007046ac49`
- Control-plane intake status: `accepted_local`

Balance proof:

```json
{
  "before": { "from": "1000000", "to": "0" },
  "after": { "from": "875000", "to": "125000" }
}
```

Ignored proof path:

```text
devnet/local/production-l1-wallet/transfer-e2e/wallet-e2e-proof.json
```
