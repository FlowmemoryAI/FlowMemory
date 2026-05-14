import type { DashboardData, DashboardStatus, Provenance, SourceSubsystem } from "./types";

export const DEFAULT_CONTROL_PLANE_URL = "http://127.0.0.1:8787";
export const WORKBENCH_DEVNET_STATE_PATH = "/data/flowchain-local-devnet-state.json";
export const WORKBENCH_DEVNET_DASHBOARD_STATE_PATH = "/data/flowchain-local-devnet-dashboard-state.json";
export const WORKBENCH_BRIDGE_TEST_DEPOSIT_PATH = "/data/flowchain-bridge-test-deposit.json";

const FIXTURE_CHAIN_CONTEXT = "flowchain-private-local-testnet";
const CONTROL_PLANE_TIMEOUT_MS = 900;

export type WorkbenchSource = "control-plane" | "fixture-fallback";
export type WorkbenchSectionKey =
  | "nodeStatus"
  | "peers"
  | "blocks"
  | "transactions"
  | "mempool"
  | "accounts"
  | "balances"
  | "faucetEvents"
  | "walletMetadata"
  | "tokenLaunches"
  | "tokenBalances"
  | "dexPools"
  | "liquidityPositions"
  | "swaps"
  | "explorerRecords"
  | "rootfields"
  | "agents"
  | "models"
  | "receipts"
  | "memoryCells"
  | "artifacts"
  | "verifierModules"
  | "verifierReports"
  | "challenges"
  | "finality"
  | "bridgeDeposits"
  | "bridgeCredits"
  | "bridgeWithdrawals"
  | "provenance"
  | "hardwareSignals"
  | "rawJson";

export interface WorkbenchFact {
  label: string;
  value: string;
}

export interface WorkbenchRecord {
  id: string;
  kind: string;
  title: string;
  summary: string;
  status: DashboardStatus;
  facts: WorkbenchFact[];
  provenance: Provenance;
  raw: unknown;
}

export interface WorkbenchSectionDefinition {
  key: WorkbenchSectionKey;
  label: string;
  detail: string;
  expectedEndpoint: string;
  missingCommand: string;
  missingService: string;
}

export interface ControlPlaneProbe {
  url: string;
  status: "available" | "not-detected";
  checkedAt: string;
  endpoints: string[];
  error?: string;
  health?: unknown;
  state?: unknown;
}

export interface WorkbenchNodeStatus {
  status: DashboardStatus;
  title: string;
  summary: string;
  facts: WorkbenchFact[];
}

export interface WorkbenchSetupStep {
  command: string;
  label: string;
  state: "available" | "expected";
  detail: string;
}

export interface WorkbenchAction {
  label: string;
  endpoint: string;
  detail: string;
  boundary: string;
}

export interface WorkbenchSnapshot {
  source: WorkbenchSource;
  generatedAt: string;
  controlPlane: ControlPlaneProbe;
  node: WorkbenchNodeStatus;
  setupSteps: WorkbenchSetupStep[];
  actions: WorkbenchAction[];
  sections: Record<WorkbenchSectionKey, WorkbenchRecord[]>;
  loadIssues: string[];
  raw: {
    dashboard: DashboardData;
    devnetState: unknown | null;
    devnetDashboardState: unknown | null;
    bridgeTestDeposit: unknown | null;
    controlPlaneHealth: unknown | null;
    controlPlaneState: unknown | null;
  };
}

type UnknownRecord = Record<string, unknown>;

export const WORKBENCH_SECTIONS: WorkbenchSectionDefinition[] = [
  {
    key: "nodeStatus",
    label: "Node Status",
    detail: "Runtime health, chain head, genesis, state root, and local API availability.",
    expectedEndpoint: "GET /health + GET /state",
    missingCommand: "npm run flowchain:start",
    missingService: "FlowChain control-plane API on http://127.0.0.1:8787",
  },
  {
    key: "peers",
    label: "Peers",
    detail: "Private/local peer inventory when the control-plane exposes network state.",
    expectedEndpoint: "GET /peers",
    missingCommand: "npm run flowchain:start",
    missingService: "FlowChain peer service /peers",
  },
  {
    key: "blocks",
    label: "Blocks",
    detail: "Private/local chain blocks, state roots, parent hashes, and receipt counts.",
    expectedEndpoint: "GET /blocks",
    missingCommand: "npm run flowchain:smoke",
    missingService: "FlowChain state export /blocks",
  },
  {
    key: "transactions",
    label: "Transactions",
    detail: "Smoke-flow transaction ids and receipt application status.",
    expectedEndpoint: "GET /transactions",
    missingCommand: "npm run flowchain:smoke",
    missingService: "FlowChain state export /transactions",
  },
  {
    key: "mempool",
    label: "Mempool",
    detail: "Pending local transaction pool before deterministic block production.",
    expectedEndpoint: "GET /mempool",
    missingCommand: "npm run flowchain:start",
    missingService: "FlowChain control-plane /mempool",
  },
  {
    key: "accounts",
    label: "Accounts",
    detail: "Public account/controller metadata for local agent and operator identities.",
    expectedEndpoint: "GET /accounts",
    missingCommand: "npm run flowchain:smoke",
    missingService: "FlowChain account registry /accounts",
  },
  {
    key: "balances",
    label: "Local Balances",
    detail: "No-value local balance or credit metadata when exported by the private testnet API.",
    expectedEndpoint: "GET /balances + GET /accounts/:id/balances",
    missingCommand: "npm run flowchain:smoke",
    missingService: "FlowChain no-value balance view /balances",
  },
  {
    key: "faucetEvents",
    label: "Faucet Events",
    detail: "Local faucet or no-value credit events for demo accounts only.",
    expectedEndpoint: "GET /faucet-events",
    missingCommand: "npm run flowchain:smoke",
    missingService: "FlowChain local faucet event view /faucet-events",
  },
  {
    key: "walletMetadata",
    label: "Wallet Metadata",
    detail: "Public key references and browser-safe wallet metadata. Private keys are never read here.",
    expectedEndpoint: "GET /wallets/public",
    missingCommand: "npm run flowchain:init",
    missingService: "FlowChain public wallet metadata /wallets/public",
  },
  {
    key: "tokenLaunches",
    label: "Token Launch",
    detail: "Local/testnet token definition and launch receipts. This surface does not represent tokenomics or a production coin sale.",
    expectedEndpoint: "GET /tokens + GET /token-launches",
    missingCommand: "npm run flowchain:product-e2e",
    missingService: "FlowChain product-testnet token launch view /tokens",
  },
  {
    key: "tokenBalances",
    label: "Token Balances",
    detail: "Browser-safe token balances for local/testnet accounts. Private keys and signing secrets stay outside browser storage.",
    expectedEndpoint: "GET /token-balances",
    missingCommand: "npm run flowchain:product-e2e",
    missingService: "FlowChain token balance view /token-balances",
  },
  {
    key: "dexPools",
    label: "DEX Pools",
    detail: "Local/testnet pool definitions, reserve state, quote metadata, and status for the product-testnet DEX path.",
    expectedEndpoint: "GET /dex/pools",
    missingCommand: "npm run flowchain:product-e2e",
    missingService: "FlowChain DEX pool view /dex/pools",
  },
  {
    key: "liquidityPositions",
    label: "Liquidity",
    detail: "Local/testnet LP positions and add/remove liquidity receipts.",
    expectedEndpoint: "GET /dex/liquidity",
    missingCommand: "npm run flowchain:product-e2e",
    missingService: "FlowChain liquidity position view /dex/liquidity",
  },
  {
    key: "swaps",
    label: "Swaps",
    detail: "Local/testnet swap receipts and balance deltas for the DEX path.",
    expectedEndpoint: "GET /dex/swaps",
    missingCommand: "npm run flowchain:product-e2e",
    missingService: "FlowChain swap receipt view /dex/swaps",
  },
  {
    key: "explorerRecords",
    label: "Explorer Records",
    detail: "Unified explorer rollup for blocks, transactions, receipts, token records, pool records, swap records, and bridge records.",
    expectedEndpoint: "GET /explorer",
    missingCommand: "npm run flowchain:product-e2e",
    missingService: "FlowChain explorer API /explorer",
  },
  {
    key: "rootfields",
    label: "Rootfields",
    detail: "Rootfield namespaces, owners, compact roots, schema hashes, and active state.",
    expectedEndpoint: "GET /rootfields",
    missingCommand: "npm run flowchain:smoke",
    missingService: "FlowChain rootfield registry /rootfields",
  },
  {
    key: "agents",
    label: "Agents",
    detail: "Operators, workers, verifier identities, and observed contract actors.",
    expectedEndpoint: "GET /agents",
    missingCommand: "npm run flowchain:smoke",
    missingService: "FlowChain agent registry /agents",
  },
  {
    key: "models",
    label: "Models",
    detail: "ModelPassport objects when the private testnet runtime exports them.",
    expectedEndpoint: "GET /models",
    missingCommand: "npm run flowchain:smoke",
    missingService: "FlowChain model registry /models",
  },
  {
    key: "receipts",
    label: "Work Receipts",
    detail: "Work receipts from the launch fixture and local devnet handoff.",
    expectedEndpoint: "GET /receipts",
    missingCommand: "npm run flowchain:smoke",
    missingService: "FlowChain receipt view /receipts",
  },
  {
    key: "memoryCells",
    label: "Memory Cells",
    detail: "Native MemoryCell records or rootfield-bundle projections while the API is pending.",
    expectedEndpoint: "GET /memory-cells",
    missingCommand: "npm run flowchain:smoke",
    missingService: "FlowChain memory-cell registry /memory-cells",
  },
  {
    key: "artifacts",
    label: "Artifacts",
    detail: "Artifact availability commitments and receipt-linked artifact URIs.",
    expectedEndpoint: "GET /artifacts",
    missingCommand: "npm run flowchain:smoke",
    missingService: "FlowChain artifact registry /artifacts",
  },
  {
    key: "verifierModules",
    label: "Verifier Modules",
    detail: "Verifier module identities or derived module projections from local reports.",
    expectedEndpoint: "GET /verifier-modules",
    missingCommand: "npm run flowchain:smoke",
    missingService: "FlowChain verifier module registry /verifier-modules",
  },
  {
    key: "verifierReports",
    label: "Verifier Reports",
    detail: "Verifier reports, report digests, policies, checks, and reason codes.",
    expectedEndpoint: "GET /verifier-reports",
    missingCommand: "npm run flowchain:smoke",
    missingService: "FlowChain verifier report view /verifier-reports",
  },
  {
    key: "challenges",
    label: "Challenges",
    detail: "Challenge lifecycle objects once the runtime/control-plane exports them.",
    expectedEndpoint: "GET /challenges",
    missingCommand: "npm run flowchain:smoke",
    missingService: "FlowChain challenge registry /challenges",
  },
  {
    key: "finality",
    label: "Finality",
    detail: "Local finality distance, anchor placeholders, and latest finalized state.",
    expectedEndpoint: "GET /finality",
    missingCommand: "npm run flowchain:smoke",
    missingService: "FlowChain finality view /finality",
  },
  {
    key: "bridgeDeposits",
    label: "Bridge Deposits",
    detail: "Private/local bridge-deposit test objects only; this is not a production bridge.",
    expectedEndpoint: "GET /bridge/deposits",
    missingCommand: "npm run flowchain:smoke",
    missingService: "FlowChain bridge deposit view /bridge/deposits",
  },
  {
    key: "bridgeCredits",
    label: "Bridge Credits",
    detail: "Private/local bridge-credit test objects only; no real-funds flow is available.",
    expectedEndpoint: "GET /bridge/credits",
    missingCommand: "npm run flowchain:smoke",
    missingService: "FlowChain bridge credit view /bridge/credits",
  },
  {
    key: "bridgeWithdrawals",
    label: "Bridge Withdrawals",
    detail: "Private/local bridge-withdrawal test objects only; production bridge work is out of scope.",
    expectedEndpoint: "GET /bridge/withdrawals",
    missingCommand: "npm run flowchain:smoke",
    missingService: "FlowChain bridge withdrawal view /bridge/withdrawals",
  },
  {
    key: "provenance",
    label: "Provenance / Source",
    detail: "Source paths, API probe result, and fixture fallback boundary.",
    expectedEndpoint: "GET /raw",
    missingCommand: "npm run dev --prefix apps/dashboard",
    missingService: "Dashboard fixture and control-plane probe",
  },
  {
    key: "hardwareSignals",
    label: "Hardware Signals",
    detail: "FlowRouter, gateway, and low-bandwidth sidecar heartbeat/control-signal records.",
    expectedEndpoint: "GET /hardware-signals",
    missingCommand: "npm run flowchain:smoke",
    missingService: "FlowChain hardware signal export /hardware-signals",
  },
  {
    key: "rawJson",
    label: "Raw JSON",
    detail: "Loaded dashboard, devnet, and control-plane payloads for direct inspection.",
    expectedEndpoint: "GET /raw",
    missingCommand: "npm run dev --prefix apps/dashboard",
    missingService: "Dashboard raw JSON inspector",
  },
];

