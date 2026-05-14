# Handoff

## Scope Completed

The existing `services/control-plane/` JSON-RPC API now exposes the private/local L1-shaped FlowChain surface without creating a second API service.

## Key Files

- API handlers: `services/control-plane/src/methods.ts`
- Error envelope: `services/control-plane/src/errors.ts`
- Signed envelope helper: `services/control-plane/src/transaction-envelope.ts`
- Smoke client: `services/control-plane/src/smoke.ts`
- Schema catalog: `schemas/flowmemory/control-plane-production-l1.schema.json`
- API docs: `docs/FLOWCHAIN_CONTROL_PLANE_API.md`
- Endpoint matrix: `docs/agent-runs/production-l1-rpc/ENDPOINT_MATRIX.md`

## Methods Added Or Tightened

Added:

- `sync_status`
- `finality_status`
- `event_list`
- `event_get`
- `bridge_config_get`
- `bridge_status`
- `withdrawal_intent_list`
- `withdrawal_intent_get`
- `release_evidence_list`
- `release_evidence_get`
- `replay_rejection_list`
- `replay_rejection_get`

Tightened:

- `transaction_submit`
- `receipt_get`
- `balance_get`
- `bridge_observation_submit`
- `chain_status`
- `node_status`

## Request And Response Schemas

Schema catalog path:

```text
schemas/flowmemory/control-plane-production-l1.schema.json
```

The full method-to-schema matrix is in:

```text
docs/agent-runs/production-l1-rpc/ENDPOINT_MATRIX.md
```

## Smoke Command

```powershell
npm run control-plane:smoke
```

Observed result:

- `methodCount: 91`
- `successCount: 87`
- `expectedErrorCount: 4`
- `noSecretScan.findingCount: 0`

## Dashboard Fields

Dashboard field contract:

```text
docs/agent-runs/production-l1-rpc/DASHBOARD_CONTRACT.md
```

High-priority views:

- status: `chain_status`, `node_status`, `sync_status`, `finality_status`;
- explorer: `block_list`, `transaction_list`, `event_list`, `receipt_get`;
- accounts: `account_list`, `balance_get`, `wallet_metadata_list`;
- tokens/DEX: `token_list`, `pool_list`, `lp_position_list`, `swap_list`;
- bridge: `bridge_config_get`, `bridge_status`, `bridge_observation_list`, `bridge_credit_list`, `withdrawal_intent_list`, `release_evidence_list`, `replay_rejection_list`;
- diagnostics: `raw_json_get`, `provenance_get`.

## Known Blockers And Caveats

- Live long-running runtime state is not present in this worktree (`devnet/local/state.json` is absent), so responses mark fallback provenance instead of claiming live state.
- Signed transaction verification uses a deterministic local digest scheme for the private/local testnet path. It is not production custody or audited cryptography.
- Accepted submits write local intake rows and expose local receipts immediately. Public-chain broadcast is not implemented or claimed.
- DEX detail methods return explicit diagnostic empty projections when no live pools, positions, or swaps are present, so dashboard detail contracts stay stable without hiding fallback provenance.
- Release evidence returns a pending projection when withdrawal intent exists but no release record has been exported.
