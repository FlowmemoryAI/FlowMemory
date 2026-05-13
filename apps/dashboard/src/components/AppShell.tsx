import type { ReactNode } from "react";
import { NavLink } from "react-router-dom";
import {
  Activity,
  Bell,
  Binary,
  Braces,
  BrainCircuit,
  Boxes,
  ClipboardCheck,
  LayoutDashboard,
  Network,
  RadioTower,
  ShieldCheck,
} from "lucide-react";
import type { DashboardData } from "../data/types";
import { StatusBadge } from "./StatusBadge";

interface AppShellProps {
  data: DashboardData;
  children: ReactNode;
}

const NAV_ITEMS = [
  { to: "/", label: "Overview", icon: LayoutDashboard },
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

export function AppShell({ data, children }: AppShellProps) {
  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand-block">
          <div className="brand-mark" aria-hidden="true">
            <Binary size={20} />
          </div>
          <div>
            <span className="brand-kicker">FlowMemory</span>
            <strong>Dashboard V0</strong>
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
          <StatusBadge status="observed" compact />
          <span>{data.metadata.mode} data</span>
          <small>{data.chain.name}</small>
        </div>
      </aside>

      <div className="workspace">
        <header className="topbar">
          <div>
            <span className="eyebrow">local operator surface</span>
            <h2>{data.chain.name}</h2>
          </div>
          <div className="topbar-meta" aria-label="Data provenance">
            <span>chain {data.chain.chainId}</span>
            <span>{data.chain.source}</span>
            <span>updated {new Date(data.chain.lastUpdated).toLocaleString()}</span>
          </div>
        </header>
        <div className="fixture-banner" role="note">
          <strong>Fixture/local data only.</strong>
          <span>
            Runtime JSON is loaded from {data.metadata.runtimeDataPath}; future generated outputs should land in the
            documented fixture boundary before becoming live APIs.
          </span>
        </div>
        <main className="content">{children}</main>
      </div>
    </div>
  );
}
