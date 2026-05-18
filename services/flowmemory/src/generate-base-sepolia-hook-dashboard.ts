import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { canonicalJson, keccak256Hex } from "../../shared/src/index.ts";
import { observationLifecycleToFlowMemoryStatus, type FlowMemoryStatus } from "./status.ts";
import type {
  FlowPulseContractEvent,
  FlowPulseContractEventRef,
  FlowPulseContractTypeName,
  MemoryReceipt,
  MemorySignal,
  RootflowTransition,
} from "./types.ts";

const ZERO_ROOT = "0x0000000000000000000000000000000000000000000000000000000000000000";
const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const BASE_SEPOLIA_CHAIN_ID = "84532";
const FLOWPULSE_EVENT_SIGNATURE_TEXT =
  "FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string)";
const FLOWPULSE_EVENT_TOPIC0 = keccak256Hex(new TextEncoder().encode(FLOWPULSE_EVENT_SIGNATURE_TEXT));
const FLOWPULSE_CONTRACT_TYPE_NAMES: Record<string, FlowPulseContractTypeName> = {
  "1": "ROOTFIELD_REGISTERED",
  "2": "ROOT_COMMITTED",
  "3": "ROOTFIELD_STATUS_CHANGED",
  "4": "SWAP_MEMORY_SIGNAL",
};

type JsonObject = Record<string, unknown>;

interface IndexedObservation {
  observationId: string;
  cursorId: string;
  lifecycleState: string;
  duplicateKind: string;
  chainId: string;
  emittingContract: string;
  eventSignature: string;
  blockNumber: string;
  blockHash: string;
  txHash: string;
  transactionIndex: string;
  logIndex: string;
  receiptStatus: string;
  pulseId: string;
  rootfieldId: string;
  actor: string;
  pulseType: string;
  subject: string;
  commitment: string;
  parentPulseId: string;
  sequence: string;
  occurredAt: string;
  uri: string;
}

interface IndexerPersistence {
  schema: "flowmemory.indexer.persistence.v0";
  state: {
    source: "base-sepolia-rpc";
    observations: IndexedObservation[];
    rootfields: Array<{
      rootfieldId: string;
      firstObservationId: string;
      latestObservationId: string;
      pulseCount: number;
    }>;
    rejectedLogs: unknown[];
    duplicates: unknown[];
    dashboardFeed?: {
      hasIntegrityWarnings?: boolean;
      warningCodes?: string[];
      dashboardCanonicalObservationCount?: number;
    };
  };
}

interface BaseSepoliaCheckpoint {
  schema: "flowmemory.indexer.base_sepolia_checkpoint.v0";
  network: "base-sepolia";
  chainId: "84532";
  addresses: string[];
  fromBlock: string;
  toBlock: string;
  observationCount: number;
  rejectedLogCount: number;
  duplicateCount: number;
  emptyRange: boolean;
  generatedAt: string;
  highestObservedBlock: string | null;
  lastIndexedBlock: string;
  nextFromBlock: string;
  finalizedBlockNumber?: string;
  dashboardFeed?: {
    hasIntegrityWarnings?: boolean;
  };
  safety: {
    networkBoundary: "base-sepolia-testnet-only";
    productionReady: false;
    storesPrivateKeys: false;
    storesRpcUrl: false;
  };
}

interface HookPlan {
  schema: "flowmemory.base_sepolia.v4_hook_proof_plan.v0";
  generatedAt: string;
  productionReady: false;
  network: {
    name: "Base Sepolia";
    chainId: "84532";
    explorer: string;
  };
  uniswapV4: JsonObject;
  hook: HookDetails;
  commands: JsonObject;
  proofSequence: string[];
  boundaries: string[];
}

interface HookEvidence {
  schema: "flowmemory.base_sepolia.v4_hook_evidence.v0";
  generatedAt: string;
  productionReady: false;
  liveProofComplete: boolean;
  stage: string;
  hook: HookDetails;
  evidence: {
    officialContractsCodePresent: boolean;
    plannedHookCodePresent: boolean;
    envBroadcastReady: boolean;
    dryRunProofReady: boolean;
    broadcastProofReady: boolean;
    readbackProofReady: boolean;
    readbackObservationCount: number;
    readbackProofComplete: boolean;
    dryRunTransactionCount: number;
    broadcastReceiptCount: number;
  };
  missing: string[];
  nextSteps: string[];
  boundaries: string[];
}

interface HookReadbackArtifact {
  schema: "flowmemory.base_sepolia.v4_hook_readback_artifact.v0";
  generatedAt: string;
  productionReady: false;
  proofComplete: boolean;
  hook: HookDetails;
  indexer: {
    observationCount: number;
    rejectedLogCount: number;
    duplicateCount: number;
    dashboardCanonicalObservationCount: number;
    fromBlock: string;
    toBlock: string;
    finalizedBlock: string | null;
    emptyRange: boolean;
    hasIntegrityWarnings: boolean;
  };
  boundaries: string[];
}

interface HookDetails {
  contract: "FlowMemoryAfterSwapHook";
  create2Deployer: string;
  constructorArgs: {
    poolManager: string;
  };
  initCodeHash: string;
  salt: string;
  hookAddress: string;
  miningMode: string;
  requiredLowBits: "0x0040";
  hasAfterSwapOnlyFlag: boolean;
  permissions: {
    afterSwap: true;
    beforeSwap: false;
    afterSwapReturnDelta: false;
    dynamicFeeOverride: false;
    custody: false;
  };
}

