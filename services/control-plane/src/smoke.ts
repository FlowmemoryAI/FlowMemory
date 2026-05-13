import { fileURLToPath } from "node:url";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { dispatchJsonRpc } from "./json-rpc.ts";
import { loadControlPlaneState } from "./fixture-state.ts";
import { assertNoSecrets } from "./no-secret.ts";
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
  const tempDir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-smoke-"));
  const rootfieldId = state.launchCore.rootfieldBundles[0]?.rootfieldId;
  const receipt = state.launchCore.memoryReceipts[0];
  const reportId = receipt?.reportId;
  const artifactUri = receipt?.evidenceRefs[0]?.uri;
  const block = firstDevnetBlock(state);
  const txIds = Array.isArray(block.txIds) ? block.txIds : [];
  const txId = stringField(txIds[0], "devnet txId");
  const walletId = Object.keys((state.devnet?.operatorKeyReferences ?? {}) as Record<string, unknown>)[0];
  const agentId = Object.keys((state.devnet?.agentAccounts ?? {}) as Record<string, unknown>)[0];
  const modelId = Object.keys((state.devnet?.modelPassports ?? {}) as Record<string, unknown>)[0];
  const memoryCellId = Object.keys((state.devnet?.memoryCells ?? {}) as Record<string, unknown>)[0];
  const challengeId = Object.keys((state.devnet?.challenges ?? {}) as Record<string, unknown>)[0];
  const finalityReceiptId = Object.keys((state.devnet?.finalityReceipts ?? {}) as Record<string, unknown>)[0];
  const bridgeDepositId = typeof state.bridgeDepositFixture?.depositId === "string" ? state.bridgeDepositFixture.depositId : undefined;

  if (
    rootfieldId === undefined
    || receipt === undefined
    || reportId === undefined
    || artifactUri === undefined
    || walletId === undefined
    || agentId === undefined
    || modelId === undefined
    || memoryCellId === undefined
    || challengeId === undefined
    || finalityReceiptId === undefined
    || bridgeDepositId === undefined
  ) {
    throw new Error("control-plane smoke requires launch-core rootfield, receipt, report, and artifact fixture data");
  }

  try {
    const requests = [
      { jsonrpc: "2.0", id: "health", method: "health" },
      { jsonrpc: "2.0", id: "chain", method: "chain_status" },
      { jsonrpc: "2.0", id: "node", method: "node_status" },
      { jsonrpc: "2.0", id: "peers", method: "peer_list" },
      { jsonrpc: "2.0", id: "mempool", method: "mempool_list", params: { limit: 10 } },
      { jsonrpc: "2.0", id: "devnet", method: "devnet_state", params: { includeBlocks: true } },
      { jsonrpc: "2.0", id: "blocks", method: "block_list", params: { limit: 10 } },
      { jsonrpc: "2.0", id: "block", method: "block_get", params: { blockNumber: stringField(block.blockNumber, "blockNumber"), includeTransactions: true } },
      { jsonrpc: "2.0", id: "transactions", method: "transaction_list", params: { limit: 10 } },
      { jsonrpc: "2.0", id: "transaction", method: "transaction_get", params: { txId } },
      { jsonrpc: "2.0", id: "transactionSubmit", method: "transaction_submit", params: { tx: { type: "RegisterRootfield", rootfieldId: "rootfield:smoke:queued-only", owner: "operator:smoke", schemaHash: "0x0d05a0ad7f9c8650e1f9b6f92a9714d7e9b7c29fcd067a8e3d48ccf8a84d1e7a", metadataHash: "0x2b49f44f3d7f2a97970cc7ee3cb3cb9e5db4c4ab65f9fd797f0c703275c9eabc" } } },
      { jsonrpc: "2.0", id: "accounts", method: "account_list", params: { limit: 10 } },
      { jsonrpc: "2.0", id: "account", method: "account_get", params: { accountId: agentId } },
      { jsonrpc: "2.0", id: "balances", method: "balance_list", params: { limit: 10 } },
      { jsonrpc: "2.0", id: "balance", method: "balance_get", params: { accountId: agentId } },
      { jsonrpc: "2.0", id: "faucetEvents", method: "faucet_event_list", params: { limit: 10 } },
      { jsonrpc: "2.0", id: "faucetEvent", method: "faucet_event_get", params: { eventId: "faucet:disabled:no-value-local-devnet" } },
      { jsonrpc: "2.0", id: "wallets", method: "wallet_metadata_list", params: { limit: 10 } },
      { jsonrpc: "2.0", id: "wallet", method: "wallet_metadata_get", params: { walletId } },
      { jsonrpc: "2.0", id: "rootfields", method: "rootfield_list", params: { limit: 10 } },
      { jsonrpc: "2.0", id: "rootfield", method: "rootfield_get", params: { rootfieldId } },
      { jsonrpc: "2.0", id: "agents", method: "agent_list", params: { limit: 10 } },
      { jsonrpc: "2.0", id: "agent", method: "agent_get", params: { rootfieldId } },
      { jsonrpc: "2.0", id: "agentAccounts", method: "agent_account_list", params: { limit: 10 } },
      { jsonrpc: "2.0", id: "agentAccount", method: "agent_account_get", params: { agentId } },
      { jsonrpc: "2.0", id: "models", method: "model_list", params: { limit: 10 } },
      { jsonrpc: "2.0", id: "model", method: "model_get", params: { rootfieldId } },
      { jsonrpc: "2.0", id: "modelPassports", method: "model_passport_list", params: { limit: 10 } },
      { jsonrpc: "2.0", id: "modelPassport", method: "model_passport_get", params: { modelId } },
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
      { jsonrpc: "2.0", id: "memoryCell", method: "memory_cell_get", params: { memoryCellId } },
      { jsonrpc: "2.0", id: "challenges", method: "challenge_list", params: { limit: 10 } },
      { jsonrpc: "2.0", id: "challenge", method: "challenge_get", params: { challengeId } },
      { jsonrpc: "2.0", id: "finalityList", method: "finality_list", params: { limit: 10 } },
      { jsonrpc: "2.0", id: "finality", method: "finality_get", params: { objectId: finalityReceiptId } },
      { jsonrpc: "2.0", id: "bridgeObservationSubmit", method: "bridge_observation_submit", params: { deposit: state.bridgeDepositFixture } },
      { jsonrpc: "2.0", id: "bridgeObservations", method: "bridge_observation_list", params: { limit: 10 } },
      { jsonrpc: "2.0", id: "bridgeObservation", method: "bridge_observation_get", params: { depositId: bridgeDepositId } },
      { jsonrpc: "2.0", id: "bridgeDeposits", method: "bridge_deposit_list", params: { limit: 10 } },
      { jsonrpc: "2.0", id: "bridgeDeposit", method: "bridge_deposit_get", params: { depositId: bridgeDepositId } },
      { jsonrpc: "2.0", id: "bridgeCredits", method: "bridge_credit_list", params: { limit: 10 } },
      { jsonrpc: "2.0", id: "bridgeCredit", method: "bridge_credit_get", params: { depositId: bridgeDepositId } },
      { jsonrpc: "2.0", id: "withdrawals", method: "withdrawal_list", params: { limit: 10 } },
      { jsonrpc: "2.0", id: "withdrawal", method: "withdrawal_get", params: { depositId: bridgeDepositId } },
      { jsonrpc: "2.0", id: "provenance", method: "provenance_get", params: { receiptId: receipt.receiptId } },
      { jsonrpc: "2.0", id: "raw", method: "raw_json_get", params: { source: "launchCore" } },
      { jsonrpc: "2.0", id: "rawBridge", method: "raw_json_get", params: { source: "bridgeDepositFixture" } },
    ] as const;

    const response = dispatchJsonRpc([...requests], {
      state,
      paths: {
        runtimeStatePath: join(tempDir, "state.json"),
        runtimeIntakeDir: join(tempDir, "intake"),
        bridgeObservationIntakePath: join(tempDir, "bridge-observations.json"),
      },
    });
    if (!Array.isArray(response)) {
      throw new Error("control-plane smoke expected batch JSON-RPC response");
    }

    const errors = response.filter((entry): entry is RpcErrorResponse => "error" in entry);
    if (errors.length > 0) {
      throw new Error(`control-plane smoke failed: ${JSON.stringify(errors, null, 2)}`);
    }

    const successes = response as RpcSuccessResponse[];
    successes.forEach((entry) => assertNoSecrets(entry.result));
    return {
      schema: "flowmemory.control_plane.smoke.v0",
      ok: true,
      methodCount: requests.length,
      responseSchemas: successes.map((entry) => (entry.result as JsonObject).schema),
      noSecretResponseScan: "passed",
      queried: {
        rootfieldId,
        receiptId: receipt.receiptId,
        reportId,
        artifactUri,
        blockNumber: stringField(block.blockNumber, "blockNumber"),
        txId,
        agentId,
        modelId,
        memoryCellId,
        challengeId,
        finalityReceiptId,
        bridgeDepositId,
      },
      localOnly: true,
    };
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  console.log(JSON.stringify(runControlPlaneSmoke(), null, 2));
}
