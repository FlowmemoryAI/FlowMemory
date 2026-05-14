# Completion Audit

## Objective

Expose the private/local FlowChain L1-shaped surface through the existing `services/control-plane/` API with versioned schemas, response provenance, signed transaction submit/query, bridge/dashboard coverage, no-secret scanning, required proof artifacts, and green command gates.

## Prompt-To-Artifact Checklist

| Requirement | Evidence |
| --- | --- |
| Use the existing control-plane API; do not create a second service. | Implementation is in `services/control-plane/src/methods.ts`, `server.ts`, `types.ts`, `errors.ts`, `smoke.ts`, and `transaction-envelope.ts`. No new API service was added. |
| Create tracking files first. | `PLAN.md`, `CHECKLIST.md`, `EXPERIMENTS.md`, and `NOTES.md` exist in this directory. |
| Keep edits in allowed folders. | Final content diff is limited to `services/control-plane/`, `schemas/flowmemory/`, `docs/FLOWCHAIN_CONTROL_PLANE_API.md`, and this run directory. |
| Signed transaction submit validates a versioned signed envelope and rejects unsigned requests. | `transaction-envelope.ts` defines `flowchain.signed_transaction_envelope.v1`; `transaction_submit` rejects unsigned input with `UNSIGNED_TRANSACTION`; tests cover both paths. |
| Submit checks chain ID, signer, nonce, signature, payload schema, duplicate tx, stale nonce, wrong chain, and invalid signature. | `transaction_submit` in `methods.ts`; smoke expected errors are `BAD_SIGNATURE`, `DUPLICATE_TX`, `WRONG_CHAIN_ID`, and `STALE_NONCE`. |
| Query methods cover chain/node/peers/sync/finality/block/tx/receipt/events/account/balance/token/pool/LP/swap/bridge/diagnostic JSON surfaces. | `ENDPOINT_MATRIX.md` lists 91 smoke-covered methods with request schema, response schema, source component, dashboard consumer, and smoke test name. |
| Every route has explicit request and response schemas. | `schemas/flowmemory/control-plane-production-l1.schema.json` publishes the method catalog; smoke validates every success result schema against it. |
| Runtime source of truth prefers live state and marks fallback provenance. | Success responses include `responseProvenance`; `API_SURFACE.md`, `DASHBOARD_CONTRACT.md`, and `FLOWCHAIN_CONTROL_PLANE_API.md` document live/imported/deterministic fixture/unavailable provenance. |
| No-secret scanner covers every smoke response and mapped browser-safe route body. | `NO_SECRET_PROOF.md`; smoke result scanned 91 responses with `findingCount: 0`; the control-plane HTTP test scans `/health`, `/state`, `/explorer/summary`, `/product-flow/status`, `/rpc`, `/bridge/observations`, and `/pilot/*` route bodies. |
| Versioned error envelope and required codes. | `ERROR_MODEL.md`; `errors.ts` emits `flowmemory.control_plane.error.v1` with machine code, message, correlation ID, recoverable, retryable, and source component. |
| At least one signed transaction is submitted or validated and later queried with a receipt and balance/state change. | `SUBMIT_QUERY_PROOF.md` and `SUBMIT_LOOP_PROOF.md`; smoke submits a signed transfer, queries `transaction_get`, `receipt_get`, and recipient `balance_get`. |
| Bridge API loop is covered. | `BRIDGE_API_PROOF.md`; smoke covers bridge config/status, observation, credit, withdrawal intent, release evidence, and replay rejection list/detail paths. |
| Dashboard contract fields are stable and documented. | `DASHBOARD_CONTRACT.md` and `DASHBOARD_FIELD_PROOF.md`. |
| Raw JSON diagnostics are local and safe. | `raw_json_get` is in the schema catalog, matrix, and smoke; responses are no-secret scanned. |
| Required proof artifacts are present. | `API_SURFACE.md`, `ERROR_MODEL.md`, `NO_SECRET_PROOF.md`, `SUBMIT_QUERY_PROOF.md`, `ENDPOINT_MATRIX.md`, `SUBMIT_LOOP_PROOF.md`, `BRIDGE_API_PROOF.md`, `DASHBOARD_FIELD_PROOF.md`, `SCHEMA_VALIDATION_PROOF.md`, `DASHBOARD_CONTRACT.md`, and `HANDOFF.md`. |
| `npm test --prefix services/control-plane` passes. | Passed: 21 tests, 0 failures. |
| `npm run control-plane:smoke` passes and calls every private/local L1-shaped method. | Passed: `methodCount: 91`, `successCount: 87`, `expectedErrorCount: 4`, `noSecretScan.findingCount: 0`. |
| `npm run flowchain:l1-e2e` passes after integration. | Passed full private/local smoke gate, including service, crypto, launch, dashboard, bridge, hardware, and control-plane gates. |
| `git diff --check` passes. | Passed with no whitespace errors; only Windows LF/CRLF warnings were emitted. |

## Residual Caveats

- Live long-running runtime state is not present in this worktree, so the API marks fallback provenance instead of claiming live state.
- The signed transaction path uses deterministic local testnet validation, not production custody or audited cryptography.
- Accepted transactions are persisted as local intake rows with immediate local receipts; no public-chain broadcast is implemented or claimed.
