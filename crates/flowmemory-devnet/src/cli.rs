use crate::hash::{hash_json, normalize_value};
use crate::model::{
    FLOWPULSE_TOPIC0, ImportedFlowPulseObservation, ImportedVerifierReport, Transaction,
    build_block, demo_transactions, genesis_state, queue_transaction, state_root,
};
use crate::storage::{default_state_path, load_or_genesis, reset_state, save_state};
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
    RunBlock,
    SubmitFixture { fixture: PathBuf },
    InspectState { summary: bool },
    ExportFixtures { out_dir: PathBuf },
    Demo { out_dir: PathBuf },
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
        "run-block" => Command::RunBlock,
        "submit-fixture" => {
            let fixture = option_value(&positional[1..], "--fixture")?;
            Command::SubmitFixture {
                fixture: PathBuf::from(fixture),
            }
        }
        "inspect-state" => Command::InspectState {
            summary: positional.iter().any(|arg| arg == "--summary"),
        },
        "export-fixtures" => Command::ExportFixtures {
            out_dir: option_value(&positional[1..], "--out-dir")
                .map(PathBuf::from)
                .unwrap_or_else(|_| PathBuf::from("fixtures/handoff/generated")),
        },
        "demo" => Command::Demo {
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

fn print_help() {
    println!(
        "flowmemory-devnet --state <path> <command>\n\nCommands:\n  init\n  reset-local\n  run-block\n  submit-fixture --fixture <path>\n  inspect-state [--summary]\n  export-fixtures [--out-dir <path>]\n  demo [--out-dir <path>]\n"
    );
}

fn run(cli: Cli) -> Result<()> {
    match cli.command {
        Command::Init => {
            let state = genesis_state();
            save_state(&cli.state, &state)?;
            print_json(&StateSummary::from_state(&state))?;
        }
        Command::ResetLocal => {
            let state = reset_state(&cli.state)?;
            print_json(&StateSummary::from_state(&state))?;
        }
        Command::RunBlock => {
            let mut state = load_or_genesis(&cli.state)?;
            let block = build_block(&mut state);
            save_state(&cli.state, &state)?;
            print_json(&block)?;
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
        Command::Demo { out_dir } => {
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
            save_state(&cli.state, &state)?;
            export_handoff(&state, &out_dir)?;
            print_json(&DemoSummary {
                state_path: cli.state,
                first_block_hash: first.block_hash,
                second_block_hash: second.block_hash,
                state_root: state_root(&state),
                out_dir,
            })?;
        }
    }
    Ok(())
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

    let dashboard = serde_json::json!({
        "schema": "flowmemory.dashboard_state.local_devnet.v0",
        "stateRoot": state_root(state),
        "blockHeight": state.blocks.len(),
        "rootfields": state.rootfields,
        "artifactCommitments": state.artifact_commitments,
        "workReceipts": state.work_receipts,
        "verifierReports": state.verifier_reports,
        "baseAnchors": state.base_anchors,
    });

    let indexer = serde_json::json!({
        "schema": "flowmemory.indexer_handoff.local_devnet.v0",
        "importedObservations": state.imported_observations,
        "blocks": state.blocks,
        "stateRoot": state_root(state),
    });

    let verifier = serde_json::json!({
        "schema": "flowmemory.verifier_handoff.local_devnet.v0",
        "workReceipts": state.work_receipts,
        "verifierReports": state.verifier_reports,
        "importedVerifierReports": state.imported_verifier_reports,
        "stateRoot": state_root(state),
    });

    write_json(out_dir.join("dashboard-state.json"), &dashboard)?;
    write_json(out_dir.join("indexer-handoff.json"), &indexer)?;
    write_json(out_dir.join("verifier-handoff.json"), &verifier)?;
    write_json(out_dir.join("state.json"), state)?;
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
    pending_txs: usize,
    blocks: usize,
    rootfields: usize,
    artifact_commitments: usize,
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
            pending_txs: state.pending_txs.len(),
            blocks: state.blocks.len(),
            rootfields: state.rootfields.len(),
            artifact_commitments: state.artifact_commitments.len(),
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
struct ExportSummary {
    schema: String,
    out_dir: PathBuf,
    state_root: String,
}

impl ExportSummary {
    fn from_state(state: &crate::model::ChainState, out_dir: PathBuf) -> Self {
        Self {
            schema: "flowmemory.local_devnet.export_summary.v0".to_string(),
            out_dir,
            state_root: state_root(state),
        }
    }
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct DemoSummary {
    state_path: PathBuf,
    first_block_hash: String,
    second_block_hash: String,
    state_root: String,
    out_dir: PathBuf,
}

#[allow(dead_code)]
fn _default_state_path_for_docs() -> PathBuf {
    default_state_path()
}