export interface BaseSepoliaHookDashboardPaths {
  planPath: string;
  evidencePath: string;
  readbackArtifactPath: string;
  indexerPath: string;
  checkpointPath: string;
  flowMemoryOutPath: string;
  dashboardOutPath: string;
  dashboardRuntimePath: string;
}

export interface BaseSepoliaHookDashboardOptions {
  allowIncomplete?: boolean;
}

export interface BaseSepoliaHookEvidenceOutput {
  schema: "flowmemory.base_sepolia.v4_hook_flowmemory_evidence.v0";
  generatedAt: string;
  mode: "base-sepolia-v4-hook-proof";
  productionReady: false;
  liveProofComplete: boolean;
  stage: string;
  sourcePaths: Record<string, string>;
  hook: HookDetails;
  checks: JsonObject;
  memorySignals: MemorySignal[];
  memoryReceipts: MemoryReceipt[];
  rootflowTransitions: RootflowTransition[];
  rootfieldBundles: JsonObject[];
  agentMemoryViews: JsonObject[];
  acceptance: JsonObject;
  boundaries: string[];
}

export interface BaseSepoliaHookDashboardData {
  metadata: JsonObject;
  chain: JsonObject;
  flowPulseObservations: JsonObject[];
  rootfields: JsonObject[];
  workLanes: JsonObject[];
  workReceipts: JsonObject[];
  verifierReports: JsonObject[];
  rootflowTransitions: JsonObject[];
  memorySignals: JsonObject[];
  memoryReceipts: JsonObject[];
  rootfieldBundles: JsonObject[];
  agentMemoryViews: JsonObject[];
  devnetBlocks: JsonObject[];
  hardwareNodes: JsonObject[];
  alerts: JsonObject[];
}

export const DEFAULT_BASE_SEPOLIA_HOOK_DASHBOARD_PATHS: BaseSepoliaHookDashboardPaths = {
  planPath: "fixtures/deployments/base-sepolia-v4-hook-proof-plan.json",
  evidencePath: "fixtures/deployments/base-sepolia-v4-hook-evidence.latest.json",
  readbackArtifactPath: "fixtures/deployments/base-sepolia-v4-hook-readback.latest.json",
  indexerPath: "fixtures/deployments/base-sepolia-v4-hook-readback-state.latest.json",
  checkpointPath: "fixtures/deployments/base-sepolia-v4-hook-readback-checkpoint.latest.json",
  flowMemoryOutPath: "fixtures/deployments/base-sepolia-v4-hook-flowmemory.latest.json",
  dashboardOutPath: "fixtures/dashboard/flowmemory-dashboard-base-sepolia-v4-hook.json",
  dashboardRuntimePath: "apps/dashboard/public/data/flowmemory-dashboard-base-sepolia-v4-hook.json",
};

function readJson<T>(path: string): T {
  return JSON.parse(readFileSync(path, "utf8")) as T;
}

function writeJson(path: string, value: unknown): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}

function stableId(schema: string, value: unknown): string {
  return keccak256Hex(new TextEncoder().encode(canonicalJson({ schema, value } as JsonObject)));
}

function sameAddress(left: string | undefined, right: string | undefined): boolean {
  return typeof left === "string" && typeof right === "string" && left.toLowerCase() === right.toLowerCase();
}

function requireSameAddress(label: string, left: string | undefined, right: string | undefined): void {
  if (!sameAddress(left, right)) {
    throw new Error(`${label} address mismatch: ${left ?? "<missing>"} != ${right ?? "<missing>"}`);
  }
}

function isoFromUnixSeconds(value: string, fallback: string): string {
  const seconds = Number(value);
  if (!Number.isFinite(seconds)) {
    return fallback;
  }
  return new Date(seconds * 1000).toISOString();
}

function pulseTypeName(pulseType: string): MemorySignal["signalType"] {
  if (pulseType === "1") return "rootfield_registration";
  if (pulseType === "2") return "root_commitment";
  if (pulseType === "4") return "swap_memory_signal";
  return "unsupported_pulse";
}

function contractPulseTypeName(pulseType: string): FlowPulseContractTypeName {
  return FLOWPULSE_CONTRACT_TYPE_NAMES[pulseType] ?? "UNKNOWN_FLOWPULSE_TYPE";
}

function sortObservations(observations: IndexedObservation[]): IndexedObservation[] {
  return [...observations].sort((left, right) => {
    const block = BigInt(left.blockNumber) - BigInt(right.blockNumber);
    if (block !== 0n) return block < 0n ? -1 : 1;
    const tx = BigInt(left.transactionIndex) - BigInt(right.transactionIndex);
    if (tx !== 0n) return tx < 0n ? -1 : 1;
    const log = BigInt(left.logIndex) - BigInt(right.logIndex);
    if (log !== 0n) return log < 0n ? -1 : 1;
    return left.observationId.localeCompare(right.observationId);
  });
}

function canonicalObservations(observations: IndexedObservation[]): IndexedObservation[] {
  return observations.filter((observation) => (
    observation.duplicateKind !== "exactDuplicate"
    && observationLifecycleToFlowMemoryStatus(observation.lifecycleState) !== "reorged"
  ));
}

function successfulSwapMemoryObservations(observations: IndexedObservation[]): IndexedObservation[] {
  return canonicalObservations(observations).filter((observation) => (
    observation.pulseType === "4"
    && observation.eventSignature.toLowerCase() === FLOWPULSE_EVENT_TOPIC0.toLowerCase()
    && observation.receiptStatus === "success"
  ));
}

