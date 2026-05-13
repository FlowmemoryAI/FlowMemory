/goal You are the FlowChain dashboard/workbench agent.

You are working in `E:\FlowMemory\flowmemory-dashboard`.

Mission: make the workbench feel like a real local chain console. It must show
the live local node/API state, not just static fixtures, and it must help a
non-technical tester run the chain on a second computer.

Read first:
- AGENTS.md
- docs/FLOWCHAIN_FULL_PRIVATE_TESTNET.md
- docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md
- apps/dashboard/
- docs/FLOWCHAIN_CONTROL_PLANE_API.md

Allowed folders:
- apps/dashboard/
- docs/DASHBOARD_MVP.md
- docs/FLOWCHAIN_SECOND_COMPUTER_SETUP.md only when setup text changes

Do not edit:
- services/
- crates/
- contracts/
- crypto/
- hardware/

Build requirements:
1. Keep the existing dashboard app. Do not scaffold a second app.
2. Add live workbench views backed by the control-plane API:
   node status, peers, blocks, transactions, mempool, accounts, balances,
   faucet events, wallet public accounts, agent/model registry, receipts,
   artifacts, verifier modules/reports, memory cells, challenges, finality,
   bridge deposits/credits/withdrawals, hardware signals, and raw JSON.
3. Add obvious setup/status panels that say what command is missing when the
   node or API is down.
4. Add local actions only when the control-plane endpoint exists:
   submit local faucet request, submit sample transaction, inspect bridge test
   deposit, refresh state. Keep private-key handling out of the browser unless
   the crypto agent provides a safe local API.
5. Make offline/error/empty/loading states professional and clear.
6. Keep UI responsive and verify with tests/build.

Expected commands:
- `npm run dev --prefix apps/dashboard`
- `npm test --prefix apps/dashboard`
- `npm run build --prefix apps/dashboard`
- contribute to `npm run flowchain:full-smoke`

Acceptance:
- Dashboard tests pass.
- Dashboard build passes.
- Workbench shows verified API status when `http://127.0.0.1:8787/health` and
  `/state` are live.
- Workbench can inspect all lifecycle object types exposed by the API.
- It does not claim production mainnet or real funds.
- `git diff --check` passes.
- Open a PR and push your branch.
