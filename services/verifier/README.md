# FlowMemory Verifier MVP

Status: specification draft.

The verifier MVP reads FlowPulse observations, reconstructs commitments, checks evidence, and emits deterministic reports. It does not run a production service, proof network, or token system.

## Inputs

- decoded FlowPulse log
- receipt/log metadata used to derive `observationId`
- artifact manifest and Merkle openings, when required
- storage receipt commitment openings, when required
- worker signature envelope, when required
- verifier policy document hash

## Import Strategy

There is no `services/shared/` package yet. Until one exists, verifier code should import or mirror the package under `crypto/`:

```js
import {
  flowPulseObservationId,
  flowPulseEventArgsHash,
  receiptHash,
  verifierReportHash,
  verifierSignaturePayload,
  verifyDigest
} from "../../crypto/src/index.js";
```

If the verifier cannot import directly, it must run equivalent tests against `crypto/fixtures/`, `crypto/fixtures/vectors.json`, and `crypto/test-vectors/`. The compatibility gate is:

```powershell
cd E:\FlowMemory\flowmemory-crypto\crypto
npm test
npm run validate:vectors
python validate_test_vectors.py
```

## Deterministic Report Flow

1. Recompute `observationId`.
2. Recompute `eventArgsHash`.
3. Recompute `receiptHash`.
4. Recompute artifact root and storage commitment if openings are supplied.
5. Verify worker signatures if policy requires them.
6. Evaluate finality and reorg status.
7. Produce canonical checks JSON or a checks Merkle root.
8. Produce `reportId`.
9. Sign `reportId` with the verifier signature envelope.

## Status Vocabulary

```text
0 = reserved
1 = observed
2 = verified
3 = unresolved
4 = unsupported
5 = failed
6 = reorged
7 = superseded
```

Minimum requirements:

- `observed`: receipt/log parsed and observation id computed.
- `verified`: all policy-required checks passed.
- `unresolved`: required evidence is missing or unavailable.
- `unsupported`: schema, pulse type, root scheme, or key type is unknown.
- `failed`: a policy-required check failed.
- `reorged`: block/log is not canonical under finality policy.
- `superseded`: a newer report intentionally replaces this report.

## Non-Goals

- No live RPC integration in this spec.
- No database schema.
- No API server.
- No zk proof implementation.
- No verifier economics.
- No tokenomics.
