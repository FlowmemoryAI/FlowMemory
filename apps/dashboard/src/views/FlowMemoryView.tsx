import { useMemo, useState } from "react";
import { BrainCircuit, Search } from "lucide-react";
import { EmptyState } from "../components/EmptyState";
import { HashValue } from "../components/HashValue";
import { ProvenanceLine } from "../components/ProvenanceLine";
import { SectionHeader } from "../components/SectionHeader";
import { StatusBadge } from "../components/StatusBadge";
import { searchRecords } from "../data/selectors";
import type { DashboardData } from "../data/types";

export function FlowMemoryView({ data }: { data: DashboardData }) {
  const [query, setQuery] = useState("");
  const transitions = useMemo(
    () => searchRecords(data.rootflowTransitions, query),
    [data.rootflowTransitions, query],
  );

  return (
    <div className="view-stack">
      <SectionHeader
        eyebrow="launch core"
        title="Rootflow and Flow Memory"
        detail="Generated V0 state built from indexer observations, verifier reports, local devnet output, and hardware fixture data."
        action={
          <label className="search-box">
            <Search size={16} aria-hidden="true" />
            <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search transitions" />
          </label>
        }
      />

      <section className="metric-grid" aria-label="Flow Memory generated objects">
        <article className="metric-tile">
          <span>Memory signals</span>
          <strong>{data.memorySignals.length}</strong>
          <div>
            <StatusBadge status="observed" compact />
            <small>from FlowPulse observations</small>
          </div>
        </article>
        <article className="metric-tile">
          <span>Memory receipts</span>
          <strong>{data.memoryReceipts.length}</strong>
          <div>
            <StatusBadge status="verified" compact />
            <small>verifier statuses adapted</small>
          </div>
        </article>
        <article className="metric-tile">
          <span>Rootflow transitions</span>
          <strong>{data.rootflowTransitions.length}</strong>
          <div>
            <StatusBadge status="pending" compact />
            <small>parent/child state path</small>
          </div>
        </article>
        <article className="metric-tile">
          <span>Agent views</span>
          <strong>{data.agentMemoryViews.length}</strong>
          <div>
            <StatusBadge status="stale" compact />
            <small>warnings preserved</small>
          </div>
        </article>
      </section>

      <section className="overview-grid">
        <div className="panel panel-wide">
          <div className="panel-heading">
            <div>
              <BrainCircuit size={18} aria-hidden="true" />
              <h2>Rootflow transitions</h2>
            </div>
            <span>{transitions.length} shown</span>
          </div>
          {transitions.length > 0 ? (
            <div className="record-list">
              {transitions.map((transition) => (
                <article className="record-row" key={transition.transitionId}>
                  <div>
                    <div className="record-title">
                      <StatusBadge status={transition.status} compact />
                      <HashValue value={transition.transitionId} label="transition id" />
                    </div>
                    <p>
                      sequence {transition.sequence} moves root from{" "}
                      <HashValue value={transition.previousRoot} trim="short" /> to{" "}
                      <HashValue value={transition.nextRoot} trim="short" />
                    </p>
                    <ProvenanceLine provenance={transition.provenance} lastUpdated={transition.lastUpdated} />
                  </div>
                  <dl className="record-facts">
                    <div>
                      <dt>pulse</dt>
                      <dd>
                        <HashValue value={transition.pulseId} trim="short" />
                      </dd>
                    </div>
                    <div>
                      <dt>receipt</dt>
                      <dd>{transition.memoryReceiptId ? <HashValue value={transition.memoryReceiptId} trim="short" /> : "none"}</dd>
                    </div>
                    <div>
                      <dt>reasons</dt>
                      <dd>{transition.reasonCodes.join(", ") || "none"}</dd>
                    </div>
                  </dl>
                </article>
              ))}
            </div>
          ) : (
            <EmptyState title="No Rootflow transitions" detail="Run the launch V0 generator to create transition output." />
          )}
        </div>

        <div className="panel">
          <div className="panel-heading">
            <div>
              <BrainCircuit size={18} aria-hidden="true" />
              <h2>Agent memory view</h2>
            </div>
            <span>{data.agentMemoryViews.length} views</span>
          </div>
          <div className="compact-list">
            {data.agentMemoryViews.map((view) => (
              <article key={view.viewId}>
                <StatusBadge status={view.status} compact />
                <div>
                  <strong>
                    <HashValue value={view.viewId} trim="short" />
                  </strong>
                  <small>{view.warnings.join(", ") || "no warnings"}</small>
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>
    </div>
  );
}
