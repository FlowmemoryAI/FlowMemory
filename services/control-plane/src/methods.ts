import { appendFileSync, mkdirSync, readFileSync, existsSync } from "node:fs";
import { dirname } from "node:path";

import { canonicalJson, findSecret, keccak256Hex } from "../../shared/src/index.ts";
import { bridgeSourceEventReplayKey, flowchainBridgeObservationId } from "../../../crypto/src/production-l1.js";
import { localTransactionReplayKey } from "../../../crypto/src/transactions.js";
import { verifyFlowchainEnvelope } from "../../../crypto/src/runtime-validation.js";
import { cryptoRejected, invalidParams, methodNotFound, objectNotFound, secretRejected } from "./errors.ts";
import { loadControlPlaneState, resolveControlPlanePath } from "./fixture-state.ts";
import {
  pilotCapStatus,
  pilotCreditList,
  pilotDepositObservationList,
  pilotEmergencyStatus,
  pilotPauseStatus,
  pilotReleaseEvidenceList,
  pilotRetryStatus,
  pilotStatus,
  pilotWithdrawalIntentList,
} from "./pilot.ts";
import type {
  ControlPlaneContext,
  ControlPlaneMethod,
  JsonObject,
  JsonValue,
  LoadedControlPlaneState,
} from "./types.ts";

const ZERO_ROOT = "0x0000000000000000000000000000000000000000000000000000000000000000";
const FLOWCHAIN_LIVE_L1_CHAIN_ID = "31337";
const FLOWCHAIN_LIVE_L1_NETWORK_PROFILE = "local-chain";

type MethodHandler = (params: JsonValue | undefined, context: ControlPlaneContext) => JsonValue;

