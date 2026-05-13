import type { DashboardData, DashboardStatus, Provenance, SourceSubsystem } from "./types";

export const DEFAULT_CONTROL_PLANE_URL = "http://127.0.0.1:8787";
export const WORKBENCH_DEVNET_STATE_PATH = "/data/flowchain-local-devnet-state.json";
export const WORKBENCH_DEVNET_DASHBOARD_STATE_PATH = "/data/flowchain-local-devnet-dashboard-state.json";
export const WORKBENCH_BRIDGE_DEPOSIT_PATH = "/data/flowchain-bridge-test-deposit.json";

const FIXTURE_CHAIN_CONTEXT = "flowchain-private-local-testnet";
const CONTROL_PLANE_TIMEOUT_MS = 900;

export type WorkbenchSource = "control-plane" | "fixture-fallback";
export type WorkbenchSectionKey =
  | "blocks"
  | "peers"
  | "transactions"
  | "mempool"
  | "accounts"
  | "balances"
  | "faucetEvents"
  | "wallets"
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
  | "bridge"
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
}

export interface ControlPlaneProbe {
  url: string;
  status: "available" | "not-detected";
  checkedAt: string;
  endpoints: string[];
  error?: string;
  health?: unknown;
  state?: unknown;
  rpc?: Record<string, unknown>;
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
  key: "refresh" | "faucet" | "sampleTransaction" | "bridgeDeposit";
  label: string;
  method: string;
  state: "available" | "missing";
  detail: string;
  params: UnknownRecord;
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
    bridgeDeposit: unknown | null;
    controlPlaneHealth: unknown | null;
    controlPlaneState: unknown | null;
    controlPlaneRpc: Record<string, unknown> | null;
  };
}

type UnknownRecord = Record<string, unknown>;

