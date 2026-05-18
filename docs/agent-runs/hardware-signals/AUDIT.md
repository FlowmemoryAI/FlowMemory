# Hardware Signals Completion Audit

Last updated: 2026-05-14

## Objective Restatement

Add optional FlowChain hardware/operator-signal fixtures and integration hooks
inside the allowed hardware scope, keep hardware optional, verify the eight
named checks, and leave PR-ready evidence.

## Prompt-To-Artifact Checklist

| Requirement | Evidence | Status |
| --- | --- | --- |
| Create `docs/agent-runs/hardware-signals/PLAN.md` first | `PLAN.md` exists and records branch, worktree, allowed folders, forbidden folders, objective, and acceptance checks. | Complete |
| Create `docs/agent-runs/hardware-signals/CHECKLIST.md` first | `CHECKLIST.md` exists and records completed hardware, product-e2e, and l1-e2e checks. | Complete |
| Create `docs/agent-runs/hardware-signals/EXPERIMENTS.md` first | `EXPERIMENTS.md` exists and records commands/results. | Complete |
| Create `docs/agent-runs/hardware-signals/NOTES.md` first | `NOTES.md` exists and records source docs, implementation notes, verification notes, blocker history, and final resolution. | Complete |
| Stay inside allowed folders | `node docs/agent-runs/hardware-signals/SCOPE_CHECK.mjs` passed: current dirty files are under `hardware/`, `fixtures/hardware/`, `schemas/flowmemory/hardware-control-plane-handoff.schema.json`, and `docs/agent-runs/hardware-signals/`. | Complete |
| Avoid forbidden folders | Product-e2e generated side effects outside scope were restored; no forbidden-path edits remain in `git status --short`. | Complete |
| `npm run flowchain:hardware:smoke` passes | Passed: `smoke passed: raw packets, operator signals, control-plane handoff, fixture drift check, and 12 negative cases`. | Complete |
| Deterministic heartbeat fixture | `hardware/fixtures/flowrouter_sample_seed42.json` has `heartbeat`; projected into `hardwareNodes` and `heartbeat` signal envelope. | Complete |
| Deterministic alert fixture | `emergency_offline_signal` exists and projects into `alerts` and `challenges`. | Complete |
| Deterministic receipt relay fixture | `compact_receipt_relay` exists and projects into `workReceipts` and `finalityReceipts`. | Complete |
| Deterministic verifier digest fixture | `verifier_report_digest_relay` exists and projects into `verifierReports`. | Complete |
| Deterministic bridge alert fixture | `bridge_alert` exists and projects into `bridgeAlerts` and `alerts`. | Complete |
| Deterministic NFC metadata fixture | `nfc_memory_cartridge_metadata` exists and projects into `artifactCommitments` and `memoryCells`. | Complete |
| Deterministic peer hint fixture if applicable | `peer_hint` packet/schema exists and projects into `peerHints`. | Complete |
| Deterministic node health fixture if applicable | `node_health` packet/schema exists and projects into `nodeHealth`. | Complete |
| Negative fixture rejects malformed IDs | `heartbeat_malformed_device_id` rejected in `flowrouter_negative_validation_seed42.json`. | Complete |
| Negative fixture rejects oversized payloads | `receipt_relay_payload_exceeds_control_budget` and `operator_envelope_payload_exceeds_control_budget` rejected. | Complete |
| Negative fixture rejects stale timestamps | `heartbeat_stale_timestamp` rejected. | Complete |
| Negative fixture rejects duplicate signals | `operator_projection_duplicate_signal_id` rejected. | Complete |
| Negative fixture rejects secret-shaped payloads | `nfc_metadata_secret_shaped_pointer` rejected; fixture scan found no secret-shaped strings. | Complete |
| Generated fixtures contain no secrets | `node docs/agent-runs/hardware-signals/NO_SECRET_FIXTURE_SCAN.mjs` found no secret-shaped strings in the generated hardware fixtures. | Complete |
| Raw packet fixtures have schemas | Raw packet keys were compared to `hardware/simulator/schemas/*.schema.json`; every packet type has a schema file. | Complete |
| Full JSON Schema validation passes | `node docs/agent-runs/hardware-signals/AJV_2020_VALIDATION.mjs` passed for every raw packet fixture, the operator projection, the control-plane handoff, and the negative validation report. | Complete |
| Signal schemas are documented | `hardware/simulator/README.md`, `fixtures/hardware/README.md`, and `hardware/flowrouter/FLOWCHAIN_LOCAL_ALPHA_SIGNALS.md` document packet types, projection shape, validation commands, and boundaries. | Complete |
| Control-plane/dashboard handoff shape stable and documented | `fixtures/hardware/flowrouter_control_plane_handoff_seed42.json`, `schemas/flowmemory/hardware-control-plane-handoff.schema.json`, and docs define read-only optional merge collections/id fields/workbench records. | Complete |
| Meshtastic/LoRa remains low-bandwidth control signaling only | `hardware/lora-sidecar/CONTROL_MESSAGE_INVENTORY.md`, `hardware/README.md`, and `hardware/flowrouter/FLOWCHAIN_LOCAL_ALPHA_SIGNALS.md` explicitly reject broadband, app traffic, artifact transfer, and raw AI/model/media transfer over LoRa. | Complete |
| Unsafe claims remain blocked | `node infra/scripts/check-unsafe-claims.mjs` passed. Additional phrase review over changed files found only negative/guardrail statements for manufacturing, broadband/LoRa, ISP replacement, production bridge, public validators, AI-on-chain, and free-storage terms. | Complete |
| Hardware remains optional and cannot block local chain startup | Handoff has `hardwareRequiredForPrivateTestnet=false`; node health has `chain_startup_blocking=false`; bridge alerts have `doesNotBlockLocalChain=true`; docs repeat the boundary. | Complete |
| `git diff --check` passes | Passed; only Git line-ending warnings were emitted. | Complete |
| `npm run flowchain:product-e2e` still passes after changes | Passed after rebasing onto `origin/main` at `14f378b`, which includes PR #132's default-vs-audit Slither policy fix. | Complete |
| If `npm run flowchain:l1-e2e` exists, run it last | The script exists after the rebase and `npm run flowchain:l1-e2e` passed after `flowchain:product-e2e`. | Complete |
| PR output includes fixture list and exact commands run | `EXPERIMENTS.md` records exact commands; final handoff should list raw packet, operator projection, handoff, negative report, and new node/peer schemas. | Ready |
| State optional integration points | `FLOWCHAIN_LOCAL_ALPHA_SIGNALS.md` and this audit identify read-only control-plane collections, workbench records, optional smoke row, and no-startup-blocking boundary. | Ready |
| GitHub PR state checked | Draft PR #139 is open at `https://github.com/FlowmemoryAI/FlowMemory/pull/139`; GitHub CI passed after the hygiene literal fix. | Complete |
| GitHub hardware issue handoff | Added and later updated #105 status comment with fixture list, passing scope/hardware/AJV/no-secret/claim checks, optional handoff shape, retry docs, and #131 blocker reference: `https://github.com/FlowmemoryAI/FlowMemory/issues/105#issuecomment-4446712093`. | Complete |
| Changed-file scope manifest | `CHANGED_FILES.md` lists the current modified/untracked files and confirms they remain inside allowed hardware-signals scope. | Complete |
| Retry path documented | `RETRY_AFTER_131.md` records the exact commands and completion rule that were used after #131 landed. | Complete |

