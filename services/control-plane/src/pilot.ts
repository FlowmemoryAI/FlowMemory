import { canonicalJson, keccak256Utf8 } from "../../shared/src/index.ts";
import { invalidParams, objectNotFound } from "./errors.ts";
import { loadControlPlaneState } from "./fixture-state.ts";
import type {
  ControlPlaneContext,
  JsonObject,
  JsonValue,
  LoadedControlPlaneState,
} from "./types.ts";

const BASE_MAINNET_CHAIN_ID = 8453;
const PILOT_PER_DEPOSIT_CAP_USD = 25;
const PILOT_TOTAL_CAP_USD = 25;
const REQUIRED_OPERATOR_ACK = "I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT";
const MIN_CONFIRMATION_DEPTH = 2;
const MAX_CONFIRMATION_DEPTH = 256;
const LIVE_REQUIRED_ENV_NAMES = [
  "FLOWCHAIN_PILOT_OPERATOR_ACK",
  "FLOWCHAIN_BASE8453_RPC_URL",
  "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
  "FLOWCHAIN_BASE8453_FROM_BLOCK",
  "FLOWCHAIN_BASE8453_TO_BLOCK",
  "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
  "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
] as const;
const CONFIRMATION_DEPTH_ENV_NAMES = [
  "FLOWCHAIN_PILOT_CONFIRMATIONS",
  "FLOWCHAIN_BASE8453_CONFIRMATION_DEPTH",
] as const;
const LIVE_OPTIONAL_ENV_NAMES = [
  "FLOWCHAIN_BASE8453_TOKEN_MODE",
  "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
  "FLOWCHAIN_BRIDGE_TARGET_SETTLEMENT_SECONDS",
  "FLOWCHAIN_BASE8453_ESTIMATED_BLOCK_SECONDS",
  "FLOWCHAIN_BRIDGE_POLL_SECONDS",
  "FLOWCHAIN_PILOT_WITHDRAWAL_RECIPIENT",
  "FLOWCHAIN_PILOT_MAX_USD",
] as const;

type PilotState = "live" | "degraded" | "error";
type PilotPhase =
  | "base_deposit_observed"
  | "local_credit_applied"
  | "replay_retry_checked"
  | "withdrawal_intent_recorded"
  | "release_evidence_recorded"
  | "caps_enforced"
  | "pause_clear"
  | "emergency_clear";

type PilotStep = {
  label: string;
  command: string;
  reason: string;
};

type PilotLifecycle = {
  schema: "flowmemory.control_plane.real_value_pilot_status.v0";
  pilotId: string;
  label: "FlowChain capped owner real-value pilot";
  state: PilotState;
  stateReason: string;
  generatedAt: string;
  baseChainId: 8453;
  cappedOwnerTesting: true;
  broadPublicReadiness: false;
  productionReady: false;
  browserStoresSecrets: false;
  nextOperatorStep: PilotStep;
  counts: JsonObject;
  lifecycle: JsonObject[];
  depositObservations: JsonObject[];
  credits: JsonObject[];
  withdrawalIntents: JsonObject[];
  releaseEvidence: JsonObject[];
  bridgeLiveReadiness: JsonObject;
  lifecycleRecords: JsonObject[];
  exactValueChecks: JsonObject;
  operationalStates: JsonObject[];
  capStatus: JsonObject;
  pauseStatus: JsonObject;
  retryStatus: JsonObject;
  emergencyStatus: JsonObject;
  localOnly: true;
};

function stateFor(context: ControlPlaneContext): LoadedControlPlaneState {
  return context.state ?? loadControlPlaneState(context.paths);
}

function asObject(value: JsonValue | undefined | unknown): JsonObject | null {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value as JsonObject : null;
}

function asArray(value: JsonValue | undefined | unknown): JsonValue[] {
  return Array.isArray(value) ? value as JsonValue[] : [];
}

function objectRows(value: JsonValue | undefined | unknown): JsonObject[] {
  if (Array.isArray(value)) {
    return value.map((entry) => asObject(entry)).filter((entry): entry is JsonObject => entry !== null);
  }
  const object = asObject(value);
  return object === null ? [] : Object.values(object).map((entry) => asObject(entry)).filter((entry): entry is JsonObject => entry !== null);
}