function provenance(subsystem: string, localPathHint: string, generatedAt: string): JsonObject {
  return {
    subsystem,
    origin: "live-readback",
    chainContext: "base-sepolia-v4-hook-proof",
    fixturePath: "fixtures/deployments/base-sepolia-v4-hook-flowmemory.latest.json",
    capturedAt: generatedAt,
    localPathHint,
  };
}

function buildFlowPulseContractEvent(observation: IndexedObservation, generatedAt: string): FlowPulseContractEvent {
  return {
    schema: "flowmemory.flowpulse_contract_event.v0",
    interfaceName: "IFlowPulse",
    eventName: "FlowPulse",
    eventSignatureText: FLOWPULSE_EVENT_SIGNATURE_TEXT,
    eventTopic0: observation.eventSignature,
    expectedTopic0: FLOWPULSE_EVENT_TOPIC0,
    topicMatchesContract: observation.eventSignature.toLowerCase() === FLOWPULSE_EVENT_TOPIC0.toLowerCase(),
    sourceContract: observation.emittingContract,
    pulseTypeId: observation.pulseType,
    pulseTypeName: contractPulseTypeName(observation.pulseType),
    indexed: {
      pulseId: observation.pulseId,
      rootfieldId: observation.rootfieldId,
      actor: observation.actor,
    },
    payload: {
      subject: observation.subject,
      commitment: observation.commitment,
      parentPulseId: observation.parentPulseId,
      sequence: observation.sequence,
      occurredAt: isoFromUnixSeconds(observation.occurredAt, generatedAt),
      uri: observation.uri,
    },
    receiptLocator: {
      chainId: observation.chainId,
      blockNumber: observation.blockNumber,
      blockHash: observation.blockHash,
      txHash: observation.txHash,
      transactionIndex: observation.transactionIndex,
      logIndex: observation.logIndex,
      receiptStatus: observation.receiptStatus,
    },
    receiptDerivedFields: [
      "blockHash",
      "txHash",
      "transactionIndex",
      "logIndex",
      "receiptStatus",
    ],
  };
}

function buildContractEventRef(signal: MemorySignal): FlowPulseContractEventRef {
  return {
    signalId: signal.signalId,
    eventName: signal.contractEvent.eventName,
    eventTopic0: signal.contractEvent.eventTopic0,
    sourceContract: signal.contractEvent.sourceContract,
    pulseTypeId: signal.contractEvent.pulseTypeId,
    pulseTypeName: signal.contractEvent.pulseTypeName,
    txHash: signal.contractEvent.receiptLocator.txHash,
    logIndex: signal.contractEvent.receiptLocator.logIndex,
  };
}

function liveProofIsComplete(
  evidence: HookEvidence,
  readback: HookReadbackArtifact,
  checkpoint: BaseSepoliaCheckpoint,
  observations: IndexedObservation[],
): boolean {
  const canonical = canonicalObservations(observations);
  const swapMemorySignals = successfulSwapMemoryObservations(observations);

  return evidence.liveProofComplete === true
    && evidence.evidence.plannedHookCodePresent === true
    && evidence.evidence.broadcastProofReady === true
    && evidence.evidence.readbackProofReady === true
    && readback.proofComplete === true
    && checkpoint.observationCount > 0
    && observations.length > 0
    && canonical.length > 0
    && swapMemorySignals.length > 0
    && evidence.evidence.readbackObservationCount === observations.length
    && readback.indexer.observationCount === observations.length
    && checkpoint.observationCount === observations.length
    && readback.indexer.dashboardCanonicalObservationCount === canonical.length
    && checkpoint.emptyRange === false
    && readback.indexer.hasIntegrityWarnings === false
    && checkpoint.dashboardFeed?.hasIntegrityWarnings !== true;
}

