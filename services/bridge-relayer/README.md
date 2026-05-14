# FlowChain Bridge Relayer POC

Status: fixture-first bridge observer for local/Base Sepolia testing.

This package converts explicit `BaseBridgeLockbox` deposit records into
FlowChain bridge observation JSON. It does not custody funds, sign releases, run
a production relayer, or prove finality.

Local mock:

```powershell
npm run bridge:mock
```

Mock real-value pilot E2E, with no external RPC:

```powershell
npm run flowchain:real-value-pilot:bridge
```

The mock pilot E2E writes deterministic observation, credit, pilot evidence,
withdrawal intent, release evidence, runtime handoff, replay handoff, and
exactly-once application-state files under
`services/bridge-relayer/out/real-value-pilot-e2e/`.

Base public-network pilot observation:

```powershell
$env:FLOWCHAIN_BASE8453_RPC_URL="<base-8453-rpc-url>"
$env:FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS="<approved-lockbox>"
$env:FLOWCHAIN_BASE8453_APPROVED_LOCKBOX_ADDRESS="<approved-lockbox>"
$env:FLOWCHAIN_BASE8453_FROM_BLOCK="<from>"
$env:FLOWCHAIN_BASE8453_TO_BLOCK="<to>"
$env:FLOWCHAIN_BASE8453_CONFIRMATIONS="2"
$env:FLOWCHAIN_PILOT_MAX_USD="1"
$env:FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI="<tiny-cap>"
$env:FLOWCHAIN_PILOT_TOTAL_CAP_WEI="<tiny-total-cap>"
$env:FLOWCHAIN_PILOT_OPERATOR_ACK="I_UNDERSTAND_THIS_IS_A_TINY_CAPPED_BASE8453_PILOT"
npm run bridge:base8453:pilot:observe -- -OperatorAck -ApplyCredit -WithdrawalIntent
```

The observer verifies `eth_chainId == 0x2105`, rejects unapproved lockboxes,
enforces confirmation depth before `eth_getLogs`, and never prints or writes the
RPC URL. Re-running the same observed event is idempotent: the existing local
application is cited and the replay credit is rejected with evidence instead of
applying a second local credit.

The control plane can read `services/bridge-relayer/out/bridge-observation.json`
and can intake additional local bridge-agent observations through JSON-RPC
`bridge_observation_submit` or HTTP `POST /bridge/observations`. Readbacks are
available through `bridge_observation_list`, `bridge_deposit_list`,
`bridge_credit_list`, and `withdrawal_list`.

Base Sepolia guarded smoke:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/bridge-base-sepolia-smoke.ps1 `
  -RpcUrl <base-sepolia-rpc-url> `
  -LockboxAddress <deployed-lockbox> `
  -FromBlock <from> `
  -ToBlock <to>
```

Base mainnet canary reads are disabled unless the operator explicitly passes
the real-funds acknowledgement and keeps the requested cap at or below 25 USD.
The separate Base `8453` pilot mode also requires an approved lockbox list,
operator acknowledgement, configured confirmation depth, and tiny amount caps.

No private key, seed phrase, RPC credential, or API key belongs in this package
or in committed fixtures.
