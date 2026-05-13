# FlowChain Full Private Testnet Plan

Status: packaging and acceptance map for the next milestone.

Correct public phrase:

```text
FlowChain private/local L1 testnet package for second-computer validation.
```

Do not describe this milestone as production mainnet, public validator readiness,
tokenomics, audited cryptography, or production bridge readiness.

## Purpose

This plan turns the current FlowMemory V0 launch-core and active Local Alpha
work into one testable package that a second computer can run locally.

The target is a private/local L1-style testnet package. It should prove local
state transitions, receipts, verifier reports, memory updates, challenges,
finality, control-plane queries, and workbench inspection on a clean Windows
machine. It is not a public chain launch.

## Build On Existing Surfaces

Agents must extend the current surfaces in place.

Status vocabulary for this milestone:

- `Implemented`: merged source-of-truth surface exists today.
- `In flight`: visible in active unmerged worktrees or next-wave prompts.
- `Missing`: required for second-computer validation and not merged.
- `Later gated`: outside this private/local package.

| Area | Existing surface to extend | Current merged status | Active work to treat as in flight |
| --- | --- | --- | --- |
| Launch core | `npm run launch:v0`, `npm run launch:candidate`, `fixtures/launch-core/`, `schemas/flowmemory/` | Implemented local/test V0 foundation | Keep as the compatibility baseline for private testnet objects. |
| Devnet/runtime | `crates/flowmemory-devnet/`, `docs/LOCAL_DEVNET.md` | Implemented no-value deterministic prototype | Local Alpha work expands native object transitions and lifecycle tests. |
| Contracts spine | `contracts/`, `tests/`, FlowPulse and registry skeletons | Implemented local/test settlement/event foundation | Contracts work should remain optional settlement/event spine. |
| Crypto/object identity | `crypto/`, `crypto/fixtures/`, `schemas/flowmemory/` | Implemented V0 hash helpers and vectors | Local Alpha work adds object IDs for agent, model, memory, challenge, and finality objects. |
| Indexer/verifier/control plane | `services/indexer/`, `services/verifier/`, `services/flowmemory/` | Implemented fixture-first indexer/verifier and generator | Local Alpha work adds `services/control-plane/` as the local API. |
| Dashboard/workbench | `apps/dashboard/` and generated dashboard fixtures | Implemented fixture-backed dashboard V0 | Workbench work should extend this app, not create a second dashboard. |
| Hardware/operator signals | `hardware/`, `fixtures/hardware/`, simulator | Implemented FlowRouter POC and simulator | Local Alpha work maps optional operator signals into private testnet views. |
| Research gates | `research/`, `docs/DECISIONS/` | Implemented research docs and guardrails | Local Alpha research gates Process-Witness, SEAL, private state, and public L1 work. |

## Required User-Facing Path

The final package should offer one obvious path. The exact command names may
change only if the second-computer setup guide names the chosen commands.

| Capability | Target command | Current status |
| --- | --- | --- |
| Clone repo | `git clone https://github.com/FlowmemoryAI/FlowMemory.git` | Implemented by GitHub. |
| Install JS dependencies | `npm install` | Implemented for current npm workspaces. Dashboard still needs its own install unless package metadata changes. |
| Test devnet | `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml` | Implemented. |
| Test service packages | `npm test` | Implemented for merged service packages; control-plane tests are active unmerged work. |
| Run launch candidate gate | `npm run launch:candidate` | Implemented V0 local/test gate. |
| Initialize private testnet | `npm run flowchain:init` | Implemented wrapper over the existing devnet `init`; also writes ignored local operator metadata under `devnet/local/`. |
| Start private testnet | `npm run flowchain:start` | Implemented bounded wrapper that prepares launch-core fixtures and inspects local state. Current devnet is still CLI/demo oriented, not a long-running node. |
| Run deterministic demo | `npm run flowchain:demo` | Implemented wrapper over the existing devnet `demo`. |
| Run full smoke test | `npm run flowchain:smoke` | Implemented for merged surfaces: services, crypto tests/vectors, launch candidate, devnet tests, deterministic replay, dashboard build, hardware fixture, unsafe-claim scan, and no-secret export scan. Native object/control-plane coverage remains blocked on subsystem work. |
| Export state | `npm run flowchain:export` | Implemented wrapper over `export-fixtures`; writes ignored export bundles under `devnet/local/export/`. |
| Import state | `npm run flowchain:import -- --BundlePath <zip> -Force` | Implemented script path for local state restore from an exported bundle. |
| Start local workbench | `npm run workbench:dev` | Implemented wrapper over the existing dashboard dev server. |
| Prerequisite check | `npm run flowchain:prereq` | Implemented Windows-first prerequisite and dependency-state check. |
| Stop private testnet | `npm run flowchain:stop` | Implemented operator-state wrapper; can reset ignored local state with `-ResetLocalState`. |
| Start control plane | documented local API command | In flight in `services/control-plane/`; active command is `npm run control-plane:serve` in the control-plane worktree. |

