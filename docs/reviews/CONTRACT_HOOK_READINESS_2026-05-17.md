# Contract And Hook Readiness Review - 2026-05-17

Status: V0 contract and hook hardening pass complete.

## What Was Checked

- FlowMemory Uniswap v4 afterSwap hook shape.
- Base Sepolia PoolManager constant.
- afterSwap-only hook permission flags.
- PoolManager caller gating.
- event schema boundary excluding `txHash` and `logIndex`.
- bridge lockbox access control and release hardening.
- Foundry tests, format gate, and Slither required audit gate.
- Base Sepolia v4 hook proof tooling, live-code check, hook address mining,
  and full PoolManager swap-proof dry run.

## Changes Made

- Added a canonical ABI selector test for the Uniswap v4 `afterSwap` callback.
- Added a regression test pinning the current Base Sepolia PoolManager address:
  `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408`.
- Added a native bridge release zero-recipient regression test.
- Made the native release zero-recipient guard explicit directly in
  `releaseNative`.
- Documented the intentional native value transfer boundary.
- Ran `forge fmt` across Solidity contracts, tests, and scripts so the explicit
  format gate passes.
- Added a Base Sepolia CREATE2 hook deploy script for
  `FlowMemoryAfterSwapHook`.
- Added a Base Sepolia v4 hook proof runner with plan, env-check, evidence,
  strict live-proof, live-check, dry-run, broadcast, swap-proof dry-run, and
  swap-proof broadcast modes.
- Added a full PoolManager swap proof script that deploys throwaway testnet
  tokens, initializes a hooked v4 pool, adds tiny liquidity, and performs a
  tiny swap with FlowMemory hook data.
- Added the v4 hook proof runbook at
  `docs/DEPLOYMENTS/BASE_SEPOLIA_V4_HOOK_PROOF.md`.
- Hardened the proof runner so private keys and RPC URLs are redacted in runner
  error messages, and so the swap-proof operator is derived from or must match
  the broadcast signer.
- Added sanitized Foundry run summaries to hook proof artifacts and added a
  Base Sepolia readback mode that fails by default when no hook FlowPulse
  observations are found.
- Added a non-secret env-check artifact so operators can verify local RPC,
  Base Sepolia chain id, deployer key format, deployer address, and test ETH
  balance before sending the public testnet proof transaction sequence.
- Added a non-secret evidence artifact and strict `require-live-proof` gate so
  the repo can mechanically distinguish dry-run readiness from a completed live
  Base Sepolia PoolManager hook proof.
- Added a readback range planner and auto-readback path that can infer the
  readback window from successful broadcast receipt block numbers while
  rejecting dry-run proof artifacts as live evidence.
- Added a strict acceptance package gate that ties together env readiness,
  live code, broadcast receipts, readback, evidence, Flow Memory outputs, and
  count agreement before any live-proof claim is allowed. It also requires the
  selected readback range to match the actual readback artifact, deployed hook
  runtime-bytecode identity against the compiled artifact, successful receipts
  for the PoolManager initialize/liquidity/swap actions, FlowPulse observation
  integrity, at least one successful `SWAP_MEMORY_SIGNAL`, and Flow Memory
  signal linkage to successful broadcast receipt transaction hashes.

## Verification

Commands run:

```powershell
forge test --match-contract FlowMemoryAfterSwapHookTest -vvv
forge test --match-contract BaseBridgeLockboxTest -vvv
powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/contracts-static-analysis.ps1 -CheckFormat
npm run contracts:hardening:slither
npm run hook:base-sepolia:plan -- --json
npm run hook:base-sepolia:env-check -- --json
npm run hook:base-sepolia:evidence -- --json
npm run hook:base-sepolia:require-live-proof -- --json
npm run hook:base-sepolia:check -- --json
npm run hook:base-sepolia:dry-run -- --json
npm run hook:base-sepolia:swap-proof:dry-run -- --json
npm run hook:base-sepolia:test-readback-range
npm run hook:base-sepolia:readback-range -- --from-block <latestBlock> --to-block <latestBlock> --json
npm run hook:base-sepolia:readback-range -- --infer-readback-range --json
npm run hook:base-sepolia:acceptance -- --allow-incomplete --json
npm run hook:base-sepolia:acceptance -- --json
npm run hook:base-sepolia:readback -- --rpc-url https://sepolia.base.org --from-block <latestBlock> --to-block <latestBlock> --allow-empty-readback --json
npm run hook:base-sepolia:flowmemory
npm run hook:base-sepolia:flowmemory -- --allow-incomplete
npm run launch:candidate
npm run flowchain:no-secret:scan
git diff --check
```

Results:

- FlowMemory afterSwap hook tests: 9 passing.
- BaseBridgeLockbox tests: 18 passing.
- Full contract hardening with format gate: 90 passing.
- Slither required gate: 0 findings across 29 analyzed contracts.
- Base Sepolia hook plan generated:
  `fixtures/deployments/base-sepolia-v4-hook-proof-plan.json`.
