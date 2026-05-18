import { fileURLToPath } from "node:url";
import { readFileSync } from "node:fs";

import { dispatchJsonRpc } from "./json-rpc.ts";
import { loadControlPlaneState } from "./fixture-state.ts";
import type { ControlPlanePaths, JsonObject, RpcErrorResponse, RpcSuccessResponse } from "./types.ts";

function firstDevnetBlock(state: ReturnType<typeof loadControlPlaneState>): JsonObject {
  const blocksResponse = dispatchJsonRpc(
    { jsonrpc: "2.0", id: "blocks-prefetch", method: "block_list", params: { limit: 10 } },
    { state },
  ) as RpcSuccessResponse;
  const blocks = (blocksResponse.result as JsonObject).blocks;
  const blockRows = Array.isArray(blocks) ? blocks : [];
  const block = blockRows.find((entry) => {
    if (entry === null || typeof entry !== "object" || Array.isArray(entry)) {
      return false;
    }
    return Array.isArray((entry as JsonObject).txIds) && ((entry as JsonObject).txIds as unknown[]).length > 0;
  }) ?? blockRows[0];
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

function smokeSignedEnvelope(): JsonObject {
  const vectors = JSON.parse(
    readFileSync(new URL("../../../crypto/fixtures/production-l1-vectors.json", import.meta.url), "utf8"),
  ) as JsonObject;
  const walletTransfer = (vectors.positive as JsonObject[]).find((entry) => entry.name === "wallet-transfer");
  if (walletTransfer === undefined) {
    throw new Error("control-plane smoke missing production-L1 wallet-transfer vector");
  }
  return {
    document: walletTransfer.document,
    envelope: walletTransfer.envelope,
  };
}

export function runControlPlaneSmoke(pathOverrides: Partial<ControlPlanePaths> = {}): JsonObject {
  const state = loadControlPlaneState(pathOverrides);
  const rootfieldId = state.launchCore.rootfieldBundles[0]?.rootfieldId;
  const receipt = state.launchCore.memoryReceipts[0];
  const reportId = receipt?.reportId;
  const artifactUri = receipt?.evidenceRefs[0]?.uri;
  const block = firstDevnetBlock(state);
  const txIds = Array.isArray(block.txIds) ? block.txIds : [];
  const txId = stringField(txIds[0], "devnet txId");
  const accounts = dispatchJsonRpc({ jsonrpc: "2.0", id: "accounts-prefetch", method: "account_list" }, { state }) as RpcSuccessResponse;
  const account = ((accounts.result as JsonObject).accounts as JsonObject[])[0];
  const accountId = stringField(account.accountId, "accountId");
  const deposits = dispatchJsonRpc({ jsonrpc: "2.0", id: "bridge-deposits-prefetch", method: "bridge_deposit_list" }, { state }) as RpcSuccessResponse;
  const deposit = ((deposits.result as JsonObject).deposits as JsonObject[])[0];
  const depositId = stringField(deposit.depositId, "depositId");
  const credits = dispatchJsonRpc({ jsonrpc: "2.0", id: "bridge-credits-prefetch", method: "bridge_credit_list" }, { state }) as RpcSuccessResponse;
  const credit = ((credits.result as JsonObject).credits as JsonObject[])[0];
  const creditId = stringField(credit.creditId, "creditId");
  const withdrawals = dispatchJsonRpc({ jsonrpc: "2.0", id: "withdrawals-prefetch", method: "withdrawal_list" }, { state }) as RpcSuccessResponse;
  const withdrawal = ((withdrawals.result as JsonObject).withdrawals as JsonObject[])[0];
  const withdrawalId = stringField(withdrawal.withdrawalId, "withdrawalId");
  const tokens = dispatchJsonRpc({ jsonrpc: "2.0", id: "tokens-prefetch", method: "token_list" }, { state }) as RpcSuccessResponse;
  const token = ((tokens.result as JsonObject).tokens as JsonObject[])[0];
  const tokenId = stringField(token.tokenId, "tokenId");
  const tokenBalances = dispatchJsonRpc({ jsonrpc: "2.0", id: "token-balances-prefetch", method: "token_balance_list" }, { state }) as RpcSuccessResponse;
  const tokenBalance = ((tokenBalances.result as JsonObject).balances as JsonObject[])[0];
  const tokenBalanceId = stringField(tokenBalance.balanceId, "tokenBalanceId");
  const tokenTransfers = dispatchJsonRpc({ jsonrpc: "2.0", id: "token-transfers-prefetch", method: "token_transfer_list" }, { state }) as RpcSuccessResponse;
  const tokenTransfer = ((tokenTransfers.result as JsonObject).transfers as JsonObject[])[0];
  const tokenTransferId = stringField(tokenTransfer.transferId, "tokenTransferId");
  const pools = dispatchJsonRpc({ jsonrpc: "2.0", id: "pools-prefetch", method: "pool_list" }, { state }) as RpcSuccessResponse;
  const pool = ((pools.result as JsonObject).pools as JsonObject[])[0];
  const poolId = stringField(pool.poolId, "poolId");
  const lpPositions = dispatchJsonRpc({ jsonrpc: "2.0", id: "lp-positions-prefetch", method: "lp_position_list" }, { state }) as RpcSuccessResponse;
  const lpPosition = ((lpPositions.result as JsonObject).positions as JsonObject[])[0];
  const lpPositionId = stringField(lpPosition.positionId, "lpPositionId");
  const swaps = dispatchJsonRpc({ jsonrpc: "2.0", id: "swaps-prefetch", method: "swap_list" }, { state }) as RpcSuccessResponse;
  const swap = ((swaps.result as JsonObject).swaps as JsonObject[])[0];
  const swapId = stringField(swap.swapId, "swapId");

  if (rootfieldId === undefined || receipt === undefined || reportId === undefined || artifactUri === undefined) {
    throw new Error("control-plane smoke requires launch-core rootfield, receipt, report, and artifact fixture data");
  }

  const requests = [
    { jsonrpc: "2.0", id: "health", method: "health" },
    { jsonrpc: "2.0", id: "node", method: "node_status" },
    { jsonrpc: "2.0", id: "peers", method: "peer_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "chain", method: "chain_status" },
    { jsonrpc: "2.0", id: "pilotStatus", method: "pilot_status" },
    { jsonrpc: "2.0", id: "pilotDeposits", method: "pilot_deposit_observation_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "pilotCredits", method: "pilot_credit_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "pilotWithdrawals", method: "pilot_withdrawal_intent_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "pilotReleaseEvidence", method: "pilot_release_evidence_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "pilotCapStatus", method: "pilot_cap_status" },
    { jsonrpc: "2.0", id: "pilotPauseStatus", method: "pilot_pause_status" },
    { jsonrpc: "2.0", id: "pilotRetryStatus", method: "pilot_retry_status" },
    { jsonrpc: "2.0", id: "pilotEmergencyStatus", method: "pilot_emergency_status" },
    { jsonrpc: "2.0", id: "devnet", method: "devnet_state", params: { includeBlocks: true } },
    { jsonrpc: "2.0", id: "blocks", method: "block_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "block", method: "block_get", params: { blockNumber: stringField(block.blockNumber, "blockNumber"), includeTransactions: true } },
    { jsonrpc: "2.0", id: "transactions", method: "transaction_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "transaction", method: "transaction_get", params: { txId } },
    {
      jsonrpc: "2.0",
      id: "transactionSubmit",
      method: "transaction_submit",
      params: {
        signedEnvelope: smokeSignedEnvelope(),
        submittedBy: "control-plane-smoke",
      },
    },
    { jsonrpc: "2.0", id: "mempool", method: "mempool_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "accounts", method: "account_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "account", method: "account_get", params: { accountId } },
    { jsonrpc: "2.0", id: "balance", method: "balance_get", params: { accountId } },
    { jsonrpc: "2.0", id: "tokens", method: "token_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "token", method: "token_get", params: { tokenId } },
    { jsonrpc: "2.0", id: "tokenBalances", method: "token_balance_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "tokenBalance", method: "token_balance_get", params: { balanceId: tokenBalanceId } },
    { jsonrpc: "2.0", id: "tokenTransfers", method: "token_transfer_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "tokenTransfer", method: "token_transfer_get", params: { transferId: tokenTransferId } },
    { jsonrpc: "2.0", id: "pools", method: "pool_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "pool", method: "pool_get", params: { poolId } },
    { jsonrpc: "2.0", id: "lpPositions", method: "lp_position_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "lpPosition", method: "lp_position_get", params: { positionId: lpPositionId } },
    { jsonrpc: "2.0", id: "swaps", method: "swap_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "swap", method: "swap_get", params: { swapId } },
    { jsonrpc: "2.0", id: "productFlowStatus", method: "product_flow_status" },
    { jsonrpc: "2.0", id: "faucet", method: "faucet_event_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "wallets", method: "wallet_metadata_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "wallet", method: "wallet_metadata_get", params: { walletId: accountId } },
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
    { jsonrpc: "2.0", id: "bridgeObservationList", method: "bridge_observation_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "bridgeObservation", method: "bridge_observation_get", params: { depositId } },
    { jsonrpc: "2.0", id: "bridgeDeposits", method: "bridge_deposit_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "bridgeDeposit", method: "bridge_deposit_get", params: { depositId } },
    { jsonrpc: "2.0", id: "bridgeCredits", method: "bridge_credit_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "bridgeCredit", method: "bridge_credit_get", params: { creditId } },
    { jsonrpc: "2.0", id: "withdrawals", method: "withdrawal_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "withdrawal", method: "withdrawal_get", params: { withdrawalId } },
    { jsonrpc: "2.0", id: "explorerSearchBlock", method: "explorer_search", params: { query: stringField(block.blockNumber, "blockNumber"), limit: 10 } },
    { jsonrpc: "2.0", id: "explorerSearchTx", method: "explorer_search", params: { query: txId, limit: 10 } },
    { jsonrpc: "2.0", id: "explorerSearchAccount", method: "explorer_search", params: { query: accountId, limit: 10 } },
    { jsonrpc: "2.0", id: "explorerSearchToken", method: "explorer_search", params: { query: tokenId, limit: 10 } },
    { jsonrpc: "2.0", id: "explorerSearchPool", method: "explorer_search", params: { query: poolId, limit: 10 } },
    { jsonrpc: "2.0", id: "explorerSearchBridgeCredit", method: "explorer_search", params: { query: creditId, limit: 10 } },
    { jsonrpc: "2.0", id: "explorerSearchWithdrawal", method: "explorer_search", params: { query: withdrawalId, limit: 10 } },
    { jsonrpc: "2.0", id: "provenance", method: "provenance_get", params: { receiptId: receipt.receiptId } },
    { jsonrpc: "2.0", id: "raw", method: "raw_json_get", params: { source: "launchCore" } },
    { jsonrpc: "2.0", id: "rawExplorerFallback", method: "raw_json_get", params: { source: "explorerFallback" } },
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
      accountId,
      depositId,
      tokenId,
      tokenTransferId,
      poolId,
      swapId,
    },
    localOnly: true,
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  console.log(JSON.stringify(runControlPlaneSmoke(), null, 2));
}
