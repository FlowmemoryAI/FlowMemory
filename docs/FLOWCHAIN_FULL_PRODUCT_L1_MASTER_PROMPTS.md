# FlowChain Full Product L1 Master Prompts

Status: master agent prompt pack for moving from the current private/local L1
testnet package to a usable product testnet with wallet, transactions, token
launch, DEX, explorer/workbench, and bridge test flow.

Last updated: 2026-05-13.

## Truth Boundary

The current merged stack is a private/local no-value L1-style testnet harness.
It proves the repo can run deterministic blocks, local state, crypto fixtures,
control-plane reads, bridge credit fixtures, hardware signals, and a workbench.

It is not yet the full product chain target:

- not a consumer-grade L1 network;
- not a production mainnet;
- not audited cryptography;
- not a real-funds Base mainnet bridge;
- not a complete wallet/DEX/token-launch product flow;
- not a DEX where users can trade real assets.

The next target is `FlowChain Product Testnet V1`: a local/testnet environment
that a non-technical user can install on another Windows computer and use to:

1. start a local node and API;
2. open the workbench;
3. create or import a local test wallet;
4. receive local test units through faucet or test bridge credit;
5. send transactions that are included in blocks;
6. launch a local test token;
7. create a DEX pool;
8. add/remove liquidity;
9. swap local test assets;
10. see blocks, transactions, token balances, pools, swaps, and bridge events in
    the explorer/workbench;
11. stop, restart, export, and import state without losing the local chain;
12. run one final command that proves the whole user flow works.

Real-funds bridge work must remain gated until there is a separately reviewed
security plan, audited contracts, deployment runbook, key-management plan,
monitoring plan, emergency pause plan, and loss-of-funds test matrix. Base
Sepolia or local Anvil bridge tests are acceptable now. Base mainnet should stay
read-only/canary until explicitly reviewed.

## Non-Negotiable Acceptance Gate

All agents are building toward this command:

```powershell
npm run flowchain:product-e2e
```

If the command does not exist yet, the integration/review agent must create it.
It must fail until every required product-testnet flow is implemented.

The final acceptance command must prove, from a clean-ish Windows checkout:

- dependency check passes;
- one-command setup works;
- local node starts and produces blocks;
- control-plane API is online;
- workbench opens;
- local wallet can be created, unlocked, and used to sign;
- faucet or test bridge credit funds an account;
- signed transfer is included in a block;
- local test token can be launched;
- DEX pool can be created;
- liquidity can be added;
- swap changes balances and creates a receipt;
- explorer/workbench can query the block, tx, token, pool, swap, and bridge
  records;
- export/import preserves deterministic state roots where expected;
- second-computer setup is documented and scriptable;
- no private keys or secret-shaped material is returned by public API routes;
- all docs clearly say this is local/testnet unless a production gate has been
  completed.

## Universal Agent Rules

Every agent must start with:

```powershell
cd E:\FlowMemory\<assigned-worktree>
git checkout main
git pull
git checkout -B <assigned-branch>
git status
```

Every agent must read the current repo before building:

- `AGENTS.md`
- `docs/START_HERE.md`
- `docs/CURRENT_STATE.md`
- `docs/ROADMAP.md`
- `docs/FLOWCHAIN_HQ_INTEGRATION_STATUS.md`
- `docs/FLOWCHAIN_FULL_PRIVATE_TESTNET.md`
- `docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md`
- `docs/FLOWCHAIN_SECOND_COMPUTER_SETUP.md`
- the files in its allowed folders

Every agent must build on top of existing code. Do not create duplicate apps,
duplicate runtimes, duplicate bridge services, duplicate wallet systems, or
parallel schemas when the repo already has a surface to extend.

Every agent must finish with:

```powershell
git status
git diff --check
```

If tests exist for the touched area, run them. If a needed test command does not
exist, add the smallest useful command and wire it into the product E2E gate.

Every PR must say:

- what user flow it unlocks;
- exact commands run;
- exact files/folders touched;
- what remains blocked;
- whether it changes any financial, cryptographic, or bridge risk.

## Prompt 1: HQ Integration Captain

Worktree: `E:\FlowMemory\flowmemory-review`

Branch: `agent/product-l1-integration-captain`

Allowed folders:

