# Private/Local L1-Shaped RPC Plan

## Mission

Expose the full FlowChain L1 through the existing `services/control-plane/` API surface without creating a second service, while keeping responses free of secrets and explicit about runtime provenance.

## Scope

Allowed folders:

- `services/control-plane/`
- `services/shared/`
- `schemas/flowmemory/`
- `docs/FLOWCHAIN_CONTROL_PLANE_API.md`
- `docs/agent-runs/production-l1-rpc/`
- `package.json` only for API aliases

Forbidden folders:

- `crates/` implementation
- `contracts/`
- `crypto/` secret-handling internals
- `apps/dashboard/`
- `hardware/`
- local secret files

## Phases

1. Inventory current control-plane routes, schemas, tests, and runtime/storage handoffs.
2. Map every required L1 surface to an existing JSON-RPC method or a new method inside the current service.
3. Add versioned request/response schemas and one versioned error envelope.
4. Wire handlers to live local runtime state where available, with explicit fallback provenance.
5. Add signed transaction intake validation, rejection paths, duplicate detection, and receipt visibility.
6. Add events, account, token, DEX, bridge, finality, sync, and diagnostics query coverage.
7. Extend smoke tests to call every private/local L1-shaped method, validate responses, and run the no-secret scanner.
8. Run required commands and record proof artifacts.

## Stop Condition

Stop only when the existing control-plane API can submit and inspect a signed local L1 transaction, expose all dashboard and bridge query surfaces, return structured errors, validate schemas in smoke, and prove no route returns secret-shaped material.
