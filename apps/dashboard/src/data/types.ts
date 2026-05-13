export type DashboardStatus =
  | "observed"
  | "pending"
  | "finalized"
  | "verified"
  | "unresolved"
  | "invalid"
  | "unsupported"
  | "reorged"
  | "offline"
  | "stale";

export type DataOrigin = "fixture" | "local" | "live";

export type SourceSubsystem =
  | "contracts"
  | "indexer"
  | "verifier"
  | "devnet"
  | "worker"
  | "hardware"
  | "alerts";

export interface Provenance {
  subsystem: SourceSubsystem;
  origin: DataOrigin;
  chainContext: string;
  fixturePath?: string;
  capturedAt?: string;
  localPathHint?: string;
}

export interface ProvenancedRecord {
  id: string;
  status: DashboardStatus;
  lastUpdated?: string;
  provenance: Provenance;
}

export interface DashboardChainContext {
  chainId: string;
  name: string;
  environment: "local-devnet" | "testnet" | "mainnet" | "unknown";
  settlementContext: string;
  currentBlock: number;
  finalizedBlock: number;
  source: DataOrigin;
  lastUpdated: string;
}

export interface FixtureMetadata {
  schema: "flowmemory.dashboard.fixture.v0";
  generatedAt: string;
  mode: "fixture";
  description: string;
  fixturePath: string;
  runtimeDataPath: string;
  futureGeneratedPaths: {
    indexer: string;
    verifier: string;
    devnet: string;
    hardware: string;
  };
}

export interface FlowPulseObservation extends ProvenancedRecord {
  observationId: string;
  pulseId: string;
  rootfieldId: string;
  eventSignature: string;
  blockNumber: string;
  blockHash: string;
  txHash: string;
  transactionIndex: string;
  logIndex: string;
  receiptStatus: "success" | "reverted" | "unknown";
  actor: string;
  pulseType: string;
  subject: string;
  commitment: string;
  parentPulseId: string;
  sequence: string;
  occurredAt: string;
  uri: string;
  summary: string;
}

export interface RootfieldState extends ProvenancedRecord {
  rootfieldId: string;
  owner: string;
  schemaHash: string;
  metadataHash: string;
  latestRoot: string;
  latestObservationId: string;
  pulseCount: number;
  workLaneIds: string[];
  evidenceUri: string;
}

export interface WorkLane extends ProvenancedRecord {
  laneId: string;
  name: string;
  queueDepth: number;
  inflight: number;
  completed24h: number;
  p95LatencyMs: number;
  operator: string;
}

export interface WorkReceipt extends ProvenancedRecord {
  receiptId: string;
  laneId: string;
  rootfieldId: string;
  observationId?: string;
  reportId?: string;
  workType: string;
  artifactUri: string;
  startedAt: string;
  completedAt?: string;
  resultHash: string;
}

export interface VerifierReport extends ProvenancedRecord {
  reportId: string;
  observationId: string;
  rootfieldId: string;
  resolverPolicyId: string;
  verifierSpecVersion: string;
  checksPassed: number;
  checksTotal: number;
  reasonCodes: string[];
  reportHash: string;
}

export interface DevnetBlock extends ProvenancedRecord {
  blockNumber: number;
  blockHash: string;
  parentHash: string;
  stateRoot: string;
  receiptsRoot: string;
  timestamp: string;
  observationCount: number;
  reportCount: number;
  finalityDistance: number;
}

export interface HardwareNode extends ProvenancedRecord {
  nodeId: string;
  callsign: string;
  role: "router" | "gateway" | "sidecar" | "field-kit";
  firmware: string;
  transport: string;
  lastHeartbeatAt?: string;
  batteryPercent?: number;
  signalDbm?: number;
  temperatureC?: number;
  linkedWorkLaneId?: string;
  locationHint: string;
}

export interface AlertIncident extends ProvenancedRecord {
  incidentId: string;
  severity: "info" | "warning" | "critical";
  title: string;
  summary: string;
  openedAt: string;
  linkedObjectIds: string[];
  recommendedAction: string;
}

export interface DashboardData {
  metadata: FixtureMetadata;
  chain: DashboardChainContext;
  flowPulseObservations: FlowPulseObservation[];
  rootfields: RootfieldState[];
  workLanes: WorkLane[];
  workReceipts: WorkReceipt[];
  verifierReports: VerifierReport[];
  devnetBlocks: DevnetBlock[];
  hardwareNodes: HardwareNode[];
  alerts: AlertIncident[];
}
