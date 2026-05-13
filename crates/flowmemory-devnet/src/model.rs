use crate::hash::{hash_json, keccak_hex};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use thiserror::Error;

pub const STATE_SCHEMA: &str = "flowmemory.local_devnet.state.v0";
pub const BLOCK_SCHEMA: &str = "flowmemory.local_devnet.block.v0";
pub const TX_SCHEMA: &str = "flowmemory.local_devnet.tx.v0";
pub const GENESIS_HASH: &str = "0x0f23c892cbd2d00c10839d97ddab833698a83f8df8d6df27ceac03cfdd4b7bc9";
pub const ZERO_HASH: &str = "0x0000000000000000000000000000000000000000000000000000000000000000";
pub const FLOWPULSE_TOPIC0: &str =
    "0x5d07190b9ae441b4d7b16259a48424acd451492b12f5f99a29f5bfd992c13e43";

#[derive(Debug, Error, PartialEq, Eq)]
pub enum DevnetError {
    #[error("rootfield already exists: {0}")]
    RootfieldAlreadyExists(String),
    #[error("rootfield does not exist: {0}")]
    RootfieldMissing(String),
    #[error("rootfield is inactive: {0}")]
    RootfieldInactive(String),
    #[error("artifact commitment already exists: {0}")]
    ArtifactAlreadyExists(String),
    #[error("work receipt already exists: {0}")]
    WorkReceiptAlreadyExists(String),
    #[error("work receipt does not exist: {0}")]
    WorkReceiptMissing(String),
    #[error("verifier report already exists: {0}")]
    VerifierReportAlreadyExists(String),
    #[error("imported observation already exists: {0}")]
    ImportedObservationAlreadyExists(String),
    #[error("imported verifier report already exists: {0}")]
    ImportedVerifierReportAlreadyExists(String),
    #[error("base anchor already exists: {0}")]
    AnchorAlreadyExists(String),
    #[error("invalid event signature: {0}")]
    InvalidEventSignature(String),
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ChainState {
    pub schema: String,
    pub chain_id: String,
    pub genesis_hash: String,
    pub next_block_number: u64,
    pub logical_time: u64,
    pub parent_hash: String,
    pub rootfields: BTreeMap<String, Rootfield>,
    pub artifact_commitments: BTreeMap<String, ArtifactCommitment>,
    pub work_receipts: BTreeMap<String, WorkReceipt>,
    pub verifier_reports: BTreeMap<String, VerifierReport>,
    pub imported_observations: BTreeMap<String, ImportedFlowPulseObservation>,
    pub imported_verifier_reports: BTreeMap<String, ImportedVerifierReport>,
    pub base_anchors: BTreeMap<String, BaseAnchorPlaceholder>,
    pub blocks: Vec<Block>,
    pub pending_txs: Vec<TxEnvelope>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct Rootfield {
    pub rootfield_id: String,
    pub owner: String,
    pub schema_hash: String,
    pub metadata_hash: String,
    pub latest_root: Option<String>,
    pub pulse_count: u64,
    pub root_count: u64,
    pub active: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ArtifactCommitment {
    pub artifact_id: String,
    pub rootfield_id: String,
    pub commitment: String,
    pub uri_hint: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct WorkReceipt {
    pub receipt_id: String,
    pub rootfield_id: String,
    pub worker_id: String,
    pub input_root: String,
    pub output_root: String,
    pub artifact_commitment: String,
    pub rule_set: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct VerifierReport {
    pub report_id: String,
    pub rootfield_id: String,
    pub receipt_id: String,
    pub verifier_id: String,
    pub report_digest: String,
    pub status: String,
    pub reason_codes: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ImportedFlowPulseObservation {
    pub observation_id: String,
    pub chain_id: String,
    pub emitting_contract: String,
    pub block_number: String,
    pub block_hash: String,
    pub tx_hash: String,
    pub transaction_index: String,
    pub log_index: String,
    pub event_signature: String,
    pub pulse_id: String,
    pub rootfield_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ImportedVerifierReport {
    pub report_id: String,
    pub rootfield_id: Option<String>,
    pub receipt_id: Option<String>,
    pub report_digest: String,
    pub status: String,
    pub source: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct BaseAnchorPlaceholder {
    pub anchor_id: String,
    pub appchain_chain_id: String,
    pub block_range_start: u64,
    pub block_range_end: u64,
    pub state_root: String,
    pub work_receipt_root: String,
    pub verifier_report_root: String,
    pub rootfield_state_root: String,
    pub artifact_commitment_root: String,
    pub previous_anchor_id: String,
    pub finality_status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(
    tag = "type",
    rename_all = "PascalCase",
    rename_all_fields = "camelCase"
)]
pub enum Transaction {
    RegisterRootfield {
        rootfield_id: String,
        owner: String,
        schema_hash: String,
        metadata_hash: String,
    },
    CommitRoot {
        rootfield_id: String,
        actor: String,
        root: String,
        artifact_commitment: String,
    },
    SubmitArtifactCommitment {
        artifact_id: String,
        rootfield_id: String,
        commitment: String,
        uri_hint: Option<String>,
    },
    SubmitWorkReceipt {
        receipt_id: String,
        rootfield_id: String,
        worker_id: String,
        input_root: String,
        output_root: String,
        artifact_commitment: String,
        rule_set: String,
    },
    SubmitVerifierReport {
        report_id: String,
        rootfield_id: String,
        receipt_id: String,
        verifier_id: String,
        report_digest: String,
        status: String,
        reason_codes: Vec<String>,
    },
    AnchorBatchToBasePlaceholder {
        appchain_chain_id: String,
        finality_status: String,
    },
    ImportFlowPulseObservation(ImportedFlowPulseObservation),
    ImportVerifierReport(ImportedVerifierReport),
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct TxEnvelope {
    pub tx_id: String,
    pub tx: Transaction,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct Block {
    pub schema: String,
    pub block_number: u64,
    pub parent_hash: String,
    pub logical_time: u64,
    pub tx_ids: Vec<String>,
    pub receipts: Vec<BlockReceipt>,
    pub state_root: String,
    pub block_hash: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct BlockReceipt {
    pub tx_id: String,
    pub status: String,
    pub error: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct StateCommitmentView<'a> {
    schema: &'a str,
    chain_id: &'a str,
    genesis_hash: &'a str,
    rootfields: &'a BTreeMap<String, Rootfield>,
    artifact_commitments: &'a BTreeMap<String, ArtifactCommitment>,
    work_receipts: &'a BTreeMap<String, WorkReceipt>,
    verifier_reports: &'a BTreeMap<String, VerifierReport>,
    imported_observations: &'a BTreeMap<String, ImportedFlowPulseObservation>,
    imported_verifier_reports: &'a BTreeMap<String, ImportedVerifierReport>,
    base_anchors: &'a BTreeMap<String, BaseAnchorPlaceholder>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct RootMapView<'a, T> {
    schema: &'a str,
    entries: &'a BTreeMap<String, T>,
}

pub fn genesis_state() -> ChainState {
    ChainState {
        schema: STATE_SCHEMA.to_string(),
        chain_id: "flowmemory-local-devnet-v0".to_string(),
        genesis_hash: GENESIS_HASH.to_string(),
        next_block_number: 1,
        logical_time: 1_778_688_000,
        parent_hash: GENESIS_HASH.to_string(),
        rootfields: BTreeMap::new(),
        artifact_commitments: BTreeMap::new(),
        work_receipts: BTreeMap::new(),
        verifier_reports: BTreeMap::new(),
        imported_observations: BTreeMap::new(),
        imported_verifier_reports: BTreeMap::new(),
        base_anchors: BTreeMap::new(),
        blocks: Vec::new(),
        pending_txs: Vec::new(),
    }
}

pub fn envelope_tx(tx: Transaction) -> TxEnvelope {
    let tx_id = hash_json(TX_SCHEMA, &tx);
    TxEnvelope { tx_id, tx }
}

pub fn queue_transaction(state: &mut ChainState, tx: Transaction) -> String {
    let envelope = envelope_tx(tx);
    let tx_id = envelope.tx_id.clone();
    state.pending_txs.push(envelope);
    tx_id
}

pub fn state_root(state: &ChainState) -> String {
    let view = StateCommitmentView {
        schema: STATE_SCHEMA,
        chain_id: &state.chain_id,
        genesis_hash: &state.genesis_hash,
        rootfields: &state.rootfields,
        artifact_commitments: &state.artifact_commitments,
        work_receipts: &state.work_receipts,
        verifier_reports: &state.verifier_reports,
        imported_observations: &state.imported_observations,
        imported_verifier_reports: &state.imported_verifier_reports,
        base_anchors: &state.base_anchors,
    };
    hash_json("flowmemory.local_devnet.state_root.v0", &view)
}

pub fn map_root<T: Serialize>(schema: &'static str, entries: &BTreeMap<String, T>) -> String {
    hash_json(
        "flowmemory.local_devnet.map_root.v0",
        &RootMapView { schema, entries },
    )
}

pub fn build_block(state: &mut ChainState) -> Block {
    let txs = std::mem::take(&mut state.pending_txs);
    let mut receipts = Vec::with_capacity(txs.len());
    let mut tx_ids = Vec::with_capacity(txs.len());

    for envelope in txs {
        tx_ids.push(envelope.tx_id.clone());
        let result = apply_transaction(state, &envelope.tx);
        receipts.push(BlockReceipt {
            tx_id: envelope.tx_id,
            status: if result.is_ok() {
                "applied"
            } else {
                "rejected"
            }
            .to_string(),
            error: result.err().map(|error| error.to_string()),
        });
    }

    let root = state_root(state);
    let block_number = state.next_block_number;
    let logical_time = state.logical_time;
    let parent_hash = state.parent_hash.clone();

    let mut block = Block {
        schema: BLOCK_SCHEMA.to_string(),
        block_number,
        parent_hash,
        logical_time,
        tx_ids,
        receipts,
        state_root: root,
        block_hash: ZERO_HASH.to_string(),
    };
    block.block_hash = hash_json("flowmemory.local_devnet.block_hash.v0", &block);

    state.next_block_number += 1;
    state.logical_time += 1;
    state.parent_hash = block.block_hash.clone();
    state.blocks.push(block.clone());

    block
}

pub fn apply_transaction(state: &mut ChainState, tx: &Transaction) -> Result<(), DevnetError> {
    match tx {
        Transaction::RegisterRootfield {
            rootfield_id,
            owner,
            schema_hash,
            metadata_hash,
        } => {
            if state.rootfields.contains_key(rootfield_id) {
                return Err(DevnetError::RootfieldAlreadyExists(rootfield_id.clone()));
            }
            state.rootfields.insert(
                rootfield_id.clone(),
                Rootfield {
                    rootfield_id: rootfield_id.clone(),
                    owner: owner.clone(),
                    schema_hash: schema_hash.clone(),
                    metadata_hash: metadata_hash.clone(),
                    latest_root: None,
                    pulse_count: 1,
                    root_count: 0,
                    active: true,
                },
            );
        }
        Transaction::CommitRoot {
            rootfield_id,
            actor: _,
            root,
            artifact_commitment: _,
        } => {
            let rootfield = state
                .rootfields
                .get_mut(rootfield_id)
                .ok_or_else(|| DevnetError::RootfieldMissing(rootfield_id.clone()))?;
            if !rootfield.active {
                return Err(DevnetError::RootfieldInactive(rootfield_id.clone()));
            }
            rootfield.latest_root = Some(root.clone());
            rootfield.pulse_count += 1;
            rootfield.root_count += 1;
        }
        Transaction::SubmitArtifactCommitment {
            artifact_id,
            rootfield_id,
            commitment,
            uri_hint,
        } => {
            ensure_rootfield_exists(state, rootfield_id)?;
            if state.artifact_commitments.contains_key(artifact_id) {
                return Err(DevnetError::ArtifactAlreadyExists(artifact_id.clone()));
            }
            state.artifact_commitments.insert(
                artifact_id.clone(),
                ArtifactCommitment {
                    artifact_id: artifact_id.clone(),
                    rootfield_id: rootfield_id.clone(),
                    commitment: commitment.clone(),
                    uri_hint: uri_hint.clone(),
                },
            );
        }
        Transaction::SubmitWorkReceipt {
            receipt_id,
            rootfield_id,
            worker_id,
            input_root,
            output_root,
            artifact_commitment,
            rule_set,
        } => {
            ensure_rootfield_exists(state, rootfield_id)?;
            if state.work_receipts.contains_key(receipt_id) {
                return Err(DevnetError::WorkReceiptAlreadyExists(receipt_id.clone()));
            }
            state.work_receipts.insert(
                receipt_id.clone(),
                WorkReceipt {
                    receipt_id: receipt_id.clone(),
                    rootfield_id: rootfield_id.clone(),
                    worker_id: worker_id.clone(),
                    input_root: input_root.clone(),
                    output_root: output_root.clone(),
                    artifact_commitment: artifact_commitment.clone(),
                    rule_set: rule_set.clone(),
                },
            );
        }
        Transaction::SubmitVerifierReport {
            report_id,
            rootfield_id,
            receipt_id,
            verifier_id,
            report_digest,
            status,
            reason_codes,
        } => {
            ensure_rootfield_exists(state, rootfield_id)?;
            if !state.work_receipts.contains_key(receipt_id) {
                return Err(DevnetError::WorkReceiptMissing(receipt_id.clone()));
            }
            if state.verifier_reports.contains_key(report_id) {
                return Err(DevnetError::VerifierReportAlreadyExists(report_id.clone()));
            }
            state.verifier_reports.insert(
                report_id.clone(),
                VerifierReport {
                    report_id: report_id.clone(),
                    rootfield_id: rootfield_id.clone(),
                    receipt_id: receipt_id.clone(),
                    verifier_id: verifier_id.clone(),
                    report_digest: report_digest.clone(),
                    status: status.clone(),
                    reason_codes: reason_codes.clone(),
                },
            );
        }
        Transaction::AnchorBatchToBasePlaceholder {
            appchain_chain_id,
            finality_status,
        } => {
            let anchor = anchor_from_state(state, appchain_chain_id, finality_status);
            if state.base_anchors.contains_key(&anchor.anchor_id) {
                return Err(DevnetError::AnchorAlreadyExists(anchor.anchor_id));
            }
            state.base_anchors.insert(anchor.anchor_id.clone(), anchor);
        }
        Transaction::ImportFlowPulseObservation(observation) => {
            if observation.event_signature.to_lowercase() != FLOWPULSE_TOPIC0 {
                return Err(DevnetError::InvalidEventSignature(
                    observation.event_signature.clone(),
                ));
            }
            if state
                .imported_observations
                .contains_key(&observation.observation_id)
            {
                return Err(DevnetError::ImportedObservationAlreadyExists(
                    observation.observation_id.clone(),
                ));
            }
            state
                .imported_observations
                .insert(observation.observation_id.clone(), observation.clone());
        }
        Transaction::ImportVerifierReport(report) => {
            if state
                .imported_verifier_reports
                .contains_key(&report.report_id)
            {
                return Err(DevnetError::ImportedVerifierReportAlreadyExists(
                    report.report_id.clone(),
                ));
            }
            state
                .imported_verifier_reports
                .insert(report.report_id.clone(), report.clone());
        }
    }
    Ok(())
}

pub fn anchor_from_state(
    state: &ChainState,
    appchain_chain_id: &str,
    finality_status: &str,
) -> BaseAnchorPlaceholder {
    let block_range_start = state
        .blocks
        .first()
        .map(|block| block.block_number)
        .unwrap_or(0);
    let block_range_end = state
        .blocks
        .last()
        .map(|block| block.block_number)
        .unwrap_or(0);
    let state_root = state_root(state);
    let work_receipt_root = map_root(
        "flowmemory.local_devnet.work_receipts.v0",
        &state.work_receipts,
    );
    let verifier_report_root = map_root(
        "flowmemory.local_devnet.verifier_reports.v0",
        &state.verifier_reports,
    );
    let rootfield_state_root = map_root("flowmemory.local_devnet.rootfields.v0", &state.rootfields);
    let artifact_commitment_root = map_root(
        "flowmemory.local_devnet.artifact_commitments.v0",
        &state.artifact_commitments,
    );

    let previous_anchor_id = state
        .base_anchors
        .keys()
        .next_back()
        .cloned()
        .unwrap_or_else(|| ZERO_HASH.to_string());

    #[derive(Serialize)]
    #[serde(rename_all = "camelCase")]
    struct AnchorIdInput<'a> {
        schema: &'a str,
        appchain_chain_id: &'a str,
        block_range_start: u64,
        block_range_end: u64,
        state_root: &'a str,
        work_receipt_root: &'a str,
        verifier_report_root: &'a str,
        rootfield_state_root: &'a str,
        artifact_commitment_root: &'a str,
        previous_anchor_id: &'a str,
        finality_status: &'a str,
    }

    let anchor_id = hash_json(
        "flowmemory.local_devnet.base_anchor_placeholder.v0",
        &AnchorIdInput {
            schema: "flowmemory.base_anchor.placeholder.v0",
            appchain_chain_id,
            block_range_start,
            block_range_end,
            state_root: &state_root,
            work_receipt_root: &work_receipt_root,
            verifier_report_root: &verifier_report_root,
            rootfield_state_root: &rootfield_state_root,
            artifact_commitment_root: &artifact_commitment_root,
            previous_anchor_id: &previous_anchor_id,
            finality_status,
        },
    );

    BaseAnchorPlaceholder {
        anchor_id,
        appchain_chain_id: appchain_chain_id.to_string(),
        block_range_start,
        block_range_end,
        state_root,
        work_receipt_root,
        verifier_report_root,
        rootfield_state_root,
        artifact_commitment_root,
        previous_anchor_id,
        finality_status: finality_status.to_string(),
    }
}

pub fn demo_transactions() -> Vec<Transaction> {
    let rootfield_id = "rootfield:demo:alpha".to_string();
    let artifact_commitment = keccak_hex(b"flowmemory.demo.artifact.v0");
    let committed_root = keccak_hex(b"flowmemory.demo.root.v0");
    let receipt_id = "receipt:demo:001".to_string();

    vec![
        Transaction::RegisterRootfield {
            rootfield_id: rootfield_id.clone(),
            owner: "operator:local-demo".to_string(),
            schema_hash: keccak_hex(b"flowmemory.rootfield.schema.v0"),
            metadata_hash: keccak_hex(b"flowmemory.rootfield.metadata.demo"),
        },
        Transaction::SubmitArtifactCommitment {
            artifact_id: "artifact:demo:001".to_string(),
            rootfield_id: rootfield_id.clone(),
            commitment: artifact_commitment.clone(),
            uri_hint: Some("fixture://artifact/demo/001".to_string()),
        },
        Transaction::CommitRoot {
            rootfield_id: rootfield_id.clone(),
            actor: "operator:local-demo".to_string(),
            root: committed_root.clone(),
            artifact_commitment: artifact_commitment.clone(),
        },
        Transaction::SubmitWorkReceipt {
            receipt_id: receipt_id.clone(),
            rootfield_id: rootfield_id.clone(),
            worker_id: "worker:local-demo".to_string(),
            input_root: ZERO_HASH.to_string(),
            output_root: committed_root,
            artifact_commitment,
            rule_set: "flowmemory.work.rule_set.local_demo.v0".to_string(),
        },
        Transaction::SubmitVerifierReport {
            report_id: "report:demo:001".to_string(),
            rootfield_id,
            receipt_id,
            verifier_id: "verifier:local-demo".to_string(),
            report_digest: keccak_hex(b"flowmemory.demo.report.digest.v0"),
            status: "verified".to_string(),
            reason_codes: Vec::new(),
        },
    ]
}

fn ensure_rootfield_exists(state: &ChainState, rootfield_id: &str) -> Result<(), DevnetError> {
    match state.rootfields.get(rootfield_id) {
        Some(rootfield) if rootfield.active => Ok(()),
        Some(_) => Err(DevnetError::RootfieldInactive(rootfield_id.to_string())),
        None => Err(DevnetError::RootfieldMissing(rootfield_id.to_string())),
    }
}
