import assert from "node:assert/strict";
import { once } from "node:events";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { canonicalJson } from "../../shared/src/index.ts";
import {
  dispatchJsonRpc,
  loadControlPlaneState,
  scanJsonForSecrets,
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
  const first = dispatchJsonRpc({ jsonrpc: "2.0", id: 1, method: "chain_status" }) as RpcSuccessResponse;
  const second = dispatchJsonRpc({ jsonrpc: "2.0", id: 2, method: "chain_status" }) as RpcSuccessResponse;
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
  assert.equal(first.result.chainId, "flowmemory-local-devnet-v0");
  assert.ok((first.result.capabilities as string[]).includes("live_local_state_reads"));
  assert.ok((first.result.capabilities as string[]).includes("transaction_submission"));
  assert.ok((first.result.capabilities as string[]).includes("bridge_observation_intake"));
  assert.equal(first.result.counts.observations, 8);
  assert.ok(first.result.counts.bridgeDeposits >= 1);
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

test("smoke client queries the complete local lifecycle surface", () => {
  const smoke = runControlPlaneSmoke();

  assert.equal(smoke.schema, "flowmemory.control_plane.smoke.v0");
  assert.equal(smoke.ok, true);
  assert.equal(smoke.methodCount, 57);
  assert.equal(smoke.noSecretResponseScan, "passed");
  assert.ok((smoke.responseSchemas as string[]).includes("flowmemory.control_plane.raw_json.v0"));
});

test("detects secret-bearing response keys", () => {
  const findings = scanJsonForSecrets({
    schema: "test",
    privateKey: "not-allowed",
  });

  assert.equal(findings.length, 1);
  assert.equal(findings[0]?.reason, "forbidden secret-bearing key");
});

test("rejects transaction submissions with secret-bearing fields", () => {
  const response = dispatchJsonRpc({
    jsonrpc: "2.0",
    id: 1,
    method: "transaction_submit",
    params: {
      tx: {
        type: "RegisterRootfield",
        privateKey: "not-allowed",
      },
    },
  }) as RpcErrorResponse;

  assert.equal(response.error.code, -32602);
  assert.equal(response.error.data.reasonCode, "params.invalid");
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

    const node = await fetch(`http://127.0.0.1:${port}/node/status`, {
      headers: { Origin: "http://127.0.0.1:5173" },
    });
    assert.equal(node.status, 200);
    assert.equal(node.headers.get("access-control-allow-origin"), "*");
    assert.equal((await node.json()).schema, "flowmemory.control_plane.node_status.v0");

    const deposits = await fetch(`http://127.0.0.1:${port}/bridge/deposits?limit=1`, {
      headers: { Origin: "http://127.0.0.1:5173" },
    });
    assert.equal(deposits.status, 200);
    assert.equal(deposits.headers.get("access-control-allow-origin"), "*");
    assert.equal((await deposits.json()).schema, "flowmemory.control_plane.bridge_deposit_list.v0");
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
