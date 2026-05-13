use flowmemory_devnet::model::{
    DevnetError, FLOWPULSE_TOPIC0, Transaction, ZERO_HASH, apply_transaction, build_block,
    demo_transactions, genesis_state, queue_transaction, state_map_roots, state_root,
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
    assert_eq!(before, state_root(&state));
    assert!(state.rootfields.is_empty());
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
        &Transaction::FaucetLocalBalance {
            faucet_record_id: "faucet:unit:001".to_string(),
            account_id: "local-account:alice".to_string(),
            amount: 50,
            reason: "unit-test".to_string(),
        },
    )
    .unwrap();
    apply_transaction(
        &mut state,
        &Transaction::TransferLocalBalance {
            transfer_id: "transfer:unit:001".to_string(),
            from_account_id: "local-account:alice".to_string(),
            to_account_id: "local-account:bob".to_string(),
            amount: 20,
            memo: "unit-test-transfer".to_string(),
        },
    )
    .unwrap();

    assert_eq!(state.local_balances["local-account:alice"].balance, 30);
    assert_eq!(state.local_balances["local-account:bob"].balance, 20);
    assert_eq!(state.faucet_records.len(), 1);
    assert_eq!(state.balance_transfers.len(), 1);

    assert_eq!(
        apply_transaction(
            &mut state,
            &Transaction::TransferLocalBalance {
                transfer_id: "transfer:unit:002".to_string(),
                from_account_id: "local-account:bob".to_string(),
                to_account_id: "local-account:alice".to_string(),
                amount: 30,
                memo: "too-much".to_string(),
            },
        ),
        Err(DevnetError::LocalBalanceInsufficient(
            "local-account:bob".to_string()
        ))
    );
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
    assert_eq!(summary["checks"]["genesisConfigInitialized"], true);
    assert_eq!(summary["checks"]["operatorKeyReferencePresent"], true);
    assert_eq!(summary["checks"]["receiptFinalized"], true);
    assert!(out_dir.join("control-plane-handoff.json").exists());

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
