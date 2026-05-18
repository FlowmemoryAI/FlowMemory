# FlowChain Profile Matrix

The canonical profile IDs are the only values accepted in transaction envelopes. Legacy names are aliases for operator language and must not be used as signing domains.

| Profile | Legacy alias | Chain ID | Network name | Genesis hash rule | Bridge source chains | Finality rule | Block time target | Default data directory |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `flowchain-local-private` | `flowchain-local` | `742001` | FlowChain Local Private | Keccak-256 over canonical sorted JSON with domain `flowchain.production_l1.genesis_hash.v0` | `31337` | `single_authority_instant`, quorum `1/1` | 1000 ms | `devnet/local/flowchain-local-private` |
| `flowchain-local-multinode` | `flowchain-private-lan` | `742002` | FlowChain Local Multinode | Same domain and input fields | `31337`, `84532` | `quorum_2f_plus_1_checkpoint`, quorum `2/3` | 2000 ms | `devnet/local/flowchain-local-multinode` |
| `flowchain-base8453-pilot` | none | `7428453` | FlowChain Base 8453 Pilot Destination | Same domain and input fields | `8453` | `source_base_confirmed_destination_local_finalized`, quorum `1/1`, 12 source confirmations | 2000 ms | `devnet/local/flowchain-base8453-pilot` |

`flowchain-base8453-pilot` is local/private on the destination side. Its source evidence is Base chain ID `8453`; this does not make the destination a public network.

## Replay Boundary

The signed envelope binds `chainId`, `networkProfile`, `genesisHash`, `nonceDomain`, signer, payload type, and payload hash. A transaction signed for one profile fails validation on another profile with `FC_PROTO_WRONG_CHAIN_ID`, `FC_PROTO_WRONG_NETWORK_PROFILE`, or `FC_PROTO_WRONG_GENESIS_HASH`.

## Allowed Families

All three profiles expose the same schema catalog so agents can build one parser. Runtime policy may disable families later, but the current private/local fixtures validate one transaction for every family:

`native_transfer`, `faucet_funding`, `bridge_credit`, `token_launch`, `token_mint`, `token_transfer`, `pool_create`, `add_liquidity`, `remove_liquidity`, `swap`, `withdrawal_intent`, `validator_authority_config`, `finality_vote`, `finality_certificate`, and object lifecycle updates for `AgentAccount`, `ModelPassport`, `WorkReceipt`, `ArtifactAvailabilityProof`, `VerifierModule`, `VerifierReport`, `MemoryCell`, `Challenge`, and `FinalityReceipt`.
