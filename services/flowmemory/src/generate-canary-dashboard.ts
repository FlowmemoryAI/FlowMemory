import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { canonicalJson, keccak256Hex } from "../../shared/src/index.ts";
import { observationLifecycleToFlowMemoryStatus, type FlowMemoryStatus } from "./status.ts";
import type {
  FlowPulseContractEvent,
  FlowPulseContractEventRef,
  FlowPulseContractTypeName,
  MemorySignal,
  RootflowTransition,
} from "./types.ts";

const ZERO_ROOT = "0x0000000000000000000000000000000000000000000000000000000000000000";
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
    source: "base-mainnet-canary-rpc";
    observations: IndexedObservation[];
    rootfields: Array<{
      rootfieldId: string;
      firstObservationId: string;
      latestObservationId: string;
      pulseCount: number;
    }>;
    rejectedLogs: unknown[];
    duplicates: unknown[];
  };
}

interface CanaryCheckpoint {
  schema: "flowmemory.indexer.base_canary_checkpoint.v0";
  network: "base-mainnet-canary";
  chainId: "8453";
  fromBlock: string;
  toBlock: string;
  finalizedBlockNumber?: string;
  observationCount: number;
  rejectedLogCount: number;
  duplicateCount: number;
  lastIndexedBlock: string;
  highestObservedBlock: string | null;
  nextFromBlock: string;
  emptyRange: boolean;
  generatedAt: string;
  safety: {
    productionReady: false;
  };
}

interface DeploymentArtifact {
  schema: "flowmemory.deployment_artifact.v0";
  name: string;
  status: "canary-only";
  productionReady: false;
  deployer: string;
  docsPath: string;
  network: {
    name: string;
    chainId: "8453";
    environment: "mainnet";
  };
  rootfield: {
    rootfieldId: string;
    owner: string;
    schemaHash: string;
    metadataHash: string;
    latestRoot: string;
  };
  contracts: Array<{
    name: string;
    sourceName: string;
    address: string;
    deployTx: string;
    block: string;
    emitsFlowPulse: boolean;
  }>;
  sourceVerification: {
    compilerVersion: string;
    optimizer: boolean;
    optimizerRuns: number;
    chainId: string;
    verifier: string;
    apiKeyEnv: string;
  };
  boundaries: string[];
}

export interface CanaryDashboardPaths {
  deploymentPath: string;
  indexerPath: string;
  checkpointPath: string;
  dashboardOutPath: string;
  dashboardRuntimePath: string;
}

export interface CanaryDashboardData {
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
  localRuntimeBlocks: JsonObject[];
  hardwareNodes: JsonObject[];
  alerts: JsonObject[];
}

