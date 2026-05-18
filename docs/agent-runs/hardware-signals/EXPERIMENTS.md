# Hardware Signals Experiments

This run is fixture-first. No physical hardware, manufacturing, firmware flashing, radio deployment, or normal-internet-over-LoRa experiment is in scope.

## Planned Checks

| Check | Command or Method | Result |
| --- | --- | --- |
| Python compile | `python -m py_compile hardware\simulator\flowrouter_sim.py` | Passed |
| Changed-file scope check | `node docs/agent-runs/hardware-signals/SCOPE_CHECK.mjs` | Passed; 27 changed/untracked paths all inside allowed scope |
| Negative cases | `python hardware/simulator/flowrouter_sim.py --run-negative-cases --seed 42` | Passed; 12/12 rejected |
| Fixture generation | `python hardware/simulator/flowrouter_sim.py --generate-fixtures --seed 42` | Passed; wrote raw, operator, handoff, and negative fixtures |
| Packet schema coverage | Compared raw packet keys in `hardware/fixtures/flowrouter_sample_seed42.json` to `hardware/simulator/schemas/*.schema.json` | Passed; schemas present for all packet fixtures |
| Full JSON Schema validation | `node docs/agent-runs/hardware-signals/AJV_2020_VALIDATION.mjs` | Passed; validated all raw packets, operator projection, control-plane handoff, and negative report |
| Fixture secret scan | `node docs/agent-runs/hardware-signals/NO_SECRET_FIXTURE_SCAN.mjs` | Passed; no secret-shaped strings in generated hardware fixtures |
| Unsafe-claim scan | `node infra/scripts/check-unsafe-claims.mjs` | Passed |
| Hardware overclaim phrase review | Searched changed files for manufacturing, broadband/LoRa, ISP replacement, production bridge, public validator, AI-on-chain, and free-storage phrases | Reviewed; matches were negative/guardrail language only |
| Raw packet validation | `python hardware/simulator/flowrouter_sim.py --validate-file hardware/fixtures/flowrouter_sample_seed42.json` | Passed |
| Operator fixture validation | `python hardware/simulator/flowrouter_sim.py --validate-operator-file fixtures/hardware/flowrouter_local_alpha_seed42.json` | Passed |
| Handoff validation | `python hardware/simulator/flowrouter_sim.py --validate-handoff-file fixtures/hardware/flowrouter_control_plane_handoff_seed42.json` | Passed |
| Negative report validation | `python hardware/simulator/flowrouter_sim.py --validate-negative-report-file fixtures/hardware/flowrouter_negative_validation_seed42.json` | Passed |
| Hardware smoke | `npm run flowchain:hardware:smoke` | Passed; 12 negative cases |
| Diff whitespace | `git diff --check` | Passed |
| Product e2e, unmodified environment | `npm run flowchain:product-e2e` | Failed before product checks because optional Slither was present on PATH and reported existing `contracts/bridge/BaseBridgeLockbox.sol` findings outside hardware scope |
| Product e2e, Slither absent from PATH | `$oldPath = $env:Path; $slitherSource = (Get-Command slither -ErrorAction SilentlyContinue).Source; if ($slitherSource) { $slitherDir = Split-Path -Parent $slitherSource; $env:Path = (($oldPath -split ';') | Where-Object { $_ -and (-not [string]::Equals($_.TrimEnd('\\'), $slitherDir.TrimEnd('\\'), [System.StringComparison]::OrdinalIgnoreCase)) }) -join ';' }; npm run flowchain:product-e2e; $code = $LASTEXITCODE; $env:Path = $oldPath; exit $code` | Passed; matches repo docs that Slither is audit-environment tooling unless explicitly required |
| Product e2e, historical completion audit rerun | `npm run flowchain:product-e2e` | Failed before PR #132 landed because the default hardening gate still ran local Slither when present on `PATH` |
| Product e2e, latest source-of-truth retry | `git fetch --all --prune`; `git rebase origin/main`; `npm run flowchain:product-e2e` | Passed after rebasing onto `origin/main` at `14f378b`; default hardening now warns that Slither is optional instead of failing merely because Slither is on `PATH` |
| L1 e2e if present | `npm run flowchain:l1-e2e` | Passed after `flowchain:product-e2e`; this script exists after the rebase |

## Constraints

- Fixtures must be deterministic and small.
- Fixtures must not contain secrets, private keys, mnemonics, seed phrases, RPC credentials, API keys, or webhook URLs.
- Meshtastic/LoRa signal examples remain low-bandwidth control messages only.
- Hardware signals are optional advisory inputs and must not block local chain startup.
