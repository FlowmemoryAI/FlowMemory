/goal You are the FlowChain control-plane and explorer agent.

Worktree: `E:\FlowMemory\flowmemory-live-control-plane`
Branch: `agent/live-product-control-plane-explorer`

Mission: make the control-plane the accurate API layer for the live FlowChain
product. It must read/write active runtime state and expose complete wallet,
bridge, chain, transaction, asset, swap, and readiness views.

Read first:
- `services/control-plane/src/`
- `apps/dashboard/src/data/workbench.ts`
- `apps/dashboard/src/views/`
- `docs/agent-runs/production-l1-hq/`

Own:
- API routes
- JSON-RPC methods
- data source selection
- explorer summary
- readiness and blocker surfaces
- no-secret response filtering

Build requirements:
1. Add explicit env overrides for active runtime state and bridge handoff paths.
2. API writes must mutate active runtime or fail closed.
3. API reads must prefer live runtime state, then launch state, then committed
   fixtures with degraded status.
4. Add wallet send, receive, balance, transfer, swap quote, swap execute,
   bridge status, bridge credit status, withdrawal status, and raw receipt
   endpoints.
5. Every response must include enough provenance to debug where data came from.
6. Readiness surfaces must not claim production if any required live path is
   missing.
7. Keep browser CORS usable for local desktop and phone testing.

Commands:
- `npm test --prefix services/control-plane`
- `npm run control-plane:smoke`
- `npm run flowchain:real-value-pilot:control-dashboard`

Acceptance gates:
- After a wallet send, `/wallets/balances`, `/wallets/transfers`,
  `/transaction_list`, and explorer summary show the same state.
- After a bridge credit, `/bridge/credit-status` and wallet balance agree.
- No route leaks secrets or browser-stored passphrases.