function stringValue(value: JsonValue | undefined | unknown): string | null {
  if (typeof value === "string") {
    return value;
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  return null;
}

function numberValue(value: JsonValue | undefined | unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function stableId(schema: string, value: JsonValue): string {
  return keccak256Utf8(canonicalJson({ schema, value }));
}

function pageLimit(params: JsonObject): number {
  const value = params.limit;
  if (value === undefined) {
    return 50;
  }
  if (typeof value !== "number" || !Number.isInteger(value) || value < 1 || value > 100) {
    throw invalidParams("limit must be an integer from 1 to 100");
  }
  return value;
}

function asObjectParams(params: JsonValue | undefined, method: string): JsonObject {
  if (params === undefined) {
    return {};
  }
  if (params === null || typeof params !== "object" || Array.isArray(params)) {
    throw invalidParams(`${method} params must be an object`);
  }
  return params as JsonObject;
}

function lowerText(value: JsonValue | undefined | unknown): string {
  return stringValue(value)?.toLowerCase() ?? "";
}

function rowText(row: JsonObject): string {
  return JSON.stringify(row).toLowerCase();
}

function matchesOptionalFilter(row: JsonObject, params: JsonObject, names: string[]): boolean {
  const expected = names.map((name) => lowerText(params[name])).find((value) => value.length > 0);
  if (expected === undefined) {
    return true;
  }
  return rowText(row).includes(expected);
}

function filterRows(rows: JsonObject[], params: JsonObject): JsonObject[] {
  const status = lowerText(params.status);
  const query = lowerText(params.query);
  return rows
    .filter((row) => matchesOptionalFilter(row, params, ["baseTxHash", "txHash"]))
    .filter((row) => matchesOptionalFilter(row, params, ["creditId"]))
    .filter((row) => matchesOptionalFilter(row, params, ["walletAddress", "wallet", "accountId", "recipientWallet"]))
    .filter((row) => status.length === 0 || lowerText(row.status) === status || rowText(row).includes(`"status":"${status}"`))
    .filter((row) => query.length === 0 || rowText(row).includes(query));
}

function listResult(schema: string, rowsKey: string, rows: JsonObject[], params: JsonValue | undefined, method: string): JsonObject {
  const objectParams = asObjectParams(params, method);
  const limit = pageLimit(objectParams);
  const filteredRows = filterRows(rows, objectParams);
  return {
    schema,
    count: Math.min(filteredRows.length, limit),
    totalCount: rows.length,
    filteredCount: filteredRows.length,
    nextCursor: null,
    [rowsKey]: filteredRows.slice(0, limit),
    localOnly: true,
    productionReady: false,
    cappedOwnerTesting: true,
  };
}

function handoffRows(state: LoadedControlPlaneState, key: string): JsonObject[] {
  return objectRows(state.bridgeRuntimeHandoff?.[key]);
}

function handoffRowsAny(state: LoadedControlPlaneState, keys: string[]): JsonObject[] {
  return keys.flatMap((key) => handoffRows(state, key));
}

function devnetObjectRows(state: LoadedControlPlaneState, keys: string[]): JsonObject[] {
  const controlPlaneObjects = asObject(state.devnetControlPlaneHandoff?.objects);
  const rows = new Map<string, JsonObject>();
  for (const key of keys) {
    for (const source of [
      state.devnet?.[key],
      controlPlaneObjects?.[key],
      state.devnetControlPlaneHandoff?.[key],
      state.devnetVerifierHandoff?.[key],
      state.devnetIndexerHandoff?.[key],
    ]) {
      for (const row of objectRows(source)) {
        const id = stringValue(row.id)
          ?? stringValue(row.creditId)
          ?? stringValue(row.bridgeCreditId)
          ?? stringValue(row.withdrawalIntentId)
          ?? stringValue(row.withdrawalId)
          ?? stringValue(row.depositId)
          ?? stableId("flowmemory.control_plane.pilot.devnet_row.v0", row);
        rows.set(`${key}:${id}`, row);
      }
    }
  }
  return [...rows.values()];
}

function chainIdOf(row: JsonObject): number | null {
  const source = asObject(row.source);
  const deposit = asObject(row.deposit);
  return numberValue(row.sourceChainId)
    ?? numberValue(row.chainId)
    ?? numberValue(source?.chainId)
    ?? numberValue(deposit?.sourceChainId);
}

function modeFor(row: JsonObject): string {
  const explicit = stringValue(row.mode);
  if (explicit !== null) {
    return explicit;
  }
  const chainId = chainIdOf(row);
  if (chainId === BASE_MAINNET_CHAIN_ID) {
    return "base-mainnet-canary";
  }
  if (chainId === 84532) {
    return "base-sepolia";
  }
  if (chainId === 31337) {
    return "local-anvil";
  }
  return "mock";
}

function replayKeyFor(deposit: JsonObject, observation: JsonObject): string {
  return stringValue(observation.replayKey)
    ?? stringValue(deposit.replayKey)
    ?? stableId("flowmemory.control_plane.real_value_pilot_replay_key.v0", {
      sourceChainId: deposit.sourceChainId ?? null,
      sourceContract: deposit.sourceContract ?? asObject(deposit.source)?.contract ?? null,
      txHash: deposit.txHash ?? asObject(deposit.source)?.txHash ?? null,
      logIndex: deposit.logIndex ?? asObject(deposit.source)?.logIndex ?? null,
      depositId: deposit.depositId ?? null,
    });
}

function normalizeDepositObservation(observation: JsonObject): JsonObject {
  const deposit = asObject(observation.deposit) ?? observation;
  const mode = modeFor({ ...observation, ...deposit });
  const replayKey = replayKeyFor(deposit, observation);
  const observationId = stringValue(observation.observationId)
    ?? stableId("flowmemory.control_plane.real_value_pilot_observation.v0", {
      mode,
      replayKey,
      depositId: deposit.depositId ?? null,
    });
  const sourceChainId = chainIdOf({ ...observation, ...deposit });

  return {
    schema: "flowmemory.control_plane.real_value_pilot_deposit_observation.v0",
    observationId,
    depositId: stringValue(deposit.depositId) ?? stableId("flowmemory.control_plane.real_value_pilot_deposit.v0", deposit),
    replayKey,
    mode,
    baseMainnet: sourceChainId === BASE_MAINNET_CHAIN_ID,
    sourceChainId: sourceChainId ?? null,
    sourceContract: stringValue(deposit.sourceContract) ?? stringValue(asObject(deposit.source)?.contract) ?? null,
    txHash: stringValue(deposit.txHash) ?? stringValue(asObject(deposit.source)?.txHash) ?? null,
    logIndex: numberValue(deposit.logIndex) ?? numberValue(asObject(deposit.source)?.logIndex),
    token: stringValue(deposit.token) ?? stringValue(deposit.assetId) ?? null,
    amount: stringValue(deposit.amount) ?? stringValue(deposit.amountUnits) ?? "0",
    sender: stringValue(deposit.sender) ?? null,
    flowchainRecipient: stringValue(deposit.flowchainRecipient) ?? stringValue(deposit.recipient) ?? null,
    status: stringValue(deposit.status) ?? stringValue(observation.status) ?? "observed",
    observedAt: stringValue(observation.observedAt) ?? stringValue(deposit.observedAt) ?? null,
    capGuardrail: {
      maxUsd: numberValue(asObject(observation.guardrails)?.maxUsd) ?? (mode === "base-mainnet-canary" ? PILOT_PER_DEPOSIT_CAP_USD : null),
      explicitChainId: asObject(observation.guardrails)?.explicitChainId === true,
      explicitContract: asObject(observation.guardrails)?.explicitContract === true,
      noSecrets: asObject(observation.guardrails)?.noSecrets !== false,
    },
    localOnly: true,
    productionReady: false,
  };
}

function pilotDepositRows(state: LoadedControlPlaneState): JsonObject[] {
  const rows = [
    ...state.bridgeObservations,
    ...handoffRows(state, "observations"),
    ...devnetObjectRows(state, ["bridgeObservations", "bridgeDeposits", "deposits"]),
  ].map(normalizeDepositObservation);

  const replaySeen = new Set<string>();
  return rows.map((row) => {
    const replayKey = stringValue(row.replayKey) ?? "";
    const replayStatus = replaySeen.has(replayKey) ? "duplicate_replay_rejected" : "accepted";
    replaySeen.add(replayKey);
    return {
      ...row,
      replayStatus,
    };
  }).sort((left, right) => String(left.observationId).localeCompare(String(right.observationId)));
}

function normalizeCredit(credit: JsonObject, deposits: JsonObject[]): JsonObject {
  const source = asObject(credit.source);
  const depositId = stringValue(credit.depositId);
  const matchedDeposit = deposits.find((deposit) => deposit.depositId === depositId || deposit.replayKey === credit.replayKey);
  const creditId = stringValue(credit.creditId)
    ?? stringValue(credit.bridgeCreditId)
    ?? stableId("flowmemory.control_plane.real_value_pilot_credit.v0", credit);
  const sourceChainId = numberValue(source?.chainId)
    ?? numberValue(credit.sourceChainId)
    ?? numberValue(matchedDeposit?.sourceChainId);

  return {
    schema: "flowmemory.control_plane.real_value_pilot_credit.v0",
    creditId,
    observationId: stringValue(credit.observationId) ?? stringValue(matchedDeposit?.observationId),
    depositId: depositId ?? stringValue(matchedDeposit?.depositId),
    replayKey: stringValue(credit.replayKey) ?? stringValue(matchedDeposit?.replayKey),
    mode: modeFor({ ...credit, sourceChainId }),
    baseMainnet: sourceChainId === BASE_MAINNET_CHAIN_ID,
    sourceChainId: sourceChainId ?? null,
    sourceContract: stringValue(source?.contract) ?? stringValue(matchedDeposit?.sourceContract),
    txHash: stringValue(source?.txHash) ?? stringValue(credit.sourceTxId) ?? stringValue(matchedDeposit?.txHash),
    logIndex: numberValue(source?.logIndex) ?? numberValue(matchedDeposit?.logIndex),
    accountId: stringValue(credit.accountId) ?? stringValue(credit.recipient) ?? stringValue(credit.flowchainRecipient),
    amount: stringValue(credit.amount) ?? stringValue(credit.amountUnits) ?? "0",
    token: stringValue(credit.token) ?? stringValue(credit.assetId) ?? stringValue(matchedDeposit?.token),
    status: stringValue(credit.status) ?? (stringValue(credit.bridgeCreditId) !== null ? "applied" : "pending"),
    appliedAt: stringValue(credit.appliedAt) ?? stringValue(credit.creditedAtBlock),
    rejectionReason: stringValue(credit.rejectionReason),
    localOnly: true,
    productionReady: false,
  };
}

function pilotCreditRows(state: LoadedControlPlaneState): JsonObject[] {
  const deposits = pilotDepositRows(state);
  const rows = [
    ...handoffRows(state, "credits"),
    ...devnetObjectRows(state, ["bridgeCredits", "bridgeCreditReceipts", "runtimeBridgeCredits"]),
  ].map((credit) => normalizeCredit(credit, deposits));

  for (const deposit of deposits) {
    const hasCredit = rows.some((credit) => credit.depositId === deposit.depositId || credit.replayKey === deposit.replayKey);
    if (!hasCredit) {
      rows.push(normalizeCredit({
        creditId: stableId("flowmemory.control_plane.real_value_pilot_projected_credit.v0", deposit),
        observationId: deposit.observationId,
        depositId: deposit.depositId,
        replayKey: deposit.replayKey,
        source: {
          chainId: deposit.sourceChainId,
          contract: deposit.sourceContract,
          txHash: deposit.txHash,
          logIndex: deposit.logIndex,
        },
        token: deposit.token,
        amount: deposit.amount,
        flowchainRecipient: deposit.flowchainRecipient,
        status: deposit.replayStatus === "duplicate_replay_rejected" ? "rejected" : "pending",
        rejectionReason: deposit.replayStatus === "duplicate_replay_rejected" ? "duplicate_replay_key" : undefined,
      }, deposits));
    }
  }

  return dedupeRows(rows, ["creditId", "depositId", "replayKey"]);
}

function normalizeWithdrawalIntent(intent: JsonObject, credits: JsonObject[]): JsonObject {
  const creditId = stringValue(intent.creditId);
  const matchedCredit = credits.find((credit) => credit.creditId === creditId || credit.depositId === intent.depositId);
  const withdrawalIntentId = stringValue(intent.withdrawalIntentId)
    ?? stringValue(intent.withdrawalId)
    ?? stableId("flowmemory.control_plane.real_value_pilot_withdrawal_intent.v0", intent);

  return {
    schema: "flowmemory.control_plane.real_value_pilot_withdrawal_intent.v0",
    withdrawalIntentId,
    creditId: creditId ?? stringValue(matchedCredit?.creditId),
    depositId: stringValue(intent.depositId) ?? stringValue(matchedCredit?.depositId),
    sourceChainId: numberValue(intent.sourceChainId) ?? numberValue(matchedCredit?.sourceChainId),
    destinationChainId: numberValue(intent.destinationChainId) ?? numberValue(intent.destinationChain) ?? BASE_MAINNET_CHAIN_ID,
    token: stringValue(intent.token) ?? stringValue(matchedCredit?.token),
    amount: stringValue(intent.amount) ?? stringValue(matchedCredit?.amount) ?? "0",
    flowchainAccount: stringValue(intent.flowchainAccount) ?? stringValue(matchedCredit?.accountId),
    baseRecipient: stringValue(intent.baseRecipient) ?? stringValue(intent.recipient),
    status: stringValue(intent.status) ?? "requested",
    requestedAt: stringValue(intent.requestedAt) ?? null,
    broadcast: intent.broadcast === true,
    releasePolicy: stringValue(intent.releasePolicy) ?? "operator_release_evidence_required",
    localOnly: true,
    productionReady: false,
  };
}

function pilotWithdrawalRows(state: LoadedControlPlaneState): JsonObject[] {
  const credits = pilotCreditRows(state);
  return dedupeRows([
    ...handoffRows(state, "withdrawalIntents"),
    ...devnetObjectRows(state, ["withdrawalIntents", "bridgeWithdrawalIntents", "withdrawals", "bridgeWithdrawals"]),
  ].map((intent) => normalizeWithdrawalIntent(intent, credits)), ["withdrawalIntentId", "creditId", "depositId"]);
}

function normalizeReleaseEvidence(evidence: JsonObject): JsonObject {
  const releaseCall = asObject(evidence.releaseCall);
  return {
    schema: "flowmemory.control_plane.real_value_pilot_release_evidence.v0",
    releaseEvidenceId: stringValue(evidence.releaseEvidenceId)
      ?? stringValue(evidence.evidenceId)
      ?? stableId("flowmemory.control_plane.real_value_pilot_release_evidence.v0", evidence),
    withdrawalIntentId: stringValue(evidence.withdrawalIntentId) ?? stringValue(evidence.withdrawalId),
    creditId: stringValue(evidence.creditId),
    depositId: stringValue(evidence.depositId),
    status: stringValue(evidence.status) ?? "recorded",
    releaseTxHash: stringValue(evidence.releaseTxHash) ?? stringValue(evidence.txHash),
    amount: stringValue(evidence.amount) ?? stringValue(releaseCall?.amount) ?? "0",
    token: stringValue(evidence.token) ?? stringValue(releaseCall?.token),
    baseRecipient: stringValue(evidence.baseRecipient) ?? stringValue(releaseCall?.recipient),
    releasedAt: stringValue(evidence.releasedAt) ?? stringValue(evidence.recordedAt),
    evidenceURI: stringValue(evidence.evidenceURI) ?? null,
    operatorNote: stringValue(evidence.operatorNote) ?? null,
    localOnly: true,
    productionReady: false,
  };
}

function pilotReleaseEvidenceRows(state: LoadedControlPlaneState): JsonObject[] {
  const native = [
    ...handoffRowsAny(state, ["releaseEvidence", "releaseEvidences"]),
    ...devnetObjectRows(state, ["releaseEvidence", "bridgeReleaseEvidence", "releaseEvidenceRecords"]),
  ].map(normalizeReleaseEvidence);

  const withdrawals = pilotWithdrawalRows(state);
  const derived = withdrawals.map((intent) => {
    const released = stringValue(intent.status) === "released" || stringValue(intent.status) === "released_test_record";
    return normalizeReleaseEvidence({
      releaseEvidenceId: stableId("flowmemory.control_plane.real_value_pilot_derived_release_evidence.v0", intent),
      withdrawalIntentId: intent.withdrawalIntentId,
      creditId: intent.creditId,
      depositId: intent.depositId,
      status: released ? "recorded" : "pending_operator_release_evidence",
      evidenceURI: null,
      operatorNote: released
        ? "Release record was present in the withdrawal intent."
        : "Withdrawal intent exists, but no release evidence has been exported yet.",
    });
  });

  return dedupeRows([...native, ...derived], ["releaseEvidenceId", "withdrawalIntentId"]);
}

function dedupeRows(rows: JsonObject[], keys: string[]): JsonObject[] {
  const byId = new Map<string, JsonObject>();
  for (const row of rows) {
    const id = keys.map((key) => stringValue(row[key])).find((value): value is string => value !== null)
      ?? stableId("flowmemory.control_plane.real_value_pilot_dedupe.v0", row);
    if (!byId.has(id)) {
      byId.set(id, row);
    }
  }
  return [...byId.values()].sort((left, right) => {
    const leftId = keys.map((key) => stringValue(left[key])).find((value): value is string => value !== null) ?? "";
    const rightId = keys.map((key) => stringValue(right[key])).find((value): value is string => value !== null) ?? "";
    return leftId.localeCompare(rightId);
  });
}

function statusIsApplied(value: JsonValue | undefined): boolean {
  const status = stringValue(value)?.toLowerCase();
  return status === "applied" || status === "credited" || status === "local_credit" || status === "verified";
}

function configuredEmergency(state: LoadedControlPlaneState): JsonObject {
  const object = asObject(state.bridgeRuntimeHandoff?.emergency)
    ?? asObject(state.devnetControlPlaneHandoff?.emergency)
    ?? asObject(state.devnet?.emergency)
    ?? {};
  return object;
}

function configuredPause(state: LoadedControlPlaneState): JsonObject {
  const object = asObject(state.bridgeRuntimeHandoff?.pause)
    ?? asObject(state.devnetControlPlaneHandoff?.pause)
    ?? asObject(state.devnet?.pause)
    ?? {};
  return object;
}

function bigintAmount(value: JsonValue | undefined): bigint {
  const textValue = stringValue(value) ?? "0";
  return /^\d+$/.test(textValue) ? BigInt(textValue) : 0n;
}

function envText(name: string): string | undefined {
  const value = process.env[name];
  return value === undefined || value.trim() === "" ? undefined : value;
}

function envConfigured(name: string): boolean {
  return envText(name) !== undefined;
}

function firstConfiguredEnv(names: readonly string[]): string | null {
  return names.find((name) => envConfigured(name)) ?? null;
}

function envUintCheck(name: string, min?: bigint, max?: bigint): JsonObject {
  const value = envText(name);
  const configured = value !== undefined;
  const decimal = configured && /^\d+$/.test(value);
  const parsed = decimal ? BigInt(value) : null;
  const withinMin = parsed === null || min === undefined || parsed >= min;
  const withinMax = parsed === null || max === undefined || parsed <= max;
  return {
    envName: name,
    configured,
    decimal,
    withinPolicy: configured && decimal && withinMin && withinMax,
    minimumAccepted: min?.toString() ?? null,
    maximumAccepted: max?.toString() ?? null,
  };
}

function envPositiveNumber(name: string, fallback: number): { envName: string; configured: boolean; valid: boolean; seconds: number } {
  const value = envText(name);
  if (value === undefined) {
    return { envName: name, configured: false, valid: true, seconds: fallback };
  }
  const parsed = Number(value);
  return {
    envName: name,
    configured: true,
    valid: Number.isFinite(parsed) && parsed > 0,
    seconds: Number.isFinite(parsed) && parsed > 0 ? parsed : fallback,
  };
}

function readinessIssue(reasonCode: string, status: "blocked" | "failed" | "warning", title: string, summary: string, envNames: string[] = []): JsonObject {
  return {
    schema: "flowmemory.control_plane.bridge_live_readiness_issue.v0",
    reasonCode,
    status,
    title,
    summary,
    envNames,
  };
}

function sourceModeLabel(row: JsonObject | null | undefined): string {
  const mode = stringValue(row?.mode);
  if (mode !== null) {
    return mode;
  }
  const sourceChainId = numberValue(row?.sourceChainId);
  if (sourceChainId === BASE_MAINNET_CHAIN_ID) {
    return "base-mainnet-pilot";
  }
  if (sourceChainId === 84532) {
    return "base-sepolia-or-mock";
  }
  return "local-or-mock";
}

function sourceArtifactClass(row: JsonObject | null | undefined): string {
  return numberValue(row?.sourceChainId) === BASE_MAINNET_CHAIN_ID || row?.baseMainnet === true
    ? "live-base8453"
    : "local-or-mock";
}

function runtimeApplicationRows(state: LoadedControlPlaneState): JsonObject[] {
  return [
    ...handoffRows(state, "runtimeApplications"),
    ...devnetObjectRows(state, ["runtimeApplications", "bridgeRuntimeApplications", "bridgeCreditApplications"]),
  ];
}

function proofTransferRows(state: LoadedControlPlaneState): JsonObject[] {
  const proof = state.walletTransferProof;
  const transfer = asObject(proof?.transfer);
  const receipt = asObject(transfer?.receipt);
  if (proof === null || transfer === null || receipt === null) {
    return [];
  }
  return [{
    schema: "flowmemory.control_plane.wallet_transfer.v0",
    transferId: stringValue(receipt.txId) ?? stringValue(transfer.txId) ?? stableId("flowmemory.control_plane.wallet_transfer.proof.v0", receipt),
    txId: stringValue(receipt.txId) ?? stringValue(transfer.txId),
    fromAccountId: stringValue(receipt.from),
    toAccountId: stringValue(receipt.to),
    assetId: stringValue(receipt.assetId),
    amount: stringValue(receipt.amount) ?? "0",
    status: stringValue(receipt.status) ?? "applied",
    balancesBefore: asObject(receipt.balancesBefore) ?? {},
    balancesAfter: asObject(receipt.balancesAfter) ?? {},
    fundingSource: stringValue(asObject(proof.funding)?.source) ?? null,
    evidenceFilePath: state.paths.walletTransferProofPath,
    source: "wallet-transfer-proof",
    localOnly: true,
    productionReady: false,
  }];
}

function walletTransferRows(state: LoadedControlPlaneState): JsonObject[] {
  const native = devnetObjectRows(state, ["balanceTransfers", "walletTransfers", "transfers", "tokenTransfers"]).map((transfer) => ({
    schema: "flowmemory.control_plane.wallet_transfer.v0",
    transferId: stringValue(transfer.transferId)
      ?? stringValue(transfer.txId)
      ?? stringValue(transfer.transactionId)
      ?? stableId("flowmemory.control_plane.wallet_transfer.native.v0", transfer),
    txId: stringValue(transfer.txId) ?? stringValue(transfer.transactionId),
    fromAccountId: stringValue(transfer.fromAccountId) ?? stringValue(transfer.from) ?? stringValue(transfer.sender),
    toAccountId: stringValue(transfer.toAccountId) ?? stringValue(transfer.to) ?? stringValue(transfer.recipient),
    assetId: stringValue(transfer.assetId) ?? stringValue(transfer.tokenId) ?? stringValue(transfer.token),
    amount: stringValue(transfer.amount) ?? stringValue(transfer.amountUnits) ?? "0",
    status: stringValue(transfer.status) ?? "applied",
    transfer,
    source: "local-devnet",
    localOnly: true,
    productionReady: false,
  }));
  return dedupeRows([...native, ...proofTransferRows(state)], ["transferId", "txId"]);
}

function walletBalanceRows(state: LoadedControlPlaneState): JsonObject[] {
  const rows: JsonObject[] = [];
  for (const credit of pilotCreditRows(state).filter((row) => statusIsApplied(row.status))) {
    rows.push({
      schema: "flowmemory.control_plane.wallet_balance.v0",
      balanceId: stableId("flowmemory.control_plane.wallet_balance.bridge_credit.v0", credit),
      walletAddress: stringValue(credit.accountId) ?? "not recorded",
      asset: stringValue(credit.token) ?? "not recorded",
      amount: stringValue(credit.amount) ?? "0",
      creditedAmount: stringValue(credit.amount) ?? "0",
      creditId: stringValue(credit.creditId),
      depositId: stringValue(credit.depositId),
      status: "credited",
      source: "bridge-credit",
      localOnly: true,
      productionReady: false,
    });
  }

  for (const transfer of proofTransferRows(state)) {
    const before = asObject(transfer.balancesBefore) ?? {};
    const after = asObject(transfer.balancesAfter) ?? {};
    const from = stringValue(transfer.fromAccountId);
    const to = stringValue(transfer.toAccountId);
    const asset = stringValue(transfer.assetId) ?? "not recorded";
    if (from !== null) {
      rows.push({
        schema: "flowmemory.control_plane.wallet_balance.v0",
        balanceId: stableId("flowmemory.control_plane.wallet_balance.transfer.from.v0", transfer),
        walletAddress: from,
        asset,
        amount: stringValue(after.from) ?? "0",
        previousAmount: stringValue(before.from) ?? null,
        transferId: stringValue(transfer.transferId),
        status: "after_transfer",
        source: "wallet-transfer-proof",
        evidenceFilePath: state.paths.walletTransferProofPath,
        localOnly: true,
        productionReady: false,
      });
    }
    if (to !== null) {
      rows.push({
        schema: "flowmemory.control_plane.wallet_balance.v0",
        balanceId: stableId("flowmemory.control_plane.wallet_balance.transfer.to.v0", transfer),
        walletAddress: to,
        asset,
        amount: stringValue(after.to) ?? "0",
        previousAmount: stringValue(before.to) ?? null,
        transferId: stringValue(transfer.transferId),
        status: "after_transfer",
        source: "wallet-transfer-proof",
        evidenceFilePath: state.paths.walletTransferProofPath,
        localOnly: true,
        productionReady: false,
      });
    }
  }

  return dedupeRows(rows, ["balanceId", "walletAddress", "asset"]);
}

function buildBridgeLiveReadiness(state: LoadedControlPlaneState): JsonObject {
  const deposits = pilotDepositRows(state);
  const credits = pilotCreditRows(state);
  const caps = capStatus(state, deposits);
  const retry = retryStatus(state, deposits, credits);
  const confirmationEnvName = firstConfiguredEnv(CONFIRMATION_DEPTH_ENV_NAMES);
  const requiredMissing = [
    ...LIVE_REQUIRED_ENV_NAMES.filter((name) => !envConfigured(name)),
    ...(confirmationEnvName === null ? ["FLOWCHAIN_PILOT_CONFIRMATIONS"] : []),
  ];
  const tokenMode = envText("FLOWCHAIN_BASE8453_TOKEN_MODE")?.toLowerCase() ?? "native";
  const tokenRequired = ["erc20", "token", "supported-token"].includes(tokenMode);
  const tokenMissing = tokenRequired && !envConfigured("FLOWCHAIN_BASE8453_SUPPORTED_TOKEN")
    ? ["FLOWCHAIN_BASE8453_SUPPORTED_TOKEN"]
    : [];
  const missingEnvNames = [...new Set([...requiredMissing, ...tokenMissing])].sort();
  const confirmation = envUintCheck(
    confirmationEnvName ?? "FLOWCHAIN_PILOT_CONFIRMATIONS",
    BigInt(MIN_CONFIRMATION_DEPTH),
    BigInt(MAX_CONFIRMATION_DEPTH),
  );
  const confirmationText = confirmationEnvName === null ? undefined : envText(confirmationEnvName);
  const confirmationValue = confirmationText !== undefined && /^\d+$/.test(confirmationText) ? Number(BigInt(confirmationText)) : null;
  const targetSettlement = envPositiveNumber("FLOWCHAIN_BRIDGE_TARGET_SETTLEMENT_SECONDS", 30);
  const estimatedBaseBlock = envPositiveNumber("FLOWCHAIN_BASE8453_ESTIMATED_BLOCK_SECONDS", 2);
  const bridgePoll = envPositiveNumber("FLOWCHAIN_BRIDGE_POLL_SECONDS", 30);
  const estimatedConfirmationSeconds = confirmationValue === null ? null : confirmationValue * estimatedBaseBlock.seconds;
  const estimatedDetectionSeconds = estimatedConfirmationSeconds === null ? null : estimatedConfirmationSeconds + bridgePoll.seconds;
  const settlementTargetFeasible = estimatedDetectionSeconds !== null
    && targetSettlement.valid
    && estimatedBaseBlock.valid
    && bridgePoll.valid
    && estimatedDetectionSeconds <= targetSettlement.seconds;
  const maxDeposit = envUintCheck("FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI", 1n);
  const totalCap = envUintCheck("FLOWCHAIN_PILOT_TOTAL_CAP_WEI", 1n);
  const operatorAckAccepted = envText("FLOWCHAIN_PILOT_OPERATOR_ACK") === REQUIRED_OPERATOR_ACK;
  const devnetSourceStatus = state.sources.devnet?.status ?? "missing";
  const nodeAvailable = state.devnet !== null && devnetSourceStatus !== "missing" && devnetSourceStatus !== "degraded";
  const baseDeposits = deposits.filter((deposit) => deposit.baseMainnet === true);
  const issues: JsonObject[] = [];

  if (!nodeAvailable) {
    issues.push(readinessIssue(
      devnetSourceStatus === "degraded" ? "local_runtime_state_degraded" : "node_offline",
      "blocked",
      devnetSourceStatus === "degraded" ? "Local runtime state degraded" : "Node offline",
      devnetSourceStatus === "degraded"
        ? "The active local FlowChain runtime state could not be parsed; the control-plane failed closed to fallback data."
        : "No local runtime/devnet state is available to prove credit application.",
    ));
  }
  if (missingEnvNames.length > 0) {
    issues.push(readinessIssue("missing_env", "blocked", "Missing live pilot env", "Live readiness is blocked until all required env names are present.", missingEnvNames));
  }
  if (!operatorAckAccepted) {
    issues.push(readinessIssue("operator_ack_missing", "blocked", "Operator acknowledgement missing", "The exact capped-owner-pilot acknowledgement is not present.", ["FLOWCHAIN_PILOT_OPERATOR_ACK"]));
  }
  if (confirmation.configured === true && confirmation.withinPolicy !== true) {
    issues.push(readinessIssue("insufficient_confirmations", "failed", "Confirmation depth outside policy", "The configured confirmation depth is missing, non-decimal, below the minimum, or above the pilot maximum.", [...CONFIRMATION_DEPTH_ENV_NAMES]));
  }
  if (!targetSettlement.valid || !estimatedBaseBlock.valid || !bridgePoll.valid) {
    issues.push(readinessIssue("settlement_policy_invalid", "failed", "Settlement policy invalid", "Fast bridge timing env values must be positive numbers.", [
      "FLOWCHAIN_BRIDGE_TARGET_SETTLEMENT_SECONDS",
      "FLOWCHAIN_BASE8453_ESTIMATED_BLOCK_SECONDS",
      "FLOWCHAIN_BRIDGE_POLL_SECONDS",
    ]));
  }
  if (confirmation.configured === true && settlementTargetFeasible === false) {
    issues.push(readinessIssue("settlement_target_missed", "failed", "Settlement target cannot be met", "The configured confirmation depth plus polling interval exceeds the fast bridge target.", [
      ...(CONFIRMATION_DEPTH_ENV_NAMES as readonly string[]),
      "FLOWCHAIN_BRIDGE_TARGET_SETTLEMENT_SECONDS",
      "FLOWCHAIN_BRIDGE_POLL_SECONDS",
    ]));
  }
  if (maxDeposit.configured === true && maxDeposit.withinPolicy !== true) {
    issues.push(readinessIssue("cap_exceeded", "failed", "Per-deposit cap outside policy", "The per-deposit cap is missing, non-decimal, or zero.", ["FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI"]));
  }
  if (totalCap.configured === true && totalCap.withinPolicy !== true) {
    issues.push(readinessIssue("cap_exceeded", "failed", "Total cap outside policy", "The total pilot cap is missing, non-decimal, or zero.", ["FLOWCHAIN_PILOT_TOTAL_CAP_WEI"]));
  }
  if (caps.withinCap === false) {
    issues.push(readinessIssue("cap_exceeded", "failed", "Observed cap exceeded", "Visible pilot evidence reports a cap breach."));
  }
  if (asArray(retry.duplicateReplayKeys).length > 0) {
    issues.push(readinessIssue("replay_rejected", "warning", "Replay rejected", "Duplicate replay keys are visible and rejected by the pilot surface."));
  }
  if (tokenRequired && tokenMissing.length > 0) {
    issues.push(readinessIssue("unsupported_asset", "blocked", "Supported asset missing", "Token mode requires an explicit supported-token env name.", tokenMissing));
  }
  if (baseDeposits.length === 0) {
    issues.push(readinessIssue("no_deposits_observed", "blocked", "No Base deposits observed", "No Base chain ID 8453 deposit artifact is visible in the control-plane state."));
  }

  const failed = issues.some((issue) => issue.status === "failed");
  const blocked = issues.some((issue) => issue.status === "blocked");
  const failClosedStatus = failed ? "FAILED" : blocked ? "BLOCKED" : "READY_FOR_OPERATOR_LIVE_PILOT";

  return {
    schema: "flowmemory.control_plane.bridge_live_readiness.v0",
    generatedAt: state.launchCore.generatedAt,
    baseChainId: BASE_MAINNET_CHAIN_ID,
    baseChainName: "Base",
    failClosedStatus,
    machineStatus: failClosedStatus === "READY_FOR_OPERATOR_LIVE_PILOT" ? "ready" : failClosedStatus.toLowerCase(),
    readyForOperatorLivePilot: failClosedStatus === "READY_FOR_OPERATOR_LIVE_PILOT",
    node: {
      running: nodeAvailable,
      sourceStatus: devnetSourceStatus,
      chainId: stringValue(state.devnet?.chainId) ?? "missing",
    },
    lockbox: {
      configured: envConfigured("FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS"),
      envName: "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
      ownerVerified: false,
      ownerVerificationRequired: true,
    },
    baseReaderEndpoint: {
      configured: envConfigured("FLOWCHAIN_BASE8453_RPC_URL"),
      envName: "FLOWCHAIN_BASE8453_RPC_URL",
      valuePrinted: false,
    },
    blockRange: {
      fromConfigured: envConfigured("FLOWCHAIN_BASE8453_FROM_BLOCK"),
      toConfigured: envConfigured("FLOWCHAIN_BASE8453_TO_BLOCK"),
      fromEnvName: "FLOWCHAIN_BASE8453_FROM_BLOCK",
      toEnvName: "FLOWCHAIN_BASE8453_TO_BLOCK",
      valuesPrinted: false,
    },
    confirmationDepth: {
      ...confirmation,
      acceptedEnvNames: [...CONFIRMATION_DEPTH_ENV_NAMES],
      valuePrinted: false,
    },
    settlementPolicy: {
      targetSettlementSeconds: {
        envName: targetSettlement.envName,
        configured: targetSettlement.configured,
        valid: targetSettlement.valid,
        defaultSeconds: 30,
        valuePrinted: false,
      },
      estimatedBaseBlockSeconds: {
        envName: estimatedBaseBlock.envName,
        configured: estimatedBaseBlock.configured,
        valid: estimatedBaseBlock.valid,
        defaultSeconds: 2,
        valuePrinted: false,
      },
      bridgePollSeconds: {
        envName: bridgePoll.envName,
        configured: bridgePoll.configured,
        valid: bridgePoll.valid,
        defaultSeconds: 30,
        valuePrinted: false,
      },
      estimatedConfirmationSeconds,
      estimatedDetectionSeconds,
      targetFeasible: settlementTargetFeasible,
    },
    capSettings: {
      perDeposit: {
        ...maxDeposit,
        valuePrinted: false,
      },
      totalPilot: {
        ...totalCap,
        valuePrinted: false,
      },
      observedWithinCap: caps.withinCap === true,
    },
    supportedAsset: {
      tokenMode,
      supportedTokenConfigured: envConfigured("FLOWCHAIN_BASE8453_SUPPORTED_TOKEN"),
      supportedTokenEnvName: "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
      valuePrinted: false,
    },
    operatorAck: {
      configured: envConfigured("FLOWCHAIN_PILOT_OPERATOR_ACK"),
      accepted: operatorAckAccepted,
      requiredValuePrinted: false,
      envName: "FLOWCHAIN_PILOT_OPERATOR_ACK",
    },
    missingEnvNames,
    requiredEnvNames: [...LIVE_REQUIRED_ENV_NAMES, "one of FLOWCHAIN_PILOT_CONFIRMATIONS or FLOWCHAIN_BASE8453_CONFIRMATION_DEPTH"],
    optionalEnvNames: [...LIVE_OPTIONAL_ENV_NAMES],
    currentArtifacts: {
      base8453DepositCount: baseDeposits.length,
      localOrMockDepositCount: deposits.length - baseDeposits.length,
      mockPresentedAsLive: false,
    },
    issues,
    envValuesPrinted: false,
    localOnly: true,
    productionReady: false,
  };
}

function valueEquality(values: Record<string, string | null>): JsonObject {
  const present = Object.values(values).filter((value): value is string => value !== null && value.length > 0 && value !== "0");
  const baseline = values.depositAmount ?? present[0] ?? "0";
  const equalities = Object.fromEntries(Object.entries(values).map(([key, value]) => [key, value === null ? null : value === baseline]));
  return {
    schema: "flowmemory.control_plane.bridge_exact_value_equality.v0",
    ...values,
    baselineAmount: baseline,
    equalities,
    allPresent: Object.values(values).every((value) => value !== null),
    allEqual: Object.values(values).every((value) => value !== null && value === baseline),
  };
}

function buildLifecycleRecords(state: LoadedControlPlaneState): JsonObject[] {
  const deposits = pilotDepositRows(state);
  const credits = pilotCreditRows(state);
  const withdrawals = pilotWithdrawalRows(state);
  const releases = pilotReleaseEvidenceRows(state);
  const applications = runtimeApplicationRows(state);
  const transfers = walletTransferRows(state);

  return deposits.map((deposit) => {
    const credit = credits.find((candidate) => candidate.depositId === deposit.depositId || candidate.replayKey === deposit.replayKey) ?? null;
    const application = applications.find((candidate) => stringValue(candidate.creditId) === credit?.creditId || stringValue(candidate.depositId) === deposit.depositId) ?? null;
    const withdrawal = withdrawals.find((candidate) => candidate.creditId === credit?.creditId || candidate.depositId === deposit.depositId) ?? null;
    const matchingReleases = releases.filter((candidate) =>
      candidate.creditId === credit?.creditId ||
      candidate.depositId === deposit.depositId ||
      candidate.withdrawalIntentId === withdrawal?.withdrawalIntentId
    );
    const release = matchingReleases.find((candidate) => {
      const status = stringValue(candidate.status);
      return status === "recorded" || status === "released";
    }) ?? matchingReleases[0] ?? null;
    const transfer = transfers.find((candidate) => {
      const accountId = stringValue(credit?.accountId);
      const asset = stringValue(credit?.token);
      const from = stringValue(candidate.fromAccountId);
      const to = stringValue(candidate.toAccountId);
      const transferAsset = stringValue(candidate.assetId);
      return accountId !== null && (from === accountId || to === accountId) && (asset === null || transferAsset === null || transferAsset === asset);
    }) ?? null;
    const depositAmount = stringValue(deposit.amount) ?? "0";
    const creditAmount = stringValue(credit?.amount);
    const withdrawalAmount = stringValue(withdrawal?.amount);
    const releaseAmount = stringValue(release?.amount) ?? stringValue(withdrawal?.amount);
    const transferAmount = stringValue(transfer?.amount);
    const equality = valueEquality({
      depositAmount,
      observedAmount: depositAmount,
      creditedAmount: creditAmount,
      walletDelta: stringValue(application?.amount) ?? creditAmount,
      transferableAmount: transferAmount ?? creditAmount,
      withdrawalAmount,
      releaseAmount,
    });
    const status = release !== null && stringValue(release.status) === "recorded"
      ? "release_evidence_recorded"
      : withdrawal !== null
        ? "withdrawal_intent_recorded"
        : credit !== null && statusIsApplied(credit.status)
          ? "credited"
          : credit !== null
            ? stringValue(credit.status) ?? "pending"
            : stringValue(deposit.status) ?? "observed";

    return {
      schema: "flowmemory.control_plane.bridge_lifecycle_record.v0",
      lifecycleRecordId: stableId("flowmemory.control_plane.bridge_lifecycle_record.v0", {
        depositId: deposit.depositId,
        creditId: credit?.creditId ?? null,
        withdrawalIntentId: withdrawal?.withdrawalIntentId ?? null,
        releaseEvidenceId: release?.releaseEvidenceId ?? null,
      }),
      baseTxHash: stringValue(deposit.txHash),
      txHash: stringValue(deposit.txHash),
      logIndex: numberValue(deposit.logIndex),
      creditId: stringValue(credit?.creditId),
      depositId: stringValue(deposit.depositId),
      replayKey: stringValue(deposit.replayKey) ?? stringValue(credit?.replayKey),
      replayStatus: stringValue(deposit.replayStatus),
      recipientWallet: stringValue(credit?.accountId) ?? stringValue(deposit.flowchainRecipient),
      sourceWallet: stringValue(deposit.sender),
      withdrawalIntentId: stringValue(withdrawal?.withdrawalIntentId),
      withdrawalStatus: stringValue(withdrawal?.status),
      releaseRecipient: stringValue(release?.baseRecipient) ?? stringValue(withdrawal?.baseRecipient),
      releaseEvidenceId: stringValue(release?.releaseEvidenceId),
      releaseStatus: stringValue(release?.status),
      asset: stringValue(credit?.token) ?? stringValue(deposit.token),
      amountSmallestUnits: depositAmount,
      status,
      sourceChainId: numberValue(deposit.sourceChainId),
      mode: sourceModeLabel(deposit),
      artifactClass: sourceArtifactClass(deposit),
      liveArtifact: deposit.baseMainnet === true,
      evidenceFilePath: state.paths.bridgeRuntimeHandoffPath,
      evidenceFileId: stringValue(release?.releaseEvidenceId)
        ?? stringValue(withdrawal?.withdrawalIntentId)
        ?? stringValue(credit?.creditId)
        ?? stringValue(deposit.observationId),
      equality,
      depositObservation: deposit,
      credit,
      runtimeApplication: application,
      transfer,
      withdrawalIntent: withdrawal,
      releaseEvidence: release,
      localOnly: true,
      productionReady: false,
    };
  });
}

function summarizeExactValueChecks(records: JsonObject[]): JsonObject {
  const equalityRows = records.map((record) => asObject(record.equality)).filter((row): row is JsonObject => row !== null);
  return {
    schema: "flowmemory.control_plane.bridge_exact_value_summary.v0",
    recordCount: records.length,
    allRecordsExact: records.length > 0 && equalityRows.every((row) => row.allEqual === true),
    exactRecordIds: records
      .filter((record) => asObject(record.equality)?.allEqual === true)
      .map((record) => stringValue(record.lifecycleRecordId))
      .filter((value): value is string => value !== null),
    nonExactRecordIds: records
      .filter((record) => asObject(record.equality)?.allEqual !== true)
      .map((record) => stringValue(record.lifecycleRecordId))
      .filter((value): value is string => value !== null),
  };
}

function capStatus(state: LoadedControlPlaneState, deposits: JsonObject[]): JsonObject {
  const capConfig = asObject(state.bridgeRuntimeHandoff?.capStatus)
    ?? asObject(state.devnetControlPlaneHandoff?.capStatus)
    ?? asObject(state.devnet?.capStatus)
    ?? {};
  const observedTotal = deposits.reduce((sum, deposit) => sum + bigintAmount(deposit.amount), 0n);
  const maxGuardrailUsd = deposits
    .map((deposit) => numberValue(asObject(deposit.capGuardrail)?.maxUsd))
    .filter((value): value is number => value !== null)
    .sort((left, right) => right - left)[0] ?? null;
  const configuredPerDepositUsd = numberValue(capConfig.perDepositUsd) ?? PILOT_PER_DEPOSIT_CAP_USD;
  const configuredTotalUsd = numberValue(capConfig.totalUsd) ?? PILOT_TOTAL_CAP_USD;
  const breached = maxGuardrailUsd !== null && maxGuardrailUsd > configuredPerDepositUsd;

  return {
    schema: "flowmemory.control_plane.real_value_pilot_cap_status.v0",
    state: breached ? "error" : deposits.some((deposit) => deposit.baseMainnet === true) ? "live" : "degraded",
    cappedOwnerTesting: true,
    perDepositCapUsd: configuredPerDepositUsd,
    totalPilotCapUsd: configuredTotalUsd,
    observedDepositCount: deposits.length,
    observedTotalRawUnits: observedTotal.toString(),
    maxObservedGuardrailUsd: maxGuardrailUsd,
    withinCap: !breached,
    source: Object.keys(capConfig).length > 0 ? "handoff" : "default-capped-owner-testing-policy",
    nextOperatorCommand: breached ? "npm run flowchain:stop" : "npm run bridge:observe -- --mode base-mainnet-canary --acknowledge-real-funds --max-usd 25",
    localOnly: true,
    productionReady: false,
  };
}

function pauseStatus(state: LoadedControlPlaneState): JsonObject {
  const pause = configuredPause(state);
  const active = pause.active === true || pause.paused === true || stringValue(pause.status) === "paused";
  return {
    schema: "flowmemory.control_plane.real_value_pilot_pause_status.v0",
    state: active ? "error" : "live",
    active,
    status: active ? "paused" : "unpaused",
    reason: stringValue(pause.reason) ?? null,
    nextOperatorCommand: active ? "npm run flowchain:real-value-pilot:e2e -- --resume-after-pause" : "npm run bridge:observe -- --mode base-mainnet-canary --acknowledge-real-funds --max-usd 25",
    localOnly: true,
    productionReady: false,
  };
}

function retryStatus(state: LoadedControlPlaneState, deposits: JsonObject[], credits: JsonObject[]): JsonObject {
  const duplicateReplayKeys = asArray(asObject(state.bridgeRuntimeHandoff?.replayProtection)?.duplicateReplayKeys)
    .map((value) => stringValue(value))
    .filter((value): value is string => value !== null);
  const observedDuplicates = deposits
    .filter((deposit) => deposit.replayStatus === "duplicate_replay_rejected")
    .map((deposit) => stringValue(deposit.replayKey))
    .filter((value): value is string => value !== null);
  const duplicates = [...new Set([...duplicateReplayKeys, ...observedDuplicates])].sort();
  const rejectedDuplicates = credits.filter((credit) => stringValue(credit.rejectionReason) === "duplicate_replay_key").length;
  const failedRetries = credits.filter((credit) => stringValue(credit.status) === "failed").length;

  return {
    schema: "flowmemory.control_plane.real_value_pilot_retry_status.v0",
    state: failedRetries > 0 ? "error" : "live",
    replayStrategy: stringValue(asObject(state.bridgeRuntimeHandoff?.replayProtection)?.strategy) ?? "source-chain-contract-tx-log-deposit",
    duplicateReplayKeys: duplicates,
    rejectedDuplicateCredits: rejectedDuplicates,
    failedRetries,
    retryableCredits: credits.filter((credit) => stringValue(credit.status) === "pending").map((credit) => credit.creditId),
    nextOperatorCommand: failedRetries > 0 ? "npm run control-plane:smoke" : "npm run flowchain:real-value-pilot:e2e",
    localOnly: true,
    productionReady: false,
  };
}

function emergencyStatus(state: LoadedControlPlaneState): JsonObject {
  const emergency = configuredEmergency(state);
  const active = emergency.active === true || stringValue(emergency.status) === "active";
  return {
    schema: "flowmemory.control_plane.real_value_pilot_emergency_status.v0",
    state: active ? "error" : "live",
    active,
    status: active ? "active" : "standby",
    reason: stringValue(emergency.reason) ?? null,
    nextOperatorCommand: active ? "npm run flowchain:stop" : "npm run flowchain:real-value-pilot:e2e",
    recoveryCommand: "npm run flowchain:export",
    localOnly: true,
    productionReady: false,
  };
}

function lifecycleItem(phase: PilotPhase, state: PilotState, title: string, summary: string, command: string, evidenceIds: string[] = []): JsonObject {
  return {
    schema: "flowmemory.control_plane.real_value_pilot_lifecycle_step.v0",
    phase,
    state,
    title,
    summary,
    evidenceIds,
    nextOperatorCommand: command,
  };
}

function nextStep(lifecycle: JsonObject[], emergency: JsonObject): PilotStep {
  if (emergency.state === "error") {
    return {
      label: "Stop pilot and export evidence",
      command: "npm run flowchain:stop",
      reason: "Emergency state is active.",
    };
  }
  const degraded = lifecycle.find((item) => item.state !== "live");
  if (degraded !== undefined) {
    return {
      label: stringValue(degraded.title) ?? "Continue pilot",
      command: stringValue(degraded.nextOperatorCommand) ?? "npm run flowchain:real-value-pilot:e2e",
      reason: stringValue(degraded.summary) ?? "A pilot lifecycle phase is not live.",
    };
  }
  return {
    label: "Export pilot evidence",
    command: "npm run flowchain:export",
    reason: "All visible pilot lifecycle phases are live.",
  };
}

function buildPilotLifecycle(state: LoadedControlPlaneState): PilotLifecycle {
  const deposits = pilotDepositRows(state);
  const credits = pilotCreditRows(state);
  const withdrawals = pilotWithdrawalRows(state);
  const releases = pilotReleaseEvidenceRows(state);
  const baseDeposits = deposits.filter((deposit) => deposit.baseMainnet === true);
  const appliedCredits = credits.filter((credit) => statusIsApplied(credit.status));
  const withdrawalRequests = withdrawals.filter((withdrawal) => stringValue(withdrawal.status) !== "rejected");
  const recordedReleaseEvidence = releases.filter((release) => stringValue(release.status) === "recorded" || stringValue(release.status) === "released");
  const caps = capStatus(state, deposits);
  const pause = pauseStatus(state);
  const retry = retryStatus(state, deposits, credits);
  const emergency = emergencyStatus(state);
  const bridgeLiveReadiness = buildBridgeLiveReadiness(state);
  const lifecycleRecords = buildLifecycleRecords(state);
  const exactValueChecks = summarizeExactValueChecks(lifecycleRecords);
  const operationalStates = asArray(bridgeLiveReadiness.issues)
    .map((issue) => asObject(issue))
    .filter((issue): issue is JsonObject => issue !== null);
  const lifecycle = [
    lifecycleItem(
      "base_deposit_observed",
      baseDeposits.length > 0 ? "live" : deposits.length > 0 ? "degraded" : "error",
      baseDeposits.length > 0 ? "Base deposit observed" : "Observe Base 8453 deposit",
      baseDeposits.length > 0
        ? `${baseDeposits.length} Base 8453 pilot deposit observation(s) are visible.`
        : deposits.length > 0
          ? "Only mock/local/Base Sepolia bridge observations are visible; no Base 8453 pilot deposit has been loaded."
          : "No bridge observation is visible.",
      "npm run bridge:observe -- --mode base-mainnet-canary --rpc-url <FLOWCHAIN_BASE8453_RPC_URL> --lockbox-address <FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS> --from-block <n> --to-block <n> --acknowledge-real-funds --max-usd 25",
      baseDeposits.map((deposit) => stringValue(deposit.observationId) ?? "").filter((id) => id.length > 0),
    ),
    lifecycleItem(
      "local_credit_applied",
      appliedCredits.length > 0 ? "live" : credits.length > 0 ? "degraded" : "error",
      appliedCredits.length > 0 ? "Local credit applied" : "Apply local credit",
      appliedCredits.length > 0
        ? `${appliedCredits.length} local credit record(s) are applied or credited.`
        : "Bridge credit records are pending, rejected, or missing.",
      "npm run flowchain:real-value-pilot:e2e",
      appliedCredits.map((credit) => stringValue(credit.creditId) ?? "").filter((id) => id.length > 0),
    ),
    lifecycleItem(
      "replay_retry_checked",
      retry.state as PilotState,
      retry.state === "live" ? "Replay and retry status checked" : "Resolve replay or retry errors",
      retry.state === "live"
        ? "Replay protection is visible and no failed retry is reported."
        : "At least one retry path is failed.",
      stringValue(retry.nextOperatorCommand) ?? "npm run flowchain:real-value-pilot:e2e",
      asArray(retry.duplicateReplayKeys).map((value) => stringValue(value) ?? "").filter((value) => value.length > 0),
    ),
    lifecycleItem(
      "withdrawal_intent_recorded",
      withdrawalRequests.length > 0 ? "live" : "degraded",
      withdrawalRequests.length > 0 ? "Withdrawal intent recorded" : "Record withdrawal intent",
      withdrawalRequests.length > 0
        ? `${withdrawalRequests.length} withdrawal intent record(s) are visible.`
        : "No withdrawal intent is visible yet.",
      "npm run flowchain:real-value-pilot:e2e -- --withdrawal-intent",
      withdrawalRequests.map((withdrawal) => stringValue(withdrawal.withdrawalIntentId) ?? "").filter((id) => id.length > 0),
    ),
    lifecycleItem(
      "release_evidence_recorded",
      recordedReleaseEvidence.length > 0 ? "live" : releases.length > 0 ? "degraded" : "degraded",
      recordedReleaseEvidence.length > 0 ? "Release evidence recorded" : "Export release evidence",
      recordedReleaseEvidence.length > 0
        ? `${recordedReleaseEvidence.length} release evidence record(s) are visible.`
        : "Withdrawal/release evidence is pending or absent.",
      "npm run flowchain:real-value-pilot:e2e -- --export-evidence",
      releases.map((release) => stringValue(release.releaseEvidenceId) ?? "").filter((id) => id.length > 0),
    ),
    lifecycleItem(
      "caps_enforced",
      caps.state as PilotState,
      caps.state === "error" ? "Cap breach" : "Pilot caps visible",
      caps.state === "error" ? "Pilot cap status reports a breach." : "Per-deposit and total pilot cap status is visible.",
      stringValue(caps.nextOperatorCommand) ?? "npm run bridge:observe -- --mode base-mainnet-canary --acknowledge-real-funds --max-usd 25",
    ),
    lifecycleItem(
      "pause_clear",
      pause.state as PilotState,
      pause.state === "live" ? "Pause is clear" : "Pause is active",
      pause.state === "live" ? "New observations are not marked paused by the visible control-plane state." : "Pause status is active.",
      stringValue(pause.nextOperatorCommand) ?? "npm run flowchain:real-value-pilot:e2e",
    ),
    lifecycleItem(
      "emergency_clear",
      emergency.state as PilotState,
      emergency.state === "live" ? "Emergency state clear" : "Emergency state active",
      emergency.state === "live" ? "Emergency status is standby." : "Emergency controls are active.",
      stringValue(emergency.nextOperatorCommand) ?? "npm run flowchain:stop",
    ),
  ];

  const stateSeverity: PilotState = lifecycle.some((item) => item.state === "error")
    ? "error"
    : lifecycle.some((item) => item.state === "degraded")
      ? "degraded"
      : "live";
  const nextOperatorStep = nextStep(lifecycle, emergency);

  return {
    schema: "flowmemory.control_plane.real_value_pilot_status.v0",
    pilotId: stableId("flowmemory.control_plane.real_value_pilot_status.v0", {
      deposits: deposits.map((deposit) => deposit.observationId),
      credits: credits.map((credit) => credit.creditId),
      withdrawals: withdrawals.map((withdrawal) => withdrawal.withdrawalIntentId),
      releases: releases.map((release) => release.releaseEvidenceId),
    }),
    label: "FlowChain capped owner real-value pilot",
    state: stateSeverity,
    stateReason: nextOperatorStep.reason,
    generatedAt: state.launchCore.generatedAt,
    baseChainId: BASE_MAINNET_CHAIN_ID,
    cappedOwnerTesting: true,
    broadPublicReadiness: false,
    productionReady: false,
    browserStoresSecrets: false,
    nextOperatorStep,
    counts: {
      depositObservations: deposits.length,
      baseMainnetDeposits: baseDeposits.length,
      credits: credits.length,
      appliedCredits: appliedCredits.length,
      withdrawalIntents: withdrawals.length,
      releaseEvidence: releases.length,
      lifecycleRecords: lifecycleRecords.length,
      exactLifecycleRecords: (exactValueChecks.exactRecordIds as JsonValue[]).length,
      walletBalances: walletBalanceRows(state).length,
      walletTransfers: walletTransferRows(state).length,
    },
    lifecycle,
    depositObservations: deposits,
    credits,
    withdrawalIntents: withdrawals,
    releaseEvidence: releases,
    bridgeLiveReadiness,
    lifecycleRecords,
    exactValueChecks,
    operationalStates,
    capStatus: caps,
    pauseStatus: pause,
    retryStatus: retry,
    emergencyStatus: emergency,
    localOnly: true,
  };
}

export function pilotStatus(_params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  return buildPilotLifecycle(stateFor(context));
}

export function pilotDepositObservationList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  return listResult(
    "flowmemory.control_plane.real_value_pilot_deposit_observation_list.v0",
    "depositObservations",
    pilotDepositRows(stateFor(context)),
    params,
    "pilot_deposit_observation_list",
  );
}

export function pilotCreditList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  return listResult(
    "flowmemory.control_plane.real_value_pilot_credit_list.v0",
    "credits",
    pilotCreditRows(stateFor(context)),
    params,
    "pilot_credit_list",
  );
}