- `docs/`
- `infra/scripts/`
- `package.json`
- `.github/`

Forbidden folders:

- `contracts/`
- `crates/`
- `services/`
- `crypto/`
- `apps/dashboard/`
- `hardware/`

Prompt:

```text
/goal You are the FlowChain Product L1 Integration Captain.

The current repo has a private/local L1-style testnet package, but the target is
now FlowChain Product Testnet V1: a usable local/testnet chain that a
non-technical user can install on a second Windows computer and use end to end.

Do not build subsystem product code. Your job is to create the acceptance gate,
coordination map, and merge plan that forces all builders toward the same user
flow.

Read AGENTS.md and the FlowChain docs first. Then:

1. Create or update docs/FLOWCHAIN_PRODUCT_TESTNET_V1_ACCEPTANCE.md.
2. Define the exact user journey: install, start node, open workbench, create
   wallet, fund with faucet/test bridge credit, send transfer, launch token,
   create DEX pool, add liquidity, swap, inspect explorer, export/import state.
3. Add or update a root command `npm run flowchain:product-e2e`.
   - If subsystem pieces are missing, the command must fail clearly and name the
     missing owner.
   - Do not mark incomplete work as passing.
4. Add infra/scripts/flowchain-product-e2e.ps1 as the orchestrated final gate.
5. Update docs/FLOWCHAIN_HQ_INTEGRATION_STATUS.md so it no longer implies the
   current private/local package is the full user-facing L1.
6. Create a merge-order table for runtime, wallet, token/DEX, bridge,
   control-plane, dashboard, installer, and review.
7. Create exact follow-up prompts for any missing agents.

Acceptance:
- `git diff --check` passes.
- `npm run flowchain:product-e2e` exists.
- The command fails with actionable missing-coverage messages until all builder
  agents land their pieces.
- No product feature implementation is added outside docs/scripts/package
  orchestration.
```

## Prompt 2: Runtime And Chain Agent

Worktree: `E:\FlowMemory\flowmemory-chain`

Branch: `agent/product-l1-runtime`

Allowed folders:

- `crates/flowmemory-devnet/`
- `devnet/`
- `infra/scripts/flowchain-node*.ps1`
- `infra/scripts/flowchain-tx.ps1`
- `infra/scripts/flowchain-faucet.ps1`
- runtime-related docs under `docs/`

Forbidden folders:

- `apps/dashboard/`
- `contracts/`
- `services/bridge-relayer/`
- `crypto/` except read-only coordination

Prompt:

```text
/goal You are the FlowChain Runtime And Chain Agent.

Build on the existing Rust devnet. Do not replace it. Do not create a second
chain implementation.

Target: a local/testnet L1 runtime that can run continuously, include signed
transactions in blocks, maintain account balances, token balances, DEX state,
bridge credit state, and expose deterministic state summaries for the
control-plane and workbench.

Required user flows:
1. initialize genesis;
2. start a persistent local node loop;
3. create local account/balance state;
4. accept signed transactions from the existing inbox/intake path;
5. include transactions in blocks;
6. support local test-unit transfer;
7. support token launch transaction;
8. support DEX pool creation;
9. support add liquidity;
10. support remove liquidity;
11. support swap;
12. support bridge credit application from the bridge handoff;
13. produce queryable receipts for every transaction;
14. export/import state;
15. survive stop/restart.

Implementation constraints:
- Use existing `crates/flowmemory-devnet`.
- Keep everything local/testnet/no-value.
- Deterministic IDs and roots are required.
- The runtime must not know Base mainnet private keys or real bridge secrets.
- Add focused Rust tests for every new transaction type.

Acceptance:
- `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml` passes.
- `npm run flowchain:node:smoke` passes.
- Add a runtime-level product smoke command if needed.
- The chain produces receipts for transfer, token launch, pool create, add
  liquidity, swap, and bridge credit.
- Update the product E2E coverage handoff expected by the integration captain.
```

## Prompt 3: Wallet And Local Crypto Agent

Worktree: `E:\FlowMemory\flowmemory-crypto`

Branch: `agent/product-l1-wallet-crypto`

Allowed folders:

- `crypto/`
- `schemas/flowmemory/`
- wallet-related docs under `docs/`
- small package command wiring if required

Forbidden folders:

