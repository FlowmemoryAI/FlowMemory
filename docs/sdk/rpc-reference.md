# FlowChain RPC Reference

This file is generated from `rpc_discover` by `node tools/flowchain-rpc-reference.mjs --write`.
Do not edit the method table by hand.

- Service: `flowmemory-control-plane-v0`
- Protocol: `JSON-RPC 2.0`
- RPC path: `/rpc`
- Method count: `79`
- EVM JSON-RPC compatible: `false`
- FlowChain-native JSON-RPC compatible: `true`
- Production ready: `false`

| Method | Category | Mode | Local only | Production ready |
| --- | --- | --- | --- | --- |
| `account_get` | wallet | read | true | false |
| `account_list` | wallet | read | true | false |
| `agent_get` | general | read | true | false |
| `agent_list` | general | read | true | false |
| `artifact_availability_get` | storage | read | true | false |
| `artifact_availability_list` | storage | read | true | false |
| `artifact_get` | storage | read | true | false |
| `balance_get` | wallet | read | true | false |
| `block_get` | ledger | read | true | false |
| `block_list` | ledger | read | true | false |
| `bridge_credit_get` | bridge | read | true | false |
| `bridge_credit_list` | bridge | read | true | false |
| `bridge_credit_status` | bridge | read | true | false |
| `bridge_deposit_get` | bridge | read | true | false |
| `bridge_deposit_list` | bridge | read | true | false |
| `bridge_live_readiness` | bridge | read | true | false |
| `bridge_observation_get` | bridge | read | true | false |
| `bridge_observation_list` | bridge | read | true | false |
| `bridge_observation_submit` | bridge | local-file-intake | true | false |
| `bridge_status` | bridge | read | true | false |
| `chain_status` | node | read | true | false |
| `challenge_get` | verification | read | true | false |
| `challenge_list` | verification | read | true | false |
| `devnet_state` | general | read | true | false |
| `faucet_event_list` | general | read | true | false |
| `finality_get` | verification | read | true | false |
| `finality_list` | verification | read | true | false |
| `health` | general | read | true | false |
| `lp_position_get` | assets-dex | read | true | false |
| `lp_position_list` | assets-dex | read | true | false |
| `memory_cell_get` | flowmemory | read | true | false |
| `memory_cell_list` | flowmemory | read | true | false |
| `mempool_list` | ledger | read | true | false |
| `model_get` | general | read | true | false |
| `model_list` | general | read | true | false |
| `node_status` | node | read | true | false |
| `peer_list` | node | read | true | false |
| `pilot_cap_status` | bridge | read | true | false |
| `pilot_credit_list` | bridge | read | true | false |
| `pilot_deposit_observation_list` | bridge | read | true | false |
| `pilot_emergency_status` | bridge | read | true | false |
| `pilot_lifecycle_record_list` | bridge | read | true | false |
| `pilot_pause_status` | bridge | read | true | false |
| `pilot_release_evidence_list` | bridge | read | true | false |
| `pilot_retry_status` | bridge | read | true | false |
| `pilot_status` | bridge | read | true | false |
| `pilot_withdrawal_intent_list` | bridge | read | true | false |
| `pool_get` | assets-dex | read | true | false |
| `pool_list` | assets-dex | read | true | false |
| `product_flow_status` | general | read | true | false |
| `provenance_get` | general | read | true | false |
| `raw_json_get` | general | read | true | false |
| `receipt_get` | flowmemory | read | true | false |
| `receipt_list` | flowmemory | read | true | false |
| `rootfield_get` | flowmemory | read | true | false |
| `rootfield_list` | flowmemory | read | true | false |
| `rpc_discover` | rpc | read | true | false |
| `rpc_readiness` | rpc | read | true | false |
| `swap_get` | assets-dex | read | true | false |
| `swap_list` | assets-dex | read | true | false |
| `token_balance_get` | assets-dex | read | true | false |
| `token_balance_list` | assets-dex | read | true | false |
| `token_get` | assets-dex | read | true | false |
| `token_list` | assets-dex | read | true | false |
| `transaction_get` | ledger | read | true | false |
| `transaction_list` | ledger | read | true | false |
| `transaction_submit` | ledger | local-file-intake | true | false |
| `verifier_module_get` | verification | read | true | false |
| `verifier_module_list` | verification | read | true | false |
| `verifier_report_get` | verification | read | true | false |
| `verifier_report_list` | verification | read | true | false |
| `wallet_balance_list` | wallet | read | true | false |
| `wallet_metadata_get` | wallet | read | true | false |
| `wallet_metadata_list` | wallet | read | true | false |
| `wallet_transfer_history` | wallet | read | true | false |
| `withdrawal_get` | bridge | read | true | false |
| `withdrawal_list` | bridge | read | true | false |
| `work_receipt_get` | flowmemory | read | true | false |
| `work_receipt_list` | flowmemory | read | true | false |
