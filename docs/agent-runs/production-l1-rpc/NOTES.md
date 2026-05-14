# Private/Local L1-Shaped RPC Notes

## Initial Context

- Current branch: `agent/production-l1-rpc`.
- The existing control-plane API is JSON-RPC 2.0 under `services/control-plane/`.
- Existing documentation describes the service as local runtime/fixture-backed V0, not a production RPC endpoint.
- This task must expose the private/local L1-shaped surface through the existing control-plane boundary while keeping live/fixture provenance explicit.

## Guardrails

- Do not create a second API service.
- Do not edit forbidden folders.
- Do not hardcode or return secrets.
- Do not silently substitute fixtures for live state.
- Keep schemas, smoke cases, error shapes, and no-secret assertions in sync.

## Implementation Notes

- `transaction_submit` now accepts only `flowchain.signed_transaction_envelope.v1`.
- The smoke client builds a no-secret local signed transfer using `flowchain-local-digest-v1`.
- Every success result is annotated with `responseProvenance`.
- The schema catalog is source-checked by smoke before success.
- The current worktree has no live `devnet/local/state.json`; fallback state is marked as deterministic fixture/imported provenance.
