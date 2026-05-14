# Real-Value Pilot Control-Plane/Dashboard Notes

## Operating Boundary

- The pilot must be labeled as capped owner testing.
- The dashboard must not imply broad public readiness.
- Browser state must not store private keys, mnemonics, seed phrases, RPC credentials, API keys, or webhooks.
- Base mainnet chain ID is `8453`; current bridge fixtures are Base Sepolia/mock unless a live pilot handoff appears.

## Handoff Shape Notes

- Bridge relayer `BridgeRuntimeHandoff` contains `observations`, `credits`, `withdrawalIntents`, `replayProtection`, `runtimeIntake`, `workbenchTimeline`, `workbenchRecords`, and `limitations`.
- Bridge observations include `mode`, `replayKey`, `guardrails`, `productionReady: false`, and nested `deposit`.
- Bridge credits include `status: pending|applied|rejected`, `replayKey`, source chain/contract/tx/log, amount, token, and recipient.
- Withdrawal intents are test-mode records with `broadcast: false` and `releasePolicy: test_record_only` in the current handoff.
- Runtime long-loop handoff uses `bridgeCredits` maps in local devnet state/control-plane handoff.

## API Design Notes

Implemented pilot-specific JSON-RPC methods:

- `pilot_status`
- `pilot_deposit_observation_list`
- `pilot_credit_list`
- `pilot_withdrawal_intent_list`
- `pilot_release_evidence_list`
- `pilot_cap_status`
- `pilot_pause_status`
- `pilot_retry_status`
- `pilot_emergency_status`

HTTP read endpoints mirror those methods under `/pilot/*`.

## Verification Notes

- The fixture-backed pilot state is currently `degraded` because mock/local/Base Sepolia evidence is visible but no Base mainnet chain ID `8453` pilot deposit is loaded.
- The dashboard renders that degraded state directly and keeps the next operator command from the API visible.
- The pilot API and E2E scanner reject or fail on private key, seed phrase, mnemonic, RPC credential, API key, and webhook-shaped material.
- Browser evidence is source-level so far: the dashboard fetches `/pilot/status`, renders `realValuePilot`, and contains no `localStorage.setItem` for keys or RPC secrets.

## GitHub Source Of Truth

- Issue #131 tracks the Slither/audit-gate follow-up: https://github.com/FlowmemoryAI/FlowMemory/issues/131
- PR #110 is the active contracts hardening PR related to bridge lockbox work: https://github.com/FlowmemoryAI/FlowMemory/pull/110
- Added a branch-specific evidence comment to issue #131: https://github.com/FlowmemoryAI/FlowMemory/issues/131#issuecomment-4446815478
- This branch was rebased onto `origin/main` commit `f384236` (`Refresh real-value pilot HQ status`).
- Upstream `docs/FLOWCHAIN_REAL_VALUE_PILOT.md` expects the control-plane/dashboard owner proof command `npm run flowchain:real-value-pilot:control-dashboard`; this branch now provides that command and verifies it.
- Added branch evidence to issue #137: https://github.com/FlowmemoryAI/FlowMemory/issues/137#issuecomment-4446943001

## Current Gate Notes

- Bare `npm run flowchain:product-e2e` now passes because the upstream optional Slither policy is present via rebase.
- Bare `npm run flowchain:real-value-pilot:e2e` now runs the upstream final HQ pilot gate and reports missing contracts, bridge, runtime, wallet, and ops proof commands.
- This branch's owner-specific proof command is `npm run flowchain:real-value-pilot:control-dashboard`, and it passes.
