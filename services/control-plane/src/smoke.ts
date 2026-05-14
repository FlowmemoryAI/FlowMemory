import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { dispatchJsonRpc } from "./json-rpc.ts";
import { loadControlPlaneState, repoRoot } from "./fixture-state.ts";
import { scanJsonForSecrets } from "./no-secret.ts";
import { buildLocalSignedTransferEnvelope, signedEnvelopeTxId, localSignatureDigest } from "./transaction-envelope.ts";
import type { ControlPlanePaths, JsonObject, RpcErrorResponse, RpcSuccessResponse } from "./types.ts";

interface MethodSchemaCatalog {
  schema: "flowmemory.control_plane.production_l1_schema_catalog.v1";
  methods: Record<string, {
    requestSchema: string;
    responseSchema: string;
    resultSchema?: string;
    allowedResultSchemas?: string[];
  }>;
}

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

function loadSchemaCatalog(): MethodSchemaCatalog {
  return JSON.parse(readFileSync(resolve(repoRoot(), "schemas/flowmemory/control-plane-production-l1.schema.json"), "utf8")) as MethodSchemaCatalog;
}

function assertNoSecretResponse(value: unknown, label: string): void {
  const findings = scanJsonForSecrets(value as never);
  if (findings.length > 0) {
    throw new Error(`control-plane smoke secret scan failed for ${label}: ${JSON.stringify(findings, null, 2)}`);
  }
}

function assertCatalogResponse(catalog: MethodSchemaCatalog, method: string, response: RpcSuccessResponse): void {
  const entry = catalog.methods[method];
  if (entry === undefined) {
    throw new Error(`schema catalog missing method ${method}`);
  }
  const result = response.result as JsonObject;
  const schema = result.schema;
  const allowed = entry.allowedResultSchemas ?? (entry.resultSchema === undefined ? [] : [entry.resultSchema]);
  if (typeof schema !== "string" || !allowed.includes(schema)) {
    throw new Error(`schema catalog mismatch for ${method}: got ${String(schema)}, expected ${allowed.join(", ")}`);
  }
}

function assertCatalogError(response: RpcErrorResponse): void {
  assertNoSecretResponse(response, String(response.id ?? "error"));
  if (response.error.data.schema !== "flowmemory.control_plane.error.v1") {
    throw new Error(`error response used unexpected schema ${response.error.data.schema}`);
  }
  for (const field of ["errorCode", "message", "correlationId", "recoverable", "retryable", "sourceComponent"]) {
    if (!(field in response.error.data)) {
      throw new Error(`error response missing ${field}`);
    }
  }
}

