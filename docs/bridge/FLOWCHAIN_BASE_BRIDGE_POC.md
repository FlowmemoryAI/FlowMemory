# FlowChain Base Bridge POC

Status: test-only bridge lane for local and Base Sepolia validation.

This bridge POC is designed so a small canary can be reviewed later without
claiming production bridge readiness. It is not audited, not trustless, not a
public bridge, and not approved for broad mainnet use.

## What Exists

- `contracts/bridge/BaseBridgeLockbox.sol`: non-upgradeable lockbox with owner,
  explicit test release authority, pause, allowlisted tokens, per-deposit caps,
  total caps, deposit records, replay guards, deposit events, and release hooks.
- `contracts/FlowChainSettlementSpine.sol`: compact local/test event spine for
  bridge and FlowChain object commitments.
- `tests/bridge/BaseBridgeLockbox.t.sol`: Foundry coverage for token
  allowlisting, ERC-20 deposits, native deposits, caps, pause behavior,
  ownership, release, and replay protection.
- `tests/FlowChainSettlementSpine.t.sol`: Foundry coverage for authorized object
  commitments and stable settlement event shape.
- `services/bridge-relayer/`: fixture-first and RPC-range observer that
  converts explicit bridge deposit records into FlowChain bridge observation,
  credit, withdrawal-intent, and runtime handoff JSON.
- `fixtures/bridge/base-sepolia-mock-deposit.json`: deterministic test deposit.
- `fixtures/bridge/local-runtime-bridge-handoff.json`: deterministic local
  bridge handoff consumed by the runtime/control-plane until direct intake is
  enabled.
- `schemas/flowmemory/bridge-*.schema.json`: bridge deposit, observation,
  credit, withdrawal-intent, and runtime handoff contracts.
- `infra/scripts/bridge-base-sepolia-observe.ps1`: env-friendly Base Sepolia
  observation wrapper that requires no private key.
- `infra/scripts/bridge-base-sepolia-smoke.ps1`: guarded Base Sepolia smoke.
- `infra/scripts/bridge-local-anvil-observe.ps1`: local Anvil observation
  wrapper for chain id `31337`.
- `infra/scripts/bridge-base-mainnet-canary-read.ps1`: disabled-by-default
  Base mainnet canary read wrapper.

## Architecture

```text
Base Sepolia user/test wallet
  -> BaseBridgeLockbox.lockERC20 or lockNative
  -> BridgeDeposit event and DepositRecord state
  -> bridge-relayer explicit reader/mock observer
  -> BridgeObservation with replay key
  -> BridgeCredit pending/applied local object
  -> optional FlowChainSettlementSpine.commitObject bridge-deposit commitment
  -> local runtime/control-plane/workbench handoff
```

The POC does not mint production assets on FlowChain. Local acceptance is a
fixture/control-plane event until the private/local runtime explicitly consumes
bridge deposit objects.

The handoff includes a workbench-ready timeline:

```text
deposit observed -> credit pending -> credit applied -> withdrawal requested
```

Until live bridge intake is enabled, `fixtures/bridge/local-runtime-bridge-handoff.json`
is the exact file for the runtime/control-plane to consume.

## Risk Model

- Base mainnet uses real funds. Mainnet canary reads require
  `--acknowledge-real-funds` and `--max-usd 25` or lower.
- The lockbox owner can configure tokens, caps, pause state, and the explicit
  release authority. Only the release authority can call release hooks. That is
  a test operator model, not a decentralized bridge model.
- The relayer reads explicit chains, contracts, and block ranges. It must not
  broad-scan Base mainnet.
- No secrets, RPC keys, private keys, or seed phrases should be committed.
- Bridge observations are advisory local objects until the FlowChain runtime
  verifies and accepts them.

## Local Mock

```powershell
npm install
npm run bridge:mock
npm run bridge:test
npm run bridge:local-credit:smoke
npm run flowchain:real-value-pilot:bridge
```

Expected output:

```text
services/bridge-relayer/out/bridge-observation.json
services/bridge-relayer/out/bridge-credit.json
services/bridge-relayer/out/bridge-runtime-handoff.json
fixtures/bridge/local-runtime-bridge-handoff.json
```

The real-value pilot mock E2E uses Base chain ID `8453` fixture data without
external RPC and writes:

```text
services/bridge-relayer/out/real-value-pilot-e2e/bridge-observation.json
services/bridge-relayer/out/real-value-pilot-e2e/bridge-credit.json
services/bridge-relayer/out/real-value-pilot-e2e/bridge-pilot-evidence.json
services/bridge-relayer/out/real-value-pilot-e2e/bridge-release-evidence.json
services/bridge-relayer/out/real-value-pilot-e2e/bridge-runtime-handoff.json
services/bridge-relayer/out/real-value-pilot-e2e/bridge-replay-handoff.json
services/bridge-relayer/out/real-value-pilot-e2e/bridge-credit-application-state.json
```

