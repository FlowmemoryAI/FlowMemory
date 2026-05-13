use crate::hash::{hash_json, normalize_value};
use crate::model::{
    FLOWPULSE_TOPIC0, ImportedFlowPulseObservation, ImportedVerifierReport, Transaction,
    build_block, demo_transactions, genesis_state, queue_transaction, state_map_roots, state_root,
};
use crate::storage::{default_state_path, load_or_genesis, load_state, reset_state, save_state};
use anyhow::{Context, Result, anyhow};
use serde::Serialize;
use serde_json::Value;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug)]
pub struct Cli {
    state: PathBuf,
    command: Command,
}

#[derive(Debug)]
pub enum Command {
    Init,
    ResetLocal,
    Start { blocks: u64 },
    SubmitFixture { fixture: PathBuf },
    InspectState { summary: bool },
    ExportFixtures { out_dir: PathBuf },
    ExportState { out: PathBuf },
    ImportState { from: PathBuf },
    Demo { out_dir: PathBuf },
    Smoke { out_dir: PathBuf },
}

pub fn run_cli() -> Result<()> {
    let cli = parse_args(env::args().skip(1).collect())?;
    run(cli)
}

fn parse_args(args: Vec<String>) -> Result<Cli> {
    let mut state = default_state_path();
    let mut index = 0;
    let mut positional = Vec::new();

    while index < args.len() {
        match args[index].as_str() {
            "--state" => {
                index += 1;
                let value = args
                    .get(index)
                    .ok_or_else(|| anyhow!("--state requires a path"))?;
                state = PathBuf::from(value);
            }
            "--help" | "-h" => {
                print_help();
                std::process::exit(0);
            }
            other => positional.push(other.to_string()),
        }
        index += 1;
    }

    let command = positional
        .first()
        .ok_or_else(|| anyhow!("missing command; run with --help for usage"))?;

    let command = match command.as_str() {
        "init" => Command::Init,
        "reset-local" => Command::ResetLocal,
        "run-block" => Command::Start { blocks: 1 },
        "start" | "run" => Command::Start {
            blocks: option_u64(&positional[1..], "--blocks")?.unwrap_or(1),
        },
        "submit-fixture" => {
            let fixture = option_value(&positional[1..], "--fixture")?;
            Command::SubmitFixture {
                fixture: PathBuf::from(fixture),
            }
        }
        "inspect" | "inspect-state" => Command::InspectState {
            summary: positional.iter().any(|arg| arg == "--summary"),
        },
        "export" | "export-fixtures" => Command::ExportFixtures {
            out_dir: option_value(&positional[1..], "--out-dir")
                .map(PathBuf::from)
                .unwrap_or_else(|_| PathBuf::from("fixtures/handoff/generated")),
        },
        "export-state" => Command::ExportState {
            out: option_value(&positional[1..], "--out")
                .map(PathBuf::from)
                .unwrap_or_else(|_| PathBuf::from("fixtures/handoff/generated/state.json")),
        },
        "import-state" => Command::ImportState {
            from: PathBuf::from(option_value(&positional[1..], "--from")?),
        },
        "demo" => Command::Demo {
            out_dir: option_value(&positional[1..], "--out-dir")
                .map(PathBuf::from)
                .unwrap_or_else(|_| PathBuf::from("fixtures/handoff/generated")),
        },
        "smoke" => Command::Smoke {
            out_dir: option_value(&positional[1..], "--out-dir")
                .map(PathBuf::from)
                .unwrap_or_else(|_| PathBuf::from("fixtures/handoff/generated")),
        },
        unknown => return Err(anyhow!("unknown command '{unknown}'")),
    };

    Ok(Cli { state, command })
}

fn option_value(args: &[String], name: &str) -> Result<String> {
    let index = args
        .iter()
        .position(|arg| arg == name)
        .ok_or_else(|| anyhow!("{name} is required"))?;
    args.get(index + 1)
        .cloned()
        .ok_or_else(|| anyhow!("{name} requires a value"))
}

fn option_u64(args: &[String], name: &str) -> Result<Option<u64>> {
    let Some(index) = args.iter().position(|arg| arg == name) else {
        return Ok(None);
    };
    let value = args
        .get(index + 1)
        .ok_or_else(|| anyhow!("{name} requires a value"))?;
    value
        .parse::<u64>()
        .map(Some)
        .with_context(|| format!("{name} must be a positive integer"))
}

