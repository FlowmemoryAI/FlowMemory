# FlowChain Developer Guides

These guides describe the current FlowChain-native developer surface. They are
local/private unless a readiness command says the public RPC, backup, bridge,
and external tester gates have passed.

- `FLOWCHAIN_QUICKSTART.md`: clean-checkout local RPC and wallet transfer path.
- `FLOWCHAIN_WALLET_INTEGRATION.md`: account IDs, wallet metadata, send flow,
  and no-custody boundaries.
- `FLOWCHAIN_BRIDGE_INTEGRATION.md`: Base 8453 pilot inputs, exact-credit
  accounting, replay protection, caps, and blocked-owner-input behavior.
- `FLOWCHAIN_NODE_OPERATOR.md`: service commands, public RPC deployment
  boundary, backups, monitoring, and incident drills.
- `FLOWCHAIN_APP_BUILDER.md`: SDK, CLI, Node.js/Python examples, browser
  readiness example, and activity/bridge panels.
- `FLOWCHAIN_EXPLORER_INDEXER.md`: block, transaction, account, finality,
  provenance, and bridge lookup methods.
- `FLOWCHAIN_FAUCET_TESTER_FUNDS.md`: local no-value faucet/test allocation
  rules and friends-and-family funding boundaries.
- `FLOWCHAIN_RELEASE_COMPATIBILITY.md`: SDK/RPC/version compatibility and
  generated reference update command.
- `FLOWCHAIN_TROUBLESHOOTING.md`: common runtime, RPC, wallet, bridge, backup,
  public endpoint, and docs drift failures.

Machine check:

```powershell
npm run flowchain:tester:gateway:e2e
npm run flowchain:dev-pack:e2e
```
