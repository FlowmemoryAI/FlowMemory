# Contracts Deployment Boundary

Status: V0 local, Base Sepolia, and capped Base public-network pilot boundary.

The current contracts are a compact event and commitment spine. They store intentional roots, receipt/report commitments, registry metadata hashes, counters, and status fields only. Heavy artifacts, AI memory, media, model data, verifier evidence, and receipt reconstruction data remain off-chain.

For the private/local FlowChain testnet package, these Solidity contracts are optional settlement/event anchors. They are not the private L1 runtime. The private/local runtime remains the Rust/local devnet and local services path; Solidity may mirror compact events or commitments for tests and canaries only when that boundary is explicit.

## Allowed Now

- Local Foundry tests.
- Local fixture generation and indexer/verifier/dashboard flows.
- Base Sepolia deployment dry runs and explicit broadcasts for the current V0 contracts.
- Base Sepolia planning for a Uniswap v4 `afterSwap`-only hook address,
  including CREATE2 salt mining for the exact hook flag target.
- Base Sepolia dry-run and explicit broadcast commands for the v4 hook proof,
  including a PoolManager swap through Uniswap's public testnet helper
  contracts, provided the operator records the live readback evidence.
- Non-secret Base Sepolia hook env checks that confirm local RPC, chain id,
  deployer key format, deployer address, and test ETH balance before broadcast.
- Non-secret Base Sepolia hook evidence checks that classify proof state and
  fail a strict live-proof gate until broadcast receipts and non-empty readback
  exist.
- Non-secret Base Sepolia hook readback range planning from explicit operator
  block numbers or successful broadcast receipt block numbers. Dry-run proof
  artifacts must not be accepted as live readback range evidence.
- Non-secret Base Sepolia hook acceptance package generation that fails until
  env readiness, live code, broadcast receipts, selected readback range,
  planned hook runtime-bytecode identity, successful receipts for the
  PoolManager initialize/liquidity/swap actions, range/readback artifact
  agreement, readback, Flow Memory outputs, FlowPulse observation integrity,
  successful `SWAP_MEMORY_SIGNAL` evidence, Flow Memory signal linkage to
  successful broadcast receipt transactions, and count agreement all pass.
- Base Sepolia reads from explicit RPC URLs.
- Guarded Base mainnet canary reads and source-verification dry runs for the documented V0 canary addresses only.
- Capped Base chain id `8453` bridge-pilot dry runs and explicit broadcasts for
  `BaseBridgeLockbox` and `FlowChainSettlementSpine` only, with local env
  acknowledgement, explicit owner/release authority, allowlisted assets, and
  nonzero configured total caps.
- Public docs that describe emitted events, roots, receipts, and off-chain verification paths.

## Not Allowed Yet

- Base mainnet deployment claims.
- Production-mainnet readiness claims.
- Production L1 claims.
- Claims that the Solidity contracts are the private/local FlowChain L1 runtime.
- Production Base settlement-anchor claims.
- Production bridge, production finality, or production challenge-resolution claims.
- Broad Base mainnet scans outside the documented canary reader guardrails.
- Token launch, rewards, slashing, or fee-market mechanics.
- Dynamic Uniswap v4 fee hooks.
- Uncapped or unreviewed custody of user tokens.
- Claims that contracts can know `txHash` or `logIndex` during execution.
- Claims that on-chain storage is free or that arbitrary AI data is stored on-chain.

## Settlement Anchor Boundary

Base anchoring is placeholder/research until separately approved. A future anchor must be scoped in its own issue or decision record with threat model, source/target chain assumptions, replay boundaries, event semantics, indexer/verifier responsibilities, and deployment review. The current V0 contracts do not implement a bridge, production settlement finality, token movement, or appchain/L1 launch path.

FlowPulse events intentionally omit `txHash` and `logIndex`; indexers derive those values after receipts and logs exist. URI fields are advisory caller-supplied log data unless a future contract explicitly validates format, length, resolvability, or content hash linkage.

No current Solidity contract exposes a challenge lifecycle or finality state machine. `VerifierReportRegistry.REORGED` is an advisory report status for off-chain reconciliation, not a bridge finality proof or challenge resolution path.

## Uniswap V4 Hook Path Boundary

The contract set now includes a production-shaped but not production-deployed
Uniswap v4 hook path:

- `FlowMemoryHookAdapter` remains the dependency-light fixture/canary adapter.
- `FlowMemoryAfterSwapHook` is the real-path hook candidate. Its v4-shaped
  `afterSwap` callback is restricted to the configured PoolManager, emits the
  same `SWAP_MEMORY_SIGNAL` FlowPulse semantics, returns zero hook delta, and
  exposes no token custody, dynamic fee, LP fee override, before-swap, pool
  creation, or liquidity-position path.
- `FlowMemoryHookPlanner` defines the exact permission target:
  `AFTER_SWAP_FLAG` only, `0x40` in the low hook bits. It rejects addresses with
  extra custom-accounting or dynamic-fee-adjacent flags such as
  `AFTER_SWAP_RETURNS_DELTA_FLAG`.
