import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { once } from "node:events";
import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { canonicalJson } from "../../shared/src/index.ts";
import {
  bridgeSourceEventReplayKey,
  flowchainBridgeObservationId,
} from "../../../crypto/src/production-l1.js";
import {
  dispatchJsonRpc,
  loadControlPlaneState,
  repoRoot,
  type JsonObject,
  type RpcErrorResponse,
  type RpcSuccessResponse,
} from "../src/index.ts";
import { spawnCargoSync } from "../src/cargo.ts";
import { startControlPlaneServer } from "../src/server.ts";
import { runControlPlaneSmoke } from "../src/smoke.ts";

const EXPECTED_CHAIN_CAPABILITIES = [
  "health_reads",
  "rpc_discovery_reads",
  "rpc_readiness_reads",
  "node_status_reads",
  "peer_reads",
  "local_runtime_status_reads",
  "block_reads",
  "transaction_reads",
  "local_transaction_file_intake",
  "mempool_reads",
  "account_reads",
  "balance_reads",
  "faucet_event_reads",
  "wallet_public_metadata_reads",
  "token_reads",
  "token_balance_reads",
  "token_transfer_reads",
  "dex_pool_reads",
  "lp_position_reads",
  "swap_reads",
  "product_flow_status_reads",
  "receipt_lookup",
  "verifier_report_lookup",
  "memory_lineage_lookup",
  "artifact_fixture_lookup",
  "bridge_observation_file_intake",
  "bridge_deposit_reads",
  "bridge_credit_reads",
  "withdrawal_reads",
  "bridge_live_readiness_reads",
  "bridge_lifecycle_exact_value_reads",
  "wallet_balance_reads",
  "wallet_transfer_history_reads",
  "real_value_pilot_reads",
  "real_value_pilot_operator_steps",
  "agent_bond_runtime_reads",
  "agent_bond_public_launch_status_reads",
  "base_agent_memory_runtime_reads",
  "public_agent_network_launch_reads",
  "public_swarm_network_reads",
  "devnet_handoff_reads",
  "no_secret_response_checks",
  "raw_json_reads",
  "explorer_search",
] as const;
const productionL1Vectors = JSON.parse(
  readFileSync(new URL("../../../crypto/fixtures/production-l1-vectors.json", import.meta.url), "utf8"),
) as JsonObject;

function productionSignedEnvelope(name = "wallet-transfer"): JsonObject {
  const positive = (productionL1Vectors.positive as JsonObject[]).find((entry) => entry.name === name);
  assert.ok(positive, `missing production-L1 vector: ${name}`);
  return {
    document: positive.document,
    envelope: positive.envelope,
  };
}

function bridgeObservationFromDeposit(deposit: JsonObject, mode = "base-mainnet-pilot"): JsonObject {
  return {
    schema: "flowmemory.bridge_deposit_observation.v0",
    observationId: flowchainBridgeObservationId({
      sourceChainId: deposit.sourceChainId,
      lockbox: deposit.sourceContract,
      token: deposit.token,
      depositor: deposit.sender,
      recipient: deposit.flowchainRecipient,
      amount: deposit.amount,
      txHash: deposit.txHash,
      logIndex: deposit.logIndex,
      blockNumber: deposit.sourceBlockNumber ?? "0",
      eventNonce: deposit.nonce ?? "0",
    }),
    replayKey: bridgeSourceEventReplayKey({
      sourceChainId: deposit.sourceChainId,
      lockbox: deposit.sourceContract,
      txHash: deposit.txHash,
      logIndex: deposit.logIndex,
    }),
    observedAt: "2026-05-13T00:00:00.000Z",
    mode,
    productionReady: false,
    deposit,
    guardrails: {
      explicitChainId: true,
      explicitContract: true,
      explicitBlockRange: true,
      noSecrets: true,
      approvedContract: true,
    },
  };
}

test("dispatches JSON-RPC methods against local fixture state", () => {
  const response = dispatchJsonRpc({ jsonrpc: "2.0", id: "status", method: "chain_status" }) as RpcSuccessResponse;

  assert.equal(response.jsonrpc, "2.0");
  assert.equal(response.id, "status");
  assert.equal(response.result.schema, "flowmemory.control_plane.chain_status.v0");
  assert.equal(response.result.localOnly, true);
});

test("exposes agent bond runtime and readiness methods", () => {
  const state = loadControlPlaneState();
  state.agentBondReadinessReport = { ok: true };
  state.agentBondReplayReport = { match: true };
  state.agentBondEconomicReport = { scenarios: [{ name: "fixture" }] };
  const list = dispatchJsonRpc({ jsonrpc: "2.0", id: "agent-bond-list", method: "agent_bond_task_list" }, { state }) as RpcSuccessResponse;
  const row = ((list.result as JsonObject).tasks as JsonObject[])[0];
  const task = dispatchJsonRpc(
    { jsonrpc: "2.0", id: "agent-bond-task", method: "agent_bond_task_get", params: { taskId: row.taskId } },
    { state },
  ) as RpcSuccessResponse;
  const readiness = dispatchJsonRpc({ jsonrpc: "2.0", id: "agent-bond-readiness", method: "agent_bond_readiness_get" }, { state }) as RpcSuccessResponse;
  const replay = dispatchJsonRpc({ jsonrpc: "2.0", id: "agent-bond-replay", method: "agent_bond_replay_report_get" }, { state }) as RpcSuccessResponse;
  const economics = dispatchJsonRpc({ jsonrpc: "2.0", id: "agent-bond-economics", method: "agent_bond_economic_report_get" }, { state }) as RpcSuccessResponse;
  const publicLaunchStatus = dispatchJsonRpc({ jsonrpc: "2.0", id: "agent-bond-launch-status", method: "agent_bond_public_launch_status_get" }, { state }) as RpcSuccessResponse;

  assert.equal((list.result as JsonObject).schema, "flowmemory.control_plane.agent_bond_task_list.v1");
  assert.equal((list.result as JsonObject).count, 1);
  assert.equal(row.status, "settled");
  assert.equal(row.readinessOk, true);
  assert.equal(row.replayMatch, true);
  assert.equal((task.result as JsonObject).schema, "flowmemory.control_plane.agent_bond_task.v1");
  assert.equal((((task.result as JsonObject).fixture as JsonObject).schema), "flowmemory.agent_bonds.fixture.v1");
  assert.equal((readiness.result as JsonObject).schema, "flowmemory.control_plane.agent_bond_readiness.v1");
  assert.equal((((readiness.result as JsonObject).readinessReport as JsonObject).ok), true);
  assert.equal((replay.result as JsonObject).schema, "flowmemory.control_plane.agent_bond_replay_report.v1");
  assert.equal((((replay.result as JsonObject).report as JsonObject).match), true);
  assert.equal((economics.result as JsonObject).schema, "flowmemory.control_plane.agent_bond_economic_report.v1");
  assert.equal(Array.isArray(((economics.result as JsonObject).report as JsonObject).scenarios), true);
  assert.equal((publicLaunchStatus.result as JsonObject).schema, "flowmemory.control_plane.agent_bond_public_launch_status.v1");
  assert.equal((publicLaunchStatus.result as JsonObject).status, "blocked");
  assert.ok(Array.isArray((publicLaunchStatus.result as JsonObject).blockers));
});

test("returns stable invalid params errors for missing required params", () => {
  const response = dispatchJsonRpc({ jsonrpc: "2.0", id: 1, method: "rootfield_get" }) as RpcErrorResponse;

  assert.equal(response.error.code, -32602);
  assert.equal(response.error.data.reasonCode, "params.invalid");
  assert.equal(response.error.data.localOnly, true);
});

test("returns standard unknown method errors", () => {
  const response = dispatchJsonRpc({ jsonrpc: "2.0", id: 1, method: "flow_sendTransaction" }) as RpcErrorResponse;

  assert.equal(response.error.code, -32601);
  assert.equal(response.error.data.reasonCode, "method.not_found");
});

test("validates malformed requests and bad params with stable codes", () => {
  const invalidRequest = dispatchJsonRpc({ jsonrpc: "2.0", id: 1 }) as RpcErrorResponse;
  const badLimit = dispatchJsonRpc({ jsonrpc: "2.0", id: 2, method: "receipt_list", params: { limit: 0 } }) as RpcErrorResponse;
  const badRawSource = dispatchJsonRpc({ jsonrpc: "2.0", id: 3, method: "raw_json_get", params: { source: "E:/secrets" } }) as RpcErrorResponse;

  assert.equal(invalidRequest.error.code, -32600);
  assert.equal(invalidRequest.error.data.reasonCode, "request.invalid");
  assert.equal(badLimit.error.code, -32602);
  assert.equal(badLimit.error.data.reasonCode, "params.invalid");
  assert.equal(badRawSource.error.code, -32602);
  assert.equal(badRawSource.error.data.reasonCode, "params.invalid");
});

test("keeps deterministic chain status response snapshots", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-snapshot-"));
  const state = loadControlPlaneState({
    localDevnetPath: join(dir, "missing-local-state.json"),
    localDevnetLaunchPath: join(dir, "missing-local-launch-state.json"),
    txIntakePath: join(dir, "transactions.ndjson"),
    bridgeObservationIntakePath: join(dir, "bridge-observations.ndjson"),
  });
  const first = dispatchJsonRpc({ jsonrpc: "2.0", id: 1, method: "chain_status" }, { state }) as RpcSuccessResponse;
  const second = dispatchJsonRpc({ jsonrpc: "2.0", id: 2, method: "chain_status" }, { state }) as RpcSuccessResponse;
  const snapshot = (response: RpcSuccessResponse) => {
    const result = response.result;
    return canonicalJson({
      schema: result.schema,
      chainId: result.chainId,
      counts: result.counts,
      capabilities: result.capabilities,
    });
  };

  assert.equal(snapshot(first), snapshot(second));
  assert.deepEqual((first.result as JsonObject).capabilities, EXPECTED_CHAIN_CAPABILITIES);
  assert.equal(((first.result as JsonObject).counts as JsonObject).pilotStatus, 1);
  assert.equal(typeof ((first.result as JsonObject).counts as JsonObject).bridgeDeposits, "number");
  assert.equal(typeof ((first.result as JsonObject).counts as JsonObject).withdrawals, "number");
  rmSync(dir, { recursive: true, force: true });
});

