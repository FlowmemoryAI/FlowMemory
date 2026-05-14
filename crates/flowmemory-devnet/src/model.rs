use crate::hash::{hash_json, keccak_hex};
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};
use thiserror::Error;

pub const STATE_SCHEMA: &str = "flowmemory.local_devnet.state.v0";
pub const BLOCK_SCHEMA: &str = "flowmemory.local_devnet.block.v0";
pub const TX_SCHEMA: &str = "flowmemory.local_devnet.tx.v0";
pub const CONFIG_SCHEMA: &str = "flowmemory.local_devnet.config.v0";
pub const OPERATOR_KEY_REFERENCE_SCHEMA: &str = "flowmemory.local_devnet.operator_key_reference.v0";
pub const VALIDATOR_IDENTITY_SCHEMA: &str = "flowmemory.local_devnet.validator_identity.v0";
pub const AUTHORITY_SET_SCHEMA: &str = "flowmemory.local_devnet.authority_set.v0";
pub const CONSENSUS_STATE_SCHEMA: &str = "flowmemory.local_devnet.consensus_state.v0";
pub const CHAIN_FINALITY_RECEIPT_SCHEMA: &str = "flowmemory.local_devnet.chain_finality_receipt.v0";
pub const FINALITY_CERTIFICATE_SCHEMA: &str = "flowmemory.local_devnet.finality_certificate.v0";
pub const MISBEHAVIOR_EVIDENCE_SCHEMA: &str = "flowmemory.local_devnet.misbehavior_evidence.v0";
pub const FORK_EVIDENCE_SCHEMA: &str = "flowmemory.local_devnet.fork_evidence.v0";
pub const AUTHORITY_PROOF_SCHEMA: &str = "flowmemory.local_devnet.authority_proof.v0";
pub const BRIDGE_REPLAY_KEY_SCHEMA: &str = "flowmemory.local_devnet.bridge_replay_key.v0";
pub const BRIDGE_CREDIT_SCHEMA: &str = "flowmemory.local_devnet.bridge_credit.v0";
pub const BRIDGE_LIFECYCLE_EVIDENCE_SCHEMA: &str =
    "flowmemory.local_devnet.bridge_lifecycle_evidence.v0";
pub const GENESIS_HASH: &str = "0x0f23c892cbd2d00c10839d97ddab833698a83f8df8d6df27ceac03cfdd4b7bc9";
pub const ZERO_HASH: &str = "0x0000000000000000000000000000000000000000000000000000000000000000";
pub const FLOWPULSE_TOPIC0: &str =
    "0x5d07190b9ae441b4d7b16259a48424acd451492b12f5f99a29f5bfd992c13e43";
pub const LOCAL_TEST_UNIT_ASSET_ID: &str = "asset:flowchain-local-test-unit";
pub const LOCAL_PRIVATE_VALIDATOR_ID: &str = "validator:local-private:alpha";
pub const LOCAL_PRIVATE_AUTHORITY_SET_ID: &str = "authority-set:flowmemory-local-private-v0";

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
    #[error("insufficient local test-unit balance: {0}")]
    LocalTestUnitBalanceInsufficient(String),
    #[error("faucet record already exists: {0}")]
    FaucetRecordAlreadyExists(String),
    #[error("faucet amount must be greater than zero: {0}")]
    FaucetAmountMustBePositive(String),
    #[error("balance transfer already exists: {0}")]
    BalanceTransferAlreadyExists(String),
    #[error("deterministic {kind} id mismatch: expected {expected}, got {actual}")]
    DeterministicIdMismatch {
        kind: String,
        expected: String,
        actual: String,
    },
    #[error("token already exists: {0}")]
    TokenAlreadyExists(String),
    #[error("token symbol already exists: {0}")]
    TokenSymbolAlreadyExists(String),
    #[error("token does not exist: {0}")]
    TokenMissing(String),
    #[error("token amount must be greater than zero: {0}")]
    TokenAmountMustBePositive(String),
    #[error("token balance overflow: {0}")]
    TokenBalanceOverflow(String),
    #[error("insufficient token balance: {0}")]
    TokenBalanceInsufficient(String),
    #[error("token mint already exists: {0}")]
    TokenMintAlreadyExists(String),
    #[error("pool already exists: {0}")]
    PoolAlreadyExists(String),
    #[error("pool does not exist: {0}")]
    PoolMissing(String),
    #[error("pool asset is invalid: {0}")]
    PoolInvalidAsset(String),
    #[error("pool reserves are insufficient: {0}")]
    PoolReserveInsufficient(String),
    #[error("pool reserve overflow: {0}")]
    PoolReserveOverflow(String),
    #[error("liquidity receipt already exists: {0}")]
    LiquidityReceiptAlreadyExists(String),
    #[error("liquidity amount is below minimum: {0}")]
    LiquidityBelowMinimum(String),
    #[error("LP position does not exist: {0}")]
    LpPositionMissing(String),
    #[error("insufficient LP position: {0}")]
    LpPositionInsufficient(String),
    #[error("swap receipt already exists: {0}")]
    SwapReceiptAlreadyExists(String),
    #[error("swap output is below minimum: {0}")]
    SwapSlippageExceeded(String),
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
    #[error("duplicate transaction id in block: {0}")]
    DuplicateTransaction(String),
    #[error("bridge replay key already used: {0}")]
    BridgeReplayKeyAlreadyUsed(String),
    #[error("bridge credit amount must be greater than zero: {0}")]
    BridgeCreditAmountMustBePositive(String),
    #[error("bridge credit already exists: {0}")]
    BridgeCreditAlreadyExists(String),
    #[error("bridge credit does not exist: {0}")]
    BridgeCreditMissing(String),
    #[error("bridge finality receipt does not exist: {0}")]
    BridgeFinalityReceiptMissing(String),
    #[error("bridge credit is not final under the supplied receipt: {0}")]
    BridgeCreditNotFinal(String),
    #[error("bridge spend reference is invalid: {0}")]
    BridgeSpendReferenceInvalid(String),
}