- Base Sepolia planning targets chain id `84532`, Uniswap v4 PoolManager
  `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408`, and the standard CREATE2
  deployer `0x4e59b44847b379578588920cA78FbF26c0B4956C`.

Before any Base Sepolia hook broadcast, the PR or issue must record the mined
salt, computed hook address, init code hash, constructor args, deployer, target
chain, PoolManager address, source verification plan, and post-deploy reader
range. A mined/testnet hook address is still not a production hook deployment
or a Base mainnet approval.

The current Base Sepolia hook proof runbook is
`docs/DEPLOYMENTS/BASE_SEPOLIA_V4_HOOK_PROOF.md`. It records the current mined
hook plan:

- hook address: `0xD24d7f807cb00D28DdF675E55879547d4F7B0040`;
- salt:
  `0x0000000000000000000000000000000000000000000000004915000000000000`;
- init code hash:
  `0x2734b4f6b4f6932249d4d98240147f02cf2ba548fe1ade4a7d63d9dd0a8b9fef`;
- active permission bits: afterSwap only, `0x0040`.

The proof runner derives `FLOWMEMORY_HOOK_PROOF_OPERATOR` from the same
testnet deployer key unless explicitly set to the same address. This prevents
the throwaway proof tokens from being minted to one address while approvals and
swaps are sent by another address.

## Private/Local FlowChain Mirror Map

The private/local FlowChain runtime owns object execution and final state. The Solidity spine may mirror or anchor only compact object references:

| Private/local object | Optional Solidity mirror |
| --- | --- |
| Agent/operator identity | `WorkerRegistry` metadata commitments |
| Verifier module identity | `VerifierRegistry` metadata commitments |
| WorkReceipt | `WorkReceiptRegistry` compact receipt commitments |
| VerifierReport | `VerifierReportRegistry` or `ReceiptVerifier` report commitments |
| ArtifactAvailabilityProof or model metadata pointer | `ArtifactRegistry` commitment and schema hashes |
| Indexer checkpoint | `CursorRegistry` cursor commitments |
| MemoryCell or Rootflow state update | `RootfieldRegistry` root commitments and FlowPulse events |
| Challenge or finality state | Not mirrored by Solidity V0; handled by the Rust/local devnet and local services |

These mirrors do not make Solidity the private L1 runtime and do not create production bridge, settlement, fee, token, or validator semantics.

## Local Hardening Commands

Run these from the repository root before review:

```powershell
forge test
npm run contracts:hardening
git diff --check
```

`npm run contracts:hardening` runs the local Foundry hardening baseline and Slither when it is installed. Slither can be made mandatory with:

```powershell
npm run contracts:hardening:slither
```

Formatting can be checked explicitly with:

```powershell
.\infra\scripts\contracts-static-analysis.ps1 -CheckFormat
```

## Deployment Inputs Required

Before a Base Sepolia deployment transaction is sent, the PR or issue must record:

- target chain: Base Sepolia, chain id `84532`
- exact contract names and constructor arguments
- deployer account address
- compiled bytecode hash or Foundry build commit
- expected event signatures
- post-deploy verification steps
- rollback or redeploy plan

Private keys must not be committed to the repo, copied into docs, or stored in generated artifacts.

## Current Commands

```powershell
npm run deploy:base-sepolia:plan -- --json
npm run deploy:base-sepolia
npm run deploy:base-sepolia:broadcast
npm run read:base-sepolia -- --rpc-url <base-sepolia-rpc-url> --address <flowpulse-contract> --from-block <n> --to-block <n>
npm run read:base-sepolia -- --rpc-url <base-sepolia-rpc-url> --address <flowpulse-contract> --resume-from-checkpoint --to-block <n>
npm run verify:base-canary:sources -- --json
npm run hook:base-sepolia:plan -- --json
npm run hook:base-sepolia:env-check -- --json
npm run hook:base-sepolia:evidence -- --json
npm run hook:base-sepolia:require-live-proof -- --json
npm run hook:base-sepolia:acceptance -- --json
npm run hook:base-sepolia:check -- --json
npm run hook:base-sepolia:swap-proof:dry-run -- --json
npm run hook:base-sepolia:readback-range -- --infer-readback-range --json
npm run hook:base-sepolia:readback:auto -- --json
npm run hook:base-sepolia:readback -- --rpc-url <base-sepolia-rpc-url> --from-block <deployBlock> --to-block <latestBlock> --finalized-block <safeFinalizedBlock> --json
npm run hook:base-sepolia:flowmemory
```

`deploy:base-sepolia:plan` requires no private key and writes a non-secret
rehearsal plan to `fixtures/deployments/base-sepolia-rehearsal-plan.json`.

`deploy:base-sepolia` requires `BASE_SEPOLIA_RPC_URL` and
`BASE_SEPOLIA_DEPLOYER_KEY_HEX` from the local shell or an untracked `.env`
loader. The example file is `.env.example`; real key material must stay
outside Git.

