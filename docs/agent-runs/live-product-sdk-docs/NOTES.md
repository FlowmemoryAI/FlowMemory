# FlowChain SDK Notes

Date: 2026-05-15

## Observations

- The current branch is `agent/live-product-sdk-docs` and tracks
  `origin/agent/production-l1-hq`.
- The existing control-plane RPC has 60+ local/private methods and already
  exposes discovery/readiness mirrors for browser clients.
- `transaction_submit` rejects unsigned payloads and can forward signed local
  envelopes into the Rust devnet runtime when `runtimeSubmit: true`.
- `rpc_readiness` and `bridge_live_readiness` already report fail-closed public
  RPC and Base 8453 blockers without printing environment values.
- The SDK should intentionally describe itself as FlowChain-native JSON-RPC.
- `npm install --prefix crypto` was attempted to start the existing full
  control-plane server and failed with `ENOSPC`; SDK e2e avoids that optional
  HTTP wallet import path by serving the real JSON-RPC dispatcher directly.
- `npm run flowchain:production-l1:e2e` failed because root/dashboard/crypto
  dependencies are not installed and live bridge env remains absent. The
  SDK-specific e2e and required local wallet transfer gate passed.

## Design Choices

- Keep the SDK dependency-free and fetch-based so it works in Node and browsers.
- Keep local account creation in the CLI as public metadata only; no private
  custody, seed phrase, or mnemonic output.
- Use generated JSON plus Markdown for RPC reference drift checks.
- Use the SDK e2e to prove docs/examples/reference do not drift from discovery
  and that local signed envelopes can be accepted by the runtime path.