fn print_help() {
    println!(
        "flowmemory-devnet --state <path> <command>\n\nCommands:\n  init\n  reset-local\n  start|run [--blocks <n>]\n  run-block\n  submit-fixture --fixture <path>\n  inspect|inspect-state [--summary]\n  export|export-fixtures [--out-dir <path>]\n  export-state [--out <path>]\n  import-state --from <path>\n  demo [--out-dir <path>]\n  smoke [--out-dir <path>]\n"
    );
}

fn run(cli: Cli) -> Result<()> {
    match cli.command {
        Command::Init => {
            let state = genesis_state();
            save_state(&cli.state, &state)?;
            write_runtime_boundary_files(&cli.state, &state)?;
            print_json(&StateSummary::from_state(&state))?;
        }
        Command::ResetLocal => {
            let state = reset_state(&cli.state)?;
            write_runtime_boundary_files(&cli.state, &state)?;
            print_json(&StateSummary::from_state(&state))?;
        }
        Command::Start { blocks } => {
            let mut state = load_or_genesis(&cli.state)?;
            let produced = build_blocks(&mut state, blocks)?;
            save_state(&cli.state, &state)?;
            print_json(&RunSummary::from_blocks(&state, produced))?;
        }
        Command::SubmitFixture { fixture } => {
            let mut state = load_or_genesis(&cli.state)?;
            let txs = transactions_from_fixture(&fixture)?;
            let mut queued = Vec::new();
            for tx in txs {
                queued.push(queue_transaction(&mut state, tx));
            }
            save_state(&cli.state, &state)?;
            print_json(&QueuedTransactions { queued })?;
        }
        Command::InspectState { summary } => {
            let state = load_or_genesis(&cli.state)?;
            if summary {
                print_json(&StateSummary::from_state(&state))?;
            } else {
                print_json(&state)?;
            }
        }
        Command::ExportFixtures { out_dir } => {
            let state = load_or_genesis(&cli.state)?;
            export_handoff(&state, &out_dir)?;
            print_json(&ExportSummary::from_state(&state, out_dir))?;
        }
        Command::ExportState { out } => {
            let state = load_or_genesis(&cli.state)?;
            write_json(out.clone(), &state)?;
            print_json(&ExportStateSummary::from_state(&state, out))?;
        }
        Command::ImportState { from } => {
            let state = load_state(&from)?;
            save_state(&cli.state, &state)?;
            write_runtime_boundary_files(&cli.state, &state)?;
            print_json(&ImportStateSummary::from_state(&state, from, cli.state))?;
        }
        Command::Demo { out_dir } => {
            let demo = build_demo_state();
            save_state(&cli.state, &demo.state)?;
            write_runtime_boundary_files(&cli.state, &demo.state)?;
            export_handoff(&demo.state, &out_dir)?;
            print_json(&DemoSummary::from_demo(cli.state, out_dir, &demo))?;
        }
        Command::Smoke { out_dir } => {
            let first = build_smoke_state(10);
            let second = build_smoke_state(10);
            let deterministic_replay = first.first_block_hash == second.first_block_hash
                && first.second_block_hash == second.second_block_hash
                && first.state.parent_hash == second.state.parent_hash
                && first.state.blocks.len() == second.state.blocks.len()
                && state_root(&first.state) == state_root(&second.state)
                && state_map_roots(&first.state) == state_map_roots(&second.state);
            save_state(&cli.state, &first.state)?;
            write_runtime_boundary_files(&cli.state, &first.state)?;
            export_handoff(&first.state, &out_dir)?;
            print_json(&SmokeSummary::from_demo(
                cli.state,
                out_dir,
                &first,
                deterministic_replay,
            ))?;
        }
    }
    Ok(())
}

fn build_blocks(
    state: &mut crate::model::ChainState,
    blocks: u64,
) -> Result<Vec<crate::model::Block>> {
    if blocks == 0 {
        return Err(anyhow!("--blocks must be greater than zero"));
    }
    let mut produced = Vec::with_capacity(blocks as usize);
    for _ in 0..blocks {
        produced.push(build_block(state));
    }
    Ok(produced)
}

