import assert from "node:assert/strict";
import { once } from "node:events";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { canonicalJson } from "../../shared/src/index.ts";
import {
  dispatchJsonRpc,
  loadControlPlaneState,
  type RpcErrorResponse,
  type RpcSuccessResponse,
} from "../src/index.ts";
import { startControlPlaneServer } from "../src/server.ts";
import { runControlPlaneSmoke } from "../src/smoke.ts";

test("dispatches JSON-RPC methods against local fixture state", () => {
  const response = dispatchJsonRpc({ jsonrpc: "2.0", id: "status", method: "chain_status" }) as RpcSuccessResponse;

  assert.equal(response.jsonrpc, "2.0");
  assert.equal(response.id, "status");
  assert.equal(response.result.schema, "flowmemory.control_plane.chain_status.v0");
  assert.equal(response.result.localOnly, true);
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
  assert.equal(
    snapshot(first),
    "{\"capabilities\":[\"health_reads\",\"node_status_reads\",\"peer_reads\",\"local_runtime_status_reads\",\"block_reads\",\"transaction_reads\",\"local_transaction_file_intake\",\"mempool_reads\",\"account_reads\",\"balance_reads\",\"faucet_event_reads\",\"wallet_public_metadata_reads\",\"token_reads\",\"token_balance_reads\",\"dex_pool_reads\",\"lp_position_reads\",\"swap_reads\",\"product_flow_status_reads\",\"receipt_lookup\",\"verifier_report_lookup\",\"memory_lineage_lookup\",\"artifact_fixture_lookup\",\"bridge_observation_file_intake\",\"bridge_deposit_reads\",\"bridge_credit_reads\",\"withdrawal_reads\",\"devnet_handoff_reads\",\"no_secret_response_checks\",\"raw_json_reads\"],\"chainId\":\"flowmemory-local-devnet-v0\",\"counts\":{\"accounts\":2,\"agents\":2,\"artifactAvailability\":5,\"balances\":2,\"blocks\":11,\"bridgeCredits\":1,\"bridgeDeposits\":1,\"challenges\":1,\"devnetBlocks\":2,\"duplicates\":1,\"faucetEvents\":1,\"finalityRows\":9,\"lpPositions\":0,\"memoryCells\":1,\"memoryReceipts\":8,\"memorySignals\":8,\"mempool\":0,\"models\":2,\"observations\":8,\"pools\":0,\"rejectedLogs\":2,\"rootfields\":2,\"swaps\":0,\"tokenBalances\":1,\"tokens\":1,\"transactions\":25,\"verifierModules\":3,\"verifierReports\":8,\"walletPublicMetadata\":2,\"withdrawals\":1,\"workReceipts\":9},\"schema\":\"flowmemory.control_plane.chain_status.v0\"}",
  );
  rmSync(dir, { recursive: true, force: true });
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
    assert.equal(response.result.counts.observations, 8);
    assert.equal(response.result.counts.verifierReports, 8);
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
          signedEnvelope: {
            schema: "flowmemory.test_signed_envelope.v0",
            tx: {
              schema: "flowmemory.test_transaction.v0",
              action: "test",
            },
            signature: "0xtest-signature",
          },
        },
      },
      { state },
    ) as RpcSuccessResponse;
    const mempool = dispatchJsonRpc({ jsonrpc: "2.0", id: 2, method: "mempool_list" }, { state }) as RpcSuccessResponse;

    assert.equal(response.result.accepted, true);
    assert.equal(mempool.result.count, 1);
    assert.equal(mempool.result.transactions[0].source, "local-file-intake");
    assert.equal(mempool.result.transactions[0].transaction.action, "test");
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
  const withdrawals = dispatchJsonRpc({ jsonrpc: "2.0", id: 4, method: "withdrawal_list" }, { state }) as RpcSuccessResponse;
  const withdrawalId = withdrawals.result.withdrawals[0].withdrawalId as string;

  assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 5, method: "account_get", params: { accountId } }, { state }) as RpcSuccessResponse).result.schema, "flowmemory.control_plane.account_detail.v0");
  assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 6, method: "wallet_metadata_get", params: { walletId: accountId } }, { state }) as RpcSuccessResponse).result.schema, "flowmemory.control_plane.wallet_public_metadata_detail.v0");
  assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 7, method: "balance_get", params: { accountId } }, { state }) as RpcSuccessResponse).result.noValue, true);
  assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 8, method: "bridge_deposit_get", params: { depositId } }, { state }) as RpcSuccessResponse).result.schema, "flowmemory.control_plane.bridge_deposit_detail.v0");
  assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 9, method: "bridge_credit_get", params: { creditId } }, { state }) as RpcSuccessResponse).result.schema, "flowmemory.control_plane.bridge_credit_detail.v0");
  assert.equal((dispatchJsonRpc({ jsonrpc: "2.0", id: 10, method: "withdrawal_get", params: { withdrawalId } }, { state }) as RpcSuccessResponse).result.schema, "flowmemory.control_plane.withdrawal_detail.v0");
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
            schema: "flowmemory.test_signed_envelope.v0",
            tx: {
              schema: "flowmemory.test_transaction.v0",
              action: "test",
            },
            signature: "0xtest-signature",
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

test("smoke client queries the complete local lifecycle surface", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-smoke-"));
  const smoke = runControlPlaneSmoke({
    txIntakePath: join(dir, "transactions.ndjson"),
    bridgeObservationIntakePath: join(dir, "bridge-observations.ndjson"),
  });

  assert.equal(smoke.schema, "flowmemory.control_plane.smoke.v0");
  assert.equal(smoke.ok, true);
  assert.equal(smoke.methodCount, 57);
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
    }));

    const smoke = runControlPlaneSmoke({
      localDevnetPath: staleDevnetPath,
      txIntakePath: join(dir, "transactions.ndjson"),
      bridgeObservationIntakePath: join(dir, "bridge-observations.ndjson"),
    });

    assert.equal(smoke.schema, "flowmemory.control_plane.smoke.v0");
    assert.equal(smoke.ok, true);
    assert.equal(typeof (smoke.queried as Record<string, unknown>).txId, "string");
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
