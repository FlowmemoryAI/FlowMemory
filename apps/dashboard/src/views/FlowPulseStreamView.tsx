import { useMemo, useState } from "react";
import { Search } from "lucide-react";
import { EmptyState } from "../components/EmptyState";
import { HashValue } from "../components/HashValue";
import { ProvenanceLine } from "../components/ProvenanceLine";
import { SectionHeader } from "../components/SectionHeader";
import { StatusBadge } from "../components/StatusBadge";
import { DASHBOARD_STATUSES } from "../data/status";
import { searchRecords } from "../data/selectors";
import type { DashboardData, DashboardStatus } from "../data/types";

export function FlowPulseStreamView({ data }: { data: DashboardData }) {
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState<DashboardStatus | "all">("all");

  const observations = useMemo(() => {
    const statusFiltered =
      status === "all"
        ? data.flowPulseObservations
        : data.flowPulseObservations.filter((observation) => observation.status === status);
    return searchRecords(statusFiltered, query);
  }, [data.flowPulseObservations, query, status]);

  return (
    <div className="view-stack">
      <SectionHeader
        eyebrow="indexer"
        title="FlowPulse stream"
        detail="Decoded local observation records with receipt/log identity, rootfield linkage, and fixture provenance."
        action={
          <div className="filter-row">
            <label className="search-box">
              <Search size={16} aria-hidden="true" />
              <input
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Search observations, hashes, URIs"
              />
            </label>
            <select value={status} onChange={(event) => setStatus(event.target.value as DashboardStatus | "all")}>
              <option value="all">All statuses</option>
              {DASHBOARD_STATUSES.map((item) => (
                <option key={item} value={item}>
                  {item}
                </option>
              ))}
            </select>
          </div>
        }
      />

      <section className="table-panel">
        {observations.length > 0 ? (
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Status</th>
                  <th>Observation</th>
                  <th>Rootfield / pulse</th>
                  <th>Receipt context</th>
                  <th>Commitment</th>
                  <th>Provenance</th>
                </tr>
              </thead>
              <tbody>
                {observations.map((observation) => (
                  <tr key={observation.observationId}>
                    <td>
                      <StatusBadge status={observation.status} />
                    </td>
                    <td>
                      <div className="cell-stack">
                        <HashValue value={observation.observationId} label="observation id" />
                        <small>{observation.summary}</small>
                      </div>
                    </td>
                    <td>
                      <div className="cell-stack">
                        <span>
                          root <HashValue value={observation.rootfieldId} trim="short" />
                        </span>
                        <span>
                          pulse <HashValue value={observation.pulseId} trim="short" />
                        </span>
                      </div>
                    </td>
                    <td>
                      <div className="cell-stack">
                        <span>block {observation.blockNumber}</span>
                        <span>
                          tx <HashValue value={observation.txHash} trim="short" />
                        </span>
                        <small>
                          index {observation.transactionIndex}:{observation.logIndex} / {observation.receiptStatus}
                        </small>
                      </div>
                    </td>
                    <td>
                      <div className="cell-stack">
                        <HashValue value={observation.commitment} label="commitment" />
                        <small>type {observation.pulseType} / seq {observation.sequence}</small>
                      </div>
                    </td>
                    <td>
                      <ProvenanceLine provenance={observation.provenance} lastUpdated={observation.lastUpdated} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState
            title="No FlowPulse records match"
            detail="Clear search or status filters, or sync a generated indexer fixture into the dashboard data path."
          />
        )}
      </section>
    </div>
  );
}