struct DemoRun {
    state: crate::model::ChainState,
    first_block_hash: String,
    second_block_hash: String,
}

fn build_demo_state() -> DemoRun {
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

    DemoRun {
        state,
        first_block_hash: first.block_hash,
        second_block_hash: second.block_hash,
    }
}

fn build_smoke_state(min_blocks: usize) -> DemoRun {
    let mut demo = build_demo_state();
    while demo.state.blocks.len() < min_blocks {
        build_block(&mut demo.state);
    }
    demo
}

fn transactions_from_fixture(path: &Path) -> Result<Vec<Transaction>> {
    let body = fs::read_to_string(path)
        .with_context(|| format!("failed to read fixture {}", path.display()))?;
    let value: Value = serde_json::from_str(&body)
        .with_context(|| format!("failed to parse fixture {}", path.display()))?;

    if value.get("txs").is_some() {
        return serde_json::from_value(value["txs"].clone())
            .with_context(|| format!("failed to parse txs in {}", path.display()));
    }

    if value.get("tx").is_some() {
        let tx = serde_json::from_value(value["tx"].clone())
            .with_context(|| format!("failed to parse tx in {}", path.display()))?;
        return Ok(vec![tx]);
    }

    if value.get("rawLog").is_some() && value.get("expected").is_some() {
        return Ok(vec![Transaction::ImportFlowPulseObservation(
            observation_from_flowpulse_fixture(&value)?,
        )]);
    }

    if value.get("reportCore").is_some() && value.get("expected").is_some() {
        return Ok(vec![Transaction::ImportVerifierReport(
            verifier_report_from_fixture(&value)?,
        )]);
    }

    Err(anyhow!(
        "unsupported fixture shape in {}: expected tx, txs, FlowPulse observation, or verifier report fixture",
        path.display()
    ))
}

fn observation_from_flowpulse_fixture(value: &Value) -> Result<ImportedFlowPulseObservation> {
    let raw = value
        .get("rawLog")
        .and_then(Value::as_object)
        .ok_or_else(|| anyhow!("missing rawLog object"))?;
    let expected = value
        .get("expected")
        .and_then(Value::as_object)
        .ok_or_else(|| anyhow!("missing expected object"))?;
    let topics = raw
        .get("topics")
        .and_then(Value::as_array)
        .ok_or_else(|| anyhow!("missing rawLog.topics"))?;

    let event_signature = string_at(topics, 0, "topics[0]")?;
    if event_signature.to_lowercase() != FLOWPULSE_TOPIC0 {
        return Err(anyhow!("fixture event signature is not FlowPulse v0"));
    }

    Ok(ImportedFlowPulseObservation {
        observation_id: string_field(expected, "observationId")?,
        chain_id: string_field_value(raw, "chainId")?,
        emitting_contract: string_field_value(raw, "address")?,
        block_number: string_field_value(raw, "blockNumber")?,
        block_hash: string_field_value(raw, "blockHash")?,
        tx_hash: string_field_value(raw, "transactionHash")?,
        transaction_index: string_field_value(raw, "transactionIndex")?,
        log_index: string_field_value(raw, "logIndex")?,
        event_signature,
        pulse_id: string_at(topics, 1, "topics[1]")?,
        rootfield_id: string_at(topics, 2, "topics[2]")?,
    })
}

fn verifier_report_from_fixture(value: &Value) -> Result<ImportedVerifierReport> {
    let expected = value
        .get("expected")
        .and_then(Value::as_object)
        .ok_or_else(|| anyhow!("missing expected object"))?;
    let report_core = value
        .get("reportCore")
        .ok_or_else(|| anyhow!("missing reportCore"))?;
    let normalized = normalize_value(report_core.clone());
    let report_digest = hash_json("flowmemory.local_devnet.imported_report.v0", &normalized);
    let report_object = report_core
        .as_object()
        .ok_or_else(|| anyhow!("reportCore must be an object"))?;

    Ok(ImportedVerifierReport {
        report_id: string_field(expected, "reportId")?,
        rootfield_id: report_object
            .get("observation")
            .and_then(|observation| observation.get("rootfieldId"))
            .and_then(Value::as_str)
            .map(ToOwned::to_owned),
        receipt_id: None,
        report_digest,
        status: report_object
            .get("status")
            .and_then(Value::as_str)
            .unwrap_or("observed")
            .to_string(),
        source: "fixture.reportCore".to_string(),
    })
}

