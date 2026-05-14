# Validator Set

## Implemented Shape

- Authority-set schema: `flowmemory.local_devnet.authority_set.v0`
- Validator schema: `flowmemory.local_devnet.validator_identity.v0`
- Authority set id: `authority-set:flowmemory-local-private-v0`
- Validator id: `validator:local-private:alpha`
- Roles: `validator`, `sequencer`, `proposer`, `finality-signer`
- Profile: private/local authority set

The validator identity stores only dashboard-safe metadata, a consensus public
key reference, role metadata, and key-separation notes. It does not store
signing secrets, user wallet keys, or bridge release keys.

## Runtime Fields

The devnet state and handoff output expose:

- `validatorSet`
- `authoritySet`
- `consensusState`
- `chainFinalityReceipts`
- `consensusStateRoot`

Public metadata is written by:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- validator-set
```

