import { canonicalJson, keccak256Hex } from "../../shared/src/index.ts";
import { invalidParams, methodNotFound, objectNotFound } from "./errors.ts";
import { loadControlPlaneState } from "./fixture-state.ts";
import type {
  ControlPlaneContext,
  ControlPlaneMethod,
  JsonObject,
  JsonValue,
  LoadedControlPlaneState,
} from "./types.ts";

const ZERO_ROOT = "0x0000000000000000000000000000000000000000000000000000000000000000";

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
  const value = state.devnet?.[key]
    ?? controlPlaneObjects?.[key]
    ?? state.devnetControlPlaneHandoff?.[key]
    ?? state.devnetVerifierHandoff?.[key]
    ?? state.devnetIndexerHandoff?.[key];
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value as Record<string, JsonValue> : {};
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
  const candidate = asJsonArray(state.devnet?.blocks).length > 0
    ? asJsonArray(state.devnet?.blocks)
    : asJsonArray(state.devnetControlPlaneHandoff?.blocks).length > 0
      ? asJsonArray(state.devnetControlPlaneHandoff?.blocks)
      : asJsonArray(state.devnetIndexerHandoff?.blocks);
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

function health(_params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const missing = Object.values(state.sources).filter((source) => source.status === "missing").map((source) => source.name);
  return {
    schema: "flowmemory.control_plane.health.v0",
    service: "flowmemory-control-plane-v0",
    status: missing.length === 0 ? "ok" : "degraded",
    localOnly: true,
    checks: {
      launchCore: state.sources.launchCore.status,
      indexer: state.sources.indexer.status,
      verifier: state.sources.verifier.status,
      artifacts: state.sources.artifacts.status,
      devnet: state.sources.devnet.status,
      devnetControlPlaneHandoff: state.sources.devnetControlPlaneHandoff.status,
      txFixtures: state.sources.txFixtures.status,
    },
    counts: {
      observations: state.indexer.state.observations.length,
      verifierReports: state.verifier.reports.length,
      rootfields: rootfieldRows(state).length,
      blocks: blockRows(state).length,
      transactions: transactionRows(state).length,
    },
    missingOptionalSources: missing,
  };
}

function chainStatus(_params: JsonValue | undefined, context: ControlPlaneContext): JsonValue {
  const state = stateFor(context);
  const latest = latestBlock(state);

  return {
    schema: "flowmemory.control_plane.chain_status.v0",
    chainId: "flowmemory-local-alpha",
    settlementContext: "local fixture stack over FlowPulse and local no-value devnet handoff",
    environment: "local-devnet-fixture",
    source: "fixture",
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
      devnetBlocks: devnetBlocksArray(state).length,
    },
    capabilities: [
      "health_reads",
      "fixture_status_reads",
      "block_reads",
      "transaction_reads",
      "receipt_lookup",
      "verifier_report_lookup",
      "memory_lineage_lookup",
      "artifact_fixture_lookup",
      "devnet_handoff_reads",
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
      ?? devnetFinalityReceipts(state)[key];
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
  chain_status: chainStatus,
  devnet_state: devnetState,
  block_get: blockGet,
  block_list: blockList,
  transaction_get: transactionGet,
  transaction_list: transactionList,
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
