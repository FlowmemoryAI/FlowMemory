# Hardware Signals PR Summary

## What Changed

- Extended the FlowRouter simulator with deterministic optional operator-signal packets for:
  - heartbeat
  - emergency/offline alert
  - compact receipt relay
  - verifier report digest relay
  - bridge alert
  - NFC memory cartridge metadata
  - node health
  - peer hint
- Added `node_health` and `peer_hint` simulator schemas.
- Regenerated seed 42 hardware fixtures:
  - `hardware/fixtures/flowrouter_sample_seed42.json`
  - `fixtures/hardware/flowrouter_local_alpha_seed42.json`
  - `fixtures/hardware/flowrouter_control_plane_handoff_seed42.json`
  - `fixtures/hardware/flowrouter_negative_validation_seed42.json`
- Expanded operator projections into `hardwareSignals`, `operatorMetadata`, `hardwareNodes`, `nodeHealth`, `peerHints`, `workReceipts`, `verifierReports`, `bridgeAlerts`, `artifactCommitments`, `memoryCells`, `challenges`, `finalityReceipts`, `alerts`, and `workbenchRecords`.
- Documented the control-plane/dashboard handoff shape and the Meshtastic/LoRa low-bandwidth control-only boundary.

## Why It Changed

FlowRouter/Meshtastic-style signals should be useful to local control-plane and workbench consumers without requiring physical hardware or blocking local chain startup. These fixtures provide deterministic optional operator-signal input while keeping all hardware state local-only, advisory, and reconciliation-bound.

## Fixture List

- Raw packet fixture: `hardware/fixtures/flowrouter_sample_seed42.json`
- Operator projection: `fixtures/hardware/flowrouter_local_alpha_seed42.json`
- Control-plane handoff: `fixtures/hardware/flowrouter_control_plane_handoff_seed42.json`
- Negative validation report: `fixtures/hardware/flowrouter_negative_validation_seed42.json`
- New packet schemas:
  - `hardware/simulator/schemas/node_health.schema.json`
  - `hardware/simulator/schemas/peer_hint.schema.json`

## Optional Integration Points

- Control plane can read `flowmemory.hardware_control_plane_handoff.local_alpha.v0` as `mode=read-only-optional-merge`.
- Stable merge ids are declared under `ingest.idFields`.
- Workbench can either render `workbenchRecords` directly or re-project canonical collections.
- `optionalSmokeRows` names `python hardware/simulator/flowrouter_sim.py --smoke` as optional hardware evidence.
- Hardware is never required for private/local chain startup: `hardwareRequiredForPrivateTestnet=false`, node health has `chainStartupBlocking=false`, and bridge alerts have `doesNotBlockLocalChain=true`.

## Checks Run

Passed:

```powershell
python -m py_compile hardware\simulator\flowrouter_sim.py
node docs/agent-runs/hardware-signals/SCOPE_CHECK.mjs
python hardware/simulator/flowrouter_sim.py --run-negative-cases --seed 42
python hardware/simulator/flowrouter_sim.py --generate-fixtures --seed 42
python hardware/simulator/flowrouter_sim.py --validate-file hardware/fixtures/flowrouter_sample_seed42.json
python hardware/simulator/flowrouter_sim.py --validate-operator-file fixtures/hardware/flowrouter_local_alpha_seed42.json
python hardware/simulator/flowrouter_sim.py --validate-handoff-file fixtures/hardware/flowrouter_control_plane_handoff_seed42.json
python hardware/simulator/flowrouter_sim.py --validate-negative-report-file fixtures/hardware/flowrouter_negative_validation_seed42.json
npm run flowchain:hardware:smoke
node docs/agent-runs/hardware-signals/AJV_2020_VALIDATION.mjs
node docs/agent-runs/hardware-signals/NO_SECRET_FIXTURE_SCAN.mjs
node infra/scripts/check-unsafe-claims.mjs
git diff --check
git fetch --all --prune
git rebase origin/main
npm run flowchain:product-e2e
npm run flowchain:l1-e2e
```

Conditional/pass with documented environment adjustment:

```powershell
$oldPath = $env:Path; $slitherSource = (Get-Command slither -ErrorAction SilentlyContinue).Source; if ($slitherSource) { $slitherDir = Split-Path -Parent $slitherSource; $env:Path = (($oldPath -split ';') | Where-Object { $_ -and (-not [string]::Equals($_.TrimEnd('\\'), $slitherDir.TrimEnd('\\'), [System.StringComparison]::OrdinalIgnoreCase)) }) -join ';' }; npm run flowchain:product-e2e; $code = $LASTEXITCODE; $env:Path = $oldPath; exit $code
```

This passed only when the user-local Slither script directory was removed from `PATH` for the command.

Previously blocked, now resolved:

```powershell
npm run flowchain:product-e2e
npm run flowchain:l1-e2e
```

The exact product E2E command originally failed because local `slither.exe` was present on `PATH` and reported existing `missing-zero-check` and `low-level-calls` findings in `contracts/bridge/BaseBridgeLockbox.sol`. GitHub issue #131 was later closed by the owning HQ/contracts policy path in PR #132. After rebasing this branch onto `origin/main` at `14f378b`, exact `npm run flowchain:product-e2e` passed in the unmodified environment, and `npm run flowchain:l1-e2e` passed last.

Historical blocker handoff:

- GitHub issue: `https://github.com/FlowmemoryAI/FlowMemory/issues/131`
- Hardware evidence comment: `https://github.com/FlowmemoryAI/FlowMemory/issues/131#issuecomment-4446678297`
- PR #132 resolved the default product/L1 e2e blocker on `main`; explicit Slither audit findings remain visible through `contracts:hardening:slither`.

## Risks, Assumptions, Follow-Ups

- Risk: explicit `contracts:hardening:slither` still surfaces the known bridge lockbox audit findings, so do not treat this as an audit/public-readiness claim.
- Assumption: hardware fixtures remain optional advisory inputs, not authority for chain state, verifier finality, bridge settlement, or dashboard truth.
- Follow-up: keep PR #139 draft until review confirms the optional handoff shape and merge order.