It proves deterministic IDs, wrong-chain rejection, unapproved-lockbox rejection,
duplicate replay evidence, exactly-once local credit application, and
test-record-only withdrawal/release evidence.

## Base Sepolia Smoke

Deploy the lockbox with Foundry or a deployment script, then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/bridge-base-sepolia-smoke.ps1 `
  -RpcUrl <base-sepolia-rpc-url> `
  -LockboxAddress <deployed-lockbox> `
  -FromBlock <from> `
  -ToBlock <to>
```

The script checks Base Sepolia chain id `84532`, requires an explicit lockbox,
requires an explicit block range, and writes local observation output.

The root package also exposes an env-var smoke path that does not require a
private key:

```powershell
$env:BASE_SEPOLIA_RPC_URL="<base-sepolia-rpc-url>"
$env:BASE_BRIDGE_LOCKBOX_ADDRESS="<deployed-lockbox>"
$env:BASE_BRIDGE_FROM_BLOCK="<from>"
$env:BASE_BRIDGE_TO_BLOCK="<to>"
npm run bridge:sepolia:observe
```

This command reads only `BridgeDeposit` logs from the explicit lockbox and
range, then writes observation, credit, and handoff JSON under
`services/bridge-relayer/out/`.

## Local Anvil Observation

Local Anvil is supported as a mock Base event lane with chain id `31337`.
Deploy `BaseBridgeLockbox`, emit one or more deposits, then run:

```powershell
$env:ANVIL_BRIDGE_LOCKBOX_ADDRESS="<deployed-lockbox>"
$env:ANVIL_BRIDGE_FROM_BLOCK="<from>"
$env:ANVIL_BRIDGE_TO_BLOCK="<to>"
npm run bridge:anvil:observe
```

Use `-RpcUrl` or `ANVIL_RPC_URL` if the Anvil endpoint is not
`http://127.0.0.1:8545`.

## Foundry Deploy Script

The contract-side bridge spine has a dry-run-by-default Foundry script:

```powershell
$env:FLOWCHAIN_BRIDGE_OWNER = "0x..."
$env:FLOWCHAIN_BRIDGE_RELEASE_AUTHORITY = "0x..."
$env:FLOWCHAIN_SETTLEMENT_SUBMITTER = "0x..."
$env:FLOWCHAIN_BRIDGE_ALLOW_NATIVE = "true"
$env:FLOWCHAIN_BRIDGE_NATIVE_PER_DEPOSIT_CAP = "100000000000000000"
$env:FLOWCHAIN_BRIDGE_NATIVE_TOTAL_CAP = "1000000000000000000"
$env:FLOWCHAIN_BRIDGE_ALLOW_ERC20 = "false"
$env:FLOWCHAIN_BRIDGE_ERC20_TOKEN = "0x0000000000000000000000000000000000000000"
$env:FLOWCHAIN_BRIDGE_ERC20_PER_DEPOSIT_CAP = "0"
$env:FLOWCHAIN_BRIDGE_ERC20_TOTAL_CAP = "0"

forge script script/DeployBridgeSpine.s.sol:DeployBridgeSpine `
  --rpc-url http://127.0.0.1:8545
```

For Base Sepolia dry-run, use `--rpc-url $env:BASE_SEPOLIA_RPC_URL`. Add
`--broadcast` only after the environment values are explicit and the owner key
is intentionally supplied to Foundry. Do not commit RPC URLs or private keys.

## Contract Event Schema

`BridgeDeposit` is the relayer-facing deposit event:

```solidity
event BridgeDeposit(
    bytes32 indexed depositId,
    uint256 indexed sourceChainId,
    address indexed sender,
    address token,
    uint256 amount,
    bytes32 flowchainRecipient,
    uint256 nonce,
    bytes32 metadataHash
);
```

`depositId` is:

```text
keccak256(abi.encode(
  BRIDGE_DEPOSIT_SCHEMA_ID,
  block.chainid,
  lockboxAddress,
  sender,
  token,
  amount,
  flowchainRecipient,
  nonce,
  metadataHash
))
```

`BridgeRelease` is a test-only release event:

```solidity
event BridgeRelease(
    bytes32 indexed releaseId,
    bytes32 indexed depositId,
    address indexed recipient,
    address token,
    uint256 amount,
    bytes32 evidenceHash
);
```

Release hooks require the configured release authority, a recorded deposit,
matching token, nonzero evidence hash, and available unreleased deposit amount.
They do not mint anything and do not prove FlowChain finality.

`FlowChainSettlementSpine` can record the local/private runtime's accepted
object commitments without implementing the runtime in Solidity:

```solidity
event FlowChainObjectCommitted(
    bytes32 indexed objectId,
    bytes32 indexed rootfieldId,
    bytes32 indexed objectType,
    address submitter,
    bytes32 commitment,
    bytes32 parentObjectId,
    uint64 sequence,
    uint64 committedAt,
    string evidenceURI
);
```

Bridge agents should use `BRIDGE_DEPOSIT_OBJECT` as `objectType` when committing
a FlowChain bridge-deposit object derived from a `BridgeDeposit`. Indexers still
derive `txHash`, `logIndex`, and block metadata from receipts and logs; those
fields are not emitted by the contracts.

## Base Mainnet Canary Read

Only after review, and only for a tiny capped canary:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/bridge-base-mainnet-canary-read.ps1 `
  -RpcUrl <base-mainnet-rpc-url> `
  -LockboxAddress <deployed-lockbox> `
  -FromBlock <from> `
  -ToBlock <to> `
  -AcknowledgeRealFunds `
  -MaxUsd 20
```