function stateFor(context: ControlPlaneContext): LoadedControlPlaneState {
  return context.state ?? loadControlPlaneState(context.paths);
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

function requiredString(params: JsonObject, names: string[], method: string): string {
  for (const name of names) {
    const value = params[name];
    if (typeof value === "string" && value.length > 0) {
      return value;
    }
  }
  throw invalidParams(`${method} requires one of: ${names.join(", ")}`, { required: names });
}

function optionalString(params: JsonObject, name: string): string | undefined {
  const value = params[name];
  return typeof value === "string" && value.length > 0 ? value : undefined;
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

function optionalBoolean(params: JsonObject, name: string): boolean {
  const value = params[name];
  if (value === undefined) {
    return false;
  }
  if (typeof value !== "boolean") {
    throw invalidParams(`${name} must be a boolean`);
  }
  return value;
}

function asJsonObject(value: JsonValue | undefined): JsonObject | null {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value as JsonObject : null;
}

function asJsonArray(value: JsonValue | undefined): JsonValue[] {
  return Array.isArray(value) ? value : [];
}

function stringValue(value: JsonValue | undefined): string | null {
  if (typeof value === "string") {
    return value;
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  return null;
}

function stringList(value: JsonValue | undefined): string[] {
  return asJsonArray(value)
    .map((entry) => stringValue(entry))
    .filter((entry): entry is string => entry !== null);
}

function compareStringNumbers(left: string, right: string): number {
  if (/^\d+$/.test(left) && /^\d+$/.test(right)) {
    const diff = BigInt(left) - BigInt(right);
    return diff < 0n ? -1 : diff > 0n ? 1 : 0;
  }
  return left.localeCompare(right);
}

function stableId(schema: string, value: JsonValue): string {
  return keccak256Hex(new TextEncoder().encode(canonicalJson({ schema, value })));
}

function latestBlock(state: LoadedControlPlaneState): { blockNumber: string; blockHash: string } {
  const latest = [...state.indexer.state.observations].sort((left, right) => {
    const block = BigInt(right.blockNumber) - BigInt(left.blockNumber);
    if (block !== 0n) {
      return block < 0n ? -1 : 1;
    }
    const log = BigInt(right.logIndex) - BigInt(left.logIndex);
    if (log !== 0n) {
      return log < 0n ? -1 : 1;
    }
    return right.observationId.localeCompare(left.observationId);
  })[0];

  return {
    blockNumber: latest?.blockNumber ?? "0",
    blockHash: latest?.blockHash ?? ZERO_ROOT,
  };
}

function finalizedBlock(state: LoadedControlPlaneState): string {
  const finalized = state.indexer.state.observations
    .filter((observation) => observation.lifecycleState === "finalized")
    .map((observation) => BigInt(observation.blockNumber));
  if (finalized.length === 0) {
    return "0";
  }
  return finalized.reduce((max, block) => block > max ? block : max, 0n).toString();
}

function provenanceSource(subsystem: string, path: string, schema: string, note?: string): JsonObject {
  return {
    schema: "flowmemory.control_plane.provenance_source.v0",
    subsystem,
    path,
    source: "local-fixture",
    objectSchema: schema,
    note,
  };
}

function reportByIdOrObservation(state: LoadedControlPlaneState, key: string) {
  return state.verifier.reports.find((report) => {
    return report.reportId === key || report.reportDigest === key || report.reportCore.observationId === key;
  });
}

function receiptByAnyId(state: LoadedControlPlaneState, key: string) {
  return state.launchCore.memoryReceipts.find((receipt) => {
    return receipt.receiptId === key
      || receipt.observationId === key
      || receipt.reportId === key
      || receipt.reportDigest === key;
  });
}

function signalByObservation(state: LoadedControlPlaneState, observationId: string) {
  return state.launchCore.memorySignals.find((signal) => signal.observationId === observationId);
}

function transitionByAnyId(state: LoadedControlPlaneState, key: string) {
  return state.launchCore.rootflowTransitions.find((transition) => {
    return transition.transitionId === key
      || transition.observationId === key
      || transition.memoryReceiptId === key
      || transition.memorySignalId === key
      || transition.reportId === key;
  });
}

function devnetRootfields(state: LoadedControlPlaneState): Record<string, JsonValue> {
  return devnetMap(state, "rootfields");
}

function devnetMap(state: LoadedControlPlaneState, key: string): Record<string, JsonValue> {
  const controlPlaneObjects = asJsonObject(state.devnetControlPlaneHandoff?.objects);
  const candidates = [
    state.devnet?.[key],
    controlPlaneObjects?.[key],
    state.devnetControlPlaneHandoff?.[key],
    state.devnetVerifierHandoff?.[key],
    state.devnetIndexerHandoff?.[key],
  ];
  const maps = candidates
    .map((value) => asJsonObject(value))
    .filter((value): value is Record<string, JsonValue> => value !== null);
  return maps.find((value) => Object.keys(value).length > 0) ?? maps[0] ?? {};
}

function firstDevnetMap(state: LoadedControlPlaneState, keys: string[]): Record<string, JsonValue> {
  for (const key of keys) {
    const value = devnetMap(state, key);
    if (Object.keys(value).length > 0) {
      return value;
    }
  }
  return {};
}

function devnetBlocksArray(state: LoadedControlPlaneState): JsonObject[] {
  const sources = [
    asJsonArray(state.devnet?.blocks),
    asJsonArray(state.devnetControlPlaneHandoff?.blocks),
    asJsonArray(state.devnetIndexerHandoff?.blocks),
  ];
  const candidate = sources.find((blocks) =>
    blocks.some((entry) => {
      const block = asJsonObject(entry);
      return block !== null && stringList(block.txIds).length > 0;
    }),
  ) ?? sources.find((blocks) => blocks.length > 0) ?? [];
  return candidate
    .map((entry) => asJsonObject(entry))
    .filter((entry): entry is JsonObject => entry !== null);
}

function txFixtureRows(state: LoadedControlPlaneState): JsonObject[] {
  return asJsonArray(state.txFixtures?.txs)
    .map((entry) => asJsonObject(entry))
    .filter((entry): entry is JsonObject => entry !== null);
}

function devnetWorkReceipts(state: LoadedControlPlaneState): Record<string, JsonValue> {
  return devnetMap(state, "workReceipts");
}

function devnetReports(state: LoadedControlPlaneState): Record<string, JsonValue> {
  return devnetMap(state, "verifierReports");
}

function devnetArtifacts(state: LoadedControlPlaneState): Record<string, JsonValue> {
  return devnetMap(state, "artifactCommitments");
}

function devnetAgentAccounts(state: LoadedControlPlaneState): Record<string, JsonValue> {
  return devnetMap(state, "agentAccounts");
}

function devnetModels(state: LoadedControlPlaneState): Record<string, JsonValue> {
  return firstDevnetMap(state, ["modelPassports", "models"]);
}

function devnetVerifierModules(state: LoadedControlPlaneState): Record<string, JsonValue> {
  return firstDevnetMap(state, ["verifierModules", "modules"]);
}

function devnetArtifactAvailability(state: LoadedControlPlaneState): Record<string, JsonValue> {
  return firstDevnetMap(state, ["artifactAvailabilityProofs", "artifactAvailability"]);
}

function devnetMemoryCells(state: LoadedControlPlaneState): Record<string, JsonValue> {
  return devnetMap(state, "memoryCells");
}

function devnetChallenges(state: LoadedControlPlaneState): Record<string, JsonValue> {
  return devnetMap(state, "challenges");
}

function devnetFinalityReceipts(state: LoadedControlPlaneState): Record<string, JsonValue> {
  return devnetMap(state, "finalityReceipts");
}

function devnetOperatorKeyReferences(state: LoadedControlPlaneState): Record<string, JsonValue> {
  return firstDevnetMap(state, ["operatorKeyReferences", "walletPublicMetadata", "wallets"]);
}

function devnetProductEntries(
  state: LoadedControlPlaneState,
  keys: string[],
  idFields: string[],
): Array<{ id: string; object: JsonObject; sourceKey: string }> {
  const rows = new Map<string, { id: string; object: JsonObject; sourceKey: string }>();
  for (const sourceKey of keys) {
    for (const [mapId, value] of Object.entries(devnetMap(state, sourceKey))) {
      const object = asJsonObject(value) ?? {};
      const id = idFields
        .map((field) => stringValue(object[field]))
        .find((candidate): candidate is string => candidate !== null)
        ?? mapId;
      rows.set(id, { id, object, sourceKey });
    }
  }
  return [...rows.values()].sort((left, right) => left.id.localeCompare(right.id));
}

function devnetProductMapCount(state: LoadedControlPlaneState, keys: string[]): number {
  return devnetProductEntries(state, keys, ["id"]).length;
}

function devnetLocalTestUnitBalances(state: LoadedControlPlaneState): Record<string, JsonValue> {
  return firstDevnetMap(state, ["localTestUnitBalances", "localBalances"]);
}

function devnetBalanceTransfers(state: LoadedControlPlaneState): Record<string, JsonValue> {
  return devnetMap(state, "balanceTransfers");
}

function productSource(sourceKey: string): string {
  return `local-devnet:${sourceKey}`;
}

function devnetPeers(state: LoadedControlPlaneState): JsonObject[] {
  return asJsonArray(state.devnet?.peers)
    .map((entry) => asJsonObject(entry))
    .filter((entry): entry is JsonObject => entry !== null);
}

function runtimeSourcePath(state: LoadedControlPlaneState): string {
  return state.sources.devnet?.path ?? state.paths.devnetPath;
}

function readNdjson(path: string): JsonObject[] {
  const resolved = resolveControlPlanePath(path);
  if (!existsSync(resolved)) {
    return [];
  }
  return readFileSync(resolved, "utf8")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .map((line) => JSON.parse(line) as JsonObject);
}

function appendNdjson(path: string, row: JsonObject): void {
  const resolved = resolveControlPlanePath(path);
  mkdirSync(dirname(resolved), { recursive: true });
  appendFileSync(resolved, `${JSON.stringify(row)}\n`);
}

function txIntakeRows(state: LoadedControlPlaneState): JsonObject[] {
  const rows = readNdjson(state.paths.txIntakePath);
  return rows.length > 0 ? rows : state.txIntake;
}

function bridgeObservationRows(state: LoadedControlPlaneState): JsonObject[] {
  const intakeRows = readNdjson(state.paths.bridgeObservationIntakePath);
  const byId = new Map<string, JsonObject>();
  for (const observation of [...state.bridgeObservations, ...intakeRows]) {
    const id = stringValue(observation.observationId)
      ?? stringValue(asJsonObject(observation.deposit)?.depositId)
      ?? stableId("flowmemory.control_plane.bridge_observation.row.v0", observation);
    byId.set(id, observation);
  }
  return [...byId.values()].sort((left, right) => String(left.observationId ?? "").localeCompare(String(right.observationId ?? "")));
}

function nodeAccountRows(state: LoadedControlPlaneState): JsonObject[] {
  const rows: JsonObject[] = [];
  for (const [agentId, value] of Object.entries(devnetAgentAccounts(state))) {
    const agent = asJsonObject(value) ?? {};
    rows.push({
      schema: "flowmemory.control_plane.account.v0",
      accountId: agentId,
      accountType: "agent",
      controller: stringValue(agent.controller) ?? null,
      rootfieldId: stringValue(agent.rootfieldId) ?? null,
      balance: "0",
      noValue: true,
      metadata: agent,
      source: "local-devnet",
      localOnly: true,
    });
  }
  for (const [keyReferenceId, value] of Object.entries(devnetOperatorKeyReferences(state))) {
    const keyReference = asJsonObject(value) ?? {};
    rows.push({
      schema: "flowmemory.control_plane.account.v0",
      accountId: stringValue(keyReference.operatorId) ?? keyReferenceId,
      accountType: "operator",
      keyReferenceId,
      balance: "0",
      noValue: true,
      walletPublicMetadata: {
        keyReferenceId,
        operatorId: keyReference.operatorId,
        workerKeyId: keyReference.workerKeyId,
        verifierKeyId: keyReference.verifierKeyId,
        verifierSetRoot: keyReference.verifierSetRoot,
        signatureScheme: keyReference.signatureScheme,
        publicKeyHint: keyReference.publicKeyHint,
        secretMaterialBoundary: keyReference.secretMaterialBoundary,
      },
      source: "local-devnet",
      localOnly: true,
    });
  }
  if (rows.length === 0) {
    rows.push({
      schema: "flowmemory.control_plane.account.v0",
      accountId: "operator:local-demo",
      accountType: "operator",
      balance: "0",
      noValue: true,
      source: "projection",
      localOnly: true,
    });
  }
  return rows.sort((left, right) => String(left.accountId).localeCompare(String(right.accountId)));
}

function walletMetadataRows(state: LoadedControlPlaneState): JsonObject[] {
  return nodeAccountRows(state).map((account) => ({
    schema: "flowmemory.control_plane.wallet_public_metadata.v0",
    walletId: account.accountId,
    accountId: account.accountId,
    accountType: account.accountType,
    metadata: account.walletPublicMetadata ?? account.metadata ?? {},
    publicOnly: true,
    localOnly: true,
  }));
}

function mempoolRows(state: LoadedControlPlaneState): JsonObject[] {
  const pending = asJsonArray(state.devnet?.pendingTxs)
    .map((entry) => asJsonObject(entry))
    .filter((entry): entry is JsonObject => entry !== null)
    .map((tx) => ({
      schema: "flowmemory.control_plane.mempool_transaction.v0",
      transactionId: stringValue(tx.txId) ?? stringValue(tx.transactionId) ?? stableId("flowmemory.control_plane.mempool.devnet.v0", tx),
      status: "pending",
      transaction: tx,
      source: "local-devnet",
      localOnly: true,
  }));
  const intake = txIntakeRows(state).map((entry) => ({
    schema: "flowmemory.control_plane.mempool_transaction.v0",
    transactionId: stringValue(entry.txId) ?? stringValue(entry.intakeId) ?? stableId("flowmemory.control_plane.mempool.intake.v0", entry),
    status: stringValue(entry.status) ?? "accepted_local",
    transaction: asJsonObject(asJsonObject(entry.signedEnvelope)?.document)
      ?? asJsonObject(asJsonObject(entry.signedEnvelope)?.tx)
      ?? asJsonObject(asJsonObject(entry.signedEnvelope)?.transaction)
      ?? asJsonObject(asJsonObject(entry.signedEnvelope)?.payload)
      ?? asJsonObject(entry.transaction)
      ?? entry,
    signedEnvelope: asJsonObject(entry.signedEnvelope) ?? undefined,
    source: "local-file-intake",
    localOnly: true,
  }));
  return [...pending, ...intake].sort((left, right) => String(left.transactionId).localeCompare(String(right.transactionId)));
}

function bridgeDepositRows(state: LoadedControlPlaneState): JsonObject[] {
  return bridgeObservationRows(state).map((observation) => {
    const deposit = asJsonObject(observation.deposit) ?? observation;
    const depositId = stringValue(deposit.depositId) ?? stableId("flowmemory.control_plane.bridge_deposit.v0", deposit);
    return {
      schema: "flowmemory.control_plane.bridge_deposit.v0",
      depositId,
      observationId: stringValue(observation.observationId) ?? null,
      status: stringValue(deposit.status) ?? "observed",
      sourceChainId: deposit.sourceChainId ?? null,
      sourceContract: deposit.sourceContract ?? null,
      txHash: deposit.txHash ?? null,
      logIndex: deposit.logIndex ?? null,
      token: deposit.token ?? null,
      amount: deposit.amount ?? "0",
      sender: deposit.sender ?? null,
      flowchainRecipient: deposit.flowchainRecipient ?? null,
      deposit,
      observation,
      source: "bridge-relayer",
      localOnly: true,
    };
  }).sort((left, right) => String(left.depositId).localeCompare(String(right.depositId)));
}

function bridgeCreditRows(state: LoadedControlPlaneState): JsonObject[] {
  const rows = new Map<string, JsonObject>();
  for (const entry of devnetProductEntries(state, ["bridgeCredits", "bridgeCreditReceipts", "runtimeBridgeCredits"], ["creditId", "bridgeCreditId", "id", "depositId"])) {
    const credit = entry.object;
    const creditId = entry.id;
    rows.set(creditId, {
      schema: "flowmemory.control_plane.bridge_credit.v0",
      creditId,
      depositId: stringValue(credit.depositId) ?? null,
      accountId: stringValue(credit.accountId) ?? stringValue(credit.recipient) ?? stringValue(credit.flowchainRecipient) ?? null,
      amount: stringValue(credit.amount) ?? stringValue(credit.amountUnits) ?? stringValue(credit.units) ?? "0",
      token: credit.token ?? credit.tokenId ?? credit.assetId ?? null,
      status: stringValue(credit.status) ?? "local_credit",
      credit,
      source: productSource(entry.sourceKey),
      localOnly: true,
    });
  }

  for (const deposit of bridgeDepositRows(state)) {
    const creditId = stableId("flowmemory.control_plane.bridge_credit.v0", deposit.depositId);
    if (!rows.has(creditId)) {
      rows.set(creditId, {
        schema: "flowmemory.control_plane.bridge_credit.v0",
        creditId,
        depositId: deposit.depositId,
        accountId: deposit.flowchainRecipient,
        amount: deposit.amount ?? "0",
        token: deposit.token ?? null,
        status: deposit.status === "rejected" ? "rejected" : "pending_local_credit",
        source: "bridge-deposit-projection",
        localOnly: true,
      });
    }
  }

  return [...rows.values()].sort((left, right) => String(left.creditId).localeCompare(String(right.creditId)));
}

function withdrawalRows(state: LoadedControlPlaneState): JsonObject[] {
  const native = firstDevnetMap(state, ["withdrawals", "bridgeWithdrawals"]);
  const rows = Object.entries(native).map(([withdrawalId, value]) => ({
    schema: "flowmemory.control_plane.withdrawal.v0",
    withdrawalId,
    status: stringValue(asJsonObject(value)?.status) ?? "local",
    withdrawal: asJsonObject(value) ?? {},
    source: "local-devnet",
    localOnly: true,
  }));
  if (rows.length > 0) {
    return rows;
  }
  return bridgeCreditRows(state).slice(0, 1).map((credit) => ({
    schema: "flowmemory.control_plane.withdrawal.v0",
    withdrawalId: stableId("flowmemory.control_plane.withdrawal.projected.v0", credit.creditId),
    creditId: credit.creditId,
    depositId: credit.depositId,
    accountId: credit.accountId,
    amount: credit.amount,
    token: credit.token,
    status: "not_requested",
    source: "bridge-credit-projection",
    localOnly: true,
  }));
}

function tokenRows(state: LoadedControlPlaneState): JsonObject[] {
  const rows = devnetProductEntries(
    state,
    ["tokens", "tokenDefinitions", "tokenLaunches", "localTokens", "launchedTokens"],
    ["tokenId", "assetId", "symbol", "address", "id"],
  ).map((entry) => {
    const token = entry.object;
    return {
      schema: "flowmemory.control_plane.token.v0",
      tokenId: entry.id,
      symbol: stringValue(token.symbol) ?? stringValue(token.ticker) ?? entry.id,
      name: stringValue(token.name) ?? null,
      decimals: token.decimals ?? null,
      totalSupply: stringValue(token.totalSupply) ?? stringValue(token.supply) ?? stringValue(token.initialSupply) ?? null,
      owner: stringValue(token.owner) ?? stringValue(token.creator) ?? stringValue(token.issuer) ?? null,
      status: stringValue(token.status) ?? "local",
      token,
      source: productSource(entry.sourceKey),
      noValue: true,
      localOnly: true,
    };
  });

  if (rows.length > 0) {
    return rows;
  }

  const localBalances = devnetLocalTestUnitBalances(state);
  if (Object.keys(localBalances).length === 0) {
    return [];
  }

  return [{
    schema: "flowmemory.control_plane.token.v0",
    tokenId: "local-test-unit",
    symbol: "LTU",
    name: "Local Test Unit",
    decimals: 0,
    totalSupply: Object.values(localBalances)
      .map((entry) => BigInt(stringValue(asJsonObject(entry)?.units) ?? "0"))
      .reduce((sum, units) => sum + units, 0n)
      .toString(),
    owner: "local-faucet",
    status: "projected_local_unit",
    token: {
      schema: "flowmemory.local_test_unit.projected.v0",
      noValue: true,
    },
    source: "local-test-unit-balance-projection",
    noValue: true,
    localOnly: true,
  }];
}

function tokenBalanceRows(state: LoadedControlPlaneState): JsonObject[] {
  const rows = devnetProductEntries(
    state,
    ["tokenBalances", "localTokenBalances", "accountTokenBalances"],
    ["balanceId", "tokenBalanceId", "positionId", "id"],
  ).map((entry) => {
    const balance = entry.object;
    const accountId = stringValue(balance.accountId) ?? stringValue(balance.owner) ?? stringValue(balance.walletId) ?? null;
    const tokenId = stringValue(balance.tokenId) ?? stringValue(balance.assetId) ?? stringValue(balance.symbol) ?? null;
    return {
      schema: "flowmemory.control_plane.token_balance.v0",
      balanceId: entry.id,
      accountId,
      tokenId,
      amount: stringValue(balance.amount) ?? stringValue(balance.units) ?? stringValue(balance.balance) ?? "0",
      status: stringValue(balance.status) ?? "local",
      balance,
      source: productSource(entry.sourceKey),
      noValue: true,
      localOnly: true,
    };
  });

  if (rows.length > 0) {
    return rows.sort((left, right) => String(left.balanceId).localeCompare(String(right.balanceId)));
  }

  return Object.entries(devnetLocalTestUnitBalances(state)).map(([balanceId, value]) => {
    const balance = asJsonObject(value) ?? {};
    return {
      schema: "flowmemory.control_plane.token_balance.v0",
      balanceId,
      accountId: stringValue(balance.owner) ?? stringValue(balance.accountId) ?? balanceId,
      tokenId: "local-test-unit",
      amount: stringValue(balance.units) ?? stringValue(balance.amountUnits) ?? "0",
      status: "projected_local_unit",
      balance,
      source: "local-test-unit-balance-projection",
      noValue: true,
      localOnly: true,
    };
  }).sort((left, right) => String(left.balanceId).localeCompare(String(right.balanceId)));
}

function poolRows(state: LoadedControlPlaneState): JsonObject[] {
  return devnetProductEntries(
    state,
    ["pools", "dexPools", "liquidityPools", "ammPools"],
    ["poolId", "id", "address"],
  ).map((entry) => {
    const pool = entry.object;
    return {
      schema: "flowmemory.control_plane.pool.v0",
      poolId: entry.id,
      token0: stringValue(pool.token0) ?? stringValue(pool.tokenA) ?? stringValue(pool.baseToken) ?? null,
      token1: stringValue(pool.token1) ?? stringValue(pool.tokenB) ?? stringValue(pool.quoteToken) ?? null,
      reserve0: stringValue(pool.reserve0) ?? stringValue(pool.reserveA) ?? null,
      reserve1: stringValue(pool.reserve1) ?? stringValue(pool.reserveB) ?? null,
      lpSupply: stringValue(pool.lpSupply) ?? stringValue(pool.totalLiquidity) ?? null,
      status: stringValue(pool.status) ?? "local",
      pool,
      source: productSource(entry.sourceKey),
      noValue: true,
      localOnly: true,
    };
  });
}

function lpPositionRows(state: LoadedControlPlaneState): JsonObject[] {
  return devnetProductEntries(
    state,
    ["lpPositions", "liquidityPositions", "poolPositions"],
    ["positionId", "lpPositionId", "id"],
  ).map((entry) => {
    const position = entry.object;
    return {
      schema: "flowmemory.control_plane.lp_position.v0",
      positionId: entry.id,
      poolId: stringValue(position.poolId) ?? null,
      accountId: stringValue(position.accountId) ?? stringValue(position.owner) ?? stringValue(position.walletId) ?? null,
      liquidity: stringValue(position.liquidity) ?? stringValue(position.lpTokens) ?? stringValue(position.amount) ?? "0",
      status: stringValue(position.status) ?? "local",
      position,
      source: productSource(entry.sourceKey),
      noValue: true,
      localOnly: true,
    };
  });
}

function swapRows(state: LoadedControlPlaneState): JsonObject[] {
  return devnetProductEntries(
    state,
    ["swaps", "swapReceipts", "dexSwaps"],
    ["swapId", "receiptId", "txId", "transactionId", "id"],
  ).map((entry) => {
    const swap = entry.object;
    return {
      schema: "flowmemory.control_plane.swap.v0",
      swapId: entry.id,
      txId: stringValue(swap.txId) ?? stringValue(swap.transactionId) ?? null,
      poolId: stringValue(swap.poolId) ?? null,
      accountId: stringValue(swap.accountId) ?? stringValue(swap.trader) ?? stringValue(swap.owner) ?? null,
      tokenIn: stringValue(swap.tokenIn) ?? stringValue(swap.inputToken) ?? null,
      tokenOut: stringValue(swap.tokenOut) ?? stringValue(swap.outputToken) ?? null,
      amountIn: stringValue(swap.amountIn) ?? stringValue(swap.inputAmount) ?? "0",
      amountOut: stringValue(swap.amountOut) ?? stringValue(swap.outputAmount) ?? "0",
      status: stringValue(swap.status) ?? "local",
      swap,
      source: productSource(entry.sourceKey),
      noValue: true,
      localOnly: true,
    };
  });
}

function transactionRows(state: LoadedControlPlaneState): JsonObject[] {
  const rows: JsonObject[] = [];
  const txFixtures = txFixtureRows(state);
  let fixtureIndex = 0;

  for (const block of devnetBlocksArray(state)) {
    const blockNumber = stringValue(block.blockNumber) ?? "0";
    const blockHash = stringValue(block.blockHash) ?? ZERO_ROOT;
    const receipts = asJsonArray(block.receipts)
      .map((entry) => asJsonObject(entry))
      .filter((entry): entry is JsonObject => entry !== null);

    stringList(block.txIds).forEach((txId, transactionIndex) => {
      const receipt = receipts.find((entry) => stringValue(entry.txId) === txId) ?? null;
      const payload = txFixtures[fixtureIndex] ?? null;
      fixtureIndex += 1;
      rows.push({
        schema: "flowmemory.control_plane.transaction.v0",
        transactionId: txId,
        txHash: txId,
        blockNumber,
        blockHash,
        transactionIndex: String(transactionIndex),
        status: stringValue(receipt?.status) ?? "unknown",
        type: stringValue(payload?.type) ?? "unknown",
        payload,
        receipt,
        source: "local-devnet",
        localOnly: true,
      });
    });
  }

  const byHash = new Map<string, JsonObject>();
  for (const observation of state.indexer.state.observations) {
    const existing = byHash.get(observation.txHash) ?? {
      schema: "flowmemory.control_plane.transaction.v0",
      transactionId: observation.txHash,
      txHash: observation.txHash,
      chainId: observation.chainId,
      blockNumber: observation.blockNumber,
      blockHash: observation.blockHash,
      transactionIndex: observation.transactionIndex,
      status: observation.receiptStatus,
      type: "FlowPulse",
      observationIds: [],
      pulseIds: [],
      rootfieldIds: [],
      logCount: 0,
      source: "flowpulse-indexer",
      localOnly: true,
    };
    (existing.observationIds as JsonValue[]).push(observation.observationId);
    (existing.pulseIds as JsonValue[]).push(observation.pulseId);
    (existing.rootfieldIds as JsonValue[]).push(observation.rootfieldId);
    existing.logCount = Number(existing.logCount ?? 0) + 1;
    existing.status = observation.lifecycleState;
    byHash.set(observation.txHash, existing);
  }

  for (const rejected of state.indexer.state.rejectedLogs) {
    const existing = byHash.get(rejected.txHash) ?? {
      schema: "flowmemory.control_plane.transaction.v0",
      transactionId: rejected.txHash,
      txHash: rejected.txHash,
      chainId: rejected.chainId,
      blockNumber: rejected.blockNumber,
      blockHash: rejected.blockHash,
      transactionIndex: rejected.transactionIndex,
      status: "rejected",
      type: "FlowPulseRejectedLog",
      rejectedLogs: [],
      source: "flowpulse-indexer",
      localOnly: true,
    };
    const rejectedLogs = Array.isArray(existing.rejectedLogs) ? existing.rejectedLogs : [];
    rejectedLogs.push({
      reasonCode: rejected.reasonCode,
      message: rejected.message,
      logIndex: rejected.logIndex,
    });
    existing.rejectedLogs = rejectedLogs;
    existing.status = "rejected";
    byHash.set(rejected.txHash, existing);
  }

  rows.push(...byHash.values());
  return rows.sort((left, right) => {
    const byBlock = compareStringNumbers(stringValue(left.blockNumber) ?? "0", stringValue(right.blockNumber) ?? "0");
    if (byBlock !== 0) {
      return byBlock;
    }
    return compareStringNumbers(stringValue(left.transactionIndex) ?? "0", stringValue(right.transactionIndex) ?? "0");
  });
}

function blockRows(state: LoadedControlPlaneState, includeTransactions = false): JsonObject[] {
  const txs = includeTransactions ? transactionRows(state) : [];
  const rows = devnetBlocksArray(state).map((block) => {
    const blockNumber = stringValue(block.blockNumber) ?? "0";
    const blockHash = stringValue(block.blockHash) ?? ZERO_ROOT;
    return {
      schema: "flowmemory.control_plane.block.v0",
      blockNumber,
      blockHash,
      parentHash: stringValue(block.parentHash) ?? null,
      logicalTime: block.logicalTime ?? null,
      stateRoot: stringValue(block.stateRoot) ?? null,
      txIds: stringList(block.txIds),
      receiptCount: asJsonArray(block.receipts).length,
      receipts: asJsonArray(block.receipts),
      transactions: includeTransactions
        ? txs.filter((tx) => tx.source === "local-devnet" && tx.blockHash === blockHash && tx.blockNumber === blockNumber)
        : undefined,
      source: "local-devnet",
      localOnly: true,
    };
  });

  const indexerBlocks = new Map<string, JsonObject>();
  for (const observation of state.indexer.state.observations) {
    const key = `${observation.chainId}:${observation.blockHash}:${observation.blockNumber}`;
    const existing = indexerBlocks.get(key) ?? {
      schema: "flowmemory.control_plane.block.v0",
      chainId: observation.chainId,
      blockNumber: observation.blockNumber,
      blockHash: observation.blockHash,
      txIds: [],
      observationIds: [],
      rejectedLogCount: 0,
      source: "flowpulse-indexer",
      localOnly: true,
    };
    const txIds = existing.txIds as JsonValue[];
    if (!txIds.includes(observation.txHash)) {
      txIds.push(observation.txHash);
    }
    (existing.observationIds as JsonValue[]).push(observation.observationId);
    existing.observationCount = Number(existing.observationCount ?? 0) + 1;
    indexerBlocks.set(key, existing);
  }
  for (const rejected of state.indexer.state.rejectedLogs) {
    const key = `${rejected.chainId}:${rejected.blockHash}:${rejected.blockNumber}`;
    const existing = indexerBlocks.get(key) ?? {
      schema: "flowmemory.control_plane.block.v0",
      chainId: rejected.chainId,
      blockNumber: rejected.blockNumber,
      blockHash: rejected.blockHash,
      txIds: [],
      observationIds: [],
      observationCount: 0,
      source: "flowpulse-indexer",
      localOnly: true,
    };
    const txIds = existing.txIds as JsonValue[];
    if (!txIds.includes(rejected.txHash)) {
      txIds.push(rejected.txHash);
    }
    existing.rejectedLogCount = Number(existing.rejectedLogCount ?? 0) + 1;
    indexerBlocks.set(key, existing);
  }

  rows.push(...[...indexerBlocks.values()].map((block) => ({
    ...block,
    transactions: includeTransactions
      ? txs.filter((tx) => tx.source === "flowpulse-indexer" && tx.blockHash === block.blockHash && tx.blockNumber === block.blockNumber)
      : undefined,
  })));

  return rows.sort((left, right) => compareStringNumbers(stringValue(left.blockNumber) ?? "0", stringValue(right.blockNumber) ?? "0"));
}

function rootfieldRows(state: LoadedControlPlaneState): JsonObject[] {
  const rows = new Map<string, JsonObject>();
  for (const bundle of state.launchCore.rootfieldBundles) {
    rows.set(bundle.rootfieldId, {
      schema: "flowmemory.control_plane.rootfield_row.v0",
      rootfieldId: bundle.rootfieldId,
      status: bundle.status,
      latestRoot: bundle.latestRoot,
      bundle,
      devnetRootfield: null,
      source: "launch-core",
      localOnly: true,
    });
  }
  for (const [rootfieldId, value] of Object.entries(devnetRootfields(state))) {
    const devnetRootfield = asJsonObject(value) ?? {};
    const existing = rows.get(rootfieldId);
    rows.set(rootfieldId, {
      schema: "flowmemory.control_plane.rootfield_row.v0",
      rootfieldId,
      status: stringValue(devnetRootfield.active) === "false" ? "inactive" : stringValue(devnetRootfield.status) ?? existing?.status ?? "active",
      latestRoot: stringValue(devnetRootfield.latestRoot) ?? stringValue(existing?.latestRoot) ?? ZERO_ROOT,
      bundle: existing?.bundle ?? null,
      devnetRootfield,
      source: existing === undefined ? "local-devnet" : "launch-core+local-devnet",
      localOnly: true,
    });
  }
  return [...rows.values()].sort((left, right) => String(left.rootfieldId).localeCompare(String(right.rootfieldId)));
}

function agentRows(state: LoadedControlPlaneState): JsonObject[] {
  const rows: JsonObject[] = [];
  for (const [agentId, value] of Object.entries(devnetAgentAccounts(state))) {
    const agent = asJsonObject(value) ?? {};
    rows.push({
      schema: "flowmemory.control_plane.agent_row.v0",
      agentId,
      rootfieldId: stringValue(agent.rootfieldId) ?? null,
      status: stringValue(agent.status) ?? "local",
      agentAccount: agent,
      agentMemoryView: null,
      source: "local-devnet",
      localOnly: true,
    });
  }
  for (const view of state.launchCore.agentMemoryViews) {
    rows.push({
      schema: "flowmemory.control_plane.agent_row.v0",
      agentId: view.viewId,
      rootfieldId: view.rootfieldId,
      status: view.status,
      agentAccount: null,
      agentMemoryView: view,
      source: "launch-core",
      localOnly: true,
    });
  }
  return rows.sort((left, right) => String(left.agentId).localeCompare(String(right.agentId)));
}

function modelRows(state: LoadedControlPlaneState): JsonObject[] {
  const nativeModels = Object.entries(devnetModels(state)).map(([modelId, value]) => {
    const model = asJsonObject(value) ?? {};
    return {
      schema: "flowmemory.control_plane.model.v0",
      modelId,
      rootfieldId: stringValue(model.rootfieldId) ?? null,
      status: stringValue(model.status) ?? "local",
      modelPassport: model,
      source: "local-devnet",
      localOnly: true,
    };
  });
  const projectedModels = state.launchCore.agentMemoryViews.map((view) => ({
    schema: "flowmemory.control_plane.model.v0",
    modelId: stableId("flowmemory.control_plane.model.projected.v0", view.rootfieldId),
    rootfieldId: view.rootfieldId,
    status: "local-placeholder",
    modelPassport: null,
    capabilities: ["read_agent_memory_view", "cite_local_fixture_provenance"],
    extensionPoint: "No ModelPassport handoff fixture exists yet; this projected row keeps the dashboard/workbench model API stable.",
    source: "projection",
    localOnly: true,
  }));
  return [...nativeModels, ...projectedModels].sort((left, right) => String(left.modelId).localeCompare(String(right.modelId)));
}

function workReceiptRows(state: LoadedControlPlaneState): JsonObject[] {
  const rows: JsonObject[] = [];
  for (const [receiptId, value] of Object.entries(devnetWorkReceipts(state))) {
    const receipt = asJsonObject(value) ?? {};
    const linkedReport = Object.values(devnetReports(state))
      .map((entry) => asJsonObject(entry))
      .find((report) => report?.receiptId === receiptId) ?? null;
    rows.push({
      schema: "flowmemory.control_plane.work_receipt_row.v0",
      workReceiptId: receiptId,
      receiptId,
      rootfieldId: stringValue(receipt.rootfieldId) ?? null,
      status: stringValue(linkedReport?.status) ?? "submitted",
      workReceipt: receipt,
      verifierReport: linkedReport,
      source: "local-devnet",
      localOnly: true,
    });
  }
  for (const receipt of state.launchCore.memoryReceipts) {
    rows.push({
      schema: "flowmemory.control_plane.work_receipt_row.v0",
      workReceiptId: receipt.receiptId,
      receiptId: receipt.receiptId,
      rootfieldId: receipt.rootfieldId,
      status: receipt.flowMemoryStatus,
      memoryReceipt: receipt,
      verifierReport: reportByIdOrObservation(state, receipt.reportId) ?? null,
      source: "launch-core-memory-receipt",
      localOnly: true,
    });
  }
  return rows.sort((left, right) => String(left.receiptId).localeCompare(String(right.receiptId)));
}

function artifactAvailabilityRows(state: LoadedControlPlaneState): JsonObject[] {
  const rows: JsonObject[] = [];
  for (const [id, value] of Object.entries(devnetArtifactAvailability(state))) {
    rows.push({
      schema: "flowmemory.control_plane.artifact_availability.v0",
      availabilityId: id,
      status: stringValue(asJsonObject(value)?.status) ?? "local",
      proof: asJsonObject(value) ?? {},
      source: "local-devnet",
      localOnly: true,
    });
  }
  for (const [artifactId, value] of Object.entries(devnetArtifacts(state))) {
    const artifact = asJsonObject(value) ?? {};
    rows.push({
      schema: "flowmemory.control_plane.artifact_availability.v0",
      availabilityId: artifactId,
      artifactId,
      rootfieldId: stringValue(artifact.rootfieldId) ?? null,
      commitment: stringValue(artifact.commitment) ?? null,
      uri: stringValue(artifact.uriHint) ?? null,
      status: "committed_local",
      proof: artifact,
      source: "local-devnet-artifact-commitment",
      localOnly: true,
    });
  }
  for (const [uri, artifact] of Object.entries(state.artifacts.artifactsByUri)) {
    const artifactObject = artifact as JsonObject;
    rows.push({
      schema: "flowmemory.control_plane.artifact_availability.v0",
      availabilityId: stableId("flowmemory.control_plane.artifact_availability.fixture.v0", uri),
      artifactId: stableId("flowmemory.control_plane.artifact.fixture.v0", uri),
      uri,
      commitment: stringValue(artifactObject.artifactCommitment) ?? stringValue(artifactObject.commitment) ?? null,
      status: "available_fixture",
      resolverPolicyId: state.artifacts.resolverPolicyId,
      artifact,
      source: "verifier-fixture",
      localOnly: true,
    });
  }
  return rows.sort((left, right) => String(left.availabilityId).localeCompare(String(right.availabilityId)));
}

function verifierModuleRows(state: LoadedControlPlaneState): JsonObject[] {
  const nativeModules = Object.entries(devnetVerifierModules(state)).map(([moduleId, value]) => ({
    schema: "flowmemory.control_plane.verifier_module.v0",
    moduleId,
    verifierModule: asJsonObject(value) ?? {},
    status: stringValue(asJsonObject(value)?.status) ?? "local",
    source: "local-devnet",
    localOnly: true,
  }));
  const projected = new Map<string, JsonObject>();
  for (const report of state.verifier.reports) {
    const key = `${report.reportCore.verifierSpecVersion}:${report.reportCore.resolverPolicyId}`;
    if (!projected.has(key)) {
      projected.set(key, {
        schema: "flowmemory.control_plane.verifier_module.v0",
        moduleId: stableId("flowmemory.control_plane.verifier_module.projected.v0", key),
        verifierSpecVersion: report.reportCore.verifierSpecVersion,
        resolverPolicyId: report.reportCore.resolverPolicyId,
        supportedStatuses: ["valid", "invalid", "unresolved", "unsupported", "reorged"],
        status: "available_fixture",
        source: "verifier-report-projection",
        localOnly: true,
      });
    }
  }
  for (const report of Object.values(devnetReports(state)).map((entry) => asJsonObject(entry)).filter((entry): entry is JsonObject => entry !== null)) {
    const verifierId = stringValue(report.verifierId);
    if (verifierId !== null && !projected.has(verifierId)) {
      projected.set(verifierId, {
        schema: "flowmemory.control_plane.verifier_module.v0",
        moduleId: verifierId,
        verifierId,
        status: "available_fixture",
        source: "local-devnet-report-projection",
        localOnly: true,
      });
    }
  }
  return [...nativeModules, ...projected.values()].sort((left, right) => String(left.moduleId).localeCompare(String(right.moduleId)));
}

function memoryCellRows(state: LoadedControlPlaneState): JsonObject[] {
  const nativeCells = Object.entries(devnetMemoryCells(state)).map(([memoryCellId, value]) => {
    const cell = asJsonObject(value) ?? {};
    return {
      schema: "flowmemory.control_plane.memory_cell_row.v0",
      memoryCellId,
      rootfieldId: stringValue(cell.rootfieldId) ?? null,
      status: stringValue(cell.status) ?? "local",
      memoryCell: cell,
      source: "local-devnet",
      localOnly: true,
    };
  });
  if (nativeCells.length > 0) {
    return nativeCells;
  }
  return state.launchCore.rootfieldBundles.map((bundle) => ({
    schema: "flowmemory.control_plane.memory_cell_row.v0",
    memoryCellId: bundle.rootfieldId,
    rootfieldId: bundle.rootfieldId,
    status: bundle.status,
    latestRoot: bundle.latestRoot,
    rootfieldBundle: bundle,
    source: "launch-core-projection",
    localOnly: true,
  }));
}

function challengeRows(state: LoadedControlPlaneState): JsonObject[] {
  return Object.entries(devnetChallenges(state)).map(([challengeId, value]) => {
    const challenge = asJsonObject(value) ?? {};
    return {
      schema: "flowmemory.control_plane.challenge_row.v0",
      challengeId,
      targetId: stringValue(challenge.targetId) ?? stringValue(challenge.receiptId) ?? null,
      status: stringValue(challenge.status) ?? "unknown",
      challenge,
      source: "local-devnet",
      localOnly: true,
    };
  }).sort((left, right) => String(left.challengeId).localeCompare(String(right.challengeId)));
}

function finalityRows(state: LoadedControlPlaneState): JsonObject[] {
  const rows = Object.entries(devnetFinalityReceipts(state)).map(([finalityReceiptId, value]) => {
    const finality = asJsonObject(value) ?? {};
    const sourceStatus = stringValue(finality.finalityStatus) ?? stringValue(finality.status);
    return {
      schema: "flowmemory.control_plane.finality_row.v0",
      finalityReceiptId,
      objectId: stringValue(finality.receiptId) ?? stringValue(finality.rootfieldId) ?? finalityReceiptId,
      status: finalityStatusFor(sourceStatus),
      sourceStatus,
      finalityReceipt: finality,
      source: "local-devnet",
      localOnly: true,
    };
  });
  for (const receipt of state.launchCore.memoryReceipts) {
    rows.push({
      schema: "flowmemory.control_plane.finality_row.v0",
      finalityReceiptId: stableId("flowmemory.control_plane.finality.projected.v0", receipt.receiptId),
      objectId: receipt.receiptId,
      rootfieldId: receipt.rootfieldId,
      status: finalityStatusFor(receipt.flowMemoryStatus),
      sourceStatus: receipt.flowMemoryStatus,
      source: "launch-core-projection",
      localOnly: true,
    });
  }
  return rows.sort((left, right) => String(left.objectId).localeCompare(String(right.objectId)));
}

function nodeStatus(_params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const blocks = devnetBlocksArray(state);
  const latest = blocks[blocks.length - 1] ?? null;
  return {
    schema: "flowmemory.control_plane.node_status.v0",
    nodeId: "flowmemory-local-control-plane",
    status: state.devnet === null ? "degraded" : "ok",
    runtimeStateSource: runtimeSourcePath(state),
    chainId: typeof state.devnet?.chainId === "string" ? state.devnet.chainId : "flowmemory-local-devnet-v0",
    latestBlockNumber: latest?.blockNumber ?? null,
    latestBlockHash: latest?.blockHash ?? null,
    peerCount: devnetPeers(state).length,
    mempoolSize: mempoolRows(state).length,
    noValue: true,
    localOnly: true,
  };
}

function peerList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "peer_list");
  const limit = pageLimit(objectParams);
  const peers = devnetPeers(state);
  const rows = (peers.length > 0 ? peers : [{
    peerId: "local-single-node",
    address: "127.0.0.1",
    status: "self",
  }]).slice(0, limit).map((peer) => ({
    schema: "flowmemory.control_plane.peer.v0",
    ...peer,
    localOnly: true,
  }));
  return {
    schema: "flowmemory.control_plane.peer_list.v0",
    count: rows.length,
    nextCursor: null,
    peers: rows,
    localOnly: true,
  };
}

function health(_params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const missing = Object.values(state.sources).filter((source) => source.status === "missing").map((source) => source.name);
  const criticalMissing = ["launchCore", "indexer", "verifier", "artifacts", "devnet"]
    .filter((name) => state.sources[name]?.status === "missing");
  return {
    schema: "flowmemory.control_plane.health.v0",
    service: "flowmemory-control-plane-v0",
    status: criticalMissing.length === 0 ? "ok" : "degraded",
    localOnly: true,
    checks: {
      launchCore: state.sources.launchCore.status,
      indexer: state.sources.indexer.status,
      verifier: state.sources.verifier.status,
      artifacts: state.sources.artifacts.status,
      devnet: state.sources.devnet.status,
      devnetControlPlaneHandoff: state.sources.devnetControlPlaneHandoff.status,
      txFixtures: state.sources.txFixtures.status,
      bridgeObservation: state.sources.bridgeObservation.status,
      bridgeRuntimeHandoff: state.sources.bridgeRuntimeHandoff.status,
    },
    counts: {
      observations: state.indexer.state.observations.length,
      verifierReports: state.verifier.reports.length,
      rootfields: rootfieldRows(state).length,
      blocks: blockRows(state).length,
      transactions: transactionRows(state).length,
      mempool: mempoolRows(state).length,
      bridgeDeposits: bridgeDepositRows(state).length,
      bridgeCredits: bridgeCreditRows(state).length,
      pilotStatus: 1,
      tokens: tokenRows(state).length,
      tokenBalances: tokenBalanceRows(state).length,
      pools: poolRows(state).length,
      lpPositions: lpPositionRows(state).length,
      swaps: swapRows(state).length,
    },
    missingOptionalSources: missing,
  };
}

function chainStatus(_params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const latest = latestBlock(state);

  return {
    schema: "flowmemory.control_plane.chain_status.v0",
    chainId: typeof state.devnet?.chainId === "string" ? state.devnet.chainId : "flowmemory-local-alpha",
    settlementContext: "local no-value devnet runtime over FlowPulse fixtures",
    environment: "local-devnet",
    source: "local-runtime-first",
    currentBlock: latest.blockNumber,
    currentBlockHash: latest.blockHash,
    finalizedBlock: finalizedBlock(state),
    generatedAt: state.launchCore.generatedAt,
    localOnly: true,
    counts: {
      observations: state.indexer.state.observations.length,
      rejectedLogs: state.indexer.state.rejectedLogs.length,
      duplicates: state.indexer.state.duplicates.length,
      memorySignals: state.launchCore.memorySignals.length,
      memoryReceipts: state.launchCore.memoryReceipts.length,
      verifierReports: state.verifier.reports.length,
      rootfields: rootfieldRows(state).length,
      agents: agentRows(state).length,
      models: modelRows(state).length,
      workReceipts: workReceiptRows(state).length,
      artifactAvailability: artifactAvailabilityRows(state).length,
      verifierModules: verifierModuleRows(state).length,
      memoryCells: memoryCellRows(state).length,
      challenges: challengeRows(state).length,
      finalityRows: finalityRows(state).length,
      blocks: blockRows(state).length,
      transactions: transactionRows(state).length,
      mempool: mempoolRows(state).length,
      accounts: nodeAccountRows(state).length,
      balances: nodeAccountRows(state).length,
      faucetEvents: 1,
      walletPublicMetadata: walletMetadataRows(state).length,
      tokens: tokenRows(state).length,
      tokenBalances: tokenBalanceRows(state).length,
      pools: poolRows(state).length,
      lpPositions: lpPositionRows(state).length,
      swaps: swapRows(state).length,
      bridgeDeposits: bridgeDepositRows(state).length,
      bridgeCredits: bridgeCreditRows(state).length,
      withdrawals: withdrawalRows(state).length,
      pilotStatus: 1,
      devnetBlocks: devnetBlocksArray(state).length,
    },
    capabilities: [
      "health_reads",
      "node_status_reads",
      "peer_reads",
      "local_runtime_status_reads",
      "block_reads",
      "transaction_reads",
      "local_transaction_file_intake",
      "mempool_reads",
      "account_reads",
      "balance_reads",
      "faucet_event_reads",
      "wallet_public_metadata_reads",
      "token_reads",
      "token_balance_reads",
      "dex_pool_reads",
      "lp_position_reads",
      "swap_reads",
      "product_flow_status_reads",
      "receipt_lookup",
      "verifier_report_lookup",
      "memory_lineage_lookup",
      "artifact_fixture_lookup",
      "bridge_observation_file_intake",
      "bridge_deposit_reads",
      "bridge_credit_reads",
      "withdrawal_reads",
      "real_value_pilot_reads",
      "real_value_pilot_operator_steps",
      "devnet_handoff_reads",
      "no_secret_response_checks",
      "raw_json_reads",
    ],
    limitations: [
      "No production RPC URLs, wallets, or hosted services are used.",
      "No production L1, bridge, tokenomics, or verifier economics are implied.",
      "Challenge and finality methods expose local V0 fixture state only.",
    ],
    dataSources: state.sources,
  };
}

function devnetState(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "devnet_state");
  const includeBlocks = optionalBoolean(objectParams, "includeBlocks");
  const blocks = devnetBlocksArray(state);

  return {
    schema: "flowmemory.control_plane.devnet_state.v0",
    available: state.devnet !== null,
    chainId: typeof state.devnet?.chainId === "string" ? state.devnet.chainId : "flowmemory-local-devnet-v0",
    genesisHash: typeof state.devnet?.genesisHash === "string" ? state.devnet.genesisHash : null,
    latestBlockNumber: blocks.length > 0 ? blocks[blocks.length - 1]?.blockNumber ?? null : null,
    latestBlockHash: blocks.length > 0 ? blocks[blocks.length - 1]?.blockHash ?? null : null,
    stateRoot: typeof state.devnetControlPlaneHandoff?.stateRoot === "string"
      ? state.devnetControlPlaneHandoff.stateRoot
      : typeof state.devnetIndexerHandoff?.stateRoot === "string"
        ? state.devnetIndexerHandoff.stateRoot
        : state.devnet?.parentHash ?? null,
    rootfieldCount: Object.keys(devnetRootfields(state)).length,
    workReceiptCount: Object.keys(devnetWorkReceipts(state)).length,
    verifierReportCount: Object.keys(devnetReports(state)).length,
    agentAccountCount: Object.keys(devnetAgentAccounts(state)).length,
    modelCount: Object.keys(devnetModels(state)).length,
    verifierModuleCount: Object.keys(devnetVerifierModules(state)).length,
    artifactAvailabilityCount: Object.keys(devnetArtifactAvailability(state)).length,
    memoryCellCount: Object.keys(devnetMemoryCells(state)).length,
    challengeCount: Object.keys(devnetChallenges(state)).length,
    finalityReceiptCount: Object.keys(devnetFinalityReceipts(state)).length,
    tokenCount: tokenRows(state).length,
    tokenBalanceCount: tokenBalanceRows(state).length,
    poolCount: poolRows(state).length,
    lpPositionCount: lpPositionRows(state).length,
    swapCount: swapRows(state).length,
    nativeProductMapCounts: {
      tokens: devnetProductMapCount(state, ["tokens", "tokenDefinitions", "tokenLaunches", "localTokens", "launchedTokens"]),
      tokenBalances: devnetProductMapCount(state, ["tokenBalances", "localTokenBalances", "accountTokenBalances"]),
      pools: devnetProductMapCount(state, ["pools", "dexPools", "liquidityPools", "ammPools"]),
      lpPositions: devnetProductMapCount(state, ["lpPositions", "liquidityPositions", "poolPositions"]),
      swaps: devnetProductMapCount(state, ["swaps", "swapReceipts", "dexSwaps"]),
      bridgeCredits: devnetProductMapCount(state, ["bridgeCredits", "bridgeCreditReceipts", "runtimeBridgeCredits"]),
    },
    baseAnchorCount: state.devnet?.baseAnchors && typeof state.devnet.baseAnchors === "object" && !Array.isArray(state.devnet.baseAnchors)
      ? Object.keys(state.devnet.baseAnchors).length
      : 0,
    blocks: includeBlocks ? blocks : undefined,
    source: state.sources.devnet,
    indexerHandoff: state.devnetIndexerHandoff === null ? null : {
      schema: state.devnetIndexerHandoff.schema,
      stateRoot: state.devnetIndexerHandoff.stateRoot,
      blockCount: Array.isArray(state.devnetIndexerHandoff.blocks) ? state.devnetIndexerHandoff.blocks.length : 0,
    },
    verifierHandoff: state.devnetVerifierHandoff === null ? null : {
      schema: state.devnetVerifierHandoff.schema,
      stateRoot: state.devnetVerifierHandoff.stateRoot,
      workReceiptCount: Object.keys(devnetWorkReceipts(state)).length,
      verifierReportCount: Object.keys(devnetReports(state)).length,
    },
    controlPlaneHandoff: state.devnetControlPlaneHandoff === null ? null : {
      schema: state.devnetControlPlaneHandoff.schema,
      stateRoot: state.devnetControlPlaneHandoff.stateRoot,
      blockCount: asJsonArray(state.devnetControlPlaneHandoff.blocks).length,
      objectGroups: Object.keys(asJsonObject(state.devnetControlPlaneHandoff.objects) ?? {}).length,
    },
    localOnly: true,
  };
}

