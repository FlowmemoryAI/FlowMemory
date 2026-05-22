import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { canonicalJson, keccak256Hex } from "../../shared/src/index.ts";
import {
  observationLifecycleToFlowMemoryStatus,
  transitionStatus,
  VERIFIER_TO_FLOW_MEMORY_STATUS,
  verifierStatusToFlowMemoryStatus,
  type FlowMemoryStatus,
} from "./status.ts";
import { buildTaskScoutFixture, writeTaskScoutFixture } from "./agent-memory.ts";
import { getAgentBondsPhase2Gate } from "./agent-bonds-phase2-gate.ts";
import { buildPublicClaimPackage } from "./agent-bonds-public-claim.ts";
import type {
  AgentBondFixtureEnvelope,
  AgentMemoryView,
  FlowPulseContractEvent,
  FlowPulseContractEventRef,
  FlowPulseContractTypeName,
  LaunchCoreOutput,
  MemoryReceipt,
  MemorySignal,
  RootfieldBundle,
  RootflowTransition,
  TaskScoutFixtureEnvelope,
} from "./types.ts";

const ZERO_ROOT = "0x0000000000000000000000000000000000000000000000000000000000000000";
const GENERATED_AT = "2026-05-13T17:02:00.000Z";
const CHAIN_CONTEXT = "flowmemory-local-v0";
const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const FLOWPULSE_EVENT_SIGNATURE_TEXT = "FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string)";
const FLOWPULSE_EVENT_TOPIC0 = keccak256Hex(new TextEncoder().encode(FLOWPULSE_EVENT_SIGNATURE_TEXT));
const FLOWPULSE_CONTRACT_TYPE_NAMES: Record<string, FlowPulseContractTypeName> = {
  "1": "ROOTFIELD_REGISTERED",
  "2": "ROOT_COMMITTED",
  "3": "ROOTFIELD_STATUS_CHANGED",
  "4": "SWAP_MEMORY_SIGNAL",
  "5": "TASK_OPENED",
  "6": "TASK_ACCEPTED",
  "7": "TASK_STARTED",
  "8": "TASK_EVIDENCE_COMMITTED",
  "9": "TASK_VERIFIED",
  "10": "TASK_FAILED",
  "11": "TASK_CHALLENGED",
  "12": "TASK_SETTLED",
  "13": "TASK_SLASHED",
  "14": "AGENT_REGISTERED",
  "15": "AGENT_POLICY_UPDATED",
  "16": "AGENT_STEP_COMMITTED",
  "17": "AGENT_ACTION_EXECUTED",
  "18": "AGENT_MEMORY_COMMITTED",
  "19": "AGENT_PAUSED",
  "34": "AGENT_MEMORY_CORRECTED",
};

type JsonObject = Record<string, unknown>;

interface IndexerPersistence {
  schema: "flowmemory.indexer.persistence.v0";
  state: {
    observations: IndexedObservation[];
    pulses: Array<Record<string, unknown>>;
    rootfields: Array<{ rootfieldId: string; firstObservationId: string; latestObservationId: string; pulseCount: number }>;
  };
}

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

interface VerifierPersistence {
  schema: "flowmemory.verifier.persistence.v0";
  reports: VerifierReport[];
}

interface VerifierReport {
  reportId: string;
  reportDigest: string;
  reportCore: {
    status: string;
    observationId: string;
    resolverPolicyId: string;
    verifierSpecVersion: string;
    reasonCodes: string[];
    evidenceRefs: Array<Record<string, string>>;
    checks: Array<Record<string, string | boolean>>;
    observation: {
      rootfieldId: string;
    };
  };
}

export interface LaunchCorePaths {
  indexerPath: string;
  verifierPath: string;
  localRuntimePath: string;
  hardwarePath: string;
  launchOutPath: string;
  transitionsOutPath: string;
  dashboardOutPath: string;
  dashboardRuntimePath: string;
  agentBondFixturePath: string;
  agentMemoryFixturePath: string;
  agentMemoryViewPath: string;
  agentMemoryReplayPath: string;
}

export interface DashboardData {
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
  agentBondTasks: JsonObject[];
  agentBondSettlements: JsonObject[];
  agentBondPassportViews: JsonObject[];
  agentBondPassports: JsonObject[];
  bondedTaskEnvelopes: JsonObject[];
  bondedExecutionReceipts: JsonObject[];
  agentBondPhase2Gate: JsonObject;
  agentBondA2A: JsonObject;
  agentBondMcp: JsonObject;
  agentBondX402: JsonObject;
  agentBondCredit: JsonObject;
  agentBondUnderwriters: JsonObject;
  agentBondPublicClaim: JsonObject;
  agentBondRecoursePolicies: JsonObject[];
  agentBondRecourseDecisions: JsonObject[];
  agentBondFailureWaterfalls: JsonObject[];
  baseAgentMemoryScouts: JsonObject[];
  localRuntimeBlocks: JsonObject[];
  hardwareNodes: JsonObject[];
  alerts: JsonObject[];
}

export const DEFAULT_LAUNCH_CORE_PATHS: LaunchCorePaths = {
  indexerPath: "services/indexer/out/indexer-state.json",
  verifierPath: "services/verifier/out/reports.json",
  localRuntimePath: "fixtures/launch-core/generated/local-runtime/state.json",
  hardwarePath: "hardware/fixtures/flowrouter_sample_seed42.json",
  launchOutPath: "fixtures/launch-core/flowmemory-launch-v0.json",
  transitionsOutPath: "fixtures/launch-core/rootflow-transitions.json",
  dashboardOutPath: "fixtures/dashboard/flowmemory-dashboard-v0.json",
  dashboardRuntimePath: "apps/dashboard/public/data/flowmemory-dashboard-v0.json",
  agentBondFixturePath: "fixtures/agent-bonds/agent-bonds-v1.json",
  agentMemoryFixturePath: "fixtures/base-agent-memory/task-scout-v0.json",
  agentMemoryViewPath: "fixtures/base-agent-memory/task-scout-agent-memory-view.json",
  agentMemoryReplayPath: "fixtures/base-agent-memory/task-scout-replay-report.json",
};

function readJson<T>(path: string): T {
  return JSON.parse(readFileSync(path, "utf8")) as T;
}

function writeJson(path: string, value: unknown): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}