export const WORKBENCH_SECTIONS: WorkbenchSectionDefinition[] = [
  {
    key: "blocks",
    label: "Blocks",
    detail: "Private/local chain blocks, state roots, parent hashes, and receipt counts.",
    expectedEndpoint: "POST /rpc block_list",
  },
  {
    key: "peers",
    label: "Peers",
    detail: "Local node peer rows when the runtime exports peer or LAN node state.",
    expectedEndpoint: "POST /rpc peer_list",
  },
  {
    key: "transactions",
    label: "Transactions",
    detail: "Smoke-flow transaction ids and receipt application status.",
    expectedEndpoint: "POST /rpc transaction_list",
  },
  {
    key: "mempool",
    label: "Mempool",
    detail: "Pending local transactions waiting for deterministic block production.",
    expectedEndpoint: "POST /rpc mempool_list",
  },
  {
    key: "accounts",
    label: "Accounts",
    detail: "Local operator and agent account records. Browser output never includes private keys.",
    expectedEndpoint: "POST /rpc account_list",
  },
  {
    key: "balances",
    label: "Balances",
    detail: "No-value local balance or credit rows when explicitly exported by the runtime.",
    expectedEndpoint: "POST /rpc balance_list",
  },
  {
    key: "faucetEvents",
    label: "Faucet Events",
    detail: "Local faucet request history when a no-value faucet endpoint exists.",
    expectedEndpoint: "POST /rpc faucet_event_list",
  },
  {
    key: "wallets",
    label: "Wallet Public Accounts",
    detail: "Public wallet/operator references only. Signing material stays outside the browser.",
    expectedEndpoint: "POST /rpc wallet_account_list",
  },
  {
    key: "rootfields",
    label: "Rootfields",
    detail: "Rootfield namespaces, owners, compact roots, schema hashes, and active state.",
    expectedEndpoint: "POST /rpc rootfield_list",
  },
  {
    key: "agents",
    label: "Agents",
    detail: "Operators, workers, verifier identities, and observed contract actors.",
    expectedEndpoint: "POST /rpc agent_list",
  },
  {
    key: "models",
    label: "Models",
    detail: "ModelPassport objects when the private testnet runtime exports them.",
    expectedEndpoint: "POST /rpc model_list",
  },
  {
    key: "receipts",
    label: "Work Receipts",
    detail: "Work receipts from the launch fixture and local devnet handoff.",
    expectedEndpoint: "POST /rpc work_receipt_list",
  },
  {
    key: "memoryCells",
    label: "Memory Cells",
    detail: "Native MemoryCell records or rootfield-bundle projections while the API is pending.",
    expectedEndpoint: "POST /rpc memory_cell_list",
  },
  {
    key: "artifacts",
    label: "Artifacts",
    detail: "Artifact availability commitments and receipt-linked artifact URIs.",
    expectedEndpoint: "POST /rpc artifact_availability_list",
  },
  {
    key: "verifierModules",
    label: "Verifier Modules",
    detail: "Verifier module identities or derived module projections from local reports.",
    expectedEndpoint: "POST /rpc verifier_module_list",
  },
  {
    key: "verifierReports",
    label: "Verifier Reports",
    detail: "Verifier reports, report digests, policies, checks, and reason codes.",
    expectedEndpoint: "POST /rpc verifier_report_list",
  },
  {
    key: "challenges",
    label: "Challenges",
    detail: "Challenge lifecycle objects once the runtime/control-plane exports them.",
    expectedEndpoint: "POST /rpc challenge_list",
  },
  {
    key: "finality",
    label: "Finality",
    detail: "Local finality distance, anchor placeholders, and latest finalized state.",
    expectedEndpoint: "POST /rpc finality_list",
  },
  {
    key: "bridge",
    label: "Bridge Test Lane",
    detail: "Test-only bridge deposit, credit, and withdrawal rows. This is not a production bridge surface.",
    expectedEndpoint: "POST /rpc bridge_deposit_list",
  },
  {
    key: "provenance",
    label: "Provenance / Source",
    detail: "Source paths, API probe result, and fixture fallback boundary.",
    expectedEndpoint: "POST /rpc provenance_get",
  },
  {
    key: "hardwareSignals",
    label: "Hardware Signals",
    detail: "FlowRouter, gateway, and low-bandwidth sidecar heartbeat/control-signal records.",
    expectedEndpoint: "POST /rpc hardware_signal_list",
  },
  {
    key: "rawJson",
    label: "Raw JSON",
    detail: "Loaded dashboard, devnet, and control-plane payloads for direct inspection.",
    expectedEndpoint: "POST /rpc raw_json_get",
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

function collectionFromRoots(roots: unknown[], keys: string[]): UnknownRecord[] {
  for (const root of roots) {
    const values = collectionFrom(root, keys);
    if (values.length > 0) {
      return values;
    }
  }

  return [];
}

function resultRecord(value: unknown): UnknownRecord | null {
  if (isRecord(value) && isRecord(value.result)) {
    return value.result;
  }

  return isRecord(value) ? value : null;
}

function rpcResult(controlPlane: ControlPlaneProbe, id: string): UnknownRecord | null {
  return resultRecord(controlPlane.rpc?.[id]);
}

function rpcCollection(controlPlane: ControlPlaneProbe, id: string, keys: string[]): UnknownRecord[] {
  const result = rpcResult(controlPlane, id);
  return result ? collectionFrom(result, keys) : [];
}

function rpcRaw(controlPlane: ControlPlaneProbe, id: string): unknown | null {
  const result = rpcResult(controlPlane, id);
  return result?.raw ?? result?.data ?? null;
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
  if (normalized === "applied" || normalized === "success" || normalized === "active" || normalized === "available") {
    return "verified";
  }
  if (normalized === "finalized" || normalized === "local-finalized") {
    return "finalized";
  }
  if (normalized === "failed" || normalized === "invalid" || normalized === "reverted" || normalized === "local-rejected") {
    return "failed";
  }
  if (normalized === "pending" || normalized === "local-placeholder" || normalized === "local-pending" || normalized === "not-opened" || normalized === "not_opened") {
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

async function postJsonWithTimeout(url: string, body: unknown, timeoutMs: number): Promise<unknown> {
  const controller = new AbortController();
  const timeout = globalThis.setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      method: "POST",
      cache: "no-store",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
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

async function fetchControlPlaneRpc(url: string): Promise<Record<string, unknown>> {
  const requests = [
    { jsonrpc: "2.0", id: "chainStatus", method: "chain_status" },
    { jsonrpc: "2.0", id: "devnetState", method: "devnet_state", params: { includeBlocks: true } },
    { jsonrpc: "2.0", id: "blocks", method: "block_list", params: { includeTransactions: true, limit: 100 } },
    { jsonrpc: "2.0", id: "transactions", method: "transaction_list", params: { limit: 100 } },
    { jsonrpc: "2.0", id: "rootfields", method: "rootfield_list", params: { limit: 100 } },
    { jsonrpc: "2.0", id: "agents", method: "agent_list", params: { limit: 100 } },
    { jsonrpc: "2.0", id: "models", method: "model_list", params: { limit: 100 } },
    { jsonrpc: "2.0", id: "workReceipts", method: "work_receipt_list", params: { limit: 100 } },
    { jsonrpc: "2.0", id: "receipts", method: "receipt_list", params: { limit: 100 } },
    { jsonrpc: "2.0", id: "artifacts", method: "artifact_availability_list", params: { limit: 100 } },
    { jsonrpc: "2.0", id: "verifierModules", method: "verifier_module_list", params: { limit: 100 } },
    { jsonrpc: "2.0", id: "verifierReports", method: "verifier_report_list", params: { limit: 100 } },
    { jsonrpc: "2.0", id: "memoryCells", method: "memory_cell_list", params: { limit: 100 } },
    { jsonrpc: "2.0", id: "challenges", method: "challenge_list", params: { limit: 100 } },
    { jsonrpc: "2.0", id: "finality", method: "finality_list", params: { limit: 100 } },
    { jsonrpc: "2.0", id: "rawDevnet", method: "raw_json_get", params: { source: "devnet" } },
    { jsonrpc: "2.0", id: "rawTxFixtures", method: "raw_json_get", params: { source: "txFixtures" } },
  ];
  const response = await postJsonWithTimeout(`${url}/rpc`, requests, CONTROL_PLANE_TIMEOUT_MS);
  if (!Array.isArray(response)) {
    throw new Error("control-plane RPC batch did not return an array");
  }

  return Object.fromEntries(
    response
      .filter((entry): entry is UnknownRecord => isRecord(entry) && (typeof entry.id === "string" || typeof entry.id === "number"))
      .map((entry) => [String(entry.id), entry]),
  );
}

async function probeControlPlane(): Promise<ControlPlaneProbe> {
  const url = getControlPlaneUrl();
  const checkedAt = new Date().toISOString();
  const endpoints = ["GET /health", "GET /state", "POST /rpc"];

  try {
    const health = await fetchJsonWithTimeout(`${url}/health`, CONTROL_PLANE_TIMEOUT_MS);
    let state: unknown | undefined;
    let rpc: Record<string, unknown> | undefined;
    const errors: string[] = [];

    try {
      state = await fetchJsonWithTimeout(`${url}/state`, CONTROL_PLANE_TIMEOUT_MS);
    } catch (error) {
      errors.push(`state endpoint was not loaded: ${error instanceof Error ? error.message : "unknown state error"}`);
    }

    try {
      rpc = await fetchControlPlaneRpc(url);
    } catch (error) {
      errors.push(`RPC batch was not loaded: ${error instanceof Error ? error.message : "unknown RPC error"}`);
    }

    if (state === undefined && rpc === undefined) {
      return {
        url,
        status: "available",
        checkedAt,
        endpoints,
        health,
        error: `Health endpoint responded, but no state payload was loaded: ${errors.join(" / ")}`,
      };
    }

    return {
      url,
      status: "available",
      checkedAt,
      endpoints,
      health,
      state,
      rpc,
      error: errors.length > 0 ? errors.join(" / ") : undefined,
    };
  } catch (error) {
    return {
      url,
      status: "not-detected",
      checkedAt,
      endpoints,
      error: error instanceof Error ? error.message : "control-plane API not detected",
    };
  }
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

function scalarFacts(record: UnknownRecord, preferred: string[] = []): WorkbenchFact[] {
  const facts: WorkbenchFact[] = [];
  const seen = new Set<string>();
  const add = (key: string, value: unknown) => {
    if (seen.has(key) || value === undefined || value === null || typeof value === "object") {
      return;
    }
    facts.push({ label: key.replace(/([A-Z])/g, " $1").toLowerCase(), value: text(value) });
    seen.add(key);
  };

  preferred.forEach((key) => add(key, record[key]));
  Object.entries(record).forEach(([key, value]) => add(key, value));
  return facts.slice(0, 6);
}

function titleFromRecord(record: UnknownRecord, fallback: string, keys: string[]): string {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "string" || typeof value === "number") {
      return String(value);
    }
  }
  return fallback;
}

function preferRpcRecords(fallback: WorkbenchRecord[], rpcRecords: WorkbenchRecord[]): WorkbenchRecord[] {
  return rpcRecords.length > 0 ? rpcRecords : fallback;
}

function buildRpcGenericRecords(
  controlPlane: ControlPlaneProbe,
  id: string,
  keys: string[],
  kind: string,
  primaryIdKey: string,
): WorkbenchRecord[] {
  return rpcCollection(controlPlane, id, keys).map((record, index) => {
    const title = titleFromRecord(record, `${kind.toLowerCase()}:${index + 1}`, [
      primaryIdKey,
      "id",
      "objectId",
      "receiptId",
      "reportId",
      "rootfieldId",
      "transactionId",
      "txHash",
    ]);

    return makeLocalRecord(
      "devnet",
      controlPlane.url,
      {
        id: title,
        kind,
        title,
        summary: text(record.extensionPoint ?? record.summary ?? record.schema, `Loaded from ${id} control-plane RPC response.`),
        status: statusFrom(record.status ?? record.sourceStatus ?? record.finalityStatus, "observed"),
        facts: scalarFacts(record, [primaryIdKey, "rootfieldId", "status", "source", "localOnly", "schema"]),
        raw: record,
      },
      controlPlane.checkedAt,
    );
  });
}

function buildRpcBlockRecords(controlPlane: ControlPlaneProbe): WorkbenchRecord[] {
  return rpcCollection(controlPlane, "blocks", ["blocks"]).map((block, index) => {
    const blockNumber = text(block.blockNumber, `${index + 1}`);
    return makeLocalRecord(
      "devnet",
      controlPlane.url,
      {
        id: text(block.blockHash, `block:${blockNumber}`),
        kind: "API Block",
        title: `Block ${blockNumber}`,
        summary: `${stringArray(block.txIds).length} transactions and ${text(block.receiptCount, "0")} receipts from control-plane block_list.`,
        status: "finalized",
        facts: [
          { label: "block hash", value: text(block.blockHash) },
          { label: "parent hash", value: text(block.parentHash) },
          { label: "state root", value: text(block.stateRoot) },
          { label: "source", value: text(block.source) },
          { label: "transactions", value: stringArray(block.txIds).length.toString() },
          { label: "receipts", value: text(block.receiptCount, "0") },
        ],
        raw: block,
      },
      controlPlane.checkedAt,
    );
  });
}

function buildRpcTransactionRecords(controlPlane: ControlPlaneProbe): WorkbenchRecord[] {
  return rpcCollection(controlPlane, "transactions", ["transactions"]).map((transaction) =>
    makeLocalRecord(
      "devnet",
      controlPlane.url,
      {
        id: text(transaction.transactionId ?? transaction.txHash),
        kind: "API Transaction",
        title: text(transaction.txHash ?? transaction.transactionId),
        summary: `${text(transaction.type, "local")} transaction is ${text(transaction.status, "unknown")} from ${text(transaction.source, "control-plane")}.`,
        status: statusFrom(transaction.status, "observed"),
        facts: [
          { label: "block", value: text(transaction.blockNumber) },
          { label: "tx index", value: text(transaction.transactionIndex) },
          { label: "type", value: text(transaction.type) },
          { label: "source", value: text(transaction.source) },
          { label: "local only", value: text(transaction.localOnly) },
        ],
        raw: transaction,
      },
      controlPlane.checkedAt,
    ),
  );
}

function buildPeerRecords(controlPlane: ControlPlaneProbe, devnetState: unknown): WorkbenchRecord[] {
  const peers = [
    ...rpcCollection(controlPlane, "peers", ["peers", "nodes"]),
    ...collectionFromRoots([devnetState, controlPlane.state], ["peers", "peerState", "networkPeers", "nodes"]),
  ];

  return peers.map((peer, index) =>
    makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id: text(peer.peerId ?? peer.nodeId ?? peer.id, `peer:${index + 1}`),
      kind: "Peer",
      title: text(peer.peerId ?? peer.nodeId ?? peer.id, `Peer ${index + 1}`),
      summary: text(peer.summary ?? peer.address ?? peer.transport, "Peer exported by local runtime state."),
      status: statusFrom(peer.status ?? peer.state, "observed"),
      facts: scalarFacts(peer, ["peerId", "nodeId", "address", "transport", "lastSeenAt", "status"]),
      raw: peer,
    }),
  );
}

function buildMempoolRecords(devnetState: unknown): WorkbenchRecord[] {
  return collectionFrom(devnetState, ["pendingTxs", "mempool", "pendingTransactions"]).map((transaction, index) =>
    makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id: text(transaction.txId ?? transaction.transactionId ?? transaction.txHash, `pending:${index + 1}`),
      kind: "Mempool transaction",
      title: text(transaction.txHash ?? transaction.txId ?? transaction.transactionId, `Pending transaction ${index + 1}`),
      summary: text(transaction.summary ?? transaction.type, "Pending local transaction waiting for block production."),
      status: statusFrom(transaction.status, "pending"),
      facts: scalarFacts(transaction, ["type", "from", "to", "rootfieldId", "createdAt", "status"]),
      raw: transaction,
    }),
  );
}