The detailed public testnet rehearsal runbook is
`docs/DEPLOYMENTS/BASE_SEPOLIA_REHEARSAL.md`.

The detailed v4 PoolManager hook proof runbook is
`docs/DEPLOYMENTS/BASE_SEPOLIA_V4_HOOK_PROOF.md`.
The env-check command writes
`fixtures/deployments/base-sepolia-v4-hook-env-check.latest.json` and must not
include private keys, RPC URLs, explorer API keys, raw signed transactions, seed
phrases, or webhook URLs.
The evidence command writes
`fixtures/deployments/base-sepolia-v4-hook-evidence.latest.json`. The strict
`require-live-proof` command is expected to fail until the mined hook address
has deployed code, the broadcast artifact has receipts, and readback has at
least one hook FlowPulse observation.
The readback command writes Base Sepolia hook proof state/checkpoint artifacts
under `fixtures/deployments/` and fails by default when the selected range has
zero hook FlowPulse observations.
The readback range command writes
`fixtures/deployments/base-sepolia-v4-hook-readback-range.latest.json`. With
`--infer-readback-range`, it derives `fromBlock`, `toBlock`, and
`finalizedBlock` from successful receipts in the broadcast swap-proof artifact
and refuses non-broadcast/dry-run artifacts.
The live-code check also records the expected compiled hook runtime hash and
the on-chain code hash for the mined hook address. Final acceptance requires
those hashes to match, so a random contract at the mined address is not enough.
The Flow Memory command writes
`fixtures/deployments/base-sepolia-v4-hook-flowmemory.latest.json`,
`fixtures/dashboard/flowmemory-dashboard-base-sepolia-v4-hook.json`, and
`apps/dashboard/public/data/flowmemory-dashboard-base-sepolia-v4-hook.json`.
It fails by default until the evidence artifact has `liveProofComplete: true`.
`npm run hook:base-sepolia:flowmemory -- --allow-incomplete` is allowed only
for diagnostics and must not be treated as acceptance evidence.
The final acceptance command writes
`fixtures/deployments/base-sepolia-v4-hook-acceptance.latest.json` and exits
nonzero until every source artifact agrees, including the selected readback
range artifact and the actual readback artifact's source and block window.
`npm run hook:base-sepolia:acceptance -- --allow-incomplete --json` is
diagnostic only.

`script/DeployBridgeSpine.s.sol` is a separate dry-run-by-default bridge-spine
script for local Anvil `31337`, Base Sepolia `84532`, and the capped Base
`8453` pilot. The `8453` path requires `FLOWCHAIN_BASE8453_PILOT_ACK=true` and
nonzero total caps for every configured asset. The script deploys the existing
lockbox and settlement spine only; it does not create a new bridge architecture
or broad public bridge approval.

`verify:base-canary:sources` reads `fixtures/deployments/base-canary-v0.json`
and prints a dry-run verification plan by default. It also writes the same
non-secret plan to
`fixtures/deployments/base-canary-source-verification-plan.json`. Actual
submission uses `npm run verify:base-canary:sources:submit` and requires
`BASESCAN_API_KEY`. This script does not need a private key.

## Current Contract Set

- `RootfieldRegistry`: Rootfield namespaces and root commitment pulses.
- `FlowMemoryHookAdapter`: dependency-light hook-adapter plus Uniswap v4-shaped afterSwap callback path, not a production Uniswap hook deployment.
- `FlowMemoryAfterSwapHook`: PoolManager-gated, afterSwap-only hook candidate
  for Base Sepolia planning; returns zero hook delta and has no custody or fee
  mechanics.
- `FlowMemoryHookPlanner`: pure hook flag, CREATE2 address, and Base Sepolia
  planning helper; it does not deploy contracts or store secrets.
- `ReceiptVerifier`: compact receipt-report commitments, not cryptographic receipt verification.
- `VerifierReportRegistry`: owner-authorized verifier report commitments.
- `WorkReceiptRegistry`: owner-authorized worker receipt commitments.
- `WorkerRegistry`: self-registration for worker identity metadata.
- `VerifierRegistry`: self-registration for verifier identity metadata.
- `ArtifactRegistry`: artifact commitment metadata.
- `CursorRegistry`: off-chain cursor commitment metadata.
- `WorkDebtScheduler`: work-state commitments without token debt.
- `BaseBridgeLockbox`: capped bridge-pilot lockbox with owner configuration,
  explicit release authority, pause, allowlisted assets, per-deposit caps,
  per-asset total caps, deposit replay guards, and release replay guards.
- `FlowChainSettlementSpine`: object commitment event spine for bridge,
  control-plane, memory, and finality object references.

## Post-Deploy Checks

- Verify source on the explorer when possible.
- Emit one small test event per deployed event source where safe.
- Run the Base Sepolia indexer reader over the deployment block range.
- Confirm persisted indexer state and checkpoint exist.
- Confirm dashboard fixtures can read the generated state.
- Update `docs/CURRENT_STATE.md` with what is deployed and what remains local-only.
