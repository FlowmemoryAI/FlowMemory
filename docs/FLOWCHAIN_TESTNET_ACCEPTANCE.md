# FlowChain Testnet Acceptance

Status: acceptance matrix for the private/local testnet package. The HQ/Ops
command wrapper layer and full-smoke gate are implemented for current
private/local surfaces. Workbench polish and longer-running runtime behavior
remain active, but the local object/control-plane path is no longer blocked.

This document marks every major feature as one of:

- **Implemented**: merged in the current repo.
- **In flight**: visible in active unmerged worktrees or next-wave prompts.
- **Missing**: needed for second-computer validation and not merged.
- **Later gated**: outside this private/local package.

## Package-Level Acceptance

| Requirement | Status | Evidence or required next step |
| --- | --- | --- |
| Clone repo on second computer | Implemented | GitHub repo clone command. |
| Install JS dependencies | Implemented | `npm install` for current root workspaces. |
| Install dashboard dependencies | Implemented | `npm install --prefix apps/dashboard`; root workspace integration is missing. |
| Run devnet tests | Implemented | `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml`. |
| Run service tests | Implemented | `npm test` for merged service packages. |
| Run launch candidate gate | Implemented | `npm run launch:candidate`. |
| One-command private testnet aliases | Implemented for merged surfaces | `package.json` now exposes `flowchain:prereq`, `flowchain:init`, `flowchain:start`, `flowchain:stop`, `flowchain:demo`, `flowchain:smoke`, `flowchain:full-smoke`, `flowchain:export`, `flowchain:import`, `control-plane:serve`, and `workbench:dev`. |
| Prerequisite check script | Implemented | `infra/scripts/flowchain-check-prereqs.ps1`. |
| Start/stop scripts | Implemented bounded wrappers | `flowchain:start` prepares launch-core fixtures and state summary; `flowchain:stop` records stopped state and can reset ignored local state. Long-running node behavior remains in flight. |
| Full smoke script | Implemented for current private/local surfaces | `flowchain:full-smoke` runs the smoke gate, control-plane smoke client, deterministic replay, dashboard build, hardware fixture, unsafe-claim scan, export no-secret scan, and `git diff --check`. |
| Export/import state bundles | Implemented local wrapper | `flowchain:export` writes ignored export files and zip bundle; `flowchain:import` restores local state from a bundle. |
| Troubleshooting guide | Implemented | `docs/FLOWCHAIN_TROUBLESHOOTING.md` plus script error messages. |

## Runtime And State

| Feature | Status | Acceptance condition |
| --- | --- | --- |
| No-value deterministic devnet | Implemented | Existing Rust devnet remains the single runtime surface. |
| Private/local genesis/config | Implemented local boundary | `flowchain:init` and devnet exports write deterministic local genesis/config references. |
| Single-node local runtime | Implemented bounded local runtime | Current CLI can init/demo/run blocks and `flowchain:start` gives an obvious bounded start path; long-running node behavior remains future polish. |
| Multi-node or LAN notes | Missing | Must be optional and safe, or marked later gated. |
| Deterministic block production | Implemented | Current devnet models deterministic blocks and state roots. |
| Deterministic replay | Implemented | `flowchain:smoke` reruns the native object demo twice and compares block hashes, latest parent hash, state root, and map roots. |
| Transaction ingestion | Implemented local fixture path | Current devnet supports fixture submission plus deterministic demo transactions for the local object lifecycle. |
| State export | Implemented | `export-fixtures` exists and is exercised by the package-level smoke path. |
| State import/snapshot restore | Implemented local wrapper | `flowchain:import` restores current devnet state from an exported bundle; richer subsystem snapshots remain future work. |
| Health/status output | Implemented local control-plane path | CLI summary and `control-plane:smoke` exercise local health/status queries. |

## Native Objects

| Object or lifecycle | Status | Acceptance condition |
| --- | --- | --- |
| Rootfield namespace | Implemented | Existing contracts, launch fixtures, and devnet model support this. |
| Root commitment | Implemented | Existing contracts, fixtures, and devnet model support this. |
| FlowPulse linkage | Implemented | Launch-core fixtures preserve contract-event semantics. |
| AgentAccount | Implemented | Devnet demo and smoke register/query local agent state. |
| ModelPassport | Implemented | Devnet demo and smoke register/query local model passport state. |
| WorkReceipt | Implemented | Work receipts are part of the devnet and control-plane smoke flow. |
| ToolReceipt | Missing | Explicit placeholder is acceptable for this package if documented. |
| EvalReceipt | Missing | Explicit placeholder is acceptable for this package if documented. |
| ArtifactAvailabilityProof | Implemented | Local artifact availability objects are included in devnet state, export, and smoke. |
| VerifierModule | Implemented | Local verifier module identity is included in devnet state, export, and smoke. |
| VerifierReport | Implemented | Verifier reports are queryable through the local control-plane smoke path. |
| MemoryCell | Implemented | Memory cells update only from accepted receipts with accepted verifier reports. |
| Challenge | Implemented | Challenge open/resolve lifecycle is included in devnet smoke. |
| FinalityReceipt | Implemented | Finality receipts are included in devnet smoke and export. |
| DependencyAtom | Later gated | Keep as placeholder or dependency-root boundary; no SEAL proof claim. |

## Control Plane API

