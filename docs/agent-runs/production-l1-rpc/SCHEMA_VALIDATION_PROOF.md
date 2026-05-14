# Schema Validation Proof

Published schema catalog:

```text
schemas/flowmemory/control-plane-production-l1.schema.json
```

The catalog defines:

- every JSON-RPC method name;
- request schema name;
- response schema name;
- success result schema name;
- versioned error envelope fields and required error codes.

Smoke validation behavior:

1. Loads the catalog from `schemas/flowmemory/control-plane-production-l1.schema.json`.
2. Calls the 91-case private/local L1-shaped smoke batch.
3. For every success response, verifies the method is in the catalog.
4. Verifies each result `schema` matches the catalog result schema.
5. For expected errors, verifies `flowmemory.control_plane.error.v1` and required fields:
   - `errorCode`
   - `message`
   - `correlationId`
   - `recoverable`
   - `retryable`
   - `sourceComponent`
6. Scans every response for secret-shaped material.

Command result:

```text
npm run control-plane:smoke
methodCount: 91
successCount: 87
expectedErrorCount: 4
findingCount: 0
```

Backward compatibility note:

Most existing result shapes keep their `*.v0` schema names. The new transaction submit result uses `flowmemory.control_plane.transaction_submit_result.v1`, and the error envelope uses `flowmemory.control_plane.error.v1`. Existing dashboard-facing field names were preserved where possible; new fields are additive.
