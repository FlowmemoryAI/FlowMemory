# Real-Value Pilot Wallet Operator

Status: local operator support for a capped real-value pilot. Not production custody.

## Boundary

The pilot wallet path is command-line only. Private keys stay in the local
encrypted test vault and are never handled by browser code. Public metadata
exports include signer ids, signer key ids, public keys, chain id, contract
address, and pilot cap data only.

Do not commit:

- local vault files;
- `.env` files;
- private keys, seed phrases, or mnemonics;
- RPC credentials, API keys, or webhook URLs;
- generated pilot envelopes that contain operational data not intended for the
  PR.

The config records public operator and cap policy. Runtime network access stays
in the local shell environment.

## Required Environment

```powershell
$env:FLOWCHAIN_PILOT_CHAIN_ID="84532"
$env:FLOWCHAIN_PILOT_CONTRACT_ADDRESS="<lockbox-or-pilot-contract>"
$env:FLOWCHAIN_PILOT_OPERATOR_ID="<operator-signer-id>"
$env:FLOWCHAIN_PILOT_CAP_ID="<bytes32-cap-id>"
$env:FLOWCHAIN_PILOT_CAP_ASSET_ID="<bytes32-asset-id>"
$env:FLOWCHAIN_PILOT_CAP_MAX_AMOUNT="25000000"
$env:FLOWCHAIN_PILOT_CAP_UNIT="USDC-6"
$env:FLOWCHAIN_PILOT_CAP_WINDOW_START_UNIX_MS="<start-ms>"
$env:FLOWCHAIN_PILOT_CAP_WINDOW_END_UNIX_MS="<end-ms>"
```

Set network access only in the local shell when observing bridge events:

```powershell
$env:FLOWCHAIN_PILOT_RPC_URL="<local-shell-only-endpoint>"
```

For capped Base mainnet canary reads, also set:

```powershell
$env:FLOWCHAIN_PILOT_REAL_FUNDS_ACK="I_ACCEPT_CAPPED_REAL_VALUE_PILOT"
```

## Commands

Create the non-secret local operator config:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-wallet-pilot-config.ps1
```

Create and use a local encrypted vault from `crypto/`:

```powershell
$env:FLOWMEMORY_TEST_WALLET_PASSWORD="<local-password>"
npm run wallet:create --prefix crypto -- --vault devnet/local/pilot-wallet/operator-vault.json --role operator --label real-value-pilot-operator
npm run wallet:pilot-metadata --prefix crypto -- --config devnet/local/pilot-wallet/operator-config.local.json --vault devnet/local/pilot-wallet/operator-vault.json --out devnet/local/pilot-wallet/operator-public-metadata.json
```

Print the exact deploy, observe, credit, release, and verify command sequence:

```powershell
npm run wallet:pilot-next --prefix crypto -- --config devnet/local/pilot-wallet/operator-config.local.json
```

Run the deterministic pilot wallet/operator E2E:

```powershell
npm run wallet:pilot-e2e --prefix crypto
```

## Validation

Runtime and control-plane consumers that only need public verification should
import `@flowmemory/crypto/pilot-envelope-validation`. That subpath validates
pilot envelopes and does not import vault creation, unlock, or signing helpers.

Pilot verification rejects wrong chain id, wrong contract address, wrong
operator, mutated payloads, replayed nonces, expired messages, and missing cap
fields.