function buildAccountRecords(devnetState: unknown): WorkbenchRecord[] {
  const agentAccounts = collectionFrom(devnetState, ["agentAccounts", "accounts", "publicAccounts"]).map((account, index) =>
    makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id: text(account.agentId ?? account.accountId ?? account.id, `account:${index + 1}`),
      kind: "AgentAccount",
      title: text(account.agentId ?? account.accountId ?? account.id, `Account ${index + 1}`),
      summary: `Controller ${text(account.controller ?? account.owner)}; private signing material is not present in browser state.`,
      status: account.active === false ? "stale" : statusFrom(account.status, "verified"),
      facts: scalarFacts(account, ["controller", "modelPassportId", "memoryRoot", "rootfieldId", "active"]),
      raw: account,
    }),
  );

  const operatorRefs = collectionFrom(devnetState, ["operatorKeyReferences"]).map((reference, index) =>
    makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id: text(reference.operatorId ?? reference.keyReferenceId, `operator:${index + 1}`),
      kind: "Operator public reference",
      title: text(reference.keyReferenceId ?? reference.operatorId, `Operator reference ${index + 1}`),
      summary: text(reference.secretMaterialBoundary, "Secret material is not stored in dashboard or handoff output."),
      status: "verified",
      facts: scalarFacts(reference, ["operatorId", "workerKeyId", "verifierKeyId", "signatureScheme", "publicKeyHint"]),
      raw: reference,
    }),
  );

  return [...agentAccounts, ...operatorRefs];
}

