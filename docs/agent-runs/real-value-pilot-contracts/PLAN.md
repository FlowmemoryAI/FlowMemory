# Real-Value Pilot Contracts Plan

Status: implemented on branch `agent/real-value-pilot-contracts-proof`;
pending PR for issue #133.

Worktree: `E:\FlowMemory\flowmemory-live-wallet`
Branch: `agent/real-value-pilot-contracts-proof`

## Scope

Build the contract side of the capped Base public-network pilot bridge without
creating a parallel bridge architecture. Reuse the existing `BaseBridgeLockbox`,
`FlowChainSettlementSpine`, tests, and deployment script.

Allowed edit folders:

- `contracts/`
- `tests/`
- `script/`
- `infra/scripts/flowchain-real-value-pilot-contracts-e2e.ps1`
- `package.json`
- `docs/bridge/`
- `docs/agent-runs/real-value-pilot-contracts/`

Forbidden edit folders:

- `crates/`
- `services/`
- `apps/dashboard/`
- `crypto/`
- `hardware/`

## Inspection Notes

- This integration branch starts from current `main` after PR #145.
- Existing lockbox already has token allowlisting, per-deposit caps, per-asset
  total caps, pause, release authority, deposit records, deposit replay IDs,
  release replay IDs, and relayer-facing events.
- `E:\FlowMemory\flowmemory-contracts` adds useful settlement object constants,
  extra release tests, deployment chain gating, and docs for authority/emergency
  assumptions.
- `E:\FlowMemory\flowmemory-bridge-full` expects the existing
  `BridgeDeposit(bytes32,uint256,address,address,uint256,bytes32,uint256,bytes32)`
  event shape. The relayer derives replay keys and observation IDs from
  `sourceChainId`, lockbox address, receipt `txHash`, `logIndex`, and
  `depositId`; contracts must not emit or assume receipt locator fields.

## Implementation Plan

1. Keep the existing bridge architecture and event ABI unchanged.
2. Port the settlement object vocabulary from the long-loop contracts work.
3. Tighten deployment gating in `DeployBridgeSpine` for local Anvil, Base
   Sepolia, and the capped Base `8453` pilot.
4. Require explicit Base `8453` pilot acknowledgement and nonzero total caps for
   any Base `8453` configured asset.
5. Add tests for the added object vocabulary, partial release/replay behavior,
   and zero release parameters.
6. Update bridge/contract docs with owner, release authority, caps, pause,
   replay, emergency assumptions, deployed-address handling, and verification
   instructions.
7. Add the root `flowchain:real-value-pilot:contracts` proof wrapper.
8. Run focused tests, contract hardening, local Anvil dry run, Base `8453`
   missing-ack rejection, Base `8453` acknowledged dry run,
   `npm run flowchain:product-e2e`, and `git diff --check`.

## Deployed-Address Handling Design

Deployment addresses must be treated as local operator state until a reviewed
pilot record is intentionally published. The deployment script emits a
non-secret deployment event, and Foundry broadcast artifacts stay local. The
operator should store the selected lockbox and settlement-spine addresses in a
local ignored env file or shell variables such as
`FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`; public docs should describe how to load
that address, not hardcode it as a blanket endorsement.