const WORKBENCH_ACTIONS: WorkbenchAction[] = [
  {
    label: "Run smoke",
    endpoint: "POST /smoke",
    detail: "Ask the local control-plane to run the deterministic private/local object smoke path.",
    boundary: "Uses a local API endpoint only; no browser key material is collected.",
  },
  {
    label: "Produce block",
    endpoint: "POST /blocks",
    detail: "Request deterministic local block production when the runtime advertises that action.",
    boundary: "No value-bearing transaction signing happens in the browser.",
  },
  {
    label: "Request demo faucet",
    endpoint: "POST /faucet",
    detail: "Create a local no-value faucet/credit event for demo accounts when supported.",
    boundary: "Demo credits only; this is not a token or real-funds faucet.",
  },
  {
    label: "Refresh bridge demo",
    endpoint: "POST /bridge/smoke",
    detail: "Populate private/local bridge lifecycle test objects when the control-plane exposes them.",
    boundary: "Private/local bridge fixtures only; production bridge work remains out of scope.",
  },
  {
    label: "Launch test token",
    endpoint: "POST /tokens/launch",
    detail: "Request a local/testnet token-launch transaction through the control-plane when it is explicitly advertised.",
    boundary: "No production tokenomics and no private key material in browser storage.",
  },
  {
    label: "Create test pool",
    endpoint: "POST /dex/pools",
    detail: "Request a local/testnet DEX pool create transaction through the control-plane when it is explicitly advertised.",
    boundary: "Local DEX testing only; no production market or real asset liquidity claim.",
  },
  {
    label: "Add test liquidity",
    endpoint: "POST /dex/liquidity",
    detail: "Request a local/testnet liquidity transaction through the control-plane when it is explicitly advertised.",
    boundary: "Local no-value liquidity only.",
  },
  {
    label: "Run test swap",
    endpoint: "POST /dex/swaps",
    detail: "Request a local/testnet swap transaction through the control-plane when it is explicitly advertised.",
    boundary: "Local no-value swap only; this is not a production DEX route.",
  },
];

function isRecord(value: unknown): value is UnknownRecord {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function recordValues(value: unknown): UnknownRecord[] {
  if (Array.isArray(value)) {
    return value.filter(isRecord);
  }

  if (isRecord(value)) {
    return Object.values(value).filter(isRecord);
  }

  return [];
}

function collectionFrom(root: unknown, keys: string[]): UnknownRecord[] {
  if (!isRecord(root)) {
    return [];
  }

  for (const key of keys) {
    const values = recordValues(root[key]);
    if (values.length > 0) {
      return values;
    }
  }

  return [];
}

function text(value: unknown, fallback = "not recorded"): string {
  if (value === null || value === undefined || value === "") {
    return fallback;
  }

  return String(value);
}

function numberValue(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }

  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }

  return null;
}

function stringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.map((item) => text(item)).filter((item) => item !== "not recorded");
}

function statusFrom(value: unknown, fallback: DashboardStatus = "observed"): DashboardStatus {
  const normalized = text(value, fallback).toLowerCase();
  if (normalized === "applied" || normalized === "success" || normalized === "active") {
    return "verified";
  }
  if (normalized === "finalized") {
    return "finalized";
  }
  if (normalized === "failed" || normalized === "invalid" || normalized === "reverted") {
    return "failed";
  }
  if (normalized === "pending" || normalized === "local-placeholder") {
    return "pending";
  }
  if (normalized === "stale" || normalized === "not-detected") {
    return "stale";
  }
  if (normalized === "unsupported") {
    return "unsupported";
  }
  if (normalized === "reorged") {
    return "reorged";
  }
  if (normalized === "unresolved") {
    return "unresolved";
  }
  if (normalized === "offline") {
    return "offline";
  }
  if (normalized === "verified") {
    return "verified";
  }

  return fallback;
}

function fixtureProvenance(subsystem: SourceSubsystem, fixturePath: string): Provenance {
  return {
    subsystem,
    origin: "fixture",
    chainContext: FIXTURE_CHAIN_CONTEXT,
    fixturePath,
  };
}

function localProvenance(subsystem: SourceSubsystem, localPathHint: string, capturedAt?: string): Provenance {
  return {
    subsystem,
    origin: "local",
    chainContext: FIXTURE_CHAIN_CONTEXT,
    localPathHint,
    capturedAt,
  };
}

function makeRecord(
  subsystem: SourceSubsystem,
  fixturePath: string,
  record: Omit<WorkbenchRecord, "provenance">,
): WorkbenchRecord {
  return {
    ...record,
    provenance: fixtureProvenance(subsystem, fixturePath),
  };
}

function makeLocalRecord(
  subsystem: SourceSubsystem,
  localPathHint: string,
  record: Omit<WorkbenchRecord, "provenance">,
  capturedAt?: string,
): WorkbenchRecord {
  return {
    ...record,
    provenance: localProvenance(subsystem, localPathHint, capturedAt),
  };
}

function relabelDevnetRecordsAsControlPlane(
  sections: Record<WorkbenchSectionKey, WorkbenchRecord[]>,
  controlPlane: ControlPlaneProbe,
): Record<WorkbenchSectionKey, WorkbenchRecord[]> {
  return Object.fromEntries(
    Object.entries(sections).map(([key, records]) => [
      key,
      records.map((record) => {
        const fromFallbackFile =
          record.provenance.fixturePath === WORKBENCH_DEVNET_STATE_PATH ||
          record.provenance.fixturePath === WORKBENCH_DEVNET_DASHBOARD_STATE_PATH;

        if (!fromFallbackFile) {
          return record;
        }

        return {
          ...record,
          provenance: localProvenance(record.provenance.subsystem, controlPlane.url, controlPlane.checkedAt),
        };
      }),
    ]),
  ) as Record<WorkbenchSectionKey, WorkbenchRecord[]>;
}

function latestBlockFromDevnet(devnetState: unknown): UnknownRecord | null {
  const blocks = collectionFrom(devnetState, ["blocks"]);
  return blocks.length > 0 ? blocks[blocks.length - 1] : null;
}

function extractControlPlaneState(state: unknown): unknown {
  if (isRecord(state) && isRecord(state.state)) {
    return state.state;
  }

  return state;
}

function normalizeEndpointHint(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  const methodMatch = /^(GET|POST|PUT|PATCH|DELETE|OPTIONS)\s+\/[A-Za-z0-9/_:.-]+$/i.exec(trimmed);
  if (methodMatch) {
    return `${methodMatch[1].toUpperCase()} ${trimmed.slice(methodMatch[1].length).trim()}`;
  }

  if (/^\/[A-Za-z0-9/_:.-]+$/.test(trimmed)) {
    return `GET ${trimmed}`;
  }

  return null;
}