function buildBalanceRecords(devnetState: unknown): WorkbenchRecord[] {
  const balances = collectionFrom(devnetState, ["balances", "accountBalances", "ledgerBalances", "credits"]).map((balance, index) =>
    makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id: text(balance.accountId ?? balance.owner ?? balance.id, `balance:${index + 1}`),
      kind: "Local balance row",
      title: text(balance.accountId ?? balance.owner ?? balance.id, `Balance row ${index + 1}`),
      summary: text(balance.summary ?? balance.asset, "No-value local balance or credit row."),
      status: statusFrom(balance.status, "observed"),
      facts: scalarFacts(balance, ["accountId", "asset", "amount", "credit", "status", "source"]),
      raw: balance,
    }),
  );

  if (balances.length > 0) {
    return balances;
  }

  const config = isRecord(devnetState) && isRecord(devnetState.config) ? devnetState.config : null;
  if (config?.noValue === true) {
    return [
      makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
        id: "no-value-balance-boundary",
        kind: "Balance boundary",
        title: "No value-bearing balances",
        summary: "The current private/local devnet state is marked no-value; no real funds, token balances, gas, rewards, or staking ledger is exposed.",
        status: "unsupported",
        facts: [
          { label: "chain id", value: text(devnetState && isRecord(devnetState) ? devnetState.chainId : null) },
          { label: "no value", value: "true" },
          { label: "source", value: "local devnet config" },
        ],
        raw: config,
      }),
    ];
  }

  return [];
}