export function pilotWithdrawalIntentList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  return listResult(
    "flowmemory.control_plane.real_value_pilot_withdrawal_intent_list.v0",
    "withdrawalIntents",
    pilotWithdrawalRows(stateFor(context)),
    params,
    "pilot_withdrawal_intent_list",
  );
}

export function pilotReleaseEvidenceList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  return listResult(
    "flowmemory.control_plane.real_value_pilot_release_evidence_list.v0",
    "releaseEvidence",
    pilotReleaseEvidenceRows(stateFor(context)),
    params,
    "pilot_release_evidence_list",
  );
}

export function pilotCapStatus(_params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  return capStatus(state, pilotDepositRows(state));
}

export function pilotPauseStatus(_params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  return pauseStatus(stateFor(context));
}

export function pilotRetryStatus(_params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  return retryStatus(state, pilotDepositRows(state), pilotCreditRows(state));
}

export function pilotEmergencyStatus(_params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  return emergencyStatus(stateFor(context));
}

export function bridgeLiveReadiness(_params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  return buildBridgeLiveReadiness(stateFor(context));
}

export function pilotLifecycleRecordList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  return listResult(
    "flowmemory.control_plane.bridge_lifecycle_record_list.v0",
    "lifecycleRecords",
    buildLifecycleRecords(stateFor(context)),
    params,
    "pilot_lifecycle_record_list",
  );
}

export function walletBalanceList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  return listResult(
    "flowmemory.control_plane.wallet_balance_list.v0",
    "balances",
    walletBalanceRows(stateFor(context)),
    params,
    "wallet_balance_list",
  );
}

export function walletTransferHistory(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  return listResult(
    "flowmemory.control_plane.wallet_transfer_history.v0",
    "transfers",
    walletTransferRows(stateFor(context)),
    params,
    "wallet_transfer_history",
  );
}

export function requirePilotEvidence(context: ControlPlaneContext = {}): PilotLifecycle {
  const lifecycle = buildPilotLifecycle(stateFor(context));
  const missing = [
    lifecycle.depositObservations.length === 0 ? "deposit observations" : null,
    lifecycle.credits.length === 0 ? "credits" : null,
    lifecycle.withdrawalIntents.length === 0 ? "withdrawal intents" : null,
    lifecycle.releaseEvidence.length === 0 ? "release evidence" : null,
  ].filter((entry): entry is string => entry !== null);
  if (missing.length > 0) {
    throw objectNotFound(`pilot evidence missing: ${missing.join(", ")}`, { missing });
  }
  return lifecycle;
}
