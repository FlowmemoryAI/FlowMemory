import { afterEach, describe, expect, it, vi } from "vitest";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import canaryFixture from "../../../../fixtures/dashboard/flowmemory-dashboard-base-canary-v0.json";
import fixture from "../../../../fixtures/dashboard/flowmemory-dashboard-v0.json";
import bridgeDeposit from "../../../../fixtures/bridge/base-sepolia-mock-deposit.json";
import devnetDashboardState from "../../../../fixtures/launch-core/generated/devnet/dashboard-state.json";
import devnetState from "../../../../fixtures/launch-core/generated/devnet/state.json";
import { validateDashboardData } from "../data/loadDashboardData";
import { DASHBOARD_STATUSES } from "../data/status";
import { computeOverviewMetrics, searchRecords } from "../data/selectors";
import type { DashboardData, ProvenancedRecord } from "../data/types";
import {
  DEFAULT_CONTROL_PLANE_URL,
  WORKBENCH_BRIDGE_DEPOSIT_PATH,
  WORKBENCH_DEVNET_DASHBOARD_STATE_PATH,
  WORKBENCH_DEVNET_STATE_PATH,
  WORKBENCH_SECTIONS,
  buildWorkbenchSnapshot,
  fetchWorkbenchSnapshot,
} from "../data/workbench";
import { WorkbenchView } from "../views/WorkbenchView";

