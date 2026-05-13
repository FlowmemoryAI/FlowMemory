import { useEffect, useState } from "react";
import { Route, Routes } from "react-router-dom";
import { AlertTriangle, RefreshCw } from "lucide-react";
import { AppShell } from "./components/AppShell";
import { fetchDashboardData } from "./data/loadDashboardData";
import type { DashboardData } from "./data/types";
import { AlertsView } from "./views/AlertsView";
import { DevnetBlocksView } from "./views/DevnetBlocksView";
import { FlowPulseStreamView } from "./views/FlowPulseStreamView";
import { HardwareNodesView } from "./views/HardwareNodesView";
import { OverviewView } from "./views/OverviewView";
import { RawJsonInspectorView } from "./views/RawJsonInspectorView";
import { RootfieldsView } from "./views/RootfieldsView";
import { VerifierReportsView } from "./views/VerifierReportsView";
import { WorkReceiptsView } from "./views/WorkReceiptsView";

function LoadingState() {
  return (
    <div className="boot-screen" role="status">
      <div className="boot-panel">
        <div className="skeleton-line skeleton-title" />
        <div className="skeleton-line" />
        <div className="skeleton-line skeleton-short" />
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
  const [error, setError] = useState<string | null>(null);
  const [version, setVersion] = useState(0);

  useEffect(() => {
    let cancelled = false;

    fetchDashboardData()
      .then((nextData) => {
        if (!cancelled) {
          setData(nextData);
          setError(null);
        }
      })
      .catch((nextError: unknown) => {
        if (!cancelled) {
          setError(nextError instanceof Error ? nextError.message : "Unknown fixture load error.");
        }
      });

    return () => {
      cancelled = true;
    };
  }, [version]);

  if (error) {
    return <ErrorState message={error} onRetry={() => setVersion((current) => current + 1)} />;
  }

  if (data === null) {
    return <LoadingState />;
  }

  return (
    <AppShell data={data}>
      <Routes>
        <Route path="/" element={<OverviewView data={data} />} />
        <Route path="/flowpulse" element={<FlowPulseStreamView data={data} />} />
        <Route path="/rootfields" element={<RootfieldsView data={data} />} />
        <Route path="/work" element={<WorkReceiptsView data={data} />} />
        <Route path="/verifier" element={<VerifierReportsView data={data} />} />
        <Route path="/devnet" element={<DevnetBlocksView data={data} />} />
        <Route path="/hardware" element={<HardwareNodesView data={data} />} />
        <Route path="/alerts" element={<AlertsView data={data} />} />
        <Route path="/raw" element={<RawJsonInspectorView data={data} />} />
      </Routes>
    </AppShell>
  );
}
