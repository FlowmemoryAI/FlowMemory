# Real-Value Pilot Bridge Relayer Plan

Status: implemented on branch `agent/real-value-pilot-bridge-proof`; pending
PR for issue #138.

## Scope

Implement the bridge relayer path for a tiny capped Base public-network pilot on
chain ID `8453`. The relayer must observe only an explicit approved lockbox,
derive deterministic bridge observation, credit, and evidence objects, hand the
credit to local FlowChain exactly once, and emit pilot withdrawal/release
evidence without broadcasting a release.

## Allowed Edit Areas

- `services/bridge-relayer/`
- `fixtures/bridge/`
- `schemas/flowmemory/bridge*.json`
- `infra/scripts/bridge-*.ps1`
- `infra/scripts/flowchain-real-value*.ps1`
- `docs/bridge/`
- `docs/agent-runs/real-value-pilot-bridge/`

## Implementation Steps

1. Preserve the existing mock, local Anvil, Base Sepolia, and read-only Base
   canary paths.
2. Add a distinct `base-mainnet-pilot` mode for explicit, capped Base `8453`
   observation.
3. Require approved lockbox addresses for the pilot observer and reject
   unapproved contracts before reading logs.
4. Add confirmation-depth support using `eth_blockNumber` before `eth_getLogs`.
5. Generate deterministic observation, credit, runtime handoff, pilot evidence,
   and release-evidence artifacts.
6. Add exactly-once local credit application state for pilot/mock E2E replay
   checks.
7. Add a no-RPC mock pilot E2E and a PowerShell wrapper that prints exact next
   operator commands after every step.
8. Update bridge docs with mock and live pilot commands, env vars, replay
   behavior, and failure/retry behavior.
9. Run the requested bridge tests, pilot mock E2E, wrong-chain tests, local
   credit smoke, and product E2E.

## Boundary

This is not a production bridge, public deposit launch, audited security claim,
or production release authority path. Live Base `8453` mode is read-only until
the relayer derives local artifacts; it does not sign or broadcast release
transactions.
