# FlowChain SDK / Docs / Devkit Plan

Date: 2026-05-15

## Scope

Build the developer-facing FlowChain surface without claiming production or public
L1 readiness. The SDK and examples must use the real FlowChain-native
JSON-RPC `/rpc` control-plane surface and must fail closed for public RPC and
Base 8453 bridge paths when owner/operator inputs are absent.

## Ordered Work

1. Inventory the existing control-plane RPC, runtime wrapper scripts, wallet
   dashboard expectations, and bridge readiness boundaries.
2. Add a browser-safe and Node-usable SDK package over the real JSON-RPC
   methods.
3. Add typed errors, transaction-envelope validation, and strict redaction.
4. Add focused SDK unit tests.
5. Add a local devkit CLI with JSON output and loopback defaults.
6. Add runnable Node and browser/Vite-shaped examples that import the SDK.
7. Add a generated or mechanically checked RPC reference from `rpc_discover`.
8. Add developer docs only after the runnable path exists.
9. Add `npm run flowchain:sdk:e2e` to start or attach to local RPC, submit a
   signed local envelope, produce a block, verify reads, run CLI/examples, check
   docs/reference drift, and write the report.
10. Run the required command set and record exact gaps in `HANDOFF.md`.

## Source Contracts

- Control-plane RPC: `services/control-plane/src/methods.ts`
- JSON-RPC transport: `services/control-plane/src/json-rpc.ts`
- RPC server and browser-safe mirrors: `services/control-plane/src/server.ts`
- Runtime transaction path: `transaction_submit` with `runtimeSubmit: true`
- Local runtime: `crates/flowmemory-devnet/`
- Existing production/live blockers:
  - `FLOWCHAIN_RPC_PUBLIC_URL`
  - `FLOWCHAIN_RPC_ALLOWED_ORIGINS`
  - `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`
  - `FLOWCHAIN_RPC_TLS_TERMINATED`
  - `FLOWCHAIN_RPC_STATE_BACKUP_PATH`
  - `FLOWCHAIN_PILOT_OPERATOR_ACK`
  - `FLOWCHAIN_BASE8453_RPC_URL`
  - `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`
  - `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`
  - `FLOWCHAIN_BASE8453_ASSET_DECIMALS`
  - `FLOWCHAIN_BASE8453_FROM_BLOCK`
  - `FLOWCHAIN_BASE8453_TO_BLOCK`
  - `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`
  - `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`
  - `FLOWCHAIN_PILOT_CONFIRMATIONS`

## Inventory

| Requirement | Status | Evidence / note |
| --- | --- | --- |
| Real `/rpc` discovery/readiness | implemented | `rpc_discover`, `rpc_readiness`, `GET /rpc/discover`, `GET /rpc/readiness` exist. |
| Runtime-backed signed local transaction submit | implemented | `transaction_submit` supports `runtimeSubmit: true` and direct Rust state queueing. |
| Browser-safe discovery/readiness | implemented | Control-plane server exposes CORS-enabled GET mirrors. |
| SDK package | missing | Add `packages/flowchain-sdk/`. |
| CLI/devkit command group | missing | Add `tools/flowchain-devkit.mjs`. |
| Generated or checked RPC reference | missing | Add generator/check script and generated markdown/JSON. |
| Node example | missing | Add `examples/flowchain-node-local/`. |
| Browser/Vite example | missing | Add `examples/flowchain-browser-vite/`. |
| Bridge readiness example | missing | Add `examples/flowchain-bridge-readiness/`. |
| Wallet-send example | missing | Add `examples/flowchain-wallet-send/`. |
| Developer quickstart | missing | Add `docs/developer/quickstart.md`. |
| Wallet integration docs | missing | Add `docs/developer/wallet-integration.md`. |
| Bridge integration docs | missing | Add `docs/developer/bridge-integration.md`. |
| Node operator docs | missing | Add `docs/developer/node-operator.md`. |
| App builder docs | missing | Add `docs/developer/app-builder.md`. |
| Release/versioning docs | missing | Add `docs/sdk/release-versioning.md`. |
| Troubleshooting docs | missing | Add `docs/developer/troubleshooting.md`. |
| SDK e2e root command | missing | Add `npm run flowchain:sdk:e2e`. |
| SDK unit tests | missing | Add `npm test --prefix packages/flowchain-sdk`. |
| Public/live bridge readiness | blocked | Owner env/deployment inputs absent by design; fail closed only. |

## Non-Goals

- Do not add EVM JSON-RPC compatibility claims.
- Do not add wallet custody or private-key server handling.
- Do not add live bridge broadcasts.
- Do not edit runtime internals except through documented SDK/example usage.
