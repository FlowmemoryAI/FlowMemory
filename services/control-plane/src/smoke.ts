import { fileURLToPath } from "node:url";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

import { dispatchJsonRpc } from "./json-rpc.ts";
import { loadControlPlaneState } from "./fixture-state.ts";
import type { ControlPlanePaths, JsonObject, RpcErrorResponse, RpcSuccessResponse } from "./types.ts";

function firstLocalRuntimeBlock(state: ReturnType<typeof loadControlPlaneState>): JsonObject {
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
    throw new Error("control-plane smoke requires at least one local runtime block");
  }
  return block as JsonObject;
}

function stringField(value: unknown, name: string): string {
  if (typeof value !== "string" && typeof value !== "number") {
    throw new Error(`control-plane smoke missing ${name}`);
  }
  return String(value);
}

function asObject(value: unknown): JsonObject | null {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value as JsonObject : null;
}


function smokeSignedEnvelope(): JsonObject {
  const vectors = JSON.parse(
    readFileSync(new URL("../../../crypto/fixtures/production-network-vectors.json", import.meta.url), "utf8"),
  ) as JsonObject;
  const walletTransfer = (vectors.positive as JsonObject[]).find((entry) => entry.name === "wallet-transfer");
  if (walletTransfer === undefined) {
    throw new Error("control-plane smoke missing production-network wallet-transfer vector");
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
  const agentBondTask = state.launchCore.agentBondFixture?.task as { taskId?: string } | undefined;
  const taskScoutFixture = (state.taskScoutFixture ?? state.launchCore.taskScoutFixture ?? null) as JsonObject | null;
  const block = firstLocalRuntimeBlock(state);
  const txIds = Array.isArray(block.txIds) ? block.txIds : [];
  const txId = stringField(txIds[0], "localRuntime txId");
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
  const taskScoutAgentId = stringField(asObject(taskScoutFixture?.agentConfig)?.agentId, "taskScout agentId");
  const publicClasses = dispatchJsonRpc({ jsonrpc: "2.0", id: "public-classes-prefetch", method: "public_agent_network_classes_list", params: { limit: 10 } }, { state }) as RpcSuccessResponse;
  const publicClass = ((publicClasses.result as JsonObject).classes as JsonObject[])[0];
  const publicClassId = stringField(publicClass.classId, "public classId");
  const publicTools = dispatchJsonRpc({ jsonrpc: "2.0", id: "public-tools-prefetch", method: "public_agent_network_tools_list", params: { limit: 10 } }, { state }) as RpcSuccessResponse;
  const publicTool = ((publicTools.result as JsonObject).tools as JsonObject[])[0];
  const publicToolSetRoot = stringField(publicTool.toolSetRoot, "public toolSetRoot");
  const publicSwarmClasses = dispatchJsonRpc({ jsonrpc: "2.0", id: "public-swarm-classes-prefetch", method: "public_swarm_classes_list", params: { limit: 10 } }, { state }) as RpcSuccessResponse;
  const publicSwarmClass = ((publicSwarmClasses.result as JsonObject).classes as JsonObject[])[0];
  const publicSwarmClassId = stringField(publicSwarmClass.swarmClass, "public swarmClass");

  if (
    rootfieldId === undefined
    || receipt === undefined
    || reportId === undefined
    || artifactUri === undefined
    || typeof agentBondTask?.taskId !== "string"
    || taskScoutFixture === null
  ) {
    throw new Error("control-plane smoke requires launch-core rootfield, receipt, report, artifact fixture data, agent bond task fixture data, and task scout fixture data");
  }

  const requests = [
    { jsonrpc: "2.0", id: "rpcDiscover", method: "rpc_discover" },
    { jsonrpc: "2.0", id: "rpcReadiness", method: "rpc_readiness" },
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
    { jsonrpc: "2.0", id: "bridgeLiveReadiness", method: "bridge_live_readiness" },
    { jsonrpc: "2.0", id: "pilotLifecycleRecords", method: "pilot_lifecycle_record_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "agentBondReadiness", method: "agent_bond_readiness_get" },
    { jsonrpc: "2.0", id: "agentBondTasks", method: "agent_bond_task_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "agentBondTask", method: "agent_bond_task_get", params: { taskId: agentBondTask.taskId } },
    { jsonrpc: "2.0", id: "agentBondLaunchStatus", method: "agent_bond_public_launch_status_get" },
    { jsonrpc: "2.0", id: "agentBondPassportList", method: "agent_bond_passport_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "agentBondPassport", method: "agent_bond_passport_get", params: { agentId: "agent_code_001" } },
    { jsonrpc: "2.0", id: "agentBondEnvelopeQuote", method: "agent_bond_envelope_quote", params: { taskClass: "code.patch", payoutUSDC: "50000000" } },
    { jsonrpc: "2.0", id: "agentBondReceiptList", method: "agent_bond_receipt_list", params: { agentId: "agent_code_001", limit: 10 } },
    { jsonrpc: "2.0", id: "agentBondPhase2Gate", method: "agent_bond_phase2_gate_get" },
    { jsonrpc: "2.0", id: "agentBondA2ACard", method: "agent_bond_a2a_agent_card_get", params: { agentId: "agent_code_001" } },
    { jsonrpc: "2.0", id: "agentBondMcpTools", method: "agent_bond_mcp_tools_get" },
    { jsonrpc: "2.0", id: "agentBondX402Intent", method: "agent_bond_x402_payment_intent_create", params: { mode: "service_payment" } },
    { jsonrpc: "2.0", id: "agentBondCredit", method: "agent_bond_credit_score_get", params: { agentId: "agent_code_001" } },
    { jsonrpc: "2.0", id: "agentBondUnderwriterPools", method: "agent_bond_underwriter_pool_list" },
    { jsonrpc: "2.0", id: "agentBondPublicClaim", method: "agent_bond_public_claim_status_get" },
    { jsonrpc: "2.0", id: "agentBondRecoursePolicy", method: "agent_bond_recourse_policy_get" },
    { jsonrpc: "2.0", id: "agentBondRecourseDecision", method: "agent_bond_recourse_decision_quote", params: { agentId: "agent_data_001" } },
    { jsonrpc: "2.0", id: "agentBondFailureWaterfall", method: "agent_bond_failure_waterfall_get" },
    { jsonrpc: "2.0", id: "localRuntime", method: "localRuntime_state", params: { includeBlocks: true } },
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
    { jsonrpc: "2.0", id: "walletBalances", method: "wallet_balance_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "walletTransfers", method: "wallet_transfer_history", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "rootfields", method: "rootfield_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "rootfield", method: "rootfield_get", params: { rootfieldId } },
    { jsonrpc: "2.0", id: "agents", method: "agent_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "agent", method: "agent_get", params: { rootfieldId } },
    { jsonrpc: "2.0", id: "baseAgentScouts", method: "base_agent_memory_task_scout_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "baseAgentScout", method: "base_agent_memory_task_scout_get", params: { agentId: taskScoutAgentId } },
    { jsonrpc: "2.0", id: "baseAgentReplay", method: "base_agent_memory_replay_get", params: { agentId: taskScoutAgentId } },
    { jsonrpc: "2.0", id: "publicAgentClasses", method: "public_agent_network_classes_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "publicAgentClass", method: "public_agent_network_class_get", params: { classId: publicClassId } },
    { jsonrpc: "2.0", id: "publicAgentTools", method: "public_agent_network_tools_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "publicAgentToolSet", method: "public_agent_network_tool_set_get", params: { toolSetRoot: publicToolSetRoot } },
    { jsonrpc: "2.0", id: "publicAgentLaunchPreview", method: "public_agent_launch_preview", params: { owner: accountId, classId: publicClassId, objectiveText: "Launch a task scout", profileText: "Public task scout profile", toolSetRoot: publicToolSetRoot, autonomyLevel: 2, riskLevel: 1, bondToken: "0x2000000000000000000000000000000000000001", bondAmount: "10000000000000000000", fuelToken: "0x2000000000000000000000000000000000000001", initialFuelAmount: "5000000000000000000", discoverable: true } },
    { jsonrpc: "2.0", id: "publicSwarmClasses", method: "public_swarm_classes_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "publicSwarmClass", method: "public_swarm_class_get", params: { swarmClass: publicSwarmClassId } },
    { jsonrpc: "2.0", id: "publicSwarmLaunchPreview", method: "public_swarm_launch_preview", params: { creator: accountId, swarmClass: publicSwarmClassId, missionText: "Research a launch opportunity", profileText: "Research swarm profile", budgetAsset: "0x2000000000000000000000000000000000000001", initialBudget: "1000000000000000000" } },
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
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-control-plane-smoke-"));
  try {
    console.log(JSON.stringify(runControlPlaneSmoke({
      txIntakePath: join(dir, "transactions.ndjson"),
      bridgeObservationIntakePath: join(dir, "bridge-observations.ndjson"),
    }), null, 2));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}