fn export_handoff(state: &crate::model::ChainState, out_dir: &Path) -> Result<()> {
    fs::create_dir_all(out_dir)
        .with_context(|| format!("failed to create handoff directory {}", out_dir.display()))?;
    let map_roots = state_map_roots(state);

    let dashboard = serde_json::json!({
        "schema": "flowmemory.dashboard_state.local_devnet.v0",
        "genesisConfig": state.config,
        "operatorKeyReferences": state.operator_key_references,
        "stateRoot": state_root(state),
        "mapRoots": map_roots,
        "blockHeight": state.blocks.len(),
        "rootfields": state.rootfields,
        "agentAccounts": state.agent_accounts,
        "localTestUnitBalances": state.local_test_unit_balances,
        "faucetRecords": state.faucet_records,
        "modelPassports": state.model_passports,
        "memoryCells": state.memory_cells,
        "challenges": state.challenges,
        "finalityReceipts": state.finality_receipts,
        "artifactCommitments": state.artifact_commitments,
        "artifactAvailabilityProofs": state.artifact_availability_proofs,
        "verifierModules": state.verifier_modules,
        "workReceipts": state.work_receipts,
        "verifierReports": state.verifier_reports,
        "baseAnchors": state.base_anchors,
    });

    let indexer = serde_json::json!({
        "schema": "flowmemory.indexer_handoff.local_devnet.v0",
        "genesisConfig": state.config,
        "importedObservations": state.imported_observations,
        "operatorKeyReferences": state.operator_key_references,
        "agentAccounts": state.agent_accounts,
        "localTestUnitBalances": state.local_test_unit_balances,
        "faucetRecords": state.faucet_records,
        "memoryCells": state.memory_cells,
        "challenges": state.challenges,
        "finalityReceipts": state.finality_receipts,
        "artifactAvailabilityProofs": state.artifact_availability_proofs,
        "blocks": state.blocks,
        "mapRoots": state_map_roots(state),
        "stateRoot": state_root(state),
    });

    let verifier = serde_json::json!({
        "schema": "flowmemory.verifier_handoff.local_devnet.v0",
        "genesisConfig": state.config,
        "operatorKeyReferences": state.operator_key_references,
        "localTestUnitBalances": state.local_test_unit_balances,
        "faucetRecords": state.faucet_records,
        "verifierModules": state.verifier_modules,
        "workReceipts": state.work_receipts,
        "verifierReports": state.verifier_reports,
        "challenges": state.challenges,
        "finalityReceipts": state.finality_receipts,
        "artifactAvailabilityProofs": state.artifact_availability_proofs,
        "importedVerifierReports": state.imported_verifier_reports,
        "mapRoots": state_map_roots(state),
        "stateRoot": state_root(state),
    });

    let control_plane = serde_json::json!({
        "schema": "flowmemory.control_plane_handoff.local_devnet.v0",
        "genesisConfig": state.config,
        "operatorKeyReferences": state.operator_key_references,
        "chainId": state.chain_id,
        "stateRoot": state_root(state),
        "mapRoots": state_map_roots(state),
        "latestBlock": state.blocks.last(),
        "blocks": state.blocks,
        "pendingTxs": state.pending_txs,
        "objects": {
            "rootfields": state.rootfields,
            "agentAccounts": state.agent_accounts,
            "localTestUnitBalances": state.local_test_unit_balances,
            "faucetRecords": state.faucet_records,
            "modelPassports": state.model_passports,
            "memoryCells": state.memory_cells,
            "challenges": state.challenges,
            "finalityReceipts": state.finality_receipts,
            "artifactCommitments": state.artifact_commitments,
            "artifactAvailabilityProofs": state.artifact_availability_proofs,
            "verifierModules": state.verifier_modules,
            "workReceipts": state.work_receipts,
            "verifierReports": state.verifier_reports,
            "baseAnchors": state.base_anchors
        }
    });

    write_json(out_dir.join("dashboard-state.json"), &dashboard)?;
    write_json(out_dir.join("indexer-handoff.json"), &indexer)?;
    write_json(out_dir.join("verifier-handoff.json"), &verifier)?;
    write_json(out_dir.join("control-plane-handoff.json"), &control_plane)?;
    write_json(out_dir.join("genesis-config.json"), &state.config)?;
    write_json(
        out_dir.join("operator-key-references.json"),
        &state.operator_key_references,
    )?;
    write_json(out_dir.join("state.json"), state)?;
    Ok(())
}

