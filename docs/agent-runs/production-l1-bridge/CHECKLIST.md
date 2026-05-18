# Capped Base 8453 Bridge Pilot Checklist

## Context

- [x] `AGENTS.md`
- [x] `docs/START_HERE.md`
- [x] `docs/FLOWMEMORY_HQ_CONTEXT.md`
- [x] `docs/CURRENT_STATE.md`
- [x] `docs/ROOTFLOW_V0.md`
- [x] `docs/FLOW_MEMORY_V0.md`
- [x] `docs/V0_LAUNCH_ACCEPTANCE.md`
- [x] Bridge POC docs and existing handoffs

## Contract

- [x] Base chain ID `8453` deployment configuration
- [x] Asset allowlist or documented native-only decision
- [x] Per-deposit cap
- [x] Total pilot cap
- [x] Deposit pause
- [x] Emergency stop
- [x] Owner authority
- [x] Release authority separation where possible
- [x] Replay protection for deposits and releases
- [x] Deterministic relayer event fields
- [x] Contract tests for happy path and refusal paths

## Relayer

- [x] `eth_chainId == 0x2105` live gate
- [x] Operator acknowledgement live gate
- [x] Required env validation without secret logging
- [x] Bounded block scan
- [x] Confirmation-depth checks
- [x] Deterministic observation ID
- [x] Deterministic credit ID
- [x] Evidence JSON export
- [x] Credit exactly once
- [x] Duplicate/replay handling
- [x] Withdrawal intent
- [x] Release evidence
- [x] Secret-free evidence bundle export

## Ops

- [x] Dry-run deploy command
- [x] Broadcast deploy command with acknowledgement
- [x] Observe command
- [x] Credit command
- [x] Replay check command
- [x] Withdrawal intent command
- [x] Release evidence command
- [x] Pause command
- [x] Resume command
- [x] Emergency stop command
- [x] Evidence export command
- [x] Deterministic fixture bridge E2E command
- [x] Live readiness check command

## Proof

- [x] `CONTRACT_PROOF.md`
- [x] `RELAYER_PROOF.md`
- [x] `MOCK_PILOT_E2E_PROOF.md`
- [x] `REPLAY_PROOF.md`
- [x] `LIVE_READINESS_PROOF.md`
- [x] `OWNER_LIVE_TEST_COMMANDS.md`
- [x] `ASSET_DECISION.md`
- [x] `DEPLOYMENT_READINESS_PROOF.md`
- [x] `DEPOSIT_EVENT_PROOF.md`
- [x] `LIVE_OBSERVATION_GATE_PROOF.md`
- [x] `CREDIT_APPLICATION_PROOF.md`
- [x] `REAL_FUNDS_PILOT_RUNBOOK.md`
- [x] `WITHDRAW_RELEASE_PROOF.md`
- [x] `FULL_MOCK_PILOT_PROOF.md`
- [x] `HANDOFF.md`

## Verification

- [x] `forge test`
- [x] `npm test --prefix services/bridge-relayer`
- [x] `npm run flowchain:bridge:local-credit:smoke`
- [x] `npm run flowchain:real-value-pilot:bridge`
- [x] `npm run flowchain:bridge:live:check`
- [x] `npm run flowchain:bridge:command-matrix`
- [x] `npm run flowchain:bridge:no-secret-audit`
- [x] `npm run flowchain:real-value-pilot:e2e`
- [x] `git diff --check`