- `crates/flowmemory-devnet/` except read-only coordination
- `apps/dashboard/`
- `contracts/`
- `services/bridge-relayer/`

Prompt:

```text
/goal You are the FlowChain Wallet And Local Crypto Agent.

Build on the existing crypto package and local test vault. Do not create a
second wallet system.

Target: a local test wallet that can create/import accounts, unlock locally,
sign product-testnet transactions, export public metadata, never expose private
keys through public APIs, and support the full user flow needed by the runtime,
control-plane, and workbench.

Required transaction signing support:
- local test-unit transfer;
- token launch;
- DEX pool creation;
- add liquidity;
- remove liquidity;
- swap;
- bridge credit acknowledgement or withdrawal intent where applicable.

Required CLI support:
- create vault;
- unlock/check vault;
- list accounts;
- create account;
- show public metadata;
- sign transaction document;
- verify transaction envelope;
- rotate local test account if already supported safely.

Required schema/vector support:
- canonical JSON vectors for every signed transaction type;
- negative vectors for replay, wrong chain ID, wrong nonce, malformed signer,
  changed payload, changed domain, and wrong object type;
- no-secret scanner coverage for any public metadata export.

Acceptance:
- `npm test --prefix crypto` passes.
- `npm run validate:vectors --prefix crypto` passes.
- Add or update a wallet product-flow smoke command.
- The runtime/control-plane agents can consume the envelopes without custom
  parsing hacks.
```

## Prompt 4: Token Launch And DEX Agent

Worktree: `E:\FlowMemory\flowmemory-chain`

Branch: `agent/product-l1-token-dex`

Allowed folders:

- `crates/flowmemory-devnet/`
- `schemas/flowmemory/`
- `fixtures/`
- DEX/token docs under `docs/`

Forbidden folders:

- `apps/dashboard/` except read-only coordination
- `services/bridge-relayer/`
- production deployment scripts

Prompt:

```text
/goal You are the FlowChain Token Launch And DEX Agent.

Build token launch and DEX behavior into the existing local/testnet runtime.
Coordinate with the runtime agent instead of duplicating state models.

Target: a user can launch a local test token, create a DEX pool, add liquidity,
swap between local test units and the launched token, remove liquidity, and see
all resulting receipts/state changes.

Required state objects:
- token definition;
- token account balance;
- token launch receipt;
- pool definition;
- LP position;
- swap receipt;
- pool reserves;
- price/quote view;
- event/receipt objects that the explorer can query.

Required transaction types:
- LaunchToken;
- MintLocalTestToken or initial supply assignment;
- CreatePool;
- AddLiquidity;
- RemoveLiquidity;
- SwapExactIn.

Constraints:
- This is a local/testnet DEX, not production AMM infrastructure.
- Use deterministic integer math with explicit rounding rules.
- Reject zero amounts, missing pools, insufficient balances, duplicate token
  symbols/ids, and slippage violations.
- Do not introduce tokenomics or a real FlowChain coin sale.

Acceptance:
- Rust tests cover happy paths and all rejection cases.
- Product E2E can run: faucet/test credit -> launch token -> create pool -> add
  liquidity -> swap -> inspect balances and receipts.
- Explorer/control-plane handoff includes token, pool, and swap summaries.
```

## Prompt 5: Bridge Agent

Worktree: `E:\FlowMemory\flowmemory-bridge-full`

Branch: `agent/product-l1-test-bridge`

Allowed folders:

- `services/bridge-relayer/`
- `contracts/bridge/`
- `schemas/flowmemory/bridge*.json`
- `fixtures/bridge/`
- `infra/scripts/bridge-*.ps1`
- bridge docs under `docs/bridge/`

Forbidden folders:

- runtime internals except documented handoff files
- wallet private key handling
- production mainnet deployment

Prompt:

