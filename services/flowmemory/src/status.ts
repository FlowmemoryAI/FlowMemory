export const FLOW_MEMORY_STATUSES = [
  "observed",
  "pending",
  "finalized",
  "verified",
  "unresolved",
  "failed",
  "unsupported",
  "reorged",
  "offline",
  "stale",
] as const;

export type FlowMemoryStatus = (typeof FLOW_MEMORY_STATUSES)[number];

export const VERIFIER_TO_FLOW_MEMORY_STATUS = {
  valid: "verified",
  invalid: "failed",
  unresolved: "unresolved",
  unsupported: "unsupported",
  reorged: "reorged",
} as const;

export type VerifierResultStatus = keyof typeof VERIFIER_TO_FLOW_MEMORY_STATUS;

export function verifierStatusToFlowMemoryStatus(status: string): FlowMemoryStatus {
  if (status in VERIFIER_TO_FLOW_MEMORY_STATUS) {
    return VERIFIER_TO_FLOW_MEMORY_STATUS[status as VerifierResultStatus];
  }
  throw new Error(`unsupported verifier status for Flow Memory adapter: ${status}`);
}

export function observationLifecycleToFlowMemoryStatus(lifecycleState: string): FlowMemoryStatus {
  if (lifecycleState === "removed") {
    return "reorged";
  }
  if (FLOW_MEMORY_STATUSES.includes(lifecycleState as FlowMemoryStatus)) {
    return lifecycleState as FlowMemoryStatus;
  }
  if (lifecycleState === "superseded") {
    return "stale";
  }
  return "observed";
}

export function transitionStatus(lifecycleState: string, verifierStatus?: string): FlowMemoryStatus {
  const observationStatus = observationLifecycleToFlowMemoryStatus(lifecycleState);
  if (observationStatus === "reorged" || observationStatus === "stale") {
    return observationStatus;
  }
  if (verifierStatus === undefined) {
    return observationStatus;
  }

  const mapped = verifierStatusToFlowMemoryStatus(verifierStatus);
  if (observationStatus === "pending" && mapped === "verified") {
    return "pending";
  }
  return mapped;
}