function blockList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "block_list");
  const limit = pageLimit(objectParams);
  const source = optionalString(objectParams, "source");
  const includeTransactions = optionalBoolean(objectParams, "includeTransactions");
  const rows = blockRows(state, includeTransactions)
    .filter((block) => source === undefined || block.source === source)
    .slice(0, limit);
  return {
    schema: "flowmemory.control_plane.block_list.v0",
    count: rows.length,
    nextCursor: null,
    blocks: rows,
    localOnly: true,
  };
}

function blockGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "block_get");
  const key = requiredString(objectParams, ["blockHash", "blockNumber"], "block_get");
  const includeTransactions = optionalBoolean(objectParams, "includeTransactions");
  const block = blockRows(state, includeTransactions).find((candidate) => {
    return candidate.blockHash === key || String(candidate.blockNumber) === key;
  });
  if (block === undefined) {
    throw objectNotFound(`block not found: ${key}`, { id: key });
  }
  return {
    schema: "flowmemory.control_plane.block_detail.v0",
    block,
    provenance: {
      sources: [
        block.source === "local-devnet"
          ? provenanceSource("devnet", "fixtures/launch-core/generated/devnet/state.json", "flowmemory.local_devnet.block.v0")
          : provenanceSource("indexer", "services/indexer/out/indexer-state.json", "flowmemory.indexer.persistence.v0"),
      ],
    },
    localOnly: true,
  };
}

