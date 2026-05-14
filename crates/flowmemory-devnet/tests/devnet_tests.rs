use flowmemory_devnet::model::{
    DevnetError, EXECUTION_COST_CHARGE_NATIVE, FLOWPULSE_TOPIC0, LOCAL_TEST_UNIT_ASSET_ID,
    Transaction, ZERO_HASH, apply_transaction, build_block, demo_transactions,
    deterministic_bridge_credit_id, deterministic_liquidity_id, deterministic_lp_position_id,
    deterministic_pool_id, deterministic_swap_id, deterministic_token_balance_id,
    deterministic_token_id, deterministic_token_transfer_id, genesis_state,
    product_demo_transactions, queue_transaction, state_map_roots, state_root,
};
use flowmemory_devnet::{canonical_json, keccak_hex};
use std::process::Command;

#[test]
fn state_root_is_deterministic_for_same_inputs() {
    let mut first = genesis_state();
    let mut second = genesis_state();

    for tx in demo_transactions() {
        queue_transaction(&mut first, tx.clone());
        queue_transaction(&mut second, tx);
    }

    let first_block = build_block(&mut first);
    let second_block = build_block(&mut second);

    assert_eq!(state_root(&first), state_root(&second));
    assert_eq!(first_block.block_hash, second_block.block_hash);
}

#[test]
fn deterministic_replay_covers_new_maps_and_anchor() {
    let first = run_demo_chain();
    let second = run_demo_chain();

    assert_eq!(first, second);
}

#[test]
fn block_hash_changes_when_transactions_change() {
    let mut first = genesis_state();
    let mut second = genesis_state();

    queue_transaction(
        &mut first,
        Transaction::RegisterRootfield {
            rootfield_id: "rootfield:a".to_string(),
            owner: "operator:a".to_string(),
            schema_hash: keccak_hex(b"schema"),
            metadata_hash: keccak_hex(b"metadata"),
        },
    );
    queue_transaction(
        &mut second,
        Transaction::RegisterRootfield {
            rootfield_id: "rootfield:b".to_string(),
            owner: "operator:a".to_string(),
            schema_hash: keccak_hex(b"schema"),
            metadata_hash: keccak_hex(b"metadata"),
        },
    );

    let first_block = build_block(&mut first);
    let second_block = build_block(&mut second);

    assert_ne!(state_root(&first), state_root(&second));
    assert_ne!(first_block.block_hash, second_block.block_hash);
}

#[test]
fn invalid_tx_is_rejected_without_state_mutation() {
    let mut state = genesis_state();
    let before = state_root(&state);

    queue_transaction(
        &mut state,
        Transaction::CommitRoot {
            rootfield_id: "missing-rootfield".to_string(),
            actor: "operator:a".to_string(),
            root: keccak_hex(b"root"),
            artifact_commitment: keccak_hex(b"artifact"),
        },
    );

    let block = build_block(&mut state);

    assert_eq!(block.receipts.len(), 1);
    assert_eq!(block.receipts[0].status, "rejected");
    assert!(
        block.receipts[0]
            .error
            .as_ref()
            .expect("error")
            .contains("rootfield does not exist")
    );
    assert_ne!(before, state_root(&state));
    assert!(state.rootfields.is_empty());
    assert_eq!(state.execution_receipts.len(), 1);
    let execution_receipt = state
        .execution_receipts
        .values()
        .next()
        .expect("failed execution receipt");
    assert!(!execution_receipt.success);
    assert_eq!(
        execution_receipt.error_code.as_deref(),
        Some("execution-error")
    );
}

#[test]
fn invalid_dependencies_are_rejected() {
    let mut state = genesis_state();
    assert_eq!(
        apply_transaction(
            &mut state,
            &register_agent_tx("agent:missing-model", Some("model:missing")),
        ),
        Err(DevnetError::ModelPassportMissing(
            "model:missing".to_string()
        ))
    );

    apply_transaction(&mut state, &register_rootfield_tx("rootfield:deps")).unwrap();
    let missing_artifact_receipt = work_receipt_tx(
        "receipt:missing-artifact",
        "rootfield:deps",
        "artifact:missing",
    );
    let Transaction::SubmitWorkReceipt {
        artifact_commitment: missing_artifact_commitment,
        ..
    } = &missing_artifact_receipt
    else {
        unreachable!("helper must build a work receipt")
    };
    assert_eq!(
        apply_transaction(&mut state, &missing_artifact_receipt),
        Err(DevnetError::ArtifactMissing(
            missing_artifact_commitment.clone()
        ))
    );

    assert_eq!(
        apply_transaction(
            &mut state,
            &availability_tx(
                "availability:missing-artifact",
                "artifact:missing",
                "rootfield:deps",
                "available",
            ),
        ),
        Err(DevnetError::ArtifactMissing("artifact:missing".to_string()))
    );

    let mut missing_verifier = genesis_state();
    apply_transaction(
        &mut missing_verifier,
        &register_rootfield_tx("rootfield:missing-verifier"),
    )
    .unwrap();
    apply_transaction(
        &mut missing_verifier,
        &artifact_tx("artifact:missing-verifier", "rootfield:missing-verifier"),
    )
    .unwrap();
    apply_transaction(
        &mut missing_verifier,
        &work_receipt_tx(
            "receipt:missing-verifier",
            "rootfield:missing-verifier",
            "artifact:missing-verifier",
        ),
    )
    .unwrap();
    assert_eq!(
        apply_transaction(
            &mut missing_verifier,
            &verifier_report_tx(
                "report:missing-verifier",
                "receipt:missing-verifier",
                "rootfield:missing-verifier",
                "verified",
            ),
        ),
        Err(DevnetError::VerifierModuleMissing(
            "verifier:test".to_string()
        ))
    );

    apply_transaction(&mut state, &register_verifier_module_tx("verifier:test")).unwrap();
    assert_eq!(
        apply_transaction(
            &mut state,
            &verifier_report_tx(
                "report:missing-receipt",
                "receipt:missing",
                "rootfield:deps",
                "verified",
            ),
        ),
        Err(DevnetError::WorkReceiptMissing(
            "receipt:missing".to_string()
        ))
    );
}

#[test]
fn every_core_transaction_type_can_be_applied() {
    let mut state = genesis_state();
    for tx in demo_transactions() {
        queue_transaction(&mut state, tx);
    }
    queue_transaction(
        &mut state,
        Transaction::ImportFlowPulseObservation(
            flowmemory_devnet::model::ImportedFlowPulseObservation {
                observation_id: "observation:local:001".to_string(),
                chain_id: "8453".to_string(),
                emitting_contract: "0x1111111111111111111111111111111111111111".to_string(),
                block_number: "1".to_string(),
                block_hash: keccak_hex(b"block"),
                tx_hash: keccak_hex(b"tx"),
                transaction_index: "0".to_string(),
                log_index: "0".to_string(),
                event_signature: FLOWPULSE_TOPIC0.to_string(),
                pulse_id: keccak_hex(b"pulse"),
                rootfield_id: "rootfield:demo:alpha".to_string(),
            },
        ),
    );
    queue_transaction(
        &mut state,
        Transaction::ImportVerifierReport(flowmemory_devnet::model::ImportedVerifierReport {
            report_id: "imported-report:001".to_string(),
            rootfield_id: Some("rootfield:demo:alpha".to_string()),
            receipt_id: Some("receipt:demo:001".to_string()),
            report_digest: keccak_hex(b"imported-report"),
            status: "observed".to_string(),
            source: "unit-test".to_string(),
        }),
    );
    let first = build_block(&mut state);
    assert!(
        first
            .receipts
            .iter()
            .all(|receipt| receipt.status == "applied")
    );

    let appchain_chain_id = state.chain_id.clone();
    queue_transaction(
        &mut state,
        Transaction::AnchorBatchToBasePlaceholder {
            appchain_chain_id,
            finality_status: "local-placeholder".to_string(),
        },
    );
    let second = build_block(&mut state);
    assert!(
        second
            .receipts
            .iter()
            .all(|receipt| receipt.status == "applied")
    );
    assert_eq!(state.rootfields.len(), 1);
    assert_eq!(state.agent_accounts.len(), 1);
    assert_eq!(state.local_test_unit_balances.len(), 1);
    assert_eq!(state.faucet_records.len(), 1);
    assert_eq!(state.model_passports.len(), 1);
    assert_eq!(state.memory_cells.len(), 1);
    assert_eq!(state.challenges.len(), 1);
    assert_eq!(state.finality_receipts.len(), 1);
    assert_eq!(state.artifact_commitments.len(), 1);
    assert_eq!(state.artifact_availability_proofs.len(), 1);
    assert_eq!(state.verifier_modules.len(), 1);
    assert_eq!(state.work_receipts.len(), 1);
    assert_eq!(state.verifier_reports.len(), 1);
    assert_eq!(state.imported_observations.len(), 1);
    assert_eq!(state.imported_verifier_reports.len(), 1);
    assert_eq!(state.base_anchors.len(), 1);
}

