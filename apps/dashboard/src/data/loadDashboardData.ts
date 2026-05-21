import type { DashboardData } from "./types";

export const DEFAULT_DASHBOARD_DATA_PATH = "/data/flowmemory-dashboard-v0.json";
export const DEFAULT_CANARY_DASHBOARD_DATA_PATH = "/data/flowmemory-dashboard-base-canary-v0.json";

export function publicAssetPath(path: string): string {
  const baseUrl = (import.meta as ImportMeta & { env?: { BASE_URL?: string } }).env?.BASE_URL ?? "/";
  if (/^[a-z][a-z0-9+.-]*:/i.test(path)) {
    return path;
  }
  if (baseUrl === "./") {
    return `./${path.replace(/^\/+/, "")}`;
  }
  return path;
}

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
  if (candidate.metadata.mode !== "fixture" && candidate.metadata.mode !== "canary") {
    throw new Error("Dashboard V0 expects fixture or canary mode data.");
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
  assertArray(candidate.agentBondTasks, "agentBondTasks");
  assertArray(candidate.agentBondSettlements, "agentBondSettlements");
  assertArray(candidate.agentBondPassportViews, "agentBondPassportViews");
  assertArray(candidate.agentBondPassports, "agentBondPassports");
  assertArray(candidate.bondedTaskEnvelopes, "bondedTaskEnvelopes");
  assertArray(candidate.bondedExecutionReceipts, "bondedExecutionReceipts");
  if (candidate.agentBondPhase2Gate === undefined || typeof candidate.agentBondPhase2Gate !== "object") { throw new Error("Dashboard fixture is missing agentBondPhase2Gate."); }
  if (candidate.agentBondA2A === undefined || typeof candidate.agentBondA2A !== "object") { throw new Error("Dashboard fixture is missing agentBondA2A."); }
  if (candidate.agentBondMcp === undefined || typeof candidate.agentBondMcp !== "object") { throw new Error("Dashboard fixture is missing agentBondMcp."); }
  if (candidate.agentBondX402 === undefined || typeof candidate.agentBondX402 !== "object") { throw new Error("Dashboard fixture is missing agentBondX402."); }
  if (candidate.agentBondCredit === undefined || typeof candidate.agentBondCredit !== "object") { throw new Error("Dashboard fixture is missing agentBondCredit."); }
  if (candidate.agentBondUnderwriters === undefined || typeof candidate.agentBondUnderwriters !== "object") { throw new Error("Dashboard fixture is missing agentBondUnderwriters."); }
  if (candidate.agentBondPublicClaim === undefined || typeof candidate.agentBondPublicClaim !== "object") { throw new Error("Dashboard fixture is missing agentBondPublicClaim."); }
  assertArray(candidate.agentBondRecoursePolicies, "agentBondRecoursePolicies");
  assertArray(candidate.agentBondRecourseDecisions, "agentBondRecourseDecisions");
  assertArray(candidate.agentBondFailureWaterfalls, "agentBondFailureWaterfalls");
  assertArray(candidate.baseAgentMemoryScouts, "baseAgentMemoryScouts");
  assertArray(candidate.devnetBlocks, "devnetBlocks");
  assertArray(candidate.hardwareNodes, "hardwareNodes");
  assertArray(candidate.alerts, "alerts");

  return candidate as DashboardData;
}

export async function fetchDashboardData(
  path = DEFAULT_DASHBOARD_DATA_PATH,
): Promise<DashboardData> {
  const response = await fetch(publicAssetPath(path), { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`Unable to load dashboard fixture at ${path}: ${response.status}`);
  }

  return validateDashboardData(await response.json());
}