function buildFaucetEventRecords(devnetState: unknown): WorkbenchRecord[] {
  return collectionFrom(devnetState, ["faucetEvents", "faucetRequests", "faucetClaims"]).map((event, index) =>
    makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id: text(event.eventId ?? event.requestId ?? event.id, `faucet:${index + 1}`),
      kind: "Faucet event",
      title: text(event.requestId ?? event.eventId ?? event.id, `Faucet event ${index + 1}`),
      summary: text(event.summary ?? event.reason, "Local no-value faucet event."),
      status: statusFrom(event.status, "observed"),
      facts: scalarFacts(event, ["accountId", "amount", "asset", "createdAt", "status"]),
      raw: event,
    }),
  );
}

function buildWalletRecords(devnetState: unknown): WorkbenchRecord[] {
  const walletRows = collectionFrom(devnetState, ["walletPublicAccounts", "wallets", "publicWallets"]).map((wallet, index) =>
    makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id: text(wallet.address ?? wallet.accountId ?? wallet.id, `wallet:${index + 1}`),
      kind: "Wallet public account",
      title: text(wallet.address ?? wallet.accountId ?? wallet.id, `Wallet ${index + 1}`),
      summary: "Public account metadata only; signing and private-key handling stay outside this browser app.",
      status: statusFrom(wallet.status, "observed"),
      facts: scalarFacts(wallet, ["address", "accountId", "role", "keyReferenceId", "status"]),
      raw: wallet,
    }),
  );

  const keyRefs = collectionFrom(devnetState, ["operatorKeyReferences"]).map((reference, index) =>
    makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id: text(reference.keyReferenceId, `wallet-reference:${index + 1}`),
      kind: "Operator key reference",
      title: text(reference.operatorId ?? reference.keyReferenceId, `Operator public key ${index + 1}`),
      summary: text(reference.publicKeyHint, "Public key hint only; no private key or seed phrase is present."),
      status: "verified",
      facts: scalarFacts(reference, ["operatorId", "workerKeyId", "verifierKeyId", "signatureScheme", "secretMaterialBoundary"]),
      raw: reference,
    }),
  );

  return [...walletRows, ...keyRefs];
}

