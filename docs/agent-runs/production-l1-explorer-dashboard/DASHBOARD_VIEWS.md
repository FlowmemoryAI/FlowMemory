# Dashboard Views Proof

Existing app only: all work is in `apps/dashboard/`; no second dashboard was added.

Rendered views:

- Overview/node/API: node state, API state, latest height, finalized height, state root, peer count, pilot status, setup commands.
- Blocks: search/list/detail facts for height, hash, parent, state root, tx count, receipt/event counts.
- Transactions: tx ID, payload type, signer/account, nonce/status, block reference, receipt/error facts.
- Receipts / Events: receipt status plus event references by tx/account/token/pool/bridge when present.
- Accounts / Balances / Wallet Metadata: public account IDs, balances, public wallet metadata, no signing material.
- Tokens: token launches, token balances, token transfer history.
- DEX: pools, reserves, LP positions, liquidity actions, swap history.
- Bridge: Base chain `8453`, lockbox, deposit observations, credits, withdrawal intents, release evidence, duplicate replay rejection.
- Finality / Network: finalized objects, peers, sync state.
- Errors / Recovery: runtime/API/storage/bridge/wrong-chain/duplicate/build recovery references.
- Raw JSON: dashboard fixture, devnet state, bridge fixture, explorer fallback, and control-plane JSON.

Empty/degraded states:

- Empty sections show the expected endpoint and recovery command.
- Offline control-plane state remains visible via deterministic fallback records with provenance.
- Runtime/API/storage/bridge degraded states are visible in `Errors / Recovery`.