```text
/goal You are the FlowChain Test Bridge Agent.

Build a complete test bridge flow for Product Testnet V1. The bridge must let a
user test "bridge in" behavior without risking real funds.

Target flow:
1. local Anvil bridge smoke works end to end;
2. Base Sepolia observation works in read/write testnet mode only when explicit
   testnet env vars are present;
3. observed bridge deposits create deterministic bridge observations;
4. bridge observations create bridge credits;
5. bridge credits are handed to the local runtime;
6. runtime applies credits to a local account;
7. withdrawal intent can be created for a local test withdrawal path;
8. workbench/explorer can show bridge deposit, credit, and withdrawal status.

Mainnet rule:
- Do not broadcast Base mainnet transactions.
- Do not ask for or store mainnet private keys.
- Base mainnet support may be read-only canary only.
- Any real-funds bridge must remain blocked behind a separate audit and release
  issue.

Acceptance:
- `npm test --prefix services/bridge-relayer` passes.
- Local Anvil bridge smoke passes.
- Base Sepolia observation/testnet smoke is guarded by explicit env vars and
  cannot accidentally use mainnet.
- `npm run bridge:local-credit:smoke` passes.
- Product E2E can fund a local account through bridge credit.
```

## Prompt 6: Control Plane, Indexer, And Explorer API Agent

Worktree: `E:\FlowMemory\flowmemory-indexer`

Branch: `agent/product-l1-control-plane-explorer`

Allowed folders:

- `services/`
- `schemas/flowmemory/`
- API docs under `docs/`
- package command wiring if required

Forbidden folders:

- `apps/dashboard/` except read-only API coordination
- `contracts/` except read-only ABI/event coordination
- wallet secret storage

Prompt:

```text
/goal You are the FlowChain Control Plane, Indexer, And Explorer API Agent.

Build on the existing control-plane service. Do not create a second API server.

Target: the workbench and user can query everything needed for a usable local
testnet: health, blocks, transactions, receipts, accounts, balances, wallet
public metadata, tokens, token balances, DEX pools, liquidity positions, swaps,
bridge deposits, bridge credits, withdrawal intents, and runtime status.

Required API behavior:
- stable JSON-RPC methods for every product-testnet object;
- browser-safe `/health` and summary endpoints;
- transaction submission endpoint that accepts signed envelopes only;
- no private keys or secret-shaped fields in responses;
- helpful offline/error states for workbench;
- pagination or bounded lists for blocks/transactions/events.

Acceptance:
- `npm test --prefix services/control-plane` passes.
- `npm run control-plane:smoke` passes.
- Product E2E can use the API to verify the full wallet/token/DEX/bridge flow.
- Update docs/FLOWCHAIN_CONTROL_PLANE_API.md with exact methods and examples.
```

## Prompt 7: Workbench, Wallet UI, DEX UI, And Explorer Agent

Worktree: `E:\FlowMemory\flowmemory-dashboard`

Branch: `agent/product-l1-workbench-wallet-dex`

Allowed folders:

- `apps/dashboard/`
- dashboard docs under `docs/`

Forbidden folders:

- `crates/`
- `contracts/`
- `services/` except read-only API coordination
- wallet secret algorithms

Prompt:

```text
/goal You are the FlowChain Workbench, Wallet UI, DEX UI, And Explorer Agent.

Build on the existing dashboard/workbench. Do not create a separate frontend.

Target: a non-technical tester can open the workbench and complete the core
FlowChain Product Testnet V1 journey without using the terminal except to start
the stack.

Required screens/actions:
- node/API status with exact offline recovery commands;
- wallet setup status and public account view;
- local balance and token balance views;
- faucet/test bridge funding flow;
- send local test-unit transfer;
- launch local test token;
- create DEX pool;
- add/remove liquidity;
- swap;
- explorer views for blocks, transactions, receipts, accounts, tokens, pools,
  swaps, and bridge records;
- clear local/testnet boundary labels without claiming production readiness.

Constraints:
- Do not put private keys in browser localStorage.
- Any signing must use the existing local wallet/crypto flow or a clearly local
  development-only API.
- No real-funds bridge UI unless it is explicitly disabled by default and
  labeled as blocked.

Acceptance:
- `npm run build --prefix apps/dashboard` passes.
- Add component/data tests for the new views.
- Product E2E can verify that the workbench loads and shows the completed
  user-flow records.
```

## Prompt 8: Installer And Second Computer Agent

Worktree: `E:\FlowMemory\flowmemory-review`

Branch: `agent/product-l1-windows-installer`

Allowed folders:

- `infra/scripts/`
- `docs/`
- root `README.md`
- `package.json`

Forbidden folders:

- protocol/runtime implementation folders

Prompt:

