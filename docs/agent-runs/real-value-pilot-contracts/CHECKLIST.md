# Real-Value Pilot Contracts Checklist

## Acceptance

- [x] `forge test` passes.
- [x] `npm run contracts:hardening` passes.
- [x] Lockbox supports chain ID `8453` deployment configuration.
- [x] Contract enforces per-deposit cap and total pilot cap.
- [x] Contract supports allowlisted asset(s) only.
- [x] Pause blocks deposits.
- [x] Authorized release/recovery path remains possible while paused.
- [x] Replay protection prevents duplicate release/deposit accounting.
- [x] Events contain deterministic relayer inputs without contract-side
  `txHash`/`logIndex` assumptions.
- [x] Dry-run deployment script exists.
- [x] Broadcast deployment script requires explicit local env ack and never
  commits keys.
- [x] Verification/source command or instructions exist.
- [x] Contract docs explain owner, release authority, cap, pause, replay, and
  emergency assumptions.
- [x] `npm run flowchain:product-e2e` still passes or breakage is assigned.

## Work Items

- [x] Read required repo docs.
- [x] Inspect current main contracts and tests.
- [x] Inspect `E:\FlowMemory\flowmemory-contracts` active long-loop work.
- [x] Inspect `E:\FlowMemory\flowmemory-bridge-full` event expectations.
- [x] Update settlement object vocabulary and tests.
- [x] Update deployment gating for Base `8453` pilot.
- [x] Update bridge and deployment docs.
- [x] Run verification commands and record exact results.