#[test]
fn local_faucet_and_transfer_update_test_unit_ledger() {
    let mut state = genesis_state();
    apply_transaction(
        &mut state,
        &Transaction::CreateLocalTestUnitBalance {
            account_id: "local-account:alice".to_string(),
            owner: "operator:alice".to_string(),
        },
    )
    .unwrap();
    apply_transaction(
        &mut state,
        &Transaction::CreateLocalTestUnitBalance {
            account_id: "local-account:bob".to_string(),
            owner: "operator:bob".to_string(),
        },
    )
    .unwrap();
    apply_transaction(
        &mut state,
        &Transaction::FaucetLocalTestUnits {
            faucet_record_id: "faucet:unit:001".to_string(),
            account_id: "local-account:alice".to_string(),
            recipient: "operator:alice".to_string(),
            amount_units: 50,
            reason: "unit-test".to_string(),
        },
    )
    .unwrap();
    apply_transaction(
        &mut state,
        &Transaction::TransferLocalTestUnits {
            transfer_id: "transfer:unit:001".to_string(),
            from_account_id: "local-account:alice".to_string(),
            to_account_id: "local-account:bob".to_string(),
            amount_units: 20,
            account_nonce: 1,
            memo: "unit-test-transfer".to_string(),
        },
    )
    .unwrap();

    assert_eq!(
        state.local_test_unit_balances["local-account:alice"].units,
        30
    );
    assert_eq!(
        state.local_test_unit_balances["local-account:bob"].units,
        20
    );
    assert_eq!(state.faucet_records.len(), 1);
    assert_eq!(state.balance_transfers.len(), 1);

    assert_eq!(
        apply_transaction(
            &mut state,
            &Transaction::TransferLocalTestUnits {
                transfer_id: "transfer:unit:002".to_string(),
                from_account_id: "local-account:bob".to_string(),
                to_account_id: "local-account:alice".to_string(),
                amount_units: 30,
                account_nonce: 1,
                memo: "too-much".to_string(),
            },
        ),
        Err(DevnetError::LocalTestUnitBalanceInsufficient(
            "local-account:bob".to_string()
        ))
    );
}

#[test]
fn token_launch_pool_liquidity_swap_and_remove_update_product_state() {
    let mut state = genesis_state();
    setup_product_test_accounts(&mut state);

    let token_id = deterministic_token_id("FLOWT");
    let pool_id = deterministic_pool_id(LOCAL_TEST_UNIT_ASSET_ID, &token_id);
    let alice = "local-account:product:alice";
    let bob = "local-account:product:bob";
    let add_liquidity_id = deterministic_liquidity_id(
        &pool_id,
        alice,
        "add",
        &format!("{}:{}:{}", 5_000, 500_000, 1),
    );
    let swap_id = deterministic_swap_id(
        &pool_id,
        bob,
        LOCAL_TEST_UNIT_ASSET_ID,
        100,
        &9_000_u64.to_string(),
    );
    let remove_liquidity_id =
        deterministic_liquidity_id(&pool_id, alice, "remove", &format!("{}:{}:{}", 100, 1, 1));

    apply_transaction(
        &mut state,
        &Transaction::LaunchToken {
            token_id: token_id.clone(),
            symbol: "flowt".to_string(),
            name: "FlowChain Product Test Token".to_string(),
            decimals: 6,
            initial_owner_account_id: alice.to_string(),
            initial_supply_units: 1_000_000,
            account_nonce: 1,
        },
    )
    .unwrap();
    apply_transaction(
        &mut state,
        &Transaction::CreatePool {
            pool_id: pool_id.clone(),
            base_asset_id: LOCAL_TEST_UNIT_ASSET_ID.to_string(),
            quote_asset_id: token_id.clone(),
            created_by_account_id: alice.to_string(),
            account_nonce: 2,
        },
    )
    .unwrap();
    apply_transaction(
        &mut state,
        &Transaction::AddLiquidity {
            liquidity_id: add_liquidity_id.clone(),
            pool_id: pool_id.clone(),
            provider_account_id: alice.to_string(),
            base_amount_units: 5_000,
            quote_amount_units: 500_000,
            min_lp_units: 1,
            account_nonce: 3,
        },
    )
    .unwrap();
    apply_transaction(
        &mut state,
        &Transaction::SwapExactIn {
            swap_id: swap_id.clone(),
            pool_id: pool_id.clone(),
            trader_account_id: bob.to_string(),
            asset_in_id: LOCAL_TEST_UNIT_ASSET_ID.to_string(),
            amount_in_units: 100,
            min_amount_out_units: 9_000,
            account_nonce: 1,
        },
    )
    .unwrap();
    apply_transaction(
        &mut state,
        &Transaction::RemoveLiquidity {
            liquidity_id: remove_liquidity_id.clone(),
            pool_id: pool_id.clone(),
            provider_account_id: alice.to_string(),
            lp_units: 100,
            min_base_amount_units: 1,
            min_quote_amount_units: 1,
            account_nonce: 4,
        },
    )
    .unwrap();

    let pool = state.dex_pools.get(&pool_id).expect("pool");
    assert_eq!(pool.reserve_base_units, 4_998);
    assert_eq!(pool.reserve_quote_units, 480_394);
    assert_eq!(pool.total_lp_units, 4_900);
    assert_eq!(
        pool.last_liquidity_receipt_id.as_deref(),
        Some(remove_liquidity_id.as_str())
    );
    assert_eq!(pool.last_swap_receipt_id.as_deref(), Some(swap_id.as_str()));

    let alice_lp_id = deterministic_lp_position_id(&pool_id, alice);
    let position = state.lp_positions.get(&alice_lp_id).expect("LP position");
    assert_eq!(position.lp_units, 4_900);
    assert_eq!(position.base_units_deposited, 5_000);
    assert_eq!(position.base_units_withdrawn, 102);
    assert_eq!(state.liquidity_receipts.len(), 2);

    let bob_token_balance_id = deterministic_token_balance_id(&token_id, bob);
    assert_eq!(state.token_balances[&bob_token_balance_id].units, 9_803);
    assert_eq!(state.swap_receipts[&swap_id].amount_out_units, 9_803);

    let roots = state_map_roots(&state);
    assert!(roots.token_definition_root.starts_with("0x"));
    assert!(roots.dex_pool_root.starts_with("0x"));
    assert!(roots.swap_receipt_root.starts_with("0x"));
}

