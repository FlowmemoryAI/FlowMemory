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

The operator live-readiness surface uses the Base `8453` env names below. The
API and dashboard show names and configured booleans only; they must not show
values.

```powershell
$env:FLOWCHAIN_PILOT_OPERATOR_ACK="I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
$env:FLOWCHAIN_BASE8453_RPC_URL="<local-shell-only-endpoint>"
$env:FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS="<owner-verified-lockbox>"
$env:FLOWCHAIN_BASE8453_FROM_BLOCK="<start-block>"
$env:FLOWCHAIN_BASE8453_CURSOR_STATE="services/bridge-relayer/out/base8453-pilot-cursor-state.json"
$env:FLOWCHAIN_BASE8453_CONFIRMATION_DEPTH="<tiny-pilot-depth>"
$env:FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI="<tiny-cap>"
$env:FLOWCHAIN_PILOT_TOTAL_CAP_WEI="<tiny-total-cap>"
```

Use `FLOWCHAIN_BASE8453_TO_BLOCK` only as an optional upper bound for a one-off
scan. The pilot relayer loop advances from the cursor state after confirmed
reads.

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

Run the local operator UI/API surfaces:

```powershell
npm run flowchain:start
npm run control-plane:serve
npm run workbench:dev
```

Before any real Base funds are sent, inspect:

```text
http://127.0.0.1:8787/chain/status
http://127.0.0.1:8787/bridge/live-readiness
http://127.0.0.1:8787/pilot/lifecycle
http://127.0.0.1:8787/wallets/balances
http://127.0.0.1:8787/wallets/transfers
```

The live pilot remains blocked until `/bridge/live-readiness` returns
`READY_FOR_OPERATOR_LIVE_PILOT`, `envValuesPrinted: false`, no missing required
env names, and an owner-verified lockbox address. After a deposit is observed,
use `/pilot/lifecycle` and the dashboard `Real-Value Pilot` table to confirm
exact equality across deposit, observed, credited, wallet delta, transferable,
withdrawal, and release amounts. Use `/wallets/balances` and
`/wallets/transfers` to confirm the credited wallet can transfer the exact
credited amount and balances update exactly.

## Validation

Runtime and control-plane consumers that only need public verification should
import `@flowmemory/crypto/pilot-envelope-validation`. That subpath validates
pilot envelopes and does not import vault creation, unlock, or signing helpers.

Pilot verification rejects wrong chain id, wrong contract address, wrong
operator, mutated payloads, replayed nonces, expired messages, and missing cap
fields.