export function runControlPlaneSmoke(pathOverrides: Partial<ControlPlanePaths> = {}): JsonObject {
  const catalog = loadSchemaCatalog();
  const state = loadControlPlaneState(pathOverrides);
  const chainStatus = dispatchJsonRpc({ jsonrpc: "2.0", id: "chain-prefetch", method: "chain_status" }, { state }) as RpcSuccessResponse;
  const chainId = stringField((chainStatus.result as JsonObject).chainId, "chainId");
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
  const creditTxHash = stringField(credit.txHash ?? credit.baseTxHash, "bridge credit txHash");
  const withdrawals = dispatchJsonRpc({ jsonrpc: "2.0", id: "withdrawals-prefetch", method: "withdrawal_list" }, { state }) as RpcSuccessResponse;
  const withdrawal = ((withdrawals.result as JsonObject).withdrawals as JsonObject[])[0];
  const withdrawalId = stringField(withdrawal.withdrawalId, "withdrawalId");
  const tokens = dispatchJsonRpc({ jsonrpc: "2.0", id: "tokens-prefetch", method: "token_list" }, { state }) as RpcSuccessResponse;
  const token = ((tokens.result as JsonObject).tokens as JsonObject[])[0];
  const tokenId = stringField(token.tokenId, "tokenId");
  const tokenBalances = dispatchJsonRpc({ jsonrpc: "2.0", id: "token-balances-prefetch", method: "token_balance_list" }, { state }) as RpcSuccessResponse;
  const tokenBalance = ((tokenBalances.result as JsonObject).balances as JsonObject[])[0];
  const tokenBalanceId = stringField(tokenBalance.balanceId, "tokenBalanceId");
  const pools = dispatchJsonRpc({ jsonrpc: "2.0", id: "pools-prefetch", method: "pool_list" }, { state }) as RpcSuccessResponse;
  const pool = ((pools.result as JsonObject).pools as JsonObject[])[0];
  const poolId = stringField(pool.poolId, "poolId");
  const lpPositions = dispatchJsonRpc({ jsonrpc: "2.0", id: "lp-prefetch", method: "lp_position_list" }, { state }) as RpcSuccessResponse;
  const lpPosition = ((lpPositions.result as JsonObject).positions as JsonObject[])[0];
  const lpPositionId = stringField(lpPosition.positionId, "lpPositionId");
  const swaps = dispatchJsonRpc({ jsonrpc: "2.0", id: "swap-prefetch", method: "swap_list" }, { state }) as RpcSuccessResponse;
  const swap = ((swaps.result as JsonObject).swaps as JsonObject[])[0];
  const swapId = stringField(swap.swapId, "swapId");
  const events = dispatchJsonRpc({ jsonrpc: "2.0", id: "events-prefetch", method: "event_list", params: { limit: 10 } }, { state }) as RpcSuccessResponse;
  const event = ((events.result as JsonObject).events as JsonObject[])[0];
  const eventId = stringField(event.eventId, "eventId");
  const releaseEvidenceList = dispatchJsonRpc({ jsonrpc: "2.0", id: "release-prefetch", method: "release_evidence_list" }, { state }) as RpcSuccessResponse;
  const releaseEvidence = ((releaseEvidenceList.result as JsonObject).releaseEvidence as JsonObject[])[0];
  const releaseEvidenceId = stringField(releaseEvidence.releaseEvidenceId, "releaseEvidenceId");
  const replayRejections = dispatchJsonRpc({ jsonrpc: "2.0", id: "replay-prefetch", method: "replay_rejection_list" }, { state }) as RpcSuccessResponse;
  const replayRejection = ((replayRejections.result as JsonObject).replayRejections as JsonObject[])[0];
  const replayRejectionId = stringField(replayRejection.replayRejectionId, "replayRejectionId");
  const signer = `0x${Date.now().toString(16).padStart(40, "0").slice(-40)}`;
  const submitAccountSuffix = Date.now().toString(16);
  const transferFrom = `account:submit:alice:${submitAccountSuffix}`;
  const transferTo = `account:submit:bob:${submitAccountSuffix}`;
  const bridgeObservationId = `0x${(Date.now() + 1).toString(16).padStart(64, "0").slice(-64)}`;
  const bridgeReplayKey = `0x${(Date.now() + 2).toString(16).padStart(64, "0").slice(-64)}`;
  const signedEnvelope = buildLocalSignedTransferEnvelope({
    chainId,
    signer,
    nonce: "0",
    from: transferFrom,
    to: transferTo,
    amount: "7",
    memo: "control-plane-smoke",
  });
  const submittedTxId = signedEnvelopeTxId(signedEnvelope);
  const invalidSignatureEnvelope = { ...signedEnvelope, signature: `0x${"0".repeat(64)}` };
  const wrongChainEnvelope = buildLocalSignedTransferEnvelope({
    chainId: "flowmemory-wrong-chain",
    signer: "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    nonce: "0",
    from: "account:submit:wrong-chain",
    to: "account:submit:bob",
    amount: "1",
  });
  const staleNonceEnvelope = buildLocalSignedTransferEnvelope({
    chainId,
    signer,
    nonce: "0",
    from: transferFrom,
    to: "account:submit:charlie",
    amount: "8",
  });
  staleNonceEnvelope.signature = localSignatureDigest(staleNonceEnvelope);

  if (rootfieldId === undefined || receipt === undefined || reportId === undefined || artifactUri === undefined) {
    throw new Error("control-plane smoke requires launch-core rootfield, receipt, report, and artifact fixture data");
  }

  const requests = [
    { jsonrpc: "2.0", id: "health", method: "health" },
    { jsonrpc: "2.0", id: "node", method: "node_status" },
    { jsonrpc: "2.0", id: "peers", method: "peer_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "sync", method: "sync_status" },
    { jsonrpc: "2.0", id: "chain", method: "chain_status" },
    { jsonrpc: "2.0", id: "finalityStatus", method: "finality_status" },
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
    { jsonrpc: "2.0", id: "events", method: "event_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "event", method: "event_get", params: { eventId } },
    {
      jsonrpc: "2.0",
      id: "transactionSubmit",
      method: "transaction_submit",
      params: {
        signedEnvelope,
        submittedBy: "control-plane-smoke",
      },
    },
    { jsonrpc: "2.0", id: "submittedTransaction", method: "transaction_get", params: { txId: submittedTxId } },
    { jsonrpc: "2.0", id: "submittedReceipt", method: "receipt_get", params: { txId: submittedTxId } },
    { jsonrpc: "2.0", id: "submittedBalance", method: "balance_get", params: { accountId: transferTo, tokenId: "local-test-unit" } },
    {
      jsonrpc: "2.0",
      id: "transferSend",
      method: "transfer_send",
      params: {
        from: transferTo,
        to: `account:submit:carol:${submitAccountSuffix}`,
        tokenId: "local-test-unit",
        amount: "2",
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
    { jsonrpc: "2.0", id: "artifactResolver", method: "artifact_get", params: { uri: artifactUri } },
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
    {
      jsonrpc: "2.0",
      id: "bridgeObservationSubmit",
      method: "bridge_observation_submit",
      params: {
        observation: {
          schema: "flowmemory.bridge_deposit_observation.v0",
          observationId: bridgeObservationId,
          replayKey: bridgeReplayKey,
          observedAt: "2026-05-13T00:00:00.000Z",
          mode: "mock",
          productionReady: false,
          deposit: {
            schema: "flowmemory.bridge_deposit.v0",
            depositId: bridgeObservationId,
            sourceChainId: 84532,
            sourceContract: "0x1111111111111111111111111111111111111111",
            txHash: bridgeReplayKey,
            logIndex: 0,
            token: "0x3333333333333333333333333333333333333333",
            amount: "1",
            sender: "0x4444444444444444444444444444444444444444",
            flowchainRecipient: transferTo,
            nonce: "1",
            status: "observed"
          }
        }
      }
    },
    { jsonrpc: "2.0", id: "submittedBridgeObservation", method: "bridge_observation_get", params: { observationId: bridgeObservationId } },
    { jsonrpc: "2.0", id: "bridgeConfig", method: "bridge_config_get" },
    { jsonrpc: "2.0", id: "bridgeStatus", method: "bridge_status" },
    { jsonrpc: "2.0", id: "bridgeCreditStatus", method: "bridge_credit_status", params: { txHash: creditTxHash } },
    { jsonrpc: "2.0", id: "bridgeDeposits", method: "bridge_deposit_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "bridgeDeposit", method: "bridge_deposit_get", params: { depositId } },
    { jsonrpc: "2.0", id: "bridgeCredits", method: "bridge_credit_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "bridgeCredit", method: "bridge_credit_get", params: { creditId } },
    { jsonrpc: "2.0", id: "bridgeCreditByTxHash", method: "bridge_credit_get", params: { txHash: creditTxHash } },
    { jsonrpc: "2.0", id: "withdrawalIntents", method: "withdrawal_intent_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "withdrawalIntent", method: "withdrawal_intent_get", params: { withdrawalId } },
    { jsonrpc: "2.0", id: "releaseEvidenceList", method: "release_evidence_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "releaseEvidence", method: "release_evidence_get", params: { releaseEvidenceId } },
    { jsonrpc: "2.0", id: "replayRejectionList", method: "replay_rejection_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "replayRejection", method: "replay_rejection_get", params: { replayRejectionId } },
    { jsonrpc: "2.0", id: "withdrawals", method: "withdrawal_list", params: { limit: 10 } },
    { jsonrpc: "2.0", id: "withdrawal", method: "withdrawal_get", params: { withdrawalId } },
    { jsonrpc: "2.0", id: "provenance", method: "provenance_get", params: { receiptId: receipt.receiptId } },
    { jsonrpc: "2.0", id: "raw", method: "raw_json_get", params: { source: "launchCore" } },
    { jsonrpc: "2.0", id: "invalidSignature", method: "transaction_submit", params: { signedEnvelope: invalidSignatureEnvelope } },
    { jsonrpc: "2.0", id: "duplicateTransaction", method: "transaction_submit", params: { signedEnvelope } },
    { jsonrpc: "2.0", id: "wrongChain", method: "transaction_submit", params: { signedEnvelope: wrongChainEnvelope } },
    { jsonrpc: "2.0", id: "staleNonce", method: "transaction_submit", params: { signedEnvelope: staleNonceEnvelope } },
  ] as const;

  const response = dispatchJsonRpc([...requests], { state });
  if (!Array.isArray(response)) {
    throw new Error("control-plane smoke expected batch JSON-RPC response");
  }

  response.forEach((entry) => assertNoSecretResponse(entry, String(entry.id ?? "batch-entry")));
  const expectedErrorIds = new Set(["invalidSignature", "duplicateTransaction", "wrongChain", "staleNonce"]);
  const unexpectedErrors = response.filter((entry): entry is RpcErrorResponse => "error" in entry && !expectedErrorIds.has(String(entry.id)));
  const expectedErrors = response.filter((entry): entry is RpcErrorResponse => "error" in entry && expectedErrorIds.has(String(entry.id)));
  expectedErrors.forEach(assertCatalogError);
  const expectedCodes = new Map(expectedErrors.map((entry) => [String(entry.id), entry.error.data.errorCode]));
  if (expectedCodes.get("invalidSignature") !== "BAD_SIGNATURE"
    || expectedCodes.get("duplicateTransaction") !== "DUPLICATE_TX"
    || expectedCodes.get("wrongChain") !== "WRONG_CHAIN_ID"
    || expectedCodes.get("staleNonce") !== "STALE_NONCE") {
    throw new Error(`control-plane smoke expected transaction rejection codes, got ${JSON.stringify(Object.fromEntries(expectedCodes))}`);
  }
  const errors = unexpectedErrors;
  if (errors.length > 0) {
    throw new Error(`control-plane smoke failed: ${JSON.stringify(errors, null, 2)}`);
  }

  if (expectedErrors.length !== expectedErrorIds.size) {
    throw new Error("control-plane smoke did not exercise every expected transaction rejection");
  }

  const successes = response.filter((entry): entry is RpcSuccessResponse => "result" in entry);
  successes.forEach((entry) => {
    const request = requests.find((candidate) => candidate.id === entry.id);
    if (request !== undefined) {
      assertCatalogResponse(catalog, request.method, entry);
    }
  });
  const submittedBalance = successes.find((entry) => entry.id === "submittedBalance")?.result as JsonObject | undefined;
  if (submittedBalance?.amount !== "7") {
    throw new Error(`submitted transfer balance proof failed: ${String(submittedBalance?.amount)}`);
  }
  const transferSendResult = successes.find((entry) => entry.id === "transferSend")?.result as JsonObject | undefined;
  if (transferSendResult?.schema !== "flowmemory.control_plane.transfer_send_result.v1"
    || (transferSendResult.receipt as JsonObject | undefined)?.status !== "accepted_local") {
    throw new Error(`transfer_send receipt proof failed: ${JSON.stringify(transferSendResult)}`);
  }
  return {
    schema: "flowmemory.control_plane.smoke.v0",
    ok: true,
    methodCount: requests.length,
    successCount: successes.length,
    expectedErrorCount: expectedErrors.length,
    responseSchemas: successes.map((entry) => (entry.result as JsonObject).schema),
    noSecretScan: {
      schema: "flowmemory.control_plane.no_secret_scan.v1",
      scannedResponses: response.length,
      findingCount: 0,
    },
    queried: {
      rootfieldId,
      receiptId: receipt.receiptId,
      reportId,
      artifactUri,
      blockNumber: stringField(block.blockNumber, "blockNumber"),
      txId,
      submittedTxId,
      accountId,
      depositId,
      tokenId,
      poolId,
      lpPositionId,
      swapId,
      releaseEvidenceId,
      replayRejectionId,
    },
    localOnly: true,
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  console.log(JSON.stringify(runControlPlaneSmoke(), null, 2));
}
