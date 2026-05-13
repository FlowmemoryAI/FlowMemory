import { useMemo, useState } from "react";
import { Search } from "lucide-react";
import { EmptyState } from "../components/EmptyState";
import { ProvenanceLine } from "../components/ProvenanceLine";
import { SectionHeader } from "../components/SectionHeader";
import { StatusBadge } from "../components/StatusBadge";
import { formatDateTime } from "../data/format";
import { searchRecords } from "../data/selectors";
import type { DashboardData } from "../data/types";

export function AlertsView({ data }: { data: DashboardData }) {
  const [query, setQuery] = useState("");
  const alerts = useMemo(() => searchRecords(data.alerts, query), [data.alerts, query]);

  return (
    <div className="view-stack">
      <SectionHeader
        eyebrow="incidents"
        title="Alerts"
        detail="Local incidents derived from fixture state. Statuses are operational markers, not production monitoring claims."
        action={
          <label className="search-box">
            <Search size={16} aria-hidden="true" />
            <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search alerts" />
          </label>
        }
      />

      {alerts.length > 0 ? (
        <section className="alert-list">
          {alerts.map((alert) => (
            <article className={`alert-row severity-${alert.severity}`} key={alert.incidentId}>
              <div className="alert-main">
                <div className="tile-heading">
                  <StatusBadge status={alert.status} />
                  <span className="severity-label">{alert.severity}</span>
                  <strong>{alert.title}</strong>
                </div>
                <p>{alert.summary}</p>
                <dl className="alert-facts">
                  <div>
                    <dt>incident id</dt>
                    <dd>{alert.incidentId}</dd>
                  </div>
                  <div>
                    <dt>opened</dt>
                    <dd>{formatDateTime(alert.openedAt)}</dd>
                  </div>
                  <div>
                    <dt>linked objects</dt>
                    <dd>{alert.linkedObjectIds.join(", ")}</dd>
                  </div>
                </dl>
                <ProvenanceLine provenance={alert.provenance} lastUpdated={alert.lastUpdated} />
              </div>
              <aside className="alert-action">
                <span>next action</span>
                <p>{alert.recommendedAction}</p>
              </aside>
            </article>
          ))}
        </section>
      ) : (
        <EmptyState
          title="No alerts match"
          detail="Incident fixtures should appear here when generated status snapshots contain unresolved or stale conditions."
        />
      )}
    </div>
  );
}