function buildBridgeRecords(devnetState: unknown, bridgeDeposit: unknown | null): WorkbenchRecord[] {
  const bridgeRows = collectionFrom(devnetState, [
    "bridgeDeposits",
    "bridgeCredits",
    "bridgeWithdrawals",
    "bridgeEvents",
    "bridgeObservations",
  ]).map((bridgeObject, index) =>
    makeRecord("devnet", WORKBENCH_DEVNET_STATE_PATH, {
      id: text(bridgeObject.depositId ?? bridgeObject.creditId ?? bridgeObject.withdrawalId ?? bridgeObject.id, `bridge:${index + 1}`),
      kind: text(bridgeObject.kind ?? bridgeObject.type, "Bridge lifecycle object"),
      title: text(bridgeObject.depositId ?? bridgeObject.creditId ?? bridgeObject.withdrawalId ?? bridgeObject.id, `Bridge object ${index + 1}`),
      summary: text(bridgeObject.summary ?? bridgeObject.status, "Local/test bridge lifecycle row from runtime state."),
      status: statusFrom(bridgeObject.status, "observed"),
      facts: scalarFacts(bridgeObject, ["sourceChainId", "txHash", "amount", "sender", "flowchainRecipient", "status"]),
      raw: bridgeObject,
    }),
  );

  if (isRecord(bridgeDeposit)) {
    bridgeRows.push(
      makeRecord("devnet", WORKBENCH_BRIDGE_DEPOSIT_PATH, {
        id: text(bridgeDeposit.depositId),
        kind: "Test bridge deposit",
        title: text(bridgeDeposit.depositId),
        summary: "Deterministic Base Sepolia mock deposit for local bridge inspection only; not a production bridge or real-funds workflow.",
        status: statusFrom(bridgeDeposit.status, "observed"),
        facts: [
          { label: "source chain", value: text(bridgeDeposit.sourceChainId) },
          { label: "tx hash", value: text(bridgeDeposit.txHash) },
          { label: "token", value: text(bridgeDeposit.token) },
          { label: "amount", value: text(bridgeDeposit.amount) },
          { label: "sender", value: text(bridgeDeposit.sender) },
          { label: "recipient", value: text(bridgeDeposit.flowchainRecipient) },
        ],
        raw: bridgeDeposit,
      }),
    );
  }

  return bridgeRows;
}

function advertisedText(controlPlane: ControlPlaneProbe): string {
  return JSON.stringify({
    health: controlPlane.health ?? null,
    state: controlPlane.state ?? null,
    rpc: controlPlane.rpc ?? null,
  }).toLowerCase();
}

function advertisedMethod(controlPlane: ControlPlaneProbe, candidates: string[]): string | null {
  if (controlPlane.status !== "available") {
    return null;
  }
  const haystack = advertisedText(controlPlane);
  return candidates.find((candidate) => haystack.includes(candidate.toLowerCase())) ?? null;
}

