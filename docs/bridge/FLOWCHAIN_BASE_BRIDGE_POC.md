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
- `services/bridge-relayer/`: fixture-first observer that converts explicit
  bridge deposit records into FlowChain bridge observation JSON.
- `fixtures/bridge/base-sepolia-mock-deposit.json`: deterministic test deposit.
- `schemas/flowmemory/bridge-deposit.schema.json` and
  `schemas/flowmemory/bridge-observation.schema.json`: bridge object contracts.
- `infra/scripts/bridge-base-sepolia-smoke.ps1`: guarded Base Sepolia smoke.
- `infra/scripts/bridge-base-mainnet-canary-read.ps1`: disabled-by-default
  Base mainnet canary read wrapper.

## Architecture

```text
Base Sepolia user/test wallet
  -> BaseBridgeLockbox.lockERC20 or lockNative
  -> BridgeDeposit event and DepositRecord state
  -> bridge-relayer explicit reader/mock observer
  -> optional FlowChainSettlementSpine.commitObject bridge-deposit commitment
  -> FlowChain bridge deposit observation fixture
  -> local control plane / workbench / devnet handoff
```

The POC does not mint production assets on FlowChain. Local acceptance is a
fixture/control-plane event until the private/local runtime explicitly consumes
bridge deposit objects.

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
```

Expected output:

```text
services/bridge-relayer/out/bridge-observation.json
```

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
requires an explicit block range, and writes a local observation output.

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

`releaseId` is:

```text
keccak256(abi.encode(
  BRIDGE_RELEASE_SCHEMA_ID,
  block.chainid,
  lockboxAddress,
  depositId,
  recipient,
  token,
  amount,
  evidenceHash
))
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
`25` USD.

## Commands

```powershell
forge test --match-path tests/bridge/BaseBridgeLockbox.t.sol
forge test --match-path tests/FlowChainSettlementSpine.t.sol
npm run bridge:test
npm run bridge:mock
git diff --check
```

## Not Production

This POC is not a production bridge, not a bridge launch, not audited, not a
tokenomics system, and not a public user deposit system. It exists so the
private/local FlowChain package can test a Base-origin deposit signal safely.
