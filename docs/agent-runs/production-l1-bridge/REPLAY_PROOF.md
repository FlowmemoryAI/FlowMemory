# Replay Proof

Status: implemented and tested.

Deposit replay protection:

- Contract deposit nonces are included in `depositId`.
- Relayer replay keys include source chain, lockbox, tx hash, log index, and deposit ID.
- Local runtime application state stores applied replay keys.
- Same-event replay returns `idempotent_replay`.
- Duplicate fixture replay rejects the second credit with `duplicate_replay_key`.

Release replay protection:

- Contract release calls derive a release ID.
- `releaseId` is marked used before value leaves the lockbox.
- Duplicate releases are rejected.
- Wrong release authority is rejected.
- Emergency stop blocks release.

Proof commands:

```powershell
forge test --match-path tests/bridge/BaseBridgeLockbox.t.sol
npm test --prefix services/bridge-relayer
npm run flowchain:real-value-pilot:bridge
```

Fixture replay evidence:

- replay key: `0xea93b7d168d2f1f6c4be4f95ba4d85aa2d07fc4298a720d180000a19d98481f0`
- first application status: `applied`
- same-event replay status: `idempotent_replay`
- replay credit status: `rejected`
- duplicate decision: `duplicate_replay_key_rejected`