#[test]
fn token_and_dex_reject_duplicate_zero_insufficient_and_slippage_failures() {
    let mut state = genesis_state();
    setup_product_test_accounts(&mut state);

    let token_id = deterministic_token_id("FLOWT");
    let bad_token_id = deterministic_token_id("WRONG");
    assert_eq!(
        apply_transaction(
            &mut state,
            &Transaction::LaunchToken {
                token_id: bad_token_id,
                symbol: "FLOWT".to_string(),
                name: "Wrong ID".to_string(),
                decimals: 6,
                initial_owner_account_id: "local-account:product:alice".to_string(),
                initial_supply_units: 1_000,
                account_nonce: 1,
            },
        ),
        Err(DevnetError::DeterministicIdMismatch {
            kind: "token".to_string(),
            expected: token_id.clone(),
            actual: deterministic_token_id("WRONG"),
        })
    );

    apply_transaction(
        &mut state,
        &Transaction::LaunchToken {
            token_id: token_id.clone(),
            symbol: "FLOWT".to_string(),
            name: "FlowChain Product Test Token".to_string(),
            decimals: 6,
            initial_owner_account_id: "local-account:product:alice".to_string(),
            initial_supply_units: 1_000_000,
            account_nonce: 1,
        },
    )
    .unwrap();
    assert_eq!(
        apply_transaction(
            &mut state,
            &Transaction::LaunchToken {
                token_id: token_id.clone(),
                symbol: "FLOWT".to_string(),
                name: "Duplicate".to_string(),
                decimals: 6,
                initial_owner_account_id: "local-account:product:alice".to_string(),
                initial_supply_units: 1,
                account_nonce: 2,
            },
        ),
        Err(DevnetError::TokenAlreadyExists(token_id.clone()))
    );

    let pool_id = deterministic_pool_id(LOCAL_TEST_UNIT_ASSET_ID, &token_id);
    apply_transaction(
        &mut state,
        &Transaction::CreatePool {
            pool_id: pool_id.clone(),
            base_asset_id: LOCAL_TEST_UNIT_ASSET_ID.to_string(),
            quote_asset_id: token_id.clone(),
            created_by_account_id: "local-account:product:alice".to_string(),
            account_nonce: 2,
        },
    )
    .unwrap();
    assert_eq!(
        apply_transaction(
            &mut state,
            &Transaction::CreatePool {
                pool_id: pool_id.clone(),
                base_asset_id: LOCAL_TEST_UNIT_ASSET_ID.to_string(),
                quote_asset_id: token_id.clone(),
                created_by_account_id: "local-account:product:alice".to_string(),
                account_nonce: 3,
            },
        ),
        Err(DevnetError::PoolAlreadyExists(pool_id.clone()))
    );

    let zero_liquidity_id =
        deterministic_liquidity_id(&pool_id, "local-account:product:alice", "add", "0:1:1");
    assert_eq!(
        apply_transaction(
            &mut state,
            &Transaction::AddLiquidity {
                liquidity_id: zero_liquidity_id.clone(),
                pool_id: pool_id.clone(),
                provider_account_id: "local-account:product:alice".to_string(),
                base_amount_units: 0,
                quote_amount_units: 1,
                min_lp_units: 1,
                account_nonce: 3,
            },
        ),
        Err(DevnetError::TokenAmountMustBePositive(zero_liquidity_id))
    );

    let too_much_liquidity_id = deterministic_liquidity_id(
        &pool_id,
        "local-account:product:bob",
        "add",
        &format!("{}:{}:{}", 2_000, 1, 1),
    );
    assert_eq!(
        apply_transaction(
            &mut state,
            &Transaction::AddLiquidity {
                liquidity_id: too_much_liquidity_id,
                pool_id: pool_id.clone(),
                provider_account_id: "local-account:product:bob".to_string(),
                base_amount_units: 2_000,
                quote_amount_units: 1,
                min_lp_units: 1,
                account_nonce: 1,
            },
        ),
        Err(DevnetError::LocalTestUnitBalanceInsufficient(
            "local-account:product:bob".to_string()
        ))
    );

    let add_liquidity_id = deterministic_liquidity_id(
        &pool_id,
        "local-account:product:alice",
        "add",
        &format!("{}:{}:{}", 5_000, 500_000, 1),
    );
    apply_transaction(
        &mut state,
        &Transaction::AddLiquidity {
            liquidity_id: add_liquidity_id,
            pool_id: pool_id.clone(),
            provider_account_id: "local-account:product:alice".to_string(),
            base_amount_units: 5_000,
            quote_amount_units: 500_000,
            min_lp_units: 1,
            account_nonce: 3,
        },
    )
    .unwrap();

    let slippage_swap_id = deterministic_swap_id(
        &pool_id,
        "local-account:product:bob",
        LOCAL_TEST_UNIT_ASSET_ID,
        100,
        &50_000_u64.to_string(),
    );
    assert_eq!(
        apply_transaction(
            &mut state,
            &Transaction::SwapExactIn {
                swap_id: slippage_swap_id.clone(),
                pool_id: pool_id.clone(),
                trader_account_id: "local-account:product:bob".to_string(),
                asset_in_id: LOCAL_TEST_UNIT_ASSET_ID.to_string(),
                amount_in_units: 100,
                min_amount_out_units: 50_000,
                account_nonce: 1,
            },
        ),
        Err(DevnetError::SwapSlippageExceeded(slippage_swap_id))
    );

    let missing_pool_swap_id = deterministic_swap_id(
        "pool:missing",
        "local-account:product:bob",
        LOCAL_TEST_UNIT_ASSET_ID,
        1,
        &1_u64.to_string(),
    );
    assert_eq!(
        apply_transaction(
            &mut state,
            &Transaction::SwapExactIn {
                swap_id: missing_pool_swap_id,
                pool_id: "pool:missing".to_string(),
                trader_account_id: "local-account:product:bob".to_string(),
                asset_in_id: LOCAL_TEST_UNIT_ASSET_ID.to_string(),
                amount_in_units: 1,
                min_amount_out_units: 1,
                account_nonce: 1,
            },
        ),
        Err(DevnetError::PoolMissing("pool:missing".to_string()))
    );
}

#[test]
fn product_demo_transactions_apply_in_one_block_with_receipts() {
    let mut state = genesis_state();
    for tx in product_demo_transactions() {
        queue_transaction(&mut state, tx);
    }

    let block = build_block(&mut state);
    assert_eq!(block.receipts.len(), 10);
    assert!(
        block
            .receipts
            .iter()
            .all(|receipt| receipt.status == "applied")
    );
    assert_eq!(state.token_definitions.len(), 1);
    assert_eq!(state.bridge_credit_receipts.len(), 1);
    assert_eq!(state.balance_transfers.len(), 1);
    assert_eq!(state.token_transfer_receipts.len(), 1);
    assert_eq!(state.dex_pools.len(), 1);
    assert_eq!(state.liquidity_receipts.len(), 2);
    assert_eq!(state.swap_receipts.len(), 1);
}