#[derive(Debug, Error, Clone, PartialEq, Eq)]
pub enum ConsensusValidationError {
    #[error("wrong chain id: expected {expected}, got {actual}")]
    WrongChainId { expected: String, actual: String },
    #[error("wrong genesis hash: expected {expected}, got {actual}")]
    WrongGenesisHash { expected: String, actual: String },
    #[error("invalid parent: expected {expected}, got {actual}")]
    InvalidParent { expected: String, actual: String },
    #[error("invalid height: expected {expected}, got {actual}")]
    InvalidHeight { expected: u64, actual: u64 },
    #[error("timestamp out of bounds: min {min}, max {max}, got {actual}")]
    TimestampOutOfBounds { min: u64, max: u64, actual: u64 },
    #[error("invalid proposer: {0}")]
    InvalidProposer(String),
    #[error("invalid authority proof: {0}")]
    InvalidAuthorityProof(String),
    #[error("transaction ids are not sorted deterministically")]
    TransactionOrdering,
    #[error("duplicate transaction id in block: {0}")]
    DuplicateTransaction(String),
    #[error("{root_name} mismatch: expected {expected}, got {actual}")]
    RootMismatch {
        root_name: String,
        expected: String,
        actual: String,
    },
    #[error("block hash mismatch: expected {expected}, got {actual}")]
    BlockHashMismatch { expected: String, actual: String },
    #[error("unknown parent: {0}")]
    UnknownParent(String),
    #[error("stale block height {0}")]
    StaleBlock(u64),
    #[error("block conflicts with finalized height {height} hash {finalized_hash}")]
    FinalizedConflict { height: u64, finalized_hash: String },
    #[error("missing finality receipt for block {block_height} hash {block_hash}")]
    MissingFinalityReceipt {
        block_height: u64,
        block_hash: String,
    },
    #[error("duplicate finality receipt for block {block_height} hash {block_hash}")]
    DuplicateFinalityReceipt {
        block_height: u64,
        block_hash: String,
    },
    #[error("finality receipt mismatch: {0}")]
    FinalityReceiptMismatch(String),
    #[error("bridge credit does not exist: {0}")]
    BridgeCreditMissing(String),
    #[error("bridge spend reference is invalid: {0}")]
    BridgeSpendReferenceInvalid(String),
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
    #[serde(default = "default_validator_set")]
    pub validator_set: BTreeMap<String, ValidatorIdentity>,
    #[serde(default = "default_authority_set")]
    pub authority_set: AuthoritySet,
    #[serde(default = "default_consensus_state")]
    pub consensus_state: ConsensusState,
    #[serde(default)]
    pub chain_finality_receipts: BTreeMap<String, ConsensusFinalityReceipt>,
    #[serde(default)]
    pub fork_evidence: Vec<ForkEvidence>,
    #[serde(default)]
    pub misbehavior_evidence: Vec<MisbehaviorEvidence>,
    pub rootfields: BTreeMap<String, Rootfield>,
    #[serde(default)]
    pub agent_accounts: BTreeMap<String, AgentAccount>,
    #[serde(default)]
    pub local_test_unit_balances: BTreeMap<String, LocalTestUnitBalance>,
    #[serde(default)]
    pub faucet_records: BTreeMap<String, FaucetRecord>,
    #[serde(default)]
    pub balance_transfers: BTreeMap<String, BalanceTransfer>,
    #[serde(default)]
    pub token_definitions: BTreeMap<String, LocalTestToken>,
    #[serde(default)]
    pub token_balances: BTreeMap<String, LocalTestTokenBalance>,
    #[serde(default)]
    pub token_mint_receipts: BTreeMap<String, LocalTestTokenMintReceipt>,
    #[serde(default)]
    pub dex_pools: BTreeMap<String, DexPool>,
    #[serde(default)]
    pub lp_positions: BTreeMap<String, LpPosition>,
    #[serde(default)]
    pub liquidity_receipts: BTreeMap<String, LiquidityReceipt>,
    #[serde(default)]
    pub swap_receipts: BTreeMap<String, SwapReceipt>,
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
    #[serde(default)]
    pub bridge_replay_keys: BTreeMap<String, BridgeReplayKeyRecord>,
    #[serde(default)]
    pub bridge_credits: BTreeMap<String, BridgeCreditRecord>,
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
pub struct ValidatorIdentity {
    pub schema: String,
    pub validator_id: String,
    pub account_ref: String,
    pub consensus_public_key: String,
    pub consensus_key_id: String,
    pub roles: Vec<String>,
    pub weight: u64,
    pub active: bool,
    pub key_scope: String,
    pub bridge_key_separation: String,
    pub wallet_key_separation: String,
    pub public_metadata: ValidatorPublicMetadata,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ValidatorPublicMetadata {
    pub display_name: String,
    pub operator_ref: String,
    pub network_profile: String,
    pub dashboard_safe: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct AuthoritySet {
    pub schema: String,
    pub authority_set_id: String,
    pub chain_id: String,
    pub genesis_hash: String,
    pub profile: String,
    pub validators: Vec<String>,
    pub proposer_schedule: Vec<String>,
    pub total_weight: u64,
    pub quorum_weight: u64,
    pub public_metadata_export: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ConsensusState {
    pub schema: String,
    pub profile: String,
    pub finality_rule: String,
    pub canonical_height: u64,
    pub canonical_head_hash: String,
    pub canonical_state_root: String,
    pub finalized_height: u64,
    pub finalized_hash: String,
    pub finalized_state_root: String,
    pub finalized_at_logical_time: u64,
    pub latest_finality_receipt_id: Option<String>,
    pub consensus_state_output_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct FinalityCertificate {
    pub schema: String,
    pub certificate_id: String,
    pub chain_id: String,
    pub genesis_hash: String,
    pub authority_set_id: String,
    pub block_height: u64,
    pub block_hash: String,
    pub state_root: String,
    pub signer_ids: Vec<String>,
    pub quorum_weight: u64,
    pub total_weight: u64,
    pub profile: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ConsensusFinalityReceipt {
    pub schema: String,
    pub finality_receipt_id: String,
    pub chain_id: String,
    pub genesis_hash: String,
    pub authority_set_id: String,
    pub finalized_height: u64,
    pub finalized_block_hash: String,
    pub finalized_state_root: String,
    pub canonical_head_hash: String,
    pub canonical_height: u64,
    pub finality_rule: String,
    pub certificate: FinalityCertificate,
    pub produced_at_logical_time: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct MisbehaviorEvidence {
    pub schema: String,
    pub evidence_id: String,
    pub kind: String,
    pub block_hash: String,
    pub block_height: u64,
    pub proposer_id: String,
    pub detail: String,
    pub observed_at_logical_time: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ForkEvidence {
    pub schema: String,
    pub evidence_id: String,
    pub kind: String,
    pub block_hash: String,
    pub block_height: u64,
    pub parent_hash: String,
    pub reason: String,
    pub canonical_head_hash: String,
    pub observed_at_logical_time: u64,
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
pub struct BalanceTransfer {
    pub transfer_id: String,
    pub from_account_id: String,
    pub to_account_id: String,
    pub amount_units: u64,
    pub memo: String,
    pub transferred_at_block: u64,
    pub no_value: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct LocalTestToken {
    pub token_id: String,
    pub symbol: String,
    pub name: String,
    pub decimals: u8,
    pub launcher_account_id: String,
    pub total_supply_units: u64,
    pub launched_at_block: u64,
    pub no_value: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct LocalTestTokenBalance {
    pub token_balance_id: String,
    pub token_id: String,
    pub account_id: String,
    pub units: u64,
    pub updated_at_block: u64,
    pub no_value: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct LocalTestTokenMintReceipt {
    pub mint_id: String,
    pub token_id: String,
    pub to_account_id: String,
    pub amount_units: u64,
    pub reason: String,
    pub minted_at_block: u64,
    pub no_value: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct DexPool {
    pub pool_id: String,
    pub base_asset_id: String,
    pub quote_asset_id: String,
    pub created_by_account_id: String,
    pub reserve_base_units: u64,
    pub reserve_quote_units: u64,
    pub total_lp_units: u64,
    pub created_at_block: u64,
    pub updated_at_block: u64,
    pub last_liquidity_receipt_id: Option<String>,
    pub last_swap_receipt_id: Option<String>,
    pub no_value: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct LpPosition {
    pub lp_position_id: String,
    pub pool_id: String,
    pub owner_account_id: String,
    pub lp_units: u64,
    pub base_units_deposited: u64,
    pub quote_units_deposited: u64,
    pub base_units_withdrawn: u64,
    pub quote_units_withdrawn: u64,
    pub updated_at_block: u64,
    pub no_value: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct LiquidityReceipt {
    pub liquidity_id: String,
    pub pool_id: String,
    pub provider_account_id: String,
    pub action: String,
    pub base_amount_units: u64,
    pub quote_amount_units: u64,
    pub lp_units: u64,
    pub reserve_base_before: u64,
    pub reserve_quote_before: u64,
    pub reserve_base_after: u64,
    pub reserve_quote_after: u64,
    pub executed_at_block: u64,
    pub no_value: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct SwapReceipt {
    pub swap_id: String,
    pub pool_id: String,
    pub trader_account_id: String,
    pub asset_in_id: String,
    pub asset_out_id: String,
    pub amount_in_units: u64,
    pub amount_out_units: u64,
    pub reserve_base_before: u64,
    pub reserve_quote_before: u64,
    pub reserve_base_after: u64,
    pub reserve_quote_after: u64,
    pub executed_at_block: u64,
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
    pub balance_transfer_root: String,
    #[serde(default)]
    pub token_definition_root: String,
    #[serde(default)]
    pub token_balance_root: String,
    #[serde(default)]
    pub token_mint_receipt_root: String,
    #[serde(default)]
    pub dex_pool_root: String,
    #[serde(default)]
    pub lp_position_root: String,
    #[serde(default)]
    pub liquidity_receipt_root: String,
    #[serde(default)]
    pub swap_receipt_root: String,
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
#[serde(rename_all = "camelCase")]
pub struct BridgeReplayKeyRecord {
    pub schema: String,
    pub replay_key: String,
    pub source_chain_id: String,
    pub source_tx_hash: String,
    pub source_log_index: String,
    pub local_object_id: String,
    pub status: String,
    pub first_seen_block: u64,
    pub finalized_at_height: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct BridgeCreditRecord {
    pub schema: String,
    pub credit_id: String,
    pub replay_key: String,
    pub source_chain_id: String,
    pub source_tx_hash: String,
    pub source_log_index: String,
    pub recipient_account_id: String,
    pub amount_units: u64,
    pub evidence_hash: String,
    pub credited_at_block: u64,
    pub status: String,
    pub finality_required: bool,
    pub local_only: bool,
    pub production_ready: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct BridgeLifecycleEvidence {
    pub schema: String,
    pub evidence_id: String,
    pub credit_id: String,
    pub credit_tx_id: String,
    pub credit_included_in_block: u64,
    pub credit_block_hash: String,
    pub credit_receipt_status: String,
    pub block_hash_includes_credit_tx_and_receipt: bool,
    pub state_root_before_credit: String,
    pub state_root_after_credit: String,
    pub state_root_changed_after_credit: bool,
    pub finality: BridgeCreditFinalityEvidence,
    pub transfer_after_credit: BridgeSpendEvidence,
    pub result: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct BridgeCreditFinalityEvidence {
    pub required: bool,
    pub status: String,
    pub finality_receipt_id: Option<String>,
    pub finalized_height: u64,
    pub finalized_block_hash: String,
    pub finalized_state_root: String,
    pub rule: String,
    pub private_pilot: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct BridgeSpendEvidence {
    pub transfer_id: String,
    pub transfer_tx_id: String,
    pub transfer_block_number: u64,
    pub transfer_block_hash: String,
    pub transfer_receipt_status: String,
    pub references_credit_id: bool,
    pub references_finality_receipt_id: bool,
    pub references_credited_state_root: bool,
    pub spendable_under_finality_rule: bool,
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
    TransferLocalTestUnits {
        transfer_id: String,
        from_account_id: String,
        to_account_id: String,
        amount_units: u64,
        memo: String,
    },
    LaunchToken {
        token_id: String,
        symbol: String,
        name: String,
        decimals: u8,
        initial_owner_account_id: String,
        initial_supply_units: u64,
    },
    MintLocalTestToken {
        mint_id: String,
        token_id: String,
        to_account_id: String,
        amount_units: u64,
        reason: String,
    },
    CreatePool {
        pool_id: String,
        base_asset_id: String,
        quote_asset_id: String,
        created_by_account_id: String,
    },
    AddLiquidity {
        liquidity_id: String,
        pool_id: String,
        provider_account_id: String,
        base_amount_units: u64,
        quote_amount_units: u64,
        min_lp_units: u64,
    },
    RemoveLiquidity {
        liquidity_id: String,
        pool_id: String,
        provider_account_id: String,
        lp_units: u64,
        min_base_amount_units: u64,
        min_quote_amount_units: u64,
    },
    SwapExactIn {
        swap_id: String,
        pool_id: String,
        trader_account_id: String,
        asset_in_id: String,
        amount_in_units: u64,
        min_amount_out_units: u64,
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
    RecordBridgeReplayKey {
        replay_key: String,
        source_chain_id: String,
        source_tx_hash: String,
        source_log_index: String,
        local_object_id: String,
    },
    ApplyBridgeCredit {
        credit_id: String,
        replay_key: String,
        source_chain_id: String,
        source_tx_hash: String,
        source_log_index: String,
        recipient_account_id: String,
        amount_units: u64,
        evidence_hash: String,
    },
    SpendBridgeCreditLocalTestUnits {
        transfer_id: String,
        credit_id: String,
        finality_receipt_id: String,
        credited_block_hash: String,
        credited_state_root: String,
        from_account_id: String,
        to_account_id: String,
        amount_units: u64,
        memo: String,
    },
    ImportFlowPulseObservation(ImportedFlowPulseObservation),
    ImportVerifierReport(ImportedVerifierReport),
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct TxEnvelope {
    pub tx_id: String,
    pub tx: Transaction,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub authorization: Option<LocalAuthorization>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct LocalAuthorization {
    pub mode: String,
    pub signer: String,
    pub digest: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct AuthorityProof {
    pub schema: String,
    pub proof_type: String,
    pub validator_id: String,
    pub consensus_key_id: String,
    pub digest: String,
    pub signature: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct Block {
    pub schema: String,
    #[serde(default = "default_chain_id")]
    pub chain_id: String,
    #[serde(default = "default_genesis_hash")]
    pub genesis_hash: String,
    #[serde(default = "default_authority_set_id")]
    pub authority_set_id: String,
    #[serde(default = "default_validator_id")]
    pub proposer_id: String,
    pub block_number: u64,
    pub parent_hash: String,
    pub logical_time: u64,
    pub tx_ids: Vec<String>,
    #[serde(default = "empty_root")]
    pub tx_root: String,
    pub receipts: Vec<BlockReceipt>,
    #[serde(default = "empty_root")]
    pub receipt_root: String,
    #[serde(default = "empty_root")]
    pub event_root: String,
    pub state_root: String,
    #[serde(default = "empty_authority_proof")]
    pub authority_proof: AuthorityProof,
    pub block_hash: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct BlockReceipt {
    pub tx_id: String,
    pub status: String,
    pub error: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub authorization: Option<LocalAuthorization>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct StateCommitmentView<'a> {
    schema: &'a str,
    config: &'a DevnetConfig,
    chain_id: &'a str,
    genesis_hash: &'a str,
    operator_key_references: &'a BTreeMap<String, OperatorKeyReference>,
    validator_set: &'a BTreeMap<String, ValidatorIdentity>,
    authority_set: &'a AuthoritySet,
    rootfields: &'a BTreeMap<String, Rootfield>,
    agent_accounts: &'a BTreeMap<String, AgentAccount>,
    local_test_unit_balances: &'a BTreeMap<String, LocalTestUnitBalance>,
    faucet_records: &'a BTreeMap<String, FaucetRecord>,
    balance_transfers: &'a BTreeMap<String, BalanceTransfer>,
    token_definitions: &'a BTreeMap<String, LocalTestToken>,
    token_balances: &'a BTreeMap<String, LocalTestTokenBalance>,
    token_mint_receipts: &'a BTreeMap<String, LocalTestTokenMintReceipt>,
    dex_pools: &'a BTreeMap<String, DexPool>,
    lp_positions: &'a BTreeMap<String, LpPosition>,
    liquidity_receipts: &'a BTreeMap<String, LiquidityReceipt>,
    swap_receipts: &'a BTreeMap<String, SwapReceipt>,
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
    bridge_replay_keys: &'a BTreeMap<String, BridgeReplayKeyRecord>,
    bridge_credits: &'a BTreeMap<String, BridgeCreditRecord>,
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
    pub validator_set_root: String,
    pub authority_set_root: String,
    pub rootfield_state_root: String,
    pub agent_account_root: String,
    pub local_test_unit_balance_root: String,
    pub faucet_record_root: String,
    pub balance_transfer_root: String,
    pub token_definition_root: String,
    pub token_balance_root: String,
    pub token_mint_receipt_root: String,
    pub dex_pool_root: String,
    pub lp_position_root: String,
    pub liquidity_receipt_root: String,
    pub swap_receipt_root: String,
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
    pub bridge_replay_key_root: String,
    pub bridge_credit_root: String,
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
        consensus:
            "private/local authority-set consensus with deterministic proposer schedule and immediate local finality"
                .to_string(),
        crypto_schema_refs: vec![
            "crypto/FLOWMEMORY_CRYPTO_SPEC.md#domain-separation".to_string(),
            "crypto/ATTESTATIONS.md#local-signature-helpers".to_string(),
        ],
    }
}

fn default_chain_id() -> String {
    default_config().chain_id
}

fn default_genesis_hash() -> String {
    GENESIS_HASH.to_string()
}

fn default_authority_set_id() -> String {
    LOCAL_PRIVATE_AUTHORITY_SET_ID.to_string()
}

fn default_validator_id() -> String {
    LOCAL_PRIVATE_VALIDATOR_ID.to_string()
}

fn empty_root() -> String {
    ZERO_HASH.to_string()
}

fn empty_authority_proof() -> AuthorityProof {
    AuthorityProof {
        schema: AUTHORITY_PROOF_SCHEMA.to_string(),
        proof_type: "unset".to_string(),
        validator_id: String::new(),
        consensus_key_id: String::new(),
        digest: ZERO_HASH.to_string(),
        signature: ZERO_HASH.to_string(),
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

pub fn default_validator_set() -> BTreeMap<String, ValidatorIdentity> {
    let validator = ValidatorIdentity {
        schema: VALIDATOR_IDENTITY_SCHEMA.to_string(),
        validator_id: LOCAL_PRIVATE_VALIDATOR_ID.to_string(),
        account_ref: "operator:local-private:alpha".to_string(),
        consensus_public_key: keccak_hex(b"flowmemory.local_private.validator.alpha.public"),
        consensus_key_id: "consensus-key:local-private:alpha".to_string(),
        roles: vec![
            "validator".to_string(),
            "sequencer".to_string(),
            "proposer".to_string(),
            "finality-signer".to_string(),
        ],
        weight: 1,
        active: true,
        key_scope: "consensus-only-local-private-authority".to_string(),
        bridge_key_separation: "consensus keys do not sign bridge release or custody instructions"
            .to_string(),
        wallet_key_separation: "consensus keys are separate from local user wallet and faucet keys"
            .to_string(),
        public_metadata: ValidatorPublicMetadata {
            display_name: "FlowMemory local private authority alpha".to_string(),
            operator_ref: "operator:local-private:alpha".to_string(),
            network_profile: "private-local-single-authority".to_string(),
            dashboard_safe: true,
        },
    };
    BTreeMap::from([(validator.validator_id.clone(), validator)])
}

pub fn default_authority_set() -> AuthoritySet {
    AuthoritySet {
        schema: AUTHORITY_SET_SCHEMA.to_string(),
        authority_set_id: LOCAL_PRIVATE_AUTHORITY_SET_ID.to_string(),
        chain_id: default_chain_id(),
        genesis_hash: GENESIS_HASH.to_string(),
        profile: "private-local-authority-set".to_string(),
        validators: vec![LOCAL_PRIVATE_VALIDATOR_ID.to_string()],
        proposer_schedule: vec![LOCAL_PRIVATE_VALIDATOR_ID.to_string()],
        total_weight: 1,
        quorum_weight: 1,
        public_metadata_export: "dashboard-safe validator metadata only; no secret key material"
            .to_string(),
    }
}

pub fn default_consensus_state() -> ConsensusState {
    ConsensusState {
        schema: CONSENSUS_STATE_SCHEMA.to_string(),
        profile: "private-local-single-authority".to_string(),
        finality_rule:
            "single local authority finalizes the canonical block immediately after validation"
                .to_string(),
        canonical_height: 0,
        canonical_head_hash: GENESIS_HASH.to_string(),
        canonical_state_root: ZERO_HASH.to_string(),
        finalized_height: 0,
        finalized_hash: GENESIS_HASH.to_string(),
        finalized_state_root: ZERO_HASH.to_string(),
        finalized_at_logical_time: default_config().genesis_logical_time,
        latest_finality_receipt_id: None,
        consensus_state_output_path: "devnet/local/consensus-state.json".to_string(),
    }
}

pub fn genesis_state() -> ChainState {
    let config = default_config();
    let mut state = ChainState {
        schema: STATE_SCHEMA.to_string(),
        chain_id: config.chain_id.clone(),
        genesis_hash: config.genesis_hash.clone(),
        next_block_number: 1,
        logical_time: config.genesis_logical_time,
        parent_hash: config.genesis_hash.clone(),
        config,
        operator_key_references: default_operator_key_references(),
        validator_set: default_validator_set(),
        authority_set: default_authority_set(),
        consensus_state: default_consensus_state(),
        chain_finality_receipts: BTreeMap::new(),
        fork_evidence: Vec::new(),
        misbehavior_evidence: Vec::new(),
        rootfields: BTreeMap::new(),
        agent_accounts: BTreeMap::new(),
        local_test_unit_balances: BTreeMap::new(),
        faucet_records: BTreeMap::new(),
        balance_transfers: BTreeMap::new(),
        token_definitions: BTreeMap::new(),
        token_balances: BTreeMap::new(),
        token_mint_receipts: BTreeMap::new(),
        dex_pools: BTreeMap::new(),
        lp_positions: BTreeMap::new(),
        liquidity_receipts: BTreeMap::new(),
        swap_receipts: BTreeMap::new(),
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
        bridge_replay_keys: BTreeMap::new(),
        bridge_credits: BTreeMap::new(),
        blocks: Vec::new(),
        pending_txs: Vec::new(),
    };
    let genesis_root = state_root(&state);
    state.consensus_state.canonical_state_root = genesis_root.clone();
    state.consensus_state.finalized_state_root = genesis_root;
    state
}

pub fn envelope_tx(tx: Transaction) -> TxEnvelope {
    let tx_id = hash_json(TX_SCHEMA, &tx);
    TxEnvelope {
        tx_id,
        tx,
        authorization: None,
    }
}

pub fn queue_transaction(state: &mut ChainState, tx: Transaction) -> String {
    let envelope = envelope_tx(tx);
    let tx_id = envelope.tx_id.clone();
    state.pending_txs.push(envelope);
    tx_id
}

pub fn queue_authorized_transaction(
    state: &mut ChainState,
    tx: Transaction,
    signer: String,
) -> String {
    let mut envelope = envelope_tx(tx);
    envelope.authorization = Some(LocalAuthorization {
        mode: "local-authorized".to_string(),
        signer,
        digest: envelope.tx_id.clone(),
    });
    let tx_id = envelope.tx_id.clone();
    state.pending_txs.push(envelope);
    tx_id
}

pub fn normalize_token_symbol(symbol: &str) -> String {
    symbol.trim().to_ascii_uppercase()
}

pub fn deterministic_token_id(symbol: &str) -> String {
    hash_json(
        "flowmemory.local_devnet.token_id.v0",
        &serde_json::json!({
            "symbol": normalize_token_symbol(symbol)
        }),
    )
}

pub fn deterministic_token_balance_id(token_id: &str, account_id: &str) -> String {
    hash_json(
        "flowmemory.local_devnet.token_balance_id.v0",
        &serde_json::json!({
            "tokenId": token_id,
            "accountId": account_id
        }),
    )
}

pub fn deterministic_token_mint_id(
    token_id: &str,
    to_account_id: &str,
    amount_units: u64,
    reason: &str,
) -> String {
    hash_json(
        "flowmemory.local_devnet.token_mint_id.v0",
        &serde_json::json!({
            "tokenId": token_id,
            "toAccountId": to_account_id,
            "amountUnits": amount_units,
            "reason": reason
        }),
    )
}

pub fn deterministic_pool_id(base_asset_id: &str, quote_asset_id: &str) -> String {
    hash_json(
        "flowmemory.local_devnet.dex_pool_id.v0",
        &serde_json::json!({
            "baseAssetId": base_asset_id,
            "quoteAssetId": quote_asset_id
        }),
    )
}

pub fn deterministic_lp_position_id(pool_id: &str, owner_account_id: &str) -> String {
    hash_json(
        "flowmemory.local_devnet.lp_position_id.v0",
        &serde_json::json!({
            "poolId": pool_id,
            "ownerAccountId": owner_account_id
        }),
    )
}

pub fn deterministic_liquidity_id(
    pool_id: &str,
    provider_account_id: &str,
    action: &str,
    nonce: &str,
) -> String {
    hash_json(
        "flowmemory.local_devnet.liquidity_id.v0",
        &serde_json::json!({
            "poolId": pool_id,
            "providerAccountId": provider_account_id,
            "action": action,
            "nonce": nonce
        }),
    )
}

pub fn deterministic_swap_id(
    pool_id: &str,
    trader_account_id: &str,
    asset_in_id: &str,
    amount_in_units: u64,
    nonce: &str,
) -> String {
    hash_json(
        "flowmemory.local_devnet.swap_id.v0",
        &serde_json::json!({
            "poolId": pool_id,
            "traderAccountId": trader_account_id,
            "assetInId": asset_in_id,
            "amountInUnits": amount_in_units,
            "nonce": nonce
        }),
    )
}

pub fn state_root(state: &ChainState) -> String {
    let view = StateCommitmentView {
        schema: STATE_SCHEMA,
        config: &state.config,
        chain_id: &state.chain_id,
        genesis_hash: &state.genesis_hash,
        operator_key_references: &state.operator_key_references,
        validator_set: &state.validator_set,
        authority_set: &state.authority_set,
        rootfields: &state.rootfields,
        agent_accounts: &state.agent_accounts,
        local_test_unit_balances: &state.local_test_unit_balances,
        faucet_records: &state.faucet_records,
        balance_transfers: &state.balance_transfers,
        token_definitions: &state.token_definitions,
        token_balances: &state.token_balances,
        token_mint_receipts: &state.token_mint_receipts,
        dex_pools: &state.dex_pools,
        lp_positions: &state.lp_positions,
        liquidity_receipts: &state.liquidity_receipts,
        swap_receipts: &state.swap_receipts,
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
        bridge_replay_keys: &state.bridge_replay_keys,
        bridge_credits: &state.bridge_credits,
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
        validator_set_root: map_root(
            "flowmemory.local_devnet.validator_set.v0",
            &state.validator_set,
        ),
        authority_set_root: hash_json(
            "flowmemory.local_devnet.authority_set_root.v0",
            &state.authority_set,
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
        balance_transfer_root: map_root(
            "flowmemory.local_devnet.balance_transfers.v0",
            &state.balance_transfers,
        ),
        token_definition_root: map_root(
            "flowmemory.local_devnet.token_definitions.v0",
            &state.token_definitions,
        ),
        token_balance_root: map_root(
            "flowmemory.local_devnet.token_balances.v0",
            &state.token_balances,
        ),
        token_mint_receipt_root: map_root(
            "flowmemory.local_devnet.token_mint_receipts.v0",
            &state.token_mint_receipts,
        ),
        dex_pool_root: map_root("flowmemory.local_devnet.dex_pools.v0", &state.dex_pools),
        lp_position_root: map_root(
            "flowmemory.local_devnet.lp_positions.v0",
            &state.lp_positions,
        ),
        liquidity_receipt_root: map_root(
            "flowmemory.local_devnet.liquidity_receipts.v0",
            &state.liquidity_receipts,
        ),
        swap_receipt_root: map_root(
            "flowmemory.local_devnet.swap_receipts.v0",
            &state.swap_receipts,
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
        bridge_replay_key_root: map_root(
            "flowmemory.local_devnet.bridge_replay_keys.v0",
            &state.bridge_replay_keys,
        ),
        bridge_credit_root: map_root(
            "flowmemory.local_devnet.bridge_credits.v0",
            &state.bridge_credits,
        ),
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct BlockProposal {
    pub block: Block,
    pub transactions: Vec<TxEnvelope>,
    pub post_state: ChainState,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ForkChoiceOutcome {
    pub schema: String,
    pub canonical_head: Option<Block>,
    pub rejected: Vec<ForkEvidence>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ConsensusValidationReport {
    pub schema: String,
    pub valid: bool,
    pub checked_blocks: usize,
    pub canonical_head_hash: String,
    pub finalized_height: u64,
    pub finalized_hash: String,
    pub finalized_state_root: String,
    pub consensus_state_root: String,
    pub errors: Vec<String>,
}

pub fn tx_root(tx_ids: &[String]) -> String {
    hash_json(
        "flowmemory.local_devnet.tx_root.v0",
        &serde_json::json!({
            "schema": "flowmemory.local_devnet.tx_root.v0",
            "txIds": tx_ids
        }),
    )
}

pub fn receipt_root(receipts: &[BlockReceipt]) -> String {
    hash_json(
        "flowmemory.local_devnet.receipt_root.v0",
        &serde_json::json!({
            "schema": "flowmemory.local_devnet.receipt_root.v0",
            "receipts": receipts
        }),
    )
}

pub fn event_root(receipts: &[BlockReceipt]) -> String {
    let events = receipts
        .iter()
        .map(|receipt| {
            serde_json::json!({
                "schema": "flowmemory.local_devnet.block_event_commitment.v0",
                "txId": receipt.tx_id,
                "eventType": if receipt.status == "applied" {
                    "transaction_applied"
                } else {
                    "transaction_rejected"
                },
                "status": receipt.status
            })
        })
        .collect::<Vec<_>>();
    hash_json(
        "flowmemory.local_devnet.event_root.v0",
        &serde_json::json!({
            "schema": "flowmemory.local_devnet.event_root.v0",
            "events": events
        }),
    )
}

pub fn consensus_state_root(state: &ChainState) -> String {
    hash_json(
        "flowmemory.local_devnet.consensus_state_root.v0",
        &serde_json::json!({
            "schema": "flowmemory.local_devnet.consensus_state_commitment.v0",
            "authoritySet": state.authority_set,
            "validatorSet": state.validator_set,
            "consensusState": state.consensus_state,
            "chainFinalityReceipts": state.chain_finality_receipts,
            "forkEvidence": state.fork_evidence,
            "misbehaviorEvidence": state.misbehavior_evidence
        }),
    )
}

pub fn expected_proposer_id(state: &ChainState, height: u64) -> Option<String> {
    if state.authority_set.proposer_schedule.is_empty() || height == 0 {
        return None;
    }
    let index = ((height - 1) as usize) % state.authority_set.proposer_schedule.len();
    state.authority_set.proposer_schedule.get(index).cloned()
}

pub fn validator_has_role(state: &ChainState, validator_id: &str, role: &str) -> bool {
    state
        .validator_set
        .get(validator_id)
        .is_some_and(|validator| {
            validator.active
                && validator
                    .roles
                    .iter()
                    .any(|candidate| candidate.eq_ignore_ascii_case(role))
        })
}

pub fn calculate_block_hash(block: &Block) -> String {
    let mut input = block.clone();
    input.block_hash = ZERO_HASH.to_string();
    hash_json("flowmemory.local_devnet.block_hash.v0", &input)
}

fn authority_digest(block: &Block) -> String {
    let mut input = block.clone();
    input.block_hash = ZERO_HASH.to_string();
    input.authority_proof = empty_authority_proof();
    hash_json("flowmemory.local_devnet.authority_digest.v0", &input)
}

fn authority_signature(
    validator_id: &str,
    consensus_key_id: &str,
    consensus_public_key: &str,
    digest: &str,
) -> String {
    hash_json(
        "flowmemory.local_devnet.authority_signature.v0",
        &serde_json::json!({
            "validatorId": validator_id,
            "consensusKeyId": consensus_key_id,
            "consensusPublicKey": consensus_public_key,
            "digest": digest
        }),
    )
}

fn authority_proof_for_block(
    state: &ChainState,
    block: &Block,
    proposer_id: &str,
) -> Result<AuthorityProof, ConsensusValidationError> {
    let validator = state
        .validator_set
        .get(proposer_id)
        .filter(|validator| validator.active)
        .ok_or_else(|| ConsensusValidationError::InvalidProposer(proposer_id.to_string()))?;
    if !validator_has_role(state, proposer_id, "proposer") {
        return Err(ConsensusValidationError::InvalidProposer(
            proposer_id.to_string(),
        ));
    }
    let digest = authority_digest(block);
    Ok(AuthorityProof {
        schema: AUTHORITY_PROOF_SCHEMA.to_string(),
        proof_type: "local-private-authority-digest".to_string(),
        validator_id: proposer_id.to_string(),
        consensus_key_id: validator.consensus_key_id.clone(),
        signature: authority_signature(
            proposer_id,
            &validator.consensus_key_id,
            &validator.consensus_public_key,
            &digest,
        ),
        digest,
    })
}

fn validate_authority_proof(
    state: &ChainState,
    block: &Block,
) -> Result<(), ConsensusValidationError> {
    if block.authority_proof.validator_id != block.proposer_id {
        return Err(ConsensusValidationError::InvalidAuthorityProof(
            "authority proof validator does not match proposer".to_string(),
        ));
    }
    let validator = state
        .validator_set
        .get(&block.proposer_id)
        .filter(|validator| validator.active)
        .ok_or_else(|| ConsensusValidationError::InvalidProposer(block.proposer_id.clone()))?;
    let expected_digest = authority_digest(block);
    if block.authority_proof.digest != expected_digest {
        return Err(ConsensusValidationError::InvalidAuthorityProof(
            "authority proof digest mismatch".to_string(),
        ));
    }
    let expected_signature = authority_signature(
        &block.proposer_id,
        &validator.consensus_key_id,
        &validator.consensus_public_key,
        &expected_digest,
    );
    if block.authority_proof.consensus_key_id != validator.consensus_key_id
        || block.authority_proof.signature != expected_signature
    {
        return Err(ConsensusValidationError::InvalidAuthorityProof(
            "authority proof signature mismatch".to_string(),
        ));
    }
    Ok(())
}

fn ensure_unique_tx_ids(tx_ids: &[String]) -> Result<(), ConsensusValidationError> {
    let mut seen = BTreeSet::new();
    for tx_id in tx_ids {
        if !seen.insert(tx_id) {
            return Err(ConsensusValidationError::DuplicateTransaction(
                tx_id.clone(),
            ));
        }
    }
    Ok(())
}

pub fn propose_block(
    parent_state: &ChainState,
    transactions: Vec<TxEnvelope>,
    proposer_id: &str,
) -> Result<BlockProposal, ConsensusValidationError> {
    if !validator_has_role(parent_state, proposer_id, "proposer") {
        return Err(ConsensusValidationError::InvalidProposer(
            proposer_id.to_string(),
        ));
    }
    let expected_proposer = expected_proposer_id(parent_state, parent_state.next_block_number)
        .ok_or_else(|| {
            ConsensusValidationError::InvalidProposer("empty proposer schedule".to_string())
        })?;
    if expected_proposer != proposer_id {
        return Err(ConsensusValidationError::InvalidProposer(
            proposer_id.to_string(),
        ));
    }

    let mut post_state = parent_state.clone();
    post_state.pending_txs.clear();

    let mut receipts = Vec::with_capacity(transactions.len());
    let mut tx_ids = Vec::with_capacity(transactions.len());
    let mut seen = BTreeSet::new();

    for envelope in &transactions {
        let authorization = envelope.authorization.clone();
        if !seen.insert(envelope.tx_id.clone()) {
            receipts.push(BlockReceipt {
                tx_id: envelope.tx_id.clone(),
                status: "rejected".to_string(),
                error: Some(DevnetError::DuplicateTransaction(envelope.tx_id.clone()).to_string()),
                authorization,
            });
            continue;
        }
        tx_ids.push(envelope.tx_id.clone());
        let result = apply_transaction(&mut post_state, &envelope.tx);
        receipts.push(BlockReceipt {
            tx_id: envelope.tx_id.clone(),
            status: if result.is_ok() {
                "applied"
            } else {
                "rejected"
            }
            .to_string(),
            error: result.err().map(|error| error.to_string()),
            authorization,
        });
    }

    let mut block = Block {
        schema: BLOCK_SCHEMA.to_string(),
        chain_id: parent_state.chain_id.clone(),
        genesis_hash: parent_state.genesis_hash.clone(),
        authority_set_id: parent_state.authority_set.authority_set_id.clone(),
        proposer_id: proposer_id.to_string(),
        block_number: parent_state.next_block_number,
        parent_hash: parent_state.parent_hash.clone(),
        logical_time: parent_state.logical_time,
        tx_root: tx_root(&tx_ids),
        tx_ids,
        receipt_root: receipt_root(&receipts),
        event_root: event_root(&receipts),
        receipts,
        state_root: state_root(&post_state),
        authority_proof: empty_authority_proof(),
        block_hash: ZERO_HASH.to_string(),
    };
    block.authority_proof = authority_proof_for_block(parent_state, &block, proposer_id)?;
    block.block_hash = calculate_block_hash(&block);

    let proposal = BlockProposal {
        block,
        transactions,
        post_state,
    };
    validate_block_header(parent_state, &proposal.block)?;
    Ok(proposal)
}

pub fn validate_block_proposal(
    parent_state: &ChainState,
    proposal: &BlockProposal,
) -> Result<(), ConsensusValidationError> {
    let expected = propose_block(
        parent_state,
        proposal.transactions.clone(),
        &proposal.block.proposer_id,
    )?;
    if expected.block.state_root != proposal.block.state_root {
        return Err(ConsensusValidationError::RootMismatch {
            root_name: "stateRoot".to_string(),
            expected: expected.block.state_root,
            actual: proposal.block.state_root.clone(),
        });
    }
    if expected.block.tx_root != proposal.block.tx_root {
        return Err(ConsensusValidationError::RootMismatch {
            root_name: "txRoot".to_string(),
            expected: expected.block.tx_root,
            actual: proposal.block.tx_root.clone(),
        });
    }
    if expected.block.receipt_root != proposal.block.receipt_root {
        return Err(ConsensusValidationError::RootMismatch {
            root_name: "receiptRoot".to_string(),
            expected: expected.block.receipt_root,
            actual: proposal.block.receipt_root.clone(),
        });
    }
    if expected.block.event_root != proposal.block.event_root {
        return Err(ConsensusValidationError::RootMismatch {
            root_name: "eventRoot".to_string(),
            expected: expected.block.event_root,
            actual: proposal.block.event_root.clone(),
        });
    }
    if expected.block.block_hash != proposal.block.block_hash {
        return Err(ConsensusValidationError::BlockHashMismatch {
            expected: expected.block.block_hash,
            actual: proposal.block.block_hash.clone(),
        });
    }
    validate_block_header(parent_state, &proposal.block)?;
    Ok(())
}

pub fn validate_block_header(
    parent_state: &ChainState,
    block: &Block,
) -> Result<(), ConsensusValidationError> {
    if block.chain_id != parent_state.chain_id {
        return Err(ConsensusValidationError::WrongChainId {
            expected: parent_state.chain_id.clone(),
            actual: block.chain_id.clone(),
        });
    }
    if block.genesis_hash != parent_state.genesis_hash {
        return Err(ConsensusValidationError::WrongGenesisHash {
            expected: parent_state.genesis_hash.clone(),
            actual: block.genesis_hash.clone(),
        });
    }
    if block.authority_set_id != parent_state.authority_set.authority_set_id {
        return Err(ConsensusValidationError::InvalidAuthorityProof(
            "authority set id mismatch".to_string(),
        ));
    }
    if block.parent_hash != parent_state.parent_hash {
        return Err(ConsensusValidationError::InvalidParent {
            expected: parent_state.parent_hash.clone(),
            actual: block.parent_hash.clone(),
        });
    }
    if block.block_number != parent_state.next_block_number {
        return Err(ConsensusValidationError::InvalidHeight {
            expected: parent_state.next_block_number,
            actual: block.block_number,
        });
    }
    let min_time = parent_state.logical_time;
    let max_time = parent_state
        .logical_time
        .saturating_add(parent_state.config.block_time_seconds.max(1) * 2);
    if block.logical_time < min_time || block.logical_time > max_time {
        return Err(ConsensusValidationError::TimestampOutOfBounds {
            min: min_time,
            max: max_time,
            actual: block.logical_time,
        });
    }
    let expected_proposer =
        expected_proposer_id(parent_state, block.block_number).ok_or_else(|| {
            ConsensusValidationError::InvalidProposer("empty proposer schedule".to_string())
        })?;
    if block.proposer_id != expected_proposer
        || !validator_has_role(parent_state, &block.proposer_id, "proposer")
    {
        return Err(ConsensusValidationError::InvalidProposer(
            block.proposer_id.clone(),
        ));
    }
    if block.block_number <= parent_state.consensus_state.finalized_height {
        let finalized_hash = parent_state
            .blocks
            .iter()
            .find(|candidate| candidate.block_number == block.block_number)
            .map(|candidate| candidate.block_hash.clone())
            .unwrap_or_else(|| parent_state.consensus_state.finalized_hash.clone());
        if block.block_hash != finalized_hash {
            return Err(ConsensusValidationError::FinalizedConflict {
                height: parent_state.consensus_state.finalized_height,
                finalized_hash,
            });
        }
    }
    ensure_unique_tx_ids(&block.tx_ids)?;
    let expected_tx_root = tx_root(&block.tx_ids);
    if block.tx_root != expected_tx_root {
        return Err(ConsensusValidationError::RootMismatch {
            root_name: "txRoot".to_string(),
            expected: expected_tx_root,
            actual: block.tx_root.clone(),
        });
    }
    let expected_receipt_root = receipt_root(&block.receipts);
    if block.receipt_root != expected_receipt_root {
        return Err(ConsensusValidationError::RootMismatch {
            root_name: "receiptRoot".to_string(),
            expected: expected_receipt_root,
            actual: block.receipt_root.clone(),
        });
    }
    let expected_event_root = event_root(&block.receipts);
    if block.event_root != expected_event_root {
        return Err(ConsensusValidationError::RootMismatch {
            root_name: "eventRoot".to_string(),
            expected: expected_event_root,
            actual: block.event_root.clone(),
        });
    }
    validate_authority_proof(parent_state, block)?;
    let expected_hash = calculate_block_hash(block);
    if block.block_hash != expected_hash {
        return Err(ConsensusValidationError::BlockHashMismatch {
            expected: expected_hash,
            actual: block.block_hash.clone(),
        });
    }
    Ok(())
}

pub fn build_block(state: &mut ChainState) -> Block {
    let proposer = expected_proposer_id(state, state.next_block_number)
        .unwrap_or_else(|| LOCAL_PRIVATE_VALIDATOR_ID.to_string());
    build_block_with_proposer(state, &proposer)
        .expect("default local-private proposer should be valid")
}

pub fn build_block_with_proposer(
    state: &mut ChainState,
    proposer_id: &str,
) -> Result<Block, ConsensusValidationError> {
    let proposal = propose_block(state, state.pending_txs.clone(), proposer_id)?;
    commit_block_proposal(state, proposal)
}

pub fn commit_block_proposal(
    state: &mut ChainState,
    proposal: BlockProposal,
) -> Result<Block, ConsensusValidationError> {
    validate_block_proposal(state, &proposal)?;
    let block = proposal.block;
    let mut next_state = proposal.post_state;
    next_state.next_block_number = block.block_number + 1;
    next_state.logical_time = block.logical_time + 1;
    next_state.parent_hash = block.block_hash.clone();
    next_state.blocks.push(block.clone());
    update_consensus_after_block(&mut next_state, &block);
    *state = next_state;
    Ok(block)
}

fn update_consensus_after_block(state: &mut ChainState, block: &Block) {
    state.consensus_state.canonical_height = block.block_number;
    state.consensus_state.canonical_head_hash = block.block_hash.clone();
    state.consensus_state.canonical_state_root = block.state_root.clone();
    let receipt = chain_finality_receipt_for_block(state, block);
    state.consensus_state.finalized_height = receipt.finalized_height;
    state.consensus_state.finalized_hash = receipt.finalized_block_hash.clone();
    state.consensus_state.finalized_state_root = receipt.finalized_state_root.clone();
    state.consensus_state.finalized_at_logical_time = receipt.produced_at_logical_time;
    state.consensus_state.latest_finality_receipt_id = Some(receipt.finality_receipt_id.clone());
    state
        .chain_finality_receipts
        .insert(receipt.finality_receipt_id.clone(), receipt);
}

fn chain_finality_receipt_for_block(state: &ChainState, block: &Block) -> ConsensusFinalityReceipt {
    let signer_ids = vec![block.proposer_id.clone()];
    let certificate_id = hash_json(
        "flowmemory.local_devnet.finality_certificate_id.v0",
        &serde_json::json!({
            "chainId": block.chain_id,
            "genesisHash": block.genesis_hash,
            "authoritySetId": block.authority_set_id,
            "blockHeight": block.block_number,
            "blockHash": block.block_hash,
            "stateRoot": block.state_root,
            "signerIds": signer_ids
        }),
    );
    let certificate = FinalityCertificate {
        schema: FINALITY_CERTIFICATE_SCHEMA.to_string(),
        certificate_id,
        chain_id: block.chain_id.clone(),
        genesis_hash: block.genesis_hash.clone(),
        authority_set_id: block.authority_set_id.clone(),
        block_height: block.block_number,
        block_hash: block.block_hash.clone(),
        state_root: block.state_root.clone(),
        signer_ids,
        quorum_weight: state.authority_set.quorum_weight,
        total_weight: state.authority_set.total_weight,
        profile: state.consensus_state.profile.clone(),
    };
    let finality_receipt_id = hash_json(
        "flowmemory.local_devnet.chain_finality_receipt_id.v0",
        &serde_json::json!({
            "certificateId": certificate.certificate_id,
            "blockHash": block.block_hash,
            "blockHeight": block.block_number,
            "stateRoot": block.state_root
        }),
    );
    ConsensusFinalityReceipt {
        schema: CHAIN_FINALITY_RECEIPT_SCHEMA.to_string(),
        finality_receipt_id,
        chain_id: block.chain_id.clone(),
        genesis_hash: block.genesis_hash.clone(),
        authority_set_id: block.authority_set_id.clone(),
        finalized_height: block.block_number,
        finalized_block_hash: block.block_hash.clone(),
        finalized_state_root: block.state_root.clone(),
        canonical_head_hash: block.block_hash.clone(),
        canonical_height: block.block_number,
        finality_rule: state.consensus_state.finality_rule.clone(),
        certificate,
        produced_at_logical_time: block.logical_time,
    }
}

pub fn finalized_height(state: &ChainState) -> u64 {
    state.consensus_state.finalized_height
}

pub fn finalized_state_root(state: &ChainState) -> String {
    state.consensus_state.finalized_state_root.clone()
}

pub fn finalized_hash(state: &ChainState) -> String {
    state.consensus_state.finalized_hash.clone()
}

pub fn bridge_replay_key_is_final(state: &ChainState, replay_key: &str) -> bool {
    state
        .bridge_replay_keys
        .get(replay_key)
        .is_some_and(|record| record.first_seen_block <= state.consensus_state.finalized_height)
}

pub fn bridge_credit_transaction_id(credit: &BridgeCreditRecord) -> String {
    hash_json(
        TX_SCHEMA,
        &Transaction::ApplyBridgeCredit {
            credit_id: credit.credit_id.clone(),
            replay_key: credit.replay_key.clone(),
            source_chain_id: credit.source_chain_id.clone(),
            source_tx_hash: credit.source_tx_hash.clone(),
            source_log_index: credit.source_log_index.clone(),
            recipient_account_id: credit.recipient_account_id.clone(),
            amount_units: credit.amount_units,
            evidence_hash: credit.evidence_hash.clone(),
        },
    )
}

fn bridge_spend_transaction_id(
    transfer: &BalanceTransfer,
    credit_id: &str,
    finality_receipt_id: &str,
    credited_block_hash: &str,
    credited_state_root: &str,
) -> String {
    hash_json(
        TX_SCHEMA,
        &Transaction::SpendBridgeCreditLocalTestUnits {
            transfer_id: transfer.transfer_id.clone(),
            credit_id: credit_id.to_string(),
            finality_receipt_id: finality_receipt_id.to_string(),
            credited_block_hash: credited_block_hash.to_string(),
            credited_state_root: credited_state_root.to_string(),
            from_account_id: transfer.from_account_id.clone(),
            to_account_id: transfer.to_account_id.clone(),
            amount_units: transfer.amount_units,
            memo: transfer.memo.clone(),
        },
    )
}

fn block_receipt_status(block: &Block, tx_id: &str) -> Option<String> {
    block
        .receipts
        .iter()
        .find(|receipt| receipt.tx_id == tx_id)
        .map(|receipt| receipt.status.clone())
}

pub fn finality_receipt_for_block<'a>(
    state: &'a ChainState,
    block: &Block,
) -> Result<&'a ConsensusFinalityReceipt, ConsensusValidationError> {
    let receipts = state
        .chain_finality_receipts
        .values()
        .filter(|receipt| {
            receipt.finalized_height == block.block_number
                && receipt.finalized_block_hash == block.block_hash
        })
        .collect::<Vec<_>>();
    match receipts.len() {
        0 => Err(ConsensusValidationError::MissingFinalityReceipt {
            block_height: block.block_number,
            block_hash: block.block_hash.clone(),
        }),
        1 => {
            let receipt = receipts[0];
            if receipt.finalized_state_root != block.state_root {
                return Err(ConsensusValidationError::FinalityReceiptMismatch(
                    "finalized state root does not match credited block".to_string(),
                ));
            }
            if receipt.certificate.block_hash != block.block_hash
                || receipt.certificate.state_root != block.state_root
                || receipt.certificate.block_height != block.block_number
            {
                return Err(ConsensusValidationError::FinalityReceiptMismatch(
                    "certificate does not cover credited block".to_string(),
                ));
            }
            Ok(receipt)
        }
        _ => Err(ConsensusValidationError::DuplicateFinalityReceipt {
            block_height: block.block_number,
            block_hash: block.block_hash.clone(),
        }),
    }
}

pub fn validate_bridge_lifecycle_evidence(
    state: &ChainState,
    credit_id: &str,
    transfer_id: &str,
    require_finality: bool,
) -> Result<BridgeLifecycleEvidence, ConsensusValidationError> {
    let credit = state
        .bridge_credits
        .get(credit_id)
        .ok_or_else(|| ConsensusValidationError::BridgeCreditMissing(credit_id.to_string()))?;
    let credit_block = state
        .blocks
        .iter()
        .find(|block| block.block_number == credit.credited_at_block)
        .ok_or_else(|| {
            ConsensusValidationError::BridgeSpendReferenceInvalid(
                "credited block is missing".to_string(),
            )
        })?;
    let credit_tx_id = bridge_credit_transaction_id(credit);
    let credit_receipt_status =
        block_receipt_status(credit_block, &credit_tx_id).ok_or_else(|| {
            ConsensusValidationError::BridgeSpendReferenceInvalid(
                "credited block does not include the credit transaction receipt".to_string(),
            )
        })?;
    let block_hash_includes_credit_tx_and_receipt = credit_block.tx_ids.contains(&credit_tx_id)
        && credit_receipt_status == "applied"
        && calculate_block_hash(credit_block) == credit_block.block_hash;

    if !block_hash_includes_credit_tx_and_receipt {
        return Err(ConsensusValidationError::BridgeSpendReferenceInvalid(
            "credited block hash does not commit to an applied credit receipt".to_string(),
        ));
    }

    let state_root_before_credit = state
        .blocks
        .iter()
        .filter(|block| block.block_number < credit_block.block_number)
        .max_by_key(|block| block.block_number)
        .map(|block| block.state_root.clone())
        .unwrap_or_else(|| {
            let genesis = genesis_state();
            state_root(&genesis)
        });
    let state_root_changed_after_credit = state_root_before_credit != credit_block.state_root;
    if !state_root_changed_after_credit {
        return Err(ConsensusValidationError::BridgeSpendReferenceInvalid(
            "bridge credit did not change the state root".to_string(),
        ));
    }

    let finality_receipt = match finality_receipt_for_block(state, credit_block) {
        Ok(receipt) => Some(receipt),
        Err(_) if !require_finality => None,
        Err(error) => return Err(error),
    };

    let transfer = state.balance_transfers.get(transfer_id).ok_or_else(|| {
        ConsensusValidationError::BridgeSpendReferenceInvalid(
            "transfer record is missing".to_string(),
        )
    })?;
    let transfer_block = state
        .blocks
        .iter()
        .find(|block| block.block_number == transfer.transferred_at_block)
        .ok_or_else(|| {
            ConsensusValidationError::BridgeSpendReferenceInvalid(
                "transfer block is missing".to_string(),
            )
        })?;
    if transfer_block.block_number <= credit_block.block_number {
        return Err(ConsensusValidationError::BridgeSpendReferenceInvalid(
            "bridge credit spend must occur after the credited block".to_string(),
        ));
    }
    if transfer.from_account_id != credit.recipient_account_id {
        return Err(ConsensusValidationError::BridgeSpendReferenceInvalid(
            "transfer source does not match bridge credit recipient".to_string(),
        ));
    }
    let finality_receipt_id = finality_receipt
        .map(|receipt| receipt.finality_receipt_id.clone())
        .unwrap_or_default();
    let transfer_tx_id = bridge_spend_transaction_id(
        transfer,
        credit_id,
        &finality_receipt_id,
        &credit_block.block_hash,
        &credit_block.state_root,
    );
    let transfer_receipt_status = block_receipt_status(transfer_block, &transfer_tx_id)
        .ok_or_else(|| {
            ConsensusValidationError::BridgeSpendReferenceInvalid(
                "transfer block does not include the bridge spend receipt".to_string(),
            )
        })?;
    let references_credit_id = transfer.memo.contains(credit_id);
    let references_finality_receipt_id =
        !finality_receipt_id.is_empty() && transfer.memo.contains(&finality_receipt_id);
    let references_credited_state_root = transfer.memo.contains(&credit_block.state_root);
    let spendable_under_finality_rule = finality_receipt.is_some()
        && transfer_receipt_status == "applied"
        && references_credit_id
        && references_finality_receipt_id
        && references_credited_state_root;

    if require_finality && !spendable_under_finality_rule {
        return Err(ConsensusValidationError::BridgeSpendReferenceInvalid(
            "transfer does not reference the credited finalized state".to_string(),
        ));
    }

    let finality = match finality_receipt {
        Some(receipt) => BridgeCreditFinalityEvidence {
            required: require_finality,
            status: "finalized-private-pilot".to_string(),
            finality_receipt_id: Some(receipt.finality_receipt_id.clone()),
            finalized_height: receipt.finalized_height,
            finalized_block_hash: receipt.finalized_block_hash.clone(),
            finalized_state_root: receipt.finalized_state_root.clone(),
            rule: receipt.finality_rule.clone(),
            private_pilot: true,
        },
        None => BridgeCreditFinalityEvidence {
            required: require_finality,
            status: "unfinalized-private-pilot".to_string(),
            finality_receipt_id: None,
            finalized_height: 0,
            finalized_block_hash: ZERO_HASH.to_string(),
            finalized_state_root: ZERO_HASH.to_string(),
            rule: state.consensus_state.finality_rule.clone(),
            private_pilot: true,
        },
    };

    let transfer_after_credit = BridgeSpendEvidence {
        transfer_id: transfer_id.to_string(),
        transfer_tx_id,
        transfer_block_number: transfer_block.block_number,
        transfer_block_hash: transfer_block.block_hash.clone(),
        transfer_receipt_status,
        references_credit_id,
        references_finality_receipt_id,
        references_credited_state_root,
        spendable_under_finality_rule,
    };

    let evidence_id = hash_json(
        "flowmemory.local_devnet.bridge_lifecycle_evidence_id.v0",
        &serde_json::json!({
            "creditId": credit_id,
            "creditBlockHash": credit_block.block_hash,
            "transferId": transfer_id,
            "transferBlockHash": transfer_after_credit.transfer_block_hash,
            "finalityReceiptId": finality.finality_receipt_id
        }),
    );

    Ok(BridgeLifecycleEvidence {
        schema: BRIDGE_LIFECYCLE_EVIDENCE_SCHEMA.to_string(),
        evidence_id,
        credit_id: credit_id.to_string(),
        credit_tx_id,
        credit_included_in_block: credit_block.block_number,
        credit_block_hash: credit_block.block_hash.clone(),
        credit_receipt_status,
        block_hash_includes_credit_tx_and_receipt,
        state_root_before_credit,
        state_root_after_credit: credit_block.state_root.clone(),
        state_root_changed_after_credit,
        finality,
        transfer_after_credit,
        result: "accepted-private-pilot-finality".to_string(),
    })
}

pub fn validate_chain(state: &ChainState) -> ConsensusValidationReport {
    let mut errors = Vec::new();
    let mut cursor = genesis_state();
    cursor.validator_set = state.validator_set.clone();
    cursor.authority_set = state.authority_set.clone();
    cursor.consensus_state.finalized_height = 0;
    cursor.consensus_state.finalized_hash = GENESIS_HASH.to_string();
    cursor.consensus_state.finalized_state_root = state_root(&cursor);

    for block in &state.blocks {
        if let Err(error) = validate_block_header(&cursor, block) {
            errors.push(error.to_string());
        }
        cursor.parent_hash = block.block_hash.clone();
        cursor.next_block_number = block.block_number + 1;
        cursor.logical_time = block.logical_time + 1;
        cursor.blocks.push(block.clone());
    }

    if let Some(last) = state.blocks.last() {
        let current_state_root = state_root(state);
        if last.state_root != current_state_root {
            errors.push(format!(
                "latest block state root {} does not match current state root {}",
                last.state_root, current_state_root
            ));
        }
        if state.consensus_state.canonical_head_hash != last.block_hash {
            errors.push(format!(
                "canonical head {} does not match latest block {}",
                state.consensus_state.canonical_head_hash, last.block_hash
            ));
        }
    }
    if state.consensus_state.finalized_height > state.consensus_state.canonical_height {
        errors.push("finalized height exceeds canonical height".to_string());
    }
    let mut finality_targets = BTreeSet::new();
    for receipt in state.chain_finality_receipts.values() {
        let key = (
            receipt.finalized_height,
            receipt.finalized_block_hash.clone(),
        );
        if !finality_targets.insert(key) {
            errors.push(format!(
                "duplicate finality receipt for block {} hash {}",
                receipt.finalized_height, receipt.finalized_block_hash
            ));
        }
        match state.blocks.iter().find(|block| {
            block.block_number == receipt.finalized_height
                && block.block_hash == receipt.finalized_block_hash
        }) {
            Some(block) => {
                if receipt.finalized_state_root != block.state_root {
                    errors.push(format!(
                        "finality receipt {} state root {} does not cover block state root {}",
                        receipt.finality_receipt_id, receipt.finalized_state_root, block.state_root
                    ));
                }
                if receipt.certificate.block_hash != block.block_hash
                    || receipt.certificate.state_root != block.state_root
                    || receipt.certificate.block_height != block.block_number
                {
                    errors.push(format!(
                        "finality certificate {} does not cover block {}",
                        receipt.certificate.certificate_id, block.block_hash
                    ));
                }
            }
            None => errors.push(format!(
                "finality receipt {} points at unknown block {} hash {}",
                receipt.finality_receipt_id, receipt.finalized_height, receipt.finalized_block_hash
            )),
        }
    }
    if let Some(latest_id) = &state.consensus_state.latest_finality_receipt_id
        && !state.chain_finality_receipts.contains_key(latest_id)
    {
        errors.push(format!("latest finality receipt is missing: {latest_id}"));
    }
    ConsensusValidationReport {
        schema: "flowmemory.local_devnet.consensus_validation_report.v0".to_string(),
        valid: errors.is_empty(),
        checked_blocks: state.blocks.len(),
        canonical_head_hash: state.consensus_state.canonical_head_hash.clone(),
        finalized_height: state.consensus_state.finalized_height,
        finalized_hash: state.consensus_state.finalized_hash.clone(),
        finalized_state_root: state.consensus_state.finalized_state_root.clone(),
        consensus_state_root: consensus_state_root(state),
        errors,
    }
}

pub fn choose_canonical_fork(parent_state: &ChainState, candidates: &[Block]) -> ForkChoiceOutcome {
    let mut valid = Vec::new();
    let mut rejected = Vec::new();
    for block in candidates {
        match validate_block_header(parent_state, block) {
            Ok(()) => valid.push(block.clone()),
            Err(error) => rejected.push(fork_evidence(
                "rejected-invalid-branch",
                block,
                &error.to_string(),
                &parent_state.consensus_state.canonical_head_hash,
                parent_state.logical_time,
            )),
        }
    }
    valid.sort_by(|left, right| {
        right
            .block_number
            .cmp(&left.block_number)
            .then_with(|| left.block_hash.cmp(&right.block_hash))
    });
    let canonical_head = valid.first().cloned();
    if let Some(canonical) = &canonical_head {
        for block in valid.iter().skip(1) {
            rejected.push(fork_evidence(
                "orphaned-valid-branch",
                block,
                "lower deterministic fork-choice score",
                &canonical.block_hash,
                parent_state.logical_time,
            ));
        }
    }
    ForkChoiceOutcome {
        schema: "flowmemory.local_devnet.fork_choice_outcome.v0".to_string(),
        canonical_head,
        rejected,
    }
}

pub fn record_fork_choice_evidence(state: &mut ChainState, outcome: &ForkChoiceOutcome) {
    state.fork_evidence.extend(outcome.rejected.clone());
}

pub fn record_block_validation(
    state: &mut ChainState,
    block: &Block,
) -> Result<(), ConsensusValidationError> {
    match validate_block_header(state, block) {
        Ok(()) => Ok(()),
        Err(error) => {
            let detail = error.to_string();
            state.fork_evidence.push(fork_evidence(
                "rejected-invalid-branch",
                block,
                &detail,
                &state.consensus_state.canonical_head_hash,
                state.logical_time,
            ));
            state.misbehavior_evidence.push(misbehavior_evidence(
                misbehavior_kind(&error),
                block,
                &detail,
                state.logical_time,
            ));
            Err(error)
        }
    }
}

pub fn record_block_proposal_validation(
    state: &mut ChainState,
    proposal: &BlockProposal,
) -> Result<(), ConsensusValidationError> {
    match validate_block_proposal(state, proposal) {
        Ok(()) => Ok(()),
        Err(error) => {
            let detail = error.to_string();
            state.fork_evidence.push(fork_evidence(
                "rejected-invalid-branch",
                &proposal.block,
                &detail,
                &state.consensus_state.canonical_head_hash,
                state.logical_time,
            ));
            state.misbehavior_evidence.push(misbehavior_evidence(
                misbehavior_kind(&error),
                &proposal.block,
                &detail,
                state.logical_time,
            ));
            Err(error)
        }
    }
}

pub fn record_duplicate_proposal_evidence(state: &mut ChainState, first: &Block, second: &Block) {
    if first.proposer_id == second.proposer_id
        && first.block_number == second.block_number
        && first.block_hash != second.block_hash
    {
        state.misbehavior_evidence.push(misbehavior_evidence(
            "duplicate_proposal_same_height",
            second,
            &format!(
                "proposer {} produced competing blocks {} and {} at height {}",
                second.proposer_id, first.block_hash, second.block_hash, second.block_number
            ),
            state.logical_time,
        ));
    }
}

fn fork_evidence(
    kind: &str,
    block: &Block,
    reason: &str,
    canonical_head_hash: &str,
    observed_at_logical_time: u64,
) -> ForkEvidence {
    let evidence_id = hash_json(
        "flowmemory.local_devnet.fork_evidence_id.v0",
        &serde_json::json!({
            "kind": kind,
            "blockHash": block.block_hash,
            "reason": reason,
            "canonicalHeadHash": canonical_head_hash
        }),
    );
    ForkEvidence {
        schema: FORK_EVIDENCE_SCHEMA.to_string(),
        evidence_id,
        kind: kind.to_string(),
        block_hash: block.block_hash.clone(),
        block_height: block.block_number,
        parent_hash: block.parent_hash.clone(),
        reason: reason.to_string(),
        canonical_head_hash: canonical_head_hash.to_string(),
        observed_at_logical_time,
    }
}

fn misbehavior_kind(error: &ConsensusValidationError) -> &'static str {
    match error {
        ConsensusValidationError::WrongChainId { .. } => "wrong_chain_id",
        ConsensusValidationError::WrongGenesisHash { .. } => "wrong_genesis_hash",
        ConsensusValidationError::InvalidParent { .. } => "invalid_parent",
        ConsensusValidationError::InvalidProposer(_) => "invalid_proposer",
        ConsensusValidationError::RootMismatch { root_name, .. } if root_name == "stateRoot" => {
            "invalid_state_root"
        }
        ConsensusValidationError::RootMismatch { .. } => "invalid_root",
        ConsensusValidationError::DuplicateTransaction(_) => "duplicate_transaction",
        ConsensusValidationError::FinalizedConflict { .. } => "finalized_conflict",
        _ => "invalid_block",
    }
}

fn misbehavior_evidence(
    kind: &str,
    block: &Block,
    detail: &str,
    observed_at_logical_time: u64,
) -> MisbehaviorEvidence {
    let evidence_id = hash_json(
        "flowmemory.local_devnet.misbehavior_evidence_id.v0",
        &serde_json::json!({
            "kind": kind,
            "blockHash": block.block_hash,
            "blockHeight": block.block_number,
            "proposerId": block.proposer_id,
            "detail": detail
        }),
    );
    MisbehaviorEvidence {
        schema: MISBEHAVIOR_EVIDENCE_SCHEMA.to_string(),
        evidence_id,
        kind: kind.to_string(),
        block_hash: block.block_hash.clone(),
        block_height: block.block_number,
        proposer_id: block.proposer_id.clone(),
        detail: detail.to_string(),
        observed_at_logical_time,
    }
}

fn apply_local_test_unit_transfer(
    state: &mut ChainState,
    transfer_id: &str,
    from_account_id: &str,
    to_account_id: &str,
    amount_units: u64,
    memo: &str,
) -> Result<(), DevnetError> {
    if state.balance_transfers.contains_key(transfer_id) {
        return Err(DevnetError::BalanceTransferAlreadyExists(
            transfer_id.to_string(),
        ));
    }
    if amount_units == 0 {
        return Err(DevnetError::FaucetAmountMustBePositive(
            transfer_id.to_string(),
        ));
    }

    let from_balance = state
        .local_test_unit_balances
        .get(from_account_id)
        .ok_or_else(|| DevnetError::LocalTestUnitBalanceMissing(from_account_id.to_string()))?;
    if from_balance.units < amount_units {
        return Err(DevnetError::LocalTestUnitBalanceInsufficient(
            from_account_id.to_string(),
        ));
    }

    {
        let from_balance = state
            .local_test_unit_balances
            .get_mut(from_account_id)
            .expect("source local test-unit balance was checked above");
        from_balance.units -= amount_units;
        from_balance.updated_at_block = state.next_block_number;
    }

    let to_balance = state
        .local_test_unit_balances
        .get_mut(to_account_id)
        .ok_or_else(|| DevnetError::LocalTestUnitBalanceMissing(to_account_id.to_string()))?;
    to_balance.units = to_balance
        .units
        .checked_add(amount_units)
        .ok_or_else(|| DevnetError::LocalTestUnitBalanceOverflow(to_account_id.to_string()))?;
    to_balance.updated_at_block = state.next_block_number;

    state.balance_transfers.insert(
        transfer_id.to_string(),
        BalanceTransfer {
            transfer_id: transfer_id.to_string(),
            from_account_id: from_account_id.to_string(),
            to_account_id: to_account_id.to_string(),
            amount_units,
            memo: memo.to_string(),
            transferred_at_block: state.next_block_number,
            no_value: true,
        },
    );
    Ok(())
}

fn ensure_bridge_credit_spendable(
    state: &ChainState,
    credit_id: &str,
    finality_receipt_id: &str,
    credited_block_hash: &str,
    credited_state_root: &str,
    from_account_id: &str,
    amount_units: u64,
) -> Result<(), DevnetError> {
    let credit = state
        .bridge_credits
        .get(credit_id)
        .ok_or_else(|| DevnetError::BridgeCreditMissing(credit_id.to_string()))?;
    if credit.recipient_account_id != from_account_id {
        return Err(DevnetError::BridgeSpendReferenceInvalid(
            "bridge credit recipient does not match spend source".to_string(),
        ));
    }
    if amount_units > credit.amount_units {
        return Err(DevnetError::BridgeSpendReferenceInvalid(
            "bridge spend exceeds credited amount".to_string(),
        ));
    }
    let receipt = state
        .chain_finality_receipts
        .get(finality_receipt_id)
        .ok_or_else(|| {
            DevnetError::BridgeFinalityReceiptMissing(finality_receipt_id.to_string())
        })?;
    if receipt.finalized_height < credit.credited_at_block
        || receipt.finalized_block_hash != credited_block_hash
        || receipt.finalized_state_root != credited_state_root
    {
        return Err(DevnetError::BridgeCreditNotFinal(credit_id.to_string()));
    }
    if !matches!(
        receipt.finality_rule.to_ascii_lowercase().as_str(),
        rule if rule.contains("finalizes") || rule.contains("finality")
    ) {
        return Err(DevnetError::BridgeCreditNotFinal(credit_id.to_string()));
    }
    Ok(())
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
        Transaction::TransferLocalTestUnits {
            transfer_id,
            from_account_id,
            to_account_id,
            amount_units,
            memo,
        } => {
            apply_local_test_unit_transfer(
                state,
                transfer_id,
                from_account_id,
                to_account_id,
                *amount_units,
                memo,
            )?;
        }
        Transaction::LaunchToken {
            token_id,
            symbol,
            name,
            decimals,
            initial_owner_account_id,
            initial_supply_units,
        } => {
            let normalized_symbol = normalize_token_symbol(symbol);
            ensure_expected_id(
                "token",
                token_id,
                &deterministic_token_id(&normalized_symbol),
            )?;
            if *initial_supply_units == 0 {
                return Err(DevnetError::TokenAmountMustBePositive(token_id.clone()));
            }
            if !state
                .local_test_unit_balances
                .contains_key(initial_owner_account_id)
            {
                return Err(DevnetError::LocalTestUnitBalanceMissing(
                    initial_owner_account_id.clone(),
                ));
            }
            if state.token_definitions.contains_key(token_id) {
                return Err(DevnetError::TokenAlreadyExists(token_id.clone()));
            }
            if state
                .token_definitions
                .values()
                .any(|token| token.symbol == normalized_symbol)
            {
                return Err(DevnetError::TokenSymbolAlreadyExists(normalized_symbol));
            }

            state.token_definitions.insert(
                token_id.clone(),
                LocalTestToken {
                    token_id: token_id.clone(),
                    symbol: normalize_token_symbol(symbol),
                    name: name.clone(),
                    decimals: *decimals,
                    launcher_account_id: initial_owner_account_id.clone(),
                    total_supply_units: *initial_supply_units,
                    launched_at_block: state.next_block_number,
                    no_value: true,
                },
            );
            credit_asset_units(
                state,
                initial_owner_account_id,
                token_id,
                *initial_supply_units,
            )?;
            let mint_id = deterministic_token_mint_id(
                token_id,
                initial_owner_account_id,
                *initial_supply_units,
                "initial-supply",
            );
            state.token_mint_receipts.insert(
                mint_id.clone(),
                LocalTestTokenMintReceipt {
                    mint_id,
                    token_id: token_id.clone(),
                    to_account_id: initial_owner_account_id.clone(),
                    amount_units: *initial_supply_units,
                    reason: "initial-supply".to_string(),
                    minted_at_block: state.next_block_number,
                    no_value: true,
                },
            );
        }
        Transaction::MintLocalTestToken {
            mint_id,
            token_id,
            to_account_id,
            amount_units,
            reason,
        } => {
            ensure_expected_id(
                "token mint",
                mint_id,
                &deterministic_token_mint_id(token_id, to_account_id, *amount_units, reason),
            )?;
            if *amount_units == 0 {
                return Err(DevnetError::TokenAmountMustBePositive(mint_id.clone()));
            }
            if !state.local_test_unit_balances.contains_key(to_account_id) {
                return Err(DevnetError::LocalTestUnitBalanceMissing(
                    to_account_id.clone(),
                ));
            }
            if state.token_mint_receipts.contains_key(mint_id) {
                return Err(DevnetError::TokenMintAlreadyExists(mint_id.clone()));
            }
            let current_supply = state
                .token_definitions
                .get(token_id)
                .ok_or_else(|| DevnetError::TokenMissing(token_id.clone()))?
                .total_supply_units
                .checked_add(*amount_units)
                .ok_or_else(|| DevnetError::TokenBalanceOverflow(token_id.clone()))?;
            credit_asset_units(state, to_account_id, token_id, *amount_units)?;
            state
                .token_definitions
                .get_mut(token_id)
                .expect("token was checked before mint")
                .total_supply_units = current_supply;
            state.token_mint_receipts.insert(
                mint_id.clone(),
                LocalTestTokenMintReceipt {
                    mint_id: mint_id.clone(),
                    token_id: token_id.clone(),
                    to_account_id: to_account_id.clone(),
                    amount_units: *amount_units,
                    reason: reason.clone(),
                    minted_at_block: state.next_block_number,
                    no_value: true,
                },
            );
        }
        Transaction::CreatePool {
            pool_id,
            base_asset_id,
            quote_asset_id,
            created_by_account_id,
        } => {
            ensure_expected_id(
                "pool",
                pool_id,
                &deterministic_pool_id(base_asset_id, quote_asset_id),
            )?;
            ensure_pool_assets_are_valid(state, base_asset_id, quote_asset_id)?;
            if !state
                .local_test_unit_balances
                .contains_key(created_by_account_id)
            {
                return Err(DevnetError::LocalTestUnitBalanceMissing(
                    created_by_account_id.clone(),
                ));
            }
            if state.dex_pools.contains_key(pool_id) {
                return Err(DevnetError::PoolAlreadyExists(pool_id.clone()));
            }
            state.dex_pools.insert(
                pool_id.clone(),
                DexPool {
                    pool_id: pool_id.clone(),
                    base_asset_id: base_asset_id.clone(),
                    quote_asset_id: quote_asset_id.clone(),
                    created_by_account_id: created_by_account_id.clone(),
                    reserve_base_units: 0,
                    reserve_quote_units: 0,
                    total_lp_units: 0,
                    created_at_block: state.next_block_number,
                    updated_at_block: state.next_block_number,
                    last_liquidity_receipt_id: None,
                    last_swap_receipt_id: None,
                    no_value: true,
                },
            );
        }
        Transaction::AddLiquidity {
            liquidity_id,
            pool_id,
            provider_account_id,
            base_amount_units,
            quote_amount_units,
            min_lp_units,
        } => {
            ensure_expected_id(
                "add liquidity",
                liquidity_id,
                &deterministic_liquidity_id(
                    pool_id,
                    provider_account_id,
                    "add",
                    &format!("{base_amount_units}:{quote_amount_units}:{min_lp_units}"),
                ),
            )?;
            if state.liquidity_receipts.contains_key(liquidity_id) {
                return Err(DevnetError::LiquidityReceiptAlreadyExists(
                    liquidity_id.clone(),
                ));
            }
            if *base_amount_units == 0 || *quote_amount_units == 0 {
                return Err(DevnetError::TokenAmountMustBePositive(liquidity_id.clone()));
            }
            let pool = state
                .dex_pools
                .get(pool_id)
                .ok_or_else(|| DevnetError::PoolMissing(pool_id.clone()))?;
            let reserve_base_before = pool.reserve_base_units;
            let reserve_quote_before = pool.reserve_quote_units;
            let total_lp_before = pool.total_lp_units;
            let lp_units = liquidity_units_for_add(pool, *base_amount_units, *quote_amount_units)?;
            if lp_units == 0 || lp_units < *min_lp_units {
                return Err(DevnetError::LiquidityBelowMinimum(liquidity_id.clone()));
            }
            ensure_asset_units_available(
                state,
                provider_account_id,
                &pool.base_asset_id,
                *base_amount_units,
            )?;
            ensure_asset_units_available(
                state,
                provider_account_id,
                &pool.quote_asset_id,
                *quote_amount_units,
            )?;
            let base_asset_id = pool.base_asset_id.clone();
            let quote_asset_id = pool.quote_asset_id.clone();

            debit_asset_units(
                state,
                provider_account_id,
                &base_asset_id,
                *base_amount_units,
            )?;
            debit_asset_units(
                state,
                provider_account_id,
                &quote_asset_id,
                *quote_amount_units,
            )?;

            let reserve_base_after =
                checked_pool_add(pool_id, reserve_base_before, *base_amount_units)?;
            let reserve_quote_after =
                checked_pool_add(pool_id, reserve_quote_before, *quote_amount_units)?;
            let total_lp_after = checked_pool_add(pool_id, total_lp_before, lp_units)?;
            let pool = state
                .dex_pools
                .get_mut(pool_id)
                .expect("pool was checked before liquidity mutation");
            pool.reserve_base_units = reserve_base_after;
            pool.reserve_quote_units = reserve_quote_after;
            pool.total_lp_units = total_lp_after;
            pool.updated_at_block = state.next_block_number;
            pool.last_liquidity_receipt_id = Some(liquidity_id.clone());

            let lp_position_id = deterministic_lp_position_id(pool_id, provider_account_id);
            let position = state
                .lp_positions
                .entry(lp_position_id.clone())
                .or_insert_with(|| LpPosition {
                    lp_position_id,
                    pool_id: pool_id.clone(),
                    owner_account_id: provider_account_id.clone(),
                    lp_units: 0,
                    base_units_deposited: 0,
                    quote_units_deposited: 0,
                    base_units_withdrawn: 0,
                    quote_units_withdrawn: 0,
                    updated_at_block: state.next_block_number,
                    no_value: true,
                });
            position.lp_units = position
                .lp_units
                .checked_add(lp_units)
                .ok_or_else(|| DevnetError::PoolReserveOverflow(pool_id.clone()))?;
            position.base_units_deposited = position
                .base_units_deposited
                .checked_add(*base_amount_units)
                .ok_or_else(|| DevnetError::PoolReserveOverflow(pool_id.clone()))?;
            position.quote_units_deposited = position
                .quote_units_deposited
                .checked_add(*quote_amount_units)
                .ok_or_else(|| DevnetError::PoolReserveOverflow(pool_id.clone()))?;
            position.updated_at_block = state.next_block_number;

            state.liquidity_receipts.insert(
                liquidity_id.clone(),
                LiquidityReceipt {
                    liquidity_id: liquidity_id.clone(),
                    pool_id: pool_id.clone(),
                    provider_account_id: provider_account_id.clone(),
                    action: "add".to_string(),
                    base_amount_units: *base_amount_units,
                    quote_amount_units: *quote_amount_units,
                    lp_units,
                    reserve_base_before,
                    reserve_quote_before,
                    reserve_base_after,
                    reserve_quote_after,
                    executed_at_block: state.next_block_number,
                    no_value: true,
                },
            );
        }
        Transaction::RemoveLiquidity {
            liquidity_id,
            pool_id,
            provider_account_id,
            lp_units,
            min_base_amount_units,
            min_quote_amount_units,
        } => {
            ensure_expected_id(
                "remove liquidity",
                liquidity_id,
                &deterministic_liquidity_id(
                    pool_id,
                    provider_account_id,
                    "remove",
                    &format!("{lp_units}:{min_base_amount_units}:{min_quote_amount_units}"),
                ),
            )?;
            if state.liquidity_receipts.contains_key(liquidity_id) {
                return Err(DevnetError::LiquidityReceiptAlreadyExists(
                    liquidity_id.clone(),
                ));
            }
            if *lp_units == 0 {
                return Err(DevnetError::TokenAmountMustBePositive(liquidity_id.clone()));
            }
            let pool = state
                .dex_pools
                .get(pool_id)
                .ok_or_else(|| DevnetError::PoolMissing(pool_id.clone()))?;
            let reserve_base_before = pool.reserve_base_units;
            let reserve_quote_before = pool.reserve_quote_units;
            if pool.total_lp_units == 0 {
                return Err(DevnetError::PoolReserveInsufficient(pool_id.clone()));
            }
            let lp_position_id = deterministic_lp_position_id(pool_id, provider_account_id);
            let position = state
                .lp_positions
                .get(&lp_position_id)
                .ok_or_else(|| DevnetError::LpPositionMissing(lp_position_id.clone()))?;
            if position.lp_units < *lp_units {
                return Err(DevnetError::LpPositionInsufficient(lp_position_id));
            }
            let base_amount_units =
                proportional_amount(reserve_base_before, *lp_units, pool.total_lp_units, pool_id)?;
            let quote_amount_units = proportional_amount(
                reserve_quote_before,
                *lp_units,
                pool.total_lp_units,
                pool_id,
            )?;
            if base_amount_units < *min_base_amount_units
                || quote_amount_units < *min_quote_amount_units
            {
                return Err(DevnetError::LiquidityBelowMinimum(liquidity_id.clone()));
            }
            let base_asset_id = pool.base_asset_id.clone();
            let quote_asset_id = pool.quote_asset_id.clone();
            let total_lp_before = pool.total_lp_units;

            {
                let position = state
                    .lp_positions
                    .get_mut(&deterministic_lp_position_id(pool_id, provider_account_id))
                    .expect("LP position was checked before liquidity mutation");
                position.lp_units -= *lp_units;
                position.base_units_withdrawn = position
                    .base_units_withdrawn
                    .checked_add(base_amount_units)
                    .ok_or_else(|| DevnetError::PoolReserveOverflow(pool_id.clone()))?;
                position.quote_units_withdrawn = position
                    .quote_units_withdrawn
                    .checked_add(quote_amount_units)
                    .ok_or_else(|| DevnetError::PoolReserveOverflow(pool_id.clone()))?;
                position.updated_at_block = state.next_block_number;
            }

            let reserve_base_after = reserve_base_before
                .checked_sub(base_amount_units)
                .ok_or_else(|| DevnetError::PoolReserveInsufficient(pool_id.clone()))?;
            let reserve_quote_after = reserve_quote_before
                .checked_sub(quote_amount_units)
                .ok_or_else(|| DevnetError::PoolReserveInsufficient(pool_id.clone()))?;
            let pool = state
                .dex_pools
                .get_mut(pool_id)
                .expect("pool was checked before liquidity mutation");
            pool.reserve_base_units = reserve_base_after;
            pool.reserve_quote_units = reserve_quote_after;
            pool.total_lp_units = total_lp_before
                .checked_sub(*lp_units)
                .ok_or_else(|| DevnetError::PoolReserveInsufficient(pool_id.clone()))?;
            pool.updated_at_block = state.next_block_number;
            pool.last_liquidity_receipt_id = Some(liquidity_id.clone());

            credit_asset_units(
                state,
                provider_account_id,
                &base_asset_id,
                base_amount_units,
            )?;
            credit_asset_units(
                state,
                provider_account_id,
                &quote_asset_id,
                quote_amount_units,
            )?;

            state.liquidity_receipts.insert(
                liquidity_id.clone(),
                LiquidityReceipt {
                    liquidity_id: liquidity_id.clone(),
                    pool_id: pool_id.clone(),
                    provider_account_id: provider_account_id.clone(),
                    action: "remove".to_string(),
                    base_amount_units,
                    quote_amount_units,
                    lp_units: *lp_units,
                    reserve_base_before,
                    reserve_quote_before,
                    reserve_base_after,
                    reserve_quote_after,
                    executed_at_block: state.next_block_number,
                    no_value: true,
                },
            );
        }
        Transaction::SwapExactIn {
            swap_id,
            pool_id,
            trader_account_id,
            asset_in_id,
            amount_in_units,
            min_amount_out_units,
        } => {
            ensure_expected_id(
                "swap",
                swap_id,
                &deterministic_swap_id(
                    pool_id,
                    trader_account_id,
                    asset_in_id,
                    *amount_in_units,
                    &min_amount_out_units.to_string(),
                ),
            )?;
            if state.swap_receipts.contains_key(swap_id) {
                return Err(DevnetError::SwapReceiptAlreadyExists(swap_id.clone()));
            }
            if *amount_in_units == 0 {
                return Err(DevnetError::TokenAmountMustBePositive(swap_id.clone()));
            }
            let pool = state
                .dex_pools
                .get(pool_id)
                .ok_or_else(|| DevnetError::PoolMissing(pool_id.clone()))?;
            let reserve_base_before = pool.reserve_base_units;
            let reserve_quote_before = pool.reserve_quote_units;
            let (asset_out_id, amount_out_units, reserve_base_after, reserve_quote_after) =
                if asset_in_id == &pool.base_asset_id {
                    let amount_out = quote_out_for_base_in(pool, *amount_in_units)?;
                    (
                        pool.quote_asset_id.clone(),
                        amount_out,
                        checked_pool_add(pool_id, reserve_base_before, *amount_in_units)?,
                        reserve_quote_before
                            .checked_sub(amount_out)
                            .ok_or_else(|| DevnetError::PoolReserveInsufficient(pool_id.clone()))?,
                    )
                } else if asset_in_id == &pool.quote_asset_id {
                    let amount_out = base_out_for_quote_in(pool, *amount_in_units)?;
                    (
                        pool.base_asset_id.clone(),
                        amount_out,
                        reserve_base_before
                            .checked_sub(amount_out)
                            .ok_or_else(|| DevnetError::PoolReserveInsufficient(pool_id.clone()))?,
                        checked_pool_add(pool_id, reserve_quote_before, *amount_in_units)?,
                    )
                } else {
                    return Err(DevnetError::PoolInvalidAsset(asset_in_id.clone()));
                };
            if amount_out_units == 0 || amount_out_units < *min_amount_out_units {
                return Err(DevnetError::SwapSlippageExceeded(swap_id.clone()));
            }
            ensure_asset_units_available(state, trader_account_id, asset_in_id, *amount_in_units)?;

            debit_asset_units(state, trader_account_id, asset_in_id, *amount_in_units)?;
            credit_asset_units(state, trader_account_id, &asset_out_id, amount_out_units)?;

            let pool = state
                .dex_pools
                .get_mut(pool_id)
                .expect("pool was checked before swap mutation");
            pool.reserve_base_units = reserve_base_after;
            pool.reserve_quote_units = reserve_quote_after;
            pool.updated_at_block = state.next_block_number;
            pool.last_swap_receipt_id = Some(swap_id.clone());

            state.swap_receipts.insert(
                swap_id.clone(),
                SwapReceipt {
                    swap_id: swap_id.clone(),
                    pool_id: pool_id.clone(),
                    trader_account_id: trader_account_id.clone(),
                    asset_in_id: asset_in_id.clone(),
                    asset_out_id,
                    amount_in_units: *amount_in_units,
                    amount_out_units,
                    reserve_base_before,
                    reserve_quote_before,
                    reserve_base_after,
                    reserve_quote_after,
                    executed_at_block: state.next_block_number,
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
        Transaction::RecordBridgeReplayKey {
            replay_key,
            source_chain_id,
            source_tx_hash,
            source_log_index,
            local_object_id,
        } => {
            if state.bridge_replay_keys.contains_key(replay_key) {
                return Err(DevnetError::BridgeReplayKeyAlreadyUsed(replay_key.clone()));
            }
            state.bridge_replay_keys.insert(
                replay_key.clone(),
                BridgeReplayKeyRecord {
                    schema: BRIDGE_REPLAY_KEY_SCHEMA.to_string(),
                    replay_key: replay_key.clone(),
                    source_chain_id: source_chain_id.clone(),
                    source_tx_hash: source_tx_hash.clone(),
                    source_log_index: source_log_index.clone(),
                    local_object_id: local_object_id.clone(),
                    status: "accepted-replay-guard".to_string(),
                    first_seen_block: state.next_block_number,
                    finalized_at_height: None,
                },
            );
        }
        Transaction::ApplyBridgeCredit {
            credit_id,
            replay_key,
            source_chain_id,
            source_tx_hash,
            source_log_index,
            recipient_account_id,
            amount_units,
            evidence_hash,
        } => {
            if *amount_units == 0 {
                return Err(DevnetError::BridgeCreditAmountMustBePositive(
                    credit_id.clone(),
                ));
            }
            if state.bridge_credits.contains_key(credit_id) {
                return Err(DevnetError::BridgeCreditAlreadyExists(credit_id.clone()));
            }
            if state.bridge_replay_keys.contains_key(replay_key) {
                return Err(DevnetError::BridgeReplayKeyAlreadyUsed(replay_key.clone()));
            }
            let credited_at_block = state.next_block_number;
            let balance = state
                .local_test_unit_balances
                .entry(recipient_account_id.clone())
                .or_insert_with(|| LocalTestUnitBalance {
                    account_id: recipient_account_id.clone(),
                    owner: "bridge-credit-recipient".to_string(),
                    units: 0,
                    total_faucet_units: 0,
                    last_faucet_record_id: None,
                    updated_at_block: credited_at_block,
                    no_value: true,
                });
            balance.units = balance.units.checked_add(*amount_units).ok_or_else(|| {
                DevnetError::LocalTestUnitBalanceOverflow(recipient_account_id.clone())
            })?;
            balance.updated_at_block = credited_at_block;
            state.bridge_replay_keys.insert(
                replay_key.clone(),
                BridgeReplayKeyRecord {
                    schema: BRIDGE_REPLAY_KEY_SCHEMA.to_string(),
                    replay_key: replay_key.clone(),
                    source_chain_id: source_chain_id.clone(),
                    source_tx_hash: source_tx_hash.clone(),
                    source_log_index: source_log_index.clone(),
                    local_object_id: credit_id.clone(),
                    status: "accepted-in-block-awaits-finality-check".to_string(),
                    first_seen_block: credited_at_block,
                    finalized_at_height: None,
                },
            );
            state.bridge_credits.insert(
                credit_id.clone(),
                BridgeCreditRecord {
                    schema: BRIDGE_CREDIT_SCHEMA.to_string(),
                    credit_id: credit_id.clone(),
                    replay_key: replay_key.clone(),
                    source_chain_id: source_chain_id.clone(),
                    source_tx_hash: source_tx_hash.clone(),
                    source_log_index: source_log_index.clone(),
                    recipient_account_id: recipient_account_id.clone(),
                    amount_units: *amount_units,
                    evidence_hash: evidence_hash.clone(),
                    credited_at_block,
                    status: "accepted-in-block-not-public-final".to_string(),
                    finality_required: true,
                    local_only: true,
                    production_ready: false,
                },
            );
        }
        Transaction::SpendBridgeCreditLocalTestUnits {
            transfer_id,
            credit_id,
            finality_receipt_id,
            credited_block_hash,
            credited_state_root,
            from_account_id,
            to_account_id,
            amount_units,
            memo,
        } => {
            ensure_bridge_credit_spendable(
                state,
                credit_id,
                finality_receipt_id,
                credited_block_hash,
                credited_state_root,
                from_account_id,
                *amount_units,
            )?;
            if !memo.contains(credit_id)
                || !memo.contains(finality_receipt_id)
                || !memo.contains(credited_state_root)
            {
                return Err(DevnetError::BridgeSpendReferenceInvalid(
                    "memo must reference credit id, finality receipt id, and credited state root"
                        .to_string(),
                ));
            }
            apply_local_test_unit_transfer(
                state,
                transfer_id,
                from_account_id,
                to_account_id,
                *amount_units,
                memo,
            )?;
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

fn ensure_expected_id(kind: &str, actual: &str, expected: &str) -> Result<(), DevnetError> {
    if actual != expected {
        return Err(DevnetError::DeterministicIdMismatch {
            kind: kind.to_string(),
            expected: expected.to_string(),
            actual: actual.to_string(),
        });
    }
    Ok(())
}

fn ensure_pool_assets_are_valid(
    state: &ChainState,
    base_asset_id: &str,
    quote_asset_id: &str,
) -> Result<(), DevnetError> {
    if base_asset_id == quote_asset_id {
        return Err(DevnetError::PoolInvalidAsset(base_asset_id.to_string()));
    }
    ensure_asset_exists(state, base_asset_id)?;
    ensure_asset_exists(state, quote_asset_id)?;
    Ok(())
}

fn ensure_asset_exists(state: &ChainState, asset_id: &str) -> Result<(), DevnetError> {
    if asset_id == LOCAL_TEST_UNIT_ASSET_ID || state.token_definitions.contains_key(asset_id) {
        return Ok(());
    }
    Err(DevnetError::TokenMissing(asset_id.to_string()))
}

fn ensure_asset_units_available(
    state: &ChainState,
    account_id: &str,
    asset_id: &str,
    amount_units: u64,
) -> Result<(), DevnetError> {
    let available = asset_units(state, account_id, asset_id)?;
    if available < amount_units {
        if asset_id == LOCAL_TEST_UNIT_ASSET_ID {
            return Err(DevnetError::LocalTestUnitBalanceInsufficient(
                account_id.to_string(),
            ));
        }
        return Err(DevnetError::TokenBalanceInsufficient(
            deterministic_token_balance_id(asset_id, account_id),
        ));
    }
    Ok(())
}

fn asset_units(state: &ChainState, account_id: &str, asset_id: &str) -> Result<u64, DevnetError> {
    if asset_id == LOCAL_TEST_UNIT_ASSET_ID {
        return state
            .local_test_unit_balances
            .get(account_id)
            .map(|balance| balance.units)
            .ok_or_else(|| DevnetError::LocalTestUnitBalanceMissing(account_id.to_string()));
    }
    ensure_asset_exists(state, asset_id)?;
    let balance_id = deterministic_token_balance_id(asset_id, account_id);
    Ok(state
        .token_balances
        .get(&balance_id)
        .map(|balance| balance.units)
        .unwrap_or(0))
}

fn debit_asset_units(
    state: &mut ChainState,
    account_id: &str,
    asset_id: &str,
    amount_units: u64,
) -> Result<(), DevnetError> {
    ensure_asset_units_available(state, account_id, asset_id, amount_units)?;
    if asset_id == LOCAL_TEST_UNIT_ASSET_ID {
        let balance = state
            .local_test_unit_balances
            .get_mut(account_id)
            .ok_or_else(|| DevnetError::LocalTestUnitBalanceMissing(account_id.to_string()))?;
        balance.units -= amount_units;
        balance.updated_at_block = state.next_block_number;
        return Ok(());
    }

    let balance_id = deterministic_token_balance_id(asset_id, account_id);
    let balance = state
        .token_balances
        .get_mut(&balance_id)
        .ok_or_else(|| DevnetError::TokenBalanceInsufficient(balance_id.clone()))?;
    balance.units -= amount_units;
    balance.updated_at_block = state.next_block_number;
    Ok(())
}

fn credit_asset_units(
    state: &mut ChainState,
    account_id: &str,
    asset_id: &str,
    amount_units: u64,
) -> Result<(), DevnetError> {
    if amount_units == 0 {
        return Err(DevnetError::TokenAmountMustBePositive(asset_id.to_string()));
    }
    if asset_id == LOCAL_TEST_UNIT_ASSET_ID {
        let balance = state
            .local_test_unit_balances
            .get_mut(account_id)
            .ok_or_else(|| DevnetError::LocalTestUnitBalanceMissing(account_id.to_string()))?;
        balance.units = balance
            .units
            .checked_add(amount_units)
            .ok_or_else(|| DevnetError::LocalTestUnitBalanceOverflow(account_id.to_string()))?;
        balance.updated_at_block = state.next_block_number;
        return Ok(());
    }

    ensure_asset_exists(state, asset_id)?;
    let balance_id = deterministic_token_balance_id(asset_id, account_id);
    let balance = state
        .token_balances
        .entry(balance_id.clone())
        .or_insert_with(|| LocalTestTokenBalance {
            token_balance_id: balance_id,
            token_id: asset_id.to_string(),
            account_id: account_id.to_string(),
            units: 0,
            updated_at_block: state.next_block_number,
            no_value: true,
        });
    balance.units = balance
        .units
        .checked_add(amount_units)
        .ok_or_else(|| DevnetError::TokenBalanceOverflow(balance.token_balance_id.clone()))?;
    balance.updated_at_block = state.next_block_number;
    Ok(())
}

fn checked_pool_add(pool_id: &str, left: u64, right: u64) -> Result<u64, DevnetError> {
    left.checked_add(right)
        .ok_or_else(|| DevnetError::PoolReserveOverflow(pool_id.to_string()))
}

fn liquidity_units_for_add(
    pool: &DexPool,
    base_amount_units: u64,
    quote_amount_units: u64,
) -> Result<u64, DevnetError> {
    if pool.total_lp_units == 0 {
        return Ok(base_amount_units.min(quote_amount_units));
    }
    if pool.reserve_base_units == 0 || pool.reserve_quote_units == 0 {
        return Err(DevnetError::PoolReserveInsufficient(pool.pool_id.clone()));
    }
    let by_base = (base_amount_units as u128)
        .checked_mul(pool.total_lp_units as u128)
        .ok_or_else(|| DevnetError::PoolReserveOverflow(pool.pool_id.clone()))?
        / pool.reserve_base_units as u128;
    let by_quote = (quote_amount_units as u128)
        .checked_mul(pool.total_lp_units as u128)
        .ok_or_else(|| DevnetError::PoolReserveOverflow(pool.pool_id.clone()))?
        / pool.reserve_quote_units as u128;
    u64::try_from(by_base.min(by_quote))
        .map_err(|_| DevnetError::PoolReserveOverflow(pool.pool_id.clone()))
}

fn proportional_amount(
    reserve_units: u64,
    lp_units: u64,
    total_lp_units: u64,
    pool_id: &str,
) -> Result<u64, DevnetError> {
    if total_lp_units == 0 {
        return Err(DevnetError::PoolReserveInsufficient(pool_id.to_string()));
    }
    let amount = (reserve_units as u128)
        .checked_mul(lp_units as u128)
        .ok_or_else(|| DevnetError::PoolReserveOverflow(pool_id.to_string()))?
        / total_lp_units as u128;
    u64::try_from(amount).map_err(|_| DevnetError::PoolReserveOverflow(pool_id.to_string()))
}

fn quote_out_for_base_in(pool: &DexPool, amount_in_units: u64) -> Result<u64, DevnetError> {
    constant_product_out(
        pool.reserve_base_units,
        pool.reserve_quote_units,
        amount_in_units,
        &pool.pool_id,
    )
}

fn base_out_for_quote_in(pool: &DexPool, amount_in_units: u64) -> Result<u64, DevnetError> {
    constant_product_out(
        pool.reserve_quote_units,
        pool.reserve_base_units,
        amount_in_units,
        &pool.pool_id,
    )
}

fn constant_product_out(
    reserve_in_units: u64,
    reserve_out_units: u64,
    amount_in_units: u64,
    pool_id: &str,
) -> Result<u64, DevnetError> {
    if reserve_in_units == 0 || reserve_out_units == 0 {
        return Err(DevnetError::PoolReserveInsufficient(pool_id.to_string()));
    }
    let numerator = (reserve_out_units as u128)
        .checked_mul(amount_in_units as u128)
        .ok_or_else(|| DevnetError::PoolReserveOverflow(pool_id.to_string()))?;
    let denominator = (reserve_in_units as u128)
        .checked_add(amount_in_units as u128)
        .ok_or_else(|| DevnetError::PoolReserveOverflow(pool_id.to_string()))?;
    u64::try_from(numerator / denominator)
        .map_err(|_| DevnetError::PoolReserveOverflow(pool_id.to_string()))
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
        balance_transfer_root: &'a str,
        token_definition_root: &'a str,
        token_balance_root: &'a str,
        token_mint_receipt_root: &'a str,
        dex_pool_root: &'a str,
        lp_position_root: &'a str,
        liquidity_receipt_root: &'a str,
        swap_receipt_root: &'a str,
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
            balance_transfer_root: &roots.balance_transfer_root,
            token_definition_root: &roots.token_definition_root,
            token_balance_root: &roots.token_balance_root,
            token_mint_receipt_root: &roots.token_mint_receipt_root,
            dex_pool_root: &roots.dex_pool_root,
            lp_position_root: &roots.lp_position_root,
            liquidity_receipt_root: &roots.liquidity_receipt_root,
            swap_receipt_root: &roots.swap_receipt_root,
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
        balance_transfer_root: roots.balance_transfer_root,
        token_definition_root: roots.token_definition_root,
        token_balance_root: roots.token_balance_root,
        token_mint_receipt_root: roots.token_mint_receipt_root,
        dex_pool_root: roots.dex_pool_root,
        lp_position_root: roots.lp_position_root,
        liquidity_receipt_root: roots.liquidity_receipt_root,
        swap_receipt_root: roots.swap_receipt_root,
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

pub fn product_demo_transactions() -> Vec<Transaction> {
    let alice = "local-account:product:alice".to_string();
    let bob = "local-account:product:bob".to_string();
    let token_id = deterministic_token_id("FLOWT");
    let pool_id = deterministic_pool_id(LOCAL_TEST_UNIT_ASSET_ID, &token_id);
    let add_liquidity_id = deterministic_liquidity_id(
        &pool_id,
        &alice,
        "add",
        &format!("{}:{}:{}", 5_000_u64, 500_000_u64, 1_u64),
    );
    let swap_id = deterministic_swap_id(
        &pool_id,
        &bob,
        LOCAL_TEST_UNIT_ASSET_ID,
        100,
        &9_000_u64.to_string(),
    );
    let remove_liquidity_id = deterministic_liquidity_id(
        &pool_id,
        &alice,
        "remove",
        &format!("{}:{}:{}", 100_u64, 1_u64, 1_u64),
    );

    vec![
        Transaction::CreateLocalTestUnitBalance {
            account_id: alice.clone(),
            owner: "operator:product:alice".to_string(),
        },
        Transaction::CreateLocalTestUnitBalance {
            account_id: bob.clone(),
            owner: "operator:product:bob".to_string(),
        },
        Transaction::FaucetLocalTestUnits {
            faucet_record_id: "faucet:product:alice".to_string(),
            account_id: alice.clone(),
            recipient: "operator:product:alice".to_string(),
            amount_units: 10_000,
            reason: "product-smoke-no-value-test-units".to_string(),
        },
        Transaction::FaucetLocalTestUnits {
            faucet_record_id: "faucet:product:bob".to_string(),
            account_id: bob.clone(),
            recipient: "operator:product:bob".to_string(),
            amount_units: 1_000,
            reason: "product-smoke-no-value-test-units".to_string(),
        },
        Transaction::LaunchToken {
            token_id: token_id.clone(),
            symbol: "FLOWT".to_string(),
            name: "FlowChain Product Test Token".to_string(),
            decimals: 6,
            initial_owner_account_id: alice.clone(),
            initial_supply_units: 1_000_000,
        },
        Transaction::CreatePool {
            pool_id: pool_id.clone(),
            base_asset_id: LOCAL_TEST_UNIT_ASSET_ID.to_string(),
            quote_asset_id: token_id.clone(),
            created_by_account_id: alice.clone(),
        },
        Transaction::AddLiquidity {
            liquidity_id: add_liquidity_id,
            pool_id: pool_id.clone(),
            provider_account_id: alice.clone(),
            base_amount_units: 5_000,
            quote_amount_units: 500_000,
            min_lp_units: 1,
        },
        Transaction::SwapExactIn {
            swap_id,
            pool_id: pool_id.clone(),
            trader_account_id: bob.clone(),
            asset_in_id: LOCAL_TEST_UNIT_ASSET_ID.to_string(),
            amount_in_units: 100,
            min_amount_out_units: 9_000,
        },
        Transaction::RemoveLiquidity {
            liquidity_id: remove_liquidity_id,
            pool_id,
            provider_account_id: alice,
            lp_units: 100,
            min_base_amount_units: 1,
            min_quote_amount_units: 1,
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
