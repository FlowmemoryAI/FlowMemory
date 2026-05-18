# FlowMemory Launch Readiness Verification

Date: 2026-05-17

Status: local/test V0 launch path verified; live canary read verified; production
Uniswap v4 hook deployment and real swap execution not yet verified.

This review records the evidence gathered for the launch-critical FlowMemory
path:

```text
swap-shaped FlowPulse
-> indexer observation
-> verifier report
-> MemorySignal
-> MemoryReceipt
-> RootflowTransition
-> RootfieldBundle
-> AgentMemoryView / dashboard data
```

It does not approve production L1, production bridge, production verifier
network, production Uniswap v4 hook deployment, tokenomics, free storage, or AI
running on-chain.

## What Is Verified

### Contract and hook surfaces

Command:

```powershell
npm run contracts:hardening
```

Result:

- 90 Foundry tests passed.
- `FlowMemoryHookAdapter` emits `SWAP_MEMORY_SIGNAL` in the V0 adapter path.
- `FlowMemoryAfterSwapHook` is PoolManager-gated.
- `FlowMemoryAfterSwapHook.afterSwap` returns zero hook delta.
- The hook path rejects zero sender, zero rootfield, zero commitment, empty hook
  data, and unauthorized PoolManager calls.
- Event schemas still exclude `txHash` and `logIndex`; those remain
  indexer-derived receipt metadata.
- `FlowMemoryHookPlanner` mines the Base Sepolia afterSwap-only hook permission
  target.

Important fix made during this pass:

- Updated the Base Sepolia Uniswap v4 PoolManager constant to
  `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408`.
- Updated the matching deployment-boundary and decision docs.

### Base Sepolia Uniswap v4 hook proof tooling

Commands:

```powershell
npm run hook:base-sepolia:env-check -- --json
npm run hook:base-sepolia:check -- --json
npm run hook:base-sepolia:swap-proof:dry-run -- --json
npm run hook:base-sepolia:test-readback-range
npm run hook:base-sepolia:readback-range -- --from-block <latestBlock> --to-block <latestBlock> --json
npm run hook:base-sepolia:readback-range -- --infer-readback-range --json
npm run hook:base-sepolia:acceptance -- --allow-incomplete --json
npm run hook:base-sepolia:acceptance -- --json
npm run hook:base-sepolia:readback -- --rpc-url https://sepolia.base.org --from-block <latestBlock> --to-block <latestBlock> --allow-empty-readback --json
npm run hook:base-sepolia:evidence -- --json
npm run hook:base-sepolia:require-live-proof -- --json
npm run hook:base-sepolia:flowmemory
npm run hook:base-sepolia:flowmemory -- --allow-incomplete
```

Result:

- Env-check artifact generated:
  `fixtures/deployments/base-sepolia-v4-hook-env-check.latest.json`.
- Env-check correctly reported `broadcastReady: false` in this shell because no
  operator-provided Base Sepolia RPC URL and no funded deployer key are
  configured.
- Live-code check confirmed Base Sepolia chain id `84532`.
- The official Uniswap v4 PoolManager, Universal Router, PositionManager,
  StateView, Quoter, PoolSwapTest, PoolModifyLiquidityTest, Permit2, and
  standard CREATE2 deployer all had code at the expected Base Sepolia
  addresses.
- The planned FlowMemory hook address
  `0xD24d7f807cb00D28DdF675E55879547d4F7B0040` did not have code yet, which is
  expected before broadcast.
- Full swap-proof dry-run succeeded and produced a sanitized proof artifact:
  `fixtures/deployments/base-sepolia-v4-hook-proof.latest.json`.
- The dry-run simulated 12 public-testnet-shaped transactions: hook deploy,
  two throwaway proof token deploys, mints, approvals, pool initialization,
  liquidity modification, and swap.
- Estimated dry-run gas requirement was approximately `0.0000381` Base Sepolia
  ETH at the sampled gas price.
- Readback range planning now supports explicit operator block ranges and
  inferred ranges from successful broadcast receipt block numbers.
- The readback range regression check passed and correctly refused to infer a
  live readback range from the current dry-run proof artifact.
- A final acceptance package now exists. Diagnostic mode wrote
  `fixtures/deployments/base-sepolia-v4-hook-acceptance.latest.json` with
  `liveProofAccepted: false` and explicit failed checks; strict mode correctly
  failed until the public-testnet broadcast/readback exists. The package also
  requires planned hook runtime-bytecode identity, range/readback artifact
  agreement, successful receipts for the PoolManager
  initialize/liquidity/swap actions, FlowPulse observation integrity, at least
  one successful `SWAP_MEMORY_SIGNAL`, and Flow Memory signal linkage to
  successful broadcast receipt transaction hashes.
- Empty-range readback diagnostic produced `proofComplete: false` and
  `observationCount: 0`, which is expected before a real hook deployment and
  swap exist.
- Evidence artifact generated:
  `fixtures/deployments/base-sepolia-v4-hook-evidence.latest.json`.