#[test]
fn execution_layer_records_failed_receipts_and_preserves_product_invariants() {
    let mut state = genesis_state();
    for tx in product_demo_transactions() {
        queue_transaction(&mut state, tx);
    }
    let product_block = build_block(&mut state);
    assert!(product_block.receipts.iter().all(|receipt| receipt.success));

    let token_id = deterministic_token_id("FLOWT");
    let pool_id = deterministic_pool_id(LOCAL_TEST_UNIT_ASSET_ID, &token_id);
    let alice = "local-account:product:alice";
    let bob = "local-account:product:bob";
    let pool_before = state.dex_pools.get(&pool_id).expect("pool").clone();
    let alice_native_before = state.local_test_unit_balances[alice].units;
    let bob_native_before = state.local_test_unit_balances[bob].units;
    let bridge_credit_before = state.bridge_credit_receipts.len();
    let token_supply = state.token_definitions[&token_id].total_supply_units;

    let duplicate_bridge_deposit_id = "bridge-deposit:product:alice:001";
    let duplicate_bridge_credit_id = deterministic_bridge_credit_id(
        duplicate_bridge_deposit_id,
        alice,
        LOCAL_TEST_UNIT_ASSET_ID,
        10_000,
    );
    let negative_txs = vec![
        Transaction::TransferLocalTestUnits {
            transfer_id: "transfer:negative:insufficient-native".to_string(),
            from_account_id: bob.to_string(),
            to_account_id: alice.to_string(),
            amount_units: 100_000,
            account_nonce: 2,
            memo: "negative-insufficient-native".to_string(),
        },
        Transaction::TransferLocalTestUnits {
            transfer_id: "transfer:negative:duplicate-nonce".to_string(),
            from_account_id: alice.to_string(),
            to_account_id: bob.to_string(),
            amount_units: 1,
            account_nonce: 7,
            memo: "negative-duplicate-nonce".to_string(),
        },
        Transaction::TransferLocalTestUnits {
            transfer_id: "transfer:negative:stale-nonce".to_string(),
            from_account_id: alice.to_string(),
            to_account_id: bob.to_string(),
            amount_units: 1,
            account_nonce: 1,
            memo: "negative-stale-nonce".to_string(),
        },
        Transaction::TransferToken {
            transfer_id: deterministic_token_transfer_id(&token_id, bob, alice, 1_000_000, 2),
            token_id: token_id.clone(),
            from_account_id: bob.to_string(),
            to_account_id: alice.to_string(),
            amount_units: 1_000_000,
            account_nonce: 2,
        },
        Transaction::TransferToken {
            transfer_id: deterministic_token_transfer_id("token:missing", alice, bob, 1, 8),
            token_id: "token:missing".to_string(),
            from_account_id: alice.to_string(),
            to_account_id: bob.to_string(),
            amount_units: 1,
            account_nonce: 8,
        },
        Transaction::AddLiquidity {
            liquidity_id: deterministic_liquidity_id(&pool_id, alice, "add", "0:1:1"),
            pool_id: pool_id.clone(),
            provider_account_id: alice.to_string(),
            base_amount_units: 0,
            quote_amount_units: 1,
            min_lp_units: 1,
            account_nonce: 8,
        },
        Transaction::SwapExactIn {
            swap_id: deterministic_swap_id("pool:missing", bob, LOCAL_TEST_UNIT_ASSET_ID, 1, "1"),
            pool_id: "pool:missing".to_string(),
            trader_account_id: bob.to_string(),
            asset_in_id: LOCAL_TEST_UNIT_ASSET_ID.to_string(),
            amount_in_units: 1,
            min_amount_out_units: 1,
            account_nonce: 2,
        },
        Transaction::SwapExactIn {
            swap_id: deterministic_swap_id(&pool_id, bob, LOCAL_TEST_UNIT_ASSET_ID, 0, "1"),
            pool_id: pool_id.clone(),
            trader_account_id: bob.to_string(),
            asset_in_id: LOCAL_TEST_UNIT_ASSET_ID.to_string(),
            amount_in_units: 0,
            min_amount_out_units: 1,
            account_nonce: 2,
        },
        Transaction::SwapExactIn {
            swap_id: deterministic_swap_id(&pool_id, bob, LOCAL_TEST_UNIT_ASSET_ID, 100, "50000"),
            pool_id: pool_id.clone(),
            trader_account_id: bob.to_string(),
            asset_in_id: LOCAL_TEST_UNIT_ASSET_ID.to_string(),
            amount_in_units: 100,
            min_amount_out_units: 50_000,
            account_nonce: 2,
        },
        Transaction::ApplyBridgeCredit {
            credit_id: duplicate_bridge_credit_id,
            deposit_id: duplicate_bridge_deposit_id.to_string(),
            replay_key: "bridge-replay:product:alice:001".to_string(),
            account_id: alice.to_string(),
            asset_id: LOCAL_TEST_UNIT_ASSET_ID.to_string(),
            amount_units: 10_000,
            acknowledged_at_block_number: 8,
            account_nonce: 8,
        },
    ];
    for tx in negative_txs {
        queue_transaction(&mut state, tx);
    }
    let failure_block = build_block(&mut state);
    assert!(
        failure_block
            .receipts
            .iter()
            .all(|receipt| !receipt.success)
    );
    let error_codes = failure_block
        .receipts
        .iter()
        .map(|receipt| receipt.error_code.clone().expect("error code"))
        .collect::<Vec<_>>();
    for expected in [
        "insufficient-native-balance",
        "duplicate-nonce",
        "stale-nonce",
        "insufficient-token-balance",
        "invalid-token",
        "invalid-liquidity",
        "invalid-pool",
        "invalid-swap-amount",
        "min-output-not-met",
        "duplicate-bridge-credit",
    ] {
        assert!(
            error_codes.iter().any(|code| code == expected),
            "missing error code {expected}: {error_codes:?}"
        );
    }

    assert_eq!(state.dex_pools[&pool_id], pool_before);
    assert_eq!(
        state.local_test_unit_balances[alice].units,
        alice_native_before
    );
    assert_eq!(state.local_test_unit_balances[bob].units, bob_native_before);
    assert_eq!(state.bridge_credit_receipts.len(), bridge_credit_before);
    assert_eq!(state.account_nonces[alice].next_nonce, 8);
    assert_eq!(state.account_nonces[bob].next_nonce, 2);
    assert_eq!(total_token_units(&state, &token_id), token_supply);
    assert_eq!(
        state.dex_pools[&pool_id].total_lp_units,
        state
            .lp_positions
            .values()
            .filter(|position| position.pool_id == pool_id)
            .map(|position| position.lp_units)
            .sum::<u64>()
    );
}

#[test]
fn execution_cost_charge_mode_rejects_insufficient_execution_balance_atomically() {
    let mut state = genesis_state();
    state.config.execution_cost_charge_mode = EXECUTION_COST_CHARGE_NATIVE.to_string();
    apply_transaction(
        &mut state,
        &create_balance_tx("local-account:cost:alice", "operator:cost:alice"),
    )
    .unwrap();
    apply_transaction(
        &mut state,
        &create_balance_tx("local-account:cost:bob", "operator:cost:bob"),
    )
    .unwrap();
    apply_transaction(
        &mut state,
        &faucet_tx(
            "faucet:cost:alice",
            "local-account:cost:alice",
            "operator:cost:alice",
            1,
        ),
    )
    .unwrap();
    queue_transaction(
        &mut state,
        Transaction::TransferLocalTestUnits {
            transfer_id: "transfer:cost:too-expensive".to_string(),
            from_account_id: "local-account:cost:alice".to_string(),
            to_account_id: "local-account:cost:bob".to_string(),
            amount_units: 1,
            account_nonce: 1,
            memo: "cost-mode".to_string(),
        },
    );
    let block = build_block(&mut state);
    assert_eq!(block.receipts.len(), 1);
    assert!(!block.receipts[0].success);
    assert_eq!(
        block.receipts[0].error_code.as_deref(),
        Some("insufficient-execution-balance")
    );
    assert_eq!(
        state.local_test_unit_balances["local-account:cost:alice"].units,
        1
    );
    assert_eq!(
        state.local_test_unit_balances["local-account:cost:bob"].units,
        0
    );
    assert!(state.balance_transfers.is_empty());
    assert!(state.account_nonces.is_empty());
}

#[test]
fn duplicate_ids_are_rejected_for_new_objects() {
    let mut state = genesis_state();
    apply_transaction(&mut state, &register_rootfield_tx("rootfield:dup")).unwrap();

    let model = register_model_passport_tx("model:dup");
    apply_transaction(&mut state, &model).unwrap();
    assert_eq!(
        apply_transaction(&mut state, &model),
        Err(DevnetError::ModelPassportAlreadyExists(
            "model:dup".to_string()
        ))
    );

    let agent = register_agent_tx("agent:dup", Some("model:dup"));
    apply_transaction(&mut state, &agent).unwrap();
    assert_eq!(
        apply_transaction(&mut state, &agent),
        Err(DevnetError::AgentAlreadyExists("agent:dup".to_string()))
    );

    let balance = create_balance_tx("local-balance:dup", "agent:dup");
    apply_transaction(&mut state, &balance).unwrap();
    assert_eq!(
        apply_transaction(&mut state, &balance),
        Err(DevnetError::LocalTestUnitBalanceAlreadyExists(
            "local-balance:dup".to_string()
        ))
    );
    let faucet = faucet_tx("faucet:dup", "local-balance:dup", "agent:dup", 10);
    apply_transaction(&mut state, &faucet).unwrap();
    assert_eq!(
        apply_transaction(&mut state, &faucet),
        Err(DevnetError::FaucetRecordAlreadyExists(
            "faucet:dup".to_string()
        ))
    );

    let verifier = register_verifier_module_tx("verifier:dup");
    apply_transaction(&mut state, &verifier).unwrap();
    assert_eq!(
        apply_transaction(&mut state, &verifier),
        Err(DevnetError::VerifierModuleAlreadyExists(
            "verifier:dup".to_string()
        ))
    );

    apply_transaction(&mut state, &artifact_tx("artifact:dup", "rootfield:dup")).unwrap();
    let availability = availability_tx(
        "availability:dup",
        "artifact:dup",
        "rootfield:dup",
        "available",
    );
    apply_transaction(&mut state, &availability).unwrap();
    assert_eq!(
        apply_transaction(&mut state, &availability),
        Err(DevnetError::ArtifactAvailabilityAlreadyExists(
            "availability:dup".to_string()
        ))
    );

    apply_transaction(&mut state, &register_verifier_module_tx("verifier:test")).unwrap();
    apply_transaction(
        &mut state,
        &work_receipt_tx("receipt:dup", "rootfield:dup", "artifact:dup"),
    )
    .unwrap();
    apply_transaction(
        &mut state,
        &verifier_report_tx("report:dup", "receipt:dup", "rootfield:dup", "verified"),
    )
    .unwrap();

    let challenge = open_challenge_tx("challenge:dup", "receipt:dup");
    apply_transaction(&mut state, &challenge).unwrap();
    assert_eq!(
        apply_transaction(&mut state, &challenge),
        Err(DevnetError::ChallengeAlreadyExists(
            "challenge:dup".to_string()
        ))
    );
    apply_transaction(&mut state, &resolve_challenge_tx("challenge:dup")).unwrap();

    let finality = finalize_tx("finality:dup", "receipt:dup");
    apply_transaction(&mut state, &finality).unwrap();
    assert_eq!(
        apply_transaction(&mut state, &finality),
        Err(DevnetError::FinalityReceiptAlreadyExists(
            "finality:dup".to_string()
        ))
    );
}