fn write_runtime_boundary_files(state_path: &Path, state: &crate::model::ChainState) -> Result<()> {
    let out_dir = state_path.parent().unwrap_or_else(|| Path::new("."));
    write_json(out_dir.join("genesis-config.json"), &state.config)?;
    write_json(
        out_dir.join("operator-key-references.json"),
        &state.operator_key_references,
    )?;
    Ok(())
}

fn write_json<T: Serialize>(path: PathBuf, value: &T) -> Result<()> {
    let body = serde_json::to_string_pretty(value)?;
    fs::write(&path, format!("{body}\n"))
        .with_context(|| format!("failed to write {}", path.display()))
}

fn print_json<T: Serialize>(value: &T) -> Result<()> {
    println!("{}", serde_json::to_string_pretty(value)?);
    Ok(())
}

fn string_field(map: &serde_json::Map<String, Value>, key: &str) -> Result<String> {
    map.get(key)
        .and_then(Value::as_str)
        .map(ToOwned::to_owned)
        .ok_or_else(|| anyhow!("missing string field {key}"))
}

fn string_field_value(map: &serde_json::Map<String, Value>, key: &str) -> Result<String> {
    string_field(map, key)
}

fn string_at(values: &[Value], index: usize, label: &str) -> Result<String> {
    values
        .get(index)
        .and_then(Value::as_str)
        .map(ToOwned::to_owned)
        .ok_or_else(|| anyhow!("missing string value {label}"))
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct QueuedTransactions {
    queued: Vec<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct StateSummary {
    schema: String,
    chain_id: String,
    next_block_number: u64,
    logical_time: u64,
    parent_hash: String,
    state_root: String,
    map_roots: crate::model::StateMapRoots,
    operator_key_references: usize,
    pending_txs: usize,
    blocks: usize,
    rootfields: usize,
    agent_accounts: usize,
    local_test_unit_balances: usize,
    faucet_records: usize,
    model_passports: usize,
    memory_cells: usize,
    challenges: usize,
    finality_receipts: usize,
    artifact_commitments: usize,
    artifact_availability_proofs: usize,
    verifier_modules: usize,
    work_receipts: usize,
    verifier_reports: usize,
    imported_observations: usize,
    imported_verifier_reports: usize,
    base_anchors: usize,
}

impl StateSummary {
    fn from_state(state: &crate::model::ChainState) -> Self {
        Self {
            schema: "flowmemory.local_devnet.summary.v0".to_string(),
            chain_id: state.chain_id.clone(),
            next_block_number: state.next_block_number,
            logical_time: state.logical_time,
            parent_hash: state.parent_hash.clone(),
            state_root: state_root(state),
            map_roots: state_map_roots(state),
            operator_key_references: state.operator_key_references.len(),
            pending_txs: state.pending_txs.len(),
            blocks: state.blocks.len(),
            rootfields: state.rootfields.len(),
            agent_accounts: state.agent_accounts.len(),
            local_test_unit_balances: state.local_test_unit_balances.len(),
            faucet_records: state.faucet_records.len(),
            model_passports: state.model_passports.len(),
            memory_cells: state.memory_cells.len(),
            challenges: state.challenges.len(),
            finality_receipts: state.finality_receipts.len(),
            artifact_commitments: state.artifact_commitments.len(),
            artifact_availability_proofs: state.artifact_availability_proofs.len(),
            verifier_modules: state.verifier_modules.len(),
            work_receipts: state.work_receipts.len(),
            verifier_reports: state.verifier_reports.len(),
            imported_observations: state.imported_observations.len(),
            imported_verifier_reports: state.imported_verifier_reports.len(),
            base_anchors: state.base_anchors.len(),
        }
    }
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct RunSummary {
    schema: String,
    blocks_produced: usize,
    block_hashes: Vec<String>,
    next_block_number: u64,
    state_root: String,
}

impl RunSummary {
    fn from_blocks(state: &crate::model::ChainState, blocks: Vec<crate::model::Block>) -> Self {
        Self {
            schema: "flowmemory.local_devnet.run_summary.v0".to_string(),
            blocks_produced: blocks.len(),
            block_hashes: blocks.into_iter().map(|block| block.block_hash).collect(),
            next_block_number: state.next_block_number,
            state_root: state_root(state),
        }
    }
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ExportSummary {
    schema: String,
    out_dir: PathBuf,
    state_root: String,
    map_roots: crate::model::StateMapRoots,
    files: Vec<String>,
}

impl ExportSummary {
    fn from_state(state: &crate::model::ChainState, out_dir: PathBuf) -> Self {
        Self {
            schema: "flowmemory.local_devnet.export_summary.v0".to_string(),
            out_dir,
            state_root: state_root(state),
            map_roots: state_map_roots(state),
            files: handoff_files(),
        }
    }
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ExportStateSummary {
    schema: String,
    out: PathBuf,
    state_root: String,
}

impl ExportStateSummary {
    fn from_state(state: &crate::model::ChainState, out: PathBuf) -> Self {
        Self {
            schema: "flowmemory.local_devnet.export_state_summary.v0".to_string(),
            out,
            state_root: state_root(state),
        }
    }
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ImportStateSummary {
    schema: String,
    from: PathBuf,
    state_path: PathBuf,
    state_root: String,
    map_roots: crate::model::StateMapRoots,
}

impl ImportStateSummary {
    fn from_state(state: &crate::model::ChainState, from: PathBuf, state_path: PathBuf) -> Self {
        Self {
            schema: "flowmemory.local_devnet.import_state_summary.v0".to_string(),
            from,
            state_path,
            state_root: state_root(state),
            map_roots: state_map_roots(state),
        }
    }
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct DemoSummary {
    schema: String,
    state_path: PathBuf,
    first_block_hash: String,
    second_block_hash: String,
    state_root: String,
    agent_id: String,
    agent_registered: bool,
    local_balance_account_id: String,
    local_balance_units: u64,
    faucet_record_id: String,
    faucet_record_created: bool,
    work_receipt_id: String,
    work_receipt_submitted: bool,
    verifier_report_id: String,
    verifier_report_submitted: bool,
    memory_cell_id: String,
    memory_cell_updated: bool,
    challenge_id: String,
    challenge_resolved: bool,
    finality_receipt_id: String,
    receipt_finalized: bool,
    out_dir: PathBuf,
    handoff_files: Vec<String>,
}

impl DemoSummary {
    fn from_demo(state_path: PathBuf, out_dir: PathBuf, demo: &DemoRun) -> Self {
        Self {
            schema: "flowmemory.local_devnet.demo_summary.v0".to_string(),
            state_path,
            first_block_hash: demo.first_block_hash.clone(),
            second_block_hash: demo.second_block_hash.clone(),
            state_root: state_root(&demo.state),
            agent_id: "agent:demo:alpha".to_string(),
            agent_registered: demo.state.agent_accounts.contains_key("agent:demo:alpha"),
            local_balance_account_id: "local-balance:demo:agent-alpha".to_string(),
            local_balance_units: demo
                .state
                .local_test_unit_balances
                .get("local-balance:demo:agent-alpha")
                .map(|balance| balance.units)
                .unwrap_or(0),
            faucet_record_id: "faucet:demo:001".to_string(),
            faucet_record_created: demo.state.faucet_records.contains_key("faucet:demo:001"),
            work_receipt_id: "receipt:demo:001".to_string(),
            work_receipt_submitted: demo.state.work_receipts.contains_key("receipt:demo:001"),
            verifier_report_id: "report:demo:001".to_string(),
            verifier_report_submitted: demo.state.verifier_reports.contains_key("report:demo:001"),
            memory_cell_id: "memory:demo:agent-alpha:core".to_string(),
            memory_cell_updated: demo
                .state
                .memory_cells
                .contains_key("memory:demo:agent-alpha:core"),
            challenge_id: "challenge:demo:001".to_string(),
            challenge_resolved: demo
                .state
                .challenges
                .get("challenge:demo:001")
                .is_some_and(|challenge| challenge.status == "resolved"),
            finality_receipt_id: "finality:demo:001".to_string(),
            receipt_finalized: demo
                .state
                .finality_receipts
                .contains_key("finality:demo:001"),
            out_dir,
            handoff_files: handoff_files(),
        }
    }
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct SmokeSummary {
    schema: String,
    state_path: PathBuf,
    out_dir: PathBuf,
    state_root: String,
    block_height: usize,
    latest_block_hash: String,
    deterministic_replay: bool,
    checks: SmokeChecks,
    handoff_files: Vec<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct SmokeChecks {
    genesis_config_initialized: bool,
    operator_key_reference_present: bool,
    agent_registered: bool,
    local_test_unit_balance_created: bool,
    faucet_record_created: bool,
    local_test_unit_balance_units: u64,
    model_registered: bool,
    work_receipt_submitted: bool,
    artifact_available: bool,
    verifier_module_registered: bool,
    verifier_report_submitted: bool,
    memory_cell_updated: bool,
    challenge_opened: bool,
    challenge_resolved: bool,
    receipt_finalized: bool,
    base_anchor_created: bool,
}

impl SmokeSummary {
    fn from_demo(
        state_path: PathBuf,
        out_dir: PathBuf,
        demo: &DemoRun,
        deterministic_replay: bool,
    ) -> Self {
        Self {
            schema: "flowmemory.local_devnet.smoke_summary.v0".to_string(),
            state_path,
            out_dir,
            state_root: state_root(&demo.state),
            block_height: demo.state.blocks.len(),
            latest_block_hash: demo.state.parent_hash.clone(),
            deterministic_replay,
            checks: SmokeChecks {
                genesis_config_initialized: demo.state.config.no_value,
                operator_key_reference_present: !demo.state.operator_key_references.is_empty(),
                agent_registered: demo.state.agent_accounts.contains_key("agent:demo:alpha"),
                local_test_unit_balance_created: demo
                    .state
                    .local_test_unit_balances
                    .contains_key("local-balance:demo:agent-alpha"),
                faucet_record_created: demo.state.faucet_records.contains_key("faucet:demo:001"),
                local_test_unit_balance_units: demo
                    .state
                    .local_test_unit_balances
                    .get("local-balance:demo:agent-alpha")
                    .map(|balance| balance.units)
                    .unwrap_or(0),
                model_registered: demo
                    .state
                    .model_passports
                    .contains_key("model:demo:local-alpha"),
                work_receipt_submitted: demo.state.work_receipts.contains_key("receipt:demo:001"),
                artifact_available: demo
                    .state
                    .artifact_availability_proofs
                    .contains_key("availability:demo:001"),
                verifier_module_registered: demo
                    .state
                    .verifier_modules
                    .contains_key("verifier:local-demo"),
                verifier_report_submitted: demo
                    .state
                    .verifier_reports
                    .contains_key("report:demo:001"),
                memory_cell_updated: demo
                    .state
                    .memory_cells
                    .contains_key("memory:demo:agent-alpha:core"),
                challenge_opened: demo.state.challenges.contains_key("challenge:demo:001"),
                challenge_resolved: demo
                    .state
                    .challenges
                    .get("challenge:demo:001")
                    .is_some_and(|challenge| challenge.status == "resolved"),
                receipt_finalized: demo
                    .state
                    .finality_receipts
                    .contains_key("finality:demo:001"),
                base_anchor_created: !demo.state.base_anchors.is_empty(),
            },
            handoff_files: handoff_files(),
        }
    }
}

fn handoff_files() -> Vec<String> {
    vec![
        "dashboard-state.json".to_string(),
        "indexer-handoff.json".to_string(),
        "verifier-handoff.json".to_string(),
        "control-plane-handoff.json".to_string(),
        "genesis-config.json".to_string(),
        "operator-key-references.json".to_string(),
        "state.json".to_string(),
    ]
}

#[allow(dead_code)]
fn _default_state_path_for_docs() -> PathBuf {
    default_state_path()
}