| Feature | Status | Acceptance condition |
| --- | --- | --- |
| Local API service | Implemented | `services/control-plane/` is the single local API surface. |
| Health endpoint/method | Implemented | `control-plane:smoke` exercises local-only health/status. |
| Chain status | Implemented | Control-plane state includes block, object, fixture, and capability counters. |
| Blocks and transactions | Implemented | Required block and transaction queries are part of `control-plane:smoke`. |
| Agents and models | Implemented | Control-plane reads current devnet/fixture outputs. |
| Receipts and artifacts | Implemented | Control-plane links memory receipts, work receipts, artifacts, and provenance. |
| Verifier reports | Implemented | Control-plane exposes verifier reports through stable local queries. |
| Challenges and finality | Implemented | Control-plane exposes real local challenge and finality objects. |
| Memory cells | Implemented | Control-plane links memory state to receipts and verifier status. |
| Provenance queries | Implemented | Control-plane provenance queries cite source files, schema hashes, report ids, and object ids. |
| Stable errors | Implemented local baseline | JSON-RPC smoke covers known local methods and errors. |
| No secrets in responses | Implemented local export gate | Full smoke scans generated local exports and the control-plane client path avoids returning local operator secrets. |

## Workbench And Explorer

| Feature | Status | Acceptance condition |
| --- | --- | --- |
| Existing dashboard V0 | Implemented | Fixture-backed app renders V0 Rootflow/Flow Memory and devnet data. |
| Local private testnet workbench | In flight | Extend `apps/dashboard/`; do not build a second dashboard. |
| Node health view | In flight | Workbench source includes node/control-plane state; UI polish remains active. |
| Blocks and transactions views | In flight | Workbench source includes deterministic block and transaction state; UI polish remains active. |
| Agents and models views | In flight | Workbench source includes local identity/provenance state; UI polish remains active. |
| Receipts, artifacts, reports views | In flight | Existing dashboard has V0 views; needs private testnet completeness. |
| Memory cells, challenges, finality views | In flight | Workbench source includes these local objects; UI polish remains active. |
| Provenance/source view | In flight | Workbench source includes provenance/source data; UI polish remains active. |
| Raw JSON view | Implemented | Existing dashboard has a raw JSON view; private testnet data remains part of the workbench extension. |
| Loading/empty/error states | Missing | Required before second-computer validation. |

## Crypto, Keys, And Private State

| Feature | Status | Acceptance condition |
| --- | --- | --- |
| Keccak typed hash helpers | Implemented | Existing `crypto/` package and vectors. |
| Local object IDs | Implemented | Crypto helpers and schemas cover the current local-alpha object set, including bridge and local-balance records. |
| Signature/envelope policy | Implemented local baseline | Local signature envelopes and chain-bound transaction envelopes cover local operators, agents, verifiers, and hardware signal issuers. |
| Negative vector tests | Implemented | Tests cover wrong chain id, wrong domain, wrong signer, missing signer, zero hash, malformed objects, replay, changed object type, and bad signatures. |
| Local operator key generation/import | Implemented local-only wrapper | `flowchain:init` writes ignored `devnet/local/operator.local.json` or imports a local operator file. Encrypted vault behavior remains missing. |
| Encrypted local operator vault | Implemented local test vault | Crypto wallet CLI can create an encrypted local test vault, sign a local transaction envelope, and verify it. This is not production custody. |
| Production proof systems | Later gated | No proof-circuit or audited-crypto claim. |
| SEAL/dependency privacy | Later gated | Vocabulary and placeholders only unless reviewed separately. |

## Hardware And Operator Signals

| Feature | Status | Acceptance condition |
| --- | --- | --- |
| FlowRouter POC simulator | Implemented | Existing hardware simulator and fixtures. |
| Optional operator signal fixtures | In flight | Active hardware work maps heartbeat, receipt relay, verifier digest, alert, and NFC metadata. |
| Hardware required for local chain | Later gated | Hardware must remain optional for the private/local testnet. |
| Manufacturing or RF certification | Later gated | Not part of this milestone. |

## Contracts Settlement Spine

| Feature | Status | Acceptance condition |
| --- | --- | --- |
| FlowPulse event spine | Implemented | Existing contracts emit compact FlowPulse events. |
| Registry and receipt skeletons | Implemented | Current contracts remain optional settlement/event surfaces. |
| Private runtime implemented in Solidity | Later gated | Core private/local runtime stays in the devnet, not Solidity. |
| Production deployment or bridge | Later gated | Not part of this milestone. |

## Full Smoke Test Acceptance

The package is accepted only when one documented command can:

1. Initialize the private/local chain state.
2. Register an agent.
3. Register a model passport.
4. Submit a work receipt.
5. Mark an artifact available.
6. Submit a verifier report.
7. Update a memory cell from an accepted receipt.
8. Open a challenge.
9. Resolve the challenge.
10. Finalize the receipt.
11. Export state.
12. Query the state through the control-plane API.
13. Render the state in the workbench.
14. Rerun deterministically with the same expected roots.

Current wrapper status:

- `npm run flowchain:full-smoke` is the documented acceptance command.
- It proves the merged launch-core, crypto helpers/vectors, local devnet,
  export, dashboard build, hardware fixture, deterministic replay,
  control-plane query coverage, native local object lifecycle, and
  claim/no-secret guardrails.

Required final evidence for the acceptance PR:

- Commands run.
- Output files generated.
- Deterministic root or fixture hash comparison.
- Control-plane query sample.
- Workbench screenshot or test/build evidence.
- `git diff --check`.

## Review Gate

Reject the milestone if any PR claims production mainnet, public validator
readiness, tokenomics, audited cryptography, production bridge readiness,
production hardware readiness, or AI/model/artifact data stored on-chain.