test("reports the active local runtime block before fixture/indexer blocks", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-runtime-block-"));
  try {
    const localDevnetPath = join(dir, "state.json");
    writeFileSync(localDevnetPath, JSON.stringify({
      schema: "flowmemory.local_devnet.state.v0",
      chainId: "flowmemory-local-devnet-v0",
      blocks: [
        {
          schema: "flowmemory.local_devnet.block.v0",
          blockNumber: 1,
          blockHash: `0x${"1".repeat(64)}`,
          stateRoot: `0x${"a".repeat(64)}`,
          txIds: [],
          receipts: [],
        },
        {
          schema: "flowmemory.local_devnet.block.v0",
          blockNumber: 42,
          blockHash: `0x${"2".repeat(64)}`,
          stateRoot: `0x${"b".repeat(64)}`,
          txIds: [],
          receipts: [],
        },
      ],
      pendingTxs: [],
    }));
    const state = loadControlPlaneState({
      localDevnetPath,
      localDevnetLaunchPath: join(dir, "missing-launch-state.json"),
      txIntakePath: join(dir, "transactions.ndjson"),
      bridgeObservationIntakePath: join(dir, "bridge-observations.ndjson"),
    });
    const chain = dispatchJsonRpc({ jsonrpc: "2.0", id: 1, method: "chain_status" }, { state }) as RpcSuccessResponse;
    const node = dispatchJsonRpc({ jsonrpc: "2.0", id: 2, method: "node_status" }, { state }) as RpcSuccessResponse;
    const block = dispatchJsonRpc(
      { jsonrpc: "2.0", id: 3, method: "block_get", params: { blockNumber: "42" } },
      { state },
    ) as RpcSuccessResponse;
    const blocks = dispatchJsonRpc(
      { jsonrpc: "2.0", id: 4, method: "block_list", params: { source: "active-local-runtime" } },
      { state },
    ) as RpcSuccessResponse;

    assert.equal(chain.result.currentBlock, "42");
    assert.equal(chain.result.blockHeight, "42");
    assert.equal(chain.result.currentBlockHash, `0x${"2".repeat(64)}`);
    assert.equal(chain.result.latestStateRoot, `0x${"b".repeat(64)}`);
    assert.equal(chain.result.finalizedBlock, "42");
    assert.equal(((chain.result.counts as JsonObject).runtimeBlocks), 2);
    assert.equal(node.result.latestBlockNumber, "42");
    assert.equal((block.result.block as JsonObject).source, "active-local-runtime");
    assert.equal((((block.result.provenance as JsonObject).sources as JsonObject[])[0]).path, localDevnetPath);
    assert.equal(blocks.result.count, 2);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("exposes RPC discovery and readiness without leaking env values", () => {
  const envNames = [
    "FLOWCHAIN_RPC_PUBLIC_URL",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
    "FLOWCHAIN_RPC_TLS_TERMINATED",
    "FLOWCHAIN_RPC_STATE_BACKUP_PATH",
  ] as const;
  const originalEnv = new Map(envNames.map((name) => [name, process.env[name]]));
  try {
    for (const name of envNames) {
      delete process.env[name];
    }
    const response = dispatchJsonRpc({ jsonrpc: "2.0", id: 1, method: "rpc_discover" }) as RpcSuccessResponse;
    const readiness = dispatchJsonRpc({ jsonrpc: "2.0", id: 2, method: "rpc_readiness" }) as RpcSuccessResponse;
    const methods = response.result.methods as JsonObject[];
    const methodNames = methods.map((entry) => entry.method);
    const rpcReadinessMethod = methods.find((entry) => entry.method === "rpc_readiness") as JsonObject;
    const transactionSubmitMethod = methods.find((entry) => entry.method === "transaction_submit") as JsonObject;
    const devnetStateMethod = methods.find((entry) => entry.method === "devnet_state") as JsonObject;

    assert.equal(response.result.schema, "flowchain.rpc.discovery.v0");
    assert.equal(response.result.protocol, "JSON-RPC 2.0");
    assert.ok(methodNames.includes("transaction_submit"));
    assert.ok(methodNames.includes("bridge_credit_status"));
    assert.ok(methodNames.includes("rpc_readiness"));
    assert.equal(response.result.compatibility.evmJsonRpcCompatible, false);
    assert.equal(response.result.deploymentMode, "local-only");
    assert.equal(response.result.publicRpcReady, false);
    assert.equal(response.result.localOnly, true);
    assert.equal(response.result.productionReady, false);
    assert.equal(response.result.publicReadyMethodCount, 0);
    assert.equal(rpcReadinessMethod.publicRpcEligible, true);
    assert.equal(rpcReadinessMethod.productionReady, false);
    assert.equal(transactionSubmitMethod.publicRpcEligible, false);
    assert.equal(transactionSubmitMethod.localOnly, true);
    assert.equal(devnetStateMethod.publicRpcEligible, false);
    assert.deepEqual(response.result.publicHttpMirrors, [
      "/health",
      "/chain/status",
      "/explorer/summary",
      "/bridge/live-readiness",
      "/bridge/status",
      "/wallets/balances",
      "/wallets/transfers",
    ]);

    assert.equal(readiness.result.schema, "flowchain.rpc.readiness.v0");
    assert.equal(readiness.result.status, "BLOCKED");
    assert.equal(readiness.result.deploymentMode, "local-only");
    assert.equal(readiness.result.publicRpcReady, false);
    assert.equal(readiness.result.localOnly, true);
    assert.equal(readiness.result.envValuesPrinted, false);
    assert.equal(readiness.result.noSecrets, true);
    assert.equal(readiness.result.productionReady, false);
    assert.equal(readiness.result.publicReadyMethodCount, 0);
    assert.ok((readiness.result.missingProductionEnvNames as string[]).includes("FLOWCHAIN_RPC_PUBLIC_URL"));

    process.env.FLOWCHAIN_RPC_PUBLIC_URL = "http://rpc.example.test";
    process.env.FLOWCHAIN_RPC_ALLOWED_ORIGINS = "*";
    process.env.FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE = "0";
    process.env.FLOWCHAIN_RPC_TLS_TERMINATED = "false";
    process.env.FLOWCHAIN_RPC_STATE_BACKUP_PATH = "configured-but-not-printed";
    const invalidReadiness = dispatchJsonRpc({ jsonrpc: "2.0", id: 3, method: "rpc_readiness" }) as RpcSuccessResponse;
    assert.equal(invalidReadiness.result.status, "FAILED");
    assert.equal(invalidReadiness.result.deploymentMode, "public-owner-edge-blocked");
    assert.equal(invalidReadiness.result.publicRpcReady, false);
    assert.equal(invalidReadiness.result.localOnly, true);
    assert.equal(invalidReadiness.result.productionReady, false);
    assert.ok((invalidReadiness.result.invalidProductionEnvNames as string[]).includes("FLOWCHAIN_RPC_PUBLIC_URL"));
    assert.ok((invalidReadiness.result.invalidProductionEnvNames as string[]).includes("FLOWCHAIN_RPC_ALLOWED_ORIGINS"));
    assert.ok((invalidReadiness.result.invalidProductionEnvNames as string[]).includes("FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE"));
    assert.ok((invalidReadiness.result.invalidProductionEnvNames as string[]).includes("FLOWCHAIN_RPC_TLS_TERMINATED"));
    assert.equal((invalidReadiness.result.publicRpcControls as JsonObject).envValuesPrinted, false);
    assert.equal(JSON.stringify(invalidReadiness.result).includes("rpc.example.test"), false);
    assert.equal(JSON.stringify(invalidReadiness.result).includes("configured-but-not-printed"), false);
  } finally {
    for (const [name, value] of originalEnv) {
      if (value === undefined) {
        delete process.env[name];
      } else {
        process.env[name] = value;
      }
    }
  }
});

test("recovers when generated launch/indexer/verifier fixtures are missing", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-"));
  try {
    const state = loadControlPlaneState({
      launchCorePath: join(dir, "missing-launch.json"),
      indexerPath: join(dir, "missing-indexer.json"),
      verifierPath: join(dir, "missing-reports.json"),
    });
    const response = dispatchJsonRpc({ jsonrpc: "2.0", id: 1, method: "chain_status" }, { state }) as RpcSuccessResponse;

    assert.equal(state.sources.launchCore.status, "recovered");
    assert.equal(state.sources.indexer.status, "recovered");
    assert.equal(state.sources.verifier.status, "recovered");
    assert.equal(response.result.counts.observations, 10);
    assert.equal(response.result.counts.verifierReports, 10);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("looks up receipt, report, and memory provenance", () => {
  const state = loadControlPlaneState();
  const receipt = state.launchCore.memoryReceipts[0];
  const reportId = receipt.reportId;
  const rootfieldId = receipt.rootfieldId;

  const receiptProvenance = dispatchJsonRpc(
    { jsonrpc: "2.0", id: 1, method: "provenance_get", params: { receiptId: receipt.receiptId } },
    { state },
  ) as RpcSuccessResponse;
  const reportProvenance = dispatchJsonRpc(
    { jsonrpc: "2.0", id: 2, method: "provenance_get", params: { reportId } },
    { state },
  ) as RpcSuccessResponse;
  const memoryCell = dispatchJsonRpc(
    { jsonrpc: "2.0", id: 3, method: "memory_cell_get", params: { rootfieldId } },
    { state },
  ) as RpcSuccessResponse;

  assert.equal(receiptProvenance.result.links.receiptId, receipt.receiptId);
  assert.equal(receiptProvenance.result.links.reportId, reportId);
  assert.equal(reportProvenance.result.links.reportId, reportId);
  assert.equal(memoryCell.result.schema, "flowmemory.control_plane.memory_cell.v0");
  assert.equal(memoryCell.result.rootfieldId, rootfieldId);
  assert.match(String(memoryCell.result.extensionPoint), /projected from RootfieldBundle/);
});

test("exposes base agent memory task scout and replay reads", () => {
  const state = loadControlPlaneState();
  const fixture = state.launchCore.taskScoutFixture;
  assert.ok(fixture);
  const agentId = fixture?.agentConfig.agentId;
  assert.equal(typeof agentId, "string");

  const listResponse = dispatchJsonRpc(
    { jsonrpc: "2.0", id: 1, method: "base_agent_memory_task_scout_list", params: { limit: 10 } },
    { state },
  ) as RpcSuccessResponse;
  const getResponse = dispatchJsonRpc(
    { jsonrpc: "2.0", id: 2, method: "base_agent_memory_task_scout_get", params: { agentId } },
    { state },
  ) as RpcSuccessResponse;
  const replayResponse = dispatchJsonRpc(
    { jsonrpc: "2.0", id: 3, method: "base_agent_memory_replay_get", params: { agentId } },
    { state },
  ) as RpcSuccessResponse;

  assert.equal(listResponse.result.schema, "flowmemory.control_plane.base_agent_memory_scout_list.v1");
  assert.equal(listResponse.result.count, 1);
  assert.equal(getResponse.result.schema, "flowmemory.control_plane.base_agent_memory_task_scout.v1");
  assert.equal(getResponse.result.fixture.agentConfig.agentId, agentId);
  assert.equal(replayResponse.result.schema, "flowmemory.control_plane.base_agent_memory_replay.v1");
  assert.equal(replayResponse.result.report.status, "verified");
});


test("exposes public agent network class tool and launch preview methods", () => {
  const state = loadControlPlaneState();
  const classes = dispatchJsonRpc(
    { jsonrpc: "2.0", id: 1, method: "public_agent_network_classes_list", params: { limit: 10 } },
    { state },
  ) as RpcSuccessResponse;
  const firstClass = ((classes.result as JsonObject).classes as JsonObject[])[0];
  const classId = String(firstClass.classId);
  const classGet = dispatchJsonRpc(
    { jsonrpc: "2.0", id: 2, method: "public_agent_network_class_get", params: { classId } },
    { state },
  ) as RpcSuccessResponse;
  const tools = dispatchJsonRpc(
    { jsonrpc: "2.0", id: 3, method: "public_agent_network_tools_list", params: { limit: 10 } },
    { state },
  ) as RpcSuccessResponse;
  const firstTool = ((tools.result as JsonObject).tools as JsonObject[])[0];
  const toolSetRoot = String(firstTool.toolSetRoot);
  const toolSet = dispatchJsonRpc(
    { jsonrpc: "2.0", id: 4, method: "public_agent_network_tool_set_get", params: { toolSetRoot } },
    { state },
  ) as RpcSuccessResponse;
  const preview = dispatchJsonRpc(
    {
      jsonrpc: "2.0",
      id: 5,
      method: "public_agent_launch_preview",
      params: {
        owner: "0x1000000000000000000000000000000000000001",
        classId,
        objectiveText: "Launch a task scout",
        profileText: "Public task scout profile",
        toolSetRoot,
        autonomyLevel: 2,
        riskLevel: 1,
        bondToken: "0x2000000000000000000000000000000000000001",
        bondAmount: "10000000000000000000",
        fuelToken: "0x2000000000000000000000000000000000000001",
        initialFuelAmount: "5000000000000000000",
        discoverable: true,
      },
    },
    { state },
  ) as RpcSuccessResponse;
  assert.equal(classes.result.schema, "flowmemory.control_plane.public_agent_class_list.v1");
  assert.equal(classGet.result.schema, "flowmemory.control_plane.public_agent_class.v1");
  assert.equal(toolSet.result.schema, "flowmemory.control_plane.public_agent_tool_set.v1");
  assert.equal(preview.result.schema, "flowmemory.control_plane.public_agent_launch_preview.v1");
  assert.equal((preview.result.preview as JsonObject).valid, true);
});

test("exposes public swarm class and launch preview methods", () => {
  const state = loadControlPlaneState();
  const classes = dispatchJsonRpc(
    { jsonrpc: "2.0", id: 1, method: "public_swarm_classes_list", params: { limit: 10 } },
    { state },
  ) as RpcSuccessResponse;
  const firstClass = ((classes.result as JsonObject).classes as JsonObject[])[0];
  const swarmClass = String(firstClass.swarmClass);
  const classGet = dispatchJsonRpc(
    { jsonrpc: "2.0", id: 2, method: "public_swarm_class_get", params: { swarmClass } },
    { state },
  ) as RpcSuccessResponse;
  const preview = dispatchJsonRpc(
    {
      jsonrpc: "2.0",
      id: 3,
      method: "public_swarm_launch_preview",
      params: {
        creator: "0x1000000000000000000000000000000000000001",
        swarmClass,
        missionText: "Research a launch opportunity",
        profileText: "Research swarm profile",
        budgetAsset: "0x2000000000000000000000000000000000000001",
        initialBudget: "1000000000000000000",
      },
    },
    { state },
  ) as RpcSuccessResponse;
  assert.equal(classes.result.schema, "flowmemory.control_plane.public_swarm_class_list.v1");
  assert.equal(classGet.result.schema, "flowmemory.control_plane.public_swarm_class.v1");
  assert.equal(preview.result.schema, "flowmemory.control_plane.public_swarm_launch_preview.v1");
  assert.equal((preview.result.preview as JsonObject).valid, true);
});

test("exposes public agent launch intent, discovery, and swarm replay methods", () => {
  const state = loadControlPlaneState();
  const publicClasses = dispatchJsonRpc(
    { jsonrpc: "2.0", id: 0, method: "public_agent_network_classes_list", params: { limit: 10 } },
    { state },
  ) as RpcSuccessResponse;
  const firstClass = ((publicClasses.result as JsonObject).classes as JsonObject[])[0];
  const classId = String(firstClass.classId);
  const launchIntent = dispatchJsonRpc(
    {
      jsonrpc: "2.0",
      id: 1,
      method: "public_agent_launch_intent_get",
      params: {
        owner: "0x1000000000000000000000000000000000000001",
        classId,
        objectiveText: "Launch a task scout",
        profileText: "Public task scout profile",
        toolSetRoot: "0xd6717d12f7068dbdbdfd4e9444d1aadf133b650aeb92fa44f2c1667af14e3c94",
        autonomyLevel: 2,
        riskLevel: 1,
        bondToken: "0x2000000000000000000000000000000000000001",
        bondAmount: "10000000000000000000",
        fuelToken: "0x2000000000000000000000000000000000000001",
        initialFuelAmount: "5000000000000000000",
        discoverable: true,
        rootfieldId: "0x1111111111111111111111111111111111111111111111111111111111111111",
        validAfter: "1",
        validUntil: "2",
        nonce: "0",
        salt: "0x2222222222222222222222222222222222222222222222222222222222222222"
      },
    },
    { state },
  ) as RpcSuccessResponse;
  const launch = dispatchJsonRpc({ jsonrpc: "2.0", id: 2, method: "public_agent_launch_get" }, { state }) as RpcSuccessResponse;
  const discover = dispatchJsonRpc({ jsonrpc: "2.0", id: 3, method: "public_agent_discover", params: { limit: 10 } }, { state }) as RpcSuccessResponse;
  const swarmGet = dispatchJsonRpc({ jsonrpc: "2.0", id: 4, method: "public_swarm_get" }, { state }) as RpcSuccessResponse;
  const swarmReplay = dispatchJsonRpc({ jsonrpc: "2.0", id: 5, method: "public_swarm_replay_get" }, { state }) as RpcSuccessResponse;
  assert.equal(launchIntent.result.schema, "flowmemory.control_plane.public_agent_launch_intent.v1");
  assert.equal(launch.result.schema, "flowmemory.control_plane.public_agent_launch.v1");
  assert.equal(discover.result.schema, "flowmemory.control_plane.public_agent_discovery.v1");
  assert.equal(swarmGet.result.schema, "flowmemory.control_plane.public_swarm.v1");
  assert.equal(swarmReplay.result.schema, "flowmemory.control_plane.public_swarm_replay.v1");
});
test("supports receipt and report object lookup by provenance-linked ids", () => {
  const state = loadControlPlaneState();
  const receipt = state.launchCore.memoryReceipts[0];
  const receiptResponse = dispatchJsonRpc(
    { jsonrpc: "2.0", id: 1, method: "receipt_get", params: { observationId: receipt.observationId } },
    { state },
  ) as RpcSuccessResponse;
  const reportResponse = dispatchJsonRpc(
    { jsonrpc: "2.0", id: 2, method: "verifier_report_get", params: { reportId: receipt.reportId } },
    { state },
  ) as RpcSuccessResponse;

  assert.equal(receiptResponse.result.receipt.receiptId, receipt.receiptId);
  assert.equal(reportResponse.result.report.reportId, receipt.reportId);
});

test("exposes artifact, devnet, challenge, and finality read methods", () => {
  const state = loadControlPlaneState();
  const receipt = state.launchCore.memoryReceipts[0];
  const artifactUri = receipt.evidenceRefs[0]?.uri;
  assert.equal(typeof artifactUri, "string");

  const artifact = dispatchJsonRpc(
    { jsonrpc: "2.0", id: 1, method: "artifact_get", params: { uri: artifactUri } },
    { state },
  ) as RpcSuccessResponse;
  const devnet = dispatchJsonRpc(
    { jsonrpc: "2.0", id: 2, method: "devnet_state" },
    { state },
  ) as RpcSuccessResponse;
  const challenge = dispatchJsonRpc(
    { jsonrpc: "2.0", id: 3, method: "challenge_get", params: { receiptId: receipt.receiptId } },
    { state },
  ) as RpcSuccessResponse;
  const finality = dispatchJsonRpc(
    { jsonrpc: "2.0", id: 4, method: "finality_get", params: { receiptId: receipt.receiptId } },
    { state },
  ) as RpcSuccessResponse;

  assert.equal(artifact.result.resolverPolicyId, "flowmemory.resolver.policy.v0.fixture");
  assert.equal(devnet.result.schema, "flowmemory.control_plane.devnet_state.v0");
  assert.equal(challenge.result.status, "not_opened");
  assert.equal(finality.result.status, "local-finalized");
});

test("prefers devnet/local runtime state over committed devnet fixtures", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-local-runtime-"));
  const localRuntimePath = join(dir, "launch-v0-state.json");
  try {
    writeFileSync(localRuntimePath, JSON.stringify({
      schema: "flowmemory.local_devnet.state.v0",
      chainId: "flowmemory-local-devnet-v0",
      blocks: [],
    }));
    const state = loadControlPlaneState({
      localDevnetPath: join(dir, "missing-state.json"),
      localDevnetLaunchPath: localRuntimePath,
    });

    assert.equal(state.sources.devnet.path, localRuntimePath);
    assert.equal(state.sources.devnet.status, "recovered");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("degrades instead of crashing when active local devnet JSON is malformed", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-malformed-devnet-"));
  const malformedDevnetPath = join(dir, "state.json");
  try {
    writeFileSync(malformedDevnetPath, "{\"schema\":\"flowmemory.local_devnet.state.v0\",");
    const state = loadControlPlaneState({
      localDevnetPath: malformedDevnetPath,
      localDevnetLaunchPath: join(dir, "missing-launch-state.json"),
      txIntakePath: join(dir, "transactions.ndjson"),
      bridgeObservationIntakePath: join(dir, "bridge-observations.ndjson"),
    });
    const health = dispatchJsonRpc({ jsonrpc: "2.0", id: 1, method: "health" }, { state }) as RpcSuccessResponse;
    const readiness = dispatchJsonRpc({ jsonrpc: "2.0", id: 2, method: "bridge_live_readiness" }, { state }) as RpcSuccessResponse;
    const readinessNode = (readiness.result as JsonObject).node as JsonObject;

    assert.equal(state.sources.devnet.status, "degraded");
    assert.match(state.sources.devnet.recovery ?? "", /malformed JSON/);
    assert.equal((health.result as JsonObject).status, "degraded");
    assert.ok(((health.result as JsonObject).degradedSources as string[]).includes("devnet"));
    assert.equal((readiness.result as JsonObject).schema, "flowmemory.control_plane.bridge_live_readiness.v0");
    assert.equal(readinessNode.sourceStatus, "degraded");
    assert.equal(readinessNode.running, false);
    assert.equal((readiness.result as JsonObject).failClosedStatus, "BLOCKED");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("submits local transactions to the file-backed runtime intake path", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-intake-"));
  try {
    const state = loadControlPlaneState({ txIntakePath: join(dir, "transactions.ndjson") });
    const response = dispatchJsonRpc(
      {
        jsonrpc: "2.0",
        id: 1,
        method: "transaction_submit",
        params: {
          signedEnvelope: productionSignedEnvelope("wallet-transfer"),
        },
      },
      { state },
    ) as RpcSuccessResponse;
    const mempool = dispatchJsonRpc({ jsonrpc: "2.0", id: 2, method: "mempool_list" }, { state }) as RpcSuccessResponse;

    assert.equal(response.result.accepted, true);
    assert.equal(response.result.status, "accepted_crypto_verified");
    assert.equal((response.result.crypto as JsonObject).ok, true);
    assert.equal(mempool.result.count, 1);
    assert.equal(mempool.result.transactions[0].source, "local-file-intake");
    assert.equal(mempool.result.transactions[0].transaction.schema, "flowchain.product_transfer.v0");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("rejects replayed crypto transaction envelopes before runtime intake", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-crypto-replay-"));
  try {
    const state = loadControlPlaneState({ txIntakePath: join(dir, "transactions.ndjson") });
    const signedEnvelope = productionSignedEnvelope("wallet-transfer");
    const first = dispatchJsonRpc(
      { jsonrpc: "2.0", id: 1, method: "transaction_submit", params: { signedEnvelope } },
      { state },
    ) as RpcSuccessResponse;
    const replay = dispatchJsonRpc(
      { jsonrpc: "2.0", id: 2, method: "transaction_submit", params: { signedEnvelope } },
      { state },
    ) as RpcErrorResponse;

    assert.equal(first.result.accepted, true);
    assert.equal(replay.error.data.reasonCode, "crypto.rejected");
    assert.ok(((replay.error.data.details as JsonObject).failureCodes as string[]).includes("duplicate-nonce"));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("rejects invalid live-L1 crypto transaction envelopes before runtime intake", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-crypto-negative-"));
  try {
    const state = loadControlPlaneState({ txIntakePath: join(dir, "transactions.ndjson") });
    const cases: Array<{ name: string; signedEnvelope: JsonObject; failureCode: string }> = [
      {
        name: "wrong-chain-id",
        signedEnvelope: {
          ...productionSignedEnvelope("wallet-transfer"),
          envelope: {
            ...(productionSignedEnvelope("wallet-transfer").envelope as JsonObject),
            chainId: "1",
          },
        },
        failureCode: "wrong-chain-id",
      },
      {
        name: "wrong-signer-role",
        signedEnvelope: {
          ...productionSignedEnvelope("validator-finality"),
          envelope: {
            ...(productionSignedEnvelope("validator-finality").envelope as JsonObject),
            signerRole: "user",
            signerRoleCode: 10,
          },
        },
        failureCode: "wrong-signer",
      },
      {
        name: "wrong-domain",
        signedEnvelope: {
          ...productionSignedEnvelope("wallet-transfer"),
          envelope: {
            ...(productionSignedEnvelope("wallet-transfer").envelope as JsonObject),
            domain: "flowchain.production-l1.v0.transaction-envelope:profile:private-lan:chain:31337",
          },
        },
        failureCode: "wrong-domain",
      },
      {
        name: "mutated-payload",
        signedEnvelope: {
          ...productionSignedEnvelope("wallet-transfer"),
          document: {
            ...(productionSignedEnvelope("wallet-transfer").document as JsonObject),
            amount: "1",
          },
        },
        failureCode: "bad-payload-hash",
      },
      {
        name: "malformed-public-key",
        signedEnvelope: {
          ...productionSignedEnvelope("wallet-transfer"),
          envelope: {
            ...(productionSignedEnvelope("wallet-transfer").envelope as JsonObject),
            publicKey: "0x1234",
          },
        },
        failureCode: "malformed-public-key",
      },
    ];

    for (const testCase of cases) {
      const response = dispatchJsonRpc(
        {
          jsonrpc: "2.0",
          id: testCase.name,
          method: "transaction_submit",
          params: { signedEnvelope: testCase.signedEnvelope },
        },
        { state },
      ) as RpcErrorResponse;
      assert.equal(response.error.data.reasonCode, "crypto.rejected", testCase.name);
      assert.ok(
        ((response.error.data.details as JsonObject).failureCodes as string[]).includes(testCase.failureCode),
        testCase.name,
      );
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("can forward runtime submissions to the live node inbox", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-node-inbox-"));
  try {
    const state = loadControlPlaneState({
      localDevnetPath: join(dir, "state.json"),
      txIntakePath: join(dir, "transactions.ndjson"),
    });
    const response = dispatchJsonRpc(
      {
        jsonrpc: "2.0",
        id: 1,
        method: "transaction_submit",
        params: {
          signedEnvelope: productionSignedEnvelope("wallet-transfer"),
          runtimeTransaction: {
            type: "CreateLocalTestUnitBalance",
            accountId: "local-account:test:node-inbox",
            owner: "operator:test",
          },
          submittedBy: "operator:test",
          runtimeSubmitMode: "node-inbox",
        },
      },
      { state },
    ) as RpcSuccessResponse;

    const runtimeSubmission = response.result.runtimeSubmission as JsonObject;
    assert.equal(response.result.forwardedTo, "local-runtime-inbox");
    assert.equal(runtimeSubmission.mode, "node-inbox");
    assert.equal(runtimeSubmission.status, "queued_in_node_inbox");
    assert.ok(Array.isArray(runtimeSubmission.queued));
    assert.equal(runtimeSubmission.queued.length, 1);
    assert.equal(readdirSync(join(dir, "node", "inbox")).length, 1);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("rejects unsigned transaction_submit payloads", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-unsigned-intake-"));
  try {
    const state = loadControlPlaneState({ txIntakePath: join(dir, "transactions.ndjson") });
    const response = dispatchJsonRpc(
      {
        jsonrpc: "2.0",
        id: 1,
        method: "transaction_submit",
        params: {
          transaction: {
            schema: "flowmemory.test_transaction.v0",
            action: "test",
          },
        },
      },
      { state },
    ) as RpcErrorResponse;

    assert.equal(response.error.code, -32602);
    assert.equal(response.error.data.reasonCode, "params.invalid");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("exposes account, wallet, bridge deposit, credit, and withdrawal reads", () => {
  const state = loadControlPlaneState();
  const accounts = dispatchJsonRpc({ jsonrpc: "2.0", id: 1, method: "account_list" }, { state }) as RpcSuccessResponse;
  const accountId = accounts.result.accounts[0].accountId as string;
  const deposits = dispatchJsonRpc({ jsonrpc: "2.0", id: 2, method: "bridge_deposit_list" }, { state }) as RpcSuccessResponse;
  const depositId = deposits.result.deposits[0].depositId as string;
  const credits = dispatchJsonRpc({ jsonrpc: "2.0", id: 3, method: "bridge_credit_list" }, { state }) as RpcSuccessResponse;
  const creditId = credits.result.credits[0].creditId as string;
  const creditWithTxHash = (credits.result.credits as Record<string, unknown>[])
    .find((entry) => typeof entry.txHash === "string");
  assert.ok(creditWithTxHash);
  const withdrawals = dispatchJsonRpc({ jsonrpc: "2.0", id: 4, method: "withdrawal_list" }, { state }) as RpcSuccessResponse;
  const withdrawalId = withdrawals.result.withdrawals[0].withdrawalId as string;

  assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 5, method: "account_get", params: { accountId } }, { state }) as RpcSuccessResponse).result.schema, "flowmemory.control_plane.account_detail.v0");
  assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 6, method: "wallet_metadata_get", params: { walletId: accountId } }, { state }) as RpcSuccessResponse).result.schema, "flowmemory.control_plane.wallet_public_metadata_detail.v0");
  assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 7, method: "balance_get", params: { accountId } }, { state }) as RpcSuccessResponse).result.noValue, true);
  assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 8, method: "bridge_deposit_get", params: { depositId } }, { state }) as RpcSuccessResponse).result.schema, "flowmemory.control_plane.bridge_deposit_detail.v0");
  assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 9, method: "bridge_credit_get", params: { creditId } }, { state }) as RpcSuccessResponse).result.schema, "flowmemory.control_plane.bridge_credit_detail.v0");
  assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 11, method: "bridge_credit_get", params: { txHash: creditWithTxHash.txHash as string } }, { state }) as RpcSuccessResponse).result.credit.accountId, creditWithTxHash.accountId);
  assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 12, method: "bridge_credit_status", params: { txHash: creditWithTxHash.txHash as string } }, { state }) as RpcSuccessResponse).result.found, true);
  assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 13, method: "bridge_status" }, { state }) as RpcSuccessResponse).result.liveRuntimeHandoffLoaded, true);
  assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 10, method: "withdrawal_get", params: { withdrawalId } }, { state }) as RpcSuccessResponse).result.schema, "flowmemory.control_plane.withdrawal_detail.v0");
});

