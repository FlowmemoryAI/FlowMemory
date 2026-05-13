import { useMemo, useState } from "react";
import { Activity, Database, Network, PlayCircle, Search, Server, Terminal } from "lucide-react";
import { EmptyState } from "../components/EmptyState";
import { HashValue } from "../components/HashValue";
import { ProvenanceLine } from "../components/ProvenanceLine";
import { SectionHeader } from "../components/SectionHeader";
import { StatusBadge } from "../components/StatusBadge";
import type { DashboardData, DashboardStatus } from "../data/types";
import { WORKBENCH_SECTIONS, type WorkbenchRecord, type WorkbenchSectionKey, type WorkbenchSnapshot } from "../data/workbench";

const DEFAULT_SECTION: WorkbenchSectionKey = "nodeStatus";

function displayValue(value: string) {
  if (value.startsWith("0x") && value.length > 18) {
    return <HashValue value={value} trim="medium" />;
  }

  return value;
}

function setupStatus(state: "available" | "expected"): DashboardStatus {
  return state === "available" ? "verified" : "pending";
}

function recordMatches(record: WorkbenchRecord, query: string): boolean {
  const normalized = query.trim().toLowerCase();
  if (normalized.length === 0) {
    return true;
  }

  return JSON.stringify(record).toLowerCase().includes(normalized);
}

function missingStateDetail(activeDefinition: (typeof WORKBENCH_SECTIONS)[number]): string {
  return `${activeDefinition.missingService} did not provide records for ${activeDefinition.expectedEndpoint}. Run ${activeDefinition.missingCommand} locally, then refresh this dashboard.`;
}

