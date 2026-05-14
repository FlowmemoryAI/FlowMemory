# Live Node Bridge Intake Evidence

Status: EXTERNAL-BLOCKED on live Base 8453 handoff availability.

Run directory:

```text
devnet/local/live-l1-bridge-intake/
```

## What Changed

- Added unbounded background node start wrapper:
  `npm run flowchain:node:start`.
- Added explicit live bridge handoff intake:
  `npm run flowchain:bridge:ingest -- -HandoffPath <handoff>`.
- Added bridge credit receipts in main runtime state:
  `bridgeCreditReceipts`.
- Preserved replay protection against the Base
  `sourceChainId/sourceContract/txHash/logIndex` event, even if a duplicate
  handoff changes `replayKey`.
- Added spend proof, restart/export/import proof, live status report, and
  no-secret scan wrappers:
  `flowchain:wallet:transfer:e2e`, `flowchain:restart:verify`,
  `flowchain:live-bridge:status`, and `flowchain:no-secret:scan`.
- Added latency fields on bridge credit receipts:
  `baseObservedAt`, `handoffWrittenAt`, `nodeIngestedAt`, `creditAppliedAt`,
  `firstSpendableAt`, and `totalSeconds`.

## Commands Run

```powershell
cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml
npm run flowchain:node:start
npm run flowchain:node:status
npm run flowchain:node:smoke
npm run flowchain:no-secret:scan
```

Results:

- `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml`: passed,
  28 Rust integration tests.
- `npm run flowchain:node:start`: passed. Report:
  `devnet/local/live-l1-bridge-intake/node-start-report.json`.
- `npm run flowchain:node:status`: passed. Persisted node status reported
  `status=running`, `nodeId=node:local:live-pilot`, chain id `31337`, and
  `bridgeCredits=0`.
- `npm run flowchain:node:smoke`: passed. Report:
  `devnet/local/node-smoke/production-node-smoke-report.json`.
- `npm run flowchain:no-secret:scan`: passed. Report:
  `devnet/local/live-l1-bridge-intake/no-secret-scan-report.json`.

## External Blocker

No explicit live Base 8453 bridge runtime handoff exists in this worktree.
Checked:

```text
services/bridge-relayer/out/
devnet/local/live-base8453-pilot-runtime/
devnet/local/
```

The required live intake command is therefore not run to completion yet:

```powershell
npm run flowchain:bridge:ingest -- -HandoffPath devnet/local/live-base8453-pilot-runtime/base8453-handoff-applied.json
npm run flowchain:wallet:transfer:e2e
npm run flowchain:restart:verify
npm run flowchain:live-bridge:status
```

The handoff must be a real `flowmemory.bridge_runtime_handoff.v0` artifact with
`productionReady=true`, `localOnly=false`, Base source chain id `8453`, and
satisfied 12-confirmation evidence. Fixture or mock data should not be relabeled
as live to satisfy this gate.

## Current Main State

The main runtime state is:

```text
devnet/local/state.json
```

Current status after unbounded node start:

- Node is running and producing blocks.
- `bridgeCredits=0`.
- `bridgeCreditReceipts=0`.
- `bridgeReplayKeys=0`.

This matches the verified failure fact that bridge proof output is not currently
landing in main node state because the live handoff artifact is absent.

## Next Command

After the bridge proof path writes the real live handoff file, run:

```powershell
npm run flowchain:bridge:ingest -- -HandoffPath <explicit-live-base8453-handoff>
npm run flowchain:wallet:transfer:e2e
npm run flowchain:restart:verify
npm run flowchain:live-bridge:status
npm run flowchain:no-secret:scan
git diff --check
```
