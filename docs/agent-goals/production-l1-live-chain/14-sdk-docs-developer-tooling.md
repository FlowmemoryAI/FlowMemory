/goal You are the FlowChain SDK, documentation, and developer tooling agent.

Worktree: `E:\FlowMemory\flowmemory-live-sdk-docs`
Branch: `agent/live-product-sdk-docs`

Mission: build the developer-facing surface needed for FlowChain to be usable
as a real L1 product by wallet builders, app builders, bridge operators, node
operators, and FlowChain maintainers. Do not stop at prose. Build runnable SDK
examples, typed RPC clients, CLI/devkit commands, generated references, sample
apps, and machine-checkable docs tests that prove the docs match the actual
runtime/RPC/bridge/wallet behavior.

You are not alone in the codebase. Other agents may be changing runtime,
wallet, bridge, control-plane, dashboard, storage, and verification files. Do
not revert their edits. Integrate with the existing control-plane/RPC/runtime
contracts and avoid creating a parallel fake SDK or a docs-only surface.

Read first:
- `AGENTS.md`
- `docs/agent-goals/production-l1-live-chain/README.md`
- `docs/FLOWCHAIN_CONTROL_PLANE_API.md`
- `docs/FLOWCHAIN_PRODUCTION_L1_GO_NO_GO.md`
- `docs/FLOWCHAIN_LIVE_L1_BRIDGE_GO_NO_GO.md`
- `services/control-plane/src/methods.ts`
- `services/control-plane/src/json-rpc.ts`
- `services/control-plane/src/types.ts`
- `services/control-plane/src/rpc-e2e.ts`
- `crates/flowmemory-devnet/`
- `infra/scripts/flowchain-*.ps1`
- `apps/dashboard/WALLET_DISTRIBUTION.md`
- `apps/dashboard/src/views/WalletView.tsx`
- `apps/dashboard/src/views/BridgePilotView.tsx`
- `package.json`

Own these files/modules unless coordination requires otherwise:
- `docs/agent-runs/live-product-sdk-docs/`
- `docs/developer/`
- `docs/sdk/`
- `examples/flowchain-*`
- `tools/flowchain-*`
- `packages/flowchain-sdk/` or the repo's established package location if one
  already exists
- root `package.json` only for SDK/docs/devkit scripts

Do not own:
- runtime state transition internals except documented examples and type usage
- bridge relayer implementation except SDK/readme integration examples
- wallet private-key custody implementation except documented local-only signing
  interfaces and safe client types
- dashboard redesign
- live env values, private keys, seed phrases, RPC credentials, API keys,
  webhooks, or vault ciphertext

Required product standard:
A developer starting from a clean checkout must be able to read the docs, start
a local FlowChain node/RPC, create a local account with the documented wallet
tooling, submit a signed FlowChain transaction through the SDK, query blocks,
transactions, balances, token/DEX state, bridge readiness, bridge credits, and
finality, and run a sample app against local RPC. If a live public RPC or live
Base 8453 bridge dependency is unavailable, the SDK and docs must fail closed
with exact missing variable or deployment artifact names only.

SDK requirements:
1. Build a typed FlowChain JSON-RPC client that uses the real `/rpc` surface.
2. Support browser-safe and Node.js usage where practical.
3. Expose discovery and readiness helpers:
   - `rpc_discover`
   - `rpc_readiness`
   - browser-safe `GET /rpc/discover`
   - browser-safe `GET /rpc/readiness`
4. Expose read helpers for:
   - health and node status
   - chain status and finality
   - block list/get
   - transaction list/get
   - mempool list
   - account list/get
   - balance get
   - wallet metadata and wallet balances
   - transfer history
   - token/asset state
   - DEX pools, swaps, and LP positions
   - bridge readiness, deposits, credits, withdrawals, release evidence, and
     lifecycle records
5. Expose write helpers only when they submit signed envelopes through the real
   runtime-backed RPC path. Do not add methods that write draft rows or static
   fixtures while claiming live behavior.
6. Model signed transaction envelopes, receipts, status codes, error codes, and
   fail-closed readiness responses as stable exported types.
7. Add a strict redaction layer for logs and errors so SDK examples cannot print
   private keys, seed phrases, mnemonics, RPC credentials, API keys, webhooks,
   vault ciphertext, or raw env values.
8. Add typed error classes or tagged errors for:
   - missing live config
   - RPC unreachable
   - RPC method unavailable
   - malformed envelope
   - unsigned envelope
   - replay rejection
   - not-final transaction
   - bridge not ready
   - account not found
   - insufficient balance
9. Do not call the SDK EVM-compatible unless EVM JSON-RPC compatibility is
   implemented and tested. If the SDK is FlowChain-native JSON-RPC, say so.

CLI/devkit requirements:
1. Add a documented command group for local developers, for example:
   - discover RPC
   - print readiness
   - print chain status
   - create local dev account metadata without leaking secrets
   - submit a documented local signed transfer fixture or generated envelope
   - wait for block inclusion
   - print balance
   - print bridge readiness
   - print bridge credit lifecycle
   - print finality status
2. Commands must default to `127.0.0.1` local RPC and never expose a public bind
   or live bridge path by accident.
3. Commands that use live Base 8453 or public RPC must require explicit env and
   fail closed if any input is missing.
4. Add `--json` output for automation.
5. Add examples that can be copied into docs without hand editing.

