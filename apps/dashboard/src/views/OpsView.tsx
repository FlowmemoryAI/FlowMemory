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

interface OpsDryRunEvent {
  findingCode: string;
  severity: string;
  ruleId: string;
  signal: string;
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

function isReadyFlag(value: unknown): boolean {
  return value === true || text(value, "").toLowerCase() === "true";
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

function parseDryRunEvents(ops: UnknownRecord | null): OpsDryRunEvent[] {
  return asArray(ops?.dryRunEvents).filter(isRecord).map((event) => ({
    findingCode: text(event.findingCode, "ops-finding"),
    severity: text(event.severity, "observed"),
    ruleId: text(event.ruleId, "ops-rule"),
    signal: text(event.signal, "Ops dry-run signal"),
    commands: stringList(event.commands),
  }));
}

export function OpsView({ workbench }: { workbench: WorkbenchSnapshot }) {
  const liveReadiness = isRecord(workbench.raw.liveReadinessReport) ? workbench.raw.liveReadinessReport : null;
  const metrics = isRecord(liveReadiness?.metrics) ? liveReadiness.metrics : {};
  const ops = isRecord(liveReadiness?.ops) ? liveReadiness.ops : null;
  const findings = parseFindings(ops);
  const activeRules = parseRules(ops);
  const coveredFindingCodes = stringList(ops?.coveredFindingCodes);
  const incidentCommands = parseIncidentCommands(ops);
  const dryRunEvents = parseDryRunEvents(ops);
  const alertState = text(ops?.alertState ?? metrics.opsAlertState, "not recorded");
  const snapshotStatus = text(ops?.snapshotStatus ?? metrics.opsSnapshotStatus, "not recorded");
  const incidentDrillStatus = text(ops?.incidentDrillStatus ?? metrics.incidentDrillStatus, "not recorded");
  const escalationDryRunStatus = text(ops?.escalationDryRunStatus ?? metrics.opsEscalationDryRunStatus, "not recorded");
  const escalationDryRunEvents = text(ops?.escalationDryRunEvents ?? metrics.opsEscalationDryRunEvents, "0");
  const latestHeight = text(ops?.latestHeight ?? metrics.latestHeight);
  const criticalCount = text(ops?.criticalCount ?? metrics.opsCriticalCount, "0");
  const blockedCount = text(ops?.blockedCount ?? metrics.opsBlockedCount, "0");
  const serviceSupervisorValidationStatus = text(ops?.serviceSupervisorValidationStatus ?? metrics.serviceSupervisorValidationStatus, "not recorded");
  const serviceSupervisorRestartAttempts = text(ops?.serviceSupervisorRestartAttempts ?? metrics.serviceSupervisorRestartAttempts, "0");
  const serviceSupervisorNodeRestartAttempts = text(ops?.serviceSupervisorNodeRestartAttempts ?? metrics.serviceSupervisorNodeRestartAttempts, "0");
  const serviceSupervisorRelayerRestartAttempts = text(ops?.serviceSupervisorRelayerRestartAttempts ?? metrics.serviceSupervisorRelayerRestartAttempts, "0");
  const serviceInstallValidationStatus = text(ops?.serviceInstallValidationStatus ?? metrics.serviceInstallValidationStatus, "not recorded");
  const serviceInstallPlanDidNotMutate = isReadyFlag(ops?.serviceInstallPlanDidNotMutate ?? metrics.serviceInstallPlanDidNotMutate);
  const serviceInstallStatusDidNotMutate = isReadyFlag(ops?.serviceInstallStatusDidNotMutate ?? metrics.serviceInstallStatusDidNotMutate);
  const serviceInstallRelayerOptInStartsLoop = isReadyFlag(ops?.serviceInstallRelayerOptInStartsLoop ?? metrics.serviceInstallRelayerOptInStartsLoop);
  const systemdServiceInstallValidationStatus = text(ops?.systemdServiceInstallValidationStatus ?? metrics.systemdServiceInstallValidationStatus, "not recorded");
  const systemdInstallPlanUsesRenderedUnits = isReadyFlag(ops?.systemdInstallPlanUsesRenderedUnits ?? metrics.systemdInstallPlanUsesRenderedUnits);
  const systemdBridgeRelayerDefaultOff = isReadyFlag(ops?.systemdBridgeRelayerDefaultOff ?? metrics.systemdBridgeRelayerDefaultOff);
  const systemdBridgeRelayerOptInStartsLoop = isReadyFlag(ops?.systemdBridgeRelayerOptInStartsLoop ?? metrics.systemdBridgeRelayerOptInStartsLoop);
  const bridgeRelayerCheckContractReadyValue = ops?.bridgeRelayerCheckContractReady ?? metrics.bridgeRelayerCheckContractReady;
  const bridgeRelayerCheckContractReady = isReadyFlag(bridgeRelayerCheckContractReadyValue)
    ? "ready"
    : text(bridgeRelayerCheckContractReadyValue, "not recorded");
  const bridgeRelayerFailedChecks = text(ops?.bridgeRelayerFailedChecks ?? metrics.bridgeRelayerFailedChecks, "0");
  const bridgeRelayerMissingChecks = text(ops?.bridgeRelayerMissingChecks ?? metrics.bridgeRelayerMissingChecks, "0");
  const bridgeRelayerCheckRuleCovered = coveredFindingCodes.includes("bridge-relayer-check-contract-failed");
  const bridgeGuardrailStatus = text(ops?.bridgeRelayerGuardrailStatus ?? metrics.bridgeRelayerGuardrailStatus, "not recorded");
  const bridgeGuardrailReady = text(ops?.bridgeRelayerGuardrailReady, bridgeGuardrailStatus === "passed" ? "true" : "false");
  const bridgeRelayerLoopValidationStatus = text(metrics.bridgeRelayerLoopValidationStatus, "not recorded");
  const publicRpcDeployBundleStatus = text(ops?.publicRpcDeploymentBundleStatus ?? metrics.publicRpcDeploymentBundleStatus, "not recorded");
  const publicRpcDeployAutomationStatus = text(ops?.publicRpcDeploymentAutomationStatus ?? metrics.publicRpcDeploymentAutomationStatus, "not recorded");
  const publicRpcDeployAutomationAction = text(ops?.publicRpcDeploymentAutomationAction ?? metrics.publicRpcDeploymentAutomationAction, "not recorded");
  const publicRpcLiveSecurityHeaderProbe = isReadyFlag(ops?.publicRpcLiveSecurityHeaderProbe ?? metrics.publicRpcLiveSecurityHeaderProbe);
  const publicRpcLiveSecurityHeaders = isReadyFlag(ops?.publicRpcLiveSecurityHeaders ?? metrics.publicRpcLiveSecurityHeaders);
  const publicRpcSecurityHeaderPolicyReady = isReadyFlag(ops?.publicRpcSecurityHeaderPolicyReady ?? metrics.publicRpcSecurityHeaderPolicyReady);
  const publicRpcSecurityHeaders = isReadyFlag(ops?.publicRpcSecurityHeaders ?? metrics.publicRpcSecurityHeaders);
  const publicRpcRenderedSecurityHeaders = isReadyFlag(ops?.publicRpcRenderedSecurityHeaders ?? metrics.publicRpcRenderedSecurityHeaders);
  const publicRpcLiveHeaderProofReady =
    publicRpcLiveSecurityHeaderProbe &&
    publicRpcLiveSecurityHeaders &&
    publicRpcSecurityHeaderPolicyReady &&
    publicRpcSecurityHeaders &&
    publicRpcRenderedSecurityHeaders;
  const publicTesterGatewayStatus = text(ops?.publicTesterGatewayStatus ?? metrics.publicTesterGatewayStatus, "not recorded");
  const publicTesterGatewayAccountCount = text(ops?.publicTesterGatewayAccountCount ?? metrics.publicTesterGatewayAccountCount, "0");
  const publicTesterGatewayFailedChecks = text(ops?.publicTesterGatewayFailedChecks ?? metrics.publicTesterGatewayFailedChecks, "0");
  const publicTesterGatewayTransferApplied = isReadyFlag(ops?.publicTesterGatewayTransferApplied ?? metrics.publicTesterGatewayTransferApplied);
  const publicTesterGatewayCapRejected = isReadyFlag(ops?.publicTesterGatewayCapRejected ?? metrics.publicTesterGatewayCapRejected);
  const publicTesterGatewayNoSecrets = isReadyFlag(ops?.publicTesterGatewayNoSecrets ?? metrics.publicTesterGatewayNoSecrets);
  const publicTesterGatewayNoBroadcasts = isReadyFlag(ops?.publicTesterGatewayNoBroadcasts ?? metrics.publicTesterGatewayNoBroadcasts);
  const alertInstallValidationStatus = text(ops?.alertInstallValidationStatus ?? metrics.alertInstallValidationStatus, "not recorded");
  const opsMetricCount = text(ops?.opsMetricCount ?? metrics.opsMetricCount, "0");
  const opsRequiredMetricsPresent = isReadyFlag(ops?.opsRequiredMetricsPresent ?? metrics.opsRequiredMetricsPresent);
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
          <span>Escalation dry run</span>
          <strong>{escalationDryRunStatus}</strong>
          <small>{escalationDryRunEvents} mapped events</small>
        </div>
        <div>
          <span>Relayer checks</span>
          <strong>{bridgeRelayerCheckContractReady}</strong>
          <small>failed {bridgeRelayerFailedChecks} / missing {bridgeRelayerMissingChecks}</small>
        </div>
        <div>
          <span>Bridge guardrail</span>
          <strong>{bridgeGuardrailStatus}</strong>
          <small>fail-closed proof ready {bridgeGuardrailReady}</small>
        </div>
        <div>
          <span>Relayer loop</span>
          <strong>{bridgeRelayerLoopValidationStatus}</strong>
          <small>start, status, stop proof</small>
        </div>
        <div>
          <span>RPC deploy automation</span>
          <strong>{publicRpcDeployAutomationStatus}</strong>
          <small>mode {publicRpcDeployAutomationAction}</small>
        </div>
        <div>
          <span>Tester gateway E2E</span>
          <strong>{publicTesterGatewayStatus}</strong>
          <small>accounts {publicTesterGatewayAccountCount}; failed {publicTesterGatewayFailedChecks}</small>
        </div>
        <div>
          <span>Delivery boundary</span>
          <strong>{networkNotifications}</strong>
          <small>network sends; stores secrets {storesSecrets}</small>
        </div>
      </section>

      <section className="ops-layout">
        <div className="ops-main">
          <section className="ops-relayer-contract" aria-label="Bridge relayer check contract">
            <div>
              <span>Relayer check contract</span>
              <strong>{bridgeRelayerCheckContractReady}</strong>
              <small>one-shot safety report</small>
            </div>
            <div>
              <span>Failed checks</span>
              <strong>{bridgeRelayerFailedChecks}</strong>
              <small>must stay zero before launch</small>
            </div>
            <div>
              <span>Missing checks</span>
              <strong>{bridgeRelayerMissingChecks}</strong>
              <small>required report fields</small>
            </div>
            <div>
              <span>Critical rule</span>
              <strong>{bridgeRelayerCheckRuleCovered ? "covered" : "missing"}</strong>
              <small>bridge-relayer-check-contract-failed</small>
            </div>
          </section>

          <section className="ops-automation-proof" aria-label="Service and deployment automation proof">
            <div>
              <span>Autorecovery drill</span>
              <strong>{serviceSupervisorValidationStatus}</strong>
              <small>control-plane {serviceSupervisorRestartAttempts} / node {serviceSupervisorNodeRestartAttempts} / relayer {serviceSupervisorRelayerRestartAttempts}</small>
            </div>
            <div>
              <span>Windows service plan</span>
              <strong>{serviceInstallValidationStatus}</strong>
              <small>plan safe {String(serviceInstallPlanDidNotMutate)} / status safe {String(serviceInstallStatusDidNotMutate)}</small>
            </div>
            <div>
              <span>Systemd service plan</span>
              <strong>{systemdServiceInstallValidationStatus}</strong>
              <small>rendered units {String(systemdInstallPlanUsesRenderedUnits)} / relayer off {String(systemdBridgeRelayerDefaultOff)}</small>
            </div>
            <div>
              <span>Relayer opt-in</span>
              <strong>{String(serviceInstallRelayerOptInStartsLoop && systemdBridgeRelayerOptInStartsLoop)}</strong>
              <small>Windows and systemd install plans start the relayer loop only with owner opt-in</small>
            </div>
            <div>
              <span>Public RPC automation</span>
              <strong>{publicRpcDeployAutomationStatus}</strong>
              <small>bundle {publicRpcDeployBundleStatus} / action {publicRpcDeployAutomationAction}</small>
            </div>
            <div>
              <span>Ops install proof</span>
              <strong>{alertInstallValidationStatus}</strong>
              <small>metrics {opsMetricCount}; required metrics {String(opsRequiredMetricsPresent)}</small>
            </div>
            <div>
              <span>RPC headers</span>
              <strong>{String(publicRpcLiveHeaderProofReady)}</strong>
              <small>live {String(publicRpcLiveSecurityHeaders)} / probe {String(publicRpcLiveSecurityHeaderProbe)} / policy {String(publicRpcSecurityHeaderPolicyReady)} / rendered {String(publicRpcRenderedSecurityHeaders)}</small>
            </div>
            <div>
              <span>Tester gateway proof</span>
              <strong>{String(publicTesterGatewayTransferApplied && publicTesterGatewayCapRejected)}</strong>
              <small>no secrets {String(publicTesterGatewayNoSecrets)} / no broadcasts {String(publicTesterGatewayNoBroadcasts)}</small>
            </div>
          </section>

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
                  relayer checks {bridgeRelayerCheckContractReady}
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

          <article>
            <div className="ops-side-heading">
              <BellRing size={17} aria-hidden="true" />
              <strong>Escalation dry run</strong>
            </div>
            {dryRunEvents.length > 0 ? (
              <div className="ops-rule-list">
                {dryRunEvents.map((event) => (
                  <div key={`${event.findingCode}:${event.ruleId}`}>
                    <span>{event.severity}</span>
                    <strong>{event.findingCode}</strong>
                    <small>{event.signal}</small>
                    <code>{event.commands[0] ?? "not recorded"}</code>
                  </div>
                ))}
              </div>
            ) : (
              <small>No dry-run escalation events are loaded.</small>
            )}
          </article>
        </aside>
      </section>
    </div>
  );
}