function collectEndpointHints(payload: unknown, depth = 0): string[] {
  if (depth > 4) {
    return [];
  }

  const normalized = normalizeEndpointHint(payload);
  if (normalized) {
    return [normalized];
  }

  if (Array.isArray(payload)) {
    return payload.flatMap((item) => collectEndpointHints(item, depth + 1));
  }

  if (!isRecord(payload)) {
    return [];
  }

  const directMethod = typeof payload.method === "string" ? payload.method.toUpperCase() : null;
  const directPath = typeof payload.path === "string" ? payload.path : typeof payload.route === "string" ? payload.route : null;
  const direct = directMethod && directPath ? normalizeEndpointHint(`${directMethod} ${directPath}`) : null;

  return [
    direct,
    ...Object.entries(payload)
      .filter(([key]) => ["actions", "capabilities", "endpoints", "links", "routes"].includes(key))
      .flatMap(([, value]) => collectEndpointHints(value, depth + 1)),
  ].filter((item): item is string => item !== null);
}

function uniqueEndpoints(...sources: Array<string[] | undefined>): string[] {
  return [...new Set(sources.flatMap((source) => source ?? []))].sort((left, right) => left.localeCompare(right));
}

function getControlPlaneUrl(): string {
  const env = (import.meta as ImportMeta & { env?: Record<string, string | undefined> }).env;
  const configured = env?.VITE_FLOWCHAIN_CONTROL_PLANE_URL?.trim();
  return configured && configured.length > 0 ? configured.replace(/\/+$/, "") : DEFAULT_CONTROL_PLANE_URL;
}

async function fetchJsonWithTimeout(url: string, timeoutMs: number): Promise<unknown> {
  const controller = new AbortController();
  const timeout = globalThis.setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, { cache: "no-store", signal: controller.signal });
    if (!response.ok) {
      throw new Error(`${response.status} ${response.statusText}`.trim());
    }
    return response.json();
  } finally {
    globalThis.clearTimeout(timeout);
  }
}

async function fetchOptionalJson(path: string): Promise<{ value: unknown | null; error?: string }> {
  try {
    return { value: await fetchJsonWithTimeout(path, CONTROL_PLANE_TIMEOUT_MS) };
  } catch (error) {
    return {
      value: null,
      error: error instanceof Error ? error.message : "unknown load error",
    };
  }
}

async function probeControlPlane(): Promise<ControlPlaneProbe> {
  const url = getControlPlaneUrl();
  const checkedAt = new Date().toISOString();
  const defaultEndpoints = ["GET /health", "GET /state"];

  try {
    const health = await fetchJsonWithTimeout(`${url}/health`, CONTROL_PLANE_TIMEOUT_MS);
    let state: unknown | undefined;

    try {
      state = await fetchJsonWithTimeout(`${url}/state`, CONTROL_PLANE_TIMEOUT_MS);
    } catch (error) {
      return {
        url,
        status: "available",
        checkedAt,
        endpoints: uniqueEndpoints(defaultEndpoints, collectEndpointHints(health)),
        health,
        error: `Health endpoint responded, but state endpoint was not loaded: ${
          error instanceof Error ? error.message : "unknown state error"
        }`,
      };
    }

    return {
      url,
      status: "available",
      checkedAt,
      endpoints: uniqueEndpoints(defaultEndpoints, collectEndpointHints(health), collectEndpointHints(state)),
      health,
      state,
    };
  } catch (error) {
    return {
      url,
      status: "not-detected",
      checkedAt,
      endpoints: defaultEndpoints,
      error: error instanceof Error ? error.message : "control-plane API not detected",
    };
  }
}

function buildLocalActions(controlPlane: ControlPlaneProbe): WorkbenchAction[] {
  if (controlPlane.status !== "available") {
    return [];
  }

  const advertised = new Set(controlPlane.endpoints.map((endpoint) => endpoint.toUpperCase()));
  return WORKBENCH_ACTIONS.filter((action) => advertised.has(action.endpoint.toUpperCase()));
}

function buildNodeStatusRecords(data: DashboardData, devnetState: unknown, controlPlane: ControlPlaneProbe): WorkbenchRecord[] {
  const node = buildNodeStatus(data, devnetState, controlPlane);
  const devnet = isRecord(devnetState) ? devnetState : {};
  const config = isRecord(devnet.config) ? devnet.config : {};

  return [
    makeLocalRecord(
      "devnet",
      controlPlane.url,
      {
        id: "local-control-plane",
        kind: "Control-plane API",
        title: node.title,
        summary: node.summary,
        status: node.status,
        facts: [
          ...node.facts,
          { label: "health endpoint", value: controlPlane.status === "available" ? "responded" : "not detected" },
          { label: "state endpoint", value: controlPlane.state ? "loaded" : "not loaded" },
          { label: "error", value: text(controlPlane.error, "none") },
        ],
        raw: { controlPlane, node },
      },
      controlPlane.checkedAt,
    ),
    makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id: "local-chain-state",
      kind: "Private/local chain",
      title: text(devnet.chainId ?? data.chain.chainId),
      summary: "Committed local chain state used by the workbench when the API is offline or partial.",
      status: devnetState ? "finalized" : "stale",
      facts: [
        { label: "genesis hash", value: text(devnet.genesisHash ?? config.genesisHash) },
        { label: "next block", value: text(devnet.nextBlockNumber) },
        { label: "logical time", value: text(devnet.logicalTime ?? config.genesisLogicalTime) },
        { label: "consensus", value: text(config.consensus, "local deterministic") },
        { label: "no value", value: text(config.noValue, "true") },
      ],
      raw: devnetState,
    }),
  ];
}

function buildPeerRecords(devnetState: unknown): WorkbenchRecord[] {
  return collectionFrom(devnetState, ["peers", "networkPeers", "peerState", "nodes"]).map((peer, index) => {
    const id = text(peer.peerId ?? peer.nodeId ?? peer.id ?? peer.address, `peer:${index + 1}`);
    return makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id,
      kind: "Peer",
      title: id,
      summary: text(peer.summary ?? peer.role, "Private/local peer exported by the control-plane."),
      status: statusFrom(peer.status, "observed"),
      facts: [
        { label: "address", value: text(peer.address ?? peer.multiaddr ?? peer.url) },
        { label: "role", value: text(peer.role) },
        { label: "last seen", value: text(peer.lastSeenAt ?? peer.lastSeen) },
        { label: "height", value: text(peer.blockHeight ?? peer.height) },
      ],
      raw: peer,
    });
  });
}

function buildMempoolRecords(devnetState: unknown): WorkbenchRecord[] {
  return collectionFrom(devnetState, ["pendingTxs", "mempool", "txPool", "pendingTransactions"]).map((tx, index) => {
    const id = text(tx.txId ?? tx.hash ?? tx.id, `pending-tx:${index + 1}`);
    return makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id,
      kind: "Pending transaction",
      title: id,
      summary: text(tx.summary ?? tx.kind, "Pending local transaction waiting for deterministic block production."),
      status: statusFrom(tx.status, "pending"),
      facts: [
        { label: "from", value: text(tx.from ?? tx.sender ?? tx.agentId) },
        { label: "type", value: text(tx.type ?? tx.kind) },
        { label: "received", value: text(tx.receivedAt ?? tx.createdAt) },
        { label: "nonce", value: text(tx.nonce) },
      ],
      raw: tx,
    });
  });
}

function buildAccountRecords(devnetState: unknown): WorkbenchRecord[] {
  return collectionFrom(devnetState, ["agentAccounts", "accounts", "accountRegistry"]).map((account, index) => {
    const id = text(account.accountId ?? account.agentId ?? account.id ?? account.controller, `account:${index + 1}`);
    return makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id,
      kind: "Account",
      title: id,
      summary: `Controller ${text(account.controller)} with model ${text(account.modelPassportId ?? account.modelId)}.`,
      status: account.active === false ? "stale" : statusFrom(account.status, "verified"),
      facts: [
        { label: "controller", value: text(account.controller) },
        { label: "model", value: text(account.modelPassportId ?? account.modelId) },
        { label: "metadata hash", value: text(account.metadataHash) },
        { label: "memory root", value: text(account.memoryRoot) },
        { label: "active", value: text(account.active) },
      ],
      raw: account,
    });
  });
}

function buildBalanceRecords(devnetState: unknown): WorkbenchRecord[] {
  return collectionFrom(devnetState, [
    "localTestUnitBalances",
    "balances",
    "accountBalances",
    "balanceSheet",
    "credits",
    "creditBalances",
  ]).map((balance, index) => {
    const id = text(balance.balanceId ?? balance.accountId ?? balance.agentId ?? balance.id, `balance:${index + 1}`);
    return makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id,
      kind: "Local test-unit balance",
      title: id,
      summary: text(balance.summary, "Local no-value balance or credit metadata exported by the private testnet API."),
      status: statusFrom(balance.status, "observed"),
      facts: [
        { label: "account", value: text(balance.accountId ?? balance.agentId) },
        { label: "owner", value: text(balance.owner ?? balance.controller) },
        { label: "amount", value: text(balance.amount ?? balance.balance ?? balance.credits ?? balance.units) },
        { label: "unit", value: text(balance.unit, "no-value local test unit") },
        { label: "faucet total", value: text(balance.totalFaucetUnits) },
        { label: "updated", value: text(balance.updatedAt ?? balance.updatedAtBlock ?? balance.blockNumber) },
      ],
      raw: balance,
    });
  });
}

