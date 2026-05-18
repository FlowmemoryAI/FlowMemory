/goal You are the FlowChain bridge credit, withdrawal, and release evidence
agent.

Worktree: `E:\FlowMemory\flowmemory-live-bridge-credit`
Branch: `agent/live-product-bridge-credit-withdrawal`

Mission: finish the local side of the bridge: convert relayer observations into
runtime credits, make them spendable, support withdrawal intent, and export
release evidence without pretending unaudited release authority is ready.

Read first:
- `crates/flowmemory-devnet/`
- `services/control-plane/src/pilot.ts`
- `infra/scripts/flowchain-real-value-pilot-runtime.ps1`
- `infra/scripts/flowchain-bridge-release-evidence.ps1`
- `schemas/flowmemory/bridge-*.schema.json`

Own:
- credit application transaction type
- replay index and receipt IDs
- withdrawal intent objects
- release evidence export
- exact value lifecycle records

Build requirements:
1. Bridge credit must create or map the destination FlowChain account and asset.
2. Wallet balance must show the exact credited amount.
3. Credited funds must be transferable by the wallet.
4. Withdrawal intent must consume or reference the credited balance safely.
5. Release evidence must include source deposit, credit, withdrawal intent,
   destination recipient, amount, asset, replay key, and status.
6. No release broadcast occurs unless a separate explicit release authority path
   exists and the final verification gate enables it.
7. Bridge lifecycle records must compare deposit amount, credit amount,
   wallet balance delta, transfer amount, withdrawal amount, and release amount.

Commands:
- `npm run flowchain:real-value-pilot:runtime`
- `npm run flowchain:bridge:withdraw:intent`
- `npm run flowchain:bridge:release:evidence`
- `npm run control-plane:smoke`

Acceptance gates:
- Credit application is idempotent.
- Credit survives restart/export/import.
- Spend after credit is visible in wallet and explorer.
- Withdrawal evidence is complete and no-secret.