function readJsonDir(path: string): JsonObject[] {
  const resolved = resolve(REPO_ROOT, path);
  if (!existsSync(resolved)) return [];
  return readdirSync(resolved)
    .filter((name) => name.endsWith(".json"))
    .map((name) => readJson<JsonObject>(resolve(path, name)));
}

function stableId(schema: string, value: unknown): string {
  return keccak256Hex(new TextEncoder().encode(canonicalJson({ schema, value } as JsonObject)));
}

function pulseTypeName(pulseType: string): MemorySignal["signalType"] {
  if (pulseType === "1") {
    return "rootfield_registration";
  }
  if (pulseType === "2") {
    return "root_commitment";
  }
  if (pulseType === "4") {
    return "swap_memory_signal";
  }
  if (pulseType === "16") {
    return "agent_step_committed";
  }
  if (pulseType === "18") {
    return "agent_memory_committed";
  }
  if (pulseType === "34") {
    return "agent_memory_corrected";
  }
  return "unsupported_pulse";
}

function contractPulseTypeName(pulseType: string): FlowPulseContractTypeName {
  return FLOWPULSE_CONTRACT_TYPE_NAMES[pulseType] ?? "UNKNOWN_FLOWPULSE_TYPE";
}

function isoFromUnixSeconds(value: string): string {
  const seconds = Number(value);
  if (!Number.isFinite(seconds)) {
    return GENERATED_AT;
  }
  return new Date(seconds * 1000).toISOString();
}

function sortObservations(observations: IndexedObservation[]): IndexedObservation[] {
  return [...observations].sort((left, right) => {
    const block = BigInt(left.blockNumber) - BigInt(right.blockNumber);
    if (block !== 0n) {
      return block < 0n ? -1 : 1;
    }
    const tx = BigInt(left.transactionIndex) - BigInt(right.transactionIndex);
    if (tx !== 0n) {
      return tx < 0n ? -1 : 1;
    }
    const log = BigInt(left.logIndex) - BigInt(right.logIndex);
    if (log !== 0n) {
      return log < 0n ? -1 : 1;
    }
    return left.observationId.localeCompare(right.observationId);
  });
}

