use crate::hash::{hash_json, keccak_hex};
use serde::{Deserialize, Serialize};
use serde_json::Value;
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
pub const LOCAL_TEST_UNIT_ASSET_ID: &str = "asset:flowchain-local-test-unit";
pub const PRODUCTION_L1_PROTOCOL_VERSION: &str = "flowchain.private_local_l1.protocol.v0";
pub const PRODUCTION_L1_CHAIN_ID: &str = "7428453";
pub const PRODUCTION_L1_NETWORK_PROFILE: &str = "flowchain-base8453-pilot";
pub const PRODUCTION_L1_GENESIS_HASH: &str =
    "0x0826d4c5093c967d57dd5239b8c24e089dc898942291b5f3050a129887041e7f";
pub const PRODUCTION_L1_NATIVE_ASSET_ID: &str =
    "0xa70acd8537f968b85bbfcff11f26a46376af5de590645cfd4976f1382794c024";
pub const PRODUCTION_L1_BASE_SOURCE_CHAIN_ID: u64 = 8453;
pub const PRODUCTION_L1_BASE_SOURCE_NETWORK: &str = "base-mainnet-source-for-local-private-pilot";
pub const PRODUCTION_L1_LOCKBOX_ADDRESS: &str = "0xb9524481c154c195b4236846fe9d8fcffd6ce407";
pub const PRODUCTION_L1_BRIDGE_CREDIT_CAP_UNITS: u64 = 5_000_000;

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
    #[error("FC_PROTO_SCHEMA_VALIDATION: {0}")]
    ProtocolSchemaValidation(String),
    #[error("FC_PROTO_WRONG_CHAIN_ID: {0}")]
    ProtocolWrongChainId(String),
    #[error("FC_PROTO_WRONG_NETWORK_PROFILE: {0}")]
    ProtocolWrongNetworkProfile(String),
    #[error("FC_PROTO_WRONG_GENESIS_HASH: {0}")]
    ProtocolWrongGenesisHash(String),
    #[error("FC_PROTO_STALE_NONCE: account {account_id} expected {expected} got {actual}")]
    ProtocolStaleNonce {
        account_id: String,
        expected: u64,
        actual: u64,
    },
    #[error("FC_PROTO_DUPLICATE_TX: {0}")]
    ProtocolDuplicateTx(String),
    #[error("FC_PROTO_MALFORMED_PAYLOAD_HASH: {0}")]
    ProtocolMalformedPayloadHash(String),
    #[error("FC_PROTO_MALFORMED_TX_ID: {0}")]
    ProtocolMalformedTxId(String),
    #[error("FC_PROTO_ACCOUNT_MISSING: {0}")]
    ProtocolAccountMissing(String),
    #[error("FC_PROTO_ACCOUNT_INACTIVE: {0}")]
    ProtocolAccountInactive(String),
    #[error("FC_PROTO_BALANCE_MISSING: {0}")]
    ProtocolBalanceMissing(String),
    #[error("FC_PROTO_BALANCE_INSUFFICIENT: {0}")]
    ProtocolBalanceInsufficient(String),
    #[error("FC_PROTO_BALANCE_OVERFLOW: {0}")]
    ProtocolBalanceOverflow(String),
    #[error("FC_PROTO_INVALID_EVENT: {0}")]
    ProtocolInvalidEvent(String),
    #[error("FC_PROTO_INVALID_BRIDGE_SOURCE_CHAIN: {0}")]
    ProtocolInvalidBridgeSourceChain(String),
    #[error("FC_PROTO_WRONG_LOCKBOX: {0}")]
    ProtocolWrongLockbox(String),
    #[error("FC_PROTO_BRIDGE_AMOUNT_OVER_CAP: {0}")]
    ProtocolBridgeAmountOverCap(String),
    #[error("FC_PROTO_BRIDGE_CONFIRMATION_UNSATISFIED: {0}")]
    ProtocolBridgeConfirmationUnsatisfied(String),
    #[error("FC_PROTO_MUTATED_BRIDGE_EVIDENCE: {0}")]
    ProtocolMutatedBridgeEvidence(String),
    #[error("FC_PROTO_DUPLICATE_BRIDGE_EVENT: {0}")]
    ProtocolDuplicateBridgeEvent(String),
    #[error("FC_PROTO_BRIDGE_EVIDENCE_MISSING: {0}")]
    ProtocolBridgeEvidenceMissing(String),
    #[error("FC_PROTO_BRIDGE_EVIDENCE_MISMATCH: {0}")]
    ProtocolBridgeEvidenceMismatch(String),
    #[error("FC_PROTO_UNSUPPORTED_PAYLOAD: {0}")]
    ProtocolUnsupportedPayload(String),
    #[error("FC_PROTO_OBJECT_ALREADY_EXISTS: {0}")]
    ProtocolObjectAlreadyExists(String),
    #[error("FC_PROTO_FINALITY_VOTE_MISSING: {0}")]
    ProtocolFinalityVoteMissing(String),
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
    #[serde(default = "default_protocol_accounts")]
    pub protocol_accounts: BTreeMap<String, ProtocolAccount>,
    #[serde(default = "default_protocol_balances")]
    pub protocol_balances: BTreeMap<String, ProtocolBalance>,
    #[serde(default = "default_protocol_validator_authorities")]
    pub protocol_validator_authorities: BTreeMap<String, ProtocolValidatorAuthority>,
    #[serde(default)]
    pub protocol_bridge_evidence: BTreeMap<String, ProtocolBridgeEvidence>,
    #[serde(default)]
    pub protocol_bridge_credits: BTreeMap<String, ProtocolBridgeCredit>,
    #[serde(default)]
    pub protocol_bridge_replay_index: BTreeMap<String, ProtocolBridgeReplayIndexEntry>,
    #[serde(default)]
    pub protocol_receipts: BTreeMap<String, ProtocolReceipt>,
    #[serde(default)]
    pub protocol_events: BTreeMap<String, ProtocolEvent>,
    #[serde(default)]
    pub protocol_event_receipt_index: BTreeMap<String, ProtocolEventReceiptIndexEntry>,
    #[serde(default)]
    pub protocol_withdrawals: BTreeMap<String, ProtocolWithdrawalIntent>,
    #[serde(default)]
    pub protocol_object_store: BTreeMap<String, ProtocolObjectStoreEntry>,
    #[serde(default)]
    pub protocol_finality_votes: BTreeMap<String, ProtocolFinalityVote>,
    #[serde(default)]
    pub protocol_finality_certificates: BTreeMap<String, ProtocolFinalityCertificate>,
    pub blocks: Vec<Block>,
    pub pending_txs: Vec<TxEnvelope>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ProtocolAccount {
    pub account_id: String,
    pub label: String,
    pub public_key: String,
    pub address: String,
    pub role_flags: BTreeMap<String, bool>,
    pub next_nonce: u64,
    pub status: String,
    pub production_ready: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ProtocolBalance {
    pub balance_id: String,
    pub account_id: String,
    pub asset_id: String,
    pub amount_units: u64,
    pub balance_type: String,
    pub updated_at_block: u64,
    pub no_value: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ProtocolValidatorAuthority {
    pub authority_id: String,
    pub account_id: String,
    pub public_key: String,
    pub address: String,
    pub authority_type: String,
    pub voting_power: u64,
    pub finality_weight: u64,
    pub metadata_hash: String,
    pub status: String,
    pub production_ready: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ProtocolBridgeReleaseEvidence {
    pub withdrawal_intent_id: String,
    pub release_tx_hash: String,
    pub release_block_number: String,
    pub release_log_index: u64,
    pub released_to_address: String,
    pub release_authority_account_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ProtocolBridgeEvidence {
    pub schema: String,
    pub evidence_id: String,
    pub evidence_type: String,
    pub source_chain_id: u64,
    pub source_network: String,
    pub lockbox_address: String,
    pub source_tx_hash: String,
    pub source_block_number: String,
    pub source_log_index: u64,
    pub token_address: String,
    pub asset_id: String,
    pub depositor_address: String,
    pub local_recipient_account_id: String,
    pub amount: String,
    pub observation_id: String,
    pub credit_id: String,
    pub duplicate_key: String,
    pub evidence_hash: String,
    pub observed_by_relayer_account_id: String,
    pub finality_status: String,
    pub release: Option<ProtocolBridgeReleaseEvidence>,
    pub local_only: bool,
    pub production_ready: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ProtocolBridgeCredit {
    pub credit_id: String,
    pub evidence_id: String,
    pub observation_id: String,
    pub duplicate_key: String,
    pub source_chain_id: u64,
    pub lockbox_address: String,
    pub asset_id: String,
    pub amount_units: u64,
    pub recipient_account_id: String,
    pub receipt_id: String,
    pub event_id: String,
    pub applied_at_block: u64,
    pub status: String,
    pub no_value: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ProtocolBridgeReplayIndexEntry {
    pub duplicate_key: String,
    pub evidence_id: String,
    pub credit_id: String,
    pub source_chain_id: u64,
    pub lockbox_address: String,
    pub source_tx_hash: String,
    pub source_log_index: u64,
    pub accepted_at_block: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ProtocolReceipt {
    pub receipt_id: String,
    pub tx_id: String,
    pub payload_type: String,
    pub status: String,
    pub execution_cost_units: u64,
    pub state_delta_ref: String,
    pub emitted_events: Vec<String>,
    pub bridge_evidence_refs: Vec<String>,
    pub error_code: Option<String>,
    pub failure_reason: Option<String>,
    pub deterministic_id_input: String,
    pub applied_at_block: u64,
    pub state_root_after: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ProtocolEvent {
    pub event_id: String,
    pub event_type: String,
    pub payload_type: String,
    pub tx_id: String,
    pub receipt_id: String,
    pub block_height: u64,
    pub event_index: u64,
    pub emitter_account_id: String,
    pub subject_id: String,
    pub attributes: BTreeMap<String, String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ProtocolEventReceiptIndexEntry {
    pub event_id: String,
    pub receipt_id: String,
    pub tx_id: String,
    pub event_type: String,
    pub block_height: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ProtocolWithdrawalIntent {
    pub withdrawal_intent_id: String,
    pub source_account_id: String,
    pub destination_chain_id: u64,
    pub destination_address: String,
    pub asset_id: String,
    pub amount_units: u64,
    pub release_policy_hash: String,
    pub release_evidence_id: Option<String>,
    pub receipt_id: String,
    pub event_id: String,
    pub status: String,
    pub created_at_block: u64,
    pub no_value: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ProtocolObjectStoreEntry {
    pub lifecycle_update_id: String,
    pub payload_type: String,
    pub object_type: String,
    pub operation: String,
    pub object_id: String,
    pub object_hash: String,
    pub status: String,
    pub rootfield_id: Option<String>,
    pub source_receipt_id: Option<String>,
    pub parent_object_id: Option<String>,
    pub receipt_id: String,
    pub event_id: String,
    pub updated_at_block: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ProtocolFinalityVote {
    pub vote_id: String,
    pub validator_account_id: String,
    pub height: u64,
    pub block_hash: String,
    pub state_root: String,
    pub vote_round: u64,
    pub receipt_id: String,
    pub event_id: String,
    pub recorded_at_block: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ProtocolFinalityCertificate {
    pub certificate_id: String,
    pub height: u64,
    pub block_hash: String,
    pub state_root: String,
    pub signer_set_root: String,
    pub vote_ids: Vec<String>,
    pub quorum_numerator: u64,
    pub quorum_denominator: u64,
    pub receipt_id: String,
    pub event_id: String,
    pub status: String,
    pub accepted_at_block: u64,
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
    ApplyProtocolBridgeEvidence {
        evidence: Value,
    },
    ApplyProductionL1Transaction {
        envelope: Value,
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
    protocol_accounts: &'a BTreeMap<String, ProtocolAccount>,
    protocol_balances: &'a BTreeMap<String, ProtocolBalance>,
    protocol_validator_authorities: &'a BTreeMap<String, ProtocolValidatorAuthority>,
    protocol_bridge_evidence: &'a BTreeMap<String, ProtocolBridgeEvidence>,
    protocol_bridge_credits: &'a BTreeMap<String, ProtocolBridgeCredit>,
    protocol_bridge_replay_index: &'a BTreeMap<String, ProtocolBridgeReplayIndexEntry>,
    protocol_receipts: &'a BTreeMap<String, ProtocolReceipt>,
    protocol_events: &'a BTreeMap<String, ProtocolEvent>,
    protocol_event_receipt_index: &'a BTreeMap<String, ProtocolEventReceiptIndexEntry>,
    protocol_withdrawals: &'a BTreeMap<String, ProtocolWithdrawalIntent>,
    protocol_object_store: &'a BTreeMap<String, ProtocolObjectStoreEntry>,
    protocol_finality_votes: &'a BTreeMap<String, ProtocolFinalityVote>,
    protocol_finality_certificates: &'a BTreeMap<String, ProtocolFinalityCertificate>,
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
    #[serde(default)]
    pub protocol_account_root: String,
    #[serde(default)]
    pub protocol_balance_root: String,
    #[serde(default)]
    pub protocol_validator_authority_root: String,
    #[serde(default)]
    pub protocol_bridge_evidence_root: String,
    #[serde(default)]
    pub protocol_bridge_credit_root: String,
    #[serde(default)]
    pub protocol_bridge_replay_index_root: String,
    #[serde(default)]
    pub protocol_receipt_root: String,
    #[serde(default)]
    pub protocol_event_root: String,
    #[serde(default)]
    pub protocol_event_receipt_index_root: String,
    #[serde(default)]
    pub protocol_withdrawal_root: String,
    #[serde(default)]
    pub protocol_object_store_root: String,
    #[serde(default)]
    pub protocol_finality_vote_root: String,
    #[serde(default)]
    pub protocol_finality_certificate_root: String,
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

pub fn default_protocol_accounts() -> BTreeMap<String, ProtocolAccount> {
    let accounts = [
        (
            "alice-user",
            "0xd6d0a8eb15ca2da58ecde78beb56830564ea3302b3af4215cdccb3a08ff34908",
            "0x02a332e6b5637c5584cf1b19a24410a74a86715d1d054f5bf1f1054ed789fae974",
            "0x160c4dcc0bb4bdc9bdbdd3b652dacdb0a95731d3",
            [("user", true), ("validator", false), ("bridgeOperator", false), ("deployer", true), ("relayer", false), ("emergencyOperator", false)],
        ),
        (
            "bob-user",
            "0xc687acd2a8f82c43e7b5e5fc8c3df132aa69becb29a71abcdfe6461a2e6e774a",
            "0x02bd133d4df63458ed49a0d7acde36d546b80c735f04d9a37eb428f1d92505b6be",
            "0xc8d2f10666e1216121f6449f0fc5726f63590aa7",
            [("user", true), ("validator", false), ("bridgeOperator", false), ("deployer", false), ("relayer", false), ("emergencyOperator", false)],
        ),
        (
            "validator-one",
            "0xef8fcf1e5560df82860c4de608453cc69a07478b1c7472b6fa7f5834d7d0c46d",
            "0x021d45040882bbe0d3d1ff6ed7476a4b533e17b00633d81cff5cd15479c3c0bd22",
            "0xd0c3c122262ba1116de221d5fbf4505357b97e8a",
            [("user", false), ("validator", true), ("bridgeOperator", false), ("deployer", false), ("relayer", false), ("emergencyOperator", false)],
        ),
        (
            "bridge-relayer",
            "0xb456f55c243edcb1372f27f199f9e68b25d0909f5d2d90ec4e20fbe6de7098b4",
            "0x02f90ad32b15b53c0e4abd4f2f0de6db96dbe0adee1dab1736b0cf596070f7ef05",
            "0x633621fec8e01f8346130d81c26be8e33d1dcea9",
            [("user", false), ("validator", false), ("bridgeOperator", true), ("deployer", false), ("relayer", true), ("emergencyOperator", false)],
        ),
        (
            "bridge-release-authority",
            "0x9f7090c47663019f3d7647a2d4b5895a529e9dbac911bb2fde2c359828cbb3b8",
            "0x02be094d43f51fb0e267c4ed5767bf26ef1370dc3c7756d1399d8e152c3a59b602",
            "0xdb523727f85b4f6d0ff5f62fc4d6c25a337af90d",
            [("user", false), ("validator", false), ("bridgeOperator", true), ("deployer", false), ("relayer", false), ("emergencyOperator", false)],
        ),
        (
            "emergency-operator",
            "0x458a01532bc3ec202c267dbd715ef239d54e3844cb37c57f504ab7e7f077ac8a",
            "0x0202837e867307660b83033448b53dae9fbf18646041ac72fc3797272b59d65d79",
            "0x9386458c8c48d14bfebedc4fd00a528c15727b9e",
            [("user", false), ("validator", false), ("bridgeOperator", false), ("deployer", false), ("relayer", false), ("emergencyOperator", true)],
        ),
    ];

    accounts
        .into_iter()
        .map(|(label, account_id, public_key, address, flags)| {
            (
                account_id.to_string(),
                ProtocolAccount {
                    account_id: account_id.to_string(),
                    label: label.to_string(),
                    public_key: public_key.to_string(),
                    address: address.to_string(),
                    role_flags: flags
                        .into_iter()
                        .map(|(role, enabled)| (role.to_string(), enabled))
                        .collect(),
                    next_nonce: 1,
                    status: "active".to_string(),
                    production_ready: false,
                },
            )
        })
        .collect()
}

pub fn default_protocol_balances() -> BTreeMap<String, ProtocolBalance> {
    [
        (
            "0xd6d0a8eb15ca2da58ecde78beb56830564ea3302b3af4215cdccb3a08ff34908",
            1_000_000_u64,
        ),
        (
            "0xc687acd2a8f82c43e7b5e5fc8c3df132aa69becb29a71abcdfe6461a2e6e774a",
            100_000_u64,
        ),
        (
            "0xef8fcf1e5560df82860c4de608453cc69a07478b1c7472b6fa7f5834d7d0c46d",
            50_000_u64,
        ),
        (
            "0xb456f55c243edcb1372f27f199f9e68b25d0909f5d2d90ec4e20fbe6de7098b4",
            25_000_u64,
        ),
    ]
    .into_iter()
    .map(|(account_id, amount_units)| {
        let balance_id = protocol_balance_id(account_id, PRODUCTION_L1_NATIVE_ASSET_ID);
        (
            balance_id.clone(),
            ProtocolBalance {
                balance_id,
                account_id: account_id.to_string(),
                asset_id: PRODUCTION_L1_NATIVE_ASSET_ID.to_string(),
                amount_units,
                balance_type: "native_local_unit".to_string(),
                updated_at_block: 0,
                no_value: true,
            },
        )
    })
    .collect()
}

pub fn default_protocol_validator_authorities() -> BTreeMap<String, ProtocolValidatorAuthority> {
    let authority = ProtocolValidatorAuthority {
        authority_id: "0x4e7ad43d8db36ddde419d64fac4768a38167efd7b9e7abc503036f2ba22c92ba"
            .to_string(),
        account_id: "0xef8fcf1e5560df82860c4de608453cc69a07478b1c7472b6fa7f5834d7d0c46d"
            .to_string(),
        public_key: "0x021d45040882bbe0d3d1ff6ed7476a4b533e17b00633d81cff5cd15479c3c0bd22"
            .to_string(),
        address: "0xd0c3c122262ba1116de221d5fbf4505357b97e8a".to_string(),
        authority_type: "validator".to_string(),
        voting_power: 1,
        finality_weight: 1,
        metadata_hash: "0x708f6074acaf685798e4085ceb5d4c3053dfa72bc1ccf0078feb3dbcd39c5e15"
            .to_string(),
        status: "active".to_string(),
        production_ready: false,
    };
    BTreeMap::from([(authority.authority_id.clone(), authority)])
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
        protocol_accounts: default_protocol_accounts(),
        protocol_balances: default_protocol_balances(),
        protocol_validator_authorities: default_protocol_validator_authorities(),
        protocol_bridge_evidence: BTreeMap::new(),
        protocol_bridge_credits: BTreeMap::new(),
        protocol_bridge_replay_index: BTreeMap::new(),
        protocol_receipts: BTreeMap::new(),
        protocol_events: BTreeMap::new(),
        protocol_event_receipt_index: BTreeMap::new(),
        protocol_withdrawals: BTreeMap::new(),
        protocol_object_store: BTreeMap::new(),
        protocol_finality_votes: BTreeMap::new(),
        protocol_finality_certificates: BTreeMap::new(),
        blocks: Vec::new(),
        pending_txs: Vec::new(),
    }
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

pub fn protocol_balance_id(account_id: &str, asset_id: &str) -> String {
    hash_json(
        "flowchain.production_l1.balance_id.v0",
        &serde_json::json!({
            "accountId": account_id,
            "assetId": asset_id
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
        protocol_accounts: &state.protocol_accounts,
        protocol_balances: &state.protocol_balances,
        protocol_validator_authorities: &state.protocol_validator_authorities,
        protocol_bridge_evidence: &state.protocol_bridge_evidence,
        protocol_bridge_credits: &state.protocol_bridge_credits,
        protocol_bridge_replay_index: &state.protocol_bridge_replay_index,
        protocol_receipts: &state.protocol_receipts,
        protocol_events: &state.protocol_events,
        protocol_event_receipt_index: &state.protocol_event_receipt_index,
        protocol_withdrawals: &state.protocol_withdrawals,
        protocol_object_store: &state.protocol_object_store,
        protocol_finality_votes: &state.protocol_finality_votes,
        protocol_finality_certificates: &state.protocol_finality_certificates,
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
        protocol_account_root: map_root(
            "flowmemory.local_devnet.protocol_accounts.v0",
            &state.protocol_accounts,
        ),
        protocol_balance_root: map_root(
            "flowmemory.local_devnet.protocol_balances.v0",
            &state.protocol_balances,
        ),
        protocol_validator_authority_root: map_root(
            "flowmemory.local_devnet.protocol_validator_authorities.v0",
            &state.protocol_validator_authorities,
        ),
        protocol_bridge_evidence_root: map_root(
            "flowmemory.local_devnet.protocol_bridge_evidence.v0",
            &state.protocol_bridge_evidence,
        ),
        protocol_bridge_credit_root: map_root(
            "flowmemory.local_devnet.protocol_bridge_credits.v0",
            &state.protocol_bridge_credits,
        ),
        protocol_bridge_replay_index_root: map_root(
            "flowmemory.local_devnet.protocol_bridge_replay_index.v0",
            &state.protocol_bridge_replay_index,
        ),
        protocol_receipt_root: map_root(
            "flowmemory.local_devnet.protocol_receipts.v0",
            &state.protocol_receipts,
        ),
        protocol_event_root: map_root(
            "flowmemory.local_devnet.protocol_events.v0",
            &state.protocol_events,
        ),
        protocol_event_receipt_index_root: map_root(
            "flowmemory.local_devnet.protocol_event_receipt_index.v0",
            &state.protocol_event_receipt_index,
        ),
        protocol_withdrawal_root: map_root(
            "flowmemory.local_devnet.protocol_withdrawals.v0",
            &state.protocol_withdrawals,
        ),
        protocol_object_store_root: map_root(
            "flowmemory.local_devnet.protocol_object_store.v0",
            &state.protocol_object_store,
        ),
        protocol_finality_vote_root: map_root(
            "flowmemory.local_devnet.protocol_finality_votes.v0",
            &state.protocol_finality_votes,
        ),
        protocol_finality_certificate_root: map_root(
            "flowmemory.local_devnet.protocol_finality_certificates.v0",
            &state.protocol_finality_certificates,
        ),
    }
}

pub fn build_block(state: &mut ChainState) -> Block {
    let txs = std::mem::take(&mut state.pending_txs);
    let mut receipts = Vec::with_capacity(txs.len());
    let mut tx_ids = Vec::with_capacity(txs.len());

    for envelope in txs {
        tx_ids.push(envelope.tx_id.clone());
        let authorization = envelope.authorization.clone();
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
            authorization,
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
        Transaction::TransferLocalTestUnits {
            transfer_id,
            from_account_id,
            to_account_id,
            amount_units,
            memo,
        } => {
            if state.balance_transfers.contains_key(transfer_id) {
                return Err(DevnetError::BalanceTransferAlreadyExists(
                    transfer_id.clone(),
                ));
            }
            if *amount_units == 0 {
                return Err(DevnetError::FaucetAmountMustBePositive(transfer_id.clone()));
            }

            let from_balance = state
                .local_test_unit_balances
                .get(from_account_id)
                .ok_or_else(|| DevnetError::LocalTestUnitBalanceMissing(from_account_id.clone()))?;
            if from_balance.units < *amount_units {
                return Err(DevnetError::LocalTestUnitBalanceInsufficient(
                    from_account_id.clone(),
                ));
            }

            {
                let from_balance = state
                    .local_test_unit_balances
                    .get_mut(from_account_id)
                    .expect("source local test-unit balance was checked above");
                from_balance.units -= *amount_units;
                from_balance.updated_at_block = state.next_block_number;
            }

            let to_balance = state
                .local_test_unit_balances
                .get_mut(to_account_id)
                .ok_or_else(|| DevnetError::LocalTestUnitBalanceMissing(to_account_id.clone()))?;
            to_balance.units = to_balance
                .units
                .checked_add(*amount_units)
                .ok_or_else(|| DevnetError::LocalTestUnitBalanceOverflow(to_account_id.clone()))?;
            to_balance.updated_at_block = state.next_block_number;

            state.balance_transfers.insert(
                transfer_id.clone(),
                BalanceTransfer {
                    transfer_id: transfer_id.clone(),
                    from_account_id: from_account_id.clone(),
                    to_account_id: to_account_id.clone(),
                    amount_units: *amount_units,
                    memo: memo.clone(),
                    transferred_at_block: state.next_block_number,
                    no_value: true,
                },
            );
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
        Transaction::ApplyProtocolBridgeEvidence { evidence } => {
            let evidence = parse_protocol_bridge_evidence(evidence)?;
            if state
                .protocol_bridge_evidence
                .contains_key(&evidence.evidence_id)
                || state
                    .protocol_bridge_evidence
                    .values()
                    .any(|stored| stored.duplicate_key == evidence.duplicate_key)
                || state
                    .protocol_bridge_replay_index
                    .contains_key(&evidence.duplicate_key)
            {
                return Err(DevnetError::ProtocolDuplicateBridgeEvent(
                    evidence.duplicate_key,
                ));
            }
            validate_protocol_bridge_evidence(state, &evidence)?;
            state
                .protocol_bridge_evidence
                .insert(evidence.evidence_id.clone(), evidence);
        }
        Transaction::ApplyProductionL1Transaction { envelope } => {
            apply_production_l1_transaction(state, envelope)?;
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

fn apply_production_l1_transaction(
    state: &mut ChainState,
    envelope: &Value,
) -> Result<(), DevnetError> {
    expect_string(
        envelope,
        "schema",
        "flowchain.production_l1.transaction_envelope.v0",
    )?;
    expect_string(
        envelope,
        "protocolVersion",
        PRODUCTION_L1_PROTOCOL_VERSION,
    )?;
    expect_string(envelope, "chainId", PRODUCTION_L1_CHAIN_ID)?;
    expect_string(envelope, "networkProfile", PRODUCTION_L1_NETWORK_PROFILE)?;
    expect_string(envelope, "genesisHash", PRODUCTION_L1_GENESIS_HASH)?;

    let tx_id = required_string(envelope, "txId")?;
    if state
        .protocol_receipts
        .values()
        .any(|receipt| receipt.tx_id == tx_id)
    {
        return Err(DevnetError::ProtocolDuplicateTx(tx_id));
    }

    let nonce = required_u64_string(envelope, "nonce")?;
    let payload_type = required_string(envelope, "payloadType")?;
    let payload_hash = required_string(envelope, "payloadHash")?;
    let payload = envelope
        .get("payload")
        .ok_or_else(|| DevnetError::ProtocolSchemaValidation("missing payload".to_string()))?;
    expect_string(payload, "schema", "flowchain.production_l1.transaction_payload.v0")?;
    expect_string(payload, "payloadType", &payload_type)?;
    let actor_account_id = required_string(payload, "actorAccountId")?;
    let account_nonce = required_u64_string(payload, "accountNonce")?;
    if account_nonce != nonce {
        return Err(DevnetError::ProtocolStaleNonce {
            account_id: actor_account_id,
            expected: nonce,
            actual: account_nonce,
        });
    }

    let signer = envelope
        .get("signer")
        .ok_or_else(|| DevnetError::ProtocolSchemaValidation("missing signer".to_string()))?;
    let signer_account_id = required_string(signer, "accountId")?;
    let signer_public_key = required_string(signer, "publicKey")?;
    let signer_address = required_string(signer, "address")?;
    if signer_account_id != actor_account_id {
        return Err(DevnetError::ProtocolMalformedTxId(tx_id));
    }

    let account = state
        .protocol_accounts
        .get(&signer_account_id)
        .ok_or_else(|| DevnetError::ProtocolAccountMissing(signer_account_id.clone()))?;
    if account.status != "active" {
        return Err(DevnetError::ProtocolAccountInactive(signer_account_id.clone()));
    }
    if account.public_key != signer_public_key || account.address != signer_address {
        return Err(DevnetError::ProtocolMalformedTxId(tx_id));
    }
    if account.next_nonce != nonce {
        return Err(DevnetError::ProtocolStaleNonce {
            account_id: signer_account_id,
            expected: account.next_nonce,
            actual: nonce,
        });
    }

    let recomputed_payload_hash = hash_json("flowchain.production_l1.payload_hash.v0", payload);
    if recomputed_payload_hash != payload_hash {
        return Err(DevnetError::ProtocolMalformedPayloadHash(payload_type));
    }
    let recomputed_tx_id = hash_json(
        "flowchain.production_l1.tx_id.v0",
        &serde_json::json!({
            "chainId": PRODUCTION_L1_CHAIN_ID,
            "networkProfile": PRODUCTION_L1_NETWORK_PROFILE,
            "genesisHash": PRODUCTION_L1_GENESIS_HASH,
            "nonce": nonce.to_string(),
            "signerAccountId": signer_account_id,
            "payloadType": payload_type,
            "payloadHash": payload_hash
        }),
    );
    if recomputed_tx_id != tx_id {
        return Err(DevnetError::ProtocolMalformedTxId(tx_id));
    }

    let event_types = emitted_event_types(payload)?;
    if event_types.is_empty() {
        return Err(DevnetError::ProtocolInvalidEvent(payload_type));
    }
    if let Some(expected_event) = expected_event_type(&payload_type)
        && !event_types.iter().any(|event_type| event_type == expected_event)
    {
        return Err(DevnetError::ProtocolInvalidEvent(format!(
            "{payload_type} expected {expected_event}"
        )));
    }

    let receipt_id = production_receipt_id(&tx_id, &payload_type, "succeeded");
    let event_ids: Vec<String> = event_types
        .iter()
        .enumerate()
        .map(|(index, event_type)| production_event_id(&tx_id, &receipt_id, event_type, index))
        .collect();
    let details = payload
        .get("details")
        .ok_or_else(|| DevnetError::ProtocolSchemaValidation("missing payload.details".to_string()))?;
    let bridge_evidence_refs = apply_production_l1_payload(
        state,
        &tx_id,
        &receipt_id,
        event_ids
            .first()
            .ok_or_else(|| DevnetError::ProtocolInvalidEvent(payload_type.clone()))?,
        &payload_type,
        &signer_account_id,
        details,
    )?;

    if let Some(account) = state.protocol_accounts.get_mut(&signer_account_id) {
        account.next_nonce += 1;
    }

    let state_root_after = state_root(state);
    let subject_id = subject_id_for_payload(payload, details)?;
    for (index, event_type) in event_types.iter().enumerate() {
        let event_id = event_ids[index].clone();
        let mut attributes = BTreeMap::new();
        attributes.insert("payloadType".to_string(), payload_type.clone());
        attributes.insert("payloadId".to_string(), required_string(payload, "payloadId")?);
        attributes.insert("txId".to_string(), tx_id.clone());
        let event = ProtocolEvent {
            event_id: event_id.clone(),
            event_type: event_type.clone(),
            payload_type: payload_type.clone(),
            tx_id: tx_id.clone(),
            receipt_id: receipt_id.clone(),
            block_height: state.next_block_number,
            event_index: state.protocol_events.len() as u64,
            emitter_account_id: signer_account_id.clone(),
            subject_id: subject_id.clone(),
            attributes,
        };
        state.protocol_event_receipt_index.insert(
            event_id.clone(),
            ProtocolEventReceiptIndexEntry {
                event_id: event_id.clone(),
                receipt_id: receipt_id.clone(),
                tx_id: tx_id.clone(),
                event_type: event_type.clone(),
                block_height: state.next_block_number,
            },
        );
        state.protocol_events.insert(event_id, event);
    }

    let deterministic_id_input = hash_json(
        "flowchain.production_l1.receipt_id_input.v0",
        &serde_json::json!({
            "txId": tx_id,
            "payloadType": payload_type,
            "status": "succeeded"
        }),
    );
    state.protocol_receipts.insert(
        receipt_id.clone(),
        ProtocolReceipt {
            receipt_id,
            tx_id,
            payload_type,
            status: "succeeded".to_string(),
            execution_cost_units: 1_000 + state.protocol_receipts.len() as u64 * 10,
            state_delta_ref: hash_json(
                "flowchain.production_l1.state_delta_ref.v0",
                &serde_json::json!({
                    "txId": envelope.get("txId").and_then(Value::as_str).unwrap_or_default(),
                    "payloadType": envelope.get("payloadType").and_then(Value::as_str).unwrap_or_default()
                }),
            ),
            emitted_events: event_ids,
            bridge_evidence_refs,
            error_code: None,
            failure_reason: None,
            deterministic_id_input,
            applied_at_block: state.next_block_number,
            state_root_after,
        },
    );

    Ok(())
}

fn apply_production_l1_payload(
    state: &mut ChainState,
    _tx_id: &str,
    receipt_id: &str,
    event_id: &str,
    payload_type: &str,
    signer_account_id: &str,
    details: &Value,
) -> Result<Vec<String>, DevnetError> {
    match payload_type {
        "native_transfer" => {
            let from = required_string(details, "fromAccountId")?;
            let to = required_string(details, "toAccountId")?;
            if from != signer_account_id {
                return Err(DevnetError::ProtocolAccountMissing(from));
            }
            let asset = required_string(details, "assetId")?;
            let amount = required_u64_string(details, "amount")?;
            debit_protocol_balance(state, &from, &asset, amount)?;
            credit_protocol_balance(state, &to, &asset, amount)?;
            Ok(Vec::new())
        }
        "faucet_funding" => {
            let to = required_string(details, "toAccountId")?;
            let asset = required_string(details, "assetId")?;
            let amount = required_u64_string(details, "amount")?;
            credit_protocol_balance(state, &to, &asset, amount)?;
            Ok(Vec::new())
        }
        "bridge_credit" => {
            let evidence_id = required_string(details, "bridgeEvidenceId")?;
            let evidence = state
                .protocol_bridge_evidence
                .get(&evidence_id)
                .cloned()
                .ok_or_else(|| DevnetError::ProtocolBridgeEvidenceMissing(evidence_id.clone()))?;
            validate_protocol_bridge_evidence(state, &evidence)?;
            let amount = required_u64_string(details, "amount")?;
            if amount > PRODUCTION_L1_BRIDGE_CREDIT_CAP_UNITS {
                return Err(DevnetError::ProtocolBridgeAmountOverCap(
                    evidence.credit_id.clone(),
                ));
            }
            if state
                .protocol_bridge_replay_index
                .contains_key(&evidence.duplicate_key)
            {
                return Err(DevnetError::ProtocolDuplicateBridgeEvent(
                    evidence.duplicate_key,
                ));
            }
            let observation_id = required_string(details, "observationId")?;
            let credit_id = required_string(details, "creditId")?;
            let source_chain_id = required_u64_number(details, "sourceChainId")?;
            let asset_id = required_string(details, "assetId")?;
            let recipient = required_string(details, "recipientAccountId")?;
            if evidence.evidence_type != "deposit_observation"
                || evidence.observation_id != observation_id
                || evidence.credit_id != credit_id
                || evidence.source_chain_id != source_chain_id
                || evidence.asset_id != asset_id
                || evidence.local_recipient_account_id != recipient
                || parse_u64_string(&evidence.amount, "amount")? != amount
            {
                return Err(DevnetError::ProtocolBridgeEvidenceMismatch(credit_id));
            }
            credit_protocol_balance(state, &recipient, &asset_id, amount)?;
            state.protocol_bridge_replay_index.insert(
                evidence.duplicate_key.clone(),
                ProtocolBridgeReplayIndexEntry {
                    duplicate_key: evidence.duplicate_key.clone(),
                    evidence_id: evidence.evidence_id.clone(),
                    credit_id: evidence.credit_id.clone(),
                    source_chain_id: evidence.source_chain_id,
                    lockbox_address: evidence.lockbox_address.clone(),
                    source_tx_hash: evidence.source_tx_hash.clone(),
                    source_log_index: evidence.source_log_index,
                    accepted_at_block: state.next_block_number,
                },
            );
            state.protocol_bridge_credits.insert(
                evidence.credit_id.clone(),
                ProtocolBridgeCredit {
                    credit_id: evidence.credit_id.clone(),
                    evidence_id: evidence.evidence_id.clone(),
                    observation_id: evidence.observation_id.clone(),
                    duplicate_key: evidence.duplicate_key.clone(),
                    source_chain_id: evidence.source_chain_id,
                    lockbox_address: evidence.lockbox_address.clone(),
                    asset_id,
                    amount_units: amount,
                    recipient_account_id: recipient,
                    receipt_id: receipt_id.to_string(),
                    event_id: event_id.to_string(),
                    applied_at_block: state.next_block_number,
                    status: "applied".to_string(),
                    no_value: true,
                },
            );
            Ok(vec![evidence_id])
        }
        "token_launch" => {
            let token_id = required_string(details, "tokenId")?;
            if state.token_definitions.contains_key(&token_id) {
                return Err(DevnetError::TokenAlreadyExists(token_id));
            }
            let recipient = required_string(details, "recipientAccountId")?;
            let initial_supply = required_u64_string(details, "initialSupply")?;
            let symbol = required_string(details, "symbol")?;
            state.token_definitions.insert(
                token_id.clone(),
                LocalTestToken {
                    token_id: token_id.clone(),
                    symbol,
                    name: required_string(details, "name")?,
                    decimals: required_u64_number(details, "decimals")? as u8,
                    launcher_account_id: required_string(details, "issuerAccountId")?,
                    total_supply_units: initial_supply,
                    launched_at_block: state.next_block_number,
                    no_value: true,
                },
            );
            credit_protocol_balance(state, &recipient, &token_id, initial_supply)?;
            Ok(Vec::new())
        }
        "token_mint" => {
            let token_id = required_string(details, "tokenId")?;
            let to = required_string(details, "toAccountId")?;
            let amount = required_u64_string(details, "amount")?;
            let token = state
                .token_definitions
                .get_mut(&token_id)
                .ok_or_else(|| DevnetError::TokenMissing(token_id.clone()))?;
            token.total_supply_units = token
                .total_supply_units
                .checked_add(amount)
                .ok_or_else(|| DevnetError::TokenBalanceOverflow(token_id.clone()))?;
            credit_protocol_balance(state, &to, &token_id, amount)?;
            state.token_mint_receipts.insert(
                required_string(details, "mintId")?,
                LocalTestTokenMintReceipt {
                    mint_id: required_string(details, "mintId")?,
                    token_id,
                    to_account_id: to,
                    amount_units: amount,
                    reason: required_string(details, "reasonHash")?,
                    minted_at_block: state.next_block_number,
                    no_value: true,
                },
            );
            Ok(Vec::new())
        }
        "token_transfer" => {
            let token_id = required_string(details, "tokenId")?;
            let from = required_string(details, "fromAccountId")?;
            let to = required_string(details, "toAccountId")?;
            let amount = required_u64_string(details, "amount")?;
            debit_protocol_balance(state, &from, &token_id, amount)?;
            credit_protocol_balance(state, &to, &token_id, amount)?;
            Ok(Vec::new())
        }
        "pool_create" => {
            let pool_id = required_string(details, "poolId")?;
            if state.dex_pools.contains_key(&pool_id) {
                return Err(DevnetError::PoolAlreadyExists(pool_id));
            }
            state.dex_pools.insert(
                pool_id.clone(),
                DexPool {
                    pool_id,
                    base_asset_id: required_string(details, "baseAssetId")?,
                    quote_asset_id: required_string(details, "quoteAssetId")?,
                    created_by_account_id: required_string(details, "creatorAccountId")?,
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
            Ok(Vec::new())
        }
        "add_liquidity" => {
            let liquidity_id = required_string(details, "liquidityId")?;
            let pool_id = required_string(details, "poolId")?;
            let provider = required_string(details, "providerAccountId")?;
            let base_amount = required_u64_string(details, "baseAmount")?;
            let quote_amount = required_u64_string(details, "quoteAmount")?;
            let min_lp_units = required_u64_string(details, "minLpUnits")?;
            if state.liquidity_receipts.contains_key(&liquidity_id) {
                return Err(DevnetError::LiquidityReceiptAlreadyExists(liquidity_id));
            }
            let pool = state
                .dex_pools
                .get(&pool_id)
                .ok_or_else(|| DevnetError::PoolMissing(pool_id.clone()))?;
            let reserve_base_before = pool.reserve_base_units;
            let reserve_quote_before = pool.reserve_quote_units;
            let total_lp_before = pool.total_lp_units;
            let lp_units = liquidity_units_for_add(pool, base_amount, quote_amount)?;
            if lp_units < min_lp_units {
                return Err(DevnetError::LiquidityBelowMinimum(liquidity_id));
            }
            let base_asset_id = pool.base_asset_id.clone();
            let quote_asset_id = pool.quote_asset_id.clone();
            debit_protocol_balance(state, &provider, &base_asset_id, base_amount)?;
            debit_protocol_balance(state, &provider, &quote_asset_id, quote_amount)?;
            let reserve_base_after = checked_pool_add(&pool_id, reserve_base_before, base_amount)?;
            let reserve_quote_after =
                checked_pool_add(&pool_id, reserve_quote_before, quote_amount)?;
            let total_lp_after = checked_pool_add(&pool_id, total_lp_before, lp_units)?;
            let pool = state
                .dex_pools
                .get_mut(&pool_id)
                .expect("pool was checked before production liquidity mutation");
            pool.reserve_base_units = reserve_base_after;
            pool.reserve_quote_units = reserve_quote_after;
            pool.total_lp_units = total_lp_after;
            pool.updated_at_block = state.next_block_number;
            pool.last_liquidity_receipt_id = Some(liquidity_id.clone());
            let lp_position_id = deterministic_lp_position_id(&pool_id, &provider);
            let position = state
                .lp_positions
                .entry(lp_position_id.clone())
                .or_insert_with(|| LpPosition {
                    lp_position_id,
                    pool_id: pool_id.clone(),
                    owner_account_id: provider.clone(),
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
                .checked_add(base_amount)
                .ok_or_else(|| DevnetError::PoolReserveOverflow(pool_id.clone()))?;
            position.quote_units_deposited = position
                .quote_units_deposited
                .checked_add(quote_amount)
                .ok_or_else(|| DevnetError::PoolReserveOverflow(pool_id.clone()))?;
            position.updated_at_block = state.next_block_number;
            state.liquidity_receipts.insert(
                liquidity_id.clone(),
                LiquidityReceipt {
                    liquidity_id,
                    pool_id,
                    provider_account_id: provider,
                    action: "add".to_string(),
                    base_amount_units: base_amount,
                    quote_amount_units: quote_amount,
                    lp_units,
                    reserve_base_before,
                    reserve_quote_before,
                    reserve_base_after,
                    reserve_quote_after,
                    executed_at_block: state.next_block_number,
                    no_value: true,
                },
            );
            Ok(Vec::new())
        }
        "remove_liquidity" => {
            let liquidity_id = required_string(details, "liquidityId")?;
            let pool_id = required_string(details, "poolId")?;
            let provider = required_string(details, "providerAccountId")?;
            let lp_units = required_u64_string(details, "lpUnits")?;
            let min_base = required_u64_string(details, "minBaseAmount")?;
            let min_quote = required_u64_string(details, "minQuoteAmount")?;
            let pool = state
                .dex_pools
                .get(&pool_id)
                .ok_or_else(|| DevnetError::PoolMissing(pool_id.clone()))?;
            let reserve_base_before = pool.reserve_base_units;
            let reserve_quote_before = pool.reserve_quote_units;
            let total_lp_before = pool.total_lp_units;
            let base_amount =
                proportional_amount(reserve_base_before, lp_units, total_lp_before, &pool_id)?;
            let quote_amount =
                proportional_amount(reserve_quote_before, lp_units, total_lp_before, &pool_id)?;
            if base_amount < min_base || quote_amount < min_quote {
                return Err(DevnetError::LiquidityBelowMinimum(liquidity_id));
            }
            let lp_position_id = deterministic_lp_position_id(&pool_id, &provider);
            let position = state
                .lp_positions
                .get_mut(&lp_position_id)
                .ok_or_else(|| DevnetError::LpPositionMissing(lp_position_id.clone()))?;
            if position.lp_units < lp_units {
                return Err(DevnetError::LpPositionInsufficient(lp_position_id));
            }
            position.lp_units -= lp_units;
            position.base_units_withdrawn += base_amount;
            position.quote_units_withdrawn += quote_amount;
            position.updated_at_block = state.next_block_number;
            let base_asset_id = pool.base_asset_id.clone();
            let quote_asset_id = pool.quote_asset_id.clone();
            let reserve_base_after = reserve_base_before
                .checked_sub(base_amount)
                .ok_or_else(|| DevnetError::PoolReserveInsufficient(pool_id.clone()))?;
            let reserve_quote_after = reserve_quote_before
                .checked_sub(quote_amount)
                .ok_or_else(|| DevnetError::PoolReserveInsufficient(pool_id.clone()))?;
            let pool = state
                .dex_pools
                .get_mut(&pool_id)
                .expect("pool was checked before production remove liquidity mutation");
            pool.reserve_base_units = reserve_base_after;
            pool.reserve_quote_units = reserve_quote_after;
            pool.total_lp_units = total_lp_before
                .checked_sub(lp_units)
                .ok_or_else(|| DevnetError::PoolReserveInsufficient(pool_id.clone()))?;
            pool.updated_at_block = state.next_block_number;
            pool.last_liquidity_receipt_id = Some(liquidity_id.clone());
            credit_protocol_balance(state, &provider, &base_asset_id, base_amount)?;
            credit_protocol_balance(state, &provider, &quote_asset_id, quote_amount)?;
            state.liquidity_receipts.insert(
                liquidity_id.clone(),
                LiquidityReceipt {
                    liquidity_id,
                    pool_id,
                    provider_account_id: provider,
                    action: "remove".to_string(),
                    base_amount_units: base_amount,
                    quote_amount_units: quote_amount,
                    lp_units,
                    reserve_base_before,
                    reserve_quote_before,
                    reserve_base_after,
                    reserve_quote_after,
                    executed_at_block: state.next_block_number,
                    no_value: true,
                },
            );
            Ok(Vec::new())
        }
        "swap" => {
            let swap_id = required_string(details, "swapId")?;
            let pool_id = required_string(details, "poolId")?;
            let trader = required_string(details, "traderAccountId")?;
            let asset_in = required_string(details, "assetInId")?;
            let amount_in = required_u64_string(details, "amountIn")?;
            let min_amount_out = required_u64_string(details, "minAmountOut")?;
            if state.swap_receipts.contains_key(&swap_id) {
                return Err(DevnetError::SwapReceiptAlreadyExists(swap_id));
            }
            let pool = state
                .dex_pools
                .get(&pool_id)
                .ok_or_else(|| DevnetError::PoolMissing(pool_id.clone()))?;
            let reserve_base_before = pool.reserve_base_units;
            let reserve_quote_before = pool.reserve_quote_units;
            let (asset_out, amount_out, reserve_base_after, reserve_quote_after) =
                if asset_in == pool.base_asset_id {
                    let amount_out = quote_out_for_base_in(pool, amount_in)?;
                    (
                        pool.quote_asset_id.clone(),
                        amount_out,
                        checked_pool_add(&pool_id, reserve_base_before, amount_in)?,
                        reserve_quote_before
                            .checked_sub(amount_out)
                            .ok_or_else(|| DevnetError::PoolReserveInsufficient(pool_id.clone()))?,
                    )
                } else if asset_in == pool.quote_asset_id {
                    let amount_out = base_out_for_quote_in(pool, amount_in)?;
                    (
                        pool.base_asset_id.clone(),
                        amount_out,
                        reserve_base_before
                            .checked_sub(amount_out)
                            .ok_or_else(|| DevnetError::PoolReserveInsufficient(pool_id.clone()))?,
                        checked_pool_add(&pool_id, reserve_quote_before, amount_in)?,
                    )
                } else {
                    return Err(DevnetError::PoolInvalidAsset(asset_in));
                };
            if amount_out < min_amount_out {
                return Err(DevnetError::SwapSlippageExceeded(swap_id));
            }
            debit_protocol_balance(state, &trader, &asset_in, amount_in)?;
            credit_protocol_balance(state, &trader, &asset_out, amount_out)?;
            let pool = state
                .dex_pools
                .get_mut(&pool_id)
                .expect("pool was checked before production swap mutation");
            pool.reserve_base_units = reserve_base_after;
            pool.reserve_quote_units = reserve_quote_after;
            pool.updated_at_block = state.next_block_number;
            pool.last_swap_receipt_id = Some(swap_id.clone());
            state.swap_receipts.insert(
                swap_id.clone(),
                SwapReceipt {
                    swap_id,
                    pool_id,
                    trader_account_id: trader,
                    asset_in_id: asset_in,
                    asset_out_id: asset_out,
                    amount_in_units: amount_in,
                    amount_out_units: amount_out,
                    reserve_base_before,
                    reserve_quote_before,
                    reserve_base_after,
                    reserve_quote_after,
                    executed_at_block: state.next_block_number,
                    no_value: true,
                },
            );
            Ok(Vec::new())
        }
        "withdrawal_intent" => {
            let withdrawal_intent_id = required_string(details, "withdrawalIntentId")?;
            let source_account_id = required_string(details, "sourceAccountId")?;
            let asset_id = required_string(details, "assetId")?;
            let amount = required_u64_string(details, "amount")?;
            debit_protocol_balance(state, &source_account_id, &asset_id, amount)?;
            let release_evidence_id = state
                .protocol_bridge_evidence
                .values()
                .find(|evidence| {
                    evidence
                        .release
                        .as_ref()
                        .is_some_and(|release| release.withdrawal_intent_id == withdrawal_intent_id)
                })
                .map(|evidence| evidence.evidence_id.clone());
            state.protocol_withdrawals.insert(
                withdrawal_intent_id.clone(),
                ProtocolWithdrawalIntent {
                    withdrawal_intent_id,
                    source_account_id,
                    destination_chain_id: required_u64_number(details, "destinationChainId")?,
                    destination_address: required_string(details, "destinationAddress")?,
                    asset_id,
                    amount_units: amount,
                    release_policy_hash: required_string(details, "releasePolicyHash")?,
                    release_evidence_id: release_evidence_id.clone(),
                    receipt_id: receipt_id.to_string(),
                    event_id: event_id.to_string(),
                    status: "pending_release".to_string(),
                    created_at_block: state.next_block_number,
                    no_value: true,
                },
            );
            Ok(release_evidence_id.into_iter().collect())
        }
        "validator_authority_config" => {
            let authority_id = required_string(details, "authorityId")?;
            let validator_account_id = required_string(details, "validatorAccountId")?;
            let account = state
                .protocol_accounts
                .get(&validator_account_id)
                .ok_or_else(|| DevnetError::ProtocolAccountMissing(validator_account_id.clone()))?;
            state.protocol_validator_authorities.insert(
                authority_id.clone(),
                ProtocolValidatorAuthority {
                    authority_id,
                    account_id: validator_account_id,
                    public_key: account.public_key.clone(),
                    address: account.address.clone(),
                    authority_type: required_string(details, "authorityType")?,
                    voting_power: required_u64_string(details, "votingPower")?,
                    finality_weight: required_u64_string(details, "votingPower")?,
                    metadata_hash: required_string(details, "metadataHash")?,
                    status: "active".to_string(),
                    production_ready: false,
                },
            );
            Ok(Vec::new())
        }
        "finality_vote" => {
            let vote_id = required_string(details, "voteId")?;
            state.protocol_finality_votes.insert(
                vote_id.clone(),
                ProtocolFinalityVote {
                    vote_id,
                    validator_account_id: required_string(details, "validatorAccountId")?,
                    height: required_u64_string(details, "height")?,
                    block_hash: required_string(details, "blockHash")?,
                    state_root: required_string(details, "stateRoot")?,
                    vote_round: required_u64_string(details, "voteRound")?,
                    receipt_id: receipt_id.to_string(),
                    event_id: event_id.to_string(),
                    recorded_at_block: state.next_block_number,
                },
            );
            Ok(Vec::new())
        }
        "finality_certificate" => {
            let certificate_id = required_string(details, "certificateId")?;
            let vote_ids = required_string_array(details, "voteIds")?;
            for vote_id in &vote_ids {
                if !state.protocol_finality_votes.contains_key(vote_id) {
                    return Err(DevnetError::ProtocolFinalityVoteMissing(vote_id.clone()));
                }
            }
            state.protocol_finality_certificates.insert(
                certificate_id.clone(),
                ProtocolFinalityCertificate {
                    certificate_id,
                    height: required_u64_string(details, "height")?,
                    block_hash: required_string(details, "blockHash")?,
                    state_root: required_string(details, "stateRoot")?,
                    signer_set_root: required_string(details, "signerSetRoot")?,
                    vote_ids,
                    quorum_numerator: required_u64_number(details, "quorumNumerator")?,
                    quorum_denominator: required_u64_number(details, "quorumDenominator")?,
                    receipt_id: receipt_id.to_string(),
                    event_id: event_id.to_string(),
                    status: "accepted".to_string(),
                    accepted_at_block: state.next_block_number,
                },
            );
            Ok(Vec::new())
        }
        other if is_object_lifecycle_payload(other) => {
            let lifecycle_update_id = required_string(details, "lifecycleUpdateId")?;
            if state
                .protocol_object_store
                .contains_key(&lifecycle_update_id)
            {
                return Err(DevnetError::ProtocolObjectAlreadyExists(
                    lifecycle_update_id,
                ));
            }
            state.protocol_object_store.insert(
                lifecycle_update_id.clone(),
                ProtocolObjectStoreEntry {
                    lifecycle_update_id,
                    payload_type: payload_type.to_string(),
                    object_type: required_string(details, "objectType")?,
                    operation: required_string(details, "operation")?,
                    object_id: required_string(details, "objectId")?,
                    object_hash: required_string(details, "objectHash")?,
                    status: required_string(details, "status")?,
                    rootfield_id: optional_string(details, "rootfieldId"),
                    source_receipt_id: optional_string(details, "sourceReceiptId"),
                    parent_object_id: optional_string(details, "parentObjectId"),
                    receipt_id: receipt_id.to_string(),
                    event_id: event_id.to_string(),
                    updated_at_block: state.next_block_number,
                },
            );
            Ok(Vec::new())
        }
        other => Err(DevnetError::ProtocolUnsupportedPayload(other.to_string())),
    }
}

fn parse_protocol_bridge_evidence(value: &Value) -> Result<ProtocolBridgeEvidence, DevnetError> {
    serde_json::from_value(value.clone())
        .map_err(|error| DevnetError::ProtocolSchemaValidation(error.to_string()))
}

fn validate_protocol_bridge_evidence(
    state: &ChainState,
    evidence: &ProtocolBridgeEvidence,
) -> Result<(), DevnetError> {
    if evidence.schema != "flowchain.production_l1.bridge_evidence.v0" {
        return Err(DevnetError::ProtocolSchemaValidation(
            evidence.evidence_id.clone(),
        ));
    }
    if evidence.source_chain_id != PRODUCTION_L1_BASE_SOURCE_CHAIN_ID {
        return Err(DevnetError::ProtocolInvalidBridgeSourceChain(
            evidence.evidence_id.clone(),
        ));
    }
    if evidence.source_network != PRODUCTION_L1_BASE_SOURCE_NETWORK {
        return Err(DevnetError::ProtocolInvalidBridgeSourceChain(
            evidence.evidence_id.clone(),
        ));
    }
    if evidence.lockbox_address.to_ascii_lowercase()
        != PRODUCTION_L1_LOCKBOX_ADDRESS.to_ascii_lowercase()
    {
        return Err(DevnetError::ProtocolWrongLockbox(
            evidence.lockbox_address.clone(),
        ));
    }
    if evidence.finality_status != "source_finalized" {
        return Err(DevnetError::ProtocolBridgeConfirmationUnsatisfied(
            evidence.evidence_id.clone(),
        ));
    }
    let amount = parse_u64_string(&evidence.amount, "amount")?;
    if amount == 0 || amount > PRODUCTION_L1_BRIDGE_CREDIT_CAP_UNITS {
        return Err(DevnetError::ProtocolBridgeAmountOverCap(
            evidence.evidence_id.clone(),
        ));
    }
    if state
        .protocol_bridge_replay_index
        .contains_key(&evidence.duplicate_key)
        || state
            .protocol_bridge_evidence
            .values()
            .any(|stored| stored.duplicate_key == evidence.duplicate_key
                && stored.evidence_id != evidence.evidence_id)
    {
        return Err(DevnetError::ProtocolDuplicateBridgeEvent(
            evidence.duplicate_key.clone(),
        ));
    }

    let duplicate_key = protocol_bridge_duplicate_key(evidence);
    if duplicate_key != evidence.duplicate_key {
        return Err(DevnetError::ProtocolMutatedBridgeEvidence(
            evidence.evidence_id.clone(),
        ));
    }
    let evidence_hash = protocol_bridge_evidence_hash(evidence);
    if evidence_hash != evidence.evidence_hash {
        return Err(DevnetError::ProtocolMutatedBridgeEvidence(
            evidence.evidence_id.clone(),
        ));
    }
    let evidence_id = hash_json(
        "flowchain.production_l1.bridge_evidence_id.v0",
        &serde_json::json!({ "evidenceHash": evidence_hash }),
    );
    if evidence_id != evidence.evidence_id {
        return Err(DevnetError::ProtocolMutatedBridgeEvidence(
            evidence.evidence_id.clone(),
        ));
    }
    if evidence.evidence_type == "deposit_observation" && evidence.release.is_some() {
        return Err(DevnetError::ProtocolSchemaValidation(
            evidence.evidence_id.clone(),
        ));
    }
    if evidence.evidence_type == "withdrawal_release" && evidence.release.is_none() {
        return Err(DevnetError::ProtocolSchemaValidation(
            evidence.evidence_id.clone(),
        ));
    }
    Ok(())
}

fn protocol_bridge_duplicate_key(evidence: &ProtocolBridgeEvidence) -> String {
    hash_json(
        "flowchain.production_l1.bridge_duplicate_key.v0",
        &protocol_source_event_key(evidence),
    )
}

fn protocol_source_event_key(evidence: &ProtocolBridgeEvidence) -> Value {
    serde_json::json!({
        "sourceChainId": evidence.source_chain_id,
        "lockboxAddress": evidence.lockbox_address,
        "sourceTxHash": evidence.source_tx_hash,
        "sourceLogIndex": evidence.source_log_index
    })
}

fn protocol_bridge_evidence_hash(evidence: &ProtocolBridgeEvidence) -> String {
    hash_json(
        "flowchain.production_l1.bridge_evidence_hash.v0",
        &serde_json::json!({
            "evidenceType": evidence.evidence_type,
            "sourceChainId": evidence.source_chain_id,
            "sourceNetwork": evidence.source_network,
            "lockboxAddress": evidence.lockbox_address,
            "sourceTxHash": evidence.source_tx_hash,
            "sourceBlockNumber": evidence.source_block_number,
            "sourceLogIndex": evidence.source_log_index,
            "tokenAddress": evidence.token_address,
            "assetId": evidence.asset_id,
            "depositorAddress": evidence.depositor_address,
            "localRecipientAccountId": evidence.local_recipient_account_id,
            "amount": evidence.amount,
            "observedByRelayerAccountId": evidence.observed_by_relayer_account_id,
            "finalityStatus": evidence.finality_status,
            "observationId": evidence.observation_id,
            "creditId": evidence.credit_id,
            "release": evidence.release,
            "duplicateKey": evidence.duplicate_key
        }),
    )
}

fn production_receipt_id(tx_id: &str, payload_type: &str, status: &str) -> String {
    let receipt_id_input = hash_json(
        "flowchain.production_l1.receipt_id_input.v0",
        &serde_json::json!({
            "txId": tx_id,
            "payloadType": payload_type,
            "status": status
        }),
    );
    hash_json(
        "flowchain.production_l1.receipt_id.v0",
        &serde_json::json!({ "receiptIdInput": receipt_id_input }),
    )
}

fn production_event_id(tx_id: &str, receipt_id: &str, event_type: &str, index: usize) -> String {
    let deterministic_id_input = hash_json(
        "flowchain.production_l1.event_id_input.v0",
        &serde_json::json!({
            "txId": tx_id,
            "receiptId": receipt_id,
            "eventType": event_type,
            "index": index
        }),
    );
    hash_json(
        "flowchain.production_l1.event_id.v0",
        &serde_json::json!({ "deterministicIdInput": deterministic_id_input }),
    )
}

fn debit_protocol_balance(
    state: &mut ChainState,
    account_id: &str,
    asset_id: &str,
    amount_units: u64,
) -> Result<(), DevnetError> {
    ensure_protocol_account_active(state, account_id)?;
    let balance_id = protocol_balance_id(account_id, asset_id);
    let balance = state
        .protocol_balances
        .get_mut(&balance_id)
        .ok_or_else(|| DevnetError::ProtocolBalanceMissing(balance_id.clone()))?;
    if balance.amount_units < amount_units {
        return Err(DevnetError::ProtocolBalanceInsufficient(balance_id));
    }
    balance.amount_units -= amount_units;
    balance.updated_at_block = state.next_block_number;
    Ok(())
}

fn credit_protocol_balance(
    state: &mut ChainState,
    account_id: &str,
    asset_id: &str,
    amount_units: u64,
) -> Result<(), DevnetError> {
    ensure_protocol_account_active(state, account_id)?;
    if amount_units == 0 {
        return Err(DevnetError::ProtocolBalanceOverflow(account_id.to_string()));
    }
    let balance_id = protocol_balance_id(account_id, asset_id);
    let balance = state
        .protocol_balances
        .entry(balance_id.clone())
        .or_insert_with(|| ProtocolBalance {
            balance_id,
            account_id: account_id.to_string(),
            asset_id: asset_id.to_string(),
            amount_units: 0,
            balance_type: if asset_id == PRODUCTION_L1_NATIVE_ASSET_ID {
                "native_local_unit".to_string()
            } else {
                "test_token".to_string()
            },
            updated_at_block: state.next_block_number,
            no_value: true,
        });
    balance.amount_units = balance
        .amount_units
        .checked_add(amount_units)
        .ok_or_else(|| DevnetError::ProtocolBalanceOverflow(balance.balance_id.clone()))?;
    balance.updated_at_block = state.next_block_number;
    Ok(())
}

fn ensure_protocol_account_active(state: &ChainState, account_id: &str) -> Result<(), DevnetError> {
    match state.protocol_accounts.get(account_id) {
        Some(account) if account.status == "active" => Ok(()),
        Some(_) => Err(DevnetError::ProtocolAccountInactive(account_id.to_string())),
        None => Err(DevnetError::ProtocolAccountMissing(account_id.to_string())),
    }
}

fn expected_event_type(payload_type: &str) -> Option<&'static str> {
    Some(match payload_type {
        "native_transfer" => "NativeTransferRecorded",
        "faucet_funding" => "FaucetFundingRecorded",
        "bridge_credit" => "BridgeCreditApplied",
        "token_launch" => "TokenLaunched",
        "token_mint" => "TokenMinted",
        "token_transfer" => "TokenTransferred",
        "pool_create" => "PoolCreated",
        "add_liquidity" => "LiquidityAdded",
        "remove_liquidity" => "LiquidityRemoved",
        "swap" => "SwapExecuted",
        "withdrawal_intent" => "WithdrawalIntentRecorded",
        "validator_authority_config" => "ValidatorAuthorityConfigured",
        "finality_vote" => "FinalityVoteRecorded",
        "finality_certificate" => "FinalityCertificateRecorded",
        other if is_object_lifecycle_payload(other) => "ObjectLifecycleUpdated",
        _ => return None,
    })
}

fn is_object_lifecycle_payload(payload_type: &str) -> bool {
    matches!(
        payload_type,
        "agent_account_update"
            | "model_passport_update"
            | "work_receipt_update"
            | "artifact_availability_proof_update"
            | "verifier_module_update"
            | "verifier_report_update"
            | "memory_cell_update"
            | "challenge_update"
            | "finality_receipt_update"
    )
}

fn emitted_event_types(payload: &Value) -> Result<Vec<String>, DevnetError> {
    payload
        .get("emittedEventTypes")
        .and_then(Value::as_array)
        .ok_or_else(|| DevnetError::ProtocolInvalidEvent("missing emittedEventTypes".to_string()))?
        .iter()
        .map(|value| {
            value.as_str().map(ToOwned::to_owned).ok_or_else(|| {
                DevnetError::ProtocolInvalidEvent("event type must be a string".to_string())
            })
        })
        .collect()
}

fn subject_id_for_payload(payload: &Value, details: &Value) -> Result<String, DevnetError> {
    for key in [
        "tokenId",
        "poolId",
        "creditId",
        "withdrawalIntentId",
        "objectId",
        "authorityId",
    ] {
        if let Some(value) = details.get(key).and_then(Value::as_str) {
            return Ok(value.to_string());
        }
    }
    required_string(payload, "payloadId")
}

fn expect_string(value: &Value, key: &str, expected: &str) -> Result<(), DevnetError> {
    let actual = required_string(value, key)?;
    if actual == expected {
        return Ok(());
    }
    match key {
        "chainId" => Err(DevnetError::ProtocolWrongChainId(actual)),
        "networkProfile" => Err(DevnetError::ProtocolWrongNetworkProfile(actual)),
        "genesisHash" => Err(DevnetError::ProtocolWrongGenesisHash(actual)),
        _ => Err(DevnetError::ProtocolSchemaValidation(format!(
            "{key} expected {expected} got {actual}"
        ))),
    }
}

fn required_string(value: &Value, key: &str) -> Result<String, DevnetError> {
    value
        .get(key)
        .and_then(Value::as_str)
        .map(ToOwned::to_owned)
        .ok_or_else(|| DevnetError::ProtocolSchemaValidation(format!("missing string {key}")))
}

fn optional_string(value: &Value, key: &str) -> Option<String> {
    value.get(key).and_then(Value::as_str).map(ToOwned::to_owned)
}

fn required_string_array(value: &Value, key: &str) -> Result<Vec<String>, DevnetError> {
    value
        .get(key)
        .and_then(Value::as_array)
        .ok_or_else(|| DevnetError::ProtocolSchemaValidation(format!("missing array {key}")))?
        .iter()
        .map(|entry| {
            entry.as_str().map(ToOwned::to_owned).ok_or_else(|| {
                DevnetError::ProtocolSchemaValidation(format!("{key} entries must be strings"))
            })
        })
        .collect()
}

fn required_u64_string(value: &Value, key: &str) -> Result<u64, DevnetError> {
    let raw = required_string(value, key)?;
    parse_u64_string(&raw, key)
}

fn required_u64_number(value: &Value, key: &str) -> Result<u64, DevnetError> {
    if let Some(number) = value.get(key).and_then(Value::as_u64) {
        return Ok(number);
    }
    required_u64_string(value, key)
}

fn parse_u64_string(raw: &str, key: &str) -> Result<u64, DevnetError> {
    raw.parse::<u64>().map_err(|_| {
        DevnetError::ProtocolSchemaValidation(format!("{key} must be a u64 string"))
    })
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