## Product E2E Blocker Resolution

The hardware/signals work is complete inside its allowed scope. The earlier
product-e2e blocker was resolved by rebasing this branch onto `origin/main` at
`14f378b`, which merged PR #132 and changed the default contract hardening gate
so Slither remains explicit audit tooling instead of running merely because it
is installed on `PATH`.

Evidence:

- `slither` is installed at `C:\Users\ntrap\AppData\Roaming\Python\Python311\Scripts\slither.exe`.
- Before rebasing, `npm run flowchain:product-e2e` still failed in this worktree at the known `contracts/bridge/BaseBridgeLockbox.sol` Slither findings.
- GitHub issue #131 was closed by the owning HQ/contracts policy path after PR #132 merged.
- After rebasing onto `origin/main`, exact `npm run flowchain:product-e2e` passed in the unmodified local environment with Slither still on `PATH`.
- The new `npm run flowchain:l1-e2e` wrapper exists after the rebase and passed when run last.
- Product/L1 e2e generated broader launch/dashboard/service artifacts during the run; those side effects were restored so the branch keeps only allowed hardware-signals changes.

Historical re-checks before PR #132 merged:

- `git fetch --all --prune` found `origin/main` still at `9b025c5`.
- Local branch remains two commits behind `origin/main`, but those commits add long-loop/HQ launcher docs/scripts and do not change the Slither blocker.
- GitHub issue #131 is still open.
- PR #110, `[codex] harden bridge lockbox settlement spine`, is still open and draft.
- No merged source-of-truth fix is available to make this hardware branch pass the exact `npm run flowchain:product-e2e` gate with local Slither on `PATH`.
- Added hardware-signals blocker handoff comment to #131:
  `https://github.com/FlowmemoryAI/FlowMemory/issues/131#issuecomment-4446678297`.

Read-only contracts-branch check:

- `origin/agent/full-l1-contracts` is at `497c3b1`.
- That branch does not provide a newer source-of-truth unblock for this hardware worktree.
- The bridge lockbox shape still routes native releases through `releaseNative(...) -> _recordRelease(...) -> recipient.call{value: amount}("")`; `_recordRelease` has a zero-recipient check, but Slither still flags the public `releaseNative` parameter and the low-level native call.

Latest blocker re-check:

- `git fetch --all --prune` completed.
- GitHub issue #131 is still open as of 2026-05-14T01:54:48Z.
- PR #110 is still open and draft.
- `origin/main` remains at `9b025c5`; no merged source-of-truth unblock exists.
- This branch is two commits behind `origin/main`, but those commits add long-loop/HQ launcher material outside this task's allowed hardware-signals edit scope and do not change the product-e2e Slither blocker. The branch was not rebased from this worktree.
- Final re-check in this run: #131 remains open as of 2026-05-14T02:00:17Z, and PR #110 remains open/draft as of 2026-05-14T01:58:27Z.
- Follow-up re-check: #131 remains open as of 2026-05-14T02:09:46Z, and PR #110 remains open/draft as of 2026-05-14T01:58:27Z.
- Later source-of-truth update: #131 closed after PR #132 merged to `main` as `14f378b`.
- Final retry for this branch: `git rebase origin/main`, `npm run flowchain:product-e2e`, and `npm run flowchain:l1-e2e` passed. PR #110 remains open/draft, but it no longer blocks the default product/L1 e2e gate for this branch.

## Conclusion

The prompt-to-artifact audit shows all eight numbered checks are complete after
the rebase and final e2e reruns. Explicit Slither audit findings remain a
contracts/security follow-up, but they no longer block the default product/L1
e2e gate for this hardware-signals branch.