The script checks Base mainnet chain id `8453` and refuses a canary above
`25` USD. It is read-only and prints the chain, lockbox, block range, max USD
guardrail, and broadcast status before it reads logs.

## Base 8453 Pilot Observer

The pilot observer is distinct from the read-only canary path. It is for a tiny
capped owner-operated pilot only and still does not broadcast releases.

Required environment variables:

```text
FLOWCHAIN_BASE8453_RPC_URL
FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS
FLOWCHAIN_BASE8453_APPROVED_LOCKBOX_ADDRESS
FLOWCHAIN_BASE8453_FROM_BLOCK
FLOWCHAIN_BASE8453_TO_BLOCK
FLOWCHAIN_BASE8453_CONFIRMATIONS
FLOWCHAIN_PILOT_MAX_USD
FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI
FLOWCHAIN_PILOT_TOTAL_CAP_WEI
FLOWCHAIN_PILOT_OPERATOR_ACK=I_UNDERSTAND_THIS_IS_A_TINY_CAPPED_BASE8453_PILOT
```

Mock mode, no external RPC:

```powershell
npm run flowchain:real-value-pilot:bridge
```

Live observer mode:

```powershell
npm run bridge:base8453:pilot:observe -- -OperatorAck -ApplyCredit -WithdrawalIntent
```

Equivalent direct command:

```powershell
npm run bridge:observe -- `
  --mode base-mainnet-pilot `
  --rpc-url $env:FLOWCHAIN_BASE8453_RPC_URL `
  --lockbox-address $env:FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS `
  --approved-lockbox $env:FLOWCHAIN_BASE8453_APPROVED_LOCKBOX_ADDRESS `
  --from-block $env:FLOWCHAIN_BASE8453_FROM_BLOCK `
  --to-block $env:FLOWCHAIN_BASE8453_TO_BLOCK `
  --confirmations $env:FLOWCHAIN_BASE8453_CONFIRMATIONS `
  --acknowledge-pilot `
  --acknowledge-real-funds `
  --max-usd $env:FLOWCHAIN_PILOT_MAX_USD `
  --max-deposit-amount $env:FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI `
  --total-cap-amount $env:FLOWCHAIN_PILOT_TOTAL_CAP_WEI `
  --apply-credit `
  --withdrawal-intent `
  --runtime-state services/bridge-relayer/out/base8453-pilot-credit-application-state.json `
  --out services/bridge-relayer/out/base8453-pilot-bridge-observation.json `
  --credit-out services/bridge-relayer/out/base8453-pilot-bridge-credit.json `
  --handoff-out services/bridge-relayer/out/base8453-pilot-bridge-handoff.json `
  --evidence-out services/bridge-relayer/out/base8453-pilot-evidence.json `
  --withdrawal-out services/bridge-relayer/out/base8453-pilot-withdrawal-intent.json `
  --release-evidence-out services/bridge-relayer/out/base8453-pilot-release-evidence.json
```

Failure, retry, and replay behavior:

- Wrong `eth_chainId` fails before `eth_getLogs`; Base must return `0x2105`.
- Unapproved lockbox addresses fail before log reads.
- If `toBlock` is newer than `latestBlock - confirmations`, the observer fails
  with an insufficient-confirmations error; retry after more blocks or lower the
  explicitly configured confirmation depth.
- Duplicate logs in one batch produce one applied credit and one rejected credit
  with `duplicate_replay_key` evidence.
- Re-running the same deposit with the same runtime application state is
  idempotent: the credit is rejected with `already_applied_replay_key` and no
  second local application is recorded.
- Withdrawal/release evidence is written as a local operator record only. The
  relayer does not sign or broadcast `releaseERC20` or `releaseNative`.
- RPC URLs, keys, seed phrases, mnemonics, API keys, and webhooks must stay in
  local environment/config only and are not written to artifacts.

## Commands

```powershell
forge test --match-path tests/bridge/BaseBridgeLockbox.t.sol
forge test --match-path tests/FlowChainSettlementSpine.t.sol
npm run bridge:test
npm run bridge:mock
npm run bridge:sepolia:observe
npm run bridge:local-credit:smoke
npm run flowchain:real-value-pilot:bridge
npm run flowchain:full-smoke
git diff --check
```

## Not Production

This POC is not a production bridge, not a bridge launch, not audited, not a
tokenomics system, and not a public user deposit system. It exists so the
private/local FlowChain package can test a Base-origin deposit signal safely.