#[test]
fn local_test_unit_faucet_updates_balance_without_value_claims() {
    let mut state = genesis_state();
    apply_transaction(
        &mut state,
        &create_balance_tx("local-balance:test", "agent:test"),
    )
    .unwrap();
    apply_transaction(
        &mut state,
        &faucet_tx("faucet:test:001", "local-balance:test", "agent:test", 25),
    )
    .unwrap();

    let balance = state
        .local_test_unit_balances
        .get("local-balance:test")
        .expect("balance");
    assert_eq!(balance.units, 25);
    assert_eq!(balance.total_faucet_units, 25);
    assert_eq!(
        balance.last_faucet_record_id.as_deref(),
        Some("faucet:test:001")
    );
    assert!(balance.no_value);
    assert!(
        state
            .faucet_records
            .get("faucet:test:001")
            .expect("faucet record")
            .no_value
    );

    assert_eq!(
        apply_transaction(
            &mut state,
            &faucet_tx("faucet:test:zero", "local-balance:test", "agent:test", 0),
        ),
        Err(DevnetError::FaucetAmountMustBePositive(
            "faucet:test:zero".to_string()
        ))
    );
    assert_eq!(
        apply_transaction(
            &mut state,
            &faucet_tx(
                "faucet:test:missing",
                "local-balance:missing",
                "agent:test",
                1
            ),
        ),
        Err(DevnetError::LocalTestUnitBalanceMissing(
            "local-balance:missing".to_string()
        ))
    );
}

#[test]
fn memory_update_rejects_missing_or_failed_source_receipt() {
    let mut missing = genesis_state();
    setup_registered_agent_and_rootfield(&mut missing, "rootfield:memory", "agent:memory");
    assert_eq!(
        apply_transaction(
            &mut missing,
            &memory_update_tx(
                "memory:missing",
                "agent:memory",
                "rootfield:memory",
                "receipt:missing"
            ),
        ),
        Err(DevnetError::WorkReceiptMissing(
            "receipt:missing".to_string()
        ))
    );

    let mut failed = genesis_state();
    setup_receipt_with_report_status(&mut failed, "rootfield:failed", "agent:failed", "failed");
    assert_eq!(
        apply_transaction(
            &mut failed,
            &memory_update_tx(
                "memory:failed",
                "agent:failed",
                "rootfield:failed",
                "receipt:status"
            ),
        ),
        Err(DevnetError::WorkReceiptFailed("receipt:status".to_string()))
    );
}

#[test]
fn challenge_rejects_missing_receipt() {
    let mut state = genesis_state();
    assert_eq!(
        apply_transaction(
            &mut state,
            &open_challenge_tx("challenge:missing", "receipt:missing"),
        ),
        Err(DevnetError::WorkReceiptMissing(
            "receipt:missing".to_string()
        ))
    );
}

#[test]
fn finalization_rejects_unresolved_challenge() {
    let mut state = genesis_state();
    setup_receipt_with_report_status(
        &mut state,
        "rootfield:challenge",
        "agent:challenge",
        "verified",
    );
    apply_transaction(
        &mut state,
        &open_challenge_tx("challenge:open", "receipt:status"),
    )
    .unwrap();

    assert_eq!(
        apply_transaction(
            &mut state,
            &finalize_tx("finality:blocked", "receipt:status")
        ),
        Err(DevnetError::ChallengeUnresolved(
            "receipt:status".to_string()
        ))
    );
}

#[test]
fn finalization_rejects_invalid_finality_status() {
    let mut state = genesis_state();
    setup_receipt_with_report_status(
        &mut state,
        "rootfield:finality",
        "agent:finality",
        "verified",
    );

    assert_eq!(
        apply_transaction(
            &mut state,
            &Transaction::FinalizeWorkReceipt {
                finality_receipt_id: "finality:invalid".to_string(),
                receipt_id: "receipt:status".to_string(),
                finalized_by: "operator:test".to_string(),
                finality_status: "pending".to_string(),
            },
        ),
        Err(DevnetError::InvalidFinalityStatus("pending".to_string()))
    );
}

#[test]
fn canonical_json_sorts_object_keys() {
    let left = serde_json::json!({ "b": 2, "a": { "d": 4, "c": 3 } });
    let right = serde_json::json!({ "a": { "c": 3, "d": 4 }, "b": 2 });
    assert_eq!(canonical_json(&left), canonical_json(&right));
}

#[test]
fn cli_demo_writes_state_and_handoff_files() {
    let temp = temp_dir("cli-demo");
    let state = temp.join("state.json");
    let out_dir = temp.join("handoff");

    let status = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            state.to_str().expect("state path"),
            "demo",
            "--out-dir",
            out_dir.to_str().expect("out path"),
        ])
        .status()
        .expect("run flowmemory-devnet");
    assert!(status.success());

    assert!(state.exists());
    assert!(out_dir.join("dashboard-state.json").exists());
    assert!(out_dir.join("indexer-handoff.json").exists());
    assert!(out_dir.join("verifier-handoff.json").exists());
    assert!(out_dir.join("control-plane-handoff.json").exists());
    assert!(out_dir.join("genesis-config.json").exists());
    assert!(out_dir.join("operator-key-references.json").exists());

    let body = std::fs::read_to_string(&state).expect("state body");
    assert!(body.contains("rootfield:demo:alpha"));
    assert!(body.contains("agent:demo:alpha"));
    assert!(body.contains("memory:demo:agent-alpha:core"));
    assert!(body.contains("finality:demo:001"));
    assert!(!body.contains("privateKey"));
    assert!(!body.contains("seed phrase"));
    assert!(!body.contains("tokenomics"));

    let dashboard_body =
        std::fs::read_to_string(out_dir.join("dashboard-state.json")).expect("dashboard body");
    assert!(dashboard_body.contains("agentAccounts"));
    assert!(dashboard_body.contains("memoryCells"));
    assert!(dashboard_body.contains("finalityReceipts"));
    assert!(dashboard_body.contains("operatorKeyReferences"));

    std::fs::remove_dir_all(&temp).expect("cleanup temp dir");
}

#[test]
fn cli_smoke_runs_full_flow() {
    let temp = temp_dir("cli-smoke");
    let state = temp.join("state.json");
    let out_dir = temp.join("handoff");

    let output = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            state.to_str().expect("state path"),
            "smoke",
            "--out-dir",
            out_dir.to_str().expect("out path"),
        ])
        .output()
        .expect("run smoke");
    assert!(output.status.success());

    let summary: serde_json::Value =
        serde_json::from_slice(&output.stdout).expect("smoke summary json");
    assert_eq!(summary["deterministicReplay"], true);
    assert_eq!(summary["blockHeight"], 10);
    assert_eq!(summary["checks"]["genesisConfigInitialized"], true);
    assert_eq!(summary["checks"]["operatorKeyReferencePresent"], true);
    assert_eq!(summary["checks"]["localTestUnitBalanceCreated"], true);
    assert_eq!(summary["checks"]["faucetRecordCreated"], true);
    assert_eq!(summary["checks"]["localTestUnitBalanceUnits"], 1000);
    assert_eq!(summary["checks"]["receiptFinalized"], true);
    assert!(out_dir.join("control-plane-handoff.json").exists());

    std::fs::remove_dir_all(&temp).expect("cleanup temp dir");
}

