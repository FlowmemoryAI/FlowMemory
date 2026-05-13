use crate::hash::{hash_json, normalize_value};
use crate::model::{
    FLOWPULSE_TOPIC0, ImportedFlowPulseObservation, ImportedVerifierReport, LocalAuthorization,
    Transaction, build_block, demo_transactions, envelope_tx, genesis_state,
    queue_authorized_transaction, queue_transaction, state_map_roots, state_root,
};
use crate::storage::{default_state_path, load_or_genesis, load_state, reset_state, save_state};
use anyhow::{Context, Result, anyhow};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::thread;
use std::time::Duration;

#[derive(Debug)]
pub struct Cli {
    state: PathBuf,
    node_dir: PathBuf,
    command: Command,
}

#[derive(Debug)]
pub enum Command {
    Init,
    ResetLocal,
    Start {
        blocks: u64,
    },
    Node {
        node_id: String,
        block_ms: u64,
        max_blocks: Option<u64>,
        peer_config: Option<PathBuf>,
    },
    NodeStop,
    NodeStatus,
    Tick {
        node_id: String,
        peer_config: Option<PathBuf>,
    },
    SubmitTx {
        tx_file: PathBuf,
        authorized_by: Option<String>,
        direct: bool,
    },
    Faucet {
        account_id: String,
        amount: u64,
        reason: String,
        authorized_by: Option<String>,
        direct: bool,
    },
    SubmitFixture {
        fixture: PathBuf,
    },
    InspectState {
        summary: bool,
    },
    ExportFixtures {
        out_dir: PathBuf,
    },
    ExportState {
        out: PathBuf,
    },
    ImportState {
        from: PathBuf,
    },
    Demo {
        out_dir: PathBuf,
    },
    Smoke {
        out_dir: PathBuf,
    },
}

pub fn run_cli() -> Result<()> {
    let cli = parse_args(env::args().skip(1).collect())?;
    run(cli)
}