function transactionList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "transaction_list");
  const limit = pageLimit(objectParams);
  const blockNumber = optionalString(objectParams, "blockNumber");
  const rootfieldId = optionalString(objectParams, "rootfieldId");
  const status = optionalString(objectParams, "status");
  const source = optionalString(objectParams, "source");
  const rows = transactionRows(state)
    .filter((tx) => blockNumber === undefined || tx.blockNumber === blockNumber)
    .filter((tx) => status === undefined || tx.status === status)
    .filter((tx) => source === undefined || tx.source === source)
    .filter((tx) => rootfieldId === undefined || stringList(tx.rootfieldIds).includes(rootfieldId) || tx.rootfieldId === rootfieldId)
    .slice(0, limit);
  return {
    schema: "flowmemory.control_plane.transaction_list.v0",
    count: rows.length,
    nextCursor: null,
    transactions: rows,
    localOnly: true,
  };
}

function transactionGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "transaction_get");
  const key = requiredString(objectParams, ["txId", "txHash", "transactionId"], "transaction_get");
  const transaction = transactionRows(state).find((candidate) => {
    return candidate.transactionId === key || candidate.txHash === key;
  });
  if (transaction === undefined) {
    throw objectNotFound(`transaction not found: ${key}`, { id: key });
  }
  return {
    schema: "flowmemory.control_plane.transaction_detail.v0",
    transaction,
    provenance: {
      sources: [
        transaction.source === "local-devnet"
          ? provenanceSource("devnet", "fixtures/launch-core/generated/devnet/state.json", "flowmemory.local_devnet.block.v0")
          : provenanceSource("indexer", "services/indexer/out/indexer-state.json", "flowmemory.indexer.persistence.v0"),
      ],
    },
    localOnly: true,
  };
}

function mempoolList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "mempool_list");
  const limit = pageLimit(objectParams);
  const rows = mempoolRows(state).slice(0, limit);
  return {
    schema: "flowmemory.control_plane.mempool_list.v0",
    count: rows.length,
    nextCursor: null,
    transactions: rows,
    intakePath: state.paths.txIntakePath,
    localOnly: true,
  };
}

