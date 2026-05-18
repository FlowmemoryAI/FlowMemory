# Transaction Catalog

All payloads validate through `schemas/flowmemory/production-transaction-payload.schema.json` and are wrapped by `schemas/flowmemory/production-transaction-envelope.schema.json`.

| Payload type | Required details | Primary producer | Runtime writes |
| --- | --- | --- | --- |
| `native_transfer` | from account, to account, asset, amount, memo hash | wallet | balances, sender nonce |
| `faucet_funding` | faucet id, recipient, asset, amount, reason hash, `localOnly` | runtime/operator | balances, faucet record, nonce |
| `bridge_credit` | evidence id, observation id, credit id, source chain, asset, amount, recipient | bridge relayer | bridge credits, balances, duplicate source event index, nonce |
| `token_launch` | launch id, issuer, token id, symbol, name, decimals, metadata hash, initial supply, recipient | wallet/deployer | token registry, token balance, nonce |
| `token_mint` | mint id, token id, recipient, amount, reason hash, `localOrTestMode` | wallet/deployer | token supply, token balance, nonce |
| `token_transfer` | transfer id, token id, from account, to account, amount, memo hash | wallet | token balances, nonce |
| `pool_create` | pool id, base asset, quote asset, fee bps, tick spacing, metadata hash | wallet/deployer | pool registry, nonce |
| `add_liquidity` | liquidity id, pool id, provider, base amount, quote amount, minimum LP units | wallet | pool reserves, LP position, balances, nonce |
| `remove_liquidity` | liquidity id, pool id, provider, LP units, minimum returned amounts | wallet | pool reserves, LP position, balances, nonce |
| `swap` | swap id, pool id, trader, asset in/out, input amount, minimum output, route hash | wallet | pool reserves, balances, swap receipt, nonce |
| `withdrawal_intent` | intent id, source account, destination chain/address, asset, amount, release policy hash | wallet/bridge | withdrawal queue, balances, nonce |
| `validator_authority_config` | config id, authority id, validator account, action, type, voting power, metadata hash | consensus operator | validator state, nonce |
| `finality_vote` | vote id, validator account, height, block hash, state root, round | consensus | finality vote set, nonce |
| `finality_certificate` | certificate id, height, block hash, state root, signer-set root, votes, quorum | consensus | finality certificate set, nonce |
| `*_update` object lifecycle payloads | lifecycle id, object type, operation, object id/hash, status, rootfield id, optional source/parent | runtime/indexer | object store, index keys, nonce |

## Valid and Invalid Coverage

- Valid fixture set: `fixtures/production-l1/transactions.valid.json`
- Invalid fixture set: `fixtures/production-l1/negative-fixtures.json`

There is one valid transaction for every payload type and one invalid malformed-payload-hash case for every payload type. Additional negative cases cover wrong chain ID, wrong genesis hash, stale nonce, duplicate transaction, malformed state root, invalid bridge source chain, and duplicate bridge event.
