import { useEffect, useState } from "react";
import { Route, Routes } from "react-router-dom";
import { AlertTriangle, RefreshCw } from "lucide-react";
import { AppShell } from "./components/AppShell";
import { DEFAULT_CANARY_DASHBOARD_DATA_PATH, fetchDashboardData } from "./data/loadDashboardData";
import type { DashboardData } from "./data/types";
import { DEFAULT_CONTROL_PLANE_URL, buildWorkbenchSnapshot, fetchWorkbenchSnapshot, type WorkbenchSnapshot } from "./data/workbench";
import { AlertsView } from "./views/AlertsView";
import { BridgePilotView } from "./views/BridgePilotView";
import { CanaryDeploymentView } from "./views/CanaryDeploymentView";
import { DevnetBlocksView } from "./views/DevnetBlocksView";
import { ExplorerView } from "./views/ExplorerView";
import { FlowMemoryView } from "./views/FlowMemoryView";
import { FlowPulseStreamView } from "./views/FlowPulseStreamView";
import { HardwareNodesView } from "./views/HardwareNodesView";
import { OverviewView } from "./views/OverviewView";
import { RawJsonInspectorView } from "./views/RawJsonInspectorView";
import { RootfieldsView } from "./views/RootfieldsView";
import { VerifierReportsView } from "./views/VerifierReportsView";
import { WalletView } from "./views/WalletView";
import { WorkbenchView } from "./views/WorkbenchView";
import { WorkReceiptsView } from "./views/WorkReceiptsView";

function LoadingState() {
  return (
    <div className="boot-screen" role="status">
      <div className="boot-panel">
        <div className="skeleton-line skeleton-title" />
        <div className="skeleton-line" />
        <div className="skeleton-line skeleton-short" />
        <p className="boot-hint">
          Loading dashboard fixtures and probing {DEFAULT_CONTROL_PLANE_URL}/health plus /state. If this stays offline,
          start the local service with <code>npm run flowchain:start</code>.
        </p>
        <div className="boot-grid">
          <div />
          <div />
          <div />
        </div>
      </div>
    </div>
  );
}

function ErrorState({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div className="boot-screen" role="alert">
      <div className="error-panel">
        <AlertTriangle size={28} aria-hidden="true" />
        <div>
          <h1>Dashboard fixture failed to load</h1>
          <p>{message}</p>
          <p>
            Run <code>npm run launch:v0</code> or <code>npm run sync:fixtures --prefix apps/dashboard</code> to refresh
            local dashboard data, then retry.
          </p>
          <button className="button button-primary" type="button" onClick={onRetry}>
            <RefreshCw size={16} aria-hidden="true" />
            Retry fixture load
          </button>
        </div>
      </div>
    </div>
  );
}

export default function App() {
  const [data, setData] = useState<DashboardData | null>(null);
  const [canaryData, setCanaryData] = useState<DashboardData | null>(null);
  const [workbench, setWorkbench] = useState<WorkbenchSnapshot | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [version, setVersion] = useState(0);

  useEffect(() => {
    let cancelled = false;

    Promise.all([
      fetchDashboardData(),
      fetchDashboardData(DEFAULT_CANARY_DASHBOARD_DATA_PATH),
    ])
      .then(async ([nextData, nextCanaryData]) => {
        const nextWorkbench = await fetchWorkbenchSnapshot(nextData).catch((nextError: unknown) =>
          buildWorkbenchSnapshot(nextData, {
            loadIssues: [nextError instanceof Error ? nextError.message : "Unknown workbench load error."],
          }),
        );

        if (!cancelled) {
          setData(nextData);
          setCanaryData(nextCanaryData);
          setWorkbench(nextWorkbench);
          setError(null);
        }
      })
      .catch((nextError: unknown) => {
        if (!cancelled) {
          setError(nextError instanceof Error ? nextError.message : "Unknown dashboard data load error.");
        }
      });

    return () => {
      cancelled = true;
    };
  }, [version]);

  if (error) {
    return <ErrorState message={error} onRetry={() => setVersion((current) => current + 1)} />;
  }

  if (data === null || canaryData === null) {
    return <LoadingState />;
  }

  if (workbench === null) {
    return <LoadingState />;
  }

  return (
    <AppShell data={data} canaryData={canaryData} workbench={workbench}>
      <Routes>
        <Route path="/" element={<WorkbenchView data={data} workbench={workbench} onRefresh={() => setVersion((current) => current + 1)} />} />
        <Route path="/wallet" element={<WalletView workbench={workbench} />} />
        <Route path="/bridge" element={<BridgePilotView workbench={workbench} />} />
        <Route path="/explorer" element={<ExplorerView data={data} workbench={workbench} />} />
        <Route path="/overview" element={<OverviewView data={data} />} />
        <Route path="/canary" element={<CanaryDeploymentView data={canaryData} />} />
        <Route path="/flowmemory" element={<FlowMemoryView data={data} />} />
        <Route path="/flowpulse" element={<FlowPulseStreamView data={data} />} />
        <Route path="/rootfields" element={<RootfieldsView data={data} />} />
        <Route path="/work" element={<WorkReceiptsView data={data} />} />
        <Route path="/verifier" element={<VerifierReportsView data={data} />} />
        <Route path="/devnet" element={<DevnetBlocksView data={data} />} />
        <Route path="/hardware" element={<HardwareNodesView data={data} />} />
        <Route path="/alerts" element={<AlertsView data={data} />} />
        <Route path="/raw" element={<RawJsonInspectorView data={data} workbench={workbench} />} />
      </Routes>
    </AppShell>
  );
}