function parseSignedEnvelope(value: JsonValue | undefined, label: string): JsonObject | null {
  if (value === undefined) {
    return null;
  }
  if (typeof value === "string") {
    try {
      const parsed = JSON.parse(value) as JsonValue;
      const object = asJsonObject(parsed);
      if (object === null) {
        throw new Error("parsed value was not an object");
      }
      return object;
    } catch (error) {
      throw invalidParams(`${label} must be a JSON object or JSON-encoded signed envelope object`, {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }
  const object = asJsonObject(value);
  if (object === null) {
    throw invalidParams(`${label} must be a signed envelope object`);
  }
  return object;
}

function signedEnvelopeForSubmit(params: JsonObject): { document: JsonObject; envelope: JsonObject } {
  if (params.transaction !== undefined || params.tx !== undefined || params.txs !== undefined) {
    throw invalidParams("transaction_submit accepts cryptographic envelopes only; use signedTransaction or signedEnvelope");
  }
  const signedEnvelope = parseSignedEnvelope(params.signedEnvelope, "signedEnvelope")
    ?? parseSignedEnvelope(params.signedTransaction, "signedTransaction");
  if (signedEnvelope === null) {
    throw invalidParams("transaction_submit requires signedTransaction or signedEnvelope");
  }

  const document = asJsonObject(signedEnvelope.document)
    ?? asJsonObject(signedEnvelope.tx)
    ?? asJsonObject(signedEnvelope.transaction)
    ?? asJsonObject(signedEnvelope.payload);
  const envelope = asJsonObject(signedEnvelope.envelope)
    ?? (signedEnvelope.schema === "flowchain.local_transaction_envelope.v0" ? signedEnvelope : null);

  if (document === null || envelope === null) {
    throw invalidParams("signed envelope must include document and envelope");
  }
  if (envelope.schema !== "flowchain.local_transaction_envelope.v0") {
    throw invalidParams("signed envelope must use flowchain.local_transaction_envelope.v0");
  }
  return { document, envelope };
}

function seenTransactionReplayKeys(state: LoadedControlPlaneState): Set<string> {
  const seen = new Set<string>();
  for (const row of txIntakeRows(state)) {
    const signedEnvelope = asJsonObject(row.signedEnvelope);
    const envelope = asJsonObject(signedEnvelope?.envelope)
      ?? (signedEnvelope?.schema === "flowchain.local_transaction_envelope.v0" ? signedEnvelope : null);
    if (envelope !== null) {
      try {
        seen.add(localTransactionReplayKey(envelope));
      } catch {
        continue;
      }
    }
    const storedReplayKey = stringValue(row.cryptoReplayKey);
    if (storedReplayKey !== undefined) {
      seen.add(storedReplayKey);
    }
  }
  return seen;
}

function seenTransactionIds(state: LoadedControlPlaneState): Set<string> {
  const seen = new Set<string>();
  for (const row of txIntakeRows(state)) {
    const txId = stringValue(row.txId) ?? stringValue(row.transactionId);
    if (txId !== undefined) {
      seen.add(txId);
    }
    const signedEnvelope = asJsonObject(row.signedEnvelope);
    const envelope = asJsonObject(signedEnvelope?.envelope)
      ?? (signedEnvelope?.schema === "flowchain.local_transaction_envelope.v0" ? signedEnvelope : null);
    const envelopeTxId = stringValue(envelope?.transactionId);
    if (envelopeTxId !== undefined) {
      seen.add(envelopeTxId);
    }
  }
  return seen;
}

function transactionSubmit(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "transaction_submit");
  const paramsFinding = findSecret(objectParams);
  if (paramsFinding !== null) {
    throw secretRejected("transaction intake contained secret-shaped material", paramsFinding);
  }
  const signedEnvelope = signedEnvelopeForSubmit(objectParams);
  const submittedBy = optionalString(objectParams, "submittedBy") ?? "local-control-plane";
  const preflightPayload: JsonObject = { signedEnvelope, submittedBy };
  const preflightFinding = findSecret(preflightPayload);
  if (preflightFinding !== null) {
    throw secretRejected("transaction intake contained secret-shaped material", preflightFinding);
  }
  const verification = verifyFlowchainEnvelope({
    document: signedEnvelope.document,
    envelope: signedEnvelope.envelope,
    context: {
      chainId: FLOWCHAIN_LIVE_L1_CHAIN_ID,
      networkProfile: FLOWCHAIN_LIVE_L1_NETWORK_PROFILE,
      expectedNonce: optionalString(objectParams, "expectedNonce") ?? signedEnvelope.envelope.nonce,
      requireCanonical: true,
      seenNonces: seenTransactionReplayKeys(state),
      seenTransactionIds: seenTransactionIds(state),
    },
  });
  if (verification.ok !== true) {
    throw cryptoRejected("transaction_submit rejected by FlowChain crypto runtime verification", {
      failureCodes: verification.failureCodes,
      transactionId: verification.transactionId,
      envelopeId: verification.envelopeId,
    } as JsonObject);
  }
  const cryptoReplayKey = localTransactionReplayKey(signedEnvelope.envelope);
  const intakePayload: JsonObject = {
    signedEnvelope,
    cryptoVerification: verification as JsonObject,
    cryptoReplayKey,
    submittedBy,
  };
  const intakeId = stableId("flowmemory.control_plane.transaction_intake.v0", intakePayload);
  const row: JsonObject = {
    schema: "flowmemory.control_plane.transaction_intake.v0",
    intakeId,
    txId: stringValue(verification.transactionId) ?? stableId("flowmemory.control_plane.transaction.local_tx_id.v0", intakePayload),
    receivedAt: "2026-05-13T00:00:00.000Z",
    status: "accepted_crypto_verified",
    intakeMode: "local-file",
    runtimeIntakePath: state.paths.txIntakePath,
    ...intakePayload,
    localOnly: true,
  };
  appendNdjson(state.paths.txIntakePath, row);
  return {
    schema: "flowmemory.control_plane.transaction_submit_result.v0",
    accepted: true,
    intakeId,
    txId: row.txId,
    status: row.status,
    crypto: {
      ok: true,
      failureCodes: [],
      transactionId: verification.transactionId,
      envelopeId: verification.envelopeId,
      replayKey: cryptoReplayKey,
    },
    forwardedTo: "local-file-intake",
    runtimeIntakePath: state.paths.txIntakePath,
    localOnly: true,
  };
}

function accountList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "account_list");
  const limit = pageLimit(objectParams);
  const rows = nodeAccountRows(state).slice(0, limit);
  return {
    schema: "flowmemory.control_plane.account_list.v0",
    count: rows.length,
    nextCursor: null,
    accounts: rows,
    localOnly: true,
  };
}

function accountGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "account_get");
  const accountId = requiredString(objectParams, ["accountId", "agentId", "operatorId"], "account_get");
  const account = nodeAccountRows(state).find((row) => row.accountId === accountId || row.keyReferenceId === accountId);
  if (account === undefined) {
    throw objectNotFound(`account not found: ${accountId}`, { accountId });
  }
  return {
    schema: "flowmemory.control_plane.account_detail.v0",
    account,
    balance: {
      schema: "flowmemory.control_plane.balance.v0",
      accountId: account.accountId,
      amount: account.balance ?? "0",
      noValue: true,
      localOnly: true,
    },
    localOnly: true,
  };
}

function balanceGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "balance_get");
  const accountId = requiredString(objectParams, ["accountId", "agentId", "operatorId"], "balance_get");
  const account = nodeAccountRows(state).find((row) => row.accountId === accountId || row.keyReferenceId === accountId);
  if (account === undefined) {
    throw objectNotFound(`balance account not found: ${accountId}`, { accountId });
  }
  return {
    schema: "flowmemory.control_plane.balance.v0",
    accountId: account.accountId,
    amount: "0",
    unit: "no-value-local-credit",
    noValue: true,
    localOnly: true,
  };
}

function tokenList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "token_list");
  const limit = pageLimit(objectParams);
  const status = optionalString(objectParams, "status");
  const rows = tokenRows(state)
    .filter((token) => status === undefined || token.status === status)
    .slice(0, limit);
  return {
    schema: "flowmemory.control_plane.token_list.v0",
    count: rows.length,
    nextCursor: null,
    tokens: rows,
    localOnly: true,
  };
}

function tokenGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "token_get");
  const key = requiredString(objectParams, ["tokenId", "assetId", "symbol"], "token_get");
  const token = tokenRows(state).find((row) => row.tokenId === key || row.symbol === key || asJsonObject(row.token)?.assetId === key);
  if (token === undefined) {
    throw objectNotFound(`token not found: ${key}`, { id: key });
  }
  return {
    schema: "flowmemory.control_plane.token_detail.v0",
    token,
    provenance: {
      sources: [provenanceSource("devnet", "devnet/local/state.json", "flowmemory.local_devnet.token.v0")],
    },
    localOnly: true,
  };
}

function tokenBalanceList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "token_balance_list");
  const limit = pageLimit(objectParams);
  const accountId = optionalString(objectParams, "accountId");
  const tokenId = optionalString(objectParams, "tokenId");
  const rows = tokenBalanceRows(state)
    .filter((balance) => accountId === undefined || balance.accountId === accountId)
    .filter((balance) => tokenId === undefined || balance.tokenId === tokenId)
    .slice(0, limit);
  return {
    schema: "flowmemory.control_plane.token_balance_list.v0",
    count: rows.length,
    nextCursor: null,
    balances: rows,
    localOnly: true,
  };
}

function tokenBalanceGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "token_balance_get");
  const key = requiredString(objectParams, ["balanceId", "tokenBalanceId", "accountId"], "token_balance_get");
  const tokenId = optionalString(objectParams, "tokenId");
  const balance = tokenBalanceRows(state).find((row) => {
    const keyMatches = row.balanceId === key || row.accountId === key;
    return keyMatches && (tokenId === undefined || row.tokenId === tokenId);
  });
  if (balance === undefined) {
    throw objectNotFound(`token balance not found: ${key}`, { id: key, tokenId });
  }
  return {
    schema: "flowmemory.control_plane.token_balance_detail.v0",
    balance,
    localOnly: true,
  };
}

function poolList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "pool_list");
  const limit = pageLimit(objectParams);
  const tokenId = optionalString(objectParams, "tokenId");
  const rows = poolRows(state)
    .filter((pool) => tokenId === undefined || pool.token0 === tokenId || pool.token1 === tokenId)
    .slice(0, limit);
  return {
    schema: "flowmemory.control_plane.pool_list.v0",
    count: rows.length,
    nextCursor: null,
    pools: rows,
    localOnly: true,
  };
}

function poolGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "pool_get");
  const poolId = requiredString(objectParams, ["poolId", "address"], "pool_get");
  const pool = poolRows(state).find((row) => row.poolId === poolId || asJsonObject(row.pool)?.address === poolId);
  if (pool === undefined) {
    throw objectNotFound(`pool not found: ${poolId}`, { poolId });
  }
  return {
    schema: "flowmemory.control_plane.pool_detail.v0",
    pool,
    localOnly: true,
  };
}

function lpPositionList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "lp_position_list");
  const limit = pageLimit(objectParams);
  const accountId = optionalString(objectParams, "accountId");
  const poolId = optionalString(objectParams, "poolId");
  const rows = lpPositionRows(state)
    .filter((position) => accountId === undefined || position.accountId === accountId)
    .filter((position) => poolId === undefined || position.poolId === poolId)
    .slice(0, limit);
  return {
    schema: "flowmemory.control_plane.lp_position_list.v0",
    count: rows.length,
    nextCursor: null,
    positions: rows,
    localOnly: true,
  };
}

function lpPositionGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "lp_position_get");
  const key = requiredString(objectParams, ["positionId", "lpPositionId", "accountId"], "lp_position_get");
  const position = lpPositionRows(state).find((row) => row.positionId === key || row.accountId === key);
  if (position === undefined) {
    throw objectNotFound(`LP position not found: ${key}`, { id: key });
  }
  return {
    schema: "flowmemory.control_plane.lp_position_detail.v0",
    position,
    localOnly: true,
  };
}

function swapList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "swap_list");
  const limit = pageLimit(objectParams);
  const accountId = optionalString(objectParams, "accountId");
  const poolId = optionalString(objectParams, "poolId");
  const rows = swapRows(state)
    .filter((swap) => accountId === undefined || swap.accountId === accountId)
    .filter((swap) => poolId === undefined || swap.poolId === poolId)
    .slice(0, limit);
  return {
    schema: "flowmemory.control_plane.swap_list.v0",
    count: rows.length,
    nextCursor: null,
    swaps: rows,
    localOnly: true,
  };
}

function swapGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "swap_get");
  const key = requiredString(objectParams, ["swapId", "receiptId", "txId", "transactionId"], "swap_get");
  const swap = swapRows(state).find((row) => row.swapId === key || row.txId === key);
  if (swap === undefined) {
    throw objectNotFound(`swap not found: ${key}`, { id: key });
  }
  return {
    schema: "flowmemory.control_plane.swap_detail.v0",
    swap,
    localOnly: true,
  };
}

function productFlowStatus(_params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const counts = {
    wallets: walletMetadataRows(state).length,
    accounts: nodeAccountRows(state).length,
    localBalances: Object.keys(devnetLocalTestUnitBalances(state)).length,
    balanceTransfers: Object.keys(devnetBalanceTransfers(state)).length,
    tokens: tokenRows(state).length,
    nativeTokens: devnetProductMapCount(state, ["tokens", "tokenDefinitions", "tokenLaunches", "localTokens", "launchedTokens"]),
    tokenBalances: tokenBalanceRows(state).length,
    pools: poolRows(state).length,
    lpPositions: lpPositionRows(state).length,
    swaps: swapRows(state).length,
    bridgeDeposits: bridgeDepositRows(state).length,
    bridgeCredits: bridgeCreditRows(state).length,
    blocks: blockRows(state).length,
    transactions: transactionRows(state).length,
  };
  const stages = [
    { stage: "wallet", ready: counts.wallets > 0 || counts.accounts > 0 },
    { stage: "funding", ready: counts.localBalances > 0 || counts.bridgeCredits > 0 || counts.tokenBalances > 0 },
    { stage: "transfer", ready: counts.balanceTransfers > 0 },
    { stage: "token_launch", ready: counts.nativeTokens > 0 },
    { stage: "dex_pool", ready: counts.pools > 0 },
    { stage: "liquidity", ready: counts.lpPositions > 0 },
    { stage: "swap", ready: counts.swaps > 0 },
    { stage: "bridge_credit", ready: counts.bridgeCredits > 0 },
    { stage: "explorer", ready: counts.blocks > 0 && counts.transactions > 0 },
  ].map((entry) => ({
    schema: "flowmemory.control_plane.product_flow_stage.v0",
    stage: entry.stage,
    status: entry.ready ? "ready" : "missing",
    localOnly: true,
  }));
  return {
    schema: "flowmemory.control_plane.product_flow_status.v0",
    status: stages.every((stage) => stage.status === "ready") ? "ready_local_product_testnet" : "incomplete_local_product_testnet",
    counts,
    stages,
    missingStages: stages.filter((stage) => stage.status !== "ready").map((stage) => stage.stage),
    localOnly: true,
  };
}

function faucetEventList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "faucet_event_list");
  const limit = pageLimit(objectParams);
  const accounts = nodeAccountRows(state);
  const events = accounts.slice(0, Math.min(limit, accounts.length)).map((account) => ({
    schema: "flowmemory.control_plane.faucet_event.v0",
    eventId: stableId("flowmemory.control_plane.faucet_event.no_value.v0", account.accountId),
    accountId: account.accountId,
    amount: "0",
    status: "no_value_local_faucet_disabled",
    note: "The local runtime is explicitly no-value; faucet events are metadata only.",
    localOnly: true,
  }));
  return {
    schema: "flowmemory.control_plane.faucet_event_list.v0",
    count: events.length,
    nextCursor: null,
    faucetEvents: events,
    localOnly: true,
  };
}

function walletMetadataList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "wallet_metadata_list");
  const limit = pageLimit(objectParams);
  const rows = walletMetadataRows(state).slice(0, limit);
  return {
    schema: "flowmemory.control_plane.wallet_public_metadata_list.v0",
    count: rows.length,
    nextCursor: null,
    wallets: rows,
    localOnly: true,
  };
}

function walletMetadataGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "wallet_metadata_get");
  const walletId = requiredString(objectParams, ["walletId", "accountId"], "wallet_metadata_get");
  const wallet = walletMetadataRows(state).find((row) => row.walletId === walletId || row.accountId === walletId);
  if (wallet === undefined) {
    throw objectNotFound(`wallet public metadata not found: ${walletId}`, { walletId });
  }
  return {
    schema: "flowmemory.control_plane.wallet_public_metadata_detail.v0",
    wallet,
    localOnly: true,
  };
}

function rootfieldGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "rootfield_get");
  const rootfieldId = requiredString(objectParams, ["rootfieldId"], "rootfield_get");
  const bundle = state.launchCore.rootfieldBundles.find((candidate) => candidate.rootfieldId === rootfieldId);
  const devnetRootfield = devnetRootfields(state)[rootfieldId] ?? null;

  if (bundle === undefined && devnetRootfield === null) {
    throw objectNotFound(`rootfield not found: ${rootfieldId}`, { rootfieldId });
  }

  return {
    schema: "flowmemory.control_plane.rootfield.v0",
    rootfieldId,
    bundle: bundle ?? null,
    devnetRootfield,
    memoryCellId: rootfieldId,
    agentViewId: state.launchCore.agentMemoryViews.find((view) => view.rootfieldId === rootfieldId)?.viewId ?? null,
    provenance: {
      sources: [
        bundle ? provenanceSource("flowmemory", "fixtures/launch-core/flowmemory-launch-v0.json", bundle.schema) : null,
        devnetRootfield ? provenanceSource("devnet", "fixtures/launch-core/generated/devnet/state.json", "flowmemory.local_devnet.rootfield.v0") : null,
      ].filter((entry): entry is JsonObject => entry !== null),
    },
    localOnly: true,
  };
}

function rootfieldList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "rootfield_list");
  const limit = pageLimit(objectParams);
  const status = optionalString(objectParams, "status");
  const rows = rootfieldRows(state)
    .filter((rootfield) => status === undefined || rootfield.status === status)
    .slice(0, limit);
  return {
    schema: "flowmemory.control_plane.rootfield_list.v0",
    count: rows.length,
    nextCursor: null,
    rootfields: rows,
    localOnly: true,
  };
}

function artifactGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "artifact_get");
  const uri = optionalString(objectParams, "uri");
  const artifactId = optionalString(objectParams, "artifactId");
  const commitment = optionalString(objectParams, "commitment");

  if (uri === undefined && artifactId === undefined && commitment === undefined) {
    throw invalidParams("artifact_get requires uri, artifactId, or commitment");
  }

  if (uri !== undefined) {
    const artifact = state.artifacts.artifactsByUri[uri];
    if (artifact !== undefined) {
      return {
        schema: "flowmemory.control_plane.artifact.v0",
        artifactId: stableId("flowmemory.control_plane.artifact.fixture.v0", uri),
        uri,
        artifact,
        resolverPolicyId: state.artifacts.resolverPolicyId,
        provenance: {
          sources: [provenanceSource("verifier", "services/verifier/fixtures/artifacts.json", "flowmemory.verifier.artifact_fixture.v0")],
        },
        localOnly: true,
      };
    }
  }

  for (const [id, value] of Object.entries(devnetArtifacts(state))) {
    const entry = value as JsonObject;
    if (artifactId === id || artifactId === entry.artifactId || commitment === entry.commitment || uri === entry.uriHint) {
      return {
        schema: "flowmemory.control_plane.artifact.v0",
        artifactId: id,
        uri: entry.uriHint ?? null,
        artifact: entry,
        resolverPolicyId: "flowmemory.local_devnet.artifact_commitment.v0",
        provenance: {
          sources: [provenanceSource("devnet", "fixtures/launch-core/generated/devnet/state.json", "flowmemory.local_devnet.artifact_commitment.v0")],
        },
        localOnly: true,
      };
    }
  }

  throw objectNotFound("artifact not found", { uri, artifactId, commitment });
}

function artifactAvailabilityList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "artifact_availability_list");
  const limit = pageLimit(objectParams);
  const status = optionalString(objectParams, "status");
  const rootfieldId = optionalString(objectParams, "rootfieldId");
  const rows = artifactAvailabilityRows(state)
    .filter((artifact) => status === undefined || artifact.status === status)
    .filter((artifact) => rootfieldId === undefined || artifact.rootfieldId === rootfieldId)
    .slice(0, limit);
  return {
    schema: "flowmemory.control_plane.artifact_availability_list.v0",
    count: rows.length,
    nextCursor: null,
    artifacts: rows,
    localOnly: true,
  };
}

function artifactAvailabilityGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "artifact_availability_get");
  const key = requiredString(objectParams, ["availabilityId", "artifactId", "commitment", "uri"], "artifact_availability_get");
  const artifact = artifactAvailabilityRows(state).find((candidate) => {
    return candidate.availabilityId === key
      || candidate.artifactId === key
      || candidate.commitment === key
      || candidate.uri === key;
  });
  if (artifact === undefined) {
    throw objectNotFound(`artifact availability not found: ${key}`, { id: key });
  }
  return {
    schema: "flowmemory.control_plane.artifact_availability_detail.v0",
    artifactAvailability: artifact,
    provenance: artifact.source === "verifier-fixture"
      ? {
        sources: [provenanceSource("verifier", "services/verifier/fixtures/artifacts.json", "flowmemory.verifier.artifact_fixture.v0")],
      }
      : {
        sources: [provenanceSource("devnet", "fixtures/launch-core/generated/devnet/state.json", "flowmemory.local_devnet.artifact_commitment.v0")],
      },
    localOnly: true,
  };
}

function receiptGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "receipt_get");
  const key = requiredString(objectParams, ["receiptId", "observationId", "reportId"], "receipt_get");
  const receipt = receiptByAnyId(state, key);

  if (receipt !== undefined) {
    const signal = signalByObservation(state, receipt.observationId) ?? null;
    const transition = transitionByAnyId(state, receipt.receiptId) ?? null;
    return {
      schema: "flowmemory.control_plane.receipt.v0",
      receipt,
      signal,
      transition,
      verifierReport: reportByIdOrObservation(state, receipt.reportId) ?? null,
      provenance: provenanceForObject(state, receipt.receiptId),
      localOnly: true,
    };
  }

  const devnetReceipt = devnetWorkReceipts(state)[key];
  if (devnetReceipt !== undefined) {
    return {
      schema: "flowmemory.control_plane.receipt.v0",
      receipt: devnetReceipt,
      signal: null,
      transition: null,
      verifierReport: null,
      provenance: {
        sources: [provenanceSource("devnet", "fixtures/launch-core/generated/devnet/verifier-handoff.json", "flowmemory.local_devnet.work_receipt.v0")],
      },
      localOnly: true,
    };
  }

  throw objectNotFound(`receipt not found: ${key}`, { id: key });
}

function receiptList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "receipt_list");
  const rootfieldId = optionalString(objectParams, "rootfieldId");
  const status = optionalString(objectParams, "status");
  const limit = pageLimit(objectParams);
  const receipts = state.launchCore.memoryReceipts
    .filter((receipt) => rootfieldId === undefined || receipt.rootfieldId === rootfieldId)
    .filter((receipt) => status === undefined || receipt.flowMemoryStatus === status || receipt.verifierStatus === status)
    .slice(0, limit);

  return {
    schema: "flowmemory.control_plane.receipt_list.v0",
    count: receipts.length,
    nextCursor: null,
    receipts,
    localOnly: true,
  };
}

function workReceiptList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "work_receipt_list");
  const limit = pageLimit(objectParams);
  const rootfieldId = optionalString(objectParams, "rootfieldId");
  const status = optionalString(objectParams, "status");
  const rows = workReceiptRows(state)
    .filter((receipt) => rootfieldId === undefined || receipt.rootfieldId === rootfieldId)
    .filter((receipt) => status === undefined || receipt.status === status)
    .slice(0, limit);
  return {
    schema: "flowmemory.control_plane.work_receipt_list.v0",
    count: rows.length,
    nextCursor: null,
    workReceipts: rows,
    localOnly: true,
  };
}

function workReceiptGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "work_receipt_get");
  const key = requiredString(objectParams, ["workReceiptId", "receiptId", "observationId", "reportId"], "work_receipt_get");
  const row = workReceiptRows(state).find((receipt) => {
    return receipt.workReceiptId === key
      || receipt.receiptId === key
      || asJsonObject(receipt.memoryReceipt)?.observationId === key
      || asJsonObject(receipt.memoryReceipt)?.reportId === key;
  });
  if (row === undefined) {
    throw objectNotFound(`work receipt not found: ${key}`, { id: key });
  }
  return {
    schema: "flowmemory.control_plane.work_receipt.v0",
    workReceipt: row,
    provenance: provenanceForObject(state, stringValue(row.receiptId) ?? key),
    localOnly: true,
  };
}

function verifierModuleList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "verifier_module_list");
  const limit = pageLimit(objectParams);
  const status = optionalString(objectParams, "status");
  const rows = verifierModuleRows(state)
    .filter((module) => status === undefined || module.status === status)
    .slice(0, limit);
  return {
    schema: "flowmemory.control_plane.verifier_module_list.v0",
    count: rows.length,
    nextCursor: null,
    verifierModules: rows,
    localOnly: true,
  };
}

function verifierModuleGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "verifier_module_get");
  const key = requiredString(objectParams, ["moduleId", "verifierId", "resolverPolicyId"], "verifier_module_get");
  const verifierModule = verifierModuleRows(state).find((candidate) => {
    return candidate.moduleId === key
      || candidate.verifierId === key
      || candidate.resolverPolicyId === key;
  });
  if (verifierModule === undefined) {
    throw objectNotFound(`verifier module not found: ${key}`, { id: key });
  }
  return {
    schema: "flowmemory.control_plane.verifier_module_detail.v0",
    verifierModule,
    provenance: {
      sources: [
        verifierModule.source === "local-devnet"
          ? provenanceSource("devnet", "fixtures/launch-core/generated/devnet/state.json", "flowmemory.local_devnet.verifier_module.v0")
          : provenanceSource("verifier", "services/verifier/out/reports.json", "flowmemory.verifier.persistence.v0"),
      ],
    },
    localOnly: true,
  };
}

function verifierReportGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "verifier_report_get");
  const key = requiredString(objectParams, ["reportId", "observationId"], "verifier_report_get");
  const report = reportByIdOrObservation(state, key);

  if (report !== undefined) {
    return {
      schema: "flowmemory.control_plane.verifier_report.v0",
      report,
      memoryReceipt: receiptByAnyId(state, report.reportId) ?? null,
      provenance: provenanceForObject(state, report.reportId),
      localOnly: true,
    };
  }

  const devnetReport = devnetReports(state)[key];
  if (devnetReport !== undefined) {
    return {
      schema: "flowmemory.control_plane.verifier_report.v0",
      report: devnetReport,
      memoryReceipt: null,
      provenance: {
        sources: [provenanceSource("devnet", "fixtures/launch-core/generated/devnet/verifier-handoff.json", "flowmemory.local_devnet.verifier_report.v0")],
      },
      localOnly: true,
    };
  }

  throw objectNotFound(`verifier report not found: ${key}`, { id: key });
}

function verifierReportList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "verifier_report_list");
  const rootfieldId = optionalString(objectParams, "rootfieldId");
  const status = optionalString(objectParams, "status");
  const limit = pageLimit(objectParams);
  const reports = state.verifier.reports
    .filter((report) => rootfieldId === undefined || report.reportCore.observation.rootfieldId === rootfieldId)
    .filter((report) => status === undefined || report.reportCore.status === status)
    .slice(0, limit);

  return {
    schema: "flowmemory.control_plane.verifier_report_list.v0",
    count: reports.length,
    nextCursor: null,
    reports,
    localOnly: true,
  };
}

function memoryCellGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "memory_cell_get");
  const key = requiredString(objectParams, ["memoryCellId", "rootfieldId"], "memory_cell_get");
  const rootfieldId = key.startsWith("memory:") ? key.slice("memory:".length) : key;
  const devnetCellEntry = Object.entries(devnetMemoryCells(state)).find(([id, value]) => {
    const cell = value as JsonObject;
    return id === key || cell.memoryCellId === key || cell.rootfieldId === key || cell.rootfieldId === rootfieldId;
  });
  const bundle = state.launchCore.rootfieldBundles.find((candidate) => candidate.rootfieldId === rootfieldId);
  const agentView = state.launchCore.agentMemoryViews.find((view) => view.rootfieldId === rootfieldId) ?? null;

  if (bundle === undefined && agentView === null && devnetCellEntry === undefined) {
    throw objectNotFound(`memory cell not found: ${key}`, { id: key });
  }

  const devnetCell = devnetCellEntry?.[1] as JsonObject | undefined;
  return {
    schema: "flowmemory.control_plane.memory_cell.v0",
    memoryCellId: typeof devnetCell?.memoryCellId === "string" ? devnetCell.memoryCellId : rootfieldId,
    rootfieldId: typeof devnetCell?.rootfieldId === "string" ? devnetCell.rootfieldId : rootfieldId,
    status: typeof devnetCell?.status === "string" ? devnetCell.status : bundle?.status ?? agentView?.status ?? "observed",
    latestRoot: typeof devnetCell?.currentRoot === "string" ? devnetCell.currentRoot : bundle?.latestRoot ?? agentView?.latestRoot ?? ZERO_ROOT,
    devnetMemoryCell: devnetCell ?? null,
    rootfieldBundle: bundle ?? null,
    agentMemoryView: agentView,
    extensionPoint: devnetCell === undefined
      ? "Native MemoryCell handoff files are not emitted yet; this V0 object is projected from RootfieldBundle and AgentMemoryView fixtures."
      : "Loaded from local devnet memoryCells handoff.",
    provenance: provenanceForObject(state, rootfieldId),
    localOnly: true,
  };
}

function memoryCellList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "memory_cell_list");
  const limit = pageLimit(objectParams);
  const rootfieldId = optionalString(objectParams, "rootfieldId");
  const status = optionalString(objectParams, "status");
  const rows = memoryCellRows(state)
    .filter((cell) => rootfieldId === undefined || cell.rootfieldId === rootfieldId)
    .filter((cell) => status === undefined || cell.status === status)
    .slice(0, limit);
  return {
    schema: "flowmemory.control_plane.memory_cell_list.v0",
    count: rows.length,
    nextCursor: null,
    memoryCells: rows,
    localOnly: true,
  };
}

function agentGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "agent_get");
  const key = requiredString(objectParams, ["agentId", "viewId", "rootfieldId"], "agent_get");
  const devnetAgentEntry = Object.entries(devnetAgentAccounts(state)).find(([id, value]) => {
    const agent = value as JsonObject;
    return id === key || agent.agentId === key || agent.memoryRoot === key;
  });
  const view = state.launchCore.agentMemoryViews.find((candidate) => {
    return candidate.viewId === key || candidate.rootfieldId === key;
  });

  if (view === undefined && devnetAgentEntry === undefined) {
    throw objectNotFound(`agent memory view not found: ${key}`, { id: key });
  }

  const devnetAgent = devnetAgentEntry?.[1] as JsonObject | undefined;
  return {
    schema: "flowmemory.control_plane.agent.v0",
    agentId: typeof devnetAgent?.agentId === "string" ? devnetAgent.agentId : view?.viewId ?? key,
    agentAccount: devnetAgent ?? null,
    agentMemoryView: view ?? null,
    rootfieldBundle: view === undefined ? null : state.launchCore.rootfieldBundles.find((bundle) => bundle.rootfieldId === view.rootfieldId) ?? null,
    provenance: provenanceForObject(state, view?.viewId ?? key),
    localOnly: true,
  };
}

function agentList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "agent_list");
  const limit = pageLimit(objectParams);
  const rootfieldId = optionalString(objectParams, "rootfieldId");
  const status = optionalString(objectParams, "status");
  const rows = agentRows(state)
    .filter((agent) => rootfieldId === undefined || agent.rootfieldId === rootfieldId)
    .filter((agent) => status === undefined || agent.status === status)
    .slice(0, limit);
  return {
    schema: "flowmemory.control_plane.agent_list.v0",
    count: rows.length,
    nextCursor: null,
    agents: rows,
    localOnly: true,
  };
}

function modelList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "model_list");
  const limit = pageLimit(objectParams);
  const rootfieldId = optionalString(objectParams, "rootfieldId");
  const status = optionalString(objectParams, "status");
  const rows = modelRows(state)
    .filter((model) => rootfieldId === undefined || model.rootfieldId === rootfieldId)
    .filter((model) => status === undefined || model.status === status)
    .slice(0, limit);
  return {
    schema: "flowmemory.control_plane.model_list.v0",
    count: rows.length,
    nextCursor: null,
    models: rows,
    localOnly: true,
  };
}

function modelGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "model_get");
  const key = requiredString(objectParams, ["modelId", "rootfieldId"], "model_get");
  const model = modelRows(state).find((candidate) => candidate.modelId === key || candidate.rootfieldId === key);
  if (model === undefined) {
    throw objectNotFound(`model not found: ${key}`, { id: key });
  }
  return {
    schema: "flowmemory.control_plane.model_detail.v0",
    model,
    provenance: {
      sources: [
        model.source === "local-devnet"
          ? provenanceSource("devnet", "fixtures/launch-core/generated/devnet/state.json", "flowmemory.local_devnet.model_passport.v0")
          : provenanceSource("flowmemory", "fixtures/launch-core/flowmemory-launch-v0.json", "flowmemory.agent_memory_view.v0", "Projected model row; no ModelPassport fixture exists yet."),
      ],
    },
    localOnly: true,
  };
}

function challengeGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "challenge_get");
  const targetId = requiredString(objectParams, ["challengeId", "targetId", "receiptId", "reportId", "rootfieldId"], "challenge_get");
  const challengeEntry = Object.entries(devnetChallenges(state)).find(([id, value]) => {
    const challenge = value as JsonObject;
    return id === targetId || challenge.challengeId === targetId || challenge.receiptId === targetId;
  });
  if (challengeEntry !== undefined) {
    return {
      schema: "flowmemory.control_plane.challenge.v0",
      challengeId: challengeEntry[0],
      challenge: challengeEntry[1] as JsonObject,
      status: (challengeEntry[1] as JsonObject).status ?? "unknown",
      provenance: provenanceForObject(state, challengeEntry[0]),
      localOnly: true,
    };
  }

  const target = findObject(state, targetId);

  return {
    schema: "flowmemory.control_plane.challenge.v0",
    challengeId: stableId("flowmemory.control_plane.challenge.placeholder.v0", targetId),
    targetId,
    targetType: target.type,
    status: "not_opened",
    reasonCodes: [],
    openedAt: null,
    closesAt: null,
    extensionPoint: "No challenge handoff fixture exists in V0. This method reserves the stable read shape for later challenge state.",
    localOnly: true,
  };
}

