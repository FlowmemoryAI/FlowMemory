# Bridge Protocol Spec

This is a local/private bridge accounting contract for agents. It is not a value-bearing bridge readiness claim.

## Base 8453 Pilot

`flowchain-base8453-pilot` has destination chain ID `7428453` and source chain ID `8453`. Source evidence uses Base transaction/log coordinates, while destination execution remains local/private.

## Evidence Fields

`production-bridge-evidence.schema.json` requires:

- `sourceChainId`
- `sourceNetwork`
- `lockboxAddress`
- `sourceTxHash`
- `sourceBlockNumber`
- `sourceLogIndex`
- `tokenAddress`
- `assetId`
- `depositorAddress`
- `localRecipientAccountId`
- `amount`
- `observationId`
- `creditId`
- `duplicateKey`
- `evidenceHash`
- `observedByRelayerAccountId`
- `finalityStatus`

Withdrawal release evidence additionally requires `withdrawalIntentId`, `releaseTxHash`, `releaseBlockNumber`, `releaseLogIndex`, `releasedToAddress`, and `releaseAuthorityAccountId`.

## ID Derivation

- Observation ID input: source chain ID, lockbox address, source transaction hash, and source log index.
- Credit ID input: observation ID, local recipient, asset, and amount.
- Duplicate key input: source chain ID, lockbox address, source transaction hash, and source log index.

The runtime must reject a second evidence object with the same duplicate key with `FC_PROTO_DUPLICATE_BRIDGE_EVENT`.

## Fixtures

- Deposit observation and local credit evidence: `fixtures/production-l1/bridge-evidence.valid.json`
- Bridge credit transaction: `fixtures/production-l1/transactions.valid.json`
- Withdrawal intent transaction and release evidence: `fixtures/production-l1/transactions.valid.json` and `fixtures/production-l1/bridge-evidence.valid.json`
- Invalid source chain and duplicate source event cases: `fixtures/production-l1/negative-fixtures.json`
