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

function listResult(schema: string, rowsKey: string, rows: JsonObject[], params: JsonValue | undefined, method: string): JsonObject {
  const limit = pageLimit(asObjectParams(params, method));
  return {
    schema,
    count: Math.min(rows.length, limit),
    totalCount: rows.length,
    nextCursor: null,
    [rowsKey]: rows.slice(0, limit),
    localOnly: true,
    productionReady: false,
    cappedOwnerTesting: true,
  };
}

function handoffRows(state: LoadedControlPlaneState, key: string): JsonObject[] {
  const fallbackBridge = asObject(state.explorerFallback?.bridge);
  const nativeRows = objectRows(state.bridgeRuntimeHandoff?.[key]);
  const fallbackRows = objectRows(fallbackBridge?.[key]);
  if (fallbackRows.length === 0) {
    return nativeRows;
  }
  if (nativeRows.length === 0) {
    return fallbackRows;
  }
  const hasBaseMainnet = nativeRows.some((row) => chainIdOf(row) === BASE_MAINNET_CHAIN_ID);
  return hasBaseMainnet ? nativeRows : [...nativeRows, ...fallbackRows];
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
    releasedAt: stringValue(evidence.releasedAt) ?? stringValue(evidence.recordedAt),
    evidenceURI: stringValue(evidence.evidenceURI) ?? null,
    operatorNote: stringValue(evidence.operatorNote) ?? null,
    localOnly: true,
    productionReady: false,
  };
}

function pilotReleaseEvidenceRows(state: LoadedControlPlaneState): JsonObject[] {
  const native = [
    ...handoffRows(state, "releaseEvidence"),
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
    },
    lifecycle,
    depositObservations: deposits,
    credits,
    withdrawalIntents: withdrawals,
    releaseEvidence: releases,
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