function buildFaucetEventRecords(devnetState: unknown): WorkbenchRecord[] {
  return collectionFrom(devnetState, ["faucetRecords", "faucetEvents", "faucetClaims", "faucetCredits", "faucet"]).map((event, index) => {
    const id = text(event.eventId ?? event.faucetRecordId ?? event.faucetEventId ?? event.txId ?? event.id, `faucet-event:${index + 1}`);
    return makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id,
      kind: "Faucet event",
      title: id,
      summary: text(event.summary, "Local no-value faucet event exported by the control-plane."),
      status: statusFrom(event.status, "observed"),
      facts: [
        { label: "account", value: text(event.accountId ?? event.agentId ?? event.wallet) },
        { label: "recipient", value: text(event.recipient) },
        { label: "amount", value: text(event.amount ?? event.amountUnits ?? event.credits) },
        { label: "block", value: text(event.blockNumber ?? event.creditedAtBlock) },
        { label: "created", value: text(event.createdAt ?? event.timestamp) },
      ],
      raw: event,
    });
  });
}

function buildWalletMetadataRecords(devnetState: unknown): WorkbenchRecord[] {
  return collectionFrom(devnetState, ["wallets", "walletMetadata", "publicWallets", "publicAccounts", "operatorKeyReferences"]).map((wallet, index) => {
    const id = text(wallet.walletId ?? wallet.keyReferenceId ?? wallet.operatorId ?? wallet.id, `wallet:${index + 1}`);
    return makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id,
      kind: "Public wallet/account metadata",
      title: id,
      summary: text(
        wallet.secretMaterialBoundary ?? wallet.summary,
        "Public wallet/key metadata only. Private keys are intentionally outside browser state.",
      ),
      status: statusFrom(wallet.status, "verified"),
      facts: [
        { label: "operator", value: text(wallet.operatorId ?? wallet.controller) },
        { label: "worker key", value: text(wallet.workerKeyId) },
        { label: "verifier key", value: text(wallet.verifierKeyId) },
        { label: "scheme", value: text(wallet.signatureScheme) },
        { label: "public hint", value: text(wallet.publicKeyHint) },
      ],
      raw: wallet,
    });
  });
}

function buildTokenLaunchRecords(devnetState: unknown): WorkbenchRecord[] {
  return collectionFrom(devnetState, ["tokenLaunches", "tokenDefinitions", "tokens", "localTokens", "launchedTokens"]).map((token, index) => {
    const id = text(token.tokenId ?? token.launchId ?? token.id ?? token.symbol, `token-launch:${index + 1}`);
    return makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id,
      kind: "Token launch",
      title: text(token.symbol ?? token.name ?? id),
      summary: text(
        token.summary,
        "Local/testnet token definition exported for the Product Testnet V1 token-launch surface.",
      ),
      status: token.active === false ? "stale" : statusFrom(token.status, token.active === true ? "verified" : "observed"),
      facts: [
        { label: "token id", value: id },
        { label: "name", value: text(token.name) },
        { label: "symbol", value: text(token.symbol) },
        { label: "issuer", value: text(token.issuer ?? token.owner ?? token.creator) },
        { label: "supply", value: text(token.initialSupply ?? token.supply ?? token.totalSupply) },
        { label: "block", value: text(token.blockNumber ?? token.launchedAtBlock) },
      ],
      raw: token,
    });
  });
}

function buildTokenBalanceRecords(devnetState: unknown): WorkbenchRecord[] {
  return collectionFrom(devnetState, [
    "tokenBalances",
    "tokenAccountBalances",
    "accountTokenBalances",
    "tokenLedger",
    "tokenHoldings",
  ]).map((balance, index) => {
    const id = text(
      balance.balanceId ?? balance.tokenBalanceId ?? balance.id ?? `${text(balance.accountId)}:${text(balance.tokenId ?? balance.symbol)}`,
      `token-balance:${index + 1}`,
    );
    return makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id,
      kind: "Token balance",
      title: id,
      summary: text(balance.summary, "Local/testnet token balance exported by the runtime/control-plane."),
      status: statusFrom(balance.status, "observed"),
      facts: [
        { label: "account", value: text(balance.accountId ?? balance.owner ?? balance.wallet) },
        { label: "token", value: text(balance.tokenId ?? balance.symbol) },
        { label: "amount", value: text(balance.amount ?? balance.balance ?? balance.units) },
        { label: "locked", value: text(balance.locked ?? balance.reserved, "0") },
        { label: "updated", value: text(balance.updatedAt ?? balance.updatedAtBlock ?? balance.blockNumber) },
      ],
      raw: balance,
    });
  });
}

function buildDexPoolRecords(devnetState: unknown): WorkbenchRecord[] {
  return collectionFrom(devnetState, ["dexPools", "pools", "ammPools", "liquidityPools"]).map((pool, index) => {
    const id = text(pool.poolId ?? pool.id ?? `${text(pool.baseToken ?? pool.tokenA)}:${text(pool.quoteToken ?? pool.tokenB)}`, `pool:${index + 1}`);
    return makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id,
      kind: "DEX pool",
      title: id,
      summary: text(pool.summary, "Local/testnet DEX pool exported by the Product Testnet V1 runtime."),
      status: statusFrom(pool.status, pool.active === false ? "stale" : "observed"),
      facts: [
        { label: "base", value: text(pool.baseToken ?? pool.tokenA) },
        { label: "quote", value: text(pool.quoteToken ?? pool.tokenB) },
        { label: "reserve base", value: text(pool.reserveBase ?? pool.reserveA) },
        { label: "reserve quote", value: text(pool.reserveQuote ?? pool.reserveB) },
        { label: "lp supply", value: text(pool.lpSupply ?? pool.totalShares) },
        { label: "fee bps", value: text(pool.feeBps ?? pool.fee, "local default") },
      ],
      raw: pool,
    });
  });
}

function buildLiquidityPositionRecords(devnetState: unknown): WorkbenchRecord[] {
  return collectionFrom(devnetState, [
    "liquidityPositions",
    "lpPositions",
    "positions",
    "liquidityEvents",
    "liquidityReceipts",
  ]).map((position, index) => {
    const id = text(position.positionId ?? position.lpPositionId ?? position.id, `liquidity:${index + 1}`);
    return makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id,
      kind: "Liquidity position",
      title: id,
      summary: text(position.summary, "Local/testnet liquidity position or liquidity receipt."),
      status: statusFrom(position.status, "observed"),
      facts: [
        { label: "owner", value: text(position.owner ?? position.accountId ?? position.wallet) },
        { label: "pool", value: text(position.poolId) },
        { label: "shares", value: text(position.shares ?? position.lpTokens) },
        { label: "amount base", value: text(position.amountBase ?? position.amountA) },
        { label: "amount quote", value: text(position.amountQuote ?? position.amountB) },
        { label: "block", value: text(position.blockNumber ?? position.updatedAtBlock) },
      ],
      raw: position,
    });
  });
}

function buildSwapRecords(devnetState: unknown): WorkbenchRecord[] {
  return collectionFrom(devnetState, ["swaps", "swapReceipts", "swapEvents", "dexSwaps"]).map((swap, index) => {
    const id = text(swap.swapId ?? swap.receiptId ?? swap.txId ?? swap.id, `swap:${index + 1}`);
    return makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id,
      kind: "Swap",
      title: id,
      summary: text(swap.summary, "Local/testnet swap receipt exported by the DEX runtime/control-plane."),
      status: statusFrom(swap.status, "observed"),
      facts: [
        { label: "trader", value: text(swap.trader ?? swap.accountId ?? swap.wallet) },
        { label: "pool", value: text(swap.poolId) },
        { label: "token in", value: text(swap.tokenIn) },
        { label: "amount in", value: text(swap.amountIn) },
        { label: "token out", value: text(swap.tokenOut) },
        { label: "amount out", value: text(swap.amountOut) },
      ],
      raw: swap,
    });
  });
}

function bridgeFixtureRecords(kind: "deposits" | "credits" | "withdrawals", bridgeTestDeposit: unknown | null): UnknownRecord[] {
  if (kind !== "deposits" || !isRecord(bridgeTestDeposit)) {
    return [];
  }

  return [bridgeTestDeposit];
}

function buildBridgeRecords(
  devnetState: unknown,
  kind: "deposits" | "credits" | "withdrawals",
  bridgeTestDeposit: unknown | null = null,
): WorkbenchRecord[] {
  const keyMap = {
    deposits: ["bridgeDeposits", "deposits"],
    credits: ["bridgeCredits", "bridgeCreditEvents"],
    withdrawals: ["bridgeWithdrawals", "withdrawals"],
  } satisfies Record<typeof kind, string[]>;

  return [...collectionFrom(devnetState, keyMap[kind]), ...bridgeFixtureRecords(kind, bridgeTestDeposit)].map((event, index) => {
    const id = text(event.bridgeEventId ?? event.depositId ?? event.creditId ?? event.withdrawalId ?? event.id, `bridge-${kind}:${index + 1}`);
    const fixturePath = event === bridgeTestDeposit ? WORKBENCH_BRIDGE_TEST_DEPOSIT_PATH : WORKBENCH_DEVNET_STATE_PATH;
    return makeRecord("devnet", fixturePath, {
      id,
      kind: `Bridge ${kind.slice(0, -1)}`,
      title: id,
      summary: text(event.summary, "Private/local or Base Sepolia bridge lifecycle test object exported for workbench inspection."),
      status: statusFrom(event.status, "pending"),
      facts: [
        { label: "account", value: text(event.accountId ?? event.wallet ?? event.recipient ?? event.flowchainRecipient) },
        { label: "amount", value: text(event.amount) },
        { label: "source", value: text(event.sourceChain ?? event.sourceChainId ?? event.fromChain) },
        { label: "destination", value: text(event.destinationChain ?? event.toChain) },
        { label: "tx hash", value: text(event.txHash) },
        { label: "block", value: text(event.blockNumber) },
      ],
      raw: event,
    });
  });
}