## Target Native Objects

The private/local testnet package should make these objects inspectable through
the devnet, control plane, and workbench. They should reuse current schemas,
fixtures, or crypto helpers when those exist.

| Object | Target status for package | Notes |
| --- | --- | --- |
| `AgentAccount` | Required | Local identity/provenance record only; no balance or wallet-value claim. |
| `ModelPassport` | Required | Model provenance and metadata commitment; no model weights on-chain. |
| `WorkReceipt` | Required | Builds on current receipt vocabulary and registry skeletons. |
| `ToolReceipt` | Explicit placeholder allowed | Must be documented if not implemented. |
| `EvalReceipt` | Explicit placeholder allowed | Must be documented if not implemented. |
| `MemoryCell` | Required | Must link to accepted receipts, verifier reports, roots, and provenance. |
| `ArtifactAvailabilityProof` | Required | Availability/status record only; no raw artifact storage. |
| `VerifierModule` | Required | Source-visible verifier identity and supported modes. |
| `VerifierReport` | Required | Builds on current verifier report fixtures and statuses. |
| `Challenge` | Required | Must support open, resolve, rejected/unresolved, and downgrade semantics. |
| `FinalityReceipt` | Required | Must explain accepted, rejected, pending, superseded, or downgraded finality. |
| `DependencyAtom` | Explicit placeholder allowed | SEAL-compatible future boundary; no proof claim until reviewed. |

## Definition Of Done

The package is ready for second-computer validation only when a clean Windows
machine can:

1. Clone the repo and install documented prerequisites.
2. Run current baseline checks without private secrets.
3. Generate or import local operator keys without committing secrets.
4. Initialize a local/private genesis.
5. Start at least one local node/runtime.
6. Optionally start multiple local or LAN nodes, or clearly mark LAN mode later.
7. Submit transactions for FlowMemory-native objects.
8. Produce blocks and deterministic state roots.
9. Register agents and model passports.
10. Submit work receipts.
11. Submit artifact availability records.
12. Submit verifier reports.
13. Update memory cells from valid receipts only.
14. Open and resolve challenges.
15. Finalize receipts.
16. Query all state through the documented local control-plane API.
17. Inspect all state through the existing dashboard/workbench surface.
18. Export and import snapshots or state bundles.
19. Run an end-to-end smoke test proving the full flow.
20. Re-run the same smoke test deterministically.

Current HQ/Ops completion for this pass:

- The second-computer command names now exist at the repo root.
- The commands exercise the current merged launch-core, Rust devnet,
  dashboard, hardware simulator, export, import, and claim-guardrail surfaces.
- The full private object lifecycle is still owned by the chain, crypto,
  control-plane, and dashboard workstreams named in
  `docs/FLOWCHAIN_AGENT_INTEGRATION_MAP.md`.

## Non-Goals

- No production mainnet claim.
- No token launch or tokenomics.
- No public validator onboarding.
- No production consensus claim.
- No audited cryptography claim.
- No production bridge or withdrawal claim.
- No production Uniswap v4 hook deployment.
- No raw AI memory, model weights, media, or heavy artifacts on-chain.
- No requirement that FlowRouter hardware is online for the local testnet to run.

## Coordination Rule

If a needed surface already exists, improve it in place. Do not create a second
devnet, second dashboard/workbench, second crypto package, second verifier
pipeline, second object model, or second setup flow.
