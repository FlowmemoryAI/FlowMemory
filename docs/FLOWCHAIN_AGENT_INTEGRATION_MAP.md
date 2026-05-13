# FlowChain Agent Integration Map

Status: coordination map for the private/local testnet next wave.

Target phrase:

```text
FlowChain private/local L1 testnet package for second-computer validation.
```

## Shared Rule

Build on existing FlowMemory/FlowChain components. Do not create a second
devnet, dashboard/workbench, crypto package, verifier pipeline, object model,
or setup flow.

## Worktree Ownership

| Agent | Worktree | Primary ownership | Must reuse | Must not touch |
| --- | --- | --- | --- | --- |
| HQ / Review | `E:\FlowMemory\flowmemory-review` | Docs, acceptance, backlog, process, setup clarity | Current source-of-truth docs and dispatch target | Product implementation folders |
| Chain / Devnet | `E:\FlowMemory\flowmemory-chain` | `crates/flowmemory-devnet/`, devnet tests, devnet fixtures | Existing Rust devnet and launch-core fixture model | Contracts, apps, services internals, tokenomics |
| Control Plane / Indexer | `E:\FlowMemory\flowmemory-indexer` | `services/`, control-plane API, fixture handoff | Existing indexer/verifier/generator outputs | Contracts, dashboard implementation, crypto internals |
| Crypto / RD | `E:\FlowMemory\flowmemory-crypto` | `crypto/`, object IDs, schemas, vectors | Existing Keccak typed hash package | Services, apps, contracts, production proof systems |
| Dashboard / Workbench | `E:\FlowMemory\flowmemory-dashboard` | `apps/dashboard/` | Existing dashboard app, fixtures, styling, data model | New dashboard app, services, crypto, contracts |
| Hardware | `E:\FlowMemory\flowmemory-hardware` | `hardware/`, `fixtures/hardware/` | Existing FlowRouter simulator and POC docs | Chain runtime, services, dashboard implementation |
| Contracts | `E:\FlowMemory\flowmemory-contracts` | `contracts/`, `tests/` | Existing FlowPulse and registry/event skeletons | Core private L1 runtime, tokenomics, bridge |
| Bridge | `E:\FlowMemory\flowmemory-bridge-full` | `services/bridge-relayer/`, `contracts/bridge/`, `tests/bridge/`, `fixtures/bridge/`, bridge schemas/docs | Existing bridge POC docs, relayer package, schemas, and guarded smoke boundaries | Production bridge, real-funds default paths, dashboard implementation, core runtime |
| Research | `E:\FlowMemory\flowmemory-research` | `research/`, `docs/DECISIONS/` | Existing research gates and decisions | Implementation folders, public-chain claims |

## Current Coordination Facts

- The merged repo has a stable V0 launch-core path and no-value local devnet
  prototype.
- HQ/Ops has added the Windows-first root wrapper layer for the current merged
  surfaces: prerequisite check, init, bounded start/stop, demo, smoke,
  export/import, and workbench dev mode.
- Active sibling worktrees contain unmerged Local Alpha work for devnet object
  transitions, control-plane API, crypto object identity, hardware signal
  projection, and research gates.
- The full-L1 launcher from PR #98 has merged into `main`. It defines
  `docs/agent-goals/full-l1/` and starts the active `agent/full-l1-*`
  worktrees.
- GitHub milestone #7 tracks the full private/local L1 package. Workstream
  issues are #99 chain, #100 crypto, #101 control plane, #102 dashboard,
  #103 contracts, #104 bridge, #105 hardware, #106 research, #107 HQ, and
  #108 full-smoke packaging.
- `docs/FLOWCHAIN_HQ_INTEGRATION_STATUS.md` is the live HQ matrix for current
  branch/PR ownership, merge order, and full-smoke blockers.
- Unmerged worktree changes are not final source of truth. Treat them as
  in-flight context until reviewed and merged.
- GitHub remains the source of truth for issues, pull requests, reviews, and
  final history.

## Handoff Contracts

| From | To | Handoff |
| --- | --- | --- |
| Chain | Control Plane | Devnet state file, block/tx schema, object maps, deterministic roots, export/import behavior. |
| Chain | Dashboard | Dashboard-ready handoff or control-plane-backed state for blocks, txs, agents, models, memory, challenges, and finality. |
| Crypto | Chain | Object ID helpers, typed domains, envelope policy, valid/invalid vectors, schema names. |
| Crypto | Control Plane | Shared validation vocabulary and error reasons for malformed objects. |
| Control Plane | Dashboard | Stable methods, params, responses, errors, pagination, health, and local-only limitations. |
| Hardware | Control Plane | Optional operator signal fixture shape and trust labels. |
| Hardware | Dashboard | Optional hardware node, alert, receipt breadcrumb, verifier digest, and NFC metadata projections. |
| Contracts | Chain/Indexer | Optional settlement/event spine semantics and FlowPulse compatibility. |
| Contracts | Bridge | BaseBridgeLockbox events, replay/cap/pause behavior, test-only release boundaries, and Foundry evidence. |
| Bridge | Chain/Control Plane | BridgeObservation and BridgeCredit handoff files or API calls, replay status, and local-credit smoke output. |
| Bridge | Dashboard | Deposit observed, credit pending/applied, withdrawal requested, and risk labels. |
| Research | All | Gates for Process-Witness, SEAL/dependency privacy, private state, public appchain, bridge, and proof systems. |
| HQ / Review | All | Acceptance matrix, merge order, claim guardrails, issue grouping, and second-computer setup criteria. |

## Integration Sequence

1. Keep `npm run launch:candidate` green as the V0 baseline.
2. Land or refresh Local Alpha devnet object lifecycle work.
3. Land or refresh crypto object identity and vectors for the same object set.
4. Land control-plane API on top of existing fixture/devnet outputs.
5. Harden bridge/settlement event semantics and local bridge-credit handoffs
   after object/API labels are stable.
6. Extend the existing dashboard into a private testnet workbench.
7. Add optional hardware signal fixtures after object/API labels are stable.
8. Keep packaging scripts and root command aliases aligned as subsystem commands land.
9. Run `npm run flowchain:full-smoke` and update acceptance evidence.

## Duplicate-Work Stops

Stop and ask for HQ review if a PR starts adding:

- A new chain runtime outside `crates/flowmemory-devnet/`.
- A new dashboard or explorer outside the existing app surface.
- A new crypto package instead of extending `crypto/`.
- A new verifier or control-plane pipeline that bypasses current services.
- A new bridge relayer or bridge object model that bypasses the current
  `services/bridge-relayer/`, `contracts/bridge/`, or bridge schemas.
- A second object model that conflicts with `schemas/flowmemory/` or crypto IDs.
- A setup flow that competes with the second-computer setup guide.
- Tokenomics, production bridge work, public validator onboarding, or production
  mainnet language.

## PR Review Checklist

Every private testnet PR should state:

- Which existing surface it extends.
- Which acceptance rows in `docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md` it changes.
- Which second-computer command or setup step it improves.
- Which files it touched and why they are in scope.
- Which tests or checks passed.
- Which production claims remain explicitly out of scope.

Required check for all PRs:

```powershell
git diff --check
```

Area-specific checks remain required when the area has tests.
