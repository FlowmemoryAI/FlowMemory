/goal You are the FlowChain wallet, key, and signing agent.

Worktree: `E:\FlowMemory\flowmemory-live-wallet-keys`
Branch: `agent/live-product-wallet-keys`

Mission: make the FlowChain wallet a real account/key/signing system used by
the desktop/mobile wallet and runtime. Build on `crypto/` and the existing
wallet metadata/vault code.

Read first:
- `crypto/src/wallet.js`
- `crypto/src/wallet-cli.js`
- `crypto/src/transactions.js`
- `crypto/src/wallet-documents.js`
- `services/control-plane/src/server.ts`
- `apps/dashboard/src/views/WalletView.tsx`

Own:
- encrypted vault create/unlock/import/export/backup/recovery
- public account metadata
- transaction signing for transfer, bridge credit ack, withdrawal intent, swap,
  token launch, liquidity, and emergency controls
- runtime signature verification contract

Build requirements:
1. Wallet creation must produce a FlowChain account address usable by bridge,
   transfer, receive, and explorer views.
2. The UI must never display or return private keys. Recovery export must be an
   explicit encrypted backup flow.
3. Add import existing vault, backup vault, restore vault, rotate account, and
   account switch flows.
4. Add signing for runtime transfer and runtime swap, not only vector files.
5. Add nonce tracking tied to runtime accepted transactions.
6. Add negative tests for wrong chain, wrong domain, wrong nonce, expired
   envelope, duplicate tx, wrong signer, mutated payload, and malformed public
   key.
7. Provide CLI and API surfaces that other agents can call without importing
   secret-handling code.

Commands:
- `npm test --prefix crypto`
- `npm run wallet:e2e --prefix crypto`
- `npm run wallet:pilot-e2e --prefix crypto`
- `npm run flowchain:wallet:e2e`

Acceptance gates:
- A wallet-created account can receive a bridge credit and then sign/spend it.
- Runtime rejects unsigned or incorrectly signed wallet transactions when
  signature enforcement is enabled.
- Public metadata contains no secret-shaped fields.
- Desktop wallet can create, restore, receive, send, view activity, and backup.

