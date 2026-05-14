# State Transition Spec

Every payload includes explicit `preconditions`, `stateWrites`, `balanceChanges`, `nonceChange`, emitted event types, and index keys. Runtime agents should replace the fixture strings with typed checks while preserving the same observable contract.

| Family | Preconditions | State writes | Balance changes | Nonce | Index keys | Invalid cases |
| --- | --- | --- | --- | --- | --- | --- |
| Native transfer | signer owns source account; amount positive; sufficient balance | transfer record | debit source, credit recipient | increment signer | payload type, actor | stale nonce, insufficient balance, malformed payload hash |
| Faucet funding | profile allows local funding; recipient exists | faucet record | credit recipient | increment signer | payload type, actor | faucet disabled, duplicate faucet id, malformed payload hash |
| Bridge credit | source chain allowed; source event unique; evidence finalized | bridge credit, duplicate source index | credit recipient | increment relayer | credit id, observation id | invalid source chain, duplicate event, malformed payload hash |
| Token launch/mint/transfer | token policy allows action; token exists when required | token registry or token balance records | supply/balance deltas | increment signer | token id, actor | duplicate token, mint disabled, insufficient token balance |
| Pool/liquidity/swap | pool/assets exist; minimum output constraints pass | pool, LP position, swap/liquidity receipts | reserve and user deltas | increment signer | pool id, actor | bad pool, slippage, insufficient LP/balance |
| Withdrawal intent | destination chain allowed; release policy known | withdrawal record | debit or escrow source | increment signer | withdrawal id, actor | invalid destination, insufficient balance, duplicate intent |
| Validator/finality | signer has validator role; block/state roots known | validator state, vote set, certificate set | none | increment signer | height, block hash | wrong signer role, quorum failure, stale vote |
| Object lifecycle | object type known; parent/source references valid when present | object store row | none | increment signer | object type, object id | unknown type, invalid state transition, malformed object hash |

## State Root Inputs

The state root manifest covers these components:

`accounts`, `balances`, `tokens`, `pools`, `lp_positions`, `bridge_credits`, `withdrawals`, `object_store`, `finality`, and `validator_state`.

Each component root is `keccak256("flowchain.production_l1.state_component_root.v0:" + canonicalJson({ component, entries }))`. The full state root is the Keccak-256 hash of chain ID, profile, genesis hash, and the ordered component root list. The validator recomputes it twice from the same logical state and compares it to `deterministicReplay.sameLogicalStateRoot`.

## Fork Choice and Finality Vocabulary

- `candidate`: block is built but not accepted by local policy.
- `accepted`: block is selected by the profile fork-choice rule.
- `finalized`: block height is covered by an accepted finality receipt.
- `rejected`: block or certificate failed validation.
- `superseded`: a later accepted branch replaced the candidate.
- `downgraded`: finality was reduced because evidence or challenge state changed.

The current fixture uses one accepted local/private block at height `1` and a finality receipt with status `accepted`.
