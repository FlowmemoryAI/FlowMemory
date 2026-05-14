/goal You are the FlowChain assets, token, and DEX/swap agent.

Worktree: `E:\FlowMemory\flowmemory-live-assets-dex`
Branch: `agent/live-product-assets-dex`

Mission: make assets and swaps work through the FlowChain runtime and wallet.
The wallet Swap button must call a real quote/execution path or fail closed with
clear missing liquidity, not add local mock rows.

Read first:
- `crates/flowmemory-devnet/src/model.rs`
- `crypto/src/wallet-documents.js`
- `crypto/src/production-l1-vectors.js`
- `services/control-plane/src/methods.ts`
- `apps/dashboard/src/views/WalletView.tsx`

Own:
- asset registry
- token balances
- pool creation
- liquidity add/remove
- swap quote and execution
- wallet swap API and UI wiring

Build requirements:
1. Runtime asset IDs must distinguish Base ETH, bridged ERC-20s, local test
   assets, and FlowChain-native assets.
2. Quote endpoint returns input asset, output asset, reserves, expected out,
   slippage fields, and failure reason.
3. Execution endpoint submits a runtime swap transaction and returns a receipt.
4. Wallet activity shows swaps with tx id and status.
5. Explorer reads pools, positions, reserves, and swaps from runtime state.
6. No fake USD prices are used for execution. UI estimates must be labeled.
7. Add tests for insufficient balance, missing pool, stale quote, duplicate
   swap, and post-restart reserves.

Commands:
- `npm run flowchain:dex:e2e`
- `npm run flowchain:product-e2e`
- `npm run control-plane:smoke`

Acceptance gates:
- A funded account can execute a swap against runtime liquidity.
- Balances and pool reserves update exactly.
- Wallet and explorer show the same swap receipt.
- Swap fails closed without liquidity.