function buildFlowPulseContractEvent(observation: IndexedObservation): FlowPulseContractEvent {
  const occurredAt = isoFromUnixSeconds(observation.occurredAt);

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
      occurredAt,
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

function buildMemorySignal(observation: IndexedObservation, status: FlowMemoryStatus): MemorySignal {
  const signalCore = {
    observationId: observation.observationId,
    pulseId: observation.pulseId,
    rootfieldId: observation.rootfieldId,
    pulseType: observation.pulseType,
    sequence: observation.sequence,
  };
  const contractEvent = buildFlowPulseContractEvent(observation);

  return {
    schema: "flowmemory.memory_signal.v0",
    signalId: stableId("flowmemory.memory_signal.v0", signalCore),
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
    occurredAt: isoFromUnixSeconds(observation.occurredAt),
    uri: observation.uri,
    summary: `${pulseTypeName(observation.pulseType).replaceAll("_", " ")} pulse ${observation.sequence}`,
    contractEvent,
  };
}

function buildMemoryReceipt(report: VerifierReport): MemoryReceipt {
  const core = report.reportCore;
  const checksPassed = core.checks.filter((check) => check.passed === true).length;
  const checksTotal = core.checks.length;

  return {
    schema: "flowmemory.memory_receipt.v0",
    receiptId: stableId("flowmemory.memory_receipt.v0", {
      reportId: report.reportId,
      observationId: core.observationId,
      status: core.status,
    }),
    reportId: report.reportId,
    reportDigest: report.reportDigest,
    observationId: core.observationId,
    rootfieldId: core.observation.rootfieldId,
    verifierStatus: core.status,
    flowMemoryStatus: verifierStatusToFlowMemoryStatus(core.status),
    resolverPolicyId: core.resolverPolicyId,
    verifierSpecVersion: core.verifierSpecVersion,
    checksPassed,
    checksTotal,
    reasonCodes: core.reasonCodes,
    evidenceRefs: core.evidenceRefs,
  };
}

export function buildLaunchCore(
  indexer: IndexerPersistence,
  verifier: VerifierPersistence,
  paths: LaunchCorePaths,
  agentBondFixture: AgentBondFixtureEnvelope,
  taskScoutFixture: TaskScoutFixtureEnvelope,
): LaunchCoreOutput {
  const sortedObservations = sortObservations(indexer.state.observations);
  const reportByObservation = new Map(verifier.reports.map((report) => [report.reportCore.observationId, report]));
  const receiptByObservation = new Map<string, MemoryReceipt>();
  const memoryReceipts = verifier.reports.map((report) => {
    const receipt = buildMemoryReceipt(report);
    receiptByObservation.set(receipt.observationId, receipt);
    return receipt;
  });

  const memorySignals: MemorySignal[] = sortedObservations.map((observation) => {
    const report = reportByObservation.get(observation.observationId);
    return buildMemorySignal(observation, report ? transitionStatus(observation.lifecycleState, report.reportCore.status) : observationLifecycleToFlowMemoryStatus(observation.lifecycleState));
  });
  const signalByObservation = new Map(memorySignals.map((signal) => [signal.observationId, signal]));
  const latestTransitionByPulse = new Map<string, string>();
  const currentRootByRootfield = new Map<string, string>();
  const rootflowTransitions: RootflowTransition[] = [];

  for (const observation of sortedObservations) {
    if (observation.duplicateKind === "exactDuplicate") {
      continue;
    }

    const signal = signalByObservation.get(observation.observationId);
    if (signal === undefined) {
      throw new Error(`missing MemorySignal for ${observation.observationId}`);
    }

    const report = reportByObservation.get(observation.observationId);
    const receipt = receiptByObservation.get(observation.observationId);
    const previousRoot = currentRootByRootfield.get(observation.rootfieldId) ?? ZERO_ROOT;
    const attemptedRoot = observation.pulseType === "2" || observation.pulseType === "18" ? observation.subject : previousRoot;
    const status = transitionStatus(observation.lifecycleState, report?.reportCore.status);
    const nextRoot = status === "verified" && (observation.pulseType === "2" || observation.pulseType === "18") ? attemptedRoot : previousRoot;
    const parentTransitionId = latestTransitionByPulse.get(observation.parentPulseId) ?? null;

    const transitionCore = {
      rootfieldId: observation.rootfieldId,
      observationId: observation.observationId,
      pulseId: observation.pulseId,
      parentPulseId: observation.parentPulseId,
      previousRoot,
      attemptedRoot,
      nextRoot,
      status,
      sequence: observation.sequence,
    };
    const transition: RootflowTransition = {
      schema: "flowmemory.rootflow_transition.v0",
      transitionId: stableId("flowmemory.rootflow_transition.v0", transitionCore),
      rootfieldId: observation.rootfieldId,
      observationId: observation.observationId,
      pulseId: observation.pulseId,
      parentPulseId: observation.parentPulseId,
      parentTransitionId,
      memorySignalId: signal.signalId,
      memoryReceiptId: receipt?.receiptId ?? null,
      reportId: report?.reportId ?? null,
      previousRoot,
      attemptedRoot,
      nextRoot,
      status,
      blockNumber: observation.blockNumber,
      txHash: observation.txHash,
      sequence: observation.sequence,
      reasonCodes: receipt?.reasonCodes ?? [],
      contractEventRef: buildContractEventRef(signal),
    };

    rootflowTransitions.push(transition);
    latestTransitionByPulse.set(observation.pulseId, transition.transitionId);
    if (nextRoot !== previousRoot) {
      currentRootByRootfield.set(observation.rootfieldId, nextRoot);
    }
  }

  const rootfieldIds = [...new Set(memorySignals.map((signal) => signal.rootfieldId))].sort();
  const rootfieldBundles = rootfieldIds.map((rootfieldId): RootfieldBundle => {
    const signals = memorySignals.filter((signal) => signal.rootfieldId === rootfieldId);
    const transitions = rootflowTransitions.filter((transition) => transition.rootfieldId === rootfieldId);
    const receipts = memoryReceipts.filter((receipt) => receipt.rootfieldId === rootfieldId);
    const latestTransition = transitions.at(-1) ?? null;
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
    const status = latestTransition?.status ?? "observed";
    const latestRoot = [...transitions].reverse().find((transition) => transition.nextRoot !== ZERO_ROOT)?.nextRoot ?? ZERO_ROOT;
    const bundleCore = {
      rootfieldId,
      latestRoot,
      latestTransitionId: latestTransition?.transitionId ?? null,
      status,
      counts,
    };

    return {
      schema: "flowmemory.rootfield_bundle.v0",
      bundleId: stableId("flowmemory.rootfield_bundle.v0", bundleCore),
      rootfieldId,
      latestRoot,
      latestTransitionId: latestTransition?.transitionId ?? null,
      status,
      transitionIds: transitions.map((transition) => transition.transitionId),
      memorySignalIds: signals.map((signal) => signal.signalId),
      memoryReceiptIds: receipts.map((receipt) => receipt.receiptId),
      verifierReportIds: receipts.map((receipt) => receipt.reportId),
      counts,
    };
  });

  const agentMemoryViews = rootfieldBundles.map((bundle): AgentMemoryView => {
    const warnings = [
      bundle.counts.failed > 0 ? `${bundle.counts.failed} failed transition(s)` : null,
      bundle.counts.unresolved > 0 ? `${bundle.counts.unresolved} unresolved receipt(s)` : null,
      bundle.counts.reorged > 0 ? `${bundle.counts.reorged} reorged observation(s)` : null,
      bundle.counts.unsupported > 0 ? `${bundle.counts.unsupported} unsupported pulse(s)` : null,
    ].filter((warning): warning is string => warning !== null);

    return {
      schema: "flowmemory.agent_memory_view.v0",
      viewId: stableId("flowmemory.agent_memory_view.v0", {
        rootfieldId: bundle.rootfieldId,
        latestTransitionId: bundle.latestTransitionId,
        latestRoot: bundle.latestRoot,
      }),
      rootfieldId: bundle.rootfieldId,
      status: bundle.status,
      latestRoot: bundle.latestRoot,
      latestTransitionId: bundle.latestTransitionId,
      signalIds: bundle.memorySignalIds,
      receiptIds: bundle.memoryReceiptIds,
      transitionIds: bundle.transitionIds,
      warnings,
      localOnly: true,
    };
  });

  return {
    schema: "flowmemory.launch_core.v0",
    generatedAt: GENERATED_AT,
    mode: "fixture",
    sourcePaths: {
      indexer: paths.indexerPath,
      verifier: paths.verifierPath,
      localRuntime: paths.localRuntimePath,
      hardware: paths.hardwarePath,
      agentBondFixture: paths.agentBondFixturePath,
      agentMemoryFixture: paths.agentMemoryFixturePath,
    },
    statusAdapter: VERIFIER_TO_FLOW_MEMORY_STATUS,
    memorySignals,
    memoryReceipts,
    rootflowTransitions,
    rootfieldBundles,
    agentMemoryViews,
    agentBondFixture,
    taskScoutFixture,
    acceptance: {
      loadedFlowPulses: indexer.state.pulses.length,
      indexedObservations: indexer.state.observations.length,
      verifierReports: verifier.reports.length,
      rootflowTransitions: rootflowTransitions.length,
      dashboardFixtureGenerated: true,
      localOnly: true,
    },
  };
}

function provenance(subsystem: string, localPathHint: string): JsonObject {
  return {
    subsystem,
    origin: "fixture",
    chainContext: CHAIN_CONTEXT,
    fixturePath: "fixtures/launch-core/flowmemory-launch-v0.json",
    capturedAt: GENERATED_AT,
    localPathHint,
  };
}

function dashboardStatusFromLifecycle(lifecycleState: string): FlowMemoryStatus {
  if (lifecycleState === "removed") {
    return "reorged";
  }
  return observationLifecycleToFlowMemoryStatus(lifecycleState);
}

function buildDashboardData(
  launchCore: LaunchCoreOutput,
  indexer: IndexerPersistence,
  verifier: VerifierPersistence,
  localRuntime: JsonObject,
  hardware: JsonObject,
  taskScoutFixture: TaskScoutFixtureEnvelope,
): DashboardData {
  const currentBlock = Math.max(...indexer.state.observations.map((observation) => Number(observation.blockNumber)));
  const finalizedBlock = Math.max(
    ...indexer.state.observations
      .filter((observation) => observation.lifecycleState === "finalized")
      .map((observation) => Number(observation.blockNumber)),
  );
  const reportByObservation = new Map(verifier.reports.map((report) => [report.reportCore.observationId, report]));
  const packets = hardware.packets as Record<string, JsonObject> | undefined;
  const heartbeat = packets?.heartbeat as JsonObject | undefined;
  const manifest = packets?.device_manifest as JsonObject | undefined;
  const emergency = packets?.emergency_offline_signal as JsonObject | undefined;
  const gateway = packets?.gateway_discovery as JsonObject | undefined;
  const cache = packets?.local_cache_status as JsonObject | undefined;
  const sidecar = packets?.sidecar_status as JsonObject | undefined;
  const blocks = Array.isArray(localRuntime.blocks) ? localRuntime.blocks as JsonObject[] : [];

  const rootfields = launchCore.rootfieldBundles.map((bundle) => ({
    id: bundle.bundleId,
    rootfieldId: bundle.rootfieldId,
    owner: launchCore.memorySignals.find((signal) => signal.rootfieldId === bundle.rootfieldId)?.actor ?? ZERO_ROOT,
    schemaHash: stableId("flowmemory.dashboard.rootfield.schema_hash.v0", bundle.rootfieldId),
    metadataHash: stableId("flowmemory.dashboard.rootfield.metadata_hash.v0", bundle.rootfieldId),
    latestRoot: bundle.latestRoot,
    latestObservationId: launchCore.memorySignals.findLast((signal) => signal.rootfieldId === bundle.rootfieldId)?.observationId ?? ZERO_ROOT,
    pulseCount: bundle.counts.observations,
    workLaneIds: ["MEMORY_REFRESH", "FAILURE_DISCOVERY", "FAILURE_REPAIR", "EVAL_COUNTEREXAMPLE"],
    evidenceUri: "fixture://launch-core/rootfield-bundle",
    status: "observed",
    lastUpdated: GENERATED_AT,
    provenance: provenance("indexer", "fixtures/launch-core/flowmemory-launch-v0.json"),
  }));

  const verifierReports = launchCore.memoryReceipts.map((receipt) => ({
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
    lastUpdated: GENERATED_AT,
    provenance: provenance("verifier", "services/verifier/out/reports.json"),
  }));

  const hardwareNodes = [
    {
      id: String(manifest?.device_id ?? "flowrouter-fixture"),
      nodeId: String(manifest?.device_id ?? "flowrouter-fixture"),
      callsign: "FlowRouter kit",
      role: "router",
      firmware: String(manifest?.schema_version ?? "flowrouter.poc.v0"),
      transport: "local-wifi+meshtastic-sidecar-sim",
      lastHeartbeatAt: String(heartbeat?.emitted_at ?? GENERATED_AT),
      batteryPercent: 100,
      signalDbm: -61,
      temperatureC: 37,
      linkedWorkLaneId: "CHECKPOINT_STORAGE",
      locationHint: "local lab fixture",
      status: heartbeat?.network_state === "online" ? "verified" : "stale",
      provenance: provenance("hardware", "hardware/fixtures/flowrouter_sample_seed42.json"),
    },
    {
      id: String(gateway?.gateway_id ?? "gateway-fixture"),
      nodeId: String(gateway?.gateway_id ?? "gateway-fixture"),
      callsign: "Gateway relay",
      role: "gateway",
      firmware: "gateway-discovery-fixture",
      transport: "LAN gateway sim",
      lastHeartbeatAt: String(gateway?.emitted_at ?? GENERATED_AT),
      linkedWorkLaneId: "CHECKPOINT_STORAGE",
      locationHint: "derived from gateway discovery packet",
      status: emergency ? "offline" : "verified",
      provenance: provenance("hardware", "hardware/fixtures/flowrouter_sample_seed42.json"),
    },
    {
      id: `${String(manifest?.device_id ?? "flowrouter-fixture")}-sidecar`,
      nodeId: `${String(manifest?.device_id ?? "flowrouter-fixture")}-sidecar`,
      callsign: "LoRa sidecar",
      role: "sidecar",
      firmware: "meshtastic-sidecar-fixture",
      transport: "LoRa advisory sim",
      lastHeartbeatAt: String(sidecar?.emitted_at ?? heartbeat?.emitted_at ?? GENERATED_AT),
      signalDbm: -84,
      linkedWorkLaneId: "FAILURE_DISCOVERY",
      locationHint: "derived from sidecar status packet",
      status: cache?.unresolved_count ? "stale" : "verified",
      provenance: provenance("hardware", "hardware/fixtures/flowrouter_sample_seed42.json"),
    },
  ];

  const alerts = [
    ...launchCore.memoryReceipts
      .filter((receipt) => receipt.flowMemoryStatus !== "verified")
      .map((receipt) => ({
        id: stableId("flowmemory.dashboard.alert.v0", receipt.receiptId),
        incidentId: stableId("flowmemory.dashboard.alert.v0", receipt.receiptId),
        severity: receipt.flowMemoryStatus === "failed" ? "critical" : "warning",
        title: `Verifier ${receipt.flowMemoryStatus}`,
        summary: receipt.reasonCodes.join(", ") || "Verifier report needs operator review.",
        openedAt: GENERATED_AT,
        linkedObjectIds: [receipt.observationId, receipt.reportId],
        recommendedAction: "Inspect generated Flow Memory receipt and source verifier report.",
        status: receipt.flowMemoryStatus,
        lastUpdated: GENERATED_AT,
        provenance: provenance("alerts", "services/verifier/out/reports.json"),
      })),
    ...(emergency ? [{
      id: stableId("flowmemory.dashboard.alert.v0", emergency),
      incidentId: stableId("flowmemory.dashboard.alert.v0", emergency),
      severity: "warning",
      title: String(emergency.code ?? "hardware-warning"),
      summary: String(emergency.summary ?? "Hardware fixture emitted an advisory warning."),
      openedAt: String(emergency.emitted_at ?? GENERATED_AT),
      linkedObjectIds: [String(emergency.device_id ?? "flowrouter-fixture")],
      recommendedAction: String(emergency.operator_action ?? "review hardware fixture"),
      status: "unresolved",
      lastUpdated: GENERATED_AT,
      provenance: provenance("alerts", "hardware/fixtures/flowrouter_sample_seed42.json"),
    }] : []),
  ];

  const agentBondTask = launchCore.agentBondFixture?.task as Record<string, unknown> | undefined;
  const agentBondSettlement = launchCore.agentBondFixture?.settlement as Record<string, unknown> | undefined;
  const agentBondPassport = launchCore.agentBondFixture?.agentMemoryView as Record<string, unknown> | undefined;
  const agentBondReport = launchCore.agentBondFixture?.verifierReport as Record<string, unknown> | undefined;
  const agentBondProvenancePath = String(launchCore.sourcePaths.agentBondFixture);
  const agentBondTasks = agentBondTask ? [{
    id: String(agentBondTask.taskId),
    taskId: String(agentBondTask.taskId),
    rootfieldId: String(agentBondTask.rootfieldId),
    requester: String(agentBondTask.requester),
    agent: String(agentBondTask.agent),
    verifier: String(agentBondTask.verifier),
    payout: String(agentBondTask.payout),
    agentBond: String(agentBondTask.agentBond),
    disputeBond: String(agentBondTask.disputeBond),
    reportStatus: String(agentBondReport?.status ?? "unknown"),
    settlementStatus: String(agentBondSettlement?.status ?? "unknown"),
    status: "verified",
    lastUpdated: GENERATED_AT,
    provenance: provenance("worker", agentBondProvenancePath),
  }] : [];
  const agentBondSettlements = agentBondSettlement ? [{
    id: String(agentBondSettlement.settlementId),
    settlementId: String(agentBondSettlement.settlementId),
    taskId: String(agentBondSettlement.taskId),
    settlementToken: String(agentBondSettlement.settlementToken),
    totalEscrowed: String(agentBondSettlement.totalEscrowed),
    totalReleased: String(agentBondSettlement.totalReleased),
    reserveAmount: String(agentBondSettlement.reserveAmount),
    transferCount: Array.isArray(agentBondSettlement.transfers) ? agentBondSettlement.transfers.length : 0,
    status: agentBondSettlement.status === "slashed" ? "failed" : agentBondSettlement.status === "refunded" ? "unresolved" : "verified",
    lastUpdated: GENERATED_AT,
    provenance: provenance("worker", agentBondProvenancePath),
  }] : [];
  const agentBondPassportViews = agentBondPassport ? [{
    id: String(agentBondPassport.viewId),
    viewId: String(agentBondPassport.viewId),
    agent: String(agentBondPassport.agent),
    rootfieldId: String(agentBondPassport.rootfieldId),
    latestTaskId: String(agentBondPassport.latestTaskId),
    verifiedTaskCount: Number(agentBondPassport.verifiedTaskCount ?? 0),
    failedTaskCount: Number(agentBondPassport.failedTaskCount ?? 0),
    slashedTaskCount: Number(agentBondPassport.slashedTaskCount ?? 0),
    totalPayoutEarned: String(agentBondPassport.totalPayoutEarned ?? "0"),
    totalBondAtRisk: String(agentBondPassport.totalBondAtRisk ?? "0"),
    reputationScore: Number(agentBondPassport.reputationScore ?? 0),
    status: "verified",
    lastUpdated: GENERATED_AT,
    provenance: provenance("worker", agentBondProvenancePath),
  }] : [];

  const passportFixtures = readJsonDir("fixtures/agent-bonds/passports");
  const envelopeFixtures = readJsonDir("fixtures/agent-bonds/envelopes");
  const receiptFixtures = readJsonDir("fixtures/agent-bonds/receipts");
  const a2aCardFixtures = readJsonDir("fixtures/agent-bonds/a2a").filter((entry) => typeof entry.name === "string");
  const a2aExtensionFixtures = readJsonDir("fixtures/agent-bonds/a2a").filter((entry) => entry.uri === "https://flowmemory.ai/a2a/extensions/agent-bonds/v1");
  const mcpTools = readJson<JsonObject>("fixtures/agent-bonds/mcp/tools-list.agent-bonds.json");
  const x402PaymentIntents = readJsonDir("fixtures/agent-bonds/x402").filter((entry) => entry.schemaVersion === "x402-agent-bonds-payment-intent/v1");
  const creditScores = readJsonDir("fixtures/agent-bonds/credit").filter((entry) => entry.schemaVersion === "agent-credit-score/v1");
  const underwriterPools = readJsonDir("fixtures/agent-bonds/underwriters").filter((entry) => entry.schemaVersion === "underwriter-pool/v1");
  const underwriterAllocations = readJsonDir("fixtures/agent-bonds/underwriters").filter((entry) => entry.schemaVersion === "underwriter-allocation/v1");
  const recoursePolicies = readJsonDir("fixtures/agent-bonds/recourse").filter((entry) => entry.schemaVersion === "agent-bonds-recourse-policy/v1");
  const recourseDecisions = readJsonDir("fixtures/agent-bonds/recourse").filter((entry) => entry.schemaVersion === "agent-bonds-recourse-decision/v1");
  const recourseWaterfalls = readJsonDir("fixtures/agent-bonds/recourse").filter((entry) => entry.schemaVersion === "agent-bonds-failure-waterfall/v1");
  const agentBondRecoursePolicies = recoursePolicies.map((policy) => ({
    id: String(policy.policyId ?? stableId("flowmemory.dashboard.agent_bond_recourse_policy.v1", policy)),
    policyId: String(policy.policyId ?? "unknown"),
    statusLabel: String(policy.status ?? "unknown"),
    taskClasses: Array.isArray((policy.scope as JsonObject | undefined)?.taskClasses) ? ((policy.scope as JsonObject).taskClasses as string[]) : [],
    maxCoveragePerTaskUSDC: String(((policy.constraints as JsonObject | undefined)?.maxCoveragePerTaskUSDC) ?? "0"),
    maxRiskTier: Number(((policy.scope as JsonObject | undefined)?.maxRiskTier) ?? 0),
    status: policy.status === "active" ? "verified" : policy.status === "draft" ? "pending" : "stale",
    lastUpdated: GENERATED_AT,
    provenance: provenance("worker", "fixtures/agent-bonds/recourse"),
  }));
  const agentBondRecourseDecisions = recourseDecisions.map((decision) => ({
    id: String(decision.decisionId ?? stableId("flowmemory.dashboard.agent_bond_recourse_decision.v1", decision)),
    decisionId: String(decision.decisionId ?? "unknown"),
    policyId: String(decision.policyId ?? "unknown"),
    envelopeId: String(decision.envelopeId ?? "unknown"),
    decisionStatus: String(decision.status ?? "unknown"),
    approvedCoverageUSDC: String(decision.approvedCoverageUSDC ?? "0"),
    premiumUSDC: String(decision.premiumUSDC ?? "0"),
    reasonCodes: Array.isArray(decision.reasonCodes) ? decision.reasonCodes as string[] : [],
    policyAttestationId: String(((decision.policyAttestation as JsonObject | undefined)?.attestationId) ?? ""),
    policyAttestationSignerId: String(((decision.policyAttestation as JsonObject | undefined)?.signerId) ?? ""),
    status: decision.status === "approved" ? "verified" : decision.status === "manual_review" ? "pending" : "failed",
    lastUpdated: GENERATED_AT,
    provenance: provenance("worker", "fixtures/agent-bonds/recourse"),
  }));
  const agentBondFailureWaterfalls = recourseWaterfalls.map((waterfall) => ({
    id: String(waterfall.waterfallId ?? stableId("flowmemory.dashboard.agent_bond_failure_waterfall.v1", waterfall)),
    waterfallId: String(waterfall.waterfallId ?? "unknown"),
    receiptId: String(waterfall.receiptId ?? "unknown"),
    terminalState: String(waterfall.terminalState ?? "unknown"),
    toRequesterUSDC: String(((waterfall.totals as JsonObject | undefined)?.toRequesterUSDC) ?? "0"),
    recourseUSDC: String(((waterfall.totals as JsonObject | undefined)?.recourseUSDC) ?? "0"),
    slashedUSDC: String(((waterfall.totals as JsonObject | undefined)?.slashedUSDC) ?? "0"),
    status: String(waterfall.terminalState ?? "").includes("slashed") ? "failed" : "verified",
    lastUpdated: GENERATED_AT,
    provenance: provenance("worker", "fixtures/agent-bonds/recourse"),
  }));
  const phase2Gate = getAgentBondsPhase2Gate();
  const publicClaim = buildPublicClaimPackage({ claimLevel: "integration_beta", generatedAt: GENERATED_AT });
  const agentBondPassports = passportFixtures.map((passport) => ({
    id: String(passport.passportId ?? passport.agentId),
    passportId: String(passport.passportId ?? passport.agentId),
    agentId: String(passport.agentId ?? "unknown"),
    operatorId: String(passport.operatorId ?? "unknown"),
    displayName: String(passport.displayName ?? passport.agentId ?? "unknown"),
    riskBand: String(((passport.capacity as JsonObject | undefined)?.riskBand) ?? "UNRATED"),
    status: passport.status === "revoked" ? "failed" : passport.status === "paused" || passport.status === "draft" ? "pending" : "verified",
    lastUpdated: GENERATED_AT,
    provenance: provenance("worker", "fixtures/agent-bonds/passports"),
  }));
  const bondedTaskEnvelopes = envelopeFixtures.filter((entry) => entry.schemaVersion === "bonded-task-envelope/v1").map((envelope) => ({
    id: String(envelope.envelopeId),
    envelopeId: String(envelope.envelopeId),
    envelopeHash: String(envelope.envelopeHash),
    taskClass: String(((envelope.task as JsonObject | undefined)?.taskClass) ?? "unknown"),
    payoutUSDC: String(((envelope.economics as JsonObject | undefined)?.payoutUSDC) ?? "0"),
    fundingMode: String(((envelope.payment as JsonObject | undefined)?.fundingMode) ?? "unknown"),
    status: "pending",
    lastUpdated: GENERATED_AT,
    provenance: provenance("worker", "fixtures/agent-bonds/envelopes"),
  }));
  const bondedExecutionReceipts = receiptFixtures.filter((entry) => entry.schemaVersion === "bonded-execution-receipt/v1").map((receipt) => ({
    id: String(receipt.receiptId),
    receiptId: String(receipt.receiptId),
    terminalState: String(((receipt.lifecycle as JsonObject | undefined)?.terminalState) ?? "unknown"),
    agentId: String(((receipt.participants as JsonObject | undefined)?.agentId) ?? "unknown"),
    envelopeId: String(receipt.envelopeId ?? "unknown"),
    slashedUSDC: String(((receipt.settlement as JsonObject | undefined)?.slashedUSDC) ?? "0"),
    status: String(((receipt.lifecycle as JsonObject | undefined)?.terminalState) ?? "").includes("slashed") ? "failed" : String(((receipt.lifecycle as JsonObject | undefined)?.terminalState) ?? "") === "refunded_unsupported" ? "unsupported" : "verified",
    lastUpdated: GENERATED_AT,
    provenance: provenance("worker", "fixtures/agent-bonds/receipts"),
  }));

  const baseAgentMemoryScouts = [{
    id: taskScoutFixture.agentMemoryView.viewId,
    viewId: taskScoutFixture.agentMemoryView.viewId,
    agentId: taskScoutFixture.agentConfig.agentId,
    rootfieldId: taskScoutFixture.agentConfig.rootfieldId,
    latestMemoryRoot: taskScoutFixture.agentMemoryView.latestMemoryRoot,
    sequence: taskScoutFixture.agentMemoryView.sequence,
    status: taskScoutFixture.verifierReport.status,
    action: taskScoutFixture.stepPreview.action,
    reasonCode: taskScoutFixture.stepPreview.reasonCode,
    previewHash: taskScoutFixture.stepPreview.previewHash,
    actionReceiptId: taskScoutFixture.actionReceipt.actionReceiptId,
    memoryDeltaId: taskScoutFixture.memoryDelta.memoryDeltaId,
    verifierReportId: taskScoutFixture.verifierReport.verifierReportId,
    checksPassed: taskScoutFixture.verifierReport.checks.filter((check) => check.status === "pass").length,
    checksTotal: taskScoutFixture.verifierReport.checks.length,
    verifiedMemoryCount: taskScoutFixture.agentMemoryView.verifiedMemory.length,
    pendingMemoryCount: taskScoutFixture.agentMemoryView.pendingMemory.length,
    failedMemoryCount: taskScoutFixture.agentMemoryView.failedOrCorrectedMemory.length,
    replayWarnings: taskScoutFixture.agentMemoryView.replayWarnings,
    localOnly: true,
    lastUpdated: GENERATED_AT,
    provenance: provenance("worker", "fixtures/base-agent-memory/task-scout-v0.json"),
  }];

  return {
    metadata: {
      schema: "flowmemory.dashboard.fixture.v0",
      generatedAt: GENERATED_AT,
      mode: "fixture",
      description: "Generated local FlowMemory Dashboard V0 fixture from services, local runtime, and hardware POC outputs. It does not claim live production data.",
      fixturePath: "fixtures/dashboard/flowmemory-dashboard-v0.json",
      runtimeDataPath: "apps/dashboard/public/data/flowmemory-dashboard-v0.json",
      futureGeneratedPaths: {
        indexer: "services/indexer/out/indexer-state.json",
        verifier: "services/verifier/out/reports.json",
        localRuntime: "fixtures/launch-core/generated/local-runtime/state.json",
        hardware: "hardware/fixtures/flowrouter_sample_seed42.json",
        agentBondFixture: "fixtures/agent-bonds/agent-bonds-v1.json",
        agentMemoryFixture: "fixtures/base-agent-memory/task-scout-v0.json",
      },
    },
    chain: {
      chainId: "8453",
      name: "FlowMemory local V0 fixture stack",
      environment: "local-runtime",
      settlementContext: "Base-native fixture observations plus no-value local runtime handoff; not Base mainnet production data.",
      currentBlock,
      finalizedBlock,
      source: "fixture",
      lastUpdated: GENERATED_AT,
    },
    flowPulseObservations: indexer.state.observations.map((observation) => ({
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
      occurredAt: isoFromUnixSeconds(observation.occurredAt),
      uri: observation.uri,
      summary: `${pulseTypeName(observation.pulseType).replaceAll("_", " ")} from generated indexer output`,
      status: dashboardStatusFromLifecycle(observation.lifecycleState),
      lastUpdated: GENERATED_AT,
      provenance: provenance("indexer", "services/indexer/out/indexer-state.json"),
    })),
    rootfields,
    workLanes: [
      {
        id: "MEMORY_REFRESH",
        laneId: "MEMORY_REFRESH",
        name: "Memory refresh",
        queueDepth: launchCore.memoryReceipts.filter((receipt) => receipt.flowMemoryStatus === "unresolved").length,
        inflight: launchCore.rootflowTransitions.filter((transition) => transition.status === "pending").length,
        completed24h: launchCore.memoryReceipts.filter((receipt) => receipt.flowMemoryStatus === "verified").length,
        p95LatencyMs: 640,
        operator: "fixture-worker",
        status: "pending",
        lastUpdated: GENERATED_AT,
        provenance: provenance("worker", "fixtures/launch-core/flowmemory-launch-v0.json"),
      },
      {
        id: "FAILURE_REPAIR",
        laneId: "FAILURE_REPAIR",
        name: "Failure repair",
        queueDepth: launchCore.memoryReceipts.filter((receipt) => receipt.flowMemoryStatus === "failed").length,
        inflight: 0,
        completed24h: 0,
        p95LatencyMs: 920,
        operator: "fixture-worker",
        status: "failed",
        lastUpdated: GENERATED_AT,
        provenance: provenance("worker", "fixtures/launch-core/flowmemory-launch-v0.json"),
      },
    ],
    workReceipts: launchCore.memoryReceipts.map((receipt) => ({
      id: receipt.receiptId,
      receiptId: receipt.receiptId,
      laneId: receipt.flowMemoryStatus === "failed" ? "FAILURE_REPAIR" : "MEMORY_REFRESH",
      rootfieldId: receipt.rootfieldId,
      observationId: receipt.observationId,
      reportId: receipt.reportId,
      workType: "VERIFIER_REPORT_TO_MEMORY_RECEIPT",
      artifactUri: receipt.evidenceRefs[0]?.uri ?? "fixture://missing-artifact",
      startedAt: GENERATED_AT,
      completedAt: receipt.flowMemoryStatus === "unresolved" ? undefined : GENERATED_AT,
      resultHash: receipt.reportDigest,
      status: receipt.flowMemoryStatus,
      lastUpdated: GENERATED_AT,
      provenance: provenance("verifier", "services/verifier/out/reports.json"),
    })),
    verifierReports,
    rootflowTransitions: launchCore.rootflowTransitions.map((transition) => ({
      ...transition,
      id: transition.transitionId,
      lastUpdated: GENERATED_AT,
      provenance: provenance("indexer", "fixtures/launch-core/rootflow-transitions.json"),
    })),
    memorySignals: launchCore.memorySignals.map((signal) => ({
      ...signal,
      id: signal.signalId,
      lastUpdated: GENERATED_AT,
      provenance: provenance("indexer", "fixtures/launch-core/flowmemory-launch-v0.json"),
    })),
    memoryReceipts: launchCore.memoryReceipts.map((receipt) => ({
      ...receipt,
      id: receipt.receiptId,
      status: receipt.flowMemoryStatus,
      lastUpdated: GENERATED_AT,
      provenance: provenance("verifier", "fixtures/launch-core/flowmemory-launch-v0.json"),
    })),
    rootfieldBundles: launchCore.rootfieldBundles.map((bundle) => ({
      ...bundle,
      id: bundle.bundleId,
      lastUpdated: GENERATED_AT,
      provenance: provenance("indexer", "fixtures/launch-core/flowmemory-launch-v0.json"),
    })),
    agentMemoryViews: launchCore.agentMemoryViews.map((view) => ({
      ...view,
      id: view.viewId,
      lastUpdated: GENERATED_AT,
      provenance: provenance("worker", "fixtures/launch-core/flowmemory-launch-v0.json"),
    })),
    agentBondTasks,
    agentBondSettlements,
    agentBondPassportViews,
    agentBondPassports,
    bondedTaskEnvelopes,
    bondedExecutionReceipts,
    agentBondPhase2Gate: {
      id: "agent-bond-phase2-gate",
      ...phase2Gate,
      status: phase2Gate.foundationReady ? "verified" : "unresolved",
      lastUpdated: GENERATED_AT,
      provenance: provenance("worker", "local-runtime/local/agent-bonds-readiness/agent-bonds-phase2-gate.json"),
    },
    agentBondA2A: {
      agentCards: a2aCardFixtures,
      extensions: a2aExtensionFixtures,
    },
    agentBondMcp: {
      tools: Array.isArray(mcpTools.tools) ? mcpTools.tools : [],
      resources: Array.isArray(mcpTools.resources) ? mcpTools.resources : [],
      prompts: Array.isArray(mcpTools.prompts) ? mcpTools.prompts : [],
    },
    agentBondX402: {
      paymentIntents: x402PaymentIntents,
    },
    agentBondCredit: {
      scores: creditScores,
    },
    agentBondUnderwriters: {
      pools: underwriterPools,
      allocations: underwriterAllocations,
    },
    agentBondRecoursePolicies,
    agentBondRecourseDecisions,
    agentBondFailureWaterfalls,
    agentBondPublicClaim: {
      ...publicClaim,
      status: publicClaim.enabled ? "verified" : "unresolved",
      lastUpdated: GENERATED_AT,
      provenance: provenance("worker", "fixtures/agent-bonds/claims"),
    },
    baseAgentMemoryScouts,
    localRuntimeBlocks: blocks.map((block) => ({
      id: String(block.blockHash),
      blockNumber: Number(block.blockNumber),
      blockHash: String(block.blockHash),
      parentHash: String(block.parentHash),
      stateRoot: String(block.stateRoot),
      receiptsRoot: stableId("flowmemory.dashboard.localRuntime.receipts_root.v0", block.receipts ?? []),
      timestamp: new Date(Number(block.logicalTime ?? 0) * 1000).toISOString(),
      observationCount: launchCore.acceptance.indexedObservations,
      reportCount: launchCore.acceptance.verifierReports,
      finalityDistance: Math.max(0, currentBlock - Number(block.blockNumber ?? 0)),
      status: Number(block.blockNumber ?? 0) === blocks.length ? "finalized" : "stale",
      lastUpdated: GENERATED_AT,
      provenance: provenance("localRuntime", "fixtures/launch-core/generated/local-runtime/state.json"),
    })),
    hardwareNodes,
    alerts,
  };
}

export function generateLaunchCore(paths: LaunchCorePaths = DEFAULT_LAUNCH_CORE_PATHS): {
  launchCore: LaunchCoreOutput;
  dashboard: DashboardData;
} {
  const indexer = readJson<IndexerPersistence>(paths.indexerPath);
  const verifier = readJson<VerifierPersistence>(paths.verifierPath);
  const localRuntime = readJson<JsonObject>(paths.localRuntimePath);
  const hardware = readJson<JsonObject>(paths.hardwarePath);
  const agentBondFixture = readJson<AgentBondFixtureEnvelope>(paths.agentBondFixturePath);
  const taskScoutFixture = buildTaskScoutFixture();
  const launchCore = buildLaunchCore(indexer, verifier, paths, agentBondFixture, taskScoutFixture);
  const dashboard = buildDashboardData(launchCore, indexer, verifier, localRuntime, hardware, taskScoutFixture);

  writeJson(paths.launchOutPath, launchCore);
  writeJson(paths.transitionsOutPath, {
    schema: "flowmemory.rootflow_transition_set.v0",
    generatedAt: launchCore.generatedAt,
    rootflowTransitions: launchCore.rootflowTransitions,
  });
  writeJson(paths.dashboardOutPath, dashboard);
  writeJson(paths.dashboardRuntimePath, dashboard);
  writeTaskScoutFixture({
    fixturePath: paths.agentMemoryFixturePath,
    viewPath: paths.agentMemoryViewPath,
    replayPath: paths.agentMemoryReplayPath,
  });

  return { launchCore, dashboard };
}

function parseCliPaths(): LaunchCorePaths {
  const args = process.argv.slice(2);
  const paths = { ...DEFAULT_LAUNCH_CORE_PATHS };
  const optionMap: Record<string, keyof LaunchCorePaths> = {
    "--indexer": "indexerPath",
    "--verifier": "verifierPath",
    "--localRuntime": "localRuntimePath",
    "--hardware": "hardwarePath",
    "--out": "launchOutPath",
    "--transitions-out": "transitionsOutPath",
    "--dashboard-out": "dashboardOutPath",
    "--dashboard-runtime-out": "dashboardRuntimePath",
  };

  for (let index = 0; index < args.length; index += 1) {
    const key = optionMap[args[index]];
    if (key !== undefined) {
      const value = args[index + 1];
      if (value === undefined) {
        throw new Error(`${args[index]} requires a path value`);
      }
      paths[key] = value;
      index += 1;
    }
  }

  return paths;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  process.chdir(REPO_ROOT);
  const paths = parseCliPaths();
  const { launchCore, dashboard } = generateLaunchCore(paths);
  console.log(JSON.stringify({
    service: "flowmemory-launch-core-v0",
    launchOutPath: resolve(paths.launchOutPath),
    transitionsOutPath: resolve(paths.transitionsOutPath),
    dashboardOutPath: resolve(paths.dashboardOutPath),
    dashboardRuntimePath: resolve(paths.dashboardRuntimePath),
    memorySignals: launchCore.memorySignals.length,
    memoryReceipts: launchCore.memoryReceipts.length,
    rootflowTransitions: launchCore.rootflowTransitions.length,
    rootfieldBundles: launchCore.rootfieldBundles.length,
    agentMemoryViews: launchCore.agentMemoryViews.length,
    dashboardRecords: [
      ...dashboard.flowPulseObservations,
      ...dashboard.rootfields,
      ...dashboard.workLanes,
      ...dashboard.workReceipts,
      ...dashboard.verifierReports,
      ...dashboard.rootflowTransitions,
      ...dashboard.memorySignals,
      ...dashboard.memoryReceipts,
      ...dashboard.rootfieldBundles,
      ...dashboard.agentMemoryViews,
      ...dashboard.agentBondTasks,
      ...dashboard.agentBondSettlements,
      ...dashboard.agentBondPassportViews,
      ...dashboard.localRuntimeBlocks,
      ...dashboard.hardwareNodes,
      ...dashboard.alerts,
    ].length,
    statusAdapter: launchCore.statusAdapter,
  }, null, 2));
}
