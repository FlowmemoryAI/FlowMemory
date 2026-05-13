use crate::hash::{hash_json, keccak_hex};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use thiserror::Error;

pub const STATE_SCHEMA: &str = "flowmemory.local_devnet.state.v0";
pub const BLOCK_SCHEMA: &str = "flowmemory.local_devnet.block.v0";
pub const TX_SCHEMA: &str = "flowmemory.local_devnet.tx.v0";
pub const CONFIG_SCHEMA: &str = "flowmemory.local_devnet.config.v0";
pub const OPERATOR_KEY_REFERENCE_SCHEMA: &str = "flowmemory.local_devnet.operator_key_reference.v0";
pub const GENESIS_HASH: &str = "0x0f23c892cbd2d00c10839d97ddab833698a83f8df8d6df27ceac03cfdd4b7bc9";
pub const ZERO_HASH: &str = "0x0000000000000000000000000000000000000000000000000000000000000000";
pub const FLOWPULSE_TOPIC0: &str =
    "0x5d07190b9ae441b4d7b16259a48424acd451492b12f5f99a29f5bfd992c13e43";

#[derive(Debug, Error, PartialEq, Eq)]
pub enum DevnetError {
    #[error("agent already exists: {0}")]
    AgentAlreadyExists(String),
    #[error("agent does not exist: {0}")]
    AgentMissing(String),
    #[error("agent is inactive: {0}")]
    AgentInactive(String),
    #[error("local test-unit balance already exists: {0}")]
    LocalTestUnitBalanceAlreadyExists(String),
    #[error("local test-unit balance does not exist: {0}")]
    LocalTestUnitBalanceMissing(String),
    #[error("local test-unit balance overflow: {0}")]
    LocalTestUnitBalanceOverflow(String),
    #[error("faucet record already exists: {0}")]
    FaucetRecordAlreadyExists(String),
    #[error("faucet amount must be greater than zero: {0}")]
    FaucetAmountMustBePositive(String),
    #[error("model passport already exists: {0}")]
    ModelPassportAlreadyExists(String),
    #[error("model passport does not exist: {0}")]
    ModelPassportMissing(String),
    #[error("memory cell ownership mismatch: {0}")]
    MemoryCellOwnershipMismatch(String),
    #[error("challenge already exists: {0}")]
    ChallengeAlreadyExists(String),
    #[error("challenge does not exist: {0}")]
    ChallengeMissing(String),
    #[error("challenge is already resolved: {0}")]
    ChallengeAlreadyResolved(String),
    #[error("receipt has unresolved challenge: {0}")]
    ChallengeUnresolved(String),
    #[error("rootfield already exists: {0}")]
    RootfieldAlreadyExists(String),
    #[error("rootfield does not exist: {0}")]
    RootfieldMissing(String),
    #[error("rootfield is inactive: {0}")]
    RootfieldInactive(String),
    #[error("artifact commitment already exists: {0}")]
    ArtifactAlreadyExists(String),
    #[error("artifact commitment does not exist: {0}")]
    ArtifactMissing(String),
    #[error("artifact commitment rootfield mismatch: {0}")]
    ArtifactRootfieldMismatch(String),
    #[error("artifact availability proof already exists: {0}")]
    ArtifactAvailabilityAlreadyExists(String),
    #[error("work receipt already exists: {0}")]
    WorkReceiptAlreadyExists(String),
    #[error("work receipt does not exist: {0}")]
    WorkReceiptMissing(String),
    #[error("work receipt belongs to a different rootfield: {0}")]
    WorkReceiptRootfieldMismatch(String),
    #[error("work receipt is not accepted: {0}")]
    WorkReceiptNotAccepted(String),
    #[error("work receipt has failed verifier status: {0}")]
    WorkReceiptFailed(String),
    #[error("work receipt is already finalized: {0}")]
    WorkReceiptAlreadyFinalized(String),
    #[error("invalid finality status: {0}")]
    InvalidFinalityStatus(String),
    #[error("verifier report already exists: {0}")]
    VerifierReportAlreadyExists(String),
    #[error("verifier module already exists: {0}")]
    VerifierModuleAlreadyExists(String),
    #[error("verifier module does not exist: {0}")]
    VerifierModuleMissing(String),
    #[error("verifier module is inactive: {0}")]
    VerifierModuleInactive(String),
    #[error("finality receipt already exists: {0}")]
    FinalityReceiptAlreadyExists(String),
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
    #[serde(default = "default_config")]
    pub config: DevnetConfig,
    pub chain_id: String,
    pub genesis_hash: String,
    pub next_block_number: u64,
    pub logical_time: u64,
    pub parent_hash: String,
    #[serde(default = "default_operator_key_references")]
    pub operator_key_references: BTreeMap<String, OperatorKeyReference>,
    pub rootfields: BTreeMap<String, Rootfield>,
    #[serde(default)]
    pub agent_accounts: BTreeMap<String, AgentAccount>,
    #[serde(default)]
    pub local_test_unit_balances: BTreeMap<String, LocalTestUnitBalance>,
    #[serde(default)]
    pub faucet_records: BTreeMap<String, FaucetRecord>,
    #[serde(default)]
    pub model_passports: BTreeMap<String, ModelPassport>,
    #[serde(default)]
    pub memory_cells: BTreeMap<String, MemoryCell>,
    #[serde(default)]
    pub challenges: BTreeMap<String, Challenge>,
    #[serde(default)]
    pub finality_receipts: BTreeMap<String, FinalityReceipt>,
    pub artifact_commitments: BTreeMap<String, ArtifactCommitment>,
    #[serde(default)]
    pub artifact_availability_proofs: BTreeMap<String, ArtifactAvailabilityProof>,
    #[serde(default)]
    pub verifier_modules: BTreeMap<String, VerifierModule>,
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
pub struct DevnetConfig {
    pub schema: String,
    pub chain_id: String,
    pub network_id: String,
    pub genesis_hash: String,
    pub genesis_logical_time: u64,
    pub block_time_seconds: u64,
    pub operator_key_reference_id: String,
    pub no_value: bool,
    pub consensus: String,
    pub crypto_schema_refs: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct OperatorKeyReference {
    pub schema: String,
    pub key_reference_id: String,
    pub operator_id: String,
    pub worker_key_id: String,
    pub verifier_key_id: String,
    pub verifier_set_root: String,
    pub signature_scheme: String,
    pub public_key_hint: String,
    pub secret_material_boundary: String,
    pub crypto_schema_refs: Vec<String>,
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
pub struct AgentAccount {
    pub agent_id: String,
    pub controller: String,
    pub model_passport_id: Option<String>,
    pub metadata_hash: String,
    pub memory_root: String,
    pub active: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct LocalTestUnitBalance {
    pub account_id: String,
    pub owner: String,
    pub units: u64,
    pub total_faucet_units: u64,
    pub last_faucet_record_id: Option<String>,
    pub updated_at_block: u64,
    pub no_value: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct FaucetRecord {
    pub faucet_record_id: String,
    pub account_id: String,
    pub recipient: String,
    pub amount_units: u64,
    pub reason: String,
    pub credited_at_block: u64,
    pub no_value: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ModelPassport {
    pub model_passport_id: String,
    pub issuer: String,
    pub model_family: String,
    pub model_hash: String,
    pub metadata_hash: String,
    pub active: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct MemoryCell {
    pub memory_cell_id: String,
    pub agent_id: String,
    pub rootfield_id: String,
    pub current_root: String,
    pub parent_root: String,
    pub source_receipt_id: String,
    pub memory_delta_root: String,
    pub status: String,
    pub update_count: u64,
    pub updated_at_block: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct Challenge {
    pub challenge_id: String,
    pub receipt_id: String,
    pub challenger: String,
    pub evidence_hash: String,
    pub reason_code: String,
    pub status: String,
    pub resolution: Option<String>,
    pub opened_at_block: u64,
    pub resolved_at_block: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct FinalityReceipt {
    pub finality_receipt_id: String,
    pub receipt_id: String,
    pub rootfield_id: String,
    pub finalized_by: String,
    pub finality_status: String,
    pub challenge_count: u64,
    pub finalized_at_block: u64,
    pub state_root: String,
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
pub struct ArtifactAvailabilityProof {
    pub proof_id: String,
    pub artifact_id: String,
    pub rootfield_id: String,
    pub commitment: String,
    pub proof_digest: String,
    pub storage_backend: String,
    pub status: String,
    pub checked_at_block: u64,
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
pub struct VerifierModule {
    pub verifier_id: String,
    pub operator: String,
    pub module_hash: String,
    pub rule_set: String,
    pub metadata_hash: String,
    pub active: bool,
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
    #[serde(default)]
    pub operator_key_reference_root: String,
    #[serde(default)]
    pub agent_account_root: String,
    #[serde(default)]
    pub local_test_unit_balance_root: String,
    #[serde(default)]
    pub faucet_record_root: String,
    #[serde(default)]
    pub model_passport_root: String,
    #[serde(default)]
    pub memory_cell_root: String,
    #[serde(default)]
    pub challenge_root: String,
    #[serde(default)]
    pub finality_receipt_root: String,
    #[serde(default)]
    pub artifact_availability_proof_root: String,
    #[serde(default)]
    pub verifier_module_root: String,
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
    RegisterAgent {
        agent_id: String,
        controller: String,
        model_passport_id: Option<String>,
        metadata_hash: String,
    },
    CreateLocalTestUnitBalance {
        account_id: String,
        owner: String,
    },
    FaucetLocalTestUnits {
        faucet_record_id: String,
        account_id: String,
        recipient: String,
        amount_units: u64,
        reason: String,
    },
    RegisterModelPassport {
        model_passport_id: String,
        issuer: String,
        model_family: String,
        model_hash: String,
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
    MarkArtifactAvailability {
        proof_id: String,
        artifact_id: String,
        rootfield_id: String,
        proof_digest: String,
        storage_backend: String,
        status: String,
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
    RegisterVerifierModule {
        verifier_id: String,
        operator: String,
        module_hash: String,
        rule_set: String,
        metadata_hash: String,
    },
    UpdateMemoryCell {
        memory_cell_id: String,
        agent_id: String,
        rootfield_id: String,
        source_receipt_id: String,
        new_root: String,
        memory_delta_root: String,
    },
    OpenChallenge {
        challenge_id: String,
        receipt_id: String,
        challenger: String,
        evidence_hash: String,
        reason_code: String,
    },
    ResolveChallenge {
        challenge_id: String,
        resolver: String,
        resolution: String,
    },
    FinalizeWorkReceipt {
        finality_receipt_id: String,
        receipt_id: String,
        finalized_by: String,
        finality_status: String,
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
    config: &'a DevnetConfig,
    chain_id: &'a str,
    genesis_hash: &'a str,
    operator_key_references: &'a BTreeMap<String, OperatorKeyReference>,
    rootfields: &'a BTreeMap<String, Rootfield>,
    agent_accounts: &'a BTreeMap<String, AgentAccount>,
    local_test_unit_balances: &'a BTreeMap<String, LocalTestUnitBalance>,
    faucet_records: &'a BTreeMap<String, FaucetRecord>,
    model_passports: &'a BTreeMap<String, ModelPassport>,
    memory_cells: &'a BTreeMap<String, MemoryCell>,
    challenges: &'a BTreeMap<String, Challenge>,
    finality_receipts: &'a BTreeMap<String, FinalityReceipt>,
    artifact_commitments: &'a BTreeMap<String, ArtifactCommitment>,
    artifact_availability_proofs: &'a BTreeMap<String, ArtifactAvailabilityProof>,
    verifier_modules: &'a BTreeMap<String, VerifierModule>,
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

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct StateMapRoots {
    pub operator_key_reference_root: String,
    pub rootfield_state_root: String,
    pub agent_account_root: String,
    pub local_test_unit_balance_root: String,
    pub faucet_record_root: String,
    pub model_passport_root: String,
    pub memory_cell_root: String,
    pub challenge_root: String,
    pub finality_receipt_root: String,
    pub artifact_commitment_root: String,
    pub artifact_availability_proof_root: String,
    pub verifier_module_root: String,
    pub work_receipt_root: String,
    pub verifier_report_root: String,
    pub imported_observation_root: String,
    pub imported_verifier_report_root: String,
    pub base_anchor_root: String,
}

pub fn default_config() -> DevnetConfig {
    DevnetConfig {
        schema: CONFIG_SCHEMA.to_string(),
        chain_id: "flowmemory-local-devnet-v0".to_string(),
        network_id: "flowmemory-private-local".to_string(),
        genesis_hash: GENESIS_HASH.to_string(),
        genesis_logical_time: 1_778_688_000,
        block_time_seconds: 1,
        operator_key_reference_id: "operator-key:local-devnet:alpha".to_string(),
        no_value: true,
        consensus: "single-process deterministic local block production".to_string(),
        crypto_schema_refs: vec![
            "crypto/FLOWMEMORY_CRYPTO_SPEC.md#domain-separation".to_string(),
            "crypto/ATTESTATIONS.md#local-signature-helpers".to_string(),
        ],
    }
}

pub fn default_operator_key_references() -> BTreeMap<String, OperatorKeyReference> {
    let reference = OperatorKeyReference {
        schema: OPERATOR_KEY_REFERENCE_SCHEMA.to_string(),
        key_reference_id: "operator-key:local-devnet:alpha".to_string(),
        operator_id: keccak_hex(b"operator:flowmemory-labs-devnet"),
        worker_key_id: keccak_hex(b"worker-key:flowmemory-local-devnet-alpha"),
        verifier_key_id: keccak_hex(b"verifier-key:flowmemory-local-devnet-alpha"),
        verifier_set_root: keccak_hex(b"verifier-set:flowmemory-local-devnet-v0"),
        signature_scheme: "eip712-secp256k1-fixture-digest-only".to_string(),
        public_key_hint: "local fixture boundary; no public key registry is implemented"
            .to_string(),
        secret_material_boundary:
            "no signing secret material is stored in devnet state or handoff output".to_string(),
        crypto_schema_refs: vec![
            "crypto/FLOWMEMORY_CRYPTO_SPEC.md#domain-separation".to_string(),
            "crypto/ATTESTATIONS.md#local-signature-helpers".to_string(),
        ],
    };
    BTreeMap::from([(reference.key_reference_id.clone(), reference)])
}

pub fn genesis_state() -> ChainState {
    let config = default_config();
    ChainState {
        schema: STATE_SCHEMA.to_string(),
        chain_id: config.chain_id.clone(),
        genesis_hash: config.genesis_hash.clone(),
        next_block_number: 1,
        logical_time: config.genesis_logical_time,
        parent_hash: config.genesis_hash.clone(),
        config,
        operator_key_references: default_operator_key_references(),
        rootfields: BTreeMap::new(),
        agent_accounts: BTreeMap::new(),
        local_test_unit_balances: BTreeMap::new(),
        faucet_records: BTreeMap::new(),
        model_passports: BTreeMap::new(),
        memory_cells: BTreeMap::new(),
        challenges: BTreeMap::new(),
        finality_receipts: BTreeMap::new(),
        artifact_commitments: BTreeMap::new(),
        artifact_availability_proofs: BTreeMap::new(),
        verifier_modules: BTreeMap::new(),
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
        config: &state.config,
        chain_id: &state.chain_id,
        genesis_hash: &state.genesis_hash,
        operator_key_references: &state.operator_key_references,
        rootfields: &state.rootfields,
        agent_accounts: &state.agent_accounts,
        local_test_unit_balances: &state.local_test_unit_balances,
        faucet_records: &state.faucet_records,
        model_passports: &state.model_passports,
        memory_cells: &state.memory_cells,
        challenges: &state.challenges,
        finality_receipts: &state.finality_receipts,
        artifact_commitments: &state.artifact_commitments,
        artifact_availability_proofs: &state.artifact_availability_proofs,
        verifier_modules: &state.verifier_modules,
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

pub fn state_map_roots(state: &ChainState) -> StateMapRoots {
    StateMapRoots {
        operator_key_reference_root: map_root(
            "flowmemory.local_devnet.operator_key_references.v0",
            &state.operator_key_references,
        ),
        rootfield_state_root: map_root("flowmemory.local_devnet.rootfields.v0", &state.rootfields),
        agent_account_root: map_root(
            "flowmemory.local_devnet.agent_accounts.v0",
            &state.agent_accounts,
        ),
        local_test_unit_balance_root: map_root(
            "flowmemory.local_devnet.local_test_unit_balances.v0",
            &state.local_test_unit_balances,
        ),
        faucet_record_root: map_root(
            "flowmemory.local_devnet.faucet_records.v0",
            &state.faucet_records,
        ),
        model_passport_root: map_root(
            "flowmemory.local_devnet.model_passports.v0",
            &state.model_passports,
        ),
        memory_cell_root: map_root(
            "flowmemory.local_devnet.memory_cells.v0",
            &state.memory_cells,
        ),
        challenge_root: map_root("flowmemory.local_devnet.challenges.v0", &state.challenges),
        finality_receipt_root: map_root(
            "flowmemory.local_devnet.finality_receipts.v0",
            &state.finality_receipts,
        ),
        artifact_commitment_root: map_root(
            "flowmemory.local_devnet.artifact_commitments.v0",
            &state.artifact_commitments,
        ),
        artifact_availability_proof_root: map_root(
            "flowmemory.local_devnet.artifact_availability_proofs.v0",
            &state.artifact_availability_proofs,
        ),
        verifier_module_root: map_root(
            "flowmemory.local_devnet.verifier_modules.v0",
            &state.verifier_modules,
        ),
        work_receipt_root: map_root(
            "flowmemory.local_devnet.work_receipts.v0",
            &state.work_receipts,
        ),
        verifier_report_root: map_root(
            "flowmemory.local_devnet.verifier_reports.v0",
            &state.verifier_reports,
        ),
        imported_observation_root: map_root(
            "flowmemory.local_devnet.imported_observations.v0",
            &state.imported_observations,
        ),
        imported_verifier_report_root: map_root(
            "flowmemory.local_devnet.imported_verifier_reports.v0",
            &state.imported_verifier_reports,
        ),
        base_anchor_root: map_root(
            "flowmemory.local_devnet.base_anchors.v0",
            &state.base_anchors,
        ),
    }
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
        Transaction::RegisterAgent {
            agent_id,
            controller,
            model_passport_id,
            metadata_hash,
        } => {
            if state.agent_accounts.contains_key(agent_id) {
                return Err(DevnetError::AgentAlreadyExists(agent_id.clone()));
            }
            if let Some(model_passport_id) = model_passport_id
                && !state.model_passports.contains_key(model_passport_id)
            {
                return Err(DevnetError::ModelPassportMissing(model_passport_id.clone()));
            }
            state.agent_accounts.insert(
                agent_id.clone(),
                AgentAccount {
                    agent_id: agent_id.clone(),
                    controller: controller.clone(),
                    model_passport_id: model_passport_id.clone(),
                    metadata_hash: metadata_hash.clone(),
                    memory_root: ZERO_HASH.to_string(),
                    active: true,
                },
            );
        }
        Transaction::CreateLocalTestUnitBalance { account_id, owner } => {
            if state.local_test_unit_balances.contains_key(account_id) {
                return Err(DevnetError::LocalTestUnitBalanceAlreadyExists(
                    account_id.clone(),
                ));
            }
            state.local_test_unit_balances.insert(
                account_id.clone(),
                LocalTestUnitBalance {
                    account_id: account_id.clone(),
                    owner: owner.clone(),
                    units: 0,
                    total_faucet_units: 0,
                    last_faucet_record_id: None,
                    updated_at_block: state.next_block_number,
                    no_value: true,
                },
            );
        }
        Transaction::FaucetLocalTestUnits {
            faucet_record_id,
            account_id,
            recipient,
            amount_units,
            reason,
        } => {
            if *amount_units == 0 {
                return Err(DevnetError::FaucetAmountMustBePositive(
                    faucet_record_id.clone(),
                ));
            }
            if state.faucet_records.contains_key(faucet_record_id) {
                return Err(DevnetError::FaucetRecordAlreadyExists(
                    faucet_record_id.clone(),
                ));
            }
            let balance = state
                .local_test_unit_balances
                .get_mut(account_id)
                .ok_or_else(|| DevnetError::LocalTestUnitBalanceMissing(account_id.clone()))?;
            balance.units = balance
                .units
                .checked_add(*amount_units)
                .ok_or_else(|| DevnetError::LocalTestUnitBalanceOverflow(account_id.clone()))?;
            balance.total_faucet_units = balance
                .total_faucet_units
                .checked_add(*amount_units)
                .ok_or_else(|| DevnetError::LocalTestUnitBalanceOverflow(account_id.clone()))?;
            balance.last_faucet_record_id = Some(faucet_record_id.clone());
            balance.updated_at_block = state.next_block_number;
            state.faucet_records.insert(
                faucet_record_id.clone(),
                FaucetRecord {
                    faucet_record_id: faucet_record_id.clone(),
                    account_id: account_id.clone(),
                    recipient: recipient.clone(),
                    amount_units: *amount_units,
                    reason: reason.clone(),
                    credited_at_block: state.next_block_number,
                    no_value: true,
                },
            );
        }
        Transaction::RegisterModelPassport {
            model_passport_id,
            issuer,
            model_family,
            model_hash,
            metadata_hash,
        } => {
            if state.model_passports.contains_key(model_passport_id) {
                return Err(DevnetError::ModelPassportAlreadyExists(
                    model_passport_id.clone(),
                ));
            }
            state.model_passports.insert(
                model_passport_id.clone(),
                ModelPassport {
                    model_passport_id: model_passport_id.clone(),
                    issuer: issuer.clone(),
                    model_family: model_family.clone(),
                    model_hash: model_hash.clone(),
                    metadata_hash: metadata_hash.clone(),
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
        Transaction::MarkArtifactAvailability {
            proof_id,
            artifact_id,
            rootfield_id,
            proof_digest,
            storage_backend,
            status,
        } => {
            ensure_rootfield_exists(state, rootfield_id)?;
            if state.artifact_availability_proofs.contains_key(proof_id) {
                return Err(DevnetError::ArtifactAvailabilityAlreadyExists(
                    proof_id.clone(),
                ));
            }
            let artifact = state
                .artifact_commitments
                .get(artifact_id)
                .ok_or_else(|| DevnetError::ArtifactMissing(artifact_id.clone()))?;
            if artifact.rootfield_id != rootfield_id.as_str() {
                return Err(DevnetError::ArtifactRootfieldMismatch(artifact_id.clone()));
            }
            let commitment = artifact.commitment.clone();
            state.artifact_availability_proofs.insert(
                proof_id.clone(),
                ArtifactAvailabilityProof {
                    proof_id: proof_id.clone(),
                    artifact_id: artifact_id.clone(),
                    rootfield_id: rootfield_id.clone(),
                    commitment,
                    proof_digest: proof_digest.clone(),
                    storage_backend: storage_backend.clone(),
                    status: status.clone(),
                    checked_at_block: state.next_block_number,
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
            if !state.artifact_commitments.values().any(|artifact| {
                artifact.rootfield_id == rootfield_id.as_str()
                    && artifact.commitment == artifact_commitment.as_str()
            }) {
                return Err(DevnetError::ArtifactMissing(artifact_commitment.clone()));
            }
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
            ensure_verifier_module_active(state, verifier_id)?;
            let receipt = state
                .work_receipts
                .get(receipt_id)
                .ok_or_else(|| DevnetError::WorkReceiptMissing(receipt_id.clone()))?;
            if receipt.rootfield_id != rootfield_id.as_str() {
                return Err(DevnetError::WorkReceiptRootfieldMismatch(
                    receipt_id.clone(),
                ));
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
        Transaction::RegisterVerifierModule {
            verifier_id,
            operator,
            module_hash,
            rule_set,
            metadata_hash,
        } => {
            if state.verifier_modules.contains_key(verifier_id) {
                return Err(DevnetError::VerifierModuleAlreadyExists(
                    verifier_id.clone(),
                ));
            }
            state.verifier_modules.insert(
                verifier_id.clone(),
                VerifierModule {
                    verifier_id: verifier_id.clone(),
                    operator: operator.clone(),
                    module_hash: module_hash.clone(),
                    rule_set: rule_set.clone(),
                    metadata_hash: metadata_hash.clone(),
                    active: true,
                },
            );
        }
        Transaction::UpdateMemoryCell {
            memory_cell_id,
            agent_id,
            rootfield_id,
            source_receipt_id,
            new_root,
            memory_delta_root,
        } => {
            ensure_rootfield_exists(state, rootfield_id)?;
            ensure_agent_active(state, agent_id)?;
            ensure_receipt_accepted(state, source_receipt_id, rootfield_id)?;

            let (parent_root, update_count) =
                if let Some(memory_cell) = state.memory_cells.get(memory_cell_id) {
                    if memory_cell.agent_id != agent_id.as_str()
                        || memory_cell.rootfield_id != rootfield_id.as_str()
                    {
                        return Err(DevnetError::MemoryCellOwnershipMismatch(
                            memory_cell_id.clone(),
                        ));
                    }
                    (
                        memory_cell.current_root.clone(),
                        memory_cell.update_count + 1,
                    )
                } else {
                    (ZERO_HASH.to_string(), 1)
                };

            state.memory_cells.insert(
                memory_cell_id.clone(),
                MemoryCell {
                    memory_cell_id: memory_cell_id.clone(),
                    agent_id: agent_id.clone(),
                    rootfield_id: rootfield_id.clone(),
                    current_root: new_root.clone(),
                    parent_root,
                    source_receipt_id: source_receipt_id.clone(),
                    memory_delta_root: memory_delta_root.clone(),
                    status: "active".to_string(),
                    update_count,
                    updated_at_block: state.next_block_number,
                },
            );
            if let Some(agent) = state.agent_accounts.get_mut(agent_id) {
                agent.memory_root = new_root.clone();
            }
        }
        Transaction::OpenChallenge {
            challenge_id,
            receipt_id,
            challenger,
            evidence_hash,
            reason_code,
        } => {
            if state.challenges.contains_key(challenge_id) {
                return Err(DevnetError::ChallengeAlreadyExists(challenge_id.clone()));
            }
            if !state.work_receipts.contains_key(receipt_id) {
                return Err(DevnetError::WorkReceiptMissing(receipt_id.clone()));
            }
            if state
                .finality_receipts
                .values()
                .any(|receipt| receipt.receipt_id == receipt_id.as_str())
            {
                return Err(DevnetError::WorkReceiptAlreadyFinalized(receipt_id.clone()));
            }
            state.challenges.insert(
                challenge_id.clone(),
                Challenge {
                    challenge_id: challenge_id.clone(),
                    receipt_id: receipt_id.clone(),
                    challenger: challenger.clone(),
                    evidence_hash: evidence_hash.clone(),
                    reason_code: reason_code.clone(),
                    status: "open".to_string(),
                    resolution: None,
                    opened_at_block: state.next_block_number,
                    resolved_at_block: None,
                },
            );
        }
        Transaction::ResolveChallenge {
            challenge_id,
            resolver: _,
            resolution,
        } => {
            let challenge = state
                .challenges
                .get_mut(challenge_id)
                .ok_or_else(|| DevnetError::ChallengeMissing(challenge_id.clone()))?;
            if challenge.status != "open" {
                return Err(DevnetError::ChallengeAlreadyResolved(challenge_id.clone()));
            }
            challenge.status = "resolved".to_string();
            challenge.resolution = Some(resolution.clone());
            challenge.resolved_at_block = Some(state.next_block_number);
        }
        Transaction::FinalizeWorkReceipt {
            finality_receipt_id,
            receipt_id,
            finalized_by,
            finality_status,
        } => {
            if !is_valid_finality_status(finality_status) {
                return Err(DevnetError::InvalidFinalityStatus(finality_status.clone()));
            }
            if state.finality_receipts.contains_key(finality_receipt_id) {
                return Err(DevnetError::FinalityReceiptAlreadyExists(
                    finality_receipt_id.clone(),
                ));
            }
            let receipt = ensure_receipt_accepted_for_any_rootfield(state, receipt_id)?;
            let rootfield_id = receipt.rootfield_id.clone();
            if state.challenges.values().any(|challenge| {
                challenge.receipt_id == receipt_id.as_str() && challenge.status == "open"
            }) {
                return Err(DevnetError::ChallengeUnresolved(receipt_id.clone()));
            }
            if state
                .finality_receipts
                .values()
                .any(|receipt| receipt.receipt_id == receipt_id.as_str())
            {
                return Err(DevnetError::WorkReceiptAlreadyFinalized(receipt_id.clone()));
            }
            let challenge_count = state
                .challenges
                .values()
                .filter(|challenge| challenge.receipt_id == receipt_id.as_str())
                .count() as u64;
            let finality_state_root = state_root(state);
            state.finality_receipts.insert(
                finality_receipt_id.clone(),
                FinalityReceipt {
                    finality_receipt_id: finality_receipt_id.clone(),
                    receipt_id: receipt_id.clone(),
                    rootfield_id,
                    finalized_by: finalized_by.clone(),
                    finality_status: finality_status.clone(),
                    challenge_count,
                    finalized_at_block: state.next_block_number,
                    state_root: finality_state_root,
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
    let roots = state_map_roots(state);

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
        operator_key_reference_root: &'a str,
        agent_account_root: &'a str,
        local_test_unit_balance_root: &'a str,
        faucet_record_root: &'a str,
        model_passport_root: &'a str,
        memory_cell_root: &'a str,
        challenge_root: &'a str,
        finality_receipt_root: &'a str,
        artifact_availability_proof_root: &'a str,
        verifier_module_root: &'a str,
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
            work_receipt_root: &roots.work_receipt_root,
            verifier_report_root: &roots.verifier_report_root,
            rootfield_state_root: &roots.rootfield_state_root,
            artifact_commitment_root: &roots.artifact_commitment_root,
            operator_key_reference_root: &roots.operator_key_reference_root,
            agent_account_root: &roots.agent_account_root,
            local_test_unit_balance_root: &roots.local_test_unit_balance_root,
            faucet_record_root: &roots.faucet_record_root,
            model_passport_root: &roots.model_passport_root,
            memory_cell_root: &roots.memory_cell_root,
            challenge_root: &roots.challenge_root,
            finality_receipt_root: &roots.finality_receipt_root,
            artifact_availability_proof_root: &roots.artifact_availability_proof_root,
            verifier_module_root: &roots.verifier_module_root,
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
        work_receipt_root: roots.work_receipt_root,
        verifier_report_root: roots.verifier_report_root,
        rootfield_state_root: roots.rootfield_state_root,
        artifact_commitment_root: roots.artifact_commitment_root,
        operator_key_reference_root: roots.operator_key_reference_root,
        agent_account_root: roots.agent_account_root,
        local_test_unit_balance_root: roots.local_test_unit_balance_root,
        faucet_record_root: roots.faucet_record_root,
        model_passport_root: roots.model_passport_root,
        memory_cell_root: roots.memory_cell_root,
        challenge_root: roots.challenge_root,
        finality_receipt_root: roots.finality_receipt_root,
        artifact_availability_proof_root: roots.artifact_availability_proof_root,
        verifier_module_root: roots.verifier_module_root,
        previous_anchor_id,
        finality_status: finality_status.to_string(),
    }
}

pub fn demo_transactions() -> Vec<Transaction> {
    let rootfield_id = "rootfield:demo:alpha".to_string();
    let model_passport_id = "model:demo:local-alpha".to_string();
    let agent_id = "agent:demo:alpha".to_string();
    let local_balance_account_id = "local-balance:demo:agent-alpha".to_string();
    let verifier_id = "verifier:local-demo".to_string();
    let artifact_id = "artifact:demo:001".to_string();
    let artifact_commitment = keccak_hex(b"flowmemory.demo.artifact.v0");
    let committed_root = keccak_hex(b"flowmemory.demo.root.v0");
    let memory_root = keccak_hex(b"flowmemory.demo.memory.root.v0");
    let memory_delta_root = keccak_hex(b"flowmemory.demo.memory.delta.v0");
    let receipt_id = "receipt:demo:001".to_string();

    vec![
        Transaction::RegisterRootfield {
            rootfield_id: rootfield_id.clone(),
            owner: "operator:local-demo".to_string(),
            schema_hash: keccak_hex(b"flowmemory.rootfield.schema.v0"),
            metadata_hash: keccak_hex(b"flowmemory.rootfield.metadata.demo"),
        },
        Transaction::RegisterModelPassport {
            model_passport_id: model_passport_id.clone(),
            issuer: "operator:local-demo".to_string(),
            model_family: "local-alpha-fixture-model".to_string(),
            model_hash: keccak_hex(b"flowmemory.demo.model.local-alpha"),
            metadata_hash: keccak_hex(b"flowmemory.demo.model.metadata"),
        },
        Transaction::RegisterAgent {
            agent_id: agent_id.clone(),
            controller: "operator:local-demo".to_string(),
            model_passport_id: Some(model_passport_id),
            metadata_hash: keccak_hex(b"flowmemory.demo.agent.metadata"),
        },
        Transaction::CreateLocalTestUnitBalance {
            account_id: local_balance_account_id.clone(),
            owner: agent_id.clone(),
        },
        Transaction::FaucetLocalTestUnits {
            faucet_record_id: "faucet:demo:001".to_string(),
            account_id: local_balance_account_id,
            recipient: agent_id.clone(),
            amount_units: 1_000,
            reason: "local-smoke-no-value-test-units".to_string(),
        },
        Transaction::RegisterVerifierModule {
            verifier_id: verifier_id.clone(),
            operator: "operator:local-demo".to_string(),
            module_hash: keccak_hex(b"flowmemory.demo.verifier.module"),
            rule_set: "flowmemory.work.rule_set.local_demo.v0".to_string(),
            metadata_hash: keccak_hex(b"flowmemory.demo.verifier.metadata"),
        },
        Transaction::SubmitArtifactCommitment {
            artifact_id: artifact_id.clone(),
            rootfield_id: rootfield_id.clone(),
            commitment: artifact_commitment.clone(),
            uri_hint: Some("fixture://artifact/demo/001".to_string()),
        },
        Transaction::MarkArtifactAvailability {
            proof_id: "availability:demo:001".to_string(),
            artifact_id: artifact_id.clone(),
            rootfield_id: rootfield_id.clone(),
            proof_digest: keccak_hex(b"flowmemory.demo.artifact.availability"),
            storage_backend: "fixture-local".to_string(),
            status: "available".to_string(),
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
            rootfield_id: rootfield_id.clone(),
            receipt_id: receipt_id.clone(),
            verifier_id,
            report_digest: keccak_hex(b"flowmemory.demo.report.digest.v0"),
            status: "verified".to_string(),
            reason_codes: Vec::new(),
        },
        Transaction::UpdateMemoryCell {
            memory_cell_id: "memory:demo:agent-alpha:core".to_string(),
            agent_id,
            rootfield_id,
            source_receipt_id: receipt_id.clone(),
            new_root: memory_root,
            memory_delta_root,
        },
        Transaction::OpenChallenge {
            challenge_id: "challenge:demo:001".to_string(),
            receipt_id: receipt_id.clone(),
            challenger: "reviewer:local-demo".to_string(),
            evidence_hash: keccak_hex(b"flowmemory.demo.challenge.evidence"),
            reason_code: "local-review".to_string(),
        },
        Transaction::ResolveChallenge {
            challenge_id: "challenge:demo:001".to_string(),
            resolver: "verifier:local-demo".to_string(),
            resolution: "dismissed".to_string(),
        },
        Transaction::FinalizeWorkReceipt {
            finality_receipt_id: "finality:demo:001".to_string(),
            receipt_id,
            finalized_by: "operator:local-demo".to_string(),
            finality_status: "finalized".to_string(),
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

fn ensure_agent_active(state: &ChainState, agent_id: &str) -> Result<(), DevnetError> {
    match state.agent_accounts.get(agent_id) {
        Some(agent) if agent.active => Ok(()),
        Some(_) => Err(DevnetError::AgentInactive(agent_id.to_string())),
        None => Err(DevnetError::AgentMissing(agent_id.to_string())),
    }
}

fn ensure_verifier_module_active(state: &ChainState, verifier_id: &str) -> Result<(), DevnetError> {
    match state.verifier_modules.get(verifier_id) {
        Some(verifier) if verifier.active => Ok(()),
        Some(_) => Err(DevnetError::VerifierModuleInactive(verifier_id.to_string())),
        None => Err(DevnetError::VerifierModuleMissing(verifier_id.to_string())),
    }
}

fn ensure_receipt_accepted<'a>(
    state: &'a ChainState,
    receipt_id: &str,
    rootfield_id: &str,
) -> Result<&'a WorkReceipt, DevnetError> {
    let receipt = state
        .work_receipts
        .get(receipt_id)
        .ok_or_else(|| DevnetError::WorkReceiptMissing(receipt_id.to_string()))?;
    if receipt.rootfield_id != rootfield_id {
        return Err(DevnetError::WorkReceiptRootfieldMismatch(
            receipt_id.to_string(),
        ));
    }
    ensure_receipt_status_accepted(state, receipt_id)?;
    Ok(receipt)
}

fn ensure_receipt_accepted_for_any_rootfield<'a>(
    state: &'a ChainState,
    receipt_id: &str,
) -> Result<&'a WorkReceipt, DevnetError> {
    let receipt = state
        .work_receipts
        .get(receipt_id)
        .ok_or_else(|| DevnetError::WorkReceiptMissing(receipt_id.to_string()))?;
    ensure_receipt_status_accepted(state, receipt_id)?;
    Ok(receipt)
}

fn ensure_receipt_status_accepted(state: &ChainState, receipt_id: &str) -> Result<(), DevnetError> {
    if state
        .verifier_reports
        .values()
        .any(|report| report.receipt_id == receipt_id && is_failed_status(&report.status))
    {
        return Err(DevnetError::WorkReceiptFailed(receipt_id.to_string()));
    }
    if state
        .verifier_reports
        .values()
        .any(|report| report.receipt_id == receipt_id && is_accepted_status(&report.status))
    {
        return Ok(());
    }
    Err(DevnetError::WorkReceiptNotAccepted(receipt_id.to_string()))
}

fn is_accepted_status(status: &str) -> bool {
    matches!(
        status.to_ascii_lowercase().as_str(),
        "accepted" | "verified"
    )
}

fn is_failed_status(status: &str) -> bool {
    matches!(
        status.to_ascii_lowercase().as_str(),
        "failed" | "invalid" | "rejected" | "unsupported" | "reorged"
    )
}

fn is_valid_finality_status(status: &str) -> bool {
    matches!(
        status.to_ascii_lowercase().as_str(),
        "finalized" | "local-finalized"
    )
}
