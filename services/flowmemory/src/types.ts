import type { FlowMemoryStatus } from "./status.ts";

export type FlowPulseContractTypeName =
  | "ROOTFIELD_REGISTERED"
  | "ROOT_COMMITTED"
  | "ROOTFIELD_STATUS_CHANGED"
  | "UNKNOWN_FLOWPULSE_TYPE";

export interface FlowPulseContractEvent {
  schema: "flowmemory.flowpulse_contract_event.v0";
  interfaceName: "IFlowPulse";
  eventName: "FlowPulse";
  eventSignatureText: string;
  eventTopic0: string;
  expectedTopic0: string;
  topicMatchesContract: boolean;
  sourceContract: string;
  pulseTypeId: string;
  pulseTypeName: FlowPulseContractTypeName;
  indexed: {
    pulseId: string;
    rootfieldId: string;
    actor: string;
  };
  payload: {
    subject: string;
    commitment: string;
    parentPulseId: string;
    sequence: string;
    occurredAt: string;
    uri: string;
  };
  receiptLocator: {
    chainId: string;
    blockNumber: string;
    blockHash: string;
    txHash: string;
    transactionIndex: string;
    logIndex: string;
    receiptStatus: string;
  };
  receiptDerivedFields: string[];
}

export interface FlowPulseContractEventRef {
  signalId: string;
  eventName: "FlowPulse";
  eventTopic0: string;
  sourceContract: string;
  pulseTypeId: string;
  pulseTypeName: FlowPulseContractTypeName;
  txHash: string;
  logIndex: string;
}

export interface MemorySignal {
  schema: "flowmemory.memory_signal.v0";
  signalId: string;
  observationId: string;
  pulseId: string;
  rootfieldId: string;
  signalType: "rootfield_registration" | "root_commitment" | "unsupported_pulse";
  status: FlowMemoryStatus;
  chainId: string;
  emittingContract: string;
  blockNumber: string;
  blockHash: string;
  txHash: string;
  transactionIndex: string;
  logIndex: string;
  actor: string;
  subject: string;
  commitment: string;
  parentPulseId: string;
  sequence: string;
  occurredAt: string;
  uri: string;
  summary: string;
  contractEvent: FlowPulseContractEvent;
}

export interface MemoryReceipt {
  schema: "flowmemory.memory_receipt.v0";
  receiptId: string;
  reportId: string;
  reportDigest: string;
  observationId: string;
  rootfieldId: string;
  verifierStatus: string;
  flowMemoryStatus: FlowMemoryStatus;
  resolverPolicyId: string;
  verifierSpecVersion: string;
  checksPassed: number;
  checksTotal: number;
  reasonCodes: string[];
  evidenceRefs: Array<Record<string, string>>;
}

export interface RootflowTransition {
  schema: "flowmemory.rootflow_transition.v0";
  transitionId: string;
  rootfieldId: string;
  observationId: string;
  pulseId: string;
  parentPulseId: string;
  parentTransitionId: string | null;
  memorySignalId: string;
  memoryReceiptId: string | null;
  reportId: string | null;
  previousRoot: string;
  attemptedRoot: string;
  nextRoot: string;
  status: FlowMemoryStatus;
  blockNumber: string;
  txHash: string;
  sequence: string;
  reasonCodes: string[];
  contractEventRef: FlowPulseContractEventRef;
}

export interface RootfieldBundle {
  schema: "flowmemory.rootfield_bundle.v0";
  bundleId: string;
  rootfieldId: string;
  latestRoot: string;
  latestTransitionId: string | null;
  status: FlowMemoryStatus;
  transitionIds: string[];
  memorySignalIds: string[];
  memoryReceiptIds: string[];
  verifierReportIds: string[];
  counts: {
    observations: number;
    transitions: number;
    receipts: number;
    verified: number;
    failed: number;
    unresolved: number;
    unsupported: number;
    reorged: number;
  };
}

export interface AgentMemoryView {
  schema: "flowmemory.agent_memory_view.v0";
  viewId: string;
  rootfieldId: string;
  status: FlowMemoryStatus;
  latestRoot: string;
  latestTransitionId: string | null;
  signalIds: string[];
  receiptIds: string[];
  transitionIds: string[];
  warnings: string[];
  localOnly: true;
}

export interface LaunchCoreOutput {
  schema: "flowmemory.launch_core.v0";
  generatedAt: string;
  mode: "fixture";
  sourcePaths: {
    indexer: string;
    verifier: string;
    devnet: string;
    hardware: string;
  };
  statusAdapter: {
    valid: "verified";
    invalid: "failed";
    unresolved: "unresolved";
    unsupported: "unsupported";
    reorged: "reorged";
  };
  memorySignals: MemorySignal[];
  memoryReceipts: MemoryReceipt[];
  rootflowTransitions: RootflowTransition[];
  rootfieldBundles: RootfieldBundle[];
  agentMemoryViews: AgentMemoryView[];
  acceptance: {
    loadedFlowPulses: number;
    indexedObservations: number;
    verifierReports: number;
    rootflowTransitions: number;
    dashboardFixtureGenerated: boolean;
    localOnly: true;
  };
}
