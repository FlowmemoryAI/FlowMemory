# FlowChain Base Bridge POC

Status: capped owner pilot path for mock/local validation and guarded Base chain ID `8453` testing.

This bridge lane is intentionally small and gated. It is not a public bridge, not a broad mainnet bridge, not audited, and not approved for unrestricted deposits.

## What Exists

- `contracts/bridge/BaseBridgeLockbox.sol`: non-upgradeable owner-controlled lockbox with native ETH and ERC20 custody paths, allowlist, per-deposit cap, cumulative total pilot cap, pause, emergency stop, deposit nonce accounting, release authority, and release replay protection.
- `tests/bridge/BaseBridgeLockbox.t.sol`: Foundry coverage for deposits, caps, pause, emergency stop, allowlist, wrong authority, release, replay, and zero-value failures.
- `services/bridge-relayer/src/observe-base-lockbox.ts`: fixture/RPC observer, deterministic evidence builder, local credit applier, withdrawal intent generator, and release evidence writer.
- `services/bridge-relayer/src/base8453-relay-monitor.ts`: low-latency Base `8453` relay with 12-confirmation eligibility, 5-second default polling, durable checkpoint, bounded recovery window, status/report output, and local FlowChain node intake.
- `services/bridge-relayer/src/base8453-tx-diagnostic.ts`: transaction hash diagnostic for receipt status, approved lockbox recipient, `lockNative(bytes32,bytes32)` selector `0x1326d1ec`, BridgeDeposit presence, direct ETH sends, reverts, wrong-contract calls, and cap failures.
- `services/bridge-relayer/src/bridge-pilot-e2e.ts`: no-RPC mock pilot E2E for observe, credit, replay, local usage handoff, withdrawal intent, and release evidence.
- `services/bridge-relayer/src/bridge-live-readiness-check.ts`: fail-closed live gate self-test.
- `infra/scripts/bridge-base8453-deploy.ps1`: dry-run and guarded broadcast deployment wrapper.
- `infra/scripts/bridge-base-mainnet-pilot-observe.ps1`: Base `8453` observation wrapper with chain, cap, confirmation, range, and acknowledgement gates.
- `infra/scripts/bridge-base8453-control.ps1`: pause, resume, and emergency stop wrapper.
- `infra/scripts/bridge-evidence-export.ps1`: secret-free bridge evidence bundle export.
- `fixtures/bridge/base8453-pilot-mock-deposit.json`: deterministic Base `8453` pilot deposit fixture.
- `schemas/flowmemory/bridge-*.schema.json`: bridge deposit, observation, credit, credit application, pilot evidence, withdrawal intent, withdrawal authorization, release evidence, local usage, and runtime handoff schemas.

## Asset Decision

The lockbox supports both native Base ETH and ERC20 assets. The owner pilot activates one configured asset:

- zero address in `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN` means native ETH
- nonzero address in `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN` means that ERC20

The relayer refuses tokens not configured by `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`.

## Architecture

```text
Base 8453 owner wallet
  -> BaseBridgeLockbox.lockNative or lockERC20
  -> BridgeDeposit event
  -> low-latency guarded bridge relay
  -> BridgeObservation with replay key
  -> BridgeCredit
  -> local exactly-once credit application state
  -> running FlowChain local node intake for newly applied credits
  -> local usage handoff and product gate
  -> withdrawal intent
  -> release evidence for operator review
```

Local credit evidence is JSON state and runtime handoff data until the private/local FlowChain runtime consumes bridge objects directly.

## Contract Event Schema

`BridgeDeposit` is the relayer-facing deposit event:

```solidity
event BridgeDeposit(
    bytes32 indexed depositId,
    uint256 indexed sourceChainId,
    address indexed sender,
    address lockbox,
    address token,
    uint256 amount,
    bytes32 flowchainRecipient,
    uint256 nonce,
    bytes32 metadataHash,
    bytes32 pilotModeTag
);
```

`depositId` includes:

```text
BRIDGE_DEPOSIT_SCHEMA_ID
block.chainid
lockbox address
sender
token
amount
flowchain recipient
nonce
metadata hash
pilot mode tag
```

Receipt-derived fields such as `txHash`, `logIndex`, block number, block hash, and confirmations are written by the relayer evidence path.

## Live Gates

Live observation requires:

- `eth_chainId == 0x2105`
- explicit operator acknowledgement
- configured lockbox address
- configured supported token
- configured confirmation depth
- bounded start and end block
- safe block range width
- durable checkpoint and bounded recovery window for relay mode
- per-deposit cap
- total pilot cap
- nonzero local recipient

The readiness self-test proves missing env, missing acknowledgement, wrong chain, unapproved lockbox, unsupported token, missing confirmations, and broad block scan fail closed.

## Required Env Names

- `FLOWCHAIN_BASE8453_RPC_URL`
- `FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY`
- `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`
- `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`
- `FLOWCHAIN_BASE8453_FROM_BLOCK`
- `FLOWCHAIN_BASE8453_TO_BLOCK`
- `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`
- `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`
- `FLOWCHAIN_PILOT_CONFIRMATIONS`
- `FLOWCHAIN_PILOT_OPERATOR_ACK`

Required acknowledgement value:

```text
I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT
```

## Commands

```powershell
forge test
npm test --prefix services/bridge-relayer
npm run bridge:local-credit:smoke
npm run bridge:pilot:mock:e2e
npm run flowchain:bridge:mock:e2e
npm run bridge:pilot:live:check
npm run flowchain:bridge:live:check
npm run flowchain:real-value-pilot:e2e
npm run flowchain:no-secret:scan
git diff --check
```

Pilot command aliases:

```powershell
npm run bridge:deploy:dry-run
npm run bridge:deploy:base8453 -- -AcknowledgeBroadcast
npm run bridge:observe:base8453
npm run bridge:relay:base8453
npm run bridge:tx:diagnose -- --tx-hash <base-tx-hash> --acknowledge-pilot
npm run bridge:credit:local
npm run bridge:credit:replay-check
npm run bridge:withdraw:intent
npm run bridge:release:evidence
npm run bridge:pause -- -Execute
npm run bridge:resume -- -Execute
npm run bridge:emergency-stop -- -Execute
npm run bridge:evidence:export
```

## Proof Artifacts

- `docs/agent-runs/production-l1-bridge/CONTRACT_PROOF.md`
- `docs/agent-runs/production-l1-bridge/RELAYER_PROOF.md`
- `docs/agent-runs/production-l1-bridge/MOCK_PILOT_E2E_PROOF.md`
- `docs/agent-runs/production-l1-bridge/REPLAY_PROOF.md`
- `docs/agent-runs/production-l1-bridge/LIVE_READINESS_PROOF.md`
- `docs/agent-runs/production-l1-bridge/REAL_FUNDS_PILOT_RUNBOOK.md`
- `docs/agent-runs/production-l1-bridge/HANDOFF.md`

## Boundary

This path is for a capped owner pilot. It does not remove the need for independent review, conservative caps, operator controls, and owner-provided live credentials.