export const DEFAULT_CANARY_DASHBOARD_PATHS: CanaryDashboardPaths = {
  deploymentPath: "fixtures/deployments/base-canary-v0.json",
  indexerPath: "fixtures/deployments/base-canary-indexer-state.json",
  checkpointPath: "fixtures/deployments/base-canary-indexer-checkpoint.json",
  dashboardOutPath: "fixtures/dashboard/flowmemory-dashboard-base-canary-v0.json",
  dashboardRuntimePath: "apps/dashboard/public/data/flowmemory-dashboard-base-canary-v0.json",
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

function provenance(subsystem: string, localPathHint: string, generatedAt: string): JsonObject {
  return {
    subsystem,
    origin: "live",
    chainContext: "base-mainnet-canary",
    fixturePath: "fixtures/deployments/base-canary-indexer-state.json",
    capturedAt: generatedAt,
    localPathHint,
  };
}

function buildFlowPulseContractEvent(observation: IndexedObservation): FlowPulseContractEvent {
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
      occurredAt: isoFromUnixSeconds(observation.occurredAt, new Date(0).toISOString()),
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

function buildCanaryDashboardData(
  deployment: DeploymentArtifact,
  indexer: IndexerPersistence,
  checkpoint: CanaryCheckpoint,
  paths: CanaryDashboardPaths,
): CanaryDashboardData {
  if (indexer.state.source !== "base-mainnet-canary-rpc") {
    throw new Error(`expected canary indexer source, received ${indexer.state.source}`);
  }
  if (checkpoint.safety.productionReady !== false || deployment.productionReady !== false) {
    throw new Error("canary dashboard refuses production-ready deployment artifacts");
  }

  const generatedAt = checkpoint.generatedAt;
  const observations = sortObservations(indexer.state.observations);
  const statusByObservation = new Map(observations.map((observation) => [
    observation.observationId,
    observationLifecycleToFlowMemoryStatus(observation.lifecycleState),
  ]));
  const memorySignals: MemorySignal[] = observations.map((observation) => {
    const status = statusByObservation.get(observation.observationId) ?? "observed";
    const signalCore = {
      observationId: observation.observationId,
      pulseId: observation.pulseId,
      rootfieldId: observation.rootfieldId,
      pulseType: observation.pulseType,
      sequence: observation.sequence,
    };

    return {
      schema: "flowmemory.memory_signal.v0",
      signalId: stableId("flowmemory.canary.memory_signal.v0", signalCore),
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
      summary: `${pulseTypeName(observation.pulseType).replaceAll("_", " ")} canary pulse ${observation.sequence}`,
      contractEvent: buildFlowPulseContractEvent(observation),
    };
  });
  const signalByObservation = new Map(memorySignals.map((signal) => [signal.observationId, signal]));
  const latestTransitionByPulse = new Map<string, string>();
  const currentRootByRootfield = new Map<string, string>();
  const rootflowTransitions: RootflowTransition[] = [];

  for (const observation of observations) {
    if (observation.duplicateKind === "exactDuplicate") continue;
    const signal = signalByObservation.get(observation.observationId);
    if (signal === undefined) {
      throw new Error(`missing MemorySignal for ${observation.observationId}`);
    }

    const previousRoot = currentRootByRootfield.get(observation.rootfieldId) ?? ZERO_ROOT;
    const attemptedRoot = observation.pulseType === "2" ? observation.subject : previousRoot;
    const status = statusByObservation.get(observation.observationId) ?? "observed";
    const nextRoot = observation.pulseType === "2" && (status === "finalized" || status === "observed")
      ? attemptedRoot
      : previousRoot;
    const transitionCore = {
      rootfieldId: observation.rootfieldId,
      observationId: observation.observationId,
      pulseId: observation.pulseId,
      previousRoot,
      attemptedRoot,
      nextRoot,
      status,
      sequence: observation.sequence,
    };
    const transition: RootflowTransition = {
      schema: "flowmemory.rootflow_transition.v0",
      transitionId: stableId("flowmemory.canary.rootflow_transition.v0", transitionCore),
      rootfieldId: observation.rootfieldId,
      observationId: observation.observationId,
      pulseId: observation.pulseId,
      parentPulseId: observation.parentPulseId,
      parentTransitionId: latestTransitionByPulse.get(observation.parentPulseId) ?? null,
      memorySignalId: signal.signalId,
      memoryReceiptId: null,
      reportId: null,
      previousRoot,
      attemptedRoot,
      nextRoot,
      status,
      blockNumber: observation.blockNumber,
      txHash: observation.txHash,
      sequence: observation.sequence,
      reasonCodes: ["canary.no_verifier_report"],
      contractEventRef: buildContractEventRef(signal),
    };

    rootflowTransitions.push(transition);
    latestTransitionByPulse.set(observation.pulseId, transition.transitionId);
    if (nextRoot !== previousRoot) {
      currentRootByRootfield.set(observation.rootfieldId, nextRoot);
    }
  }

  const rootfieldBundles = indexer.state.rootfields.map((rootfield) => {
    const signals = memorySignals.filter((signal) => signal.rootfieldId === rootfield.rootfieldId);
    const transitions = rootflowTransitions.filter((transition) => transition.rootfieldId === rootfield.rootfieldId);
    const latestTransition = transitions.at(-1) ?? null;
    const latestRoot = currentRootByRootfield.get(rootfield.rootfieldId) ?? deployment.rootfield.latestRoot ?? ZERO_ROOT;
    const counts = {
      observations: signals.length,
      transitions: transitions.length,
      receipts: 0,
      verified: 0,
      failed: 0,
      unresolved: 0,
      unsupported: 0,
      reorged: transitions.filter((transition) => transition.status === "reorged").length,
    };
    const bundleCore = {
      rootfieldId: rootfield.rootfieldId,
      latestRoot,
      latestTransitionId: latestTransition?.transitionId ?? null,
      status: latestTransition?.status ?? "observed",
      counts,
    };

    return {
      schema: "flowmemory.rootfield_bundle.v0",
      id: stableId("flowmemory.canary.rootfield_bundle.v0", bundleCore),
      bundleId: stableId("flowmemory.canary.rootfield_bundle.v0", bundleCore),
      rootfieldId: rootfield.rootfieldId,
      latestRoot,
      latestTransitionId: latestTransition?.transitionId ?? null,
      status: latestTransition?.status ?? "observed",
      transitionIds: transitions.map((transition) => transition.transitionId),
      memorySignalIds: signals.map((signal) => signal.signalId),
      memoryReceiptIds: [],
      verifierReportIds: [],
      counts,
      lastUpdated: generatedAt,
      provenance: provenance("indexer", paths.indexerPath, generatedAt),
    };
  });

  const rootfieldRows = indexer.state.rootfields.map((rootfield) => {
    const bundle = rootfieldBundles.find((candidate) => candidate.rootfieldId === rootfield.rootfieldId);
    return {
      id: rootfield.rootfieldId,
      rootfieldId: rootfield.rootfieldId,
      owner: deployment.rootfield.owner,
      schemaHash: deployment.rootfield.schemaHash,
      metadataHash: deployment.rootfield.metadataHash,
      latestRoot: bundle?.latestRoot ?? deployment.rootfield.latestRoot,
      latestObservationId: rootfield.latestObservationId,
      pulseCount: rootfield.pulseCount,
      workLaneIds: ["MEMORY_REFRESH", "STEERING_VALIDATION"],
      evidenceUri: deployment.docsPath,
      status: bundle?.status ?? "observed",
      lastUpdated: generatedAt,
      provenance: provenance("indexer", paths.indexerPath, generatedAt),
    };
  });

  return {
    metadata: {
      schema: "flowmemory.dashboard.fixture.v0",
      generatedAt,
      mode: "canary",
      description: "Generated Base mainnet canary dashboard data from the guarded FlowPulse reader. It is canary-only and not a production-readiness claim.",
      fixturePath: paths.dashboardOutPath,
      runtimeDataPath: paths.dashboardRuntimePath,
      canary: {
        deploymentArtifactPath: paths.deploymentPath,
        indexerStatePath: paths.indexerPath,
        checkpointPath: paths.checkpointPath,
        docsPath: deployment.docsPath,
        productionReady: false,
        sourceVerification: deployment.sourceVerification,
        readWindow: {
          fromBlock: checkpoint.fromBlock,
          toBlock: checkpoint.toBlock,
          finalizedBlock: checkpoint.finalizedBlockNumber,
        },
        counts: {
          observations: checkpoint.observationCount,
          rejectedLogs: checkpoint.rejectedLogCount,
          duplicates: checkpoint.duplicateCount,
          contracts: deployment.contracts.length,
        },
        contracts: deployment.contracts,
        boundaries: deployment.boundaries,
      },
      futureGeneratedPaths: {
        indexer: paths.indexerPath,
        verifier: "not-applicable-for-canary-v0",
        localRuntime: "not-applicable-for-canary-v0",
        hardware: "not-applicable-for-canary-v0",
        agentBondFixture: "not-applicable-for-canary-v0",
      },
    },
    chain: {
      chainId: deployment.network.chainId,
      name: "Base mainnet V0 canary",
      environment: "mainnet",
      settlementContext: "Guarded canary read from deployed V0 FlowPulse surfaces; not production protocol readiness.",
      currentBlock: Number(checkpoint.toBlock),
      finalizedBlock: Number(checkpoint.finalizedBlockNumber ?? checkpoint.lastIndexedBlock),
      source: "live",
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
      summary: `${pulseTypeName(observation.pulseType).replaceAll("_", " ")} from Base canary reader`,
      status: statusByObservation.get(observation.observationId) ?? "observed",
      lastUpdated: generatedAt,
      provenance: provenance("indexer", paths.indexerPath, generatedAt),
    })),
    rootfields: rootfieldRows,
    workLanes: [],
    workReceipts: [],
    verifierReports: [],
    rootflowTransitions: rootflowTransitions.map((transition) => ({
      ...transition,
      id: transition.transitionId,
      lastUpdated: generatedAt,
      provenance: provenance("indexer", paths.indexerPath, generatedAt),
    })),
    memorySignals: memorySignals.map((signal) => ({
      ...signal,
      id: signal.signalId,
      lastUpdated: generatedAt,
      provenance: provenance("indexer", paths.indexerPath, generatedAt),
    })),
    memoryReceipts: [],
    rootfieldBundles,
    agentMemoryViews: rootfieldBundles.map((bundle) => ({
      schema: "flowmemory.agent_memory_view.v0",
      id: stableId("flowmemory.canary.agent_memory_view.v0", bundle.bundleId),
      viewId: stableId("flowmemory.canary.agent_memory_view.v0", bundle.bundleId),
      rootfieldId: bundle.rootfieldId,
      status: bundle.status,
      latestRoot: bundle.latestRoot,
      latestTransitionId: bundle.latestTransitionId,
      signalIds: bundle.memorySignalIds,
      receiptIds: [],
      transitionIds: bundle.transitionIds,
      warnings: [
        "Canary data is live-read but not verifier-backed.",
        "Source verification and operator policy must be completed before any production claim.",
      ],
      localOnly: false,
      lastUpdated: generatedAt,
      provenance: provenance("worker", paths.indexerPath, generatedAt),
    })),
    agentBondTasks: [],
    agentBondSettlements: [],
    agentBondPassportViews: [],
    agentBondPassports: [],
    bondedTaskEnvelopes: [],
    bondedExecutionReceipts: [],
    agentBondPhase2Gate: {
      id: "agent-bond-phase2-gate-canary",
      foundationReady: false,
      status: "stale",
      blockers: ["Phase 2 fixtures are not generated from the Base canary dashboard path."],
      lastUpdated: generatedAt,
      provenance: provenance("worker", "apps/dashboard/public/data/flowmemory-dashboard-base-canary-v0.json"),
    },
    agentBondA2A: { agentCards: [], extensions: [] },
    agentBondMcp: { tools: [], resources: [], prompts: [] },
    agentBondX402: { paymentIntents: [] },
    agentBondCredit: { scores: [] },
    agentBondUnderwriters: { pools: [], allocations: [] },
    agentBondPublicClaim: {
      claimLevel: "internal_dev",
      enabled: false,
      blockers: ["Base canary dashboard does not project public Agent Bonds Phase 2 claims."],
      status: "stale",
      lastUpdated: generatedAt,
      provenance: provenance("worker", "apps/dashboard/public/data/flowmemory-dashboard-base-canary-v0.json"),
    },
    agentBondRecoursePolicies: [],
    agentBondRecourseDecisions: [],
    agentBondFailureWaterfalls: [],
    baseAgentMemoryScouts: [],
    localRuntimeBlocks: [],
    hardwareNodes: [],
    alerts: [{
      id: stableId("flowmemory.canary.alert.v0", deployment.name),
      incidentId: stableId("flowmemory.canary.alert.v0", deployment.name),
      severity: "info",
      title: "Canary mode",
      summary: "Base mainnet canary logs are visible, but verifier reports, source verification, multisig ownership, and production hook wiring are not complete.",
      openedAt: generatedAt,
      linkedObjectIds: deployment.contracts.map((contract) => contract.address),
      recommendedAction: "Use this view for launch demonstrations and operator review only.",
      status: "unresolved",
      lastUpdated: generatedAt,
      provenance: provenance("alerts", paths.deploymentPath, generatedAt),
    }],
  };
}

