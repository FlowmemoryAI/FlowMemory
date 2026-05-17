import { Link } from "react-router-dom";
import { Activity, BellRing, ListChecks, ShieldAlert, ShieldCheck, Terminal } from "lucide-react";
import { EmptyState } from "../components/EmptyState";
import { SectionHeader } from "../components/SectionHeader";
import { StatusBadge } from "../components/StatusBadge";
import type { DashboardStatus } from "../data/types";
import type { WorkbenchSnapshot } from "../data/workbench";

type UnknownRecord = Record<string, unknown>;

interface OpsFinding {
  severity: string;
  code: string;
  message: string;
  commands: string[];
}

interface OpsRule {
  id: string;
  severity: string;
  signal: string;
  threshold: string;
  commands: string[];
}

function isRecord(value: unknown): value is UnknownRecord {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function text(value: unknown, fallback = "not recorded"): string {
  if (value === null || value === undefined || value === "") {
    return fallback;
  }
  return String(value);
}

function stringList(value: unknown): string[] {
  return asArray(value).map((item) => text(item)).filter((item) => item !== "not recorded");
}

function statusFromOps(value: unknown): DashboardStatus {
  const normalized = text(value, "").toLowerCase();
  if (normalized === "critical" || normalized === "failed" || normalized === "failure") {
    return "failed";
  }
  if (normalized === "blocked" || normalized === "pending") {
    return "pending";
  }
  if (normalized === "clear" || normalized === "passed" || normalized === "verified") {
    return "verified";
  }
  return "observed";
}

function parseFindings(ops: UnknownRecord | null): OpsFinding[] {
  return asArray(ops?.findings).filter(isRecord).map((finding) => ({
    severity: text(finding.severity, "observed"),
    code: text(finding.code, "ops-finding"),
    message: text(finding.message, "Ops finding loaded without a message."),
    commands: stringList(finding.commands),
  }));
}

function parseRules(ops: UnknownRecord | null): OpsRule[] {
  return asArray(ops?.activeRules).filter(isRecord).map((rule) => ({
    id: text(rule.id, "ops-rule"),
    severity: text(rule.severity, "observed"),
    signal: text(rule.signal, "Ops rule signal"),
    threshold: text(rule.threshold, "not recorded"),
    commands: stringList(rule.commands),
  }));
}

function parseIncidentCommands(ops: UnknownRecord | null): Array<{ group: string; commands: string[] }> {
  const commandGroups = isRecord(ops?.incidentCommands) ? ops.incidentCommands : {};
  return Object.entries(commandGroups).map(([group, commands]) => ({
    group,
    commands: stringList(commands),
  }));
}

export function OpsView({ workbench }: { workbench: WorkbenchSnapshot }) {
  const liveReadiness = isRecord(workbench.raw.liveReadinessReport) ? workbench.raw.liveReadinessReport : null;
  const metrics = isRecord(liveReadiness?.metrics) ? liveReadiness.metrics : {};
  const ops = isRecord(liveReadiness?.ops) ? liveReadiness.ops : null;
  const findings = parseFindings(ops);
  const activeRules = parseRules(ops);
  const incidentCommands = parseIncidentCommands(ops);
  const alertState = text(ops?.alertState ?? metrics.opsAlertState, "not recorded");
  const snapshotStatus = text(ops?.snapshotStatus ?? metrics.opsSnapshotStatus, "not recorded");
  const incidentDrillStatus = text(ops?.incidentDrillStatus ?? metrics.incidentDrillStatus, "not recorded");
  const latestHeight = text(ops?.latestHeight ?? metrics.latestHeight);
  const criticalCount = text(ops?.criticalCount ?? metrics.opsCriticalCount, "0");
  const blockedCount = text(ops?.blockedCount ?? metrics.opsBlockedCount, "0");
  const bridgeGuardrailStatus = text(ops?.bridgeRelayerGuardrailStatus ?? metrics.bridgeRelayerGuardrailStatus, "not recorded");
  const bridgeGuardrailReady = text(ops?.bridgeRelayerGuardrailReady, bridgeGuardrailStatus === "passed" ? "true" : "false");
  const publicRpcDeployAutomationStatus = text(metrics.publicRpcDeploymentAutomationStatus, "not recorded");
  const publicRpcDeployAutomationAction = text(metrics.publicRpcDeploymentAutomationAction, "not recorded");
  const networkNotifications = text(ops?.sendsNetworkNotifications, "false");
  const storesSecrets = text(ops?.storesSecrets, "false");

  return (
    <div className="view-stack">
      <SectionHeader
        eyebrow="operations"
        title="Ops center"
        detail="Current block-production health, launch blockers, alert rules, and incident commands from the latest no-secret ops reports."
        action={
          <div className="workbench-header-actions">
            <Link className="button" to="/raw">
              <ListChecks size={15} aria-hidden="true" />
              Raw reports
            </Link>
            <Link className="button" to="/explorer">
              <Activity size={15} aria-hidden="true" />
              Explorer
            </Link>
          </div>
        }
      />

      <section className="ops-command-panel" aria-label="Ops status">
        <div>
          <span>Alert state</span>
          <strong>{alertState}</strong>
          <small>critical {criticalCount} / blocked {blockedCount}</small>
        </div>
        <div>
          <span>Snapshot</span>
          <strong>{snapshotStatus}</strong>
          <small>latest height {latestHeight}</small>
        </div>
        <div>
          <span>Incident drill</span>
          <strong>{incidentDrillStatus}</strong>
          <small>synthetic failures mapped</small>
        </div>
        <div>
          <span>Bridge guardrail</span>
          <strong>{bridgeGuardrailStatus}</strong>
          <small>fail-closed proof ready {bridgeGuardrailReady}</small>
        </div>
        <div>
          <span>RPC deploy automation</span>
          <strong>{publicRpcDeployAutomationStatus}</strong>
          <small>mode {publicRpcDeployAutomationAction}</small>
        </div>
        <div>
          <span>Delivery boundary</span>
          <strong>{networkNotifications}</strong>
          <small>network sends; stores secrets {storesSecrets}</small>
        </div>
      </section>

      <section className="ops-layout">
        <div className="ops-main">
          <article className="panel ops-findings-panel">
            <div className="panel-heading">
              <div>
                <ShieldAlert size={18} aria-hidden="true" />
                <h2>Current findings</h2>
              </div>
              <div className="ops-heading-status">
                <StatusBadge status={statusFromOps(alertState)} compact />
                <span>
                  <ShieldCheck size={15} aria-hidden="true" />
                  relayer guardrail {bridgeGuardrailStatus}
                </span>
              </div>
            </div>
            {findings.length > 0 ? (
              <div className="ops-finding-list">
                {findings.map((finding) => (
                  <article key={finding.code} className={`ops-finding ops-finding-${finding.severity}`}>
                    <div className="ops-finding-head">
                      <StatusBadge status={statusFromOps(finding.severity)} compact />
                      <span>{finding.severity}</span>
                    </div>
                    <h3>{finding.code}</h3>
                    <p>{finding.message}</p>
                    <div className="ops-command-list">
                      {finding.commands.map((command) => (
                        <code key={`${finding.code}:${command}`}>{command}</code>
                      ))}
                    </div>
                  </article>
                ))}
              </div>
            ) : (
              <EmptyState title="No current ops findings" detail="Run npm run flowchain:ops:alerts -- -AllowBlocked, then refresh the dashboard." />
            )}
          </article>
        </div>

        <aside className="ops-side">
          <article>
            <div className="ops-side-heading">
              <BellRing size={17} aria-hidden="true" />
              <strong>Active rules</strong>
            </div>
            {activeRules.length > 0 ? (
              <div className="ops-rule-list">
                {activeRules.map((rule) => (
                  <div key={rule.id}>
                    <span>{rule.severity}</span>
                    <strong>{rule.id}</strong>
                    <small>{rule.signal}</small>
                    <code>{rule.commands[0] ?? "not recorded"}</code>
                  </div>
                ))}
              </div>
            ) : (
              <small>No active alert rules are loaded.</small>
            )}
          </article>

          <article>
            <div className="ops-side-heading">
              <Terminal size={17} aria-hidden="true" />
              <strong>Incident commands</strong>
            </div>
            <div className="ops-incident-groups">
              {incidentCommands.map((group) => (
                <details key={group.group} open={group.group === "status" || group.group === "emergency"}>
                  <summary>{group.group}</summary>
                  <div>
                    {group.commands.map((command) => (
                      <code key={`${group.group}:${command}`}>{command}</code>
                    ))}
                  </div>
                </details>
              ))}
            </div>
          </article>
        </aside>
      </section>
    </div>
  );
}
