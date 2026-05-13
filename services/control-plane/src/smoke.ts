import { fileURLToPath } from "node:url";

import { dispatchJsonRpc } from "./json-rpc.ts";
import { loadControlPlaneState } from "./fixture-state.ts";
import type { JsonObject, RpcErrorResponse, RpcSuccessResponse } from "./types.ts";

function firstDevnetBlock(state: ReturnType<typeof loadControlPlaneState>): JsonObject {
  const blocks = Array.isArray(state.devnet?.blocks) ? state.devnet.blocks : [];
  const block = blocks[0];
  if (block === null || typeof block !== "object" || Array.isArray(block)) {
    throw new Error("control-plane smoke requires at least one local devnet block");
  }
  return block as JsonObject;
}

function stringField(value: unknown, name: string): string {
  if (typeof value !== "string" && typeof value !== "number") {
    throw new Error(`control-plane smoke missing ${name}`);
  }
  return String(value);
}

export function runControlPlaneSmoke(): JsonObject {
  const state = loadControlPlaneState();
  const rootfieldId = state.launchCore.rootfieldBundles[0]?.rootfieldId;
  const receipt = state.launchCore.memoryReceipts[0];
  const reportId = receipt?.reportId;
  const artifactUri = receipt?.evidenceRefs[0]?.uri;
  const block = firstDevnetBlock(state);
  const txIds = Array.isArray(block.txIds) ? block.txIds : [];
  const txId = stringField(txIds[0], "devnet txId");

  if (rootfieldId === undefined || receipt === undefined || reportId === undefined || artifactUri === undefined) {
    throw new Error("control-plane smoke requires launch-core rootfield, receipt, report, and artifact fixture data");
  }

  const requests = [
    { jsonrpc: "2.0", id: "health", method: "health" },
    { jsonrpc: "2.0", id: "chain", method: "chain_status" },
    { jsonrpc: "2.0", id: "devnet", method: "devnet_state", params: { includeBlocks: true } },
    { jsonrpc: "2.0", id: "blocks", method: "block_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "block", method: "block_get", params: { blockNumber: stringField(block.blockNumber, "blockNumber"), includeTransactions: true } },
    { jsonrpc: "2.0", id: "transactions", method: "transaction_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "transaction", method: "transaction_get", params: { txId } },
    { jsonrpc: "2.0", id: "rootfields", method: "rootfield_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "rootfield", method: "rootfield_get", params: { rootfieldId } },
    { jsonrpc: "2.0", id: "agents", method: "agent_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "agent", method: "agent_get", params: { rootfieldId } },
    { jsonrpc: "2.0", id: "models", method: "model_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "model", method: "model_get", params: { rootfieldId } },
    { jsonrpc: "2.0", id: "workReceipts", method: "work_receipt_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "workReceipt", method: "work_receipt_get", params: { receiptId: receipt.receiptId } },
    { jsonrpc: "2.0", id: "artifactAvailability", method: "artifact_availability_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "artifact", method: "artifact_availability_get", params: { uri: artifactUri } },
    { jsonrpc: "2.0", id: "modules", method: "verifier_module_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "module", method: "verifier_module_get", params: { resolverPolicyId: receipt.resolverPolicyId } },
    { jsonrpc: "2.0", id: "reports", method: "verifier_report_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "report", method: "verifier_report_get", params: { reportId } },
    { jsonrpc: "2.0", id: "receipts", method: "receipt_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "receipt", method: "receipt_get", params: { receiptId: receipt.receiptId } },
    { jsonrpc: "2.0", id: "memoryCells", method: "memory_cell_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "memoryCell", method: "memory_cell_get", params: { rootfieldId } },
    { jsonrpc: "2.0", id: "challenges", method: "challenge_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "challenge", method: "challenge_get", params: { receiptId: receipt.receiptId } },
    { jsonrpc: "2.0", id: "finalityList", method: "finality_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "finality", method: "finality_get", params: { receiptId: receipt.receiptId } },
    { jsonrpc: "2.0", id: "provenance", method: "provenance_get", params: { receiptId: receipt.receiptId } },
    { jsonrpc: "2.0", id: "raw", method: "raw_json_get", params: { source: "launchCore" } },
  ] as const;

  const response = dispatchJsonRpc([...requests], { state });
  if (!Array.isArray(response)) {
    throw new Error("control-plane smoke expected batch JSON-RPC response");
  }

  const errors = response.filter((entry): entry is RpcErrorResponse => "error" in entry);
  if (errors.length > 0) {
    throw new Error(`control-plane smoke failed: ${JSON.stringify(errors, null, 2)}`);
  }

  const successes = response as RpcSuccessResponse[];
  return {
    schema: "flowmemory.control_plane.smoke.v0",
    ok: true,
    methodCount: requests.length,
    responseSchemas: successes.map((entry) => (entry.result as JsonObject).schema),
    queried: {
      rootfieldId,
      receiptId: receipt.receiptId,
      reportId,
      artifactUri,
      blockNumber: stringField(block.blockNumber, "blockNumber"),
      txId,
    },
    localOnly: true,
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  console.log(JSON.stringify(runControlPlaneSmoke(), null, 2));
}
