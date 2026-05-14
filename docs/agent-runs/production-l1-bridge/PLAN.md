# Capped Base 8453 Bridge Pilot Plan

Status: implemented and verified in mock/gated-live modes.

Scope: capped Base public network chain ID `8453` real-value pilot bridge path into local/private FlowChain pilot state.

Safety floor:

- No committed keys, RPC URLs, webhook URLs, seed phrases, or env files with secrets.
- Base live observation must verify `eth_chainId == 0x2105`.
- Live mode must require explicit operator acknowledgement.
- Observation must use a bounded block range and configured confirmation depth.
- Contract custody must remain capped, allowlisted, pausable, emergency-stoppable, and replay-protected.
- Duplicate deposit or release evidence must not apply value twice.

Phases:

1. [x] Read required repository, bridge, and handoff context.
2. [x] Audit existing contract, test, relayer, schema, fixture, script, and package surfaces.
3. [x] Fill contract gaps for caps, allowlist, pause, emergency stop, authorities, replay protection, and deterministic events.
4. [x] Add and repair contract tests for all movement and blocking branches.
5. [x] Build relayer observation, evidence, deterministic IDs, credit, withdrawal intent, release evidence, replay, and export paths.
6. [x] Add guarded Base `8453` deploy, observe, pause, resume, emergency, live readiness, and evidence commands.
7. [x] Add mock pilot E2E that runs without live credentials.
8. [x] Run required checks and write proof artifacts, live command docs, runbook, and handoff.

Live Base status:

- No owner RPC URL, deployer key, or live lockbox address was present in the worktree.
- Live actions are therefore safely blocked until the owner supplies local env values and the required acknowledgement.
- Mock and readiness paths prove the bridge behavior without committing secrets or broadcasting a live transaction.