function buildWorkbenchActions(controlPlane: ControlPlaneProbe): WorkbenchAction[] {
  const faucetMethod = advertisedMethod(controlPlane, ["faucet_request", "local_faucet_request", "faucet_submit"]);
  const txMethod = advertisedMethod(controlPlane, ["transaction_submit", "sample_transaction_submit", "submit_sample_transaction"]);
  const bridgeMethod = advertisedMethod(controlPlane, ["bridge_deposit_get", "bridge_deposit_inspect", "bridge_test_deposit_get"]);
  const refreshAvailable = controlPlane.status === "available";

  return [
    {
      key: "refresh",
      label: "Refresh state",
      method: "devnet_state",
      state: refreshAvailable ? "available" : "missing",
      detail: refreshAvailable
        ? "Reloads dashboard data and re-probes /health, /state, and /rpc."
        : "Start the API with npm run control-plane:serve before live refresh can verify state.",
      params: { includeBlocks: true },
    },
    {
      key: "faucet",
      label: "Submit faucet request",
      method: faucetMethod ?? "faucet_request",
      state: faucetMethod ? "available" : "missing",
      detail: faucetMethod
        ? "Uses the advertised local no-value faucet JSON-RPC method. No private keys are handled in the browser."
        : "No local faucet method is advertised by the current control-plane API.",
      params: { localOnly: true },
    },
    {
      key: "sampleTransaction",
      label: "Submit sample transaction",
      method: txMethod ?? "transaction_submit",
      state: txMethod ? "available" : "missing",
      detail: txMethod
        ? "Submits a local sample transaction through the advertised control-plane method."
        : "No transaction submit method is advertised. Run npm run flowchain:demo or npm run flowchain:smoke to populate deterministic transactions.",
      params: { sample: true, localOnly: true },
    },
    {
      key: "bridgeDeposit",
      label: "Inspect bridge test deposit",
      method: bridgeMethod ?? "bridge_deposit_get",
      state: bridgeMethod ? "available" : "missing",
      detail: bridgeMethod
        ? "Reads the advertised test bridge deposit method. This remains a local/test bridge lane."
        : "No bridge deposit inspection method is advertised; the workbench can still show the copied deterministic mock deposit fixture.",
      params: { localOnly: true },
    },
  ];
}

function topLevelKeys(value: unknown): string {
  return isRecord(value) ? Object.keys(value).sort().join(", ") : "not loaded";
}

function buildRawJsonRecords(
  data: DashboardData,
  controlPlane: ControlPlaneProbe,
  devnetState: unknown | null,
  devnetDashboardState: unknown | null,
  bridgeDeposit: unknown | null,
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
          { label: "rpc result ids", value: controlPlane.rpc ? Object.keys(controlPlane.rpc).sort().join(", ") : "not loaded" },
          { label: "error", value: text(controlPlane.error, "none") },
        ],
        raw: {
          health: controlPlane.health ?? null,
          state: controlPlane.state ?? null,
          rpc: controlPlane.rpc ?? null,
          error: controlPlane.error ?? null,
        },
      },
      controlPlane.checkedAt,
    ),
    makeRecord("devnet", WORKBENCH_BRIDGE_DEPOSIT_PATH, {
      id: "raw-bridge-test-deposit",
      kind: "Raw JSON",
      title: WORKBENCH_BRIDGE_DEPOSIT_PATH,
      summary: bridgeDeposit
        ? "Copied deterministic bridge test deposit fixture loaded for local inspection."
        : "Bridge test deposit fixture was not loaded.",
      status: bridgeDeposit ? "observed" : "unresolved",
      facts: [
        { label: "schema", value: isRecord(bridgeDeposit) ? text(bridgeDeposit.schema) : "missing" },
        { label: "keys", value: topLevelKeys(bridgeDeposit) },
      ],
      raw: bridgeDeposit,
    }),
  ];
}