export function WorkbenchView({ data, workbench }: { data: DashboardData; workbench: WorkbenchSnapshot }) {
  const [activeSection, setActiveSection] = useState<WorkbenchSectionKey>(DEFAULT_SECTION);
  const [query, setQuery] = useState("");
  const [actionResult, setActionResult] = useState<string | null>(null);
  const activeDefinition = WORKBENCH_SECTIONS.find((section) => section.key === activeSection) ?? WORKBENCH_SECTIONS[0];
  const activeRecords = workbench.sections[activeSection] ?? [];
  const filteredRecords = useMemo(
    () => activeRecords.filter((record) => recordMatches(record, query)),
    [activeRecords, query],
  );
  const sourceStatus: DashboardStatus = workbench.source === "control-plane" ? "verified" : "stale";

  const runLocalAction = async (endpoint: string, label: string) => {
    const [method, path] = endpoint.split(/\s+/, 2);
    setActionResult(`${label}: sending ${endpoint}`);

    try {
      const response = await fetch(`${workbench.controlPlane.url}${path}`, {
        method,
        headers: { Accept: "application/json" },
      });
      setActionResult(`${label}: ${response.status} ${response.statusText || "response"}`.trim());
    } catch (error) {
      setActionResult(`${label}: ${error instanceof Error ? error.message : "request failed"}`);
    }
  };

  return (
    <div className="view-stack">
      <SectionHeader
        eyebrow="flowchain private/local testnet"
        title="Local explorer workbench"
        detail="Usable browser surface for inspecting the private/local L1 testnet shape. It probes the local control-plane API when available and otherwise renders deterministic committed fixtures; value-bearing wallet flows are not included."
        action={
          <label className="search-box">
            <Search size={16} aria-hidden="true" />
            <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search current workbench view" />
          </label>
        }
      />

      <section className="workbench-command-center">
        <article className="panel workbench-node-panel">
          <div className="panel-heading">
            <div>
              <Server size={18} aria-hidden="true" />
              <h2>Node and API status</h2>
            </div>
            <StatusBadge status={workbench.node.status} compact />
          </div>
          <div className="workbench-node-body">
            <div>
              <span className="eyebrow">{workbench.source}</span>
              <h3>{workbench.node.title}</h3>
              <p>{workbench.node.summary}</p>
            </div>
            <dl className="workbench-fact-grid">
              {workbench.node.facts.map((fact) => (
                <div key={fact.label}>
                  <dt>{fact.label}</dt>
                  <dd>{displayValue(fact.value)}</dd>
                </div>
              ))}
            </dl>
          </div>
        </article>

        <article className="panel workbench-setup-panel">
          <div className="panel-heading">
            <div>
              <Terminal size={18} aria-hidden="true" />
              <h2>Local setup path</h2>
            </div>
            <span>{workbench.controlPlane.url}</span>
          </div>
          <div className="setup-step-list">
            {workbench.setupSteps.map((step) => (
              <article key={step.command}>
                <StatusBadge status={setupStatus(step.state)} compact />
                <div>
                  <strong>{step.label}</strong>
                  <code>{step.command}</code>
                  <small>{step.detail}</small>
                </div>
              </article>
            ))}
          </div>
        </article>
      </section>

      <section className="panel workbench-api-panel">
        <div className="panel-heading">
          <div>
            <Network size={18} aria-hidden="true" />
            <h2>Control-plane endpoints and local actions</h2>
          </div>
          <span>{workbench.controlPlane.endpoints.length} advertised/probed</span>
        </div>
        <div className="endpoint-strip" aria-label="Control-plane endpoint status">
          {workbench.controlPlane.endpoints.map((endpoint) => (
            <span key={endpoint}>{endpoint}</span>
          ))}
        </div>
        {workbench.actions.length > 0 ? (
          <div className="local-action-grid">
            {workbench.actions.map((action) => (
              <article key={action.endpoint}>
                <div>
                  <strong>{action.label}</strong>
                  <code>{action.endpoint}</code>
                  <small>{action.boundary}</small>
                </div>
                <button className="button" type="button" onClick={() => runLocalAction(action.endpoint, action.label)}>
                  <PlayCircle size={15} aria-hidden="true" />
                  Run
                </button>
              </article>
            ))}
          </div>
        ) : (
          <EmptyState
            title="No browser-safe local actions are advertised"
            detail={`The dashboard only renders action buttons after ${workbench.controlPlane.url}/health or /state advertises a matching POST endpoint. Start ${activeDefinition.missingCommand} if you expect local actions.`}
          />
        )}
        {actionResult ? <p className="action-result">{actionResult}</p> : null}
      </section>

      {workbench.loadIssues.length > 0 ? (
        <section className="workbench-warning" role="status">
          <Activity size={18} aria-hidden="true" />
          <div>
            <strong>Fixture fallback loaded with warnings.</strong>
            <span>{workbench.loadIssues.join(" / ")}</span>
          </div>
        </section>
      ) : null}

      <section className="metric-grid" aria-label="Workbench coverage">
        <article className="metric-tile">
          <span>Data source</span>
          <strong>{workbench.source === "control-plane" ? "API" : "Fixture"}</strong>
          <div>
            <StatusBadge status={sourceStatus} compact />
            <small>{workbench.controlPlane.status}</small>
          </div>
        </article>
        <article className="metric-tile">
          <span>Node views</span>
          <strong>{workbench.sections.nodeStatus.length}</strong>
          <div>
            <StatusBadge status={workbench.node.status} compact />
            <small>health and state</small>
          </div>
        </article>
        <article className="metric-tile">
          <span>Chain objects</span>
          <strong>
            {workbench.sections.blocks.length +
              workbench.sections.transactions.length +
              workbench.sections.mempool.length +
              workbench.sections.accounts.length}
          </strong>
          <div>
            <StatusBadge status={workbench.sections.transactions.length > 0 ? "verified" : "pending"} compact />
            <small>blocks txs accounts</small>
          </div>
        </article>
        <article className="metric-tile">
          <span>Smoke objects</span>
          <strong>
            {workbench.sections.receipts.length +
              workbench.sections.artifacts.length +
              workbench.sections.verifierReports.length +
              workbench.sections.memoryCells.length}
          </strong>
          <div>
            <StatusBadge status="observed" compact />
            <small>fixtures plus projections</small>
          </div>
        </article>
        <article className="metric-tile">
          <span>Open challenges</span>
          <strong>{workbench.sections.challenges.length}</strong>
          <div>
            <StatusBadge status={workbench.sections.challenges.length > 0 ? "pending" : "observed"} compact />
            <small>API-ready view</small>
          </div>
        </article>
      </section>

      <section className="workbench-layout">
        <div className="workbench-switcher" aria-label="Workbench object views">
          {WORKBENCH_SECTIONS.map((section) => (
            <button
              className={section.key === activeSection ? "workbench-switch active" : "workbench-switch"}
              key={section.key}
              type="button"
              onClick={() => setActiveSection(section.key)}
            >
              <span>{section.label}</span>
              <strong>{workbench.sections[section.key].length}</strong>
            </button>
          ))}
        </div>

        <article className="panel workbench-record-panel">
          <div className="panel-heading">
            <div>
              {activeSection === "provenance" ? <Database size={18} aria-hidden="true" /> : <Network size={18} aria-hidden="true" />}
              <h2>{activeDefinition.label}</h2>
            </div>
            <span>{activeDefinition.expectedEndpoint}</span>
          </div>
          <p className="workbench-section-detail">{activeDefinition.detail}</p>

          {filteredRecords.length > 0 ? (
            <div className="workbench-record-grid">
              {filteredRecords.map((record) => (
                <article className="workbench-record" key={`${activeSection}:${record.id}:${record.kind}`}>
                  <div className="tile-heading">
                    <StatusBadge status={record.status} compact />
                    <span>{record.kind}</span>
                  </div>
                  <h3>{displayValue(record.title)}</h3>
                  <p>{record.summary}</p>
                  <dl className="definition-grid">
                    {record.facts.slice(0, 6).map((fact) => (
                      <div key={`${record.id}:${fact.label}`}>
                        <dt>{fact.label}</dt>
                        <dd>{displayValue(fact.value)}</dd>
                      </div>
                    ))}
                  </dl>
                  <ProvenanceLine provenance={record.provenance} />
                </article>
              ))}
            </div>
          ) : (
            <EmptyState
              title={`No ${activeDefinition.label.toLowerCase()} in the current source`}
              detail={missingStateDetail(activeDefinition)}
            />
          )}
        </article>
      </section>

      <section className="panel workbench-boundary-panel">
        <div className="panel-heading">
          <div>
            <Activity size={18} aria-hidden="true" />
            <h2>Boundary notes</h2>
          </div>
          <span>{data.chain.environment}</span>
        </div>
        <div className="boundary-copy">
          <p>
            This screen is an explorer/workbench for private/local validation. It uses existing V0 dashboard state,
            launch-core devnet output, and future control-plane API responses; it does not introduce a new fixture
            system or a separate dashboard surface.
          </p>
          <p>
            The integration point is the local control-plane API at <code>{workbench.controlPlane.url}</code>. Until that
            service is running, the API status is intentionally shown as fixture fallback.
          </p>
        </div>
      </section>
    </div>
  );
}
