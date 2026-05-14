# Evidence-Safe Export Proof

## Export Contents

The durable export includes:

- Storage schema/version.
- Chain id and genesis hash.
- Latest height/hash.
- Finalized height/hash.
- State root and map roots.
- Manifest.
- Included-files manifest.
- Evidence-safety metadata.
- Full public local devnet state.
- Storage indexes.

Included file patterns are deterministic and sorted. For the storage E2E export:

- `blocks/00000000000000000001.json`
- `blocks/00000000000000000002.json`
- `blocks/00000000000000000003.json`
- `headers/00000000000000000001.json`
- `headers/00000000000000000002.json`
- `headers/00000000000000000003.json`
- `indexes/storage-indexes.json`
- `manifest.json`
- `objects/*.json`
- `snapshots/00000000000000000003.json`

## Exclusions

The export marks these as excluded:

- Local wallet vaults.
- Env files.
- Network endpoints.
- Signing secrets.
- Recovery phrases.
- API credential/callback material.

The export path and the storage E2E output were scanned by the wrapper scripts. Early safety metadata used secret-shaped field names and was rejected by the scanner; those fields were renamed and the final `npm run flowchain:storage:e2e`, `npm run flowchain:export`, and `npm run flowchain:import` commands passed.