#[test]
fn cli_product_smoke_exports_token_and_dex_handoff() {
    let temp = temp_dir("cli-product-smoke");
    let state = temp.join("state.json");
    let out_dir = temp.join("handoff");

    let output = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            state.to_str().expect("state path"),
            "product-smoke",
            "--out-dir",
            out_dir.to_str().expect("out path"),
        ])
        .output()
        .expect("run product smoke");
    assert!(output.status.success());

    let summary: serde_json::Value =
        serde_json::from_slice(&output.stdout).expect("product smoke summary json");
    assert_eq!(summary["deterministicReplay"], true);
    assert_eq!(summary["checks"]["localAccountsFunded"], true);
    assert_eq!(summary["checks"]["tokenLaunched"], true);
    assert_eq!(summary["checks"]["poolCreated"], true);
    assert_eq!(summary["checks"]["liquidityAdded"], true);
    assert_eq!(summary["checks"]["swapExecuted"], true);
    assert_eq!(summary["checks"]["liquidityRemoved"], true);
    assert_eq!(summary["checks"]["productReceiptsQueryable"], true);
    assert!(out_dir.join("control-plane-handoff.json").exists());

    let control_plane_body =
        std::fs::read_to_string(out_dir.join("control-plane-handoff.json")).expect("handoff body");
    assert!(control_plane_body.contains("tokenDefinitions"));
    assert!(control_plane_body.contains("dexPools"));
    assert!(control_plane_body.contains("swapReceipts"));

    std::fs::remove_dir_all(&temp).expect("cleanup temp dir");
}

#[test]
fn cli_execution_e2e_writes_report_and_round_trips_state() {
    let temp = temp_dir("cli-execution-e2e");
    let state = temp.join("state.json");
    let out_dir = temp.join("execution-e2e");
    let snapshot = temp.join("snapshot.json");
    let imported = temp.join("imported-state.json");

    let output = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            state.to_str().expect("state path"),
            "execution-e2e",
            "--out-dir",
            out_dir.to_str().expect("out path"),
        ])
        .output()
        .expect("run execution e2e");
    assert!(output.status.success());

    let summary: serde_json::Value =
        serde_json::from_slice(&output.stdout).expect("execution e2e summary json");
    assert_eq!(summary["successReceipts"], 11);
    assert_eq!(summary["failedReceipts"], 11);

    let report_path = out_dir.join("execution-e2e-report.json");
    assert!(state.exists());
    assert!(report_path.exists());
    assert!(out_dir.join("dashboard-state.json").exists());
    assert!(out_dir.join("control-plane-handoff.json").exists());

    let report_body = std::fs::read_to_string(&report_path).expect("execution report body");
    let report: serde_json::Value =
        serde_json::from_str(&report_body).expect("execution report json");
    assert_eq!(
        report["schema"],
        "flowmemory.local_devnet.execution_e2e_report.v0"
    );
    assert_eq!(
        report["productTxIds"]
            .as_array()
            .expect("product txs")
            .len(),
        10
    );
    assert_eq!(
        report["negativeTxIds"]
            .as_array()
            .expect("negative txs")
            .len(),
        11
    );
    assert!(
        report["queryableIds"]["bridgeCreditIds"]
            .as_array()
            .is_some_and(|ids| !ids.is_empty())
    );
    assert!(
        report["queryableIds"]["executionReceiptIds"]
            .as_array()
            .is_some_and(|ids| ids.len() == 22)
    );
    assert!(
        report["failedTransactionEvidence"]
            .as_array()
            .expect("failed evidence")
            .iter()
            .any(|receipt| receipt["errorCode"] == "min-output-not-met")
    );
    assert!(
        report["failedTransactionEvidence"]
            .as_array()
            .expect("failed evidence")
            .iter()
            .any(|receipt| receipt["errorCode"] == "duplicate-transaction")
    );

    let inspect = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            state.to_str().expect("state path"),
            "inspect-state",
            "--summary",
        ])
        .output()
        .expect("inspect execution e2e state");
    assert!(inspect.status.success());
    let inspect_summary: serde_json::Value =
        serde_json::from_slice(&inspect.stdout).expect("inspect summary json");
    assert_eq!(inspect_summary["blocks"], 3);
    assert_eq!(inspect_summary["bridgeCreditReceipts"], 1);
    assert_eq!(inspect_summary["tokenTransferReceipts"], 1);
    assert_eq!(inspect_summary["executionReceipts"], 22);
    assert_eq!(inspect_summary["executionEvents"], 22);

    let export_status = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            state.to_str().expect("state path"),
            "export-state",
            "--out",
            snapshot.to_str().expect("snapshot path"),
        ])
        .status()
        .expect("export execution e2e state");
    assert!(export_status.success());

    let import_status = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            imported.to_str().expect("imported path"),
            "import-state",
            "--from",
            snapshot.to_str().expect("snapshot path"),
        ])
        .status()
        .expect("import execution e2e state");
    assert!(import_status.success());

    let original_body = std::fs::read_to_string(&state).expect("original state");
    let imported_body = std::fs::read_to_string(&imported).expect("imported state");
    assert_eq!(original_body, imported_body);

    std::fs::remove_dir_all(&temp).expect("cleanup temp dir");
}

#[test]
fn cli_start_runs_10_blocks_and_state_survives_restart() {
    let temp = temp_dir("start-10-restart");
    let state = temp.join("state.json");

    let first = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            state.to_str().expect("state path"),
            "start",
            "--blocks",
            "10",
        ])
        .output()
        .expect("start 10 blocks");
    assert!(first.status.success());

    let inspect = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            state.to_str().expect("state path"),
            "inspect-state",
            "--summary",
        ])
        .output()
        .expect("inspect after restart");
    assert!(inspect.status.success());
    let summary: serde_json::Value =
        serde_json::from_slice(&inspect.stdout).expect("inspect summary");
    assert_eq!(summary["blocks"], 10);
    assert_eq!(summary["nextBlockNumber"], 11);

    let second = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            state.to_str().expect("state path"),
            "start",
            "--blocks",
            "1",
        ])
        .output()
        .expect("start one more block");
    assert!(second.status.success());

    let inspect_again = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            state.to_str().expect("state path"),
            "inspect-state",
            "--summary",
        ])
        .output()
        .expect("inspect after second restart");
    assert!(inspect_again.status.success());
    let summary_again: serde_json::Value =
        serde_json::from_slice(&inspect_again.stdout).expect("inspect summary again");
    assert_eq!(summary_again["blocks"], 11);
    assert_eq!(summary_again["nextBlockNumber"], 12);

    std::fs::remove_dir_all(&temp).expect("cleanup temp dir");
}

#[test]
fn cli_generated_handoff_files_are_deterministic() {
    let temp = temp_dir("deterministic-handoff");
    let state_a = temp.join("a-state.json");
    let state_b = temp.join("b-state.json");
    let out_a = temp.join("a-handoff");
    let out_b = temp.join("b-handoff");

    for (state, out_dir) in [(&state_a, &out_a), (&state_b, &out_b)] {
        let output = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
            .args([
                "--state",
                state.to_str().expect("state path"),
                "demo",
                "--out-dir",
                out_dir.to_str().expect("out path"),
            ])
            .output()
            .expect("run demo");
        assert!(output.status.success());
    }

    for file in [
        "dashboard-state.json",
        "indexer-handoff.json",
        "verifier-handoff.json",
        "control-plane-handoff.json",
        "genesis-config.json",
        "operator-key-references.json",
        "state.json",
    ] {
        let left = std::fs::read_to_string(out_a.join(file)).expect("left handoff");
        let right = std::fs::read_to_string(out_b.join(file)).expect("right handoff");
        assert_eq!(left, right, "handoff file differed: {file}");
    }

    std::fs::remove_dir_all(&temp).expect("cleanup temp dir");
}