fn parse_args(args: Vec<String>) -> Result<Cli> {
    let mut state = default_state_path();
    let mut node_dir = default_node_dir();
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
            "--node-dir" => {
                index += 1;
                let value = args
                    .get(index)
                    .ok_or_else(|| anyhow!("--node-dir requires a path"))?;
                node_dir = PathBuf::from(value);
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
        "node" => Command::Node {
            node_id: option_value_optional(&positional[1..], "--node-id")
                .unwrap_or_else(|| "node:local:alpha".to_string()),
            block_ms: option_u64(&positional[1..], "--block-ms")?.unwrap_or(1_000),
            max_blocks: option_u64(&positional[1..], "--max-blocks")?,
            peer_config: option_value_optional(&positional[1..], "--peer-config")
                .map(PathBuf::from),
        },
        "node-stop" => Command::NodeStop,
        "node-status" => Command::NodeStatus,
        "tick" => Command::Tick {
            node_id: option_value_optional(&positional[1..], "--node-id")
                .unwrap_or_else(|| "node:local:alpha".to_string()),
            peer_config: option_value_optional(&positional[1..], "--peer-config")
                .map(PathBuf::from),
        },
        "submit-tx" => {
            let tx_file = option_value(&positional[1..], "--tx-file")?;
            Command::SubmitTx {
                tx_file: PathBuf::from(tx_file),
                authorized_by: option_value_optional(&positional[1..], "--authorized-by"),
                direct: positional.iter().any(|arg| arg == "--direct"),
            }
        }
        "faucet" => Command::Faucet {
            account_id: option_value(&positional[1..], "--account")?,
            amount: option_u64(&positional[1..], "--amount")?
                .ok_or_else(|| anyhow!("--amount is required"))?,
            reason: option_value_optional(&positional[1..], "--reason")
                .unwrap_or_else(|| "local-private-testnet-faucet".to_string()),
            authorized_by: option_value_optional(&positional[1..], "--authorized-by"),
            direct: positional.iter().any(|arg| arg == "--direct"),
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

    Ok(Cli {
        state,
        node_dir,
        command,
    })
}

fn default_node_dir() -> PathBuf {
    PathBuf::from("devnet/local/node")
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

fn option_value_optional(args: &[String], name: &str) -> Option<String> {
    let index = args.iter().position(|arg| arg == name)?;
    args.get(index + 1).cloned()
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
        "flowmemory-devnet --state <path> --node-dir <path> <command>\n\nCommands:\n  init\n  reset-local\n  node [--node-id <id>] [--block-ms <ms>] [--max-blocks <n>] [--peer-config <path>]\n  node-stop\n  node-status\n  tick [--node-id <id>] [--peer-config <path>]\n  submit-tx --tx-file <path> [--authorized-by <id>] [--direct]\n  faucet --account <id> --amount <n> [--reason <text>] [--authorized-by <id>] [--direct]\n  start|run [--blocks <n>]\n  run-block\n  submit-fixture --fixture <path>\n  inspect|inspect-state [--summary]\n  export|export-fixtures [--out-dir <path>]\n  export-state [--out <path>]\n  import-state --from <path>\n  demo [--out-dir <path>]\n  smoke [--out-dir <path>]\n"
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
        Command::Node {
            node_id,
            block_ms,
            max_blocks,
            peer_config,
        } => {
            run_node(NodeRunOptions {
                state_path: cli.state,
                node_dir: cli.node_dir,
                node_id,
                block_ms,
                max_blocks,
                peer_config,
            })?;
        }
        Command::NodeStop => {
            request_node_stop(&cli.node_dir)?;
            let stop_path = stop_file(&cli.node_dir);
            let state = load_or_genesis(&cli.state)?;
            write_node_status(
                &cli.node_dir,
                &NodeStatus::from_state(
                    "stopping",
                    "local stop requested",
                    "node:local:unknown",
                    0,
                    &cli.state,
                    &cli.node_dir,
                    &state,
                    0,
                    0,
                    None,
                ),
            )?;
            print_json(&NodeStopSummary {
                schema: "flowmemory.local_devnet.node_stop.v0".to_string(),
                node_dir: cli.node_dir,
                stop_file: stop_path,
                requested: true,
            })?;
        }
        Command::NodeStatus => {
            let state = load_or_genesis(&cli.state)?;
            let persisted_status = read_node_status(&cli.node_dir)?;
            print_json(&NodeStatusSummary::from_state(
                cli.state,
                cli.node_dir,
                &state,
                persisted_status,
            ))?;
        }
        Command::Tick {
            node_id,
            peer_config,
        } => {
            let mut state = load_or_genesis(&cli.state)?;
            let peers = load_peer_config(peer_config.as_deref())?;
            let sync_event = sync_from_peers(&mut state, &peers)?;
            let ingested = drain_inbox(&mut state, &cli.node_dir)?;
            let produced = build_block(&mut state);
            save_state(&cli.state, &state)?;
            write_runtime_boundary_files(&cli.state, &state)?;
            let status = NodeStatus::from_state(
                "ticked",
                "manual tick completed",
                &node_id,
                std::process::id(),
                &cli.state,
                &cli.node_dir,
                &state,
                ingested.queued,
                ingested.rejected,
                sync_event,
            );
            write_node_identity(&cli.node_dir, &node_id, &cli.state, peer_config.as_deref())?;
            write_node_status(&cli.node_dir, &status)?;
            print_json(&NodeTickSummary::from_block(status, produced.block_hash))?;
        }
        Command::SubmitTx {
            tx_file,
            authorized_by,
            direct,
        } => {
            let txs = transactions_from_fixture(&tx_file)?;
            let queued = if direct {
                queue_txs_direct(&cli.state, txs, authorized_by)?
            } else {
                write_txs_to_inbox(&cli.node_dir, txs, authorized_by)?
            };
            print_json(&QueuedTransactions { queued })?;
        }
        Command::Faucet {
            account_id,
            amount,
            reason,
            authorized_by,
            direct,
        } => {
            let faucet_record_id = crate::hash::hash_json(
                "flowmemory.local_devnet.faucet_record_id.v0",
                &serde_json::json!({
                    "accountId": &account_id,
                    "amount": amount,
                    "reason": &reason
                }),
            );
            let tx = Transaction::FaucetLocalBalance {
                faucet_record_id,
                account_id,
                amount,
                reason,
            };
            let queued = if direct {
                queue_txs_direct(&cli.state, vec![tx], authorized_by)?
            } else {
                write_txs_to_inbox(&cli.node_dir, vec![tx], authorized_by)?
            };
            print_json(&QueuedTransactions { queued })?;
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
            let first = build_demo_state();
            let second = build_demo_state();
            let deterministic_replay = first.first_block_hash == second.first_block_hash
                && first.second_block_hash == second.second_block_hash
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

#[derive(Debug)]
struct NodeRunOptions {
    state_path: PathBuf,
    node_dir: PathBuf,
    node_id: String,
    block_ms: u64,
    max_blocks: Option<u64>,
    peer_config: Option<PathBuf>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct PeerConfig {
    #[serde(default = "peer_config_schema")]
    schema: String,
    #[serde(default)]
    node_id: Option<String>,
    #[serde(default)]
    peers: Vec<StaticPeer>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct StaticPeer {
    node_id: String,
    state_path: PathBuf,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct PeerSyncEvent {
    peer_id: String,
    peer_state_path: PathBuf,
    adopted_block_height: usize,
    adopted_state_root: String,
}

#[derive(Debug, Default)]
struct InboxIngestSummary {
    queued: usize,
    rejected: usize,
}

fn peer_config_schema() -> String {
    "flowmemory.local_devnet.static_peers.v0".to_string()
}

fn run_node(options: NodeRunOptions) -> Result<()> {
    if options.block_ms == 0 {
        return Err(anyhow!("--block-ms must be greater than zero"));
    }

    fs::create_dir_all(inbox_dir(&options.node_dir))?;
    fs::create_dir_all(processed_dir(&options.node_dir))?;
    fs::create_dir_all(rejected_dir(&options.node_dir))?;
    let stop_path = stop_file(&options.node_dir);
    if stop_path.exists() {
        fs::remove_file(&stop_path)
            .with_context(|| format!("failed to remove stale stop file {}", stop_path.display()))?;
    }

    let peers = load_peer_config(options.peer_config.as_deref())?;
    write_node_identity(
        &options.node_dir,
        &options.node_id,
        &options.state_path,
        options.peer_config.as_deref(),
    )?;

    let mut state = load_or_genesis(&options.state_path)?;
    save_state(&options.state_path, &state)?;
    write_runtime_boundary_files(&options.state_path, &state)?;

    let mut produced = 0_u64;
    loop {
        if stop_path.exists() {
            let status = NodeStatus::from_state(
                "stopped",
                "stop file observed",
                &options.node_id,
                std::process::id(),
                &options.state_path,
                &options.node_dir,
                &state,
                0,
                0,
                None,
            );
            write_node_status(&options.node_dir, &status)?;
            println!("{}", serde_json::to_string(&status)?);
            break;
        }

        let sync_event = sync_from_peers(&mut state, &peers)?;
        let ingested = drain_inbox(&mut state, &options.node_dir)?;
        let block = build_block(&mut state);
        produced += 1;
        save_state(&options.state_path, &state)?;
        write_runtime_boundary_files(&options.state_path, &state)?;

        let status = NodeStatus::from_state(
            "running",
            "block produced",
            &options.node_id,
            std::process::id(),
            &options.state_path,
            &options.node_dir,
            &state,
            ingested.queued,
            ingested.rejected,
            sync_event,
        );
        write_node_status(&options.node_dir, &status)?;

        println!(
            "{}",
            serde_json::to_string(&serde_json::json!({
                "schema": "flowmemory.local_devnet.node_log.v0",
                "nodeId": options.node_id,
                "event": "blockProduced",
                "blockNumber": block.block_number,
                "blockHash": block.block_hash,
                "txs": block.tx_ids.len(),
                "stateRoot": block.state_root
            }))?
        );

        if options
            .max_blocks
            .is_some_and(|max_blocks| produced >= max_blocks)
        {
            let status = NodeStatus::from_state(
                "stopped",
                "max blocks reached",
                &options.node_id,
                std::process::id(),
                &options.state_path,
                &options.node_dir,
                &state,
                0,
                0,
                None,
            );
            write_node_status(&options.node_dir, &status)?;
            println!("{}", serde_json::to_string(&status)?);
            break;
        }

        thread::sleep(Duration::from_millis(options.block_ms));
    }

    Ok(())
}

fn request_node_stop(node_dir: &Path) -> Result<()> {
    fs::create_dir_all(node_dir)
        .with_context(|| format!("failed to create node directory {}", node_dir.display()))?;
    fs::write(stop_file(node_dir), b"stop\n")
        .with_context(|| format!("failed to write node stop file in {}", node_dir.display()))
}

fn queue_txs_direct(
    state_path: &Path,
    txs: Vec<Transaction>,
    authorized_by: Option<String>,
) -> Result<Vec<String>> {
    let mut state = load_or_genesis(state_path)?;
    let mut queued = Vec::new();
    for tx in txs {
        let tx_id = match authorized_by.clone() {
            Some(signer) => queue_authorized_transaction(&mut state, tx, signer),
            None => queue_transaction(&mut state, tx),
        };
        queued.push(tx_id);
    }
    save_state(state_path, &state)?;
    Ok(queued)
}

fn write_txs_to_inbox(
    node_dir: &Path,
    txs: Vec<Transaction>,
    authorized_by: Option<String>,
) -> Result<Vec<String>> {
    let inbox = inbox_dir(node_dir);
    fs::create_dir_all(&inbox)
        .with_context(|| format!("failed to create inbox directory {}", inbox.display()))?;

    let mut queued = Vec::new();
    for tx in txs {
        let envelope = local_authorized_envelope(tx, authorized_by.clone());
        let tx_id = envelope.tx_id.clone();
        let path = inbox.join(format!("{}.json", file_safe_id(&tx_id)));
        write_json(
            path,
            &serde_json::json!({
                "schema": "flowmemory.local_devnet.inbox_tx.v0",
                "tx": envelope.tx,
                "authorization": envelope.authorization
            }),
        )?;
        queued.push(tx_id);
    }
    Ok(queued)
}

fn drain_inbox(
    state: &mut crate::model::ChainState,
    node_dir: &Path,
) -> Result<InboxIngestSummary> {
    let inbox = inbox_dir(node_dir);
    if !inbox.exists() {
        return Ok(InboxIngestSummary::default());
    }

    fs::create_dir_all(processed_dir(node_dir))?;
    fs::create_dir_all(rejected_dir(node_dir))?;
    let mut files = fs::read_dir(&inbox)?
        .filter_map(|entry| entry.ok())
        .map(|entry| entry.path())
        .filter(|path| {
            path.extension()
                .and_then(|extension| extension.to_str())
                .is_some_and(|extension| extension.eq_ignore_ascii_case("json"))
        })
        .collect::<Vec<_>>();
    files.sort();

    let mut summary = InboxIngestSummary::default();
    for path in files {
        match transactions_from_inbox_file(&path) {
            Ok(txs) => {
                for (tx, authorization) in txs {
                    let mut envelope = envelope_tx(tx);
                    envelope.authorization = authorization;
                    state.pending_txs.push(envelope);
                    summary.queued += 1;
                }
                move_inbox_file(&path, &processed_dir(node_dir))?;
            }
            Err(error) => {
                let error_path = rejected_dir(node_dir).join(format!(
                    "{}.error.json",
                    path.file_stem()
                        .and_then(|stem| stem.to_str())
                        .unwrap_or("rejected")
                ));
                write_json(
                    error_path,
                    &serde_json::json!({
                        "schema": "flowmemory.local_devnet.rejected_inbox_tx.v0",
                        "source": path,
                        "error": error.to_string()
                    }),
                )?;
                move_inbox_file(&path, &rejected_dir(node_dir))?;
                summary.rejected += 1;
            }
        }
    }

    Ok(summary)
}

fn move_inbox_file(path: &Path, target_dir: &Path) -> Result<()> {
    fs::create_dir_all(target_dir)?;
    let file_name = path
        .file_name()
        .ok_or_else(|| anyhow!("inbox path has no file name: {}", path.display()))?;
    let target = target_dir.join(file_name);
    if target.exists() {
        fs::remove_file(&target)?;
    }
    fs::rename(path, target)?;
    Ok(())
}

fn local_authorized_envelope(
    tx: Transaction,
    authorized_by: Option<String>,
) -> crate::model::TxEnvelope {
    let mut envelope = envelope_tx(tx);
    if let Some(signer) = authorized_by {
        envelope.authorization = Some(LocalAuthorization {
            mode: "local-authorized".to_string(),
            signer,
            digest: envelope.tx_id.clone(),
        });
    }
    envelope
}

fn load_peer_config(path: Option<&Path>) -> Result<Vec<StaticPeer>> {
    let Some(path) = path else {
        return Ok(Vec::new());
    };
    let body = fs::read_to_string(path)
        .with_context(|| format!("failed to read peer config {}", path.display()))?;
    let config: PeerConfig = serde_json::from_str(body.trim_start_matches('\u{feff}'))
        .with_context(|| format!("failed to parse peer config {}", path.display()))?;
    Ok(config.peers)
}

fn sync_from_peers(
    state: &mut crate::model::ChainState,
    peers: &[StaticPeer],
) -> Result<Option<PeerSyncEvent>> {
    let mut adopted = None;
    for peer in peers {
        if !peer.state_path.exists() {
            continue;
        }
        let peer_state = load_state(&peer.state_path)?;
        if peer_state.chain_id != state.chain_id {
            continue;
        }
        if should_adopt_peer_state(state, &peer_state) {
            let adopted_state_root = state_root(&peer_state);
            let adopted_block_height = peer_state.blocks.len();
            *state = peer_state;
            adopted = Some(PeerSyncEvent {
                peer_id: peer.node_id.clone(),
                peer_state_path: peer.state_path.clone(),
                adopted_block_height,
                adopted_state_root,
            });
        }
    }
    Ok(adopted)
}

fn should_adopt_peer_state(
    local: &crate::model::ChainState,
    peer: &crate::model::ChainState,
) -> bool {
    let local_height = local.blocks.len();
    let peer_height = peer.blocks.len();
    if peer_height > local_height {
        return true;
    }
    if peer_height == local_height && peer_height > 0 {
        return state_root(peer) < state_root(local);
    }
    false
}

fn write_node_identity(
    node_dir: &Path,
    node_id: &str,
    state_path: &Path,
    peer_config: Option<&Path>,
) -> Result<()> {
    fs::create_dir_all(node_dir)?;
    write_json(
        node_dir.join("node-identity.json"),
        &serde_json::json!({
            "schema": "flowmemory.local_devnet.node_identity.v0",
            "nodeId": node_id,
            "mode": "local-file-private-testnet",
            "statePath": state_path,
            "peerConfig": peer_config,
            "localOnly": true,
            "lanMode": "not exposed; static local-file peers only"
        }),
    )
}

fn write_node_status(node_dir: &Path, status: &NodeStatus) -> Result<()> {
    fs::create_dir_all(node_dir)?;
    write_json(node_dir.join("status.json"), status)
}

fn read_node_status(node_dir: &Path) -> Result<Option<Value>> {
    let path = node_dir.join("status.json");
    if !path.exists() {
        return Ok(None);
    }
    let body = fs::read_to_string(&path)
        .with_context(|| format!("failed to read node status {}", path.display()))?;
    serde_json::from_str(&body)
        .map(Some)
        .with_context(|| format!("failed to parse node status {}", path.display()))
}

fn inbox_dir(node_dir: &Path) -> PathBuf {
    node_dir.join("inbox")
}

fn processed_dir(node_dir: &Path) -> PathBuf {
    node_dir.join("processed")
}

fn rejected_dir(node_dir: &Path) -> PathBuf {
    node_dir.join("rejected")
}

fn stop_file(node_dir: &Path) -> PathBuf {
    node_dir.join("stop")
}

fn file_safe_id(id: &str) -> String {
    id.chars()
        .map(|ch| match ch {
            'a'..='z' | 'A'..='Z' | '0'..='9' => ch,
            _ => '-',
        })
        .collect()
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

fn transactions_from_inbox_file(
    path: &Path,
) -> Result<Vec<(Transaction, Option<LocalAuthorization>)>> {
    let body = fs::read_to_string(path)
        .with_context(|| format!("failed to read inbox transaction {}", path.display()))?;
    let value: Value = serde_json::from_str(body.trim_start_matches('\u{feff}'))
        .with_context(|| format!("failed to parse inbox transaction {}", path.display()))?;
    let authorization = authorization_from_value(value.get("authorization"))?;

    if value.get("txs").is_some() {
        let txs: Vec<Transaction> = serde_json::from_value(value["txs"].clone())
            .with_context(|| format!("failed to parse txs in {}", path.display()))?;
        return Ok(txs
            .into_iter()
            .map(|tx| (tx, authorization.clone()))
            .collect());
    }

    if value.get("tx").is_some() {
        let tx = serde_json::from_value(value["tx"].clone())
            .with_context(|| format!("failed to parse tx in {}", path.display()))?;
        return Ok(vec![(tx, authorization)]);
    }

    transactions_from_fixture(path).map(|txs| txs.into_iter().map(|tx| (tx, None)).collect())
}

fn authorization_from_value(value: Option<&Value>) -> Result<Option<LocalAuthorization>> {
    match value {
        Some(Value::Null) | None => Ok(None),
        Some(value) => serde_json::from_value(value.clone())
            .map(Some)
            .context("failed to parse local authorization"),
    }
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
        "localBalances": state.local_balances,
        "faucetRecords": state.faucet_records,
        "balanceTransfers": state.balance_transfers,
        "rootfields": state.rootfields,
        "agentAccounts": state.agent_accounts,
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
        "localBalances": state.local_balances,
        "faucetRecords": state.faucet_records,
        "balanceTransfers": state.balance_transfers,
        "agentAccounts": state.agent_accounts,
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
        "localBalances": state.local_balances,
        "faucetRecords": state.faucet_records,
        "balanceTransfers": state.balance_transfers,
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
            "localBalances": state.local_balances,
            "faucetRecords": state.faucet_records,
            "balanceTransfers": state.balance_transfers,
            "rootfields": state.rootfields,
            "agentAccounts": state.agent_accounts,
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

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct NodeStatus {
    schema: String,
    status: String,
    note: String,
    node_id: String,
    pid: u32,
    state_path: PathBuf,
    node_dir: PathBuf,
    block_height: usize,
    next_block_number: u64,
    latest_block_hash: String,
    state_root: String,
    pending_txs: usize,
    local_balances: usize,
    faucet_records: usize,
    static_peer_sync: Option<PeerSyncEvent>,
    last_ingested_txs: usize,
    last_rejected_inbox_files: usize,
    lan_mode: String,
}

impl NodeStatus {
    fn from_state(
        status: &str,
        note: &str,
        node_id: &str,
        pid: u32,
        state_path: &Path,
        node_dir: &Path,
        state: &crate::model::ChainState,
        last_ingested_txs: usize,
        last_rejected_inbox_files: usize,
        static_peer_sync: Option<PeerSyncEvent>,
    ) -> Self {
        Self {
            schema: "flowmemory.local_devnet.node_status.v0".to_string(),
            status: status.to_string(),
            note: note.to_string(),
            node_id: node_id.to_string(),
            pid,
            state_path: state_path.to_path_buf(),
            node_dir: node_dir.to_path_buf(),
            block_height: state.blocks.len(),
            next_block_number: state.next_block_number,
            latest_block_hash: state
                .blocks
                .last()
                .map(|block| block.block_hash.clone())
                .unwrap_or_else(|| state.parent_hash.clone()),
            state_root: state_root(state),
            pending_txs: state.pending_txs.len(),
            local_balances: state.local_balances.len(),
            faucet_records: state.faucet_records.len(),
            static_peer_sync,
            last_ingested_txs,
            last_rejected_inbox_files,
            lan_mode: "not exposed; static local-file peers only".to_string(),
        }
    }
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct NodeStatusSummary {
    schema: String,
    state_path: PathBuf,
    node_dir: PathBuf,
    stop_requested: bool,
    state: StateSummary,
    persisted_status: Option<Value>,
}

impl NodeStatusSummary {
    fn from_state(
        state_path: PathBuf,
        node_dir: PathBuf,
        state: &crate::model::ChainState,
        persisted_status: Option<Value>,
    ) -> Self {
        let stop_requested = stop_file(&node_dir).exists();
        Self {
            schema: "flowmemory.local_devnet.node_status_summary.v0".to_string(),
            state_path,
            node_dir,
            stop_requested,
            state: StateSummary::from_state(state),
            persisted_status,
        }
    }
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct NodeStopSummary {
    schema: String,
    node_dir: PathBuf,
    stop_file: PathBuf,
    requested: bool,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct NodeTickSummary {
    schema: String,
    block_hash: String,
    status: NodeStatus,
}

impl NodeTickSummary {
    fn from_block(status: NodeStatus, block_hash: String) -> Self {
        Self {
            schema: "flowmemory.local_devnet.node_tick.v0".to_string(),
            block_hash,
            status,
        }
    }
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
    local_balances: usize,
    faucet_records: usize,
    balance_transfers: usize,
    pending_txs: usize,
    blocks: usize,
    rootfields: usize,
    agent_accounts: usize,
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
            local_balances: state.local_balances.len(),
            faucet_records: state.faucet_records.len(),
            balance_transfers: state.balance_transfers.len(),
            pending_txs: state.pending_txs.len(),
            blocks: state.blocks.len(),
            rootfields: state.rootfields.len(),
            agent_accounts: state.agent_accounts.len(),
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
    local_balance_credited: bool,
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
            local_balance_credited: demo.state.local_balances.contains_key("agent:demo:alpha"),
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
    deterministic_replay: bool,
    checks: SmokeChecks,
    handoff_files: Vec<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct SmokeChecks {
    genesis_config_initialized: bool,
    operator_key_reference_present: bool,
    local_balance_credited: bool,
    local_balance_transferred: bool,
    agent_registered: bool,
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
            deterministic_replay,
            checks: SmokeChecks {
                genesis_config_initialized: demo.state.config.no_value,
                operator_key_reference_present: !demo.state.operator_key_references.is_empty(),
                local_balance_credited: demo
                    .state
                    .local_balances
                    .get("agent:demo:alpha")
                    .is_some_and(|balance| balance.balance == 100),
                local_balance_transferred: demo
                    .state
                    .balance_transfers
                    .contains_key("transfer:demo:operator-to-agent:001"),
                agent_registered: demo.state.agent_accounts.contains_key("agent:demo:alpha"),
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
