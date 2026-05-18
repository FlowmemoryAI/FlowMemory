# FlowChain Developer Ecosystem Dev Pack Goal

Status: copy-ready `/goal` prompt and reference benchmark for building the
developer ecosystem around the FlowChain L1. This is not proof of production
readiness. It is the work package for making the chain usable by builders,
testers, wallet integrators, node operators, bridge operators, and support
staff.

## Current Ecosystem Benchmark

Mature chain ecosystems expose more than an RPC URL. Current official docs show
the baseline:

- Ethereum developer docs cover blocks, EVM, gas, nodes, local development
  networks, development frameworks, client APIs, block explorers, smart contract
  security, and formal verification.
  Source: https://ethereum.org/developers/docs/
- Ethereum network docs pair testnets with explicit resources, explorers,
  faucets, staking or app-development purpose, and warnings about not reusing
  mainnet and testnet accounts.
  Source: https://ethereum.org/developers/docs/networks/
- Solana developer tools include CLI tools, JavaScript, React, Rust, Python,
  Go, and Java SDKs, commerce packages, devnet faucets, and infrastructure
  links.
  Source: https://solana.com/docs/payments/developer-tools
- Cosmos SDK documents chain interfaces as CLI, gRPC, REST, and CometBFT RPC,
  with each interface mapped to its best developer or operator use case.
  Source: https://docs.cosmos.network/sdk/next/learn/concepts/cli-grpc-rest
- Polygon publishes network details with chain id, gas token, RPC, WSS, block
  explorer, faucet, gas station, and public or paid RPC providers.
  Source: https://docs.polygon.technology/pos/reference/rpc-endpoints
- Polygon node operator docs call out port exposure boundaries and say metrics
  ports should only be opened to monitoring systems, while RPC ports should be
  opened only if necessary.
  Source: https://docs.polygon.technology/pos/how-to/prerequisites
- Optimism bridge docs provide package-based bridging examples, testnet funding
  steps, and safety framing around bridge helper libraries.
  Source: https://docs.optimism.io/app-developers/tutorials/bridging/cross-dom-bridge-erc20

The FlowChain dev pack therefore needs to prove a complete ecosystem, not just
prose:

- Public and private RPC contracts with discovery, readiness, allowlists, and
  examples.
- SDKs or generated clients for the first supported language, then a matrix for
  future languages.
- CLI/devkit for developers and operators.
- Wallet creation, account backup/import guidance, and no-custody signing
  boundaries.
- Faucet or pilot allocation flow for local/tester use, with caps and abuse
  limits.
- Explorer/indexer docs and APIs for blocks, transactions, balances, bridge
  events, and finality.
- Bridge guides for Base 8453 pilot inputs, confirmations, replay protection,
  exact credit accounting, and blocked-owner-input behavior.
- Node operator guide for start/stop/restart, public RPC, TLS, CORS, rate
  limiting, backups, monitoring, incident drills, and recovery.
- Example applications that run against the real local RPC.
- Version compatibility and release docs.
- Troubleshooting docs that match real failure modes.
- Machine-checkable docs and examples so the developer surface cannot drift
  away from the runtime.

## /goal Prompt: Developer Ecosystem Dev Pack Worker