function challengeList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "challenge_list");
  const limit = pageLimit(objectParams);
  const status = optionalString(objectParams, "status");
  const rows = challengeRows(state)
    .filter((challenge) => status === undefined || challenge.status === status)
    .slice(0, limit);
  return {
    schema: "flowmemory.control_plane.challenge_list.v0",
    count: rows.length,
    nextCursor: null,
    challenges: rows,
    extensionPoint: rows.length === 0
      ? "No challenge handoff fixture exists in V0; challenge_get can still return a stable not_opened placeholder for known local objects."
      : undefined,
    localOnly: true,
  };
}

function finalityStatusFor(status: string | null): string {
  if (status === "verified" || status === "valid" || status === "finalized" || status === "local-placeholder") {
    return "local-finalized";
  }
  if (status === "failed" || status === "invalid") {
    return "local-rejected";
  }
  if (status === "reorged" || status === "removed") {
    return "reorged";
  }
  if (status === "unsupported") {
    return "local-unsupported";
  }
  return "local-pending";
}

function finalityGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "finality_get");
  const key = requiredString(objectParams, ["objectId", "rootfieldId", "receiptId", "reportId", "transitionId"], "finality_get");
  const finalityEntry = Object.entries(devnetFinalityReceipts(state)).find(([id, value]) => {
    const finality = value as JsonObject;
    return id === key || finality.finalityReceiptId === key || finality.receiptId === key || finality.rootfieldId === key;
  });
  if (finalityEntry !== undefined) {
    const finality = finalityEntry[1] as JsonObject;
    const sourceStatus = typeof finality.finalityStatus === "string" ? finality.finalityStatus : null;
    return {
      schema: "flowmemory.control_plane.finality.v0",
      objectId: key,
      objectType: "devnet_finality_receipt",
      finalityReceipt: finality,
      status: finalityStatusFor(sourceStatus),
      sourceStatus,
      challengeWindow: null,
      settlement: "local-devnet-fixture",
      limitations: [
        "This is fixture/devnet finality only.",
        "No production consensus, bridge finality, verifier economics, or challenge market is implied.",
      ],
      localOnly: true,
    };
  }

  const target = findObject(state, key);
  const status = typeof target.object.status === "string"
    ? target.object.status
    : typeof target.object.flowMemoryStatus === "string"
      ? target.object.flowMemoryStatus
      : typeof target.object.verifierStatus === "string"
        ? target.object.verifierStatus
        : typeof target.object.finalityStatus === "string"
          ? target.object.finalityStatus
          : null;

  return {
    schema: "flowmemory.control_plane.finality.v0",
    objectId: key,
    objectType: target.type,
    status: finalityStatusFor(status),
    sourceStatus: status,
    challengeWindow: null,
    settlement: "local-fixture",
    limitations: [
      "This is fixture/devnet finality only.",
      "No production consensus, bridge finality, verifier economics, or challenge market is implied.",
    ],
    localOnly: true,
  };
}

function finalityList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "finality_list");
  const limit = pageLimit(objectParams);
  const status = optionalString(objectParams, "status");
  const rootfieldId = optionalString(objectParams, "rootfieldId");
  const rows = finalityRows(state)
    .filter((finality) => status === undefined || finality.status === status)
    .filter((finality) => rootfieldId === undefined || finality.rootfieldId === rootfieldId)
    .slice(0, limit);
  return {
    schema: "flowmemory.control_plane.finality_list.v0",
    count: rows.length,
    nextCursor: null,
    finality: rows,
    localOnly: true,
  };
}

function bridgeObservationList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "bridge_observation_list");
  const limit = pageLimit(objectParams);
  const rows = bridgeObservationRows(state).slice(0, limit);
  return {
    schema: "flowmemory.control_plane.bridge_observation_list.v0",
    count: rows.length,
    nextCursor: null,
    observations: rows,
    localOnly: true,
  };
}

function bridgeObservationGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "bridge_observation_get");
  const key = requiredString(objectParams, ["observationId", "depositId", "txHash"], "bridge_observation_get");
  const observation = bridgeObservationRows(state).find((row) => {
    const deposit = asJsonObject(row.deposit) ?? {};
    return row.observationId === key || deposit.depositId === key || deposit.txHash === key;
  });
  if (observation === undefined) {
    throw objectNotFound(`bridge observation not found: ${key}`, { id: key });
  }
  return {
    schema: "flowmemory.control_plane.bridge_observation.v0",
    observation,
    localOnly: true,
  };
}

function bridgeDepositCryptoInput(deposit: JsonObject): JsonObject {
  return {
    sourceChainId: stringValue(deposit.sourceChainId),
    lockbox: stringValue(deposit.sourceContract),
    token: stringValue(deposit.token),
    depositor: stringValue(deposit.sender),
    recipient: stringValue(deposit.flowchainRecipient),
    amount: stringValue(deposit.amount),
    txHash: stringValue(deposit.txHash),
    logIndex: stringValue(deposit.logIndex),
    blockNumber: stringValue(deposit.sourceBlockNumber) ?? "0",
    eventNonce: stringValue(deposit.nonce) ?? "0",
  };
}

function bridgeSourceEventInput(deposit: JsonObject): JsonObject {
  return {
    sourceChainId: stringValue(deposit.sourceChainId),
    lockbox: stringValue(deposit.sourceContract),
    txHash: stringValue(deposit.txHash),
    logIndex: stringValue(deposit.logIndex),
  };
}

function seenBridgeReplayKeys(state: LoadedControlPlaneState): Set<string> {
  const seen = new Set<string>();
  for (const row of bridgeObservationRows(state)) {
    const replayKey = stringValue(row.replayKey);
    if (replayKey !== null) {
      seen.add(replayKey);
    }
  }
  return seen;
}

function verifyBridgeObservationForRuntime(observation: JsonObject, state: LoadedControlPlaneState): JsonObject {
  const failureCodes = new Set<string>();
  const deposit = asJsonObject(observation.deposit);
  let expectedReplayKey: string | undefined;
  let expectedObservationId: string | undefined;

  if (deposit === null) {
    failureCodes.add("missing-bridge-deposit");
  } else {
    try {
      expectedReplayKey = bridgeSourceEventReplayKey(bridgeSourceEventInput(deposit));
      expectedObservationId = flowchainBridgeObservationId(bridgeDepositCryptoInput(deposit));
      if (stringValue(observation.replayKey) !== expectedReplayKey) {
        failureCodes.add("wrong-bridge-replay-key");
      }
      if (stringValue(observation.observationId) !== expectedObservationId) {
        failureCodes.add("wrong-bridge-observation-id");
      }
      if (seenBridgeReplayKeys(state).has(expectedReplayKey)) {
        failureCodes.add("duplicate-bridge-replay-key");
        failureCodes.add("duplicate-bridge-source-event");
      }
    } catch {
      failureCodes.add("malformed-bridge-evidence");
    }

    const mode = stringValue(observation.mode);
    const sourceChainId = stringValue(deposit.sourceChainId);
    const guardrails = asJsonObject(observation.guardrails);
    if (mode === "base-mainnet-pilot" && sourceChainId !== "8453") {
      failureCodes.add("wrong-chain-id");
    }
    if (mode === "base-mainnet-pilot") {
      for (const [field, code] of [
        ["explicitChainId", "missing-chain-guardrail"],
        ["explicitContract", "missing-contract-guardrail"],
        ["explicitBlockRange", "missing-range-guardrail"],
        ["noSecrets", "missing-no-secret-guardrail"],
        ["approvedContract", "unapproved-bridge-lockbox"],
      ] as const) {
        if (guardrails?.[field] !== true) {
          failureCodes.add(code);
        }
      }
    }
  }

  if (failureCodes.size > 0) {
    throw cryptoRejected("bridge_observation_submit rejected by FlowChain bridge crypto verification", {
      failureCodes: [...failureCodes],
      observationId: stringValue(observation.observationId),
      replayKey: stringValue(observation.replayKey),
    } as JsonObject);
  }

  return {
    schema: "flowchain.bridge_observation_runtime_crypto.v0",
    ok: true,
    observationId: expectedObservationId,
    replayKey: expectedReplayKey,
  };
}

function bridgeObservationSubmit(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "bridge_observation_submit");
  const observation = asJsonObject(objectParams.observation) ?? objectParams;
  const finding = findSecret(observation);
  if (finding !== null) {
    throw secretRejected("bridge observation intake contained secret-shaped material", finding);
  }
  const cryptoVerification = verifyBridgeObservationForRuntime(observation, state);
  const observationId = stringValue(observation.observationId)
    ?? stableId("flowmemory.control_plane.bridge_observation_intake.v0", observation);
  const row: JsonObject = {
    schema: "flowmemory.bridge_deposit_observation.v0",
    observationId,
    observedAt: stringValue(observation.observedAt) ?? "2026-05-13T00:00:00.000Z",
    mode: stringValue(observation.mode) ?? "mock",
    productionReady: false,
    ...observation,
    cryptoVerification,
    intakeStatus: "accepted_local",
    localOnly: true,
  };
  appendNdjson(state.paths.bridgeObservationIntakePath, row);
  return {
    schema: "flowmemory.control_plane.bridge_observation_submit_result.v0",
    accepted: true,
    observationId,
    crypto: cryptoVerification,
    forwardedTo: "local-file-intake",
    runtimeIntakePath: state.paths.bridgeObservationIntakePath,
    localOnly: true,
  };
}

function bridgeDepositList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "bridge_deposit_list");
  const limit = pageLimit(objectParams);
  const rows = bridgeDepositRows(state).slice(0, limit);
  return {
    schema: "flowmemory.control_plane.bridge_deposit_list.v0",
    count: rows.length,
    nextCursor: null,
    deposits: rows,
    localOnly: true,
  };
}

function bridgeDepositGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "bridge_deposit_get");
  const key = requiredString(objectParams, ["depositId", "observationId", "txHash"], "bridge_deposit_get");
  const deposit = bridgeDepositRows(state).find((row) => row.depositId === key || row.observationId === key || row.txHash === key);
  if (deposit === undefined) {
    throw objectNotFound(`bridge deposit not found: ${key}`, { id: key });
  }
  return {
    schema: "flowmemory.control_plane.bridge_deposit_detail.v0",
    deposit,
    localOnly: true,
  };
}

function bridgeCreditList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "bridge_credit_list");
  const limit = pageLimit(objectParams);
  const rows = bridgeCreditRows(state).slice(0, limit);
  return {
    schema: "flowmemory.control_plane.bridge_credit_list.v0",
    count: rows.length,
    nextCursor: null,
    credits: rows,
    localOnly: true,
  };
}

function bridgeCreditGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "bridge_credit_get");
  const key = requiredString(objectParams, ["creditId", "depositId", "accountId"], "bridge_credit_get");
  const credit = bridgeCreditRows(state).find((row) => row.creditId === key || row.depositId === key || row.accountId === key);
  if (credit === undefined) {
    throw objectNotFound(`bridge credit not found: ${key}`, { id: key });
  }
  return {
    schema: "flowmemory.control_plane.bridge_credit_detail.v0",
    credit,
    localOnly: true,
  };
}

function withdrawalList(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "withdrawal_list");
  const limit = pageLimit(objectParams);
  const rows = withdrawalRows(state).slice(0, limit);
  return {
    schema: "flowmemory.control_plane.withdrawal_list.v0",
    count: rows.length,
    nextCursor: null,
    withdrawals: rows,
    localOnly: true,
  };
}

function withdrawalGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "withdrawal_get");
  const key = requiredString(objectParams, ["withdrawalId", "creditId", "depositId", "accountId"], "withdrawal_get");
  const withdrawal = withdrawalRows(state).find((row) => {
    return row.withdrawalId === key || row.creditId === key || row.depositId === key || row.accountId === key;
  });
  if (withdrawal === undefined) {
    throw objectNotFound(`withdrawal not found: ${key}`, { id: key });
  }
  return {
    schema: "flowmemory.control_plane.withdrawal_detail.v0",
    withdrawal,
    localOnly: true,
  };
}

function findObject(state: LoadedControlPlaneState, key: string): { type: string; object: JsonObject } {
  const receipt = receiptByAnyId(state, key);
  if (receipt !== undefined) {
    return { type: "memory_receipt", object: receipt as unknown as JsonObject };
  }
  const report = reportByIdOrObservation(state, key);
  if (report !== undefined) {
    return { type: "verifier_report", object: report.reportCore as unknown as JsonObject };
  }
  const signal = state.launchCore.memorySignals.find((candidate) => candidate.signalId === key || candidate.observationId === key || candidate.pulseId === key);
  if (signal !== undefined) {
    return { type: "memory_signal", object: signal as unknown as JsonObject };
  }
  const transition = transitionByAnyId(state, key);
  if (transition !== undefined) {
    return { type: "rootflow_transition", object: transition as unknown as JsonObject };
  }
  const bundle = state.launchCore.rootfieldBundles.find((candidate) => candidate.bundleId === key || candidate.rootfieldId === key);
  if (bundle !== undefined) {
    return { type: "rootfield_bundle", object: bundle as unknown as JsonObject };
  }
  const view = state.launchCore.agentMemoryViews.find((candidate) => candidate.viewId === key || candidate.rootfieldId === key);
  if (view !== undefined) {
    return { type: "agent_memory_view", object: view as unknown as JsonObject };
  }
  const block = blockRows(state).find((candidate) => candidate.blockHash === key || candidate.blockNumber === key);
  if (block !== undefined) {
    return { type: "block", object: block };
  }
  const transaction = transactionRows(state).find((candidate) => candidate.transactionId === key || candidate.txHash === key);
  if (transaction !== undefined) {
    return { type: "transaction", object: transaction };
  }
  const model = modelRows(state).find((candidate) => candidate.modelId === key || candidate.rootfieldId === key);
  if (model !== undefined) {
    return { type: "model", object: model };
  }
  const verifierModule = verifierModuleRows(state).find((candidate) => candidate.moduleId === key || candidate.verifierId === key || candidate.resolverPolicyId === key);
  if (verifierModule !== undefined) {
    return { type: "verifier_module", object: verifierModule };
  }
  const artifactAvailability = artifactAvailabilityRows(state).find((candidate) => candidate.availabilityId === key || candidate.artifactId === key || candidate.uri === key || candidate.commitment === key);
  if (artifactAvailability !== undefined) {
    return { type: "artifact_availability", object: artifactAvailability };
  }
  const account = nodeAccountRows(state).find((candidate) => candidate.accountId === key || candidate.keyReferenceId === key);
  if (account !== undefined) {
    return { type: "account", object: account };
  }
  const bridgeDeposit = bridgeDepositRows(state).find((candidate) => candidate.depositId === key || candidate.observationId === key || candidate.txHash === key);
  if (bridgeDeposit !== undefined) {
    return { type: "bridge_deposit", object: bridgeDeposit };
  }
  const bridgeCredit = bridgeCreditRows(state).find((candidate) => candidate.creditId === key || candidate.depositId === key || candidate.accountId === key);
  if (bridgeCredit !== undefined) {
    return { type: "bridge_credit", object: bridgeCredit };
  }
  const withdrawal = withdrawalRows(state).find((candidate) => candidate.withdrawalId === key || candidate.creditId === key || candidate.depositId === key || candidate.accountId === key);
  if (withdrawal !== undefined) {
    return { type: "withdrawal", object: withdrawal };
  }
  const token = tokenRows(state).find((candidate) => candidate.tokenId === key || candidate.symbol === key);
  if (token !== undefined) {
    return { type: "token", object: token };
  }
  const tokenBalance = tokenBalanceRows(state).find((candidate) => candidate.balanceId === key || candidate.accountId === key);
  if (tokenBalance !== undefined) {
    return { type: "token_balance", object: tokenBalance };
  }
  const pool = poolRows(state).find((candidate) => candidate.poolId === key);
  if (pool !== undefined) {
    return { type: "pool", object: pool };
  }
  const lpPosition = lpPositionRows(state).find((candidate) => candidate.positionId === key || candidate.accountId === key);
  if (lpPosition !== undefined) {
    return { type: "lp_position", object: lpPosition };
  }
  const swap = swapRows(state).find((candidate) => candidate.swapId === key || candidate.txId === key);
  if (swap !== undefined) {
    return { type: "swap", object: swap };
  }
  const devnetReceipt = devnetWorkReceipts(state)[key];
  if (devnetReceipt !== undefined) {
    return { type: "devnet_work_receipt", object: devnetReceipt as JsonObject };
  }
  const devnetReport = devnetReports(state)[key];
  if (devnetReport !== undefined) {
    return { type: "devnet_verifier_report", object: devnetReport as JsonObject };
  }
  const devnetRootfield = devnetRootfields(state)[key];
  if (devnetRootfield !== undefined) {
    return { type: "devnet_rootfield", object: devnetRootfield as JsonObject };
  }
  const devnetAgent = devnetAgentAccounts(state)[key];
  if (devnetAgent !== undefined) {
    return { type: "devnet_agent_account", object: devnetAgent as JsonObject };
  }
  const devnetMemoryCell = devnetMemoryCells(state)[key];
  if (devnetMemoryCell !== undefined) {
    return { type: "devnet_memory_cell", object: devnetMemoryCell as JsonObject };
  }
  const devnetChallenge = devnetChallenges(state)[key];
  if (devnetChallenge !== undefined) {
    return { type: "devnet_challenge", object: devnetChallenge as JsonObject };
  }
  const devnetFinality = devnetFinalityReceipts(state)[key];
  if (devnetFinality !== undefined) {
    return { type: "devnet_finality_receipt", object: devnetFinality as JsonObject };
  }

  throw objectNotFound(`object not found: ${key}`, { id: key });
}

