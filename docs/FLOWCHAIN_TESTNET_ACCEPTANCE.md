# FlowChain Testnet Acceptance

Status: acceptance matrix for the private/local testnet package. The chain
runtime now has a long-running local node, local transaction intake, local
test-unit faucet records, and static local-file multi-node reconciliation.
Control-plane query coverage and workbench runtime inspection remain in flight.

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
| One-command private testnet aliases | Implemented for chain runtime surfaces | `package.json` now exposes `flowchain:prereq`, `flowchain:init`, `flowchain:start`, `flowchain:node`, `flowchain:node:stop`, `flowchain:node:status`, `flowchain:tx`, `flowchain:faucet`, `flowchain:node:smoke`, `flowchain:multi-node:smoke`, `flowchain:stop`, `flowchain:demo`, `flowchain:smoke`, `flowchain:full-smoke`, `flowchain:export`, `flowchain:import`, and `workbench:dev`. `control-plane:serve` remains in flight. |
| Prerequisite check script | Implemented | `infra/scripts/flowchain-check-prereqs.ps1`. |
| Start/stop scripts | Implemented | `flowchain:start` remains a compatibility wrapper; `flowchain:node` starts the long-running runtime; `flowchain:node:stop` and `flowchain:stop` request node shutdown through the stop file. |
| Full smoke script | Implemented for merged surfaces | `flowchain:smoke` runs service tests, crypto tests/vectors, launch candidate, devnet tests, one-node runtime smoke, multi-node runtime smoke, deterministic replay, dashboard build, hardware fixture, unsafe-claim scan, and export no-secret scan. Control-plane query evidence remains blocked on subsystem work. |
| Export/import state bundles | Implemented local wrapper | `flowchain:export` writes ignored export files and zip bundle; `flowchain:import` restores local state from a bundle. |
| Troubleshooting guide | Implemented | `docs/FLOWCHAIN_TROUBLESHOOTING.md` plus script error messages. |

## Runtime And State

| Feature | Status | Acceptance condition |
| --- | --- | --- |
| No-value deterministic devnet | Implemented | Existing Rust devnet remains the single runtime surface. |
| Private/local genesis/config | Implemented for chain runtime | `init` writes deterministic genesis config and operator key references; node state is under `devnet/local/state.json`; node-local identity/status files are under `devnet/local/node/`. |
| Single-node local runtime | Implemented | `npm run flowchain:node` runs a long-running local node that persists state, ingests inbox transactions, produces interval blocks, writes logs/status, and stops through `flowchain:node:stop`. `npm run flowchain:node:smoke` proves 10+ blocks, transaction inclusion, restart persistence, and export/import. |
| Multi-node or LAN notes | Implemented local-file mode; LAN not exposed | `npm run flowchain:multi-node:smoke` starts two local node processes and proves static local-file peer reconciliation. LAN mode is explicitly not exposed. |
| Deterministic block production | Implemented | Current devnet models deterministic blocks and state roots. |
| Deterministic replay | Implemented for merged demo | `flowchain:smoke` reruns the current demo twice and compares exported dashboard state roots. Full native object replay remains in flight. |
| Transaction ingestion | Implemented for chain runtime | `submit-tx`, `faucet`, `flowchain:tx`, and `flowchain:faucet` submit locally authorized JSON transactions to node inboxes or direct pending state. |
| Local balance/faucet ledger | Implemented for no-value test units | `FaucetLocalBalance`, `TransferLocalBalance`, `localBalances`, `faucetRecords`, and `balanceTransfers` are included in state roots, blocks, exports, and smoke tests. |
| State export | Implemented | `export-fixtures`, `export-state`, `flowchain:export`, and `flowchain:node:smoke` export runtime state. |
| State import/snapshot restore | Implemented local wrapper | `flowchain:import` restores current devnet state from an exported bundle; `flowchain:node:smoke` proves runtime export/import root equality. |
| Health/status output | Implemented for node/runtime | `node-status` and `flowchain:node:status` expose latest block, state root, pending transactions, local balance counts, persisted node status, and LAN boundary. Control-plane health remains in flight. |

## Native Objects

| Object or lifecycle | Status | Acceptance condition |
| --- | --- | --- |
| Rootfield namespace | Implemented | Existing contracts, launch fixtures, and devnet model support this. |
| Root commitment | Implemented | Existing contracts, fixtures, and devnet model support this. |
| FlowPulse linkage | Implemented | Launch-core fixtures preserve contract-event semantics. |
| AgentAccount | Implemented in devnet | `RegisterAgent`, demo, handoff export, and `flowchain:tx` sample transaction cover local agent identity. |
| ModelPassport | Implemented in devnet | `RegisterModelPassport`, demo, handoff export, and `flowchain:tx` sample transaction cover local model provenance. |
| WorkReceipt | Implemented in devnet | Demo and smoke submit work receipts with dependency checks and handoff export. |
| ToolReceipt | Missing | Explicit placeholder is acceptable for this package if documented. |
| EvalReceipt | Missing | Explicit placeholder is acceptable for this package if documented. |
| ArtifactAvailabilityProof | Implemented in devnet | `MarkArtifactAvailability`, demo, smoke, roots, and handoff export cover local availability records. |
| VerifierModule | Implemented in devnet | `RegisterVerifierModule`, verifier dependency checks, demo, smoke, roots, and handoff export cover local verifier identity. |
| VerifierReport | Implemented in devnet | `SubmitVerifierReport`, accepted/failed status checks, demo, smoke, roots, and handoff export cover local reports. Workbench/query exposure remains subsystem work. |
| MemoryCell | Implemented in devnet | `UpdateMemoryCell` requires an accepted verifier report and updates agent memory root; demo, smoke, roots, and handoff export cover it. |
| Challenge | Implemented in devnet | `OpenChallenge` and `ResolveChallenge` enforce receipt/finality rules; demo, smoke, roots, and handoff export cover them. |
| FinalityReceipt | Implemented in devnet | `FinalizeWorkReceipt` requires accepted receipts with no unresolved challenge; demo, smoke, roots, and handoff export cover it. |
| LocalBalance/FaucetRecord | Implemented in devnet | Local no-value test-unit ledger supports transaction/faucet smoke and is included in roots, blocks, exports, and node status. |
| DependencyAtom | Later gated | Keep as placeholder or dependency-root boundary; no SEAL proof claim. |

