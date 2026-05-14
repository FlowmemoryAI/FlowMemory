import { useMemo, useState } from "react";
import { Activity, Coins, Database, ListChecks, Network, PlayCircle, RefreshCw, Repeat2, Search, Server, ShieldAlert, Terminal, Wallet } from "lucide-react";
import { EmptyState } from "../components/EmptyState";
import { HashValue } from "../components/HashValue";
import { ProvenanceLine } from "../components/ProvenanceLine";
import { SectionHeader } from "../components/SectionHeader";
import { StatusBadge } from "../components/StatusBadge";
import type { DashboardData, DashboardStatus } from "../data/types";
import { WORKBENCH_SECTIONS, type WorkbenchRecord, type WorkbenchSectionKey, type WorkbenchSnapshot } from "../data/workbench";

const DEFAULT_SECTION: WorkbenchSectionKey = "nodeStatus";

interface WorkbenchViewProps {
  data: DashboardData;
  workbench: WorkbenchSnapshot;
  onRefresh?: () => void;
}

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

function statusForCount(count: number): DashboardStatus {
  return count > 0 ? "verified" : "pending";
}

export function WorkbenchView({ data, workbench, onRefresh }: WorkbenchViewProps) {
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
  const bridgeRecordCount =
    workbench.sections.bridgeDeposits.length + workbench.sections.bridgeCredits.length + workbench.sections.bridgeWithdrawals.length;
  const pilotRecords = workbench.sections.realValuePilot;
  const pilotOverview = pilotRecords.find((record) => record.kind === "Pilot status") ?? pilotRecords[0];
  const bridgeReadiness = pilotRecords.find((record) => record.kind === "Bridge live readiness");
  const pilotState = pilotOverview?.facts.find((fact) => fact.label === "state")?.value ?? "degraded";
  const pilotNextCommand = pilotOverview?.facts.find((fact) => fact.label === "next command")?.value ?? "npm run control-plane:serve";
  const bridgeReadinessStatus = bridgeReadiness?.facts.find((fact) => fact.label === "fail-closed status")?.value ?? "BLOCKED";
  const bridgeReadinessMissingEnv = bridgeReadiness?.facts.find((fact) => fact.label === "missing env names")?.value ?? "endpoint unavailable";
  const productSurfaces: Array<{
    key: WorkbenchSectionKey;
    label: string;
    detail: string;
    command: string;
    count: number;
    Icon: typeof Wallet;
  }> = [
    {
      key: "walletMetadata",
      label: "Wallet public state",
      detail: "Public account/key references only. Signing secrets stay outside browser storage.",
      command: "npm run flowchain:init",
      count: workbench.sections.walletMetadata.length + workbench.sections.accounts.length,
      Icon: Wallet,
    },
    {
      key: "balances",
      label: "Local balances",
      detail: "No-value local test units from faucet or bridge-credit flows.",
      command: "npm run flowchain:faucet",
      count: workbench.sections.balances.length + workbench.sections.faucetEvents.length,
      Icon: Coins,
    },
    {
      key: "tokenLaunches",
      label: "Token launch",
      detail: "Local/testnet token definitions and launch receipts.",
      command: "npm run flowchain:product-e2e",
      count: workbench.sections.tokenLaunches.length + workbench.sections.tokenBalances.length,
      Icon: ListChecks,
    },
    {
      key: "dexPools",
      label: "DEX pools",
      detail: "Pool reserves, liquidity positions, and swap receipt visibility.",
      command: "npm run flowchain:product-e2e",
      count: workbench.sections.dexPools.length + workbench.sections.liquidityPositions.length + workbench.sections.swaps.length,
      Icon: Repeat2,
    },
    {
      key: "explorerRecords",
      label: "Explorer records",
      detail: "Blocks, transactions, receipts, token, DEX, and bridge rollups.",
      command: "npm run flowchain:product-e2e",
      count: workbench.sections.explorerRecords.length,
      Icon: Database,
    },
    {
      key: "realValuePilot",
      label: "Real-value pilot",
      detail: "Capped owner testing lifecycle and next operator command.",
      command: "npm run flowchain:real-value-pilot:e2e",
      count: pilotRecords.length,
      Icon: ShieldAlert,
    },
    {
      key: "bridgeDeposits",
      label: "Bridge records",
      detail: "Local/Anvil/Base Sepolia test records only; real-funds bridge remains blocked.",
      command: "npm run bridge:local-credit:smoke",
      count: bridgeRecordCount,
      Icon: ShieldAlert,
    },
  ];

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
        detail="Product Testnet V1 browser surface for local node/API, wallet public state, balances, token launch, DEX, explorer, and bridge-test records. It probes the local control-plane API when available, falls back to deterministic fixtures, and never stores private keys in browser localStorage."
        action={
          <div className="workbench-header-actions">
            <label className="search-box">
              <Search size={16} aria-hidden="true" />
              <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search current workbench view" />
            </label>
            {onRefresh ? (
              <button className="button" type="button" onClick={onRefresh} title="Refresh local workbench data">
                <RefreshCw size={15} aria-hidden="true" />
                Refresh
              </button>
            ) : null}
          </div>
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

      <section className="workbench-boundary-strip" aria-label="Local testnet boundary">
        <article>
          <strong>Capped owner testing</strong>
          <span>The real-value pilot surface is for capped project-owner validation only; it is not broad public readiness.</span>
        </article>
        <article>
          <strong>Browser key boundary</strong>
          <span>The UI reads public wallet/account metadata and calls advertised local endpoints; private keys are not written to localStorage.</span>
        </article>
        <article>
          <strong>Offline recovery</strong>
          <span>
            Run <code>npm run flowchain:start</code>, then <code>npm run control-plane:serve</code>, then refresh.
          </span>
        </article>
      </section>

      <section className="pilot-status-panel" aria-label="Real-value pilot status">
        <article>
          <div className="panel-heading">
            <div>
              <ShieldAlert size={18} aria-hidden="true" />
              <h2>Real-value pilot</h2>
            </div>
            <StatusBadge status={pilotOverview?.status ?? "pending"} compact />
          </div>
          <div className="pilot-status-body">
            <div>
              <span className="eyebrow">capped owner testing</span>
              <h3>{pilotState}</h3>
              <p>{pilotOverview?.summary ?? "Pilot status is waiting on the local control-plane API."}</p>
            </div>
            <dl className="workbench-fact-grid">
              <div>
                <dt>next command</dt>
                <dd>{displayValue(pilotNextCommand)}</dd>
              </div>
              <div>
                <dt>public readiness</dt>
                <dd>false</dd>
              </div>
              <div>
                <dt>browser secrets</dt>
                <dd>not stored</dd>
              </div>
              <div>
                <dt>evidence rows</dt>
                <dd>{pilotRecords.length}</dd>
              </div>
            </dl>
          </div>
        </article>
        <article>
          <div className="panel-heading">
            <div>
              <ShieldAlert size={18} aria-hidden="true" />
              <h2>Bridge live readiness</h2>
            </div>
            <StatusBadge status={bridgeReadiness?.status ?? "pending"} compact />
          </div>
          <div className="pilot-status-body">
            <div>
              <span className="eyebrow">base 8453 fail-closed check</span>
              <h3>{bridgeReadinessStatus}</h3>
              <p>
                {bridgeReadiness?.summary ??
                  "Live readiness is blocked until the local control-plane exposes bridge readiness details."}
              </p>
            </div>
            <dl className="workbench-fact-grid">
              <div>
                <dt>base chain</dt>
                <dd>{displayValue(bridgeReadiness?.facts.find((fact) => fact.label === "base chain")?.value ?? "8453")}</dd>
              </div>
              <div>
                <dt>lockbox configured</dt>
                <dd>{displayValue(bridgeReadiness?.facts.find((fact) => fact.label === "lockbox configured")?.value ?? "false")}</dd>
              </div>
              <div>
                <dt>missing env names</dt>
                <dd>{displayValue(bridgeReadinessMissingEnv)}</dd>
              </div>
              <div>
                <dt>env values printed</dt>
                <dd>{displayValue(bridgeReadiness?.facts.find((fact) => fact.label === "env values printed")?.value ?? "false")}</dd>
              </div>
            </dl>
          </div>
        </article>
      </section>

      <section className="product-surface-grid" aria-label="Product Testnet V1 workbench surfaces">
        {productSurfaces.map(({ key, label, detail, command, count, Icon }) => (
          <button className="product-surface" key={key} type="button" onClick={() => setActiveSection(key)}>
            <span className="product-surface-icon">
              <Icon size={18} aria-hidden="true" />
            </span>
            <span>
              <strong>{label}</strong>
              <small>{detail}</small>
              <code>{command}</code>
            </span>
            <StatusBadge status={statusForCount(count)} compact />
            <b>{count}</b>
          </button>
        ))}
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
          <span>Token/DEX objects</span>
          <strong>
            {workbench.sections.tokenLaunches.length +
              workbench.sections.tokenBalances.length +
              workbench.sections.dexPools.length +
              workbench.sections.liquidityPositions.length +
              workbench.sections.swaps.length}
          </strong>
          <div>
            <StatusBadge
              status={statusForCount(
                workbench.sections.tokenLaunches.length +
                  workbench.sections.tokenBalances.length +
                  workbench.sections.dexPools.length +
                  workbench.sections.liquidityPositions.length +
                  workbench.sections.swaps.length,
              )}
              compact
            />
            <small>product-testnet path</small>
          </div>
        </article>
        <article className="metric-tile">
          <span>Bridge/explorer</span>
          <strong>{bridgeRecordCount + workbench.sections.explorerRecords.length + pilotRecords.length}</strong>
          <div>
            <StatusBadge status={statusForCount(bridgeRecordCount + workbench.sections.explorerRecords.length + pilotRecords.length)} compact />
            <small>pilot and bridge evidence</small>
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
            This screen is an explorer/workbench for private/local Product Testnet V1 validation. It uses existing V0
            dashboard state, launch-core devnet output, bridge test-deposit fixtures, and future control-plane API
            responses; it does not introduce a new fixture system or a separate dashboard surface.
          </p>
          <p>
            The integration point is the local control-plane API at <code>{workbench.controlPlane.url}</code>. Until that
            service is running, the API status is intentionally shown as fixture fallback.
          </p>
          <p>
            Recovery commands: <code>npm run flowchain:prereq</code> <code>npm run flowchain:init</code>{" "}
            <code>npm run flowchain:start</code> <code>npm run control-plane:serve</code>{" "}
            <code>npm run workbench:dev</code> <code>npm run flowchain:product-e2e</code>.
          </p>
        </div>
      </section>
    </div>
  );
}