- Evidence currently reports `stage: dry-run-proof-ready` and
  `liveProofComplete: false`.
- The strict live-proof gate correctly fails until deployed hook code,
  broadcast receipts, and non-empty hook readback exist.
- The strict Flow Memory / Rootflow evidence generator correctly fails until
  `liveProofComplete: true`.
- The strict Flow Memory / Rootflow evidence generator now also rejects weak
  evidence: count mismatches across artifacts, non-FlowPulse topics,
  non-success receipts, and complete-readback claims that do not include at
  least one unique successful `SWAP_MEMORY_SIGNAL`.
- Diagnostic Flow Memory generation with `--allow-incomplete` writes
  `fixtures/deployments/base-sepolia-v4-hook-flowmemory.latest.json`,
  `fixtures/dashboard/flowmemory-dashboard-base-sepolia-v4-hook.json`, and
  `apps/dashboard/public/data/flowmemory-dashboard-base-sepolia-v4-hook.json`
  with zero observations and `liveProofComplete: false`.

This proves the public-testnet proof tooling and fork simulation path. It does
not prove the mined hook is deployed or that a real Base Sepolia PoolManager
swap has emitted FlowPulse. The new Flow Memory generator also proves the
post-broadcast artifact path is wired: once readback is non-empty and evidence
is complete, the same command will produce MemorySignals, MemoryReceipts,
RootflowTransitions, RootfieldBundles, AgentMemoryViews, and dashboard data
from the real hook observation.

### Launch-core local path

Command:

```powershell
npm run launch:candidate
```

Result:

- Contract hardening passed.
- `npm run launch:v0` regenerated the local V0 path.
- Schema validation passed.
- Fixture drift check passed.
- Unsafe claim guard passed.

Generated launch-core counts:

- loaded FlowPulses: 8
- indexed observations: 8
- verifier reports: 8
- rootflow transitions: 7
- memory signals: 8
- memory receipts: 8
- rootfield bundles: 1
- agent memory views: 1
- swap-memory signals in launch validator: 1

This proves the current local V0 system can transform a swap-memory pulse into
agent/dashboard-readable Flow Memory state.

### Swap-memory stress path

New command:

```powershell
npm run stress:swaps --prefix services/flowmemory -- --swaps 1024 --out fixtures/launch-core/swap-memory-stress-report.json
```

Report:

```text
fixtures/launch-core/swap-memory-stress-report.json
```

Stress input:

- generated logs: 1,037
- valid swap candidates: 1,017
- exact duplicate logs: 7
- reorg replacement logs: 3
- intentionally invalid logs: 4
- intentionally unresolved logs: 3
- malformed logs: 3

Indexer result:

- observations: 1,034
- dashboard-canonical observations: 1,024
- cursors: 1,027
- rejected logs: 3
- duplicates: 10
- warning codes:
  - `duplicate.exactDuplicate`
  - `duplicate.reorgReplacement`
  - `rejected.log.malformed`

Verifier result:

- reports: 1,034
- valid: 1,027
- invalid: 4
- unresolved: 3
- invalid reason codes:
  - `subject.mismatch`
  - `commitment.mismatch`
- unresolved reason code:
  - `artifact.unavailable`

Flow Memory result:

- memory signals: 1,034
- swap-memory signals: 1,034
- memory receipts: 1,034
- rootflow transitions: 1,027
- rootfield bundles: 1
- agent memory views: 1
- verified transitions/signals: 1,017
- failed: 4
- unresolved: 3
- stale: 3

Stress invariants:

- one report per observation: true
- one MemorySignal per observation: true
- all signals are swap-memory signals: true
- malformed logs rejected: true
- duplicate logs detected: true
- valid signals present: true
- failed signals present: true
- unresolved signals present: true

This proves the architecture can handle more than the tiny launch fixture and
still preserve duplicate, reorg, malformed, invalid, and unresolved states
instead of flattening them into a false success.

### Service, crypto, dashboard, and local-chain gates

Commands run:

```powershell
npm test
npm test --prefix crypto
cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml
npm run build --prefix apps/dashboard
npm run flowchain:full-smoke
npm run flowchain:product-e2e
```

Results:

- Root service suite passed.
- Crypto package tests passed: 23 tests.
- Crypto vector validation passed: 46 vectors.
- Local Alpha fixture validation passed: 15 documents, 15 envelopes, 1 transaction.
- Rust devnet tests passed: 38 integration tests.
- Dashboard production build passed.
- FlowChain full private/local smoke passed.
- Product Testnet V1 E2E passed.
- Control-plane smoke queried 72 methods successfully.
- Hardware simulator smoke passed with raw packets, operator signals, control-plane handoff, fixture drift check, and 8 negative cases.

The local product path also validated token/DEX behavior in the private/local
runtime. That is useful for FlowChain product modeling, but it is not proof of
Base or Uniswap production behavior.

## Live Data Checked

The documented Base mainnet V0 canary range was reread through public Base RPC:

```powershell
npm run index:base-canary -- --acknowledge-mainnet-canary --rpc-url https://mainnet.base.org --address 0x2a7ADd68a1d45C3251E2F92fFe4926124654a97C --address 0x179Df6d52e9DeF5D02704583a2E4E5a9FF427245 --from-block 45955500 --to-block 45955540 --finalized-block 45955540
```

Result:

- network: Base mainnet canary
- chain id: 8453
- observation count: 4
- rejected logs: 0
- duplicate count: 0
- dashboard-canonical observations: 4
- last indexed block: 45955540
- integrity warnings: false
- production ready: false

Then the canary dashboard data was regenerated:

```powershell
npm run flowmemory:canary-dashboard
```

Result:

- observations: 4
- memory signals: 4
- rootflow transitions: 4
- production ready: false

This is real chain evidence for the V0 canary contracts. It is not a production
Uniswap v4 hook deployment.

## What Is Useful

The useful part is narrow and concrete:

1. A swap-shaped event can become a public, compact, agent-readable memory
   signal.
2. The event keeps heavy memory artifacts off-chain and puts only commitments
   and identifiers into the pipeline.
3. The indexer reconstructs receipt facts after logs exist, including
   `txHash`, `transactionIndex`, and `logIndex`.
4. The verifier can mark signals as verified, failed, unresolved, unsupported,
   stale, or reorged.
5. Rootflow can preserve state transitions and avoid silently accepting bad or
   missing evidence.
6. The dashboard/control-plane can show the resulting state without claiming AI
   is running on-chain.

For launch messaging, the defensible claim is:

```text
FlowMemory turns swap activity into verifiable memory signals for AI agents.
```

The stronger but still defensible technical version is:

```text
FlowMemory emits compact FlowPulse events, derives receipt-aware MemorySignals
off-chain, verifies commitments against local/test resolver rules, and exposes
Rootflow state for dashboards and agent memory views.
```

## Not Verified Yet

These are the remaining hard gaps before saying the actual Uniswap v4 launch
path is live:

1. No Base Sepolia RPC URL is configured in this shell.
2. No Base Sepolia deployer key is configured in this shell.
3. No Base Sepolia `FlowMemoryAfterSwapHook` deployment was broadcast in this
   pass.
4. No mined afterSwap-only hook address was recorded as deployed.
5. No Uniswap v4 pool was initialized with the FlowMemory hook.
6. No real Uniswap v4 swap was executed through PoolManager using this hook.
7. No live Base Sepolia reader pass observed events from a real
   PoolManager-triggered hook.
8. No live readback range artifact has been generated from broadcast receipt
   block numbers.
9. No final acceptance package has `liveProofAccepted: true`.
10. No production ownership policy, multisig policy, or recovery policy is in
   place for a production deployment.

Without those items, the correct status is:

```text
Local/test V0 verified.
Base canary read verified.
Production Uniswap v4 hook launch path not yet verified.
```

## Required Next Verification

Contracts agent, `flowmemory-contracts`:

1. Mine and record the Base Sepolia afterSwap-only hook salt/address.
2. Deploy `FlowMemoryAfterSwapHook` on Base Sepolia with PoolManager
   `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408`.
3. Initialize a test Uniswap v4 pool with that hook.
4. Execute one tiny Base Sepolia swap with hook data.
5. Generate or review the readback range artifact from the broadcast receipts.
6. Record deploy tx, hook address, pool id, swap tx, block range, and source
   verification plan.

Indexer agent, `flowmemory-indexer`:

1. Run the Base Sepolia reader over the hook deployment/swap block range.
2. Confirm one or more `SWAP_MEMORY_SIGNAL` logs from the deployed hook.
3. Generate a Base Sepolia hook-read evidence artifact.
4. Run `npm run hook:base-sepolia:flowmemory` without `--allow-incomplete` and
   confirm it writes live-proof-complete Flow Memory / Rootflow dashboard
   evidence.
5. Run `npm run hook:base-sepolia:acceptance -- --json` and confirm
   `liveProofAccepted: true`.

Review agent, `flowmemory-review`:

1. Confirm no production claims are added after the testnet run.
2. Confirm the hook address flags are exactly afterSwap-only.
3. Confirm `txHash`/`logIndex` appear only in reader-derived fields.

## Launch Wording Boundary

Allowed:

- "The local/test FlowMemory V0 path is verified."
- "A Base mainnet canary read observed 4 V0 FlowPulse logs."
- "Synthetic stress testing processed 1,034 swap-memory observations through
  the FlowMemory data path."
- "FlowMemory turns swap-shaped activity into verifiable memory signals for AI
  agents."

Not allowed yet:

- "The production Uniswap v4 hook is live."
- "Real Uniswap swaps are already feeding FlowMemory through PoolManager."
- "FlowMemory is production mainnet-ready."
- "AI runs on-chain."
- "Storage is free."
- "The hook knows transaction hashes or log indexes."