function buildBlockRecords(data: DashboardData, devnetState: unknown): WorkbenchRecord[] {
  const blocks = collectionFrom(devnetState, ["blocks"]);

  if (blocks.length > 0) {
    return blocks
      .map((block) => {
        const receipts = recordValues(block.receipts);
        const txIds = stringArray(block.txIds);
        const failedReceipt = receipts.some((receipt) => statusFrom(receipt.status) === "failed");
        const blockNumber = text(block.blockNumber);

        return makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
          id: text(block.blockHash, `block:${blockNumber}`),
          kind: "Block",
          title: `Block ${blockNumber}`,
          summary: `${txIds.length} transactions, ${receipts.length} receipts, state root ${text(block.stateRoot)}`,
          status: failedReceipt ? "failed" : "finalized",
          facts: [
            { label: "block hash", value: text(block.blockHash) },
            { label: "parent hash", value: text(block.parentHash) },
            { label: "state root", value: text(block.stateRoot) },
            { label: "logical time", value: text(block.logicalTime) },
            { label: "transactions", value: txIds.length.toString() },
            { label: "receipts", value: receipts.length.toString() },
          ],
          raw: block,
        });
      })
      .sort((left, right) => Number(right.title.replace("Block ", "")) - Number(left.title.replace("Block ", "")));
  }

  return data.devnetBlocks.map((block) =>
    makeRecord("devnet", data.metadata.fixturePath, {
      id: block.blockHash,
      kind: "Block",
      title: `Block ${block.blockNumber}`,
      summary: `${block.observationCount} observations and ${block.reportCount} reports in the dashboard fixture window.`,
      status: block.status,
      facts: [
        { label: "block hash", value: block.blockHash },
        { label: "parent hash", value: block.parentHash },
        { label: "state root", value: block.stateRoot },
        { label: "receipts root", value: block.receiptsRoot },
        { label: "finality distance", value: block.finalityDistance.toString() },
      ],
      raw: block,
    }),
  );
}

function buildTransactionRecords(data: DashboardData, devnetState: unknown): WorkbenchRecord[] {
  const blocks = collectionFrom(devnetState, ["blocks"]);
  const records: WorkbenchRecord[] = [];

  for (const block of blocks) {
    const txIds = stringArray(block.txIds);
    const receipts = recordValues(block.receipts);
    const blockNumber = text(block.blockNumber);

    txIds.forEach((txId, index) => {
      const receipt = receipts.find((candidate) => text(candidate.txId) === txId) ?? receipts[index];
      const receiptStatus = statusFrom(receipt?.status, "pending");
      records.push(
        makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
          id: txId,
          kind: "Transaction",
          title: txId,
          summary: receipt ? `Receipt ${text(receipt.status)} in block ${blockNumber}.` : `Pending transaction in block ${blockNumber}.`,
          status: receiptStatus === "verified" ? "finalized" : receiptStatus,
          facts: [
            { label: "block", value: blockNumber },
            { label: "receipt status", value: text(receipt?.status, "pending") },
            { label: "error", value: text(receipt?.error, "none") },
            { label: "block hash", value: text(block.blockHash) },
          ],
          raw: { txId, receipt, block },
        }),
      );
    });
  }

  if (records.length > 0) {
    return records;
  }

  return data.flowPulseObservations.map((observation) =>
    makeRecord("indexer", data.metadata.fixturePath, {
      id: `${observation.txHash}:${observation.logIndex}`,
      kind: "Receipt-derived transaction",
      title: observation.txHash,
      summary: observation.summary,
      status: statusFrom(observation.receiptStatus, observation.status),
      facts: [
        { label: "block", value: observation.blockNumber },
        { label: "log index", value: observation.logIndex },
        { label: "pulse type", value: observation.pulseType },
        { label: "rootfield", value: observation.rootfieldId },
      ],
      raw: observation,
    }),
  );
}

function buildExplorerRecords(data: DashboardData, devnetState: unknown, bridgeTestDeposit: unknown | null): WorkbenchRecord[] {
  const explorerRecords = [
    ...buildBlockRecords(data, devnetState).slice(0, 4),
    ...buildTransactionRecords(data, devnetState).slice(0, 8),
    ...buildReceiptRecords(data, devnetState).slice(0, 6),
    ...buildTokenLaunchRecords(devnetState).slice(0, 4),
    ...buildTokenBalanceRecords(devnetState).slice(0, 4),
    ...buildDexPoolRecords(devnetState).slice(0, 4),
    ...buildLiquidityPositionRecords(devnetState).slice(0, 4),
    ...buildSwapRecords(devnetState).slice(0, 4),
    ...buildBridgeRecords(devnetState, "deposits", bridgeTestDeposit).slice(0, 4),
    ...buildBridgeRecords(devnetState, "credits", bridgeTestDeposit).slice(0, 4),
    ...buildBridgeRecords(devnetState, "withdrawals", bridgeTestDeposit).slice(0, 4),
  ];

  return explorerRecords.map((record) => ({
    ...record,
    id: `explorer:${record.kind}:${record.id}`,
    kind: `Explorer ${record.kind}`,
    summary: `Explorer index projection: ${record.summary}`,
  }));
}

function buildRootfieldRecords(data: DashboardData, devnetState: unknown): WorkbenchRecord[] {
  const devnetRootfields = collectionFrom(devnetState, ["rootfields", "rootfieldState", "rootfieldsById"]).map((rootfield, index) => {
    const id = text(rootfield.rootfieldId ?? rootfield.id, `rootfield:${index + 1}`);
    const isActive = rootfield.active === true;

    return makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id,
      kind: "Local Rootfield",
      title: id,
      summary: isActive
        ? `Active local namespace owned by ${text(rootfield.owner)}.`
        : `Local namespace exported by the private testnet state.`,
      status: rootfield.active === false ? "stale" : statusFrom(rootfield.status, isActive ? "verified" : "observed"),
      facts: [
        { label: "owner", value: text(rootfield.owner) },
        { label: "latest root", value: text(rootfield.latestRoot) },
        { label: "schema hash", value: text(rootfield.schemaHash) },
        { label: "metadata hash", value: text(rootfield.metadataHash) },
        { label: "pulse count", value: text(rootfield.pulseCount) },
        { label: "root count", value: text(rootfield.rootCount) },
      ],
      raw: rootfield,
    });
  });

  const dashboardRootfields = data.rootfields.map((rootfield) =>
    makeRecord("devnet", data.metadata.fixturePath, {
      id: rootfield.rootfieldId,
      kind: "Dashboard Rootfield",
      title: rootfield.rootfieldId,
      summary: `Dashboard fixture namespace with latest root ${rootfield.latestRoot}.`,
      status: rootfield.status,
      facts: [
        { label: "owner", value: rootfield.owner },
        { label: "latest root", value: rootfield.latestRoot },
        { label: "schema hash", value: rootfield.schemaHash },
        { label: "metadata hash", value: rootfield.metadataHash },
        { label: "pulse count", value: rootfield.pulseCount.toString() },
        { label: "work lanes", value: rootfield.workLaneIds.join(", ") || "none" },
      ],
      raw: rootfield,
    }),
  );

  return [...devnetRootfields, ...dashboardRootfields];
}

function buildAgentRecords(data: DashboardData, devnetState: unknown): WorkbenchRecord[] {
  const agents = new Map<string, { roles: Set<string>; raw: unknown[] }>();

  const addAgent = (id: unknown, role: string, raw: unknown) => {
    const agentId = text(id, "");
    if (agentId.length === 0 || agentId === "not recorded") {
      return;
    }
    const current = agents.get(agentId) ?? { roles: new Set<string>(), raw: [] };
    current.roles.add(role);
    current.raw.push(raw);
    agents.set(agentId, current);
  };

  data.rootfields.forEach((rootfield) => addAgent(rootfield.owner, "rootfield owner", rootfield));
  data.workLanes.forEach((lane) => addAgent(lane.operator, "work-lane operator", lane));
  data.flowPulseObservations.forEach((observation) => addAgent(observation.actor, "FlowPulse actor", observation));

  collectionFrom(devnetState, ["workReceipts"]).forEach((receipt) => addAgent(receipt.workerId, "worker", receipt));
  collectionFrom(devnetState, ["verifierReports"]).forEach((report) => addAgent(report.verifierId, "verifier", report));

  return [...agents.entries()].map(([agentId, agent]) =>
    makeRecord("devnet", data.metadata.fixturePath, {
      id: agentId,
      kind: "Agent identity",
      title: agentId,
      summary: [...agent.roles].join(", "),
      status: "verified",
      facts: [
        { label: "roles", value: [...agent.roles].join(", ") },
        { label: "references", value: agent.raw.length.toString() },
        { label: "source", value: "fixture projection" },
      ],
      raw: agent.raw,
    }),
  );
}

function buildModelRecords(devnetState: unknown): WorkbenchRecord[] {
  return collectionFrom(devnetState, ["models", "modelPassports", "modelPassportsById"]).map((model, index) => {
    const id = text(model.modelId ?? model.passportId ?? model.id, `model:${index + 1}`);

    return makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id,
      kind: "ModelPassport",
      title: id,
      summary: text(model.summary ?? model.description ?? model.name, "Model passport exported by the control-plane/devnet state."),
      status: statusFrom(model.status, "observed"),
      facts: [
        { label: "publisher", value: text(model.publisher ?? model.owner ?? model.agentId) },
        { label: "model hash", value: text(model.modelHash ?? model.commitment ?? model.digest) },
        { label: "created", value: text(model.createdAt ?? model.registeredAt) },
      ],
      raw: model,
    });
  });
}

