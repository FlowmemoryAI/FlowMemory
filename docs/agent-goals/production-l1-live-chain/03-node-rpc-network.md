/goal You are the FlowChain node, RPC, and network agent.

Worktree: `E:\FlowMemory\flowmemory-live-node-rpc`
Branch: `agent/live-product-node-rpc`

Mission: build the FlowChain RPC into a real, wallet/explorer/bridge-usable
L1 RPC surface. Do not stop at docs, fixtures, UI labels, or a local-only demo.
Keep looping until every RPC requirement below is implemented, machine-tested,
or blocked by a precise external deployment input with a fail-closed check.

You are not alone in the codebase. Other agents may be changing runtime,
wallet, bridge, dashboard, storage, and verification files. Do not revert their
edits. Integrate with the existing runtime/control-plane contracts and avoid
creating a parallel RPC stack.

Read first:
- `AGENTS.md`
- `docs/agent-goals/production-l1-live-chain/README.md`
- `docs/FLOWCHAIN_CONTROL_PLANE_API.md`
- `docs/FLOWCHAIN_PRODUCTION_L1_GO_NO_GO.md`
- `docs/FLOWCHAIN_LIVE_L1_BRIDGE_GO_NO_GO.md`
- `services/control-plane/src/`
- `crates/flowmemory-devnet/`
- `infra/scripts/flowchain-node*.ps1`
- `infra/scripts/flowchain-production-l1-e2e.ps1`
- `infra/scripts/flowchain-live-l1-bridge-e2e.ps1`
- `apps/dashboard/src/views/WalletView.tsx`
- `apps/dashboard/src/views/WorkbenchView.tsx`

Own these files/modules unless coordination requires otherwise:
- `services/control-plane/src/`
- `services/control-plane/test/`
- `services/control-plane/README.md`
- `docs/FLOWCHAIN_CONTROL_PLANE_API.md`
- `docs/agent-runs/live-product-node-rpc/`
- node/RPC scripts under `infra/scripts/flowchain-node*.ps1`
- root `package.json` RPC scripts, only for RPC-focused commands

Do not own:
- wallet private-key custody internals except RPC discovery integration
- Base lockbox Solidity deployment except fields needed by RPC readiness
- bridge event parsing logic except relay/RPC contracts
- dashboard redesign except proving dashboard can consume RPC
- unrelated formatting churn or broad refactors

Required product standard:
A wallet on another machine must be able to discover a FlowChain RPC URL, query
chain status, create/use a local account address, submit a signed FlowChain
transaction, see the transaction enter mempool or a block, query updated account
balances, and see bridge credits once the bridge relayer submits them. An
explorer must be able to read the same blocks, transactions, receipts, accounts,
balances, token/DEX state, bridge credits, finality, and health state from that
same RPC. If any part is not live, return a structured fail-closed reason.

RPC protocol requirements:
1. Keep JSON-RPC 2.0 at `/rpc`.
2. Add/maintain machine-readable discovery:
   - `rpc_discover`
   - browser-safe `GET /rpc/discover`
   - all supported method names, categories, read/write mode, and boundaries.
3. Add/maintain machine-readable readiness:
   - `rpc_readiness`
   - browser-safe `GET /rpc/readiness`
   - exact missing env/deployment names only, never values.
4. Maintain core methods:
   - `health`, `node_status`, `peer_list`, `chain_status`
   - `block_list`, `block_get`
   - `transaction_list`, `transaction_get`, `transaction_submit`
   - `mempool_list`
   - `account_list`, `account_get`
   - `balance_get`
   - `wallet_metadata_list`, `wallet_metadata_get`
   - `wallet_balance_list`, `wallet_transfer_history`
   - token/DEX methods: token, token balance, pool, LP position, swap
   - bridge methods: live readiness, status, observations, deposits, credits,
     withdrawals, lifecycle records
   - receipt/provenance/finality methods.
5. Every write method must:
   - reject unsigned or malformed envelopes;
   - reject private keys, seed phrases, mnemonics, RPC credentials, API keys,
     webhook URLs, vault ciphertext, and browser-stored secrets;
   - return a stable accepted/rejected receipt;
   - write to active runtime intake, not static committed fixtures;
   - be replay-safe or explicitly fail closed.
6. Every read method must:
   - prefer active `devnet/local/` runtime state;
   - fall back to deterministic fixtures only with `source` and `localOnly`
     boundaries;
   - never silently present fixture data as live state;
   - include enough IDs for wallet/explorer linking.

Runtime coupling requirements:
1. RPC reads must reflect the exact state file the node is mutating.
2. RPC writes must be visible in `mempool_list` immediately.
3. After block production, submitted txs must be visible in `block_get`,
   `transaction_get`, account/balance reads, and relevant receipt/finality
   reads.