#[test]
fn cli_rejects_malformed_fixture() {
    let temp = temp_dir("malformed-fixture");
    let state = temp.join("state.json");
    let fixture = temp.join("bad.json");
    std::fs::write(&fixture, "{ not valid json").expect("write bad fixture");

    let output = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            state.to_str().expect("state path"),
            "submit-fixture",
            "--fixture",
            fixture.to_str().expect("fixture path"),
        ])
        .output()
        .expect("run submit fixture");

    assert!(!output.status.success());
    assert!(String::from_utf8_lossy(&output.stderr).contains("failed to parse fixture"));
    assert!(!state.exists());

    std::fs::remove_dir_all(&temp).expect("cleanup temp dir");
}

#[test]
fn cli_export_import_state_round_trip_is_deterministic() {
    let temp = temp_dir("export-import");
    let state = temp.join("state.json");
    let imported = temp.join("imported-state.json");
    let snapshot = temp.join("snapshot.json");

    let demo_status = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            state.to_str().expect("state path"),
            "demo",
            "--out-dir",
            temp.join("handoff").to_str().expect("handoff path"),
        ])
        .status()
        .expect("run demo");
    assert!(demo_status.success());

    let export_status = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            state.to_str().expect("state path"),
            "export-state",
            "--out",
            snapshot.to_str().expect("snapshot path"),
        ])
        .status()
        .expect("export state");
    assert!(export_status.success());

    let import_status = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            imported.to_str().expect("imported path"),
            "import-state",
            "--from",
            snapshot.to_str().expect("snapshot path"),
        ])
        .status()
        .expect("import state");
    assert!(import_status.success());

    let original_body = std::fs::read_to_string(&state).expect("original state");
    let imported_body = std::fs::read_to_string(&imported).expect("imported state");
    assert_eq!(original_body, imported_body);
    assert!(temp.join("genesis-config.json").exists());
    assert!(temp.join("operator-key-references.json").exists());

    std::fs::remove_dir_all(&temp).expect("cleanup temp dir");
}

#[test]
fn cli_node_runs_ten_blocks_and_includes_authorized_inbox_tx() {
    let temp = temp_dir("cli-node");
    let state = temp.join("state.json");
    let node_dir = temp.join("node");

    let faucet = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            state.to_str().expect("state path"),
            "--node-dir",
            node_dir.to_str().expect("node dir"),
            "faucet",
            "--account",
            "local-account:cli-node",
            "--amount",
            "9",
            "--reason",
            "cli-node-test",
            "--authorized-by",
            "local-test-operator",
        ])
        .status()
        .expect("submit faucet");
    assert!(faucet.success());

    let node = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            state.to_str().expect("state path"),
            "--node-dir",
            node_dir.to_str().expect("node dir"),
            "node",
            "--node-id",
            "node:test:cli",
            "--block-ms",
            "1",
            "--max-blocks",
            "10",
        ])
        .status()
        .expect("run node");
    assert!(node.success());

    let output = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            state.to_str().expect("state path"),
            "--node-dir",
            node_dir.to_str().expect("node dir"),
            "node-status",
        ])
        .output()
        .expect("node status");
    assert!(output.status.success());
    let summary: serde_json::Value =
        serde_json::from_slice(&output.stdout).expect("status summary json");
    assert_eq!(summary["state"]["blocks"], 10);
    assert_eq!(summary["state"]["localBalances"], 1);
    assert_eq!(summary["state"]["faucetRecords"], 1);
    let state_body = std::fs::read_to_string(&state).expect("state body");
    let state_json: serde_json::Value = serde_json::from_str(&state_body).expect("state json");
    assert_eq!(
        state_json["blocks"][0]["receipts"][0]["authorization"]["signer"],
        "local-test-operator"
    );
    assert!(node_dir.join("node-identity.json").exists());
    assert!(node_dir.join("status.json").exists());

    std::fs::remove_dir_all(&temp).expect("cleanup temp dir");
}

#[test]
fn cli_static_peer_sync_reconciles_two_local_node_states() {
    let temp = temp_dir("cli-peer-sync");
    let state_a = temp.join("state-a.json");
    let state_b = temp.join("state-b.json");
    let node_a = temp.join("node-a");
    let node_b = temp.join("node-b");
    let peer_b = temp.join("node-b-peers.json");

    let faucet = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            state_a.to_str().expect("state a"),
            "--node-dir",
            node_a.to_str().expect("node a"),
            "faucet",
            "--account",
            "local-account:peer-sync",
            "--amount",
            "11",
            "--reason",
            "peer-sync-test",
            "--authorized-by",
            "local-test-operator",
        ])
        .status()
        .expect("submit faucet to node a");
    assert!(faucet.success());

    let node_a_status = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            state_a.to_str().expect("state a"),
            "--node-dir",
            node_a.to_str().expect("node a"),
            "node",
            "--node-id",
            "node:test:a",
            "--block-ms",
            "1",
            "--max-blocks",
            "2",
        ])
        .status()
        .expect("run node a");
    assert!(node_a_status.success());

    std::fs::write(
        &peer_b,
        format!(
            "{{\"schema\":\"flowmemory.local_devnet.static_peers.v0\",\"nodeId\":\"node:test:b\",\"peers\":[{{\"nodeId\":\"node:test:a\",\"statePath\":\"{}\"}}]}}\n",
            state_a.to_string_lossy().replace('\\', "\\\\")
        ),
    )
    .expect("write peer config");

    let node_b_status = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            state_b.to_str().expect("state b"),
            "--node-dir",
            node_b.to_str().expect("node b"),
            "node",
            "--node-id",
            "node:test:b",
            "--block-ms",
            "1",
            "--max-blocks",
            "1",
            "--peer-config",
            peer_b.to_str().expect("peer config"),
        ])
        .status()
        .expect("run node b");
    assert!(node_b_status.success());

    let summary_a = inspect_summary(&state_a, &node_a);
    let summary_b = inspect_summary(&state_b, &node_b);
    assert_eq!(
        summary_a["state"]["stateRoot"],
        summary_b["state"]["stateRoot"]
    );
    assert_eq!(summary_b["state"]["localBalances"], 1);

    std::fs::remove_dir_all(&temp).expect("cleanup temp dir");
}

#[test]
fn zero_hash_constant_is_hex_32_bytes() {
    assert_eq!(ZERO_HASH.len(), 66);
    assert!(ZERO_HASH.starts_with("0x"));
}

fn inspect_summary(state: &std::path::Path, node_dir: &std::path::Path) -> serde_json::Value {
    let output = Command::new(env!("CARGO_BIN_EXE_flowmemory-devnet"))
        .args([
            "--state",
            state.to_str().expect("state path"),
            "--node-dir",
            node_dir.to_str().expect("node dir"),
            "node-status",
        ])
        .output()
        .expect("inspect node status");
    assert!(output.status.success());
    serde_json::from_slice(&output.stdout).expect("status json")
}

fn temp_dir(name: &str) -> std::path::PathBuf {
    let temp = std::env::temp_dir().join(format!(
        "flowmemory-devnet-test-{}-{name}",
        std::process::id()
    ));
    if temp.exists() {
        std::fs::remove_dir_all(&temp).expect("remove old temp dir");
    }
    std::fs::create_dir_all(&temp).expect("create temp dir");
    temp
}

fn run_demo_chain() -> (
    String,
    String,
    String,
    flowmemory_devnet::model::StateMapRoots,
) {
    let mut state = genesis_state();
    for tx in demo_transactions() {
        queue_transaction(&mut state, tx);
    }
    let first = build_block(&mut state);
    let appchain_chain_id = state.chain_id.clone();
    queue_transaction(
        &mut state,
        Transaction::AnchorBatchToBasePlaceholder {
            appchain_chain_id,
            finality_status: "local-placeholder".to_string(),
        },
    );
    let second = build_block(&mut state);
    (
        first.block_hash,
        second.block_hash,
        state_root(&state),
        state_map_roots(&state),
    )
}

fn setup_registered_agent_and_rootfield(
    state: &mut flowmemory_devnet::model::ChainState,
    rootfield_id: &str,
    agent_id: &str,
) {
    apply_transaction(state, &register_rootfield_tx(rootfield_id)).unwrap();
    apply_transaction(state, &register_model_passport_tx("model:status")).unwrap();
    apply_transaction(state, &register_agent_tx(agent_id, Some("model:status"))).unwrap();
}

