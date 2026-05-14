# Dashboard Contract

Dashboard agents should consume stable JSON-RPC fields and should not parse logs or raw files.

## Global Status

Methods: `health`, `node_status`, `sync_status`, `chain_status`, `finality_status`

Fields:

- `schema`
- `status`
- `chainId`
- `networkName`
- `genesisHash`
- `latestHeight`
- `latestBlockHash`
- `finalizedHeight`
- `finalizedHash`
- `stateRoot`
- `runtimeSource`
- `storageSource`
- `responseProvenance`
- `counts`

## Node And Peers

Methods: `node_status`, `peer_list`

Fields:

- `nodeId`
- `startTime`
- `uptimeSeconds`
- `dataDirectory`
- `listeningAddresses`
- `peerCount`
- `syncMode`
- `syncTarget`
- `catchUpState`
- `lastError`
- `peers[].peerId`
- `peers[].address`
- `peers[].status`

## Blocks, Transactions, Receipts, Events

Methods: `block_list`, `block_get`, `transaction_list`, `transaction_get`, `receipt_get`, `event_list`, `event_get`, `mempool_list`

Fields:

- `blocks[].blockNumber`
- `blocks[].blockHash`
- `blocks[].parentHash`
- `blocks[].txIds`
- `blocks[].eventCount`
- `blocks[].receiptCount`
- `blocks[].stateRoot`
- `transactions[].txId`
- `transactions[].status`
- `transactions[].signer`
- `transactions[].nonce`
- `transactions[].payloadSummary`
- `transactions[].receiptRef`
- `receipt.txId`
- `receipt.status`
- `receipt.reason`
- `events[].eventId`
- `events[].eventType`
- `events[].txId`
- `events[].blockNumber`
- `events[].accountId`

## Accounts And Balances

Methods: `account_list`, `account_get`, `balance_get`, `wallet_metadata_list`, `wallet_metadata_get`

Fields:

- `accounts[].accountId`
- `accounts[].accountType`
- `accounts[].controller`
- `accounts[].rootfieldId`
- `accounts[].walletPublicMetadata`
- `balance.accountId`
- `balance.tokenId`
- `balance.amount`
- `balance.baseAmount`
- `balance.pendingAcceptedDelta`
- `wallets[].walletId`
- `wallets[].publicOnly`

## Tokens And DEX

Methods: `token_list`, `token_get`, `token_balance_list`, `token_balance_get`, `pool_list`, `pool_get`, `lp_position_list`, `lp_position_get`, `swap_list`, `swap_get`, `product_flow_status`

Fields:

- `tokens[].tokenId`
- `tokens[].symbol`
- `tokens[].name`
- `tokens[].totalSupply`
- `token.holderCount`
- `token.transferHistory`
- `token.launchTransaction`
- `balances[].balanceId`
- `balances[].accountId`
- `balances[].tokenId`
- `balances[].amount`
- `pools[].poolId`
- `pools[].token0`
- `pools[].token1`
- `pools[].reserve0`
- `pools[].reserve1`
- `pools[].lpSupply`
- `positions[].positionId`
- `positions[].poolId`
- `positions[].accountId`
- `positions[].liquidity`
- `swaps[].swapId`
- `swaps[].poolId`
- `swaps[].tokenIn`
- `swaps[].tokenOut`
- `swaps[].amountIn`
- `swaps[].amountOut`
- `stages[].stage`
- `stages[].status`

## Flow Memory

Methods: `rootfield_list`, `rootfield_get`, `agent_list`, `agent_get`, `model_list`, `model_get`, `work_receipt_list`, `work_receipt_get`, `artifact_get`, `artifact_availability_list`, `artifact_availability_get`, `verifier_module_list`, `verifier_module_get`, `verifier_report_list`, `verifier_report_get`, `memory_cell_list`, `memory_cell_get`, `challenge_list`, `challenge_get`, `finality_list`, `finality_get`, `provenance_get`

Fields:

- `rootfields[].rootfieldId`
- `rootfields[].status`
- `bundle.latestRoot`
- `agents[].agentId`
- `models[].modelId`
- `workReceipts[].receiptId`
- `artifactAvailability[].availabilityId`
- `verifierModules[].moduleId`
- `reports[].reportId`
- `memoryCells[].memoryCellId`
- `challenges[].challengeId`
- `finality[].objectId`
- `finality[].status`
- `provenance.sources[]`
- `provenance.links`

## Bridge

Methods: `bridge_config_get`, `bridge_status`, `bridge_observation_list`, `bridge_observation_get`, `bridge_deposit_list`, `bridge_deposit_get`, `bridge_credit_list`, `bridge_credit_get`, `withdrawal_intent_list`, `withdrawal_intent_get`, `release_evidence_list`, `release_evidence_get`, `replay_rejection_list`, `replay_rejection_get`, `pilot_status`

Fields:

- `readiness`
- `bridgeSource`
- `envValuesExposed`
- `pilotCaps`
- `replayProtection`
- `runtimeIntake`
- `observations[].observationId`
- `observations[].replayKey`
- `deposits[].depositId`
- `deposits[].sourceChainId`
- `deposits[].txHash`
- `credits[].creditId`
- `credits[].status`
- `withdrawalIntents[].withdrawalIntentId`
- `withdrawalIntents[].status`
- `releaseEvidence[].releaseEvidenceId`
- `releaseEvidence[].status`
- `replayRejections[].replayRejectionId`
- `replayRejections[].status`
- `pilot_status.lifecycle[]`

## Diagnostics

Methods: `raw_json_get`, `devnet_state`, `provenance_get`

Fields:

- `source`
- `dataSource`
- `raw`
- `responseProvenance`

Raw JSON is only available through allowlisted local diagnostic sources.