function buildReceiptRecords(data: DashboardData, devnetState: unknown): WorkbenchRecord[] {
  const dashboardReceipts = data.workReceipts.map((receipt) =>
    makeRecord("worker", data.metadata.fixturePath, {
      id: receipt.receiptId,
      kind: "WorkReceipt",
      title: receipt.receiptId,
      summary: `${receipt.workType} for lane ${receipt.laneId}.`,
      status: receipt.status,
      facts: [
        { label: "lane", value: receipt.laneId },
        { label: "rootfield", value: receipt.rootfieldId },
        { label: "artifact", value: receipt.artifactUri },
        { label: "result hash", value: receipt.resultHash },
        { label: "report", value: text(receipt.reportId) },
      ],
      raw: receipt,
    }),
  );

  const devnetReceipts = collectionFrom(devnetState, ["workReceipts"]).map((receipt) =>
    makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id: text(receipt.receiptId),
      kind: "Devnet WorkReceipt",
      title: text(receipt.receiptId),
      summary: `Worker ${text(receipt.workerId)} moved ${text(receipt.inputRoot)} to ${text(receipt.outputRoot)}.`,
      status: "verified",
      facts: [
        { label: "worker", value: text(receipt.workerId) },
        { label: "rootfield", value: text(receipt.rootfieldId) },
        { label: "input root", value: text(receipt.inputRoot) },
        { label: "output root", value: text(receipt.outputRoot) },
        { label: "artifact commitment", value: text(receipt.artifactCommitment) },
      ],
      raw: receipt,
    }),
  );

  return [...dashboardReceipts, ...devnetReceipts];
}

function buildMemoryCellRecords(data: DashboardData, devnetState: unknown): WorkbenchRecord[] {
  const nativeCells = collectionFrom(devnetState, ["memoryCells", "memoryCellState", "cells"]);
  if (nativeCells.length > 0) {
    return nativeCells.map((cell, index) => {
      const id = text(cell.cellId ?? cell.memoryCellId ?? cell.id, `memory-cell:${index + 1}`);
      return makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
        id,
        kind: "MemoryCell",
        title: id,
        summary: text(cell.summary ?? cell.description, "Native MemoryCell exported by the local/private testnet state."),
        status: statusFrom(cell.status, "observed"),
        facts: [
          { label: "rootfield", value: text(cell.rootfieldId) },
          { label: "latest root", value: text(cell.latestRoot ?? cell.root) },
          { label: "receipt", value: text(cell.receiptId) },
          { label: "updated", value: text(cell.updatedAt) },
        ],
        raw: cell,
      });
    });
  }

  return data.rootfieldBundles.map((bundle) =>
    makeRecord("devnet", data.metadata.fixturePath, {
      id: `memory-cell-projection:${bundle.rootfieldId}`,
      kind: "Memory cell projection",
      title: bundle.rootfieldId,
      summary: "Derived from the existing RootfieldBundle until native MemoryCell objects are exported by the runtime API.",
      status: bundle.status,
      facts: [
        { label: "latest root", value: bundle.latestRoot },
        { label: "signals", value: bundle.memorySignalIds.length.toString() },
        { label: "receipts", value: bundle.memoryReceiptIds.length.toString() },
        { label: "transitions", value: bundle.transitionIds.length.toString() },
        { label: "latest transition", value: text(bundle.latestTransitionId) },
      ],
      raw: bundle,
    }),
  );
}

function buildArtifactRecords(data: DashboardData, devnetState: unknown): WorkbenchRecord[] {
  const artifacts = collectionFrom(devnetState, ["artifactCommitments", "artifacts", "artifactAvailabilityProofs"]).map((artifact) =>
    makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id: text(artifact.artifactId ?? artifact.id ?? artifact.proofId),
      kind: "Artifact",
      title: text(artifact.artifactId ?? artifact.id ?? artifact.proofId),
      summary: text(artifact.uriHint ?? artifact.uri ?? artifact.evidenceURI, "Artifact commitment from local devnet state."),
      status: statusFrom(artifact.status, "verified"),
      facts: [
        { label: "rootfield", value: text(artifact.rootfieldId) },
        { label: "commitment", value: text(artifact.commitment ?? artifact.artifactCommitment) },
        { label: "uri", value: text(artifact.uriHint ?? artifact.uri ?? artifact.evidenceURI) },
      ],
      raw: artifact,
    }),
  );

  const receiptArtifacts = data.workReceipts.map((receipt) =>
    makeRecord("worker", data.metadata.fixturePath, {
      id: `${receipt.receiptId}:artifact`,
      kind: "Receipt artifact reference",
      title: receipt.artifactUri,
      summary: `Referenced by work receipt ${receipt.receiptId}.`,
      status: receipt.status,
      facts: [
        { label: "receipt", value: receipt.receiptId },
        { label: "result hash", value: receipt.resultHash },
        { label: "rootfield", value: receipt.rootfieldId },
      ],
      raw: receipt,
    }),
  );

  return [...artifacts, ...receiptArtifacts];
}

function buildVerifierModuleRecords(data: DashboardData, devnetState: unknown): WorkbenchRecord[] {
  const nativeModules = collectionFrom(devnetState, [
    "verifierModules",
    "verifierModuleRegistry",
    "verifierModulesById",
    "verifiers",
  ]).map((module, index) => {
    const id = text(module.moduleId ?? module.verifierModuleId ?? module.verifierId ?? module.id, `verifier-module:${index + 1}`);

    return makeRecord("verifier", WORKBENCH_DEVNET_STATE_PATH, {
      id,
      kind: "VerifierModule",
      title: id,
      summary: text(module.summary ?? module.description, "Verifier module exported by the local control-plane/devnet state."),
      status: statusFrom(module.status, "observed"),
      facts: [
        { label: "owner", value: text(module.owner ?? module.operator ?? module.verifierId) },
        { label: "spec", value: text(module.specVersion ?? module.verifierSpecVersion ?? module.version) },
        { label: "policy", value: text(module.resolverPolicyId ?? module.policyId) },
        { label: "registered", value: text(module.registeredAt ?? module.createdAt) },
      ],
      raw: module,
    });
  });

  if (nativeModules.length > 0) {
    return nativeModules;
  }

  const derived = new Map<string, { reports: number; statuses: Set<DashboardStatus>; raw: unknown[]; policy: string; spec: string }>();

  for (const report of data.verifierReports) {
    const key = `${report.resolverPolicyId}:${report.verifierSpecVersion}`;
    const current =
      derived.get(key) ??
      ({
        reports: 0,
        statuses: new Set<DashboardStatus>(),
        raw: [],
        policy: report.resolverPolicyId,
        spec: report.verifierSpecVersion,
      } satisfies { reports: number; statuses: Set<DashboardStatus>; raw: unknown[]; policy: string; spec: string });
    current.reports += 1;
    current.statuses.add(report.status);
    current.raw.push(report);
    derived.set(key, current);
  }

  for (const report of collectionFrom(devnetState, ["verifierReports"])) {
    const verifierId = text(report.verifierId, "verifier:local");
    const key = `${verifierId}:${text(report.rootfieldId)}`;
    const current =
      derived.get(key) ??
      ({
        reports: 0,
        statuses: new Set<DashboardStatus>(),
        raw: [],
        policy: text(report.rootfieldId),
        spec: "local-devnet",
      } satisfies { reports: number; statuses: Set<DashboardStatus>; raw: unknown[]; policy: string; spec: string });
    current.reports += 1;
    current.statuses.add(statusFrom(report.status, "observed"));
    current.raw.push(report);
    derived.set(key, current);
  }

  return [...derived.entries()].map(([id, module]) =>
    makeRecord("verifier", data.metadata.fixturePath, {
      id,
      kind: "Verifier module projection",
      title: id,
      summary: `Derived from ${module.reports} verifier report(s) until explicit VerifierModule objects are exported.`,
      status: module.statuses.has("failed")
        ? "failed"
        : module.statuses.has("unresolved")
          ? "unresolved"
          : module.statuses.has("unsupported")
            ? "unsupported"
            : "verified",
      facts: [
        { label: "reports", value: module.reports.toString() },
        { label: "policy", value: module.policy },
        { label: "spec", value: module.spec },
        { label: "statuses", value: [...module.statuses].join(", ") || "none" },
      ],
      raw: module.raw,
    }),
  );
}

function buildVerifierRecords(data: DashboardData, devnetState: unknown): WorkbenchRecord[] {
  const dashboardReports = data.verifierReports.map((report) =>
    makeRecord("verifier", data.metadata.fixturePath, {
      id: report.reportId,
      kind: "VerifierReport",
      title: report.reportId,
      summary: `${report.checksPassed}/${report.checksTotal} checks passed; ${
        report.reasonCodes.join(", ") || "no reason codes"
      }.`,
      status: report.status,
      facts: [
        { label: "rootfield", value: report.rootfieldId },
        { label: "observation", value: report.observationId },
        { label: "policy", value: report.resolverPolicyId },
        { label: "report hash", value: report.reportHash },
      ],
      raw: report,
    }),
  );

  const devnetReports = collectionFrom(devnetState, ["verifierReports"]).map((report) =>
    makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id: text(report.reportId),
      kind: "Devnet VerifierReport",
      title: text(report.reportId),
      summary: `Verifier ${text(report.verifierId)} reported ${text(report.status)} for ${text(report.receiptId)}.`,
      status: statusFrom(report.status, "observed"),
      facts: [
        { label: "verifier", value: text(report.verifierId) },
        { label: "receipt", value: text(report.receiptId) },
        { label: "rootfield", value: text(report.rootfieldId) },
        { label: "digest", value: text(report.reportDigest) },
        { label: "reasons", value: stringArray(report.reasonCodes).join(", ") || "none" },
      ],
      raw: report,
    }),
  );

  return [...dashboardReports, ...devnetReports];
}

function buildChallengeRecords(devnetState: unknown): WorkbenchRecord[] {
  return collectionFrom(devnetState, ["challenges", "challengeState", "openChallenges"]).map((challenge, index) => {
    const id = text(challenge.challengeId ?? challenge.id, `challenge:${index + 1}`);
    return makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id,
      kind: "Challenge",
      title: id,
      summary: text(challenge.summary ?? challenge.reason, "Challenge exported by local/private testnet state."),
      status: statusFrom(challenge.status, "pending"),
      facts: [
        { label: "receipt", value: text(challenge.receiptId) },
        { label: "report", value: text(challenge.reportId) },
        { label: "opened by", value: text(challenge.openedBy ?? challenge.challenger) },
        { label: "resolved at", value: text(challenge.resolvedAt) },
      ],
      raw: challenge,
    });
  });
}

