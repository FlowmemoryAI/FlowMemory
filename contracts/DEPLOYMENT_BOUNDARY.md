# Contracts Deployment Boundary

Status: V0 local and Base Sepolia readiness boundary.

The current contracts are a compact event and commitment spine. They store intentional roots, receipt/report commitments, registry metadata hashes, counters, and status fields only. Heavy artifacts, AI memory, media, model data, verifier evidence, and receipt reconstruction data remain off-chain.

For the private/local FlowChain testnet package, these Solidity contracts are optional settlement/event anchors. They are not the private L1 runtime. The private/local runtime remains the Rust/local devnet and local services path; Solidity may mirror compact events or commitments for tests and canaries only when that boundary is explicit.

## Allowed Now

- Local Foundry tests.
- Local fixture generation and indexer/verifier/dashboard flows.
- Base Sepolia deployment dry runs and explicit broadcasts for the current V0 contracts.
- Base Sepolia planning for a Uniswap v4 `afterSwap`-only hook address,
  including CREATE2 salt mining for the exact hook flag target.
- Base Sepolia reads from explicit RPC URLs.
- Guarded Base mainnet canary reads and source-verification dry runs for the documented V0 canary addresses only.
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
- Custody of user tokens.
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
  `0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3`, and the standard CREATE2
  deployer `0x4e59b44847b379578588920cA78FbF26c0B4956C`.

Before any Base Sepolia hook broadcast, the PR or issue must record the mined
salt, computed hook address, init code hash, constructor args, deployer, target
chain, PoolManager address, source verification plan, and post-deploy reader
range. A mined/testnet hook address is still not a production hook deployment
or a Base mainnet approval.

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
```

`deploy:base-sepolia:plan` requires no private key and writes a non-secret
rehearsal plan to `fixtures/deployments/base-sepolia-rehearsal-plan.json`.

`deploy:base-sepolia` requires `BASE_SEPOLIA_RPC_URL` and
`BASE_SEPOLIA_DEPLOYER_KEY_HEX` from the local shell or an untracked `.env`
loader. The example file is `.env.example`; real key material must stay
outside Git.

The detailed public testnet rehearsal runbook is
`docs/DEPLOYMENTS/BASE_SEPOLIA_REHEARSAL.md`.

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

## Post-Deploy Checks

- Verify source on the explorer when possible.
- Emit one small test event per deployed event source where safe.
- Run the Base Sepolia indexer reader over the deployment block range.
- Confirm persisted indexer state and checkpoint exist.
- Confirm dashboard fixtures can read the generated state.
- Update `docs/CURRENT_STATE.md` with what is deployed and what remains local-only.
