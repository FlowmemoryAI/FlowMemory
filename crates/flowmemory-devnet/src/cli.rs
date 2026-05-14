use crate::hash::{canonical_json_hash, hash_json, keccak_hex, normalize_value};
use crate::model::{
    FLOWPULSE_TOPIC0, ImportedFlowPulseObservation, ImportedVerifierReport,
    LOCAL_TEST_UNIT_ASSET_ID, LocalAuthorization, Transaction, build_block, demo_transactions,
    deterministic_token_id, envelope_tx, genesis_state, product_demo_transactions,
    queue_authorized_transaction, queue_transaction, record_pending_transaction, state_map_roots,
    state_root,
};
use crate::storage::{default_state_path, load_or_genesis, load_state, reset_state, save_state};
use anyhow::{Context, Result, anyhow};
use k256::ecdsa::{Signature, VerifyingKey, signature::hazmat::PrehashVerifier};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::BTreeSet;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

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
    NodeRestart {
        node_id: String,
        block_ms: u64,
        max_blocks: Option<u64>,
        peer_config: Option<PathBuf>,
    },
    Tick {
        node_id: String,
        peer_config: Option<PathBuf>,
    },
    SubmitTx {
        tx_file: PathBuf,
        authorized_by: Option<String>,
        direct: bool,
    },
    BridgeIngest {
        handoff: PathBuf,
        authorized_by: Option<String>,
        direct: bool,
        require_live: bool,
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
    ListMempool,
    Query {
        kind: QueryKind,
        id: String,
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
    ProductSmoke {
        out_dir: PathBuf,
    },
    NodeSmoke {
        out_dir: PathBuf,
    },
}

#[derive(Debug, Clone)]
pub enum QueryKind {
    Block,
    Transaction,
    Receipt,
    Account,
    Token,
    Pool,
    BridgeCredit,
    FinalityReceipt,
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
        "node-restart" => Command::NodeRestart {
            node_id: option_value_optional(&positional[1..], "--node-id")
                .unwrap_or_else(|| "node:local:alpha".to_string()),
            block_ms: option_u64(&positional[1..], "--block-ms")?.unwrap_or(1_000),
            max_blocks: option_u64(&positional[1..], "--max-blocks")?.or(Some(1)),
            peer_config: option_value_optional(&positional[1..], "--peer-config")
                .map(PathBuf::from),
        },
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
        "bridge-ingest" | "bridge-handoff" => Command::BridgeIngest {
            handoff: PathBuf::from(option_value(&positional[1..], "--handoff")?),
            authorized_by: option_value_optional(&positional[1..], "--authorized-by"),
            direct: positional.iter().any(|arg| arg == "--direct"),
            require_live: positional.iter().any(|arg| arg == "--require-live"),
        },
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
        "list-mempool" | "mempool" => Command::ListMempool,
        "query" => Command::Query {
            kind: query_kind(&option_value(&positional[1..], "--kind")?)?,
            id: option_value(&positional[1..], "--id")?,
        },
        "query-block" => Command::Query {
            kind: QueryKind::Block,
            id: option_value(&positional[1..], "--id")?,
        },
        "query-tx" | "query-transaction" => Command::Query {
            kind: QueryKind::Transaction,
            id: option_value(&positional[1..], "--id")?,
        },
        "query-receipt" => Command::Query {
            kind: QueryKind::Receipt,
            id: option_value(&positional[1..], "--id")?,
        },
        "query-account" => Command::Query {
            kind: QueryKind::Account,
            id: option_value(&positional[1..], "--id")?,
        },
        "query-token" => Command::Query {
            kind: QueryKind::Token,
            id: option_value(&positional[1..], "--id")?,
        },
        "query-pool" => Command::Query {
            kind: QueryKind::Pool,
            id: option_value(&positional[1..], "--id")?,
        },
        "query-bridge-credit" => Command::Query {
            kind: QueryKind::BridgeCredit,
            id: option_value(&positional[1..], "--id")?,
        },
        "query-finality" | "query-finality-receipt" => Command::Query {
            kind: QueryKind::FinalityReceipt,
            id: option_value(&positional[1..], "--id")?,
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
        "product-demo" | "product-smoke" => Command::ProductSmoke {
            out_dir: option_value(&positional[1..], "--out-dir")
                .map(PathBuf::from)
                .unwrap_or_else(|_| PathBuf::from("fixtures/handoff/generated-product")),
        },
        "node-smoke" => Command::NodeSmoke {
            out_dir: option_value(&positional[1..], "--out-dir")
                .map(PathBuf::from)
                .unwrap_or_else(|_| PathBuf::from("devnet/local/node-smoke")),
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

fn query_kind(value: &str) -> Result<QueryKind> {
    match value {
        "block" => Ok(QueryKind::Block),
        "tx" | "transaction" => Ok(QueryKind::Transaction),
        "receipt" => Ok(QueryKind::Receipt),
        "account" => Ok(QueryKind::Account),
        "token" => Ok(QueryKind::Token),
        "pool" => Ok(QueryKind::Pool),
        "bridge-credit" | "bridgeCredit" => Ok(QueryKind::BridgeCredit),
        "finality" | "finality-receipt" | "finalityReceipt" => Ok(QueryKind::FinalityReceipt),
        other => Err(anyhow!("unsupported query kind '{other}'")),
    }
}

fn print_help() {
    println!(
        "flowmemory-devnet --state <path> --node-dir <path> <command>\n\nCommands:\n  init\n  reset-local\n  node [--node-id <id>] [--block-ms <ms>] [--max-blocks <n>] [--peer-config <path>]\n  node-stop\n  node-status\n  node-restart [--node-id <id>] [--block-ms <ms>] [--max-blocks <n>] [--peer-config <path>]\n  tick [--node-id <id>] [--peer-config <path>]\n  submit-tx --tx-file <path> [--authorized-by <id>] [--direct]\n  bridge-ingest --handoff <path> [--authorized-by <id>] [--direct] [--require-live]\n  faucet --account <id> --amount <n> [--reason <text>] [--authorized-by <id>] [--direct]\n  list-mempool\n  query --kind <block|transaction|receipt|account|token|pool|bridge-credit|finality-receipt> --id <id>\n  query-block|query-tx|query-receipt|query-account|query-token|query-pool|query-bridge-credit|query-finality --id <id>\n  start|run [--blocks <n>]\n  run-block\n  submit-fixture --fixture <path>\n  inspect|inspect-state [--summary]\n  export|export-fixtures [--out-dir <path>]\n  export-state [--out <path>]\n  import-state --from <path>\n  demo [--out-dir <path>]\n  smoke [--out-dir <path>]\n  product-demo|product-smoke [--out-dir <path>]\n  node-smoke [--out-dir <path>]\n"
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
            let state = load_or_genesis(&cli.state)?;
            let stop_path = stop_file(&cli.node_dir);
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
        Command::NodeRestart {
            node_id,
            block_ms,
            max_blocks,
            peer_config,
        } => {
            request_node_stop(&cli.node_dir)?;
            if stop_file(&cli.node_dir).exists() {
                fs::remove_file(stop_file(&cli.node_dir))?;
            }
            run_node(NodeRunOptions {
                state_path: cli.state,
                node_dir: cli.node_dir,
                node_id,
                block_ms,
                max_blocks,
                peer_config,
            })?;
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
            append_node_log(
                &cli.node_dir,
                &serde_json::json!({
                    "schema": "flowmemory.local_devnet.node_log.v0",
                    "nodeId": node_id,
                    "event": "manualTick",
                    "blockHash": produced.block_hash,
                    "txs": produced.tx_ids.len(),
                    "stateRoot": produced.state_root
                }),
            )?;
            print_json(&NodeTickSummary::from_block(status, produced.block_hash))?;
        }
        Command::SubmitTx {
            tx_file,
            authorized_by,
            direct,
        } => {
            let queued = if direct {
                queue_tx_file_direct(&cli.state, &tx_file, authorized_by)?
            } else {
                write_tx_file_to_inbox(&cli.node_dir, &tx_file, authorized_by)?
            };
            print_json(&queued)?;
        }
        Command::BridgeIngest {
            handoff,
            authorized_by,
            direct,
            require_live,
        } => {
            let txs = bridge_handoff_transactions_from_path(&handoff, require_live)?;
            let credit_ids = txs
                .iter()
                .filter_map(bridge_credit_id_from_tx)
                .collect::<Vec<_>>();
            let queued = if direct {
                queue_txs_direct_result(&cli.state, txs, authorized_by)?
            } else {
                QueuedTransactions::accepted_only(write_txs_to_inbox(
                    &cli.node_dir,
                    txs,
                    authorized_by,
                )?)
            };
            print_json(&BridgeIngestSummary {
                schema: "flowmemory.local_devnet.bridge_ingest.v0".to_string(),
                handoff,
                direct,
                require_live,
                credit_ids,
                queued,
            })?;
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
            let owner = authorized_by
                .clone()
                .unwrap_or_else(|| "local-test-operator".to_string());
            let txs = vec![
                Transaction::CreateLocalTestUnitBalance {
                    account_id: account_id.clone(),
                    owner: owner.clone(),
                },
                Transaction::FaucetLocalTestUnits {
                    faucet_record_id,
                    account_id,
                    recipient: owner,
                    amount_units: amount,
                    reason,
                },
            ];
            let queued = if direct {
                queue_txs_direct(&cli.state, txs, authorized_by)?
            } else {
                write_txs_to_inbox(&cli.node_dir, txs, authorized_by)?
            };
            print_json(&QueuedTransactions::accepted_only(queued))?;
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
            print_json(&QueuedTransactions::accepted_only(queued))?;
        }
        Command::InspectState { summary } => {
            let state = load_or_genesis(&cli.state)?;
            if summary {
                print_json(&StateSummary::from_state(&state))?;
            } else {
                print_json(&state)?;
            }
        }
        Command::ListMempool => {
            let state = load_or_genesis(&cli.state)?;
            print_json(&MempoolSummary::from_state(&state))?;
        }
        Command::Query { kind, id } => {
            let state = load_or_genesis(&cli.state)?;
            print_json(&query_state(&state, kind, &id)?)?;
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
        Command::ProductSmoke { out_dir } => {
            let first = build_product_smoke_state();
            let second = build_product_smoke_state();
            let deterministic_replay = first.first_block_hash == second.first_block_hash
                && first.second_block_hash == second.second_block_hash
                && first.state.parent_hash == second.state.parent_hash
                && state_root(&first.state) == state_root(&second.state)
                && state_map_roots(&first.state) == state_map_roots(&second.state);
            save_state(&cli.state, &first.state)?;
            write_runtime_boundary_files(&cli.state, &first.state)?;
            export_handoff(&first.state, &out_dir)?;
            print_json(&ProductSmokeSummary::from_demo(
                cli.state,
                out_dir,
                &first,
                deterministic_replay,
            ))?;
        }
        Command::NodeSmoke { out_dir } => {
            let report = run_node_smoke(&cli.state, &cli.node_dir, &out_dir)?;
            print_json(&report)?;
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

const MAX_MEMPOOL_TXS: usize = 1_024;
const LOCAL_TRANSACTION_TYPE: &str = "FlowChainLocalTransactionEnvelopeV0(uint256 chainId,bytes32 domainSeparator,bytes32 signerId,bytes32 signerKeyId,uint8 signerRole,uint64 nonce,bytes32 payloadHash,bytes32 objectId,bytes32 objectTypeHash,uint64 issuedAtUnixMs)";

#[derive(Debug)]
struct ParsedEnvelope {
    envelope: crate::model::TxEnvelope,
    signer: Option<String>,
    nonce: Option<u64>,
    replay_key: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct RejectedTx {
    tx_id: Option<String>,
    reason: String,
    source: Option<PathBuf>,
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

        let log_line = serde_json::json!({
                "schema": "flowmemory.local_devnet.node_log.v0",
                "nodeId": options.node_id,
                "event": "blockProduced",
                "blockNumber": block.block_number,
                "blockHash": block.block_hash,
                "txs": block.tx_ids.len(),
                "stateRoot": block.state_root
        });
        append_node_log(&options.node_dir, &log_line)?;
        println!("{}", serde_json::to_string(&log_line)?);

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
        let envelope = local_authorized_envelope(tx, authorized_by.clone());
        let parsed = parsed_local_envelope(envelope);
        queued.push(try_queue_envelope(&mut state, parsed)?);
    }
    save_state(state_path, &state)?;
    Ok(queued)
}

fn queue_txs_direct_result(
    state_path: &Path,
    txs: Vec<Transaction>,
    authorized_by: Option<String>,
) -> Result<QueuedTransactions> {
    let mut state = load_or_genesis(state_path)?;
    let mut result = QueuedTransactions::default();
    let mut simulation = preflight_state_with_pending(&state);
    for tx in txs {
        let envelope = local_authorized_envelope(tx, authorized_by.clone());
        let parsed = parsed_local_envelope(envelope);
        match validate_and_queue_envelope(&mut state, &mut simulation, parsed, None) {
            Ok(tx_id) => result.queued.push(tx_id),
            Err(rejected) => result.rejected.push(rejected),
        }
    }
    save_state(state_path, &state)?;
    Ok(result)
}

fn queue_tx_file_direct(
    state_path: &Path,
    tx_file: &Path,
    authorized_by: Option<String>,
) -> Result<QueuedTransactions> {
    let mut state = load_or_genesis(state_path)?;
    let mut result = QueuedTransactions::default();
    let parsed = parsed_envelopes_from_file(tx_file, authorized_by)?;
    let mut simulation = preflight_state_with_pending(&state);
    for parsed in parsed {
        match validate_and_queue_envelope(&mut state, &mut simulation, parsed, None) {
            Ok(tx_id) => result.queued.push(tx_id),
            Err(rejected) => result.rejected.push(rejected),
        }
    }
    save_state(state_path, &state)?;
    Ok(result)
}

fn write_tx_file_to_inbox(
    node_dir: &Path,
    tx_file: &Path,
    authorized_by: Option<String>,
) -> Result<QueuedTransactions> {
    let inbox = inbox_dir(node_dir);
    fs::create_dir_all(&inbox)
        .with_context(|| format!("failed to create inbox directory {}", inbox.display()))?;
    let body = fs::read_to_string(tx_file)
        .with_context(|| format!("failed to read transaction file {}", tx_file.display()))?;
    let value: Value = serde_json::from_str(body.trim_start_matches('\u{feff}'))
        .with_context(|| format!("failed to parse transaction file {}", tx_file.display()))?;
    let tx_ids = tx_ids_from_value(&value, authorized_by.clone())?;
    let suffix = file_safe_id(&hash_json(
        "flowmemory.local_devnet.inbox_file.v0",
        &serde_json::json!({
            "path": tx_file,
            "txIds": tx_ids
        }),
    ));
    let path = inbox.join(format!("{suffix}.json"));
    write_json(path, &value)?;
    Ok(QueuedTransactions {
        queued: tx_ids,
        rejected: Vec::new(),
    })
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
    let mut simulation = preflight_state_with_pending(state);
    for path in files {
        match parsed_envelopes_from_inbox_file(&path) {
            Ok(envelopes) => {
                let mut file_rejections = Vec::new();
                for envelope in envelopes {
                    match validate_and_queue_envelope(
                        state,
                        &mut simulation,
                        envelope,
                        Some(path.clone()),
                    ) {
                        Ok(_) => summary.queued += 1,
                        Err(rejected) => {
                            summary.rejected += 1;
                            file_rejections.push(rejected);
                        }
                    }
                }
                if file_rejections.is_empty() {
                    move_inbox_file(&path, &processed_dir(node_dir))?;
                } else {
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
                            "rejections": file_rejections
                        }),
                    )?;
                    move_inbox_file(&path, &rejected_dir(node_dir))?;
                }
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
            chain_id: None,
            nonce: None,
            signer_role: None,
            signer_key_id: None,
            public_key: None,
            signature: None,
            replay_key: None,
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

fn append_node_log(node_dir: &Path, value: &Value) -> Result<()> {
    fs::create_dir_all(node_dir)?;
    let path = node_dir.join("node.log.jsonl");
    let mut line = serde_json::to_string(value)?;
    line.push('\n');
    use std::io::Write;
    let mut file = fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
        .with_context(|| format!("failed to open node log {}", path.display()))?;
    file.write_all(line.as_bytes())
        .with_context(|| format!("failed to append node log {}", path.display()))
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

fn parsed_envelopes_from_inbox_file(path: &Path) -> Result<Vec<ParsedEnvelope>> {
    let body = fs::read_to_string(path)
        .with_context(|| format!("failed to read inbox transaction {}", path.display()))?;
    let value: Value = serde_json::from_str(body.trim_start_matches('\u{feff}'))
        .with_context(|| format!("failed to parse inbox transaction {}", path.display()))?;
    parsed_envelopes_from_value(&value, None)
}

fn parsed_envelopes_from_file(
    path: &Path,
    authorized_by: Option<String>,
) -> Result<Vec<ParsedEnvelope>> {
    let body = fs::read_to_string(path)
        .with_context(|| format!("failed to read transaction file {}", path.display()))?;
    let value: Value = serde_json::from_str(body.trim_start_matches('\u{feff}'))
        .with_context(|| format!("failed to parse transaction file {}", path.display()))?;
    parsed_envelopes_from_value(&value, authorized_by)
}

fn parsed_envelopes_from_value(
    value: &Value,
    authorized_by: Option<String>,
) -> Result<Vec<ParsedEnvelope>> {
    if value.get("envelope").is_some() {
        return Ok(vec![signed_envelope_from_value(value)?]);
    }

    if value.get("schema").and_then(Value::as_str)
        == Some("flowchain.local_transaction_envelope.v0")
    {
        return Ok(vec![signed_envelope_from_value(&serde_json::json!({
            "envelope": value,
            "document": value.get("payload")
        }))?]);
    }

    let authorization = authorization_from_value(value.get("authorization"))?;
    if value.get("txs").is_some() {
        let txs: Vec<Transaction> =
            serde_json::from_value(value["txs"].clone()).context("failed to parse txs")?;
        return Ok(txs
            .into_iter()
            .map(|tx| {
                let mut envelope = local_authorized_envelope(
                    tx,
                    authorization
                        .as_ref()
                        .map(|authorization| authorization.signer.clone())
                        .or_else(|| authorized_by.clone()),
                );
                if authorization.is_some() {
                    envelope.authorization = authorization.clone();
                }
                parsed_local_envelope(envelope)
            })
            .collect());
    }

    if value.get("tx").is_some() {
        let tx = serde_json::from_value(value["tx"].clone()).context("failed to parse tx")?;
        let mut envelope = local_authorized_envelope(
            tx,
            authorization
                .as_ref()
                .map(|authorization| authorization.signer.clone())
                .or(authorized_by),
        );
        if authorization.is_some() {
            envelope.authorization = authorization;
        }
        return Ok(vec![parsed_local_envelope(envelope)]);
    }

    Err(anyhow!(
        "unsupported transaction file shape: expected envelope, tx, or txs"
    ))
}

fn parsed_local_envelope(envelope: crate::model::TxEnvelope) -> ParsedEnvelope {
    let signer = envelope
        .authorization
        .as_ref()
        .map(|authorization| authorization.signer.clone());
    let nonce = envelope
        .authorization
        .as_ref()
        .and_then(|authorization| authorization.nonce);
    let replay_key = envelope
        .authorization
        .as_ref()
        .and_then(|authorization| authorization.replay_key.clone())
        .or_else(|| {
            let authorization = envelope.authorization.as_ref()?;
            Some(format!(
                "{}:local-authorized:{}:{}",
                authorization.chain_id.clone()?,
                authorization.signer,
                authorization.nonce?
            ))
        });
    ParsedEnvelope {
        envelope,
        signer,
        nonce,
        replay_key,
    }
}

fn tx_ids_from_value(value: &Value, authorized_by: Option<String>) -> Result<Vec<String>> {
    let mut ids = Vec::new();
    for parsed in parsed_envelopes_from_value(value, authorized_by)? {
        ids.push(parsed.envelope.tx_id);
    }
    Ok(ids)
}

fn authorization_from_value(value: Option<&Value>) -> Result<Option<LocalAuthorization>> {
    match value {
        Some(Value::Null) | None => Ok(None),
        Some(value) => serde_json::from_value(value.clone())
            .map(Some)
            .context("failed to parse local authorization"),
    }
}

fn signed_envelope_from_value(value: &Value) -> Result<ParsedEnvelope> {
    let envelope_value = value.get("envelope").unwrap_or(value);
    let payload = envelope_value
        .get("payload")
        .or_else(|| value.get("payload"))
        .or_else(|| value.get("document"))
        .ok_or_else(|| anyhow!("signed transaction envelope must include payload or document"))?;
    let tx_value = payload
        .get("tx")
        .or_else(|| value.get("tx"))
        .ok_or_else(|| anyhow!("signed transaction envelope payload must include tx"))?;
    let tx: Transaction = serde_json::from_value(tx_value.clone())
        .context("failed to parse signed transaction payload tx")?;

    let schema = required_str(envelope_value, "schema")?;
    if schema != "flowchain.local_transaction_envelope.v0" {
        return Err(anyhow!("unsupported signed envelope schema: {schema}"));
    }
    let envelope_id = required_str(envelope_value, "envelopeId")?;
    let chain_id = required_str(envelope_value, "chainId")?;
    let nonce = required_u64(envelope_value, "nonce")?;
    let signer_id = envelope_signer_str(envelope_value, "signerId")?;
    let signer_key_id = envelope_signer_str(envelope_value, "signerKeyId")?;
    let signer_role = envelope_signer_str(envelope_value, "signerRole")?;
    let signer_role_code = envelope_signer_u64(envelope_value, "signerRoleCode")?;
    let public_key = envelope_signer_str(envelope_value, "publicKey")?;
    let domain = required_str(envelope_value, "domain")?;
    let domain_separator = required_str(envelope_value, "domainSeparator")?;
    let payload_hash = required_str(envelope_value, "payloadHash")?;
    let object_id = envelope_value.get("objectId").and_then(Value::as_str);
    let object_type_hash = envelope_value.get("objectTypeHash").and_then(Value::as_str);
    let issued_at_unix_ms = required_u64(envelope_value, "issuedAtUnixMs")?;
    let signing_digest = required_str(envelope_value, "signingDigest")?;
    let signature = required_str(envelope_value, "signature")?;

    let expected_payload_hash = canonical_json_hash(payload);
    if payload_hash != expected_payload_hash {
        return Err(anyhow!("bad-payload-hash"));
    }
    let expected_domain =
        format!("flowchain.local-alpha.v0.local-transaction-envelope:chain:{chain_id}");
    let legacy_domain = "flowchain.local.v0.transaction-envelope".to_string();
    if domain != expected_domain && domain != legacy_domain {
        return Err(anyhow!("wrong-domain"));
    }
    if domain_separator != keccak_hex(domain.as_bytes()) {
        return Err(anyhow!("wrong-domain"));
    }
    let expected_role_code = match signer_role {
        "operator" => 1,
        "agent" => 2,
        "verifier" => 3,
        "hardware" => 4,
        _ => return Err(anyhow!("wrong-signer")),
    };
    if signer_role_code != expected_role_code {
        return Err(anyhow!("wrong-signer"));
    }

    if let (Some(object_id), Some(object_type_hash)) = (object_id, object_type_hash) {
        let expected_envelope_id =
            local_transaction_envelope_hash(LocalTransactionEnvelopeInput {
                chain_id,
                domain_separator,
                signer_id,
                signer_key_id,
                signer_role: signer_role_code,
                nonce,
                payload_hash,
                object_id,
                object_type_hash,
                issued_at_unix_ms,
            })?;
        if envelope_id != expected_envelope_id {
            return Err(anyhow!("bad-envelope-id"));
        }
        let expected_digest = eip712_digest(domain_separator, &expected_envelope_id)?;
        if signing_digest != expected_digest {
            return Err(anyhow!("bad-envelope-digest"));
        }
    }
    if !verify_signature(signing_digest, signature, public_key)? {
        return Err(anyhow!("bad-signature"));
    }

    let replay_key = format!("{chain_id}:{domain}:{signer_id}:{nonce}");
    let authorization = LocalAuthorization {
        mode: "signed-local-transaction-envelope".to_string(),
        signer: signer_id.to_string(),
        digest: signing_digest.to_string(),
        chain_id: Some(chain_id.to_string()),
        nonce: Some(nonce),
        signer_role: Some(signer_role.to_string()),
        signer_key_id: Some(signer_key_id.to_string()),
        public_key: Some(public_key.to_string()),
        signature: Some(signature.to_string()),
        replay_key: Some(replay_key.clone()),
    };
    Ok(ParsedEnvelope {
        envelope: crate::model::TxEnvelope {
            tx_id: envelope_id.to_string(),
            tx,
            authorization: Some(authorization),
            submitted_at_block: 0,
        },
        signer: Some(signer_id.to_string()),
        nonce: Some(nonce),
        replay_key: Some(replay_key),
    })
}

struct LocalTransactionEnvelopeInput<'a> {
    chain_id: &'a str,
    domain_separator: &'a str,
    signer_id: &'a str,
    signer_key_id: &'a str,
    signer_role: u64,
    nonce: u64,
    payload_hash: &'a str,
    object_id: &'a str,
    object_type_hash: &'a str,
    issued_at_unix_ms: u64,
}

fn local_transaction_envelope_hash(input: LocalTransactionEnvelopeInput<'_>) -> Result<String> {
    let mut encoded = Vec::with_capacity(320);
    encoded.extend(hex_32(&keccak_hex(LOCAL_TRANSACTION_TYPE.as_bytes()))?);
    encoded.extend(uint_word(parse_u128(input.chain_id, "chainId")?));
    encoded.extend(hex_32(input.domain_separator)?);
    encoded.extend(hex_32(input.signer_id)?);
    encoded.extend(hex_32(input.signer_key_id)?);
    encoded.extend(uint_word(input.signer_role as u128));
    encoded.extend(uint_word(input.nonce as u128));
    encoded.extend(hex_32(input.payload_hash)?);
    encoded.extend(hex_32(input.object_id)?);
    encoded.extend(hex_32(input.object_type_hash)?);
    encoded.extend(uint_word(input.issued_at_unix_ms as u128));
    Ok(keccak_hex(&encoded))
}

fn eip712_digest(domain_separator: &str, struct_hash: &str) -> Result<String> {
    let mut encoded = Vec::with_capacity(66);
    encoded.extend([0x19, 0x01]);
    encoded.extend(hex_32(domain_separator)?);
    encoded.extend(hex_32(struct_hash)?);
    Ok(keccak_hex(&encoded))
}

fn verify_signature(digest: &str, signature: &str, public_key: &str) -> Result<bool> {
    let digest_bytes = hex_32(digest)?;
    let signature_bytes = hex_bytes(signature, 64)?;
    let public_key_bytes = hex_bytes(public_key, 0)?;
    let verifying_key =
        VerifyingKey::from_sec1_bytes(&public_key_bytes).map_err(|_| anyhow!("bad-public-key"))?;
    let signature =
        Signature::from_slice(&signature_bytes).map_err(|_| anyhow!("bad-signature"))?;
    Ok(verifying_key
        .verify_prehash(&digest_bytes, &signature)
        .is_ok())
}

fn hex_32(value: &str) -> Result<Vec<u8>> {
    hex_bytes(value, 32)
}

fn hex_bytes(value: &str, expected_len: usize) -> Result<Vec<u8>> {
    let stripped = value
        .strip_prefix("0x")
        .ok_or_else(|| anyhow!("hex value must start with 0x"))?;
    let bytes = hex::decode(stripped).map_err(|_| anyhow!("malformed hex"))?;
    if expected_len > 0 && bytes.len() != expected_len {
        return Err(anyhow!("hex value has wrong length"));
    }
    Ok(bytes)
}

fn uint_word(value: u128) -> Vec<u8> {
    let mut word = vec![0_u8; 32];
    word[16..].copy_from_slice(&value.to_be_bytes());
    word
}

fn parse_u128(value: &str, field: &str) -> Result<u128> {
    value
        .parse::<u128>()
        .with_context(|| format!("{field} must be an unsigned integer string"))
}

fn required_str<'a>(value: &'a Value, key: &str) -> Result<&'a str> {
    value
        .get(key)
        .and_then(Value::as_str)
        .ok_or_else(|| anyhow!("missing string field {key}"))
}

fn required_u64(value: &Value, key: &str) -> Result<u64> {
    let raw = value
        .get(key)
        .and_then(|value| value.as_str().or_else(|| value.as_u64().map(|_| "")))
        .ok_or_else(|| anyhow!("missing integer field {key}"))?;
    if raw.is_empty() {
        return value
            .get(key)
            .and_then(Value::as_u64)
            .ok_or_else(|| anyhow!("missing integer field {key}"));
    }
    raw.parse::<u64>()
        .with_context(|| format!("{key} must be an unsigned integer string"))
}

fn envelope_signer_str<'a>(value: &'a Value, key: &str) -> Result<&'a str> {
    value
        .get(key)
        .and_then(Value::as_str)
        .or_else(|| {
            value
                .get("signer")
                .and_then(|signer| signer.get(key))
                .and_then(Value::as_str)
        })
        .ok_or_else(|| anyhow!("missing string field {key}"))
}

fn envelope_signer_u64(value: &Value, key: &str) -> Result<u64> {
    if value.get(key).is_some() {
        return required_u64(value, key);
    }
    let signer = value
        .get("signer")
        .ok_or_else(|| anyhow!("missing signer object"))?;
    required_u64(signer, key)
}

fn preflight_state_with_pending(state: &crate::model::ChainState) -> crate::model::ChainState {
    let mut simulation = state.clone();
    let pending = simulation.pending_txs.clone();
    simulation.pending_txs.clear();
    for envelope in pending {
        let _ = crate::model::apply_transaction(&mut simulation, &envelope.tx);
    }
    simulation
}

fn validate_and_queue_envelope(
    state: &mut crate::model::ChainState,
    simulation: &mut crate::model::ChainState,
    mut parsed: ParsedEnvelope,
    source: Option<PathBuf>,
) -> std::result::Result<String, RejectedTx> {
    parsed.envelope.submitted_at_block = state.next_block_number;
    validate_envelope_for_mempool(state, simulation, &parsed).map_err(|reason| RejectedTx {
        tx_id: Some(parsed.envelope.tx_id.clone()),
        reason,
        source: source.clone(),
    })?;
    let tx_id = parsed.envelope.tx_id.clone();
    if let Some(signer) = parsed.signer.clone()
        && let Some(nonce) = parsed.nonce
    {
        state.account_nonces.insert(
            signer.clone(),
            crate::model::AccountNonce {
                signer,
                next_nonce: nonce + 1,
                last_tx_id: Some(tx_id.clone()),
                updated_at_block: state.next_block_number,
            },
        );
    }
    if let Some(replay_key) = parsed.replay_key.clone()
        && let Some(signer) = parsed.signer.clone()
        && let Some(nonce) = parsed.nonce
    {
        state.replay_keys.insert(
            replay_key.clone(),
            crate::model::ReplayKeyRecord {
                replay_key,
                tx_id: tx_id.clone(),
                signer,
                nonce,
                accepted_at_block: state.next_block_number,
            },
        );
    }
    crate::model::apply_transaction(simulation, &parsed.envelope.tx).map_err(|error| {
        RejectedTx {
            tx_id: Some(tx_id.clone()),
            reason: error.to_string(),
            source,
        }
    })?;
    record_pending_transaction(state, &parsed.envelope);
    state.pending_txs.push(parsed.envelope);
    Ok(tx_id)
}

fn try_queue_envelope(
    state: &mut crate::model::ChainState,
    parsed: ParsedEnvelope,
) -> Result<String> {
    let mut simulation = preflight_state_with_pending(state);
    validate_and_queue_envelope(state, &mut simulation, parsed, None)
        .map_err(|rejected| anyhow!(rejected.reason))
}

fn validate_envelope_for_mempool(
    state: &crate::model::ChainState,
    simulation: &crate::model::ChainState,
    parsed: &ParsedEnvelope,
) -> std::result::Result<(), String> {
    if state.pending_txs.len() >= MAX_MEMPOOL_TXS {
        return Err("mempool-full".to_string());
    }
    if parsed.envelope.tx_id.trim().is_empty() {
        return Err("missing-tx-id".to_string());
    }
    if state
        .pending_txs
        .iter()
        .any(|pending| pending.tx_id == parsed.envelope.tx_id)
        || state.consumed_tx_ids.contains_key(&parsed.envelope.tx_id)
    {
        return Err("duplicate-tx-id".to_string());
    }
    if let Some(authorization) = &parsed.envelope.authorization
        && let Some(chain_id) = &authorization.chain_id
        && chain_id != &state.chain_id
    {
        return Err("wrong-chain-id".to_string());
    }
    if let Some(replay_key) = &parsed.replay_key
        && state.replay_keys.contains_key(replay_key)
    {
        return Err("replay".to_string());
    }
    if let Some(signer) = &parsed.signer
        && let Some(nonce) = parsed.nonce
    {
        let expected = state
            .account_nonces
            .get(signer)
            .map(|record| record.next_nonce)
            .unwrap_or(1);
        if nonce < expected {
            return Err("stale-nonce".to_string());
        }
        if nonce > expected {
            return Err("future-nonce".to_string());
        }
    }
    crate::model::apply_transaction(&mut simulation.clone(), &parsed.envelope.tx)
        .map_err(|error| error.to_string())?;
    Ok(())
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

fn build_product_smoke_state() -> DemoRun {
    let mut state = genesis_state();
    for tx in product_demo_transactions() {
        queue_transaction(&mut state, tx);
    }
    let first = build_block(&mut state);
    let appchain_chain_id = state.chain_id.clone();
    queue_transaction(
        &mut state,
        Transaction::AnchorBatchToBasePlaceholder {
            appchain_chain_id,
            finality_status: "local-product-testnet-placeholder".to_string(),
        },
    );
    let second = build_block(&mut state);

    DemoRun {
        state,
        first_block_hash: first.block_hash,
        second_block_hash: second.block_hash,
    }
}

fn run_node_smoke(
    state_path: &Path,
    _node_dir: &Path,
    out_dir: &Path,
) -> Result<NodeRuntimeSmokeReport> {
    fs::create_dir_all(out_dir)?;
    let mut state = genesis_state();
    let txs = production_runtime_smoke_transactions();
    let mut tx_ids = Vec::with_capacity(txs.len());
    for tx in txs {
        tx_ids.push(queue_authorized_transaction(
            &mut state,
            tx,
            "local-node-smoke-operator".to_string(),
        ));
    }
    let mut block_hashes = Vec::new();
    while state.blocks.len() < 10 {
        block_hashes.push(build_block(&mut state).block_hash);
    }
    save_state(state_path, &state)?;
    write_runtime_boundary_files(state_path, &state)?;
    let restart_state = load_state(state_path)?;
    let snapshot_path = out_dir.join("state-snapshot.json");
    write_json(snapshot_path.clone(), &restart_state)?;
    let imported_state: crate::model::ChainState =
        serde_json::from_str(&fs::read_to_string(&snapshot_path)?)?;
    let report = NodeRuntimeSmokeReport {
        schema: "flowchain.private_testnet.production_node_smoke.v0".to_string(),
        commands_run: vec!["flowmemory-devnet node-smoke".to_string()],
        block_count: restart_state.blocks.len(),
        tx_ids,
        receipt_ids: restart_state.receipts.keys().cloned().collect(),
        state_root: state_root(&restart_state),
        latest_hash: restart_state.latest_hash.clone(),
        restart_proof: RestartProof {
            before_state_root: state_root(&state),
            after_state_root: state_root(&restart_state),
            before_latest_hash: state.latest_hash.clone(),
            after_latest_hash: restart_state.latest_hash.clone(),
            preserved: state_root(&state) == state_root(&restart_state)
                && state.latest_hash == restart_state.latest_hash,
        },
        export_import_proof: ExportImportProof {
            imported_state_root: state_root(&imported_state),
            preserved: state_root(&restart_state) == state_root(&imported_state),
        },
        failure_details: Vec::new(),
        block_hashes,
    };
    write_json(out_dir.join("production-node-smoke-report.json"), &report)?;
    Ok(report)
}

fn production_runtime_smoke_transactions() -> Vec<Transaction> {
    let mut txs = Vec::new();
    txs.extend(demo_transactions());
    txs.extend(product_demo_transactions());

    let token_id = deterministic_token_id("FLOWT");
    let token_transfer_id = hash_json(
        "flowmemory.local_devnet.token_transfer_id.v0",
        &serde_json::json!({
            "tokenId": token_id,
            "from": "local-account:product:alice",
            "to": "local-account:product:bob",
            "amount": 100_u64,
            "memo": "node-smoke-token-transfer"
        }),
    );
    txs.push(Transaction::TransferLocalTestToken {
        transfer_id: token_transfer_id,
        token_id,
        from_account_id: "local-account:product:alice".to_string(),
        to_account_id: "local-account:product:bob".to_string(),
        amount_units: 100,
        memo: "node-smoke-token-transfer".to_string(),
    });

    txs.push(Transaction::CreateLocalTestUnitBalance {
        account_id: "local-account:bridge:bob".to_string(),
        owner: "operator:bridge:bob".to_string(),
    });
    let replay_key = keccak_hex(b"flowchain.node-smoke.bridge.replay-key");
    let credit_id = hash_json(
        "flowmemory.local_devnet.bridge_credit_id.v0",
        &serde_json::json!({
            "replayKey": replay_key,
            "recipient": "local-account:bridge:alice",
            "amount": 75_u64
        }),
    );
    txs.push(Transaction::ApplyBridgeCredit {
        credit_id: credit_id.clone(),
        observation_id: keccak_hex(b"flowchain.node-smoke.bridge.observation"),
        deposit_id: keccak_hex(b"flowchain.node-smoke.bridge.deposit"),
        replay_key: replay_key.clone(),
        source_chain_id: 8453,
        source_contract: "0x1111111111111111111111111111111111111111".to_string(),
        source_tx_hash: keccak_hex(b"flowchain.node-smoke.bridge.source-tx"),
        source_log_index: 0,
        token: "0x3333333333333333333333333333333333333333".to_string(),
        asset_id: LOCAL_TEST_UNIT_ASSET_ID.to_string(),
        recipient_account_id: "local-account:bridge:alice".to_string(),
        amount_units: 75,
        verifier: "bridge-verifier:local-smoke".to_string(),
        evidence_hash: keccak_hex(b"flowchain.node-smoke.bridge.evidence"),
        local_only: true,
        production_ready: false,
        base_observed_at: "2026-05-13T00:00:00.000Z".to_string(),
        handoff_written_at: "2026-05-13T00:00:01.000Z".to_string(),
        node_ingested_at: "2026-05-13T00:00:02.000Z".to_string(),
    });
    txs.push(Transaction::TransferLocalTestUnits {
        transfer_id: "transfer:bridge:alice-to-bob".to_string(),
        from_account_id: "local-account:bridge:alice".to_string(),
        to_account_id: "local-account:bridge:bob".to_string(),
        amount_units: 25,
        memo: "bridge-credit-spend-proof".to_string(),
    });
    txs.push(Transaction::RequestWithdrawal {
        withdrawal_intent_id: keccak_hex(b"flowchain.node-smoke.withdrawal.intent"),
        credit_id,
        account_id: "local-account:bridge:alice".to_string(),
        asset_id: LOCAL_TEST_UNIT_ASSET_ID.to_string(),
        amount_units: 10,
        destination_chain_id: 8453,
        base_recipient: "0x4444444444444444444444444444444444444444".to_string(),
        memo: "test-mode-withdrawal-intent".to_string(),
    });
    txs
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

    if value
        .get("schema")
        .and_then(Value::as_str)
        .is_some_and(|schema| schema == "flowmemory.bridge_runtime_handoff.v0")
    {
        return bridge_handoff_transactions(&value, false)
            .with_context(|| format!("failed to parse bridge handoff {}", path.display()));
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
        "unsupported fixture shape in {}: expected tx, txs, bridge handoff, FlowPulse observation, or verifier report fixture",
        path.display()
    ))
}

fn bridge_handoff_transactions_from_path(
    path: &Path,
    require_live: bool,
) -> Result<Vec<Transaction>> {
    let body = fs::read_to_string(path)
        .with_context(|| format!("failed to read bridge handoff {}", path.display()))?;
    let value: Value = serde_json::from_str(body.trim_start_matches('\u{feff}'))
        .with_context(|| format!("failed to parse bridge handoff {}", path.display()))?;
    bridge_handoff_transactions(&value, require_live)
}

fn bridge_handoff_transactions(value: &Value, require_live: bool) -> Result<Vec<Transaction>> {
    let schema = value
        .get("schema")
        .and_then(Value::as_str)
        .ok_or_else(|| anyhow!("bridge handoff missing schema"))?;
    if schema != "flowmemory.bridge_runtime_handoff.v0" {
        return Err(anyhow!("unsupported bridge handoff schema: {schema}"));
    }
    if require_live {
        require_bool(value, "productionReady", true)?;
        require_bool(value, "localOnly", false)?;
    }

    let credits = value
        .get("credits")
        .and_then(Value::as_array)
        .ok_or_else(|| anyhow!("bridge handoff missing credits array"))?;
    let observations = value
        .get("observations")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let handoff_written_at = string_value_optional(value, "handoffWrittenAt")
        .or_else(|| string_value_optional(value, "generatedAt"))
        .unwrap_or_else(current_rfc3339);
    let mut txs = Vec::new();
    let mut local_accounts = BTreeSet::new();

    for credit in credits {
        let status = credit
            .get("status")
            .and_then(Value::as_str)
            .unwrap_or("pending");
        if status == "rejected" {
            continue;
        }
        if require_live {
            require_bool(credit, "productionReady", true)?;
            require_bool(credit, "localOnly", false)?;
        }

        let source = credit
            .get("source")
            .and_then(Value::as_object)
            .ok_or_else(|| anyhow!("bridge credit missing source object"))?;
        let source_chain_id = value_to_u64(
            source
                .get("chainId")
                .ok_or_else(|| anyhow!("bridge credit source missing chainId"))?,
            "source.chainId",
        )?;
        if require_live && source_chain_id != 8453 {
            return Err(anyhow!(
                "live bridge handoff source chain must be Base 8453, got {source_chain_id}"
            ));
        }
        let observation_id = string_value(credit, "observationId")?;
        if require_live {
            require_confirmation_eligible(&observations, &observation_id)?;
        }
        let flowchain_recipient = string_value(credit, "flowchainRecipient")?;
        let recipient_account_id = string_value_optional(credit, "recipientAccountId")
            .unwrap_or_else(|| deterministic_bridge_account_id(&flowchain_recipient));
        if local_accounts.insert(recipient_account_id.clone()) {
            txs.push(Transaction::CreateLocalTestUnitBalance {
                account_id: recipient_account_id.clone(),
                owner: "operator:bridge:pilot".to_string(),
            });
        }

        let node_ingested_at = current_rfc3339();
        let base_observed_at = string_value_optional(credit, "baseObservedAt")
            .or_else(|| observation_timestamp(&observations, &observation_id))
            .or_else(|| string_value_optional(value, "baseObservedAt"))
            .unwrap_or_else(|| handoff_written_at.clone());
        let source_contract = string_field(source, "contract")?;
        let source_tx_hash = string_field(source, "txHash")?;
        let source_log_index = value_to_u64(
            source
                .get("logIndex")
                .ok_or_else(|| anyhow!("bridge credit source missing logIndex"))?,
            "source.logIndex",
        )?;
        let credit_id = string_value(credit, "creditId")?;
        txs.push(Transaction::ApplyBridgeCredit {
            credit_id: credit_id.clone(),
            observation_id,
            deposit_id: string_value(credit, "depositId")?,
            replay_key: string_value(credit, "replayKey").unwrap_or_else(|_| {
                crate::model::bridge_source_replay_key(
                    source_chain_id,
                    &source_contract,
                    &source_tx_hash,
                    source_log_index,
                )
            }),
            source_chain_id,
            source_contract,
            source_tx_hash,
            source_log_index,
            token: string_value(credit, "token")?,
            asset_id: LOCAL_TEST_UNIT_ASSET_ID.to_string(),
            recipient_account_id,
            amount_units: value_to_u64(
                credit
                    .get("amount")
                    .ok_or_else(|| anyhow!("bridge credit missing amount"))?,
                "amount",
            )?,
            verifier: "bridge-verifier:base8453-live-handoff".to_string(),
            evidence_hash: string_value_optional(credit, "evidenceHash").unwrap_or_else(|| {
                hash_json(
                    "flowmemory.local_devnet.bridge_credit_evidence.v0",
                    &normalize_value(credit.clone()),
                )
            }),
            local_only: bool_field_default(credit, "localOnly", true),
            production_ready: bool_field_default(credit, "productionReady", false),
            base_observed_at,
            handoff_written_at: string_value_optional(credit, "handoffWrittenAt")
                .unwrap_or_else(|| handoff_written_at.clone()),
            node_ingested_at,
        });
    }

    Ok(txs)
}

fn deterministic_bridge_account_id(flowchain_recipient: &str) -> String {
    format!(
        "local-account:bridge:{}",
        hash_json(
            "flowmemory.local_devnet.bridge_account_id.v0",
            &serde_json::json!({ "flowchainRecipient": flowchain_recipient })
        )
        .trim_start_matches("0x")
    )
}

fn bridge_credit_id_from_tx(tx: &Transaction) -> Option<String> {
    match tx {
        Transaction::ApplyBridgeCredit { credit_id, .. } => Some(credit_id.clone()),
        _ => None,
    }
}

fn current_rfc3339() -> String {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_secs().to_string())
        .unwrap_or_else(|_| "0".to_string())
}

fn string_value(value: &Value, key: &str) -> Result<String> {
    value
        .get(key)
        .and_then(Value::as_str)
        .map(ToOwned::to_owned)
        .ok_or_else(|| anyhow!("missing string field {key}"))
}

fn string_value_optional(value: &Value, key: &str) -> Option<String> {
    value
        .get(key)
        .and_then(Value::as_str)
        .map(ToOwned::to_owned)
}

fn value_to_u64(value: &Value, label: &str) -> Result<u64> {
    match value {
        Value::String(value) => value
            .parse::<u64>()
            .with_context(|| format!("{label} must be an unsigned integer string")),
        Value::Number(value) => value
            .as_u64()
            .ok_or_else(|| anyhow!("{label} must be a non-negative integer")),
        _ => Err(anyhow!("{label} must be a string or number")),
    }
}

fn bool_field_default(value: &Value, key: &str, default: bool) -> bool {
    value.get(key).and_then(Value::as_bool).unwrap_or(default)
}

fn require_bool(value: &Value, key: &str, expected: bool) -> Result<()> {
    let actual = value
        .get(key)
        .and_then(Value::as_bool)
        .ok_or_else(|| anyhow!("live bridge handoff missing boolean field {key}"))?;
    if actual != expected {
        return Err(anyhow!(
            "live bridge handoff field {key} must be {expected}, got {actual}"
        ));
    }
    Ok(())
}

fn observation_timestamp(observations: &[Value], observation_id: &str) -> Option<String> {
    observations
        .iter()
        .find(|observation| {
            observation
                .get("observationId")
                .and_then(Value::as_str)
                .is_some_and(|id| id == observation_id)
        })
        .and_then(|observation| observation.get("observedAt"))
        .and_then(Value::as_str)
        .map(ToOwned::to_owned)
}

fn require_confirmation_eligible(observations: &[Value], observation_id: &str) -> Result<()> {
    let Some(observation) = observations.iter().find(|observation| {
        observation
            .get("observationId")
            .and_then(Value::as_str)
            .is_some_and(|id| id == observation_id)
    }) else {
        return Err(anyhow!(
            "live bridge handoff missing observation {observation_id}"
        ));
    };
    let confirmation = observation
        .get("guardrails")
        .and_then(|guardrails| guardrails.get("confirmation"))
        .ok_or_else(|| anyhow!("live bridge handoff missing confirmation evidence"))?;
    let depth = confirmation
        .get("depth")
        .and_then(Value::as_u64)
        .ok_or_else(|| anyhow!("live bridge handoff confirmation depth is missing"))?;
    let satisfied = confirmation
        .get("satisfied")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    if depth < 12 || !satisfied {
        return Err(anyhow!(
            "live bridge handoff is not 12-confirmation eligible: depth={depth}, satisfied={satisfied}"
        ));
    }
    Ok(())
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
        "latestHash": state.latest_hash,
        "finalizedHeight": state.finalized_height,
        "rootfields": state.rootfields,
        "accountNonces": state.account_nonces,
        "agentAccounts": state.agent_accounts,
        "localTestUnitBalances": state.local_test_unit_balances,
        "faucetRecords": state.faucet_records,
        "balanceTransfers": state.balance_transfers,
        "tokenDefinitions": state.token_definitions,
        "tokenBalances": state.token_balances,
        "tokenMintReceipts": state.token_mint_receipts,
        "tokenTransferReceipts": state.token_transfer_receipts,
        "dexPools": state.dex_pools,
        "lpPositions": state.lp_positions,
        "liquidityReceipts": state.liquidity_receipts,
        "swapReceipts": state.swap_receipts,
        "modelPassports": state.model_passports,
        "memoryCells": state.memory_cells,
        "challenges": state.challenges,
        "finalityReceipts": state.finality_receipts,
        "artifactCommitments": state.artifact_commitments,
        "artifactAvailabilityProofs": state.artifact_availability_proofs,
        "verifierModules": state.verifier_modules,
        "workReceipts": state.work_receipts,
        "verifierReports": state.verifier_reports,
        "bridgeObservations": state.bridge_observations,
        "bridgeCredits": state.bridge_credits,
        "bridgeCreditReceipts": state.bridge_credit_receipts,
        "bridgeReplayKeys": state.bridge_replay_keys,
        "withdrawalIntents": state.withdrawal_intents,
        "transactions": state.transactions,
        "receipts": state.receipts,
        "events": state.events,
        "baseAnchors": state.base_anchors,
    });

    let indexer = serde_json::json!({
        "schema": "flowmemory.indexer_handoff.local_devnet.v0",
        "genesisConfig": state.config,
        "importedObservations": state.imported_observations,
        "operatorKeyReferences": state.operator_key_references,
        "accountNonces": state.account_nonces,
        "agentAccounts": state.agent_accounts,
        "localTestUnitBalances": state.local_test_unit_balances,
        "faucetRecords": state.faucet_records,
        "balanceTransfers": state.balance_transfers,
        "tokenDefinitions": state.token_definitions,
        "tokenBalances": state.token_balances,
        "tokenMintReceipts": state.token_mint_receipts,
        "tokenTransferReceipts": state.token_transfer_receipts,
        "dexPools": state.dex_pools,
        "lpPositions": state.lp_positions,
        "liquidityReceipts": state.liquidity_receipts,
        "swapReceipts": state.swap_receipts,
        "memoryCells": state.memory_cells,
        "challenges": state.challenges,
        "finalityReceipts": state.finality_receipts,
        "artifactAvailabilityProofs": state.artifact_availability_proofs,
        "bridgeObservations": state.bridge_observations,
        "bridgeCredits": state.bridge_credits,
        "bridgeCreditReceipts": state.bridge_credit_receipts,
        "bridgeReplayKeys": state.bridge_replay_keys,
        "withdrawalIntents": state.withdrawal_intents,
        "transactions": state.transactions,
        "receipts": state.receipts,
        "events": state.events,
        "blocks": state.blocks,
        "mapRoots": state_map_roots(state),
        "stateRoot": state_root(state),
    });

    let verifier = serde_json::json!({
        "schema": "flowmemory.verifier_handoff.local_devnet.v0",
        "genesisConfig": state.config,
        "operatorKeyReferences": state.operator_key_references,
        "accountNonces": state.account_nonces,
        "localTestUnitBalances": state.local_test_unit_balances,
        "faucetRecords": state.faucet_records,
        "balanceTransfers": state.balance_transfers,
        "tokenDefinitions": state.token_definitions,
        "tokenBalances": state.token_balances,
        "tokenMintReceipts": state.token_mint_receipts,
        "tokenTransferReceipts": state.token_transfer_receipts,
        "dexPools": state.dex_pools,
        "lpPositions": state.lp_positions,
        "liquidityReceipts": state.liquidity_receipts,
        "swapReceipts": state.swap_receipts,
        "verifierModules": state.verifier_modules,
        "workReceipts": state.work_receipts,
        "verifierReports": state.verifier_reports,
        "challenges": state.challenges,
        "finalityReceipts": state.finality_receipts,
        "artifactAvailabilityProofs": state.artifact_availability_proofs,
        "importedVerifierReports": state.imported_verifier_reports,
        "bridgeObservations": state.bridge_observations,
        "bridgeCredits": state.bridge_credits,
        "bridgeCreditReceipts": state.bridge_credit_receipts,
        "bridgeReplayKeys": state.bridge_replay_keys,
        "withdrawalIntents": state.withdrawal_intents,
        "transactions": state.transactions,
        "receipts": state.receipts,
        "events": state.events,
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
        "latestHeight": state.latest_height,
        "latestHash": state.latest_hash,
        "finalizedHeight": state.finalized_height,
        "latestBlock": state.blocks.last(),
        "blocks": state.blocks,
        "pendingTxs": state.pending_txs,
        "transactions": state.transactions,
        "receipts": state.receipts,
        "events": state.events,
        "objects": {
            "rootfields": state.rootfields,
            "accountNonces": state.account_nonces,
            "agentAccounts": state.agent_accounts,
            "localTestUnitBalances": state.local_test_unit_balances,
            "faucetRecords": state.faucet_records,
            "balanceTransfers": state.balance_transfers,
            "tokenDefinitions": state.token_definitions,
            "tokenBalances": state.token_balances,
            "tokenMintReceipts": state.token_mint_receipts,
            "tokenTransferReceipts": state.token_transfer_receipts,
            "dexPools": state.dex_pools,
            "lpPositions": state.lp_positions,
            "liquidityReceipts": state.liquidity_receipts,
            "swapReceipts": state.swap_receipts,
            "modelPassports": state.model_passports,
            "memoryCells": state.memory_cells,
            "challenges": state.challenges,
            "finalityReceipts": state.finality_receipts,
            "artifactCommitments": state.artifact_commitments,
            "artifactAvailabilityProofs": state.artifact_availability_proofs,
            "verifierModules": state.verifier_modules,
            "workReceipts": state.work_receipts,
            "verifierReports": state.verifier_reports,
            "bridgeObservations": state.bridge_observations,
            "bridgeCredits": state.bridge_credits,
            "bridgeCreditReceipts": state.bridge_credit_receipts,
            "bridgeReplayKeys": state.bridge_replay_keys,
            "withdrawalIntents": state.withdrawal_intents,
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
    write_json(
        out_dir.join("runtime-handoff.json"),
        &serde_json::json!({
            "schema": "flowmemory.local_devnet.runtime_handoff.v0",
            "chainId": state.chain_id,
            "latestHeight": state.latest_height,
            "latestHash": state.latest_hash,
            "finalizedHeight": state.finalized_height,
            "stateRoot": state_root(state),
            "mapRoots": state_map_roots(state),
            "mempool": {
                "pending": state.pending_txs.len(),
                "maxSize": MAX_MEMPOOL_TXS,
                "pendingTxs": state.pending_txs
            },
            "transactions": state.transactions,
            "receipts": state.receipts,
            "events": state.events,
            "bridgeCredits": state.bridge_credits,
            "bridgeCreditReceipts": state.bridge_credit_receipts,
            "withdrawalIntents": state.withdrawal_intents,
            "controlPlanePreferredHandoff": out_dir.join("handoff").join("control-plane-handoff.json"),
            "dashboardPreferredHandoff": out_dir.join("handoff").join("dashboard-state.json")
        }),
    )?;
    export_handoff(state, &out_dir.join("handoff"))?;
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

#[derive(Debug, Default, Serialize)]
#[serde(rename_all = "camelCase")]
struct QueuedTransactions {
    queued: Vec<String>,
    rejected: Vec<RejectedTx>,
}

impl QueuedTransactions {
    fn accepted_only(queued: Vec<String>) -> Self {
        Self {
            queued,
            rejected: Vec::new(),
        }
    }
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct BridgeIngestSummary {
    schema: String,
    handoff: PathBuf,
    direct: bool,
    require_live: bool,
    credit_ids: Vec<String>,
    queued: QueuedTransactions,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct MempoolSummary {
    schema: String,
    max_size: usize,
    pending: usize,
    pending_txs: Vec<crate::model::TxEnvelope>,
}

impl MempoolSummary {
    fn from_state(state: &crate::model::ChainState) -> Self {
        Self {
            schema: "flowmemory.local_devnet.mempool.v0".to_string(),
            max_size: MAX_MEMPOOL_TXS,
            pending: state.pending_txs.len(),
            pending_txs: state.pending_txs.clone(),
        }
    }
}

fn query_state(state: &crate::model::ChainState, kind: QueryKind, id: &str) -> Result<Value> {
    let value = match kind {
        QueryKind::Block => {
            let block = if let Ok(height) = id.parse::<u64>() {
                state
                    .blocks
                    .iter()
                    .find(|block| block.block_number == height)
            } else {
                state.blocks.iter().find(|block| block.block_hash == id)
            };
            serde_json::json!({
                "schema": "flowmemory.local_devnet.query.block.v0",
                "id": id,
                "block": block
            })
        }
        QueryKind::Transaction => serde_json::json!({
            "schema": "flowmemory.local_devnet.query.transaction.v0",
            "id": id,
            "transaction": state.transactions.get(id),
            "pending": state.pending_txs.iter().find(|tx| tx.tx_id == id)
        }),
        QueryKind::Receipt => serde_json::json!({
            "schema": "flowmemory.local_devnet.query.receipt.v0",
            "id": id,
            "receipt": state.receipts.get(id)
        }),
        QueryKind::Account => {
            let token_balances = state
                .token_balances
                .values()
                .filter(|balance| balance.account_id == id)
                .collect::<Vec<_>>();
            serde_json::json!({
                "schema": "flowmemory.local_devnet.query.account.v0",
                "id": id,
                "localTestUnitBalance": state.local_test_unit_balances.get(id),
                "agentAccount": state.agent_accounts.get(id),
                "tokenBalances": token_balances,
                "nonce": state.account_nonces.get(id)
            })
        }
        QueryKind::Token => serde_json::json!({
            "schema": "flowmemory.local_devnet.query.token.v0",
            "id": id,
            "token": state.token_definitions.get(id),
            "balances": state.token_balances.values().filter(|balance| balance.token_id == id).collect::<Vec<_>>()
        }),
        QueryKind::Pool => serde_json::json!({
            "schema": "flowmemory.local_devnet.query.pool.v0",
            "id": id,
            "pool": state.dex_pools.get(id),
            "lpPositions": state.lp_positions.values().filter(|position| position.pool_id == id).collect::<Vec<_>>(),
            "liquidityReceipts": state.liquidity_receipts.values().filter(|receipt| receipt.pool_id == id).collect::<Vec<_>>(),
            "swapReceipts": state.swap_receipts.values().filter(|receipt| receipt.pool_id == id).collect::<Vec<_>>()
        }),
        QueryKind::BridgeCredit => serde_json::json!({
            "schema": "flowmemory.local_devnet.query.bridge_credit.v0",
            "id": id,
            "credit": state.bridge_credits.get(id),
            "receipt": state.bridge_credit_receipts.get(id),
            "replayKey": state.bridge_credits.get(id).and_then(|credit| state.bridge_replay_keys.get(&credit.replay_key))
        }),
        QueryKind::FinalityReceipt => serde_json::json!({
            "schema": "flowmemory.local_devnet.query.finality_receipt.v0",
            "id": id,
            "finalityReceipt": state.finality_receipts.get(id)
        }),
    };
    Ok(value)
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
    latest_height: u64,
    next_block_number: u64,
    latest_block_hash: String,
    finalized_height: u64,
    state_root: String,
    receipt_root: String,
    event_root: String,
    pending_txs: usize,
    max_mempool_txs: usize,
    account_nonces: usize,
    consumed_txs: usize,
    local_test_unit_balances: usize,
    faucet_records: usize,
    balance_transfers: usize,
    token_definitions: usize,
    token_balances: usize,
    token_mint_receipts: usize,
    token_transfer_receipts: usize,
    dex_pools: usize,
    lp_positions: usize,
    liquidity_receipts: usize,
    swap_receipts: usize,
    bridge_observations: usize,
    bridge_credits: usize,
    bridge_credit_receipts: usize,
    bridge_replay_keys: usize,
    withdrawal_intents: usize,
    receipts: usize,
    events: usize,
    log_path: PathBuf,
    last_error: Option<String>,
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
            latest_height: state.latest_height,
            next_block_number: state.next_block_number,
            latest_block_hash: state
                .blocks
                .last()
                .map(|block| block.block_hash.clone())
                .unwrap_or_else(|| state.parent_hash.clone()),
            finalized_height: state.finalized_height,
            state_root: state_root(state),
            receipt_root: state_map_roots(state).receipt_root,
            event_root: state_map_roots(state).event_root,
            pending_txs: state.pending_txs.len(),
            max_mempool_txs: MAX_MEMPOOL_TXS,
            account_nonces: state.account_nonces.len(),
            consumed_txs: state.consumed_tx_ids.len(),
            local_test_unit_balances: state.local_test_unit_balances.len(),
            faucet_records: state.faucet_records.len(),
            balance_transfers: state.balance_transfers.len(),
            token_definitions: state.token_definitions.len(),
            token_balances: state.token_balances.len(),
            token_mint_receipts: state.token_mint_receipts.len(),
            token_transfer_receipts: state.token_transfer_receipts.len(),
            dex_pools: state.dex_pools.len(),
            lp_positions: state.lp_positions.len(),
            liquidity_receipts: state.liquidity_receipts.len(),
            swap_receipts: state.swap_receipts.len(),
            bridge_observations: state.bridge_observations.len(),
            bridge_credits: state.bridge_credits.len(),
            bridge_credit_receipts: state.bridge_credit_receipts.len(),
            bridge_replay_keys: state.bridge_replay_keys.len(),
            withdrawal_intents: state.withdrawal_intents.len(),
            receipts: state.receipts.len(),
            events: state.events.len(),
            log_path: node_dir.join("node.log.jsonl"),
            last_error: None,
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
    latest_height: u64,
    next_block_number: u64,
    logical_time: u64,
    parent_hash: String,
    latest_hash: String,
    finalized_height: u64,
    state_root: String,
    map_roots: crate::model::StateMapRoots,
    operator_key_references: usize,
    account_nonces: usize,
    consumed_txs: usize,
    replay_keys: usize,
    pending_txs: usize,
    blocks: usize,
    rootfields: usize,
    agent_accounts: usize,
    local_balances: usize,
    local_test_unit_balances: usize,
    faucet_records: usize,
    balance_transfers: usize,
    token_definitions: usize,
    token_balances: usize,
    token_mint_receipts: usize,
    token_transfer_receipts: usize,
    dex_pools: usize,
    lp_positions: usize,
    liquidity_receipts: usize,
    swap_receipts: usize,
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
    bridge_observations: usize,
    bridge_credits: usize,
    bridge_credit_receipts: usize,
    bridge_replay_keys: usize,
    withdrawal_intents: usize,
    base_anchors: usize,
    transactions: usize,
    receipts: usize,
    events: usize,
}

impl StateSummary {
    fn from_state(state: &crate::model::ChainState) -> Self {
        Self {
            schema: "flowmemory.local_devnet.summary.v0".to_string(),
            chain_id: state.chain_id.clone(),
            latest_height: state.latest_height,
            next_block_number: state.next_block_number,
            logical_time: state.logical_time,
            parent_hash: state.parent_hash.clone(),
            latest_hash: state.latest_hash.clone(),
            finalized_height: state.finalized_height,
            state_root: state_root(state),
            map_roots: state_map_roots(state),
            operator_key_references: state.operator_key_references.len(),
            account_nonces: state.account_nonces.len(),
            consumed_txs: state.consumed_tx_ids.len(),
            replay_keys: state.replay_keys.len(),
            pending_txs: state.pending_txs.len(),
            blocks: state.blocks.len(),
            rootfields: state.rootfields.len(),
            agent_accounts: state.agent_accounts.len(),
            local_balances: state.local_test_unit_balances.len(),
            local_test_unit_balances: state.local_test_unit_balances.len(),
            faucet_records: state.faucet_records.len(),
            balance_transfers: state.balance_transfers.len(),
            token_definitions: state.token_definitions.len(),
            token_balances: state.token_balances.len(),
            token_mint_receipts: state.token_mint_receipts.len(),
            token_transfer_receipts: state.token_transfer_receipts.len(),
            dex_pools: state.dex_pools.len(),
            lp_positions: state.lp_positions.len(),
            liquidity_receipts: state.liquidity_receipts.len(),
            swap_receipts: state.swap_receipts.len(),
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
            bridge_observations: state.bridge_observations.len(),
            bridge_credits: state.bridge_credits.len(),
            bridge_credit_receipts: state.bridge_credit_receipts.len(),
            bridge_replay_keys: state.bridge_replay_keys.len(),
            withdrawal_intents: state.withdrawal_intents.len(),
            base_anchors: state.base_anchors.len(),
            transactions: state.transactions.len(),
            receipts: state.receipts.len(),
            events: state.events.len(),
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

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ProductSmokeSummary {
    schema: String,
    state_path: PathBuf,
    out_dir: PathBuf,
    state_root: String,
    block_height: usize,
    latest_block_hash: String,
    deterministic_replay: bool,
    checks: ProductSmokeChecks,
    handoff_files: Vec<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ProductSmokeChecks {
    local_accounts_funded: bool,
    token_launched: bool,
    initial_supply_assigned: bool,
    pool_created: bool,
    liquidity_added: bool,
    swap_executed: bool,
    liquidity_removed: bool,
    product_receipts_queryable: bool,
    no_value_boundary: bool,
    base_anchor_created: bool,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct NodeRuntimeSmokeReport {
    schema: String,
    commands_run: Vec<String>,
    block_count: usize,
    tx_ids: Vec<String>,
    receipt_ids: Vec<String>,
    state_root: String,
    latest_hash: String,
    restart_proof: RestartProof,
    export_import_proof: ExportImportProof,
    failure_details: Vec<String>,
    block_hashes: Vec<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct RestartProof {
    before_state_root: String,
    after_state_root: String,
    before_latest_hash: String,
    after_latest_hash: String,
    preserved: bool,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ExportImportProof {
    imported_state_root: String,
    preserved: bool,
}

impl ProductSmokeSummary {
    fn from_demo(
        state_path: PathBuf,
        out_dir: PathBuf,
        demo: &DemoRun,
        deterministic_replay: bool,
    ) -> Self {
        let token_id = crate::model::deterministic_token_id("FLOWT");
        let pool_id =
            crate::model::deterministic_pool_id(crate::model::LOCAL_TEST_UNIT_ASSET_ID, &token_id);
        let lp_position_id =
            crate::model::deterministic_lp_position_id(&pool_id, "local-account:product:alice");
        let token_balance_id =
            crate::model::deterministic_token_balance_id(&token_id, "local-account:product:alice");
        let bob_token_balance_id =
            crate::model::deterministic_token_balance_id(&token_id, "local-account:product:bob");
        let alice_funded = demo
            .state
            .local_test_unit_balances
            .get("local-account:product:alice")
            .is_some_and(|balance| balance.units > 0);
        let bob_funded = demo
            .state
            .local_test_unit_balances
            .get("local-account:product:bob")
            .is_some_and(|balance| balance.units > 0);
        let pool_created = demo
            .state
            .dex_pools
            .get(&pool_id)
            .is_some_and(|pool| pool.reserve_base_units > 0 && pool.reserve_quote_units > 0);
        let liquidity_added = demo
            .state
            .lp_positions
            .get(&lp_position_id)
            .is_some_and(|position| position.base_units_deposited > 0);
        let liquidity_removed = demo
            .state
            .lp_positions
            .get(&lp_position_id)
            .is_some_and(|position| position.base_units_withdrawn > 0);

        Self {
            schema: "flowmemory.local_devnet.product_smoke_summary.v0".to_string(),
            state_path,
            out_dir,
            state_root: state_root(&demo.state),
            block_height: demo.state.blocks.len(),
            latest_block_hash: demo.state.parent_hash.clone(),
            deterministic_replay,
            checks: ProductSmokeChecks {
                local_accounts_funded: alice_funded && bob_funded,
                token_launched: demo.state.token_definitions.contains_key(&token_id),
                initial_supply_assigned: demo
                    .state
                    .token_balances
                    .get(&token_balance_id)
                    .is_some_and(|balance| balance.units > 0),
                pool_created,
                liquidity_added,
                swap_executed: demo
                    .state
                    .swap_receipts
                    .values()
                    .any(|receipt| receipt.pool_id == pool_id)
                    && demo
                        .state
                        .token_balances
                        .get(&bob_token_balance_id)
                        .is_some_and(|balance| balance.units > 0),
                liquidity_removed,
                product_receipts_queryable: !demo.state.token_mint_receipts.is_empty()
                    && !demo.state.liquidity_receipts.is_empty()
                    && !demo.state.swap_receipts.is_empty(),
                no_value_boundary: demo.state.config.no_value
                    && demo
                        .state
                        .token_definitions
                        .values()
                        .all(|token| token.no_value)
                    && demo.state.dex_pools.values().all(|pool| pool.no_value),
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