test("loads standalone wallet public metadata as account metadata", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-wallet-metadata-"));
  try {
    const walletPath = join(dir, "wallet-public-metadata.json");
    const walletId = `0x${"ab".repeat(32)}`;
    writeFileSync(walletPath, JSON.stringify({
      schema: "flowchain.local_wallet_public_metadata.v0",
      vaultId: `0x${"cd".repeat(32)}`,
      accounts: [{
        accountId: walletId,
        address: walletId,
        signerId: walletId,
        signerKeyId: `0x${"ef".repeat(32)}`,
        signerRole: "operator",
        keyScheme: "secp256k1",
        publicKey: `0x02${"12".repeat(32)}`,
        label: "operator-test-wallet",
        status: "active",
        chainId: "31337",
        nextNonce: "1",
      }],
      boundary: "Public local wallet metadata only.",
    }));

    const state = loadControlPlaneState({ walletPublicMetadataPath: walletPath });
    const accounts = dispatchJsonRpc({ jsonrpc: "2.0", id: 1, method: "account_list" }, { state }) as RpcSuccessResponse;
    const account = accounts.result.accounts.find((entry: JsonObject) => entry.accountId === walletId);
    assert.equal(account?.accountType, "wallet");
    assert.equal(account?.source, "wallet-public-metadata");

    const wallet = dispatchJsonRpc(
      { jsonrpc: "2.0", id: 2, method: "wallet_metadata_get", params: { walletId } },
      { state },
    ) as RpcSuccessResponse;
    assert.equal(wallet.result.wallet.accountId, walletId);
    assert.equal(wallet.result.wallet.publicOnly, true);
    assert.equal(JSON.stringify(wallet.result).includes("privateKey"), false);

    const health = dispatchJsonRpc({ jsonrpc: "2.0", id: 3, method: "health" }, { state }) as RpcSuccessResponse;
    assert.equal(health.result.checks.walletPublicMetadata, "loaded");

    const devnetState = dispatchJsonRpc({ jsonrpc: "2.0", id: 4, method: "devnet_state" }, { state }) as RpcSuccessResponse;
    assert.ok((devnetState.result.accounts as JsonObject[]).some((entry) => entry.accountId === walletId));
    assert.ok((devnetState.result.walletMetadata as JsonObject[]).some((entry) => entry.accountId === walletId));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("exposes product token, DEX, bridge credit, and product-flow reads from handoff maps", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-product-"));
  try {
    const localDevnetPath = join(dir, "state.json");
    const handoffPath = join(dir, "control-plane-handoff.json");
    writeFileSync(localDevnetPath, JSON.stringify({
      schema: "flowmemory.local_devnet.state.v0",
      chainId: "flowmemory-local-devnet-v0",
      blocks: [],
    }));
    writeFileSync(handoffPath, JSON.stringify({
      schema: "flowmemory.control_plane_handoff.local_devnet.v0",
      stateRoot: "0xproduct",
      objects: {
        tokens: {
          "token:demo": {
            tokenId: "token:demo",
            symbol: "DEMO",
            name: "Demo Token",
            totalSupply: "1000000",
            status: "launched",
          },
        },
        tokenBalances: {
          "token-balance:demo:alice": {
            balanceId: "token-balance:demo:alice",
            accountId: "account:alice",
            tokenId: "token:demo",
            amount: "5000",
          },
        },
        pools: {
          "pool:demo-ltu": {
            poolId: "pool:demo-ltu",
            token0: "local-test-unit",
            token1: "token:demo",
            reserve0: "1000",
            reserve1: "2000",
          },
        },
        lpPositions: {
          "lp:alice:demo-ltu": {
            positionId: "lp:alice:demo-ltu",
            accountId: "account:alice",
            poolId: "pool:demo-ltu",
            liquidity: "100",
          },
        },
        swaps: {
          "swap:001": {
            swapId: "swap:001",
            txId: "tx:swap:001",
            accountId: "account:alice",
            poolId: "pool:demo-ltu",
            tokenIn: "local-test-unit",
            tokenOut: "token:demo",
            amountIn: "10",
            amountOut: "19",
            status: "applied",
          },
        },
        bridgeCredits: {
          "bridge-credit:001": {
            creditId: "bridge-credit:001",
            depositId: "deposit:001",
            accountId: "account:alice",
            token: "local-test-unit",
            amount: "25",
            status: "applied",
          },
        },
      },
    }));

    const state = loadControlPlaneState({
      localDevnetPath,
      localDevnetLaunchPath: join(dir, "missing-launch-state.json"),
      devnetControlPlaneHandoffPath: handoffPath,
      txIntakePath: join(dir, "transactions.ndjson"),
      bridgeObservationIntakePath: join(dir, "bridge-observations.ndjson"),
    });

    assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 1, method: "token_list" }, { state }) as RpcSuccessResponse).result.tokens[0].tokenId, "token:demo");
    assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 2, method: "token_get", params: { symbol: "DEMO" } }, { state }) as RpcSuccessResponse).result.schema, "flowmemory.control_plane.token_detail.v0");
    assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 3, method: "token_balance_get", params: { accountId: "account:alice", tokenId: "token:demo" } }, { state }) as RpcSuccessResponse).result.balance.amount, "5000");
    assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 4, method: "pool_get", params: { poolId: "pool:demo-ltu" } }, { state }) as RpcSuccessResponse).result.pool.token1, "token:demo");
    assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 5, method: "lp_position_get", params: { positionId: "lp:alice:demo-ltu" } }, { state }) as RpcSuccessResponse).result.position.liquidity, "100");
    assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 6, method: "swap_get", params: { txId: "tx:swap:001" } }, { state }) as RpcSuccessResponse).result.swap.amountOut, "19");
    assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 7, method: "bridge_credit_get", params: { creditId: "bridge-credit:001" } }, { state }) as RpcSuccessResponse).result.credit.status, "applied");
    assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 8, method: "product_flow_status" }, { state }) as RpcSuccessResponse).result.counts.swaps, 1);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("rejects secret-shaped intake and responses before returning them", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-secret-"));
  try {
    const secretFixturePath = join(dir, "tx-fixtures.json");
    writeFileSync(secretFixturePath, JSON.stringify({ privateKey: `0x${"1".repeat(64)}` }));
    const state = loadControlPlaneState({
      txFixturesPath: secretFixturePath,
      txIntakePath: join(dir, "transactions.ndjson"),
    });
    const submit = dispatchJsonRpc(
      {
        jsonrpc: "2.0",
        id: 1,
        method: "transaction_submit",
        params: {
          signedEnvelope: {
            ...productionSignedEnvelope("wallet-transfer"),
            privateKey: `0x${"1".repeat(64)}`,
          },
        },
      },
      { state },
    ) as RpcErrorResponse;
    const raw = dispatchJsonRpc(
      { jsonrpc: "2.0", id: 2, method: "raw_json_get", params: { source: "txFixtures" } },
      { state },
    ) as RpcErrorResponse;

    assert.equal(submit.error.data.reasonCode, "secret.rejected");
    assert.equal(raw.error.data.reasonCode, "secret.rejected");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("exposes real-value pilot lifecycle reads and operator next steps", () => {
  const state = loadControlPlaneState();
  const status = dispatchJsonRpc({ jsonrpc: "2.0", id: 1, method: "pilot_status" }, { state }) as RpcSuccessResponse;
  const deposits = dispatchJsonRpc({ jsonrpc: "2.0", id: 2, method: "pilot_deposit_observation_list" }, { state }) as RpcSuccessResponse;
  const credits = dispatchJsonRpc({ jsonrpc: "2.0", id: 3, method: "pilot_credit_list" }, { state }) as RpcSuccessResponse;
  const withdrawals = dispatchJsonRpc({ jsonrpc: "2.0", id: 4, method: "pilot_withdrawal_intent_list" }, { state }) as RpcSuccessResponse;
  const releases = dispatchJsonRpc({ jsonrpc: "2.0", id: 5, method: "pilot_release_evidence_list" }, { state }) as RpcSuccessResponse;

  assert.equal(status.result.schema, "flowmemory.control_plane.real_value_pilot_status.v0");
  assert.equal(status.result.cappedOwnerTesting, true);
  assert.equal(status.result.broadPublicReadiness, false);
  assert.equal(status.result.browserStoresSecrets, false);
  assert.match(String(status.result.nextOperatorStep.command), /^npm run /);
  assert.equal((status.result.lifecycle as JsonObject[]).some((step) => step.phase === "base_deposit_observed"), true);
  assert.equal(deposits.result.schema, "flowmemory.control_plane.real_value_pilot_deposit_observation_list.v0");
  assert.equal(credits.result.schema, "flowmemory.control_plane.real_value_pilot_credit_list.v0");
  assert.equal(withdrawals.result.schema, "flowmemory.control_plane.real_value_pilot_withdrawal_intent_list.v0");
  assert.equal(releases.result.schema, "flowmemory.control_plane.real_value_pilot_release_evidence_list.v0");
  assert.ok((deposits.result.depositObservations as JsonObject[]).length > 0);
  assert.ok((credits.result.credits as JsonObject[]).length > 0);
  assert.ok((withdrawals.result.withdrawalIntents as JsonObject[]).length > 0);
  assert.ok((releases.result.releaseEvidence as JsonObject[]).length > 0);
});

test("pilot lifecycle can represent a live Base 8453 evidence bundle", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-pilot-live-"));
  try {
    const handoffPath = join(dir, "pilot-handoff.json");
    writeFileSync(handoffPath, JSON.stringify({
      schema: "flowmemory.bridge_runtime_handoff.v0",
      handoffId: `0x${"a".repeat(64)}`,
      generatedAt: "2026-05-14T00:00:00.000Z",
      mode: "base-mainnet-canary",
      productionReady: false,
      localOnly: true,
      observations: [{
        schema: "flowmemory.bridge_deposit_observation.v0",
        observationId: `0x${"b".repeat(64)}`,
        replayKey: `0x${"c".repeat(64)}`,
        observedAt: "2026-05-14T00:00:00.000Z",
        mode: "base-mainnet-canary",
        productionReady: false,
        deposit: {
          schema: "flowmemory.bridge_deposit.v0",
          depositId: `0x${"d".repeat(64)}`,
          sourceChainId: 8453,
          sourceContract: `0x${"1".repeat(40)}`,
          txHash: `0x${"2".repeat(64)}`,
          logIndex: 0,
          token: `0x${"3".repeat(40)}`,
          amount: "1000000",
          sender: `0x${"4".repeat(40)}`,
          flowchainRecipient: `0x${"5".repeat(64)}`,
          nonce: "1",
          status: "observed",
        },
        guardrails: {
          explicitChainId: true,
          explicitContract: true,
          explicitBlockRange: true,
          noSecrets: true,
          maxUsd: 20,
        },
      }],
      credits: [{
        schema: "flowmemory.bridge_credit.v0",
        creditId: `0x${"e".repeat(64)}`,
        observationId: `0x${"b".repeat(64)}`,
        depositId: `0x${"d".repeat(64)}`,
        replayKey: `0x${"c".repeat(64)}`,
        source: {
          chainId: 8453,
          contract: `0x${"1".repeat(40)}`,
          txHash: `0x${"2".repeat(64)}`,
          logIndex: 0,
        },
        token: `0x${"3".repeat(40)}`,
        amount: "1000000",
        flowchainRecipient: `0x${"5".repeat(64)}`,
        status: "applied",
        appliedAt: "2026-05-14T00:00:01.000Z",
        localOnly: true,
        productionReady: false,
      }],
      withdrawalIntents: [{
        schema: "flowmemory.bridge_withdrawal_intent.v0",
        withdrawalIntentId: `0x${"6".repeat(64)}`,
        creditId: `0x${"e".repeat(64)}`,
        depositId: `0x${"d".repeat(64)}`,
        sourceChainId: 8453,
        destinationChainId: 8453,
        token: `0x${"3".repeat(40)}`,
        amount: "1000000",
        flowchainAccount: `0x${"5".repeat(64)}`,
        baseRecipient: `0x${"4".repeat(40)}`,
        status: "requested",
        requestedAt: "2026-05-14T00:00:02.000Z",
        testMode: true,
        broadcast: false,
        releasePolicy: "operator_release_evidence_required",
        productionReady: false,
      }],
      releaseEvidence: [{
        releaseEvidenceId: `0x${"7".repeat(64)}`,
        withdrawalIntentId: `0x${"6".repeat(64)}`,
        creditId: `0x${"e".repeat(64)}`,
        depositId: `0x${"d".repeat(64)}`,
        status: "recorded",
        releaseTxHash: `0x${"8".repeat(64)}`,
        recordedAt: "2026-05-14T00:00:03.000Z",
      }],
      replayProtection: {
        strategy: "source-chain-contract-tx-log-deposit",
        replayKeys: [`0x${"c".repeat(64)}`],
        duplicateReplayKeys: [],
      },
      runtimeIntake: {
        status: "handoff_file",
        consumer: "flowchain-runtime-agent",
        expectedPath: "fixtures/bridge/local-runtime-bridge-handoff.json",
        note: "test",
      },
      workbenchTimeline: [],
      workbenchRecords: [],
      limitations: [],
    }));
    const state = loadControlPlaneState({
      bridgeRuntimeHandoffPath: handoffPath,
      bridgeObservationPath: join(dir, "missing-observation.json"),
      bridgeObservationIntakePath: join(dir, "bridge-observations.ndjson"),
    });
    const status = dispatchJsonRpc({ jsonrpc: "2.0", id: 1, method: "pilot_status" }, { state }) as RpcSuccessResponse;

    assert.equal(status.result.state, "live");
    assert.equal(status.result.counts.baseMainnetDeposits, 1);
    assert.equal(status.result.capStatus.withinCap, true);
    assert.equal(status.result.nextOperatorStep.command, "npm run flowchain:export");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("bridge live readiness fails closed for missing env and returns env names only", () => {
  const envNames = [
    "FLOWCHAIN_PILOT_OPERATOR_ACK",
    "FLOWCHAIN_BASE8453_RPC_URL",
    "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
    "FLOWCHAIN_BASE8453_FROM_BLOCK",
    "FLOWCHAIN_BASE8453_TO_BLOCK",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_BASE8453_CONFIRMATION_DEPTH",
    "FLOWCHAIN_BASE8453_TOKEN_MODE",
    "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
  ] as const;
  const originalEnv = new Map(envNames.map((name) => [name, process.env[name]]));
  const configuredButHidden = "https://example.invalid/rpc-redacted";

  try {
    for (const name of envNames) {
      delete process.env[name];
    }
    process.env.FLOWCHAIN_BASE8453_RPC_URL = configuredButHidden;
    const state = loadControlPlaneState();
    const response = dispatchJsonRpc(
      { jsonrpc: "2.0", id: 1, method: "bridge_live_readiness" },
      { state },
    ) as RpcSuccessResponse;

    assert.equal(response.result.schema, "flowmemory.control_plane.bridge_live_readiness.v0");
    assert.equal(response.result.failClosedStatus, "BLOCKED");
    assert.equal(response.result.baseChainId, 8453);
    assert.equal(response.result.envValuesPrinted, false);
    assert.equal(response.result.readyForOperatorLivePilot, false);
    assert.ok((response.result.missingEnvNames as string[]).includes("FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS"));
    assert.ok((response.result.missingEnvNames as string[]).includes("FLOWCHAIN_PILOT_OPERATOR_ACK"));
    assert.equal((response.result.missingEnvNames as string[]).includes("FLOWCHAIN_BASE8453_RPC_URL"), false);
    assert.equal(JSON.stringify(response.result).includes(configuredButHidden), false);
  } finally {
    for (const [name, value] of originalEnv) {
      if (value === undefined) {
        delete process.env[name];
      } else {
        process.env[name] = value;
      }
    }
  }
});

test("exact-value fixture reports equality across bridge lifecycle and wallet transfer history", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-exact-lifecycle-"));
  try {
    const handoffPath = join(dir, "pilot-handoff.json");
    const walletProofPath = join(dir, "wallet-e2e-proof.json");
    const baseTxHash = `0x${"ab".repeat(32)}`;
    const creditId = `0x${"ed".repeat(32)}`;
    const depositId = `0x${"da".repeat(32)}`;
    const replayKey = `0x${"ce".repeat(32)}`;
    const withdrawalIntentId = `0x${"7".repeat(64)}`;
    const releaseEvidenceId = `0x${"f".repeat(64)}`;
    const token = `0x${"31".repeat(20)}`;
    const creditedWallet = `0x${"5a".repeat(32)}`;
    const recipientWallet = `0x${"6b".repeat(32)}`;
    const amount = "1000000";

    writeFileSync(handoffPath, JSON.stringify({
      schema: "flowmemory.bridge_runtime_handoff.v0",
      handoffId: `0x${"a".repeat(64)}`,
      generatedAt: "2026-05-14T00:00:00.000Z",
      mode: "base-mainnet-canary",
      productionReady: false,
      localOnly: true,
      observations: [{
        schema: "flowmemory.bridge_deposit_observation.v0",
        observationId: `0x${"b".repeat(64)}`,
        replayKey,
        mode: "base-mainnet-canary",
        observedAt: "2026-05-14T00:00:00.000Z",
        deposit: {
          schema: "flowmemory.bridge_deposit.v0",
          depositId,
          sourceChainId: 8453,
          sourceContract: `0x${"1".repeat(40)}`,
          txHash: baseTxHash,
          logIndex: 7,
          token,
          amount,
          sender: `0x${"4".repeat(40)}`,
          flowchainRecipient: creditedWallet,
          nonce: "1",
          status: "observed",
        },
        guardrails: {
          explicitChainId: true,
          explicitContract: true,
          explicitBlockRange: true,
          noSecrets: true,
          maxUsd: 20,
        },
      }],
      credits: [{
        schema: "flowmemory.bridge_credit.v0",
        creditId,
        observationId: `0x${"b".repeat(64)}`,
        depositId,
        replayKey,
        source: {
          chainId: 8453,
          contract: `0x${"1".repeat(40)}`,
          txHash: baseTxHash,
          logIndex: 7,
        },
        token,
        amount,
        flowchainRecipient: creditedWallet,
        status: "applied",
        appliedAt: "2026-05-14T00:00:01.000Z",
        localOnly: true,
        productionReady: false,
      }],
      runtimeApplications: [{
        schema: "flowmemory.bridge_runtime_credit_application.v0",
        applicationId: `0x${"9".repeat(64)}`,
        creditId,
        depositId,
        accountId: creditedWallet,
        assetId: token,
        amount,
        status: "applied",
      }],
      withdrawalIntents: [{
        schema: "flowmemory.bridge_withdrawal_intent.v0",
        withdrawalIntentId,
        creditId,
        depositId,
        sourceChainId: 8453,
        destinationChainId: 8453,
        token,
        amount,
        flowchainAccount: creditedWallet,
        baseRecipient: `0x${"8".repeat(40)}`,
        status: "requested",
        requestedAt: "2026-05-14T00:00:02.000Z",
        testMode: true,
        broadcast: false,
        releasePolicy: "operator_release_evidence_required",
        productionReady: false,
      }],
      releaseEvidences: [{
        schema: "flowmemory.bridge_release_evidence.v0",
        releaseEvidenceId,
        withdrawalIntentId,
        creditId,
        depositId,
        status: "recorded",
        releaseTxHash: `0x${"8".repeat(64)}`,
        amount,
        token,
        recordedAt: "2026-05-14T00:00:03.000Z",
      }],
    }));
    writeFileSync(walletProofPath, JSON.stringify({
      schema: "flowmemory.wallet_e2e_proof.v0",
      generatedAt: "2026-05-14T00:00:04.000Z",
      funding: { source: "bridge-credit", creditId },
      transfer: {
        receipt: {
          txId: `tx:${"1".repeat(16)}`,
          from: creditedWallet,
          to: recipientWallet,
          assetId: token,
          amount,
          status: "applied",
          balancesBefore: { from: amount, to: "0" },
          balancesAfter: { from: "0", to: amount },
        },
      },
    }));

    const state = loadControlPlaneState({
      bridgeRuntimeHandoffPath: handoffPath,
      bridgeObservationPath: join(dir, "missing-observation.json"),
      bridgeObservationIntakePath: join(dir, "bridge-observations.ndjson"),
      walletTransferProofPath: walletProofPath,
    });
    const lifecycle = dispatchJsonRpc(
      { jsonrpc: "2.0", id: 1, method: "pilot_lifecycle_record_list", params: { txHash: baseTxHash } },
      { state },
    ) as RpcSuccessResponse;
    const record = (lifecycle.result.lifecycleRecords as JsonObject[])[0];
    const equality = record.equality as JsonObject;

    assert.equal(lifecycle.result.schema, "flowmemory.control_plane.bridge_lifecycle_record_list.v0");
    assert.equal(lifecycle.result.count, 1);
    assert.equal(record.baseTxHash, baseTxHash);
    assert.equal(record.logIndex, 7);
    assert.equal(record.creditId, creditId);
    assert.equal(record.recipientWallet, creditedWallet);
    assert.equal(record.replayKey, replayKey);
    assert.equal(record.replayStatus, "accepted");
    assert.equal(record.withdrawalIntentId, withdrawalIntentId);
    assert.equal(record.withdrawalStatus, "requested");
    assert.equal(record.releaseEvidenceId, releaseEvidenceId);
    assert.equal(record.releaseStatus, "recorded");
    assert.equal(record.asset, token);
    assert.equal(record.amountSmallestUnits, amount);
    assert.equal(record.status, "release_evidence_recorded");
    assert.equal(equality.depositAmount, amount);
    assert.equal(equality.observedAmount, amount);
    assert.equal(equality.creditedAmount, amount);
    assert.equal(equality.walletDelta, amount);
    assert.equal(equality.transferableAmount, amount);
    assert.equal(equality.withdrawalAmount, amount);
    assert.equal(equality.releaseAmount, amount);
    assert.equal(equality.allEqual, true);

    for (const params of [
      { creditId },
      { walletAddress: creditedWallet },
      { status: "release_evidence_recorded" },
    ]) {
      const filtered = dispatchJsonRpc(
        { jsonrpc: "2.0", id: JSON.stringify(params), method: "pilot_lifecycle_record_list", params },
        { state },
      ) as RpcSuccessResponse;
      const rows = filtered.result.lifecycleRecords as JsonObject[];
      assert.ok(rows.some((row) => row.baseTxHash === baseTxHash));
      if ("status" in params) {
        assert.ok(rows.every((row) => row.status === params.status));
      } else {
        assert.equal(filtered.result.count, 1);
      }
    }

    const balances = dispatchJsonRpc(
      { jsonrpc: "2.0", id: 2, method: "wallet_balance_list", params: { walletAddress: creditedWallet } },
      { state },
    ) as RpcSuccessResponse;
    const recipientBalances = dispatchJsonRpc(
      { jsonrpc: "2.0", id: 3, method: "wallet_balance_list", params: { walletAddress: recipientWallet } },
      { state },
    ) as RpcSuccessResponse;
    const transfers = dispatchJsonRpc(
      { jsonrpc: "2.0", id: 4, method: "wallet_transfer_history", params: { walletAddress: creditedWallet } },
      { state },
    ) as RpcSuccessResponse;
    const transfer = (transfers.result.transfers as JsonObject[])[0];

    assert.equal(balances.result.schema, "flowmemory.control_plane.wallet_balance_list.v0");
    assert.ok((balances.result.balances as JsonObject[]).some((row) => row.status === "credited" && row.amount === amount));
    assert.ok((balances.result.balances as JsonObject[]).some((row) => row.status === "after_transfer" && row.amount === "0"));
    assert.ok((recipientBalances.result.balances as JsonObject[]).some((row) => row.status === "after_transfer" && row.amount === amount));
    assert.equal(transfers.result.schema, "flowmemory.control_plane.wallet_transfer_history.v0");
    assert.equal(transfers.result.count, 1);
    assert.equal(transfer.fromAccountId, creditedWallet);
    assert.equal(transfer.toAccountId, recipientWallet);
    assert.equal(transfer.amount, amount);
    assert.equal(transfer.status, "applied");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("bridge observation intake enforces crypto replay keys and duplicates", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-bridge-crypto-"));
  try {
    const deposit = JSON.parse(
      readFileSync(new URL("../../../fixtures/bridge/base8453-pilot-mock-deposit.json", import.meta.url), "utf8"),
    ) as JsonObject;
    const observation = bridgeObservationFromDeposit(deposit);
    const state = loadControlPlaneState({
      bridgeObservationPath: join(dir, "missing-observation.json"),
      bridgeRuntimeHandoffPath: join(dir, "missing-handoff.json"),
      bridgeObservationIntakePath: join(dir, "bridge-observations.ndjson"),
    });
    const first = dispatchJsonRpc(
      { jsonrpc: "2.0", id: 1, method: "bridge_observation_submit", params: { observation } },
      { state },
    ) as RpcSuccessResponse;
    const duplicate = dispatchJsonRpc(
      { jsonrpc: "2.0", id: 2, method: "bridge_observation_submit", params: { observation } },
      { state },
    ) as RpcErrorResponse;
    const mutated = structuredClone(observation);
    (mutated.deposit as JsonObject).amount = "1";
    const badPayload = dispatchJsonRpc(
      { jsonrpc: "2.0", id: 3, method: "bridge_observation_submit", params: { observation: mutated } },
      { state },
    ) as RpcErrorResponse;

    assert.equal(first.result.accepted, true);
    assert.equal((first.result.crypto as JsonObject).ok, true);
    assert.equal(duplicate.error.data.reasonCode, "crypto.rejected");
    assert.ok(((duplicate.error.data.details as JsonObject).failureCodes as string[]).includes("duplicate-bridge-replay-key"));
    assert.equal(badPayload.error.data.reasonCode, "crypto.rejected");
    assert.ok(((badPayload.error.data.details as JsonObject).failureCodes as string[]).includes("wrong-bridge-observation-id"));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("rejects secret-shaped bridge and pilot-adjacent intake material", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-pilot-secrets-"));
  try {
    const state = loadControlPlaneState({
      bridgeObservationIntakePath: join(dir, "bridge-observations.ndjson"),
    });
    const secretCases: JsonObject[] = [
      { privateKey: `0x${"1".repeat(64)}` },
      { seedPhrase: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about" },
      { mnemonic: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about" },
      { rpcCredential: "https://user:pass@example.invalid" },
      { apiKey: "sk-1234567890abcdefghijklmnop" },
      { webhookUrl: "https://hooks.slack.com/services/T000/B000/XXXXXXXXXXXXXXXXXXXXXXXX" },
    ];

    for (const secret of secretCases) {
      const response = dispatchJsonRpc(
        {
          jsonrpc: "2.0",
          id: Object.keys(secret)[0],
          method: "bridge_observation_submit",
          params: {
            observation: {
              schema: "flowmemory.bridge_deposit_observation.v0",
              observationId: `0x${"9".repeat(64)}`,
              ...secret,
            },
          },
        },
        { state },
      ) as RpcErrorResponse;
      assert.equal(response.error.data.reasonCode, "secret.rejected");
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("smoke client queries the complete local lifecycle surface", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-smoke-"));
  const smoke = runControlPlaneSmoke({
    txIntakePath: join(dir, "transactions.ndjson"),
    bridgeObservationIntakePath: join(dir, "bridge-observations.ndjson"),
  });

  assert.equal(smoke.schema, "flowmemory.control_plane.smoke.v0");
  assert.equal(smoke.ok, true);
  const responseSchemas = smoke.responseSchemas as string[];
  assert.equal(smoke.methodCount, responseSchemas.length);
  for (const expectedSchema of [
    "flowchain.rpc.discovery.v0",
    "flowchain.rpc.readiness.v0",
    "flowmemory.control_plane.real_value_pilot_status.v0",
    "flowmemory.control_plane.real_value_pilot_deposit_observation_list.v0",
    "flowmemory.control_plane.real_value_pilot_credit_list.v0",
    "flowmemory.control_plane.real_value_pilot_withdrawal_intent_list.v0",
    "flowmemory.control_plane.real_value_pilot_release_evidence_list.v0",
    "flowmemory.control_plane.real_value_pilot_cap_status.v0",
    "flowmemory.control_plane.real_value_pilot_pause_status.v0",
    "flowmemory.control_plane.real_value_pilot_retry_status.v0",
    "flowmemory.control_plane.real_value_pilot_emergency_status.v0",
    "flowmemory.control_plane.bridge_live_readiness.v0",
    "flowmemory.control_plane.bridge_lifecycle_record_list.v0",
    "flowmemory.control_plane.wallet_balance_list.v0",
    "flowmemory.control_plane.wallet_transfer_history.v0",
    "flowmemory.control_plane.raw_json.v0",
    "flowmemory.control_plane.agent_bond_readiness.v1",
    "flowmemory.control_plane.agent_bond_task_list.v1",
    "flowmemory.control_plane.agent_bond_task.v1",
    "flowmemory.control_plane.agent_bond_public_launch_status.v1",
    "flowmemory.control_plane.base_agent_memory_scout_list.v1",
    "flowmemory.control_plane.base_agent_memory_task_scout.v1",
    "flowmemory.control_plane.base_agent_memory_replay.v1",
    "flowmemory.control_plane.public_agent_class_list.v1",
    "flowmemory.control_plane.public_agent_class.v1",
    "flowmemory.control_plane.public_agent_tool_list.v1",
    "flowmemory.control_plane.public_agent_tool_set.v1",
    "flowmemory.control_plane.public_agent_launch_preview.v1",
    "flowmemory.control_plane.public_swarm_class_list.v1",
    "flowmemory.control_plane.public_swarm_class.v1",
    "flowmemory.control_plane.public_swarm_launch_preview.v1",
  ]) {
    assert.ok(responseSchemas.includes(expectedSchema), `smoke response should include ${expectedSchema}`);
  }
  assert.equal(smoke.methodCount, responseSchemas.length);
  assert.ok((smoke.responseSchemas as string[]).includes("flowmemory.control_plane.real_value_pilot_status.v0"));
  assert.ok((smoke.responseSchemas as string[]).includes("flowmemory.control_plane.explorer_search.v0"));
  assert.ok((smoke.responseSchemas as string[]).includes("flowmemory.control_plane.raw_json.v0"));
  rmSync(dir, { recursive: true, force: true });
});

test("smoke client ignores stale local devnet blocks without transactions", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-stale-devnet-"));
  try {
    const staleDevnetPath = join(dir, "state.json");
    writeFileSync(staleDevnetPath, JSON.stringify({
      schema: "flowmemory.local_devnet.state.v0",
      blocks: [{
        schema: "flowmemory.local_devnet.block.v0",
        blockNumber: "1",
        blockHash: "0x1909a47bfaaabbfe51d371173d550fcdaff1abaedeea1045bfb77a496bdb8695",
        txIds: [],
        receipts: [],
      }],
      tokenDefinitions: {},
      tokenBalances: {},
      dexPools: {},
      lpPositions: {},
      swapReceipts: {},
      bridgeCredits: {},
    }));

    const smoke = runControlPlaneSmoke({
      localDevnetPath: staleDevnetPath,
      txIntakePath: join(dir, "transactions.ndjson"),
      bridgeObservationIntakePath: join(dir, "bridge-observations.ndjson"),
    });

    assert.equal(smoke.schema, "flowmemory.control_plane.smoke.v0");
    assert.equal(smoke.ok, true);
    assert.equal(typeof (smoke.queried as Record<string, unknown>).txId, "string");
    assert.equal(typeof (smoke.queried as Record<string, unknown>).tokenId, "string");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("HTTP server exposes browser-safe health and state endpoints", async () => {
  const server = startControlPlaneServer({ host: "127.0.0.1", port: 0 });

  try {
    await once(server, "listening");
    const address = server.address();
    assert.equal(typeof address, "object");
    assert.notEqual(address, null);
    const port = address?.port;

    const health = await fetch(`http://127.0.0.1:${port}/health`, {
      headers: { Origin: "http://127.0.0.1:5173" },
    });
    assert.equal(health.status, 200);
    assert.equal(health.headers.get("access-control-allow-origin"), "*");
    assert.equal((await health.json()).status, "ok");

    const rpcDiscover = await fetch(`http://127.0.0.1:${port}/rpc/discover`, {
      headers: { Origin: "http://127.0.0.1:5173" },
    });
    assert.equal(rpcDiscover.status, 200);
    assert.equal(rpcDiscover.headers.get("access-control-allow-origin"), "*");
    assert.equal((await rpcDiscover.json()).schema, "flowchain.rpc.discovery.v0");

    const rpcReadiness = await fetch(`http://127.0.0.1:${port}/rpc/readiness`, {
      headers: { Origin: "http://127.0.0.1:5173" },
    });
    assert.equal(rpcReadiness.status, 200);
    assert.equal(rpcReadiness.headers.get("access-control-allow-origin"), "*");
    assert.equal((await rpcReadiness.json()).schema, "flowchain.rpc.readiness.v0");

    const state = await fetch(`http://127.0.0.1:${port}/state`, {
      headers: { Origin: "http://127.0.0.1:5173" },
    });
    assert.equal(state.status, 200);
    assert.equal(state.headers.get("access-control-allow-origin"), "*");
    assert.equal((await state.json()).schema, "flowmemory.control_plane.devnet_state.v0");

    const explorer = await fetch(`http://127.0.0.1:${port}/explorer/summary`, {
      headers: { Origin: "http://127.0.0.1:5173" },
    });
    assert.equal(explorer.status, 200);
    assert.equal(explorer.headers.get("access-control-allow-origin"), "*");
    assert.equal((await explorer.json()).schema, "flowmemory.control_plane.chain_status.v0");

    const productFlow = await fetch(`http://127.0.0.1:${port}/product-flow/status`, {
      headers: { Origin: "http://127.0.0.1:5173" },
    });
    assert.equal(productFlow.status, 200);
    assert.equal(productFlow.headers.get("access-control-allow-origin"), "*");
    assert.equal((await productFlow.json()).schema, "flowmemory.control_plane.product_flow_status.v0");

    const rpc = await fetch(`http://127.0.0.1:${port}/rpc`, {
      method: "POST",
      headers: { "content-type": "application/json", Origin: "http://127.0.0.1:5173" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "node_status" }),
    });
    assert.equal(rpc.status, 200);
    assert.equal(rpc.headers.get("access-control-allow-origin"), "*");
    assert.equal((await rpc.json()).result.schema, "flowmemory.control_plane.node_status.v0");

    const bridge = await fetch(`http://127.0.0.1:${port}/bridge/observations`, {
      headers: { Origin: "http://127.0.0.1:5173" },
    });
    assert.equal(bridge.status, 200);
    assert.equal(bridge.headers.get("access-control-allow-origin"), "*");
    assert.equal((await bridge.json()).schema, "flowmemory.control_plane.bridge_observation_list.v0");

    const pilotDeposits = await fetch(`http://127.0.0.1:${port}/pilot/deposits?limit=1`, {
      headers: { Origin: "http://127.0.0.1:5173" },
    });
    assert.equal(pilotDeposits.status, 200);
    assert.equal(pilotDeposits.headers.get("access-control-allow-origin"), "*");
    const pilotDepositBody = await pilotDeposits.json();
    assert.equal(pilotDepositBody.schema, "flowmemory.control_plane.real_value_pilot_deposit_observation_list.v0");
    assert.equal(pilotDepositBody.count, 1);

    const bridgeReadiness = await fetch(`http://127.0.0.1:${port}/bridge/live-readiness`, {
      headers: { Origin: "http://127.0.0.1:5173" },
    });
    assert.equal(bridgeReadiness.status, 200);
    assert.equal(bridgeReadiness.headers.get("access-control-allow-origin"), "*");
    assert.equal((await bridgeReadiness.json()).schema, "flowmemory.control_plane.bridge_live_readiness.v0");

    const pilotLifecycle = await fetch(`http://127.0.0.1:${port}/pilot/lifecycle?limit=1`, {
      headers: { Origin: "http://127.0.0.1:5173" },
    });
    assert.equal(pilotLifecycle.status, 200);
    assert.equal(pilotLifecycle.headers.get("access-control-allow-origin"), "*");
    assert.equal((await pilotLifecycle.json()).schema, "flowmemory.control_plane.bridge_lifecycle_record_list.v0");

    const walletBalances = await fetch(`http://127.0.0.1:${port}/wallets/balances`, {
      headers: { Origin: "http://127.0.0.1:5173" },
    });
    assert.equal(walletBalances.status, 200);
    assert.equal(walletBalances.headers.get("access-control-allow-origin"), "*");
    assert.equal((await walletBalances.json()).schema, "flowmemory.control_plane.wallet_balance_list.v0");

    const walletTransfers = await fetch(`http://127.0.0.1:${port}/wallets/transfers`, {
      headers: { Origin: "http://127.0.0.1:5173" },
    });
    assert.equal(walletTransfers.status, 200);
    assert.equal(walletTransfers.headers.get("access-control-allow-origin"), "*");
    assert.equal((await walletTransfers.json()).schema, "flowmemory.control_plane.wallet_transfer_history.v0");

    const badPilotDeposits = await fetch(`http://127.0.0.1:${port}/pilot/deposits?limit=0`, {
      headers: { Origin: "http://127.0.0.1:5173" },
    });
    assert.equal(badPilotDeposits.status, 200);
    const badPilotDepositBody = await badPilotDeposits.json();
    assert.equal(badPilotDepositBody.error.data.reasonCode, "params.invalid");
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    });
  }
});

test("HTTP server honors configured CORS origins", async () => {
  const previousOrigins = process.env.FLOWCHAIN_RPC_ALLOWED_ORIGINS;
  process.env.FLOWCHAIN_RPC_ALLOWED_ORIGINS = "http://allowed.example";
  const server = startControlPlaneServer({ host: "127.0.0.1", port: 0 });

  try {
    await once(server, "listening");
    const address = server.address();
    assert.equal(typeof address, "object");
    assert.notEqual(address, null);
    const port = address?.port;

    const allowed = await fetch(`http://127.0.0.1:${port}/health`, {
      headers: { Origin: "http://allowed.example" },
    });
    assert.equal(allowed.status, 200);
    assert.equal(allowed.headers.get("access-control-allow-origin"), "http://allowed.example");

    const rejected = await fetch(`http://127.0.0.1:${port}/health`, {
      headers: { Origin: "http://blocked.example" },
    });
    assert.equal(rejected.status, 403);
    assert.equal(rejected.headers.get("access-control-allow-origin"), null);
    assert.equal((await rejected.json()).schema, "flowmemory.control_plane.cors_rejected.v0");
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    });
    if (previousOrigins === undefined) {
      delete process.env.FLOWCHAIN_RPC_ALLOWED_ORIGINS;
    } else {
      process.env.FLOWCHAIN_RPC_ALLOWED_ORIGINS = previousOrigins;
    }
  }
});

test("HTTP server enforces configured per-client rate limits without trusting spoofed forwarded clients", async () => {
  const previousRateLimit = process.env.FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE;
  process.env.FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE = "1";
  const server = startControlPlaneServer({ host: "127.0.0.1", port: 0 });

  try {
    await once(server, "listening");
    const address = server.address();
    assert.equal(typeof address, "object");
    assert.notEqual(address, null);
    const port = address?.port;
    const edgeConfirmedClient = `198.51.100.${Math.floor(Math.random() * 100) + 1}`;
    const firstRequestHeaders = { "x-forwarded-for": `203.0.113.10, ${edgeConfirmedClient}` };
    const secondRequestHeaders = { "x-forwarded-for": `203.0.113.11, ${edgeConfirmedClient}` };

    const first = await fetch(`http://127.0.0.1:${port}/health`, { headers: firstRequestHeaders });
    assert.equal(first.status, 200);

    const second = await fetch(`http://127.0.0.1:${port}/health`, { headers: secondRequestHeaders });
    assert.equal(second.status, 429);
    assert.equal(second.headers.get("retry-after") !== null, true);
    const body = await second.json() as JsonObject;
    assert.equal(body.schema, "flowmemory.control_plane.rate_limited.v0");
    assert.equal(body.envValuesPrinted, false);
    assert.equal(JSON.stringify(body).includes("FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE"), false);
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    });
    if (previousRateLimit === undefined) {
      delete process.env.FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE;
    } else {
      process.env.FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE = previousRateLimit;
    }
  }
});

test("HTTP server rejects abusive public RPC POST shapes before dispatch", async () => {
  const server = startControlPlaneServer({ host: "127.0.0.1", port: 0 });

  try {
    await once(server, "listening");
    const address = server.address();
    assert.equal(typeof address, "object");
    assert.notEqual(address, null);
    const baseUrl = `http://127.0.0.1:${address?.port}`;
    const origin = "http://127.0.0.1:5173";

    const unsupported = await fetch(`${baseUrl}/rpc`, {
      method: "POST",
      headers: { "content-type": "text/plain", Origin: origin },
      body: "not-json",
    });
    assert.equal(unsupported.status, 415);
    const unsupportedBody = await unsupported.json() as JsonObject;
    assert.equal(unsupportedBody.schema, "flowmemory.control_plane.unsupported_media_type.v0");
    assert.equal(unsupportedBody.reasonCode, "request.unsupported_media_type");
    assert.equal(unsupportedBody.noSecrets, true);

    const malformed = await fetch(`${baseUrl}/rpc`, {
      method: "POST",
      headers: { "content-type": "application/json", Origin: origin },
      body: "{",
    });
    assert.equal(malformed.status, 400);
    const malformedBody = await malformed.json() as JsonObject;
    const malformedError = malformedBody.error as JsonObject;
    const malformedData = malformedError.data as JsonObject;
    assert.equal(malformedBody.jsonrpc, "2.0");
    assert.equal(malformedBody.id, null);
    assert.equal(malformedError.code, -32700);
    assert.equal(malformedData.schema, "flowmemory.control_plane.error.v0");
    assert.equal(malformedData.reasonCode, "parse.error");
    assert.equal(malformedData.noSecrets, true);

    for (const method of ["transaction_submit", "bridge_observation_submit", "raw_json_get", "devnet_state", "flow_sendRawTransaction"]) {
      const blocked = await fetch(`${baseUrl}/rpc`, {
        method: "POST",
        headers: { "content-type": "application/json", Origin: origin },
        body: JSON.stringify({ jsonrpc: "2.0", id: method, method, params: { source: "launchCore" } }),
      });
      assert.equal(blocked.status, 200);
      const blockedBody = await blocked.json() as JsonObject;
      const blockedError = blockedBody.error as JsonObject;
      const blockedData = blockedError.data as JsonObject;
      assert.equal(blockedError.code, -32601);
      assert.equal(blockedData.reasonCode, "method.not_found");
      assert.equal(blockedData.noSecrets, true);
    }

    const bridgeObservationPostAlias = await fetch(`${baseUrl}/bridge/observations`, {
      method: "POST",
      headers: { "content-type": "application/json", Origin: origin },
      body: JSON.stringify({ observationId: "public-http-abuse" }),
    });
    assert.equal(bridgeObservationPostAlias.status, 200);
    const bridgeObservationPostAliasBody = await bridgeObservationPostAlias.json() as JsonObject;
    assert.equal(((bridgeObservationPostAliasBody.error as JsonObject).data as JsonObject).reasonCode, "method.not_found");

    const emptyBatch = await fetch(`${baseUrl}/rpc`, {
      method: "POST",
      headers: { "content-type": "application/json", Origin: origin },
      body: "[]",
    });
    assert.equal(emptyBatch.status, 400);
    const emptyBatchBody = await emptyBatch.json() as JsonObject;
    assert.equal(((emptyBatchBody.error as JsonObject).data as JsonObject).reasonCode, "request.batch_empty");

    const oversizedBatchPayload = Array.from({ length: 51 }, (_, index) => ({
      jsonrpc: "2.0",
      id: index,
      method: "health",
    }));
    const oversizedBatch = await fetch(`${baseUrl}/rpc`, {
      method: "POST",
      headers: { "content-type": "application/json", Origin: origin },
      body: JSON.stringify(oversizedBatchPayload),
    });
    assert.equal(oversizedBatch.status, 413);
    const oversizedBatchBody = await oversizedBatch.json() as JsonObject;
    const oversizedBatchData = (oversizedBatchBody.error as JsonObject).data as JsonObject;
    assert.equal(oversizedBatchData.reasonCode, "request.batch_too_large");
    assert.equal(oversizedBatchData.maxBatchRequests, 50);

    const oversizedBody = await fetch(`${baseUrl}/rpc`, {
      method: "POST",
      headers: { "content-type": "application/json", Origin: origin },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        method: "health",
        params: { padding: "x".repeat(300_000) },
      }),
    });
    assert.equal(oversizedBody.status, 413);
    const oversizedBodyJson = await oversizedBody.json() as JsonObject;
    assert.equal(oversizedBodyJson.schema, "flowmemory.control_plane.payload_too_large.v0");
    assert.equal(oversizedBodyJson.reasonCode, "request.payload_too_large");
    assert.equal(oversizedBodyJson.noSecrets, true);

    const notification = await fetch(`${baseUrl}/rpc`, {
      method: "POST",
      headers: { "content-type": "application/json", Origin: origin },
      body: JSON.stringify({ jsonrpc: "2.0", method: "health" }),
    });
    assert.equal(notification.status, 204);
    assert.equal(await notification.text(), "");
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    });
  }
});

test("control-plane cargo target override must stay inside the repository", () => {
  const previousTarget = process.env.FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR;
  process.env.FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR = tmpdir();

  try {
    assert.throws(
      () => spawnCargoSync(["--version"], { cwd: process.cwd(), encoding: "utf8", windowsHide: true }),
      /FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR must stay inside the repository/,
    );
  } finally {
    if (previousTarget === undefined) {
      delete process.env.FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR;
    } else {
      process.env.FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR = previousTarget;
    }
  }
});

test("HTTP server creates local encrypted wallet metadata without returning secret material", async () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-wallet-http-"));
  const previousMetadataPath = process.env.FLOWCHAIN_CONTROL_PLANE_WALLET_PUBLIC_METADATA_PATH;
  process.env.FLOWCHAIN_CONTROL_PLANE_WALLET_PUBLIC_METADATA_PATH = join(dir, "flowchain-operator-public-metadata.json");
  const server = startControlPlaneServer({ host: "127.0.0.1", port: 0 });

  try {
    await once(server, "listening");
    const address = server.address();
    assert.equal(typeof address, "object");
    assert.notEqual(address, null);
    const port = address?.port;

    const create = await fetch(`http://127.0.0.1:${port}/wallets/create`, {
      method: "POST",
      headers: { "content-type": "application/json", Origin: "http://127.0.0.1:5173" },
      body: JSON.stringify({
        label: "operator-test-wallet",
        password: "local-test-wallet-passphrase",
        chainId: "31337",
        replace: true,
      }),
    });
    assert.equal(create.status, 200);
    assert.equal(create.headers.get("access-control-allow-origin"), "*");
    const created = await create.json() as JsonObject;
    assert.equal(created.schema, "flowmemory.control_plane.local_wallet_create_result.v0");
    assert.equal(created.created, true);
    assert.equal(created.secretMaterialReturned, false);
    assert.equal((created.account as JsonObject).keyScheme, "secp256k1");
    assert.equal(JSON.stringify(created).includes("privateKey"), false);
    assert.equal(JSON.stringify(created).includes("ciphertext"), false);
    assert.equal(JSON.stringify(created).includes("local-test-wallet-passphrase"), false);

    const status = await fetch(`http://127.0.0.1:${port}/wallets/operator`, {
      headers: { Origin: "http://127.0.0.1:5173" },
    });
    assert.equal(status.status, 200);
    const body = await status.json() as JsonObject;
    assert.equal(body.exists, true);
    assert.equal((body.account as JsonObject).accountId, (created.account as JsonObject).accountId);

    const testerA = await fetch(`http://127.0.0.1:${port}/wallets/create`, {
      method: "POST",
      headers: { "content-type": "application/json", Origin: "http://127.0.0.1:5173" },
      body: JSON.stringify({
        label: "tester-a",
        password: "local-test-wallet-passphrase-a",
        chainId: "31337",
        replace: true,
        isolated: true,
      }),
    });
    const testerB = await fetch(`http://127.0.0.1:${port}/wallets/create`, {
      method: "POST",
      headers: { "content-type": "application/json", Origin: "http://127.0.0.1:5173" },
      body: JSON.stringify({
        label: "tester-b",
        password: "local-test-wallet-passphrase-b",
        chainId: "31337",
        replace: true,
        isolated: true,
      }),
    });
    assert.equal(testerA.status, 200);
    assert.equal(testerB.status, 200);
    const testerABody = await testerA.json() as JsonObject;
    const testerBBody = await testerB.json() as JsonObject;
    assert.equal(testerABody.schema, "flowmemory.control_plane.local_wallet_create_result.v0");
    assert.equal(testerBBody.schema, "flowmemory.control_plane.local_wallet_create_result.v0");
    assert.equal(testerABody.isolated, true);
    assert.equal(testerBBody.isolated, true);
    assert.notEqual((testerABody.account as JsonObject).accountId, (testerBBody.account as JsonObject).accountId);
    assert.equal(JSON.stringify(testerABody).includes("privateKey"), false);
    assert.equal(JSON.stringify(testerBBody).includes("ciphertext"), false);
    assert.equal(JSON.stringify(testerABody).includes("local-test-wallet-passphrase-a"), false);
    assert.equal(JSON.stringify(testerBBody).includes("local-test-wallet-passphrase-b"), false);
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    });
    if (previousMetadataPath === undefined) {
      delete process.env.FLOWCHAIN_CONTROL_PLANE_WALLET_PUBLIC_METADATA_PATH;
    } else {
      process.env.FLOWCHAIN_CONTROL_PLANE_WALLET_PUBLIC_METADATA_PATH = previousMetadataPath;
    }
    rmSync(dir, { recursive: true, force: true });
  }
});