function validateInputs(
  plan: HookPlan,
  evidence: HookEvidence,
  readback: HookReadbackArtifact,
  indexer: IndexerPersistence,
  checkpoint: BaseSepoliaCheckpoint,
  allowIncomplete: boolean,
): { observations: IndexedObservation[]; complete: boolean } {
  if (plan.productionReady !== false || evidence.productionReady !== false || readback.productionReady !== false) {
    throw new Error("Base Sepolia hook dashboard refuses production-ready artifacts");
  }
  if (indexer.state.source !== "base-sepolia-rpc") {
    throw new Error(`expected base-sepolia-rpc indexer source, received ${indexer.state.source}`);
  }
  if (plan.network.chainId !== BASE_SEPOLIA_CHAIN_ID || checkpoint.chainId !== BASE_SEPOLIA_CHAIN_ID) {
    throw new Error("Base Sepolia hook dashboard only accepts chain id 84532 artifacts");
  }

  requireSameAddress("evidence hook", evidence.hook.hookAddress, plan.hook.hookAddress);
  requireSameAddress("readback hook", readback.hook.hookAddress, plan.hook.hookAddress);
  if (evidence.hook.salt !== plan.hook.salt || readback.hook.salt !== plan.hook.salt) {
    throw new Error("Base Sepolia hook salt mismatch across plan, evidence, and readback artifacts");
  }
  if (!checkpoint.addresses.some((address) => sameAddress(address, plan.hook.hookAddress))) {
    throw new Error(`checkpoint does not include planned hook address ${plan.hook.hookAddress}`);
  }

  const observations = sortObservations(indexer.state.observations);
  const canonical = canonicalObservations(observations);
  const swapMemorySignals = successfulSwapMemoryObservations(observations);
  for (const observation of observations) {
    if (observation.chainId !== BASE_SEPOLIA_CHAIN_ID) {
      throw new Error(`observation ${observation.observationId} has wrong chain id ${observation.chainId}`);
    }
    requireSameAddress(`observation ${observation.observationId}`, observation.emittingContract, plan.hook.hookAddress);
    if (observation.eventSignature.toLowerCase() !== FLOWPULSE_EVENT_TOPIC0.toLowerCase()) {
      throw new Error(`observation ${observation.observationId} is not an IFlowPulse.FlowPulse event`);
    }
    if (observation.receiptStatus !== "success") {
      throw new Error(`observation ${observation.observationId} does not have a successful receipt`);
    }
  }

  if (readback.indexer.observationCount !== observations.length) {
    throw new Error(`readback observation count mismatch: ${readback.indexer.observationCount} != ${observations.length}`);
  }
  if (checkpoint.observationCount !== observations.length) {
    throw new Error(`checkpoint observation count mismatch: ${checkpoint.observationCount} != ${observations.length}`);
  }
  if (evidence.evidence.readbackObservationCount !== observations.length) {
    throw new Error(
      `evidence readback observation count mismatch: ${evidence.evidence.readbackObservationCount} != ${observations.length}`,
    );
  }
  if (readback.indexer.dashboardCanonicalObservationCount !== canonical.length) {
    throw new Error(
      `readback canonical observation count mismatch: ${readback.indexer.dashboardCanonicalObservationCount} != ${canonical.length}`,
    );
  }
  if (!allowIncomplete && evidence.liveProofComplete === true && swapMemorySignals.length === 0) {
    throw new Error("Base Sepolia v4 hook proof requires at least one unique successful SWAP_MEMORY_SIGNAL observation");
  }

  const complete = liveProofIsComplete(evidence, readback, checkpoint, observations);
  if (!allowIncomplete && !complete) {
    const missing = evidence.missing.length > 0 ? evidence.missing.join("; ") : "live hook readback evidence";
    throw new Error(`Base Sepolia v4 hook Flow Memory evidence is incomplete: ${missing}`);
  }

  return { observations, complete };
}

function buildMemorySignal(
  observation: IndexedObservation,
  status: FlowMemoryStatus,
  generatedAt: string,
): MemorySignal {
  const signalCore = {
    observationId: observation.observationId,
    pulseId: observation.pulseId,
    rootfieldId: observation.rootfieldId,
    pulseType: observation.pulseType,
    sequence: observation.sequence,
  };

  return {
    schema: "flowmemory.memory_signal.v0",
    signalId: stableId("flowmemory.base_sepolia.v4_hook.memory_signal.v0", signalCore),
    observationId: observation.observationId,
    pulseId: observation.pulseId,
    rootfieldId: observation.rootfieldId,
    signalType: pulseTypeName(observation.pulseType),
    status,
    chainId: observation.chainId,
    emittingContract: observation.emittingContract,
    blockNumber: observation.blockNumber,
    blockHash: observation.blockHash,
    txHash: observation.txHash,
    transactionIndex: observation.transactionIndex,
    logIndex: observation.logIndex,
    actor: observation.actor,
    subject: observation.subject,
    commitment: observation.commitment,
    parentPulseId: observation.parentPulseId,
    sequence: observation.sequence,
    occurredAt: isoFromUnixSeconds(observation.occurredAt, generatedAt),
    uri: observation.uri,
    summary: `Base Sepolia ${pulseTypeName(observation.pulseType).replaceAll("_", " ")} from the mined Uniswap v4 hook`,
    contractEvent: buildFlowPulseContractEvent(observation, generatedAt),
  };
}

function buildMemoryReceipt(
  signal: MemorySignal,
  evidence: HookEvidence,
  readback: HookReadbackArtifact,
  complete: boolean,
): MemoryReceipt {
  const checks = [
    evidence.evidence.officialContractsCodePresent,
    evidence.evidence.plannedHookCodePresent,
    evidence.evidence.broadcastProofReady,
    evidence.evidence.readbackProofReady,
    readback.proofComplete,
  ];
  const verifierStatus = complete ? "valid" : "unresolved";
  const flowMemoryStatus: FlowMemoryStatus = complete ? "verified" : "unresolved";
  const reasonCodes = complete
    ? ["base_sepolia_v4_hook.live_poolmanager_swap_observed"]
    : [
      "base_sepolia_v4_hook.live_proof_incomplete",
      ...evidence.missing.map((missing) => `missing:${missing}`),
    ];

  return {
    schema: "flowmemory.memory_receipt.v0",
    receiptId: stableId("flowmemory.base_sepolia.v4_hook.memory_receipt.v0", {
      signalId: signal.signalId,
      stage: evidence.stage,
      txHash: signal.txHash,
      logIndex: signal.logIndex,
    }),
    reportId: stableId("flowmemory.base_sepolia.v4_hook.verifier_report.v0", {
      signalId: signal.signalId,
      evidenceStage: evidence.stage,
    }),
    reportDigest: stableId("flowmemory.base_sepolia.v4_hook.report_digest.v0", {
      signalId: signal.signalId,
      evidence: evidence.evidence,
      readback: readback.indexer,
    }),
    observationId: signal.observationId,
    rootfieldId: signal.rootfieldId,
    verifierStatus,
    flowMemoryStatus,
    resolverPolicyId: "base-sepolia-v4-hook-live-proof-v0",
    verifierSpecVersion: "flowmemory-base-sepolia-v4-hook-proof-v0",
    checksPassed: checks.filter(Boolean).length,
    checksTotal: checks.length,
    reasonCodes,
    evidenceRefs: [
      { kind: "hook-evidence", uri: "fixtures/deployments/base-sepolia-v4-hook-evidence.latest.json" },
      { kind: "hook-readback", uri: "fixtures/deployments/base-sepolia-v4-hook-readback.latest.json" },
      { kind: "indexer-state", uri: "fixtures/deployments/base-sepolia-v4-hook-readback-state.latest.json" },
    ],
  };
}

