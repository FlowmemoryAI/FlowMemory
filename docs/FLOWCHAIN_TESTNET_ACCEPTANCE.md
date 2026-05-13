# FlowChain Testnet Acceptance

Status: acceptance matrix for the private/local testnet package. The HQ/Ops
command wrapper layer is implemented for merged surfaces; full native object,
long-running runtime, wallet, bridge-credit, live control-plane, and workbench
acceptance remains in flight.

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
| One-command private testnet aliases | Implemented for merged surfaces | `package.json` now exposes `flowchain:prereq`, `flowchain:init`, `flowchain:start`, `flowchain:stop`, `flowchain:demo`, `flowchain:smoke`, `flowchain:full-smoke`, `flowchain:export`, `flowchain:import`, `control-plane:serve`, bridge mock/test commands, and `workbench:dev`. |
| Prerequisite check script | Implemented | `infra/scripts/flowchain-check-prereqs.ps1`. |
| Start/stop scripts | Implemented bounded wrappers | `flowchain:start` prepares launch-core fixtures and state summary; `flowchain:stop` records stopped state and can reset ignored local state. Long-running node behavior remains in flight. |
| Full smoke script | Implemented for merged surfaces | `flowchain:smoke` runs service tests, crypto tests/vectors, launch candidate, devnet tests, deterministic replay, dashboard build, hardware fixture, unsafe-claim scan, and export no-secret scan. Native object/control-plane lifecycle remains blocked. |
| Full private/local L1 smoke gate | In flight | `flowchain:full-smoke` exists as the #108 temporary blocker-report wrapper. It writes `devnet/local/smoke/flowchain-full-smoke-report.json` and exits nonzero until issues #99 through #105 land the missing command coverage. |
| Export/import state bundles | Implemented local wrapper | `flowchain:export` writes ignored export files and zip bundle; `flowchain:import` restores local state from a bundle. |
| Troubleshooting guide | Implemented | `docs/FLOWCHAIN_TROUBLESHOOTING.md` plus script error messages. |

## Runtime And State

| Feature | Status | Acceptance condition |
| --- | --- | --- |
| No-value deterministic devnet | Implemented | Existing Rust devnet remains the single runtime surface. |
| Private/local genesis/config | In flight | Chain agent must document generated config and replay behavior. |
| Single-node local runtime | In flight | Current CLI can init/demo/run blocks and `flowchain:start` gives an obvious bounded start path; long-running node behavior is still missing. |
| Multi-node or LAN notes | Missing | Must be optional and safe, or marked later gated. |
| Deterministic block production | Implemented | Current devnet models deterministic blocks and state roots. |
| Deterministic replay | Implemented for merged demo | `flowchain:smoke` reruns the current demo twice and compares exported dashboard state roots. Full native object replay remains in flight. |
| Transaction ingestion | In flight | Current devnet supports fixture submission; expanded object ingestion is active work. |
| State export | Implemented | `export-fixtures` exists; full package export/import still needs the package-level smoke path. |
| State import/snapshot restore | Implemented local wrapper | `flowchain:import` restores current devnet state from an exported bundle; richer subsystem snapshots remain future work. |
| Health/status output | In flight | CLI summary exists; control-plane health is active work. |

## Native Objects

| Object or lifecycle | Status | Acceptance condition |
| --- | --- | --- |
| Rootfield namespace | Implemented | Existing contracts, launch fixtures, and devnet model support this. |
| Root commitment | Implemented | Existing contracts, fixtures, and devnet model support this. |
| FlowPulse linkage | Implemented | Launch-core fixtures preserve contract-event semantics. |
| AgentAccount | In flight | Active devnet/crypto work adds local object identity and state. |
| ModelPassport | In flight | Active devnet/crypto work adds local object identity and state. |
| WorkReceipt | In flight | Foundation exists; it must still be part of the full private testnet smoke flow. |
| ToolReceipt | Missing | Explicit placeholder is acceptable for this package if documented. |
| EvalReceipt | Missing | Explicit placeholder is acceptable for this package if documented. |
| ArtifactAvailabilityProof | In flight | Active devnet/crypto/hardware work maps availability objects. |
| VerifierModule | In flight | Active devnet/crypto work adds local verifier identity. |
| VerifierReport | In flight | Existing verifier reports exist; they still must be queryable and workbench-visible in the private testnet package. |
| MemoryCell | In flight | Active devnet/crypto/control-plane work expands local state. |
| Challenge | In flight | Active devnet/crypto/control-plane work adds local challenge shape. |
| FinalityReceipt | In flight | Active devnet/crypto/control-plane work adds local finality shape. |
| DependencyAtom | Later gated | Keep as placeholder or dependency-root boundary; no SEAL proof claim. |

## Control Plane API

