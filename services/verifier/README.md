# FlowMemory Verifier V0

This package is a local, fixture-first verifier. It consumes indexed FlowPulse observations, resolves only local fixture artifacts, applies deterministic commitment checks, and writes canonical verification reports.

It is not a verifier network, production proof service, token system, staking system, or full trustless verifier layer.

## Commands

From the repository root:

```powershell
npm run verify:fixtures
npm run demo:verifier
npm test --prefix services/verifier
```

`npm run verify:fixtures` reads `services/indexer/out/indexer-state.json` when present. If the indexer output is missing, it builds indexer state from fixtures. It writes:

```text
services/verifier/out/reports.json
```

Use custom paths:

```powershell
npm run verify:fixtures -- --input ../indexer/out/indexer-state.json --out out/custom-reports.json
```

## Resolver Policy

V0 uses local fixture resolver policy:

```text
flowmemory.resolver.policy.v0.fixture
```

Artifact fixtures live at:

```text
services/verifier/fixtures/artifacts.json
```

The verifier does not fetch arbitrary HTTP or IPFS content. `uri` is advisory and only acts as a lookup key inside the local fixture resolver. The resolver supports an optional maximum artifact byte size and returns `unresolved` when evidence is missing or policy-rejected.

## Report Statuses

The verifier report package uses these deterministic report statuses:

- `valid`: supported checks passed.
- `invalid`: supported checks ran and at least one required check failed.
- `unresolved`: required fixture evidence is missing or policy-rejected.
- `unsupported`: pulse type or artifact semantics are outside V0 rules.
- `reorged`: observation is removed or reorged.

The status vocabulary is documented in [VERIFIER_STATUS_VOCABULARY.md](./VERIFIER_STATUS_VOCABULARY.md).

## Flow Memory Status Mapping

Flow Memory and dashboard surfaces may use the launch vocabulary:

- `verified`
- `unresolved`
- `unsupported`
- `failed`
- `reorged`

The V0 adapter rule is:

- verifier `valid` maps to Flow Memory `verified`.
- verifier `invalid` maps to Flow Memory `failed`.
- verifier `unresolved`, `unsupported`, and `reorged` keep the same meaning.

Do not silently collapse `unresolved` into `failed`; missing evidence and failed evidence are different states.

## Commitment Checks

For `ROOTFIELD_REGISTERED` (`pulseType = 1`):

```text
subject == rootfieldId
commitment == keccak256(abi.encode(schemaHash, metadataHash))
```

For `ROOT_COMMITTED` (`pulseType = 2`):

```text
subject == root
commitment == keccak256(abi.encode(root, artifactCommitment))
```

Unsupported pulse types return `unsupported`. Missing artifacts return `unresolved`. Subject or commitment mismatches return `invalid`.

## Reports

Each report has:

- `reportId`
- `reportDigest`
- `reportCore`

`reportId` and `reportDigest` are the same V0 digest:

```text
keccak256(canonical_json(reportCore))
```

The digest excludes wall-clock timestamps, local file paths, signatures, operator notes, and other mutable presentation data.

The JSON schema fixture lives at:

```text
services/verifier/fixtures/verification-report.schema.json
```

## Persistence

The persisted report file declares:

```text
flowmemory.verifier.persistence.v0
```

Each report core declares:

```text
flowmemory.verifier.report.v0
```

JSON output is deterministic across repeated runs with the same fixtures.

## Non-Goals

- No verifier economics.
- No staking, rewards, or slashing.
- No production verifier network.
- No live artifact fetching.
- No production database.
- No report signing or attestations yet.
- No zk proof implementation.
- No API server.

See [docs/INDEXER_VERIFIER_MVP.md](../../docs/INDEXER_VERIFIER_MVP.md) for the full local pipeline.
