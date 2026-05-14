/goal You are the FlowChain node, RPC, and network agent.

Worktree: `E:\FlowMemory\flowmemory-live-node-rpc`
Branch: `agent/live-product-node-rpc`

Mission: make FlowChain run like a real local/private L1 node product with an
RPC surface that wallets, relayers, and explorers can use. Build on the current
runtime and control-plane. Do not replace the runtime.

Read first:
- `crates/flowmemory-devnet/`
- `services/control-plane/src/`
- `infra/scripts/flowchain-node*.ps1`
- `docs/LOCAL_DEVNET.md`

Own:
- node start/stop/status/log commands
- JSON-RPC or HTTP endpoints for submit, blocks, txs, receipts, balances,
  accounts, assets, swaps, bridge credits, and finality
- local multi-process peer smoke and LAN documentation if exposed
- wallet-safe connection discovery

Build requirements:
1. A wallet can discover the active node/API without hard-coded stale ports.
2. RPC writes must submit to the active runtime, not to static fixtures.
3. RPC reads must reflect the same state file the runtime is mutating.
4. Every write endpoint must return a stable receipt or fail closed.
5. Add health probes for block production, finality lag, mempool depth, peer
   count, bridge relayer lag, and wallet API reachability.
6. Support configurable confirmation/finality settings without hard-coded
   arbitrary pilot caps.
7. Ensure CORS is safe for local desktop/mobile use and does not expose secrets.

Commands:
- `npm run flowchain:node`
- `npm run flowchain:node:status`
- `npm run control-plane:smoke`
- `npm run flowchain:restart:verify`

Acceptance gates:
- Wallet send uses a live RPC/control-plane path.
- Explorer block and transaction reads match runtime state after a write.
- Node restart does not lose pending or included transactions.
- API errors name missing env/deployment artifacts exactly.
- No endpoint returns private keys, vault ciphertext, RPC credentials, or seed
  material.

