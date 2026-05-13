import type { DashboardData } from "./types";

export const DEFAULT_DASHBOARD_DATA_PATH = "/data/flowmemory-dashboard-v0.json";

function assertArray(value: unknown, label: string): void {
  if (!Array.isArray(value)) {
    throw new Error(`Dashboard fixture field "${label}" must be an array.`);
  }
}

export function validateDashboardData(payload: unknown): DashboardData {
  if (payload === null || typeof payload !== "object") {
    throw new Error("Dashboard fixture must be a JSON object.");
  }

  const candidate = payload as Partial<DashboardData>;
  if (candidate.metadata?.schema !== "flowmemory.dashboard.fixture.v0") {
    throw new Error("Unsupported dashboard fixture schema.");
  }
  if (candidate.metadata.mode !== "fixture") {
    throw new Error("Dashboard V0 expects fixture mode data.");
  }
  if (candidate.chain === undefined) {
    throw new Error("Dashboard fixture is missing chain context.");
  }

  assertArray(candidate.flowPulseObservations, "flowPulseObservations");
  assertArray(candidate.rootfields, "rootfields");
  assertArray(candidate.workLanes, "workLanes");
  assertArray(candidate.workReceipts, "workReceipts");
  assertArray(candidate.verifierReports, "verifierReports");
  assertArray(candidate.rootflowTransitions, "rootflowTransitions");
  assertArray(candidate.memorySignals, "memorySignals");
  assertArray(candidate.memoryReceipts, "memoryReceipts");
  assertArray(candidate.rootfieldBundles, "rootfieldBundles");
  assertArray(candidate.agentMemoryViews, "agentMemoryViews");
  assertArray(candidate.devnetBlocks, "devnetBlocks");
  assertArray(candidate.hardwareNodes, "hardwareNodes");
  assertArray(candidate.alerts, "alerts");

  return candidate as DashboardData;
}

export async function fetchDashboardData(
  path = DEFAULT_DASHBOARD_DATA_PATH,
): Promise<DashboardData> {
  const response = await fetch(path, { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`Unable to load dashboard fixture at ${path}: ${response.status}`);
  }

  return validateDashboardData(await response.json());
}