function buildProvenanceRecords(
  data: DashboardData,
  controlPlane: ControlPlaneProbe,
  devnetState: unknown | null,
  devnetDashboardState: unknown | null,
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
    bridgeDeposit?: unknown | null;
    loadIssues?: string[];
  } = {},
): WorkbenchSnapshot {
  const controlPlane =
    options.controlPlane ??
    ({
      url: DEFAULT_CONTROL_PLANE_URL,
      status: "not-detected",
      checkedAt: new Date().toISOString(),
      endpoints: ["GET /health", "GET /state", "POST /rpc"],
      error: "not probed",
    } satisfies ControlPlaneProbe);
  const rpcDevnetState = rpcRaw(controlPlane, "rawDevnet");
  const rpcDevnetSummary = rpcResult(controlPlane, "devnetState");
  const controlPlaneState = rpcDevnetState ?? extractControlPlaneState(controlPlane.state) ?? rpcDevnetSummary;
  const activeDevnetState = controlPlaneState ?? options.devnetState ?? null;
  const source: WorkbenchSource = controlPlane.status === "available" && (controlPlaneState !== null || controlPlane.rpc) ? "control-plane" : "fixture-fallback";

  const sections: Record<WorkbenchSectionKey, WorkbenchRecord[]> = {
    blocks: buildBlockRecords(data, activeDevnetState),
    peers: buildPeerRecords(controlPlane, activeDevnetState),
    transactions: buildTransactionRecords(data, activeDevnetState),
    mempool: buildMempoolRecords(activeDevnetState),
    accounts: buildAccountRecords(activeDevnetState),
    balances: buildBalanceRecords(activeDevnetState),
    faucetEvents: buildFaucetEventRecords(activeDevnetState),
    wallets: buildWalletRecords(activeDevnetState),
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
    bridge: buildBridgeRecords(activeDevnetState, options.bridgeDeposit ?? null),
    provenance: [],
    hardwareSignals: buildHardwareSignalRecords(data, activeDevnetState),
    rawJson: [],
  };

  sections.blocks = preferRpcRecords(sections.blocks, buildRpcBlockRecords(controlPlane));
  sections.transactions = preferRpcRecords(sections.transactions, buildRpcTransactionRecords(controlPlane));
  sections.rootfields = preferRpcRecords(sections.rootfields, buildRpcGenericRecords(controlPlane, "rootfields", ["rootfields"], "Rootfield", "rootfieldId"));
  sections.agents = preferRpcRecords(sections.agents, buildRpcGenericRecords(controlPlane, "agents", ["agents"], "Agent", "agentId"));
  sections.models = preferRpcRecords(sections.models, buildRpcGenericRecords(controlPlane, "models", ["models"], "ModelPassport", "modelId"));
  sections.receipts = preferRpcRecords(sections.receipts, buildRpcGenericRecords(controlPlane, "workReceipts", ["workReceipts"], "WorkReceipt", "receiptId"));
  sections.artifacts = preferRpcRecords(sections.artifacts, buildRpcGenericRecords(controlPlane, "artifacts", ["artifacts"], "Artifact availability", "availabilityId"));
  sections.verifierModules = preferRpcRecords(
    sections.verifierModules,
    buildRpcGenericRecords(controlPlane, "verifierModules", ["verifierModules"], "VerifierModule", "moduleId"),
  );
  sections.verifierReports = preferRpcRecords(sections.verifierReports, buildRpcGenericRecords(controlPlane, "verifierReports", ["reports"], "VerifierReport", "reportId"));
  sections.memoryCells = preferRpcRecords(sections.memoryCells, buildRpcGenericRecords(controlPlane, "memoryCells", ["memoryCells"], "MemoryCell", "memoryCellId"));
  sections.challenges = preferRpcRecords(sections.challenges, buildRpcGenericRecords(controlPlane, "challenges", ["challenges"], "Challenge", "challengeId"));
  sections.finality = preferRpcRecords(sections.finality, buildRpcGenericRecords(controlPlane, "finality", ["finality"], "Finality receipt", "finalityReceiptId"));

  sections.provenance = buildProvenanceRecords(data, controlPlane, options.devnetState ?? null, options.devnetDashboardState ?? null);
  sections.rawJson = buildRawJsonRecords(data, controlPlane, options.devnetState ?? null, options.devnetDashboardState ?? null, options.bridgeDeposit ?? null);
  const displayedSections = source === "control-plane" ? relabelDevnetRecordsAsControlPlane(sections, controlPlane) : sections;

  return {
    source,
    generatedAt: new Date().toISOString(),
    controlPlane,
    node: buildNodeStatus(data, activeDevnetState, controlPlane),
    setupSteps: buildSetupSteps(controlPlane),
    actions: buildWorkbenchActions(controlPlane),
    sections: displayedSections,
    loadIssues: options.loadIssues ?? [],
    raw: {
      dashboard: data,
      devnetState: options.devnetState ?? null,
      devnetDashboardState: options.devnetDashboardState ?? null,
      bridgeDeposit: options.bridgeDeposit ?? null,
      controlPlaneHealth: controlPlane.health ?? null,
      controlPlaneState: controlPlane.state ?? null,
      controlPlaneRpc: controlPlane.rpc ?? null,
    },
  };
}

export async function fetchWorkbenchSnapshot(data: DashboardData): Promise<WorkbenchSnapshot> {
  const [controlPlane, devnetStateResult, devnetDashboardStateResult, bridgeDepositResult] = await Promise.all([
    probeControlPlane(),
    fetchOptionalJson(WORKBENCH_DEVNET_STATE_PATH),
    fetchOptionalJson(WORKBENCH_DEVNET_DASHBOARD_STATE_PATH),
    fetchOptionalJson(WORKBENCH_BRIDGE_DEPOSIT_PATH),
  ]);
  const loadIssues = [devnetStateResult.error, devnetDashboardStateResult.error, bridgeDepositResult.error].filter(
    (issue): issue is string => typeof issue === "string" && issue.length > 0,
  );

  return buildWorkbenchSnapshot(data, {
    controlPlane,
    devnetState: devnetStateResult.value,
    devnetDashboardState: devnetDashboardStateResult.value,
    bridgeDeposit: bridgeDepositResult.value,
    loadIssues,
  });
}