function buildOutputs(
  plan: HookPlan,
  evidence: HookEvidence,
  readback: HookReadbackArtifact,
  indexer: IndexerPersistence,
  checkpoint: BaseSepoliaCheckpoint,
  paths: BaseSepoliaHookDashboardPaths,
  allowIncomplete: boolean,
): {
  flowMemory: BaseSepoliaHookEvidenceOutput;
  dashboard: BaseSepoliaHookDashboardData;
} {
  const { observations, complete } = validateInputs(plan, evidence, readback, indexer, checkpoint, allowIncomplete);
  const generatedAt = checkpoint.generatedAt ?? evidence.generatedAt;
  const status: FlowMemoryStatus = complete ? "verified" : observations.length > 0 ? "pending" : "unresolved";
  const memorySignals = observations.map((observation) => buildMemorySignal(observation, status, generatedAt));
  const memoryReceipts = memorySignals.map((signal) => buildMemoryReceipt(signal, evidence, readback, complete));
  const signalByObservation = new Map(memorySignals.map((signal) => [signal.observationId, signal]));
  const receiptByObservation = new Map(memoryReceipts.map((receipt) => [receipt.observationId, receipt]));
  const currentRootByRootfield = new Map<string, string>();
  const latestTransitionByPulse = new Map<string, string>();
  const rootflowTransitions: RootflowTransition[] = [];

  for (const observation of observations) {
    if (observation.duplicateKind === "exactDuplicate") continue;
    const signal = signalByObservation.get(observation.observationId);
    const receipt = receiptByObservation.get(observation.observationId);
    if (!signal || !receipt) {
      throw new Error(`missing Flow Memory object for ${observation.observationId}`);
    }

    const previousRoot = currentRootByRootfield.get(observation.rootfieldId) ?? ZERO_ROOT;
    const attemptedRoot = observation.pulseType === "4" ? observation.commitment : observation.subject;
    const nextRoot = complete ? attemptedRoot : previousRoot;
    const transitionStatusValue = observationLifecycleToFlowMemoryStatus(observation.lifecycleState) === "reorged"
      ? "reorged"
      : receipt.flowMemoryStatus;
    const transitionCore = {
      rootfieldId: observation.rootfieldId,
      pulseId: observation.pulseId,
      previousRoot,
      attemptedRoot,
      nextRoot,
      status: transitionStatusValue,
      txHash: observation.txHash,
      logIndex: observation.logIndex,
    };
    const transition: RootflowTransition = {
      schema: "flowmemory.rootflow_transition.v0",
      transitionId: stableId("flowmemory.base_sepolia.v4_hook.rootflow_transition.v0", transitionCore),
      rootfieldId: observation.rootfieldId,
      observationId: observation.observationId,
      pulseId: observation.pulseId,
      parentPulseId: observation.parentPulseId,
      parentTransitionId: latestTransitionByPulse.get(observation.parentPulseId) ?? null,
      memorySignalId: signal.signalId,
      memoryReceiptId: receipt.receiptId,
      reportId: receipt.reportId,
      previousRoot,
      attemptedRoot,
      nextRoot,
      status: transitionStatusValue,
      blockNumber: observation.blockNumber,
      txHash: observation.txHash,
      sequence: observation.sequence,
      reasonCodes: receipt.reasonCodes,
      contractEventRef: buildContractEventRef(signal),
    };

    rootflowTransitions.push(transition);
    latestTransitionByPulse.set(observation.pulseId, transition.transitionId);
    if (nextRoot !== previousRoot) {
      currentRootByRootfield.set(observation.rootfieldId, nextRoot);
    }
  }

  const rootfieldIds = [
    ...new Set([
      ...indexer.state.rootfields.map((rootfield) => rootfield.rootfieldId),
      ...observations.map((observation) => observation.rootfieldId),
    ]),
  ].sort();
  const rootfieldBundles = rootfieldIds.map((rootfieldId) => {
    const signals = memorySignals.filter((signal) => signal.rootfieldId === rootfieldId);
    const receipts = memoryReceipts.filter((receipt) => receipt.rootfieldId === rootfieldId);
    const transitions = rootflowTransitions.filter((transition) => transition.rootfieldId === rootfieldId);
    const latestTransition = transitions.at(-1) ?? null;
    const latestRoot = currentRootByRootfield.get(rootfieldId) ?? ZERO_ROOT;
    const counts = {
      observations: signals.length,
      transitions: transitions.length,
      receipts: receipts.length,
      verified: transitions.filter((transition) => transition.status === "verified").length,
      failed: transitions.filter((transition) => transition.status === "failed").length,
      unresolved: transitions.filter((transition) => transition.status === "unresolved").length,
      unsupported: transitions.filter((transition) => transition.status === "unsupported").length,
      reorged: transitions.filter((transition) => transition.status === "reorged").length,
    };
    const bundleCore = {
      rootfieldId,
      latestRoot,
      latestTransitionId: latestTransition?.transitionId ?? null,
      status: latestTransition?.status ?? status,
      counts,
    };

    return {
      schema: "flowmemory.rootfield_bundle.v0",
      id: stableId("flowmemory.base_sepolia.v4_hook.rootfield_bundle.v0", bundleCore),
      bundleId: stableId("flowmemory.base_sepolia.v4_hook.rootfield_bundle.v0", bundleCore),
      rootfieldId,
      latestRoot,
      latestTransitionId: latestTransition?.transitionId ?? null,
      status: latestTransition?.status ?? status,
      transitionIds: transitions.map((transition) => transition.transitionId),
      memorySignalIds: signals.map((signal) => signal.signalId),
      memoryReceiptIds: receipts.map((receipt) => receipt.receiptId),
      verifierReportIds: receipts.map((receipt) => receipt.reportId),
      counts,
      lastUpdated: generatedAt,
      provenance: provenance("flowmemory", paths.flowMemoryOutPath, generatedAt),
    };
  });
  const agentMemoryViews = rootfieldBundles.map((bundle) => ({
    schema: "flowmemory.agent_memory_view.v0",
    id: stableId("flowmemory.base_sepolia.v4_hook.agent_memory_view.v0", bundle.bundleId),
    viewId: stableId("flowmemory.base_sepolia.v4_hook.agent_memory_view.v0", bundle.bundleId),
    rootfieldId: bundle.rootfieldId,
    status: bundle.status,
    latestRoot: bundle.latestRoot,
    latestTransitionId: bundle.latestTransitionId,
    signalIds: bundle.memorySignalIds,
    receiptIds: bundle.memoryReceiptIds,
    transitionIds: bundle.transitionIds,
    warnings: [
      "Base Sepolia evidence is public-testnet proof, not production mainnet readiness.",
      "This proves hook/readback mechanics only after liveProofComplete is true.",
      ...(!complete ? ["Live PoolManager swap/readback proof is not complete yet."] : []),
    ],
    localOnly: true,
    lastUpdated: generatedAt,
    provenance: provenance("flowmemory", paths.flowMemoryOutPath, generatedAt),
  }));

  const checks = {
    planEvidenceHookMatch: sameAddress(plan.hook.hookAddress, evidence.hook.hookAddress),
    planReadbackHookMatch: sameAddress(plan.hook.hookAddress, readback.hook.hookAddress),
    checkpointIncludesHookAddress: checkpoint.addresses.some((address) => sameAddress(address, plan.hook.hookAddress)),
    observationCount: observations.length,
    canonicalObservationCount: canonicalObservations(observations).length,
    swapMemorySignalObservationCount: successfulSwapMemoryObservations(observations).length,
    allObservationsFromHook: observations.every((observation) => sameAddress(observation.emittingContract, plan.hook.hookAddress)),
    allObservationsBaseSepolia: observations.every((observation) => observation.chainId === BASE_SEPOLIA_CHAIN_ID),
    allObservationsFlowPulse: observations.every((observation) => observation.eventSignature.toLowerCase() === FLOWPULSE_EVENT_TOPIC0.toLowerCase()),
    allObservationsReceiptSuccess: observations.every((observation) => observation.receiptStatus === "success"),
    liveProofComplete: complete,
    allowIncomplete,
  };
  const flowMemory: BaseSepoliaHookEvidenceOutput = {
    schema: "flowmemory.base_sepolia.v4_hook_flowmemory_evidence.v0",
    generatedAt,
    mode: "base-sepolia-v4-hook-proof",
    productionReady: false,
    liveProofComplete: complete,
    stage: evidence.stage,
    sourcePaths: {
      plan: paths.planPath,
      evidence: paths.evidencePath,
      readbackArtifact: paths.readbackArtifactPath,
      indexer: paths.indexerPath,
      checkpoint: paths.checkpointPath,
    },
    hook: plan.hook,
    checks,
    memorySignals,
    memoryReceipts,
    rootflowTransitions,
    rootfieldBundles,
    agentMemoryViews,
    acceptance: {
      network: "base-sepolia",
      chainId: BASE_SEPOLIA_CHAIN_ID,
      livePoolManagerSwapObserved: complete,
      flowPulseObservations: observations.length,
      memorySignals: memorySignals.length,
      memoryReceipts: memoryReceipts.length,
      rootflowTransitions: rootflowTransitions.length,
      dashboardFixtureGenerated: true,
      productionReady: false,
    },
    boundaries: [
      ...new Set([
        ...plan.boundaries,
        ...evidence.boundaries,
        ...readback.boundaries,
        "Flow Memory evidence is derived from receipt/log readback; the hook does not know txHash or logIndex during execution.",
      ]),
    ],
  };

  const rootfields = rootfieldBundles.map((bundle) => {
    const firstSignal = memorySignals.find((signal) => signal.rootfieldId === bundle.rootfieldId);
    return {
      id: bundle.bundleId,
      rootfieldId: bundle.rootfieldId,
      owner: firstSignal?.actor ?? ZERO_ROOT,
      schemaHash: stableId("flowmemory.base_sepolia.v4_hook.rootfield.schema_hash.v0", bundle.rootfieldId),
      metadataHash: stableId("flowmemory.base_sepolia.v4_hook.rootfield.metadata_hash.v0", bundle.rootfieldId),
      latestRoot: bundle.latestRoot,
      latestObservationId: firstSignal?.observationId ?? null,
      pulseCount: bundle.counts.observations,
      workLaneIds: ["MEMORY_REFRESH", "STEERING_VALIDATION"],
      evidenceUri: paths.flowMemoryOutPath,
      status: bundle.status,
      lastUpdated: generatedAt,
      provenance: provenance("flowmemory", paths.flowMemoryOutPath, generatedAt),
    };
  });
  const verifierReports = memoryReceipts.map((receipt) => ({
    id: receipt.reportId,
    reportId: receipt.reportId,
    observationId: receipt.observationId,
    rootfieldId: receipt.rootfieldId,
    resolverPolicyId: receipt.resolverPolicyId,
    verifierSpecVersion: receipt.verifierSpecVersion,
    checksPassed: receipt.checksPassed,
    checksTotal: receipt.checksTotal,
    reasonCodes: receipt.reasonCodes,
    reportHash: receipt.reportDigest,
    status: receipt.flowMemoryStatus,
    lastUpdated: generatedAt,
    provenance: provenance("verifier", paths.evidencePath, generatedAt),
  }));
  const alertIdSeed = {
    stage: evidence.stage,
    hookAddress: plan.hook.hookAddress,
    observationCount: observations.length,
    complete,
  };
  const dashboard: BaseSepoliaHookDashboardData = {
    metadata: {
      schema: "flowmemory.dashboard.fixture.v0",
      generatedAt,
      mode: "base-sepolia-v4-hook-proof",
      description:
        "Generated Base Sepolia v4 hook proof dashboard data from readback artifacts. It is public-testnet evidence and not production mainnet readiness.",
      fixturePath: paths.dashboardOutPath,
      runtimeDataPath: paths.dashboardRuntimePath,
      baseSepoliaHookProof: {
        liveProofComplete: complete,
        stage: evidence.stage,
        plannedHookAddress: plan.hook.hookAddress,
        readWindow: {
          fromBlock: checkpoint.fromBlock,
          toBlock: checkpoint.toBlock,
          finalizedBlock: checkpoint.finalizedBlockNumber ?? readback.indexer.finalizedBlock,
        },
        counts: {
          observations: observations.length,
          canonicalObservations: canonicalObservations(observations).length,
          swapMemorySignals: successfulSwapMemoryObservations(observations).length,
          rejectedLogs: checkpoint.rejectedLogCount,
          duplicates: checkpoint.duplicateCount,
          memorySignals: memorySignals.length,
          rootflowTransitions: rootflowTransitions.length,
        },
        missing: evidence.missing,
        nextSteps: evidence.nextSteps,
      },
      futureGeneratedPaths: {
        indexer: paths.indexerPath,
        evidence: paths.evidencePath,
        readback: paths.readbackArtifactPath,
      },
    },
    chain: {
      chainId: BASE_SEPOLIA_CHAIN_ID,
      name: "Base Sepolia v4 hook proof",
      environment: "public-testnet",
      settlementContext:
        "Mined Uniswap v4 afterSwap hook proof path. Complete only after real PoolManager swap broadcast and non-empty readback.",
      currentBlock: Number(checkpoint.toBlock),
      finalizedBlock: Number(checkpoint.finalizedBlockNumber ?? checkpoint.lastIndexedBlock),
      source: observations.length > 0 ? "live-rpc-readback" : "diagnostic-empty-readback",
      lastUpdated: generatedAt,
    },
    flowPulseObservations: observations.map((observation) => ({
      id: observation.observationId,
      observationId: observation.observationId,
      pulseId: observation.pulseId,
      rootfieldId: observation.rootfieldId,
      eventSignature: observation.eventSignature,
      blockNumber: observation.blockNumber,
      blockHash: observation.blockHash,
      txHash: observation.txHash,
      transactionIndex: observation.transactionIndex,
      logIndex: observation.logIndex,
      receiptStatus: observation.receiptStatus,
      actor: observation.actor,
      pulseType: observation.pulseType,
      subject: observation.subject,
      commitment: observation.commitment,
      parentPulseId: observation.parentPulseId,
      sequence: observation.sequence,
      occurredAt: isoFromUnixSeconds(observation.occurredAt, generatedAt),
      uri: observation.uri,
      summary: "FlowPulse read from the mined Base Sepolia Uniswap v4 hook address.",
      status,
      lastUpdated: generatedAt,
      provenance: provenance("indexer", paths.indexerPath, generatedAt),
    })),
    rootfields,
    workLanes: [{
      id: "MEMORY_REFRESH",
      laneId: "MEMORY_REFRESH",
      name: "Swap memory proof",
      queueDepth: complete ? 0 : Math.max(1, observations.length),
      inflight: complete ? 0 : observations.length,
      completed24h: complete ? observations.length : 0,
      p95LatencyMs: null,
      operator: "base-sepolia-hook-proof",
      status,
      lastUpdated: generatedAt,
      provenance: provenance("flowmemory", paths.flowMemoryOutPath, generatedAt),
    }],
    workReceipts: memoryReceipts.map((receipt) => ({
      id: receipt.receiptId,
      receiptId: receipt.receiptId,
      laneId: "MEMORY_REFRESH",
      rootfieldId: receipt.rootfieldId,
      observationId: receipt.observationId,
      reportId: receipt.reportId,
      workType: "BASE_SEPOLIA_V4_HOOK_READBACK_TO_MEMORY_RECEIPT",
      artifactUri: paths.readbackArtifactPath,
      startedAt: generatedAt,
      completedAt: complete ? generatedAt : undefined,
      resultHash: receipt.reportDigest,
      status: receipt.flowMemoryStatus,
      lastUpdated: generatedAt,
      provenance: provenance("verifier", paths.evidencePath, generatedAt),
    })),
    verifierReports,
    rootflowTransitions: rootflowTransitions.map((transition) => ({
      ...transition,
      id: transition.transitionId,
      lastUpdated: generatedAt,
      provenance: provenance("flowmemory", paths.flowMemoryOutPath, generatedAt),
    })),
    memorySignals: memorySignals.map((signal) => ({
      ...signal,
      id: signal.signalId,
      lastUpdated: generatedAt,
      provenance: provenance("indexer", paths.indexerPath, generatedAt),
    })),
    memoryReceipts: memoryReceipts.map((receipt) => ({
      ...receipt,
      id: receipt.receiptId,
      status: receipt.flowMemoryStatus,
      lastUpdated: generatedAt,
      provenance: provenance("verifier", paths.evidencePath, generatedAt),
    })),
    rootfieldBundles,
    agentMemoryViews,
    devnetBlocks: [],
    hardwareNodes: [],
    alerts: [{
      id: stableId("flowmemory.base_sepolia.v4_hook.alert.v0", alertIdSeed),
      incidentId: stableId("flowmemory.base_sepolia.v4_hook.alert.v0", alertIdSeed),
      severity: complete ? "info" : "warning",
      title: complete ? "Base Sepolia hook proof complete" : "Base Sepolia hook proof incomplete",
      summary: complete
        ? "A real Base Sepolia PoolManager swap was read back from the mined FlowMemory hook address."
        : "Dry-run proof exists, but a funded Base Sepolia broadcast and non-empty hook readback are still required.",
      openedAt: generatedAt,
      linkedObjectIds: [plan.hook.hookAddress, ...memorySignals.map((signal) => signal.signalId)],
      recommendedAction: complete
        ? "Use this public-testnet evidence for launch demonstration with production boundaries."
        : "Broadcast the swap proof with a funded testnet key, run readback over the receipt block range, then regenerate this dashboard.",
      status: complete ? "verified" : "unresolved",
      lastUpdated: generatedAt,
      provenance: provenance("alerts", paths.evidencePath, generatedAt),
    }],
  };

  return { flowMemory, dashboard };
}