Documentation requirements:
1. Create a developer quickstart that starts from a clean checkout:
   - prerequisites
   - install
   - start local node/RPC
   - discover RPC
   - create/import a local account safely
   - submit a transaction
   - produce or wait for a block
   - query balances
   - inspect finality
   - stop/restart and verify continuity
2. Create an RPC reference generated from, or mechanically checked against, the
   actual `rpc_discover` method list. Do not maintain an unchecked hand-written
   list that can drift.
3. Create wallet integration docs:
   - address/account ID shape
   - signing envelope shape
   - receive address flow
   - send flow
   - activity query flow
   - backup/import boundaries
   - no server-side custody rule
4. Create bridge integration docs:
   - Base 8453 lockbox inputs
   - required env/deployment names
   - confirmations/finality expectations
   - exact-credit accounting
   - replay protection
   - withdrawal intent and release evidence
   - what is local/mock, what is configured-live, and what is blocked
5. Create node operator docs:
   - local node start/stop/restart
   - unbounded/live pilot node mode
   - public RPC prerequisites
   - TLS/CORS/rate-limit boundaries
   - state backup path
   - export/import/recovery
   - health checks and monitoring fields
6. Create app builder docs:
   - using the SDK from Node.js
   - using the SDK from browser/Vite/React if supported
   - sample balance widget
   - sample send transaction flow
   - sample bridge readiness panel
   - sample activity list
7. Create release and versioning docs:
   - SDK package versioning
   - compatibility with RPC method versions
   - breaking change policy
   - generated reference update command
8. Create troubleshooting docs:
   - failed to fetch
   - 404 on wallet creation or RPC path
   - missing public RPC env
   - bridge blocked on Base 8453 inputs
   - local node stopped/max-block bounded mode
   - stale dashboard or wrong endpoint

Examples and sample apps:
1. Add a minimal Node.js example that:
   - calls discovery/readiness
   - submits a local signed transaction or documented dev envelope
   - waits for block inclusion
   - reads the updated account balance
2. Add a minimal browser or Vite example if the repo structure supports it.
3. Add a bridge-readiness example that proves fail-closed live behavior without
   printing env values.
4. Add a wallet-send example that uses the real SDK client and real RPC method
   names.
5. Add sample output files only if they are generated by commands and clearly
   marked local/dev output.

Verification requirements:
1. Add a root command:
   ```powershell
   npm run flowchain:sdk:e2e
   ```
2. That command must:
   - start or attach to a local FlowChain node/RPC
   - call RPC discovery through the SDK
   - verify the generated RPC reference matches discovery
   - call readiness and verify public/live blockers when env is absent
   - submit a signed local transaction through the SDK
   - verify mempool visibility or accepted receipt
   - produce or wait for a block
   - read block, transaction, account, balance, finality, and provenance
   - run at least one CLI command with `--json`
   - run at least one sample app/example command
   - verify docs snippets or generated examples do not drift
   - run no-secret checks against SDK output, docs generated examples, and logs
3. Add focused unit tests for SDK request/response parsing, error handling,
   redaction, readiness blockers, and transaction envelope validation.
4. Add machine-readable report:
   `docs/agent-runs/live-product-sdk-docs/flowchain-sdk-e2e-report.json`
5. Add human handoff:
   `docs/agent-runs/live-product-sdk-docs/HANDOFF.md`

Implementation loop:
1. Create:
   - `docs/agent-runs/live-product-sdk-docs/PLAN.md`
   - `docs/agent-runs/live-product-sdk-docs/CHECKLIST.md`
   - `docs/agent-runs/live-product-sdk-docs/EXPERIMENTS.md`
   - `docs/agent-runs/live-product-sdk-docs/NOTES.md`
2. Inventory current docs/scripts/packages and mark each requirement as
   `implemented`, `missing`, `fixture-only`, `blocked`, or `needs-owner-input`.
3. Build the smallest real SDK client over the actual RPC surface first.
4. Add unit tests and a local example.
5. Add generated or checked RPC reference.
6. Add CLI/devkit commands.
7. Add docs only after the runnable path exists.
8. Run the command set below.
9. Update the checklist with command output paths and exact gaps.
10. Repeat until every requirement is implemented and verified or blocked by a
    precise external deployment input.

Commands to run before finishing:
```powershell
npm run flowchain:rpc:e2e
npm run flowchain:sdk:e2e
npm run flowchain:wallet:transfer:e2e
npm run flowchain:production-l1:e2e
npm run flowchain:no-secret:scan
node infra/scripts/check-unsafe-claims.mjs
git diff --check
```

Acceptance gates:
- `npm run flowchain:sdk:e2e` exists and passes locally.
- SDK/client uses the real FlowChain JSON-RPC surface, not static fixtures.
- SDK write examples submit signed envelopes through runtime-backed RPC.
- CLI/devkit commands have JSON output and fail closed for missing live config.
- RPC reference is generated from or checked against live discovery.
- Quickstart, wallet integration, bridge integration, node operator, app
  builder, release, and troubleshooting docs exist.
- Sample Node.js and browser/app examples exist or a documented unsupported
  reason is machine-checked.
- No docs, SDK output, logs, examples, or reports include secrets or raw env
  values.
- Public/live readiness remains blocked until public RPC and Base bridge inputs
  are configured and verified.
- Handoff includes exact changed files, commands run, report paths, remaining
  blockers, and integration instructions for the verification agent.

Stop condition:
Stop only when FlowChain has a runnable local SDK/devkit/docs path with
machine-checked references and examples, and every remaining live-only gap is
reported by exact missing env/deployment name. Do not mark FlowChain live-ready
only because docs or examples exist.