function buildFinalityRecords(data: DashboardData, devnetState: unknown): WorkbenchRecord[] {
  const records: WorkbenchRecord[] = [
    makeRecord("devnet", data.metadata.fixturePath, {
      id: "dashboard-finality-window",
      kind: "Finality window",
      title: `${data.chain.finalizedBlock} finalized`,
      summary: `Dashboard fixture head is ${data.chain.currentBlock}; finalized through ${data.chain.finalizedBlock}.`,
      status: data.chain.currentBlock > data.chain.finalizedBlock ? "pending" : "finalized",
      facts: [
        { label: "chain", value: data.chain.chainId },
        { label: "head", value: data.chain.currentBlock.toString() },
        { label: "finalized", value: data.chain.finalizedBlock.toString() },
        { label: "settlement context", value: data.chain.settlementContext },
      ],
      raw: data.chain,
    }),
  ];

  collectionFrom(devnetState, ["baseAnchors"]).forEach((anchor) => {
    records.push(
      makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
        id: text(anchor.anchorId),
        kind: "Local anchor",
        title: text(anchor.anchorId),
        summary: `Blocks ${text(anchor.blockRangeStart)}-${text(anchor.blockRangeEnd)} are marked ${text(anchor.finalityStatus)}.`,
        status: statusFrom(anchor.finalityStatus, "pending"),
        facts: [
          { label: "appchain", value: text(anchor.appchainChainId) },
          { label: "state root", value: text(anchor.stateRoot) },
          { label: "work receipt root", value: text(anchor.workReceiptRoot) },
          { label: "verifier root", value: text(anchor.verifierReportRoot) },
          { label: "previous anchor", value: text(anchor.previousAnchorId) },
        ],
        raw: anchor,
      }),
    );
  });

  return records;
}

function buildHardwareSignalRecords(data: DashboardData, devnetState: unknown): WorkbenchRecord[] {
  const nativeSignals = collectionFrom(devnetState, [
    "hardwareSignals",
    "hardwareHeartbeats",
    "heartbeats",
    "signals",
    "loraSignals",
    "meshtasticSignals",
  ]).map((signal, index) => {
    const id = text(signal.signalId ?? signal.heartbeatId ?? signal.nodeId ?? signal.id, `hardware-signal:${index + 1}`);

    return makeRecord("hardware", WORKBENCH_DEVNET_STATE_PATH, {
      id,
      kind: "Hardware signal",
      title: id,
      summary: text(signal.summary ?? signal.message, "Low-bandwidth hardware/control signal from local state."),
      status: statusFrom(signal.status, "observed"),
      facts: [
        { label: "node", value: text(signal.nodeId ?? signal.callsign) },
        { label: "transport", value: text(signal.transport ?? signal.radio ?? signal.channel) },
        { label: "received", value: text(signal.receivedAt ?? signal.lastHeartbeatAt ?? signal.timestamp) },
        { label: "rssi", value: text(signal.signalDbm ?? signal.rssiDbm) },
      ],
      raw: signal,
    });
  });

  const dashboardSignals = data.hardwareNodes.map((node) =>
    makeRecord("hardware", data.metadata.fixturePath, {
      id: node.nodeId,
      kind: "Hardware heartbeat",
      title: node.callsign,
      summary: `${node.role} over ${node.transport}; ${node.locationHint}.`,
      status: node.status,
      facts: [
        { label: "node id", value: node.nodeId },
        { label: "firmware", value: node.firmware },
        { label: "transport", value: node.transport },
        { label: "heartbeat", value: text(node.lastHeartbeatAt) },
        { label: "battery", value: node.batteryPercent === undefined ? "not recorded" : `${node.batteryPercent}%` },
        { label: "signal", value: node.signalDbm === undefined ? "not recorded" : `${node.signalDbm} dBm` },
      ],
      raw: node,
    }),
  );

  return [...nativeSignals, ...dashboardSignals];
}

function topLevelKeys(value: unknown): string {
  return isRecord(value) ? Object.keys(value).sort().join(", ") : "not loaded";
}

function buildRawJsonRecords(
  data: DashboardData,
  controlPlane: ControlPlaneProbe,
  devnetState: unknown | null,
  devnetDashboardState: unknown | null,
  bridgeTestDeposit: unknown | null,
): WorkbenchRecord[] {
  return [
    makeRecord("indexer", data.metadata.fixturePath, {
      id: "raw-dashboard-fixture",
      kind: "Raw JSON",
      title: data.metadata.runtimeDataPath,
      summary: "Primary dashboard runtime fixture loaded by the app.",
      status: "verified",
      facts: [
        { label: "schema", value: data.metadata.schema },
        { label: "mode", value: data.metadata.mode },
        { label: "keys", value: topLevelKeys(data) },
      ],
      raw: data,
    }),
    makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id: "raw-devnet-state",
      kind: "Raw JSON",
      title: WORKBENCH_DEVNET_STATE_PATH,
      summary: devnetState ? "Launch-core local devnet state loaded." : "Launch-core local devnet state was not loaded.",
      status: devnetState ? "verified" : "unresolved",
      facts: [
        { label: "schema", value: isRecord(devnetState) ? text(devnetState.schema) : "missing" },
        { label: "keys", value: topLevelKeys(devnetState) },
      ],
      raw: devnetState,
    }),
    makeRecord("devnet", WORKBENCH_DEVNET_DASHBOARD_STATE_PATH, {
      id: "raw-devnet-dashboard-state",
      kind: "Raw JSON",
      title: WORKBENCH_DEVNET_DASHBOARD_STATE_PATH,
      summary: devnetDashboardState
        ? "Launch-core devnet dashboard projection loaded."
        : "Launch-core devnet dashboard projection was not loaded.",
      status: devnetDashboardState ? "verified" : "unresolved",
      facts: [
        { label: "schema", value: isRecord(devnetDashboardState) ? text(devnetDashboardState.schema) : "missing" },
        { label: "keys", value: topLevelKeys(devnetDashboardState) },
      ],
      raw: devnetDashboardState,
    }),
    makeRecord("devnet", WORKBENCH_BRIDGE_TEST_DEPOSIT_PATH, {
      id: "raw-bridge-test-deposit",
      kind: "Raw JSON",
      title: WORKBENCH_BRIDGE_TEST_DEPOSIT_PATH,
      summary: bridgeTestDeposit
        ? "Bridge test-deposit fixture loaded for the local/testnet bridge record surface."
        : "Bridge test-deposit fixture was not loaded.",
      status: bridgeTestDeposit ? "verified" : "unresolved",
      facts: [
        { label: "schema", value: isRecord(bridgeTestDeposit) ? text(bridgeTestDeposit.schema) : "missing" },
        { label: "keys", value: topLevelKeys(bridgeTestDeposit) },
      ],
      raw: bridgeTestDeposit,
    }),
    makeLocalRecord(
      "indexer",
      controlPlane.url,
      {
        id: "raw-control-plane",
        kind: "Raw JSON",
        title: controlPlane.url,
        summary:
          controlPlane.status === "available"
            ? "Control-plane health/state payloads loaded or partially loaded."
            : "Control-plane API not detected; no local API JSON was loaded.",
        status: controlPlane.status === "available" ? "verified" : "offline",
        facts: [
          { label: "status", value: controlPlane.status },
          { label: "health keys", value: topLevelKeys(controlPlane.health) },
          { label: "state keys", value: topLevelKeys(controlPlane.state) },
          { label: "error", value: text(controlPlane.error, "none") },
        ],
        raw: {
          health: controlPlane.health ?? null,
          state: controlPlane.state ?? null,
          error: controlPlane.error ?? null,
        },
      },
      controlPlane.checkedAt,
    ),
  ];
}

function buildProvenanceRecords(
  data: DashboardData,
  controlPlane: ControlPlaneProbe,
  devnetState: unknown | null,
  devnetDashboardState: unknown | null,
  bridgeTestDeposit: unknown | null,
): WorkbenchRecord[] {
  return [
    makeLocalRecord(
      "indexer",
      controlPlane.url,
      {
        id: "control-plane-api",
        kind: "Control-plane integration",
        title: controlPlane.url,
        summary:
          controlPlane.status === "available"
            ? "Control-plane health endpoint responded; state endpoint is used when present."
            : "Control-plane API was not detected; the workbench is rendering deterministic fixture fallback.",
        status: controlPlane.status === "available" ? "verified" : "offline",
        facts: [
          { label: "status", value: controlPlane.status },
          { label: "checked", value: controlPlane.checkedAt },
          { label: "endpoints", value: controlPlane.endpoints.join(", ") },
          { label: "error", value: text(controlPlane.error, "none") },
        ],
        raw: controlPlane,
      },
      controlPlane.checkedAt,
    ),
    makeRecord("indexer", data.metadata.fixturePath, {
      id: "dashboard-fixture",
      kind: "Dashboard fixture",
      title: data.metadata.fixturePath,
      summary: data.metadata.description,
      status: "verified",
      facts: [
        { label: "runtime copy", value: data.metadata.runtimeDataPath },
        { label: "generated", value: data.metadata.generatedAt },
        { label: "mode", value: data.metadata.mode },
      ],
      raw: data.metadata,
    }),
    makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id: "devnet-state-fixture",
      kind: "Devnet state fixture",
      title: WORKBENCH_DEVNET_STATE_PATH,
      summary: devnetState ? "Existing launch-core devnet state loaded into the workbench." : "Devnet state fixture was not loaded.",
      status: devnetState ? "verified" : "unresolved",
      facts: [
        { label: "schema", value: isRecord(devnetState) ? text(devnetState.schema) : "missing" },
        { label: "source", value: "fixtures/launch-core/generated/devnet/state.json" },
      ],
      raw: devnetState,
    }),
    makeRecord("devnet", WORKBENCH_DEVNET_DASHBOARD_STATE_PATH, {
      id: "devnet-dashboard-state-fixture",
      kind: "Devnet dashboard-state fixture",
      title: WORKBENCH_DEVNET_DASHBOARD_STATE_PATH,
      summary: devnetDashboardState
        ? "Existing devnet dashboard-state fixture loaded for raw/provenance inspection."
        : "Devnet dashboard-state fixture was not loaded.",
      status: devnetDashboardState ? "verified" : "unresolved",
      facts: [
        { label: "schema", value: isRecord(devnetDashboardState) ? text(devnetDashboardState.schema) : "missing" },
        { label: "source", value: "fixtures/launch-core/generated/devnet/dashboard-state.json" },
      ],
      raw: devnetDashboardState,
    }),
    makeRecord("devnet", WORKBENCH_BRIDGE_TEST_DEPOSIT_PATH, {
      id: "bridge-test-deposit-fixture",
      kind: "Bridge fixture",
      title: WORKBENCH_BRIDGE_TEST_DEPOSIT_PATH,
      summary: bridgeTestDeposit
        ? "Existing bridge test-deposit fixture is available for bridge/explorer views."
        : "Bridge test-deposit fixture was not loaded.",
      status: bridgeTestDeposit ? "verified" : "unresolved",
      facts: [
        { label: "schema", value: isRecord(bridgeTestDeposit) ? text(bridgeTestDeposit.schema) : "missing" },
        { label: "source", value: "fixtures/bridge/test deposit runtime copy" },
      ],
      raw: bridgeTestDeposit,
    }),
  ];
}

