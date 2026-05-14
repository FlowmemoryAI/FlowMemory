# Wallet Commands

Status: implemented for local/private FlowChain operator use.

Set the password only in the local shell:

```powershell
$env:FLOWMEMORY_TEST_WALLET_PASSWORD="<local-password>"
```

Create wallet A and wallet B:

```powershell
npm run wallet:create --prefix crypto -- --vault devnet/local/wallet/wallet-a.vault.local.json --chain-id 31337 --label wallet-a --role agent --metadata-out devnet/local/wallet/wallet-a-public-metadata.json
npm run wallet:create --prefix crypto -- --vault devnet/local/wallet/wallet-b.vault.local.json --chain-id 31337 --label wallet-b --role agent --metadata-out devnet/local/wallet/wallet-b-public-metadata.json
```

Safe create output contains public fields only:

```json
{
  "schema": "flowchain.wallet.account_created.v0",
  "address": "0x70cc34b88ea98239192ca6329498fdb7bf92173206f5f7d33e97b9e09d9add9f",
  "publicKey": "0x0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
}
```

Import from explicit local input:

```powershell
$env:FLOWCHAIN_WALLET_IMPORT_PRIVATE_KEY="<local-only-hex-key>"
npm run wallet:import --prefix crypto -- --vault devnet/local/wallet/imported.vault.local.json --private-key-env FLOWCHAIN_WALLET_IMPORT_PRIVATE_KEY --chain-id 31337 --label imported-a
```

Safe import output prints only the public address:

```json
{
  "schema": "flowchain.wallet.account_imported.v0",
  "address": "0x..."
}
```

Unlock, lock, and list:

```powershell
npm run wallet:unlock --prefix crypto -- --vault devnet/local/wallet/wallet-a.vault.local.json
npm run wallet:lock --prefix crypto -- --vault devnet/local/wallet/wallet-a.vault.local.json
npm run wallet:list --prefix crypto -- --vault devnet/local/wallet/wallet-a.vault.local.json --public
```

Export and verify public metadata:

```powershell
npm run wallet:export-metadata --prefix crypto -- --vault devnet/local/wallet/wallet-a.vault.local.json --out devnet/local/wallet/wallet-a-public-metadata.json
npm run wallet:verify-metadata --prefix crypto -- --metadata devnet/local/wallet/wallet-a-public-metadata.json --chain-id 31337
```

Sign and verify local actions:

```powershell
npm run wallet:sign-transfer --prefix crypto -- --vault devnet/local/wallet/wallet-a.vault.local.json --from <wallet-a-address> --to <wallet-b-address> --amount 125000 --nonce 1 --chain-id 31337
npm run wallet:sign-token-launch --prefix crypto -- --vault devnet/local/wallet/wallet-a.vault.local.json --owner <wallet-a-address> --symbol FLOWT --name "Flow Test Token" --supply 1000000 --nonce 2 --chain-id 31337
npm run wallet:sign-token-transfer --prefix crypto -- --vault devnet/local/wallet/wallet-a.vault.local.json --from <wallet-a-address> --to <wallet-b-address> --token-id <token-id> --amount 100 --nonce 3 --chain-id 31337
npm run wallet:sign-pool-create --prefix crypto -- --vault devnet/local/wallet/wallet-a.vault.local.json --owner <wallet-a-address> --base-asset-id <asset-a> --quote-asset-id <asset-b> --base-reserve 100000 --quote-reserve 250000 --nonce 4 --chain-id 31337
npm run wallet:sign-add-liquidity --prefix crypto -- --vault devnet/local/wallet/wallet-a.vault.local.json --owner <wallet-a-address> --pool-id <pool-id> --base-amount 100000 --quote-amount 250000 --min-liquidity-tokens 1 --deadline-block 35 --nonce 5 --chain-id 31337
npm run wallet:sign-remove-liquidity --prefix crypto -- --vault devnet/local/wallet/wallet-a.vault.local.json --owner <wallet-a-address> --pool-id <pool-id> --liquidity-tokens 1 --min-base-amount 1 --min-quote-amount 1 --deadline-block 45 --nonce 7 --chain-id 31337
npm run wallet:sign-swap --prefix crypto -- --vault devnet/local/wallet/wallet-a.vault.local.json --owner <wallet-a-address> --pool-id <pool-id> --input-token-id <asset-a> --output-token-id <asset-b> --input-amount 1000 --minimum-output 1 --deadline-block 40 --nonce 6 --chain-id 31337
npm run wallet:sign-withdrawal-intent --prefix crypto -- --vault devnet/local/wallet/wallet-a.vault.local.json --account <wallet-a-address> --base-address 0x4444444444444444444444444444444444444444 --amount 500000 --bridge-asset 0x3333333333333333333333333333333333333333 --credit-id <credit-id> --deposit-id <deposit-id> --nonce 8 --chain-id 31337
npm run wallet:verify --prefix crypto -- --envelope devnet/local/wallet/envelopes/<tx-id>.json --chain-id 31337 --expected-nonce 1
```

Submit or query the local control-plane intake:

```powershell
npm run wallet:submit --prefix crypto -- --envelope devnet/local/wallet/envelopes/<tx-id>.json
npm run wallet:query --prefix crypto -- --method mempool_list
```