describe("dashboard fixture", () => {
  const data = validateDashboardData(fixture) as DashboardData;
  const canaryData = validateDashboardData(canaryFixture) as DashboardData;
  const originalFetch = globalThis.fetch;

  afterEach(() => {
    globalThis.fetch = originalFetch;
    vi.restoreAllMocks();
  });

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

  it("builds a FlowChain workbench from existing dashboard and devnet fixtures", () => {
    const workbench = buildWorkbenchSnapshot(data, {
      devnetState,
      devnetDashboardState,
    });

    expect(workbench.source).toBe("fixture-fallback");
    expect(workbench.controlPlane.url).toBe(DEFAULT_CONTROL_PLANE_URL);
    expect(workbench.sections.blocks).toHaveLength(2);
    expect(workbench.sections.transactions.length).toBeGreaterThanOrEqual(6);
    expect(workbench.sections.transactions.every((transaction) => transaction.status === "finalized")).toBe(true);
    expect(workbench.sections.accounts.length).toBeGreaterThan(0);
    expect(workbench.sections.wallets.length).toBeGreaterThan(0);
    expect(workbench.sections.balances.map((record) => record.id)).toContain("no-value-balance-boundary");
    expect(workbench.sections.rootfields.length).toBeGreaterThan(0);
    expect(workbench.sections.agents.length).toBeGreaterThan(0);
    expect(workbench.sections.receipts.length).toBeGreaterThan(data.workReceipts.length);
    expect(workbench.sections.memoryCells.length).toBeGreaterThan(0);
    expect(workbench.sections.artifacts.length).toBeGreaterThan(0);
    expect(workbench.sections.verifierModules.length).toBeGreaterThan(0);
    expect(workbench.sections.hardwareSignals.length).toBeGreaterThan(0);
    expect(workbench.sections.finality.length).toBeGreaterThan(1);
    expect(workbench.sections.provenance.map((record) => record.id)).toContain("control-plane-api");
    expect(workbench.sections.rawJson.map((record) => record.id)).toContain("raw-dashboard-fixture");
    expect(workbench.sections.models.length).toBeGreaterThan(0);
    expect(workbench.sections.challenges.length).toBeGreaterThan(0);
    expect(workbench.node.status).toBe("offline");

    for (const section of WORKBENCH_SECTIONS) {
      expect(workbench.sections[section.key], `${section.key} should be a defined workbench view`).toBeDefined();
    }
  });

  it("switches workbench provenance to local when control-plane state is available", () => {
    const workbench = buildWorkbenchSnapshot(data, {
      controlPlane: {
        url: "http://127.0.0.1:8787",
        status: "available",
        checkedAt: "2026-05-13T15:00:00.000Z",
        endpoints: ["GET /health", "GET /state"],
        health: { status: "ok" },
        state: devnetState,
      },
      devnetState,
      devnetDashboardState,
    });

    expect(workbench.source).toBe("control-plane");
    expect(workbench.node.status).toBe("verified");
    expect(workbench.sections.blocks[0].provenance.origin).toBe("local");
    expect(workbench.sections.blocks[0].provenance.localPathHint).toBe("http://127.0.0.1:8787");
    expect(workbench.sections.provenance.find((record) => record.id === "control-plane-api")?.status).toBe("verified");
  });

  it("fetches control-plane state while keeping deterministic fixture payloads available", async () => {
    const fetchMock = vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);

      if (url.endsWith("/health")) {
        return Response.json({ status: "ok" });
      }
      if (url.endsWith("/state")) {
        return Response.json({ state: devnetState });
      }
      if (url.endsWith("/rpc")) {
        return Response.json([
          { jsonrpc: "2.0", id: "chainStatus", result: { schema: "flowmemory.control_plane.chain_status.v0", capabilities: ["raw_json_reads"] } },
          { jsonrpc: "2.0", id: "devnetState", result: { schema: "flowmemory.control_plane.devnet_state.v0", blocks: devnetState.blocks } },
          { jsonrpc: "2.0", id: "blocks", result: { blocks: devnetState.blocks } },
          { jsonrpc: "2.0", id: "transactions", result: { transactions: [] } },
          { jsonrpc: "2.0", id: "rootfields", result: { rootfields: [] } },
          { jsonrpc: "2.0", id: "agents", result: { agents: [] } },
          { jsonrpc: "2.0", id: "models", result: { models: [] } },
          { jsonrpc: "2.0", id: "workReceipts", result: { workReceipts: [] } },
          { jsonrpc: "2.0", id: "receipts", result: { receipts: [] } },
          { jsonrpc: "2.0", id: "artifacts", result: { artifacts: [] } },
          { jsonrpc: "2.0", id: "verifierModules", result: { verifierModules: [] } },
          { jsonrpc: "2.0", id: "verifierReports", result: { reports: [] } },
          { jsonrpc: "2.0", id: "memoryCells", result: { memoryCells: [] } },
          { jsonrpc: "2.0", id: "challenges", result: { challenges: [] } },
          { jsonrpc: "2.0", id: "finality", result: { finality: [] } },
          { jsonrpc: "2.0", id: "rawDevnet", result: { raw: devnetState } },
          { jsonrpc: "2.0", id: "rawTxFixtures", result: { raw: { txs: [] } } },
        ]);
      }
      if (url === WORKBENCH_DEVNET_STATE_PATH) {
        return Response.json(devnetState);
      }
      if (url === WORKBENCH_DEVNET_DASHBOARD_STATE_PATH) {
        return Response.json(devnetDashboardState);
      }
      if (url === WORKBENCH_BRIDGE_DEPOSIT_PATH) {
        return Response.json(bridgeDeposit);
      }

      return new Response("not found", { status: 404 });
    });
    globalThis.fetch = fetchMock as typeof fetch;

    const workbench = await fetchWorkbenchSnapshot(data);

    expect(workbench.source).toBe("control-plane");
    expect(workbench.raw.controlPlaneHealth).toEqual({ status: "ok" });
    expect(workbench.raw.controlPlaneState).toEqual({ state: devnetState });
    expect(workbench.raw.controlPlaneRpc?.rawDevnet).toBeDefined();
    expect(workbench.raw.devnetState).toEqual(devnetState);
    expect(workbench.raw.bridgeDeposit).toEqual(bridgeDeposit);
    expect(workbench.loadIssues).toEqual([]);
    expect(fetchMock).toHaveBeenCalledWith("http://127.0.0.1:8787/health", expect.any(Object));
    expect(fetchMock).toHaveBeenCalledWith("http://127.0.0.1:8787/rpc", expect.any(Object));
    expect(fetchMock).toHaveBeenCalledWith(WORKBENCH_DEVNET_STATE_PATH, expect.any(Object));
  });

  it("renders the critical workbench view labels from fixture fallback", () => {
    const workbench = buildWorkbenchSnapshot(data, {
      devnetState,
      devnetDashboardState,
    });
    const html = renderToStaticMarkup(createElement(WorkbenchView, { data, workbench }));

    expect(html).toContain("Local explorer workbench");
    expect(html).toContain("Node and API status");
    expect(html).toContain("Local actions");
    expect(html).toContain("Control-plane offline");
    expect(html).toContain("Wallet Public Accounts");
    expect(html).toContain("Bridge Test Lane");
    expect(html).toContain("Rootfields");
    expect(html).toContain("Verifier Modules");
    expect(html).toContain("Hardware Signals");
    expect(html).toContain("Raw JSON");
  });
});