```text
/goal You are the FlowChain Windows Installer And Second Computer Agent.

The target user is non-technical. Build the setup path so a second Windows
computer can install, start, stop, reset, update, and troubleshoot FlowChain
Product Testnet V1 with minimal manual work.

Required deliverables:
- one setup command after clone or bundle import;
- one start command;
- one stop command;
- one status command;
- one reset-local-testnet command;
- one update-from-bundle or update-from-GitHub path;
- clear detection for missing Git, Node, Rust, Foundry, Python, and MSVC tools;
- clear instructions when a browser login is not available;
- service startup that survives the launching shell where possible;
- logs stored in predictable local paths;
- docs/EASY_SECOND_COMPUTER_SETUP.md updated for Product Testnet V1.

Acceptance:
- Fresh second-computer runbook can be followed by a non-technical user.
- The product E2E gate runs after setup.
- Scripts are non-destructive by default and clearly label any reset action.
```

## Prompt 9: Research And RD Crypto Direction Agent

Worktree: `E:\FlowMemory\flowmemory-research`

Branch: `agent/product-l1-rd-crypto-direction`

Allowed folders:

- `research/`
- `docs/DECISIONS/`
- crypto architecture docs under `docs/`

Forbidden folders:

- product implementation folders unless documenting required interfaces

Prompt:

```text
/goal You are the FlowChain Research And RD Crypto Direction Agent.

Clarify how the RD cryptography library and prior FlowChain/Noesis/PolyFlow
research should shape Product Testnet V1 and later production work.

Do not implement production cryptography. Your job is to define what is safe for
the product testnet now, what is research-only, and what must be audited before
real funds or public mainnet use.

Deliverables:
- docs/DECISIONS/<date>-flowchain-product-testnet-crypto-boundary.md
- docs/DECISIONS/<date>-flowchain-private-state-roadmap.md
- research/FLOWCHAIN_CRYPTO_RESEARCH_INVENTORY.md

Required analysis:
- what the current crypto package actually does;
- what the RD library is intended to provide;
- what is novel versus standard;
- what can be safely represented in local/testnet fixtures;
- what must not be claimed as production-ready;
- how wallet signatures, object commitments, private-state proofs, bridge
  proofs, and DEX receipts should connect over time.

Acceptance:
- Docs are concrete enough for builder agents to avoid inventing incompatible
  crypto assumptions.
- No production-readiness claims are added.
```

## Prompt 10: Product E2E Reviewer

Worktree: `E:\FlowMemory\flowmemory-review`

Branch: `agent/product-l1-e2e-reviewer`

Allowed folders:

- `docs/reviews/`
- `infra/scripts/`
- `.github/`
- root package command wiring if needed

Forbidden folders:

- subsystem implementation folders unless adding review-only fixtures/scripts

Prompt:

```text
/goal You are the FlowChain Product E2E Reviewer.

Your job is to prove whether Product Testnet V1 is actually usable, not to
accept partial subsystem smoke tests.

Build or harden the final acceptance report around:
- fresh install/setup;
- node/API/workbench startup;
- wallet creation;
- faucet/test bridge funding;
- signed transfer;
- token launch;
- DEX pool creation;
- add liquidity;
- swap;
- explorer verification;
- export/import;
- stop/restart;
- no-secret public API scan;
- clear non-production boundary labels.

Do not mark the stack ready until the full product journey passes on a second
computer or clean environment.

Acceptance:
- `npm run flowchain:product-e2e` passes only when the full journey passes.
- A review report is written to docs/reviews/FLOWCHAIN_PRODUCT_TESTNET_V1_REVIEW.md.
- The report lists exact commands, machine used, commit hash, pass/fail state,
  remaining blockers, and any unsafe claims found.
```

## Final Ready Definition

FlowChain Product Testnet V1 is ready only when all of this is true:

- merged to `main`;
- clean second-computer checkout is updated;
- `npm run flowchain:product-e2e` passes on the second computer;
- node, API, and workbench stay running after the setup command exits;
- the tester can complete wallet -> funding -> transfer -> token launch -> DEX
  pool -> liquidity -> swap -> explorer verification;
- docs explain the exact setup and troubleshooting steps;
- bridge is clearly testnet/local unless a separate production bridge release
  gate is completed.

