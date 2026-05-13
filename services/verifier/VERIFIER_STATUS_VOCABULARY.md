# Verifier Status Vocabulary

This document defines the V0 verifier report statuses used by the runnable fixture package.

## V0 Report Statuses

### valid

Meaning: Supported deterministic checks passed against allowed fixture evidence.

Minimum evidence:

- Complete indexed observation.
- Observation is not `removed` or `reorged`.
- Pulse type has a V0 verifier rule.
- Required fixture artifact exists under the resolver policy.
- Subject and commitment checks pass.

### invalid

Meaning: Supported deterministic checks ran and at least one required check failed.

Minimum evidence:

- Complete indexed observation.
- Pulse type has a V0 verifier rule.
- Required fixture artifact exists.
- A deterministic mismatch was found.

Typical reason codes:

- `subject.mismatch`
- `commitment.mismatch`
- `artifact.schema_mismatch`

### unresolved

Meaning: Required evidence is missing or rejected by resolver policy.

Minimum evidence:

- Complete indexed observation.
- Resolver policy produced a deterministic failure reason.

Typical reason codes:

- `artifact.unavailable`
- `artifact.too_large`

### unsupported

Meaning: The verifier cannot evaluate this observation under V0 rules.

Minimum evidence:

- Observation was decoded far enough to identify unsupported semantics.

Typical reason codes:

- `pulse.type.unsupported`

### reorged

Meaning: The observation is removed or no longer canonical.

Minimum evidence:

- Indexer lifecycle state is `removed` or `reorged`.

Typical reason codes:

- `observation.reorged`

## Status Selection Order

When multiple statuses might apply, V0 chooses:

1. `reorged`
2. `unsupported`
3. `unresolved`
4. `invalid`
5. `valid`

Reorged observations should not become `valid`. Unsupported pulse types should not be marked unresolved merely because their URI has no fixture artifact.

## Compatibility With Earlier Planning Terms

Issue #14 originally used a broader vocabulary:

- `observed`
- `verified`
- `unresolved`
- `unsupported`
- `failed`
- `reorged`
- `stale`
- `disputed`
- `superseded`

For the runnable V0 report schema:

- `verified` maps to `valid`.
- `failed` maps to `invalid`.
- `observed` is an indexer/display state, not a verifier result claim.
- `stale`, `disputed`, and `superseded` are future report lifecycle overlays, not V0 terminal report statuses.

The broader terms can return later as dashboard or attestation lifecycle fields without changing the V0 report result enum.

## Report Digest Rule

The `reportId` is:

```text
keccak256(canonical_json(reportCore))
```

`reportCore.status` is included in the digest. Wall-clock timestamps, local paths, signatures, operator notes, and presentation metadata are excluded.

## Non-Goals

- No verifier rewards.
- No slashing.
- No proof network.
- No production API.
- No production database schema.
- No report signing or attestation envelope yet.