## Control Plane API

| Feature | Status | Acceptance condition |
| --- | --- | --- |
| Local API service | In flight | Extend `services/control-plane/`; do not create a second API surface. |
| Health endpoint/method | In flight | Must show local-only status and source health. |
| Chain status | In flight | Must include block, object, fixture, and capability counters. |
| Blocks and transactions | In flight | Devnet state and control-plane handoff include blocks, pending transactions, object maps, and roots; live API methods remain control-plane work. |
| Agents and models | In flight | Must read existing devnet/fixture outputs. |
| Receipts and artifacts | In flight | Must link memory receipts, work receipts, artifacts, and provenance. |
| Verifier reports | In flight | Must expose reports and stable error shapes. |
| Challenges and finality | In flight | Must expose real local objects or explicit placeholders. |
| Memory cells | In flight | Must link memory state to receipts and verifier status. |
| Provenance queries | In flight | Must cite source files, schema hashes, report ids, and object ids. |
| Stable errors | In flight | JSON-RPC errors are active Local Alpha work. |
| No secrets in responses | Missing | Tests must prove secrets do not appear in API responses. |

## Workbench And Explorer

| Feature | Status | Acceptance condition |
| --- | --- | --- |
| Existing dashboard V0 | Implemented | Fixture-backed app renders V0 Rootflow/Flow Memory and devnet data. |
| Local private testnet workbench | In flight | Extend `apps/dashboard/`; do not build a second dashboard. |
| Node health view | In flight | Node status JSON exists; workbench rendering remains dashboard work. |
| Blocks and transactions views | In flight | Devnet handoff includes blocks and pending transactions; workbench rendering remains dashboard work. |
| Agents and models views | In flight | Devnet handoff includes local agents and models; workbench rendering remains dashboard work. |
| Receipts, artifacts, reports views | In flight | Existing dashboard has V0 views; needs private testnet completeness. |
| Memory cells, challenges, finality views | In flight | Devnet handoff includes these objects; workbench rendering remains dashboard work. |
| Provenance/source view | Missing | Required for second-computer debugging. |
| Raw JSON view | Implemented | Existing dashboard has a raw JSON view; private testnet data remains part of the workbench extension. |
| Loading/empty/error states | Missing | Required before second-computer validation. |

## Crypto, Keys, And Private State

| Feature | Status | Acceptance condition |
| --- | --- | --- |
| Keccak typed hash helpers | Implemented | Existing `crypto/` package and vectors. |
| Local object IDs | In flight | Active crypto work expands object IDs and schemas. |
| Signature/envelope policy | In flight | Devnet records `local-authorized` transaction envelopes for local operators; full crypto vectors remain crypto work. |
| Negative vector tests | In flight | Must cover wrong domain, missing signer, zero hash, malformed objects, and replay. |
| Local operator key generation/import | Implemented local-only wrapper | `flowchain:init` writes ignored `devnet/local/operator.local.json` or imports a local operator file. Encrypted vault behavior remains missing. |
| Encrypted local operator vault | Missing | Preferred target; at minimum document current local key boundary. |
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

- `npm run flowchain:smoke` is the documented command.
- It proves the merged launch-core, crypto helpers/vectors, local devnet,
  native AgentAccount, ModelPassport, ArtifactAvailabilityProof,
  VerifierModule, VerifierReport, MemoryCell, Challenge, FinalityReceipt,
  local test-unit faucet records, one-node runtime behavior, static local-file
  multi-node reconciliation, export/import, dashboard build, hardware fixture,
  deterministic replay, and claim/no-secret guardrails.
- It does not yet prove live control-plane query coverage or workbench runtime
  rendering. Those rows stay in flight until subsystem PRs land behind the
  wrapper.

Required final evidence for the acceptance PR:

- Commands run.
- Output files generated.
- Deterministic root or fixture hash comparison.
- Control-plane query sample remains a follow-up until the control-plane
  subsystem exposes the runtime handoff through API methods.
- Workbench screenshot or test/build evidence remains a follow-up until the
  dashboard subsystem renders the runtime handoff.
- `git diff --check`.

## Review Gate

Reject the milestone if any PR claims production mainnet, public validator
readiness, tokenomics, audited cryptography, production bridge readiness,
production hardware readiness, or AI/model/artifact data stored on-chain.