function provenanceForObject(state: LoadedControlPlaneState, key: string): JsonObject {
  const sources: JsonObject[] = [];
  const links: JsonObject = {};
  const receipt = receiptByAnyId(state, key);
  const report = reportByIdOrObservation(state, key);
  const transition = transitionByAnyId(state, key);
  const bundle = state.launchCore.rootfieldBundles.find((candidate) => candidate.bundleId === key || candidate.rootfieldId === key);
  const view = state.launchCore.agentMemoryViews.find((candidate) => candidate.viewId === key || candidate.rootfieldId === key);
  const signal = state.launchCore.memorySignals.find((candidate) => candidate.signalId === key || candidate.observationId === key || candidate.pulseId === key);
  const block = blockRows(state).find((candidate) => candidate.blockHash === key || candidate.blockNumber === key);
  const transaction = transactionRows(state).find((candidate) => candidate.transactionId === key || candidate.txHash === key);
  const model = modelRows(state).find((candidate) => candidate.modelId === key || candidate.rootfieldId === key);
  const verifierModule = verifierModuleRows(state).find((candidate) => candidate.moduleId === key || candidate.verifierId === key || candidate.resolverPolicyId === key);
  const artifactAvailability = artifactAvailabilityRows(state).find((candidate) => candidate.availabilityId === key || candidate.artifactId === key || candidate.uri === key || candidate.commitment === key);
  const token = tokenRows(state).find((candidate) => candidate.tokenId === key || candidate.symbol === key);
  const tokenBalance = tokenBalanceRows(state).find((candidate) => candidate.balanceId === key || candidate.accountId === key);
  const pool = poolRows(state).find((candidate) => candidate.poolId === key);
  const lpPosition = lpPositionRows(state).find((candidate) => candidate.positionId === key || candidate.accountId === key);
  const swap = swapRows(state).find((candidate) => candidate.swapId === key || candidate.txId === key);
  const selectedReceipt = receipt ?? (report ? receiptByAnyId(state, report.reportId) : undefined);
  const selectedSignal = signal ?? (selectedReceipt ? signalByObservation(state, selectedReceipt.observationId) : undefined);
  const selectedTransition = transition ?? (selectedReceipt ? transitionByAnyId(state, selectedReceipt.receiptId) : undefined);

  if (selectedSignal !== undefined || selectedTransition !== undefined || bundle !== undefined || view !== undefined || selectedReceipt !== undefined) {
    sources.push(provenanceSource("flowmemory", "fixtures/launch-core/flowmemory-launch-v0.json", "flowmemory.launch_core.v0"));
  }
  if (selectedReceipt !== undefined || report !== undefined) {
    sources.push(provenanceSource("verifier", "services/verifier/out/reports.json", "flowmemory.verifier.persistence.v0"));
  }
  if (selectedSignal !== undefined) {
    sources.push(provenanceSource("indexer", "services/indexer/out/indexer-state.json", "flowmemory.indexer.persistence.v0"));
  }
  if (block !== undefined || transaction !== undefined) {
    const source = block?.source ?? transaction?.source;
    sources.push(source === "local-devnet"
      ? provenanceSource("devnet", "fixtures/launch-core/generated/devnet/state.json", "flowmemory.local_devnet.state.v0")
      : provenanceSource("indexer", "services/indexer/out/indexer-state.json", "flowmemory.indexer.persistence.v0"));
  }
  if (model !== undefined) {
    sources.push(model.source === "local-devnet"
      ? provenanceSource("devnet", "fixtures/launch-core/generated/devnet/state.json", "flowmemory.local_devnet.model_passport.v0")
      : provenanceSource("flowmemory", "fixtures/launch-core/flowmemory-launch-v0.json", "flowmemory.agent_memory_view.v0", "Projected model row."));
  }
  if (verifierModule !== undefined) {
    sources.push(verifierModule.source === "local-devnet"
      ? provenanceSource("devnet", "fixtures/launch-core/generated/devnet/state.json", "flowmemory.local_devnet.verifier_module.v0")
      : provenanceSource("verifier", "services/verifier/out/reports.json", "flowmemory.verifier.persistence.v0"));
  }
  if (artifactAvailability !== undefined) {
    sources.push(artifactAvailability.source === "verifier-fixture"
      ? provenanceSource("verifier", "services/verifier/fixtures/artifacts.json", "flowmemory.verifier.artifact_fixture.v0")
      : provenanceSource("devnet", "fixtures/launch-core/generated/devnet/state.json", "flowmemory.local_devnet.artifact_commitment.v0"));
  }
  if (token !== undefined || tokenBalance !== undefined || pool !== undefined || lpPosition !== undefined || swap !== undefined) {
    sources.push(provenanceSource("devnet", "devnet/local/state.json", "flowmemory.local_devnet.product_objects.v0", "Product rows are read from devnet state or control-plane handoff maps."));
  }

  links.receiptId = selectedReceipt?.receiptId;
  links.reportId = selectedReceipt?.reportId ?? report?.reportId;
  links.observationId = selectedReceipt?.observationId ?? report?.reportCore.observationId ?? selectedSignal?.observationId;
  links.signalId = selectedSignal?.signalId;
  links.transitionId = selectedTransition?.transitionId;
  links.rootfieldId = selectedReceipt?.rootfieldId ?? selectedSignal?.rootfieldId ?? bundle?.rootfieldId ?? view?.rootfieldId;
  links.blockHash = block?.blockHash ?? transaction?.blockHash;
  links.blockNumber = block?.blockNumber ?? transaction?.blockNumber;
  links.txHash = transaction?.txHash;
  links.modelId = model?.modelId;
  links.verifierModuleId = verifierModule?.moduleId;
  links.artifactAvailabilityId = artifactAvailability?.availabilityId;
  links.tokenId = token?.tokenId ?? tokenBalance?.tokenId ?? pool?.token0 ?? swap?.tokenIn;
  links.balanceId = tokenBalance?.balanceId;
  links.poolId = pool?.poolId ?? lpPosition?.poolId ?? swap?.poolId;
  links.lpPositionId = lpPosition?.positionId;
  links.swapId = swap?.swapId;
  links.artifactUris = report?.reportCore.evidenceRefs.map((entry) => entry.uri).filter((value): value is string => typeof value === "string")
    ?? (selectedReceipt?.evidenceRefs.map((entry) => entry.uri).filter((value): value is string => typeof value === "string") ?? []);

  if (sources.length === 0) {
    const devnetTarget = devnetWorkReceipts(state)[key]
      ?? devnetReports(state)[key]
      ?? devnetRootfields(state)[key]
      ?? devnetArtifacts(state)[key]
      ?? devnetAgentAccounts(state)[key]
      ?? devnetMemoryCells(state)[key]
      ?? devnetChallenges(state)[key]
      ?? devnetFinalityReceipts(state)[key]
      ?? tokenRows(state).find((candidate) => candidate.tokenId === key || candidate.symbol === key)
      ?? tokenBalanceRows(state).find((candidate) => candidate.balanceId === key || candidate.accountId === key)
      ?? poolRows(state).find((candidate) => candidate.poolId === key)
      ?? lpPositionRows(state).find((candidate) => candidate.positionId === key || candidate.accountId === key)
      ?? swapRows(state).find((candidate) => candidate.swapId === key || candidate.txId === key);
    if (devnetTarget !== undefined) {
      sources.push(provenanceSource("devnet", "fixtures/launch-core/generated/devnet/state.json", "flowmemory.local_devnet.state.v0"));
    }
  }

  return {
    schema: "flowmemory.control_plane.provenance.v0",
    objectId: key,
    sources,
    links,
    localOnly: true,
  };
}

function provenanceGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "provenance_get");
  const key = requiredString(objectParams, ["objectId", "uri", "receiptId", "reportId", "rootfieldId"], "provenance_get");

  if (optionalString(objectParams, "uri") !== undefined) {
    const uri = key;
    const artifact = state.artifacts.artifactsByUri[uri];
    if (artifact === undefined) {
      throw objectNotFound(`artifact provenance not found: ${uri}`, { uri });
    }
    return {
      schema: "flowmemory.control_plane.provenance.v0",
      objectId: uri,
      sources: [provenanceSource("verifier", "services/verifier/fixtures/artifacts.json", "flowmemory.verifier.artifact_fixture.v0")],
      links: {
        artifactUri: uri,
        receiptIds: state.launchCore.memoryReceipts
          .filter((receipt) => receipt.evidenceRefs.some((ref) => ref.uri === uri))
          .map((receipt) => receipt.receiptId),
      },
      localOnly: true,
    };
  }

  const provenance = provenanceForObject(state, key);
  if ((provenance.sources as JsonObject[]).length === 0) {
    throw objectNotFound(`provenance not found: ${key}`, { id: key });
  }
  return provenance;
}

function rawJsonGet(params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const objectParams = asObjectParams(params, "raw_json_get");
  const source = requiredString(objectParams, ["source"], "raw_json_get");
  const allowed: Record<string, JsonValue> = {
    launchCore: state.launchCore as unknown as JsonValue,
    indexer: state.indexer as unknown as JsonValue,
    verifier: state.verifier as unknown as JsonValue,
    artifacts: state.artifacts as unknown as JsonValue,
    devnet: state.devnet,
    devnetIndexerHandoff: state.devnetIndexerHandoff,
    devnetVerifierHandoff: state.devnetVerifierHandoff,
    devnetControlPlaneHandoff: state.devnetControlPlaneHandoff,
    txFixtures: state.txFixtures,
    txIntake: txIntakeRows(state) as unknown as JsonValue,
    bridgeObservations: bridgeObservationRows(state) as unknown as JsonValue,
    bridgeRuntimeHandoff: state.bridgeRuntimeHandoff,
  };

  if (!Object.prototype.hasOwnProperty.call(allowed, source)) {
    throw invalidParams("raw_json_get source is not allowed", {
      source,
      allowedSources: Object.keys(allowed),
    });
  }
  const raw = allowed[source];
  if (raw === null) {
    throw objectNotFound(`raw JSON source not loaded: ${source}`, { source });
  }

  return {
    schema: "flowmemory.control_plane.raw_json.v0",
    source,
    dataSource: state.sources[source],
    raw,
    localOnly: true,
  };
}

export const CONTROL_PLANE_METHODS: Record<ControlPlaneMethod, MethodHandler> = {
  health,
  node_status: nodeStatus,
  peer_list: peerList,
  chain_status: chainStatus,
  pilot_status: pilotStatus,
  pilot_deposit_observation_list: pilotDepositObservationList,
  pilot_credit_list: pilotCreditList,
  pilot_withdrawal_intent_list: pilotWithdrawalIntentList,
  pilot_release_evidence_list: pilotReleaseEvidenceList,
  pilot_cap_status: pilotCapStatus,
  pilot_pause_status: pilotPauseStatus,
  pilot_retry_status: pilotRetryStatus,
  pilot_emergency_status: pilotEmergencyStatus,
  devnet_state: devnetState,
  block_get: blockGet,
  block_list: blockList,
  mempool_list: mempoolList,
  transaction_get: transactionGet,
  transaction_list: transactionList,
  transaction_submit: transactionSubmit,
  account_get: accountGet,
  account_list: accountList,
  balance_get: balanceGet,
  token_get: tokenGet,
  token_list: tokenList,
  token_balance_get: tokenBalanceGet,
  token_balance_list: tokenBalanceList,
  pool_get: poolGet,
  pool_list: poolList,
  lp_position_get: lpPositionGet,
  lp_position_list: lpPositionList,
  swap_get: swapGet,
  swap_list: swapList,
  product_flow_status: productFlowStatus,
  faucet_event_list: faucetEventList,
  wallet_metadata_get: walletMetadataGet,
  wallet_metadata_list: walletMetadataList,
  rootfield_get: rootfieldGet,
  rootfield_list: rootfieldList,
  artifact_get: artifactGet,
  artifact_availability_get: artifactAvailabilityGet,
  artifact_availability_list: artifactAvailabilityList,
  receipt_get: receiptGet,
  receipt_list: receiptList,
  work_receipt_get: workReceiptGet,
  work_receipt_list: workReceiptList,
  verifier_module_get: verifierModuleGet,
  verifier_module_list: verifierModuleList,
  verifier_report_get: verifierReportGet,
  verifier_report_list: verifierReportList,
  memory_cell_get: memoryCellGet,
  memory_cell_list: memoryCellList,
  agent_get: agentGet,
  agent_list: agentList,
  model_get: modelGet,
  model_list: modelList,
  challenge_get: challengeGet,
  challenge_list: challengeList,
  finality_get: finalityGet,
  finality_list: finalityList,
  bridge_observation_get: bridgeObservationGet,
  bridge_observation_list: bridgeObservationList,
  bridge_observation_submit: bridgeObservationSubmit,
  bridge_deposit_get: bridgeDepositGet,
  bridge_deposit_list: bridgeDepositList,
  bridge_credit_get: bridgeCreditGet,
  bridge_credit_list: bridgeCreditList,
  withdrawal_get: withdrawalGet,
  withdrawal_list: withdrawalList,
  provenance_get: provenanceGet,
  raw_json_get: rawJsonGet,
};

export function callControlPlaneMethod(
  method: string,
  params: JsonValue | undefined,
  context: ControlPlaneContext = {},
): JsonValue {
  const handler = CONTROL_PLANE_METHODS[method as ControlPlaneMethod];
  if (handler === undefined) {
    throw methodNotFound(`control-plane method not found: ${method}`, { method });
  }
  return handler(params, context);
}
