# FlowChain Private/Local Protocol Experiments

This file records validation commands and command-output summaries for the private/local protocol contract.

## Planned Commands

```powershell
npm run validate:production-l1-protocol
npm run validate:production-l1-fixtures
node fixtures/production-l1/production-l1-tools.mjs build-genesis
node fixtures/production-l1/production-l1-tools.mjs validate-genesis
node fixtures/production-l1/production-l1-tools.mjs genesis-hash
git diff --check
```

## Results

- `node fixtures/production-l1/production-l1-tools.mjs validate-protocol`
  - `FLOWCHAIN_PRODUCTION_L1_PROTOCOL_OK schemas=14 profiles=3 payloadTypes=23`
- `node fixtures/production-l1/production-l1-tools.mjs validate-fixtures`
  - `FLOWCHAIN_PRODUCTION_L1_FIXTURES_OK transactions=23 receipts=23 events=23 bridgeEvidence=2 negativeCases=31 genesisHash=0x0826d4c5093c967d57dd5239b8c24e089dc898942291b5f3050a129887041e7f stateRoot=0x716ccaf7e8946591973d4614d41ba39c047ef7e89bd67d62f1aa6d90b99133ef`
- `node fixtures/production-l1/production-l1-tools.mjs build-genesis`
  - `FLOWCHAIN_PRODUCTION_L1_GENESIS_BUILD_OK genesisHash=0x0826d4c5093c967d57dd5239b8c24e089dc898942291b5f3050a129887041e7f`
- `node fixtures/production-l1/production-l1-tools.mjs validate-genesis`
  - `FLOWCHAIN_PRODUCTION_L1_GENESIS_OK genesisHash=0x0826d4c5093c967d57dd5239b8c24e089dc898942291b5f3050a129887041e7f`
- `node fixtures/production-l1/production-l1-tools.mjs genesis-hash`
  - `0x0826d4c5093c967d57dd5239b8c24e089dc898942291b5f3050a129887041e7f`
- `node infra/scripts/check-unsafe-claims.mjs`
  - `Checked launch claims in README.md, docs, contracts.`
- `git diff --check`
  - Passed with line-ending warnings for `package.json` and `schemas/flowmemory/README.md`; no whitespace errors.