4. Restart must not lose mempool, included tx, bridge credit, replay key,
   account, balance, token, DEX, or finality state.
5. Export/import/recovery must prove the same roots before and after restart.

Network and deployment requirements:
1. Support a configurable bind host and port without hard-coded stale ports.
2. Provide a safe local default: `127.0.0.1`, no public exposure by accident.
3. Public exposure must require explicit env/deployment fields:
   - `FLOWCHAIN_RPC_PUBLIC_URL`
   - `FLOWCHAIN_RPC_ALLOWED_ORIGINS`
   - `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`
   - `FLOWCHAIN_RPC_TLS_TERMINATED`
   - `FLOWCHAIN_RPC_STATE_BACKUP_PATH`
4. If any public RPC input is absent, `rpc_readiness` must report `BLOCKED`.
5. Add production-shaped CORS guidance. Do not leave broad `*` as the public
   deployment path without a readiness blocker.
6. Add health probes for:
   - process alive
   - latest block height/hash/root
   - block production age
   - finality lag
   - mempool depth
   - peer count
   - bridge relayer lag/readiness
   - state persistence/readability
   - wallet API reachability
   - no-secret response checks.
7. Add rate-limit/auth extension points without breaking local development.

Wallet/explorer/bridge integration:
1. Wallet must be able to call `rpc_discover` and `rpc_readiness`.
2. Wallet send must use a live RPC/control-plane write path, not a draft row.
3. Receive address must match an account address the RPC can query.
4. Explorer blocks/txs/accounts/balances must match runtime state after a write.
5. Bridge relayer handoff must produce RPC-visible bridge credit rows.
6. The RPC must distinguish:
   - local/test units,
   - live Base 8453 observed deposits,
   - applied FlowChain credits,
   - spendable balances,
   - withdrawal intents,
   - release evidence.

Security and safety requirements:
1. Do not print or return secrets.
2. Do not commit `.env`, private keys, wallet vaults, RPC credentials, API keys,
   or webhook URLs.
3. All missing live config must be reported by variable/artifact name only.
4. Broad public readiness must remain false until live gates prove it.
5. Do not call the RPC EVM-compatible unless EVM JSON-RPC compatibility is
   implemented and tested. If it is FlowChain-native JSON-RPC, say so.
6. Keep real-funds paths fail-closed unless Base RPC, lockbox, block range,
   caps, confirmations, and owner acknowledgement are configured.

Implementation loop:
1. Create `docs/agent-runs/live-product-node-rpc/PLAN.md`,
   `CHECKLIST.md`, `EXPERIMENTS.md`, and `NOTES.md`.
2. Inventory existing methods and mark each `live-runtime`, `fixture-fallback`,
   `write-intake`, `missing`, or `blocked`.
3. Implement the highest-risk missing RPC feature first.
4. Add or update unit tests for every changed method.
5. Add HTTP/browser-safe tests for discovery/readiness.
6. Run the focused command set below.
7. Update the checklist with evidence, not claims.
8. Repeat until the RPC is green or every remaining gap has a failing/skipped
   test and exact blocker.

Commands to run before finishing:
```powershell
npm test --prefix services/control-plane
npm run control-plane:smoke
npm run flowchain:node:smoke
npm run flowchain:wallet:transfer:e2e
npm run flowchain:production-l1:e2e
npm run flowchain:no-secret:scan
```

Add a new root command if it does not already exist:
```powershell
npm run flowchain:rpc:e2e
```

That command must:
1. start or attach to a local FlowChain node;
2. call `rpc_discover` and verify method coverage;
3. call `rpc_readiness` and verify fail-closed public readiness if env is
   absent;
4. submit a signed transaction;
5. verify mempool visibility;
6. produce or wait for a block;
7. verify block, tx, account, balance, receipt, finality, and provenance reads;
8. restart the node/control-plane;
9. verify state continuity after restart;
10. verify no-secret scan coverage for RPC outputs.

Acceptance gates:
- `rpc_discover` and `GET /rpc/discover` exist and are tested.
- `rpc_readiness` and `GET /rpc/readiness` exist and are tested.
- Wallet/explorer/bridge can discover the same RPC endpoint and method list.
- Runtime writes are visible through mempool and block/tx reads.
- Active runtime state takes precedence over fixtures and says when it is a
  fallback.
- Public RPC readiness is `BLOCKED` unless all explicit public deployment inputs
  are configured.
- No endpoint returns private keys, vault ciphertext, seed phrases, RPC
  credentials, API keys, or webhooks.
- Reports under `docs/agent-runs/live-product-node-rpc/` include exact commands,
  outputs, gaps, and next owners.
- Do not mark complete if the RPC is local-only but described as public/live.
