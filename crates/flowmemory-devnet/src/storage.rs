use crate::hash::{hash_json, keccak_hex};
use crate::model::{
    BLOCK_SCHEMA, ChainState, GENESIS_HASH, STATE_SCHEMA, StateMapRoots, Transaction, TxEnvelope,
    finalized_hash, finalized_height, genesis_state, latest_hash, latest_height, state_map_roots,
    state_root,
};
use anyhow::{Context, Result, anyhow};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::{Path, PathBuf};

pub const DEFAULT_STATE_PATH: &str = "devnet/local/state.json";
pub const STORAGE_VERSION: u64 = 1;
pub const STORAGE_MANIFEST_SCHEMA: &str = "flowmemory.local_devnet.storage_manifest.v1";
pub const STORAGE_EXPORT_SCHEMA: &str = "flowmemory.local_devnet.storage_export.v1";
pub const STORAGE_INDEX_SCHEMA: &str = "flowmemory.local_devnet.storage_indexes.v1";
pub const STORAGE_EVENT_SCHEMA: &str = "flowmemory.local_devnet.storage_event.v1";
pub const STORAGE_POLICY: &str = "archival";

pub fn default_state_path() -> PathBuf {
    PathBuf::from(DEFAULT_STATE_PATH)
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct StorageManifest {
    pub schema: String,
    pub storage_version: u64,
    pub chain_id: String,
    pub genesis_hash: String,
    pub data_directory: String,
    pub latest_height: u64,
    pub latest_hash: String,
    pub finalized_height: u64,
    pub finalized_hash: String,
    pub state_root: String,
    pub map_roots: StateMapRoots,
    pub pruning_policy: String,
    pub archival: bool,
    pub created_tool_version: String,
    pub compatibility_state_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct BlockHeaderRecord {
    pub schema: String,
    pub block_number: u64,
    pub parent_hash: String,
    pub logical_time: u64,
    pub tx_ids: Vec<String>,
    pub receipt_count: usize,
    pub state_root: String,
    pub block_hash: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct TxRecord {
    pub schema: String,
    pub tx_id: String,
    pub block_height: u64,
    pub block_hash: String,
    pub tx: TxEnvelope,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ReceiptRecord {
    pub schema: String,
    pub tx_id: String,
    pub block_height: u64,
    pub block_hash: String,
    pub status: String,
    pub error: Option<String>,
    pub authorization: Option<crate::model::LocalAuthorization>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct EventRecord {
    pub schema: String,
    pub event_id: String,
    pub event_type: String,
    pub block_height: u64,
    pub block_hash: String,
    pub tx_id: String,
    pub receipt_status: String,
    pub object_id: Option<String>,
    pub receipt_id: Option<String>,
    pub account_ids: Vec<String>,
    pub token_ids: Vec<String>,
    pub pool_ids: Vec<String>,
    pub rootfield_ids: Vec<String>,
    pub bridge_observation_id: Option<String>,
    pub bridge_credit_id: Option<String>,
    pub withdrawal_intent_id: Option<String>,
    pub release_evidence_id: Option<String>,
    pub replay_key: Option<String>,
    pub payload: Value,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct TxIndexEntry {
    pub tx_id: String,
    pub block_height: u64,
    pub block_hash: String,
    pub tx_path: String,
    pub receipt_path: String,
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ReceiptIndexEntry {
    pub tx_id: String,
    pub block_height: u64,
    pub block_hash: String,
    pub receipt_path: String,
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct EventIndexEntry {
    pub event_id: String,
    pub event_type: String,
    pub block_height: u64,
    pub block_hash: String,
    pub tx_id: String,
    pub event_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct BalanceChangeIndexEntry {
    pub tx_id: String,
    pub block_height: u64,
    pub asset_id: String,
    pub delta_units: i128,
    pub reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct BridgeObservationIndexEntry {
    pub observation_id: String,
    pub source_event_key: String,
    pub replay_key: String,
    pub evidence_ref: String,
    pub credit_ids: Vec<String>,
    pub block_height: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct BridgeCreditIndexEntry {
    pub credit_id: String,
    pub observation_id: String,
    pub account_id: String,
    pub asset_id: String,
    pub amount_units: u64,
    pub source_event_key: String,
    pub replay_key: String,
    pub block_height: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct WithdrawalIntentIndexEntry {
    pub withdrawal_intent_id: String,
    pub account_id: String,
    pub asset_id: String,
    pub amount_units: u64,
    pub destination_chain_id: String,
    pub release_policy: String,
    pub block_height: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ReleaseEvidenceIndexEntry {
    pub release_evidence_id: String,
    pub withdrawal_intent_id: String,
    pub source_chain_id: String,
    pub release_tx_hash: String,
    pub evidence_ref: String,
    pub block_height: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ReplayKeyIndexEntry {
    pub replay_key: String,
    pub source_id: String,
    pub source_type: String,
    pub consumed_at_block: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct StorageIndexes {
    pub schema: String,
    pub tx_by_id: BTreeMap<String, TxIndexEntry>,
    pub receipt_by_tx_id: BTreeMap<String, ReceiptIndexEntry>,
    pub event_by_id: BTreeMap<String, EventIndexEntry>,
    pub account_to_tx_ids: BTreeMap<String, Vec<String>>,
    pub account_balance_changes: BTreeMap<String, Vec<BalanceChangeIndexEntry>>,
    pub token_to_event_ids: BTreeMap<String, Vec<String>>,
    pub pool_to_event_ids: BTreeMap<String, Vec<String>>,
    pub rootfield_to_event_ids: BTreeMap<String, Vec<String>>,
    pub bridge_event_to_observation_id: BTreeMap<String, String>,
    pub bridge_observation_by_id: BTreeMap<String, BridgeObservationIndexEntry>,
    pub bridge_credit_by_id: BTreeMap<String, BridgeCreditIndexEntry>,
    pub withdrawal_intent_by_id: BTreeMap<String, WithdrawalIntentIndexEntry>,
    pub release_evidence_by_id: BTreeMap<String, ReleaseEvidenceIndexEntry>,
    pub replay_key_by_id: BTreeMap<String, ReplayKeyIndexEntry>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct StorageExport {
    pub schema: String,
    pub storage_version: u64,
    pub chain_id: String,
    pub genesis_hash: String,
    pub latest_height: u64,
    pub latest_hash: String,
    pub finalized_height: u64,
    pub finalized_hash: String,
    pub state_root: String,
    pub map_roots: StateMapRoots,
    pub manifest: StorageManifest,
    pub pruning_policy: String,
    pub included_files: Vec<String>,
    pub evidence_safety: EvidenceSafety,
    pub state: ChainState,
    pub indexes: StorageIndexes,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct EvidenceSafety {
    pub exports_public_evidence_only: bool,
    pub wallet_vaults_excluded: bool,
    pub excludes_env_files: bool,
    pub network_endpoints_excluded: bool,
    pub signing_secrets_excluded: bool,
    pub recovery_phrases_excluded: bool,
    pub api_credentials_and_callbacks_excluded: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct StorageHealth {
    pub schema: String,
    pub data_directory: String,
    pub latest_height: u64,
    pub latest_hash: String,
    pub finalized_height: u64,
    pub finalized_hash: String,
    pub state_root: String,
    pub tx_index_entries: usize,
    pub receipt_index_entries: usize,
    pub event_index_entries: usize,
    pub account_index_entries: usize,
    pub token_index_entries: usize,
    pub pool_index_entries: usize,
    pub bridge_observation_entries: usize,
    pub bridge_credit_entries: usize,
    pub withdrawal_intent_entries: usize,
    pub release_evidence_entries: usize,
    pub replay_key_entries: usize,
    pub recovered_derived_records: bool,
}

pub fn load_state(path: &Path) -> Result<ChainState> {
    let data_dir = storage_data_dir(path);
    cleanup_temporary_files(&data_dir)?;

    if manifest_path(&data_dir).exists() {
        let (state, recovered) = load_from_manifest(path, &data_dir)?;
        if recovered {
            return Ok(state);
        }
        return Ok(state);
    }

    let body = fs::read_to_string(path)
        .with_context(|| format!("failed to read state file {}", path.display()))?;
    let state: ChainState = serde_json::from_str(body.trim_start_matches('\u{feff}'))
        .with_context(|| format!("failed to parse state file {}", path.display()))?;
    validate_chain_state(&state)?;
    backup_legacy_state(path, &data_dir, &state)?;
    commit_durable_state(path, &state)?;
    Ok(state)
}

pub fn load_or_genesis(path: &Path) -> Result<ChainState> {
    if path.exists() || manifest_path(&storage_data_dir(path)).exists() {
        load_state(path)
    } else {
        Ok(genesis_state())
    }
}

pub fn save_state(path: &Path, state: &ChainState) -> Result<()> {
    validate_chain_state(state)?;
    commit_durable_state(path, state)
}

pub fn reset_state(path: &Path) -> Result<ChainState> {
    if let Some(parent) = path.parent()
        && parent.exists()
    {
        fs::remove_dir_all(parent)
            .with_context(|| format!("failed to remove {}", parent.display()))?;
    }
    let state = genesis_state();
    save_state(path, &state)?;
    Ok(state)
}

pub fn storage_data_dir_for_state(path: &Path) -> PathBuf {
    storage_data_dir(path)
}

pub fn manifest_for_state_path(path: &Path, state: &ChainState) -> StorageManifest {
    manifest_from_state(path, state)
}

pub fn index_health(path: &Path) -> Result<StorageHealth> {
    let data_dir = storage_data_dir(path);
    let manifest = read_json::<StorageManifest>(&manifest_path(&data_dir))?;
    let state = read_json::<ChainState>(&snapshot_path(&data_dir, manifest.latest_height))?;
    let indexes = read_json::<StorageIndexes>(&indexes_path(&data_dir))?;
    validate_manifest(&manifest)?;
    validate_manifest_matches_state(&manifest, &state)?;
    validate_indexes(&data_dir, &state, &indexes)?;
    Ok(health_from_parts(&data_dir, &manifest, &indexes, false))
}

pub fn export_state(path: &Path, out: &Path) -> Result<StorageExport> {
    let state = load_or_genesis(path)?;
    let export = export_from_state(path, &state);
    validate_export(&export)?;
    write_json_atomic(out, &export)?;
    Ok(export)
}

pub fn import_state(path: &Path, from: &Path) -> Result<ChainState> {
    let data_dir = storage_data_dir(path);
    if path.exists() || data_dir.exists() {
        return Err(anyhow!(
            "import target must be clean; remove {} and {} or choose a new --state path",
            path.display(),
            data_dir.display()
        ));
    }
    let export = read_json::<StorageExport>(from)?;
    validate_export(&export)?;
    commit_durable_state(path, &export.state)?;
    Ok(export.state)
}

fn storage_data_dir(path: &Path) -> PathBuf {
    let parent = path.parent().unwrap_or_else(|| Path::new("."));
    match path.file_name().and_then(|name| name.to_str()) {
        Some("state.json") => parent.join("storage"),
        Some(file_name) => parent.join(format!("{file_name}.storage")),
        None => parent.join("storage"),
    }
}

fn manifest_path(data_dir: &Path) -> PathBuf {
    data_dir.join("manifest.json")
}

fn indexes_path(data_dir: &Path) -> PathBuf {
    data_dir.join("indexes").join("storage-indexes.json")
}

fn snapshot_path(data_dir: &Path, height: u64) -> PathBuf {
    data_dir
        .join("snapshots")
        .join(format!("{height:020}.json"))
}

fn block_path(data_dir: &Path, height: u64) -> PathBuf {
    data_dir.join("blocks").join(format!("{height:020}.json"))
}

fn header_path(data_dir: &Path, height: u64) -> PathBuf {
    data_dir.join("headers").join(format!("{height:020}.json"))
}

fn tx_path(data_dir: &Path, tx_id: &str) -> PathBuf {
    data_dir
        .join("transactions")
        .join(format!("{}.json", file_safe_id(tx_id)))
}

fn receipt_path(data_dir: &Path, tx_id: &str) -> PathBuf {
    data_dir
        .join("receipts")
        .join(format!("{}.json", file_safe_id(tx_id)))
}

fn event_path(data_dir: &Path, event_id: &str) -> PathBuf {
    data_dir
        .join("events")
        .join(format!("{}.json", file_safe_id(event_id)))
}

fn relative_path(data_dir: &Path, path: &Path) -> String {
    path.strip_prefix(data_dir)
        .unwrap_or(path)
        .to_string_lossy()
        .replace('\\', "/")
}

fn read_json<T>(path: &Path) -> Result<T>
where
    for<'de> T: Deserialize<'de>,
{
    let body =
        fs::read_to_string(path).with_context(|| format!("failed to read {}", path.display()))?;
    serde_json::from_str(body.trim_start_matches('\u{feff}'))
        .with_context(|| format!("failed to parse {}", path.display()))
}

fn write_json_atomic<T: Serialize>(path: &Path, value: &T) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("failed to create directory {}", parent.display()))?;
    }
    let body = serde_json::to_string_pretty(value)?;
    let tmp = path.with_file_name(format!(
        ".{}.{}.tmp",
        path.file_name()
            .and_then(|name| name.to_str())
            .unwrap_or("record"),
        std::process::id()
    ));
    fs::write(&tmp, format!("{body}\n"))
        .with_context(|| format!("failed to write temporary file {}", tmp.display()))?;
    if path.exists() {
        fs::remove_file(path)
            .with_context(|| format!("failed to replace existing {}", path.display()))?;
    }
    fs::rename(&tmp, path)
        .with_context(|| format!("failed to move {} to {}", tmp.display(), path.display()))
}

fn commit_durable_state(path: &Path, state: &ChainState) -> Result<()> {
    let data_dir = storage_data_dir(path);
    create_storage_directories(&data_dir)?;
    let indexes = build_storage_indexes(&data_dir, state)?;

    for block in &state.blocks {
        write_json_atomic(&block_path(&data_dir, block.block_number), block)?;
        write_json_atomic(
            &header_path(&data_dir, block.block_number),
            &BlockHeaderRecord {
                schema: "flowmemory.local_devnet.block_header.v1".to_string(),
                block_number: block.block_number,
                parent_hash: block.parent_hash.clone(),
                logical_time: block.logical_time,
                tx_ids: block.tx_ids.clone(),
                receipt_count: block.receipts.len(),
                state_root: block.state_root.clone(),
                block_hash: block.block_hash.clone(),
            },
        )?;

        for tx in &block.transactions {
            write_json_atomic(
                &tx_path(&data_dir, &tx.tx_id),
                &TxRecord {
                    schema: "flowmemory.local_devnet.tx_record.v1".to_string(),
                    tx_id: tx.tx_id.clone(),
                    block_height: block.block_number,
                    block_hash: block.block_hash.clone(),
                    tx: tx.clone(),
                },
            )?;
        }

        for receipt in &block.receipts {
            write_json_atomic(
                &receipt_path(&data_dir, &receipt.tx_id),
                &ReceiptRecord {
                    schema: "flowmemory.local_devnet.receipt_record.v1".to_string(),
                    tx_id: receipt.tx_id.clone(),
                    block_height: block.block_number,
                    block_hash: block.block_hash.clone(),
                    status: receipt.status.clone(),
                    error: receipt.error.clone(),
                    authorization: receipt.authorization.clone(),
                },
            )?;
        }
    }

    for event in build_event_records(state) {
        write_json_atomic(&event_path(&data_dir, &event.event_id), &event)?;
    }

    write_object_maps(&data_dir, state)?;
    write_json_atomic(&indexes_path(&data_dir), &indexes)?;
    write_json_atomic(&snapshot_path(&data_dir, latest_height(state)), state)?;
    write_json_atomic(&data_dir.join("snapshots").join("latest.json"), state)?;

    let manifest = manifest_from_state(path, state);
    validate_manifest_matches_state(&manifest, state)?;
    write_json_atomic(&manifest_path(&data_dir), &manifest)?;
    write_json_atomic(path, state)?;
    Ok(())
}

fn create_storage_directories(data_dir: &Path) -> Result<()> {
    for dir in [
        data_dir,
        &data_dir.join("blocks"),
        &data_dir.join("headers"),
        &data_dir.join("transactions"),
        &data_dir.join("receipts"),
        &data_dir.join("events"),
        &data_dir.join("objects"),
        &data_dir.join("indexes"),
        &data_dir.join("snapshots"),
        &data_dir.join("backups"),
        &data_dir.join("tmp"),
    ] {
        fs::create_dir_all(dir)
            .with_context(|| format!("failed to create storage directory {}", dir.display()))?;
    }
    Ok(())
}

fn write_object_maps(data_dir: &Path, state: &ChainState) -> Result<()> {
    let objects = data_dir.join("objects");
    write_json_atomic(
        &objects.join("operator-key-references.json"),
        &state.operator_key_references,
    )?;
    write_json_atomic(&objects.join("rootfields.json"), &state.rootfields)?;
    write_json_atomic(&objects.join("agent-accounts.json"), &state.agent_accounts)?;
    write_json_atomic(
        &objects.join("local-test-unit-balances.json"),
        &state.local_test_unit_balances,
    )?;
    write_json_atomic(&objects.join("faucet-records.json"), &state.faucet_records)?;
    write_json_atomic(
        &objects.join("balance-transfers.json"),
        &state.balance_transfers,
    )?;
    write_json_atomic(
        &objects.join("token-definitions.json"),
        &state.token_definitions,
    )?;
    write_json_atomic(&objects.join("token-balances.json"), &state.token_balances)?;
    write_json_atomic(
        &objects.join("token-mint-receipts.json"),
        &state.token_mint_receipts,
    )?;
    write_json_atomic(&objects.join("dex-pools.json"), &state.dex_pools)?;
    write_json_atomic(&objects.join("lp-positions.json"), &state.lp_positions)?;
    write_json_atomic(
        &objects.join("liquidity-receipts.json"),
        &state.liquidity_receipts,
    )?;
    write_json_atomic(&objects.join("swap-receipts.json"), &state.swap_receipts)?;
    write_json_atomic(
        &objects.join("model-passports.json"),
        &state.model_passports,
    )?;
    write_json_atomic(&objects.join("memory-cells.json"), &state.memory_cells)?;
    write_json_atomic(&objects.join("challenges.json"), &state.challenges)?;
    write_json_atomic(
        &objects.join("finality-receipts.json"),
        &state.finality_receipts,
    )?;
    write_json_atomic(
        &objects.join("artifact-commitments.json"),
        &state.artifact_commitments,
    )?;
    write_json_atomic(
        &objects.join("artifact-availability-proofs.json"),
        &state.artifact_availability_proofs,
    )?;
    write_json_atomic(
        &objects.join("verifier-modules.json"),
        &state.verifier_modules,
    )?;
    write_json_atomic(&objects.join("work-receipts.json"), &state.work_receipts)?;
    write_json_atomic(
        &objects.join("verifier-reports.json"),
        &state.verifier_reports,
    )?;
    write_json_atomic(
        &objects.join("imported-observations.json"),
        &state.imported_observations,
    )?;
    write_json_atomic(
        &objects.join("imported-verifier-reports.json"),
        &state.imported_verifier_reports,
    )?;
    write_json_atomic(
        &objects.join("bridge-observations.json"),
        &state.bridge_observations,
    )?;
    write_json_atomic(&objects.join("bridge-credits.json"), &state.bridge_credits)?;
    write_json_atomic(
        &objects.join("withdrawal-intents.json"),
        &state.withdrawal_intents,
    )?;
    write_json_atomic(
        &objects.join("release-evidence.json"),
        &state.release_evidence,
    )?;
    write_json_atomic(
        &objects.join("consumed-replay-keys.json"),
        &state.consumed_replay_keys,
    )?;
    write_json_atomic(&objects.join("base-anchors.json"), &state.base_anchors)?;
    Ok(())
}

fn load_from_manifest(path: &Path, data_dir: &Path) -> Result<(ChainState, bool)> {
    let manifest = read_json::<StorageManifest>(&manifest_path(data_dir))?;
    validate_manifest(&manifest)?;
    let state = read_json::<ChainState>(&snapshot_path(data_dir, manifest.latest_height))?;
    validate_chain_state(&state)?;
    validate_manifest_matches_state(&manifest, &state)?;

    let recovered = match read_json::<StorageIndexes>(&indexes_path(data_dir))
        .and_then(|indexes| validate_indexes(data_dir, &state, &indexes))
    {
        Ok(()) => false,
        Err(_) => {
            commit_durable_state(path, &state)?;
            true
        }
    };
    Ok((state, recovered))
}

fn validate_manifest(manifest: &StorageManifest) -> Result<()> {
    if manifest.schema != STORAGE_MANIFEST_SCHEMA {
        return Err(anyhow!(
            "unsupported storage manifest schema: {}",
            manifest.schema
        ));
    }
    if manifest.storage_version > STORAGE_VERSION {
        return Err(anyhow!(
            "unknown future storage version {}; this tool supports {}",
            manifest.storage_version,
            STORAGE_VERSION
        ));
    }
    if manifest.storage_version < STORAGE_VERSION {
        return Err(anyhow!(
            "old durable storage version {} requires an explicit migration",
            manifest.storage_version
        ));
    }
    let default = crate::model::default_config();
    if manifest.chain_id != default.chain_id {
        return Err(anyhow!(
            "storage chain id mismatch: expected {}, got {}",
            default.chain_id,
            manifest.chain_id
        ));
    }
    if manifest.genesis_hash != GENESIS_HASH {
        return Err(anyhow!(
            "storage genesis hash mismatch: expected {}, got {}",
            GENESIS_HASH,
            manifest.genesis_hash
        ));
    }
    if manifest.finalized_height > manifest.latest_height {
        return Err(anyhow!(
            "finalized height {} exceeds latest height {}",
            manifest.finalized_height,
            manifest.latest_height
        ));
    }
    validate_root("manifest state root", &manifest.state_root)?;
    validate_root("manifest latest hash", &manifest.latest_hash)?;
    validate_root("manifest finalized hash", &manifest.finalized_hash)?;
    Ok(())
}

fn validate_manifest_matches_state(manifest: &StorageManifest, state: &ChainState) -> Result<()> {
    let root = state_root(state);
    if manifest.chain_id != state.chain_id {
        return Err(anyhow!("manifest chain id does not match state chain id"));
    }
    if manifest.genesis_hash != state.genesis_hash {
        return Err(anyhow!(
            "manifest genesis hash does not match state genesis hash"
        ));
    }
    if manifest.latest_height != latest_height(state) {
        return Err(anyhow!("manifest latest height does not match state"));
    }
    if manifest.latest_hash != latest_hash(state) {
        return Err(anyhow!("manifest latest hash does not match state"));
    }
    if manifest.finalized_height != finalized_height(state) {
        return Err(anyhow!("manifest finalized height does not match state"));
    }
    if manifest.finalized_hash != finalized_hash(state) {
        return Err(anyhow!("manifest finalized hash does not match state"));
    }
    if manifest.state_root != root {
        return Err(anyhow!("manifest state root does not match state"));
    }
    Ok(())
}

fn validate_export(export: &StorageExport) -> Result<()> {
    if export.schema != STORAGE_EXPORT_SCHEMA {
        return Err(anyhow!("unsupported export schema: {}", export.schema));
    }
    if export.storage_version != STORAGE_VERSION {
        return Err(anyhow!(
            "unsupported export storage version: {}",
            export.storage_version
        ));
    }
    let default = crate::model::default_config();
    if export.chain_id != default.chain_id {
        return Err(anyhow!(
            "wrong chain id in export: expected {}, got {}",
            default.chain_id,
            export.chain_id
        ));
    }
    if export.genesis_hash != GENESIS_HASH {
        return Err(anyhow!(
            "wrong genesis hash in export: expected {}, got {}",
            GENESIS_HASH,
            export.genesis_hash
        ));
    }
    validate_root("export state root", &export.state_root)?;
    validate_chain_state(&export.state)?;
    if state_root(&export.state) != export.state_root {
        return Err(anyhow!("export state root mismatch"));
    }
    if export.latest_height != latest_height(&export.state)
        || export.latest_hash != latest_hash(&export.state)
        || export.finalized_height != finalized_height(&export.state)
        || export.finalized_hash != finalized_hash(&export.state)
    {
        return Err(anyhow!("export canonical point does not match state"));
    }
    validate_manifest(&export.manifest)?;
    validate_manifest_matches_state(&export.manifest, &export.state)?;
    validate_indexes_for_state(&export.state, &export.indexes)?;
    Ok(())
}

fn validate_chain_state(state: &ChainState) -> Result<()> {
    if state.schema != STATE_SCHEMA {
        return Err(anyhow!("unsupported state schema: {}", state.schema));
    }
    if state.config.chain_id != state.chain_id {
        return Err(anyhow!("state config chain id mismatch"));
    }
    if state.config.genesis_hash != state.genesis_hash {
        return Err(anyhow!("state config genesis hash mismatch"));
    }
    if state.chain_id != crate::model::default_config().chain_id {
        return Err(anyhow!(
            "state chain id mismatch: expected {}, got {}",
            crate::model::default_config().chain_id,
            state.chain_id
        ));
    }
    if state.genesis_hash != GENESIS_HASH {
        return Err(anyhow!(
            "state genesis hash mismatch: {}",
            state.genesis_hash
        ));
    }
    validate_root("state genesis hash", &state.genesis_hash)?;
    validate_root("state parent hash", &state.parent_hash)?;
    let mut expected_parent = state.genesis_hash.clone();
    for block in &state.blocks {
        if block.schema != BLOCK_SCHEMA {
            return Err(anyhow!(
                "unsupported block schema at {}",
                block.block_number
            ));
        }
        if block.parent_hash != expected_parent {
            return Err(anyhow!("block {} parent hash mismatch", block.block_number));
        }
        if block.block_number == 0 {
            return Err(anyhow!("block number must be greater than zero"));
        }
        if block.tx_ids.len() != block.receipts.len() {
            return Err(anyhow!(
                "block {} tx/receipt length mismatch",
                block.block_number
            ));
        }
        if !block.transactions.is_empty() && block.transactions.len() != block.tx_ids.len() {
            return Err(anyhow!(
                "block {} transaction body length mismatch",
                block.block_number
            ));
        }
        validate_root("block state root", &block.state_root)?;
        validate_root("block hash", &block.block_hash)?;
        expected_parent = block.block_hash.clone();
    }
    if state.parent_hash != expected_parent {
        return Err(anyhow!(
            "state parent hash does not match latest block hash"
        ));
    }
    if state.next_block_number != latest_height(state) + 1 {
        return Err(anyhow!(
            "state next block number does not match latest height"
        ));
    }
    validate_root("state root", &state_root(state))?;
    Ok(())
}

fn validate_root(label: &str, root: &str) -> Result<()> {
    let bytes = root.as_bytes();
    if bytes.len() != 66 || !root.starts_with("0x") {
        return Err(anyhow!("{label} is malformed: {root}"));
    }
    if !bytes[2..].iter().all(|byte| byte.is_ascii_hexdigit()) {
        return Err(anyhow!("{label} has non-hex characters: {root}"));
    }
    Ok(())
}

fn validate_indexes(data_dir: &Path, state: &ChainState, indexes: &StorageIndexes) -> Result<()> {
    validate_indexes_for_state(state, indexes)?;
    for entry in indexes.tx_by_id.values() {
        let path = data_dir.join(&entry.tx_path);
        if !path.exists() {
            return Err(anyhow!("missing tx record {}", path.display()));
        }
        let receipt = data_dir.join(&entry.receipt_path);
        if !receipt.exists() {
            return Err(anyhow!("missing receipt record {}", receipt.display()));
        }
    }
    for entry in indexes.event_by_id.values() {
        let path = data_dir.join(&entry.event_path);
        if !path.exists() {
            return Err(anyhow!("missing event record {}", path.display()));
        }
    }
    Ok(())
}

fn validate_indexes_for_state(state: &ChainState, indexes: &StorageIndexes) -> Result<()> {
    if indexes.schema != STORAGE_INDEX_SCHEMA {
        return Err(anyhow!(
            "unsupported storage index schema: {}",
            indexes.schema
        ));
    }
    let expected = build_storage_indexes(&PathBuf::from("."), state)?;
    if indexes.tx_by_id.keys().collect::<Vec<_>>() != expected.tx_by_id.keys().collect::<Vec<_>>() {
        return Err(anyhow!("tx index keys do not match state"));
    }
    if indexes.receipt_by_tx_id.keys().collect::<Vec<_>>()
        != expected.receipt_by_tx_id.keys().collect::<Vec<_>>()
    {
        return Err(anyhow!("receipt index keys do not match state"));
    }
    if indexes.event_by_id.keys().collect::<Vec<_>>()
        != expected.event_by_id.keys().collect::<Vec<_>>()
    {
        return Err(anyhow!("event index keys do not match state"));
    }
    for (account, tx_ids) in &indexes.account_to_tx_ids {
        let unique = tx_ids.iter().collect::<BTreeSet<_>>();
        if unique.len() != tx_ids.len() {
            return Err(anyhow!("duplicate tx id in account index for {account}"));
        }
    }
    Ok(())
}

fn manifest_from_state(path: &Path, state: &ChainState) -> StorageManifest {
    let data_dir = storage_data_dir(path);
    StorageManifest {
        schema: STORAGE_MANIFEST_SCHEMA.to_string(),
        storage_version: STORAGE_VERSION,
        chain_id: state.chain_id.clone(),
        genesis_hash: state.genesis_hash.clone(),
        data_directory: data_dir.to_string_lossy().replace('\\', "/"),
        latest_height: latest_height(state),
        latest_hash: latest_hash(state).to_string(),
        finalized_height: finalized_height(state),
        finalized_hash: finalized_hash(state).to_string(),
        state_root: state_root(state),
        map_roots: state_map_roots(state),
        pruning_policy: STORAGE_POLICY.to_string(),
        archival: true,
        created_tool_version: env!("CARGO_PKG_VERSION").to_string(),
        compatibility_state_path: path.to_string_lossy().replace('\\', "/"),
    }
}

fn export_from_state(path: &Path, state: &ChainState) -> StorageExport {
    let data_dir = storage_data_dir(path);
    let indexes = build_storage_indexes(&data_dir, state).expect("index build cannot fail");
    StorageExport {
        schema: STORAGE_EXPORT_SCHEMA.to_string(),
        storage_version: STORAGE_VERSION,
        chain_id: state.chain_id.clone(),
        genesis_hash: state.genesis_hash.clone(),
        latest_height: latest_height(state),
        latest_hash: latest_hash(state).to_string(),
        finalized_height: finalized_height(state),
        finalized_hash: finalized_hash(state).to_string(),
        state_root: state_root(state),
        map_roots: state_map_roots(state),
        manifest: manifest_from_state(path, state),
        pruning_policy: STORAGE_POLICY.to_string(),
        included_files: included_export_files(state),
        evidence_safety: EvidenceSafety {
            exports_public_evidence_only: true,
            wallet_vaults_excluded: true,
            excludes_env_files: true,
            network_endpoints_excluded: true,
            signing_secrets_excluded: true,
            recovery_phrases_excluded: true,
            api_credentials_and_callbacks_excluded: true,
        },
        state: state.clone(),
        indexes,
    }
}

fn included_export_files(state: &ChainState) -> Vec<String> {
    let mut files = vec![
        "manifest.json".to_string(),
        format!("snapshots/{:020}.json", latest_height(state)),
        "indexes/storage-indexes.json".to_string(),
        "objects/*.json".to_string(),
    ];
    for block in &state.blocks {
        files.push(format!("blocks/{:020}.json", block.block_number));
        files.push(format!("headers/{:020}.json", block.block_number));
    }
    files.sort();
    files
}

fn health_from_parts(
    data_dir: &Path,
    manifest: &StorageManifest,
    indexes: &StorageIndexes,
    recovered_derived_records: bool,
) -> StorageHealth {
    StorageHealth {
        schema: "flowmemory.local_devnet.storage_health.v1".to_string(),
        data_directory: data_dir.to_string_lossy().replace('\\', "/"),
        latest_height: manifest.latest_height,
        latest_hash: manifest.latest_hash.clone(),
        finalized_height: manifest.finalized_height,
        finalized_hash: manifest.finalized_hash.clone(),
        state_root: manifest.state_root.clone(),
        tx_index_entries: indexes.tx_by_id.len(),
        receipt_index_entries: indexes.receipt_by_tx_id.len(),
        event_index_entries: indexes.event_by_id.len(),
        account_index_entries: indexes.account_to_tx_ids.len(),
        token_index_entries: indexes.token_to_event_ids.len(),
        pool_index_entries: indexes.pool_to_event_ids.len(),
        bridge_observation_entries: indexes.bridge_observation_by_id.len(),
        bridge_credit_entries: indexes.bridge_credit_by_id.len(),
        withdrawal_intent_entries: indexes.withdrawal_intent_by_id.len(),
        release_evidence_entries: indexes.release_evidence_by_id.len(),
        replay_key_entries: indexes.replay_key_by_id.len(),
        recovered_derived_records,
    }
}

fn build_storage_indexes(data_dir: &Path, state: &ChainState) -> Result<StorageIndexes> {
    let mut indexes = StorageIndexes {
        schema: STORAGE_INDEX_SCHEMA.to_string(),
        tx_by_id: BTreeMap::new(),
        receipt_by_tx_id: BTreeMap::new(),
        event_by_id: BTreeMap::new(),
        account_to_tx_ids: BTreeMap::new(),
        account_balance_changes: BTreeMap::new(),
        token_to_event_ids: BTreeMap::new(),
        pool_to_event_ids: BTreeMap::new(),
        rootfield_to_event_ids: BTreeMap::new(),
        bridge_event_to_observation_id: BTreeMap::new(),
        bridge_observation_by_id: BTreeMap::new(),
        bridge_credit_by_id: BTreeMap::new(),
        withdrawal_intent_by_id: BTreeMap::new(),
        release_evidence_by_id: BTreeMap::new(),
        replay_key_by_id: BTreeMap::new(),
    };

    for block in &state.blocks {
        for receipt in &block.receipts {
            let tx = block
                .transactions
                .iter()
                .find(|candidate| candidate.tx_id == receipt.tx_id);
            indexes.tx_by_id.insert(
                receipt.tx_id.clone(),
                TxIndexEntry {
                    tx_id: receipt.tx_id.clone(),
                    block_height: block.block_number,
                    block_hash: block.block_hash.clone(),
                    tx_path: relative_path(data_dir, &tx_path(data_dir, &receipt.tx_id)),
                    receipt_path: relative_path(data_dir, &receipt_path(data_dir, &receipt.tx_id)),
                    status: receipt.status.clone(),
                },
            );
            indexes.receipt_by_tx_id.insert(
                receipt.tx_id.clone(),
                ReceiptIndexEntry {
                    tx_id: receipt.tx_id.clone(),
                    block_height: block.block_number,
                    block_hash: block.block_hash.clone(),
                    receipt_path: relative_path(data_dir, &receipt_path(data_dir, &receipt.tx_id)),
                    status: receipt.status.clone(),
                },
            );
            if let Some(tx) = tx {
                for account_id in account_ids_for_tx(&tx.tx) {
                    push_unique(
                        indexes.account_to_tx_ids.entry(account_id).or_default(),
                        receipt.tx_id.clone(),
                    );
                }
                for change in balance_changes_for_tx(&tx.tx, block.block_number, &receipt.tx_id) {
                    indexes
                        .account_balance_changes
                        .entry(change.0)
                        .or_default()
                        .push(change.1);
                }
            }
        }
    }

    for event in build_event_records(state) {
        indexes.event_by_id.insert(
            event.event_id.clone(),
            EventIndexEntry {
                event_id: event.event_id.clone(),
                event_type: event.event_type.clone(),
                block_height: event.block_height,
                block_hash: event.block_hash.clone(),
                tx_id: event.tx_id.clone(),
                event_path: relative_path(data_dir, &event_path(data_dir, &event.event_id)),
            },
        );
        for account_id in &event.account_ids {
            push_unique(
                indexes
                    .account_to_tx_ids
                    .entry(account_id.clone())
                    .or_default(),
                event.tx_id.clone(),
            );
        }
        for token_id in &event.token_ids {
            push_unique(
                indexes
                    .token_to_event_ids
                    .entry(token_id.clone())
                    .or_default(),
                event.event_id.clone(),
            );
        }
        for pool_id in &event.pool_ids {
            push_unique(
                indexes
                    .pool_to_event_ids
                    .entry(pool_id.clone())
                    .or_default(),
                event.event_id.clone(),
            );
        }
        for rootfield_id in &event.rootfield_ids {
            push_unique(
                indexes
                    .rootfield_to_event_ids
                    .entry(rootfield_id.clone())
                    .or_default(),
                event.event_id.clone(),
            );
        }
        if let Some(observation_id) = &event.bridge_observation_id
            && let Some(replay_key) = &event.replay_key
        {
            indexes
                .bridge_event_to_observation_id
                .insert(replay_key.clone(), observation_id.clone());
        }
    }

    for (observation_id, observation) in &state.bridge_observations {
        let credit_ids = state
            .bridge_credits
            .values()
            .filter(|credit| credit.observation_id == *observation_id)
            .map(|credit| credit.credit_id.clone())
            .collect::<Vec<_>>();
        indexes
            .bridge_event_to_observation_id
            .insert(observation.source_event_key.clone(), observation_id.clone());
        indexes.bridge_observation_by_id.insert(
            observation_id.clone(),
            BridgeObservationIndexEntry {
                observation_id: observation_id.clone(),
                source_event_key: observation.source_event_key.clone(),
                replay_key: observation.replay_key.clone(),
                evidence_ref: observation.evidence_ref.clone(),
                credit_ids,
                block_height: observation.observed_at_block,
            },
        );
    }

    for (credit_id, credit) in &state.bridge_credits {
        indexes.bridge_credit_by_id.insert(
            credit_id.clone(),
            BridgeCreditIndexEntry {
                credit_id: credit_id.clone(),
                observation_id: credit.observation_id.clone(),
                account_id: credit.account_id.clone(),
                asset_id: credit.asset_id.clone(),
                amount_units: credit.amount_units,
                source_event_key: credit.source_event_key.clone(),
                replay_key: credit.replay_key.clone(),
                block_height: credit.credited_at_block,
            },
        );
    }

    for (intent_id, intent) in &state.withdrawal_intents {
        indexes.withdrawal_intent_by_id.insert(
            intent_id.clone(),
            WithdrawalIntentIndexEntry {
                withdrawal_intent_id: intent_id.clone(),
                account_id: intent.account_id.clone(),
                asset_id: intent.asset_id.clone(),
                amount_units: intent.amount_units,
                destination_chain_id: intent.destination_chain_id.clone(),
                release_policy: intent.release_policy.clone(),
                block_height: intent.requested_at_block,
            },
        );
    }

    for (evidence_id, evidence) in &state.release_evidence {
        indexes.release_evidence_by_id.insert(
            evidence_id.clone(),
            ReleaseEvidenceIndexEntry {
                release_evidence_id: evidence_id.clone(),
                withdrawal_intent_id: evidence.withdrawal_intent_id.clone(),
                source_chain_id: evidence.source_chain_id.clone(),
                release_tx_hash: evidence.release_tx_hash.clone(),
                evidence_ref: evidence.evidence_ref.clone(),
                block_height: evidence.recorded_at_block,
            },
        );
    }

    for (replay_key, consumed) in &state.consumed_replay_keys {
        indexes.replay_key_by_id.insert(
            replay_key.clone(),
            ReplayKeyIndexEntry {
                replay_key: replay_key.clone(),
                source_id: consumed.source_id.clone(),
                source_type: consumed.source_type.clone(),
                consumed_at_block: consumed.consumed_at_block,
            },
        );
    }

    Ok(indexes)
}

fn build_event_records(state: &ChainState) -> Vec<EventRecord> {
    let mut events = Vec::new();
    for block in &state.blocks {
        for receipt in &block.receipts {
            let tx = block
                .transactions
                .iter()
                .find(|candidate| candidate.tx_id == receipt.tx_id);
            let Some(tx) = tx else {
                continue;
            };
            if receipt.status != "applied" {
                events.push(event_record(
                    "txRejected",
                    block.block_number,
                    &block.block_hash,
                    &receipt.tx_id,
                    &receipt.status,
                    None,
                    None,
                    Vec::new(),
                    Vec::new(),
                    Vec::new(),
                    Vec::new(),
                    None,
                    None,
                    None,
                    None,
                    None,
                    serde_json::json!({ "error": receipt.error }),
                ));
                continue;
            }
            events.push(event_for_transaction(
                block.block_number,
                &block.block_hash,
                &receipt.tx_id,
                &receipt.status,
                &tx.tx,
            ));
        }
    }
    events
}

#[allow(clippy::too_many_arguments)]
fn event_record(
    event_type: &str,
    block_height: u64,
    block_hash: &str,
    tx_id: &str,
    receipt_status: &str,
    object_id: Option<String>,
    receipt_id: Option<String>,
    account_ids: Vec<String>,
    token_ids: Vec<String>,
    pool_ids: Vec<String>,
    rootfield_ids: Vec<String>,
    bridge_observation_id: Option<String>,
    bridge_credit_id: Option<String>,
    withdrawal_intent_id: Option<String>,
    release_evidence_id: Option<String>,
    replay_key: Option<String>,
    payload: Value,
) -> EventRecord {
    let object_for_id = object_id
        .clone()
        .or_else(|| receipt_id.clone())
        .or_else(|| bridge_observation_id.clone())
        .or_else(|| bridge_credit_id.clone())
        .or_else(|| withdrawal_intent_id.clone())
        .or_else(|| release_evidence_id.clone())
        .unwrap_or_else(|| tx_id.to_string());
    let event_id = hash_json(
        "flowmemory.local_devnet.event_id.v1",
        &serde_json::json!({
            "eventType": event_type,
            "blockHeight": block_height,
            "blockHash": block_hash,
            "txId": tx_id,
            "objectId": object_for_id
        }),
    );
    EventRecord {
        schema: STORAGE_EVENT_SCHEMA.to_string(),
        event_id,
        event_type: event_type.to_string(),
        block_height,
        block_hash: block_hash.to_string(),
        tx_id: tx_id.to_string(),
        receipt_status: receipt_status.to_string(),
        object_id,
        receipt_id,
        account_ids: sorted_unique(account_ids),
        token_ids: sorted_unique(token_ids),
        pool_ids: sorted_unique(pool_ids),
        rootfield_ids: sorted_unique(rootfield_ids),
        bridge_observation_id,
        bridge_credit_id,
        withdrawal_intent_id,
        release_evidence_id,
        replay_key,
        payload,
    }
}

fn event_for_transaction(
    block_height: u64,
    block_hash: &str,
    tx_id: &str,
    receipt_status: &str,
    tx: &Transaction,
) -> EventRecord {
    match tx {
        Transaction::RegisterRootfield { rootfield_id, .. } => event_record(
            "rootfieldRegistered",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            Some(rootfield_id.clone()),
            None,
            Vec::new(),
            Vec::new(),
            Vec::new(),
            vec![rootfield_id.clone()],
            None,
            None,
            None,
            None,
            None,
            serde_json::to_value(tx).expect("tx serializes"),
        ),
        Transaction::RegisterAgent { agent_id, .. } => simple_account_event(
            "agentRegistered",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            agent_id,
            tx,
        ),
        Transaction::CreateLocalTestUnitBalance { account_id, .. } => simple_account_event(
            "localBalanceCreated",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            account_id,
            tx,
        ),
        Transaction::FaucetLocalTestUnits {
            faucet_record_id,
            account_id,
            ..
        } => event_record(
            "localFaucetCredited",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            Some(faucet_record_id.clone()),
            Some(faucet_record_id.clone()),
            vec![account_id.clone()],
            Vec::new(),
            Vec::new(),
            Vec::new(),
            None,
            None,
            None,
            None,
            None,
            serde_json::to_value(tx).expect("tx serializes"),
        ),
        Transaction::TransferLocalTestUnits {
            transfer_id,
            from_account_id,
            to_account_id,
            ..
        } => event_record(
            "localBalanceTransferred",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            Some(transfer_id.clone()),
            Some(transfer_id.clone()),
            vec![from_account_id.clone(), to_account_id.clone()],
            Vec::new(),
            Vec::new(),
            Vec::new(),
            None,
            None,
            None,
            None,
            None,
            serde_json::to_value(tx).expect("tx serializes"),
        ),
        Transaction::LaunchToken {
            token_id,
            initial_owner_account_id,
            ..
        } => event_record(
            "tokenLaunched",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            Some(token_id.clone()),
            None,
            vec![initial_owner_account_id.clone()],
            vec![token_id.clone()],
            Vec::new(),
            Vec::new(),
            None,
            None,
            None,
            None,
            None,
            serde_json::to_value(tx).expect("tx serializes"),
        ),
        Transaction::MintLocalTestToken {
            mint_id,
            token_id,
            to_account_id,
            ..
        } => event_record(
            "tokenMinted",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            Some(mint_id.clone()),
            Some(mint_id.clone()),
            vec![to_account_id.clone()],
            vec![token_id.clone()],
            Vec::new(),
            Vec::new(),
            None,
            None,
            None,
            None,
            None,
            serde_json::to_value(tx).expect("tx serializes"),
        ),
        Transaction::CreatePool {
            pool_id,
            base_asset_id,
            quote_asset_id,
            created_by_account_id,
        } => event_record(
            "poolCreated",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            Some(pool_id.clone()),
            None,
            vec![created_by_account_id.clone()],
            vec![base_asset_id.clone(), quote_asset_id.clone()],
            vec![pool_id.clone()],
            Vec::new(),
            None,
            None,
            None,
            None,
            None,
            serde_json::to_value(tx).expect("tx serializes"),
        ),
        Transaction::AddLiquidity {
            liquidity_id,
            pool_id,
            provider_account_id,
            ..
        }
        | Transaction::RemoveLiquidity {
            liquidity_id,
            pool_id,
            provider_account_id,
            ..
        } => event_record(
            "poolLiquidityChanged",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            Some(liquidity_id.clone()),
            Some(liquidity_id.clone()),
            vec![provider_account_id.clone()],
            Vec::new(),
            vec![pool_id.clone()],
            Vec::new(),
            None,
            None,
            None,
            None,
            None,
            serde_json::to_value(tx).expect("tx serializes"),
        ),
        Transaction::SwapExactIn {
            swap_id,
            pool_id,
            trader_account_id,
            asset_in_id,
            ..
        } => event_record(
            "poolSwap",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            Some(swap_id.clone()),
            Some(swap_id.clone()),
            vec![trader_account_id.clone()],
            vec![asset_in_id.clone()],
            vec![pool_id.clone()],
            Vec::new(),
            None,
            None,
            None,
            None,
            None,
            serde_json::to_value(tx).expect("tx serializes"),
        ),
        Transaction::RegisterModelPassport {
            model_passport_id, ..
        } => simple_object_event(
            "modelPassportRegistered",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            model_passport_id,
            tx,
        ),
        Transaction::CommitRoot { rootfield_id, .. } => event_record(
            "rootCommitted",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            Some(rootfield_id.clone()),
            None,
            Vec::new(),
            Vec::new(),
            Vec::new(),
            vec![rootfield_id.clone()],
            None,
            None,
            None,
            None,
            None,
            serde_json::to_value(tx).expect("tx serializes"),
        ),
        Transaction::SubmitArtifactCommitment {
            artifact_id,
            rootfield_id,
            ..
        } => rootfield_object_event(
            "artifactCommitted",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            artifact_id,
            rootfield_id,
            tx,
        ),
        Transaction::MarkArtifactAvailability {
            proof_id,
            rootfield_id,
            ..
        } => rootfield_object_event(
            "artifactAvailabilityMarked",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            proof_id,
            rootfield_id,
            tx,
        ),
        Transaction::SubmitWorkReceipt {
            receipt_id,
            rootfield_id,
            ..
        } => rootfield_receipt_event(
            "workReceiptSubmitted",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            receipt_id,
            rootfield_id,
            tx,
        ),
        Transaction::SubmitVerifierReport {
            report_id,
            rootfield_id,
            receipt_id,
            ..
        } => event_record(
            "verifierReportSubmitted",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            Some(report_id.clone()),
            Some(receipt_id.clone()),
            Vec::new(),
            Vec::new(),
            Vec::new(),
            vec![rootfield_id.clone()],
            None,
            None,
            None,
            None,
            None,
            serde_json::to_value(tx).expect("tx serializes"),
        ),
        Transaction::RegisterVerifierModule { verifier_id, .. } => simple_object_event(
            "verifierModuleRegistered",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            verifier_id,
            tx,
        ),
        Transaction::UpdateMemoryCell {
            memory_cell_id,
            agent_id,
            rootfield_id,
            source_receipt_id,
            ..
        } => event_record(
            "memoryCellUpdated",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            Some(memory_cell_id.clone()),
            Some(source_receipt_id.clone()),
            vec![agent_id.clone()],
            Vec::new(),
            Vec::new(),
            vec![rootfield_id.clone()],
            None,
            None,
            None,
            None,
            None,
            serde_json::to_value(tx).expect("tx serializes"),
        ),
        Transaction::OpenChallenge {
            challenge_id,
            receipt_id,
            ..
        } => event_record(
            "challengeOpened",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            Some(challenge_id.clone()),
            Some(receipt_id.clone()),
            Vec::new(),
            Vec::new(),
            Vec::new(),
            Vec::new(),
            None,
            None,
            None,
            None,
            None,
            serde_json::to_value(tx).expect("tx serializes"),
        ),
        Transaction::ResolveChallenge { challenge_id, .. } => simple_object_event(
            "challengeResolved",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            challenge_id,
            tx,
        ),
        Transaction::FinalizeWorkReceipt {
            finality_receipt_id,
            receipt_id,
            ..
        } => event_record(
            "workReceiptFinalized",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            Some(finality_receipt_id.clone()),
            Some(receipt_id.clone()),
            Vec::new(),
            Vec::new(),
            Vec::new(),
            Vec::new(),
            None,
            None,
            None,
            None,
            None,
            serde_json::to_value(tx).expect("tx serializes"),
        ),
        Transaction::AnchorBatchToBasePlaceholder {
            appchain_chain_id, ..
        } => simple_object_event(
            "baseAnchorPlaceholderCreated",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            appchain_chain_id,
            tx,
        ),
        Transaction::ImportFlowPulseObservation(observation) => event_record(
            "flowPulseObservationImported",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            Some(observation.observation_id.clone()),
            None,
            Vec::new(),
            Vec::new(),
            Vec::new(),
            vec![observation.rootfield_id.clone()],
            None,
            None,
            None,
            None,
            None,
            serde_json::to_value(tx).expect("tx serializes"),
        ),
        Transaction::ImportVerifierReport(report) => event_record(
            "verifierReportImported",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            Some(report.report_id.clone()),
            report.receipt_id.clone(),
            Vec::new(),
            Vec::new(),
            Vec::new(),
            report.rootfield_id.iter().cloned().collect(),
            None,
            None,
            None,
            None,
            None,
            serde_json::to_value(tx).expect("tx serializes"),
        ),
        Transaction::RecordBridgeObservation {
            observation_id,
            recipient_account_id,
            asset_id,
            replay_key,
            ..
        } => event_record(
            "bridgeObservationRecorded",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            Some(observation_id.clone()),
            None,
            vec![recipient_account_id.clone()],
            vec![asset_id.clone()],
            Vec::new(),
            Vec::new(),
            Some(observation_id.clone()),
            None,
            None,
            None,
            Some(replay_key.clone()),
            serde_json::to_value(tx).expect("tx serializes"),
        ),
        Transaction::ApplyBridgeCredit {
            credit_id,
            observation_id,
            account_id,
            asset_id,
            ..
        } => event_record(
            "bridgeCreditApplied",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            Some(credit_id.clone()),
            Some(credit_id.clone()),
            vec![account_id.clone()],
            vec![asset_id.clone()],
            Vec::new(),
            Vec::new(),
            Some(observation_id.clone()),
            Some(credit_id.clone()),
            None,
            None,
            None,
            serde_json::to_value(tx).expect("tx serializes"),
        ),
        Transaction::CreateWithdrawalIntent {
            withdrawal_intent_id,
            account_id,
            asset_id,
            ..
        } => event_record(
            "withdrawalIntentCreated",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            Some(withdrawal_intent_id.clone()),
            Some(withdrawal_intent_id.clone()),
            vec![account_id.clone()],
            vec![asset_id.clone()],
            Vec::new(),
            Vec::new(),
            None,
            None,
            Some(withdrawal_intent_id.clone()),
            None,
            None,
            serde_json::to_value(tx).expect("tx serializes"),
        ),
        Transaction::RecordReleaseEvidence {
            release_evidence_id,
            withdrawal_intent_id,
            ..
        } => event_record(
            "releaseEvidenceRecorded",
            block_height,
            block_hash,
            tx_id,
            receipt_status,
            Some(release_evidence_id.clone()),
            Some(release_evidence_id.clone()),
            Vec::new(),
            Vec::new(),
            Vec::new(),
            Vec::new(),
            None,
            None,
            Some(withdrawal_intent_id.clone()),
            Some(release_evidence_id.clone()),
            None,
            serde_json::to_value(tx).expect("tx serializes"),
        ),
    }
}

fn simple_account_event(
    event_type: &str,
    block_height: u64,
    block_hash: &str,
    tx_id: &str,
    receipt_status: &str,
    account_id: &str,
    tx: &Transaction,
) -> EventRecord {
    event_record(
        event_type,
        block_height,
        block_hash,
        tx_id,
        receipt_status,
        Some(account_id.to_string()),
        None,
        vec![account_id.to_string()],
        Vec::new(),
        Vec::new(),
        Vec::new(),
        None,
        None,
        None,
        None,
        None,
        serde_json::to_value(tx).expect("tx serializes"),
    )
}

fn simple_object_event(
    event_type: &str,
    block_height: u64,
    block_hash: &str,
    tx_id: &str,
    receipt_status: &str,
    object_id: &str,
    tx: &Transaction,
) -> EventRecord {
    event_record(
        event_type,
        block_height,
        block_hash,
        tx_id,
        receipt_status,
        Some(object_id.to_string()),
        None,
        Vec::new(),
        Vec::new(),
        Vec::new(),
        Vec::new(),
        None,
        None,
        None,
        None,
        None,
        serde_json::to_value(tx).expect("tx serializes"),
    )
}

fn rootfield_object_event(
    event_type: &str,
    block_height: u64,
    block_hash: &str,
    tx_id: &str,
    receipt_status: &str,
    object_id: &str,
    rootfield_id: &str,
    tx: &Transaction,
) -> EventRecord {
    event_record(
        event_type,
        block_height,
        block_hash,
        tx_id,
        receipt_status,
        Some(object_id.to_string()),
        None,
        Vec::new(),
        Vec::new(),
        Vec::new(),
        vec![rootfield_id.to_string()],
        None,
        None,
        None,
        None,
        None,
        serde_json::to_value(tx).expect("tx serializes"),
    )
}

fn rootfield_receipt_event(
    event_type: &str,
    block_height: u64,
    block_hash: &str,
    tx_id: &str,
    receipt_status: &str,
    receipt_id: &str,
    rootfield_id: &str,
    tx: &Transaction,
) -> EventRecord {
    event_record(
        event_type,
        block_height,
        block_hash,
        tx_id,
        receipt_status,
        Some(receipt_id.to_string()),
        Some(receipt_id.to_string()),
        Vec::new(),
        Vec::new(),
        Vec::new(),
        vec![rootfield_id.to_string()],
        None,
        None,
        None,
        None,
        None,
        serde_json::to_value(tx).expect("tx serializes"),
    )
}

fn account_ids_for_tx(tx: &Transaction) -> Vec<String> {
    match tx {
        Transaction::RegisterAgent { agent_id, .. }
        | Transaction::CreateLocalTestUnitBalance {
            account_id: agent_id,
            ..
        } => vec![agent_id.clone()],
        Transaction::FaucetLocalTestUnits { account_id, .. } => vec![account_id.clone()],
        Transaction::TransferLocalTestUnits {
            from_account_id,
            to_account_id,
            ..
        } => vec![from_account_id.clone(), to_account_id.clone()],
        Transaction::LaunchToken {
            initial_owner_account_id,
            ..
        } => vec![initial_owner_account_id.clone()],
        Transaction::MintLocalTestToken { to_account_id, .. } => vec![to_account_id.clone()],
        Transaction::CreatePool {
            created_by_account_id,
            ..
        } => vec![created_by_account_id.clone()],
        Transaction::AddLiquidity {
            provider_account_id,
            ..
        }
        | Transaction::RemoveLiquidity {
            provider_account_id,
            ..
        } => vec![provider_account_id.clone()],
        Transaction::SwapExactIn {
            trader_account_id, ..
        } => vec![trader_account_id.clone()],
        Transaction::UpdateMemoryCell { agent_id, .. } => vec![agent_id.clone()],
        Transaction::RecordBridgeObservation {
            recipient_account_id,
            ..
        } => vec![recipient_account_id.clone()],
        Transaction::ApplyBridgeCredit { account_id, .. }
        | Transaction::CreateWithdrawalIntent { account_id, .. } => vec![account_id.clone()],
        _ => Vec::new(),
    }
}

fn balance_changes_for_tx(
    tx: &Transaction,
    block_height: u64,
    tx_id: &str,
) -> Vec<(String, BalanceChangeIndexEntry)> {
    match tx {
        Transaction::FaucetLocalTestUnits {
            account_id,
            amount_units,
            ..
        } => vec![(
            account_id.clone(),
            BalanceChangeIndexEntry {
                tx_id: tx_id.to_string(),
                block_height,
                asset_id: crate::model::LOCAL_TEST_UNIT_ASSET_ID.to_string(),
                delta_units: *amount_units as i128,
                reason: "faucet".to_string(),
            },
        )],
        Transaction::TransferLocalTestUnits {
            from_account_id,
            to_account_id,
            amount_units,
            ..
        } => vec![
            (
                from_account_id.clone(),
                BalanceChangeIndexEntry {
                    tx_id: tx_id.to_string(),
                    block_height,
                    asset_id: crate::model::LOCAL_TEST_UNIT_ASSET_ID.to_string(),
                    delta_units: -(*amount_units as i128),
                    reason: "transfer-out".to_string(),
                },
            ),
            (
                to_account_id.clone(),
                BalanceChangeIndexEntry {
                    tx_id: tx_id.to_string(),
                    block_height,
                    asset_id: crate::model::LOCAL_TEST_UNIT_ASSET_ID.to_string(),
                    delta_units: *amount_units as i128,
                    reason: "transfer-in".to_string(),
                },
            ),
        ],
        Transaction::LaunchToken {
            token_id,
            initial_owner_account_id,
            initial_supply_units,
            ..
        }
        | Transaction::MintLocalTestToken {
            token_id,
            to_account_id: initial_owner_account_id,
            amount_units: initial_supply_units,
            ..
        } => vec![(
            initial_owner_account_id.clone(),
            BalanceChangeIndexEntry {
                tx_id: tx_id.to_string(),
                block_height,
                asset_id: token_id.clone(),
                delta_units: *initial_supply_units as i128,
                reason: "token-credit".to_string(),
            },
        )],
        Transaction::ApplyBridgeCredit {
            account_id,
            asset_id,
            amount_units,
            ..
        } => vec![(
            account_id.clone(),
            BalanceChangeIndexEntry {
                tx_id: tx_id.to_string(),
                block_height,
                asset_id: asset_id.clone(),
                delta_units: *amount_units as i128,
                reason: "bridge-credit".to_string(),
            },
        )],
        Transaction::CreateWithdrawalIntent {
            account_id,
            asset_id,
            amount_units,
            ..
        } => vec![(
            account_id.clone(),
            BalanceChangeIndexEntry {
                tx_id: tx_id.to_string(),
                block_height,
                asset_id: asset_id.clone(),
                delta_units: -(*amount_units as i128),
                reason: "withdrawal-lock".to_string(),
            },
        )],
        _ => Vec::new(),
    }
}

fn push_unique(entries: &mut Vec<String>, value: String) {
    if !entries.contains(&value) {
        entries.push(value);
        entries.sort();
    }
}

fn sorted_unique(entries: Vec<String>) -> Vec<String> {
    entries
        .into_iter()
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect()
}

fn file_safe_id(id: &str) -> String {
    if id.starts_with("0x") && id.len() == 66 {
        return id.to_string();
    }
    keccak_hex(id.as_bytes())
}

fn backup_legacy_state(path: &Path, data_dir: &Path, state: &ChainState) -> Result<()> {
    if !path.exists() {
        return Ok(());
    }
    let backup_dir = data_dir.join("backups");
    fs::create_dir_all(&backup_dir)
        .with_context(|| format!("failed to create backup directory {}", backup_dir.display()))?;
    let backup_path = backup_dir.join(format!(
        "legacy-state-{}.json",
        file_safe_id(&state_root(state))
    ));
    if !backup_path.exists() {
        fs::copy(path, &backup_path).with_context(|| {
            format!(
                "failed to back up legacy state {} to {}",
                path.display(),
                backup_path.display()
            )
        })?;
    }
    Ok(())
}

fn cleanup_temporary_files(data_dir: &Path) -> Result<()> {
    if !data_dir.exists() {
        return Ok(());
    }
    for entry in walk_files(data_dir)? {
        let Some(file_name) = entry.file_name().and_then(|name| name.to_str()) else {
            continue;
        };
        if file_name.ends_with(".tmp") {
            fs::remove_file(&entry)
                .with_context(|| format!("failed to remove temp file {}", entry.display()))?;
        }
    }
    Ok(())
}

fn walk_files(root: &Path) -> Result<Vec<PathBuf>> {
    let mut files = Vec::new();
    if !root.exists() {
        return Ok(files);
    }
    let mut stack = vec![root.to_path_buf()];
    while let Some(path) = stack.pop() {
        for entry in fs::read_dir(&path)
            .with_context(|| format!("failed to read directory {}", path.display()))?
        {
            let entry = entry?;
            let path = entry.path();
            if path.is_dir() {
                stack.push(path);
            } else {
                files.push(path);
            }
        }
    }
    Ok(files)
}
