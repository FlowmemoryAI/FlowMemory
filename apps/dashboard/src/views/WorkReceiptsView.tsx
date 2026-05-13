import { useMemo, useState } from "react";
import { Search } from "lucide-react";
import { EmptyState } from "../components/EmptyState";
import { HashValue } from "../components/HashValue";
import { ProvenanceLine } from "../components/ProvenanceLine";
import { SectionHeader } from "../components/SectionHeader";
import { StatusBadge } from "../components/StatusBadge";
import { formatDateTime, formatMs } from "../data/format";
import { searchRecords } from "../data/selectors";
import type { DashboardData } from "../data/types";

export function WorkReceiptsView({ data }: { data: DashboardData }) {
  const [query, setQuery] = useState("");
  const receipts = useMemo(() => searchRecords(data.workReceipts, query), [data.workReceipts, query]);

  return (
    <div className="view-stack">
      <SectionHeader
        eyebrow="worker"
        title="Work lanes and receipts"
        detail="Local queue and receipt fixtures for verifier/indexer work units without production scheduling claims."
        action={
          <label className="search-box">
            <Search size={16} aria-hidden="true" />
            <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search receipts" />
          </label>
        }
      />

      <section className="lane-grid" aria-label="Work lanes">
        {data.workLanes.map((lane) => (
          <article className="lane-tile" key={lane.laneId}>
            <div className="tile-heading">
              <StatusBadge status={lane.status} />
              <strong>{lane.name}</strong>
            </div>
            <dl className="lane-stats">
              <div>
                <dt>queued</dt>
                <dd>{lane.queueDepth}</dd>
              </div>
              <div>
                <dt>in flight</dt>
                <dd>{lane.inflight}</dd>
              </div>
              <div>
                <dt>24h done</dt>
                <dd>{lane.completed24h}</dd>
              </div>
              <div>
                <dt>p95</dt>
                <dd>{formatMs(lane.p95LatencyMs)}</dd>
              </div>
            </dl>
            <ProvenanceLine provenance={lane.provenance} lastUpdated={lane.lastUpdated} />
          </article>
        ))}
      </section>

      <section className="table-panel">
        {receipts.length > 0 ? (
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Status</th>
                  <th>Receipt</th>
                  <th>Lane / rootfield</th>
                  <th>Work result</th>
                  <th>Timing</th>
                  <th>Provenance</th>
                </tr>
              </thead>
              <tbody>
                {receipts.map((receipt) => (
                  <tr key={receipt.receiptId}>
                    <td>
                      <StatusBadge status={receipt.status} />
                    </td>
                    <td>
                      <div className="cell-stack">
                        <HashValue value={receipt.receiptId} label="receipt id" />
                        <small>{receipt.workType}</small>
                      </div>
                    </td>
                    <td>
                      <div className="cell-stack">
                        <span>{receipt.laneId}</span>
                        <HashValue value={receipt.rootfieldId} trim="short" />
                      </div>
                    </td>
                    <td>
                      <div className="cell-stack">
                        <HashValue value={receipt.resultHash} label="result hash" />
                        <small>{receipt.artifactUri}</small>
                      </div>
                    </td>
                    <td>
                      <div className="cell-stack">
                        <span>start {formatDateTime(receipt.startedAt)}</span>
                        <small>done {formatDateTime(receipt.completedAt)}</small>
                      </div>
                    </td>
                    <td>
                      <ProvenanceLine provenance={receipt.provenance} lastUpdated={receipt.lastUpdated} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState
            title="No work receipts match"
            detail="Receipt fixtures from future worker outputs should be copied into fixtures/dashboard before display."
          />
        )}
      </section>
    </div>
  );
}
