import type { DashboardStatus } from "./types";

export const DASHBOARD_STATUSES: DashboardStatus[] = [
  "observed",
  "pending",
  "finalized",
  "verified",
  "unresolved",
  "invalid",
  "unsupported",
  "reorged",
  "offline",
  "stale",
];

export const STATUS_LABELS: Record<DashboardStatus, string> = {
  observed: "Observed",
  pending: "Pending",
  finalized: "Finalized",
  verified: "Verified",
  unresolved: "Unresolved",
  invalid: "Invalid",
  unsupported: "Unsupported",
  reorged: "Reorged",
  offline: "Offline",
  stale: "Stale",
};

export const STATUS_DESCRIPTIONS: Record<DashboardStatus, string> = {
  observed: "Indexed or received locally without a stronger finality or verifier claim.",
  pending: "Queued, in-flight, or below the configured local finality threshold.",
  finalized: "Past the local devnet finality threshold in this fixture.",
  verified: "Fixture report says supported deterministic checks passed.",
  unresolved: "Required evidence is absent or not resolvable from fixture inputs.",
  invalid: "Supported checks ran and a deterministic mismatch was recorded.",
  unsupported: "Current V0 rules do not evaluate this object type or payload.",
  reorged: "The fixture marks the prior observation or block as noncanonical.",
  offline: "No usable heartbeat is present in the fixture window.",
  stale: "A newer local record exists or the object is outside freshness policy.",
};

export function isDashboardStatus(value: string): value is DashboardStatus {
  return DASHBOARD_STATUSES.includes(value as DashboardStatus);
}

export function statusClassName(status: DashboardStatus): string {
  return `status-badge status-${status}`;
}