export function generateCanaryDashboard(paths: CanaryDashboardPaths = DEFAULT_CANARY_DASHBOARD_PATHS): CanaryDashboardData {
  const deployment = readJson<DeploymentArtifact>(paths.deploymentPath);
  const indexer = readJson<IndexerPersistence>(paths.indexerPath);
  const checkpoint = readJson<CanaryCheckpoint>(paths.checkpointPath);
  const dashboard = buildCanaryDashboardData(deployment, indexer, checkpoint, paths);

  writeJson(paths.dashboardOutPath, dashboard);
  writeJson(paths.dashboardRuntimePath, dashboard);

  return dashboard;
}

function parseCliPaths(): CanaryDashboardPaths {
  const args = process.argv.slice(2);
  const paths = { ...DEFAULT_CANARY_DASHBOARD_PATHS };
  const optionMap: Record<string, keyof CanaryDashboardPaths> = {
    "--deployment": "deploymentPath",
    "--indexer": "indexerPath",
    "--checkpoint": "checkpointPath",
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
  const dashboard = generateCanaryDashboard(paths);

  console.log(JSON.stringify({
    service: "flowmemory-canary-dashboard-v0",
    dashboardOutPath: resolve(paths.dashboardOutPath),
    dashboardRuntimePath: resolve(paths.dashboardRuntimePath),
    observations: dashboard.flowPulseObservations.length,
    memorySignals: dashboard.memorySignals.length,
    rootflowTransitions: dashboard.rootflowTransitions.length,
    productionReady: false,
  }, null, 2));
}
