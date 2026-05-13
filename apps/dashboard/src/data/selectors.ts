import type {
  AlertIncident,
  DashboardData,
  DashboardStatus,
  DevnetBlock,
  FlowPulseObservation,
  HardwareNode,
  ProvenancedRecord,
  VerifierReport,
} from "./types";

export interface OverviewMetric {
  label: string;
  value: string;
  detail: string;
  status: DashboardStatus;
}

export interface SearchableRecord extends ProvenancedRecord {
  [key: string]: unknown;
}

export function countByStatus(records: ProvenancedRecord[]): Partial<Record<DashboardStatus, number>> {
  return records.reduce<Partial<Record<DashboardStatus, number>>>((counts, record) => {
    counts[record.status] = (counts[record.status] ?? 0) + 1;
    return counts;
  }, {});
}

export function getLatestFlowPulses(data: DashboardData, limit = 6): FlowPulseObservation[] {
  return [...data.flowPulseObservations]
    .sort((left, right) => Number(right.blockNumber) - Number(left.blockNumber))
    .slice(0, limit);
}

export function getLatestBlocks(data: DashboardData, limit = 5): DevnetBlock[] {
  return [...data.devnetBlocks]
    .sort((left, right) => right.blockNumber - left.blockNumber)
    .slice(0, limit);
}

export function getOpenAlerts(data: DashboardData): AlertIncident[] {
  return data.alerts.filter((alert) => alert.status !== "verified");
}

export function getVerifierRiskReports(data: DashboardData): VerifierReport[] {
  const riskStatuses: DashboardStatus[] = ["invalid", "unresolved", "unsupported", "reorged", "stale"];
  return data.verifierReports.filter((report) => riskStatuses.includes(report.status));
}

export function getHardwareRiskNodes(data: DashboardData): HardwareNode[] {
  return data.hardwareNodes.filter((node) => node.status === "offline" || node.status === "stale");
}

export function computeOverviewMetrics(data: DashboardData): OverviewMetric[] {
  const observations = data.flowPulseObservations.length;
  const verifiedReports = data.verifierReports.filter((report) => report.status === "verified").length;
  const openAlerts = getOpenAlerts(data).length;
  const hardwareRisk = getHardwareRiskNodes(data).length;
  const latestBlock = data.chain.currentBlock;
  const headStatus: DashboardStatus = data.chain.currentBlock > data.chain.finalizedBlock ? "pending" : "finalized";

  return [
    {
      label: "FlowPulse observations",
      value: observations.toString(),
      detail: `${data.rootfields.length} rootfields represented`,
      status: observations > 0 ? "observed" : "pending",
    },
    {
      label: "Verifier reports",
      value: `${verifiedReports}/${data.verifierReports.length}`,
      detail: "verified in fixture set",
      status: verifiedReports === data.verifierReports.length ? "verified" : "unresolved",
    },
    {
      label: "Devnet head",
      value: latestBlock.toString(),
      detail: `finalized through ${data.chain.finalizedBlock} / chain ${data.chain.chainId}`,
      status: headStatus,
    },
    {
      label: "Hardware risk",
      value: hardwareRisk.toString(),
      detail: "offline or stale nodes",
      status: hardwareRisk > 0 ? "stale" : "verified",
    },
    {
      label: "Open incidents",
      value: openAlerts.toString(),
      detail: "unresolved local alerts",
      status: openAlerts > 0 ? "unresolved" : "verified",
    },
  ];
}

export function searchRecords<T extends ProvenancedRecord>(records: T[], query: string): T[] {
  const normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.length === 0) {
    return records;
  }

  return records.filter((record) => {
    const searchableText = JSON.stringify(record).toLowerCase();
    return searchableText.includes(normalizedQuery);
  });
}
