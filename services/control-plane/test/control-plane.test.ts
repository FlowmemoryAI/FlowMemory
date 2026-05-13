import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
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
  assert.equal(
    snapshot(first),
    "{\"capabilities\":[\"health_reads\",\"fixture_status_reads\",\"block_reads\",\"transaction_reads\",\"receipt_lookup\",\"verifier_report_lookup\",\"memory_lineage_lookup\",\"artifact_fixture_lookup\",\"devnet_handoff_reads\",\"raw_json_reads\"],\"chainId\":\"flowmemory-local-alpha\",\"counts\":{\"agents\":2,\"artifactAvailability\":5,\"blocks\":11,\"challenges\":1,\"devnetBlocks\":2,\"duplicates\":1,\"finalityRows\":9,\"memoryCells\":1,\"memoryReceipts\":8,\"memorySignals\":8,\"models\":2,\"observations\":8,\"rejectedLogs\":2,\"rootfields\":2,\"transactions\":23,\"verifierModules\":3,\"verifierReports\":8,\"workReceipts\":9},\"schema\":\"flowmemory.control_plane.chain_status.v0\"}",
  );
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
  assert.equal(smoke.methodCount, 31);
  assert.ok((smoke.responseSchemas as string[]).includes("flowmemory.control_plane.raw_json.v0"));
});
