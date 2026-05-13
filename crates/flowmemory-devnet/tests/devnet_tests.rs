use flowmemory_devnet::model::{
    FLOWPULSE_TOPIC0, Transaction, ZERO_HASH, build_block, demo_transactions, genesis_state,
    queue_transaction, state_root,
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
    assert_eq!(before, state_root(&state));
    assert!(state.rootfields.is_empty());
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
    assert_eq!(state.artifact_commitments.len(), 1);
    assert_eq!(state.work_receipts.len(), 1);
    assert_eq!(state.verifier_reports.len(), 1);
    assert_eq!(state.imported_observations.len(), 1);
    assert_eq!(state.imported_verifier_reports.len(), 1);
    assert_eq!(state.base_anchors.len(), 1);
}

#[test]
fn canonical_json_sorts_object_keys() {
    let left = serde_json::json!({ "b": 2, "a": { "d": 4, "c": 3 } });
    let right = serde_json::json!({ "a": { "c": 3, "d": 4 }, "b": 2 });
    assert_eq!(canonical_json(&left), canonical_json(&right));
}

#[test]
fn cli_demo_writes_state_and_handoff_files() {
    let temp = std::env::temp_dir().join(format!("flowmemory-devnet-test-{}", std::process::id()));
    if temp.exists() {
        std::fs::remove_dir_all(&temp).expect("remove old temp dir");
    }
    std::fs::create_dir_all(&temp).expect("create temp dir");
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

    let body = std::fs::read_to_string(&state).expect("state body");
    assert!(body.contains("rootfield:demo:alpha"));
    assert!(!body.contains("privateKey"));
    assert!(!body.contains("tokenomics"));

    std::fs::remove_dir_all(&temp).expect("cleanup temp dir");
}

#[test]
fn zero_hash_constant_is_hex_32_bytes() {
    assert_eq!(ZERO_HASH.len(), 66);
    assert!(ZERO_HASH.starts_with("0x"));
}
