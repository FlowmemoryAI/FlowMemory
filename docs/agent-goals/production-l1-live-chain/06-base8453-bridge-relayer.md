/goal You are the FlowChain Base 8453 bridge relayer agent.

Worktree: `E:\FlowMemory\flowmemory-live-bridge-relayer`
Branch: `agent/live-product-base8453-bridge`

Mission: make the Base 8453 to FlowChain bridge relayer production-shaped. It
must observe configured lockbox deposits, wait the configured finality depth,
dedupe by source chain/contract/tx/log, create canonical bridge observations,
and submit credits to the FlowChain runtime.

Read first:
- `services/bridge-relayer/`
- `contracts/bridge/`
- `infra/scripts/bridge-base-mainnet-pilot-observe.ps1`
- `infra/scripts/flowchain-live-l1-bridge-e2e.ps1`
- `fixtures/bridge/base8453-runtime-bridge-handoff.json`

Own:
- Base 8453 event observation
- finality/confirmation policy
- lockbox and token config validation
- replay protection
- runtime credit handoff/submission

Build requirements:
1. Remove hard-coded UI pilot caps from the product path. Use explicit operator
   environment policy and fail closed when not configured.
2. Support native ETH and configured ERC-20 assets with exact smallest-unit
   accounting.
3. No mock path can be labeled live. Every artifact must state mock, local,
   Base Sepolia, or Base 8453.
4. Observation must never need private keys.
5. Runtime credit submission must be idempotent.
6. Bridge status must say whether the deposit is observed, confirmed, credited,
   spendable, or rejected.
7. Add diagnostics for user-supplied tx hashes.

Commands:
- `npm test --prefix services/bridge-relayer`
- `npm run flowchain:bridge:diagnose:tx -- <tx>`
- `npm run flowchain:bridge:observe:base8453`
- `npm run flowchain:live-l1-bridge:e2e`

Acceptance gates:
- A configured Base 8453 deposit can be observed from RPC.
- Confirmation depth is configurable and reported.
- Duplicate logs do not double credit.
- Credit amount equals source amount exactly.
- Missing env returns exact names and does not pretend readiness.