function buildNodeStatus(data: DashboardData, devnetState: unknown, controlPlane: ControlPlaneProbe): WorkbenchNodeStatus {
  const latestBlock = latestBlockFromDevnet(devnetState);
  const devnet = isRecord(devnetState) ? devnetState : {};
  const nextBlockNumber = numberValue(devnet.nextBlockNumber);
  const blockHeight = nextBlockNumber !== null ? Math.max(0, nextBlockNumber - 1) : data.chain.currentBlock;
  const stateRoot = text(latestBlock?.stateRoot ?? devnet.stateRoot ?? data.devnetBlocks[0]?.stateRoot);
  const pendingTxs = recordValues(devnet.pendingTxs).length;
  const status: DashboardStatus = controlPlane.status === "available" ? "verified" : "offline";

  return {
    status,
    title: controlPlane.status === "available" ? "Control-plane detected" : "Control-plane offline",
    summary:
      controlPlane.status === "available"
        ? "The local API health endpoint responded. The workbench will use API state when the state endpoint is available."
        : "No local API responded at the configured URL, so this screen is rendering committed deterministic fixtures.",
    facts: [
      { label: "chain id", value: text(devnet.chainId ?? data.chain.chainId) },
      { label: "block height", value: blockHeight.toString() },
      { label: "genesis hash", value: text(devnet.genesisHash) },
      { label: "parent/head hash", value: text(devnet.parentHash ?? latestBlock?.blockHash) },
      { label: "state root", value: stateRoot },
      { label: "pending txs", value: pendingTxs.toString() },
      { label: "api url", value: controlPlane.url },
    ],
  };
}

function buildSetupSteps(controlPlane: ControlPlaneProbe): WorkbenchSetupStep[] {
  return [
    {
      command: "npm install",
      label: "Install workspace dependencies",
      state: "available",
      detail: "Required before running launch, service, or dashboard commands on a clean machine.",
    },
    {
      command: "npm run launch:candidate",
      label: "Refresh V0 fixtures",
      state: "available",
      detail: "Current root command validates launch-core data before the workbench consumes it.",
    },
    {
      command: "npm run flowchain:start",
      label: "Start private testnet services",
      state: "expected",
      detail: "Integration point for the runtime/control-plane package; not provided by this dashboard change.",
    },
    {
      command: "npm run flowchain:smoke",
      label: "Run full object smoke flow",
      state: "expected",
      detail: "Expected to populate agents, models, receipts, artifacts, challenges, finality, and API state.",
    },
    {
      command: "npm run dev --prefix apps/dashboard",
      label: "Open the workbench",
      state: "available",
      detail:
        controlPlane.status === "available"
          ? "Runs the browser workbench against the detected local API and synced fixtures."
          : "Runs the browser workbench with deterministic fixture fallback.",
    },
  ];
}

export function buildWorkbenchSnapshot(
  data: DashboardData,
  options: {
    controlPlane?: ControlPlaneProbe;
    devnetState?: unknown | null;
    devnetDashboardState?: unknown | null;
    bridgeTestDeposit?: unknown | null;
    loadIssues?: string[];
  } = {},
): WorkbenchSnapshot {
  const controlPlane =
    options.controlPlane ??
    ({
      url: DEFAULT_CONTROL_PLANE_URL,
      status: "not-detected",
      checkedAt: new Date().toISOString(),
      endpoints: ["GET /health", "GET /state"],
      error: "not probed",
    } satisfies ControlPlaneProbe);
  const controlPlaneState = extractControlPlaneState(controlPlane.state);
  const activeDevnetState = controlPlaneState ?? options.devnetState ?? null;
  const bridgeTestDeposit = options.bridgeTestDeposit ?? null;
  const source: WorkbenchSource = controlPlane.status === "available" && controlPlaneState ? "control-plane" : "fixture-fallback";

  const sections: Record<WorkbenchSectionKey, WorkbenchRecord[]> = {
    nodeStatus: buildNodeStatusRecords(data, activeDevnetState, controlPlane),
    peers: buildPeerRecords(activeDevnetState),
    blocks: buildBlockRecords(data, activeDevnetState),
    transactions: buildTransactionRecords(data, activeDevnetState),
    mempool: buildMempoolRecords(activeDevnetState),
    accounts: buildAccountRecords(activeDevnetState),
    balances: buildBalanceRecords(activeDevnetState),
    faucetEvents: buildFaucetEventRecords(activeDevnetState),
    walletMetadata: buildWalletMetadataRecords(activeDevnetState),
    tokenLaunches: buildTokenLaunchRecords(activeDevnetState),
    tokenBalances: buildTokenBalanceRecords(activeDevnetState),
    dexPools: buildDexPoolRecords(activeDevnetState),
    liquidityPositions: buildLiquidityPositionRecords(activeDevnetState),
    swaps: buildSwapRecords(activeDevnetState),
    explorerRecords: buildExplorerRecords(data, activeDevnetState, bridgeTestDeposit),
    rootfields: buildRootfieldRecords(data, activeDevnetState),
    agents: buildAgentRecords(data, activeDevnetState),
    models: buildModelRecords(activeDevnetState),
    receipts: buildReceiptRecords(data, activeDevnetState),
    memoryCells: buildMemoryCellRecords(data, activeDevnetState),
    artifacts: buildArtifactRecords(data, activeDevnetState),
    verifierModules: buildVerifierModuleRecords(data, activeDevnetState),
    verifierReports: buildVerifierRecords(data, activeDevnetState),
    challenges: buildChallengeRecords(activeDevnetState),
    finality: buildFinalityRecords(data, activeDevnetState),
    bridgeDeposits: buildBridgeRecords(activeDevnetState, "deposits", bridgeTestDeposit),
    bridgeCredits: buildBridgeRecords(activeDevnetState, "credits", bridgeTestDeposit),
    bridgeWithdrawals: buildBridgeRecords(activeDevnetState, "withdrawals", bridgeTestDeposit),
    provenance: [],
    hardwareSignals: buildHardwareSignalRecords(data, activeDevnetState),
    rawJson: [],
  };

  sections.provenance = buildProvenanceRecords(
    data,
    controlPlane,
    options.devnetState ?? null,
    options.devnetDashboardState ?? null,
    bridgeTestDeposit,
  );
  sections.rawJson = buildRawJsonRecords(
    data,
    controlPlane,
    options.devnetState ?? null,
    options.devnetDashboardState ?? null,
    bridgeTestDeposit,
  );
  const displayedSections = source === "control-plane" ? relabelDevnetRecordsAsControlPlane(sections, controlPlane) : sections;

  return {
    source,
    generatedAt: new Date().toISOString(),
    controlPlane,
    node: buildNodeStatus(data, activeDevnetState, controlPlane),
    setupSteps: buildSetupSteps(controlPlane),
    actions: buildLocalActions(controlPlane),
    sections: displayedSections,
    loadIssues: options.loadIssues ?? [],
    raw: {
      dashboard: data,
      devnetState: options.devnetState ?? null,
      devnetDashboardState: options.devnetDashboardState ?? null,
      bridgeTestDeposit,
      controlPlaneHealth: controlPlane.health ?? null,
      controlPlaneState: controlPlane.state ?? null,
    },
  };
}

export async function fetchWorkbenchSnapshot(data: DashboardData): Promise<WorkbenchSnapshot> {
  const [controlPlane, devnetStateResult, devnetDashboardStateResult, bridgeTestDepositResult] = await Promise.all([
    probeControlPlane(),
    fetchOptionalJson(WORKBENCH_DEVNET_STATE_PATH),
    fetchOptionalJson(WORKBENCH_DEVNET_DASHBOARD_STATE_PATH),
    fetchOptionalJson(WORKBENCH_BRIDGE_TEST_DEPOSIT_PATH),
  ]);
  const loadIssues = [devnetStateResult.error, devnetDashboardStateResult.error, bridgeTestDepositResult.error].filter(
    (issue): issue is string => typeof issue === "string" && issue.length > 0,
  );

  return buildWorkbenchSnapshot(data, {
    controlPlane,
    devnetState: devnetStateResult.value,
    devnetDashboardState: devnetDashboardStateResult.value,
    bridgeTestDeposit: bridgeTestDepositResult.value,
    loadIssues,
  });
}
