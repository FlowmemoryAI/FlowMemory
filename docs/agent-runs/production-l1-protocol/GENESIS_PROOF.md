# Genesis Proof

## Commands

```powershell
node fixtures/production-l1/production-l1-tools.mjs build-genesis
node fixtures/production-l1/production-l1-tools.mjs validate-genesis
node fixtures/production-l1/production-l1-tools.mjs genesis-hash
npm run validate:production-l1-protocol
npm run validate:production-l1-fixtures
```

## Output Summary

- Genesis profile: `flowchain-base8453-pilot`
- Destination chain ID: `7428453`
- Base source chain ID for bridge evidence: `8453`
- Genesis hash: `0x0826d4c5093c967d57dd5239b8c24e089dc898942291b5f3050a129887041e7f`
- State root: `0x716ccaf7e8946591973d4614d41ba39c047ef7e89bd67d62f1aa6d90b99133ef`
- Public identities: two users, one validator, one bridge relayer, one bridge release authority, one emergency operator
- Secret material: none

## Hash Inputs

Genesis hash input fields are:

`protocolVersion`, `networkProfile`, `chainId`, `genesisTimestamp`, `stateRootSeed`, `initialAccountsRoot`, `initialBalancesRoot`, `validatorSetRoot`, `bridgePilotConfigHash`, and `tokenDexBootstrapConfigHash`.

The builder writes `fixtures/production-l1/genesis.json` from `fixtures/production-l1/genesis.input.json`. The validator recomputes the hash and fails on drift.