export function generateBaseSepoliaHookDashboard(
  paths: BaseSepoliaHookDashboardPaths = DEFAULT_BASE_SEPOLIA_HOOK_DASHBOARD_PATHS,
  options: BaseSepoliaHookDashboardOptions = {},
): { flowMemory: BaseSepoliaHookEvidenceOutput; dashboard: BaseSepoliaHookDashboardData } {
  const plan = readJson<HookPlan>(paths.planPath);
  const evidence = readJson<HookEvidence>(paths.evidencePath);
  const readback = readJson<HookReadbackArtifact>(paths.readbackArtifactPath);
  const indexer = readJson<IndexerPersistence>(paths.indexerPath);
  const checkpoint = readJson<BaseSepoliaCheckpoint>(paths.checkpointPath);
  const outputs = buildOutputs(plan, evidence, readback, indexer, checkpoint, paths, options.allowIncomplete === true);

  writeJson(paths.flowMemoryOutPath, outputs.flowMemory);
  writeJson(paths.dashboardOutPath, outputs.dashboard);
  writeJson(paths.dashboardRuntimePath, outputs.dashboard);

  return outputs;
}

function parseCli(): { paths: BaseSepoliaHookDashboardPaths; allowIncomplete: boolean } {
  const args = process.argv.slice(2);
  const paths = { ...DEFAULT_BASE_SEPOLIA_HOOK_DASHBOARD_PATHS };
  const optionMap: Record<string, keyof BaseSepoliaHookDashboardPaths> = {
    "--plan": "planPath",
    "--evidence": "evidencePath",
    "--readback-artifact": "readbackArtifactPath",
    "--indexer": "indexerPath",
    "--checkpoint": "checkpointPath",
    "--out": "flowMemoryOutPath",
    "--dashboard-out": "dashboardOutPath",
    "--dashboard-runtime-out": "dashboardRuntimePath",
  };

  for (let index = 0; index < args.length; index += 1) {
    const key = optionMap[args[index]];
    if (key !== undefined) {
      const value = args[index + 1];
      if (value === undefined || value.startsWith("--")) {
        throw new Error(`${args[index]} requires a path value`);
      }
      paths[key] = value;
      index += 1;
    }
  }

  return { paths, allowIncomplete: args.includes("--allow-incomplete") };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  process.chdir(REPO_ROOT);
  const { paths, allowIncomplete } = parseCli();
  const { flowMemory, dashboard } = generateBaseSepoliaHookDashboard(paths, { allowIncomplete });

  console.log(JSON.stringify({
    service: "flowmemory-base-sepolia-v4-hook-dashboard",
    flowMemoryOutPath: resolve(paths.flowMemoryOutPath),
    dashboardOutPath: resolve(paths.dashboardOutPath),
    dashboardRuntimePath: resolve(paths.dashboardRuntimePath),
    liveProofComplete: flowMemory.liveProofComplete,
    stage: flowMemory.stage,
    observations: dashboard.flowPulseObservations.length,
    memorySignals: dashboard.memorySignals.length,
    rootflowTransitions: dashboard.rootflowTransitions.length,
    productionReady: false,
  }, null, 2));
}