| Feature | Status | Acceptance condition |
| --- | --- | --- |
| Local API service | Implemented fixture-backed; live mode in flight | Extend `services/control-plane/`; do not create a second API surface. Issue #101 owns live-node adapters and transaction submission. |
| Health endpoint/method | Implemented fixture-backed; live mode in flight | Must show local-only status and source health. |
| Chain status | Implemented fixture-backed; live mode in flight | Must include block, object, fixture, and capability counters. |
| Blocks and transactions | In flight | Required for full private testnet inspection; live local-node coverage belongs to #101. |
| Agents and models | In flight | Must read existing devnet/fixture outputs. |
| Receipts and artifacts | In flight | Must link memory receipts, work receipts, artifacts, and provenance. |
| Verifier reports | In flight | Must expose reports and stable error shapes. |
| Challenges and finality | In flight | Must expose real local objects or explicit placeholders. |
| Memory cells | In flight | Must link memory state to receipts and verifier status. |
| Provenance queries | In flight | Must cite source files, schema hashes, report ids, and object ids. |
| Stable errors | Implemented baseline; live mode in flight | JSON-RPC errors exist for the local API; #101 must preserve them for live adapters. |
| No secrets in responses | Missing | Tests must prove secrets do not appear in API responses. |

## Workbench And Explorer

| Feature | Status | Acceptance condition |
| --- | --- | --- |
| Existing dashboard V0 | Implemented | Fixture-backed app renders V0 Rootflow/Flow Memory and devnet data. |
| Local private testnet workbench | In flight | Extend `apps/dashboard/`; do not build a second dashboard. |
| Node health view | Missing | Must show local runtime/control-plane status. |
| Blocks and transactions views | Missing | Must show deterministic local block and transaction state. |
| Agents and models views | Missing | Must show local identity/provenance state. |
| Receipts, artifacts, reports views | In flight | Existing dashboard has V0 views; needs private testnet completeness. |
| Memory cells, challenges, finality views | Missing | Required for full smoke inspection. |
| Provenance/source view | Missing | Required for second-computer debugging. |
| Raw JSON view | Implemented | Existing dashboard has a raw JSON view; private testnet data remains part of the workbench extension. |
| Loading/empty/error states | Missing | Required before second-computer validation. |

## Crypto, Keys, And Private State

| Feature | Status | Acceptance condition |
| --- | --- | --- |
| Keccak typed hash helpers | Implemented | Existing `crypto/` package and vectors. |
| Local object IDs | In flight | Active crypto work expands object IDs and schemas. |
| Signature/envelope policy | In flight | Must cover local operators, agents, verifiers, and hardware signal issuers. |
| Negative vector tests | In flight | Must cover wrong domain, missing signer, zero hash, malformed objects, and replay. |
| Local operator key generation/import | Implemented local-only wrapper | `flowchain:init` writes ignored `devnet/local/operator.local.json` or imports a local operator file. Encrypted vault behavior remains missing. |
| Encrypted local operator vault | Missing | Preferred target; at minimum document current local key boundary. |
| Production proof systems | Later gated | No proof-circuit or audited-crypto claim. |
| SEAL/dependency privacy | Later gated | Vocabulary and placeholders only unless reviewed separately. |

## Bridge Test Path

| Feature | Status | Acceptance condition |
| --- | --- | --- |
| Test-only bridge POC | Implemented foundation | Existing bridge docs, lockbox surface, relayer package, mock fixture, and bridge schemas stay test-only. |
| Mock bridge observation | Implemented | `npm run bridge:mock` produces deterministic observation output. |
| Bridge tests | Implemented baseline | `npm run bridge:test` runs relayer tests; bridge Foundry tests are required when contracts change. |
| Base Sepolia observation | In flight | #104 must expose explicit Base Sepolia observation smoke without private-key requirements. |
| Local BridgeCredit application | In flight | #104 must apply or hand off BridgeCredit to the local runtime with replay protection. |
| Withdrawal intent | In flight | #104 may create local test-mode withdrawal records; no mainnet release default. |
| Production bridge | Later gated | No production bridge, audited bridge-security, or broad mainnet deposit claim. |

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
11. Observe a mock/Base Sepolia test bridge deposit and apply or hand off a
    local BridgeCredit.
12. Export state.
13. Query the state through the control-plane API.
14. Render the state in the workbench.
15. Rerun deterministically with the same expected roots.

Current wrapper status:

- `npm run flowchain:smoke` is the merged-surface smoke command.
- `npm run flowchain:full-smoke` is the full acceptance command for #108, now
  present as a temporary blocker-report wrapper.
- It proves the merged launch-core, crypto helpers/vectors, local devnet,
  export, dashboard build, hardware fixture, deterministic replay, and
  claim/no-secret guardrails.
- The current full-smoke wrapper does not yet prove long-running node behavior,
  wallet signing, AgentAccount, ModelPassport, native MemoryCell, Challenge,
  FinalityReceipt, live control-plane queries, workbench live-state inspection,
  bridge local-credit smoke, or deterministic full export/import replay. Those
  rows stay in flight or missing until issues #99 through #105 land behind
  the wrapper.

Required final evidence for the acceptance PR:

- Commands run.
- Output files generated.
- Deterministic root or fixture hash comparison.
- Control-plane query sample.
- Workbench screenshot or test/build evidence.
- Bridge mock/local-credit smoke evidence.
- `git diff --check`.

## Review Gate

Reject the milestone if any PR claims production mainnet, public validator
readiness, tokenomics, audited cryptography, production bridge readiness,
production hardware readiness, or AI/model/artifact data stored on-chain.
