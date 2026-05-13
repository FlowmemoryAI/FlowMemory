import { describe, expect, it } from "vitest";
import canaryFixture from "../../../../fixtures/dashboard/flowmemory-dashboard-base-canary-v0.json";
import fixture from "../../../../fixtures/dashboard/flowmemory-dashboard-v0.json";
import { validateDashboardData } from "../data/loadDashboardData";
import { DASHBOARD_STATUSES } from "../data/status";
import { computeOverviewMetrics, searchRecords } from "../data/selectors";
import type { DashboardData, ProvenancedRecord } from "../data/types";

describe("dashboard fixture", () => {
  const data = validateDashboardData(fixture) as DashboardData;
  const canaryData = validateDashboardData(canaryFixture) as DashboardData;

  it("loads the V0 dashboard fixture shape", () => {
    expect(data.metadata.schema).toBe("flowmemory.dashboard.fixture.v0");
    expect(data.metadata.mode).toBe("fixture");
    expect(data.flowPulseObservations.length).toBeGreaterThan(0);
    expect(data.verifierReports.length).toBeGreaterThan(0);
    expect(data.memorySignals.every((signal) => signal.contractEvent.eventName === "FlowPulse")).toBe(true);
    expect(data.memorySignals.every((signal) => signal.contractEvent.topicMatchesContract)).toBe(true);
    expect(data.memorySignals.some((signal) => signal.signalType === "swap_memory_signal")).toBe(true);
    expect(data.rootflowTransitions.every((transition) => transition.contractEventRef.signalId === transition.memorySignalId)).toBe(true);
  });

  it("loads the Base canary dashboard mode separately from local fixtures", () => {
    expect(canaryData.metadata.schema).toBe("flowmemory.dashboard.fixture.v0");
    expect(canaryData.metadata.mode).toBe("canary");
    expect(canaryData.metadata.canary?.productionReady).toBe(false);
    expect(canaryData.chain.environment).toBe("mainnet");
    expect(canaryData.chain.source).toBe("live");
    expect(canaryData.flowPulseObservations).toHaveLength(4);
    expect(canaryData.verifierReports).toHaveLength(0);
    expect(canaryData.memorySignals.some((signal) => signal.signalType === "swap_memory_signal")).toBe(true);
    expect(canaryData.agentMemoryViews.every((view) => view.localOnly === false)).toBe(true);
  });

  it("covers every required dashboard status", () => {
    const records: ProvenancedRecord[] = [
      ...data.flowPulseObservations,
      ...data.rootfields,
      ...data.workLanes,
      ...data.workReceipts,
      ...data.verifierReports,
      ...data.rootflowTransitions,
      ...data.memorySignals,
      ...data.memoryReceipts,
      ...data.rootfieldBundles,
      ...data.agentMemoryViews,
      ...data.devnetBlocks,
      ...data.hardwareNodes,
      ...data.alerts,
    ];
    const statuses = new Set(records.map((record) => record.status));

    for (const status of DASHBOARD_STATUSES) {
      expect(statuses.has(status), `${status} should appear in fixture data`).toBe(true);
    }
  });

  it("keeps provenance on every displayed record", () => {
    const records: ProvenancedRecord[] = [
      ...data.flowPulseObservations,
      ...data.rootfields,
      ...data.workLanes,
      ...data.workReceipts,
      ...data.verifierReports,
      ...data.rootflowTransitions,
      ...data.memorySignals,
      ...data.memoryReceipts,
      ...data.rootfieldBundles,
      ...data.agentMemoryViews,
      ...data.devnetBlocks,
      ...data.hardwareNodes,
      ...data.alerts,
    ];

    expect(records.every((record) => record.id && record.status && record.provenance.subsystem)).toBe(true);
    expect(records.every((record) => record.provenance.origin === "fixture")).toBe(true);
    expect(records.every((record) => record.provenance.chainContext === "flowmemory-local-v0")).toBe(true);
  });

  it("computes overview metrics and searches records", () => {
    const metrics = computeOverviewMetrics(data);
    const matches = searchRecords(data.verifierReports, "commitment.mismatch");

    expect(metrics).toHaveLength(5);
    expect(matches.map((match) => match.status)).toContain("failed");
  });
});