fn setup_receipt_with_report_status(
    state: &mut flowmemory_devnet::model::ChainState,
    rootfield_id: &str,
    agent_id: &str,
    status: &str,
) {
    setup_registered_agent_and_rootfield(state, rootfield_id, agent_id);
    apply_transaction(state, &artifact_tx("artifact:status", rootfield_id)).unwrap();
    apply_transaction(state, &register_verifier_module_tx("verifier:test")).unwrap();
    apply_transaction(
        state,
        &work_receipt_tx("receipt:status", rootfield_id, "artifact:status"),
    )
    .unwrap();
    apply_transaction(
        state,
        &verifier_report_tx("report:status", "receipt:status", rootfield_id, status),
    )
    .unwrap();
}

fn setup_product_test_accounts(state: &mut flowmemory_devnet::model::ChainState) {
    apply_transaction(
        state,
        &create_balance_tx("local-account:product:alice", "operator:product:alice"),
    )
    .unwrap();
    apply_transaction(
        state,
        &create_balance_tx("local-account:product:bob", "operator:product:bob"),
    )
    .unwrap();
    apply_transaction(
        state,
        &faucet_tx(
            "faucet:product:alice",
            "local-account:product:alice",
            "operator:product:alice",
            10_000,
        ),
    )
    .unwrap();
    apply_transaction(
        state,
        &faucet_tx(
            "faucet:product:bob",
            "local-account:product:bob",
            "operator:product:bob",
            1_000,
        ),
    )
    .unwrap();
}

fn total_token_units(state: &flowmemory_devnet::model::ChainState, token_id: &str) -> u64 {
    let account_units = state
        .token_balances
        .values()
        .filter(|balance| balance.token_id == token_id)
        .map(|balance| balance.units)
        .sum::<u64>();
    let pool_units = state
        .dex_pools
        .values()
        .map(|pool| {
            let mut total = 0;
            if pool.base_asset_id == token_id {
                total += pool.reserve_base_units;
            }
            if pool.quote_asset_id == token_id {
                total += pool.reserve_quote_units;
            }
            total
        })
        .sum::<u64>();
    account_units + pool_units
}

fn register_rootfield_tx(rootfield_id: &str) -> Transaction {
    Transaction::RegisterRootfield {
        rootfield_id: rootfield_id.to_string(),
        owner: "operator:test".to_string(),
        schema_hash: keccak_hex(b"schema:test"),
        metadata_hash: keccak_hex(b"metadata:test"),
    }
}

fn register_model_passport_tx(model_passport_id: &str) -> Transaction {
    Transaction::RegisterModelPassport {
        model_passport_id: model_passport_id.to_string(),
        issuer: "operator:test".to_string(),
        model_family: "fixture-model".to_string(),
        model_hash: keccak_hex(format!("model:{model_passport_id}").as_bytes()),
        metadata_hash: keccak_hex(format!("model-metadata:{model_passport_id}").as_bytes()),
    }
}

fn register_agent_tx(agent_id: &str, model_passport_id: Option<&str>) -> Transaction {
    Transaction::RegisterAgent {
        agent_id: agent_id.to_string(),
        controller: "operator:test".to_string(),
        model_passport_id: model_passport_id.map(ToOwned::to_owned),
        metadata_hash: keccak_hex(format!("agent-metadata:{agent_id}").as_bytes()),
    }
}

fn create_balance_tx(account_id: &str, owner: &str) -> Transaction {
    Transaction::CreateLocalTestUnitBalance {
        account_id: account_id.to_string(),
        owner: owner.to_string(),
    }
}

fn faucet_tx(
    faucet_record_id: &str,
    account_id: &str,
    recipient: &str,
    amount_units: u64,
) -> Transaction {
    Transaction::FaucetLocalTestUnits {
        faucet_record_id: faucet_record_id.to_string(),
        account_id: account_id.to_string(),
        recipient: recipient.to_string(),
        amount_units,
        reason: "unit-test-no-value".to_string(),
    }
}

fn register_verifier_module_tx(verifier_id: &str) -> Transaction {
    Transaction::RegisterVerifierModule {
        verifier_id: verifier_id.to_string(),
        operator: "operator:test".to_string(),
        module_hash: keccak_hex(format!("verifier-module:{verifier_id}").as_bytes()),
        rule_set: "flowmemory.work.rule_set.test.v0".to_string(),
        metadata_hash: keccak_hex(format!("verifier-metadata:{verifier_id}").as_bytes()),
    }
}

fn artifact_tx(artifact_id: &str, rootfield_id: &str) -> Transaction {
    Transaction::SubmitArtifactCommitment {
        artifact_id: artifact_id.to_string(),
        rootfield_id: rootfield_id.to_string(),
        commitment: keccak_hex(format!("artifact:{artifact_id}").as_bytes()),
        uri_hint: Some(format!("fixture://artifact/{artifact_id}")),
    }
}

fn availability_tx(
    proof_id: &str,
    artifact_id: &str,
    rootfield_id: &str,
    status: &str,
) -> Transaction {
    Transaction::MarkArtifactAvailability {
        proof_id: proof_id.to_string(),
        artifact_id: artifact_id.to_string(),
        rootfield_id: rootfield_id.to_string(),
        proof_digest: keccak_hex(format!("availability:{proof_id}").as_bytes()),
        storage_backend: "fixture-local".to_string(),
        status: status.to_string(),
    }
}

fn work_receipt_tx(receipt_id: &str, rootfield_id: &str, artifact_id: &str) -> Transaction {
    Transaction::SubmitWorkReceipt {
        receipt_id: receipt_id.to_string(),
        rootfield_id: rootfield_id.to_string(),
        worker_id: "worker:test".to_string(),
        input_root: ZERO_HASH.to_string(),
        output_root: keccak_hex(format!("output:{receipt_id}").as_bytes()),
        artifact_commitment: keccak_hex(format!("artifact:{artifact_id}").as_bytes()),
        rule_set: "flowmemory.work.rule_set.test.v0".to_string(),
    }
}

fn verifier_report_tx(
    report_id: &str,
    receipt_id: &str,
    rootfield_id: &str,
    status: &str,
) -> Transaction {
    Transaction::SubmitVerifierReport {
        report_id: report_id.to_string(),
        rootfield_id: rootfield_id.to_string(),
        receipt_id: receipt_id.to_string(),
        verifier_id: "verifier:test".to_string(),
        report_digest: keccak_hex(format!("report:{report_id}:{status}").as_bytes()),
        status: status.to_string(),
        reason_codes: Vec::new(),
    }
}

fn memory_update_tx(
    memory_cell_id: &str,
    agent_id: &str,
    rootfield_id: &str,
    source_receipt_id: &str,
) -> Transaction {
    Transaction::UpdateMemoryCell {
        memory_cell_id: memory_cell_id.to_string(),
        agent_id: agent_id.to_string(),
        rootfield_id: rootfield_id.to_string(),
        source_receipt_id: source_receipt_id.to_string(),
        new_root: keccak_hex(format!("memory-root:{memory_cell_id}").as_bytes()),
        memory_delta_root: keccak_hex(format!("memory-delta:{memory_cell_id}").as_bytes()),
    }
}

fn open_challenge_tx(challenge_id: &str, receipt_id: &str) -> Transaction {
    Transaction::OpenChallenge {
        challenge_id: challenge_id.to_string(),
        receipt_id: receipt_id.to_string(),
        challenger: "reviewer:test".to_string(),
        evidence_hash: keccak_hex(format!("challenge-evidence:{challenge_id}").as_bytes()),
        reason_code: "unit-test".to_string(),
    }
}

fn resolve_challenge_tx(challenge_id: &str) -> Transaction {
    Transaction::ResolveChallenge {
        challenge_id: challenge_id.to_string(),
        resolver: "verifier:test".to_string(),
        resolution: "dismissed".to_string(),
    }
}

fn finalize_tx(finality_receipt_id: &str, receipt_id: &str) -> Transaction {
    Transaction::FinalizeWorkReceipt {
        finality_receipt_id: finality_receipt_id.to_string(),
        receipt_id: receipt_id.to_string(),
        finalized_by: "operator:test".to_string(),
        finality_status: "finalized".to_string(),
    }
}
