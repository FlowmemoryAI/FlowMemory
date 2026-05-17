import { afterEach, describe, expect, it, vi } from "vitest";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { MemoryRouter } from "react-router-dom";
import canaryFixture from "../../../../fixtures/dashboard/flowmemory-dashboard-base-canary-v0.json";
import fixture from "../../../../fixtures/dashboard/flowmemory-dashboard-v0.json";
import devnetDashboardState from "../../../../fixtures/launch-core/generated/devnet/dashboard-state.json";
import devnetState from "../../../../fixtures/launch-core/generated/devnet/state.json";
import bridgeTestDeposit from "../../public/data/flowchain-bridge-test-deposit.json";
import liveReadinessReport from "../../public/data/flowchain-live-readiness-report.json";
import { validateDashboardData } from "../data/loadDashboardData";
import { DASHBOARD_STATUSES } from "../data/status";
import { computeOverviewMetrics, searchRecords } from "../data/selectors";
import type { DashboardData, ProvenancedRecord } from "../data/types";
import {
  DEFAULT_CONTROL_PLANE_URL,
  WORKBENCH_BRIDGE_TEST_DEPOSIT_PATH,
  WORKBENCH_DEVNET_DASHBOARD_STATE_PATH,
  WORKBENCH_DEVNET_STATE_PATH,
  WORKBENCH_LIVE_READINESS_REPORT_PATH,
  WORKBENCH_SECTIONS,
  buildWorkbenchSnapshot,
  fetchWorkbenchSnapshot,
} from "../data/workbench";
import { WalletView } from "../views/WalletView";
import { ExternalTesterLaunchView } from "../views/ExternalTesterLaunchView";
import { ExplorerView } from "../views/ExplorerView";
import { OpsView } from "../views/OpsView";
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
      bridgeTestDeposit,
      liveReadinessReport,
    });

    expect(workbench.source).toBe("fixture-fallback");
    expect(workbench.controlPlane.url).toBe(DEFAULT_CONTROL_PLANE_URL);
    expect(workbench.sections.blocks).toHaveLength(2);
    expect(workbench.sections.transactions.length).toBeGreaterThanOrEqual(6);
    expect(workbench.sections.transactions.every((transaction) => transaction.status === "finalized")).toBe(true);
    expect(workbench.sections.nodeStatus.length).toBeGreaterThan(0);
    expect(workbench.sections.mempool).toHaveLength(0);
    expect(workbench.sections.accounts.length).toBeGreaterThan(0);
    expect(workbench.sections.walletMetadata.length).toBeGreaterThan(0);
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
    expect(workbench.sections.balances.length).toBeGreaterThan(0);
    expect(workbench.sections.tokenLaunches).toHaveLength(0);
    expect(workbench.sections.tokenBalances).toHaveLength(0);
    expect(workbench.sections.dexPools).toHaveLength(0);
    expect(workbench.sections.liquidityPositions).toHaveLength(0);
    expect(workbench.sections.swaps).toHaveLength(0);
    expect(workbench.sections.bridgeDeposits.length).toBeGreaterThan(0);
    expect(workbench.sections.bridgeCredits).toHaveLength(0);
    expect(workbench.sections.bridgeWithdrawals).toHaveLength(0);
    expect(workbench.sections.realValuePilot.length).toBeGreaterThan(0);
    expect(workbench.sections.realValuePilot[0].facts.find((fact) => fact.label === "scope")?.value).toBe("capped owner testing");
    expect(workbench.sections.liveReadiness.length).toBeGreaterThan(0);
    expect(workbench.sections.liveReadiness[0].facts.find((fact) => fact.label === "deployment ready")?.value).toBe("false");
    expect(workbench.sections.liveReadiness.some((record) => record.id === "public-rpc-edge")).toBe(true);
    expect(workbench.sections.explorerRecords.length).toBeGreaterThan(0);
    expect(workbench.node.status).toBe("offline");
    expect(workbench.actions).toEqual([]);

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
        pilotStatus: {
          schema: "flowmemory.control_plane.real_value_pilot_status.v0",
          pilotId: `0x${"a".repeat(64)}`,
          label: "FlowChain capped owner real-value pilot",
          state: "degraded",
          stateReason: "Only mock/local/Base Sepolia bridge observations are visible.",
          baseChainId: 8453,
          cappedOwnerTesting: true,
          broadPublicReadiness: false,
          productionReady: false,
          browserStoresSecrets: false,
          nextOperatorStep: {
            label: "Observe Base 8453 deposit",
            command: "npm run bridge:observe -- --mode base-mainnet-canary --acknowledge-real-funds --max-usd 25",
            reason: "No Base 8453 pilot deposit has been loaded.",
          },
          lifecycle: [{
            phase: "base_deposit_observed",
            state: "degraded",
            title: "Observe Base 8453 deposit",
            summary: "No Base 8453 pilot deposit has been loaded.",
            nextOperatorCommand: "npm run bridge:observe -- --mode base-mainnet-canary --acknowledge-real-funds --max-usd 25",
          }],
          capStatus: { state: "degraded", withinCap: true, productionReady: false },
          pauseStatus: { state: "live", status: "unpaused", productionReady: false },
          retryStatus: { state: "live", duplicateReplayKeys: [], productionReady: false },
          emergencyStatus: { state: "live", status: "standby", productionReady: false },
        },
      },
      devnetState,
      devnetDashboardState,
    });

    expect(workbench.source).toBe("control-plane");
    expect(workbench.node.status).toBe("verified");
    expect(workbench.sections.blocks[0].provenance.origin).toBe("local");
    expect(workbench.sections.blocks[0].provenance.localPathHint).toBe("http://127.0.0.1:8787");
    expect(workbench.sections.realValuePilot[0].title).toBe("Pilot degraded");
    expect(workbench.sections.realValuePilot[0].summary).toContain("Only mock/local/Base Sepolia");
    expect(workbench.sections.provenance.find((record) => record.id === "control-plane-api")?.status).toBe("verified");
  });

  it("only exposes local actions when the control-plane advertises matching endpoints", () => {
    const workbench = buildWorkbenchSnapshot(data, {
      controlPlane: {
        url: "http://127.0.0.1:8787",
        status: "available",
        checkedAt: "2026-05-13T15:00:00.000Z",
        endpoints: ["GET /health", "GET /state", "POST /smoke", "POST /faucet"],
        health: { status: "ok" },
        state: devnetState,
      },
      devnetState,
      devnetDashboardState,
    });

    expect(workbench.actions.map((action) => action.endpoint)).toEqual(["POST /smoke", "POST /faucet"]);
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
      if (url.endsWith("/pilot/status")) {
        return Response.json({
          schema: "flowmemory.control_plane.real_value_pilot_status.v0",
          state: "degraded",
          label: "FlowChain capped owner real-value pilot",
          stateReason: "Waiting for Base 8453 deposit.",
          baseChainId: 8453,
          cappedOwnerTesting: true,
          broadPublicReadiness: false,
          productionReady: false,
          browserStoresSecrets: false,
          nextOperatorStep: {
            command: "npm run bridge:observe -- --mode base-mainnet-canary --acknowledge-real-funds --max-usd 25",
          },
          lifecycle: [],
        });
      }
      if (url.endsWith("/bridge/live-readiness")) {
        return Response.json({
          schema: "flowmemory.control_plane.bridge_live_readiness.v0",
          baseChainId: 8453,
          baseChainName: "Base",
          failClosedStatus: "BLOCKED",
          readyForOperatorLivePilot: false,
          lockbox: { configured: false, envName: "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", ownerVerified: false },
          node: { running: true, chainId: "flowmemory-local-devnet-v0" },
          confirmationDepth: { configured: false, envName: "FLOWCHAIN_BASE8453_CONFIRMATION_DEPTH" },
          missingEnvNames: ["FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS"],
          currentArtifacts: { base8453DepositCount: 0, localOrMockDepositCount: 1, mockPresentedAsLive: false },
          issues: [{
            reasonCode: "missing_env",
            status: "blocked",
            title: "Missing live pilot env",
            summary: "Live readiness is blocked until all required env names are present.",
            envNames: ["FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS"],
          }],
          envValuesPrinted: false,
          localOnly: true,
          productionReady: false,
        });
      }
      if (url.endsWith("/pilot/lifecycle")) {
        return Response.json({
          schema: "flowmemory.control_plane.bridge_lifecycle_record_list.v0",
          count: 1,
          lifecycleRecords: [{
            lifecycleRecordId: "lifecycle:1",
            baseTxHash: `0x${"1".repeat(64)}`,
            logIndex: 0,
            depositId: "deposit:1",
            replayKey: "replay:1",
            replayStatus: "accepted",
            creditId: "credit:1",
            recipientWallet: "wallet:credited",
            withdrawalIntentId: "withdrawal:1",
            withdrawalStatus: "requested",
            releaseEvidenceId: "release:1",
            releaseStatus: "recorded",
            asset: "local-test-unit",
            amountSmallestUnits: "100",
            status: "credited",
            artifactClass: "local-or-mock",
            liveArtifact: false,
            evidenceFilePath: "fixtures/bridge/local-runtime-bridge-handoff.json",
            equality: {
              depositAmount: "100",
              observedAmount: "100",
              creditedAmount: "100",
              walletDelta: "100",
              transferableAmount: "100",
              withdrawalAmount: "100",
              releaseAmount: "100",
              allEqual: true,
              equalities: { walletDelta: true },
            },
          }],
        });
      }
      if (url.endsWith("/wallets/balances")) {
        return Response.json({
          schema: "flowmemory.control_plane.wallet_balance_list.v0",
          count: 1,
          balances: [{
            balanceId: "balance:credited",
            walletAddress: "wallet:credited",
            asset: "local-test-unit",
            amount: "100",
            status: "credited",
            creditId: "credit:1",
          }],
        });
      }
      if (url.endsWith("/wallets/transfers")) {
        return Response.json({
          schema: "flowmemory.control_plane.wallet_transfer_history.v0",
          count: 1,
          transfers: [{
            transferId: "transfer:1",
            txId: "tx:transfer:1",
            fromAccountId: "wallet:credited",
            toAccountId: "wallet:recipient",
            assetId: "local-test-unit",
            amount: "100",
            status: "applied",
          }],
        });
      }
      if (url === WORKBENCH_DEVNET_STATE_PATH) {
        return Response.json(devnetState);
      }
      if (url === WORKBENCH_DEVNET_DASHBOARD_STATE_PATH) {
        return Response.json(devnetDashboardState);
      }
      if (url === WORKBENCH_BRIDGE_TEST_DEPOSIT_PATH) {
        return Response.json(bridgeTestDeposit);
      }
      if (url === WORKBENCH_LIVE_READINESS_REPORT_PATH) {
        return Response.json(liveReadinessReport);
      }

      return new Response("not found", { status: 404 });
    });
    globalThis.fetch = fetchMock as typeof fetch;

    const workbench = await fetchWorkbenchSnapshot(data);

    expect(workbench.source).toBe("control-plane");
    expect(workbench.raw.controlPlaneHealth).toEqual({ status: "ok" });
    expect(workbench.raw.controlPlaneState).toEqual({ state: devnetState });
    expect(workbench.raw.controlPlanePilotStatus).toMatchObject({ state: "degraded" });
    expect(workbench.raw.controlPlaneBridgeReadiness).toMatchObject({ failClosedStatus: "BLOCKED" });
    expect(workbench.raw.controlPlanePilotLifecycle).toMatchObject({ count: 1 });
    expect(workbench.sections.realValuePilot.some((record) => record.kind === "Bridge live readiness")).toBe(true);
    expect(workbench.sections.realValuePilot.some((record) => record.kind === "Bridge exact lifecycle")).toBe(true);
    expect(workbench.sections.realValuePilot.some((record) => record.kind === "Wallet transfer history")).toBe(true);
    const lifecycleRecord = workbench.sections.realValuePilot.find((record) => record.kind === "Bridge exact lifecycle");
    expect(lifecycleRecord?.facts.find((fact) => fact.label === "replay key")?.value).toBe("replay:1");
    expect(lifecycleRecord?.facts.find((fact) => fact.label === "withdrawal intent")?.value).toBe("withdrawal:1");
    expect(lifecycleRecord?.facts.find((fact) => fact.label === "release evidence")?.value).toBe("release:1");
    expect(lifecycleRecord?.facts.find((fact) => fact.label === "withdrawal amount")?.value).toBe("100");
    expect(lifecycleRecord?.facts.find((fact) => fact.label === "release amount")?.value).toBe("100");
    expect(workbench.raw.devnetState).toEqual(devnetState);
    expect(workbench.raw.bridgeTestDeposit).toEqual(bridgeTestDeposit);
    expect(workbench.loadIssues).toEqual([]);
    expect(fetchMock).toHaveBeenCalledWith("http://127.0.0.1:8787/health", expect.any(Object));
    expect(fetchMock).toHaveBeenCalledWith("http://127.0.0.1:8787/pilot/status", expect.any(Object));
    expect(fetchMock).toHaveBeenCalledWith("http://127.0.0.1:8787/bridge/live-readiness", expect.any(Object));
    expect(fetchMock).toHaveBeenCalledWith("http://127.0.0.1:8787/pilot/lifecycle", expect.any(Object));
    expect(fetchMock).toHaveBeenCalledWith(WORKBENCH_DEVNET_STATE_PATH, expect.any(Object));
    expect(fetchMock).toHaveBeenCalledWith(WORKBENCH_BRIDGE_TEST_DEPOSIT_PATH, expect.any(Object));
    expect(fetchMock).toHaveBeenCalledWith(WORKBENCH_LIVE_READINESS_REPORT_PATH, expect.any(Object));
  });

  it("renders live public launch readiness from infra reports", () => {
    const workbench = buildWorkbenchSnapshot(data, {
      devnetState,
      devnetDashboardState,
      bridgeTestDeposit,
      liveReadinessReport,
    });
    const html = renderToStaticMarkup(createElement(WorkbenchView, { data, workbench }));

    expect(html).toContain("Public launch readiness");
    expect(html).toContain("Public launch blocked");
    expect(html).toContain("Public RPC edge");
    expect(html).toContain("State backup proof");
    expect(html).toContain("Backup dry run");
    expect(html).toContain("Bridge relayer queue");
    expect(html).toContain("External tester packet");
    expect(html).toContain("FLOWCHAIN_RPC_PUBLIC_URL");
    expect(html).toContain("flowchain:public-deployment:contract");
  });

  it("renders wallet tester gateway controls without secrets", () => {
    const workbench = buildWorkbenchSnapshot(data, {
      devnetState,
      devnetDashboardState,
      bridgeTestDeposit,
      liveReadinessReport,
    });
    const html = renderToStaticMarkup(createElement(MemoryRouter, { initialEntries: ["/wallet?panel=tester"] }, createElement(WalletView, { workbench })));

    expect(html).toContain("Tester gateway");
    expect(html).toContain("Open tester tools");
    expect(html).toContain("Inspect tester activity");
    expect(html).toContain("Open ops status");
    expect(html).toContain("Friend access");
    expect(html).toContain("FLOWCHAIN_TESTER_WRITE_ENABLED");
    expect(html).not.toContain("local-tester-write-token");
  });

  it("renders the dedicated friends-and-family launch flow without secrets", () => {
    const workbench = buildWorkbenchSnapshot(data, {
      devnetState,
      devnetDashboardState,
      bridgeTestDeposit,
      liveReadinessReport,
    });
    const html = renderToStaticMarkup(createElement(MemoryRouter, { initialEntries: ["/tester"] }, createElement(ExternalTesterLaunchView, { workbench })));

    expect(html).toContain("Friends-and-family launch");
    expect(html).toContain("Shareable");
    expect(html).toContain("Packet smoke");
    expect(html).toContain("Gateway proof");
    expect(html).toContain("Owner inputs");
    expect(html).toContain("FLOWCHAIN_RPC_PUBLIC_URL");
    expect(html).toContain("FLOWCHAIN_TESTER_WRITE_ENABLED");
    expect(html).toContain("/tester/wallets/create");
    expect(html).toContain("npm run flowchain:external-tester:packet");
    expect(html).not.toContain("local-tester-write-token");
  });

  it("renders the explorer route for tester-visible chain activity without secrets", () => {
    const workbench = buildWorkbenchSnapshot(data, {
      devnetState,
      devnetDashboardState,
      bridgeTestDeposit,
      liveReadinessReport,
    });
    const html = renderToStaticMarkup(createElement(MemoryRouter, null, createElement(ExplorerView, { data, workbench })));

    expect(html).toContain("Flowchain explorer");
    expect(html).toContain("Create, fund, send, inspect");
    expect(html).toContain("Open tester tools");
    expect(html).toContain("Funding proofs");
    expect(html).toContain("Blocks");
    expect(html).toContain("Transactions");
    expect(html).toContain("Wallets");
    expect(html).toContain("Bridge");
    expect(html).not.toContain("local-tester-write-token");
  });

  it("renders the ops center from alert and incident reports without secrets", () => {
    const workbench = buildWorkbenchSnapshot(data, {
      devnetState,
      devnetDashboardState,
      bridgeTestDeposit,
      liveReadinessReport,
    });
    const html = renderToStaticMarkup(createElement(MemoryRouter, null, createElement(OpsView, { workbench })));

    expect(html).toContain("Ops center");
    expect(html).toContain("Current findings");
    expect(html).toContain("Incident commands");
    expect(html).toContain("network sends; stores secrets");
    expect(html).toContain("Relayer loop");
    expect(html).toContain("Escalation dry run");
    expect(html).toContain("public-rpc-not-ready");
    expect(html).not.toContain("local-tester-write-token");
  });

  it("renders bridge readiness live-blocked without env values", () => {
    const configuredButHidden = "https://example.invalid/rpc-redacted";
    const workbench = buildWorkbenchSnapshot(data, {
      controlPlane: {
        url: "http://127.0.0.1:8787",
        status: "available",
        checkedAt: "2026-05-14T15:00:00.000Z",
        endpoints: ["GET /health", "GET /state", "GET /bridge/live-readiness", "GET /pilot/lifecycle"],
        health: { status: "ok" },
        state: devnetState,
        pilotStatus: {
          schema: "flowmemory.control_plane.real_value_pilot_status.v0",
          state: "degraded",
          stateReason: "Waiting for Base 8453 deposit.",
          baseChainId: 8453,
          cappedOwnerTesting: true,
          broadPublicReadiness: false,
          productionReady: false,
          browserStoresSecrets: false,
          nextOperatorStep: { command: "npm run control-plane:serve" },
          lifecycle: [],
        },
        bridgeLiveReadiness: {
          schema: "flowmemory.control_plane.bridge_live_readiness.v0",
          baseChainId: 8453,
          baseChainName: "Base",
          failClosedStatus: "BLOCKED",
          readyForOperatorLivePilot: false,
          lockbox: { configured: false, envName: "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS", ownerVerified: false },
          node: { running: true, chainId: "flowmemory-local-devnet-v0" },
          confirmationDepth: { configured: false, envName: "FLOWCHAIN_BASE8453_CONFIRMATION_DEPTH" },
          missingEnvNames: ["FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS"],
          currentArtifacts: { base8453DepositCount: 0, localOrMockDepositCount: 1, mockPresentedAsLive: false },
          issues: [{
            reasonCode: "missing_env",
            status: "blocked",
            title: "Missing live pilot env",
            summary: "Live readiness is blocked until all required env names are present.",
            envNames: ["FLOWCHAIN_BASE8453_RPC_URL", "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS"],
          }],
          envValuesPrinted: false,
          localOnly: true,
          productionReady: false,
        },
      },
      devnetState,
      devnetDashboardState,
    });
    const html = renderToStaticMarkup(createElement(WorkbenchView, { data, workbench }));

    expect(html).toContain("Bridge live readiness");
    expect(html).toContain("BLOCKED");
    expect(html).toContain("FLOWCHAIN_BASE8453_RPC_URL");
    expect(html).toContain("FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS");
    expect(html).toContain("env values printed");
    expect(html).toContain("false");
    expect(html).not.toContain(configuredButHidden);
  });

  it("renders the critical workbench view labels from fixture fallback", () => {
    const workbench = buildWorkbenchSnapshot(data, {
      devnetState,
      devnetDashboardState,
      bridgeTestDeposit,
      liveReadinessReport,
    });
    const html = renderToStaticMarkup(createElement(WorkbenchView, { data, workbench }));

    expect(html).toContain("Local explorer workbench");
    expect(html).toContain("Node and API status");
    expect(html).toContain("Control-plane offline");
    expect(html).toContain("Real-value pilot");
    expect(html).toContain("Bridge live readiness");
    expect(html).toContain("Public launch readiness");
    expect(html).toContain("Live Readiness");
    expect(html).toContain("capped owner testing");
    expect(html).toContain("public readiness");
    expect(html).toContain("Wallet Metadata");
    expect(html).toContain("Token Launch");
    expect(html).toContain("Token Balances");
    expect(html).toContain("DEX Pools");
    expect(html).toContain("Liquidity");
    expect(html).toContain("Swaps");
    expect(html).toContain("Explorer Records");
    expect(html).toContain("Bridge Deposits");
    expect(html).toContain("private keys in browser localStorage");
    expect(html).toContain("Rootfields");
    expect(html).toContain("Verifier Modules");
    expect(html).toContain("Hardware Signals");
    expect(html).toContain("Raw JSON");
  });
});
