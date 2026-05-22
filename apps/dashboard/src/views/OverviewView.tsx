import { AlertTriangle, Cpu, DatabaseZap, RadioTower } from "lucide-react";
import { EmptyState } from "../components/EmptyState";
import { HashValue } from "../components/HashValue";
import { ProvenanceLine } from "../components/ProvenanceLine";
import { SectionHeader } from "../components/SectionHeader";
import { StatusBadge } from "../components/StatusBadge";
import { formatDateTime } from "../data/format";
import {
  computeOverviewMetrics,
  getHardwareRiskNodes,
  getLatestBlocks,
  getLatestFlowPulses,
  getVerifierRiskReports,
} from "../data/selectors";
import type { DashboardData } from "../data/types";

export function OverviewView({ data }: { data: DashboardData }) {
  const metrics = computeOverviewMetrics(data);
  const latestPulses = getLatestFlowPulses(data, 5);
  const latestBlocks = getLatestBlocks(data, 4);
  const verifierRisk = getVerifierRiskReports(data);
  const hardwareRisk = getHardwareRiskNodes(data);

  return (
    <div className="view-stack">
      <SectionHeader
        eyebrow="overview"
        title="Local FlowMemory state"
        detail="Fixture-backed operator view across FlowPulse observations, verifier reports, work lanes, localRuntime roots, and hardware heartbeats."
      />

      <section className="metric-grid" aria-label="Dashboard metrics">
        {metrics.map((metric) => (
          <article className="metric-tile" key={metric.label}>
            <span>{metric.label}</span>
            <strong>{metric.value}</strong>
            <div>
              <StatusBadge status={metric.status} compact />
              <small>{metric.detail}</small>
            </div>
          </article>
        ))}
      </section>

      <section className="overview-grid">
        <div className="panel panel-wide">
          <div className="panel-heading">
            <div>
              <DatabaseZap size={18} aria-hidden="true" />
              <h2>Recent FlowPulse observations</h2>
            </div>
            <span>{data.flowPulseObservations.length} total</span>
          </div>
          {latestPulses.length > 0 ? (
            <div className="record-list">
              {latestPulses.map((pulse) => (
                <article className="record-row" key={pulse.observationId}>
                  <div>
                    <div className="record-title">
                      <StatusBadge status={pulse.status} compact />
                      <HashValue value={pulse.observationId} label="observation id" />
                    </div>
                    <p>{pulse.summary}</p>
                    <ProvenanceLine provenance={pulse.provenance} lastUpdated={pulse.lastUpdated} />
                  </div>
                  <dl className="record-facts">
                    <div>
                      <dt>block</dt>
                      <dd>{pulse.blockNumber}</dd>
                    </div>
                    <div>
                      <dt>sequence</dt>
                      <dd>{pulse.sequence}</dd>
                    </div>
                    <div>
                      <dt>tx</dt>
                      <dd>
                        <HashValue value={pulse.txHash} trim="short" />
                      </dd>
                    </div>
                  </dl>
                </article>
              ))}
            </div>
          ) : (
            <EmptyState title="No observations in fixture" detail="Sync generated indexer output into the dashboard fixture boundary." />
          )}
        </div>

        <div className="panel">
          <div className="panel-heading">
            <div>
              <AlertTriangle size={18} aria-hidden="true" />
              <h2>Verifier attention</h2>
            </div>
            <span>{verifierRisk.length} reports</span>
          </div>
          {verifierRisk.length > 0 ? (
            <div className="compact-list">
              {verifierRisk.map((report) => (
                <article key={report.reportId}>
                  <StatusBadge status={report.status} compact />
                  <div>
                    <strong>
                      <HashValue value={report.reportId} trim="short" />
                    </strong>
                    <small>{report.reasonCodes.join(", ") || "no reason code"}</small>
                  </div>
                </article>
              ))}
            </div>
          ) : (
            <EmptyState title="No verifier risk reports" detail="All fixture reports are currently marked verified." />
          )}
        </div>

        <div className="panel">
          <div className="panel-heading">
            <div>
              <RadioTower size={18} aria-hidden="true" />
              <h2>Hardware risk</h2>
            </div>
            <span>{hardwareRisk.length} nodes</span>
          </div>
          {hardwareRisk.length > 0 ? (
            <div className="compact-list">
              {hardwareRisk.map((node) => (
                <article key={node.nodeId}>
                  <StatusBadge status={node.status} compact />
                  <div>
                    <strong>{node.callsign}</strong>
                    <small>{node.lastHeartbeatAt ? formatDateTime(node.lastHeartbeatAt) : "no heartbeat"}</small>
                  </div>
                </article>
              ))}
            </div>
          ) : (
            <EmptyState title="No stale hardware nodes" detail="All fixture nodes have current local heartbeats." />
          )}
        </div>

        <div className="panel panel-wide">
          <div className="panel-heading">
            <div>
              <Cpu size={18} aria-hidden="true" />
              <h2>LocalRuntime block window</h2>
            </div>
            <span>{data.chain.finalizedBlock} finalized</span>
          </div>
          <div className="block-strip">
            {latestBlocks.map((block) => (
              <article key={block.blockHash}>
                <StatusBadge status={block.status} compact />
                <strong>{block.blockNumber}</strong>
                <span>
                  <HashValue value={block.stateRoot} trim="short" />
                </span>
                <small>{block.observationCount} observations</small>
              </article>
            ))}
          </div>
        </div>
      </section>
    </div>
  );
}