test("HTTP tester write gateway requires bearer auth, caps sends, and returns public-only wallet data", async () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-tester-gateway-"));
  const previousMetadataPath = process.env.FLOWCHAIN_CONTROL_PLANE_WALLET_PUBLIC_METADATA_PATH;
  const previousLocalDevnetPath = process.env.FLOWCHAIN_CONTROL_PLANE_LOCAL_DEVNET_PATH;
  const previousTesterWriteEnabled = process.env.FLOWCHAIN_TESTER_WRITE_ENABLED;
  const previousTesterTokenHash = process.env.FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256;
  const previousTesterMaxSendUnits = process.env.FLOWCHAIN_TESTER_MAX_SEND_UNITS;
  const testerToken = "local-tester-write-token";
  const localDevnetPath = join(dir, "state.json");
  const localNodeDir = join(dir, "node");
  process.env.FLOWCHAIN_CONTROL_PLANE_WALLET_PUBLIC_METADATA_PATH = join(dir, "flowchain-operator-public-metadata.json");
  process.env.FLOWCHAIN_CONTROL_PLANE_LOCAL_DEVNET_PATH = localDevnetPath;
  process.env.FLOWCHAIN_TESTER_WRITE_ENABLED = "true";
  process.env.FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256 = createHash("sha256").update(testerToken, "utf8").digest("hex");
  process.env.FLOWCHAIN_TESTER_MAX_SEND_UNITS = "2";
  const init = spawnCargoSync([
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    localDevnetPath,
    "--node-dir",
    localNodeDir,
    "init",
  ], { cwd: repoRoot(), encoding: "utf8", windowsHide: true });
  assert.equal(init.status, 0, init.stderr);
  const server = startControlPlaneServer({ host: "127.0.0.1", port: 0 });

  try {
    await once(server, "listening");
    const address = server.address();
    assert.equal(typeof address, "object");
    assert.notEqual(address, null);
    const baseUrl = `http://127.0.0.1:${address?.port}`;

    const status = await fetch(`${baseUrl}/tester/status`);
    assert.equal(status.status, 200);
    const statusBody = await status.json() as JsonObject;
    assert.equal(statusBody.schema, "flowmemory.control_plane.tester_write_status.v0");
    assert.equal(statusBody.configured, true);
    assert.equal(statusBody.tokenHashConfigured, true);
    assert.equal(statusBody.maxSendUnits, "2");
    assert.equal(JSON.stringify(statusBody).includes(testerToken), false);
    assert.equal(JSON.stringify(statusBody).includes(process.env.FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256), false);

    const unauthenticated = await fetch(`${baseUrl}/tester/wallets/create`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ label: "tester-public-a", password: "local-test-wallet-passphrase-a", replace: true }),
    });
    assert.equal(unauthenticated.status, 401);
    const unauthenticatedBody = await unauthenticated.json() as JsonObject;
    assert.equal(unauthenticatedBody.schema, "flowmemory.control_plane.tester_write_auth_required.v0");
    assert.equal(unauthenticatedBody.noSecrets, true);

    const rejected = await fetch(`${baseUrl}/tester/wallets/create`, {
      method: "POST",
      headers: { "content-type": "application/json", authorization: "Bearer wrong-token" },
      body: JSON.stringify({ label: "tester-public-a", password: "local-test-wallet-passphrase-a", replace: true }),
    });
    assert.equal(rejected.status, 403);
    const rejectedBody = await rejected.json() as JsonObject;
    assert.equal(rejectedBody.schema, "flowmemory.control_plane.tester_write_auth_rejected.v0");
    assert.equal(rejectedBody.noSecrets, true);

    const create = await fetch(`${baseUrl}/tester/wallets/create`, {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${testerToken}` },
      body: JSON.stringify({ label: "tester-public-a", password: "local-test-wallet-passphrase-a", replace: true }),
    });
    assert.equal(create.status, 200);
    const created = await create.json() as JsonObject;
    assert.equal(created.schema, "flowmemory.control_plane.tester_wallet_create_result.v0");
    assert.equal(created.secretMaterialReturned, false);
    assert.equal(created.credentialStored, false);
    assert.equal(created.noSecrets, true);
    assert.equal(created.isolated, true);
    assert.equal((created.account as JsonObject).keyScheme, "secp256k1");
    assert.equal(JSON.stringify(created).includes("vaultPath"), false);
    assert.equal(JSON.stringify(created).includes("metadataPath"), false);
    assert.equal(JSON.stringify(created).includes("privateKey"), false);
    assert.equal(JSON.stringify(created).includes("ciphertext"), false);
    assert.equal(JSON.stringify(created).includes("local-test-wallet-passphrase-a"), false);
    assert.equal(JSON.stringify(created).includes(testerToken), false);
    const createdAccount = created.account as JsonObject;
    const accountId = String(createdAccount.accountId);

    const faucet = await fetch(`${baseUrl}/tester/faucet`, {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${testerToken}` },
      body: JSON.stringify({
        accountId,
        amountUnits: "2",
        reason: "control-plane-tester-gateway-test",
      }),
    });
    assert.equal(faucet.status, 200);
    const faucetBody = await faucet.json() as JsonObject;
    assert.equal(faucetBody.schema, "flowmemory.control_plane.tester_faucet_result.v0");
    assert.equal(faucetBody.accepted, true);
    assert.equal(faucetBody.noSecrets, true);
    assert.equal(JSON.stringify(faucetBody).includes(testerToken), false);

    const send = await fetch(`${baseUrl}/tester/wallets/send`, {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${testerToken}` },
      body: JSON.stringify({
        fromAccountId: accountId,
        toAccountId: "local-account:tester-recipient",
        amountUnits: "1",
        memo: "tester-send-test",
        createRecipient: true,
      }),
    });
    assert.equal(send.status, 200);
    const sendBody = await send.json() as JsonObject;
    assert.equal(sendBody.schema, "flowmemory.control_plane.tester_wallet_send_result.v0");
    assert.equal(sendBody.accepted, true);
    assert.equal(sendBody.noSecrets, true);

    const overCap = await fetch(`${baseUrl}/tester/wallets/send`, {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${testerToken}` },
      body: JSON.stringify({
        fromAccountId: "local-account:tester-a",
        toAccountId: "local-account:tester-b",
        amountUnits: "3",
        memo: "cap-test",
      }),
    });
    assert.equal(overCap.status, 400);
    const overCapBody = await overCap.json() as JsonObject;
    assert.equal(overCapBody.schema, "flowmemory.control_plane.tester_wallet_send_error.v0");
    assert.equal(overCapBody.accepted, false);
    assert.equal(overCapBody.noSecrets, true);
    assert.equal(String(overCapBody.message).includes("FLOWCHAIN_TESTER_MAX_SEND_UNITS"), true);
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    });
    if (previousMetadataPath === undefined) {
      delete process.env.FLOWCHAIN_CONTROL_PLANE_WALLET_PUBLIC_METADATA_PATH;
    } else {
      process.env.FLOWCHAIN_CONTROL_PLANE_WALLET_PUBLIC_METADATA_PATH = previousMetadataPath;
    }
    if (previousLocalDevnetPath === undefined) {
      delete process.env.FLOWCHAIN_CONTROL_PLANE_LOCAL_DEVNET_PATH;
    } else {
      process.env.FLOWCHAIN_CONTROL_PLANE_LOCAL_DEVNET_PATH = previousLocalDevnetPath;
    }
    if (previousTesterWriteEnabled === undefined) {
      delete process.env.FLOWCHAIN_TESTER_WRITE_ENABLED;
    } else {
      process.env.FLOWCHAIN_TESTER_WRITE_ENABLED = previousTesterWriteEnabled;
    }
    if (previousTesterTokenHash === undefined) {
      delete process.env.FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256;
    } else {
      process.env.FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256 = previousTesterTokenHash;
    }
    if (previousTesterMaxSendUnits === undefined) {
      delete process.env.FLOWCHAIN_TESTER_MAX_SEND_UNITS;
    } else {
      process.env.FLOWCHAIN_TESTER_MAX_SEND_UNITS = previousTesterMaxSendUnits;
    }
    rmSync(dir, { recursive: true, force: true });
  }
});
