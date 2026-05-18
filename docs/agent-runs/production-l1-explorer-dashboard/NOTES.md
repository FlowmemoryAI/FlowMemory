# FlowChain L1 Pilot Explorer Dashboard Notes

## Initial Context

- Current repo state says dashboard V0 already has product-testnet wallet, token, DEX, explorer, and capped owner-testing bridge pilot surfaces.
- Current control-plane docs already define local JSON-RPC methods and HTTP mirrors for health, state, explorer summary, product flow, pilot status, bridge observations, and raw JSON.
- The task requires making those surfaces complete and owner-inspectable from the existing dashboard/API, with deterministic fallback data labeled by provenance.

## Open Runtime Dependencies

- Resolved locally by reconciling this branch with `origin/main`, where the dedicated contract, bridge-relayer, and runtime proof gates have landed.
- The merge was left uncommitted in this worktree.

## Outcome Notes

- Control-plane search and fallback-backed token/DEX/bridge records are visible through the existing API.
- Browser verification passed on desktop and mobile after fixing React record-key collisions and mobile switcher clipping.
- `npm run flowchain:l1-e2e` passed.
- `npm run flowchain:real-value-pilot:e2e` passed with empty `missingProofs` and `ownerGoNoGo.go: true`.