```text
/goal FlowChain Developer Ecosystem Dev Pack

Build the complete developer ecosystem pack for FlowChain so a real developer
can start from a clean checkout, run the local L1, create or connect a wallet,
query blocks, send a wallet-to-wallet transaction, inspect the transaction in
an explorer/indexer surface, understand bridge readiness, and build a small app
against the actual FlowChain RPC.

You are not alone in the codebase. Do not revert edits made by others. Own the
developer ecosystem surface only, and integrate with the real runtime, control
plane, bridge, wallet, explorer, backup, and public RPC contracts already in
the repository. Do not create a fake SDK or docs-only happy path.

Likely write scope:
- `docs/developer/`
- `docs/sdk/`
- `docs/agent-runs/live-product-dev-pack/`
- `examples/flowchain-*`
- `tools/flowchain-*`
- SDK package directory selected from existing repo conventions
- CLI/devkit package directory selected from existing repo conventions
- Root `package.json` only for dev-pack scripts
- Generated RPC reference outputs
- No wallet private-key custody internals unless required to call existing safe
  wallet APIs

Do not own:
- Consensus/runtime state-transition redesign
- Bridge relayer accounting internals
- Public deployment secrets
- Owner env values
- Dashboard redesign
- Live Base 8453 broadcasting

Research baseline:
1. Read the current official docs benchmark in
   `docs/agent-goals/production-l1-live-chain/17-developer-ecosystem-dev-pack.md`.
2. Treat Ethereum, Solana, Cosmos, Polygon, and Optimism as ecosystem shape
   references, not as claims that FlowChain is equivalent.
3. Translate those references into FlowChain-native deliverables that are
   honest about the current local/private versus owner-configured public
   boundary.

Inventory first:
1. Read `AGENTS.md`.
2. Read `docs/agent-goals/production-l1-live-chain/README.md`.
3. Read `docs/FLOWCHAIN_CONTROL_PLANE_API.md`.
4. Read `docs/FLOWCHAIN_PRODUCTION_L1_GO_NO_GO.md`.
5. Read `docs/FLOWCHAIN_LIVE_L1_BRIDGE_GO_NO_GO.md`.
6. Read `docs/OPERATIONS/FLOWCHAIN_OWNER_OPERATED_PUBLIC_RPC.md`.
7. Read `services/control-plane/src/methods.ts`.
8. Read `services/control-plane/src/server.ts`.
9. Read `services/control-plane/src/types.ts`.
10. Read `services/control-plane/src/rpc-e2e.ts`.
11. Read `services/control-plane/src/wallet-runtime.ts`.
12. Read `services/bridge-relayer/README.md`.
13. Read `infra/scripts/flowchain-*.ps1` enough to identify the real commands.
14. Read `package.json` scripts.
15. Produce `docs/agent-runs/live-product-dev-pack/INVENTORY.md` classifying
    each ecosystem surface as `implemented`, `partial`, `fixture-only`,
    `blocked-owner-input`, or `missing`.

Build the SDK:
1. Add a typed FlowChain JSON-RPC client over the real `/rpc` endpoint.
2. Support `rpc_discover` and `rpc_readiness`.
3. Support read helpers for health, chain status, finality, blocks,
   transactions, mempool, accounts, balances, wallet metadata, wallet balances,
   transfer history, bridge readiness, bridge deposits, bridge credits,
   withdrawals, release evidence, lifecycle records, and public deployment
   status.
4. Add write helpers only for existing runtime-backed signed transaction paths.
   Do not write static rows or call fixture files while claiming live behavior.
5. Export stable types for JSON-RPC envelopes, readiness results, status codes,
   block summaries, transaction details, wallet metadata, balances, bridge
   lifecycle records, public RPC deployment status, and tagged errors.
6. Add redaction for error messages, logs, diagnostics, and examples. The SDK
   must not print private keys, seed phrases, mnemonics, RPC credentials, API
   keys, webhooks, vault ciphertext, or raw owner env values.
7. Add tagged errors for missing live config, RPC unreachable, method blocked,
   method unavailable, malformed envelope, unsigned envelope, replay rejected,
   transaction not final, bridge not ready, account not found, insufficient
   balance, and stale chain height.

Build the CLI/devkit:
1. Add commands for:
   - discover RPC
   - print readiness
   - print chain status
   - watch block height
   - list blocks
   - get block
   - list transactions
   - get transaction
   - list accounts
   - get account
   - get balance
   - list wallet metadata
   - list wallet transfers
   - submit a documented local signed transfer or existing wallet-send path
   - wait for transaction inclusion
   - print bridge readiness
   - print bridge credit status
   - export public-safe diagnostics
2. Commands must default to `http://127.0.0.1:8787/rpc`.
3. Commands must support `--json`.
4. Commands that require public RPC or Base 8453 owner inputs must fail closed
   and print missing variable names only.
5. Commands must never bind a public endpoint or broadcast live bridge
   transactions by accident.

Build the docs:
1. Developer quickstart:
   - prerequisites
   - install
   - start local FlowChain L1
   - verify control-plane/RPC health
   - discover RPC methods
   - create or connect a local wallet safely
   - submit a wallet-to-wallet transfer
   - wait for block inclusion
   - query balances
   - view transaction history
   - inspect finality
   - stop/restart and verify continuity
2. RPC reference:
   - generated from or checked against `rpc_discover`
   - includes method safety class: public read, private admin, local write,
     blocked owner input, or unsupported
   - includes examples for every public read method
3. Wallet integration:
   - account/address shape
   - signing envelope shape
   - send and receive flow
   - backup/import boundaries
   - nonce and replay rules
   - no server-side custody rule
   - diagnostics redaction