- Base Sepolia env-check generated
  `fixtures/deployments/base-sepolia-v4-hook-env-check.latest.json`; this
  shell still lacked an operator-provided RPC URL and funded deployer key, so
  it correctly reported `broadcastReady: false`.
- Base Sepolia live-code check passed against chain id `84532`; the official
  Uniswap v4 PoolManager, Universal Router, PositionManager, StateView,
  Quoter, PoolSwapTest, PoolModifyLiquidityTest, Permit2, and standard CREATE2
  deployer all had code at the expected addresses. The planned FlowMemory hook
  address did not have code yet, which is expected before broadcast.
- Hook deployment dry-run succeeded for planned address
  `0xD24d7f807cb00D28DdF675E55879547d4F7B0040`.
- Full swap-proof dry-run succeeded and wrote
  `fixtures/deployments/base-sepolia-v4-hook-proof.latest.json`.
- The latest proof artifact includes a sanitized Foundry transaction/proof
  summary for the dry run. The readback command was added but has not been run
  against a live broadcast because this shell has no operator-provided Base
  Sepolia RPC URL or funded deployer key configured.
- The readback range regression check passed. It verifies explicit operator
  ranges, rejects dry-run artifacts for inferred live readback, and accepts
  broadcast-style proof artifacts with successful receipt block numbers. It
  also verifies that acceptance only treats the selected range as usable when
  the actual readback artifact reports the same source and block window, and
  that generated Flow Memory signal transaction hashes are traceable to
  successful broadcast receipt transactions.
- The acceptance package diagnostic generated
  `fixtures/deployments/base-sepolia-v4-hook-acceptance.latest.json` with
  `liveProofAccepted: false` and explicit failed checks. The strict acceptance
  command correctly failed because the hook is not deployed, no broadcast
  receipts exist, and readback has zero observations.
- The consolidated evidence artifact currently reports `stage:
  dry-run-proof-ready`, `liveProofComplete: false`,
  `officialContractsCodePresent: true`, `dryRunProofReady: true`,
  `plannedHookCodePresent: false`, `broadcastProofReady: false`, and
  `readbackProofReady: false`.
- The strict `require-live-proof` command was run and correctly failed because
  `liveProofComplete` is still false.
- The readback wrapper was tested against a current Base Sepolia empty block
  range with `--allow-empty-readback`. It produced `proofComplete: false` and
  `observationCount: 0`, which is the expected diagnostic behavior before the
  hook is actually deployed and swapped through on Base Sepolia.
- The post-readback Flow Memory generator was added and tested. Strict mode
  fails until the evidence artifact has `liveProofComplete: true`; diagnostic
  mode with `--allow-incomplete` writes non-production Flow Memory / Rootflow /
  dashboard JSON with zero observations and a warning alert.
- The strict generator also rejects count mismatches, non-FlowPulse topics,
  non-success receipts, and complete-readback claims without at least one
  unique successful `SWAP_MEMORY_SIGNAL`.
- `npm run launch:candidate` passed after the proof tooling changes.
- `npm run flowchain:no-secret:scan` passed.
- `git diff --check` passed with line-ending warnings only.

## Readiness Boundary

The contract surface is good for the current V0 launch candidate boundary:

- no token custody in the FlowMemory swap hook;
- no dynamic fee override;
- no custom accounting delta;
- no `txHash` or `logIndex` assumptions inside hooks;
- indexers/verifiers derive receipt locators after logs exist;
- Base Sepolia hook planning uses the current Uniswap deployment address.

This does not prove a production Uniswap v4 pool is live. A real hook launch
still requires CREATE2 deployment at a permissioned hook address, pool creation
against the target PoolManager, a real swap through that pool, and explorer
verification of the deployed bytecode.

The next proof step is not another unit test. It is a funded Base Sepolia
broadcast of:

```powershell
npm run hook:base-sepolia:swap-proof:broadcast -- --json
```

followed by:

```powershell
npm run hook:base-sepolia:readback-range -- --infer-readback-range --json
npm run hook:base-sepolia:readback:auto -- --json
```

or, if the operator chooses the block range manually:

```powershell
npm run hook:base-sepolia:readback -- --rpc-url $env:BASE_SEPOLIA_RPC_URL --from-block <deployBlock> --to-block <latestBlock> --finalized-block <safeFinalizedBlock> --json
```

That readback must produce `proofComplete: true` and at least one hook
FlowPulse observation. The indexer state/checkpoint then provides the `txHash`
and `logIndex` for the emitted FlowPulse. The hook itself still does not know
or emit those receipt locator fields.

Then strict Flow Memory / Rootflow dashboard evidence must succeed:

```powershell
npm run hook:base-sepolia:flowmemory
```

This command must pass without `--allow-incomplete` before the proof can be
treated as complete.

The final package must also pass:

```powershell
npm run hook:base-sepolia:acceptance -- --json
```

It must report `liveProofAccepted: true`; diagnostic packages generated with
`--allow-incomplete` are not acceptance evidence.
