import { fileURLToPath } from "node:url";

import { dispatchJsonRpc } from "./json-rpc.ts";
import { loadControlPlaneState } from "./fixture-state.ts";

export function runDemo(): unknown {
  const state = loadControlPlaneState();
  const rootfieldId = state.launchCore.rootfieldBundles[0]?.rootfieldId;
  const receiptId = state.launchCore.memoryReceipts[0]?.receiptId;
  const reportId = state.launchCore.memoryReceipts[0]?.reportId;
  const artifactUri = state.launchCore.memoryReceipts[0]?.evidenceRefs[0]?.uri;

  return dispatchJsonRpc([
    { jsonrpc: "2.0", id: 1, method: "health" },
    { jsonrpc: "2.0", id: 2, method: "chain_status" },
    { jsonrpc: "2.0", id: 3, method: "block_list", params: { limit: 3 } },
    { jsonrpc: "2.0", id: 4, method: "transaction_list", params: { limit: 3 } },
    { jsonrpc: "2.0", id: 5, method: "rootfield_get", params: { rootfieldId } },
    { jsonrpc: "2.0", id: 6, method: "receipt_get", params: { receiptId } },
    { jsonrpc: "2.0", id: 7, method: "verifier_report_get", params: { reportId } },
    { jsonrpc: "2.0", id: 8, method: "artifact_availability_get", params: { uri: artifactUri } },
    { jsonrpc: "2.0", id: 9, method: "provenance_get", params: { receiptId } },
  ], { state });
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  console.log(JSON.stringify(runDemo(), null, 2));
}
