import type { ReactNode } from "react";
import { NavLink, useLocation } from "react-router-dom";
import {
  Activity,
  Bell,
  Binary,
  Braces,
  BrainCircuit,
  Boxes,
  ClipboardCheck,
  ArrowRightLeft,
  RadioReceiver,
  LayoutDashboard,
  Monitor,
  Network,
  RadioTower,
  ShieldCheck,
  Wallet,
} from "lucide-react";
import type { DashboardData } from "../data/types";
import type { WorkbenchSnapshot } from "../data/workbench";
import { StatusBadge } from "./StatusBadge";

interface AppShellProps {
  data: DashboardData;
  canaryData?: DashboardData;
  workbench: WorkbenchSnapshot;
  children: ReactNode;
}

const NAV_ITEMS = [
  { to: "/", label: "Workbench", icon: Monitor },
  { to: "/wallet", label: "Wallet", icon: Wallet },
  { to: "/bridge", label: "Bridge pilot", icon: ArrowRightLeft },
  { to: "/overview", label: "Overview", icon: LayoutDashboard },
  { to: "/canary", label: "Base canary", icon: RadioReceiver },
  { to: "/flowmemory", label: "Flow Memory", icon: BrainCircuit },
  { to: "/flowpulse", label: "FlowPulse", icon: Activity },
  { to: "/rootfields", label: "Rootfields", icon: Boxes },
  { to: "/work", label: "Work lanes", icon: ClipboardCheck },
  { to: "/verifier", label: "Verifier", icon: ShieldCheck },
  { to: "/devnet", label: "Devnet", icon: Network },
  { to: "/hardware", label: "Hardware", icon: RadioTower },
  { to: "/alerts", label: "Alerts", icon: Bell },
  { to: "/raw", label: "Raw JSON", icon: Braces },
];

export function AppShell({ data, canaryData, workbench, children }: AppShellProps) {
  const location = useLocation();
  const isBridgeRoute = location.pathname.startsWith("/bridge");
  const isWalletRoute = location.pathname.startsWith("/wallet");
  if (isBridgeRoute || isWalletRoute) {
    return <>{children}</>;
  }

  const isCanaryRoute = location.pathname.startsWith("/canary");
  const activeData = isCanaryRoute && canaryData ? canaryData : data;
  const bannerMode = isCanaryRoute
    ? {
        lead: "Canary-only review active.",
        detail:
          "This route uses the guarded Base canary fixture and keeps local fixture/V0 workbench views separate. It is not a production launch or production-readiness claim.",
      }
    : {
        lead: workbench.source === "control-plane" ? "Local API detected." : "Fixture fallback active.",
        detail: `Runtime JSON is loaded from ${data.metadata.runtimeDataPath}; control-plane integration probes ${workbench.controlPlane.url} and falls back to deterministic fixture data when unavailable.`,
      };

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand-block">
          <div className="brand-mark" aria-hidden="true">
            <Binary size={20} />
          </div>
          <div>
            <span className="brand-kicker">FlowMemory</span>
            <strong>Workbench V0</strong>
          </div>
        </div>
        <nav className="nav-list" aria-label="Dashboard views">
          {NAV_ITEMS.map(({ to, label, icon: Icon }) => (
            <NavLink key={to} to={to} end={to === "/"} className="nav-link">
              <Icon size={17} aria-hidden="true" />
              <span>{label}</span>
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-footer">
          <StatusBadge status={workbench.source === "control-plane" ? "verified" : "stale"} compact />
          <span>{workbench.source}</span>
          {canaryData ? <span>{canaryData.metadata.mode} data ready</span> : null}
          <small>{data.chain.name}</small>
        </div>
      </aside>

      <div className="workspace">
        <header className="topbar">
          <div>
            <span className="eyebrow">{isCanaryRoute ? "guarded canary surface" : "local operator surface"}</span>
            <h2>{activeData.chain.name}</h2>
          </div>
          <div className="topbar-meta" aria-label="Data provenance">
            <span>chain {activeData.chain.chainId}</span>
            <span>{isCanaryRoute ? activeData.metadata.mode : workbench.controlPlane.status}</span>
            <span>{activeData.chain.source}</span>
            <span>updated {new Date(activeData.chain.lastUpdated).toLocaleString()}</span>
          </div>
        </header>
        <div className="fixture-banner" role="note">
          <strong>{bannerMode.lead}</strong>
          <span>{bannerMode.detail}</span>
        </div>
        <main className="content">{children}</main>
      </div>
    </div>
  );
}
