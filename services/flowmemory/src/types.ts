import type { FlowMemoryStatus } from "./status.ts";

export type FlowPulseContractTypeName =
  | "ROOTFIELD_REGISTERED"
  | "ROOT_COMMITTED"
  | "ROOTFIELD_STATUS_CHANGED"
  | "SWAP_MEMORY_SIGNAL"
  | "TASK_OPENED"
  | "TASK_ACCEPTED"
  | "TASK_STARTED"
  | "TASK_EVIDENCE_COMMITTED"
  | "TASK_VERIFIED"
  | "TASK_FAILED"
  | "TASK_CHALLENGED"
  | "TASK_SETTLED"
  | "TASK_SLASHED"
  | "AGENT_REGISTERED"
  | "AGENT_POLICY_UPDATED"
  | "AGENT_STEP_COMMITTED"
  | "AGENT_ACTION_EXECUTED"
  | "AGENT_MEMORY_COMMITTED"
  | "AGENT_PAUSED"
  | "AGENT_BOND_PASSPORT_CREATED"
  | "AGENT_BOND_PASSPORT_UPDATED"
  | "AGENT_BOND_ENVELOPE_QUOTED"
  | "AGENT_BOND_ENVELOPE_SIGNED"
  | "AGENT_BOND_RECEIPT_EMITTED"
  | "AGENT_BOND_CREDIT_SCORE_UPDATED"
  | "AGENT_BOND_UNDERWRITER_CAPACITY_ALLOCATED"
  | "AGENT_BOND_UNDERWRITER_CAPACITY_LOCKED"
  | "AGENT_BOND_UNDERWRITER_LOSS_EVENT"
  | "AGENT_BOND_A2A_TASK_LINKED"
  | "AGENT_BOND_MCP_TOOL_LINKED"
  | "AGENT_BOND_X402_PAYMENT_LINKED"
  | "AGENT_BOND_PUBLIC_CLAIM_GENERATED"
  | "AGENT_BOND_PUBLIC_CLAIM_BLOCKED"
  | "AGENT_MEMORY_CORRECTED"
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
  signalType:
    | "rootfield_registration"
    | "root_commitment"
    | "swap_memory_signal"
    | "agent_step_committed"
    | "agent_memory_committed"
    | "agent_memory_corrected"
    | "unsupported_pulse";
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


export type TaskScoutFixtureEnvelope = import("./agent-memory.ts").TaskScoutFixtureEnvelope;

export interface AgentBondFixtureEnvelope {
  schema: "flowmemory.agent_bonds.fixture.v1";
  generatedAt: string;
  mode: "fixture";
  task: Record<string, unknown>;
  evidence: Record<string, unknown>;
  availabilityProof: Record<string, unknown>;
  verifierReport: Record<string, unknown>;
  resolution: Record<string, unknown>;
  settlement: Record<string, unknown>;
  flowPulses: Array<Record<string, unknown>>;
  memoryReceipt: Record<string, unknown>;
  rootflowTransition: Record<string, unknown>;
  rootfieldBundle: Record<string, unknown>;
  agentMemoryView: Record<string, unknown>;
  accounting: Record<string, unknown>;
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
    agentBondFixture: string;
    agentMemoryFixture: string;
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
  agentBondFixture?: AgentBondFixtureEnvelope;
  taskScoutFixture?: TaskScoutFixtureEnvelope;
  acceptance: {
    loadedFlowPulses: number;
    indexedObservations: number;
    verifierReports: number;
    rootflowTransitions: number;
    dashboardFixtureGenerated: boolean;
    localOnly: true;
  };
}
