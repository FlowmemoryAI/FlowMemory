import { useMemo, useState } from "react";
import { Activity, BrainCircuit, GitBranch, Search, ShieldCheck } from "lucide-react";
import { EmptyState } from "../components/EmptyState";
import { HashValue } from "../components/HashValue";
import { ProvenanceLine } from "../components/ProvenanceLine";
import { SectionHeader } from "../components/SectionHeader";
import { StatusBadge } from "../components/StatusBadge";
import { searchRecords } from "../data/selectors";
import type { DashboardData, DashboardStatus } from "../data/types";

export function FlowMemoryView({ data }: { data: DashboardData }) {
  const [query, setQuery] = useState("");
  const transitions = useMemo(
    () => searchRecords(data.rootflowTransitions, query),
    [data.rootflowTransitions, query],
  );
  const latestView = data.agentMemoryViews[0];
  const latestBundle = data.rootfieldBundles[0];
  const contractEventCount = data.memorySignals.filter((signal) => signal.contractEvent.topicMatchesContract).length;
  const swapMemorySignalCount = data.memorySignals.filter((signal) => signal.signalType === "swap_memory_signal").length;
  const statusCounts = useMemo(
    () => data.rootflowTransitions.reduce<Record<string, number>>((counts, transition) => {
      counts[transition.status] = (counts[transition.status] ?? 0) + 1;
      return counts;
    }, {}),
    [data.rootflowTransitions],
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

      <section className="flowmemory-hero" aria-label="Flow Memory launch demo summary">
        <div className="flowmemory-hero-main">
          <span className="eyebrow">local acceptance path</span>
          <h2>IFlowPulse events become verified memory state</h2>
          <p>
            The fixture path now preserves the contract event spine: indexed FlowPulse fields,
            receipt-derived coordinates, verifier result, and Rootflow state movement.
          </p>
          <div className="flowmemory-spine" aria-label="Generated launch-core pipeline">
            <span>FlowPulse</span>
            <span>MemorySignal</span>
            <span>MemoryReceipt</span>
            <span>RootflowTransition</span>
            <span>AgentMemoryView</span>
          </div>
        </div>
        <div className="flowmemory-hero-side">
          <div>
            <small>Latest root</small>
            <HashValue value={latestBundle?.latestRoot ?? "0x0000000000000000000000000000000000000000000000000000000000000000"} trim="short" />
          </div>
          <div>
            <small>Rootfield</small>
            <HashValue value={latestBundle?.rootfieldId ?? "0x0000000000000000000000000000000000000000000000000000000000000000"} trim="short" />
          </div>
          <div>
            <small>Agent view</small>
            <StatusBadge status={latestView?.status ?? "observed"} compact />
          </div>
        </div>
      </section>

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
        <article className="metric-tile">
          <span>Contract events</span>
          <strong>{contractEventCount}</strong>
          <div>
            <StatusBadge status="verified" compact />
            <small>topic0 matched</small>
          </div>
        </article>
        <article className="metric-tile">
          <span>Swap memory signals</span>
          <strong>{swapMemorySignalCount}</strong>
          <div>
            <StatusBadge status={swapMemorySignalCount > 0 ? "verified" : "pending"} compact />
            <small>Uniswap adapter path</small>
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
          <div className="status-strip" aria-label="Rootflow status counts">
            {Object.entries(statusCounts).map(([status, count]) => (
              <span key={status}>
                <StatusBadge status={status as DashboardStatus} compact />
                <strong>{count}</strong>
              </span>
            ))}
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
                      <dt>event</dt>
                      <dd>{transition.contractEventRef.pulseTypeName}</dd>
                    </div>
                    <div>
                      <dt>source</dt>
                      <dd>
                        <HashValue value={transition.contractEventRef.sourceContract} trim="short" />
                      </dd>
                    </div>
                    <div>
                      <dt>tx/log</dt>
                      <dd>
                        <HashValue value={transition.contractEventRef.txHash} trim="short" /> / {transition.contractEventRef.logIndex}
                      </dd>
                    </div>
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
              <Activity size={18} aria-hidden="true" />
              <h2>Contract event spine</h2>
            </div>
            <span>{data.memorySignals.length} signals</span>
          </div>
          <div className="contract-event-list">
            {data.memorySignals.map((signal, index) => (
              <article key={`${signal.signalId}-${signal.contractEvent.receiptLocator.txHash}-${signal.contractEvent.receiptLocator.logIndex}-${index}`}>
                <div>
                  <StatusBadge status={signal.status} compact />
                  <strong>{signal.contractEvent.pulseTypeName}</strong>
                </div>
                <dl>
                  <div>
                    <dt>indexed</dt>
                    <dd>
                      <HashValue value={signal.contractEvent.indexed.pulseId} trim="short" />
                    </dd>
                  </div>
                  <div>
                    <dt>payload</dt>
                    <dd>
                      <HashValue value={signal.contractEvent.payload.commitment} trim="short" />
                    </dd>
                  </div>
                  <div>
                    <dt>locator</dt>
                    <dd>
                      <HashValue value={signal.contractEvent.receiptLocator.txHash} trim="short" /> / {signal.contractEvent.receiptLocator.logIndex}
                    </dd>
                  </div>
                </dl>
              </article>
            ))}
          </div>
        </div>

        <div className="panel panel-side-bottom">
          <div className="panel-heading">
            <div>
              <ShieldCheck size={18} aria-hidden="true" />
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

      <section className="panel panel-wide">
        <div className="panel-heading">
          <div>
            <GitBranch size={18} aria-hidden="true" />
            <h2>Rootfield bundle</h2>
          </div>
          <span>{data.rootfieldBundles.length} bundle</span>
        </div>
        <div className="bundle-grid">
          {data.rootfieldBundles.map((bundle) => (
            <article key={bundle.bundleId}>
              <StatusBadge status={bundle.status} compact />
              <div>
                <strong>
                  <HashValue value={bundle.bundleId} trim="short" />
                </strong>
                <small>
                  {bundle.counts.verified} verified, {bundle.counts.failed} failed, {bundle.counts.unresolved} unresolved
                </small>
              </div>
              <HashValue value={bundle.latestRoot} trim="medium" />
            </article>
          ))}
        </div>
      </section>
    </div>
  );
}