4. Bridge integration:
   - Base 8453 inputs
   - lockbox/token/decimals/chain-id checks
   - confirmations and reorg handling expectations
   - exact credit accounting
   - replay protection
   - caps and emergency stop
   - local/mock versus owner-configured-live boundary
5. Node operator:
   - local start/stop/restart/status
   - live profile
   - public RPC deployment prerequisites
   - TLS, CORS, rate limits, body limits, and method allowlists
   - backup path, backup creation, restore rehearsal, retention
   - monitoring, incidents, and recovery
6. App builder:
   - Node.js SDK example
   - browser/Vite/React example if supported
   - balance widget
   - transfer flow
   - bridge readiness panel
   - activity list
7. Explorer/indexer:
   - block lookup
   - transaction lookup
   - account lookup
   - balance history
   - bridge event lookup
   - stale data detection
8. Faucet/tester funds:
   - local no-value faucet or pilot allocation flow
   - caps
   - abuse limits
   - audit logs
   - why production funds stay blocked until owner gates pass
9. Release and compatibility:
   - SDK versioning
   - RPC method versioning
   - node/wallet/explorer/SDK compatibility matrix
   - breaking change policy
   - generated reference update command
10. Troubleshooting:
    - RPC connection refused
    - control plane stopped
    - local chain not advancing
    - public RPC env missing
    - public method rejected
    - bridge blocked on Base 8453 inputs
    - backup path missing
    - stale report
    - no-secret scan failure

Build examples:
1. Node.js example that calls discovery/readiness, reads height, submits or
   exercises the real local wallet-send path, waits for inclusion, and reads
   balances.
2. Browser or Vite example if the repo can support it without inventing a new
   app architecture.
3. Bridge-readiness example that proves fail-closed live behavior without
   printing env values.
4. Public RPC read-only example that refuses to run unless public deployment
   evidence is fresh and shareable.
5. Diagnostic export example that proves secret redaction.

Build verification:
1. Add root command `npm run flowchain:dev-pack:e2e`.
2. The command must start or attach to the local live profile safely.
3. It must call the SDK and CLI against the real control-plane `/rpc`.
4. It must verify `rpc_discover` against the generated RPC reference.
5. It must verify readiness stays blocked for owner inputs when env values are
   absent.
6. It must prove block height advances over a short window.
7. It must prove wallet balance and transfer-history reads work.
8. It must run at least one SDK example and one CLI command with `--json`.
9. It must scan generated docs, examples, logs, and diagnostics for secrets.
10. It must write:
    - `docs/agent-runs/live-product-dev-pack/DEV_PACK.md`
    - `docs/agent-runs/live-product-dev-pack/dev-pack-e2e-report.json`
    - `docs/agent-runs/live-product-dev-pack/HANDOFF.md`

Required commands before commit:
```powershell
npm run flowchain:dev-pack:e2e -- -AllowBlocked
npm run flowchain:public-rpc:validate
npm run flowchain:tester:readiness -- -AllowBlocked
npm run flowchain:no-secret:scan
node infra/scripts/check-unsafe-claims.mjs
git diff --check
```

Acceptance gates:
- Clean-checkout quickstart exists and is mechanically checked.
- SDK calls the real FlowChain JSON-RPC surface.
- CLI/devkit has JSON output and redacted diagnostics.
- RPC reference is generated from or checked against live discovery.
- Wallet, bridge, node operator, app builder, explorer, faucet/tester,
  troubleshooting, release, and compatibility docs exist.
- At least one real SDK example and one real CLI command run against local RPC.
- Public/live docs fail closed until owner inputs and public deployment gates
  pass.
- No generated artifact leaks secrets or raw owner env values.
- Handoff lists changed files, commands, reports, implemented surfaces, and
  remaining blockers.

Stop condition:
Commit and push only when a developer can use the dev pack to run local
FlowChain, connect to RPC, inspect height, inspect balances, submit or exercise
the real local wallet-send path, and lookup the resulting activity. Do not
claim public ecosystem readiness until public RPC, backup, bridge, and tester
packet gates pass with fresh evidence.
```

## How This Fits The Nightly Loop

After the current public RPC, bridge, backup, and completion-audit repairs are
committed, this worker should become a top-level autonomous loop item. It is
token-expensive because it crosses SDK, CLI, docs, examples, live RPC,
wallets, explorer/indexer, bridge readiness, no-secret scanning, and release
gates.
