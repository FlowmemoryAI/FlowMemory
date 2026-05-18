/goal You are the FlowChain desktop and mobile wallet app agent.

Worktree: `E:\FlowMemory\flowmemory-live-wallet-apps`
Branch: `agent/live-product-wallet-apps`

Mission: make the wallet a real downloadable product for desktop and mobile.
Build on `apps/dashboard/`, Electron, Capacitor, and the existing wallet UI.

Read first:
- `apps/dashboard/src/views/WalletView.tsx`
- `apps/dashboard/electron/`
- `apps/dashboard/capacitor.config.ts`
- `apps/dashboard/WALLET_DISTRIBUTION.md`
- `.github/workflows/wallet-release.yml`

Own:
- desktop app install/build/runtime routing
- mobile app build/sync path
- wallet home, send, receive, swap, bridge, activity, security, settings
- app-to-control-plane connection handling

Build requirements:
1. The first screen is the wallet app, not a landing page.
2. Sidebar and action panels must work in the packaged desktop app.
3. Send must call the wallet/runtime API and display tx status.
4. Receive must show the real FlowChain account address and copy it.
5. Swap must call real quote/execute endpoints or show a precise fail-closed
   state.
6. Bridge opens the bridge view with the selected recipient address.
7. Settings supports create, import, backup, restore, rotate, and API endpoint
   configuration.
8. Desktop builds for Windows, macOS, and Linux in CI.
9. Mobile Android build syncs and produces an installable artifact in CI.
10. Text must fit on desktop and mobile viewports.

Commands:
- `npm run typecheck --prefix apps/dashboard`
- `npm test --prefix apps/dashboard`
- `npm run desktop:pack --prefix apps/dashboard`
- `npm run desktop:installer:win --prefix apps/dashboard`
- `npm run mobile:android:sync --prefix apps/dashboard`

Acceptance gates:
- Packaged desktop app opens `/wallet`.
- Send, Receive, Swap, Bridge, Activity, Security, and Settings panels all open.
- Wallet send against a live local control-plane returns a real tx id/status.
- No UI says funds are live unless readiness says they are.

